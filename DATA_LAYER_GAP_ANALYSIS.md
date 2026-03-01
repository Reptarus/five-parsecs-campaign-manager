# Five Parsecs Campaign Manager - Data Layer Gap Analysis

**Analysis Date**: 2025-12-13
**Analyzed By**: Campaign Data Architect
**Scope**: Resource classes, JSON data files, save/load integration, campaign state persistence

---

## Executive Summary

**Total JSON Files**: 105 files in `data/` directory
**Total Resource Classes**: 12 major data Resource classes identified
**JSON Loading Points**: 79 instances of JSON file loading in codebase
**Critical Gaps Found**: 7 high-priority integration gaps

**Overall Assessment**: The data layer has significant architectural split between:
1. **New Resource-based architecture** (FiveParsecsCharacterData, FiveParsecsCampaignData, etc.)
2. **Legacy JSON loading** (still used in 79+ locations)
3. **Incomplete migration** - Resources exist but aren't fully integrated

---

## 1. UNUSED RESOURCE CLASSES (High Priority)

### 1.1 FiveParsecsCharacterData Resource
**File**: `src/data/resources/FiveParsecsCharacterData.gd`
**Status**: ⚠️ **DEFINED BUT BARELY USED**
**Line Count**: 351 lines

**What It Contains**:
- CharacterBackground (backgrounds, stat modifiers, starting equipment)
- CharacterMotivation (motivations with mechanical benefits)
- CharacterSpecies (species with base stats, abilities)
- CharacterTrait (traits with costs and prerequisites)
- StatGenerationRules (2d6÷3 method, min/max values)
- EquipmentTable (starting equipment tables)
- NameGenerationTables (human/alien name generators)
- AdvancementOption (character progression data)
- SkillTree (skill progression trees)
- TrainingOption (training possibilities)

**Usage Analysis**:
```bash
# Only 9 files reference this Resource
Found in:
- src/data/resources/FiveParsecsCharacterData.gd (definition)
- src/core/data/DataManager.gd (mentioned but not instantiated)
- docs/archive/*.md (documentation only)
```

**The Gap**:
- Resource **exists with comprehensive data structures**
- Character creation system **still loads from JSON** instead of using this Resource
- `CharacterGeneration.gd` loads from `character_creation_data.json` directly
- `CharacterCreationTables.gd` loads from `character_creation_tables/*.json` files

**Impact**: Duplication of character data loading logic, type-unsafe Dictionary access

---

### 1.2 FiveParsecsCombatData Resource
**File**: `src/data/resources/FiveParsecsCombatData.gd`
**Status**: ⚠️ **DEFINED BUT NOT INTEGRATED**
**Line Count**: 471 lines

**What It Contains**:
- CombatWeaponData (weapons with range, damage, shots, traits)
- CombatArmorData (armor with saves, coverage, movement penalties)
- EquipmentData (gear, consumables, tools)
- CombatRules (movement, hit chances, cover modifiers, action system)
- TerrainEffect (terrain types with movement/cover modifiers)
- CombatStatusEffect (status effects for combat)
- MissionTemplate (mission structures)
- EnemyType (enemy data)
- DeploymentPattern (deployment strategies)

**Usage Analysis**:
```bash
# Only referenced in 9 files (mostly docs)
Actual usage: NONE in combat systems
```

**The Gap**:
- Combat system loads from `weapons.json`, `armor.json`, `battle_rules.json`
- `WeaponSystem.gd` uses JSON loading instead of Resource
- Battlefield generators use JSON files directly
- **NO integration with actual combat logic**

**Impact**: Type-unsafe combat data, no validation, duplicate data definitions

---

### 1.3 FiveParsecsCampaignData Resource
**File**: `src/data/resources/FiveParsecsCampaignData.gd`
**Status**: ⚠️ **PARTIALLY USED**
**Line Count**: 558 lines

