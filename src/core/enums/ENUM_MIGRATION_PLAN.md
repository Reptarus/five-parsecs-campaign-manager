# Comprehensive Enum Migration Plan

## Overview

This document outlines a complete plan for migrating all enum definitions from the old `GlobalEnums.gd` to the new centralized `GameEnums.gd` file. This approach will resolve the ongoing issues with duplicate enum definitions and missing references.

## Current Status

- **GlobalEnums.gd** (old): Located at `res://src/core/systems/GlobalEnums.gd`
  - Extends `Node`
  - Contains many enum definitions plus utility functions
  - Used throughout the codebase

- **GameEnums.gd** (new): Located at `res://src/core/enums/GameEnums.gd`
  - Extends `RefCounted` with `class_name GameEnums`
  - Contains some, but not all, of the enums from GlobalEnums
  - Gradually being adopted across the codebase

## Migration Steps

### 1. Complete Enum Migration

First, we need to ensure all enum definitions from GlobalEnums are included in GameEnums.gd:

| Enum Name | Status | Notes |
|-----------|--------|-------|
| DifficultyLevel | ✅ Migrated | |
| FiveParcsecsCampaignPhase | ✅ Migrated | |
| CampaignSubPhase | ❌ Missing | |
| ArmorCharacteristic | ❌ Missing | |
| CharacterClass | ✅ Migrated | |
| Training | ✅ Migrated | |
| Origin | ✅ Migrated | |
| Background | ✅ Migrated | |
| Motivation | ✅ Migrated | |
| ResourceType | ✅ Migrated | |
| FiveParcsecsCampaignType | ❌ Missing | |
| FiveParcsecsCampaignVictoryType | ❌ Missing | |
| MarketState | ❌ Missing | |
| MissionObjective | ✅ Migrated | |
| WeatherType | ❌ Missing | |
| MissionType | ✅ Migrated | |
| WeaponType | ✅ Migrated | |
| AIBehavior | ❌ Missing | |
| PlanetType | ❌ Missing | |
| ThreatType | ❌ Missing | |
| RelationType | ❌ Missing | |
| ShipCondition | ❌ Missing | |
| VictoryConditionType | ❌ Missing | |
| EnemyRank | ❌ Missing | |
| EnemyTrait | ❌ Missing | |
| LocationType | ❌ Missing | |
| ArmorClass | ❌ Missing | |
| EnemyCategory | ❌ Missing | |
| EnemyBehavior | ❌ Missing | |
| EnemyType | ❌ Missing | |
| ItemType | ✅ Migrated | |
| ItemRarity | ✅ Migrated | |
| GlobalEvent | ❌ Missing | |
| QuestType | ❌ Missing | |
| QuestStatus | ❌ Missing | |
| BattleType | ❌ Missing | |
| MissionVictoryType | ❌ Missing | |
| WorldTrait | ✅ Migrated | |
| PlanetEnvironment | ❌ Missing | |
| StrifeType | ❌ Missing | |
| DeploymentType | ❌ Missing | |
| EnemyDeploymentPattern | ❌ Missing | |
| EnemyWeaponClass | ❌ Missing | |
| ArmorType | ✅ Migrated | |
| CampaignPhase | ❌ Missing | |
| CombatModifier | ❌ Missing | |
| CombatPhase | ❌ Missing | |
| TerrainFeatureType | ❌ Missing | |
| BattleState | ❌ Missing | |
| BattlePhase | ❌ Missing | |
| UnitAction | ❌ Missing | |
| CombatAdvantage | ❌ Missing | |
| CombatStatus | ❌ Missing | |
| CombatTactic | ❌ Missing | |
| CombatResult | ❌ Missing | |
| TerrainModifier | ❌ Missing | |
| TerrainEffectType | ❌ Missing | |
| VerificationType | ❌ Missing | |
| VerificationScope | ❌ Missing | |
| VerificationResult | ❌ Missing | |
| EventCategory | ❌ Missing | |
| CombatRange | ❌ Missing | |
| CrewTask | ❌ Missing | |
| JobType | ❌ Missing | |
| StrangeCharacterType | ❌ Missing | |
| EnemyCharacteristic | ❌ Missing | |
| GameState | ✅ Migrated | |
| Skill | ❌ Missing | |
| Ability | ❌ Missing | |
| Trait | ❌ Missing | |
| CharacterStatus | ✅ Migrated | |
| VerificationStatus | ❌ Missing | |
| CrewSize | ❌ Missing | |
| ShipComponentType | ❌ Missing | |
| CharacterStats | ❌ Missing | |
| FactionType | ❌ Missing | |
| EditMode | ❌ Missing | |
| EquipmentType | ✅ Migrated | |

