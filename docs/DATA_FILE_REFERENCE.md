# Five Parsecs Campaign Manager - Data File Reference

**Last Updated**: 2026-02-09
**Total JSON Files**: 95+
**Data Directory**: `data/`

---

## 📁 Directory Structure

```
data/
├── RulesReference/          # Core rulebook tables & systems
├── Tutorials/               # Tutorial content
├── battlefield/             # Battlefield generation
│   ├── features/
│   ├── objectives/
│   ├── rules/
│   └── themes/
├── battlefield_tables/      # Battlefield tables
├── campaign_tables/         # Campaign phase tables
│   ├── crew_tasks/
│   └── world_phase/
├── character_creation_tables/  # Character generation
├── enemies/                 # Enemy type data
├── mission_tables/          # Mission generation
├── missions/                # Mission templates
└── autoload/                # System configuration
```

---

## 1. RULES REFERENCE (`data/RulesReference/`)

Core rulebook data extracted from Five Parsecs source material.

| File | Purpose | Used By |
|------|---------|---------|
| `AlternateEnemyDeployment.json` | Enemy spawn patterns | `BattleManager.gd` |
| `Bestiary.json` | Monster/creature stats | `EnemyGenerator.gd` |
| `Campaign.json` | Campaign rules & phases | `CampaignPhaseManager.gd` |
| `DifficultyOptions.json` | Difficulty modifiers | `DifficultyManager.gd` |
| `EliteEnemies.json` | Elite enemy definitions | `EnemyGenerator.gd` |
| `EnemyAI.json` | AI behavior patterns | `EnemyAI.gd` |
| `EquipmentItems.json` | Full equipment catalog | `EquipmentManager.gd` |
| `ExpandedMissions.json` | Expanded mission types | `MissionGenerator.gd` |
| `Factions.json` | Faction definitions | `FactionManager.gd` |
| `NameGenerationTables.json` | Name generation | `NameGenerator.gd` |
| `Nominis.json` | Optional naming system | `NameGenerator.gd` |
| `PVPCoop.json` | Multiplayer rules | Future use |
| `Psionics.json` | Psionic powers system | `PsionicSystem.gd` |
| `SalvageJobs.json` | Salvage mission type | `MissionGenerator.gd` |
| `SpeciesList.json` | All playable species | `CharacterCreationData.gd` |
| `StealthAndStreet.json` | Stealth rules | `StealthSystem.gd` |
| `TerrainTables.json` | Terrain generation | `TerrainGenerator.gd` |
| `tutorial_character_creation_data.json` | Tutorial data | `TutorialManager.gd` |

---

## 2. CHARACTER CREATION (`data/character_creation_tables/`)

D100 tables for character generation matching rulebook.

| File | Purpose | Roll Type |
|------|---------|-----------|
| `background_table.json` | Character backgrounds | D100 |
| `background_events.json` | Background story events | D100 |
| `class_table.json` | Character classes | D100 |
| `connections_table.json` | NPC connections | D100 |
| `equipment_tables.json` | Starting equipment | By background |
| `flavor_table.json` | Personality traits | D100 |
| `motivation_table.json` | Character motivations | D100 |
| `quirks_table.json` | Character quirks | D100 |

**Usage**: `src/core/character/CharacterCreationData.gd`

---

## 3. CAMPAIGN TABLES (`data/campaign_tables/`)

### Phase Events
| File | Purpose |
|------|---------|
| `campaign_phases.json` | Phase definitions & order |
| `phase_events.json` | Random phase events |

### Crew Tasks (`data/campaign_tables/crew_tasks/`)
| File | Purpose | Source |
|------|---------|--------|
| `crew_task_resolution.json` | Resolution mechanics for all 8 crew tasks (dice types, difficulties) | Core Rules pp.76-82 |
| `exploration_events.json` | D100 Exploration Table — 30 entries | Core Rules p.80 |
| `recruitment_opportunities.json` | Recruit rules: auto if crew<6, D6+crew if >=6 | Core Rules p.78 |
| `trade_results.json` | D100 Trade Table — 34 entries | Core Rules p.79 |
| `training_outcomes.json` | Train rules: automatic 1 XP | Core Rules p.76 |

### World Phase (`data/campaign_tables/world_phase/`)
| File | Purpose | Source |
|------|---------|--------|
| `crew_task_modifiers.json` | Core rules modifiers only (crew count, Savvy, Engineer, credits) | Core Rules pp.76-82 |
| `patron_jobs.json` | Patron job offers | Core Rules |

---

## 4. MISSION TABLES (`data/mission_tables/`)

Mission generation and rewards.

| File | Purpose |
|------|---------|
| `mission_types.json` | Available mission types |
| `mission_objectives.json` | Victory conditions |
| `mission_rewards.json` | Base rewards |
| `mission_events.json` | Mid-mission events |
| `mission_difficulty.json` | Difficulty scaling |
| `mission_descriptions.json` | Flavor text |
| `mission_titles.json` | Mission name generation |
| `bonus_objectives.json` | Optional objectives |
| `bonus_rewards.json` | Bonus loot |
| `credit_rewards.json` | Credit payout tables |
| `deployment_points.json` | Deployment rules |
| `rival_involvement.json` | Rival encounter chance |
| `reward_items.json` | Specific item rewards |

