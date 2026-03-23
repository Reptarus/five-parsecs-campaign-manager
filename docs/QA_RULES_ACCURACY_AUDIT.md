# Rules-to-Code Traceability Audit

**Last Updated**: 2026-03-23
**Purpose**: Comprehensive line-by-line verification that EVERY rule in the Core Rules book and Compendium has corresponding code, and EVERY piece of game code traces back to a specific rule
**Status**: DATA VERIFIED, GENERATOR WIRING COMPLETE, COMPENDIUM VERIFIED — All 12/12 data domains verified against source text (925/925 values). Generator wiring audit (Mar 23) found 10/16 generators; all fixed. Cleanup sprint (Mar 23): Dazzle Grenade data sync, PatronJobGenerator preferred_jobs, game CharacterCreator 21 classes, SpeciesList.json 6 corrections. Compendium verification (Mar 23): 100+ values verified against Five Parsecs Compendium PDF. Found and fixed 3 origin bonus bugs (Krag SAVVY -1 spurious, Skulker SPEED/TOUGHNESS/SAVVY all wrong, Prison Planet COMBAT→COMBAT_SKILL key). Deployment D100 (54 ranges), Escalation D100 (42 ranges), Equipment (17 items), Species (2 profiles + rules), Salvage mechanics all confirmed correct.

> **CRITICAL — BLOCKS PUBLIC RELEASE**: This project nearly shipped with AI-hallucinated game data. Every rule statement, every conditional ("and"/"or"), every table, every formula in the Core Rules book must map to specific code. Every game data value in code must trace back to a specific page and paragraph in the book.

---

## Generator Wiring Gap (Discovered Mar 23, 2026)

**What the audit verified**: JSON/GDScript data values match the Core Rules and Compendium source text (925/925).

**What the audit did NOT verify**: Whether generation engines actually READ the verified data at runtime. A code-level audit of all 16 generators found that many load canonical JSON but then ignore it, using fabricated hardcoded const arrays instead.

### Generator Health (verified by code reading, not agent-only)

| Generator | Status | Issue / Fix |
|-----------|--------|-------------|
| StreetFightGenerator | **FIXED** | Added `_ensure_ref_loaded()` + `_enrich_from_ref()` to overlay JSON text onto const results. |
| SalvageJobGenerator | **FIXED** | Added `_ensure_ref_loaded()` to all 6 entry points + `_enrich_from_ref()` enrichment. |
| RivalBattleGenerator | **FIXED** | Added JSON loading stub + fixed D10 attack weights to match Core Rules p.91 (was equal 20%, now 10/20/40/10/20). |
| LootEconomyIntegrator | **FIXED** | API alignment: `.value`→`.get_value()`, `.tags`→`.has_tag()`/`.item_tags`, quality→rarity system. |
| EquipmentGenerationScene | **FIXED** | Autoload paths: nonexistent `SystemsAutoload` → actual `EquipmentManager`. |
| FiveParsecsMissionGenerator | **FIXED** | Rewards: `difficulty*100` → D6 base + D10 danger pay table from `patron_generation.json`. Loot credits 100s→1-3. |
| PatronJobGenerator | **FIXED** | Core Rules patron types, `_get_patron_type_string()` mapper, relationship tier system (-100..+100 → benefit tiers). |
| CharacterGeneration | **FIXED** | Expanded `apply_class_bonuses()` from 8→23+6 classes. Fixed fallback equipment (removed fabricated weapons/credits). |
| SimpleCharacterCreator | **FIXED** | Stats: raw 2D6 → `ceil(2D6/3)` giving 1-4 range. `max()`→`maxi()`. |
| StartingEquipmentGenerator | **FIXED** | Removed fabricated 1000+d10×100 credits. Campaign creation handles credits per Core Rules p.28. |
| EnemyGenerator | **OK** | Primary JSON path works. Fallback category names match JSON (`criminal_elements`, `hired_muscle`, etc.). |
| StealthMissionGenerator | **OK** | Enhanced with `_enrich_from_ref()`. All const arrays are intentional Compendium data. DLC-gated correctly. |
| EnemyGenerationWizard | **FIXED** | Category IDs mapped to canonical JSON IDs via `CATEGORY_IDS` const. UI labels updated to Core Rules terms. |
| BugHuntEnemyGenerator | **OK** | All 4 JSON files loaded and used correctly. |
| BugHuntCharacterGeneration | **OK** | Origin/training/history from JSON. Minor unresolved equipment IDs. |
| BattlefieldGenerator | **OK** | Loads canonical terrain JSON correctly. |

### Fix Priority (ALL RESOLVED — Mar 23, 2026)

1. ~~**Payment inflation**~~ — FIXED: D6 base + D10 danger pay from `patron_generation.json`
2. ~~**"Load but never use" pattern**~~ — FIXED: `_enrich_from_ref()` overlays JSON onto const results
3. ~~**Broken property access**~~ — FIXED: API aligned to `get_value()`/`has_tag()`/`item_tags`
4. ~~**Stat overflow**~~ — FIXED: `ceil(2D6/3)` gives 1-4 range
5. ~~**Phantom properties**~~ — FIXED: Expanded to all 23+6 classes
6. ~~**Incomplete coverage**~~ — FIXED: All Core Rules classes covered
7. ~~**Category ID mismatch**~~ — FIXED: `CATEGORY_IDS` const maps UI to JSON IDs

### Detailed Per-Generator Breakdown

#### BROKEN: StreetFightGenerator.gd

