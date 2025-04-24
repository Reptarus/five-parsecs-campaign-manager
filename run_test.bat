@echo off
echo Running Five Parsecs test with Godot console...
echo.

set GODOT_PATH="C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe"
set PROJECT_PATH="C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"

if "%1"=="" (
    echo Running all tests...
    %GODOT_PATH% --path %PROJECT_PATH% --script "res://tests/run_cli.gd" --verbose
) else (
    echo Running test: %1
    if "%2"=="" (
        echo Test file only...
        %GODOT_PATH% --path %PROJECT_PATH% --script "res://tests/run_cli.gd" --test-file "res://tests/unit/%1.gd" --verbose
    ) else (
        echo Test file with function: %1 - %2
        %GODOT_PATH% --path %PROJECT_PATH% --script "res://tests/run_cli.gd" --test-file "res://tests/unit/%1.gd" --test-func "%2" --verbose
    )
)

echo.
echo Test run complete!
pause 