---

## 5. MISSION TEMPLATES (`data/missions/`)

Pre-built mission configurations.

| File | Purpose |
|------|---------|
| `mission_generation_params.json` | Generation rules |
| `opportunity_missions.json` | Random missions |
| `patron_missions.json` | Patron-specific missions |

---

## 6. BATTLEFIELD DATA (`data/battlefield/`)

### Themes (`data/battlefield/themes/`)
| File | Description |
|------|-------------|
| `01_urban_sprawl.json` | City battlefield |
| `02_wasteland_outpost.json` | Desert/wasteland |

### Features (`data/battlefield/features/`)
| File | Description |
|------|-------------|
| `common_features.json` | Generic cover/obstacles |
| `natural_features.json` | Rocks, trees, water |
| `urban_features.json` | Buildings, walls, vehicles |

### Other
| File | Purpose |
|------|---------|
| `objectives/objective_markers.json` | Objective types |
| `rules/deployment_rules.json` | Deployment zones |
| `rules/validation_rules.json` | Map validation |
| `companion_config.json` | Companion app settings |

---

## 7. BATTLEFIELD TABLES (`data/battlefield_tables/`)

| File | Purpose |
|------|---------|
| `cover_elements.json` | Cover types & values |
| `terrain_types.json` | Terrain classifications |
| `hazard_features.json` | Dangerous terrain |
| `strategic_points.json` | Tactical locations |

---

## 8. ENEMY DATA

### Root Level
| File | Purpose |
|------|---------|
| `enemy_types.json` | Standard enemy catalog |
| `elite_enemy_types.json` | Elite/boss enemies |

### Specific Factions (`data/enemies/`)
| File | Faction |
|------|---------|
| `corporate_security_data.json` | Corporate forces |
| `pirates_data.json` | Pirate gangs |
| `wildlife_data.json` | Hostile creatures |

---

## 9. EQUIPMENT & ITEMS

| File | Category |
|------|----------|
| `weapons.json` | All weapons (22+) |
| `armor.json` | Armor types |
| `gear_database.json` | General gear |
| `equipment_database.json` | Full equipment |
| `ship_components.json` | Ship upgrades |
| `resources.json` | Tradeable resources |

---

## 10. CHARACTER DATA

| File | Purpose |
|------|---------|
| `character_creation_data.json` | Master creation rules |
| `character_species.json` | Species definitions |
| `character_backgrounds.json` | Background details |
| `character_skills.json` | Skill definitions |
| `psionic_powers.json` | Psionic abilities |
| `skill_proression.json` | Skill advancement |

---

## 11. WORLD & LOCATIONS

| File | Purpose |
|------|---------|
| `planet_types.json` | Planet classifications |
| `location_types.json` | Location categories |
| `world_traits.json` | World modifiers (16 traits: Haze, Overgrown, Industrial, etc.) |
| `patron_types.json` | Patron categories |

---

## 12. COMBAT & STATUS

| File | Purpose |
|------|---------|
| `battle_rules.json` | Combat rule reference |
| `injury_table.json` | Injury outcomes |
| `loot_tables.json` | Loot generation |
| `status_effects.json` | Buffs/debuffs |

---

## 13. EVENTS & NARRATIVE

| File | Purpose |
|------|---------|
| `event_tables.json` | Random events |
| `expanded_connections.json` | NPC relationships |
| `expanded_quest_progressions.json` | Story progression |

---

## 14. TUTORIALS (`data/Tutorials/`)

| File | Purpose |
|------|---------|
| `quick_start_tutorial.json` | New player guide |
| `advanced_tutorial.json` | Advanced mechanics |

---

## 15. SYSTEM CONFIG (`data/autoload/`)

| File | Purpose |
|------|---------|
| `system_config.json` | Global settings |

---

## 16. HELP & UI

| File | Purpose |
|------|---------|
| `help_text.json` | In-game help content |

---

## 📊 File Count Summary

| Category | Count |
|----------|-------|
| RulesReference | 18 |
| Character Creation | 8 |
| Campaign Tables | 12 |
| Mission Tables | 13 |
| Mission Templates | 3 |
| Battlefield | 11 |
| Enemies | 5 |
| Equipment | 6 |
| Character | 6 |
| World | 4 |
| Combat | 4 |
| Events | 3 |
| Tutorials | 2 |
| Config | 2 |
| **Total** | **~95** |

---

## 🔗 Related Files

- `docs/IMPLEMENTATION_CHECKLIST.md` - Implementation status
- `docs/gameplay/rules/core_rules.md` - Source rulebook
- `src/core/data/DataManager.gd` - Data loading system
- `src/core/data/GameDataManager.gd` - Equipment/armor/weapon/gear/world_traits loader
- `src/core/managers/GameDataManager.gd` - Full data manager with JSON loading

## 📝 Path Constants (Feb 2026 - Verified Correct)

All data file path constants point to `res://data/` (root data directory):
- `ARMOR_DATA_PATH = "res://data/armor.json"`
- `WEAPON_DATA_PATH = "res://data/weapons.json"`
- `GEAR_DATA_PATH = "res://data/gear_database.json"`
- `WORLD_TRAITS_PATH = "res://data/world_traits.json"`
- `GearDatabase._load_gear_data() = "res://data/gear_database.json"`