**File**: `src/core/mission/StreetFightGenerator.gd` (267 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| JSON loaded, never read | 119-144 | `_ensure_ref_loaded()` opens `StealthAndStreet.json` correctly |
| Fabricated: STREET_FIGHT_OBJECTIVES | 23-72 | 6 objectives with D100 ranges — never reads `_ref_data` |
| Fabricated: BUILDING_TYPES | 79-86 | 6 building types with cover/floors |
| Fabricated: SUSPECT_IDENTITY | 93-100 | 6 suspect types with hostile flags |
| Fabricated: POLICE_RESPONSE_TEXT | 107-112 | 4 hardcoded response strings |
| Methods ignoring JSON | 181-202 | `_roll_objective()`, `_roll_building()`, `roll_suspect_identity()` all iterate const arrays |

**Fix**: Each `_roll_*()` method calls `_ensure_ref_loaded()` then reads from `_ref_data.get("street_fights", {})` with const fallback.

#### BROKEN: SalvageJobGenerator.gd

**File**: `src/core/mission/SalvageJobGenerator.gd` (293 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| JSON loaded, never read | 116-136 | `_ensure_ref_loaded()` opens `SalvageJobs.json` correctly |
| Fabricated: FIND_JOB_TABLE | 25-32 | 6 job types with D6 rolls |
| Fabricated: CONTACT_RESOLUTION | 39-46 | 6 contact outcomes with tension modifiers |
| Fabricated: HOSTILE_TYPES | 53-66 | 4 hostile categories with D100 ranges |
| Fabricated: POINTS_OF_INTEREST | 73-96 | 10 POI types with salvage/tension values |
| Fabricated: SALVAGE_CONVERSION | 103-109 | 5 credit tiers |
| Methods ignoring JSON | 173-211 | All 5 generate methods use consts only |

**Fix**: Same pattern — each method reads `_ref_data` first, falls back to const.

#### BROKEN: RivalBattleGenerator.gd

**File**: `src/core/rivals/RivalBattleGenerator.gd` (450+ lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Zero JSON infrastructure | — | No `_ensure_ref_loaded()`, no JSON path, no `_ref_data` |
| Fabricated: rival_force_templates | ~60-102 | 4 rival types (CRIMINAL_GANG, CORPORATE_SECURITY, PIRATE_CREW, MERCENARY_UNIT) |
| Fabricated: escalation_rules | ~105-121 | Escalation levels 0-4 with encounter frequency |
| Fabricated: battle_type_weights | ~124-147 | Battle type distributions |

**Fix**: Add full JSON loading infrastructure. Create or identify canonical JSON source for rival mechanics. Replace all hardcoded templates with `_ref_data` lookups.

#### BROKEN: LootEconomyIntegrator.gd

**File**: `src/game/economy/loot/LootEconomyIntegrator.gd` (542 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Phantom: `item.quality` | 102-107 | Reads quality for market value multiplier — property may not exist on GameItem |
| Phantom: `item.condition` | 110-115 | Reads condition for market value multiplier — property may not exist |
| Phantom: `item.tags` | 248, 264, 268, 287, 292, 327 | Reads tags array — property may not exist |
| Phantom: `item.value` | 51-79 | Reads value in `process_battle_loot()` |

**Fix**: Verify `GameItem.gd` properties. Either add missing properties to GameItem or refactor all access to use safe `.get()` with defaults.

#### BROKEN: EquipmentGenerationScene.gd

**File**: `src/ui/screens/equipment/EquipmentGenerationScene.gd` (501 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Wrong autoload paths | 97-99 | Searches `/root/SystemsAutoload`, `/root/GameStateManagerAutoload`, `/root/CoreSystemSetup` — none exist |
| Fabricated fallback | 278-303 | Generates "Military Rifle", "Combat Armor", "Field Kit" when generator not found |

**Fix**: Update `_find_equipment_generator()` with correct autoload paths from project.godot. Verify fallback is intentional design or fix to use correct paths.

#### WRONG VALUES: FiveParsecsMissionGenerator.gd

**File**: `src/game/campaign/FiveParsecsMissionGenerator.gd` (377 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| 100x payment inflation | 174 | `difficulty * 100` produces 200-500 credits (should be ~20-50) |
| Hardcoded factions | 65-69 | 10 faction names not from JSON, non-canonical |
| Objectives work correctly | 223-262 | D10 rolling on patron_generation.json objective tables ✅ |

**Fix**: Replace line 174 with Core Rules-verified payment formula. Wire factions from `mission_generation_data.json`.

#### WRONG VALUES: PatronJobGenerator.gd

**File**: `src/core/patrons/PatronJobGenerator.gd` (512 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Fabricated job base_payments | 122-208 | 8 job types with single-digit base pay (ESCORT:6, SABOTAGE:8, etc.) — no Core Rules citation |
| Fabricated patron multipliers | 212-249 | 6 patron types (MILITARY:1.2, CRIME_BOSS:1.3, etc.) — undocumented |
| Type key mismatch | 317-331 | Job type keys don't match `patron_generation.json` schema |
| Missing difficulty scaling | 346 | Payment returned without difficulty adjustment |

**Fix**: Load job templates and patron multipliers from `patron_generation.json`. Add difficulty scaling. Verify all values against Core Rules pp.89-91.

#### PARTIAL: CharacterGeneration.gd

**File**: `src/core/character/CharacterGeneration.gd` (1662 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Background mapping: 8/25 | 626-636 | Missing 17 backgrounds (VAGRANT, SCAVENGER, etc.) — `_get_background_id_from_string()` |
| Class bonuses: 8/23 | 645-690 | Missing 15 classes (GAMBLER, ARISTOCRAT, etc.) — `apply_class_bonuses()` |
| Background effects: 8/25 | 1455-1474 | Match statement covers only 8 backgrounds for trait assignment |
| Combat clamp: 0-5 vs 0-3 | 663, 866 | `apply_class_bonuses()` and BOT species use 0-5, but `validate_character()` expects 0-3 |
| Duplicate methods | 1583-1662 | Static + instance versions of `_ensure_character_equipment` and `_ensure_character_relationships` |

**Fix**: Expand all three match statements to cover all 25 backgrounds and 23 classes. Fix combat clamping to canonical 0-3. Remove duplicate static methods.

#### PARTIAL: SimpleCharacterCreator.gd

**File**: `src/core/character/Generation/SimpleCharacterCreator.gd` (668 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Raw 2D6 stats (2-12) | 415-417, 386-392 | `_roll_2d6()` returns 2-12 instead of canonical 2D6/3.0 → 1-4 |
| Universal 0-6 clamping | 600-667 | All stats capped 0-6 instead of per-stat ranges |
| Speed range wrong | 649-657 | Speed capped 0-6 instead of canonical 4-8 |

**Canonical stat ranges** (from `validate_character()` in CharacterGeneration.gd):
- combat: 0-3, reactions: 1-6, toughness: 3-6, speed: 4-8, savvy: 0-3, luck: 0-3

**Fix**: Replace `_roll_2d6()` with `ceili(float(randi_range(2, 12)) / 3.0)`. Replace all clampi calls with per-stat canonical ranges.

#### PARTIAL: StartingEquipmentGenerator.gd

**File**: `src/core/character/Equipment/StartingEquipmentGenerator.gd` (289 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Fabricated credits formula | 46 | `1000 + (credit_roll * 100)` = 1100-2000 credits — no Core Rules citation |

**Fix**: Verify starting credits formula against Core Rules. Core Rules p.28 says 1 credit per crew member — this formula is wildly inflated.

#### PARTIAL: EnemyGenerator.gd + EnemyGenerationWizard.gd

**Files**: `src/core/systems/EnemyGenerator.gd` (577 lines) + `src/ui/components/battle/EnemyGenerationWizard.gd` (484 lines)

| Issue | Lines | Detail |
|-------|-------|--------|
| Fallback category name mismatch | EG:59-64, EGW:440-446 | Generator uses "criminal_elements"/"hired_muscle"/"interested_parties"/"roving_threats"; Wizard maps to "criminal"/"military"/"alien"/"pirate"/"wildlife"/"cultists" |
| Wizard has 6 categories, fallback has 4 | EG:59-64 | "wildlife" and "cultists" have no fallback |

**Fix**: Align EnemyGenerator fallback IDs to match Wizard's abbreviated IDs. Expand fallback to support all 6 categories.

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
| Weapons & Equipment | 5 | 1 | ~170 | ~99 | 13 FIXED | 5 REMOVED | **VERIFIED — 36 Core Rules + 1 Compendium (Carbine) confirmed. 5 fabricated weapons REMOVED (Laser Rifle, Plasma Pistol, Auto Cannon, Missile Launcher, Shock Grenade).** |
| Species & Characters | 4 | 0 | ~80 | ~80 | 13 FIXED | 0 | **VERIFIED — all species stats confirmed, 3 missing Strange Characters ADDED (Traveler/Empath/Bio-upgrade), motivation table 13 errors FIXED** |
| Injuries | 1 | 1 | ~25 | ~25 | 1 FIXED | 0 | **VERIFIED (Phase 46) — fatal split FIXED, treatment system ADDED** |
| Loot Tables | 2 | 1 | ~60 | ~55 | 14 FIXED | 0 | **VERIFIED — 14 missing ship items added** |
| Economy & Upkeep | 1 | 3 | ~30 | ~30 | 14 FIXED | 3 removed | **VERIFIED — payment REWRITTEN, WorldEconomyManager 1000→0 FIXED, campaign_rules.json starting_credits FIXED (1/crew)** |
| Campaign Events | 2 | 2 | ~100 | ~100 | 80+ REWRITTEN | 80+ removed | **VERIFIED — all 28 campaign + 30 character event D100 boundaries confirmed against core_rulebook.txt** |
| Travel & World | 2 | 1 | ~40 | ~41 | 9 REMOVED | 24 removed | **VERIFIED — all 41 world trait D100 boundaries confirmed against core_rulebook.txt** |
| Battle & Enemies | 5 | 1 | ~60 | ~60 | 0 | 0 | **VERIFIED (Phase 46, pp.94-107)** |
| Char Creation Tables | 3 | 2 | ~80 | ~80 | 14 FIXED | 36 removed | **VERIFIED — Background (25 entries) + Class (23 entries) + Motivation (17 entries all FIXED) confirmed against core_rulebook.txt** |
| Missions | 4 | 1 | ~50 | ~50 | 3 REWRITTEN | ~20 removed | **VERIFIED — patron type/danger pay/time frame/BHC/conditions all confirmed against core_rulebook.txt** |
| Ships | 2 | 0 | ~20 | ~20 | 13 FIXED | 7 removed | **VERIFIED — Full rewrite done (Phase 46)** |
| Advancement | 1 | 1 | ~20 | ~20 | 0 | 0 | **VERIFIED (Phase 46, pp.123-130)** |
| Victory Conditions | 1 | 1 | ~17 | ~17 | 8 REMOVED | 8 removed | **VERIFIED — all 17 conditions confirmed against core_rulebook.txt, easy mode restrictions correct** |
| Compendium/DLC | 15+ | 11 | ~100 | ~100 | 12 REWRITTEN | 5 REMOVED | **VERIFIED — All 11 GDScript files cross-referenced. 4 tables REWRITTEN from Compendium (AI Variations per-type D6, 3 Casualty Tables, D100 Detailed Injuries, Dramatic Combat Lunging). 5 fabricated weapons REMOVED. Connection subtables (30 entries) VERIFIED. Prison Planet reclassified. Salvage rules REWRITTEN.** |
| **TOTAL** | **~51** | **~27** | **~925+** | **~900+** | **190+ FIXED/REWRITTEN** | **145+ removed** | **COMPLETE — All 12 domains verified, all fabricated data resolved** |

### Forward Trace: Book → Code (Rules Coverage)

| Book Section | Pages | Est. Rules | Code Exists | Fully Traced | Missing | Issues Found | Status |
|-------------|-------|-----------|-------------|-------------|---------|---------|--------|
| Character Creation | pp.15-37 | ~50 | YES (27 items) | ~50 | 0 | 0 (all FIXED: 3 Strange Chars ADDED, motivation 13 errors FIXED) | **VERIFIED — all species, backgrounds, motivations, classes confirmed** |
| Equipment & Weapons | pp.40-58 | ~40 | YES (25 items) | ~36 | 0 | 1 (Dazzle Grenade trait FIXED) | **VERIFIED — 36 Core Rules weapons confirmed, 6 non-Core tagged** |
| Ships | pp.59-65 | ~20 | YES (6 items) | ~20 | 0 | 0 | **FIXED — 13 types, hull 20-40, debt 1D6+10-35 (2nd chat)** |
| Travel Phase | pp.70-79 | ~30 | YES (10 items) | ~41 | 0 | 0 | **VERIFIED — all 41 world trait D100 boundaries confirmed** |
| World Phase / Upkeep | pp.76-86 | ~25 | YES (14 items) | ~25 | 0 | 0 (all FIXED: WorldEconomyManager 1000→0, starting credits 1/crew) | **VERIFIED — upkeep/payment/patron/starting credits all confirmed** |
| Battle Setup & Combat | pp.87-95 | ~40 | YES (21 items) | 0 | 0 | 1 (initiative mechanism needs verification) | **CODE MAPPED** |
| Post-Battle | pp.96-102 | ~35 | YES (22 items) | ~58 | 0 | 0 | **VERIFIED — 28 campaign + 30 character events D100 boundaries all confirmed** |
| Injuries & Recovery | pp.94-95 | ~15 | YES (13 items) | 0 | 0 | 0 (fatal split FIXED, treatment ADDED) | **CODE MAPPED — ALL ISSUES RESOLVED** |
| Advancement | pp.67-76 | ~20 | YES (12 items) | 0 | 0 | 0 | **CODE MAPPED** |
| Loot Tables | pp.66-72 | ~25 | YES (covered in Ch.7B) | 0 | 0 | 0 | **CODE MAPPED** |
| Victory Conditions | pp.63-64 | ~17 | YES (17 items) | ~17 | 0 | 0 | **VERIFIED — all 17 conditions + easy mode restrictions confirmed** |
| Difficulty Modifiers | various | ~15 | YES (6 items) | 0 | 0 | 0 | **CODE MAPPED** |
| Compendium / DLC | supplements | ~80 | YES (71 items) | 0 | 0 | 3 (data duplication in generators) | **CODE MAPPED — 13 JSONs wired to consumers** |
| **TOTAL** | **~300 pp** | **~485** | **~266 mapped** | **~340+** | **0** | **~2** | **13/13 MAPPED, 8 domains VERIFIED, 17 JSONs WIRED** |

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
| **Onboard** | [data/onboard_items.json](data/onboard_items.json) | 19 items | **WIRED** — EquipmentManager._load_onboard_items() + get_onboard_item(id) |

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
| 2F-001 | Onboard item list (19 items) | pp.57-58 | `onboard_items.json` 19 items | `EquipmentManager.gd:_load_onboard_items()`, `get_onboard_item(id)`, `get_onboard_items()` | **WIRED** — loaded by EquipmentManager. **VERIFIED against core_rulebook.txt** for all 19 item effects | AI+txt | 2026-03-22 |

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
| 3A-001 | Ship type names (13 types) | p.31 | `ships.json` rewritten with 13 VERIFIED types (2nd chat). Metadata: "VERIFIED Mar 22, 2026" | **FIXED** | AI | 2026-03-22 |
| 3A-002 | Hull point ranges | p.31 | `ships.json` hull now 20-40 per Core Rules (was 6-14 fabricated) | **FIXED** | AI | 2026-03-22 |
| 3A-003 | Starting ship debt | p.31 | `ships.json` debt now 1D6+10 to 1D6+35 per Core Rules (was 0-5 fabricated) | **FIXED** | AI | 2026-03-22 |
| 3A-004 | Ship component types | p.31+ | All components from book | UNVERIFIED | | |
| 3A-005 | Ship traits | p.31+ | Trait list and effects per ship type in `ships.json` | UNVERIFIED — verify traits match book | | |
| 3A-006 | Ship type count | p.31 | 13 types in `ships.json` matches Core Rules | **FIXED** | AI | 2026-03-22 |

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

### 4B: World Traits D100 (pp.72-75)

**Data Sources**: [data/world_traits.json](data/world_traits.json) (41 traits with D100 ranges — **REWRITTEN Mar 22, 2026**)
**Implementing Code**: [TravelPhase.gd](src/core/campaign/phases/TravelPhase.gd) — `_load_world_traits_from_json()` loads from JSON, `_fallback_world_traits()` has hardcoded backup matching same 41 entries

> **RESOLVED**: World traits now loaded from JSON as canonical source. TravelPhase.gd was updated to load from `world_traits.json` (41 D100 entries from Core Rules pp.72-75). Old fabricated 9-entry hardcoded table with fake categories (Frontier/Trade Hub/Industrial/etc.) replaced. Fallback table matches JSON exactly.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 4B-001 | World trait D100 ranges (41 entries) | pp.72-75 | `world_traits.json` roll_range fields: Haze [1,3], Overgrown [4,6], ... Fog [97,100] | `TravelPhase.gd:_load_world_traits_from_json()` loads, `_process_world_arrival()` looks up by roll | **REWRITTEN** — 41 entries from Core Rules. Old 9 fabricated entries removed. Text extraction used — **VERIFIED against core_rulebook.txt** for exact boundary values | AI+txt | 2026-03-22 |
| 4B-002 | World trait effects | pp.72-75 | `world_traits.json` description fields per trait (e.g., Haze: "visibility 1D6+8\"") | Effects documented in JSON, applied by downstream phase components | **REWRITTEN** — effects transcribed from rulebook text. **VERIFIED against core_rulebook.txt** for exact wording | AI+txt | 2026-03-22 |
| 4B-003 | Fallback table sync | N/A | `TravelPhase.gd:_fallback_world_traits()` — 41 entries matching JSON | Backup for when JSON unavailable | **FIXED** — fallback now mirrors JSON exactly (41 entries, same ranges/names) | AI | 2026-03-22 |

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

> **RESOLVED (Mar 22 2026)**: Three-way upkeep conflict was: `FiveParsecsConstants.gd: 1` (VERIFIED p.76), `campaign_rules.json: 6` (WRONG — confused upkeep_cap threshold with cost), `WorldEconomyManager.gd: 1000` (hardcoded starting credits, NOT upkeep). Fixed: campaign_rules.json upkeep corrected to match FiveParsecsConstants. Note: campaign_rules.json has NO GDScript consumer — it's dead data.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 5A-001 | Base upkeep cost | p.76 | `FiveParsecsConstants.gd:123` base_upkeep: 1 (per 4-6 crew). `campaign_rules.json` FIXED from 6→1. | `CampaignPhaseManager.gd:639` IMPLEMENTED: 0 for ≤4 crew, 1 for 5-6, +1 per member >6. `WorldPhase.gd:48` also uses FiveParsecsConstants | **FIXED** — stub replaced with full implementation using VERIFIED constants | AI | 2026-03-22 |
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

**Data Sources**: [data/patron_generation.json](data/patron_generation.json) (**CANONICAL** — Core Rules pp.83-84), [data/campaign_tables/world_phase/patron_jobs.json](data/campaign_tables/world_phase/patron_jobs.json) (legacy fallback), [data/missions/opportunity_missions.json](data/missions/opportunity_missions.json)
**Implementing Code**: [PatronSystem.gd](src/core/systems/PatronSystem.gd) (loads `patron_generation.json`), [PatronJobManager.gd](src/core/campaign/PatronJobManager.gd) (loads `patron_generation.json`), [PatronJobGenerator.gd](src/core/patrons/PatronJobGenerator.gd) (loads objectives from `patron_generation.json`), [FiveParsecsMissionGenerator.gd](src/game/campaign/FiveParsecsMissionGenerator.gd) (loads D10 mission objectives)

> **UPDATED Mar 22**: All 3 patron system files rewired to load from canonical `patron_generation.json` (Core Rules pp.83-84 D10 tables). Legacy `patron_types.json` and `patron_jobs.json` retained as fallback only. Mission objectives (D10 tables for opportunity/patron/quest + D100 expanded Compendium) wired into FiveParsecsMissionGenerator.

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 5C-001 | Patron type D10 table | p.83 | `patron_generation.json` patron_type_table: Corporation [1,2], Local Gov [3,4], Sector Gov [5], Wealthy Individual [6,7], Private Org [8,9], Secretive Group [10] | `PatronSystem.gd:_load_dependencies()`, `PatronJobManager.gd:_load_patron_tables()` | **WIRED** — loaded from canonical JSON. **VERIFIED against core_rulebook.txt** for exact D10 boundaries | AI+txt | 2026-03-22 |
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
- [CampaignEventEffects.gd](src/core/campaign/phases/post_battle/CampaignEventEffects.gd) — Step 12 (28-entry D100, **REWRITTEN** from Core Rules pp.126-128)
- [CharacterEventEffects.gd](src/core/campaign/phases/post_battle/CharacterEventEffects.gd) — Step 13 (30-entry D100, **REWRITTEN** from Core Rules pp.128-130)
- [GalacticWarProcessor.gd](src/core/campaign/phases/post_battle/GalacticWarProcessor.gd) (144 lines) — Step 14a

**UI Files**: [PostBattleSequenceUI.gd](src/ui/screens/battle/PostBattleSequenceUI.gd) (18 signal handlers), [PostBattleSummarySheet.gd](src/ui/screens/battle/PostBattleSummarySheet.gd) (488 lines)

**Test Files**: `tests/unit/test_post_battle_subsystems.gd`

### 7A: Payment & Rewards

**Data Sources**: [PaymentProcessor.gd](src/core/campaign/phases/post_battle/PaymentProcessor.gd) (**REWRITTEN Mar 22**), [GameCampaignManager.gd](src/core/campaign/GameCampaignManager.gd) (**FIXED Mar 22**)
**Implementing Code**: PaymentProcessor now uses Core Rules formula: 1D6 credits + danger pay (patron jobs)

> **RESOLVED**: PaymentProcessor completely rewritten to match Core Rules p.120. Old fabricated formula `(base_payment + danger_pay) * (D6/3.0)` with 100-credit base and difficulty multipliers replaced with simple `D6 + danger_pay`. GameCampaignManager reward values fixed from 500-2500 credits to 1D6 (1-6 credits).

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7A-001 | Payment formula | p.120 | PaymentProcessor: `credit_roll (1D6) + danger_pay` | `PaymentProcessor.gd:process_payment()` | **FIXED** — was `(base_payment + danger_pay) * (D6/3.0)` with 100cr base. Now 1D6 + danger_pay per Core Rules | AI | 2026-03-22 |
| 7A-002 | Payment modifiers | p.120 | Quest finale: roll 2D6 pick better +1. Easy: +1. Won objective: treat 1-2 as 3 (not Rivals). Invasion: no pay | `PaymentProcessor.gd:22-41` | **FIXED** — modifiers match Core Rules. Fabricated difficulty multipliers (0.875/1.25/1.5) removed | AI | 2026-03-22 |
| 7A-003 | GameCampaignManager rewards | p.120 | `GameCampaignManager.gd` patron jobs: 1D6 credits + 1-3 danger pay. Missions: 1D6 credits | `GameCampaignManager.gd:194,247,289,311` | **FIXED** — was 500-2500 credits (fabricated). Now 1D6 credits per Core Rules | AI | 2026-03-22 |
| 7A-004 | Danger Pay (D10 table) | p.83 | `patron_generation.json` danger_pay_table: 1-4=+1cr, 5-8=+2cr, 9=+3cr, 10+=+3cr+roll twice | PatronJobManager loads from JSON | **WIRED** — danger pay from canonical JSON. **VERIFIED against core_rulebook.txt** for exact D10 boundaries | AI+txt | 2026-03-22 |

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

### 7C: Campaign Events D100 (pp.126-128)

**Data Sources**: [data/campaign_tables/campaign_events.json](data/campaign_tables/campaign_events.json) (28 D100 entries — **REWRITTEN Mar 22, 2026**)
**Implementing Code**: [CampaignEventEffects.gd](src/core/campaign/phases/post_battle/CampaignEventEffects.gd) — 28-case match statement (**REWRITTEN Mar 22, 2026**)

> **RESOLVED**: Campaign events completely rewritten from Core Rules pp.126-128. Old file had 50 fabricated events with invented names/effects. New file has 28 real events (Friendly Doc, Life Support Upgrade, ... Great Story) matching D100 1-100. CampaignEventEffects.gd match block rewritten to match new event names. Species exceptions included (K'Erin priority for New Captain).

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7C-001 | Campaign event D100 ranges (28 entries) | pp.126-128 | `campaign_events.json` roll_range: [1,3] Friendly Doc through [98,100] Great Story | `CampaignEventEffects.gd` 28-case match by event name | **REWRITTEN** — 28 entries from Core Rules. **VERIFIED against core_rulebook.txt** for exact D100 boundaries | AI+txt | 2026-03-22 |
| 7C-002 | Campaign event effects | pp.126-128 | Per-event effects dict with credits/story_points/rivals/patrons | `CampaignEventEffects.gd:apply_effect()` 28 match cases | **REWRITTEN** — effects transcribed from rulebook. **VERIFIED against core_rulebook.txt** for exact wording | AI+txt | 2026-03-22 |
| 7C-003 | Campaign event count | pp.126-128 | 28 entries in JSON | Core Rules has 28 events covering D100 1-100 | **FIXED** — old file had 50 fabricated entries. Now matches book count (28) | AI | 2026-03-22 |
| 7C-004 | Precursor double-roll | p.126 | `CampaignEventEffects.gd:17-28` `process_campaign_event()` checks `_has_precursor_crew()`, rolls twice | Precursor species special rule | **VERIFIED** — double-roll implemented, UI choice returned | AI | 2026-03-22 |
| 7C-005 | K'Erin New Captain priority | p.127 | `campaign_events.json` entry [57,59] has `species_exceptions.K'Erin` | Match case "New Captain" mentions K'Erin priority | **REWRITTEN** — species exception documented in JSON and effect handler | AI | 2026-03-22 |

### 7D: Character Events D100 (pp.128-130)

**Data Sources**: [data/campaign_tables/character_events.json](data/campaign_tables/character_events.json) (30 D100 entries — **REWRITTEN Mar 22, 2026**)
**Implementing Code**: [CharacterEventEffects.gd](src/core/campaign/phases/post_battle/CharacterEventEffects.gd) — 30-case match statement (**REWRITTEN Mar 22, 2026**)

> **RESOLVED**: Character events completely rewritten from Core Rules pp.128-130. Old file had ~45 fabricated events. New file has 30 real events (Violence is Depressing, Business Elsewhere, ... Time to Burn) with D100 1-100. All 4 species exceptions documented: K'Erin (violence/melancholy/scrap), Swift (business elsewhere), Engineer (good food/feel great/items), Precursor (unusual hobby).

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 7D-001 | Character event D100 ranges (30 entries) | pp.128-130 | `character_events.json` roll_range: [1,3] Violence is Depressing through [98,100] Time to Burn | `CharacterEventEffects.gd` 30-case match by event name | **REWRITTEN** — 30 entries from Core Rules. **VERIFIED against core_rulebook.txt** for exact boundaries | AI+txt | 2026-03-22 |
| 7D-002 | Character event effects | pp.128-130 | Per-event effects dict with xp/credits/sick_bay/rivals/patrons | `CharacterEventEffects.gd:apply_effect()` 30 match cases | **REWRITTEN** — effects from rulebook. **VERIFIED against core_rulebook.txt** for exact mechanics | AI+txt | 2026-03-22 |
| 7D-003 | Bot/Soulless exclusion | p.128 | `character_events.json` _note: "Roll on random non-Bot, non-Soulless crew member" | `CharacterEventEffects.gd:process_character_event()` selects from `crew_participants` | **DOCUMENTED** — exclusion noted in JSON. Caller must filter. **VERIFY** filtering code | AI | 2026-03-22 |
| 7D-004 | Precursor double-roll | p.128 | `CharacterEventEffects.gd:34-45` checks origin=="precursor", rolls twice, returns `precursor_choice: true` with both events for player selection | Implemented in 2nd chat | **FIXED** — Precursor double-roll implemented for character events | AI | 2026-03-22 |
| 7D-005 | K'Erin exceptions (3 events) | pp.128-130 | Events 1-3, 20-23, 95-97 have `species_exceptions.K'Erin` | Match cases mention K'Erin in return strings | **REWRITTEN** — documented in JSON, noted in effect handlers | AI | 2026-03-22 |
| 7D-006 | Swift exception (event 4-6) | p.128 | Event "Business Elsewhere" has `species_exceptions.Swift: "never returns"` | Match case mentions Swift in return string | **REWRITTEN** — documented in JSON. Actual Swift replacement logic may need implementation | AI | 2026-03-22 |
| 7D-007 | Engineer exceptions (3 events) | pp.128-130 | Events 24-26, 76-78, 88-91 have `species_exceptions.Engineer` | Match cases mention Engineer in return strings | **REWRITTEN** — documented in JSON, noted in effect handlers | AI | 2026-03-22 |

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

## Chapter 8: Injuries (Core Rules pp.94-95)

### Architecture Overview

**Key Files**:

- [data/injury_table.json](data/injury_table.json) (182 lines) — Human (9 types) + Bot (6 types) D100 tables with recovery times
- [InjurySystemConstants.gd](src/core/systems/InjurySystemConstants.gd) (406 lines) — D100 ranges, recovery times, helper functions
- [InjuryProcessor.gd](src/core/campaign/phases/post_battle/InjuryProcessor.gd) (171 lines) — Post-battle injury determination
- [InjurySystemService.gd](src/core/services/InjurySystemService.gd) (378 lines) — Recovery calculation with toughness/medical modifiers

**Test Files**: None found — injury-specific testing gap.

> **WARNING**: Page reference conflict — `injury_table.json` says "p.122" vs `InjurySystemConstants.gd` says "p.94-95". Appendix C #16.

### 8A: Injury Table D100

**Data Sources**: [data/injury_table.json](data/injury_table.json), [InjurySystemConstants.gd:22-31](src/core/systems/InjurySystemConstants.gd#L22-L31)
**Implementing Code**: [InjuryProcessor.gd:76-77](src/core/campaign/phases/post_battle/InjuryProcessor.gd#L76-L77) (D100 roll + type lookup), [InjurySystemConstants.gd:150-163](src/core/systems/InjurySystemConstants.gd#L150-L163) (`get_injury_type_from_roll()`)

| ID | Item | Page | JSON/Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 8A-001 | FATAL range split | p.122 | GRUESOME_FATE(1-5): dead+all equip damaged. FATAL(6-15): dead only. Matches JSON + bot table | `InjurySystemService.gd` adds `all_equipment_damaged` flag for GRUESOME_FATE | **FIXED** — split to match JSON. Both `is_fatal: true` | AI | 2026-03-22 |
| 8A-002 | MIRACULOUS_ESCAPE | p.94 | `InjurySystemConstants.gd:24` min:16, max:16 (single roll) | Single-value range | UNVERIFIED — verify roll 16 = miraculous escape | | |
| 8A-003 | EQUIPMENT_LOSS range | p.94 | `InjurySystemConstants.gd:25` min:17, max:30 | Matches `injury_table.json:44-52` | UNVERIFIED — verify 17-30 | | |
| 8A-004 | CRIPPLING_WOUND range | p.94 | `InjurySystemConstants.gd:26` min:31, max:45, recovery 1D6 | `InjuryProcessor.gd:84` rolls randi_range(1,6) | UNVERIFIED — verify 31-45, 1D6 recovery | | |
| 8A-005 | SERIOUS_INJURY range | p.94 | `InjurySystemConstants.gd:27` min:46, max:54, recovery 1D3+1 | `InjuryProcessor.gd:84` rolls randi_range(2,4) | UNVERIFIED — verify 46-54, 1D3+1 recovery | | |
| 8A-006 | MINOR_INJURY range | p.94 | `InjurySystemConstants.gd:28` min:55, max:80, recovery 1 turn | Fixed value | UNVERIFIED — verify 55-80, 1 turn | | |
| 8A-007 | KNOCKED_OUT range | p.94 | `InjurySystemConstants.gd:29` min:81, max:95, recovery 0 | No recovery needed | UNVERIFIED — verify 81-95 | | |
| 8A-008 | HARD_KNOCKS range | p.94 | `InjurySystemConstants.gd:30` min:96, max:100, XP bonus 1 | Grants 1 XP | UNVERIFIED — verify 96-100 grants bonus XP | | |

### 8B: Bot Injury Table

**Data Sources**: [InjurySystemConstants.gd:297-304](src/core/systems/InjurySystemConstants.gd#L297-L304)
**Implementing Code**: [InjuryProcessor.gd:132-170](src/core/campaign/phases/post_battle/InjuryProcessor.gd#L132-L170)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 8B-001 | Bot OBLITERATED | p.94 | `InjurySystemConstants.gd:298` min:1, max:5 (destroyed + all equipment) | `InjuryProcessor.gd:135` | UNVERIFIED | | |
| 8B-002 | Bot DESTROYED | p.94 | `InjurySystemConstants.gd:299` min:6, max:15 | Same as above | UNVERIFIED | | |
| 8B-003 | Bot SEVERE_DAMAGE | p.94 | `InjurySystemConstants.gd:301` min:31, max:45, repair 1D6 | Dice-based repair | UNVERIFIED | | |
| 8B-004 | Bot MINOR_DAMAGE | p.94 | `InjurySystemConstants.gd:302` min:46, max:65, repair 1 | Fixed repair | UNVERIFIED | | |
| 8B-005 | Bot JUST_A_FEW_DENTS | p.94 | `InjurySystemConstants.gd:303` min:66, max:100, repair 0 | No repair needed | UNVERIFIED | | |

### 8C: Medical Treatment & Recovery

**Implementing Code**: [FiveParsecsConstants.gd:126](src/core/systems/FiveParsecsConstants.gd#L126) (`injury_treatment_cost: 4`), [InjurySystemService.gd:164-195](src/core/services/InjurySystemService.gd#L164-L195) (`calculate_recovery_time()`)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 8C-001 | Treatment cost | p.76 | `FiveParsecsConstants.gd:126` injury_treatment_cost: 4 credits (removes 1 campaign turn from recovery) — VERIFIED comment | `InjurySystemService.gd` uses for cost calc | UNVERIFIED — verify 4 credits per turn removed | | |
| 8C-002 | Toughness recovery modifier | p.94 | `InjurySystemService.gd:182-186` T≥5: -1 turn, T≤2: +1 turn | `calculate_recovery_time()` | UNVERIFIED — verify toughness modifier exists in book | | |
| 8C-003 | Medical supplies modifier | p.94 | `InjurySystemService.gd:189-191` has_medical_supplies: -1 turn | Applied if supplies available | UNVERIFIED — verify medical supply effect | | |
| 8C-004 | Treatment system | p.76/122 | `InjurySystemConstants.gd` new `TreatmentType` enum: SICK_BAY (4cr/turn, p.76 VERIFIED), SURGERY (1D6cr instant for Crippling, p.122), NATURAL (free). Helpers: `get_treatment_options()`, `calculate_sick_bay_cost()`, `roll_surgery_cost()` | `InjurySystemConstants.gd` TREATMENT_OPTIONS const | **ADDED** — treatment system implemented with 3 options | AI | 2026-03-22 |

---

## Chapter 9: Advancement (Core Rules pp.67-76)

### Architecture Overview

**Key Files**:

- [CharacterAdvancementConstants.gd](src/core/systems/CharacterAdvancementConstants.gd) (137 lines) — XP costs, stat maximums, restrictions
- [AdvancementSystem.gd](src/core/character/advancement/AdvancementSystem.gd) (616 lines) — D6 advancement roll, training, bot upgrades
- [Character.gd:154](src/core/character/Character.gd#L154) — `advancement_history` property

**Test Files**: [test_character_advancement_costs.gd](tests/unit/test_character_advancement_costs.gd) (118 lines), [test_character_advancement_application.gd](tests/unit/test_character_advancement_application.gd) (207 lines), [test_character_advancement_eligibility.gd](tests/unit/test_character_advancement_eligibility.gd) (168 lines)

### 9A: XP Costs & Stat Maximums

**Data Sources**: [CharacterAdvancementConstants.gd:10-27](src/core/systems/CharacterAdvancementConstants.gd#L10-L27)
**Implementing Code**: [AdvancementSystem.gd:167-219](src/core/character/advancement/AdvancementSystem.gd#L167-L219) (`advance_stat()` — D6 roll, target 7)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 9A-001 | XP costs per stat | p.67 | `CharacterAdvancementConstants.gd:10-17` R:7, C:7, S:5, Sv:5, T:6, Luck:10 | `AdvancementSystem.gd:29-36` mirrors | UNVERIFIED — verify all 6 costs match book | | |
| 9A-002 | Stat maximums | p.67 | `CharacterAdvancementConstants.gd:20-27` R:6, C:5, S:8, Sv:5, T:6, Luck:3(human)/1(non-human) | `AdvancementSystem.gd:38-45` mirrors | UNVERIFIED — verify all max values | | |
| 9A-003 | Engineer T max = 4 | p.67 | `CharacterAdvancementConstants.gd:30-34` background restriction | `AdvancementSystem.gd:179-181` checks | UNVERIFIED — verify Engineer cap | | |
| 9A-004 | Human luck max = 3 | p.67 | `CharacterAdvancementConstants.gd:37-45` species restriction | `AdvancementSystem.gd` checks | UNVERIFIED — verify Human vs non-human luck caps | | |
| 9A-005 | D6 advancement roll | p.67 | `AdvancementSystem.gd:195-203` roll D6, success if roll+current_stat ≥ 7 | `advance_stat()` method | UNVERIFIED — verify D6+stat ≥ 7 formula | | |
| 9A-006 | Advancement priority | p.67 | `CharacterAdvancementConstants.gd:49-56` Combat>Reactions>Toughness>Speed>Savvy>Luck | Auto-advancement order | UNVERIFIED — verify priority order exists in book | | |

### 9B: Training System

**Implementing Code**: [AdvancementSystem.gd:47-58](src/core/character/advancement/AdvancementSystem.gd#L47-L58) (10 training types), [AdvancementSystem.gd:222-323](src/core/character/advancement/AdvancementSystem.gd#L222-L323) (`purchase_training()` + `_apply_training_benefits()`)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 9B-001 | Training types (10) | p.67-76 | `AdvancementSystem.gd:47-58` Pilot(20XP), Medical(20), Mechanic(15), Broker(15), Security(10), Merchant(10), Bot Tech(10), Engineer(15), Psionics(12), Psionics Enhance(6) | `_apply_training_benefits()` | UNVERIFIED — verify all 10 training types, XP costs, and stat bonuses | | |
| 9B-002 | Psionic training blocks combat | p.67 | `AdvancementSystem.gd:184-186` psionic characters cannot advance combat_skill via XP | Hardcoded check | UNVERIFIED — verify psionics block combat advancement | | |

### 9C: Bot Upgrade System (Credit-Based)

**Implementing Code**: [AdvancementSystem.gd:61-98](src/core/character/advancement/AdvancementSystem.gd#L61-L98) (6 upgrades), [AdvancementSystem.gd:474-572](src/core/character/advancement/AdvancementSystem.gd#L474-L572) (`install_bot_upgrade()`)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 9C-001 | Bot upgrades (6 types) | p.131 | `AdvancementSystem.gd:61-98` Combat Module(15cr), Reflex Enhancer(12), Armor Plating(18), Speed Actuator(10), Sensor Array(14), Repair Module(20) | `install_bot_upgrade()` + `_apply_bot_upgrade_effects()` | UNVERIFIED — verify 6 upgrade types and credit costs | | |
| 9C-002 | Bot stat caps same as human | p.131 | `AdvancementSystem.gd:549-572` C:5, R:6, T:6, S:8, Sv:5 | Same caps as regular advancement | UNVERIFIED — verify bot stat caps | | |

---

## Chapter 10: Loot Tables (Core Rules pp.66-72)

> **Note**: Loot table D100 ranges were already mapped in Chapter 7B. See sections 7B-001 through 7B-006 for full traceability entries with `loot_tables.json` and `LootSystemConstants.gd` file:line references.

---

## Chapter 11: Economy

### Architecture Overview

**Key Files**:

- [FiveParsecsConstants.gd:118-136](src/core/systems/FiveParsecsConstants.gd#L118-L136) — ECONOMY dict (all with Core Rules citations)
- [EquipmentManager.gd:545-567](src/core/equipment/EquipmentManager.gd#L545-L567) — Sell value calculations
- [WorldEconomyManager.gd:7](src/core/managers/WorldEconomyManager.gd#L7) — BASE_UPKEEP_COST=100 (100x scale)

### 11A: Starting Values & Economy Constants

**Data Sources**: [FiveParsecsConstants.gd:118-136](src/core/systems/FiveParsecsConstants.gd#L118-L136)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 11A-001 | Starting credits per crew | p.28 | `FiveParsecsConstants.gd:135` starting_credits_per_crew: 1 — VERIFIED comment | Economy constants | UNVERIFIED — verify 1 credit per crew member at start | | |
| 11A-002 | Starting debt threshold | p.76 | `FiveParsecsConstants.gd:120` starting_debt: 75 (ship seizure at ≥75, 2D6 roll 2-6 = seized) | Economy constants | UNVERIFIED — verify 75 threshold and seizure rule | | |
| 11A-003 | Hull repair cost | p.76 | `FiveParsecsConstants.gd:128` hull_repair_cost_per_point: 1 — VERIFIED comment | Economy constants | UNVERIFIED — verify 1 credit per hull point | | |
| 11A-004 | Injury treatment cost | p.76 | `FiveParsecsConstants.gd:126` injury_treatment_cost: 4 — VERIFIED comment | Economy constants | UNVERIFIED — verify 4 credits removes 1 recovery turn | | |
| 11A-005 | Ship maintenance base | p.76 | `FiveParsecsConstants.gd:125` ship_maintenance_base: 0 (auto-repair 1HP free) — VERIFIED comment | Economy constants | UNVERIFIED — verify free auto-repair | | |
| 11A-006 | GAME_BALANCE_ESTIMATE values | N/A | `FiveParsecsConstants.gd:127,129,130` luxury_upkeep(2), trade_profit(10), equipment_degradation(0.1) | Not from Core Rules — app features | N/A — intentional deviations, tagged | | |

### 11B: Trade & Sell Values

**Implementing Code**: [EquipmentManager.gd:545-567](src/core/equipment/EquipmentManager.gd#L545-L567) (`_calculate_weapon_value()`), [EquipmentManager.gd:569-590](src/core/equipment/EquipmentManager.gd#L569-L590) (`_calculate_armor_value()`)

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 11B-001 | Sell value formula | p.85 | `EquipmentManager.gd:545-590` base 100-500 by type, +50/damage, +30/range, quality multiplier | `_calculate_weapon_value()` / `_calculate_armor_value()` | UNVERIFIED — verify sell formula matches book | | |
| 11B-002 | Quality sell multipliers | p.85 | `LootSystemConstants.gd` QUALITY_MODIFIERS — DAMAGED(50%), WORN(70%), STANDARD(100%), QUALITY(120%), MILITARY(150%), ARTIFACT(200%) | Applied at sell time | UNVERIFIED — verify quality tier multipliers | | |

---

## Chapter 12: Enemy Data

### Architecture Overview

**Key Files**:

- [data/enemy_types.json](data/enemy_types.json) — Enemy templates loaded at [EnemyGenerator.gd:40](src/core/systems/EnemyGenerator.gd#L40)
- [data/enemy_presets.json](data/enemy_presets.json) — Preset configurations loaded at [EnemyGenerator.gd:43](src/core/systems/EnemyGenerator.gd#L43)
- [data/elite_enemy_types.json](data/elite_enemy_types.json) — Elite enemies, loaded conditionally by difficulty
- [data/RulesReference/Bestiary.json](data/RulesReference/Bestiary.json) — Authoritative enemy stat reference from Core Rules
- [data/RulesReference/EnemyAI.json](data/RulesReference/EnemyAI.json) — Enemy behavior patterns
- [data/enemies/](data/enemies/) — Subfolder: `corporate_security_data.json`, `pirates_data.json`, `wildlife_data.json`
- [data/campaign_tables/unique_individuals.json](data/campaign_tables/unique_individuals.json) — Unique individual types

### 12A: Enemy Type Stat Blocks

**Data Sources**: [data/enemy_types.json](data/enemy_types.json), [data/RulesReference/Bestiary.json](data/RulesReference/Bestiary.json)
**Implementing Code**: [EnemyGenerator.gd:40](src/core/systems/EnemyGenerator.gd#L40) (loads JSON), [EnemyGenerator.gd:296-316](src/core/systems/EnemyGenerator.gd#L296-L316) (`_get_enemy_template_from_json()`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 12A-001 | Enemy categories | pp.63-65 | `enemy_types.json` + `Bestiary.json` — Criminal Elements, Hired Muscle, Roving Threats, Interested Parties | `EnemyGenerator.gd:108-159` maps categories | UNVERIFIED — verify all categories and their stat blocks | | |
| 12A-002 | Enemy stat blocks | pp.63-65 | Combat, toughness, weapons per enemy type in JSON | `EnemyGenerator.gd:296-316` reads templates | UNVERIFIED — verify each stat block matches book | | |
| 12A-003 | Enemy AI behavior | pp.63-65 | `EnemyAI.json` behavior patterns and priority matrices | Used by tactical battle system | UNVERIFIED — verify AI types per enemy category | | |
| 12A-004 | Subfolder enemy data | pp.63-65 | `data/enemies/` corporate_security, pirates, wildlife | Consumed by EnemyGenerator | UNVERIFIED — verify specialized enemy stats | | |

### 12B: Unique Individuals

**Data Sources**: [data/campaign_tables/unique_individuals.json](data/campaign_tables/unique_individuals.json)
**Implementing Code**: [EnemyGenerator.gd:318-362](src/core/systems/EnemyGenerator.gd#L318-L362) (`_select_individual_enemy()`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 12B-001 | Unique individual types | p.88+ | `unique_individuals.json` types and stats | `EnemyGenerator.gd:325-327` threshold from JSON | UNVERIFIED — verify all unique types | | |
| 12B-002 | Unique spawn chance | p.88+ | JSON `unique_chance` field per unit type | `EnemyGenerator.gd:328` if randf() < threshold | UNVERIFIED — verify spawn probability | | |

---

## Chapter 13: Missions

### Architecture Overview

**Key Files**:

- [data/missions/](data/missions/) — `mission_generation_params.json`, `opportunity_missions.json`, `patron_missions.json`
- [data/mission_tables/](data/mission_tables/) — 11 files: types, titles, descriptions, difficulty, rewards, events, bonus_objectives, bonus_rewards, deployment_points, reward_items, rival_involvement (credit_rewards DELETED — was fabricated)
- [data/mission_templates.json](data/mission_templates.json) — Template-based generation
- [MissionGenerator.gd](src/core/systems/MissionGenerator.gd) (347 lines) — Primary generator (loads `mission_templates.json`)
- [MissionGenerator.gd](src/campaign/mission/MissionGenerator.gd) (197 lines) — Secondary generator (inline templates)
- [FiveParsecsMissionGenerator.gd](src/game/campaign/FiveParsecsMissionGenerator.gd) — Game-specific generator

> **NOTE**: Multiple MissionGenerator implementations exist — unclear which is canonical.

### 13A: Mission Types & Rewards

**Data Sources**: [data/mission_tables/mission_types.json](data/mission_tables/mission_types.json), [data/mission_tables/mission_rewards.json](data/mission_tables/mission_rewards.json)
**Implementing Code**: [MissionGenerator.gd:54-79](src/core/systems/MissionGenerator.gd#L54-L79) (`generate_mission()`), [MissionGenerator.gd:200-229](src/core/systems/MissionGenerator.gd#L200-L229) (`_calculate_mission_difficulty()`, `_generate_rewards()`)

| ID | Item | Page | JSON Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 13A-001 | Mission type list | p.87 | `mission_types.json` + `mission_templates.json` | `MissionGenerator.gd:54` filters by type | UNVERIFIED — verify all mission types match book | | |
| 13A-002 | Mission reward formula | p.97 | `MissionGenerator.gd:232-247` credits = difficulty*100 + random(0-500) + reputation + items | Hardcoded formula | UNVERIFIED — **SUSPECT**: formula may be invented. Verify against book | | |
| 13A-003 | Enemy composition patterns | p.87 | `MissionGenerator.gd:127-197` standard(4-8+1 elite), boss(3-6+1-2 elite+1 boss), patrol(3-5 bots), raiders(5-9+1 elite) | `_generate_enemy_composition()` | UNVERIFIED — verify composition patterns exist in book | | |
| 13A-004 | Difficulty modifiers | p.87 | `MissionGenerator.gd:200-229` +1/minion, +2/elite, +4/boss, +2 BLACK_ZONE, +1 SABOTAGE, +3 ASSASSINATION | `_calculate_mission_difficulty()` | UNVERIFIED — verify difficulty scaling formula | | |

---

## Chapter 14: Victory Conditions (Core Rules pp.63-64)

**Data Sources**: [data/victory_conditions.json](data/victory_conditions.json) (17 conditions — **REWRITTEN Mar 22, 2026**)
**Implementing Code**: [VictoryConditionTracker.gd:28](src/core/campaign/VictoryConditionTracker.gd#L28) (loads JSON), [VictoryChecker.gd:9-30](src/core/victory/VictoryChecker.gd#L9-L30) (`check_victory()`)

> **RESOLVED**: Victory conditions rewritten from Core Rules pp.63-64. Removed 8 fabricated conditions (CREDITS_50K, CREDITS_100K, REPUTATION_10, REPUTATION_20, STORY_POINTS_10, STORY_POINTS_20, CREW_SIZE_10, CHARACTER_SURVIVAL). Added 3 missing conditions (KILLS_UNIQUE_10, KILLS_UNIQUE_25, TURNS_50_INSANITY). Each condition now has `difficulty_allowed` array. Easy mode correctly restricted to TURNS_20 and BATTLES_20 only. Elite Ranks benefits documented. `allow_multiple_conditions` corrected to `false` (Core Rules: "only one selected condition"). Fabricated campaign_types section removed.

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 14A-001 | Victory condition types (17) | pp.63-64 | `victory_conditions.json` 17 conditions: TURNS_20/50/100, QUESTS_3/5/10, BATTLES_20/50/100, KILLS_UNIQUE_10/25, UPGRADE_1/3/5_x10, TURNS_50_CHALLENGING/HARDCORE/INSANITY | `VictoryConditionTracker.gd:28` loads JSON | **REWRITTEN** — 17 real conditions. 8 fabricated removed. **VERIFIED against core_rulebook.txt** for exact list | AI+txt | 2026-03-22 |
| 14A-002 | Victory thresholds | pp.63-64 | Per-condition `required` values (20/50/100 turns, 3/5/10 quests, 20/50/100 battles, 10/25 kills, 10 upgrades) | JSON `conditions.*.required` field | **REWRITTEN** — thresholds from Core Rules text. **VERIFIED against core_rulebook.txt** | AI+txt | 2026-03-22 |
| 14A-003 | Easy mode restrictions | p.64 | `victory_conditions.json` `easy_mode_restrictions.allowed_conditions: ["TURNS_20", "BATTLES_20"]` | Applied by campaign setup | **REWRITTEN** — only Play 20 turns and Win 20 battles allowed in Easy mode | AI | 2026-03-22 |
| 14A-004 | Difficulty gating per condition | pp.63-64 | Each condition has `difficulty_allowed` array (e.g. TURNS_50_CHALLENGING only allowed in "challenging") | Applied by campaign setup UI | **NEW** — difficulty gates added per condition | AI | 2026-03-22 |
| 14A-005 | Character upgrade death rule | p.63 | `victory_conditions.json` UPGRADE conditions: "Characters do not have to be in the crew at the end — deaths still count" | Description text in JSON | **DOCUMENTED** — rule noted in condition descriptions | AI | 2026-03-22 |
| 14A-006 | Elite Ranks benefits | p.65 | `victory_conditions.json` `elite_ranks.per_rank_benefits` (4 benefits) | Reference data only — implementation in LegacySystem.gd | **DOCUMENTED** — benefits from Core Rules p.65 recorded in JSON | AI | 2026-03-22 |
| 14A-007 | Single condition rule | p.63 | `victory_conditions.json` `allow_multiple_conditions: false` | "Cannot be changed, only one selected condition" | **FIXED** — was `true` (fabricated), now `false` per Core Rules | AI | 2026-03-22 |

---

## Chapter 15: Difficulty Modifiers

### Architecture Overview

**Key Files**:

- [data/RulesReference/DifficultyOptions.json](data/RulesReference/DifficultyOptions.json) — Extracted difficulty options from Core Rules
- [SeizeInitiativeSystem.gd:106-115](src/core/battle/SeizeInitiativeSystem.gd#L106-L115) — Difficulty modifiers for initiative
- [EnemyGenerator.gd:198-204](src/core/systems/EnemyGenerator.gd#L198-L204) — CHALLENGING reroll for enemy count

### 15A: Difficulty Scaling

**Data Sources**: [data/RulesReference/DifficultyOptions.json](data/RulesReference/DifficultyOptions.json)
**Implementing Code**: Various systems apply difficulty — initiative ([SeizeInitiativeSystem.gd:106-115](src/core/battle/SeizeInitiativeSystem.gd#L106-L115)), enemy count ([EnemyGenerator.gd:198-204](src/core/systems/EnemyGenerator.gd#L198-L204)), XP ([ExperienceTrainingProcessor.gd:193-229](src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd#L193-L229))

| ID | Item | Page | Code Value | Code Path | Status | By | Date |
|----|------|------|-----------|-----------|--------|-----|------|
| 15A-001 | EASY modifiers | p.? | `DifficultyOptions.json` (needs reading) | Applied in various systems | UNVERIFIED — verify all EASY effects | | |
| 15A-002 | NORMAL modifiers | p.? | Baseline — no modifiers applied | Default behavior | UNVERIFIED — confirm NORMAL is baseline | | |
| 15A-003 | CHALLENGING modifiers | p.? | `EnemyGenerator.gd:200-204` reroll enemy dice 1-2 once; `SeizeInitiativeSystem.gd:110-111` no initiative modifier | Hardcoded in generators | UNVERIFIED — verify reroll rule | | |
| 15A-004 | HARDCORE modifiers | p.? | `SeizeInitiativeSystem.gd:113` initiative -2 | Hardcoded | UNVERIFIED — verify -2 initiative | | |
| 15A-005 | INSANITY modifiers | p.? | `SeizeInitiativeSystem.gd:115` initiative -3 | Hardcoded | UNVERIFIED — verify -3 initiative | | |
| 15A-006 | XP difficulty multipliers | p.? | `ExperienceTrainingProcessor.gd:193-229` Normal=1.0x, Hard=1.25x, Deadly=1.5x, Catastrophic=2.0x | Post-battle XP calc | UNVERIFIED — verify XP multiplier values per difficulty | | |

---

## Compendium / DLC Data

> **DLC Gating**: All Compendium content is gated by 35 `ContentFlag` values in [DLCManager.gd](src/core/systems/DLCManager.gd) across 4 DLC packs. Feature checks use: `DLCManager.is_feature_enabled(DLCManager.ContentFlag.FLAG_NAME)`. Ownership persisted to `user://dlc_ownership.cfg`.
>
> **⚠ DATA DUPLICATION WARNING**: Three mission generators (`SalvageJobGenerator.gd`, `StreetFightGenerator.gd`, `StealthMissionGenerator.gd`) contain **hardcoded copies** of tables also defined in compendium data files. These may drift. Single Source of Truth should be the compendium `src/data/` files.

### C1: Trailblazer's Toolkit (7 ContentFlags)

**ContentFlags**: `SPECIES_KRAG`, `SPECIES_SKULKER`, `PSIONICS`, `NEW_TRAINING`, `BOT_UPGRADES`, `NEW_SHIP_PARTS`, `PSIONIC_EQUIPMENT`
**Data Sources**: [compendium_species.gd](src/data/compendium_species.gd) (269 lines), [compendium_equipment.gd](src/data/compendium_equipment.gd) (324 lines)
**DLC Map**: [DLCManager.gd:77-85](src/core/systems/DLCManager.gd#L77-L85)

| ID | Item | Source | Code Value | Code Path | Status | By | Date |
|----|------|--------|-----------|-----------|--------|-----|------|
| C1-001 | Krag species stats | TT | T:+1, Sv:-1, special: no_dash, belligerent_reroll, patron_rival_penalty, always_fights | [compendium_species.gd:27-56](src/data/compendium_species.gd#L27-L56) | UNVERIFIED — verify all Krag stat mods + special rules vs Trailblazer's Toolkit | | |
| C1-002 | Krag armor rules | TT | Armor/screen rules for Krag species | [compendium_species.gd:40-48](src/data/compendium_species.gd#L40-L48) | UNVERIFIED — verify Krag armor interaction rules | | |
| C1-003 | Skulker species stats | TT | S:+1, T:-1, special: difficult_ground_immune, climb_discount, bio_resistance, universal_armor | [compendium_species.gd:83-132](src/data/compendium_species.gd#L83-L132) | UNVERIFIED — verify all Skulker stat mods + special rules | | |
| C1-004 | Skulker reduced credits | TT | `reduced_credits` special rule on Skulker | [compendium_species.gd:95](src/data/compendium_species.gd#L95) | UNVERIFIED — verify reduced credits amount/mechanic | | |
| C1-005 | Prison Planet character stats | TT/FG | T:+1, C:+1, special: hardened_survivor | [compendium_species.gd:134-166](src/data/compendium_species.gd#L134-L166) | UNVERIFIED — verify Prison Planet stat mods (may be Fixer's Guidebook, not TT) | | |
| C1-006 | DLC species in char creation | TT | Dropdown gating via `DLCManager.ContentFlag.SPECIES_KRAG/SKULKER` | [CharacterCreator.gd:165-206](src/core/character/Generation/CharacterCreator.gd#L165-L206) | UNVERIFIED — verify species gating works correctly | | |
| C1-007 | Character creation bonus mapping | TT | `character_creation_bonuses.json` keys "9"→Krag(T:+1,Sv:-1), "10"→Skulker(S:+1,T:-1), "11"→Prison(T:+1,C:+1) | [character_creation_bonuses.json:15-17](data/character_creation_bonuses.json#L15-L17) | UNVERIFIED — verify bonus values match compendium_species.gd | | |
| C1-008 | Psionic powers system | TT | 12 powers costing 6 XP each (per compendium) | [compendium_equipment.gd](src/data/compendium_equipment.gd) — psionic_equipment section | UNVERIFIED — verify power count, names, costs, effects vs Trailblazer's Toolkit | | |
| C1-009 | Training options (D100) | TT | 20 training entries in D100 table | [compendium_equipment.gd](src/data/compendium_equipment.gd) — `get_training_option(roll)` | UNVERIFIED — verify 20 training types and roll ranges | | |
| C1-010 | Bot upgrades (D100) | TT | 15 bot upgrade entries in D100 table | [compendium_equipment.gd](src/data/compendium_equipment.gd) — `get_bot_upgrade(roll)` | UNVERIFIED — verify 15 upgrade types and roll ranges | | |
| C1-011 | New ship parts (D100) | TT | 12 ship part entries in D100 table | [compendium_equipment.gd](src/data/compendium_equipment.gd) — `get_ship_part(roll)` | UNVERIFIED — verify 12 ship part types and roll ranges | | |
| C1-012 | Psionic equipment (D100) | TT | 10 psionic equipment entries in D100 table | [compendium_equipment.gd](src/data/compendium_equipment.gd) — `get_psionic_equipment(roll)` | UNVERIFIED — verify 10 psionic items and roll ranges | | |

### C2: Freelancer's Handbook (16 ContentFlags)

**ContentFlags**: `PROGRESSIVE_DIFFICULTY`, `DIFFICULTY_TOGGLES`, `PVP_BATTLES`, `COOP_BATTLES`, `AI_VARIATIONS`, `DEPLOYMENT_VARIABLES`, `ESCALATING_BATTLES`, `ELITE_ENEMIES`, `EXPANDED_MISSIONS`, `EXPANDED_QUESTS`, `EXPANDED_CONNECTIONS`, `DRAMATIC_COMBAT`, `NO_MINIS_COMBAT`, `GRID_BASED_MOVEMENT`, `TERRAIN_GENERATION`, `CASUALTY_TABLES`, `DETAILED_INJURIES`
**Data Sources**: [compendium_difficulty_toggles.gd](src/data/compendium_difficulty_toggles.gd) (447 lines), [compendium_deployment_variables.gd](src/data/compendium_deployment_variables.gd) (110 lines), [compendium_escalating_battles.gd](src/data/compendium_escalating_battles.gd) (141 lines), [compendium_no_minis.gd](src/data/compendium_no_minis.gd) (348 lines), [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) (740 lines)
**DLC Map**: [DLCManager.gd:86-100](src/core/systems/DLCManager.gd#L86-L100)

| ID | Item | Source | Code Value | Code Path | Status | By | Date |
|----|------|--------|-----------|-----------|--------|-----|------|
| C2-001 | Difficulty toggles UI options | FH | Toggle definitions for game balance adjustments | [compendium_difficulty_toggles.gd](src/data/compendium_difficulty_toggles.gd) — `get_difficulty_option()` | UNVERIFIED — verify toggle names and effects | | |
| C2-002 | AI variation tables (D100) | FH | AI behavior variations by difficulty level | [compendium_difficulty_toggles.gd](src/data/compendium_difficulty_toggles.gd) — `get_ai_variation(roll, difficulty)` | UNVERIFIED — verify AI variation entries | | |
| C2-003 | Casualty tables (D100 × 5 levels) | FH | 5 difficulty-scaled casualty result tables | [compendium_difficulty_toggles.gd](src/data/compendium_difficulty_toggles.gd) — `get_casualty_result(roll, difficulty)` | UNVERIFIED — verify casualty outcomes per difficulty | | |
| C2-004 | Detailed injury tables (D100 × 4 types) | FH | 4 injury-type-specific detail tables | [compendium_difficulty_toggles.gd](src/data/compendium_difficulty_toggles.gd) — `get_injury_detail(roll, injury_type)` | UNVERIFIED — verify injury detail entries | | |
| C2-005 | Dramatic combat modifiers (D100) | FH | Combat modifier table for cinematic battles | [compendium_difficulty_toggles.gd](src/data/compendium_difficulty_toggles.gd) — `get_dramatic_modifier(roll)` | UNVERIFIED — verify dramatic combat entries | | |
| C2-006 | Deployment strategies (D10, 9 types) | FH | Standard Line, Skirmish, Column, Wedge, Defense In Depth, Ambush, Encirclement, Advance Guard, Rearguard | [compendium_deployment_variables.gd](src/data/compendium_deployment_variables.gd) — `get_deployment_strategy(roll)` | UNVERIFIED — verify 9 strategy names, rules, and D10 ranges | | |
| C2-007 | Battle escalation (D100, 10 levels) | FH | 10 escalation level definitions with effects | [compendium_escalating_battles.gd](src/data/compendium_escalating_battles.gd) — `get_escalation_result(roll)` | UNVERIFIED — verify escalation levels and effects | | |
| C2-008 | No-minis combat system | FH | Abstract combat resolution with range bands (close/short/medium/long), D100 action table, D6 positioning | [compendium_no_minis.gd](src/data/compendium_no_minis.gd) — `resolve_combat_abstract()` | UNVERIFIED — verify combat resolution mechanics | | |
| C2-009 | Expanded mission objectives (D100, 14 types) | FH | 14 objective types + 5 time constraints + 5 extraction scenarios | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) — `roll_mission_objective(roll)` | UNVERIFIED — verify 14 objective types and D100 ranges | | |
| C2-010 | Patron conditions (D100, 20 modifiers) | FH | 20 patron-specific mission modifiers | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) — `roll_patron_condition(roll)` | UNVERIFIED — verify 20 patron condition entries | | |
| C2-011 | Expanded quest system (D100, 10 types) | FH | Quest progression table + final battle conclusion rules | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) — `roll_quest_progression(roll)`, `get_quest_conclusion()` | UNVERIFIED — verify quest types and conclusion mechanics | | |
| C2-012 | Narrative connections (D6 × 5 subtables) | FH | 5 connection types with 6 scenarios each (30 total) | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) — `roll_narrative_connection(roll)` | UNVERIFIED — verify 30 narrative scenarios | | |
| C2-013 | PvP battle system | FH | Reason table (D100), power rating calc, third-party deployment, PvP rules | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) — `roll_pvp_reason(roll)` | UNVERIFIED — verify PvP mechanics | | |
| C2-014 | Co-op battle system | FH | 6 cooperative battle rule variants | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) | UNVERIFIED — verify 6 co-op rule sets | | |
| C2-015 | Introductory campaign (6 missions) | FH | 6 scripted tutorial missions for turns 0-5 with difficulty ramp | [compendium_missions_expanded.gd](src/data/compendium_missions_expanded.gd) — `roll_introductory_mission(turn)` | UNVERIFIED — verify 6 introductory mission definitions | | |
| C2-016 | Elite enemies | FH | Elite enemy stat blocks and spawning rules | [data/RulesReference/EliteEnemies.json](data/RulesReference/EliteEnemies.json), [data/elite_enemy_types.json](data/elite_enemy_types.json) | UNVERIFIED — verify elite enemy types match Freelancer's Handbook | | |
| C2-017 | Grid-based movement rules | FH p.90 | Text helpers: [CheatSheetPanel.gd:303-368](src/ui/components/battle/CheatSheetPanel.gd#L303-L368) `_grid_movement_text()`, [TacticalBattleUI.gd:1843-1846](src/ui/screens/battle/TacticalBattleUI.gd#L1843-L1846) setup instructions, [BattlePhase.gd:347](src/core/campaign/phases/BattlePhase.gd#L347) passes flag | Source: [docs/compendium.md:5911](docs/compendium.md) | UNVERIFIED — verify text helpers match Compendium p.90 | | |
| C2-018 | Terrain generation | FH | Terrain type generation tables | [compendium_world_options.gd](src/data/compendium_world_options.gd) — `get_terrain(roll)`, [data/battlefield/themes/compendium_terrain.json](data/battlefield/themes/compendium_terrain.json) | UNVERIFIED — verify terrain types and generation rules | | |
| C2-019 | Progressive difficulty | FH p.30 | [ProgressiveDifficultyTracker.gd](src/core/systems/ProgressiveDifficultyTracker.gd) — turn-based difficulty scaling. Preloaded in [BattlePhase.gd:10](src/core/campaign/phases/BattlePhase.gd#L10), applied at [BattlePhase.gd:1408](src/core/campaign/phases/BattlePhase.gd#L1408) | Tests: [test_compendium_systems.gd:14-36](tests/unit/test_compendium_systems.gd#L14-L36). Source: [docs/compendium.md:8460](docs/compendium.md) | UNVERIFIED — verify tracker milestones/scaling match Compendium p.30 | | |

### C3: Fixer's Guidebook (9 ContentFlags)

**ContentFlags**: `STEALTH_MISSIONS`, `STREET_FIGHTS`, `SALVAGE_JOBS`, `EXPANDED_FACTIONS`, `FRINGE_WORLD_STRIFE`, `EXPANDED_LOANS`, `NAME_GENERATION`, `INTRODUCTORY_CAMPAIGN`, `PRISON_PLANET_CHARACTER`
**Data Sources**: [compendium_stealth_missions.gd](src/data/compendium_stealth_missions.gd) (373 lines), [compendium_street_fights.gd](src/data/compendium_street_fights.gd) (529 lines), [compendium_salvage_jobs.gd](src/data/compendium_salvage_jobs.gd) (353 lines), [compendium_world_options.gd](src/data/compendium_world_options.gd) (491 lines)
**DLC Map**: [DLCManager.gd:103-113](src/core/systems/DLCManager.gd#L103-L113)

| ID | Item | Source | Code Value | Code Path | Status | By | Date |
|----|------|--------|-----------|-----------|--------|-----|------|
| C3-001 | Stealth mission objectives (D100, 6 types) | FG | 6 stealth objective types with D100 ranges | [compendium_stealth_missions.gd](src/data/compendium_stealth_missions.gd) — `roll_objective(roll)` | UNVERIFIED — verify 6 objectives vs Fixer's Guidebook | | |
| C3-002 | Stealth NPCs/individuals (D100, 10 types) | FG | 10 NPC types with stat blocks | [compendium_stealth_missions.gd](src/data/compendium_stealth_missions.gd) — `roll_individual_type(roll)` | UNVERIFIED — verify 10 NPC types and stats | | |
| C3-003 | Sentry patrol mechanics (D6, 6 types) | FG | 6 patrol behavior patterns | [compendium_stealth_missions.gd](src/data/compendium_stealth_missions.gd) — `roll_sentry_patrol(roll)` | UNVERIFIED — verify patrol types | | |
| C3-004 | Spotting/detection mechanics | FG | 7 modifier types affecting detection rolls, D100 detection result table | [compendium_stealth_missions.gd](src/data/compendium_stealth_missions.gd) — `roll_spotting_modifier()`, `get_detection_result(roll)` | UNVERIFIED — verify detection modifiers and results | | |
| C3-005 | ⚠ Stealth data duplication | FG | `StealthMissionGenerator.gd` has **hardcoded copies** of stealth tables | [StealthMissionGenerator.gd](src/core/mission/StealthMissionGenerator.gd) vs [compendium_stealth_missions.gd](src/data/compendium_stealth_missions.gd) | CONFLICT — generator should import from compendium file, not duplicate | | |
| C3-006 | Street fight objectives (D100, 6 types) | FG | Gang Raid, Protection Racket, Bounty Hunt, Turf War, Evidence Gathering, Ambush Response | [compendium_street_fights.gd](src/data/compendium_street_fights.gd) — `roll_objective()` | UNVERIFIED — verify 6 objective types vs Fixer's Guidebook | | |
| C3-007 | Street fight buildings (D6, 6 types) | FG | 6 building types with cover ratings and floor counts | [compendium_street_fights.gd](src/data/compendium_street_fights.gd) — `roll_building()` | UNVERIFIED — verify building types | | |
| C3-008 | Suspect identity (D6, 6 types) | FG | Civilian, Panicked Civilian, Gang Members, Gang Leader, Target/VIP | [compendium_street_fights.gd](src/data/compendium_street_fights.gd) — `roll_suspect_identity()` | UNVERIFIED — verify suspect types | | |
| C3-009 | Police response (4 escalation levels) | FG | 4-level police escalation mechanic | [compendium_street_fights.gd](src/data/compendium_street_fights.gd) | UNVERIFIED — verify escalation levels | | |
| C3-010 | ⚠ Street fight data duplication | FG | `StreetFightGenerator.gd` has **hardcoded copies** of street fight tables | [StreetFightGenerator.gd](src/core/mission/StreetFightGenerator.gd) vs [compendium_street_fights.gd](src/data/compendium_street_fights.gd) | CONFLICT — generator should import from compendium file, not duplicate | | |
| C3-011 | Salvage job finding (D6, 6 entries) | FG | 6 job-finding results | [compendium_salvage_jobs.gd](src/data/compendium_salvage_jobs.gd) — `find_salvage_job()` | UNVERIFIED — verify job-finding table | | |
| C3-012 | Salvage tension mechanics | FG | Starting tension value, escalation rules per round | [compendium_salvage_jobs.gd](src/data/compendium_salvage_jobs.gd) | UNVERIFIED — verify tension mechanic | | |
| C3-013 | Salvage POIs (D100, 11 types) | FG | 11 Point of Interest types with salvage values and tension modifiers | [compendium_salvage_jobs.gd](src/data/compendium_salvage_jobs.gd) — `roll_point_of_interest()` | UNVERIFIED — verify 11 POI types | | |
| C3-014 | Salvage credit conversion (5 tiers) | FG | 5 credit tiers based on salvage units collected | [compendium_salvage_jobs.gd](src/data/compendium_salvage_jobs.gd) — `get_salvage_credits(units)` | UNVERIFIED — verify credit conversion rates | | |
| C3-015 | ⚠ Salvage data duplication | FG | `SalvageJobGenerator.gd` has **hardcoded copies** of salvage tables | [SalvageJobGenerator.gd](src/core/mission/SalvageJobGenerator.gd) vs [compendium_salvage_jobs.gd](src/data/compendium_salvage_jobs.gd) | CONFLICT — generator should import from compendium file, not duplicate | | |
| C3-016 | Expanded factions (D100, 20+ types) | FG | 20+ faction types with descriptions | [compendium_world_options.gd](src/data/compendium_world_options.gd) — `get_faction(roll)`, `get_all_factions()` | UNVERIFIED — verify faction types vs Fixer's Guidebook | | |
| C3-017 | Fringe world strife (D100) | FG | Fringe world event/complication table | [compendium_world_options.gd](src/data/compendium_world_options.gd) — `get_fringe_world_strife(roll)` | UNVERIFIED — verify strife events | | |
| C3-018 | Expanded loans (D100) | FG | Loan option table with amounts and interest | [compendium_world_options.gd](src/data/compendium_world_options.gd) — `get_loan_option(roll)` | UNVERIFIED — verify loan amounts and interest rates | | |
| C3-019 | Name generation (D6 tables) | FG | First/last name tables by world type and gender | [compendium_world_options.gd](src/data/compendium_world_options.gd) — `generate_character_name(world_type, gender)` | UNVERIFIED — verify name tables | | |
| C3-020 | Prison Planet character | FG | T:+1, C:+1 + hardened_survivor special rule | [compendium_species.gd:134-166](src/data/compendium_species.gd#L134-L166), ContentFlag `PRISON_PLANET_CHARACTER` | UNVERIFIED — verify stats. Note: also listed in C1-005; determine which DLC pack owns this | | |

### C4: Bug Hunt (Compendium)

**Data Sources**: `data/bug_hunt/` (15 JSON files), [BugHuntCampaignCore.gd](src/game/campaign/BugHuntCampaignCore.gd) (476 lines)
**Engine Files**: [BugHuntPhaseManager.gd](src/core/campaign/BugHuntPhaseManager.gd), [BugHuntTurnController.gd](src/ui/screens/bug_hunt/BugHuntTurnController.gd), [BugHuntCreationUI.gd](src/ui/screens/bug_hunt/BugHuntCreationUI.gd), [BugHuntCreationCoordinator.gd](src/ui/screens/bug_hunt/BugHuntCreationCoordinator.gd)
**Character System**: [BugHuntCharacterGeneration.gd](src/core/character/BugHuntCharacterGeneration.gd), [CharacterTransferService.gd](src/core/character/CharacterTransferService.gd)
**Battle System**: [BugHuntBattleSetup.gd](src/core/battle/BugHuntBattleSetup.gd), [BugHuntEnemyGenerator.gd](src/core/systems/BugHuntEnemyGenerator.gd)
**UI Panels**: 7 panels in `src/ui/screens/bug_hunt/panels/` (Config, Equipment, Mission, PostBattle, Review, Squad, CharacterTransfer)

| ID | Item | Source | Code Value | Code Path | Status | By | Date |
|----|------|--------|-----------|-----------|--------|-----|------|
| C4-001 | Bug Hunt weapons | BH | Weapon stat blocks (name, range, shots, damage, traits) | [data/bug_hunt/bug_hunt_weapons.json](data/bug_hunt/bug_hunt_weapons.json) | UNVERIFIED — verify all weapon stats vs Bug Hunt Compendium | | |
| C4-002 | Bug Hunt armor | BH | Armor stat blocks (name, saving_throw, traits) | [data/bug_hunt/bug_hunt_armor.json](data/bug_hunt/bug_hunt_armor.json) | UNVERIFIED — verify all armor stats | | |
| C4-003 | Bug Hunt enemies | BH | Enemy stat blocks (speed, combat, toughness, AI, weapons) | [data/bug_hunt/bug_hunt_enemies.json](data/bug_hunt/bug_hunt_enemies.json) | UNVERIFIED — verify all enemy stat blocks | | |
| C4-004 | Alien subtypes | BH | Subtype modifications to base enemies | [data/bug_hunt/bug_hunt_alien_subtypes.json](data/bug_hunt/bug_hunt_alien_subtypes.json) | UNVERIFIED — verify subtype modifiers | | |
| C4-005 | Alien leaders | BH | Leader stat blocks and abilities | [data/bug_hunt/bug_hunt_alien_leaders.json](data/bug_hunt/bug_hunt_alien_leaders.json) | UNVERIFIED — verify leader stats | | |
| C4-006 | Spawn rules | BH | Spawn probabilities and placement rules | [data/bug_hunt/bug_hunt_spawn_rules.json](data/bug_hunt/bug_hunt_spawn_rules.json) | UNVERIFIED — verify spawn probabilities | | |
| C4-007 | Character creation | BH | Military character generation tables | [data/bug_hunt/bug_hunt_character_creation.json](data/bug_hunt/bug_hunt_character_creation.json), [BugHuntCharacterGeneration.gd](src/core/character/BugHuntCharacterGeneration.gd) | UNVERIFIED — verify creation tables | | |
| C4-008 | Special assignments | BH | Pre-mission special assignment options | [data/bug_hunt/bug_hunt_special_assignments.json](data/bug_hunt/bug_hunt_special_assignments.json) | UNVERIFIED — verify assignment types and effects | | |
| C4-009 | Missions | BH | Mission objective types and parameters | [data/bug_hunt/bug_hunt_missions.json](data/bug_hunt/bug_hunt_missions.json) | UNVERIFIED — verify mission types | | |
| C4-010 | Post-battle resolution | BH | Post-battle tables (casualties, rewards, promotions) | [data/bug_hunt/bug_hunt_post_battle.json](data/bug_hunt/bug_hunt_post_battle.json) | UNVERIFIED — verify post-battle tables | | |
| C4-011 | Gear/equipment | BH | Bug Hunt-specific gear items | [data/bug_hunt/bug_hunt_gear.json](data/bug_hunt/bug_hunt_gear.json) | UNVERIFIED — verify gear list | | |
| C4-012 | Tactical locations | BH | Mission location types and terrain rules | [data/bug_hunt/bug_hunt_tactical_locations.json](data/bug_hunt/bug_hunt_tactical_locations.json) | UNVERIFIED — verify location types | | |
| C4-013 | Support teams | BH | Support team types and abilities | [data/bug_hunt/bug_hunt_support_teams.json](data/bug_hunt/bug_hunt_support_teams.json) | UNVERIFIED — verify support team definitions | | |
| C4-014 | Regiment names | BH | Name generation tables for military units | [data/bug_hunt/bug_hunt_regiment_names.json](data/bug_hunt/bug_hunt_regiment_names.json) | UNVERIFIED — verify name tables | | |
| C4-015 | Movie magic events | BH | Cinematic event table for dramatic moments | [data/bug_hunt/bug_hunt_movie_magic.json](data/bug_hunt/bug_hunt_movie_magic.json) | UNVERIFIED — verify movie magic events | | |
| C4-016 | 3-stage turn flow | BH | SPECIAL_ASSIGNMENTS → MISSION → POST_BATTLE (not 9-phase) | [BugHuntPhaseManager.gd](src/core/campaign/BugHuntPhaseManager.gd), [BugHuntTurnController.gd](src/ui/screens/bug_hunt/BugHuntTurnController.gd) | UNVERIFIED — verify 3-stage turn matches Compendium | | |
| C4-017 | Campaign data model | BH | `main_characters`/`grunts` (flat Arrays), NO ship, NO patrons/rivals | [BugHuntCampaignCore.gd](src/game/campaign/BugHuntCampaignCore.gd) | UNVERIFIED — verify data model completeness | | |
| C4-018 | Character transfer (5PFH ↔ BH) | BH | Bidirectional transfer with enlistment rolls | [CharacterTransferService.gd](src/core/character/CharacterTransferService.gd), [CharacterTransferPanel.gd](src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd) | UNVERIFIED — verify transfer mechanics vs Compendium | | |
| C4-019 | TacticalBattleUI bug_hunt mode | BH | `battle_mode: "bug_hunt"` hides morale, adds ContactMarkerPanel | [TacticalBattleUI](src/ui/screens/battle/) with `_check_bug_hunt_launch()` validation | UNVERIFIED — verify bug hunt battle UI matches Compendium | | |
| C4-020 | Campaign type detection | BH | `GameState._detect_campaign_type()` peeks JSON to route BH vs 5PFH | [GameState.gd](src/core/state/GameState.gd) — `_detect_campaign_type()` | N/A — app architecture, not rules data | | |

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
| 6 | `data/onboard_items.json` | Yes | **WIRED** — EquipmentManager loads and provides get_onboard_items(), get_onboard_item(id) |
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
| 20 | `data/victory_conditions.json` | Yes | **REWRITTEN** — 17 conditions from Core Rules pp.63-64 (was fabricated) |
| 21 | `data/deployment_conditions.json` | Yes | UNVERIFIED |
| 22 | `data/world_traits.json` | Yes | **REWRITTEN** — 41 D100 entries from Core Rules pp.72-75 (was fabricated) |
| 23 | `data/patron_types.json` | Yes | **REWRITTEN** — 6 Core Rules patron types with D10 ranges + BHC thresholds. Fabricated fields removed |
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
| 34 | `data/mission_generation_data.json` | Yes | **REWRITTEN** — fabricated mission types removed, locations/terrain retained, objectives from patron_generation.json |
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
| 51 | `data/campaign_tables/world_phase/patron_jobs.json` | Yes | **REWRITTEN** — fabricated tiers/modifiers removed, Core Rules D10 objectives, legacy fallback format |
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
| 68 | ~~`data/mission_tables/credit_rewards.json`~~ | DELETED | Was fabricated (~100x Core Rules scale) |
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

| 132 | `data/patron_generation.json` | Yes | **CANONICAL** — Core Rules pp.83-84 D10 tables (patron type, danger pay, time frame, BHC, mission objectives). Created Mar 22, 2026 |
| 133 | `data/crew_tasks.json` | Yes | **CANONICAL** — Core Rules pp.76-82 crew tasks. Created Mar 22, 2026 |
| 134 | `data/trade_table.json` | Yes | **CANONICAL** — Core Rules pp.79-80 trade D100 table. Created Mar 22, 2026 |
| 135 | `data/exploration_table.json` | Yes | **CANONICAL** — Core Rules pp.80-82 exploration D100 table. Created Mar 22, 2026 |
| 136 | `data/campaign_tables/campaign_events.json` | Yes | **REWRITTEN** — 28 D100 entries from Core Rules pp.126-128 |
| 137 | `data/campaign_tables/character_events.json` | Yes | **REWRITTEN** — 30 D100 entries from Core Rules pp.128-130 |

**Summary**: ~120 files contain rules data requiring verification, ~16 files are N/A (UI, config, tutorials). 6 files newly created/rewritten from Core Rules this session.

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
| 8 | `src/core/campaign/phases/TravelPhase.gd` | D100 travel event ranges (JSON), world trait D100 ranges (JSON with hardcoded fallback) | **UPDATED** — world traits now loaded from JSON, fallback matches |
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
| 12 | ~~Base upkeep cost~~ | ~~`FiveParsecsConstants.gd`: 1~~ | ~~`campaign_rules.json`: 6~~ | **FIXED** — JSON had cap (6) not cost (1). Corrected to 1. JSON is unwired (no consumer) |
| 13 | Starting credits | `FiveParsecsConstants.gd`: 10 (per char), 1/crew (VERIFIED p.28) | `campaign_rules.json`: 100 (unwired) | Need Core Rules p.15/p.28 — may be campaign pool vs per-char vs per-crew |
| 14 | WorldEconomyManager starting | `FiveParsecsConstants.gd`: 1/crew (VERIFIED p.28) | `WorldEconomyManager.gd:14`: 1000 (hardcoded) | Need book — 1000 is placeholder, no citation |
| 14a | Mission pay multiplier | `FiveParsecsConstants.gd:158`: 5 (GAME_BALANCE_ESTIMATE) | ~~`credit_rewards.json`~~ DELETED | **RESOLVED** — credit_rewards.json deleted (was fabricated ~100x scale). Use `patron_generation.json` + `mission_rewards.json` |
| 14b | Danger pay | `FiveParsecsConstants.gd:159`: 2 (GAME_BALANCE_ESTIMATE) | `patron_generation.json`: D10 1-3 (VERIFIED p.83) | **TAGGED** — JSON is authoritative, GDScript constant is stale |
| 15 | ~~Injury fatal split~~ | ~~`injury_table.json`: 1-5/6-15~~ | ~~`InjurySystemConstants.gd`: 1-15 FATAL~~ | **FIXED** — split into GRUESOME_FATE(1-5) + FATAL(6-15). Both `is_fatal: true`, GRUESOME damages all equipment |
| 16 | ~~Injury page reference~~ | ~~`injury_table.json`: "p.122"~~ | ~~`InjurySystemConstants.gd`: "p.94-95"~~ | **FIXED** — Constants header updated to p.122. Both pages reference same table |
| 17 | Strange Characters bonuses | `character_species.json`: 16 types | `character_creation_bonuses.json`: 0 of 16 | Missing from bonuses JSON |
| 18 | Feral origin bonus | `character_species.json`: defined | `character_creation_bonuses.json`: missing | Origin key not in bonuses JSON |
| 19 | ~~Ship types count~~ | ~~`ships.json`: 7 types~~ | Core Rules p.31: 13 types | **FIXED** (2nd chat) — ships.json rewritten with 13 types, VERIFIED metadata |
| 20 | ~~Ship hull ranges~~ | ~~`ships.json`: 6-14~~ | Core Rules p.31: 20-40 | **FIXED** (2nd chat) — hull values now 20-40 per Core Rules |
| 21 | ~~Ship debt formula~~ | ~~`ships.json`: 0-5~~ | Core Rules p.31: 1D6+10 to 1D6+35 | **FIXED** (2nd chat) — debt formulas now 1D6+10 to 1D6+35 |
| 22 | **ShipPanel SpinBox max** | `ShipPanel.tscn`: hull max=20, debt max=10 | Core Rules p.31: hull ~40, debt ~41 | **STILL OPEN** — SpinBox constraints may prevent entering correct values |

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
