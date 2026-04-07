# Battle Systems Engineer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` are the canonical authority for ALL combat mechanics, weapon stats, and battle rules. If code disagrees with the book, the code is wrong.

---

## Critical Gotchas — Must Remember

1. **BattleResolver is static** (RefCounted) — use `BattleResolver.resolve_battle()`, never instantiate as Node.
2. **TacticalBattleUI shared** between Standard and Bug Hunt — changes must not break either mode.
3. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always use `var x: Type = dict["key"]`. Zero exceptions.

---

## PDF Rulebooks & Python Extraction Tools

Source PDFs for verifying combat rules, weapon stats, and battle mechanics:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: `py` launcher (NOT `python`), PyMuPDF installed. Example: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"`

---

## Session 40b: Legal Stack + Modiphius Ask List (Apr 7, 2026)

No direct battle-domain changes. Context awareness:

- Legal stack shipped (EULA screen, privacy policy, consent management, data export/delete) — 14 new files
- Compendium library system added (10 categories, 340+ items)
- `docs/MODIPHIUS_ASK_LIST.md` created — partnership blockers include art assets (miniature photography for faction tiles, 3D renders for character cards) which will affect battle UI visuals
- Icon SOP: game-icons.net SVGs, white on transparent, `modulate` for color. Path: `assets/icons/{context}/`

---

## Session 40: Difficulty Audit — Battle Domain (Apr 7, 2026)

### Seize Initiative Difficulty Modifier Fix
- `BattleCalculations.check_seize_initiative()` now accepts `difficulty_modifier: int = 0` — Hardcore: -2, Insanity: -3 (Core Rules p.65)
- Modifier flows: BattlePhase injects into `battlefield_data["seize_initiative_modifier"]` → BattleResolver reads it → passes to BattleCalculations
- `SeizeInitiativeSystem.gd` (UI path) already handled this — the fix is for the automated resolution path in BattleResolver

### Difficulty Enum Cleanup
- HARD(3)/NIGHTMARE(5)/ELITE(7) are **DEPRECATED** — not in Core Rules or Compendium. Aliased to NORMAL/INSANITY/INSANITY in JSON
- Fabricated keys removed from JSON: `enemy_strength_multiplier`, `loot_modifier`, `credit_modifier`, `rival_resistance_modifier`
- Only 5 real modes: Easy, Normal, Challenging, Hardcore, Insanity

### Progressive Difficulty (Compendium pp.30-31)
- `ProgressiveDifficultyTracker.gd` already existed with JSON data
- BattlePhase now reads `progress_data["progressive_difficulty_options"]` (array of ProgressionType ints) instead of hardcoding BASIC
- Options combinable per Compendium (loops over array)

---

## Session 39: Crew Size Scaling — Battle Domain (Apr 7, 2026)

### Key Distinction: `get_crew_size()` ≠ `get_campaign_crew_size()`
- `get_crew_size()` = fluctuating roster count (for upkeep, travel)
- `get_campaign_crew_size()` = fixed 4/5/6 setting (for enemy numbers, deployment, reaction dice)

### EnemyGenerator Changes
- **Numbers modifier** now applied: `_parse_numbers_modifier()` converts "+0"/"+2"/"+3" from enemy template → added to base dice count
- **Order of operations** fixed: select enemy type FIRST (D100), THEN roll dice, THEN add Numbers modifier
- **Quest reroll** (Core Rules p.99): during Quest missions, any die scoring 1 rerolled once
- **Raided formula** (Core Rules p.70): NEW `calculate_raided_enemy_count(campaign_crew_size)` method
  - Crew 6: 3D6 pick highest (one step UP from standard 2D6 pick highest)
  - Crew 5: 2D6 pick highest
  - Crew 4: 1D6

### BattlePhase Changes
- Uses `get_campaign_crew_size()` instead of `get_crew_size()` for enemy count
- **Fielding-fewer reduction** (Core Rules p.93): if deploying 2+ fewer than campaign setting, -1 enemy

### FiveParsecsCombatSystem Changes
- Reaction dice now roll D6 matching campaign setting (not living crew count)

