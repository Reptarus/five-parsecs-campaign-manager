@echo off
REM Five Parsecs Campaign Manager - Warning Elimination Runner
REM Runs the Python warning elimination suite with comprehensive logging

setlocal enabledelayedexpansion

echo ========================================
echo Five Parsecs Campaign Manager
echo Warning Elimination Suite
echo ========================================
echo.

REM Set project root to current directory
set PROJECT_ROOT=%~dp0..
set PYTHON_SCRIPT=%~dp0warning_elimination_suite.py
set LOG_FILE=%PROJECT_ROOT%\tools\warning_elimination_log_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt

REM Clean up log filename (remove spaces and colons)
set LOG_FILE=%LOG_FILE: =0%
set LOG_FILE=%LOG_FILE::=%

echo Project Root: %PROJECT_ROOT%
echo Python Script: %PYTHON_SCRIPT%
echo Log File: %LOG_FILE%
echo.

REM Check if Python script exists
if not exist "%PYTHON_SCRIPT%" (
    echo ERROR: Python script not found: %PYTHON_SCRIPT%
    echo Please ensure warning_elimination_suite.py is in the tools directory.
    pause
    exit /b 1
)

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ and ensure it's in your PATH
    pause
    exit /b 1
)

echo ✅ Python found and script exists
echo.

REM Create backups directory
mkdir "%PROJECT_ROOT%\backups" 2>nul
mkdir "%PROJECT_ROOT%\backups\warning_fixes" 2>nul

echo 🚀 Starting warning elimination process...
echo This may take several minutes depending on codebase size.
echo.

REM Run the Python script with logging
echo Running: python "%PYTHON_SCRIPT%" "%PROJECT_ROOT%"
echo.

python "%PYTHON_SCRIPT%" "%PROJECT_ROOT%" 2>&1 | tee "%LOG_FILE%"
set PYTHON_EXIT_CODE=%errorlevel%

echo.
echo ========================================

if %PYTHON_EXIT_CODE% equ 0 (
    echo ✅ SUCCESS: Warning elimination completed!
    echo.
    echo 📋 Check the generated report for details:
    echo    %PROJECT_ROOT%\tools\warning_elimination_report.md
    echo.
    echo 💾 File backups are saved in:
    echo    %PROJECT_ROOT%\backups\warning_fixes\
    echo.
    echo 📄 Full log saved to:
    echo    %LOG_FILE%
) else (
    echo ❌ FAILED: Warning elimination encountered errors
    echo    Exit code: %PYTHON_EXIT_CODE%
    echo.
    echo 📄 Check the log for details:
    echo    %LOG_FILE%
)

echo.
echo ========================================
echo Processing complete!
echo.

REM Optional: Ask if user wants to view the report
set /p VIEW_REPORT="Would you like to view the elimination report now? (y/N): "
if /i "!VIEW_REPORT!"=="y" (
    if exist "%PROJECT_ROOT%\tools\warning_elimination_report.md" (
        start "" "%PROJECT_ROOT%\tools\warning_elimination_report.md"
    ) else (
        echo Report file not found.
    )
)

echo Press any key to exit...
pause >nul
exit /b %PYTHON_EXIT_CODE% 