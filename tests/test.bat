@echo off
REM Five Parsecs Campaign Manager Test Runner

echo Five Parsecs Campaign Manager Test Runner
echo ========================================
echo.

REM Check if Godot path is provided as argument
if "%1"=="" (
    goto :show_usage
)

set GODOT_PATH=%1
set TEST_TYPE=all
if not "%2"=="" set TEST_TYPE=%2

echo Godot path: %GODOT_PATH%
echo Test type: %TEST_TYPE%
echo.

REM Validate Godot path
if not exist "%GODOT_PATH%" (
    echo ERROR: Godot executable not found at specified path.
    exit /b 1
)

REM Ensure directories exist
if not exist "tests\reports" mkdir tests\reports
if not exist "tests\logs" mkdir tests\logs

if /I "%TEST_TYPE%"=="all" (
    echo Running all tests using GUT directly...
    "%GODOT_PATH%" -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs=true -gprefix=test_ -gsuffix=.gd -glog=3 -gexit_on_success -gjunit_xml_file=res://tests/reports/gut_tests.xml -gquit_on_failures=false
    goto :end
) else if /I "%TEST_TYPE%"=="unit" (
    echo Running unit tests only...
    "%GODOT_PATH%" -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs=true -gexit_on_success
    goto :end
) else if /I "%TEST_TYPE%"=="fix" (
    echo Fixing GUT stability issues...
    "%GODOT_PATH%" -s res://tests/fix_gut.gd
    goto :end
) else if /I "%TEST_TYPE%"=="cleanup" (
    echo Running resource cleanup...
    "%GODOT_PATH%" -s res://tests/cleanup_resources.gd
    goto :end
) else (
    echo Unknown test type: %TEST_TYPE%
    goto :show_usage
)

:show_usage
echo Usage:
echo   test.bat [godot_path] [test_type]
echo.
echo   [godot_path] - Path to Godot executable (required)
echo   [test_type]  - Type of test to run (optional):
echo                   all      - Run all tests (default)
echo                   unit     - Run only unit tests
echo                   fix      - Fix GUT stability issues
echo                   cleanup  - Run resource cleanup
echo.
echo Example:
echo   test.bat "c:\path\to\godot.exe" unit
exit /b 1

:end
echo.
echo Test run complete! 