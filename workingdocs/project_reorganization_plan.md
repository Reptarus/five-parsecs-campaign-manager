# Five Parsecs Campaign Manager - Project Reorganization Plan

## Overview
This document outlines the plan to reorganize the Five Parsecs Campaign Manager project for better maintainability and navigation. The reorganization is estimated to take 14-18 hours total.

## Current Project Structure
```
📁 src/
   📁 core/           # Core game systems and managers
      📁 battle/      # Battle system components
         📁 state/    # Battle state management
      📁 character/   # Character-related systems
         📁 Base/     # Base character classes
         📁 Generation/ # Character generation
         📁 Management/ # Character management
      📁 managers/    # Core game managers
      📁 systems/     # Core game systems
      📁 world/       # World management
   📁 scenes/        # Main game scenes
      📁 battle/     # Battle scenes
      📁 campaign/   # Campaign scenes
      📁 menus/      # Menu scenes
   📁 ui/            # Common UI components
      📁 components/ # Reusable UI components
      📁 screens/    # Full screen UIs
      📁 hud/        # In-game overlay elements
   📁 data/          # Data containers and resources
      📁 templates/  # Template files
      📁 configs/    # Configuration files
   📁 tests/         # Test framework
      📁 unit/       # Unit tests
      📁 integration/ # Integration tests
   📁 utils/         # Utility scripts and helpers

📁 assets/
   📁 images/        # Image assets
   📁 fonts/         # Font files
   📁 sounds/        # Audio files
   📁 models/        # 3D models if any

📁 addons/          # Third-party addons
   📁 gut/          # Godot Unit Testing framework

📁 docs/            # Documentation
   📁 rules/        # Game rules documentation
   📁 api/          # Code documentation
   📁 tests/        # Test documentation
```

## Implementation Status

### Phase 1: Initial Setup ✓
1. ✓ Create new directory structure
2. ✓ Update .gitignore rules
3. ✓ Set up project settings
4. ✓ Create path mapping
5. ✓ Set up testing framework

### Phase 2: Core Migration ✓
1. Core Systems Migration
   - ✓ State management
   - ✓ Game managers
   - ✓ Core utilities
2. Game Logic Migration
   - ✓ Battle system
   - ✓ Campaign system
   - ✓ Character system
3. ✓ Update resource paths
4. ✓ Verify core systems

### Phase 3: Resource Organization (In Progress)
1. UI Resources
   - ⚠️ Scenes (In Progress)
   - ⚠️ Scripts (In Progress)
   - ⚠️ Themes (Pending)
2. Asset Organization
   - ✓ Images
   - ✓ Sounds
   - ✓ Fonts
3. ⚠️ Update references (In Progress)
4. ⚠️ Verify loading (In Progress)

### Phase 4: Testing & Documentation (In Progress)
1. System Testing
   - ✓ Core systems
   - ✓ Game logic
   - ✓ Resource loading
2. UI Testing
   - ⚠️ Screen navigation (In Progress)
   - ⚠️ Component functionality (In Progress)
   - ⚠️ Responsive layouts (Pending)
3. Game Flow Testing
   - ⚠️ Campaign progression (In Progress)
   - ✓ Battle system
   - ✓ Character management
4. ✓ Performance Testing
5. ⚠️ Documentation Updates (In Progress)

## Core Systems Structure

### Managers
- GameStateManager
- CharacterManager
- ResourceSystem
- BattleStateMachine
- CampaignManager
- WorldManager

### Battle System
- BattleStateMachine
- CombatManager
- BattlefieldManager
- InitiativeSystem

### Character System
- Character
- CharacterStats
- CharacterCreator
- CharacterManager

### Resource Management
- ResourceSystem
- AssetLoader
- DataManager

## Testing Framework

### Unit Tests
- GameStateManager tests
- CharacterManager tests
- ResourceSystem tests
- BattleStateMachine tests

### Integration Tests
- Campaign flow tests
- Battle system tests
- Character system tests
- Resource management tests

## Success Criteria
1. ✓ Clean directory structure
2. ✓ Proper system organization
3. ✓ Working test framework
4. ⚠️ Complete documentation (In Progress)
5. ✓ No broken references
6. ✓ Improved maintainability

## Post-Migration Tasks
1. ⚠️ Update API documentation
2. ✓ Clean up old files
3. ✓ Update contribution guidelines
4. ⚠️ Review and optimize performance
5. ⚠️ Update development workflows

## Notes
- All core systems have been migrated
- Test framework is operational
- Documentation updates are ongoing
- UI system needs further organization
- Performance optimization is pending
  </rewritten_file> 