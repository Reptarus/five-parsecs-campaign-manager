# Data Consistency Validation — Five Parsecs Campaign Manager

## Campaign Save Schema

Campaign data is persisted as JSON at `user://saves/{campaign_id}.save`. The following structure must be maintained across save/load cycles.

### Required Top-Level Fields

```json
{
  "campaign_name": "string (required, non-empty)",
  "campaign_id": "string (auto-generated UUID)",
  "difficulty": "string (enum: EASY|NORMAL|HARD|CHALLENGING|NIGHTMARE|HARDCORE|ELITE|INSANITY)",
  "campaign_type": "string (enum: STANDARD|CUSTOM|TUTORIAL|STORY|SANDBOX)",
  "ironman_mode": "bool",
  "victory_conditions": ["array of victory condition strings"],
  "story_track_enabled": "bool",
  "house_rules": ["array of rule strings"],
  "schema_version": "int (current: 1)",
  "created_at": "string (ISO datetime)",
  "last_modified": "string (ISO datetime)",
  "version": "string (app version)"
}
```

### Crew Data Structure

```json
{
  "crew_data": {
    "members": [
      {
        "character_id": "string",
        "id": "string (legacy alias — MUST match character_id)",
        "name": "string",
        "character_name": "string (MUST match name)",
        "combat": "int (0-5)",
        "reactions": "int (0-6)",
        "toughness": "int (0-6)",
        "savvy": "int (0-5)",
        "tech": "int (0+)",
        "move": "int (typically 4)",
        "speed": "int (4-8)",
        "luck": "int (0-3 humans, -1 some aliens)",
        "health": "int",
        "max_health": "int",
        "experience": "int (0+)",
        "credits": "int (0+)",
        "is_captain": "bool (exactly 1 per crew)",
        "status": "string (ACTIVE|INJURED|RECOVERING|DEAD|MISSING|RETIRED)",
        "character_class": "string",
        "background": "string",
        "origin": "string",
        "motivation": "string",
        "equipment": ["array of equipment ID strings"],
        "schema_version": "int"
      }
    ]
  }
}
```

### Equipment Data (CRITICAL KEY)

```json
{
  "equipment_data": {
    "equipment": ["array of equipment items"]
  }
}
```

The key is `"equipment"`, **NOT** `"pool"`. Using `"pool"` was a systemic bug fixed in Phase 22. Always validate this.

### Ship Data

```json
{
  "ship": {
    "name": "string",
    "hull_points": "int",
    "fuel": "int",
    "debt": "int (0+)",
    "components": {}
  }
}
```

### World Data

```json
{
  "world": {
    "current_world": "string",
    "world_type": "string (DESERT|ICE|JUNGLE|OCEAN|ROCKY|TEMPERATE|VOLCANIC)",
    "environment": "string",
    "trait": "string",
    "strife_level": "string",
    "market_state": "string (NORMAL|CRISIS|BOOM|RESTRICTED)"
  }
}
```

### Progress Data (Runtime State)

```json
{
  "progress_data": {
    "turn_number": "int (1+)",
    "current_phase": "string (FiveParsecsCampaignPhase enum value)",
    "credits": "int",
    "story_points": "int",
    "patrons": [],
    "rivals": [],
    "quest_rumors": []
  }
}
```

FiveParsecsCampaignCore is a Resource — `campaign["key"] = val` silently fails. Use `progress_data["key"]` for runtime state. Use `"key" in campaign` instead of `.has("key")`.

---

## Character Data Validation Rules

### Flat Stat Properties (NO Sub-Object)

Characters use flat properties directly on the object/dict. There is NO `stats` sub-object:

| Stat | Type | Min | Max (Rules) | Notes |
|------|------|-----|-------------|-------|
| combat | int | 0 | 5 | |
| reactions | int | 0 | 6 | |
| toughness | int | 0 | 6 | Engineer species can exceed |
| savvy | int | 0 | 5 | |
| tech | int | 0 | unlimited | |
| move | int | 4 | 8 | Typically 4 base |
| speed | int | 4 | 8 | |
| luck | int | -1 | 3 | Humans 0-3, some aliens -1, Soulless 0 |

### Dual Key Aliases (MUST Both Exist)

`Character.to_dictionary()` returns BOTH:
- `"id"` AND `"character_id"` (must be identical)
- `"name"` AND `"character_name"` (must be identical)

When manually creating character dicts (e.g., in tests or factory code), always include BOTH aliases.

### Captain Invariant

Exactly ONE crew member must have `is_captain == true`. Validate:
- At least one captain exists
- At most one captain exists
- Captain has status ACTIVE (not DEAD/MISSING)