### PreBattleUI Changes
- Deployment cap enforced to `campaign_crew_size`
- "Deploying X / Y max" label visible in crew selection

### Tests Added (13 new in test_crew_size_enemy_calc.gd)
- Numbers modifier parsing (5 tests)
- Quest reroll (2 tests — P(1) drops from 16.7% to <2.8%)
- Roster vs setting distinction (2 tests)
- Raided formula (4 tests — crew 6/5/4 + statistical comparison)

---

## Session 35: Red & Black Zone Jobs Battle Integration (Apr 7, 2026)

`BattlePhase.gd:280-411` already read `is_red_zone`/`is_black_zone` flags — now wired from upstream:

- Zone flags injected by `WorldPhaseController._complete_world_phase()` into `progress_data["current_mission"]`
- Red Zone: fixed 7 enemies + 3 specialists + 1 lieutenant, threat condition (D6), time constraint (Round 6 D6), +2 invasion, -1 galactic war
- Black Zone: 4 teams of 4 from Roving Threats, reinforcement every round, Active/Passive system, 5 mission types (D10)
- PostBattle: `PaymentProcessor.process_black_zone_rewards()` handles victory (clear rivals, +2 patrons, 5cr, loan payoff) and failure (1cr/casualty). `ExperienceTrainingProcessor` adds +1 XP all crew on BZ victory. `GalacticWarProcessor` applies RZ -1 modifier
- Journal: battle entries tagged with `red_zone`/`black_zone`, enriched with threat/time/mission details
- Key files: `RedZoneSystem.gd`, `BlackZoneSystem.gd` (RefCounted, static methods, JSON-backed)
- Data: `data/red_zone_jobs.json`, `data/black_zone_jobs.json`

---

## Phase 31 QA Bug Fix Sprint (Mar 16, 2026)

10 bugs + 3 UX issues fixed across 14 files, 0 compile errors. Key battle-domain fixes below.

### Initiative Roll Crash (BUG-043 — FIXED)

`TacticalBattleUI.gd` referenced `result.seized` but `InitiativeResult` uses `result.success`. Changed to `result.success` at the crash site (line ~741).

### Phantom Equipment Modifiers (BUG-042 — FIXED)

Initiative calculator showed phantom equipment bonuses (Motion Tracker, Scanner Bot) for crew with no equipment. Added `_auto_detect_equipment()` in `InitiativeCalculator.gd` that validates equipment references exist on crew members. Wired `set_crew()` call from `TacticalBattleUI.gd` to pass actual crew data.

### Battlefield Theme Mismatch (BUG-038 — FIXED)

Terrain theme data was spread at top level of `full_bf_data` in `CampaignTurnController.gd` but `TacticalBattleUI.gd` read from `terrain` sub-dict. Fixed by merging `terrain_guide` into `terrain` sub-dict in `CampaignTurnController.gd`, and adding fallback read in `TacticalBattleUI.gd`.

### Terrain Feature Count (BUG-040 — FIXED)

Map was generating ~15+ features, exceeding the 13-feature Core Rules cap. Added `is_scatter` flag in `BattlefieldShapeLibrary.gd` and skip scatter features in `BattlefieldMapView.gd` to stay within limits.

### Terrain Size Prefixes (BUG-041 — FIXED)

Terrain labels were missing LARGE/SMALL/LINEAR type prefixes. Added `size_category` property to shapes in `BattlefieldShapeLibrary.gd` and prefix rendering in `BattlefieldMapView.gd` labels.

### Files Modified (Battle Domain)

- `src/ui/screens/battle/TacticalBattleUI.gd` — initiative result property fix, terrain theme fallback, crew wiring
- `src/ui/components/battle/InitiativeCalculator.gd` — `_auto_detect_equipment()`, `set_crew()`
- `src/ui/components/battle/BattlefieldShapeLibrary.gd` — `is_scatter` flag, `size_category` property
- `src/ui/components/battle/BattlefieldMapView.gd` — scatter skip, size prefix labels
- `src/ui/screens/campaign/CampaignTurnController.gd` — terrain_guide merge into terrain sub-dict

## Session 10: CombatResolver Interface Fix (Mar 26, 2026)

