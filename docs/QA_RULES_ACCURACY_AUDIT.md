# Rules-to-Code Traceability Audit

**Last Updated**: 2026-03-22
**Purpose**: Comprehensive line-by-line verification that EVERY rule in the Core Rules book and Compendium has corresponding code, and EVERY piece of game code traces back to a specific rule
**Status**: IN PROGRESS — Chapters 1-7 CODE MAPPED (125+ items with file:line references). Book verification still needed for all items. Chapters 8-15 + Compendium not yet started.

> **CRITICAL — BLOCKS PUBLIC RELEASE**: This project nearly shipped with AI-hallucinated game data. Every rule statement, every conditional ("and"/"or"), every table, every formula in the Core Rules book must map to specific code. Every game data value in code must trace back to a specific page and paragraph in the book.

---

## Audit Philosophy

This is NOT a spot-check. This is a **complete traceability matrix**:

- **Forward tracing** (Book → Code): Read every rule in the Core Rules. For each rule, identify the GDScript function(s) and JSON data that implement it. If no code exists, that's a gap.
- **Reverse tracing** (Code → Book): For every game data value in JSON/GDScript, identify the Core Rules page and paragraph it comes from. If no book reference exists, it's either hallucinated or a `GAME_BALANCE_ESTIMATE` that must be explicitly tagged.
- **Conditional coverage**: Every "and"/"or"/"if"/"unless"/"except" in a rule should correspond to a conditional branch in code. Missing conditionals mean rules are partially implemented.
- **Table completeness**: Every row in a Core Rules table (D100, D66, D6) must have a corresponding entry in the JSON data. Missing rows = incomplete implementation.

### Data Sources (Canonical Order)

1. **Core Rules PDF** — Ultimate authority for all Five Parsecs From Home mechanics
2. **Compendium PDFs** — Authority for DLC/expansion content (Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook, Bug Hunt)
3. **`data/RulesReference/*.json`** (18 files) — Extracted rules data from the PDFs. CHECK THESE FIRST before inventing anything
4. **`data/*.json`** (132 files) — Game data files. Must trace back to source #1 or #2
5. **GDScript constants** — Must reference the JSON files, not duplicate them

### Workflow

1. **Internal Consistency First** — Run automated cross-checks between JSON files and GDScript constants (see Appendix D: MCP Scripts). Fix internal inconsistencies before book verification.
2. **Forward Trace (Book → Code)** — Read the Core Rules page by page. For each rule statement, find the implementing code. Record the mapping.
3. **Reverse Trace (Code → Book)** — For each JSON data value and GDScript constant, find the Core Rules source. If none exists, mark as `HALLUCINATED` or `GAME_BALANCE_ESTIMATE`.
4. **Mark Status** — For each item:
   - `UNVERIFIED` — Not yet checked against book
   - `VERIFIED` — Matches Core Rules exactly, code traced to specific page/paragraph
   - `INCORRECT` — Does NOT match Core Rules (record book value in Notes)
   - `FIXED` — Was INCORRECT, now corrected to match Core Rules
   - `MISSING` — Rule exists in book but NO code implements it
   - `PARTIAL` — Rule partially implemented (missing conditionals or edge cases)
   - `GAME_BALANCE` — Intentional deviation from Core Rules (must be documented with rationale)
   - `HALLUCINATED` — Value exists in code with no corresponding rule in book
   - `N/A` — Not from Core Rules (UI text, tutorials, etc.)
5. **Record Verifier** — Initial and date each verification

### UI/UX Display & Flow Verification

Data and code correctness alone is not enough — the UI must also **display** correct values and **follow** the Core Rules book's prescribed sequences:

1. **Display accuracy**: Confirm values shown on-screen match the underlying data. See `QA_UX_UI_TEST_PLAN.md` §8a.
2. **Flow fidelity**: Confirm UI workflows match the book's prescribed order and structure. See `QA_UX_UI_TEST_PLAN.md` §8b.
3. **Dice roll display**: Confirm D100/D66/D6 results map to correct table entries. See `QA_UX_UI_TEST_PLAN.md` §8c.
4. **Conditional presentation**: When a rule says "if X, then Y; otherwise Z" — verify the UI shows the correct branch to the player.
5. **Layout & UX improvements**: See `QA_UX_UI_TEST_PLAN.md` §9 for layout tightening suggestions.

---

## Progress Summary

### Reverse Trace: Code → Book (Data Values)

| Domain | JSON Files | GDScript Files | Est. Values | Verified | Incorrect | Hallucinated | Status |
|--------|-----------|---------------|-------------|----------|-----------|-------------|--------|
| Weapons & Equipment | 4 | 1 | ~150 | ~43 | 12 FIXED | 6 tagged | **INTERNAL PASS DONE** |
| Species & Characters | 4 | 0 | ~80 | 0 | 0 | ? | NOT STARTED |
| Injuries | 1 | 1 | ~25 | ~25 | 0 | 0 | **VERIFIED (Phase 46)** |
| Loot Tables | 2 | 1 | ~60 | ~55 | 14 FIXED | 0 | **VERIFIED — 14 missing ship items added** |
| Economy & Upkeep | 1 | 2 | ~30 | ~20 | 6 FIXED | 3 tagged | **VERIFIED (Phase 46, pp.76-80)** |
| Campaign Events | 2 | 0 | ~100 | 0 | 0 | ? | NOT STARTED |
| Travel & World | 2 | 0 | ~40 | 0 | 0 | ? | NOT STARTED |
| Battle & Enemies | 5 | 1 | ~60 | ~60 | 0 | 0 | **VERIFIED (Phase 46, pp.94-107)** |
| Char Creation Tables | 3 | 2 | ~80 | ~75 | 1 REWRITE | 36 removed | **MOTIVATION TABLE REWRITTEN** |
| Missions | 6 | 0 | ~50 | 0 | 0 | ? | NOT STARTED |
| Ships | 2 | 0 | ~20 | ~20 | 13 FIXED | 7 removed | **VERIFIED — Full rewrite done (Phase 46)** |
| Advancement | 1 | 1 | ~20 | ~20 | 0 | 0 | **VERIFIED (Phase 46, pp.123-130)** |
| Victory Conditions | 1 | 0 | ~10 | 0 | 0 | ? | NOT STARTED |
| Compendium/DLC | 15+ | 0 | ~100 | 0 | 0 | ? | NOT STARTED |
| **TOTAL** | **~49** | **~9** | **~825+** | **~318** | **46 FIXED** | **9 tagged** | **IN PROGRESS** |

### Forward Trace: Book → Code (Rules Coverage)

| Book Section | Pages | Est. Rules | Code Exists | Fully Traced | Missing | Issues Found | Status |
|-------------|-------|-----------|-------------|-------------|---------|---------|--------|
| Character Creation | pp.15-37 | ~50 | YES (27 items) | 0 | 0 | 3 (Feral missing, strange char count, bonuses gap) | **CODE MAPPED** |
| Equipment & Weapons | pp.40-58 | ~40 | YES (25 items) | 0 | 1 (onboard_items unwired) | 3 (implant count/max, GAME_BALANCE weapons) | **CODE MAPPED** |
| Ships | pp.59-65 | ~20 | YES (6 items) | 0 | 0 | 3 INCORRECT (types/hull/debt) | **MAPPED — INCORRECT** |
| Travel Phase | pp.70-79 | ~30 | YES (10 items) | 0 | 0 | 2 (fallback table drift, world trait name mismatch) | **CODE MAPPED** |
| World Phase / Upkeep | pp.76-86 | ~25 | YES (14 items) | 0 | 0 | 1 CONFLICT (3-way upkeep) | **CODE MAPPED** |
| Battle Setup & Combat | pp.87-95 | ~40 | YES (21 items) | 0 | 0 | 1 (initiative mechanism needs verification) | **CODE MAPPED** |
| Post-Battle | pp.96-102 | ~35 | YES (22 items) | 0 | 0 | 2 (patron reward values suspect, event counts) | **CODE MAPPED** |
| Injuries & Recovery | pp.122-124 | ~15 | ? | 0 | ? | ? | NOT STARTED |
| Advancement | pp.128-132 | ~20 | ? | 0 | ? | ? | NOT STARTED |
| Loot Tables | pp.66-72 | ~25 | YES (covered in Ch.7B) | 0 | 0 | 0 | **CODE MAPPED** |
| Victory Conditions | p.134 | ~10 | ? | 0 | ? | ? | NOT STARTED |
| Difficulty Modifiers | various | ~15 | ? | 0 | ? | ? | NOT STARTED |
| Compendium / DLC | supplements | ~80 | ? | 0 | ? | ? | NOT STARTED |
| **TOTAL** | **~300 pp** | **~405** | **~125 mapped** | **0** | **~1** | **~15** | **8/13 MAPPED** |

### Per-Rule Traceability Entry Format

Each rule in the book should eventually have an entry like this:

```
#### Rule: "If crew size is 6+, roll 2D6 and pick the HIGHER die" (p.88)
- **Book**: Core Rules p.88, paragraph 2, Enemy Count section
- **Conditionals**: "If crew size is 6+" (AND), "pick the HIGHER" (selection logic)
- **Implementing Code**: `src/core/systems/EnemyGenerator.gd:181-195`
- **Data Source**: Hardcoded in GDScript (should be in JSON)
- **Test**: `tests/unit/test_crew_size_enemy_calc.gd`
- **UI Display**: TacticalBattleUI enemy count panel
- **Status**: VERIFIED / INCORRECT / PARTIAL / MISSING
- **Conditionals Covered**: 2/2 (crew size check + pick-higher logic)
```

---

## Chapter 1: Character Creation (Core Rules pp.15-37)

### Architecture Overview

**Two code paths** consume character creation data:

