# Rules Accuracy Audit Checklist

**Last Updated**: 2026-03-22
**Purpose**: Systematic verification that ALL game data values match the Five Parsecs From Home Core Rules book
**Status**: NOT STARTED — 0/580+ values verified

> **CRITICAL — BLOCKS PUBLIC RELEASE**: This project nearly shipped with AI-hallucinated game data. All numeric values (stats, costs, ranges, probabilities, D100 table boundaries) must be verified against the physical Core Rules book before any public release.

---

## How to Use This Document

This checklist is organized by **Core Rules book chapter order** so a human can read the book linearly and check off items.

### Workflow

1. **Internal Consistency First** — Run automated cross-checks between JSON files and GDScript constants (see Appendix D: MCP Scripts). Fix internal inconsistencies before book verification.
2. **Book Verification** — Open the Core Rules to the referenced page, compare each value.
3. **Mark Status** — For each item:
   - `UNVERIFIED` — Not yet checked against book
   - `VERIFIED` — Matches Core Rules exactly
   - `INCORRECT` — Does NOT match Core Rules (record book value in Notes)
   - `FIXED` — Was INCORRECT, now corrected to match Core Rules
   - `GAME_BALANCE` — Intentional deviation from Core Rules (must be documented)
   - `N/A` — Not from Core Rules (UI text, tutorials, etc.)
4. **Record Verifier** — Initial and date each verification

### Priority Order

- **P0** (verify first): Weapon stats, species stats, injury tables, economy values — players see these directly
- **P1**: Event table D100 ranges, loot tables, enemy stats — affect gameplay but less visible
- **P2**: Mission descriptions, flavor text, world traits — lower gameplay impact

---

## Progress Summary

| Domain | JSON Files | GDScript Files | Est. Values | Verified | Incorrect | Status |
|--------|-----------|---------------|-------------|----------|-----------|--------|
| Weapons & Equipment | 4 | 1 | ~150 | 0 | 0 | NOT STARTED |
| Species & Characters | 4 | 0 | ~80 | 0 | 0 | NOT STARTED |
| Injuries | 1 | 1 | ~25 | 0 | 0 | NOT STARTED |
| Loot Tables | 2 | 1 | ~60 | 0 | 0 | NOT STARTED |
| Economy & Upkeep | 1 | 2 | ~30 | 0 | 0 | NOT STARTED |
| Campaign Events | 2 | 0 | ~100 | 0 | 0 | NOT STARTED |
| Travel & World | 2 | 0 | ~40 | 0 | 0 | NOT STARTED |
| Battle & Enemies | 5 | 1 | ~60 | 0 | 0 | NOT STARTED |
| Missions | 6 | 0 | ~50 | 0 | 0 | NOT STARTED |
| Ships | 2 | 0 | ~20 | 0 | 0 | NOT STARTED |
| Advancement | 1 | 1 | ~20 | 0 | 0 | NOT STARTED |
| Victory Conditions | 1 | 0 | ~10 | 0 | 0 | NOT STARTED |
| Compendium/DLC | 15+ | 0 | ~100 | 0 | 0 | NOT STARTED |
| **TOTAL** | **~46** | **~7** | **~745+** | **0** | **0** | **NOT STARTED** |

---

## Chapter 1: Character Creation (Core Rules pp.15-37)

### 1A: Species Stats (pp.15-22)

**Data Sources**: `data/character_species.json`, `data/RulesReference/SpeciesList.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1A-001 | Human base stats | p.15 | R:1, S:4, C:0, T:3, Sv:0, Luck >1 allowed | UNVERIFIED | | |
| 1A-002 | Engineer stats | p.16 | Stat modifiers, T_max=4, special rules | UNVERIFIED | | |
| 1A-003 | K'Erin stats | p.17 | Stat modifiers, brawl reroll rule | UNVERIFIED | | |
| 1A-004 | Soulless stats | p.18 | Stat modifiers, 6+ save, no XP restrictions | UNVERIFIED | | |
| 1A-005 | Precursor stats | p.19 | Stat modifiers, 2 character events rule | UNVERIFIED | | |
| 1A-006 | Feral stats | p.20 | R+1, T-1 (or equivalent), special rules | UNVERIFIED | | |
| 1A-007 | Swift stats | p.21 | S+2 (Phase 43 fix), special rules | UNVERIFIED | | |
| 1A-008 | Bot stats | p.22 | No XP, Bot upgrade system, restrictions | UNVERIFIED | | |
| 1A-009 | Strange Characters (18 types) | p.32 | D100 table ranges, each type's modifiers | UNVERIFIED | | |

### 1B: Background Table (p.33)

**Data Sources**: `data/character_creation_tables/background_table.json`, `data/character_backgrounds.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1B-001 | Background D100 ranges | p.33 | All roll ranges match book | UNVERIFIED | | |
| 1B-002 | Background stat modifiers | p.33 | Each background's stat bonus/penalty | UNVERIFIED | | |
| 1B-003 | Background count | p.33 | Total number of backgrounds matches book | UNVERIFIED | | |

### 1C: Motivation Table (p.34)

**Data Sources**: `data/character_creation_tables/motivation_table.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1C-001 | Motivation D66 ranges | p.34 | All roll ranges match book | UNVERIFIED | | |
| 1C-002 | WEALTH bonus | p.34 | +1D6 credits at finalization (BUG-037 fixed) | UNVERIFIED | | |
| 1C-003 | FAME bonus | p.34 | +1 story point at finalization | UNVERIFIED | | |
| 1C-004 | SURVIVAL bonus | p.34 | Correct stat bonus | UNVERIFIED | | |
| 1C-005 | KNOWLEDGE bonus | p.34 | +1 savvy | UNVERIFIED | | |

### 1D: Class Table (p.35)

**Data Sources**: `data/character_creation_tables/class_table.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1D-001 | Class D66 ranges | p.35 | All roll ranges match book | UNVERIFIED | | |
| 1D-002 | Class stat modifiers | p.35 | Each class's equipment/credit grants | UNVERIFIED | | |
| 1D-003 | Class count | p.35 | Total number of classes matches book | UNVERIFIED | | |

