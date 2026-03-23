# Data Consistency Validation — Five Parsecs Campaign Manager

## Campaign Save Schema

Campaign data is persisted as JSON at `user://saves/{campaign_id}.save`. The following structure must be maintained across save/load cycles.

### Required Top-Level Fields

```json
{
  "campaign_name": "string (required, non-empty)",
  "campaign_id": "string (auto-generated UUID)",
  "difficulty": "int (GlobalEnums.DifficultyLevel: EASY=1, NORMAL=2, CHALLENGING=4, HARDCORE=6, INSANITY=8)",
  "campaign_type": "string (enum: STANDARD|CUSTOM|TUTORIAL|STORY|SANDBOX)",
  "ironman_mode": "bool",
  "victory_conditions": ["array of victory condition strings"],
  "story_track_enabled": "bool",
  "house_rules": ["array of rule strings"],
  "red_zone_licensed": "bool (Phase 30: Red Zone Jobs endgame access)",
  "red_zone_turns_completed": "int (turns played in Red Zone worlds)",
  "has_ship": "bool (Phase 30: false when ship destroyed, Core Rules p.59)",
  "ship_debt": "int (loan remaining, interest +1/+2 per turn, seizure risk at >75)",
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
    "type": "string (Freelancer|Worn Freighter|Scout Ship|Patrol Boat|Armed Trader|Converted Transport|Light Freighter)",
    "hull_points": "int (Core Rules: 6-14, NOT 20-35)",
    "max_hull": "int (matches hull_points at creation)",
    "fuel": "int",
    "debt": "int (Core Rules: 0-5, NOT 12-38)",
    "traits": ["array of trait strings"],
    "components": {}
  }
}
```

**CRITICAL (Mar 16 fix)**: Ship values were fabricated at hull 20-35 / debt 12-38. Now corrected to Core Rules scale. Default type is "Freelancer". SpinBox constraints: hull max=20, debt max=10. Persistent test campaigns from before Mar 16 have INVALID ship data.

### World Data

```json
{
  "world": {
    "current_world": "string",
    "world_type": "string (DESERT|ICE|JUNGLE|OCEAN|ROCKY|TEMPERATE|VOLCANIC)",
    "environment": "string",
    "trait": "string",
    "strife_level": "string",
    "market_state": "string (NORMAL|CRISIS|BOOM|RESTRICTED)",
    "tech_level": "int (1-6, d6 roll: 1-2=Low Tech, 3-4=Standard, 5-6=High Tech)",
    "tech_name": "string (Low Tech|Standard|High Tech)",
    "government_type": "int (1-10, d10 roll)",
    "government_name": "string (Anarchy|Corporate|Democracy|Dictatorship|Feudal|Military Junta|Oligarchy|Technocracy|Theocracy|Unity Oversight)",
    "population_scale": "int (1-6, d6 roll: 1-2=Sparse, 3-4=Moderate, 5-6=Dense)",
    "population_name": "string (Sparse|Moderate|Dense)"
  }
}
```

**NOTE (Mar 16 fix)**: tech_level, government_type, and population_scale are new fields added to WorldGenerator. Saves from before Mar 16 will not have these fields — code should handle missing keys gracefully.

### Progress Data (Runtime State)

```json
{
  "progress_data": {
    "turn_number": "int (1+)",
    "current_phase": "string (FiveParsecsCampaignPhase enum value)",
    "credits": "int",
    "story_points": "int",
    "missions_completed": "int",
    "battles_won": "int",
    "battles_lost": "int",
    "patrons": [],
    "rivals": [],
    "quest_rumors": []
  }
}
```

FiveParsecsCampaignCore is a Resource — `campaign["key"] = val` silently fails. Use `progress_data["key"]` for runtime state. Use `"key" in campaign` instead of `.has("key")`.

**BUG-031 FIXED (Phase 30, Mar 16 2026)**: All 4 GameStateManager setters now dual-sync to both the campaign resource property AND `progress_data`. `_on_campaign_loaded()` routes through setters to ensure consistency. `FiveParsecsCampaignCore._init()` and `from_dictionary()` initialize default zero values for `credits`, `missions_completed`, `battles_won`, `battles_lost`.