### 2. Migrate Constants and Helper Functions

Several constant mappings and helper functions need to be migrated:

| Constant/Function | Status | Notes |
|-------------------|--------|-------|
| PHASE_NAMES | ❌ Missing | Maps FiveParcsecsCampaignPhase to display names |
| PHASE_DESCRIPTIONS | ❌ Missing | Maps phases to descriptions |
| TRAINING_NAMES | ❌ Missing | Maps Training enum to display names |
| get_training_name() | ❌ Missing | Helper function for training names |
| BATTLE_STATE_NAMES | ❌ Missing | Maps BattleState to display names |
| COMBAT_PHASE_NAMES | ❌ Missing | Maps CombatPhase to display names |
| get_character_class_name() | ❌ Missing | Helper for character classes |
| get_skill_name() | ❌ Missing | Helper for skill names |
| get_ability_name() | ❌ Missing | Helper for ability names |
| get_trait_name() | ❌ Missing | Helper for trait names |
| get_enum_string() | ✅ Migrated | General helper for enum values |
| size() | ✅ Migrated | Gets the size of an enum |
| get_equipment_type_from_string() | ✅ Migrated | Converts string to equipment type |

### 3. Codebase Update Strategy

After completing the enum migration, we'll need to update all references throughout the codebase:

1. **Global Search & Replace**:
   ```
   const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
   ```
   Replace with:
   ```
   const GameEnums = preload("res://src/core/enums/GameEnums.gd")
   ```

2. **Update Script Tests**:
   - Update all test files that create mock enums to use the central GameEnums instead
   - Fix any test cases that rely on the old GlobalEnums structure

3. **Fix Type Mismatches**:
   - Update any code that passes enum values between functions to ensure type compatibility
   - Ensure signal parameters are properly typed

4. **Update Documentation**:
   - Update any code comments that reference the old enum system
   - Add explanatory comments where needed to clarify the migration

### 4. Implementation Plan

1. **Phase 1: Complete GameEnums.gd**
   - Add all missing enums to GameEnums.gd
   - Add all missing constants and helper functions
   - Add proper documentation for all enums

2. **Phase 2: Core Systems Migration**
   - Update the most central/critical files to use the new GameEnums
   - Focus on managers, state systems, and core gameplay files

3. **Phase 3: UI and Peripheral Systems**
   - Update UI components
   - Update auxiliary systems

4. **Phase 4: Test Suite Update**
   - Update all test files
   - Create new tests to verify enum compatibility

5. **Phase 5: Cleanup**
   - Remove the old GlobalEnums.gd file when all references have been migrated
   - Add deprecation warnings to GlobalEnums.gd during transition

### 5. Testing Strategy

1. **Unit Tests**:
   - Create tests for each enum to ensure values match between old and new systems
   - Test helper functions to ensure identical behavior

2. **Integration Tests**:
   - Test core systems with the new enum implementation
   - Verify no regressions in main functionality

3. **Manual Testing**:
   - Test main gameplay flows to ensure enums work correctly in all scenarios

## Benefits of Centralized Approach

1. **Single Source of Truth**: All enum definitions in one place
2. **Improved Documentation**: Better comments and organization
3. **Type Safety**: Proper GDScript typing throughout codebase
4. **Maintainability**: Easier to update and extend
5. **Consistency**: Uniform naming and usage patterns

## Potential Challenges

1. **Backward Compatibility**: Some systems may rely on specific enum values
2. **Type Mismatches**: Careful handling of functions that take enum parameters
3. **Signal Connections**: Enums used in signals need special attention
4. **Testing Overhead**: Comprehensive testing required to ensure no regressions

## Conclusion

This migration plan provides a systematic approach to centralizing all enums in the Five Parsecs Campaign Manager. By completing this migration, we'll eliminate the recurring issues with missing enum values and type mismatches, creating a more maintainable and robust codebase. 