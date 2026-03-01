# Run Both Story Mission Loader Test Files
# Usage: .\run_both_story_tests.ps1

$GodotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$ProjectPath = "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"

Write-Host "=== Running Story Mission Loader Tests (Part 1) ===" -ForegroundColor Cyan

& $GodotPath `
  --path $ProjectPath `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_story_mission_loader.gd `
  --quit-after 60

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "=== Running Story Mission Loader Tests (Part 2) ===" -ForegroundColor Cyan

& $GodotPath `
  --path $ProjectPath `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_story_mission_loader_part2.gd `
  --quit-after 60

Write-Host ""
Write-Host "=== All Test Runs Complete ===" -ForegroundColor Cyan
