$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $ProjectRoot

Write-Host "[1] Killing existing Flutter daemon & Dart processes..." -ForegroundColor Yellow
Get-Process -Name "flutter*","dart*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "[2] Killing ADB server (clears stale connections)..." -ForegroundColor Yellow
$Adb = @(
  "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
  "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
  "${env:ProgramFiles}\Android\android-sdk\platform-tools\adb.exe",
  "C:\Android\Sdk\platform-tools\adb.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($Adb) {
  & $Adb kill-server 2>$null
  Start-Sleep -Seconds 2
  & $Adb start-server 2>$null
  Write-Host "[OK] ADB restarted." -ForegroundColor Green
}

Write-Host "[3] Checking devices..." -ForegroundColor Yellow
flutter devices 2>&1

Write-Host "[4] Launching app on first Android device..." -ForegroundColor Cyan
& "$PSScriptRoot\run_android.ps1" @args
