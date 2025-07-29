@echo off
echo ================================================================
echo Five Parsecs Campaign Manager - Syntax Fix Verification
echo ================================================================
echo.

echo [1/3] Launching Godot Console to test syntax fixes...
echo Project Path: C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager
echo.

echo Starting Godot with console output...
"C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe" --path "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager" --headless --quit-after 10

echo.
echo [2/3] Checking for remaining parse errors...
echo If you see any remaining syntax errors above, please report them.
echo.

echo [3/3] Manual verification steps:
echo - Launch Godot normally: "C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe" --path "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
echo - Check console output for any remaining parser errors
echo - Verify the main menu loads without stack traces
echo - Test campaign creation basic workflow
echo.

echo ================================================================
echo Syntax fixes applied:
echo - CampaignCreationManager.gd: Fixed orphaned 'else' and malformed function
echo - WorldPhase.gd: Replaced all data_manager references with DataManager static calls
echo - DataManager.gd: Added missing get_training_outcome() method
echo ================================================================
pause
