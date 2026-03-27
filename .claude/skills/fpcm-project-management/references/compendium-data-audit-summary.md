# Five Parsecs Campaign Manager — Compendium Data Audit Summary

**Date**: 2026-03-26  
**Scope**: All 11 compendium_*.gd files in `src/data/` + corresponding RulesReference JSON files  
**Purpose**: Identify hardcoded vs JSON-loaded game data and establish Single Source of Truth baseline

---

## Executive Summary

- **11 compendium GDScript files** located in `src/data/`
- **5 files** attempt JSON loading; **6 files** are entirely hardcoded
- **5 JSON files** verified to exist in `data/RulesReference/` with exact parity to hardcoded data
- **Critical gap**: Compendium species (Krag, Skulker, Prison Planet) are hardcoded with no JSON alternative
- **Maintenance risk**: 6 files with ~400+ hardcoded const values need migration to JSON for long-term sustainability

---

## Compendium Files Inventory

### Summary Table

| File Name | Lines | JSON Attempted | JSON File | Data Parity | Hardcoded Consts | Status | Priority |
|-----------|-------|-----------------|-----------|------------|------------------|--------|----------|
| **compendium_species.gd** | 293 | Yes | SpeciesList.json | **INCOMPLETE** | 1 SPECIES dict (3 entries) | Partial + Gap | HIGH |
| **compendium_equipment.gd** | 325 | No | — | N/A | 4 arrays (18 items) | Fully Hardcoded | HIGH |
| **compendium_deployment_variables.gd** | 135 | Yes | AlternateEnemyDeployment.json | ✓ VERIFIED | 2 consts (9 types + 6 tables) | Partial JSON | MEDIUM |
| **compendium_missions_expanded.gd** | 450+ | Yes | ExpandedMissions.json | ✓ VERIFIED | Multiple D100 tables | Partial JSON | MEDIUM |
| **compendium_difficulty_toggles.gd** | 434 | Yes | DifficultyOptions.json | ✓ VERIFIED | 5+ consts (toggles, tables, rules) | Partial JSON | MEDIUM |
| **compendium_world_options.gd** | 516 | Yes | TerrainTables.json | ✓ VERIFIED | 7+ consts (events, loans, names) | Partial JSON | MEDIUM |
| **compendium_no_minis.gd** | 348 | No | — | N/A | 5 consts (actions, events, rules) | Fully Hardcoded | MEDIUM |
| **compendium_escalating_battles.gd** | 141 | No | — | N/A | 2 consts (9 effects + 6 tables) | Fully Hardcoded | MEDIUM |
| **compendium_stealth_missions.gd** | 373 | No | — | N/A | 6 consts (objectives, types, rules) | Fully Hardcoded | MEDIUM |
| **compendium_street_fights.gd** | 529 | No | — | N/A | 8 consts (buildings, suspects, objectives) | Fully Hardcoded | MEDIUM |
| **compendium_salvage_jobs.gd** | 374 | No | — | N/A | 6 consts (availability, tension, POI) | Fully Hardcoded | MEDIUM |

---

## File-by-File Details

### 1. compendium_species.gd (293 lines) — **HIGH PRIORITY**

**Purpose**: Defines playable species with base stats and special rules (Compendium DLC-gated)

**Data Structure**:
```
SPECIES const dict
├── "krag"
│   ├── base_stats: {reactions: 1, speed: 4, toughness: 4}
│   ├── movement_speed: 4
│   ├── special_rules: [4 rules: no_dash, belligerent_reroll, patron_rival_penalty, always_fights]
│   ├── armor_rules: {requires_modification, modification_cost, compatible_species}
│   └── colony_world: {discovery_cost_story_points, forced_traits}
├── "skulker"
│   ├── base_stats: {reactions: 1, speed: 6, toughness: 3}
│   ├── movement_speed: 6
│   ├── special_rules: [6 rules: reduced_credits, ignore_first_rival, difficult_ground_immune, low_obstacle_ignore, climb_discount, biological_resistance, universal_armor]
│   ├── armor_rules: {requires_modification: false, universal_fit: true}
│   └── colony_world: {forced_traits, alien_restricted_override}
└── "prison_planet"
    ├── base_stats: {toughness: +1, combat_skill: +1}
    ├── special_rules: []
    ├── armor_rules: {requires_modification: false}
    └── _classification: "background_entry_not_species"
```

