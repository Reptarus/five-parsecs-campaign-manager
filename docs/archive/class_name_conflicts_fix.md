# Class Name Conflicts Fix Guide

This document provides specific instructions for fixing each of the class name conflicts identified in the Five Parsecs Campaign Manager codebase.

## High-Priority Fixes

### 1. Fix `FiveParsecsStrangeCharacters`

**Conflicting Files:**
- `src/game/campaign/crew/FiveParsecsStrangeCharacters.gd` (non-authoritative)
- `src/core/character/FiveParsecsStrangeCharacters.gd` (authoritative)

**Fix Instructions:**
1. Edit `src/game/campaign/crew/FiveParsecsStrangeCharacters.gd`:
   - Remove `class_name FiveParsecsStrangeCharacters`
   - Add comment explaining the authoritative location
   - Add explicit preload for `BaseStrangeCharacters`

```gdscript
# REMOVED: class_name FiveParsecsStrangeCharacters
# The authoritative FiveParsecsStrangeCharacters is in src/core/character/FiveParsecsStrangeCharacters.gd
# Use explicit preload to reference this class: preload("res://src/game/campaign/crew/FiveParsecsStrangeCharacters.gd")
extends Node

const BaseStrangeCharacters = preload("res://src/core/character/BaseStrangeCharacters.gd")
```

### 2. Fix `FiveParsecsPostBattlePhase`

**Conflicting Files:**
- `src/game/campaign/FiveParsecsPostBattlePhase.gd` (non-authoritative)
- `src/core/campaign/FiveParsecsPostBattlePhase.gd` (authoritative)

**Fix Instructions:**
1. Edit `src/game/campaign/FiveParsecsPostBattlePhase.gd`:
   - Remove `class_name FiveParsecsPostBattlePhase`
   - Add comment explaining the authoritative location
   - Add explicit preload for `BasePostBattlePhase`

```gdscript
# REMOVED: class_name FiveParsecsPostBattlePhase
# The authoritative FiveParsecsPostBattlePhase is in src/core/campaign/FiveParsecsPostBattlePhase.gd
# Use explicit preload to reference this class: preload("res://src/game/campaign/FiveParsecsPostBattlePhase.gd")
extends Node

const BasePostBattlePhase = preload("res://src/core/campaign/BasePostBattlePhase.gd")
```

### 3. Fix `FiveParsecsCharacterStats`

**Conflicting Files:**
- `src/game/character/CharacterStats.gd` (non-authoritative)
- `src/core/character/FiveParsecsCharacterStats.gd` (authoritative)

**Fix Instructions:**
1. Edit `src/game/character/CharacterStats.gd`:
   - Remove `class_name FiveParsecsCharacterStats`
   - Add comment explaining the authoritative location

```gdscript
# REMOVED: class_name FiveParsecsCharacterStats
# The authoritative FiveParsecsCharacterStats is in src/core/character/FiveParsecsCharacterStats.gd
# Use explicit preload to reference this class: preload("res://src/game/character/CharacterStats.gd")
extends "res://src/core/character/Base/CharacterStats.gd"
```

### 4. Fix `CampaignSetupScreen`

**Conflicting Files:**
- `src/ui/screens/campaign/CampaignSetupScreen.gd` (non-authoritative)
- `src/ui/core/CampaignSetupScreen.gd` (authoritative)

**Fix Instructions:**
1. Edit `src/ui/screens/campaign/CampaignSetupScreen.gd`:
   - Remove `class_name CampaignSetupScreen`
   - Add comment explaining the authoritative location

```gdscript
# REMOVED: class_name CampaignSetupScreen
# The authoritative CampaignSetupScreen is in src/ui/core/CampaignSetupScreen.gd
# Use explicit preload to reference this class: preload("res://src/ui/screens/campaign/CampaignSetupScreen.gd")
extends Control
```

## Test Fixture Fixes

### 1. Fix `GameStateTestAdapter`

**Conflicting Files:**
- `tests/fixtures/helpers/game_state_test_adapter.gd` (non-authoritative)
- `tests/fixtures/base/game_state_test_adapter.gd` (authoritative)

**Fix Instructions:**
1. Edit `tests/fixtures/helpers/game_state_test_adapter.gd`:
   - Remove `class_name GameStateTestAdapter`
   - Add comment explaining the authoritative location

```gdscript
# REMOVED: class_name GameStateTestAdapter
# The authoritative GameStateTestAdapter is in tests/fixtures/base/game_state_test_adapter.gd
# Use explicit preload to reference this class: preload("res://tests/fixtures/helpers/game_state_test_adapter.gd")
extends RefCounted
```

### 2. Fix `TestGameStateAdapter`

**Conflicting Files:**
- `tests/unit/core/test_game_state_adapter.gd` (non-authoritative)
- `tests/fixtures/helpers/test_game_state_adapter.gd` (authoritative)

**Fix Instructions:**
1. Edit `tests/unit/core/test_game_state_adapter.gd`:
   - Remove `class_name TestGameStateAdapter`
   - Add comment explaining the authoritative location

```gdscript
# REMOVED: class_name TestGameStateAdapter
# The authoritative TestGameStateAdapter is in tests/fixtures/helpers/test_game_state_adapter.gd
# Use explicit preload to reference this class: preload("res://tests/unit/core/test_game_state_adapter.gd")
extends GameTest
```

### 3. Fix `CampaignTest`

**Conflicting Files:**
- `tests/fixtures/specialized/campaign_test.gd` (non-authoritative)
- `tests/fixtures/base/campaign_test.gd` (authoritative)

**Fix Instructions:**
1. Edit `tests/fixtures/specialized/campaign_test.gd`:
   - Remove `class_name CampaignTest`
   - Add comment explaining the authoritative location

```gdscript
# REMOVED: class_name CampaignTest
# The authoritative CampaignTest is in tests/fixtures/base/campaign_test.gd
# Use explicit preload to reference this class: preload("res://tests/fixtures/specialized/campaign_test.gd")
extends "res://tests/fixtures/base/game_test.gd"
```

## Method Reference Fixes

### 1. Fix `StoryQuestData.create_mission`

**Affected Files:**
- `src/core/managers/CampaignManager.gd`

**Fix Instructions:**
1. Add preload for StoryQuestData:
```gdscript
const StoryQuestDataScript = preload("res://src/core/mission/StoryQuestData.gd")
```

2. Replace all instances of `StoryQuestData.create_mission` with `StoryQuestDataScript.create_mission`

### 2. Fix `GamePlanet.deserialize`

**Affected Files:**
- `src/core/managers/SectorManager.gd`

**Fix Instructions:**
1. Add preload for GamePlanet if not already present:
```gdscript
const GamePlanetScript = preload("res://src/game/world/GamePlanet.gd")
```

2. Replace all instances of `GamePlanet.deserialize` with `GamePlanetScript.deserialize`

## Inner Class Reference Fixes

These files have already been fixed with factory methods but are included here for completeness.

### 1. `ValidationResult` in `StateValidator.gd`
- Added factory method `create_result()` to instantiate `ValidationResult` objects

### 2. `PathNode` in `PathFinder.gd`
- Added factory method `create_path_node()` to instantiate `PathNode` objects

## Testing Your Fixes

After applying these fixes:

1. Clear your Godot project cache:
   - Close Godot
   - Delete the `.godot` folder in your project directory
   - Reopen the project in Godot

2. Run the project and verify that it compiles without errors.

3. Run the `tools/fix_class_name_conflicts.gd` script again to verify no further conflicts exist.

4. If you encounter remaining linter errors related to malformed paths, they may be harmless as long as the code runs correctly. 