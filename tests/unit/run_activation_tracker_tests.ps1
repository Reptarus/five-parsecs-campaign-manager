# Run Activation Tracker Test Suite
#
# Usage: .\run_activation_tracker_tests.ps1
#
# Runs test_activation_tracker.gd via Godot console in UI mode
# (headless mode disabled due to signal 11 crash after 8-18 tests)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Battle Activation Tracker Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$godotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$projectPath = "c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$testFile = "tests/unit/test_activation_tracker.gd"

Write-Host "Test File: $testFile" -ForegroundColor Yellow
Write-Host "Test Count: 12/13 (at runner stability limit)" -ForegroundColor Yellow
Write-Host "Components: UnitActivationCard + ActivationTrackerPanel" -ForegroundColor Yellow
Write-Host ""

Write-Host "Running tests..." -ForegroundColor Green

& $godotPath `
  --path $projectPath `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a $testFile `
  --quit-after 60

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test run completed!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
