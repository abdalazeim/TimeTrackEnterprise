#requires -Version 5.1
# Builds the Windows-facing deliverables for the Generic Android Template:
#   dist\<template name>.apk   (published by the Gradle task publishTemplateApk)
#   dist\generic_template.ico  (multi-resolution icon: 16..256 px)
#   dist\<template name>.lnk   (shortcut with the branded icon)
#   dist\readme.txt            (install steps)
# and optionally mirrors the shortcut (not the APK) to the Desktop.
#
# Run: powershell -ExecutionPolicy Bypass -File tool\make_windows_assets.ps1 [-CreateDesktopShortcut]

param([switch]$CreateDesktopShortcut)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

# --- Version (single source of truth: pubspec.yaml) ----------------------
$versionName = ''
$versionCode = ''
$pubspecPath = Join-Path $root 'pubspec.yaml'
if (Test-Path $pubspecPath) {
  $pubspec = [System.IO.File]::ReadAllText($pubspecPath)
  if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
    $versionName = $Matches[1]
    $versionCode = $Matches[2]
  }
}
$versionLabel = if ($versionName) { "$versionName (build $versionCode)" } else { 'Not specified' }

$appName = if ([string]::IsNullOrWhiteSpace($env:APP_NAME)) { 'Generic Android Template' } else { $env:APP_NAME }
$apkName = "$appName.apk"
$readmeName = 'readme.txt'

$masterPath = Join-Path $root 'build\icon-preview\icon-1024.png'
if (-not (Test-Path $masterPath)) {
  $masterPath = Join-Path $root 'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png'
}
if (-not (Test-Path $masterPath)) {
  throw 'Launcher icon master not found. Run tool\generate_launcher_icon.ps1 first.'
}

$master = [System.Drawing.Bitmap]::FromFile((Resolve-Path $masterPath))

# --- ICO (PNG-compressed frames, Vista+) ---------------------------------
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$frames = New-Object System.Collections.ArrayList

foreach ($size in $sizes) {
  $frame = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $frame.SetResolution(96, 96)
  $graphics = [System.Drawing.Graphics]::FromImage($frame)
  $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.DrawImage($master, 0, 0, $size, $size)
  $graphics.Dispose()

  $stream = New-Object System.IO.MemoryStream
  $frame.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  [void]$frames.Add([pscustomobject]@{ Size = $size; Data = $stream.ToArray() })
  $stream.Dispose()
  $frame.Dispose()
}
$master.Dispose()

$icoPath = Join-Path $dist 'generic_template.ico'
$headerSize = 6 + (16 * $frames.Count)
$offset = $headerSize
$writer = [System.IO.BinaryWriter]::new([System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create))
try {
  $writer.Write([uint16]0)                # reserved
  $writer.Write([uint16]1)                # type: icon
  $writer.Write([uint16]$frames.Count)
  foreach ($frame in $frames) {
    $dimension = if ($frame.Size -ge 256) { 0 } else { $frame.Size }
    $writer.Write([byte]$dimension)       # width
    $writer.Write([byte]$dimension)       # height
    $writer.Write([byte]0)                # palette
    $writer.Write([byte]0)                # reserved
    $writer.Write([uint16]1)              # planes
    $writer.Write([uint16]32)             # bpp
    $writer.Write([uint32]$frame.Data.Length)
    $writer.Write([uint32]$offset)
    $offset += $frame.Data.Length
  }
  foreach ($frame in $frames) { $writer.Write($frame.Data) }
}
finally {
  $writer.Dispose()
}

# --- Shortcut with the branded icon --------------------------------------
$apkPath = Join-Path $dist $apkName
$shell = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path $dist "$appName.lnk"

function New-TemplateShortcut {
  param([string]$LnkPath, [string]$IconPath, [string]$TargetDir)

  # WScript.Shell cannot save a .lnk whose path contains non-ASCII characters,
  # so the file is written with an ASCII name first and then renamed.
  $tempLnk = Join-Path $env:TEMP ('template-shortcut-' + [guid]::NewGuid().ToString('N') + '.lnk')
  $shortcut = $shell.CreateShortcut($tempLnk)
  # The shortcut opens the dist folder so the user always finds the APK.
  $shortcut.TargetPath = $TargetDir
  $shortcut.IconLocation = "$IconPath,0"
  $shortcut.Description = "$appName - Android package"
  $shortcut.WorkingDirectory = $TargetDir
  $shortcut.Save()

  if (Test-Path -LiteralPath $LnkPath) { Remove-Item -LiteralPath $LnkPath -Force }
  Move-Item -LiteralPath $tempLnk -Destination $LnkPath -Force
}

New-TemplateShortcut -LnkPath $shortcutPath -IconPath $icoPath -TargetDir $dist

# --- Install notes -------------------------------------------------------
$readme = @"
$appName
====================

الإصدار: $versionLabel

ملف التثبيت: $apkName

خطوات التثبيت على الهاتف:
1) انسخ ملف APK إلى الهاتف (كيبل USB أو واتساب/تيليجرام أو Drive).
2) افتح الملف من مدير الملفات، واسمح بالتثبيت من هذا المصدر إن طُلب.
3) إن كانت هناك نسخة قديمة مثبتة: احذفها أولًا ثم ثبّت هذه النسخة.
4) بعد التثبيت يظهر التطبيق باسم "$appName" مع أيقونة التطبيق.

ملاحظات:
- أيقونة ملف APK داخل Windows تظهر عامة لأن Windows لا يقرأ أيقونات APK المدمجة.
  الأيقونة الحقيقية تظهر بعد التثبيت على أندرويد.
- يتطلب بناء الإصدار مفتاح توقيع إنتاج مضبوطًا عبر متغيرات البيئة في دليل التطوير.
"@
$utf8Bom = New-Object System.Text.UTF8Encoding -ArgumentList $true
[System.IO.File]::WriteAllText((Join-Path $dist $readmeName), $readme, $utf8Bom)

# --- Optional shortcut on the Desktop -----------------------------------
$desktop = [Environment]::GetFolderPath('Desktop')
if ($CreateDesktopShortcut -and $desktop -and (Test-Path $desktop)) {
  $desktopShortcut = Join-Path $desktop "$appName.lnk"
  New-TemplateShortcut -LnkPath $desktopShortcut -IconPath $icoPath -TargetDir $dist
  Write-Output "Desktop shortcut: $desktopShortcut"
}

if (Test-Path $apkPath) {
  $size = [Math]::Round((Get-Item $apkPath).Length / 1MB, 2)
  Write-Output "APK: $apkPath ($size MB)"
}
else {
  Write-Warning "APK not found yet: $apkPath (run flutter build apk --release)"
}
Write-Output "Icon: $icoPath"
Write-Output "Shortcut: $shortcutPath"
