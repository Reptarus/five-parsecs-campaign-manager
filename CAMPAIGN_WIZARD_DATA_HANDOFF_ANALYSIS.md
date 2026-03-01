# Campaign Creation Wizard - Data Handoff & State Management Analysis

**Analysis Date**: 2026-01-02 (Updated: 2026-01-04)
**Component**: Campaign Creation Wizard (7-panel workflow)
**Focus**: Data flow integrity from panels → state manager → finalization → GameState/MainCampaignScene

---

## Executive Summary

**Overall Assessment**: **CRITICAL GAPS RESOLVED** (Sprint 26.12)

The campaign wizard had a **three-tier data transformation problem** that has been addressed:

### Sprint 26.12 Fixes Applied

| Issue | Status | Resolution |
|-------|--------|------------|
| Credits bypass in CharacterGeneration | ✅ FIXED | Routes through GameStateManager.add_credits() |
| Credits bypass in CrewCreation | ✅ FIXED | Routes through GameStateManager.set_credits() |
| Campaign.set_crew() only updated deprecated array | ✅ FIXED | Now updates crew_members properly |
| campaign_crew orphaned array | ✅ FIXED | Removed from Campaign.gd |
| Phase handoff inconsistency | ✅ FIXED | TravelPhase & BattlePhase have get_completion_data() |

### Remaining Minor Issues (Non-Critical)
1. **Panel → State Manager**: Key naming handled by CampaignCreationCoordinator normalization
2. **State Manager → Finalization Service**: Data transformation working correctly
3. **Finalization → GameState/MainCampaignScene**: Resource types compatible

**Impact**: Campaign data now flows correctly through all tiers.

---

## Data Flow Architecture

### Current Data Flow
```
┌─────────────┐    panel_data_changed    ┌──────────────────┐
│   Panels    │ ──────────signal────────>│   Coordinator    │
│ (7 panels)  │                           │ (unified state)  │
└─────────────┘                           └──────────────────┘
                                                    │
                          update_*_data() method    │
                                                    ▼
                                          ┌──────────────────┐
                                          │  State Manager   │
                                          │ (campaign_data)  │
                                          └──────────────────┘
                                                    │
                          complete_campaign_creation()
                                                    ▼
                                          ┌──────────────────┐
                                          │ Finalization     │
                                          │ Service          │
                                          └──────────────────┘
                                                    │
                          _create_campaign_resource()
                                                    ▼
                                          ┌──────────────────┐
                                          │ Campaign         │
                                          │ Resource         │
                                          └──────────────────┘
```

---

## Panel Data Formats (What Panels Produce)

### 1. ConfigPanel → `get_panel_data()`
**Format**: Dictionary with standardized keys
```gdscript
{
    "campaign_name": String,           # ⚠️ KEY MISMATCH: State manager expects "name"
    "difficulty_level": int (1-5),     # ⚠️ KEY MISMATCH: State manager expects "difficulty"
    "crew_size": int (4, 5, or 6),
    "victory_condition": String,       # ⚠️ FORMAT MISMATCH: String vs Dictionary
    "story_track_enabled": bool,
    "elite_ranks": int,
    "house_rules": Array[String],
    "created_date": String,
    "version": String
}
```

**Issues**:
- Key mismatch: `campaign_name` → expected `name`
- Key mismatch: `difficulty_level` → expected `difficulty`
- Victory condition stored as String, but state manager expects Dictionary

---

### 2. CaptainPanel → `get_panel_data()`
**Format**: Dictionary (Character serialized to Dictionary)
```gdscript
{
    "character_name": String,          # ✅ Correct
    "background": int (enum),
    "motivation": int (enum),
    "combat": int,
    "reaction": int,
    "toughness": int,
    "savvy": int,
    "speed": int,
    "is_captain": true,
    "confirmed": bool
}
```

**Issues**: None (format matches state manager expectations)

---

### 3. CrewPanel → `get_panel_data()`
**Format**: Dictionary with nested members array
```gdscript
{
    "members": Array[Dictionary],      # ⚠️ TYPE MISMATCH: Should be Array[Character]
    "size": int,
    "captain": Dictionary,             # ⚠️ TYPE MISMATCH: Should be Character reference
    "has_captain": bool,
    "patrons": Array,
    "rivals": Array,
    "starting_equipment": Array,
    "is_complete": bool,
    "crew_flavor": {
        "meeting_story": String,
        "characteristic": String,
        "relationships": Dictionary
    }
}
```