### 1E: Starting Equipment (p.36)

**Data Sources**: `data/character_creation_tables/equipment_tables.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1E-001 | Starting weapon table | p.36 | D100 ranges and weapon assignments | UNVERIFIED | | |
| 1E-002 | Starting gear table | p.36 | D100 ranges and gear assignments | UNVERIFIED | | |

### 1F: Connections (p.37)

**Data Sources**: `data/character_creation_tables/connections_table.json`, `data/expanded_connections.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1F-001 | Patron connections | p.37 | Generation rules, probabilities | UNVERIFIED | | |
| 1F-002 | Rival connections | p.37 | Generation rules, probabilities | UNVERIFIED | | |

### 1G: Character Creation Bonuses

**Data Sources**: `data/character_creation_bonuses.json`, `data/character_creation_data.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 1G-001 | Creation bonus values | p.33-35 | All stat/credit bonuses per background/class/motivation | UNVERIFIED | | |

---

## Chapter 2: Equipment & Weapons (Core Rules pp.40-58)

### 2A: Weapon Stats Table (p.50)

**Data Sources**: `data/weapons.json`, `data/equipment_database.json`, `src/core/systems/LootSystemConstants.gd`

> **WARNING**: Known internal inconsistencies between these 3 sources — see Appendix C.

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 2A-001 | All weapon names | p.50 | Names match book exactly | UNVERIFIED | | |
| 2A-002 | All weapon ranges | p.50 | Range in inches for each weapon | UNVERIFIED | | |
| 2A-003 | All weapon shots | p.50 | Shots per weapon | UNVERIFIED | | |
| 2A-004 | All weapon damage | p.50 | Damage modifier per weapon | UNVERIFIED | | |
| 2A-005 | All weapon traits | p.50 | Trait list per weapon | UNVERIFIED | | |
| 2A-006 | Weapon count | p.50 | Total number matches book | UNVERIFIED | | |
| 2A-007 | Weapon categories | p.50 | slug/energy/melee/special/grenade assignments | UNVERIFIED | | |

### 2B: Armor (pp.44-45)

**Data Sources**: `data/armor.json`, `data/equipment_database.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 2B-001 | Armor types | pp.44-45 | All types listed in book present | UNVERIFIED | | |
| 2B-002 | Armor save values | pp.44-45 | Save modifier per type | UNVERIFIED | | |
| 2B-003 | Armor costs | pp.44-45 | Purchase price per type | UNVERIFIED | | |

### 2C: Gear & Consumables (pp.45-47)

**Data Sources**: `data/gear_database.json`, `data/equipment_database.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 2C-001 | Gear items list | pp.45-47 | All items from book present | UNVERIFIED | | |
| 2C-002 | Gear effects | pp.45-47 | Effect descriptions match book | UNVERIFIED | | |
| 2C-003 | Gear costs | pp.45-47 | Prices match book | UNVERIFIED | | |

### 2D: Implants (p.132)

**Data Sources**: `data/implants.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 2D-001 | Implant types (6) | p.132 | All 6 types present | UNVERIFIED | | |
| 2D-002 | Implant effects | p.132 | Stat bonuses match book | UNVERIFIED | | |
| 2D-003 | Max implants per char | p.132 | Max 3 rule | UNVERIFIED | | |

### 2E: Weapon Trait Definitions

**Data Sources**: `data/weapons.json` trait arrays, `data/keywords.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 2E-001 | Trait names | p.50+ | All trait names match book | UNVERIFIED | | |
| 2E-002 | Trait effects | p.50+ | Trait mechanic descriptions | UNVERIFIED | | |

### 2F: Onboard Items

**Data Sources**: `data/onboard_items.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 2F-001 | Onboard item list | p.59+ | Items, effects, costs | UNVERIFIED | | |

---

## Chapter 3: Ships (Core Rules pp.59-65)

### 3A: Ship Types & Hull