### Status Transitions

Valid status values: `ACTIVE`, `INJURED`, `RECOVERING`, `DEAD`, `MISSING`, `RETIRED`

Valid transitions:
- ACTIVE → INJURED, DEAD, MISSING, RETIRED
- INJURED → RECOVERING, DEAD
- RECOVERING → ACTIVE, DEAD
- DEAD → (terminal, no transitions)
- MISSING → ACTIVE, DEAD (can be found or confirmed dead)
- RETIRED → (terminal, no transitions)

---

## Save/Load Roundtrip Validation Protocol

### Step 1: Save Capture
Save campaign state to JSON. Record:
- Total crew count
- Each character's stat values
- Equipment inventory count
- Credits balance
- Turn number and phase
- Victory condition progress

### Step 2: Load and Compare
Load saved JSON. Verify:

1. **Integer preservation**: JSON stores all numbers as float. After loading, verify `int(value) == original_int` for all integer fields (turn_number, credits, stats, XP)
2. **Nested structure depth**: Equipment arrays, crew member arrays, implant arrays all maintain correct nesting
3. **Equipment key check**: `"equipment" in campaign.equipment_data` (NOT "pool")
4. **Dual key presence**: Every crew member dict has BOTH `id`/`character_id` and `name`/`character_name`
5. **Captain count**: Exactly 1 member has `is_captain == true`
6. **Stat ranges**: All stats within valid ranges (see table above)
7. **Status values**: All member statuses are valid enum strings
8. **Array lengths match**: crew count, equipment count preserved

### Step 3: Re-Save and Binary Compare
Save the loaded state again. Compare JSON strings (after normalization) to verify idempotent serialization.

---

## Cross-Mode Data Isolation (Standard vs Bug Hunt)

### Standard Campaign (FiveParsecsCampaignCore)
```
crew_data["members"]  →  Array of character Dictionaries (nested)
ship_data             →  Ship properties
patrons/rivals        →  Patron/rival tracking arrays
```

### Bug Hunt Campaign (BugHuntCampaignCore)
```
main_characters  →  Array of character Dictionaries (flat, top-level)
grunts           →  Array of grunt Dictionaries (flat, top-level)
NO ship, NO patrons, NO rivals
```

### Detection Pattern
```gdscript
if "main_characters" in campaign:
    # Bug Hunt campaign
else:
    # Standard 5PFH campaign
```

### Temp Data Namespacing
- Bug Hunt keys: `"bug_hunt_battle_context"`, `"bug_hunt_battle_result"`, `"bug_hunt_mission"`
- Standard keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`
- No collisions between namespaces

### Cross-Mode Validation Checklist
- [ ] Standard campaign save does NOT contain `main_characters` key
- [ ] Bug Hunt save does NOT contain `crew_data` key
- [ ] Loading a standard save with Bug Hunt loader fails gracefully
- [ ] Loading a Bug Hunt save with standard loader fails gracefully
- [ ] CharacterTransferService correctly maps between schemas
- [ ] temp_data keys don't leak between modes

---

## Enum Consistency Validation

Three enum systems must stay in sync:

| System | File | Autoloaded As |
|--------|------|---------------|
| GlobalEnums | `src/core/systems/GlobalEnums.gd` | `GlobalEnums` |
| GameEnums | `src/core/enums/GameEnums.gd` | class_name `GameEnums` |
| FiveParsecsGameEnums | `src/game/campaign/crew/FiveParsecsGameEnums.gd` | CharacterClass only |

### Validation Steps

1. **FiveParsecsCampaignPhase**: Compare ordinals between GlobalEnums and GameEnums — must have identical values
2. **CharacterClass**: FiveParsecsGameEnums must be superset of GlobalEnums character classes
3. **ContentFlag count**: DLCManager should have 37 flags (35 DLC + 2 Bug Hunt)
4. **Difficulty levels**: GlobalEnums.DifficultyMode must have 9 values
5. **Victory conditions**: VictoryChecker must handle all GlobalEnums.VictoryConditionType values (18+ types)

### Automated Check Script (run_script via MCP)

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var ge = scene_tree.root.get_node_or_null("/root/GlobalEnums")
    if not ge:
        return {"error": "GlobalEnums not loaded"}
    var dlc = scene_tree.root.get_node_or_null("/root/DLCManager")
    var flag_count = 0
    if dlc and "ContentFlag" in dlc:
        flag_count = dlc.ContentFlag.size()
    return {
        "global_enums_loaded": ge != null,
        "dlc_content_flags": flag_count,
        "expected_flags": 37
    }
```
