# Combat System Reorganization Plan

## Current Issues
- Duplicate files exist in both `/src/game/combat` and `/src/core/battle`
- The project structure should follow the pattern defined in the README:
  - Base classes in `/src/base`
  - Game-specific implementations in `/src/game`
  - The `/core` directory isn't mentioned in the README and appears to be redundant

## Reorganization Strategy

### 1. Base Classes
Move abstract/base functionality to `/src/base/combat`:

- `src/base/combat/BaseBattleCharacter.gd` - Base class for battle characters
- `src/base/combat/BaseBattleData.gd` - Base class for battle data
- `src/base/combat/BaseCombatResolver.gd` - Base class for combat resolution
- `src/base/combat/BaseCombatManager.gd` - Base class for combat management
- `src/base/combat/BaseBattleRules.gd` - Base class for battle rules

Subdirectories:
- `src/base/combat/battlefield/` - Base classes for battlefield generation and management
- `src/base/combat/enemy/` - Base classes for enemy AI and scaling
- `src/base/combat/state/` - Base classes for battle state management
- `src/base/combat/events/` - Base classes for battle events

### 2. Game-Specific Implementations
Keep game-specific implementations in `/src/game/combat`:

- `src/game/combat/BattleCharacter.gd` - Five Parsecs implementation of battle characters
- `src/game/combat/BattleData.gd` - Five Parsecs implementation of battle data
- `src/game/combat/CombatResolver.gd` - Five Parsecs implementation of combat resolution
- `src/game/combat/CombatManager.gd` - Five Parsecs implementation of combat management
- `src/game/combat/BattleRules.gd` - Five Parsecs implementation of battle rules
- `src/game/combat/BattlefieldGenerator.gd` - Five Parsecs implementation of battlefield generation
- `src/game/combat/BattlefieldManager.gd` - Five Parsecs implementation of battlefield management
- `src/game/combat/EnemyScalingSystem.gd` - Five Parsecs implementation of enemy scaling
- `src/game/combat/EnemyTacticalAI.gd` - Five Parsecs implementation of enemy AI
- `src/game/combat/MainBattleController.gd` - Five Parsecs implementation of battle controller

### 3. Remove Redundant Files
Delete the redundant files in `/src/core/battle` after ensuring all functionality is preserved in the new structure.

## Implementation Steps

1. Create base classes in `/src/base/combat` with abstract functionality
2. Update game-specific implementations in `/src/game/combat` to extend the base classes
3. Ensure all references are updated throughout the codebase
4. Delete the redundant `/src/core/battle` directory

## Testing Strategy

1. Run unit tests after each major change
2. Perform manual testing of the combat system
3. Verify that all functionality works as expected
4. Document any issues encountered during the reorganization 