#requires -Version 5.1
# Generates the launcher icon set (legacy, adaptive, monochrome, round)
# and the branded splash assets. Pure System.Drawing - no extra tooling.
# Run: powershell -ExecutionPolicy Bypass -File tool\generate_launcher_icon.ps1

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$res = Join-Path $root 'android\app\src\main\res'
$previewDir = Join-Path $root 'build\icon-preview'
New-Item -ItemType Directory -Force -Path $previewDir | Out-Null

$Utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

# Brand palette matches TimeTrackEnterpriseWeb/static/images/favicon.svg.
$Deep = [System.Drawing.Color]::FromArgb(255, 16, 36, 64)
$Green = [System.Drawing.Color]::FromArgb(255, 7, 111, 110)
$Mint = [System.Drawing.Color]::FromArgb(255, 184, 245, 224)
$Check = [System.Drawing.Color]::FromArgb(255, 8, 59, 70)
$White = [System.Drawing.Color]::White
$Transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)

function New-RoundedPath {
  param([float]$X, [float]$Y, [float]$W, [float]$H, [float]$R)
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  if ($R -le 0) {
    $path.AddRectangle([System.Drawing.RectangleF]::new($X, $Y, $W, $H))
    return $path
  }
  $d = [Math]::Min($R * 2, [Math]::Min($W, $H))
  $path.AddArc([float]$X, [float]$Y, [float]$d, [float]$d, 180, 90)
  $path.AddArc([float]($X + $W - $d), [float]$Y, [float]$d, [float]$d, 270, 90)
  $path.AddArc([float]($X + $W - $d), [float]($Y + $H - $d), [float]$d, [float]$d, 0, 90)
  $path.AddArc([float]$X, [float]($Y + $H - $d), [float]$d, [float]$d, 90, 90)
  $path.CloseFigure()
  return $path
}

function Draw-Background {
  param([System.Drawing.Graphics]$G, [bool]$Circle)

  if ($Circle) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddEllipse(0, 0, 1024, 1024)
  } else {
    $path = New-RoundedPath 16 16 992 992 256
  }

  $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.PointF]::new(96, -70),
    [System.Drawing.PointF]::new(925, 1090),
    $Deep,
    $Green
  )
  $blend = New-Object System.Drawing.Drawing2D.ColorBlend -ArgumentList 4
  $blend.Colors = [System.Drawing.Color[]]@($Deep, $Deep, $Green, $Green)
  $blend.Positions = [single[]]@(0.0, 0.116, 0.888, 1.0)
  $brush.InterpolationColors = $blend
  $G.FillPath($brush, $path)
  $brush.Dispose()
  $path.Dispose()
}

function Fill-TransparentPath {
  param([System.Drawing.Graphics]$G, [System.Drawing.Drawing2D.GraphicsPath]$Path)
  $previous = $G.CompositingMode
  $G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $brush = [System.Drawing.SolidBrush]::new($Transparent)
  $G.FillPath($brush, $Path)
  $brush.Dispose()
  $G.CompositingMode = $previous
}

function Fill-TransparentEllipse {
  param([System.Drawing.Graphics]$G, [int]$X, [int]$Y, [int]$W, [int]$H)
  $previous = $G.CompositingMode
  $G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $brush = [System.Drawing.SolidBrush]::new($Transparent)
  $G.FillEllipse($brush, $X, $Y, $W, $H)
  $brush.Dispose()
  $G.CompositingMode = $previous
}

# The clock and verified-status badge match the web favicon's geometry.
function Draw-Emblem {
  param(
    [System.Drawing.Graphics]$G,
    [double]$Scale,
    [double]$CX = 512,
    [double]$CY = 512,
    [switch]$Mono
  )

  $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $G.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $state = $G.Save()
  $G.TranslateTransform([float]$CX, [float]$CY)
  $G.ScaleTransform([float]$Scale, [float]$Scale)

  $ring = [System.Drawing.Pen]::new($White, [single](56 * $Scale))
  $ring.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $ring.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $G.DrawEllipse($ring, -352, -352, 576, 576)
  $ring.Dispose()

  $ticks = [System.Drawing.Pen]::new($White, [single](40 * $Scale))
  $ticks.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $ticks.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $G.DrawLine($ticks, -64, -352, -64, -288)
  $G.DrawLine($ticks, 224, -64, 160, -64)
  $G.DrawLine($ticks, -64, 224, -64, 160)
  $G.DrawLine($ticks, -352, -64, -288, -64)
  $ticks.Dispose()

  $hands = [System.Drawing.Pen]::new($White, [single](56 * $Scale))
  $hands.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $hands.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $G.DrawLine($hands, -64, -64, 112, -240)
  $G.DrawLine($hands, -64, -64, -224, -224)
  $hands.Dispose()

  $dot = [System.Drawing.SolidBrush]::new($White)
  $G.FillEllipse($dot, -104, -104, 80, 80)
  $dot.Dispose()

  if (-not $Mono) {
    $badge = [System.Drawing.SolidBrush]::new($Mint)
    $G.FillEllipse($badge, 80, 80, 320, 320)
    $badge.Dispose()
  }

  $accent = if ($Mono) { $White } else { $Check }
  $check = [System.Drawing.Pen]::new($accent, [single](43.2 * $Scale))
  $check.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $check.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $check.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $points = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(168, 240),
    [System.Drawing.PointF]::new(217.6, 289.6),
    [System.Drawing.PointF]::new(313.6, 180.8)
  )
  $G.DrawLines($check, $points)
  $check.Dispose()
  $G.Restore($state)
}
function New-Canvas {
  $bitmap = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bitmap.SetResolution(96, 96)
  return $bitmap
}

