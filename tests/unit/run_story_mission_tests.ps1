# Run Story Mission Loader Tests
# Usage: .\run_story_mission_tests.ps1

$GodotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$ProjectPath = "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$TestFile = "tests/unit/test_story_mission_loader.gd"

Write-Host "=== Running Story Mission Loader Tests ===" -ForegroundColor Cyan
Write-Host "Test File: $TestFile" -ForegroundColor Yellow
Write-Host ""

& $GodotPath `
  --path $ProjectPath `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a $TestFile `
  --quit-after 60

Write-Host ""
Write-Host "=== Test Run Complete ===" -ForegroundColor Cyan