**Data Sources**: `data/ships.json`, `data/ship_components.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 3A-001 | Ship type names | p.60 | All types match book | UNVERIFIED | | |
| 3A-002 | Hull point ranges | p.60 | 6-14 range (NOT 20-35) | UNVERIFIED | | |
| 3A-003 | Starting ship debt | p.62 | 0-5 range (NOT 12-38) | UNVERIFIED | | |
| 3A-004 | Ship component types | p.63 | All components from book | UNVERIFIED | | |
| 3A-005 | Ship traits | p.60-61 | Trait list and effects | UNVERIFIED | | |

---

## Chapter 4: Campaign Turn — Travel (Core Rules pp.70-79)

### 4A: Travel Event Table D100 (pp.72-75)

**Data Sources**: `data/event_tables.json` (travel_events section, 16 events with D100 ranges), `src/core/campaign/phases/TravelPhase.gd` (loader)

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 4A-001 | D100 roll ranges | pp.72-75 | All 16 event boundary values | UNVERIFIED | | |
| 4A-002 | Event names | pp.72-75 | All 16 event names match book | UNVERIFIED | | |
| 4A-003 | Event effects | pp.72-75 | Mechanical effects of each event | UNVERIFIED | | |

### 4B: World Traits D100 (p.77)

**Data Sources**: `data/world_traits.json`, `src/core/campaign/TravelPhase.gd` (hardcoded D100 ranges)

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 4B-001 | World trait D100 ranges | p.77 | All ranges (Frontier 1-15, Trade Hub 16-30, etc.) | UNVERIFIED | | |
| 4B-002 | World trait effects | p.77 | Each trait's mechanical effect | UNVERIFIED | | |

### 4C: Travel Costs & Rules

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 4C-001 | Fuel cost | p.71 | 5 credits (or book value) | UNVERIFIED | | |
| 4C-002 | License costs | p.79 | D6: 1-2=none, 3-4=basic(10cr), 5-6=full(20cr) | UNVERIFIED | | |
| 4C-003 | Rival following threshold | p.78 | D6 per rival, follows on 1-3 | UNVERIFIED | | |
| 4C-004 | Invasion escape roll | p.70 | 2D6, 8+ to escape | UNVERIFIED | | |

---

## Chapter 5: World Phase — Upkeep (Core Rules pp.80-86)

### 5A: Upkeep Costs

**Data Sources**: `src/core/systems/FiveParsecsConstants.gd`, `src/core/world/WorldEconomyManager.gd`

> **WARNING**: Known conflict — `FiveParsecsConstants.ECONOMY.base_upkeep = 1` vs `WorldEconomyManager.BASE_UPKEEP_COST = 100`. See Appendix C.

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 5A-001 | Base upkeep per crew member | p.80 | Cost per member per turn | UNVERIFIED | | |
| 5A-002 | Ship maintenance cost | p.80 | Maintenance amount | UNVERIFIED | | |
| 5A-003 | Ship debt interest | p.80 | +1/+2 per turn rate | UNVERIFIED | | |

### 5B: Crew Task Thresholds (pp.82-83)

**Data Sources**: `src/core/campaign/WorldPhase.gd`, `data/campaign_tables/crew_tasks/crew_task_resolution.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 5B-001 | Find Patron threshold | p.82 | 2D6 ≥ 7 (or book value) | UNVERIFIED | | |
| 5B-002 | Recruit threshold | p.82 | 1D6 ≥ 5 (33% chance) | UNVERIFIED | | |
| 5B-003 | Track threshold | p.83 | 1D6 ≥ 4 (50% chance) | UNVERIFIED | | |
| 5B-004 | Explore D100 ranges | p.83 | ≤20 nothing, ≤40 credits, ≤60 equipment, ≤80 rumor, >80 special | UNVERIFIED | | |
| 5B-005 | Trade D6 table | p.82 | All 6 outcomes | UNVERIFIED | | |
| 5B-006 | Train XP amount | p.82 | XP gained from training | UNVERIFIED | | |

### 5C: Patron Jobs & Opportunity Missions

**Data Sources**: `data/campaign_tables/world_phase/patron_jobs.json`, `data/missions/opportunity_missions.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 5C-001 | Patron job payment ranges | p.84 | Payment formula/ranges | UNVERIFIED | | |
| 5C-002 | Opportunity mission table | p.84 | Mission generation rules | UNVERIFIED | | |
| 5C-003 | Quest trigger roll | p.86 | D6 threshold for quest rumors | UNVERIFIED | | |

---

## Chapter 6: Battle Setup (Core Rules pp.87-95)

### 6A: Enemy Generation

**Data Sources**: `src/core/systems/EnemyGenerator.gd`, `data/enemy_types.json`, `data/enemy_presets.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 6A-001 | Enemy count formula | p.88 | Crew 6=2D6 pick HIGH, 5=1D6, 4=2D6 pick LOW | UNVERIFIED | | |
| 6A-002 | Enemy category mapping | pp.63-65 | Mission type → enemy category | UNVERIFIED | | |
| 6A-003 | Enemy stat blocks | pp.63-65 | All enemy type stats (combat, toughness, etc.) | UNVERIFIED | | |
| 6A-004 | Unique individual roll | p.88 | 2D6 ≥ 9 (standard), modifiers per difficulty | UNVERIFIED | | |
| 6A-005 | Elite enemy types | p.88+ | `data/elite_enemy_types.json` values | UNVERIFIED | | |

### 6B: Deployment & Initiative

**Data Sources**: `data/deployment_conditions.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 6B-001 | Deployment condition types | p.89 | All conditions from book | UNVERIFIED | | |
| 6B-002 | Initiative roll | p.90 | D6, crew first if ≥ 4 | UNVERIFIED | | |
| 6B-003 | Seize initiative modifiers | p.90 | Difficulty-based modifiers | UNVERIFIED | | |

### 6C: Combat Resolution (pp.91-95)

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 6C-001 | To-hit formula | pp.91-95 | Attack roll mechanics | UNVERIFIED | | |
| 6C-002 | Damage resolution | pp.91-95 | Damage vs toughness | UNVERIFIED | | |
| 6C-003 | Cover mechanics | pp.91-95 | Cover bonus values | UNVERIFIED | | |
| 6C-004 | Morale/panic rules | pp.91-95 | Morale check triggers and thresholds | UNVERIFIED | | |

---

## Chapter 7: Post-Battle (Core Rules pp.96-102)

### 7A: Payment & Rewards

**Data Sources**: `src/core/campaign/BattlePhase.gd`, `src/core/campaign/GameCampaignManager.gd`

> **WARNING**: GameCampaignManager.gd has hardcoded reward values (500-1500 credits for patron jobs, 1000-2500 for missions) with no Core Rules page references.

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 7A-001 | Base mission pay | p.97 | Payment formula | UNVERIFIED | | |
| 7A-002 | Danger pay bonus | p.97 | Difficulty multiplier | UNVERIFIED | | |
| 7A-003 | Patron job payments | p.84 | Credit ranges for patron jobs | UNVERIFIED | | |

### 7B: Battlefield Finds & Loot

**Data Sources**: `data/loot/battlefield_finds.json`, `data/loot_tables.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 7B-001 | Battlefield finds D100 | p.66 | Roll ranges and outcomes | UNVERIFIED | | |
| 7B-002 | Invasion check | p.98 | 2D6, 9+ threshold | UNVERIFIED | | |

