#!/usr/bin/env pwsh
# PowerShell script to run rival patron mechanics tests
# Uses UI mode (NOT headless) to avoid signal 11 crash

$GodotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$ProjectPath = "c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$TestFile = "tests/unit/test_rival_patron_mechanics.gd"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running Rival & Patron Mechanics Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test File: $TestFile" -ForegroundColor Yellow
Write-Host "Godot Version: 4.5.1 (UI mode for stability)" -ForegroundColor Yellow
Write-Host ""

# Run the test suite
& $GodotPath `
  --path $ProjectPath `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a $TestFile `
  --quit-after 60

# Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "All rival patron tests PASSED!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Some tests FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
}
