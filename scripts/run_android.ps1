param(
  [switch]$Release,
  [switch]$Profile
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $ProjectRoot

$AdbPaths = @(
  "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
  "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
  "${env:ProgramFiles}\Android\android-sdk\platform-tools\adb.exe",
  "C:\Android\Sdk\platform-tools\adb.exe"
)

$Adb = $null
foreach ($path in $AdbPaths) {
  if (Test-Path -LiteralPath $path) { $Adb = $path; break }
}

if (-not $Adb) {
  Write-Host "`n[ERROR] adb.exe not found. Install Android SDK platform-tools." -ForegroundColor Red
  Write-Host "  Expected at: $env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`n"
  exit 1
}

$Devices = & $Adb devices | Select-String -Pattern "^\w+\s+device$"
if (-not $Devices) {
  Write-Host "`n[ERROR] No Android device connected. Connect your phone via USB." -ForegroundColor Red
  Write-Host "  Tips:"
  Write-Host "  1. Enable USB Debugging in Developer Options"
  Write-Host "  2. Check with: $Adb devices`n"
  exit 1
}

$RawLines = $Devices.Matches.Value
$DeviceId = ($RawLines -split '\s+')[0]
Write-Host "[OK] Device found: $DeviceId" -ForegroundColor Green

$BuildMode = 'debug'
if ($Release) { $BuildMode = 'release' }
if ($Profile) { $BuildMode = 'profile' }

Write-Host "[INFO] Running flutter $BuildMode on $DeviceId ...`n" -ForegroundColor Cyan

$Args = @('run', '-d', $DeviceId)
if ($Release) { $Args += '--release' }
if ($Profile) { $Args += '--profile' }

$proc = Start-Process -FilePath 'flutter' -ArgumentList $Args -NoNewWindow -Wait -PassThru
exit $proc.ExitCode