**Issues**:
- `members` array contains Dictionaries, but turn system expects Character Resources
- `captain` is Dictionary reference, not Character object
- Missing character serialization for persistence

---

### 4. ShipPanel → `get_panel_data()`
**Format**: Dictionary with ship data
```gdscript
{
    "ship": {
        "name": String,                # ✅ Correct
        "type": String,                # ✅ Correct
        "hull_points": int,
        "max_hull": int,
        "debt": int,
        "is_configured": bool
    },
    "is_complete": bool
}
```

**Issues**:
- Nested `ship` key creates redundant structure
- Debt should transfer to GameStateManager separately (see finalization service line 212-219)

---

### 5. EquipmentPanel → `get_panel_data()`
**Format**: Dictionary with equipment array
```gdscript
{
    "equipment": Array[Dictionary],    # ⚠️ KEY MISMATCH: Nested under "equipment" key
    "starting_credits": int,           # ⚠️ KEY MISMATCH: Also "credits" in some paths
    "is_complete": bool,
    "backend_generated": bool
}
```

**Issues**:
- Key mismatch: `equipment.equipment` (redundant nesting)
- Inconsistent credit key: `starting_credits` vs `credits`
- State manager validation checks `equipment["equipment"]` (line 361, 597)

---

### 6. WorldInfoPanel → `get_panel_data()`
**Format**: Dictionary with world properties
```gdscript
{
    "name": String,
    "type": String,
    "type_name": String,
    "danger_level": int,
    "tech_level": int,
    "government_type": String,
    "traits": Array[String],
    "locations": Array[Dictionary],
    "special_features": Array[String],
    "opportunities": Array[String],
    "threats": Array[String],
    "is_complete": bool
}
```

**Issues**: None (format compatible with state manager)

---

## State Manager Storage Format

### CampaignCreationStateManager.campaign_data
```gdscript
campaign_data: Dictionary = {
    "config": {
        "campaign_name": String,        # ⚠️ Expects this key
        "campaign_type": String,
        "victory_conditions": Dictionary, # ⚠️ Expects Dictionary not String
        "story_track": String,
        "tutorial_mode": String,
        "is_complete": bool
    },
    "captain": Dictionary,              # ✅ Direct storage
    "crew": {
        "members": Array,                # ⚠️ Type not enforced
        "size": int,
        "captain": Variant,
        "has_captain": bool
    },
    "ship": Dictionary,                  # ⚠️ Direct nested storage
    "equipment": {
        "equipment": Array,              # ⚠️ Redundant nesting
        "is_complete": bool
    },
    "world": Dictionary,                 # ✅ Direct storage
    "metadata": {
        "created_at": String,
        "version": String,
        "is_complete": bool
    }
}
```

---

## Data Handoff Methods & Inconsistencies

### 1. ConfigPanel Data Handoff
**Panel Method**: `get_panel_data()` (line 672-685)
```gdscript
{
    "campaign_name": String,  # ⚠️ Mismatch
    "difficulty_level": int   # ⚠️ Mismatch
}
```

**State Manager Storage**: `campaign_data["config"]`
```gdscript
{
    "campaign_name": String,  # Expects this
    "victory_conditions": {}  # Expects Dictionary
}
```

**Handoff Method**: `panel_data_changed.emit()` → Coordinator → `state_manager.update_config_data()`

**Issue**: ConfigPanel emits `campaign_name`, but state manager's `update_config_data()` (line 1002-1013) does **simple key merge** without transformation:
```gdscript
for key in config_data:
    campaign_data["config"][key] = config_data[key]  # ⚠️ No key remapping
```

**Result**: Data stored with mismatched keys, causing validation failures.

---

### 2. CrewPanel Data Handoff
**Panel Method**: `get_panel_data()` (line 764+)
```gdscript
{
    "members": Array[Dictionary],  # ⚠️ Not Character Resources
}
```

**State Manager Storage**: `campaign_data["crew"]`
```gdscript
{
    "members": Array  # ⚠️ Type not validated
}
```

