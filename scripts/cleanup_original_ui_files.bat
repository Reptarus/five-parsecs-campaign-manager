@echo off
REM Script to remove original UI files after verification
REM This script should be run after verifying that the moved files work correctly

REM Ensure the script is run from the project root
if not exist "src\ui" (
  echo Error: This script must be run from the project root directory.
  exit /b 1
)

echo This script will remove the original UI files from src\ui\ that have been moved to their new locations.
echo Make sure you have verified that the moved files work correctly before proceeding.
echo.
echo Files to be removed:
echo -----------------------------------
if exist "src\ui\CharacterBox.tscn" echo src\ui\CharacterBox.tscn
if exist "src\ui\CharacterCreator.tscn" echo src\ui\CharacterCreator.tscn
if exist "src\ui\CharacterSheet.tscn" echo src\ui\CharacterSheet.tscn
if exist "src\ui\CharacterProgression.tscn" echo src\ui\CharacterProgression.tscn
if exist "src\ui\CampaignDashboard.tscn" echo src\ui\CampaignDashboard.tscn
if exist "src\ui\VictoryConditionSelection.tscn" echo src\ui\VictoryConditionSelection.tscn
if exist "src\ui\TutorialSelection.tscn" echo src\ui\TutorialSelection.tscn
if exist "src\ui\NewCampaignTutorial.tscn" echo src\ui\NewCampaignTutorial.tscn
if exist "src\ui\ConnectionsCreation.tscn" echo src\ui\ConnectionsCreation.tscn
echo.

set /p confirm=Are you sure you want to delete these files? (y/n): 

if /i "%confirm%" neq "y" (
  echo Operation cancelled.
  exit /b 0
)

echo Removing original UI files...
if exist "src\ui\CharacterBox.tscn" del "src\ui\CharacterBox.tscn"
if exist "src\ui\CharacterCreator.tscn" del "src\ui\CharacterCreator.tscn"
if exist "src\ui\CharacterSheet.tscn" del "src\ui\CharacterSheet.tscn"
if exist "src\ui\CharacterProgression.tscn" del "src\ui\CharacterProgression.tscn"
if exist "src\ui\CampaignDashboard.tscn" del "src\ui\CampaignDashboard.tscn"
if exist "src\ui\VictoryConditionSelection.tscn" del "src\ui\VictoryConditionSelection.tscn"
if exist "src\ui\TutorialSelection.tscn" del "src\ui\TutorialSelection.tscn"
if exist "src\ui\NewCampaignTutorial.tscn" del "src\ui\NewCampaignTutorial.tscn"
if exist "src\ui\ConnectionsCreation.tscn" del "src\ui\ConnectionsCreation.tscn"

echo Cleanup complete. 