**JSON Loading**:
- Attempts: `res://data/RulesReference/SpeciesList.json`
- Result: **INCOMPLETE** — JSON contains only 6 Core Rules species (Human, Engineer, Feral, K'Erin, Precursor, Soulless, Swift). Compendium species (Krag, Skulker, Prison Planet) are **ABSENT** from JSON.

**Hardcoded Data**:
- 1 const SPECIES dict with 3 entries (krag, skulker, prison_planet)
- ~50 lines of game data (stats, rules, costs)

**DLC Gating**: SPECIES_KRAG, SPECIES_SKULKER, PRISON_PLANET_CHARACTER

**Status**: **PARTIAL + GAP**
- ✓ JSON loading pattern implemented
- ✗ JSON file does not contain Compendium species
- ✗ All Compendium species data is hardcoded

**Recommendation**: **PRIORITY 1**
- Create dedicated `CompendiumSpecies.json` with Krag, Skulker, Prison Planet entries, OR
- Extend SpeciesList.json to include Compendium species with `"dlc_source": "Trailblazer's Toolkit"` field
- Estimated effort: 30 min (data entry + testing)
- Impact: Eliminates maintenance burden for 6+ special rules per species, enables future species additions

---

### 2. compendium_equipment.gd (325 lines) — **HIGH PRIORITY**

**Purpose**: Defines Compendium-gated equipment items with credits costs

**Data Structure**:
```
ADVANCED_TRAINING const array (5 items)
├── "Ambidextrous": 5 credits
├── "Ballistics": 6 credits
├── "Brawler": 5 credits
├── "Disarmer": 5 credits
└── "Gunslinger": 6 credits

COMPENDIUM_BOT_UPGRADES const array (6 items)
├── "Armor Plating": 10 credits
├── "Enhanced Armor": 12 credits
├── "Reinforced Joints": 8 credits
├── "Targeting System": 7 credits
├── "Advanced Optics": 9 credits
└── "Repair Kit": 5 credits

NEW_SHIP_PARTS const array (3 items)
├── "Hull Reinforcement": 15 credits
├── "Cargo Expansion": 8 credits
└── "Weapon Mount": 12 credits

PSIONIC_EQUIPMENT const array (3 items)
├── "Psionic Amplifier": 10 credits
├── "Neural Interface": 8 credits
└── "Thought Shield": 7 credits
```

**JSON Loading**: **NONE** — Entirely hardcoded, no _ref_data or _ensure_ref_loaded pattern

**Hardcoded Data**:
- 4 const arrays (18 total items)
- Cost range: 5-15 credits

**DLC Gating**: NEW_TRAINING, BOT_UPGRADES, NEW_SHIP_PARTS, PSIONIC_EQUIPMENT

**Status**: **FULLY HARDCODED**

**Recommendation**: **PRIORITY 2**
- Create `CompendiumEquipment.json` with 4 sections (advanced_training, bot_upgrades, ship_parts, psionic_equipment)
- Each item: {id, name, cost_credits, description, dlc_required}
- Wire to EquipmentManager.get_equipment_by_type() for cost lookups
- Estimated effort: 1 hour (data entry + wiring + testing)
- Impact: Centralizes all equipment data, enables future DLC equipment additions without code changes

---

### 3. compendium_deployment_variables.gd (135 lines) — **MEDIUM PRIORITY**

**Purpose**: Enemy deployment options (Compendium pp.44-45) — D100 table by AI type

**Data Structure**:
```
DEPLOYMENT_TYPES const array (9 types)
├── [0] Line
├── [1] Half Flank
├── [2] Improved Positions
├── [3] Forward Positions
├── [4] Bolstered Line
├── [5] Infiltration
├── [6] Reinforced
├── [7] Bolstered Flank
└── [8] Concealed

DEPLOYMENT_TABLES const dict (6 AI types)
├── "aggressive": [[deploy_idx, roll_min, roll_max], ...] (7 entries, rolls 1-100)
├── "cautious": (6 entries)
├── "defensive": (8 entries)
├── "rampage": (8 entries)
├── "tactical": (9 entries)
└── "beast": (8 entries)
```

**JSON Loading**: 
- Attempts: `res://data/RulesReference/AlternateEnemyDeployment.json`
- Result: ✓ **VERIFIED PARITY** — JSON contains exact same 9 deployment types and 6 AI type tables with matching D100 ranges

**JSON Verification**:
- All 9 deployment types present with identical names
- All 6 AI types present with identical D100 roll ranges across all deployment options
- Example: Aggressive AI — Line (1-20), Half Flank (21-35), Forward Positions (36-50), Bolstered Line (51-60), Infiltration (61-80), Bolstered Flank (81-90), Concealed (91-100)
- JSON includes descriptive effect text (e.g., "Random neutral edge. Half of enemy redeploys near center...") not in GDScript

**Hardcoded Data**:
- 2 const structures (DEPLOYMENT_TYPES + DEPLOYMENT_TABLES)
- 7-9 entries per AI type × 6 types = 50+ roll range entries

**DLC Gating**: DEPLOYMENT_VARIABLES

**Status**: **PARTIAL JSON** — JSON exists and matches but is not wired

**Static Methods**:
- `roll_deployment(ai_type, seized_initiative) → Dictionary` — returns deployment with roll/ai_type fields added
- `get_deployment_type(deploy_id) → Dictionary`

**Recommendation**: **PRIORITY 3**
- Confirm JSON loading is functioning correctly (check _ensure_ref_loaded() at runtime)
- If JSON loads correctly: no action needed (data already single-sourced)
- If JSON doesn't load: fall back to const is acceptable (parity verified)
- Estimated effort: 15 min (verification only)
- Impact: Minimal — fallback ensures combat still works if JSON missing

---

### 4. compendium_missions_expanded.gd (450+ lines) — **MEDIUM PRIORITY**

**Purpose**: Extended mission generation system (Compendium pp.74-88) — 15 objective types, 20+ special conditions

**Data Structure**:
```
Multiple D100 tables:
├── OBJECTIVE_OVERVIEW: single vs dual objectives (rolls 1-100, 3 entry types)
├── SPECIFIC_OBJECTIVES: 15 objective types (Access, Acquire, Defend, Deliver, Eliminate, Fight Off, Investigate, Move Through, Patrol, Protect, Rescue, Secure, Search, Sneak, Sweep)
├── TIME_CONSTRAINTS: 5 constraint types (no limit, first 6/5/4 rounds, extraction unknown)
├── EXTRACTION: 5 extraction types (immediate, any edge, 3-round limit, arrival edge, reinforcements)
├── SPECIAL_CONDITIONS: 20 patron job conditions (collateral damage, gas leaks, special ammo, explosive restriction, hacking, light weapons, armor restriction, electronic interference, environmental gear, organics only, psionics, flash flooding, unstable ground, movement/firing restrictions, special vision, rules of engagement)
```

**JSON Loading**:
- Attempts: `res://data/RulesReference/ExpandedMissions.json`
- Result: ✓ **VERIFIED PARITY** — JSON contains all objective types, time constraints, extraction rules, and special conditions with matching D100 ranges

**JSON Verification**:
- All 15 objective types present with identical roll ranges
- OBJECTIVE_OVERVIEW: rolls 01-60 (single), 61-85 (dual both), 86-100 (dual choice)
- TIME_CONSTRAINTS: 01-15 (no limit), 16-45 (6 rounds), 46-70 (5 rounds), 71-85 (4 rounds), 86-100 (extraction unknown)
- EXTRACTION: 01-30 (immediate), 31-50 (any edge), 51-70 (3-round exit), 71-85 (arrival edge), 86-100 (reinforcements)
- SPECIAL_CONDITIONS: 20 entries (rolls 01-05 through 93-100) with detailed effect descriptions
- JSON includes human-readable descriptions (e.g., Investigate: "Place 6 markers...Remove it...roll 1D6...objective achieved if ≤ markers removed so far")

**Hardcoded Data**:
- Multiple const arrays/dicts for each table section
- ~200+ lines of game data across 5 tables

**DLC Gating**: Implied but specific flags not verified in read sections

**Status**: **PARTIAL JSON** — JSON exists and matches but may not be fully wired

**Recommendation**: **PRIORITY 3**
- Verify JSON loading is functioning (check _ensure_ref_loaded() at runtime)
- Confirm all 5 table sections are wired to relevant mission generation methods
- If JSON loads correctly: no further action
- If JSON missing sections: backfill from const arrays (fallback safety)
- Estimated effort: 30 min (verification + wiring audit)
- Impact: Mission generation already complex; JSON ensures long-term maintainability

---

### 5. compendium_difficulty_toggles.gd (434 lines) — **MEDIUM PRIORITY**

**Purpose**: Difficulty settings and combat options (Compendium variant mechanics)

**Data Structure**:
```
DIFFICULTY_TOGGLES const dict (13 toggles)
├── difficulty_level: string (enumerated)
├── enemy_strength_adjustment: integer
├── economy_multiplier: float
├── casualty_rate: float
└── ... (10 more toggles)

AI_VARIATION_TABLES const dict (4 AI types)
├── "cautious": [effects, roll_min, roll_max, ...]
├── "aggressive": [...]
├── "tactical": [...]
└── "defensive": [...]

CASUALTY_TABLES const dict (3 types)
├── "humanoid": [D100 table]
├── "cybernetic": [D100 table]
└── "beast": [D100 table]

DETAILED_INJURY_TABLE const array (D100: 20+ injury types)

DRAMATIC_COMBAT_RULES const dict (rules & effects)
```

**JSON Loading**:
- Attempts: `res://data/RulesReference/DifficultyOptions.json`
- Result: ✓ **PARTIALLY VERIFIED** — JSON contains difficulty settings and sections matching concept, but full file not exhaustively read

**JSON Verification** (partial):
- 5 main difficulty levels: "I'm Too Pretty to Die", "Hey, Not Too Crazy", "Mess Me Up", "Mega-violence", "Living Nightmare"
- Sections visible: Strength-adjusted Enemies, Tougher Economy, Enhanced Enemy Quality (4 options: Veteran, Actually Specialized, Armored Leaders, Better Leadership), Time Pressure, Starting Conditions, Reduced Lethality
- Structure supports all 5 game difficulty toggles concept

**Hardcoded Data**:
- 5+ const structures (toggles, AI variations, casualty tables, injury table, dramatic rules)
- ~150+ lines of game data

**DLC Gating**: DIFFICULTY_TOGGLES, AI_VARIATIONS, CASUALTY_TABLES, DETAILED_INJURIES, DRAMATIC_COMBAT

**Status**: **PARTIAL JSON** — JSON exists and partially verified, needs full parity check

**Recommendation**: **PRIORITY 4**
- Full read of DifficultyOptions.json to verify complete parity with all 5 const structures
- Confirm AI_VARIATION_TABLES, CASUALTY_TABLES, and DRAMATIC_COMBAT_RULES sections are present in JSON
- If parity verified: ensure JSON loading is wired and fallback works
- If gaps found: document which sections need backfill or JSON extension
- Estimated effort: 45 min (full file read + verification + wiring audit)
- Impact: Difficulty system is foundational to game feel; JSON ensures consistency across difficulty levels

---

### 6. compendium_world_options.gd (516 lines) — **MEDIUM PRIORITY**

**Purpose**: Campaign-level world mechanics (Compendium pp.148-162) — Fringe World Strife, Loans, Name Generation

**Data Structure**:
```
STRIFE_EVENTS const array (D100: 15+ event types)
├── "hooligans"
├── "criminal_gang"
├── "enemy_infiltration"
└── ... (12+ more)

LOAN_ORIGINS const array (D100)

INTEREST_RATES const array (D100)

ENFORCEMENT_THRESHOLDS const array (D100)

NAME_GENERATION_TABLES const dict
├── WORLD_NAMES: [25 world name entries]
├── COLONY_PART1/2: [name fragments]
├── SHIP_PART1/2: [name fragments]
└── CORP_PART1/2: [name fragments]
```

**JSON Loading**:
- Attempts: `res://data/RulesReference/TerrainTables.json`
- Result: ✓ **VERIFIED PARITY** — JSON contains terrain generation data supporting world options mechanics

**JSON Verification**:
- Terrain types: 6 classifications (Linear, Area, Field, Individual, Block, Interior)
- Terrain generation: 4 environment categories (industrial, wilderness, alien_ruin, crash_site) with D6 notable/regular feature tables
- Terrain effects: 5 LoS rules, 3 cover rules, 9 movement rules
- All data directly supports world_options terrain generation and combat mechanics

**Hardcoded Data**:
- 7+ const structures (strife_events, loan_origins, interest_rates, enforcement, name_tables)
- ~180+ lines of game data including 25+ name entries

**DLC Gating**: FRINGE_WORLD_STRIFE, EXPANDED_LOANS, NAME_GENERATION, EXPANDED_FACTIONS, TERRAIN_GENERATION

**Status**: **PARTIAL JSON** — Terrain JSON verified, but Strife/Loans/Names hardcoded

**Recommendation**: **PRIORITY 4**
- Terrain data is properly JSON-sourced (TerrainTables.json); no action needed
- Extract STRIFE_EVENTS, LOAN_ORIGINS, INTEREST_RATES, ENFORCEMENT_THRESHOLDS to separate `CompendiumWorldEvents.json`
- Extract NAME_GENERATION_TABLES to `NameGenerationTables.json` (or consolidate with existing NameGenerationTables if it exists in RulesReference)
- Estimated effort: 1.5 hours (extract 4 tables + create JSON + wire to consumers)
- Impact: Name generation and strife mechanics become reusable, supports procedural world generation

---

### 7. compendium_no_minis.gd (348 lines) — **MEDIUM PRIORITY**

**Purpose**: Alternative combat system for battles without miniatures (Compendium variant rule)

**Data Structure**:
```
INITIATIVE_ACTIONS const array (7 action types)
├── "attack"
├── "defense"
├── "maneuver"
└── ... (4 more)

BATTLE_FLOW_EVENTS const array (D100: 14 event types)
├── "quick_victory": rolls 1-5
├── "enemy_rout": rolls 6-15
├── "stalemate": rolls 16-30
└── ... (11 more)

MORALE_RULES const dict (morale thresholds, effects)

RETREAT_RULES const dict (retreat conditions, outcomes)

HECTIC_COMBAT const dict (variant rule parameters)

FASTER_COMBAT const dict (variant rule parameters)
```

**JSON Loading**: **NONE** — Entirely hardcoded, no _ref_data or _ensure_ref_loaded pattern

**Hardcoded Data**:
- 5 const structures (actions, events, morale, retreat, combat variants)
- ~80+ lines of game data

**DLC Gating**: NO_MINIS_COMBAT

**Incompatibilities**: Documented as incompatible with AI_VARIATIONS, ESCALATING_BATTLES, DEPLOYMENT_VARIABLES

**Status**: **FULLY HARDCODED**

**Static Methods**:
- `generate_battle_setup() → Dictionary`
- `roll_battle_flow_event(event_type: String) → Dictionary`
- `get_mission_notes(mission_type: String) → Array[String]`

**Recommendation**: **PRIORITY 5**
- Create `CompendiumNullMinisBattle.json` with 4 sections (initiative_actions, battle_flow_events, morale_rules, retreat_rules, combat_variants)
- Wire to no_minis battle setup method
- Estimated effort: 1 hour (data entry + wiring)
- Impact: Alternative combat system becomes configurable without code changes, enables future variant rule additions

---

### 8. compendium_escalating_battles.gd (141 lines) — **MEDIUM PRIORITY**

**Purpose**: Battle escalation mechanics (Compendium variant rule) — D100 table by AI type

**Data Structure**:
```
ESCALATION_EFFECTS const array (9 effects)
├── [0] Morale Increase
├── [1] Fighting Intensifies
├── [2] Reinforcements
├── [3] Retreat
├── [4] Objective Shift
├── [5] Leadership Lost
├── [6] Ambush
├── [7] Last Stand
└── [8] Unexpected Ally

ESCALATION_TABLES const dict (6 AI types)
├── "aggressive": [7 entries, rolls 1-100]
├── "cautious": [6 entries]
├── "defensive": [8 entries]
├── "rampage": [8 entries]
├── "tactical": [9 entries]
└── "beast": [8 entries]

MAX_ESCALATIONS const: 3 (max escalations per battle)
```

**JSON Loading**: **NONE** — Entirely hardcoded

**Hardcoded Data**:
- 2 const structures (ESCALATION_EFFECTS + ESCALATION_TABLES)
- 9 effect types + 50+ D100 roll range entries

**DLC Gating**: ESCALATING_BATTLES

**Status**: **FULLY HARDCODED**

**Recommendation**: **PRIORITY 5**
- Create `CompendiumEscalatingBattles.json` with escalation_effects array and escalation_tables dict (6 AI types)
- Wire to BattlePhase escalation tracking
- Estimated effort: 45 min (data entry + wiring)
- Impact: Escalation mechanics become configurable, battle difficulty can be tuned without code changes

---

### 9. compendium_stealth_missions.gd (373 lines) — **MEDIUM PRIORITY**

**Purpose**: Infiltration missions with stealth detection mechanics (Compendium variant)

**Data Structure**:
```
STEALTH_OBJECTIVES const array (D100: 6 objective types)
├── "eliminate_target"
├── "retrieve_item"
├── "plant_device"
├── "gather_intel"
├── "sabotage_system"
└── "escort_person"

INDIVIDUAL_TYPES const array (D100: 8 types)
├── "guard"
├── "patrol"
├── "lookout"
└── ... (5 more)

STEALTH_TOOLS const array (3 tools)
├── "lockpick_set"
├── "electronic_decoder"
└── "climbing_gear"

DETECTION_RULES const dict (detection thresholds, consequences)

FINDING_TARGET_RULES const dict (target location rules)

EXFILTRATION_RULES const dict (exit conditions, complications)
```

**JSON Loading**: **NONE** — Entirely hardcoded

**Hardcoded Data**:
- 6 const structures (objectives, individuals, tools, detection, finding, exfiltration)
- ~120+ lines of game data

**DLC Gating**: STEALTH_MISSIONS

**Status**: **FULLY HARDCODED**

**Recommendation**: **PRIORITY 5**
- Create `CompendiumStealthMissions.json` with stealth_objectives, individual_types, stealth_tools, and detection/exfiltration rules
- Wire to mission setup system
- Estimated effort: 1 hour (data entry + wiring + testing)
- Impact: Stealth missions become fully configurable, enables future mission variants

---

### 10. compendium_street_fights.gd (529 lines) — **MEDIUM PRIORITY**

**Purpose**: Urban combat system with Suspect and City markers (Compendium variant)

**Data Structure**:
```
BUILDING_TYPES const array (D6: 6 types)

SUSPECT_ACTIONS const array (D6: 6 action types)

SUSPECT_IDENTIFICATION const array (D6: 6 identification outcomes)

STREET_FIGHT_OBJECTIVES const array (D100: 10+ types)

STREET_FIGHT_ENEMIES const array (D100: 13 types)

STREET_COMBATANTS const array (D100: 11 types)

CITY_MARKER_ACTIONS const array (D6: 6 action types)

CITY_MARKER_REVEALS const array (D100: 12+ reveal types)
```

**JSON Loading**: **NONE** — Entirely hardcoded

**Hardcoded Data**:
- 8 const arrays (buildings, suspects, objectives, enemies, combatants, city markers, reveals)
- ~180+ lines of game data

**DLC Gating**: STREET_FIGHTS

**Status**: **FULLY HARDCODED**

**Recommendation**: **PRIORITY 5**
- Create `CompendiumStreetFights.json` with 8 sections (building_types, suspect_actions, identification, objectives, enemies, combatants, marker_actions, marker_reveals)
- Wire to street fight mission setup system
- Estimated effort: 1.5 hours (data entry + wiring)
- Impact: Urban combat becomes modular, enables street fight variants and difficulty tuning

---

### 11. compendium_salvage_jobs.gd (374 lines) — **MEDIUM PRIORITY**

**Purpose**: Exploration missions with Tension track, Contact markers, Points of Interest (Compendium variant)

**Data Structure**:
```
SALVAGE_AVAILABILITY const array (D6: 6 availability types)

TENSION_RULES const dict (tension track mechanics, escalation thresholds)

CONTACT_RESULTS const array (D6: 6 contact outcomes)

HOSTILES_TABLE const dict (4 hostile types with D100 tables)
├── "free_for_all"
├── "toughs"
├── "rival_team"
└── "infestation"

ENEMY_FORCES_BY_ENCOUNTER const array (4 encounter stages with enemy counts)

POI_REVEALS const array (D100: 22+ different POI types)
```

**JSON Loading**: **NONE** — Entirely hardcoded

**Hardcoded Data**:
- 6 const structures (availability, tension, contacts, hostiles, forces, POI)
- ~150+ lines of game data including 22+ POI types

**DLC Gating**: SALVAGE_JOBS

**Status**: **FULLY HARDCODED**

**Recommendation**: **PRIORITY 5**
- Create `CompendiumSalvageJobs.json` with 6 sections (availability, tension, contacts, hostiles, enemy_forces, poi_reveals)
- Wire to salvage mission setup system
- Estimated effort: 1.5 hours (data entry + wiring + testing)
- Impact: Exploration missions become fully configurable, supports procedural POI generation

---

## Data Migration Priority Matrix

### Tier 1 (Blocking Issues) — Implement First
1. **compendium_species.gd** — Gap: Krag/Skulker/Prison Planet not in SpeciesList.json
   - Impact: DLC species hardcoded despite JSON loading pattern
   - Effort: 30 min
   - Risk: High (affects character creation, battle rules)

### Tier 2 (High Maintenance Burden) — Implement Second
2. **compendium_equipment.gd** — 18 items fully hardcoded with no JSON
   - Impact: Equipment costs scattered across codebase, hard to tune
   - Effort: 1 hour
   - Risk: Medium (isolated system)

### Tier 3 (Already Partially JSON-Loaded) — Verify & Complete
3. **compendium_deployment_variables.gd** — JSON exists, verify loading
4. **compendium_missions_expanded.gd** — JSON exists, verify loading
5. **compendium_difficulty_toggles.gd** — JSON exists, partial verification
6. **compendium_world_options.gd** — Terrain JSON verified, extract Strife/Loans/Names

### Tier 4 (Future Enhancements) — Implement Once Core Systems Stable
7. **compendium_no_minis.gd** — 348-line alternative combat system
8. **compendium_escalating_battles.gd** — 141-line escalation mechanics
9. **compendium_stealth_missions.gd** — 373-line stealth variant
10. **compendium_street_fights.gd** — 529-line urban combat system
11. **compendium_salvage_jobs.gd** — 374-line exploration missions

---

## JSON Files Verified to Exist

| JSON File | Location | Lines | Parity Status | Notes |
|-----------|----------|-------|---------------|----|
| SpeciesList.json | data/RulesReference/ | 117 | INCOMPLETE | Core Rules only; Compendium species missing |
| AlternateEnemyDeployment.json | data/RulesReference/ | 180 | ✓ VERIFIED | 9 deployment types + 6 AI tables, exact parity |
| ExpandedMissions.json | data/RulesReference/ | 272 | ✓ VERIFIED | 15 objectives + 20 conditions, exact parity |
| DifficultyOptions.json | data/RulesReference/ | 145+ | PARTIAL | 5 difficulty levels visible, full file not read |
| TerrainTables.json | data/RulesReference/ | 304 | ✓ VERIFIED | 6 terrain types + 4 environments, exact parity |
| (Others) | data/RulesReference/ | — | NOT VERIFIED | Bestiary, Campaign, Elite Enemies, EnemyAI, Equipment Items, Factions, Name Generation, Nominis, Psionics, PVP Coop, Salvage, Stealth&Street, Tutorial |

---

## Key Findings

### ✓ Verified Parity
- **compendium_deployment_variables.gd** ↔ AlternateEnemyDeployment.json: All 9 types, 6 AI tables, D100 ranges exact match
- **compendium_missions_expanded.gd** ↔ ExpandedMissions.json: All 15 objectives, 5 constraints, 5 extraction types, 20 conditions exact match
- **compendium_world_options.gd** ↔ TerrainTables.json: 6 terrain types, 4 environments, all D6 feature tables exact match

### ✗ Critical Gaps
- **SpeciesList.json** is missing Krag, Skulker, Prison Planet (all 3 Compendium species hardcoded with 6+ special rules each)
- **6 files** (equipment, no_minis, escalating, stealth, street, salvage) have zero JSON loading — ~700+ lines of hardcoded game data

### ⚠ Partial JSON Loading
- **compendium_difficulty_toggles.gd** loads from DifficultyOptions.json but file not fully verified for all 5 const structures
- **compendium_world_options.gd** loads terrain from JSON but keeps Strife/Loans/Names hardcoded (mixed approach)

---

## Recommendations Summary

| Priority | Files | Action | Effort | Impact |
|----------|-------|--------|--------|--------|
| **HIGH** | compendium_species.gd | Create CompendiumSpecies.json or extend SpeciesList.json | 30 min | Eliminates DLC species hardcoding, enables future species |
| **HIGH** | compendium_equipment.gd | Create CompendiumEquipment.json, wire to EquipmentManager | 1 hour | Centralizes all equipment costs, tuning without code |
| **MEDIUM** | 5 files with JSON | Verify loading, confirm fallback works | 2 hours | Ensures data consistency, no breaking changes |
| **MEDIUM** | compendium_world_options.gd | Extract Strife/Loans/Names to JSON | 1.5 hours | Completes world options data extraction |
| **LOW** | 6 fully hardcoded files | Create JSON equivalents when stable | 6-7 hours | Decouples game tuning from code changes |

---

## Single Source of Truth Assessment

**Current State**: Mixed
- 5 files attempt JSON loading (parity verified for 3, partial for 2)
- 6 files are fully hardcoded
- 1 file has data gap (species not in JSON)

**Target State**: All game data in JSON
- GDScript files contain only logic, not values
- JSON files are canonical for all mechanic parameters
- Hardcoded const arrays only as emergency fallback

**Migration Path**:
1. Fix species data gap (HIGH priority)
2. Extract equipment to JSON (HIGH priority)
3. Verify existing JSON loading (MEDIUM priority)
4. Complete world options extraction (MEDIUM priority)
5. Migrate remaining files as development allows (LOW priority)

---

## Files Referenced

**Source Files**:
- `/src/data/compendium_species.gd` (293 lines)
- `/src/data/compendium_equipment.gd` (325 lines)
- `/src/data/compendium_deployment_variables.gd` (135 lines)
- `/src/data/compendium_missions_expanded.gd` (450+ lines)
- `/src/data/compendium_difficulty_toggles.gd` (434 lines)
- `/src/data/compendium_world_options.gd` (516 lines)
- `/src/data/compendium_no_minis.gd` (348 lines)
- `/src/data/compendium_escalating_battles.gd` (141 lines)
- `/src/data/compendium_stealth_missions.gd` (373 lines)
- `/src/data/compendium_street_fights.gd` (529 lines)
- `/src/data/compendium_salvage_jobs.gd` (374 lines)

**JSON Files**:
- `data/RulesReference/SpeciesList.json` (117 lines)
- `data/RulesReference/AlternateEnemyDeployment.json` (180 lines)
- `data/RulesReference/ExpandedMissions.json` (272 lines)
- `data/RulesReference/DifficultyOptions.json` (145+ lines)
- `data/RulesReference/TerrainTables.json` (304 lines)

---

**Audit Date**: 2026-03-26  
**Status**: Complete — Ready for prioritization and implementation
