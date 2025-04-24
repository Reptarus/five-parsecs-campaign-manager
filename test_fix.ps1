#!/usr/bin/env pwsh
# PowerShell script to run tests with proper GUT parameters

# Define the Godot executable location
$godotPath = "C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64.exe"

Write-Host "Executing tests with GUT..."
Write-Host "------------------------"

# Run all unit tests 
& $godotPath -s "res://addons/gut/gut_cmdln.gd" -gdir="res://tests/unit" -gexit=false -glog=2 -gignore_pause -gselect="test_simple.gd"

Write-Host "------------------------"
Write-Host "Test execution complete." 