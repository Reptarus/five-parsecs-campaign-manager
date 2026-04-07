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
| `data/character_species.json` | SpeciesDataService, SimpleCharacterCreator, CharacterCreator | primary_aliens[] (8), strange_characters[] (16), compendium_species[]. Each with base_stats/stat_modifiers/special_rules/forced_motivation/forced_background/rolls_creation_tables/double_background/double_motivation. SpeciesDataService is centralized lookup |
| `data/consumables.json` | LootSystemConstants | 6 book consumables (p.54) |
| `data/onboard_items.json` | LootSystemConstants | 19 book on-board items (pp.57-58) |
| `data/character_creation_tables/` | CharacterCreationTables.gd | background_events.json, motivation_table.json, quirks_table.json |

### New JSON Files (Apr 2, 2026 — Hardcoded→JSON Migration)
| File | Consumer | Schema |
|------|----------|--------|
| `data/difficulty_modifiers.json` | GameSettings.gd | Per-difficulty-level modifiers: enemy_strength, loot, credits, xp, story_points, invasion, initiative, etc. (8 levels) |
| `data/character_advancement.json` | CharacterAdvancementConstants.gd | advancement_costs (6 stats), base_stat_maximums, background/species restrictions, priority order |
| `data/training_courses.json` | ExperienceTrainingProcessor.gd | 8 training courses with cost/effect/description (Core Rules p.125) |
| `data/battle_rewards.json` | BattleResultsManager.gd | outcome_rewards (victory/draw/defeat/retreat), mission_type_bonuses, loot_value ranges |
| `data/progressive_difficulty.json` | ProgressiveDifficultyTracker.gd | basic_milestones (8 entries), advanced_milestones (8 entries) — Compendium pp.56-60 |
| `data/battle_keywords.json` | BattleKeywordDB.gd | 32 combat terms with definition/page/category for auto-linking |
| `data/enemy_type_details.json` | 8 enemy type files in src/game/enemy/types/ | Per-type base_stats, experience_levels, loot values, behavior thresholds |

### Updated JSON Files (Apr 2, 2026)
| File | Added Data |
|------|-----------|
| `data/loot_tables.json` | battlefield_finds table, weapon/gear_definitions, consumable_items, quality_modifiers, trade_goods |
| `data/injury_results.json` | treatment_options (sick_bay/surgery/natural) |
| `data/campaign_config.json` | morale_system, upkeep, story_points, luck, stat_ranges, character_creation, campaign_turns_config, economy, combat |
| `data/victory_conditions.json` | achievement_thresholds (8), difficulty_multipliers (4 levels), common_target_turns |
| `data/mission_tables/mission_difficulty.json` | crew_experience_weights, equipment_quality_modifiers, campaign_turn_scaling |
| `data/mission_tables/mission_rewards.json` | performance_multipliers, patron_relationship_bonuses, danger_pay_scaling |
| `data/RulesReference/StealthAndStreet.json` | sentry_patrol (D6), spotting_modifiers (7), police_response (4 texts) |
| `data/RulesReference/Factions.json` | Expanded Factions (Compendium pp.110-117): D100 type table (7 types), loyalty, jobs (D6<=Influence), 6 favors, D100 activity table (11), D100 event table (15), destruction rules. Consumer: FactionSystem._load_faction_data() |

### Compendium Data Files (Apr 2, 2026 — DLC-Gated)
| File | Consumer | Contents |
|------|----------|----------|
| `data/compendium/no_minis_combat.json` | CompendiumNoMinisCombat | Initiative actions (8), firefight rules, D100 battle flow events (14), mission notes (11), variants |
| `data/compendium/escalating_battles.json` | CompendiumEscalatingBattles | Trigger rules, escalation effects (9), D100 tables by AI type (6) |
| `data/compendium/compendium_equipment.json` | CompendiumEquipment | Advanced training (5), bot upgrades (6), ship parts (3), psionic equipment (3) |
| `data/compendium/stealth_missions.json` | CompendiumStealthMissions | D100 objectives (6), individual types (8), detection/alarm/exfiltration rules, tools (3), mission type selection |
| `data/compendium/salvage_jobs.json` | CompendiumSalvageJobs | D6 availability, D100 POI reveals (22), D100 hostiles (4), contact results, tension rules, discovery table |
| `data/compendium/deployment_variables.json` | CompendiumDeploymentVariables | 9 deployment types, D100 tables by AI type (6) |
| `data/compendium/street_fights.json` | CompendiumStreetFights | D100 objectives (7), enemies (12), combatants (11), suspect/city markers, shootout/evasion/law rules |
| `data/compendium/difficulty_toggles.json` | CompendiumDifficultyToggles | 12 toggles, AI variation tables (4 types), casualty tables (3 creature types), D100 detailed injuries (12), dramatic combat |
| `data/compendium/species.json` | CompendiumSpecies | Krag/Skulker/PrisonPlanet: base_stats, special_rules, armor_rules, colony_world |
| `data/compendium/world_options.json` | CompendiumWorldOptions | D100 strife events (10), loan system (origins/rates/enforcement), D100 name tables (worlds/colonies/ships/corps) |
| `data/compendium/missions_expanded.json` | CompendiumMissionsExpanded | D100 objectives (15), time constraints, extraction, patron conditions (20), quest progression (9), connections (5 subtables), PvP/Co-op rules, introductory campaign (6 turns) |

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

