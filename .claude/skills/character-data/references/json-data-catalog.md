# JSON Data Catalog

## Data Directory Structure

All game data lives in `data/` at project root. Loaded by `GameDataManager` autoload.

### Core Data Files
| File | Consumer | Schema |
|------|----------|--------|
| `data/weapons.json` | GameDataManager.load_weapons_database() | Array of {id, name, type, range, shots, damage, traits[], cost} |
| `data/armor.json` | GameDataManager.load_armor_database() | Array of {id, name, defense_bonus, cost, special} |
| `data/gear.json` | GameDataManager.load_gear_database() | Array of {id, name, description, effect, cost, type} |
| `data/equipment.json` | GameDataManager.load_equipment_database() | Combined equipment catalog |
| `data/injury_tables.json` | GameDataManager.load_injury_tables() | {table_name: [{roll_min, roll_max, result, effect, recovery_turns}]} |
| `data/enemy_types.json` | GameDataManager.load_enemy_types() | {id: {name, combat, toughness, weapons[], ai_behavior, panic}} |
| `data/loot_tables.json` | GameDataManager.load_loot_tables() | {table_name: [{roll_min, roll_max, item_id, quantity}]} |
| `data/mission_templates.json` | GameDataManager.load_mission_templates() | Array of {id, type, objective, enemies, rewards, deployment} |
| `data/status_effects.json` | GameDataManager.load_status_effects() | {id: {name, duration, effect_type, modifier}} |
| `data/world_traits.json` | GameDataManager.load_world_traits() | {id: {name, description, modifiers}} |
| `data/planet_types.json` | GameDataManager | {id: {name, danger_level, traits[], locations[]}} |
| `data/location_types.json` | GameDataManager | {id: {name, services[], danger_modifier}} |

### Character Creation Data
| File | Consumer | Schema |
|------|----------|--------|
| `data/character_creation.json` | GameDataManager.load_character_creation_data() | {backgrounds: [], origins: [], motivations: [], classes: []} |
| `data/backgrounds.json` | Character.generate_character() | Array of {id, name, stat_modifiers, starting_equipment} |
| `data/origins.json` | Character.generate_character() | Array of {id, name, traits[], stat_modifiers} |
| `data/motivations.json` | Character.generate_character() | Array of {id, name, description} |

### Campaign Data
| File | Consumer | Schema |
|------|----------|--------|
| `data/events/*.json` | Event systems | {id, type, description, choices[], outcomes[]} |
| `data/patrons/*.json` | Patron system | {id, name, faction, jobs[], reputation_required} |
| `data/rivals/*.json` | Rival system | {id, name, faction, threat_level, encounters[]} |

### Bug Hunt Data (Separate Gamemode)
| File | Consumer | Schema |
|------|----------|--------|
| `data/bug_hunt/*.json` (15 files) | BugHuntPhaseManager, BugHuntBattleSetup | Bug Hunt-specific tables |

## Data Loading Pattern

```gdscript
# GameDataManager loads JSON files on startup
func load_json_file(file_path: String) -> Variant:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        push_warning("Failed to open: " + file_path)
        return null
    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    if error != OK:
        push_warning("JSON parse error in: " + file_path)
        return null
    return json.data
```

## Data Access Pattern

```gdscript
# Get specific items
var weapon = GameDataManager.get_weapon_by_id("laser_rifle")
var enemy = GameDataManager.get_enemy_type("pirate_captain")
var injury = GameDataManager.get_injury_result("critical", roll_value)
var loot = GameDataManager.get_random_loot_item("standard")

# Check if loaded
if GameDataManager.is_data_loaded("weapons"):
    # safe to access
```

## Validation Rules

- All JSON files must be valid JSON (use `JSON.new().parse()`)
- Roll tables must have contiguous `roll_min`/`roll_max` ranges with no gaps
- Item IDs must be unique within their file
- Cost values must be non-negative integers
- Weapon `range` uses game units (inches on tabletop)
- Equipment arrays reference item IDs from their respective databases
