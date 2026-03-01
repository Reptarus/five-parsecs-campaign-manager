# Headless Mode Verification Script for GDUnit4
#
# Tests whether headless mode works reliably with gdUnit4 v6.0.3
# Previously crashed with signal 11 after 8-18 tests on v6.0.1
#
# Usage: .\verify_headless_mode.ps1
#
# Tests 3 phases:
#   Phase 1: Small test (3 tests) - Quick sanity check
#   Phase 2: Medium test (13 tests) - Original crash threshold
#   Phase 3: Full directory - All unit tests

param(
    [switch]$SkipPhase1,
    [switch]$SkipPhase2,
    [switch]$FullOnly,
    [int]$Timeout = 120
)

$ErrorActionPreference = "Continue"

# Configuration
$godotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
$projectPath = "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  GDUnit4 Headless Mode Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "GDUnit4 Version: 6.0.3" -ForegroundColor Yellow
Write-Host "Godot Version: 4.5.1-stable" -ForegroundColor Yellow
Write-Host "Previous Issue: Signal 11 crash after 8-18 tests (v6.0.1)" -ForegroundColor Yellow
Write-Host ""

function Run-HeadlessTest {
    param(
        [string]$TestPath,
        [string]$Description,
        [int]$ExpectedTests,
        [int]$TimeoutSec = 120
    )

    Write-Host "------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "TEST: $Description" -ForegroundColor White
    Write-Host "Path: $TestPath" -ForegroundColor Gray
    Write-Host "Expected: ~$ExpectedTests tests" -ForegroundColor Gray
    Write-Host "Timeout: ${TimeoutSec}s" -ForegroundColor Gray
    Write-Host ""

    $startTime = Get-Date

    try {
        $process = Start-Process -FilePath $godotPath -ArgumentList @(
            "--headless",
            "--path", $projectPath,
            "--script", "addons/gdUnit4/bin/GdUnitCmdTool.gd",
            "-a", $TestPath,
            "--ignoreHeadlessMode",
            "-c"
        ) -PassThru -NoNewWindow -Wait -RedirectStandardOutput "headless_stdout.tmp" -RedirectStandardError "headless_stderr.tmp"

        $duration = (Get-Date) - $startTime
        $exitCode = $process.ExitCode

        # Read output
        $stdout = ""
        $stderr = ""
        if (Test-Path "headless_stdout.tmp") {
            $stdout = Get-Content "headless_stdout.tmp" -Raw
            Remove-Item "headless_stdout.tmp" -Force
        }
        if (Test-Path "headless_stderr.tmp") {
            $stderr = Get-Content "headless_stderr.tmp" -Raw
            Remove-Item "headless_stderr.tmp" -Force
        }

        Write-Host "Duration: $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
        Write-Host "Exit Code: $exitCode" -ForegroundColor Gray

        if ($exitCode -eq 0) {
            Write-Host "RESULT: PASSED" -ForegroundColor Green
            return @{ Success = $true; ExitCode = $exitCode; Duration = $duration; Output = $stdout }
        } elseif ($exitCode -eq 1) {
            Write-Host "RESULT: TEST FAILURES (but no crash)" -ForegroundColor Yellow
            return @{ Success = $true; ExitCode = $exitCode; Duration = $duration; Output = $stdout; HasFailures = $true }
        } else {
            Write-Host "RESULT: CRASHED or ERROR (Exit: $exitCode)" -ForegroundColor Red
            if ($stderr) {
                Write-Host "STDERR: $stderr" -ForegroundColor Red
            }
            return @{ Success = $false; ExitCode = $exitCode; Duration = $duration; Output = $stdout; Error = $stderr }
        }
    }
    catch {
        Write-Host "RESULT: EXCEPTION - $_" -ForegroundColor Red
        return @{ Success = $false; Exception = $_.Exception.Message }
    }
}

$results = @()

# Phase 1: Small test (3-5 tests)
if (-not $SkipPhase1 -and -not $FullOnly) {
    Write-Host ""
    Write-Host "PHASE 1: Small Test (Sanity Check)" -ForegroundColor Magenta
    $result = Run-HeadlessTest -TestPath "tests/unit/test_state_victory.gd" -Description "Victory State Tests" -ExpectedTests 7 -TimeoutSec 60
    $results += @{ Phase = 1; Result = $result }

    if (-not $result.Success) {
        Write-Host ""
        Write-Host "Phase 1 FAILED - Headless mode still unstable" -ForegroundColor Red
        Write-Host "Recommendation: Continue using UI mode" -ForegroundColor Yellow
        exit 1
    }
}

# Phase 2: Medium test (13 tests - original crash threshold)
if (-not $SkipPhase2 -and -not $FullOnly) {
    Write-Host ""
    Write-Host "PHASE 2: Medium Test (Original Crash Threshold)" -ForegroundColor Magenta
    $result = Run-HeadlessTest -TestPath "tests/unit/test_character_advancement_costs.gd" -Description "Character Advancement Costs" -ExpectedTests 13 -TimeoutSec 90
    $results += @{ Phase = 2; Result = $result }

    if (-not $result.Success) {
        Write-Host ""
        Write-Host "Phase 2 FAILED - Crashes at ~13 tests (same as before)" -ForegroundColor Red
        Write-Host "Recommendation: Continue using UI mode" -ForegroundColor Yellow
        exit 1
    }
}

# Phase 3: Full unit test directory
Write-Host ""
Write-Host "PHASE 3: Full Unit Tests" -ForegroundColor Magenta
$result = Run-HeadlessTest -TestPath "tests/unit" -Description "All Unit Tests" -ExpectedTests 80 -TimeoutSec $Timeout
$results += @{ Phase = 3; Result = $result }

# Summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true
foreach ($r in $results) {
    $status = if ($r.Result.Success) { "PASS" } else { "FAIL" }
    $color = if ($r.Result.Success) { "Green" } else { "Red" }
    Write-Host "Phase $($r.Phase): $status" -ForegroundColor $color
    if (-not $r.Result.Success) { $allPassed = $false }
}

Write-Host ""
if ($allPassed) {
    Write-Host "HEADLESS MODE: WORKING" -ForegroundColor Green
    Write-Host ""
    Write-Host "GDUnit4 v6.0.3 headless mode is stable!" -ForegroundColor Green
    Write-Host "You can now use --headless for CI/CD pipelines." -ForegroundColor Green
    Write-Host ""
    Write-Host "Recommended CI command:" -ForegroundColor Yellow
    Write-Host '  godot --headless --path "$PROJECT" --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit --ignoreHeadlessMode -c' -ForegroundColor White
} else {
    Write-Host "HEADLESS MODE: UNSTABLE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Headless mode still crashes. Continue using UI mode:" -ForegroundColor Yellow
    Write-Host '  godot --path "$PROJECT" --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit --quit-after 120' -ForegroundColor White
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
