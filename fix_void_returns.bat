@echo off
REM Safe GDScript Void Function Fixer - Windows Batch Wrapper
REM Usage: fix_void_returns.bat <file_path> [--safe-only] [--auto]

if "%1"=="" (
    echo Usage: fix_void_returns.bat ^<file_path^> [--safe-only] [--auto]
    echo.
    echo Examples:
    echo   fix_void_returns.bat src/ui/components/MyScript.gd
    echo   fix_void_returns.bat src/core/managers/EventManager.gd --safe-only
    echo   fix_void_returns.bat src/scenes/main/MainGameScene.gd --auto
    echo.
    echo Options:
    echo   --safe-only  : Only apply changes marked as SAFE
    echo   --auto       : Apply changes without confirmation
    pause
    exit /b 1
)

python fix_void_returns.py %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Script completed with errors.
    pause
) else (
    echo.
    echo Script completed successfully.
) 