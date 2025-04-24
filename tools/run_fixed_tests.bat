@echo off
echo Running fixed Five Parsecs tests...
echo.

:: Path to Godot executable - update this to match your installation
set GODOT_PATH="c:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64.exe"

:: Run tests with fixed test script selection
%GODOT_PATH% --path "%~dp0.." -d -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_simple_fix.gd -gtest=res://tests/unit/test_test_runner.gd -glog=3

echo.
echo Test run complete.
pause 