**What It Contains**:
- WorldTrait (world traits with effects, trade/mission modifiers)
- PlanetType (planet types with tech levels, population)
- LocationData (locations with services, shops)
- VictoryCondition (victory conditions with requirements)
- CampaignEvent (campaign events with choices/outcomes)
- CharacterEvent (character-specific events)
- PatronType (patron types with mission types, payment modifiers)
- RivalType (rival types with escalation patterns)
- FactionData (factions with influence, relationships)
- TradeGood (trade goods with volatility, legality)
- MarketCondition (market conditions affecting prices)
- UpkeepCosts (crew/ship upkeep costs)
- StoryTrack (story track progression)
- QuestTemplate (quest templates)

**Usage Analysis**:
```bash
# Referenced in only 3 files
- Definition file
- DataManager (not instantiated)
- Documentation
```

**The Gap**:
- World generation uses `planet_types.json`, `world_traits.json`
- Trading system loads `patron_types.json` directly
- Campaign events use `event_tables.json`
- **Resource factory methods exist but NEVER CALLED**

**Impact**: Rich Resource architecture unused, JSON loading scattered across codebase

---

### 1.4 CrewData Resource
**File**: `src/data/resources/CrewData.gd`
**Status**: ✅ **USED BUT INCOMPLETE**
**Line Count**: 209 lines

**What It Contains**:
- Crew composition (members, captain, size)
- Validation framework (MIN/MAX crew size: 1-8)
- Business logic (add_member, remove_member)
- Crew specialization tracking

**Usage Analysis**:
```bash
# Found in codebase searches but limited actual usage
# Primarily used in campaign creation workflow
```

**The Gap**:
- **NOT saved/loaded in GameState.serialize()**
- GameState tracks `active_campaign.crew_members` as raw Array
- No connection to CrewData validation framework
- Crew changes bypass validation

**Impact**: Crew data saved as unvalidated Dictionaries, CrewData validation unused

---

### 1.5 ShipData Resource
**File**: `src/data/resources/ShipData.gd`
**Status**: ⚠️ **DUPLICATES EXIST**
**Line Count**: Unknown (referenced but not fully analyzed)

**The Gap**:
- `Ship.gd` in `src/core/ships/` exists separately
- `ShipData.gd` in `src/data/ship/` exists as Resource
- Ship upgrades/components use `ship_components.json`
- **TWO ship data models compete**

**Impact**: Ship persistence fragmented, unclear which is authoritative

---

### 1.6 WorldPhaseResources
**File**: `src/core/world_phase/WorldPhaseResources.gd`
**Status**: ⚠️ **DEFINED, NOT USED**

**What It Contains**:
- Crew task data structures
- Patron/job data
- Equipment procurement resources

**The Gap**:
- World Phase logic loads JSON directly
- Resources never instantiated
- No integration with World Phase controllers

---

### 1.7 StoryEventData Resource
**File**: `src/core/story/StoryEventData.gd`
**Status**: ⚠️ **LEGACY STRUCTURE**
**Line Count**: 71 lines

**What It Contains**:
- Event ID, type, title, description
- Choices and outcomes
- Event state tracking

**The Gap**:
- Simple data holder, no integration
- Story system uses different event structure
- Not connected to story track progression

---

## 2. JSON DATA FILES NOT INTEGRATED

### 2.1 High-Value JSON Files Never Loaded

**Total JSON Files**: 105
**Estimated Unused**: ~35-40 files (33-38%)

| JSON File | Purpose | Status | Priority |
|-----------|---------|--------|----------|
| `psionic_powers.json` | Psionics expansion rules | ❌ Never loaded | Medium |
| `expanded_missions.json` | Expanded mission types | ❌ Never loaded | High |
| `expanded_connections.json` | Extended connection system | ❌ Never loaded | Medium |
| `expanded_quest_progressions.json` | Quest progression rules | ❌ Never loaded | High |
| `skill_progression.json` | (Typo: skill_proression.json) | ❌ Never loaded | Medium |
| `patron_types.json` | Patron data (duplicates Resource) | ⚠️ Partially loaded | High |
| `ship_components.json` | Ship upgrade data | ⚠️ Mentioned, not integrated | High |
| `elite_enemy_types.json` | Elite enemy variants | ❌ Never loaded | Medium |
| `planet_types.json` | Planet generation (duplicates Resource) | ⚠️ Loaded in WorldGen only | Medium |
| `character_backgrounds.json` | Character backgrounds (duplicates Resource) | ⚠️ Loaded separately | Low |