### 7C: Campaign Events D100 (pp.100-101)

**Data Sources**: `data/event_tables.json` (or `campaign_events.json`)

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 7C-001 | Campaign event D100 ranges | pp.100-101 | All 40 entry roll boundaries | UNVERIFIED | | |
| 7C-002 | Campaign event effects | pp.100-101 | Mechanical outcome per event | UNVERIFIED | | |
| 7C-003 | Campaign event count | pp.100-101 | Total entries matches book | UNVERIFIED | | |

### 7D: Character Events

**Data Sources**: `data/event_tables.json` (or `character_events.json`)

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 7D-001 | Character event D100 ranges | pp.101-102 | All 42 entry roll boundaries | UNVERIFIED | | |
| 7D-002 | Character event effects | pp.101-102 | Mechanical outcome per event | UNVERIFIED | | |
| 7D-003 | Bot/Soulless exclusion | pp.101-102 | Correct exclusion rule | UNVERIFIED | | |
| 7D-004 | Precursor double-roll | pp.101-102 | Roll twice, pick preferred | UNVERIFIED | | |

### 7E: XP Distribution

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 7E-001 | Base XP per crew | pp.89-90 | 1 base XP (or book value) | UNVERIFIED | | |
| 7E-002 | Victory bonus XP | pp.89-90 | +2 XP for victory (or book value) | UNVERIFIED | | |
| 7E-003 | XP source count | pp.89-90 | 7 XP sources as documented | UNVERIFIED | | |

---

## Chapter 8: Injuries (Core Rules pp.122-124)

### 8A: Injury Table D100

**Data Sources**: `data/injury_table.json`, `src/core/systems/InjurySystemConstants.gd`

> **WARNING**: Page reference conflict — `injury_table.json` says "p.122" vs `InjurySystemConstants.gd` says "p.94-95". See Appendix C.

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 8A-001 | Fatal range | p.122-123 | 1-15 (or book value) | UNVERIFIED | | |
| 8A-002 | All 8 injury type ranges | p.122-123 | All D100 boundaries | UNVERIFIED | | |
| 8A-003 | Recovery times | p.124 | 0-6 turns per injury type | UNVERIFIED | | |

### 8B: Medical Treatment

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 8B-001 | Treatment types (6) | p.124 | Field through Cybernetic | UNVERIFIED | | |
| 8B-002 | Treatment costs | p.124 | Credit cost per type | UNVERIFIED | | |

---

## Chapter 9: Advancement (Core Rules pp.128-132)

### 9A: XP Costs

**Data Sources**: `src/core/systems/CharacterAdvancementConstants.gd`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 9A-001 | XP cost per stat | p.128 | 5-10 XP per stat (exact values) | UNVERIFIED | | |
| 9A-002 | Max stat values | p.128 | Per species caps | UNVERIFIED | | |
| 9A-003 | Training paths (9 types) | p.129 | Path names and effects | UNVERIFIED | | |
| 9A-004 | Bot upgrade costs | p.131 | Credit-based upgrade costs | UNVERIFIED | | |

---

## Chapter 10: Loot Tables (Core Rules pp.66-72)

### 10A: Main Loot System

**Data Sources**: `data/loot_tables.json`, `src/core/systems/LootSystemConstants.gd`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 10A-001 | Battlefield finds D100 | p.66 | All ranges and outcomes | UNVERIFIED | | |
| 10A-002 | Main loot table D100 | pp.70-72 | All ranges and category assignments | UNVERIFIED | | |
| 10A-003 | Weapon subtable | pp.70-72 | Weapon distribution | UNVERIFIED | | |
| 10A-004 | Gear subtable | pp.70-72 | Gear distribution | UNVERIFIED | | |
| 10A-005 | Odds & ends subtable | pp.70-72 | Misc loot distribution | UNVERIFIED | | |
| 10A-006 | Rewards subtable | pp.70-72 | Credit/item rewards | UNVERIFIED | | |

---

## Chapter 11: Economy

### 11A: Starting Values

**Data Sources**: `src/core/systems/FiveParsecsConstants.gd`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 11A-001 | Starting credits | p.22 | Initial credit amount | UNVERIFIED | | |
| 11A-002 | Starting supplies | p.22 | Initial supply amount | UNVERIFIED | | |
| 11A-003 | Starting crew size | p.22 | Number of starting crew | UNVERIFIED | | |

### 11B: Trade & Sell Values

**Data Sources**: `src/core/equipment/EquipmentManager.gd`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 11B-001 | Equipment sell formula | p.85 | Condition-aware pricing | UNVERIFIED | | |
| 11B-002 | Equipment purchase prices | p.50 | Buy prices from book | UNVERIFIED | | |
| 11B-003 | Ship repair cost | p.81 | Cost per hull point | UNVERIFIED | | |

---

## Chapter 12: Enemy Data

### 12A: Enemy Type Stat Blocks

**Data Sources**: `data/enemy_types.json`, `data/enemies/*.json`, `data/RulesReference/Bestiary.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 12A-001 | Criminal Elements stats | pp.63-65 | Combat, toughness, weapons | UNVERIFIED | | |
| 12A-002 | Hired Muscle stats | pp.63-65 | Combat, toughness, weapons | UNVERIFIED | | |
| 12A-003 | Roving Threats stats | pp.63-65 | Combat, toughness, weapons | UNVERIFIED | | |
| 12A-004 | Interested Parties stats | pp.63-65 | Combat, toughness, weapons | UNVERIFIED | | |
| 12A-005 | Enemy AI behavior | pp.63-65 | AI type per enemy category | UNVERIFIED | | |

### 12B: Unique Individuals

**Data Sources**: `data/campaign_tables/unique_individuals.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 12B-001 | Unique individual types | p.88+ | All types from book | UNVERIFIED | | |
| 12B-002 | Unique individual stats | p.88+ | Stats per type | UNVERIFIED | | |

