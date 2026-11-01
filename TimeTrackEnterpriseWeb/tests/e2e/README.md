# End-to-end scenarios

The Python test suite covers the services and the HTTP stack. The scenarios in
this folder exercise pieces that need a real browser or a real desktop
process, so they are **not** collected by `pytest` (see `norecursedirs` in
`pytest.ini`).

| File | What it checks | How to run |
| --- | --- | --- |
| `test_camera_scan.cjs` | Bundled ZXing decoder, frame downscaling and native `BarcodeDetector` fallback | `node --test tests/e2e/test_camera_scan.cjs` |

## Manual checklist

Run the desktop build (`run.bat` or `dist/TimeTrackEnterprise.exe`) and verify:

1. **Login** — the seeded `admin` account opens without a password; changing
   the password forces the new one.
2. **Gate scan** — camera scan and a USB/keyboard wedge both record
   attendance; a repeated scan is reported as a duplicate.
3. **Entry/exit slips** — issue a slip, print it, verify the QR page, then
   return an exit slip.
4. **Messaging** — with `sms_test_mode` on, a campaign is simulated without
   network access and appears in the campaign history.
5. **Reports** — daily/monthly JSON, XLSX export and the print view.
6. **Desktop lifecycle** — the launcher opens the browser, the data folder
   (`data/`, or `--data-dir`) keeps the database, and `/health/` answers.
7. **Android companion** — use a manager-issued staff code to sign in, sync
   the offline roster, submit a scan, and open the parent portal with a
   student's national ID against the same server URL.

## Camera-scan test

The Node test loads the vendored decoder and the browser module in a `vm`
sandbox, so it needs no browser:

```powershell
node --test tests/e2e/test_camera_scan.cjs
```

Node 20 or newer is required (`node:test`).
