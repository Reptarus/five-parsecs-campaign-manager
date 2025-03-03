# UI Screens

This directory contains the main application screens for the Five Parsecs Campaign Manager.

## Directory Structure

- `campaign/` - Campaign-related screens and UI components
  - `panels/` - Reusable UI panels for campaign screens
  - `phases/` - Phase-specific UI panels for campaign phases
- `battle/` - Battle and combat-related screens
- `crew/` - Crew management screens
- `mainmenu/` - Main menu and starting screens
- `mainscene/` - Core game scene structure
- `rules/` - Rules reference and display screens
- `ships/` - Ship management screens
- `travel/` - Travel phase UI components 
- `utils/` - Utility screens (save/load, etc.)
- `world/` - World-related UI components

## Base Files

- `BasePhasePanel.gd` - Base class for phase panel components
- `UIManager.gd` - Core UI management system that handles screen transitions

## Panel Organization

All new screen components should be organized in the appropriate subdirectory based on their functionality. For example:

- Campaign-specific screens go in `campaign/`
- Battle-related screens go in `battle/`
- Generic utility screens go in `utils/`

## Screen Navigation

Screen navigation is managed through the `UIManager` class. All screens should register with the UI manager to enable proper navigation between screens.

## Best Practices

- Use proper inheritance from base classes
- Follow naming conventions (PascalCase for scene files, snake_case for resources)
- Ensure responsive design for all screen components
- Document public methods and signals
- Implement proper focus management for keyboard/controller navigation 