CombatResolver.gd defines a 24-method + 10-property interface contract on `CharacterScript` (= `BaseCharacterResource`). Previously, 22 of 24 methods were completely missing — `_validate_character_interface()` in `_ready()` would crash via `assert()`.

**Fix**: All 22 methods added to `src/core/character/Base/Character.gd`:
- Equipment: `get_equipped_weapon()`, `get_combat_skill()`
- Damage: `get_melee_damage()`, `get_ranged_damage()`, `get_armor_value()`, `apply_damage()`, `heal_damage()`
- Actions: `add_action_points()`, `reduce_action_points()`, `can_perform_action()`, `get_speed()`
- Abilities: `get_active_ability()`, `get_ability_cooldown()`, `is_ability_on_cooldown()`
- Status: `is_mechanical()`, `is_suppressed()`, `is_pinned()`, `has_overwatch()`, `add_combat_modifier()`
- Reactions: `can_counter_attack()`, `can_dodge()`, `can_suppress()`
- Lifecycle: `reset_battle_state()`

13 combat properties also added (transient state + aliases: `name`→`character_name`, `bot`→`is_bot`, `soulless`→`is_soulless`).

TacticalBattleUI now hosts Battle Simulator flow too. Three modes: Standard 5PFH, Bug Hunt, Battle Simulator. All runtime-verified via MCP with zero errors.

## Session 11-12: Hardcoded Data Cleanup (Mar 26, 2026)

### BattlePhase.gd Fabricated Payment Removed (CRITICAL)
Both tactical and auto-resolve paths had `base_payment=100 + difficulty*25 + success_bonus=50` — fabricated formula generating 150-200 credits per battle. `battle_setup_data` is rebuilt at line 323 without `base_payment`, so fallback always triggered. Fixed: `combat_results["payment"]` and `["credits_earned"]` now set to 0. Real payment handled by `PostBattlePaymentProcessor.process_payment()` (1D6 credits, Core Rules p.120).

### BattleEventsSystem.gd Wired to JSON
Added `_load_events_from_json()` loading 24 battle events from `data/event_tables.json["battle_events"]["entries"]`. Falls back to `_initialize_event_registry()` if JSON fails. Follows TravelPhase.gd pattern.

### BattleCalculations.gd Constants — Verified Correct
Hit thresholds (3+/5+/6+), range bands, armor/screen saves all properly annotated with Core Rules page citations. Appropriate as code constants — no JSON externalization needed. XP constants now derived from `data/injury_results.json` via static var getters (additive decomposition: PARTICIPATION + VICTORY_BONUS = survived_won_battle).

### STUN_THRESHOLD Removed (Previous Session)
`STUN_THRESHOLD := 8` was fabricated damage-based stun. Removed from both BattleCalculations.gd and CombatResolver.gd. Stun is now trait-based only per Core Rules p.40/51.

## Session 13: Injury/XP/Unique Individual JSON Wiring (Mar 26, 2026)

### injury_results.json — Verified & Wired (Core Rules p.122-123)

Both human (9 entries) and bot (6 entries) injury tables verified against Core Rules p.122 — exact match. XP awards verified against p.123 (7 conditions). Two missing XP entries added: `easy_mode_bonus` and `quest_completion`. Page citation corrected from p.119 to p.122/123.

**Wired to 3 consumers:**

- `PostBattleProcessor.gd` — XP awards via static lazy loader + both injury table methods now data-driven from JSON (replaced ~75-line if/elif chains with `_match_injury_entry()` + `_resolve_dice_expression()`)
- `ExperienceTrainingProcessor.gd` — `_calculate_crew_xp()` loads XP values from JSON
- `BattleCalculations.gd` — XP constants derived from JSON via static var getters

### unique_individual.json — Verified & Wired (Core Rules pp.64-65, 93-94)

