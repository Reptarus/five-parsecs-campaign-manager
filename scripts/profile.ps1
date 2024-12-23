# PowerShell Profile for Five Parsecs Campaign Manager
$ErrorActionPreference = 'Stop'

# Get the script directory and project root
$scriptPath = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptPath

# Set up environment variables if they don't exist
if (-not $env:GODOT_PATH) {
    $godotPath = "c:\Users\elija\Desktop\GoDot\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
    if (Test-Path $godotPath) {
        $env:GODOT_PATH = $godotPath
        Write-Host "Set GODOT_PATH to: $godotPath" -ForegroundColor Green
    } else {
        Write-Warning "Godot executable not found at expected path: $godotPath"
    }
}

# Function to run Godot tests
function Invoke-GodotTests {
    [CmdletBinding()]
    param(
        [string]$TestPath = "res://src/tests/unit",
        [switch]$Verbose
    )
    
    if (-not $env:GODOT_PATH) {
        throw "GODOT_PATH environment variable is not set"
    }
    
    if (-not (Test-Path $env:GODOT_PATH)) {
        throw "Godot executable not found at: $env:GODOT_PATH"
    }
    
    Write-Host "Running tests from: $TestPath" -ForegroundColor Cyan
    
    $godotArgs = @(
        "--headless",
        "--script",
        "res://src/tests/run_tests.gd"
    )
    
    if ($Verbose) {
        $godotArgs += "--verbose"
    }
    
    try {
        & $env:GODOT_PATH $godotArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Tests failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "Error running tests: $_"
        throw
    }
}

# Export the function
Export-ModuleMember -Function Invoke-GodotTests

# Create an alias only if it doesn't exist
if (-not (Get-Alias -Name 'test' -ErrorAction SilentlyContinue)) {
    New-Alias -Name 'test' -Value 'Invoke-GodotTests' -Description 'Run Godot tests' -Force
    Export-ModuleMember -Alias 'test'
}

# Set location to project root if we're not already there
if ($PWD.Path -ne $projectRoot) {
    Set-Location $projectRoot
}

# Welcome message
Write-Host "Five Parsecs Campaign Manager Development Environment" -ForegroundColor Cyan
Write-Host "Current location: $PWD" -ForegroundColor Gray
Write-Host "Godot Path: $env:GODOT_PATH" -ForegroundColor Gray
Write-Host "Type 'Invoke-GodotTests' or 'test' to run the test suite" -ForegroundColor Gray