@echo off
echo Running all tests...
"c:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64.exe" --headless --path "%~dp0" --script res://addons/gut/gut_cmdln.gd -- --dirs=res://tests/unit,res://tests/integration --include-subdirs --unit-test-name=""
echo.
echo Test run complete with exit code %ERRORLEVEL%
exit /b %ERRORLEVEL% 