---

## Chapter 13: Missions

### 13A: Mission Types & Rewards

**Data Sources**: `data/missions/*.json`, `data/mission_tables/*.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 13A-001 | Mission type list | p.87 | All types from book | UNVERIFIED | | |
| 13A-002 | Mission reward table | p.97 | Credits per mission type | UNVERIFIED | | |
| 13A-003 | Difficulty scaling | p.87 | How difficulty affects mission params | UNVERIFIED | | |

---

## Chapter 14: Victory Conditions (Core Rules p.134)

**Data Sources**: `data/victory_conditions.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 14A-001 | Victory condition types | p.134 | All 18+ types from book | UNVERIFIED | | |
| 14A-002 | Victory thresholds | p.134 | Turn counts, kill counts, etc. | UNVERIFIED | | |

---

## Chapter 15: Difficulty Modifiers

### 15A: Difficulty Scaling

**Data Sources**: `data/RulesReference/DifficultyOptions.json`, `src/core/systems/FiveParsecsConstants.gd`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 15A-001 | EASY modifiers | p.? | XP bonus, story points, enemy reduction | UNVERIFIED | | |
| 15A-002 | NORMAL modifiers | p.? | Baseline values | UNVERIFIED | | |
| 15A-003 | CHALLENGING modifiers | p.? | Enemy reroll rule | UNVERIFIED | | |
| 15A-004 | HARDCORE modifiers | p.? | +1 enemy, -1 story, rival resistance | UNVERIFIED | | |
| 15A-005 | INSANITY modifiers | p.? | Story disabled, forced unique, +3 invasion | UNVERIFIED | | |

---

## Compendium / DLC Data

### C1: Trailblazer's Toolkit

**Data Sources**: Various DLC-gated JSON files

| ID | Item | Source | What to Verify | Status | By | Date |
|----|------|--------|---------------|--------|-----|------|
| C1-001 | Krag species stats | Compendium | All stat modifiers | UNVERIFIED | | |
| C1-002 | Skulker species stats | Compendium | All stat modifiers | UNVERIFIED | | |
| C1-003 | Psionic powers (12/6 XP) | Compendium | Power names, costs, effects | UNVERIFIED | | |
| C1-004 | Bot upgrades | Compendium | Upgrade types and costs | UNVERIFIED | | |

### C2: Freelancer's Handbook

| ID | Item | Source | What to Verify | Status | By | Date |
|----|------|--------|---------------|--------|-----|------|
| C2-001 | Expanded difficulty toggles | FH | Toggle names and effects | UNVERIFIED | | |
| C2-002 | Expanded missions | FH | Mission types and rewards | UNVERIFIED | | |

### C3: Fixer's Guidebook

| ID | Item | Source | What to Verify | Status | By | Date |
|----|------|--------|---------------|--------|-----|------|
| C3-001 | Stealth missions | FG | Mission mechanics | UNVERIFIED | | |
| C3-002 | Street missions | FG | Mission mechanics | UNVERIFIED | | |
| C3-003 | Salvage missions | FG | Mission mechanics | UNVERIFIED | | |
| C3-004 | Expanded loans | FG | Loan amounts, interest rates | UNVERIFIED | | |

### C4: Bug Hunt (Compendium)

**Data Sources**: `data/bug_hunt/` (15 JSON files)

| ID | Item | Source | What to Verify | Status | By | Date |
|----|------|--------|---------------|--------|-----|------|
| C4-001 | Bug Hunt weapons | BH Compendium | `bug_hunt_weapons.json` stats | UNVERIFIED | | |
| C4-002 | Bug Hunt armor | BH Compendium | `bug_hunt_armor.json` stats | UNVERIFIED | | |
| C4-003 | Bug Hunt enemies | BH Compendium | `bug_hunt_enemies.json` stat blocks | UNVERIFIED | | |
| C4-004 | Alien subtypes | BH Compendium | `bug_hunt_alien_subtypes.json` | UNVERIFIED | | |
| C4-005 | Alien leaders | BH Compendium | `bug_hunt_alien_leaders.json` stats | UNVERIFIED | | |
| C4-006 | Spawn rules | BH Compendium | `bug_hunt_spawn_rules.json` probabilities | UNVERIFIED | | |
| C4-007 | Character creation | BH Compendium | `bug_hunt_character_creation.json` | UNVERIFIED | | |
| C4-008 | Special assignments | BH Compendium | `bug_hunt_special_assignments.json` | UNVERIFIED | | |
| C4-009 | Missions | BH Compendium | `bug_hunt_missions.json` | UNVERIFIED | | |
| C4-010 | Post-battle | BH Compendium | `bug_hunt_post_battle.json` | UNVERIFIED | | |

---

## Appendix A: JSON File Verification Status

All JSON data files in `data/` with their rules-data status.

