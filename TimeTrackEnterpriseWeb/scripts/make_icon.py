"""Generate the Windows application icon without external image libraries."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build_assets" / "attendance.ico"
SIZES = (16, 24, 32, 48, 64, 128, 256)
MASTER = 1024

NAVY_TOP = (16, 36, 64)
TEAL_BOTTOM = (7, 111, 110)
CLOCK_FACE = (247, 253, 255, 255)
BADGE_FILL = (184, 245, 224, 255)
BADGE_CHECK = (8, 59, 70, 255)


def _rounded_rect(x: float, y: float, left: float, top: float, right: float, bottom: float, radius: float) -> bool:
    if x < left or x > right or y < top or y > bottom:
        return False
    nearest_x = min(max(x, left + radius), right - radius)
    nearest_y = min(max(y, top + radius), bottom - radius)
    return (x - nearest_x) ** 2 + (y - nearest_y) ** 2 <= radius * radius


def _segment_distance(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    t = 0.0 if length_sq == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_sq))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def _master_pixels() -> list[tuple[int, int, int, int]]:
    clock_x, clock_y, clock_r = 448.0, 432.0, 270.0
    badge_x, badge_y, badge_r = 722.0, 722.0, 156.0
    minute_hand = (625.0, 270.0)
    hour_hand = (288.0, 270.0)
    check = ((654.0, 722.0), (700.0, 768.0), (792.0, 664.0))
    pixels: list[tuple[int, int, int, int]] = []
    margin = 26.0
    radius = 226.0
    for y in range(MASTER):
        py = y + 0.5
        ratio = (x_ratio := y / (MASTER - 1))
        background = (
            round(NAVY_TOP[0] + (TEAL_BOTTOM[0] - NAVY_TOP[0]) * ratio),
            round(NAVY_TOP[1] + (TEAL_BOTTOM[1] - NAVY_TOP[1]) * ratio),
            round(NAVY_TOP[2] + (TEAL_BOTTOM[2] - NAVY_TOP[2]) * ratio),
            255,
        )
        for x in range(MASTER):
            px = x + 0.5
            if not _rounded_rect(px, py, margin, margin, MASTER - margin, MASTER - margin, radius):
                pixels.append((0, 0, 0, 0))
                continue
            color = background
            clock_dx, clock_dy = px - clock_x, py - clock_y
            clock_distance = math.hypot(clock_dx, clock_dy)
            badge_dx, badge_dy = px - badge_x, py - badge_y
            badge_distance = math.hypot(badge_dx, badge_dy)

            if abs(clock_distance - clock_r) <= 24:
                color = CLOCK_FACE
            elif any(
                _segment_distance(px, py, *start, *end) <= width / 2
                for start, end, width in (
                    ((clock_x, clock_y - 196), (clock_x, clock_y - 228), 16),
                    ((clock_x + 196, clock_y), (clock_x + 228, clock_y), 16),
                    ((clock_x, clock_y + 196), (clock_x, clock_y + 228), 16),
                    ((clock_x - 196, clock_y), (clock_x - 228, clock_y), 16),
                    ((clock_x, clock_y), minute_hand, 30),
                    ((clock_x, clock_y), hour_hand, 38),
                )
            ) or clock_distance <= 28:
                color = CLOCK_FACE

            if badge_distance <= badge_r:
                color = BADGE_FILL
                if any(
                    _segment_distance(px, py, check[i][0], check[i][1], check[i + 1][0], check[i + 1][1]) <= 23
                    for i in range(len(check) - 1)
                ):
                    color = BADGE_CHECK
            pixels.append(color)
    return pixels


def _downsample(master: list[tuple[int, int, int, int]], size: int) -> list[tuple[int, int, int, int]]:
    factor = MASTER // size
    pixels: list[tuple[int, int, int, int]] = []
    for y in range(size):
        row_base = y * factor * MASTER
        for x in range(size):
            red = green = blue = alpha = 0
            for dy in range(factor):
                index = row_base + dy * MASTER + x * factor
                for dx in range(factor):
                    r, g, b, a = master[index + dx]
                    red += r * a
                    green += g * a
                    blue += b * a
                    alpha += a
            if alpha:
                pixels.append((red // alpha, green // alpha, blue // alpha, alpha // (factor * factor)))
            else:
                pixels.append((0, 0, 0, 0))
    return pixels


def _png(size: int, pixels: list[tuple[int, int, int, int]]) -> bytes:
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            r, g, b, a = pixels[y * size + x]
            raw.extend((r, g, b, a))

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(
            ">I", zlib.crc32(tag + payload) & 0xFFFFFFFF
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def _dib(size: int, pixels: list[tuple[int, int, int, int]]) -> bytes:
    header = struct.pack(
        "<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, size * size * 4, 0, 0, 0, 0
    )
    body = bytearray()
    for y in range(size - 1, -1, -1):
        for x in range(size):
            r, g, b, a = pixels[y * size + x]
            body.extend((b, g, r, a))
    mask_stride = ((size + 31) // 32) * 4
    mask = bytearray(mask_stride * size)
    for y in range(size):
        row = (size - 1 - y) * mask_stride
        for x in range(size):
            if pixels[y * size + x][3] == 0:
                mask[row + x // 8] |= 0x80 >> (x % 8)
    return header + bytes(body) + bytes(mask)


def build_ico(path: Path) -> None:
    master = _master_pixels()
    entries: list[tuple[int, bytes]] = []
    for size in SIZES:
        pixels = _downsample(master, size)
        entries.append((size, _png(size, pixels) if size >= 128 else _dib(size, pixels)))

    offset = 6 + 16 * len(entries)
    directory = bytearray(struct.pack("<HHH", 0, 1, len(entries)))
    payload = bytearray()
    for size, data in entries:
        directory.extend(
            struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(data), offset)
        )
        payload.extend(data)
        offset += len(data)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(directory) + bytes(payload))


if __name__ == "__main__":
    build_ico(OUTPUT)
    print(f"Wrote {OUTPUT} ({OUTPUT.stat().st_size} bytes)")