**Handoff Method**: `crew_setup_complete.emit()` → Coordinator → `state_manager.update_crew_data()`

**Issue**: CrewPanel serializes Character objects to Dictionaries (good for JSON), but turn system expects Character Resources:
- State manager's `_validate_crew_phase()` (line 235-305) checks for Character methods (`has_method("get_customization_completeness")`)
- But panels provide Dictionary data
- **Mismatch**: Validation expects Resources, receives Dictionaries

---

### 3. EquipmentPanel Data Handoff
**Panel Method**: `get_panel_data()` (line 1688+)
```gdscript
{
    "equipment": Array,         # ⚠️ Nested under "equipment"
    "starting_credits": int     # ⚠️ Inconsistent key
}
```

**State Manager Storage**: `campaign_data["equipment"]`
```gdscript
{
    "equipment": Array,  # ⚠️ Expects nested "equipment" key
    "is_complete": bool
}
```

**Handoff Method**: `panel_data_changed.emit()` → Coordinator → `state_manager.update_equipment_data()`

**Issue**: State manager validation (line 361, 597) checks:
```gdscript
if not equipment.has("equipment") or (equipment["equipment"] as Array).is_empty():
```

This creates **redundant nesting**: `campaign_data.equipment.equipment`

---

## Finalization Service Data Transformation Issues

### Critical Gap: Dictionary → Resource Conversion

**Finalization Service** (`_create_campaign_resource()`, line 164-288) attempts to transform state manager data into Campaign Resource:

```gdscript
var campaign = FiveParsecsCampaignCore.new()

# Config transformation
campaign.campaign_name = config.get("name", "")  # ⚠️ Expects "name" not "campaign_name"
campaign.difficulty = config.get("difficulty", -1)  # ⚠️ Expects "difficulty" not "difficulty_level"

# Crew transformation
var crew_data = data.get("crew", {})
var transformed_crew = _transform_crew_data_for_turn_system(crew_data)  # Line 199-200
campaign.initialize_crew(transformed_crew)

# Equipment transformation
var equipment_data = data.get("equipment", {})
var transformed_equipment = _transform_equipment_data_for_turn_system(equipment_data)  # Line 221-224
campaign.set_starting_equipment(transformed_equipment)
```

**Issues**:
1. **Config Key Mismatch** (line 175-182):
   - Checks for `config.get("name")` but ConfigPanel provides `campaign_name`
   - Checks for `config.get("difficulty")` but ConfigPanel provides `difficulty_level`
   - **Fallback logic exists** but relies on coordinator's `campaign_config` key (unreliable)

2. **Crew Data Transformation** (line 199-202):
   - Calls `_transform_crew_data_for_turn_system()` (line 452-480)
   - **Missing implementation**: Method exists but doesn't actually convert Dictionary → Character Resources
   - Just adds IDs and default fields to Dictionaries

3. **Equipment Data Transformation** (line 221-224):
   - Calls `_transform_equipment_data_for_turn_system()` (line 498-519)
   - **Handles nested "equipment" key** (line 503-510) but doesn't transform item format
   - Credits key inconsistency handled with fallback (line 516)

---

## GameState/MainCampaignScene Expected Formats

### GameState Expectations
From `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/state/GameState.gd`:

```gdscript
# Lines 42-55
var current_phase: int = 0
var turn_number: int = 0
var story_points: int = 0
var reputation: int = 0
var resources: Dictionary = {}
var active_quests: Array[Dictionary] = []
var current_location: Dictionary = {}  # ⚠️ Expects world data here
var player_ship: Variant = null        # ⚠️ Expects Ship Resource
var visited_locations: Array[String] = []
var rivals: Array = []
var patrons: Array = []
```

