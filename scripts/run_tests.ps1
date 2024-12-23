# Run tests script for Five Parsecs Campaign Manager
[CmdletBinding()]
param(
    [string]$TestPath = "res://src/tests/unit",
    [switch]$Verbose
)

# Ensure we stop on errors
$ErrorActionPreference = "Stop"

# Get the script directory and project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath

# Load our profile
$profilePath = Join-Path $scriptPath "profile.ps1"
if (-not (Test-Path $profilePath)) {
    Write-Error "Profile script not found at: $profilePath"
    exit 1
}

# Import the profile as a module
$env:PSModulePath = $scriptPath + ";" + $env:PSModulePath
Import-Module $profilePath -Force

# Change to project root
Set-Location $projectRoot

try {
    Write-Host "Running tests in: $TestPath" -ForegroundColor Cyan
    Write-Host "Using Godot at: $env:GODOT_PATH" -ForegroundColor Gray
    
    # Run the tests using our profile function
    Invoke-GodotTests -TestPath $TestPath -Verbose:$Verbose
}
catch {
    Write-Error "Error running tests: $_"
    exit 1
} 