| # | File | Contains Rules Data | Status |
|---|------|:-------------------:|--------|
| 1 | `data/weapons.json` | Yes | UNVERIFIED |
| 2 | `data/equipment_database.json` | Yes | UNVERIFIED |
| 3 | `data/armor.json` | Yes | UNVERIFIED |
| 4 | `data/gear_database.json` | Yes | UNVERIFIED |
| 5 | `data/implants.json` | Yes | UNVERIFIED |
| 6 | `data/onboard_items.json` | Yes | UNVERIFIED |
| 7 | `data/character_species.json` | Yes | UNVERIFIED |
| 8 | `data/character_backgrounds.json` | Yes | UNVERIFIED |
| 9 | `data/character_creation_data.json` | Yes | UNVERIFIED |
| 10 | `data/character_creation_bonuses.json` | Yes | UNVERIFIED |
| 11 | `data/character_skills.json` | Yes | UNVERIFIED |
| 12 | `data/injury_table.json` | Yes | UNVERIFIED |
| 13 | `data/loot_tables.json` | Yes | UNVERIFIED |
| 14 | `data/enemy_types.json` | Yes | UNVERIFIED |
| 15 | `data/enemy_presets.json` | Yes | UNVERIFIED |
| 16 | `data/elite_enemy_types.json` | Yes | UNVERIFIED |
| 17 | `data/event_tables.json` | Yes | UNVERIFIED |
| 18 | `data/ships.json` | Yes | UNVERIFIED |
| 19 | `data/ship_components.json` | Yes | UNVERIFIED |
| 20 | `data/victory_conditions.json` | Yes | UNVERIFIED |
| 21 | `data/deployment_conditions.json` | Yes | UNVERIFIED |
| 22 | `data/world_traits.json` | Yes | UNVERIFIED |
| 23 | `data/patron_types.json` | Yes | UNVERIFIED |
| 24 | `data/planet_types.json` | Yes | UNVERIFIED |
| 25 | `data/location_types.json` | Yes | UNVERIFIED |
| 26 | `data/psionic_powers.json` | Yes | UNVERIFIED |
| 27 | `data/status_effects.json` | Yes | UNVERIFIED |
| 28 | `data/red_zone_jobs.json` | Yes | UNVERIFIED |
| 29 | `data/black_zone_jobs.json` | Yes | UNVERIFIED |
| 30 | `data/notable_sights.json` | Yes | UNVERIFIED |
| ~~31~~ | ~~`data/expanded_missions.json`~~ | ~~Duplicate~~ | DELETED (duplicate of RulesReference/ExpandedMissions.json) |
| 32 | `data/expanded_connections.json` | Yes (DLC) | UNVERIFIED |
| 33 | `data/expanded_quest_progressions.json` | Yes (DLC) | UNVERIFIED |
| 34 | `data/mission_generation_data.json` | Yes | UNVERIFIED |
| 35 | `data/mission_templates.json` | Yes | UNVERIFIED |
| 36 | `data/campaign_rules.json` | Yes | UNVERIFIED |
| 37 | `data/campaign_config.json` | Partial | UNVERIFIED |
| 38 | `data/story_events.json` | Yes | UNVERIFIED |
| 39 | `data/galactic_war/war_progress_tracks.json` | Yes | UNVERIFIED |
| 40 | `data/character_creation_tables/background_table.json` | Yes | UNVERIFIED |
| 41 | `data/character_creation_tables/class_table.json` | Yes | UNVERIFIED |
| 42 | `data/character_creation_tables/motivation_table.json` | Yes | UNVERIFIED |
| 43 | `data/character_creation_tables/connections_table.json` | Yes | UNVERIFIED |
| 44 | `data/character_creation_tables/equipment_tables.json` | Yes | UNVERIFIED |
| 45 | `data/character_creation_tables/background_events.json` | Yes | UNVERIFIED |
| 46 | `data/character_creation_tables/quirks_table.json` | Yes | UNVERIFIED |
| 47 | `data/character_creation_tables/flavor_table.json` | No (flavor) | N/A |
| 48 | `data/campaign_tables/unique_individuals.json` | Yes | UNVERIFIED |
| ~~49~~ | ~~`data/campaign_tables/campaign_phases.json`~~ | ~~Not Core Rules~~ | DELETED (generic progression, not game data) |
| ~~50~~ | ~~`data/campaign_tables/phase_events.json`~~ | ~~Not Core Rules~~ | DELETED (generic events, not game data) |
| 51 | `data/campaign_tables/world_phase/patron_jobs.json` | Yes | UNVERIFIED |
| 52 | `data/campaign_tables/world_phase/crew_task_modifiers.json` | Yes | UNVERIFIED |
| 53 | `data/campaign_tables/crew_tasks/crew_task_resolution.json` | Yes | UNVERIFIED |
| 54 | `data/campaign_tables/crew_tasks/trade_results.json` | Yes | UNVERIFIED |
| 55 | `data/campaign_tables/crew_tasks/exploration_events.json` | Yes | UNVERIFIED |
| 56 | `data/campaign_tables/crew_tasks/recruitment_opportunities.json` | Yes | UNVERIFIED |
| 57 | `data/campaign_tables/crew_tasks/training_outcomes.json` | Yes | UNVERIFIED |
| 58 | `data/loot/battlefield_finds.json` | Yes | UNVERIFIED |
| 59 | `data/missions/mission_generation_params.json` | Yes | UNVERIFIED |
| 60 | `data/missions/opportunity_missions.json` | Yes | UNVERIFIED |
| 61 | `data/missions/patron_missions.json` | Yes | UNVERIFIED |
| 62 | `data/mission_tables/mission_types.json` | Yes | UNVERIFIED |
| 63 | `data/mission_tables/mission_titles.json` | No (flavor) | N/A |
| 64 | `data/mission_tables/mission_descriptions.json` | No (flavor) | N/A |
| 65 | `data/mission_tables/mission_difficulty.json` | Yes | UNVERIFIED |
| 66 | `data/mission_tables/mission_rewards.json` | Yes | UNVERIFIED |
| 67 | `data/mission_tables/mission_events.json` | Yes | UNVERIFIED |
| 68 | `data/mission_tables/credit_rewards.json` | Yes | UNVERIFIED |
| 69 | `data/mission_tables/bonus_objectives.json` | Yes | UNVERIFIED |
| 70 | `data/mission_tables/bonus_rewards.json` | Yes | UNVERIFIED |
| 71 | `data/mission_tables/deployment_points.json` | Yes | UNVERIFIED |
| 72 | `data/mission_tables/reward_items.json` | Yes | UNVERIFIED |
| 73 | `data/mission_tables/rival_involvement.json` | Yes | UNVERIFIED |
| 74 | `data/enemies/corporate_security_data.json` | Yes | UNVERIFIED |
| 75 | `data/enemies/pirates_data.json` | Yes | UNVERIFIED |
| 76 | `data/enemies/wildlife_data.json` | Yes | UNVERIFIED |
| 77 | `data/battlefield/companion_config.json` | No (config) | N/A |
| 78 | `data/battlefield/features/common_features.json` | Yes | UNVERIFIED |
| 79 | `data/battlefield/features/natural_features.json` | Yes | UNVERIFIED |
| 80 | `data/battlefield/features/urban_features.json` | Yes | UNVERIFIED |
| 81 | `data/battlefield/rules/deployment_rules.json` | Yes | UNVERIFIED |
| 82 | `data/battlefield/rules/validation_rules.json` | No (config) | N/A |
| 83 | `data/battlefield/objectives/objective_markers.json` | Yes | UNVERIFIED |
| 84 | `data/battlefield_tables/terrain_types.json` | Yes | UNVERIFIED |
| 85 | `data/battlefield_tables/hazard_features.json` | Yes | UNVERIFIED |
| 86 | `data/battlefield_tables/cover_elements.json` | Yes | UNVERIFIED |
| 87 | `data/battlefield_tables/strategic_points.json` | Yes | UNVERIFIED |
| 88-102 | `data/bug_hunt/*.json` (15 files) | Yes (Compendium) | UNVERIFIED |
| 103-108 | `data/story_track_missions/mission_01-06*.json` | Yes | UNVERIFIED |
| 109-122 | `data/RulesReference/*.json` (14 files) | Yes (reference) | UNVERIFIED |
| 123-124 | `data/Tutorials/*.json` (2 files) | No (tutorial) | N/A |
| 125 | `data/tutorial/story_companion_tutorials.json` | No (tutorial) | N/A |
| 126 | `data/help_text.json` | No (UI text) | N/A |
| 127 | `data/help_context_map.json` | No (UI config) | N/A |
| 128 | `data/keywords.json` | Partial (trait defs) | UNVERIFIED |
| ~~129~~ | ~~`data/shaders.json`~~ | ~~Not game data~~ | DELETED (scraped shader catalog, not game data) |
| 130 | `data/resources.json` | Partial | UNVERIFIED |
| 131 | `data/autoload/system_config.json` | No (config) | N/A |

