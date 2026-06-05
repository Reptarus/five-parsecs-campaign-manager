# QA Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules PDF and Compendium PDF are the **canonical, final authority** for ALL game mechanics. Every value in this project must match the books exactly. If code disagrees with the book, the code is wrong — file a bug, don't rationalize the discrepancy.

---

## Critical Gotchas — Must Remember

1. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always use `var x: Type = dict["key"]`. Zero exceptions. This is the #1 cause of compile errors in new code.
2. **Three-Enum Sync Rule**: GlobalEnums, GameEnums, FiveParsecsGameEnums must stay aligned. When testing enum-dependent code, verify all three.
3. **`--headless --quit` is NOT comprehensive**: Only validates startup scripts. The Godot editor LSP loads ALL scripts. Always reboot editor after headless check.
4. **GDScript does NOT hot-reload in a running Godot instance**: after editing a `.gd`, you MUST `stop_project` + `run_project` (or reboot the editor) before re-probing via MCP `run_script` — otherwise you verify against stale launch-time bytecode. Symptom: empirical probe reports values inconsistent with the on-disk source.
5. **MCP `run_project`/`run_script` run in DEBUG mode (break-on-error) — and this cuts BOTH ways**: a "debugger break" is NOT automatically a real crash, and also NOT automatically dismissible noise. Decide the error CLASS first. **Class (a) Dictionary missing-key access**: Godot returns null + logs `SCRIPT ERROR` and continues *within the same function* — often harmless log-spam (the InjurySystemService:63 case below; don't OVER-claim a crash). **Class (b) nonexistent method/property or type-method mismatch** (e.g. `.to_lower()` on a float, `has_active_quest()` on a node lacking it): Godot ABORTS the current function (unwinds it) then continues the process — so the app doesn't close, but if that function was doing essential work the feature SILENTLY does nothing. That is a REAL bug; do NOT under-claim it as "debug-only." The shipped game / gdUnit don't *halt* on either class, but class (b) still breaks the feature. (Jun 3: 4 class-(b) bugs found this way — see crash-sweep section below.)
6. **Green unit tests ≠ exercised runtime path**: `test_injury_determination` 13/13 passed both BEFORE and AFTER fixing a real crash-spam bug in the very function it tests — because the test data path didn't trip the offending line. Empirical d100 sweeps / MCP runtime exercises catch what unit tests miss. The MCP runtime is the real gate (per CLAUDE.md).

---

## Campaign-flow crash sweep (Jun 3, 2026) — walk the happy path on a LEGACY save under MCP

Verifying the post-consolidation cleanup branch, I walked create → turn → battle → post-battle under MCP `run_project` (debug mode hard-halts each error). This surfaced **4 pre-existing latent crashes** that `--headless` AND green unit tests both passed through — all class-(b) "function aborts, process survives, feature silently broken" bugs (see gotcha #5). None were from the cleanup; all blocked the campaign happy-path. Fixed + runtime-verified, committed `524c0f74`:

1. `StarsOfTheStoryPanel.gd:66` — `.connect()` to `star_ability_recharged`, a signal DELETED in `70cf5b6c` (May 19). Dangling connect crashed EVERY non-Insanity creation (FinalPanel elite-bonuses card). Fix: delete the dead connect + handler (root fix, not a `has_signal` band-aid).
2. `CrewTaskComponent.gd:262` — `.to_lower()` on legacy-float crew `origin`. Fix: `str()`-wrap.
3. `RivalPatronResolver.gd:98` — unguarded `ctx.game_state.has_active_quest()`; GameState has no quest API (dangling since `f4346c39`). Post-battle Step 3 crashed. Fix: `has_method` guard (matches siblings lines 103/105) → safe no-op.
4. `CampaignEventEffects.gd:91` — `member.origin.to_lower()` on legacy-float origin (same class as #2; was the last unguarded origin read in post-battle). Fix: `str()`-wrap.

**Method**: walk the FULL happy path on a *legacy* save (NOT a fresh campaign — fresh saves store `origin` as String and never trip #2/#4) under `run_project`; root-cause each break with `git show` on the introducing commit rather than attributing/dismissing it; re-walk to confirm the next step proceeds. #2/#4 are the legacy-float-`origin` data-model trap — root fix is a load-time `origin` normalization migration (band-aided for now). Full writeup: `project_session_jun03_wave3_crashfixes` (user memory).

---

## Cross-Mode Character Transfer Framework — Test Surface (SHIPPED — all 4 modes)

Canonical-hub design in `src/core/character/CharacterTransferService.gd` (RefCounted): every mode exports-to / imports-from the full 5PFH Character dict; any-to-any = compose two legs. File-drop at `user://transfers/<id>.json` (v2 envelope), NOT a barracks. 24/24 gdUnit4 transfer tests currently green — KEEP GREEN.

- **Test files**: `tests/unit/test_character_transfer_hub.gd`, `tests/unit/test_planetfall_transfer.gd`, `tests/unit/test_tactics_transfer.gd` (9 Tactics tests).
- **Round-trip invariant to verify**: import a char into Bug Hunt/Planetfall, then muster out to 5PFH → the restored character must equal the original VERBATIM (the embedded `snapshot` envelope key drives this; `export_to_canonical` short-circuits on it). Stat re-derivation on the way out = bug.
- **Reward-suppression invariant**: 5PFH-only exit rewards (Bug Hunt mustering credits / +1 Story Point / +Sector Government patron; Planetfall ending bonuses) attach ONLY when `target_mode == "five_parsecs"`. Verify NO rewards leak when target is another mode.
- **Double-import guard**: `apply_transfer_rewards()` deletes the `user://transfers/` file after applying — verify a transfer cannot be picked up twice.
- **Pickup wiring**: each dashboard (CampaignDashboard/BugHuntDashboard/PlanetfallDashboard) calls `_check_pending_transfers.call_deferred()` in `_setup_screen`; `GameState.load_campaign()` emits `pending_character_transfers(count)` on 5PFH load. New 5PFH mutator `FiveParsecsCampaignCore.add_crew_member()` forces `is_captain=false` + rebuilds `_crew_id_index` — verify added crew never overwrite the captain.
- **Data-integrity regression (Planetfall pp.165-166)**: `convert_from_planetfall` ending matrix was corrected — independence_won uses ship_debt_prepaid (2D6 PARTIAL prepayment), NOT a full debt wipe (the old bug). Verify against `docs/rules/planetfall_source.txt` L12088-12113.
- **Tactics transfer SHIPPED (Jun 4)** — `tests/unit/test_tactics_transfer.gd` (9 tests) pins it; assert it works. A transferred char becomes a NAMED VETERAN in `TacticsCampaignCore.veteran_characters[]` (new serialized array, NEVER `campaign_units[]` — veterans stay out of points validation, p.184). Invariants to keep green: `convert_to_tactics` is book-faithful (the invented `military_backgrounds` GAME_BALANCE_ESTIMATE list is GONE — now a "military"/"war-torn" substring check per Tactics p.184 "+2 with a military-type background", no enumerated list; weapons carry over; KP floor moved to the tagged veteran-playability layer, not the conversion); `add_veteran_character()` applies a >=1 Kill Point playability floor; round-trip via embedded `snapshot` restores verbatim. Pickup dispatch wired in `CampaignScreenBase._add_character_to_mode()` "tactics" case → `add_veteran_character()`.

---

## PDF Rulebooks & Python Extraction Tools

For RULES_VERIFIED status, extract values directly from source PDFs:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python (PyPDF2 ONLY)**: `py` launcher (NOT `python`). PyPDF2 3.0.1 is the only PDF tool — do NOT use PyMuPDF/fitz.
- **Example**: `py -c "from PyPDF2 import PdfReader; r = PdfReader('path/to/pdf'); print(r.pages[PAGE].extract_text())"`

Use this to cross-reference game values when promoting mechanics from MCP_VALIDATED to RULES_VERIFIED.

---

## Battle UI Redesign — Post-Battle Consistency Sweep (May 17–19, 2026)

Triggered by the user's request: "make sure post battle phase and the data
roll over into the next turn are still consistent" after the Phase 2 crew
injury-routing change. The static trace alone (gdUnit 50/51 + scoped
post_battle_subsystems 10/10 + injury_determination 13/13) said
"consistent" — but empirical exercise of the live path surfaced a real
defect the unit tests had been silently passing through.

### Found & fixed (PRE-EXISTING, surfaced by the sweep)

`src/core/services/InjurySystemService.gd:63` (untouched since 2026-04-02,
NOT a Phase 2 regression): `result.description = range_data.description`
but `INJURY_ROLL_RANGES` entries are `{min, max}` only (no `description`
key). Every post-battle injury roll logged a `SCRIPT ERROR` and returned
a blank description. NOT a hard player-facing crash — Godot continues
past Dictionary missing-key access; `is_fatal`/`recovery_turns` stayed
correct; the debugger-break first seen via MCP was a `run_script` debug-
mode artifact. Fixed → `InjurySystemConstants.get_injury_description(injury_type)`
(canonical `INJURY_DESCRIPTIONS`, mirrors adjacent `type_name` lookup,
no fabricated data). Surfaced BECAUSE the rules-faithful crew routing
(`_resolve_battle()`) now sends 100% of downed crew through this path.

### Consistency verdict

`_resolve_battle()` only relabels the display bucket (all downed crew →
"Roll Injury"); persist/recovery/rollover mechanism unchanged.
`determine_injury()` is roll-only (one table, no `is_casualty` branch),
empirical d100 sweep: **15/100 fatal** (e.g. roll 1 = GRUESOME_FATE),
**50/100 recovery** (feeds `_process_sick_bay_recovery` turn decrement),
**35/100 no-effect**. Bitter Day (Core Rules p.67) reads the PROCESSED
`battle_result["casualties"]` by `type`, not the pre-roll count — still
fires on an injury-roll fatality. No downstream consumer requires
`crew_casualties > 0`.

### Regression suite (run after both fixes)

`test_slide_over_drawer` 10/10, `test_activation_tracker` 12/12,
`test_battle_objective_tracker` 14/14, `test_post_battle_success_cascade`
4/4, `test_battle_tier_controller` 13/13, `test_injury_determination`
13/13, `test_injury_recovery` 15/15, `test_post_battle_subsystems` 10/10.
**One pre-existing fail tracked separately**:
`test_battle_round_tracker::test_battle_event_triggers_on_round_2`
encodes a stale expectation (bare `advance_phase()×5` to auto-emit);
the tracker's documented contract (line ~186) requires the UI to call
`check_battle_event()` post-overlay to avoid modal double-fire. Out of
scope (file unchanged by this plan).

### Lessons recorded as Critical Gotchas above (#4-6)

(1) GDScript hot-reload trap; (2) MCP `run_script` debug-mode break ≠
player-facing crash; (3) green unit tests ≠ exercised runtime path.

---

## Session 40b: Legal Stack + Compendium Library (Apr 7, 2026)

### New Test Points for Future QA

- **EULA first-launch**: Delete `user://legal_consent.cfg` → verify EULA screen blocks app access until ACCEPT
- **EULA re-trigger**: Change `EULA_VERSION` or `PRIVACY_VERSION` in LegalConsentManager → verify re-prompts on next launch
- **Data export**: Settings → Export My Data → verify `user://data_export.json` contains all save files
- **Data deletion**: Settings → Delete All Data → verify all `user://` files wiped, EULA re-triggers
- **Analytics toggle**: Default OFF (GDPR opt-in) → toggle ON → verify persisted → toggle OFF → verify persisted
- **Legal document rendering**: Each document (EULA, Privacy, Licenses, Credits) renders BBCode correctly in LegalTextViewer
- **Compendium library**: 10 categories load, 340+ items browsable, no crashes on empty categories
- **Icon rendering**: game-icons.net SVGs load as white on transparent, modulate colors applied correctly

### New Files to Test

- `src/ui/screens/legal/EULAScreen.gd` + `.tscn` — first-launch blocking
- `src/core/legal/LegalConsentManager.gd` — consent persistence + data export/delete
- `src/ui/screens/legal/LegalTextViewer.gd` — Markdown-to-BBCode rendering
- `data/legal/*.md` — document content integrity

---

## Session 39: Crew Size Scaling Tests Added (Apr 7, 2026)

`tests/unit/test_crew_size_enemy_calc.gd` expanded from 17 → 30 test cases:

### New Tests (13 added)
- **Numbers modifier parsing** (5 tests): `_parse_numbers_modifier()` for "+0", "+2", "+3", plain int, no-plus string
- **Quest mission reroll** (2 tests): Statistical verification P(1) < 8% with reroll, valid range check
- **Campaign setting vs roster** (2 tests): Crew size 6 with large roster stays in 1-6 range; statistical distribution proves crew 4 averages lower than crew 6
- **Raided Starship formula** (4 tests): `calculate_raided_enemy_count()` for crew 6/5/4 range checks + statistical comparison (3D6-pick-high averages higher than standard 2D6-pick-high)

### New Test Points for Future QA
- **campaign_crew_size persistence**: Create campaign with crew size 5, save, reload → verify setting survives
- **Stealth sentries**: Create stealth mission with crew size 4 → verify 5 sentries (setting + 1)
- **Salvage tension**: Create salvage job with crew size 5 → verify initial tension = 3 (ceil(5/2))
- **Fielding fewer**: Deploy 4 crew in crew-size-6 campaign → verify -1 enemy (BattlePhase.gd)
- **Raided event**: Trigger Raided travel event → verify uses 3D6/2D6/1D6 formula (not standard)

---

## Session 18: QA Rules Audit 100% Complete (Mar 30, 2026)

QA_RULES_ACCURACY_AUDIT.md now has **0 UNVERIFIED entries** (was 308). All 376+ entries VERIFIED/FIXED/N/A with PDF page citations. 925/925 data values confirmed.

Fixes applied this session:
- Rival following: `≤3` → `≥5` (Core Rules p.72)
- License costs: single-roll fabricated → two-roll per book (Core Rules p.72)
- 3 generator data duplications resolved (Stealth/Street/Salvage → Compendium schema)
- EquipmentPanel credits warning threshold: 500 → 1

Remaining flagged items are GAME_BALANCE_ESTIMATE (app-original mechanics not from book): ship_components.json stats, world trait upkeep modifier, D6 advancement roll, damaged ship multiplier.

---

## Phase 30 Core Rules Parity (Mar 16, 2026) — CRITICAL FOR TESTING

**Difficulty enum mismatch was found and fixed.** Before Phase 30, ALL difficulty modifiers were dead code because ExpandedConfigPanel stored IDs 1-5 while DifficultyModifiers.gd compared against GlobalEnums values (CHALLENGING=4, HARDCORE=6, INSANITY=8).

### New Test Points for Future QA

1. **Difficulty modifiers**: Create campaigns at EACH difficulty (Story, Standard, Challenging, Hardcore, Nightmare). Verify:
   - Easy: +1 XP, +1 credit, enemies reduced at 5+, only basic VCs available
   - Challenging: enemy dice 1-2 rerolled
   - Hardcore: +1 enemy, +2 invasion, -2 initiative, -1 story point
   - Insanity: 0 story points (CANNOT earn), forced Unique Individual, +1 specialist, no Stars of Story
2. **Elite Ranks**: Complete a campaign with victory condition → verify `user://player_profile.json` increments. Start new campaign → verify bonus SP/XP applied.
3. **Red Zone**: Campaign with 10+ turns → purchase license (15cr, 7+ crew) → verify fixed 7 enemies, threat condition, time constraint, enhanced rewards.
4. **Black Zone**: 10+ Red Zone turns → verify 4×4 team opposition, mission type roll, massive rewards.
5. **Shipless state**: If `has_ship=false`, verify commercial passage cost, stash limit, ship purchase flow.
6. **Story Track**: 7 events now match Core Rules Appendix V (Foiled, On the Trail, Disrupting the Plan, Enemy Strikes Back, Kidnap, We're Coming, Time to Settle This). Clock starts at 5 ticks.
7. **difficulty field is now INT** (not string): Stored values are GlobalEnums.DifficultyLevel enum values (1,2,4,6,8). Old saves with values 1-5 will map incorrectly — watch for regressions on save/load.

### New Files to Test
- `src/core/mission/RedZoneSystem.gd` — license checks, threat/time rolls, rewards
- `src/core/mission/BlackZoneSystem.gd` — access checks, mission types, opposition, rewards
- `src/core/ship/ShiplessSystem.gd` — destruction, passage, acquisition, debt
- `data/red_zone_jobs.json`, `data/black_zone_jobs.json` — data integrity

## Session 11-12: Hardcoded Data Cleanup Verified (Mar 26, 2026)

Comprehensive audit of hardcoded game data completed. Key fixes verified:

- **KeywordDB**: Now loads 89 keywords from `data/keywords.json` (was 10 hardcoded wrong ones). 14 weapon trait definitions corrected to Core Rules p.51.
- **BattlePhase.gd**: Fabricated payment formula removed (was 100+difficulty*25+50). PostBattlePaymentProcessor correctly does 1D6 per Core Rules p.120.
- **BattleEventsSystem.gd**: Now loads 24 battle events from `data/event_tables.json` (was fully hardcoded, JSON ignored).
- **Verified already correct**: PatronJobGenerator (cascades through 2 JSON files), CharacterCreator (loads from character_creation_bonuses.json), BattleCalculations constants (properly annotated).
- **Cut (cosmetic)**: CharacterNameGenerator — no gameplay impact, cosmetic only.
- **Previous session fixes also verified**: Starting credits (18 files), stun mechanic (trait-based), XP multipliers removed, Dazzle Grenade Heavy trait, ship hull values, Krag/Skulker species wiring.

---

## Phase 31 QA Bug Fix Sprint COMPLETE (Mar 16, 2026)

6 sprints, 14 files modified, 10 bugs + 3 High UX fixed, 0 compile errors.

### Bug Tracker (Updated Post-Fix)

| Bug | Sev | Description | Status |
|-----|-----|-------------|--------|
| BUG-031 | **P1** | Save/reload loses progress — dual-sync pattern fix | **FIXED** |
| BUG-036 | **P0** | Edit Captain crash — typed `current_captain: Character` | **FIXED** |
| BUG-037 | **P0** | Crew creation crash — nil stat bonus from WEALTH motivation | **FIXED (Phase 31 QA)** |
| BUG-043 | **P0** | Initiative roll crash — `result.seized` → `result.success` | **FIXED** |
| BUG-035 | **P1** | Equipment not carried to Mission Prep | **FIXED** |
| BUG-039 | **P1** | Trading credits not persisted between turns | **FIXED** |
| BUG-042 | **P2** | Phantom equipment modifiers in initiative | **FIXED** |
| BUG-038 | **P2** | Battlefield theme always "Wilderness" | **FIXED** |
| BUG-040 | **P2** | Terrain feature count exceeds 13-feature cap | **FIXED** |
| BUG-041 | **P3** | Missing LARGE/SMALL/LINEAR type prefixes | **FIXED** |
| BUG-033 | P1 | Victory counter not persisted — read from wrong results dict | **VERIFIED FIXED (already in code, confirmed at runtime Mar 20)** |
| BUG-034 | P2 | Selected VC card description text low contrast on blue bg | **FIXED (Mar 20)** |
| BUG-029 | P2 | Victory cards not interactive | **VERIFIED FIXED (Phase 30)** |
| BUG-030 | P2 | Default Origin "None" on manual creation | **FIXED (Phase 30)** |

### UX Issues Fixed (Phase 31)

| Issue | Fix | File |
|-------|-----|------|
| UX-060/070 (High) | Unstyled nav buttons → `_style_navigation_buttons()` Deep Space theme | CampaignCreationUI.gd |
| UX-074 (High) | Crew not visible in Final Review → Dictionary member handling | FinalPanel.gd |

### Key Architectural Findings (Phase 31)

1. **GameStateManager dual-sync (BUG-031 systemic root cause)**: Only `set_credits()` synced to `progress_data`. Three other setters (`set_supplies`, `set_reputation`, `set_story_progress`) were missing the sync. Also `_on_campaign_loaded()` bypassed setters, and `add_story_points()` bypassed `set_story_progress()`.

2. **Equipment restoration unreachable (BUG-035)**: Existed in `@tool`-marked `GameSystemManager` but active load path in `GameState.load_campaign()` had none.

3. **Trading credits one-way sync (BUG-039)**: Sell path never called `GameStateManager.add_credits()` while purchase refund path did.

4. **Terrain data split (BUG-038)**: Theme data at top level of `full_bf_data` vs `TacticalBattleUI` reading `terrain` sub-dict.

### Verified Working (Cumulative Phase 28-31)

- Campaign name propagation E2E
- Victory condition selection + propagation (BUG-029 fix)
- Ship hull 6-14, debt 0-5
- Upkeep auto-calculation
- Crew task assignment + resolution
- Job offer dedup
- Post-battle 14-step sequence
- Character events D100
- Trading buy/sell mechanics (within session)
- **Save/reload preserves credits, supplies, reputation, story progress** (BUG-031 fix)
- **Edit Captain doesn't crash** (BUG-036 fix)
- **Initiative roll completes** (BUG-043 fix)
- **Equipment carried to Mission Prep** (BUG-035 fix)
- **Trading credits persist across turns** (BUG-039 fix)
- **Terrain feature count within Core Rules cap** (BUG-040 fix)
- **Battlefield theme matches mission** (BUG-038 fix)
- **Navigation buttons styled** (UX-060/070 fix)
- **Crew visible in Final Review** (UX-074 fix)

### Remaining Open Items

| Item | Sev | Notes |
|------|-----|-------|
| WEALTH motivation | Open — blocked: needs resource bonus system architecture | P2 |
| 49% character bonus coverage | Open — blocked: most gaps need resource bonuses | P2 |
| Equipment table names | Cut — resolved: all weapons rewritten from Core Rules p.50 | N/A |
| Victory condition metric tracking | Open — needs counters for enemies/credits/worlds | P3 |

### MCP Testing Gotchas (updated Phase 31)

- `pressed.emit()` on InitiativeCalculator "Roll Initiative" causes 30s timeout + crash
- Multiple `RandomizeButton` nodes exist (CaptainPanel + CrewPanel) — use scoped find_child
- `click_element` with "EditButton" matches wrong node — use parent-scoped find
- Auto Deploy works via run_script but Confirm Deployment needs separate click
- Battle can only complete via programmatic `_on_battle_completed()` on CampaignTurnController
- `navigate_to("campaign_turn_controller")` recreates the full turn — use `_on_battle_completed()` instead

### Recommended Next QA Focus

1. Difficulty modifier matrix — test EASY, CHALLENGING, HARDCORE, INSANITY across full turn
2. Elite Ranks end-to-end — complete campaign, verify profile.json, verify bonuses on new campaign
3. Ship System coverage — 5/11 mechanics NOT_TESTED
4. Compendium DLC — 20/35 NOT_TESTED, especially world systems and psionics
5. RULES_VERIFIED pass — cross-reference MCP_VALIDATED mechanics against Core Rules text

---

## Mar 20-21 QA Sprint Results

### Bugs Fixed This Session (4 total)

- **BUG-033** (P1): Victory counter — already fixed in code (`self.battle_results` in CampaignTurnController:705), confirmed at runtime
- **BUG-034** (P2): VC card text contrast — swap to COLOR_TEXT_PRIMARY when selected (ExpandedConfigPanel.gd)
- **UX-091**: Mission Prep "READY" with 0 equipped — added `equipped_crew == 0` guard (MissionPrepComponent.gd)
- **UX-092**: Assign Equipment grayed out — preserve crew selection across rebuilds, auto-select first (AssignEquipmentComponent.gd)

### Phase 33 Runtime Fixes (3 issues found during MCP testing)

- **UpkeepPhaseComponent.gd**: Duplicate `_help_dialog` var/method collided with WorldPhaseComponent base class — removed
- **CrewTaskComponent.gd**: Same `_help_dialog` duplicate removal
- **TacticalBattleUI.gd**: Godot 4.6 type inference — `var panel := _get_res(...).new()` changed to `var panel: Control = ...` (2 sites)
- **WorldPhaseComponent.gd**: Added `TOUCH_TARGET_MIN := 48` constant for child component inheritance

### 5-Turn Campaign Playthrough (PASS)

- Turns 3-5 completed on "Iron Wolves" campaign via MCP
- Counters consistent: turns=5, missions=5, battles_won=4, battles_lost=1, credits=1,575
- Zero crashes, zero errors (only expected warnings)
- Event bus auto-cleanup verified: clean subscribe/unsubscribe cycles each turn
- PostBattlePhase: 19/19 signals verified, 100% emission isolation
- WorldPhaseComponent: 9/9 components extend correctly
- Equipment save/reload: 9-stage chain verified E2E
- Difficulty modifiers: 18/18 Core Rules, 40+ methods, 11 call sites, 100% compliance

### Current Status: 0 confirmed bugs, 0 UX issues, 3 open items (2 blocked, 1 feature)

---

## QA Documentation Suite (Mar 20, 2026)

4 new QA documents created — use these as the master reference for all testing work:

| Document | Location | Purpose |
|----------|----------|---------|
| **QA Status Dashboard** | `docs/QA_STATUS_DASHBOARD.md` | Consolidated health view — open bugs, coverage %, risk areas, cross-reference index |
| **Core Rules Test Plan** | `docs/QA_CORE_RULES_TEST_PLAN.md` | All 170 mechanics mapped to test verification status (NOT_TESTED→RULES_VERIFIED) |
| **Integration Scenarios** | `docs/QA_INTEGRATION_SCENARIOS.md` | 9 E2E workflow scripts (219 checkpoints) + MCP command templates |
| **UX/UI Test Plan** | `docs/QA_UX_UI_TEST_PLAN.md` | Systematic theme/responsive/animation/accessibility coverage (623 test cases) |

### Coverage Snapshot (Mar 20, 2026)
- **47 mechanics NOT_TESTED** — Ship(5), Equipment(5), Compendium(20), Travel edge cases
- **35 UNIT_TESTED** — Loot(10), Character(8), Battle calcs, Difficulty modifiers
- **25 INTEGRATION_TESTED** — Campaign phases, save/load, equipment pipeline
- **63 MCP_VALIDATED** — Campaign creation, turn flow, post-battle, trading
- **0 RULES_VERIFIED** — No mechanic has been cross-referenced against Core Rules text yet

### Critical Untested Areas
1. **Elite Ranks (PlayerProfile.gd)** — 4 bonus formulas, 0 tests
2. **6/8 difficulty battle modifiers** — only XP bonus and story points tested
3. **Compendium DLC (20/35 NOT_TESTED)** — mostly world systems, psionics, misc
4. **Ship System (5/11 NOT_TESTED)** — data resource, fuel, components

### When to Use Each Doc
- **"What should I test next?"** → Dashboard §Next Priority Items
- **"Is mechanic X tested?"** → Core Rules Test Plan, search by mechanic name
- **"Run a full workflow test"** → Integration Scenarios, pick scenario by priority
- **"Check UI compliance"** → UX/UI Test Plan §2 (theme) or §3 (responsive)
- **"Update after a fix sprint"** → Dashboard (update counts) + Core Rules Plan (update status per mechanic)
