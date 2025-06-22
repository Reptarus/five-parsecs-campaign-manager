@echo off
REM Five Parsecs Campaign Manager - Comprehensive Warning Fix Runner
REM Runs the Python comprehensive warning fixer with error handling

setlocal enabledelayedexpansion

echo ========================================
echo Five Parsecs Campaign Manager
echo Comprehensive Warning Fixer
echo ========================================
echo.

REM Set project root to current directory
set PROJECT_ROOT=%~dp0..
set PYTHON_SCRIPT=%~dp0comprehensive_warning_fixer.py
set LOG_FILE=%~dp0comprehensive_warning_fix_log_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt

REM Clean up log filename (remove spaces and colons)
set LOG_FILE=%LOG_FILE: =0%
set LOG_FILE=%LOG_FILE::=%

echo Project Root: %PROJECT_ROOT%
echo Python Script: %PYTHON_SCRIPT%
echo Log File: %LOG_FILE%
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ and try again
    pause
    exit /b 1
)

REM Check if the Python script exists
if not exist "%PYTHON_SCRIPT%" (
    echo ERROR: Python script not found at %PYTHON_SCRIPT%
    pause
    exit /b 1
)

REM Create backup directory
set BACKUP_DIR=%PROJECT_ROOT%\backups\warning_fixes_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set BACKUP_DIR=%BACKUP_DIR: =0%
set BACKUP_DIR=%BACKUP_DIR::=%

echo Creating backup directory: %BACKUP_DIR%
mkdir "%BACKUP_DIR%" >nul 2>&1

REM Create backup of important files
echo Creating backups of key files...
robocopy "%PROJECT_ROOT%\src" "%BACKUP_DIR%\src" *.gd /S /NP /NDL /NFL >nul 2>&1
robocopy "%PROJECT_ROOT%\tests" "%BACKUP_DIR%\tests" *.gd /S /NP /NDL /NFL >nul 2>&1

echo ========================================
echo Starting Comprehensive Warning Fix
echo ========================================
echo.

REM Change to project root directory
cd /d "%PROJECT_ROOT%"

REM Run the Python script and capture output
echo Running warning fixer...
python "%PYTHON_SCRIPT%" > "%LOG_FILE%" 2>&1

set SCRIPT_EXIT_CODE=%errorlevel%

REM Display the log file content to console
echo.
echo ========================================
echo SCRIPT OUTPUT:
echo ========================================
type "%LOG_FILE%"

echo.
echo ========================================
echo Warning Fix Complete
echo ========================================

if %SCRIPT_EXIT_CODE% equ 0 (
    echo ✅ SUCCESS: Warning fixing completed successfully
    echo.
    echo 📊 Results Summary:
    echo    - Log file: %LOG_FILE%
    echo    - Backup created: %BACKUP_DIR%
    echo.
    echo 🎯 Next Steps:
    echo    1. Open Godot and check for compilation errors
    echo    2. Run your test suite to verify functionality
    echo    3. Review the log file for details
    echo.
    echo Press any key to open the log file...
    pause >nul
    start notepad "%LOG_FILE%"
) else (
    echo ❌ ERROR: Warning fixing failed with exit code %SCRIPT_EXIT_CODE%
    echo.
    echo 🔍 Troubleshooting:
    echo    - Check the log file: %LOG_FILE%
    echo    - Restore from backup if needed: %BACKUP_DIR%
    echo    - Verify Python dependencies are installed
    echo.
    echo Press any key to open the log file...
    pause >nul
    start notepad "%LOG_FILE%"
)

echo.
echo Press any key to exit...
pause >nul 