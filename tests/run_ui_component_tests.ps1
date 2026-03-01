# PowerShell Script: Run UI Component Tests
# Tests the modernized dashboard components
# Usage: .\run_ui_component_tests.ps1

$ProjectPath = "c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$GodotExe = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"

$TestFiles = @(
    'tests/unit/test_campaign_turn_tracker.gd',
    'tests/integration/test_dashboard_components.gd'
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "UI Component Test Suite" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$TotalTests = 0
$PassedTests = 0
$SkippedTests = 0
$FailedTests = 0

foreach ($TestFile in $TestFiles) {
    Write-Host "Running: $TestFile" -ForegroundColor Yellow
    Write-Host "-------------------------------------" -ForegroundColor Gray

    & $GodotExe `
      --path $ProjectPath `
      --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
      -a $TestFile `
      --quit-after 60

    Write-Host ""
}

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Test Suite Complete" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Coverage:" -ForegroundColor White
Write-Host "  - CampaignTurnProgressTracker: 8 tests" -ForegroundColor Gray
Write-Host "  - MissionStatusCard: 3 tests" -ForegroundColor Gray
Write-Host "  - WorldStatusCard: 2 tests" -ForegroundColor Gray
Write-Host "  - StoryTrackSection: 2 tests" -ForegroundColor Gray
Write-Host "  - QuickActionsFooter: 4 tests" -ForegroundColor Gray
Write-Host "  - Glass Morphism: 2 tests" -ForegroundColor Gray
Write-Host "  Total: 21 tests" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Tests will skip gracefully if components not yet implemented" -ForegroundColor Yellow
Write-Host "See tests/UI_COMPONENT_TESTING_GUIDE.md for details" -ForegroundColor Yellow