Removed fabricated `unique_individual_definition` (flat +1 bonuses don't exist). Added missing Interested Parties +1 modifier (Core Rules p.93), Invasion/Roving Threats exclusion rules.

**Wired to BattlePhase.gd:**

- `_determine_unique_individual()` loads threshold (9), double threshold (11), Interested Parties modifier from JSON
- Added missing Interested Parties +1 check via `battle_setup_data.get("enemy_category", "")`

### Dual injury JSON files

- `data/injury_table.json` — older file, referenced by DataManager/GameDataManager
- `data/injury_results.json` — newer file with XP awards + processing rules, now canonical source for PostBattleProcessor/ExperienceTrainingProcessor/BattleCalculations
- Both contain identical injury table data; `injury_table.json` also has XP table in different format

---

## Mar 20-21 Runtime Verification

### TacticalBattleUI Type Inference Fix

Godot 4.6 type inference error in TacticalBattleUI.gd — `var panel := _get_res("tier_selection").new()` failed because `_get_res()` returns Variant. Fixed at 2 sites by changing to `var panel: Control = _get_res("tier_selection").new()`.

### Battle Map / Auto-Resolve — Verified Through 3 Battle Cycles

5-turn campaign playthrough (turns 3-5) included 3 battle cycles. All passed:

- Battle map terrain rendering correct
- Auto-resolve produces valid results with proper victory/defeat tracking
- Post-battle results correctly propagated (BUG-033 confirmed fixed — reads from `self.battle_results`)
- Counters after 5 turns: battles_won=4, battles_lost=1

---

## Battle UI QA Sprint (Mar 15, 2026)

18 bugs found, 11 fixed, 7 won't fix (standalone-mode-only, not applicable to normal campaign flow).

### Key Architecture Changes

- `TacticalBattleUI.gd` now has `@onready var bottom_bar: PanelContainer = $MainContainer/BottomBar`
- `_apply_stage_visibility()` controls: bottom_bar, phase_breadcrumb, battle_round_hud, action_buttons per stage
  - TIER_SELECT: hides bottom_bar + breadcrumb
  - RESOLUTION: hides battle_round_hud + action_buttons + breadcrumb, sets "Battle Complete" text
  - COMBAT: sets "Round 1 - Combat" fallback text when no round_tracker
- `BattlefieldShapeLibrary.get_rotation_range()` — static method for per-shape rotation angles
- `BattlefieldMapView` — terrain rotation, objective marker (gold diamond + "OBJ"), measurement callouts
- `BattlefieldGridPanel` — terrain legend with colored swatches
- `BattlefieldGenerator` — cross-sector spanning terrain (0-2 features), density boost (0.6->0.75 + 30% cluster chance)
- `compendium_terrain.json` — `regular_feature_per_sector_chance`: 0.6 -> 0.75
- Quick dice log shows individual dice breakdown for multi-die rolls

### Won't Fix Items (standalone-mode-only)

B01 (tier overlay not shown without `initialize_battle()`), B03 (overlay dimming), B06 (setup tab empty), B15 (no result summary), B17 (no crew cards), B18 (no phase buttons) — all require `initialize_battle()` which is always called in normal campaign flow.

### Bug Report

Full details: `docs/BATTLE_UI_QA_BUGS.md`

## Phase 29 Runtime Test (Mar 16, 2026)

Full 2-turn demo path tested via MCP. Battle UI works correctly in campaign flow:

- **PreBattleUI**: All crew pre-selected (BUG-021 fix confirmed), mission info + terrain guide displayed
- **Tier Selector**: 3-tier companion level (Log Only / Assisted / Full Oracle) renders and selects correctly
- **Battlefield Map**: Graph-paper terrain with Wilderness/Urban Settlement themes, coordinate labels, terrain shapes
- **Auto-Resolve**: `_on_auto_resolve_battle()` works — transitions to Post-Battle cleanly
- **Post-Battle 14 Steps**: All advance without crashes (ROLL-FIX verified for steps 12-14)

### Issues Found (All Fixed in Phase 31)

- **Initiative crash** (BUG-043) — `result.seized` → `result.success`
- **Phantom equipment modifiers** (BUG-042) — auto-detect validates actual equipment
- **Theme mismatch** (BUG-038) — terrain sub-dict merge
- **Feature count exceeded** (BUG-040) — scatter flag filtering
- **Missing size prefixes** (BUG-041) — size_category property
