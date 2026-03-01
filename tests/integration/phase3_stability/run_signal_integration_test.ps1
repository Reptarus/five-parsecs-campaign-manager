# Run signal integration tests with lambda-to-method fix
# Expected: 10/10 tests passing (was 0/10 before fix)

$godotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$projectPath = "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$testFile = "tests/integration/phase3_stability/test_signal_integration.gd"

Write-Host "Running Signal Integration Tests (Lambda-to-Method Fix)" -ForegroundColor Cyan
Write-Host "Expected: 10/10 passing (all lambda handlers converted to instance methods)" -ForegroundColor Yellow
Write-Host ""

& $godotPath `
  --path $projectPath `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a $testFile `
  --quit-after 60

Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "- 3 Signal Connection Lifecycle Tests" -ForegroundColor Gray
Write-Host "- 3 Signal Propagation Tests" -ForegroundColor Gray
Write-Host "- 2 Memory Leak Prevention Tests" -ForegroundColor Gray
Write-Host "- 2 Signal Validation Tests" -ForegroundColor Gray
Write-Host ""
Write-Host "Key Changes:" -ForegroundColor Cyan
Write-Host "- Lambdas replaced with instance methods (_on_testN_handler)" -ForegroundColor Green
Write-Host "- Instance variables for tracking (_testN_handler_call_count)" -ForegroundColor Green
Write-Host "- State reset at start of each test" -ForegroundColor Green
Write-Host "- Last test still uses lambda (validation only, no GC issues)" -ForegroundColor Yellow