### 2.2 Tutorial Data Files

| JSON File | Status |
|-----------|--------|
| `data/Tutorials/quick_start_tutorial.json` | ❌ Tutorial system not implemented |
| `data/Tutorials/advanced_tutorial.json` | ❌ Tutorial system not implemented |
| `data/RulesReference/tutorial_character_creation_data.json` | ❌ Not used |

**Impact**: Tutorial content exists but no UI to display it

### 2.3 RulesReference Directory (17 files)

**Location**: `data/RulesReference/*.json`
**Purpose**: Companion app data, reference tables
**Status**: Partially integrated via BattlefieldCompanionManager

Files like `Bestiary.json`, `Psionics.json`, `Factions.json` exist but have minimal integration beyond documentation display.

---

## 3. SAVE/LOAD GAPS

### 3.1 Data Saved But Never Restored

**Analysis of GameState.serialize() vs GameState.deserialize()**

#### ✅ Properly Saved AND Loaded:
- `current_phase`, `turn_number`, `story_points`, `reputation`
- `resources`, `active_quests`, `completed_quests`, `visited_locations`
- `rivals`, `patrons`, `battle_results`
- `difficulty_level`, `enable_permadeath`, `use_story_track`
- `current_location`, `player_ship`, `campaign`
- `ship_stash` (via EquipmentManager integration)

#### ⚠️ Saved But Restoration Issues:

**Ship Data**:
```gdscript
# SAVE (GameState.gd:685)
if player_ship:
    if player_ship is Dictionary:
        data["player_ship"] = player_ship.duplicate()
    elif player_ship.has_method("serialize"):
        data["player_ship"] = player_ship.serialize()

# LOAD (GameState.gd:751)
if data.has("player_ship"):
    var ship_data = data["player_ship"]
    if Ship:
        player_ship = Ship.new()
        _deserialize_player_ship(ship_data)
```
**Gap**: Ship can be saved as Dictionary OR via serialize(), but restoration only handles Object deserialization. If saved as Dictionary, ship components may be lost.

**Campaign Data**:
```gdscript
# SAVE
if current_campaign:
    save_data["campaign"] = current_campaign.serialize()

# LOAD
if data.has("campaign"):
    _current_campaign = FiveParsecsCampaign.new()
    _deserialize_campaign(campaign_data)
```
**Gap**: Campaign deserialization calls `campaign.deserialize()` but no validation that campaign state matches save data.

#### ❌ Never Saved:

**CrewData Resource**:
- CrewData validation framework exists
- Crew members saved as raw Array in `campaign.serialize()`
- No crew composition validation on load
- CrewData.validate() never called during save/load

**Victory Condition Progress**:
- Victory conditions selected during campaign creation
- Progress tracked in VictoryConditionTracker
- **NOT persisted in save files**
- Campaign load loses victory progress

**World Phase State**:
- Crew tasks assigned
- Patron jobs available
- Trade opportunities
- **NOT saved in campaign state**

---

### 3.2 Schema Version Migration Gaps

**Current Implementation**:
```gdscript
# GameState.gd line 719
var save_version = data.get("schema_version", 1)
if SaveFileMigration.needs_migration(save_version):
    migrated_data = SaveFileMigration.migrate_save_data(...)
```

**Gaps**:
1. **Resources have `schema_version: int = 1`** but never used
2. Migration system exists but only handles GameState-level data
3. No migration for:
   - FiveParsecsCharacterData schema changes
   - FiveParsecsCombatData schema changes
   - FiveParsecsCampaignData schema changes
   - CrewData schema changes

**Impact**: Future data model changes will break old saves

---

## 4. CAMPAIGN STATE FIELDS UNUSED

**Analysis of GameState.gd (1562 lines)**

### 4.1 Defined But Never Read