**Summary**: ~115 files contain rules data requiring verification, ~16 files are N/A (UI, config, tutorials).

---

## Appendix B: GDScript Hardcoded Constants

| # | File | Constants Requiring Verification | Status |
|---|------|----------------------------------|--------|
| 1 | `src/core/systems/FiveParsecsConstants.gd` | CREW_TASK_DIFFICULTIES, ECONOMY (13 values), COMBAT (5 values), MISSIONS (5 values) | UNVERIFIED |
| 2 | `src/core/systems/LootSystemConstants.gd` | BATTLEFIELD_FINDS_RANGES, MAIN_LOOT_RANGES, WEAPON_SUBTABLE_RANGES, GEAR_SUBTABLE_RANGES, ODDS_AND_ENDS_RANGES, REWARDS_SUBTABLE_RANGES, WEAPON_DEFINITIONS (30+ weapons) | UNVERIFIED |
| 3 | `src/core/systems/InjurySystemConstants.gd` | INJURY_ROLL_RANGES (8 ranges), RECOVERY_TIMES (8 entries) | UNVERIFIED |
| 4 | `src/core/systems/CharacterAdvancementConstants.gd` | XP costs per stat, max stat values, training paths | UNVERIFIED |
| 5 | `src/core/systems/CampaignVictoryConstants.gd` | Victory condition thresholds | UNVERIFIED |
| 6 | `src/core/systems/CampaignPhaseConstants.gd` | Phase-specific constants | UNVERIFIED |
| 7 | `src/core/world/WorldEconomyManager.gd` | BASE_UPKEEP_COST, economy constants | UNVERIFIED |
| 8 | `src/core/campaign/TravelPhase.gd` | D100 travel event ranges, world trait D100 ranges (hardcoded) | UNVERIFIED |
| 9 | `src/core/campaign/WorldPhase.gd` | Crew task thresholds, patron generation values | UNVERIFIED |
| 10 | `src/core/campaign/BattlePhase.gd` | XP distribution, payment formula, unique individual thresholds | UNVERIFIED |
| 11 | `src/core/campaign/GameCampaignManager.gd` | Patron/rival generation, reward ranges (500-1500/1000-2500 credits) | UNVERIFIED |
| 12 | `src/core/systems/EnemyGenerator.gd` | Enemy count formula, difficulty stat modifiers, threat level formula | UNVERIFIED |

---

## Appendix C: Known Internal Inconsistencies

These inconsistencies were found **between code sources within the project** — before even comparing to the Core Rules book. Each must be resolved to a single correct value.

### Fixed (Mar 22, 2026 — Phase 46 Internal Consistency Pass)

