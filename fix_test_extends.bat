@echo off
echo Running Test Extends Fix Script...
powershell -ExecutionPolicy Bypass -File "%~dp0fix_test_extends.ps1"
echo.
echo Script execution completed.
pause 