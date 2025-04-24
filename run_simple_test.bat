@echo off
echo Running simple test...
"c:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64.exe" -s res://addons/gut/gut_cmdln.gd -gdir="res://tests/unit" -d
echo Test run complete with exit code %ERRORLEVEL% 