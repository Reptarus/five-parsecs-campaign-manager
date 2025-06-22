@echo off
echo ========================================
echo Five Parsecs Campaign Manager
echo Backup Creator
echo ========================================
echo.

REM Create backup directory with timestamp
set BACKUP_DIR=..\backups\warning_fixes_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set BACKUP_DIR=%BACKUP_DIR: =0%
set BACKUP_DIR=%BACKUP_DIR::=%

echo Creating backup directory: %BACKUP_DIR%
mkdir "%BACKUP_DIR%" 2>nul

echo.
echo Backing up source files...
robocopy "..\src" "%BACKUP_DIR%\src" *.gd /S /NP /NDL /NFL
robocopy "..\tests" "%BACKUP_DIR%\tests" *.gd /S /NP /NDL /NFL

echo.
echo ========================================
echo Backup completed successfully!
echo ========================================
echo Backup location: %BACKUP_DIR%
echo.
echo You can now safely run the warning fixer.
echo.
echo Press any key to exit...
pause >nul 