function Save-Scaled {
  param(
    [System.Drawing.Bitmap]$Source,
    [int]$Size,
    [string]$Path
  )
  $directory = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null

  $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bitmap.SetResolution(96, 96)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.DrawImage($Source, 0, 0, $Size, $Size)
  $graphics.Dispose()
  $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

function Write-TextFile {
  param([string]$Path, [string]$Content)
  $directory = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

# --- Masters -------------------------------------------------------------
$legacy = New-Canvas
$g = [System.Drawing.Graphics]::FromImage($legacy)
$g.Clear($Transparent)
Draw-Background -G $g -Circle $false
Draw-Emblem -G $g -Scale 1.0
$g.Dispose()
$legacy.Save((Join-Path $previewDir 'icon-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$round = New-Canvas
$g = [System.Drawing.Graphics]::FromImage($round)
$g.Clear($Transparent)
Draw-Background -G $g -Circle $true
Draw-Emblem -G $g -Scale 1.0
$g.Dispose()
$round.Save((Join-Path $previewDir 'icon-round-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$foreground = New-Canvas
$g = [System.Drawing.Graphics]::FromImage($foreground)
$g.Clear($Transparent)
Draw-Emblem -G $g -Scale 0.78
$g.Dispose()
$foreground.Save((Join-Path $previewDir 'icon-foreground-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$monochrome = New-Canvas
$g = [System.Drawing.Graphics]::FromImage($monochrome)
$g.Clear($Transparent)
Draw-Emblem -G $g -Scale 0.78 -Mono
$g.Dispose()
$monochrome.Save((Join-Path $previewDir 'icon-monochrome-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$splash = New-Canvas
$g = [System.Drawing.Graphics]::FromImage($splash)
$g.Clear($Transparent)
Draw-Emblem -G $g -Scale 0.95
$g.Dispose()
$splash.Save((Join-Path $previewDir 'splash-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# --- Density buckets -----------------------------------------------------
$buckets = @(
  @{ Name = 'mdpi'; Icon = 48; Adaptive = 108 },
  @{ Name = 'hdpi'; Icon = 72; Adaptive = 162 },
  @{ Name = 'xhdpi'; Icon = 96; Adaptive = 216 },
  @{ Name = 'xxhdpi'; Icon = 144; Adaptive = 324 },
  @{ Name = 'xxxhdpi'; Icon = 192; Adaptive = 432 }
)

foreach ($bucket in $buckets) {
  $mipmap = Join-Path $res ('mipmap-' + $bucket.Name)
  $drawable = Join-Path $res ('drawable-' + $bucket.Name)

  Save-Scaled -Source $legacy -Size $bucket.Icon -Path (Join-Path $mipmap 'ic_launcher.png')
  Save-Scaled -Source $round -Size $bucket.Icon -Path (Join-Path $mipmap 'ic_launcher_round.png')
  Save-Scaled -Source $foreground -Size $bucket.Adaptive -Path (Join-Path $drawable 'ic_launcher_foreground.png')
  Save-Scaled -Source $monochrome -Size $bucket.Adaptive -Path (Join-Path $drawable 'ic_launcher_monochrome.png')
}

Save-Scaled -Source $splash -Size 432 -Path (Join-Path $res 'drawable-xxhdpi\splash_logo.png')
Save-Scaled -Source $splash -Size 576 -Path (Join-Path $res 'drawable-xxxhdpi\splash_logo.png')

# --- XML resources -------------------------------------------------------
$adaptiveIcon = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
'@

$backgroundShape = @'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="45"
        android:centerColor="#12385B"
        android:endColor="#24669B"
        android:startColor="#0B1B30"
        android:type="linear" />
</shape>
'@

$colorsXml = @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_background">#0B1B30</color>
</resources>
'@

$launchBackground = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Generic app mark on the configured splash background. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash_logo" />
    </item>
</layer-list>
'@

$launchV31 = @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenIconBackgroundColor">@color/splash_background</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
'@

$launchNightV31 = @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenIconBackgroundColor">@color/splash_background</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
'@

Write-TextFile -Path (Join-Path $res 'mipmap-anydpi-v26\ic_launcher.xml') -Content $adaptiveIcon
Write-TextFile -Path (Join-Path $res 'mipmap-anydpi-v26\ic_launcher_round.xml') -Content $adaptiveIcon
Write-TextFile -Path (Join-Path $res 'drawable\ic_launcher_background.xml') -Content $backgroundShape
Write-TextFile -Path (Join-Path $res 'values\colors.xml') -Content $colorsXml
Write-TextFile -Path (Join-Path $res 'drawable\launch_background.xml') -Content $launchBackground
Write-TextFile -Path (Join-Path $res 'drawable-v21\launch_background.xml') -Content $launchBackground
Write-TextFile -Path (Join-Path $res 'values-v31\styles.xml') -Content $launchV31
Write-TextFile -Path (Join-Path $res 'values-night-v31\styles.xml') -Content $launchNightV31

$legacy.Dispose()
$round.Dispose()
$foreground.Dispose()
$monochrome.Dispose()
$splash.Dispose()

Write-Output "Launcher icon set generated in $res"
Write-Output "Preview: $previewDir"