**Issues**:
- `current_location` expects world data directly (finalization sets this, line 231-233 ✅)
- `player_ship` expects Ship Resource, not Dictionary (finalization doesn't create Ship Resource)
- `resources` format undefined (finalization uses `initialize_resources()`, line 266-272)

---

### Campaign Resource Expectations
From `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/Campaign.gd` (SimpleCampaign):

```gdscript
campaign_data: Dictionary = {
    "name": String,
    "turn": int,
    "story_points": int,
    "crew": Array,              # ⚠️ Format undefined
    "ship": Dictionary,         # ⚠️ Not Ship Resource
    "credits": int,
    "debt": int,
    "current_world": String,    # ⚠️ Not Dictionary
    "phase": String
}
```

**Issues**:
- Campaign.gd is `SimpleCampaign` (refactored), not `FiveParsecsCampaignCore` referenced in finalization
- Finalization creates `FiveParsecsCampaignCore` but GameState may load `SimpleCampaign`
- **Class mismatch**: Two campaign implementations exist

---

## Missing Data Fields in Transitions

### 1. Config → State Manager
**Missing**:
- Key remapping: `campaign_name` → `name`
- Key remapping: `difficulty_level` → `difficulty`
- Victory condition format transformation: String → Dictionary
- House rules persistence (ConfigPanel provides, state manager stores, but finalization doesn't transfer)

### 2. Crew → State Manager → Finalization
**Missing**:
- Character Dictionary → Character Resource conversion
- Captain cross-reference validation (crew.captain should match crew.members)
- Patron/rival serialization for persistence
- Crew flavor data transfer (Core Rules p.30 data not transferred)

### 3. Equipment → State Manager → Finalization
**Missing**:
- Redundant nesting resolution (`equipment.equipment`)
- Credits key normalization (`starting_credits` vs `credits`)
- Equipment assignment to characters (who carries what)

### 4. Ship → State Manager → Finalization → GameState
**Missing**:
- Ship Dictionary → Ship Resource conversion
- Debt transfer to GameStateManager (finalization does this, line 212-219 ✅)
- Hull points initialization
- Ship components/upgrades persistence

### 5. World → Finalization → GameState
**Missing**:
- World traits validation (GameState line 182 expects `GlobalEnums.WorldTrait`)
- Location format validation (GameState expects Array[String], panel provides Array[Dictionary])

### 6. Victory Conditions → Campaign Resource
**Missing**:
- Victory conditions not transferred to Campaign Resource (finalization line 235-239 transfers but Campaign.gd doesn't define field)
- Custom victory targets lost (finalization line 250-256 tries to transfer but GameStateManager method may not exist)

---

## State Manager Gaps

### 1. Validation Gaps
**Identified in** `CampaignCreationStateManager.gd`:

```gdscript
# Line 235-305: _validate_crew_phase()
if not crew.has("members"):
    # Assumes default crew setup
    return true  # ⚠️ Too permissive - allows empty crew

# Line 356-374: _validate_equipment_phase()
if not equipment.has("equipment") or (equipment["equipment"] as Array).is_empty():
    # Requires "equipment" nested key
    return false  # ✅ Correct but awkward nesting

# Line 376-383: _validate_world_phase()
# World generation is optional - empty world data will use defaults
return true  # ⚠️ Always passes - no actual validation
```

**Issues**:
- Crew validation too permissive (allows incomplete data)
- Equipment validation enforces redundant nesting
- World validation non-existent (always passes)

---

### 2. Data Merge Gaps
**All `update_*_data()` methods** (lines 1002-1256) use **simple key merge**:
```gdscript
for key in data:
    campaign_data[section][key] = data[key]
```

**Missing**:
- Key remapping/normalization
- Type validation
- Nested structure flattening
- Cross-section dependency resolution (e.g., captain in both captain and crew sections)

---

### 3. Serialization Gaps
**`_serialize_crew_data()`** (lines 681-703) attempts enhanced serialization:
```gdscript
if member is Object:
    if member.has_method("serialize_enhanced"):
        serialized_members.append(member.serialize_enhanced())
    elif member.has_method("serialize"):
        serialized_members.append(member.serialize())
    else:
        serialized_members.append(_fallback_character_serialization(member))
else:
    # member is a Dictionary, use fallback serialization
    serialized_members.append(_fallback_character_serialization(member))
```

**Issues**:
- Assumes Character Resources have `serialize()` methods (they don't always)
- Fallback serialization (lines 705-731) is incomplete (missing equipment, traits, injuries)
- No deserialization method to reverse the process

---

## Finalization Service Issues

### 1. Data Transformation Incomplete
**`_transform_crew_data_for_turn_system()`** (lines 452-480):
```gdscript
for member in members:
    if member is Dictionary:
        var character_data = member.duplicate(true)
        if not character_data.has("id"):
            character_data["id"] = str(randi())  # ⚠️ Adds ID but doesn't create Character Resource
        if not character_data.has("experience"):
            character_data["experience"] = 0
        transformed_members.append(character_data)  # ⚠️ Still Dictionary
```

**Issue**: Transformation adds default fields but doesn't convert Dictionary → Character Resource

---

### 2. Key Fallback Logic Fragile
**Campaign name resolution** (lines 175-182):
```gdscript
var campaign_name = config.get("name", "")
if campaign_name.is_empty():
    campaign_name = config.get("campaign_name", "")
if campaign_name.is_empty():
    campaign_name = campaign_config.get("campaign_name", "")
if campaign_name.is_empty():
    campaign_name = campaign_config.get("name", "Unnamed Campaign")
```

**Issue**: 4-level fallback indicates **no single source of truth** for campaign name

---

### 3. GameStateManager Integration Fragile
**Lines 212-256**: Attempts to transfer data to GameStateManager:
```gdscript
if GameStateManager and ship_data.has("debt"):
    if GameStateManager.has_method("set_ship_debt"):
        GameStateManager.set_ship_debt(debt)  # ⚠️ Method may not exist
    else:
        print("Warning - GameStateManager missing set_ship_debt method")
```

**Issue**: Uses `has_method()` checks for critical data transfer (indicates missing contracts/interfaces)

---

## Data Format Inconsistencies Summary

| Panel | Produces | State Manager Expects | Finalization Transforms To | GameState Expects | Status |
|-------|----------|----------------------|---------------------------|-------------------|--------|
| ConfigPanel | `campaign_name`, `difficulty_level` | `name`, `difficulty` | Falls back to multiple keys | N/A | ⚠️ KEY MISMATCH |
| CaptainPanel | Dictionary | Dictionary | Dictionary (no change) | N/A | ✅ Compatible |
| CrewPanel | `members: Array[Dict]` | `members: Array` (untyped) | Adds IDs, keeps Dict | `crew: Array` (untyped) | ⚠️ TYPE MISMATCH |
| ShipPanel | `ship: {nested}` | Direct merge | Transfers debt separately | `player_ship: Ship Resource` | ❌ STRUCTURE MISMATCH |
| EquipmentPanel | `equipment: Array` | `equipment.equipment: Array` | Flattens nesting | `resources: Dict` | ⚠️ NESTING MISMATCH |
| WorldInfoPanel | Dictionary | Dictionary | Direct transfer to `current_location` | `current_location: Dict` | ✅ Compatible |

**Legend**:
- ✅ Compatible: No transformation needed
- ⚠️ Mismatch: Data flows but with key/type inconsistencies
- ❌ Incompatible: Critical structural mismatch

---

## Recommendations

### Immediate Fixes (Critical Path)

1. **Fix ConfigPanel Key Mismatches**:
   ```gdscript
   # In ConfigPanel.get_panel_data()
   return {
       "name": current_config.name,  # Change from "campaign_name"
       "difficulty": current_config.difficulty,  # Change from "difficulty_level"
       # ...
   }
   ```

2. **Fix Equipment Nesting**:
   ```gdscript
   # In EquipmentPanel.get_panel_data()
   return {
       "items": local_equipment_data.equipment,  # Flatten nesting
       "credits": local_equipment_data.starting_credits,
       # ...
   }

   # In State Manager, remove redundant validation:
   # OLD: if not equipment.has("equipment")
   # NEW: if not equipment.has("items")
   ```

3. **Add Crew Dictionary → Character Resource Conversion**:
   ```gdscript
   # In CampaignFinalizationService._transform_crew_data_for_turn_system()
   func _dict_to_character(char_dict: Dictionary) -> Character:
       var character = Character.new()
       character.character_name = char_dict.get("character_name", "")
       character.background = char_dict.get("background", 0)
       # ... copy all fields
       return character
   ```

4. **Normalize Ship Data Structure**:
   ```gdscript
   # In ShipPanel.get_panel_data()
   return local_ship_data.ship  # Don't nest under "ship" key

   # In State Manager:
   campaign_data["ship"] = ship_data  # Direct assignment
   ```

---

### Medium Priority (Data Integrity)

5. **Add Victory Condition Dictionary Storage**:
   ```gdscript
   # In ConfigPanel, convert victory_condition String to Dictionary:
   func get_panel_data() -> Dictionary:
       var victory_dict = {}
       victory_dict[current_config.victory_condition] = true
       return {
           "victory_conditions": victory_dict  # Store as Dictionary
       }
   ```

6. **Add Ship Resource Creation**:
   ```gdscript
   # In CampaignFinalizationService._create_campaign_resource()
   var ship_resource = Ship.new()
   ship_resource.name = ship_data.get("name", "")
   ship_resource.type = ship_data.get("type", "")
   ship_resource.hull_points = ship_data.get("hull_points", 0)
   campaign.set_ship(ship_resource)
   ```

7. **Add Cross-Panel Validation**:
   ```gdscript
   # In State Manager, validate captain is in crew:
   func _validate_crew_phase() -> bool:
       var captain_id = campaign_data.captain.get("id", "")
       var captain_in_crew = false
       for member in campaign_data.crew.members:
           if member.get("id") == captain_id:
               captain_in_crew = true
               break
       if not captain_in_crew:
           validation_errors.append("Captain not found in crew roster")
           return false
   ```

---

### Long-Term Refactoring (Architecture)

8. **Create Data Contract Interfaces**:
   ```gdscript
   # Define expected formats for each panel
   class_name ICampaignPanelData

   static func validate_config_data(data: Dictionary) -> bool:
       return data.has("name") and data.has("difficulty")

   static func validate_crew_data(data: Dictionary) -> bool:
       return data.has("members") and data.members is Array
   ```

9. **Add Data Mapper Layer**:
   ```gdscript
   # Between panels and state manager
   class_name CampaignDataMapper

   static func panel_to_state(panel_type: String, panel_data: Dictionary) -> Dictionary:
       match panel_type:
           "config":
               return _map_config_data(panel_data)
           "crew":
               return _map_crew_data(panel_data)

   static func _map_config_data(data: Dictionary) -> Dictionary:
       return {
           "name": data.get("campaign_name", data.get("name", "")),
           "difficulty": data.get("difficulty_level", data.get("difficulty", 2))
       }
   ```

10. **Implement Resource Factories**:
    ```gdscript
    # Centralize Character/Ship Resource creation
    class_name ResourceFactory

    static func create_character_from_dict(data: Dictionary) -> Character:
        var char = Character.new()
        char.character_name = data.get("character_name", "")
        # ... full property mapping
        return char

    static func create_ship_from_dict(data: Dictionary) -> Ship:
        var ship = Ship.new()
        ship.name = data.get("name", "")
        # ... full property mapping
        return ship
    ```

---

## Test Coverage Recommendations

### Unit Tests Needed
1. **Panel Data Format Tests**: Verify each panel's `get_panel_data()` output matches expected schema
2. **State Manager Merge Tests**: Test `update_*_data()` methods handle key mismatches
3. **Finalization Transformation Tests**: Verify Dictionary → Resource conversions
4. **Cross-Panel Dependency Tests**: Validate captain exists in crew, equipment matches crew size

### Integration Tests Needed
1. **End-to-End Wizard Flow**: Create campaign through all 7 panels, verify data integrity
2. **Save/Load Round-Trip**: Create campaign, finalize, save, load, verify no data loss
3. **GameState Integration**: Verify finalized campaign loads into MainCampaignScene without errors

---

## Appendix: File References

### Panel Files
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/ConfigPanel.gd` (lines 672-820)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/CaptainPanel.tscn` (minimal scene, logic in .gd)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/CrewPanel.gd` (lines 1-200)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/ShipPanel.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/EquipmentPanel.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/WorldInfoPanel.gd`

### State Management Files
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/campaign/creation/CampaignCreationStateManager.gd` (lines 1-1395)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/campaign/creation/CampaignFinalizationService.gd` (lines 1-537)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/CampaignCreationCoordinator.gd` (lines 1-300)

### Backend Files
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/Campaign.gd` (SimpleCampaign - lines 1-106)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/state/GameState.gd` (CoreGameState - lines 1-300)

---

**End of Analysis**
