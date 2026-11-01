"""Django-independent helpers for signed update manifests.

Both the running application (``apps/modules/services/update_service.py``) and
the release script (``scripts/sign_update.py``) must validate a manifest in
exactly the same way.  This module is deliberately free of Django imports so a
build machine can sign a release without configuring settings or touching the
database.
"""
from __future__ import annotations

import base64
import json
import re
from urllib.parse import urlsplit

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

MAX_ARTIFACT_BYTES = 400 * 1024 * 1024
VERSION_RE = re.compile(r"^\d{1,4}\.\d{1,4}\.\d{1,4}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
KINDS = {"portable", "setup"}


class UpdateSignatureError(ValueError):
    """Raised when a manifest is malformed or its signature is invalid."""


def canonical_payload(manifest: dict) -> bytes:
    """Deterministic JSON used for the Ed25519 signature."""
    payload = {key: value for key, value in manifest.items() if key != "signature"}
    return json.dumps(
        payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def verify_manifest(manifest, public_key_b64: str) -> dict:
    """Validate the shape and signature of ``latest.json``.

    Returns a normalised copy with only the known fields.  Raises
    :class:`UpdateSignatureError` with an Arabic message on failure.
    """
    if not isinstance(manifest, dict):
        raise UpdateSignatureError("ملف التحديث غير صالح.")
    signature = manifest.get("signature")
    if not isinstance(signature, str) or not signature.strip():
        raise UpdateSignatureError("التحديث غير موقّع ولن يتم تثبيته.")
    try:
        signature_bytes = base64.b64decode(signature, validate=True)
    except Exception as error:  # binascii.Error, ValueError
        raise UpdateSignatureError("توقيع التحديث مشوّه.") from error

    version = str(manifest.get("version") or "").strip()
    if not VERSION_RE.fullmatch(version):
        raise UpdateSignatureError("رقم إصدار التحديث غير صالح.")
    notes = manifest.get("notes", "")
    if not isinstance(notes, str) or len(notes) > 5000:
        raise UpdateSignatureError("وصف التحديث غير صالح.")
    files = manifest.get("files")
    if not isinstance(files, list) or not files or len(files) > 10:
        raise UpdateSignatureError("قائمة ملفات التحديث غير صالحة.")

    clean_files = []
    for entry in files:
        if not isinstance(entry, dict):
            raise UpdateSignatureError("ملف تحديث غير صالح.")
        kind = str(entry.get("kind") or "")
        url = str(entry.get("url") or "").strip()
        digest = str(entry.get("sha256") or "").strip().lower()
        parsed = urlsplit(url)
        try:
            size = int(entry.get("size") or 0)
        except (TypeError, ValueError):
            size = 0
        if kind not in KINDS:
            raise UpdateSignatureError("نوع ملف التحديث غير معروف.")
        if parsed.scheme != "https" or not parsed.hostname:
            raise UpdateSignatureError("روابط التحديث يجب أن تكون https.")
        if not SHA256_RE.fullmatch(digest):
            raise UpdateSignatureError("بصمة SHA-256 لملف التحديث غير صالحة.")
        if size <= 0 or size > MAX_ARTIFACT_BYTES:
            raise UpdateSignatureError("حجم ملف التحديث غير صالح.")
        clean_files.append(
            {
                "kind": kind,
                "url": url,
                "sha256": digest,
                "size": size,
                "name": str(entry.get("name") or "")[:120],
            }
        )

    try:
        schema = int(manifest.get("schema") or 1)
    except (TypeError, ValueError) as error:
        raise UpdateSignatureError("إصدار صيغة التحديث غير صالح.") from error

    clean = {
        "schema": schema,
        "version": version,
        "notes": notes,
        "published_at": str(manifest.get("published_at") or ""),
        "files": clean_files,
        "signature": signature,
    }

    try:
        key_bytes = base64.b64decode(public_key_b64)
        public_key = Ed25519PublicKey.from_public_bytes(key_bytes)
        public_key.verify(signature_bytes, canonical_payload(clean))
    except (InvalidSignature, ValueError, TypeError) as error:
        raise UpdateSignatureError("توقيع التحديث غير صالح. تم رفض الملف.") from error

    if not any(entry["kind"] == "portable" for entry in clean_files) and not any(
        entry["kind"] == "setup" for entry in clean_files
    ):
        raise UpdateSignatureError("لا يحتوي التحديث على ملف قابل للتثبيت.")
    return clean
