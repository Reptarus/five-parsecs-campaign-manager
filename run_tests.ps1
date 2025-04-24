#!/usr/bin/env pwsh
# PowerShell script to run tests without relying on the GUT panel
# Usage:
#   ./run_tests.ps1                  # Run all tests
#   ./run_tests.ps1 test_file.gd     # Run specific test file
#   ./run_tests.ps1 test_file.gd test_func # Run specific test function

param (
    [string]$testFile = "",
    [string]$testFunc = ""
)

# Get Godot executable path
$godotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64.exe"
if (-not (Test-Path $godotPath)) {
    # Try finding Godot in common locations
    $potentialPaths = @(
        "C:\Program Files\Godot\Godot_v4.4-stable_mono_win64.exe",
        "C:\Program Files (x86)\Godot\Godot_v4.4-stable_mono_win64.exe",
        "$env:USERPROFILE\Desktop\Godot_v4.4-stable_mono_win64.exe"
    )
    
    foreach ($path in $potentialPaths) {
        if (Test-Path $path) {
            $godotPath = $path
            break
        }
    }
}

if (-not (Test-Path $godotPath)) {
    Write-Error "Could not find Godot executable. Please update the script with the correct path."
    exit 1
}

# Set up arguments based on parameters
$arguments = @(
    "--path",
    "$PWD",
    "--script",
    "res://tests/run_cli.gd"
)

if ($testFile -ne "") {
    # Add full path to test file if it doesn't already have it
    if (-not $testFile.StartsWith("res://")) {
        if (-not $testFile.EndsWith(".gd")) {
            $testFile = "$testFile.gd"
        }
        $testFile = "res://tests/unit/$testFile"
    }
    
    $arguments += "--test-file"
    $arguments += $testFile
    
    if ($testFunc -ne "") {
        $arguments += "--test-func"
        $arguments += $testFunc
    }
}

# Run tests
Write-Host "Running tests with Godot at: $godotPath"
Write-Host "Arguments: $arguments"
& $godotPath $arguments

exit $LASTEXITCODE 