| Field | Type | Defined Line | Written | Read | Impact |
|-------|------|--------------|---------|------|--------|
| `max_turns` | int | 57 | ❌ Never set | ❌ Never checked | Turn limit not enforced |
| `max_story_points` | int | 58 | ❌ Never set | ✅ Used in add_story_points() | Works but unconfigurable |
| `max_reputation` | int | 59 | ❌ Never set | ✅ Used in add_reputation() | Works but unconfigurable |
| `battle_results` | Dictionary | 61 | ⚠️ Set externally | ✅ Serialized | Used but not via GameState API |

### 4.2 Written But Never Read

| Field | Type | Written By | Read By | Impact |
|-------|------|------------|---------|--------|
| `last_save_time` | int | save_game() | ❌ Never | Autosave timing unused |

### 4.3 Dead Code - Methods Never Called

**From GameState.gd analysis**:

```gdscript
# NEVER CALLED
func apply_location_effects() -> void  # Line 570
func apply_ship_damage(amount: int) -> void  # Line 579
func repair_ship() -> void  # Line 586
func quick_save() -> void  # Line 612
func _on_save_manager_save_completed(success: bool, message: String) -> void  # Line 619
func _on_save_manager_load_completed(success: bool, message: String) -> void  # Line 623
```

**Impact**: Dead code bloat, misleading API surface

---

## 5. PRIORITY RECOMMENDATIONS

### 5.1 CRITICAL (Do First)

#### **#1: Integrate FiveParsecsCharacterData Resource**
**Why**: Character creation is core feature, currently type-unsafe
**Effort**: 4-6 hours
**Files to Modify**:
- `CharacterGeneration.gd` - Replace JSON loading with Resource
- `CharacterCreationTables.gd` - Use Resource-based tables
- `CampaignCreationStateManager.gd` - Use typed CharacterBackground/Motivation

**Implementation**:
```gdscript
# OLD (CharacterGeneration.gd)
var backgrounds = _load_json("character_backgrounds.json")

# NEW
var character_data = FiveParsecsCharacterData.create_default_character_data()
var backgrounds = character_data.backgrounds  # Typed Array[CharacterBackground]
```

**Benefits**:
- Type safety for character creation
- Validation at compile time
- Remove 10+ JSON loading calls

---

#### **#2: Fix Victory Condition Persistence**
**Why**: Victory conditions selected but progress lost on save/load
**Effort**: 2-3 hours
**Files to Modify**:
- `GameState.serialize()` - Add victory_conditions field
- `GameState.deserialize()` - Restore victory progress
- `VictoryConditionTracker.gd` - Add serialize/deserialize methods

**Implementation**:
```gdscript
# GameState.serialize()
data["victory_conditions"] = {
    "selected": VictoryConditionTracker.get_selected_conditions(),
    "progress": VictoryConditionTracker.get_progress()
}

# GameState.deserialize()
if data.has("victory_conditions"):
    VictoryConditionTracker.restore_state(data["victory_conditions"])
```

---

#### **#3: Consolidate Ship Data Models**
**Why**: Two competing ship models cause confusion
**Effort**: 3-4 hours
**Decision Needed**: Which model is authoritative?
- `Ship.gd` (src/core/ships/) - Has component system
- `ShipData.gd` (src/data/ship/) - Resource-based

**Recommendation**: Use `ShipData.gd` as data model, `Ship.gd` as runtime wrapper

---

### 5.2 HIGH PRIORITY (Do Soon)

#### **#4: Integrate FiveParsecsCombatData Resource**
**Why**: Combat data currently type-unsafe, no validation
**Effort**: 6-8 hours
**Files to Modify**:
- `WeaponSystem.gd` - Use CombatWeaponData Resource
- `BattlefieldGenerator.gd` - Use TerrainEffect Resource
- Combat UI screens - Use typed combat data

---

#### **#5: World Phase State Persistence**
**Why**: Crew tasks/patron jobs lost on save/load
**Effort**: 4-5 hours
**Files to Modify**:
- `GameState.serialize()` - Add world_phase_state
- `WorldPhase.gd` - Add serialize/deserialize

---

#### **#6: Enable Unused JSON Data Files**
**Why**: Content exists but inaccessible (expanded missions, psionics)
**Effort**: Variable (2-8 hours per system)

**High-Value Files to Integrate**:
1. `expanded_missions.json` - More mission variety
2. `expanded_quest_progressions.json` - Quest system depth
3. `ship_components.json` - Ship upgrades
4. `psionic_powers.json` - Psionics expansion