| # | Item | Source A | Source B | Resolution |
|---|------|----------|----------|------------|
| 1 | Infantry Laser range | `weapons.json`: 30 | `LootSystemConstants.gd`: ~~18~~ → 30 | **FIXED** — LSC synced to weapons.json |
| 2 | Infantry Laser damage | `weapons.json`: 0 | `LootSystemConstants.gd`: ~~1~~ → 0 | **FIXED** — LSC synced to weapons.json |
| 3 | Blast Rifle range | `weapons.json`: 16 | `LootSystemConstants.gd`: ~~24~~ → 16 | **FIXED** — LSC synced to weapons.json |
| 4 | Blast Rifle shots | `weapons.json`: 1 | `LootSystemConstants.gd`: ~~2~~ → 1 | **FIXED** — LSC synced to weapons.json |
| 5 | Blast Rifle damage | `weapons.json`: 1 | `LootSystemConstants.gd`: ~~0~~ → 1 | **FIXED** — LSC synced to weapons.json |
| 6 | Fury Rifle shots | `weapons.json`: 1 | `LootSystemConstants.gd`: ~~2~~ → 1 | **FIXED** — LSC synced to weapons.json |
| 7 | Fury Rifle damage | `weapons.json`: 2 | `LootSystemConstants.gd`: ~~1~~ → 2 | **FIXED** — LSC synced to weapons.json |
| 8 | Plasma Rifle shots | `weapons.json`: 2 | `LootSystemConstants.gd`: ~~1~~ → 2 | **FIXED** — LSC synced to weapons.json |
| 9 | Plasma Rifle damage | `weapons.json`: 1 | `LootSystemConstants.gd`: ~~2~~ → 1 | **FIXED** — LSC synced to weapons.json |
| 10 | Needle Rifle shots | `weapons.json`: 2 | `LootSystemConstants.gd`: ~~3~~ → 2 | **FIXED** — LSC synced to weapons.json |
| 11 | Hyper Blaster range | `weapons.json`: 24 | `LootSystemConstants.gd`: ~~18~~ → 24 | **FIXED** — LSC synced to weapons.json |

> Note: Hunting Rifle and Flak Gun were fixed in Phase 43 equipment rewrite.

### Open (Requires Core Rules Book Verification)

| # | Item | Source A | Source B | Discrepancy |
|---|------|----------|----------|-------------|
| 12 | Base upkeep cost | `FiveParsecsConstants.gd`: 1 | `campaign_rules.json`: 6 per member | Need Core Rules p.76-80 |
| 13 | Starting credits | `FiveParsecsConstants.gd`: 10 | `campaign_rules.json`: 100 | Need Core Rules p.15 |
| 14 | WorldEconomyManager scale | `FiveParsecsConstants.gd`: 1 credit | `WorldEconomyManager.gd`: 100x scale (1000 starting) | Different unit scales (1:1 vs 100x) |
| 15 | Injury fatal split | `injury_table.json`: 1-5 Gruesome + 6-15 Death | `InjurySystemConstants.gd`: 1-15 FATAL combined | Need Core Rules p.122-123 |
| 16 | Injury page reference | `injury_table.json`: "p.122" | `InjurySystemConstants.gd`: "p.94-95" | Which page is correct? |
| 17 | Strange Characters bonuses | `character_species.json`: 16 types | `character_creation_bonuses.json`: 0 of 16 | Missing from bonuses JSON |
| 18 | Feral origin bonus | `character_species.json`: defined | `character_creation_bonuses.json`: missing | Origin key not in bonuses JSON |

---

## Appendix D: MCP Internal Consistency Check Scripts

Run these via `mcp__godot__run_script` after `mcp__godot__run_project` to automated cross-source checks.

### D1: Weapon Data Cross-Check

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var weapons_file = FileAccess.get_file_as_string("res://data/weapons.json")
    if not weapons_file:
        return {"error": "Cannot read weapons.json"}
    var weapons_json = JSON.parse_string(weapons_file)
    if not weapons_json or not weapons_json.has("weapons"):
        return {"error": "Invalid weapons.json format"}

    var lsc = LootSystemConstants.WEAPON_DEFINITIONS
    var mismatches = []
    for w in weapons_json["weapons"]:
        var name = w.get("name", "")
        if name in lsc:
            var lsc_w = lsc[name]
            if lsc_w.get("range", -1) != w.get("range", -1):
                mismatches.append(name + " range: JSON=" + str(w.range) + " LSC=" + str(lsc_w.range))
            if lsc_w.get("damage", -1) != w.get("damage", -1):
                mismatches.append(name + " damage: JSON=" + str(w.damage) + " LSC=" + str(lsc_w.damage))
            if lsc_w.get("shots", -1) != w.get("shots", -1):
                mismatches.append(name + " shots: JSON=" + str(w.shots) + " LSC=" + str(lsc_w.shots))
    return {"total_mismatches": mismatches.size(), "details": mismatches}
```

### D2: Injury Data Cross-Check

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var injury_file = FileAccess.get_file_as_string("res://data/injury_table.json")
    if not injury_file:
        return {"error": "Cannot read injury_table.json"}
    var injury_json = JSON.parse_string(injury_file)
    var isc_ranges = InjurySystemConstants.INJURY_ROLL_RANGES
    var mismatches = []
    # Compare roll ranges between JSON and constants
    if injury_json.has("injuries"):
        for entry in injury_json["injuries"]:
            var type_name = entry.get("type", "")
            if type_name in isc_ranges:
                var isc_range = isc_ranges[type_name]
                var json_range = [entry.get("min_roll", -1), entry.get("max_roll", -1)]
                if isc_range[0] != json_range[0] or isc_range[1] != json_range[1]:
                    mismatches.append(type_name + ": JSON=" + str(json_range) + " ISC=" + str(isc_range))
    return {"total_mismatches": mismatches.size(), "details": mismatches}
```

### D3: Economy Constants Cross-Check

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var checks = []
    var fpc_upkeep = FiveParsecsConstants.ECONOMY.get("base_upkeep", -1)
    var wem = scene_tree.root.get_node_or_null("/root/WorldEconomyManager")
    var wem_upkeep = wem.BASE_UPKEEP_COST if wem and "BASE_UPKEEP_COST" in wem else -1
    if fpc_upkeep != wem_upkeep:
        checks.append("UPKEEP MISMATCH: FiveParsecsConstants=" + str(fpc_upkeep) + " WorldEconomyManager=" + str(wem_upkeep))
    if checks.is_empty():
        return {"status": "ALL CONSISTENT", "checks": 1}
    return {"status": "INCONSISTENCIES FOUND", "details": checks}
```
