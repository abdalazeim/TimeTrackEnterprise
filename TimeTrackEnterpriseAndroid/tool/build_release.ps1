#requires -Version 5.1
# One-shot release build:
#   1. analyze + unit/widget tests
#   2. flutter build apk --release  (requires production signing and API_BASE_URL)
#   3. refresh dist icon, shortcut and install notes
#
# Run: powershell -ExecutionPolicy Bypass -File tool\build_release.ps1

$ErrorActionPreference = 'Stop'
$requiredReleaseVariables = @(
  'ANDROID_KEYSTORE_PATH',
  'ANDROID_KEYSTORE_PASSWORD',
  'ANDROID_KEY_ALIAS',
  'ANDROID_KEY_PASSWORD',
  'API_BASE_URL'
)
$missingReleaseVariables = @($requiredReleaseVariables | Where-Object {
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
})
if ($missingReleaseVariables.Count -gt 0) {
  throw "Set the required release variables before building: $($missingReleaseVariables -join ', ')"
}

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }

  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }

  $appName = if ([string]::IsNullOrWhiteSpace($env:APP_NAME)) { 'Generic Android Template' } else { $env:APP_NAME }
  $locale = if ([string]::IsNullOrWhiteSpace($env:APP_LOCALE)) { 'ar' } else { $env:APP_LOCALE }
  $apiBaseUrl = $env:API_BASE_URL
  flutter build apk --release "--dart-define=APP_NAME=$appName" "--dart-define=APP_LOCALE=$locale" "--dart-define=API_BASE_URL=$apiBaseUrl"
  if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }

  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make_windows_assets.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'make_windows_assets.ps1 failed' }

  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  Write-Output ''
  Write-Output 'Deliverables in dist\:'
  Get-ChildItem (Join-Path $root 'dist') | ForEach-Object {
    Write-Output ("  {0}  ({1:N0} bytes)" -f $_.Name, $_.Length)
  }
}
finally {
  Pop-Location
}
