@echo off
echo Running Five Parsecs Campaign Manager compatibility tests...
echo This will test Godot 4.4+ compatibility for property_exists

REM Find Godot executable
SET GODOT_PATH="C:\Program Files\Godot\Godot_v4.4-beta1_win64.exe"
IF NOT EXIST %GODOT_PATH% (
    SET GODOT_PATH="godot"
)

echo Using Godot at: %GODOT_PATH%
echo.

REM Run the compatibility tests script
%GODOT_PATH% --headless --script tests/compatibility_tests.gd

IF %ERRORLEVEL% NEQ 0 (
    echo Tests failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
) ELSE (
    echo All tests completed successfully!
    exit /b 0
) 