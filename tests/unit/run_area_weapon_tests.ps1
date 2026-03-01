# Run area weapon resolution tests
# Tests BattleCalculations area/template weapon system

$godotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$projectPath = "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$testFile = "tests/unit/test_area_weapon_resolution.gd"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Area Weapon Resolution Test Suite" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testing:" -ForegroundColor Yellow
Write-Host "  - get_targets_in_area() - Circular area detection" -ForegroundColor Gray
Write-Host "  - get_targets_in_spread() - Cone spread detection" -ForegroundColor Gray
Write-Host "  - resolve_area_attack() - Multi-target damage resolution" -ForegroundColor Gray
Write-Host "  - Shared damage roll across targets" -ForegroundColor Gray
Write-Host "  - Individual armor saves per target" -ForegroundColor Gray
Write-Host "  - Piercing trait interaction" -ForegroundColor Gray
Write-Host "  - Elimination checks" -ForegroundColor Gray
Write-Host "  - Primary target deduplication" -ForegroundColor Gray
Write-Host ""

& $godotPath `
    --path $projectPath `
    --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
    -a $testFile `
    --quit-after 60

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Test run complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