## KNOWN HARDCODED GAME DATA — NOT YET MIGRATED TO JSON

**WARNING**: Previous sessions falsely claimed "full migration complete". The following files
STILL contain hardcoded game data that should load from JSON. Do NOT mark these as done until
the hardcoded values are DELETED and replaced with JSON loading.

### CRITICAL — Core Rules Combat/Character Data
| File | Lines | Hardcoded Data | Should Load From |
|------|-------|----------------|------------------|
| `src/core/battle/BattleCalculations.gd` | 26-52 | To-hit modifiers (3/5/5/6), range bands (6/8/24/6/36), armor saves (6/5/4/3), screen saves (6/5/4) | `data/battle_rules.json` (NEW) |
| `src/core/battle/BattlefieldData.gd` | 503-521 | Injury d6 outcome table, recovery times | `data/injury_results.json` (EXPAND) |
| `src/core/character/CharacterCreator.gd` | 30-113 | ORIGIN_ITEMS (8), BACKGROUND_ITEMS (25), CLASS_ITEMS (21), MOTIVATION_ITEMS (17) | `data/gear_database.json` (EXISTS) |
| `src/core/ship/ShipManager.gd` | ?? | Fabricated upgrade list — NOT Core Rules items | `data/ship_components.json` (VERIFY) |

### MEDIUM — World/Mission/Ship Data
| File | Lines | Hardcoded Data | Should Load From |
|------|-------|----------------|------------------|
| `src/core/world/WorldGenerator.gd` | 129-141 | Government type d10 table (10 types) | `data/world_traits.json` (EXPAND) |
| `src/core/battle/PreBattleLoop.gd` | 454-555 | Fallback terrain/objective/quest arrays | `data/mission_templates.json` (EXISTS) |
| `src/core/battle/CardOracleSystem.gd` | 30-126 | AI behavior instructions (51 sets), joker events (6) | `data/card_oracle.json` (NEW) |

### PREVIOUSLY FIXED (Apr 2, Session 22)
| File | What Was Wrong | Fix |
|------|---------------|-----|
| `data/character_creation_tables/equipment_tables.json` | Entirely AI-fabricated items (Precursor Weapon, Nano Armor, etc.) | DELETED, rewired to `gear_database.json` |
| `data/character_creation_tables/{background,motivation,class}_table.json` | `"patron": true` booleans instead of int counts | Fixed to `1`, added `int()` casts |
| `StartingEquipmentGenerator.gd` | Loaded from fabricated equipment_tables.json | Rewired to `gear_database.json` weapon_tables |

### VERIFICATION RULE FOR FUTURE MIGRATIONS
A migration is NOT complete until:
1. The hardcoded data is **DELETED** from the .gd file (not just "also loads from JSON")
2. The JSON file values are **VERIFIED against the Core Rules PDF** (page citation required)
3. ALL consumers of that data are **GREP'd and rewired** (not just one)
4. A **headless compile check** passes with 0 errors

## Validation Rules

- All JSON files must be valid JSON (use `JSON.new().parse()`)
- Roll tables must have contiguous `roll_min`/`roll_max` ranges with no gaps
- Item IDs must be unique within their file
- Cost values must be non-negative integers
- Weapon `range` uses game units (inches on tabletop)
- Equipment arrays reference item IDs from their respective databases