| Path | Entry Point | JSON Files Loaded | Purpose |
|------|-------------|-------------------|---------|
| **Primary** | `CharacterCreator.gd` | `background_table.json`, `class_table.json`, `motivation_table.json`, `character_creation_bonuses.json` | Full creator with DLC species, enum-based bonus lookup |
| **Secondary** | `SimpleCharacterCreator.gd` | `character_species.json`, `character_backgrounds.json`, `motivation_table.json` | Simplified creator with direct stat modifier application |

**Key Functions**:
- `CharacterCreator._lookup_bonuses(table_key, id)` → [CharacterCreator.gd:460-469](src/core/character/Generation/CharacterCreator.gd#L460-L469) — Central bonus resolver
- `CharacterCreator._apply_origin_bonuses(origin_id)` → [CharacterCreator.gd:339-355](src/core/character/Generation/CharacterCreator.gd#L339-L355)
- `CharacterCreator._apply_background_bonuses(bg_id)` → [CharacterCreator.gd:471-483](src/core/character/Generation/CharacterCreator.gd#L471-L483)
- `CharacterCreator._apply_class_bonuses(class_id)` → [CharacterCreator.gd:485-497](src/core/character/Generation/CharacterCreator.gd#L485-L497)
- `CharacterCreator._apply_motivation_bonuses(motivation_id)` → [CharacterCreator.gd:499-513](src/core/character/Generation/CharacterCreator.gd#L499-L513)
- `CharacterCreator._populate_dropdowns()` → [CharacterCreator.gd:165-206](src/core/character/Generation/CharacterCreator.gd#L165-L206) — DLC species gating
- `SimpleCharacterCreator._load_character_data()` → [SimpleCharacterCreator.gd:66-72](src/core/character/Generation/SimpleCharacterCreator.gd#L66-L72)
- `SimpleCharacterCreator._get_species_data()` → [SimpleCharacterCreator.gd:492-500](src/core/character/Generation/SimpleCharacterCreator.gd#L492-L500)
- `SimpleCharacterCreator._on_origin_changed()` → [SimpleCharacterCreator.gd:526-533](src/core/character/Generation/SimpleCharacterCreator.gd#L526-L533)

**DLC Species** (hardcoded in [compendium_species.gd](src/data/compendium_species.gd)):
- Krag (lines 27-56), Skulker (lines 83-132), Prison Planet (lines 134-166)
- Gated by `DLCManager.ContentFlag.SPECIES_KRAG`, `.SPECIES_SKULKER`, `.PRISON_PLANET_CHARACTER`

**Test Files**:
- [tests/unit/test_character_creation_tables.gd](tests/unit/test_character_creation_tables.gd) — Background events, motivation rolls, quirks, connections
- [tests/integration/test_campaign_creation_data_flow.gd](tests/integration/test_campaign_creation_data_flow.gd) — End-to-end 7-phase wizard data flow
- [tests/test_character_diversity.gd](tests/test_character_diversity.gd) — Generation diversity, backgrounds/motivations/classes

### 1A: Species Stats (pp.15-22)

**Data Sources**: [data/character_species.json](data/character_species.json) (320 lines, 8 primary + 15 strange = 23 total), [data/RulesReference/SpeciesList.json](data/RulesReference/SpeciesList.json) (flavor only — no stat data)
**Implementing Code**: [SimpleCharacterCreator.gd:68](src/core/character/Generation/SimpleCharacterCreator.gd#L68) (loads JSON), [SimpleCharacterCreator.gd:526-533](src/core/character/Generation/SimpleCharacterCreator.gd#L526-L533) (applies modifiers)
**Bonus Application**: [CharacterCreator.gd:339-355](src/core/character/Generation/CharacterCreator.gd#L339-L355) via [character_creation_bonuses.json](data/character_creation_bonuses.json) `origin_bonuses` section

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1A-001 | Human base stats | p.15 | `character_species.json:8` R:1, S:4, C:0, T:3, Sv:0 + special "Can exceed 1 point of Luck" | `SimpleCharacterCreator.gd:526` (modifiers all 0) | UNVERIFIED — needs book confirmation of base stats | | |
| 1A-002 | Engineer stats | p.16 | `character_species.json:34-35` T:-1, Sv:+1 + "T_max=4", "+1 repair rolls" | `character_creation_bonuses.json:10` key "2": T:-1, Sv:+1 | UNVERIFIED — needs book confirmation | | |
| 1A-003 | K'Erin stats | p.16 | `character_species.json:47` T:+1 + "brawl reroll", "must move to brawl" | `character_creation_bonuses.json:11` key "4": T:+1 | UNVERIFIED — needs book confirmation | | |
| 1A-004 | Soulless stats | p.17 | `character_species.json:58-59` T:+1, Sv:+1 + "6+ save", "no consumables/implants", "XP normally" | `character_creation_bonuses.json:12` key "6": T:+1, Sv:+1 | UNVERIFIED — needs book confirmation | | |
| 1A-005 | Precursor stats | p.17 | `character_species.json:73-74` S:+1, T:-1 + "2 char events pick preferred", "1 story point to avoid" | `character_creation_bonuses.json:13` key "5": S:+1, T:-1 + `CharacterCreator.gd:352` grants psionic | UNVERIFIED — needs book confirmation | | |
| 1A-006 | Feral stats | p.18 | `character_species.json:85-86` all modifiers 0 + "ignore seize penalty", "react 1 must go to Feral" | `character_creation_bonuses.json`: NO entry for Feral (key "3" missing) | **INCONSISTENCY** — species JSON has no stat mods but Appendix C #18 flags this as missing from bonuses JSON | | |
| 1A-007 | Swift stats | p.18 | `character_species.json:97-98` S:+1 + "glide", "leap 4\" gaps", "multi-shot same target" | `character_creation_bonuses.json:14` key "7": S:+1 | UNVERIFIED — needs book confirmation (Phase 43 fixed S+2→S+1 in base_stats, verify which is correct) | | |
| 1A-008 | Bot stats | p.15 | `character_species.json:17-18` R:+1, C:+1, T:+1, Sv:+2 + "no XP", "6+ save", "no consumables", "no events", "no leader luck" | `character_creation_bonuses.json:9` key "8": R:+1, C:+1, T:+1, Sv:+2 | UNVERIFIED — bot page listed as p.15, verify | | |
| 1A-009 | Strange Characters (15 types) | pp.19-22 | `character_species.json:108-318` — De-converted, Unity Agent, Mysterious Past, Hakshan, Stalker, Hulker, Hopeful Rookie, Genetic Uplift, Mutant, Assault Bot, Manipulator, Primitive, Feeler, Emo-suppressed, Minor Alien | `SimpleCharacterCreator.gd:492-500` searches both `primary_aliens` and `strange_characters` arrays | UNVERIFIED — book says 18 types (audit item says p.32), JSON has 15. **GAP?** Verify book count | | |
| 1A-010 | DLC: Krag stats | Compendium | `compendium_species.gd:27-56` T:+1, Sv:-1 + armor rules, no dash, belligerent reroll | `character_creation_bonuses.json:15` key "9": T:+1, Sv:-1 | UNVERIFIED — needs Compendium verification | | |
| 1A-011 | DLC: Skulker stats | Compendium | `compendium_species.gd:83-132` S:+1, T:-1 + difficult ground immunity, climb discount, bio resistance | `character_creation_bonuses.json:16` key "10": S:+1, T:-1 | UNVERIFIED — needs Compendium verification | | |
| 1A-012 | DLC: Prison Planet stats | Compendium | `compendium_species.gd:134-166` T:+1, C:+1 | `character_creation_bonuses.json:17` key "11": T:+1, C:+1 | UNVERIFIED — needs Compendium verification | | |

**Conditionals to verify**:
- Bot/Assault Bot: `rolls_creation_tables: false` → must skip background/motivation/class → check `CharacterCreator._populate_dropdowns()` disables these
- Precursor: `CharacterCreator.gd:352` grants random psionic → verify book says "begin with one randomly determined Psionic Power"
- Strange char forced backgrounds/motivations: `forced_motivation`, `forced_background`, `double_background`, `double_motivation` flags in JSON → verify code respects these
- Feral: Missing from `character_creation_bonuses.json` origin_bonuses — if Feral has no stat bonuses in book this is correct, if it does have bonuses this is a bug

### 1B: Background Table (pp.24-25)

**Data Sources**: [data/character_creation_tables/background_table.json](data/character_creation_tables/background_table.json) (D100 table with stat_bonuses, resources, equipment_rolls per entry)
**Implementing Code**: [CharacterCreator.gd:407](src/core/character/Generation/CharacterCreator.gd#L407) (loads JSON), [CharacterCreator.gd:471-483](src/core/character/Generation/CharacterCreator.gd#L471-L483) (applies bonuses via `_lookup_bonuses("background_bonuses", bg_id)`)
**Bonus Data**: [character_creation_bonuses.json:19-31](data/character_creation_bonuses.json) — 12 backgrounds with stat bonuses mapped by enum int ID
**Roll Function**: [CharacterCreationTables.gd:21](src/core/character/tables/CharacterCreationTables.gd#L21) — `roll_background_event()` (D66)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1B-001 | Background D100 ranges | pp.24-25 | `background_table.json` entries: "1-4" through "96-100" (26 backgrounds) | `CharacterCreator.gd:407` loads full table | UNVERIFIED — verify all 26 D100 range boundaries match book | | |
| 1B-002 | Background stat modifiers | pp.24-25 | `character_creation_bonuses.json:19-31` — 12 backgrounds have bonuses (Sv+1, S+1, T+1, C+1, R+1 variants) | `CharacterCreator.gd:479` applies via `_lookup_bonuses()` | UNVERIFIED — verify each bonus matches book. 14 backgrounds have no bonus — confirm this is correct | | |
| 1B-003 | Background count | pp.24-25 | 26 entries in `background_table.json` | N/A | UNVERIFIED — verify book has exactly 26 backgrounds | | |
| 1B-004 | Background resources | pp.24-25 | Some backgrounds grant `credits_roll: "1D6"` or `"2D6"`, `equipment_rolls` arrays | `StartingEquipmentGenerator.gd:120` — `_get_background_equipment()` | UNVERIFIED — verify resource grants per background | | |

### 1C: Motivation Table (p.26)

**Data Sources**: [data/character_creation_tables/motivation_table.json](data/character_creation_tables/motivation_table.json) (D100 table, marked "VERIFIED against Core Rules 3e Mar 22, 2026")
**Implementing Code**: [CharacterCreator.gd:409](src/core/character/Generation/CharacterCreator.gd#L409) (loads JSON), [CharacterCreator.gd:499-513](src/core/character/Generation/CharacterCreator.gd#L499-L513) (applies bonuses)
**Secondary Loader**: [SimpleCharacterCreator.gd:70](src/core/character/Generation/SimpleCharacterCreator.gd#L70)
**Bonus Data**: [character_creation_bonuses.json:50-55](data/character_creation_bonuses.json) — 5 motivations with stat bonuses + [character_creation_bonuses.json:58-60](data/character_creation_bonuses.json) campaign-level bonuses
**Roll Function**: [CharacterCreationTables.gd:39](src/core/character/tables/CharacterCreationTables.gd#L39) — `roll_motivation()` (D100)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1C-001 | Motivation D100 ranges | p.26 | `motivation_table.json` entries: "1-8" Wealth through "91-100" Freedom (14 motivations) | `CharacterCreator.gd:409` loads, `CharacterCreationTables.gd:39` rolls | UNVERIFIED — JSON header says "VERIFIED" but no verifier initials/date recorded here | | |
| 1C-002 | WEALTH bonus | p.26 | `motivation_table.json:9` credits_roll: "1D6" | `character_creation_bonuses.json:59` type: "credits", dice: "1D6" (applied in CampaignFinalizationService) | UNVERIFIED — verify +1D6 credits at finalization | | |
| 1C-003 | FAME bonus | p.26 | `motivation_table.json:16` story_points: 1 | `character_creation_bonuses.json:60` type: "story_points", amount: 1 | UNVERIFIED — verify +1 story point | | |
| 1C-004 | SURVIVAL stat bonus | p.26 | `motivation_table.json:29` toughness: 1 | `character_creation_bonuses.json:52` key "7": T:+1 | UNVERIFIED — verify Survival grants T+1 | | |
| 1C-005 | GLORY stat bonus | p.26 | `motivation_table.json:22-23` combat: 1, equipment_rolls: ["military_weapon"] | `character_creation_bonuses.json:51` key "3": C:+1 | UNVERIFIED — verify Glory grants C+1 + military weapon | | |
| 1C-006 | ESCAPE stat bonus | p.26 | `motivation_table.json:35` speed: 1, equipment_rolls: ["low_tech_weapon"] | `character_creation_bonuses.json:53` key "14": S:+1 | UNVERIFIED — verify Escape grants S+1 + low-tech weapon | | |
| 1C-007 | TECHNOLOGY stat bonus | p.26 | `motivation_table.json:57` savvy: 1, equipment_rolls: ["gear"] | `character_creation_bonuses.json:54` key "17": Sv:+1 | UNVERIFIED — verify Technology grants Sv+1 + gear | | |
| 1C-008 | DISCOVERY stat bonus | p.26 | `motivation_table.json:63` savvy: 1 | `character_creation_bonuses.json:55` key "10": Sv:+1 | UNVERIFIED — verify Discovery grants Sv+1 | | |
| 1C-009 | REVENGE special | p.26 | `motivation_table.json:79` special: { xp: 2 } | Not in `character_creation_bonuses.json` — applied where? | UNVERIFIED — verify Revenge grants +2 XP and trace applying code | | |
| 1C-010 | TRUTH special | p.26 | `motivation_table.json:51-52` quest_rumors: 1, story_points: 1, equipment_rolls: ["gadget"] | Not in stat bonuses — campaign-level | UNVERIFIED — verify Truth grants quest rumor + story point + gadget | | |

### 1D: Class Table (pp.26-27)

**Data Sources**: [data/character_creation_tables/class_table.json](data/character_creation_tables/class_table.json) (D100 table)
**Implementing Code**: [CharacterCreator.gd:408](src/core/character/Generation/CharacterCreator.gd#L408) (loads JSON), [CharacterCreator.gd:485-497](src/core/character/Generation/CharacterCreator.gd#L485-L497) (applies bonuses)
**Bonus Data**: [character_creation_bonuses.json:33-48](data/character_creation_bonuses.json) — 16 classes with stat bonuses mapped by enum int ID
**Equipment**: [StartingEquipmentGenerator.gd:113](src/core/character/Equipment/StartingEquipmentGenerator.gd#L113) — `_get_class_equipment()`

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1D-001 | Class D100 ranges | pp.26-27 | `class_table.json` entries: "1-5" Working Class through end (count TBD) | `CharacterCreator.gd:408` loads full table | UNVERIFIED — verify all D100 range boundaries | | |
| 1D-002 | Class stat modifiers | pp.26-27 | `character_creation_bonuses.json:33-48` — 16 classes: Sv+1 (Working Class, Technician, Scientist, Hacker, Starship Crew), C+1 (Soldier, Mercenary, Enforcer), S+1 (Primitive, Petty Criminal, Scoundrel, Bounty Hunter), R+1 (Ganger, Special Agent, Troubleshooter), Luck+1 (Working Class) | `CharacterCreator.gd:493` applies via `_lookup_bonuses()` | UNVERIFIED — verify each class bonus matches book | | |
| 1D-003 | Class count | pp.26-27 | At least 18 classes visible in `class_table.json` (Trader at range 45-49 visible, more follow) | N/A | UNVERIFIED — count full table and compare to book | | |
| 1D-004 | Class resources | pp.26-27 | Some classes grant credits_roll ("1D6", "2D6"), patron, rival, story_points | `StartingEquipmentGenerator.gd:113` + campaign finalization | UNVERIFIED — verify resource grants per class | | |

### 1E: Starting Equipment (p.36 / per-class tables)

**Data Sources**: [data/character_creation_tables/equipment_tables.json](data/character_creation_tables/equipment_tables.json) — `class_equipment` (9 classes) + `background_equipment` sections
**Implementing Code**: [StartingEquipmentGenerator.gd:179-180](src/core/character/Equipment/StartingEquipmentGenerator.gd#L179-L180) (loads JSON), [StartingEquipmentGenerator.gd:113](src/core/character/Equipment/StartingEquipmentGenerator.gd#L113) (`_get_class_equipment()`), [StartingEquipmentGenerator.gd:120](src/core/character/Equipment/StartingEquipmentGenerator.gd#L120) (`_get_background_equipment()`)
**UI Display**: [EquipmentPanel.gd:387-405](src/ui/screens/campaign/panels/EquipmentPanel.gd#L387-L405) (loads and displays in campaign creation Step 4)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1E-001 | Class-based starting equipment | pp.26-27 | `equipment_tables.json:3-56` — 9 class kits (soldier, scout, medic, engineer, pilot, merchant, security, broker, bot_tech) with weapons, armor, gear, credits | `StartingEquipmentGenerator.gd:113` | UNVERIFIED — **CONCERN**: JSON has 9 class kits but class_table has 18+ classes. Many classes may have no starting equipment defined | | |
| 1E-002 | Background-based starting gear | pp.24-25 | `equipment_tables.json:58+` — `background_equipment` section | `StartingEquipmentGenerator.gd:120` | UNVERIFIED — verify background equipment grants | | |
| 1E-003 | Equipment roll types | pp.24-27 | `background_table.json` and `motivation_table.json` reference `equipment_rolls`: "low_tech_weapon", "gear", "military_weapon", "gadget" | `StartingEquipmentGenerator.gd` processes these roll types | UNVERIFIED — verify each roll type maps to correct item pool | | |

### 1F: Connections (p.28)

**Data Sources**: [data/character_creation_tables/connections_table.json](data/character_creation_tables/connections_table.json) — `background_connections` (9 backgrounds) + `random_connections` (D6 table, 6 entries)
**Implementing Code**: [CharacterConnections.gd:154-155](src/core/character/connections/CharacterConnections.gd#L154-L155) (loads JSON), [CharacterConnections.gd:94](src/core/character/connections/CharacterConnections.gd#L94) (`_get_background_connections()`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1F-001 | Background-based connections | p.28 | `connections_table.json:3-38` — 9 background categories (military, mercenary, criminal, colonist, academic, explorer, trader, noble, outcast) with 2 contacts each | `CharacterConnections.gd:94` | UNVERIFIED — verify connection types per background | | |
| 1F-002 | Random connections D6 | p.28 | `connections_table.json:40-47` — 6 entries (Starport Official through Jealous Competitor rival) | `CharacterConnections.gd` | UNVERIFIED — verify D6 table matches book | | |
| 1F-003 | Patron/Rival generation rules | p.28 | Classes like Hacker and Agitator grant `rival: true`, Negotiator grants `patron: true` | `CharacterCreator.gd` processes class resources | UNVERIFIED — verify which classes grant patrons/rivals | | |

### 1G: Character Creation Bonuses (Cross-cutting)

**Data Sources**: [data/character_creation_bonuses.json](data/character_creation_bonuses.json) — Unified bonus lookup by GlobalEnums int values
**Implementing Code**: [CharacterCreator.gd:390-403](src/core/character/Generation/CharacterCreator.gd#L390-L403) (loads JSON), [CharacterCreator.gd:460-469](src/core/character/Generation/CharacterCreator.gd#L460-L469) (`_lookup_bonuses()` — central resolver)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 1G-001 | Origin bonus count | pp.15-18 | 9 entries in `origin_bonuses` (keys 2,4,5,6,7,8,9,10,11) — Human(1) and Feral(3) missing | `CharacterCreator.gd:347` | **INCONSISTENCY** — Human having no bonuses is likely correct, but Feral missing needs book verification (Appendix C #18) | | |
| 1G-002 | Background bonus count | pp.24-25 | 12 entries in `background_bonuses` out of 26 backgrounds — 14 have no stat bonus | `CharacterCreator.gd:479` | UNVERIFIED — verify which backgrounds have no stat bonus in book | | |
| 1G-003 | Class bonus count | pp.26-27 | 16 entries in `class_bonuses` | `CharacterCreator.gd:493` | UNVERIFIED — verify against full class list in book | | |
| 1G-004 | Motivation bonus count | p.26 | 5 entries in `motivation_bonuses` (Glory C+1, Survival T+1, Escape S+1, Technology Sv+1, Discovery Sv+1) + campaign bonuses | `CharacterCreator.gd:509` | UNVERIFIED — verify which motivations have stat bonuses vs campaign bonuses | | |
| 1G-005 | Strange char bonuses | pp.19-22 | `character_creation_bonuses.json` has NO strange character entries | `SimpleCharacterCreator.gd:526` applies from `character_species.json` stat_modifiers directly | **INCONSISTENCY** — Appendix C #17 flags 0/16 strange chars in bonuses JSON. CharacterCreator path may not apply strange char bonuses correctly | | |

---

## Chapter 2: Equipment & Weapons (Core Rules pp.40-58)

### Architecture Overview

**Three data sources** for weapons/equipment, plus a consolidated database:

| Source | File | Items | Purpose |
|--------|------|-------|---------|
| **Canonical** | [data/weapons.json](data/weapons.json) | 42 weapons (6 tagged GAME_BALANCE_ESTIMATE) | Per-weapon stats: range, shots, damage, traits, category |
| **Consolidated** | [data/equipment_database.json](data/equipment_database.json) | All equipment types | Combined weapons+armor+gear for EquipmentManager |
| **Constants** | [LootSystemConstants.gd](src/core/systems/LootSystemConstants.gd) | 20+ weapon defs | Loot generation with quality modifiers |
| **Armor** | [data/armor.json](data/armor.json) | 9 armor/screen items | Saving throws, stat bonuses, effects |
| **Implants** | [data/implants.json](data/implants.json) | 11 implant types | Stat bonuses, special abilities |
| **Onboard** | [data/onboard_items.json](data/onboard_items.json) | ? | **NOT WIRED** — no GDScript consumer |

> **WARNING**: 11 weapon stat mismatches between weapons.json and LootSystemConstants.gd were FIXED in Phase 46 (Appendix C #1-11). Verify no new drift has occurred.

**Key Functions**:

- [EquipmentManager.gd:44-71](src/core/equipment/EquipmentManager.gd#L44-L71) — `_load_equipment_database()` loads `equipment_database.json` (primary entry point)
- [EquipmentManager.gd:382-393](src/core/equipment/EquipmentManager.gd#L382-L393) — `create_weapon_item()`
- [EquipmentManager.gd:396-422](src/core/equipment/EquipmentManager.gd#L396-L422) — `create_armor_item()`
- [EquipmentManager.gd:545-567](src/core/equipment/EquipmentManager.gd#L545-L567) — `_calculate_weapon_value()`
- [EquipmentManager.gd:615-677](src/core/equipment/EquipmentManager.gd#L615-L677) — `upgrade_weapon()`
- [EquipmentManager.gd:891-959](src/core/equipment/EquipmentManager.gd#L891-L959) — Market generation (weapon/armor/gear by quality 1-5)
- [LootSystemConstants.gd](src/core/systems/LootSystemConstants.gd) — `get_weapon_from_subtable()`, `get_gear_from_subtable()`, `get_odds_and_ends_from_subtable()`
- [TradingSystem.gd:82-84](src/core/systems/TradingSystem.gd#L82-L84) — Fallback loader for individual JSON files
- [Character.gd:907-948](src/core/character/Character.gd#L907-L948) — Implant loading and creation

**Fallback Pattern**: `TradingSystem.gd` falls back to `weapons.json`, `armor.json`, `gear_database.json` individually if `equipment_database.json` fails to load.

**Test Files**:

- [tests/unit/test_equipment_classes.gd](tests/unit/test_equipment_classes.gd) — Equipment class definitions
- [tests/integration/phase2_backend/test_equipment_management.gd](tests/integration/phase2_backend/test_equipment_management.gd) — Equipment management integration

### 2A: Weapon Stats Table (p.50)

**Data Sources**: [data/weapons.json](data/weapons.json) (42 weapons), [data/equipment_database.json](data/equipment_database.json), [LootSystemConstants.gd](src/core/systems/LootSystemConstants.gd) (20+ weapon defs)
**Implementing Code**: [EquipmentManager.gd:44-71](src/core/equipment/EquipmentManager.gd#L44-L71) (loads consolidated DB), [TradingSystem.gd:82](src/core/systems/TradingSystem.gd#L82) (fallback)
**Battle Usage**: `BattleResolver.gd`, `BattleCalculations.gd` — consume weapon range/damage/traits during combat resolution

> **WARNING**: 11 weapon stat mismatches between weapons.json and LootSystemConstants.gd were FIXED in Phase 46 (Appendix C #1-11). 6 weapons tagged `GAME_BALANCE_ESTIMATE` need Core Rules verification.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2A-001 | Weapon names (42 total) | p.50 | `weapons.json:7-48` — 42 weapons from Auto Rifle to Shock Grenade | `EquipmentManager.gd:44` loads consolidated DB | UNVERIFIED — 6 weapons tagged GAME_BALANCE_ESTIMATE (carbine, laser_rifle, plasma_pistol, auto_cannon, missile_launcher, shock_grenade). Verify all 42 names exist in book, or if some are invented | | |
| 2A-002 | Weapon ranges | p.50 | `weapons.json` range field per weapon (4-36 inches) | `BattleCalculations.gd` uses range for combat | UNVERIFIED — Phase 46 fixed 11 mismatches vs LootSystemConstants. Book verification still needed | | |
| 2A-003 | Weapon shots | p.50 | `weapons.json` shots field (0-3) | `BattleResolver.gd` uses shots for attack resolution | UNVERIFIED — needs book verification | | |
| 2A-004 | Weapon damage | p.50 | `weapons.json` damage field (0-3 modifier) | `BattleCalculations.gd` uses for damage resolution | UNVERIFIED — needs book verification | | |
| 2A-005 | Weapon traits | p.50+ | `weapons.json` traits arrays (Pistol, Critical, Heavy, Melee, Elegant, Piercing, Focused, Area, Stun, Snap Shot, Impact, Clumsy, Single use) | `keywords.json` defines trait effects | UNVERIFIED — verify all trait names and which weapons have which traits | | |
| 2A-006 | Weapon count | p.50 | 42 in `weapons.json`, 6 tagged GAME_BALANCE_ESTIMATE | N/A | UNVERIFIED — book weapon count unknown. **Possible 36 real + 6 invented?** | | |
| 2A-007 | Weapon categories | p.50 | 5 categories: slug (13), energy (8), melee (7), special (5), grenade (3) + GAME_BALANCE tagged (6) | `weapons.json` category field | UNVERIFIED — verify category assignments match book | | |

### 2B: Armor & Screens (pp.54-55)

**Data Sources**: [data/armor.json](data/armor.json) (9 items — armor + screens), [data/equipment_database.json](data/equipment_database.json)
**Implementing Code**: [EquipmentManager.gd:396-422](src/core/equipment/EquipmentManager.gd#L396-L422) (`create_armor_item()`), [EquipmentManager.gd:569-590](src/core/equipment/EquipmentManager.gd#L569-L590) (`_calculate_armor_value()`)
**Battle Usage**: `BattleResolver.gd` — armor save checks, `Character.gd:994-1017` — `get_effective_stat()`
**Rules**: Max 1 armor + 1 screen per character (`armor.json:5-7`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2B-001 | Armor types (9 items) | pp.54-55 | `armor.json:21-end` — Battle Dress (5+ save, R+1), Camo Cloak (screen, cover extension), plus 7 more | `EquipmentManager.gd:396` creates armor items | UNVERIFIED — verify all 9 types exist in book and none are missing | | |
| 2B-002 | Armor save values | pp.54-55 | `armor.json` `armor_save` field per item (0-5) + `effects.saving_throw` (e.g. "5+") | `BattleResolver.gd` checks saving throws | UNVERIFIED — verify each save value matches book | | |
| 2B-003 | Armor stat bonuses | pp.54-55 | `armor.json` `effects.stat_bonus` (e.g. Battle Dress: R+1 with cap R:4) | `Character.gd` applies via equipment stats | UNVERIFIED — verify stat bonuses per armor type | | |
| 2B-004 | Max armor/screen rule | pp.54-55 | `armor.json:5-7` max_armor: 1, max_screen: 1 | Verify enforcement in code | UNVERIFIED — verify rule is enforced when equipping | | |

### 2C: Gear & Consumables (pp.56-57)

**Data Sources**: [data/gear_database.json](data/gear_database.json), [data/equipment_database.json](data/equipment_database.json)
**Implementing Code**: [EquipmentManager.gd:343](src/core/equipment/EquipmentManager.gd#L343) — utility item generation, [EquipmentManager.gd:937-959](src/core/equipment/EquipmentManager.gd#L937-L959) — market gear generation
**Consumables**: [LootSystemConstants.gd](src/core/systems/LootSystemConstants.gd) — 6 consumable types (Booster Pills, Combat Serum, Kiranin Crystals, Rage Out, Still, Stim-pack)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2C-001 | Gear items list | pp.56-57 | `gear_database.json` + `equipment_database.json` gear section | `EquipmentManager.gd:937` generates for market | UNVERIFIED — count gear items and compare to book | | |
| 2C-002 | Gear effects | pp.56-57 | Per-item effect descriptions in JSON | `EquipmentManager.gd` applies effects | UNVERIFIED — verify each effect matches book | | |
| 2C-003 | Consumable types (6) | pp.56-57 | `LootSystemConstants.gd` — Booster Pills, Combat Serum, Kiranin Crystals, Rage Out, Still, Stim-pack | `EquipmentManager.gd:992-1005` `use_consumable()` | UNVERIFIED — verify all 6 exist in book, check if Kiranin Crystals is DLC-only | | |

### 2D: Implants (p.55)

**Data Sources**: [data/implants.json](data/implants.json) (11 types, max 2 per character)
**Implementing Code**: [Character.gd:900](src/core/character/Character.gd#L900) (`MAX_IMPLANTS = 2`), [Character.gd:907-948](src/core/character/Character.gd#L907-L948) (loading + creation), [Character.gd:950-977](src/core/character/Character.gd#L950-L977) (add/remove)
**PostBattle Integration**: [LootProcessor.gd:75](src/core/campaign/phases/post_battle/LootProcessor.gd#L75) — implant loot routing

> **CORRECTION**: CLAUDE.md says "6 types, max 3" — actual data has **11 types, max 2**. Both `implants.json:86` and `Character.gd:900` agree on max 2. CLAUDE.md needs updating.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2D-001 | Implant types (11) | p.55 | `implants.json:6-83` — AI Companion, Body Wire, Boosted Arm, Boosted Leg, Cyber Hand, Genetic Defenses, Health Boost, Nerve Adjuster, Neural Optimization, Night Sight, Pain Suppressor | `Character.gd:923-948` creates from type/loot name | UNVERIFIED — **book says how many types?** JSON has 11. Verify count and names | | |
| 2D-002 | Implant stat bonuses | p.55 | `implants.json` `stat_bonus` field — Body Wire (R+1), Boosted Leg (S+1), others have special abilities only | `Character.gd:979-992` `get_implant_bonuses()` sums stat bonuses | UNVERIFIED — verify each implant's effect matches book | | |
| 2D-003 | Max implants per char | p.55 | `implants.json:86` max_per_character: 2, `Character.gd:900` MAX_IMPLANTS: 2 | `Character.gd:956` enforces limit | UNVERIFIED — **CLAUDE.md says 3, code says 2**. Verify book value | | |
| 2D-004 | Species restrictions | p.55 | `implants.json:89` "Bots and Soulless cannot use implants" | `Character.gd:950-970` validation in `add_implant()` | UNVERIFIED — verify Bot/Soulless restriction matches book | | |
| 2D-005 | Psionic incompatibility | p.96 | `Character.gd:952` WARNING comment: "Psionics lose all powers permanently" | `Character.gd:964+` enforced in `add_implant()` | UNVERIFIED — verify Core Rules p.96 states this rule | | |
| 2D-006 | Removal rule | p.55 | `implants.json:87` "Cannot be removed once applied" | No removal UI exists (only `remove_implant()` for serialization) | UNVERIFIED — verify book states non-removable | | |

### 2E: Weapon Trait Definitions

**Data Sources**: [data/weapons.json](data/weapons.json) trait arrays, [data/keywords.json](data/keywords.json) (trait definitions)
**Implementing Code**: `BattleResolver.gd` applies trait effects during combat, `keywords.json` provides tooltip definitions for `KeywordDB` autoload

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2E-001 | Trait names | p.50+ | `weapons.json` uses: Pistol, Critical, Heavy, Melee, Elegant, Piercing, Focused, Area, Stun, Snap Shot, Impact, Clumsy, Single use, Terrifying | `keywords.json` defines each trait | UNVERIFIED — verify all trait names match book terminology | | |
| 2E-002 | Trait effects | p.50+ | `keywords.json` descriptions per trait | `BattleResolver.gd` implements mechanical effects | UNVERIFIED — verify each trait's mechanical effect matches book | | |

### 2F: Onboard Items

**Data Sources**: [data/onboard_items.json](data/onboard_items.json)
**Implementing Code**: **NONE** — grep finds zero GDScript consumers. Data file exists but is not wired.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2F-001 | Onboard item list | p.59+ | `onboard_items.json` exists | **NO CONSUMER** — file is not loaded by any GDScript | **MISSING** — data exists but not wired to gameplay code | | |

### 2G: Equipment Quality System

**Data Sources**: [LootSystemConstants.gd](src/core/systems/LootSystemConstants.gd) — ItemQuality enum and QUALITY_MODIFIERS
**Implementing Code**: `LootSystemConstants.gd` applies quality at loot generation, `EquipmentManager.gd` uses for sell value

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 2G-001 | Quality tiers (6) | p.? | `LootSystemConstants.gd` ItemQuality: DAMAGED, WORN, STANDARD, QUALITY, MILITARY, ARTIFACT | Applied at loot generation | UNVERIFIED — verify book has quality system and tier names match | | |
| 2G-002 | Sell value multipliers | p.? | `LootSystemConstants.gd` QUALITY_MODIFIERS per tier | `EquipmentManager.gd` `get_sell_value()` | UNVERIFIED — verify sell formula matches book | | |

---

## Chapter 3: Ships (Core Rules pp.59-65)

### 3A: Ship Types & Hull

**Data Sources**: `data/ships.json`, `data/ship_components.json`

| ID | Item | Page | What to Verify | Status | By | Date |
|----|------|------|---------------|--------|-----|------|
| 3A-001 | Ship type names (13 types) | p.31 | Book has 13 types; code has 7 fabricated types. FULL REWRITE NEEDED | **INCORRECT** | User | 2026-03-22 |
| 3A-002 | Hull point ranges | p.31 | Book: 20-40. Code was "fixed" from 20-35 → 6-14 — BOTH WRONG. Phase 30 "fix" moved values FURTHER from book | **INCORRECT** | User | 2026-03-22 |
| 3A-003 | Starting ship debt | p.31 | Book: 1D6+10 to 1D6+35. Code was "fixed" from 12-38 → 0-5 — BOTH WRONG. Original was closer to correct | **INCORRECT** | User | 2026-03-22 |
| 3A-004 | Ship component types | p.31+ | All components from book | UNVERIFIED | | |
| 3A-005 | Ship traits | p.31+ | Trait list and effects | UNVERIFIED | | |
| 3A-006 | Ship type count | p.31 | Book has 13; code has 7 | **INCORRECT** | User | 2026-03-22 |

---

## Chapter 4: Campaign Turn — Travel (Core Rules pp.70-79)

### Architecture Overview

**Dual-source pattern** — JSON canonical data + hardcoded fallback in GDScript:

**Key Functions**:

- [TravelPhase.gd:202-233](src/core/campaign/phases/TravelPhase.gd#L202-L233) — `_initialize_travel_tables()` loads events from JSON, hardcodes world traits
- [TravelPhase.gd:235-256](src/core/campaign/phases/TravelPhase.gd#L235-L256) — `_load_travel_events_from_json()` loads `event_tables.json`
- [TravelPhase.gd:696-722](src/core/campaign/phases/TravelPhase.gd#L696-L722) — Rival following + license cost D6 rolls
- [TravelPhase.gd:316-323](src/core/campaign/phases/TravelPhase.gd#L316-L323) — Invasion escape 2D6 roll
- [TravelPhaseUI.gd:33-34](src/ui/screens/travel/TravelPhaseUI.gd#L33-L34) — Mirrored cost constants (SHIP_TRAVEL_COST=5)
- [TravelPhaseUI.gd:456-535](src/ui/screens/travel/TravelPhaseUI.gd#L456-L535) — Travel event D100 processing in UI

**Test Files**: **NONE** — No dedicated travel phase tests found. Gap.

### 4A: Travel Event Table D100 (pp.72-75)

**Data Sources**: [data/event_tables.json](data/event_tables.json) (16 travel events with D100 ranges)
**Implementing Code**: [TravelPhase.gd:206](src/core/campaign/phases/TravelPhase.gd#L206) (loads JSON), [TravelPhase.gd:258-277](src/core/campaign/phases/TravelPhase.gd#L258-L277) (hardcoded fallback)
**UI Processing**: [TravelPhaseUI.gd:456-535](src/ui/screens/travel/TravelPhaseUI.gd#L456-L535)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 4A-001 | D100 roll ranges (16 events) | pp.72-75 | `event_tables.json` ranges [1,7] through [96,100] | `TravelPhase.gd:206` loads, `TravelPhaseUI.gd:456` processes | UNVERIFIED — verify all 16 boundary values match book | | |
| 4A-002 | Event names | pp.72-75 | `event_tables.json` name fields | `TravelPhaseUI.gd:456-535` displays | UNVERIFIED — verify all 16 event names | | |
| 4A-003 | Event effects | pp.72-75 | `event_tables.json` effect fields | `TravelPhaseUI.gd` applies effects | UNVERIFIED — verify mechanical outcomes per event | | |
| 4A-004 | Fallback table sync | N/A | `TravelPhase.gd:258-277` hardcoded fallback | Must match `event_tables.json` exactly | UNVERIFIED — **RISK**: dual-source may drift | | |

### 4B: World Traits D100 (p.77)

**Data Sources**: [data/world_traits.json](data/world_traits.json) (25 trait definitions, NO D100 ranges), [TravelPhase.gd:210-233](src/core/campaign/phases/TravelPhase.gd#L210-L233) (hardcoded D100 ranges)

> **WARNING**: World trait D100 ranges are HARDCODED in TravelPhase.gd, not loaded from JSON. `world_traits.json` contains only trait descriptions. D100 ranges are a single source (GDScript only).

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 4B-001 | World trait D100 ranges | p.77 | N/A — hardcoded only | `TravelPhase.gd:210-220`: Frontier [1,15], Trade Hub [16,30], Industrial [31,45], Research [46,60], Criminal [61,75], Affluent [76,85], Dangerous [86,92], Corporate [93,97], Military [98,100] | UNVERIFIED — verify 9 ranges match book | | |
| 4B-002 | World trait effects | p.77 | `world_traits.json` has 25 trait definitions with trait_type | Traits applied via WorldPhaseComponent pipeline | UNVERIFIED — verify trait mechanical effects | | |
| 4B-003 | Fallback table names differ | N/A | Primary table (line 210-220) vs fallback (line 223-233) have DIFFERENT names (e.g. "Criminal" vs "Pirate Haven") | Only primary uses GlobalEnums.WorldTrait | **INCONSISTENCY** — fallback table has divergent names, should match primary | | |

### 4C: Travel Costs & Rules

**Data Sources**: [FiveParsecsConstants.gd:132](src/core/systems/FiveParsecsConstants.gd#L132) (`starship_travel: 5`), [TravelPhase.gd:30](src/core/campaign/phases/TravelPhase.gd#L30) (local copy), [TravelPhaseUI.gd:33](src/ui/screens/travel/TravelPhaseUI.gd#L33) (UI mirror)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 4C-001 | Starship travel cost | p.64 | `FiveParsecsConstants.gd:132` starship_travel: 5 (VERIFIED comment) | `TravelPhase.gd:30,116`, `TravelPhaseUI.gd:33` all say 5 | UNVERIFIED — code says "VERIFIED" but no verifier initials | | |
| 4C-002 | Commercial passage cost | p.64 | `FiveParsecsConstants.gd:133` commercial_passage_per_crew: 1 | `TravelPhaseUI.gd:34` COMMERCIAL_TRAVEL_COST_PER_CREW=1 | UNVERIFIED — verify 1 credit per crew member | | |
| 4C-003 | License costs D6 | p.66 | `TravelPhase.gd:716-722` D6: 1-2=none, 3-4=basic(10cr), 5-6=full(20cr) | Hardcoded in TravelPhase.gd | UNVERIFIED — verify D6 thresholds and costs match book | | |
| 4C-004 | Rival following D6 | p.65 | `TravelPhase.gd:702-703` D6 per rival, follows on roll ≤ 3 | Hardcoded | UNVERIFIED — verify threshold is 1-3 (50%) | | |
| 4C-005 | Invasion escape 2D6 | p.65 | `TravelPhase.gd:319-323` 2D6 roll, escape on ≥ 8 | Hardcoded | UNVERIFIED — verify 8+ threshold | | |
| 4C-006 | Ship trait fuel modifiers | p.25 | `TravelPhase.gd:121-139` Fuel-efficient: -1, Fuel Hog: +1, per-3-components: +1, Fuel Converters: -2 | Hardcoded | UNVERIFIED — verify all 4 modifiers match book | | |

---

## Chapter 5: World Phase — Upkeep (Core Rules pp.76-86)

### Architecture Overview

**Key Functions**:

- [FiveParsecsConstants.gd:123](src/core/systems/FiveParsecsConstants.gd#L123) — `base_upkeep: 1` (canonical)
- [WorldEconomyManager.gd:7](src/core/managers/WorldEconomyManager.gd#L7) — `BASE_UPKEEP_COST: 100` (100x scale)
- [WorldPhase.gd:48](src/core/campaign/phases/WorldPhase.gd#L48) — References FiveParsecsConstants.ECONOMY.base_upkeep
- [CampaignPhaseManager.gd:810](src/core/campaign/CampaignPhaseManager.gd#L810) — Upkeep calculation formula
- [UpkeepPhaseComponent.gd:33-35](src/ui/screens/world/components/UpkeepPhaseComponent.gd#L33-L35) — UI constants (BASE_CREW_UPKEEP_PER_MEMBER=1)
- [UpkeepPhaseComponent.gd:86](src/ui/screens/world/components/UpkeepPhaseComponent.gd#L86) — `calculate_upkeep_costs()`
- [CrewTaskComponent.gd:35](src/ui/screens/world/components/CrewTaskComponent.gd#L35) — `_load_crew_tasks()` loads JSON
- [CrewTaskComponent.gd:306](src/ui/screens/world/components/CrewTaskComponent.gd#L306) — `_resolve_single_task()`

**Test Files**:

- [tests/unit/ui/screens/campaign/test_upkeep_phase_ui.gd](tests/unit/ui/screens/campaign/test_upkeep_phase_ui.gd)
- [tests/integration/test_world_phase_effects.gd](tests/integration/test_world_phase_effects.gd)

### 5A: Upkeep Costs

**Data Sources**: [FiveParsecsConstants.gd:123](src/core/systems/FiveParsecsConstants.gd#L123), [WorldEconomyManager.gd:7](src/core/managers/WorldEconomyManager.gd#L7), [data/campaign_rules.json](data/campaign_rules.json)
**Implementing Code**: [CampaignPhaseManager.gd:810](src/core/campaign/CampaignPhaseManager.gd#L810), [UpkeepPhaseComponent.gd:86-151](src/ui/screens/world/components/UpkeepPhaseComponent.gd#L86-L151)

> **WARNING**: Appendix C #12-14 — Three-way upkeep conflict: `FiveParsecsConstants.gd: 1`, `campaign_rules.json: 6`, `WorldEconomyManager.gd: 100`. Needs book verification.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 5A-001 | Base upkeep cost | p.76 | `FiveParsecsConstants.gd:123` base_upkeep: 1 (per 4-6 crew) vs `campaign_rules.json`: 6 vs `WorldEconomyManager.gd:7`: 100 | `CampaignPhaseManager.gd:810` uses FiveParsecsConstants | **CONFLICT** — Appendix C #12. Three sources disagree. Book value needed | | |
| 5A-002 | Ship maintenance cost | p.76 | `UpkeepPhaseComponent.gd:34` SHIP_MAINTENANCE_BASE_COST=1 | `UpkeepPhaseComponent.gd:122` `_calculate_ship_maintenance()` | UNVERIFIED — verify base ship maintenance | | |
| 5A-003 | Damaged ship multiplier | p.76 | `UpkeepPhaseComponent.gd:35` DAMAGED_SHIP_MULTIPLIER=2.0 | Applied at line 128 | UNVERIFIED — verify 2x for damaged ships | | |
| 5A-004 | World trait upkeep modifier | pp.87-89 | `UpkeepPhaseComponent.gd:96-98` high_cost trait adds +2 effective crew size | Applied in `calculate_upkeep_costs()` | UNVERIFIED — verify high_cost world trait effect | | |

### 5B: Crew Task Thresholds (pp.76-82)

**Data Sources**: [data/campaign_tables/crew_tasks/crew_task_resolution.json](data/campaign_tables/crew_tasks/crew_task_resolution.json), [data/campaign_tables/world_phase/crew_task_modifiers.json](data/campaign_tables/world_phase/crew_task_modifiers.json)
**Implementing Code**: [WorldPhase.gd:540-850](src/core/campaign/phases/WorldPhase.gd#L540-L850) (task resolution methods), [CrewTaskComponent.gd:306](src/ui/screens/world/components/CrewTaskComponent.gd#L306) (`_resolve_single_task()`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 5B-001 | Find Patron threshold | p.82 | `crew_task_resolution.json` FIND_PATRON base_difficulty: 5 | `WorldPhase.gd:540-600` + `CrewTaskComponent.gd:306` | UNVERIFIED — verify 2D6 threshold value | | |
| 5B-002 | Recruit threshold | p.82 | `crew_task_resolution.json` RECRUIT difficulty | `WorldPhase.gd:701-750` | UNVERIFIED — verify D6 threshold | | |
| 5B-003 | Track threshold | p.83 | `crew_task_resolution.json` TRACK difficulty | `WorldPhase.gd:801-850` | UNVERIFIED — verify D6 threshold | | |
| 5B-004 | Explore outcomes | p.83 | `crew_task_resolution.json` EXPLORE outcomes | `WorldPhase.gd:751-800` | UNVERIFIED — verify D100 outcome ranges | | |
| 5B-005 | Trade D6 table | p.82 | `crew_task_resolution.json` TRADE outcomes | `WorldPhase.gd:651-700` | UNVERIFIED — verify all 6 outcomes | | |
| 5B-006 | Train automatic success | p.82 | `crew_task_resolution.json` TRAIN automatic_success: true | `WorldPhase.gd:601-650` | UNVERIFIED — verify training is automatic | | |
| 5B-007 | Task modifiers | pp.76-82 | `crew_task_modifiers.json` per-task modifiers (CONNECTIONS +2, SAVVY +1, etc.) | `CrewTaskComponent.gd:306` applies during resolution | UNVERIFIED — verify all modifier values match book | | |

### 5C: Patron Jobs & Opportunity Missions

**Data Sources**: [data/campaign_tables/world_phase/patron_jobs.json](data/campaign_tables/world_phase/patron_jobs.json), [data/missions/opportunity_missions.json](data/missions/opportunity_missions.json)
**Implementing Code**: [CrewTaskComponent.gd:427](src/ui/screens/world/components/CrewTaskComponent.gd#L427) (`_generate_and_add_patron()`), [WorldPhase.gd:540-600](src/core/campaign/phases/WorldPhase.gd#L540-L600) (patron resolution)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 5C-001 | Patron contact 2D6 thresholds | p.84 | `patron_jobs.json`: 2-6=no_contact, 7-8=minor, 9-10=regular, 11=major, 12=elite | `CrewTaskComponent.gd:427` generates patrons | UNVERIFIED — verify tier thresholds | | |
| 5C-002 | Patron modifier values | p.84 | `patron_jobs.json` modifiers: CONNECTIONS +2, SAVVY +1 | Applied during task resolution | UNVERIFIED — verify modifier values | | |
| 5C-003 | Opportunity mission table | p.84 | `opportunity_missions.json` mission definitions | Mission generation system | UNVERIFIED — verify mission types and rules | | |

---

## Chapter 6: Battle Setup (Core Rules pp.87-95)

### Architecture Overview

**Key Files**:

- [EnemyGenerator.gd](src/core/systems/EnemyGenerator.gd) (570 lines) — Enemy count, category, stat block generation
- [BattleResolver.gd](src/core/battle/BattleResolver.gd) (600+ lines) — Combat round execution, damage resolution
- [BattleCalculations.gd](src/core/battle/BattleCalculations.gd) (700+ lines) — Hit/damage formulas, armor saves
- [SeizeInitiativeSystem.gd](src/core/battle/SeizeInitiativeSystem.gd) (253 lines) — Initiative 2D6 + Savvy vs target 10
- [MoralePanicTracker.gd](src/core/battle/MoralePanicTracker.gd) (225 lines) — Morale checks, panic outcomes
- [PreBattleUI.gd](src/ui/screens/battle/PreBattleUI.gd) (334 lines) — Pre-battle setup display
- [TacticalBattleUI.gd](src/ui/screens/battle/TacticalBattleUI.gd) — Main battle UI (3-tier: LOG_ONLY/ASSISTED/FULL_ORACLE)

**Test Files** (22 files): `tests/unit/test_battle_calculations.gd`, `tests/unit/test_difficulty_modifiers_battle.gd`, `tests/integration/test_battle_setup_data.gd`, `tests/integration/test_battle_results.gd`, and 18 more in `tests/battle/`, `tests/unit/`, `tests/integration/`.

### 6A: Enemy Generation

**Data Sources**: [data/enemy_types.json](data/enemy_types.json), [data/enemy_presets.json](data/enemy_presets.json), [data/elite_enemy_types.json](data/elite_enemy_types.json), [data/RulesReference/Bestiary.json](data/RulesReference/Bestiary.json)
**Implementing Code**: [EnemyGenerator.gd:40](src/core/systems/EnemyGenerator.gd#L40) (loads enemy_types.json), [EnemyGenerator.gd:211-215](src/core/systems/EnemyGenerator.gd#L211-L215) (crew-size dice formula)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 6A-001 | Enemy count: crew 6 | p.88 | N/A — hardcoded formula | `EnemyGenerator.gd:212-215` 2D6 pick HIGHER (with CHALLENGING reroll of 1-2 at line 200-204) | UNVERIFIED — verify 2D6-pick-higher for crew 6 | | |
| 6A-002 | Enemy count: crew 5 | p.88 | N/A — hardcoded | `EnemyGenerator.gd` 1D6 | UNVERIFIED — verify 1D6 for crew 5 | | |
| 6A-003 | Enemy count: crew 4 | p.88 | N/A — hardcoded | `EnemyGenerator.gd` 2D6 pick LOWER | UNVERIFIED — verify 2D6-pick-lower for crew 4 | | |
| 6A-004 | Enemy category mapping | pp.63-65 | `enemy_types.json` + `EnemyGenerator.gd:108-159` `_determine_enemy_category()` | Match statement on mission_type | UNVERIFIED — verify mission→enemy type mapping | | |
| 6A-005 | Enemy stat blocks | pp.63-65 | `enemy_types.json`, `Bestiary.json` | `EnemyGenerator.gd:296-316` `_get_enemy_template_from_json()` | UNVERIFIED — verify all enemy combat/toughness/weapon stats | | |
| 6A-006 | Unique individual threshold | p.88 | `EnemyGenerator.gd:325-327` threshold from JSON `unique_chance` field | `EnemyGenerator.gd:318-362` `_select_individual_enemy()` | UNVERIFIED — verify unique roll threshold | | |
| 6A-007 | CHALLENGING reroll rule | p.88 | `EnemyGenerator.gd:200-204` rerolls dice results of 1-2 once | Hardcoded in lambda | UNVERIFIED — verify reroll-before-picking rule | | |

### 6B: Deployment & Initiative

**Data Sources**: [data/deployment_conditions.json](data/deployment_conditions.json), [SeizeInitiativeSystem.gd](src/core/battle/SeizeInitiativeSystem.gd)
**Implementing Code**: [BattleResolver.gd:130-192](src/core/battle/BattleResolver.gd#L130-L192) (deployment condition effects), [SeizeInitiativeSystem.gd:153-178](src/core/battle/SeizeInitiativeSystem.gd#L153-L178) (`roll_initiative()`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 6B-001 | Deployment conditions | p.89 | `deployment_conditions.json` — ambush, surrounded, defensive, headlong assault, outnumbered | `BattleResolver.gd:145-175` applies condition effects | UNVERIFIED — verify all conditions and effects | | |
| 6B-002 | Initiative: 2D6 + Savvy vs 10 | p.117 | `SeizeInitiativeSystem.gd:157-172` 2D6 + highest_savvy + modifiers, target=10 | `SeizeInitiativeSystem.gd:172` success = total >= target | UNVERIFIED — book may say D6 not 2D6, or target may differ. **Verify mechanism** | | |
| 6B-003 | Difficulty modifiers | p.117 | `SeizeInitiativeSystem.gd:110-115` NORMAL/CHALLENGING=0, HARDCORE=-2, INSANITY=-3 | Hardcoded in `set_difficulty_mode()` | UNVERIFIED — verify modifier values per difficulty | | |
| 6B-004 | Equipment modifiers | p.117 | `SeizeInitiativeSystem.gd:132-143` Motion Tracker +1, Scanner Bot +1 | Hardcoded | UNVERIFIED — verify equipment initiative bonuses | | |
| 6B-005 | Feral ignore penalty | p.18 | `SeizeInitiativeSystem.gd:221-222` Feral ignores negative enemy type modifiers | Species special rule | UNVERIFIED — verify Feral initiative rule matches species JSON and book | | |

### 6C: Combat Resolution (pp.91-95)

**Implementing Code**: [BattleCalculations.gd:65-161](src/core/battle/BattleCalculations.gd#L65-L161) (hit calculation), [BattleCalculations.gd:163-300](src/core/battle/BattleCalculations.gd#L163-L300) (damage resolution), [BattleCalculations.gd:282-331](src/core/battle/BattleCalculations.gd#L282-L331) (armor/screen saves)
**Brawl System**: [BattleCalculations.gd:444-634](src/core/battle/BattleCalculations.gd#L444-L634)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 6C-001 | Hit thresholds | pp.91-95 | `BattleCalculations.gd:65-67` OPEN_CLOSE=3, OPEN_RANGE=5, COVER_CLOSE=5, COVER_RANGE=6 | `BattleCalculations.gd:115-155` `calculate_hit_threshold()` | UNVERIFIED — verify 4 hit thresholds match book | | |
| 6C-002 | Natural 6 critical | pp.91-95 | `BattleCalculations.gd:175` natural 6 = instant kill (or double damage with brutal_combat) | Hardcoded | UNVERIFIED — verify critical hit rule | | |
| 6C-003 | Armor save thresholds | pp.54-55 | `BattleCalculations.gd:203-234` None=7, Light=6, Combat=5, Battle Suit=4, Powered=3 | `get_armor_save_threshold()` | UNVERIFIED — verify 5 tier thresholds | | |
| 6C-004 | Screen saves (checked FIRST) | pp.54-55 | `BattleCalculations.gd:300-306` screen checked before armor, NOT affected by piercing | `resolve_saves()` priority order | UNVERIFIED — verify screen-first priority and piercing immunity | | |
| 6C-005 | Brawl mechanics | pp.91-95 | `BattleCalculations.gd:444-634` melee weapon +2, pistol +1, natural 6 extra hit, natural 1 penalty | `resolve_brawl()` | UNVERIFIED — verify brawl modifier values | | |
| 6C-006 | K'Erin brawl reroll | p.16 | `BattleCalculations.gd:491-496` rolls twice, picks higher | Species special rule implementation | UNVERIFIED — verify K'Erin gets double-roll in brawl | | |
| 6C-007 | Morale check triggers | p.114 | `MoralePanicTracker.gd:72-80` triggers when first casualty in round | Casualty-based trigger | UNVERIFIED — verify trigger condition | | |
| 6C-008 | Morale roll 2D6 | p.114 | `MoralePanicTracker.gd:83-126` 2D6 vs effective_morale, outcomes: ROUT, FALL_BACK, ONE_FLEES, DUCK | `roll_morale_check()` | UNVERIFIED — verify 4 panic outcomes and thresholds | | |
| 6C-009 | Max combat rounds | N/A | `BattleResolver.gd:14-15` MAX=6, MIN=3 | Hardcoded | UNVERIFIED — verify if book specifies round limits | | |

---

## Chapter 7: Post-Battle (Core Rules pp.96-102)

### Architecture Overview

**14-step pipeline** orchestrated by [PostBattlePhase.gd](src/core/campaign/phases/PostBattlePhase.gd) (332 lines), with 10 RefCounted subsystems in `src/core/campaign/phases/post_battle/`:

1. RivalPatronResolver → 2. PaymentProcessor → 3. LootProcessor → 4. InjuryProcessor → 5. ExperienceTrainingProcessor → 6. CampaignEventEffects → 7. CharacterEventEffects → 8. GalacticWarProcessor → 9. PostBattleCompletion

**Key Files**:

- [PostBattlePhase.gd:125-233](src/core/campaign/phases/PostBattlePhase.gd#L125-L233) — 14-step orchestration with signal emission
- [PaymentProcessor.gd](src/core/campaign/phases/post_battle/PaymentProcessor.gd) (165 lines) — Steps 4-6
- [LootProcessor.gd](src/core/campaign/phases/post_battle/LootProcessor.gd) (92 lines) — Step 7
- [InjuryProcessor.gd](src/core/campaign/phases/post_battle/InjuryProcessor.gd) (171 lines) — Step 8
- [ExperienceTrainingProcessor.gd](src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd) (257 lines) — Steps 9-11
- [CampaignEventEffects.gd](src/core/campaign/phases/post_battle/CampaignEventEffects.gd) — Step 12 (50-entry D100)
- [CharacterEventEffects.gd](src/core/campaign/phases/post_battle/CharacterEventEffects.gd) — Step 13 (45-entry D100)
- [GalacticWarProcessor.gd](src/core/campaign/phases/post_battle/GalacticWarProcessor.gd) (144 lines) — Step 14a

**UI Files**: [PostBattleSequenceUI.gd](src/ui/screens/battle/PostBattleSequenceUI.gd) (18 signal handlers), [PostBattleSummarySheet.gd](src/ui/screens/battle/PostBattleSummarySheet.gd) (488 lines)

**Test Files**: `tests/unit/test_post_battle_subsystems.gd`

### 7A: Payment & Rewards

**Data Sources**: [PaymentProcessor.gd](src/core/campaign/phases/post_battle/PaymentProcessor.gd), [GameCampaignManager.gd](src/core/campaign/GameCampaignManager.gd)
**Implementing Code**: PaymentProcessor calculates base + danger pay with multiplier formula

> **WARNING**: GameCampaignManager.gd has hardcoded reward values (500-1500 credits for patron jobs, 1000-2500 for missions) with no Core Rules page references.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7A-001 | Payment formula | p.97 | PaymentProcessor: `(base_payment + danger_pay) * (base_roll / 3.0)` | PaymentProcessor payment calculation | UNVERIFIED — verify formula matches book | | |
| 7A-002 | Danger pay modifiers | p.97 | PaymentProcessor: +25% difficult, +50% deadly | Difficulty-based multipliers | UNVERIFIED — verify percentages | | |
| 7A-003 | Patron job hardcoded values | p.84 | `GameCampaignManager.gd` 500-1500 patron, 1000-2500 mission | Hardcoded — **no page reference in code** | UNVERIFIED — **SUSPECT HALLUCINATED** — verify ranges exist in book | | |

### 7B: Battlefield Finds & Loot

**Data Sources**: [data/loot/battlefield_finds.json](data/loot/battlefield_finds.json), [data/loot_tables.json](data/loot_tables.json) (D100 hierarchical: main + 4 subtables)
**Implementing Code**: [LootProcessor.gd:11-92](src/core/campaign/phases/post_battle/LootProcessor.gd#L11-L92), [LootSystemConstants.gd](src/core/systems/LootSystemConstants.gd) (D100 range definitions)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7B-001 | Main loot D100 (6 categories) | pp.66-72 | `loot_tables.json`: 1-25=WEAPON, 26-35=DAMAGED_WEAPONS, 36-45=DAMAGED_GEAR, 46-65=GEAR, 66-80=ODDS_AND_ENDS, 81-100=REWARDS | `LootSystemConstants.gd` ranges + `LootProcessor.gd:25-41` | UNVERIFIED — verify 6 D100 category boundaries | | |
| 7B-002 | Weapon subtable D100 | pp.70-72 | `loot_tables.json` weapon_subtable: 1-35=slug, 36-50=energy, 51-65=special, 66-85=melee, 86-100=grenades | `LootSystemConstants.gd` | UNVERIFIED — verify 5 weapon category ranges | | |
| 7B-003 | Gear subtable D100 | pp.70-72 | `loot_tables.json` gear_subtable: gun_mods/sights/protective/utility | `LootSystemConstants.gd` | UNVERIFIED — verify gear category ranges | | |
| 7B-004 | Odds & ends subtable | pp.70-72 | `loot_tables.json`: 1-55=consumables, 56-70=implants (11 types), 71-100=ship_items (19 items) | `LootSystemConstants.gd` | UNVERIFIED — verify ranges and item counts | | |
| 7B-005 | Rewards subtable (10 types) | pp.70-72 | `loot_tables.json`: Documents through Personal Item, with credit formulas (1D6, 1D6+2, 2D6 pick highest) | `LootSystemConstants.gd` | UNVERIFIED — verify all 10 reward types and credit formulas | | |
| 7B-006 | Battlefield finds 2D6 | p.66 | PaymentProcessor: 1-2=damaged weapons, 3-7=one item, 8-11=two items, 12=story event | PaymentProcessor battlefield finds logic | UNVERIFIED — verify 2D6 outcome ranges | | |

### 7C: Campaign Events D100 (pp.100-101)

**Data Sources**: `campaign_events.json` (411 lines, D100 table)
**Implementing Code**: [CampaignEventEffects.gd](src/core/campaign/phases/post_battle/CampaignEventEffects.gd) — 50-entry match statement

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7C-001 | Campaign event D100 ranges | pp.100-101 | `campaign_events.json` D100 entries (50 events) | `CampaignEventEffects.gd` 50-case match | UNVERIFIED — verify all 50 D100 boundary values | | |
| 7C-002 | Campaign event effects | pp.100-101 | Per-event effects (economy, relationships, recruitment, discovery, threat, opportunity) | `CampaignEventEffects.gd` applies effects | UNVERIFIED — verify each event's mechanical outcome | | |
| 7C-003 | Campaign event count | pp.100-101 | 50 entries in JSON | N/A | UNVERIFIED — book says 40? JSON has 50. **Verify count** | | |

### 7D: Character Events

**Data Sources**: `event_tables.json` or dedicated character events file
**Implementing Code**: [CharacterEventEffects.gd](src/core/campaign/phases/post_battle/CharacterEventEffects.gd) — 45-entry match statement

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7D-001 | Character event D100 ranges | pp.101-102 | Character events D100 (45 entries) | `CharacterEventEffects.gd` 45-case match | UNVERIFIED — verify all D100 boundaries | | |
| 7D-002 | Character event effects | pp.101-102 | Per-event mechanical outcomes | `CharacterEventEffects.gd` | UNVERIFIED — verify effects per event | | |
| 7D-003 | Bot/Soulless exclusion | pp.101-102 | Species restriction on character events | Validation in character event processing | UNVERIFIED — verify exclusion rule | | |
| 7D-004 | Precursor double-roll | pp.101-102 | Precursor species: roll twice, pick preferred | Species special rule | UNVERIFIED — verify double-roll implementation | | |

### 7E: XP Distribution & Training

**Implementing Code**: [ExperienceTrainingProcessor.gd:193-229](src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd#L193-L229) (XP calculation), [ExperienceTrainingProcessor.gd:13-22](src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd#L13-L22) (8 training courses), [ExperienceTrainingProcessor.gd:152-189](src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd#L152-L189) (enrollment)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7E-001 | XP difficulty multipliers | pp.89-90 | `ExperienceTrainingProcessor.gd:193-229` Normal=1.0x, Hard=1.25x, Deadly=1.5x, Catastrophic=2.0x | `_calculate_crew_xp()` | UNVERIFIED — verify multiplier values | | |
| 7E-002 | Training courses (8 types) | p.? | `ExperienceTrainingProcessor.gd:13-22` Fieldcraft(5cr), Gun Smithing(15cr), Hacking(10cr), Healing(10cr), Heavy Weapons(10cr), Leadership(15cr), Wilderness Survival(5cr), Zero-G(15cr) | Hardcoded in processor | UNVERIFIED — verify 8 course names and credit costs match book | | |
| 7E-003 | Training enrollment roll | p.? | `ExperienceTrainingProcessor.gd:152-189` 1cr application fee + 2D6 roll, 4+ for approval | `attempt_training_enrollment()` | UNVERIFIED — verify enrollment mechanic | | |
| 7E-004 | Injury bonus XP | pp.89-90 | `ExperienceTrainingProcessor.gd` bonus from injuries | Part of XP calculation | UNVERIFIED — verify bonus XP for injured crew | | |

### 7F: Invasion & Galactic War

**Implementing Code**: [GalacticWarProcessor.gd:43-87](src/core/campaign/phases/post_battle/GalacticWarProcessor.gd#L43-L87) — 2D6 + war_modifier with outcome bands

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7F-001 | Invasion check threshold | p.98 | PaymentProcessor: invasion on 2D6 ≥ 9 | Post-battle invasion check | UNVERIFIED — verify 9+ threshold | | |
| 7F-002 | Galactic war 2D6 outcomes | p.? | `GalacticWarProcessor.gd:43-87`: ≤4=planet lost, 5-7=continues, 8-9=making ground (+1 modifier), 10+=victorious | 4-band outcome system | UNVERIFIED — verify outcome bands and modifier effects | | |

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
| 19 | **Ship types count** | `ships.json`: 7 types | Core Rules p.31: 13 types | **FULL REWRITE NEEDED** — 6 types missing, existing types may be fabricated |
| 20 | **Ship hull ranges** | `ships.json`: 6-14 (Phase 30 "fix") | Core Rules p.31: 20-40 | **Phase 30 "fix" was WRONG** — moved values FURTHER from book. Original 20-35 was closer |
| 21 | **Ship debt formula** | `ships.json`: 0-5 (Phase 30 "fix") | Core Rules p.31: 1D6+10 to 1D6+35 | **Phase 30 "fix" was WRONG** — original 12-38 was actually in range |
| 22 | **ShipPanel SpinBox max** | `ShipPanel.tscn`: hull max=20, debt max=10 | Core Rules p.31: hull ~40, debt ~41 | SpinBox constraints prevent entering correct book values |

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
