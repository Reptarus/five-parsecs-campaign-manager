#!/bin/bash
# Script to organize UI files in the Five Parsecs Campaign Manager

# Ensure the script is run from the project root
if [ ! -d "src/ui" ]; then
  echo "Error: This script must be run from the project root directory."
  exit 1
fi

# Create necessary directories if they don't exist
mkdir -p src/ui/screens/character
mkdir -p src/ui/screens/campaign/setup
mkdir -p src/ui/screens/tutorial
mkdir -p src/ui/screens/connections

# Move files to their proper locations
echo "Moving UI files to their proper locations..."

# Character-related files
if [ -f "src/ui/CharacterBox.tscn" ]; then
  echo "Moving CharacterBox.tscn to screens/character/"
  cp src/ui/CharacterBox.tscn src/ui/screens/character/
  # Don't remove the original yet, wait for user verification
fi

if [ -f "src/ui/CharacterCreator.tscn" ]; then
  echo "Moving CharacterCreator.tscn to screens/character/"
  cp src/ui/CharacterCreator.tscn src/ui/screens/character/
fi

if [ -f "src/ui/CharacterSheet.tscn" ]; then
  echo "Moving CharacterSheet.tscn to screens/character/"
  cp src/ui/CharacterSheet.tscn src/ui/screens/character/
fi

if [ -f "src/ui/CharacterProgression.tscn" ]; then
  echo "Moving CharacterProgression.tscn to screens/character/"
  cp src/ui/CharacterProgression.tscn src/ui/screens/character/
fi

# Campaign-related files
if [ -f "src/ui/CampaignDashboard.tscn" ]; then
  echo "Moving CampaignDashboard.tscn to screens/campaign/"
  cp src/ui/CampaignDashboard.tscn src/ui/screens/campaign/
fi

if [ -f "src/ui/VictoryConditionSelection.tscn" ]; then
  echo "Moving VictoryConditionSelection.tscn to screens/campaign/setup/"
  cp src/ui/VictoryConditionSelection.tscn src/ui/screens/campaign/setup/
fi

# Tutorial-related files
if [ -f "src/ui/TutorialSelection.tscn" ]; then
  echo "Moving TutorialSelection.tscn to screens/tutorial/"
  cp src/ui/TutorialSelection.tscn src/ui/screens/tutorial/
fi

if [ -f "src/ui/NewCampaignTutorial.tscn" ]; then
  echo "Moving NewCampaignTutorial.tscn to screens/tutorial/"
  cp src/ui/NewCampaignTutorial.tscn src/ui/screens/tutorial/
fi

# Other files
if [ -f "src/ui/ConnectionsCreation.tscn" ]; then
  echo "Moving ConnectionsCreation.tscn to screens/connections/"
  cp src/ui/ConnectionsCreation.tscn src/ui/screens/connections/
fi

# Create README files for new directories
cat > src/ui/screens/character/README.md << EOF
# Character UI Screens

This directory contains UI screens for character creation, management, and progression in the Five Parsecs Campaign Manager.

## Components

- \`CharacterBox.tscn\` - Character information display component
- \`CharacterCreator.tscn\` - Character creation screen
- \`CharacterSheet.tscn\` - Character stats and details screen
- \`CharacterProgression.tscn\` - Character advancement and progression screen

## Integration

These screens are used throughout the campaign flow for character management.
EOF

cat > src/ui/screens/tutorial/README.md << EOF
# Tutorial Screens

This directory contains tutorial-related screens for the Five Parsecs Campaign Manager.

## Components

- \`TutorialSelection.tscn\` - Tutorial selection screen
- \`NewCampaignTutorial.tscn\` - New campaign tutorial screen

## Integration

These screens are used to introduce new players to the game mechanics.
EOF

cat > src/ui/screens/connections/README.md << EOF
# Connections Screens

This directory contains screens for managing connections and relationships in the Five Parsecs Campaign Manager.

## Components

- \`ConnectionsCreation.tscn\` - Interface for creating and managing character connections

## Integration

These screens are used during character creation and campaign progression to manage the relationships between characters and NPCs.
EOF

echo "Organization complete. Please verify the copied files work correctly before removing the originals."
echo "After verification, you can remove the original files from src/ui/ root directory." 