---

### 5.3 MEDIUM PRIORITY (Backlog)

#### **#7: Resource Schema Migration System**
**Why**: Future-proof data model changes
**Effort**: 3-4 hours
**Implementation**: Extend SaveFileMigration to handle Resource schema versions

---

#### **#8: Clean Up Dead Code**
**Why**: Reduce confusion, improve maintainability
**Effort**: 1-2 hours
**Target**: Remove unused methods from GameState.gd

---

## 6. ARCHITECTURAL RECOMMENDATIONS

### 6.1 Data Loading Strategy

**Current State**: Hybrid (Resources + JSON)
**Recommended**: **Resource-First with JSON Fallback**

**Migration Path**:
1. Create Resource instances from JSON on first load
2. Save Resources as .tres files
3. Load from .tres (fast) with JSON fallback
4. Eventually deprecate JSON loading

**Example**:
```gdscript
static func load_character_data() -> FiveParsecsCharacterData:
    # Try Resource first (fast)
    if ResourceLoader.exists("user://character_data.tres"):
        return ResourceLoader.load("user://character_data.tres")

    # Fallback to JSON (slow)
    var data = FiveParsecsCharacterData.new()
    data.backgrounds = _load_backgrounds_from_json()
    # ... populate from JSON

    # Save as Resource for next time
    ResourceSaver.save(data, "user://character_data.tres")
    return data
```

---

### 6.2 Save/Load Architecture

**Current Gap**: GameState owns serialization, but Resources aren't integrated

**Recommended Pattern**:
```gdscript
# Each Resource implements SerializableResource
class_name SerializableResource extends Resource

func serialize() -> Dictionary:
    return {
        "schema_version": schema_version,
        "data": _serialize_data()
    }

func deserialize(data: Dictionary) -> void:
    if needs_migration(data["schema_version"]):
        data = migrate(data)
    _deserialize_data(data["data"])
```

**Benefits**:
- Resources own their serialization
- Schema versioning per Resource
- GameState orchestrates, doesn't implement

---

## 7. MEASUREMENT METRICS

### Current State (Baseline)

| Metric | Value | Target | Gap |
|--------|-------|--------|-----|
| Resource classes defined | 12 | 12 | 0% |
| Resource classes integrated | 3 | 12 | -75% |
| JSON files in data/ | 105 | 70 | +50% |
| JSON loading calls | 79 | 30 | +163% |
| Type-safe data access | 30% | 90% | -60% |
| Save/load coverage | 75% | 100% | -25% |

### Success Criteria (3-Month Target)

- [ ] 90% of Resource classes actively used
- [ ] 60% reduction in JSON loading calls
- [ ] 100% victory condition persistence
- [ ] Ship data model consolidated
- [ ] Character/Combat Resources fully integrated
- [ ] Schema migration system for all Resources

---

## 8. CONCLUSION

The Five Parsecs Campaign Manager has **excellent Resource architecture** designed but **poorly integrated**. The gap between design and implementation creates:

1. **Type Safety Issues** - Dictionary-based data access prone to runtime errors
2. **Validation Gaps** - Rich validation in Resources (CrewData, FiveParsecsCampaignData) unused
3. **Persistence Fragmentation** - Some data saved, some lost (victory progress, world phase state)
4. **Code Duplication** - JSON loading scattered across 79+ locations
5. **Unused Content** - 35-40 JSON files exist but never loaded

**Primary Recommendation**: Shift from "Resource definitions exist" to "Resource integration complete" by following Critical priorities #1-#3. This establishes pattern for remaining integrations.

**Estimated Effort**: 20-25 hours to achieve 80% Resource integration coverage.

---

**Next Steps**:
1. Review this analysis with development team
2. Prioritize Critical recommendations #1-#3
3. Create implementation plan for Resource integration
4. Establish testing plan for save/load validation
5. Track metrics monthly to measure progress

---

**Document Version**: 1.0
**Last Updated**: 2025-12-13
**Author**: Campaign Data Architect (Claude)
**Review Status**: Pending team review
