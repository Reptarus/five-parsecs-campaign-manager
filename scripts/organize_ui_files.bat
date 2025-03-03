@echo off
REM Script to organize UI files in the Five Parsecs Campaign Manager

REM Ensure the script is run from the project root
if not exist "src\ui" (
  echo Error: This script must be run from the project root directory.
  exit /b 1
)

REM Create necessary directories if they don't exist
mkdir src\ui\screens\character 2>nul
mkdir src\ui\screens\campaign\setup 2>nul
mkdir src\ui\screens\tutorial 2>nul
mkdir src\ui\screens\connections 2>nul

REM Move files to their proper locations
echo Moving UI files to their proper locations...

REM Character-related files
if exist "src\ui\CharacterBox.tscn" (
  echo Moving CharacterBox.tscn to screens\character\
  copy "src\ui\CharacterBox.tscn" "src\ui\screens\character\" >nul
  REM Don't remove the original yet, wait for user verification
)

if exist "src\ui\CharacterCreator.tscn" (
  echo Moving CharacterCreator.tscn to screens\character\
  copy "src\ui\CharacterCreator.tscn" "src\ui\screens\character\" >nul
)

if exist "src\ui\CharacterSheet.tscn" (
  echo Moving CharacterSheet.tscn to screens\character\
  copy "src\ui\CharacterSheet.tscn" "src\ui\screens\character\" >nul
)

if exist "src\ui\CharacterProgression.tscn" (
  echo Moving CharacterProgression.tscn to screens\character\
  copy "src\ui\CharacterProgression.tscn" "src\ui\screens\character\" >nul
)

REM Campaign-related files
if exist "src\ui\CampaignDashboard.tscn" (
  echo Moving CampaignDashboard.tscn to screens\campaign\
  copy "src\ui\CampaignDashboard.tscn" "src\ui\screens\campaign\" >nul
)

if exist "src\ui\VictoryConditionSelection.tscn" (
  echo Moving VictoryConditionSelection.tscn to screens\campaign\setup\
  copy "src\ui\VictoryConditionSelection.tscn" "src\ui\screens\campaign\setup\" >nul
)

REM Tutorial-related files
if exist "src\ui\TutorialSelection.tscn" (
  echo Moving TutorialSelection.tscn to screens\tutorial\
  copy "src\ui\TutorialSelection.tscn" "src\ui\screens\tutorial\" >nul
)

if exist "src\ui\NewCampaignTutorial.tscn" (
  echo Moving NewCampaignTutorial.tscn to screens\tutorial\
  copy "src\ui\NewCampaignTutorial.tscn" "src\ui\screens\tutorial\" >nul
)

REM Other files
if exist "src\ui\ConnectionsCreation.tscn" (
  echo Moving ConnectionsCreation.tscn to screens\connections\
  copy "src\ui\ConnectionsCreation.tscn" "src\ui\screens\connections\" >nul
)

REM Create README files for new directories
echo Creating README files for new directories...

(
echo # Character UI Screens
echo.
echo This directory contains UI screens for character creation, management, and progression in the Five Parsecs Campaign Manager.
echo.
echo ## Components
echo.
echo - `CharacterBox.tscn` - Character information display component
echo - `CharacterCreator.tscn` - Character creation screen
echo - `CharacterSheet.tscn` - Character stats and details screen
echo - `CharacterProgression.tscn` - Character advancement and progression screen
echo.
echo ## Integration
echo.
echo These screens are used throughout the campaign flow for character management.
) > "src\ui\screens\character\README.md"

(
echo # Tutorial Screens
echo.
echo This directory contains tutorial-related screens for the Five Parsecs Campaign Manager.
echo.
echo ## Components
echo.
echo - `TutorialSelection.tscn` - Tutorial selection screen
echo - `NewCampaignTutorial.tscn` - New campaign tutorial screen
echo.
echo ## Integration
echo.
echo These screens are used to introduce new players to the game mechanics.
) > "src\ui\screens\tutorial\README.md"

(
echo # Connections Screens
echo.
echo This directory contains screens for managing connections and relationships in the Five Parsecs Campaign Manager.
echo.
echo ## Components
echo.
echo - `ConnectionsCreation.tscn` - Interface for creating and managing character connections
echo.
echo ## Integration
echo.
echo These screens are used during character creation and campaign progression to manage the relationships between characters and NPCs.
) > "src\ui\screens\connections\README.md"

echo Organization complete. Please verify the copied files work correctly before removing the originals.
echo After verification, you can remove the original files from src\ui\ root directory.

REM List files that should be removed after verification
echo.
echo Files to remove after verification:
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