**BUG-035 FIXED (Phase 31, Mar 16 2026)**: Equipment in ship stash is now restored to EquipmentManager on campaign load via `_restore_equipment_from_campaign()`. Crew dicts are enriched with per-member equipment via `_enrich_crew_equipment()`.

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
9. **Progress counters non-null**: `progress_data.credits` must not be null; `missions_completed`, `battles_won`, `battles_lost` must persist (BUG-031 — FIXED Phase 30)
10. **Origin field populated**: All crew members should have a non-empty `origin` field (BUG-030 — FIXED Phase 30: default dropdown selection now triggers `_on_origin_changed(0)`)
11. **Dual-sync consistency**: `campaign.credits` must equal `progress_data["credits"]`; same for `missions_completed`, `battles_won`, `battles_lost`. All 4 setters in GameStateManager now sync both (Phase 30 fix). If these diverge, the setter pathway was bypassed
12. **Equipment restored on load**: After `load_campaign()`, EquipmentManager must contain the ship stash items from `equipment_data["equipment"]`. Crew member dicts must have per-member `equipment` arrays (BUG-035 — FIXED Phase 31)

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

## Rules Accuracy Validation

### The Hallucination Problem

AI-generated game data can contain fabricated values that look plausible but don't match the Five Parsecs From Home Core Rules book. This project nearly shipped publicly with wrong data — the gameplay loop worked but actual values (weapon stats, event tables, costs, probabilities) were invented. All numeric values must be verified against the physical book.

### Known Hallucination Hotspots

These areas have confirmed or suspected AI-fabricated data:

1. **LootSystemConstants.gd WEAPON_DEFINITIONS**: Multiple weapons have different stats than `weapons.json`. Infantry Laser, Hunting Rifle, Flak Gun, Blast Rifle stats diverge between sources. Neither source has been verified against the book.
2. **FiveParsecsConstants.gd ECONOMY**: Values like `starting_debt: 75`, `injury_treatment_cost: 2`, `hull_repair_cost_per_point: 3` may be fabricated. Cross-reference with Core Rules pp.59-65 and p.80.
3. **Page references contradict**: `injury_table.json` says "p.122", `InjurySystemConstants.gd` says "p.94-95" — at least one is wrong.
4. **Equipment costs**: `equipment_database.json` uses `cost: 3` for nearly everything, with metadata note "Costs are game-balance estimates." Not from Core Rules.
5. **WorldEconomyManager.gd BASE_UPKEEP_COST = 100**: Does not match `FiveParsecsConstants.gd` which says `base_upkeep: 1`. One is wrong.
6. **GameCampaignManager.gd rewards**: Patron jobs 500-1500 credits, missions 1000-2500 credits — no Core Rules page references cited.

### Internal Consistency Check Protocol

Before human book verification, run automated cross-checks between duplicate data sources:

1. **Weapons**: Compare `weapons.json` vs `equipment_database.json` vs `LootSystemConstants.WEAPON_DEFINITIONS`
2. **Injuries**: Compare `injury_table.json` vs `InjurySystemConstants.gd`
3. **Species**: Compare `character_species.json` vs `Character.gd` species modifiers
4. **Economy**: Compare `FiveParsecsConstants.ECONOMY` vs `WorldEconomyManager` constants vs `UpkeepPhaseComponent` values

MCP scripts for these checks are in `docs/QA_RULES_ACCURACY_AUDIT.md` Appendix D.

### Data Source Authority Hierarchy

When multiple sources disagree:

1. **Core Rules book** (ultimate authority)
2. **Dedicated JSON data file** (canonical data source)
3. **GDScript constants file** (should reference JSON, not duplicate it)
4. **Inline hardcoded values** (should not exist; extract to JSON or constants)

### Prevention: New Data Checklist

Before adding or modifying any game data value:

- [ ] Value sourced from Core Rules book (cite page number)
- [ ] Value added to canonical JSON file (not hardcoded in GDScript)
- [ ] No duplicate definitions in other files
- [ ] If value must exist in multiple places, add cross-reference comment
- [ ] Page reference verified against physical book

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
