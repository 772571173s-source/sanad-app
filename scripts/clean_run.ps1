$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $ProjectRoot

Write-Host "[1/4] Cleaning Flutter build cache..." -ForegroundColor Yellow
flutter clean 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] flutter clean failed." -ForegroundColor Red; exit 1 }

Write-Host "[2/4] Removing iOS/Podfile.lock & Pods (if present)..." -ForegroundColor Yellow
Remove-Item -LiteralPath "ios\Podfile.lock" -ErrorAction SilentlyContinue
Remove-Item -LiteralPath "ios\Pods" -Recurse -ErrorAction SilentlyContinue

Write-Host "[3/4] Getting Flutter packages..." -ForegroundColor Yellow
flutter pub get 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] flutter pub get failed." -ForegroundColor Red; exit 1 }

Write-Host "[4/4] Running Android clean install..." -ForegroundColor Yellow
& "$PSScriptRoot\run_android.ps1" @args
