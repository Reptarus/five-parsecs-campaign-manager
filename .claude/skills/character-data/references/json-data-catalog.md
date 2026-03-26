# JSON Data Catalog

## Data Directory Structure

All game data lives in `data/` at project root. Loaded by `GameDataManager` autoload.

### Core Data Files
| File | Consumer | Schema |
|------|----------|--------|
| `data/weapons.json` | GameDataManager.load_weapons_database() | Array of {id, name, type, range, shots, damage, traits[], cost} |
| `data/armor.json` | GameDataManager.load_armor_database() | 9 protective devices (pp.54-55): {id, name, category (armor/screen), armor_save, effects{}, special_rules} |
| `data/gear.json` | GameDataManager.load_gear_database() | Array of {id, name, description, effect, cost, type} |
| `data/equipment.json` | GameDataManager.load_equipment_database() | Combined equipment catalog |
| `data/injury_table.json` | DataManager, GameDataManager | D100 injury tables (human 9 entries, bot 6 entries) + XP awards table. Older format — same data as injury_results.json |
| `data/injury_results.json` | PostBattleProcessor, ExperienceTrainingProcessor, BattleCalculations | **Canonical** injury data source: D100 tables (human/bot), XP awards (7 conditions, Core Rules p.123), processing rules. Verified against Core Rules p.122-123 |
| `data/unique_individual.json` | BattlePhase._determine_unique_individual() | Unique Individual presence mechanics: threshold (9 on 2D6), difficulty modifiers (Hardcore +1, Insanity forced), Interested Parties +1, exclusion rules (Invasion/Roving Threats). Types table is in enemy_types.json |
| `data/enemy_types.json` | EnemyGenerator via DataManager, BattlePhase._roll_unique_individual_type() | 4 categories (criminal_elements, hired_muscle, interested_parties, roving_threats), 59 enemies with roll_range/numbers/panic/speed/combat_skill/toughness/ai/weapons/special_rules, 21 unique_individuals with D100 roll_range, weapon_tables, ai_types mapping (pp.94-107) |
| `data/loot_tables.json` | GameDataManager.load_loot_tables() | {table_name: [{roll_min, roll_max, item_id, quantity}]} |
| `data/mission_templates.json` | GameDataManager.load_mission_templates() | Array of {id, type, objective, enemies, rewards, deployment} |
| `data/status_effects.json` | GameDataManager.load_status_effects() | {id: {name, duration, effect_type, modifier}} |
| `data/world_traits.json` | GameDataManager.load_world_traits() | {id: {name, description, modifiers}} |
| `data/planet_types.json` | GameDataManager | {id: {name, danger_level, traits[], locations[]}} |
| `data/location_types.json` | GameDataManager | {id: {name, services[], danger_modifier}} |

### Character Creation Data (Phase 38 — Book-Accurate)
| File | Consumer | Schema |
|------|----------|--------|
| `data/gear_database.json` | DataManager, GameDataManager | races[] (8 species with base_stats/special_rules), backgrounds[] (25 with roll_range/stat_bonuses/resources/starting_rolls), motivations[] (17 with d100 ranges), classes[] (23 with d100 ranges), weapon_tables{} (5 tables), crew_starting_equipment{} |
| `data/character_species.json` | SimpleCharacterCreator | primary_aliens[] (8 species), strange_characters[] (15 types), each with base_stats/stat_modifiers/special_rules/rolls_creation_tables flag |
| `data/consumables.json` | LootSystemConstants | 6 book consumables (p.54) |
| `data/onboard_items.json` | LootSystemConstants | 19 book on-board items (pp.57-58) |
| `data/character_creation_tables/` | CharacterCreationTables.gd | background_events.json, motivation_table.json, quirks_table.json |

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

## PDF Source Material for Data Values

Game data values must originate from the rulebooks, never be invented. PDFs and text extractions are available:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python extraction**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"` (PyMuPDF 1.27.1 via `py` launcher)

Always check `data/RulesReference/` first, then the PDFs, before adding or modifying any game data value.

## Validation Rules

- All JSON files must be valid JSON (use `JSON.new().parse()`)
- Roll tables must have contiguous `roll_min`/`roll_max` ranges with no gaps
- Item IDs must be unique within their file
- Cost values must be non-negative integers
- Weapon `range` uses game units (inches on tabletop)
- Equipment arrays reference item IDs from their respective databases
