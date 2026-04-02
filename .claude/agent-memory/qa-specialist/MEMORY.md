# QA Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules PDF and Compendium PDF are the **canonical, final authority** for ALL game mechanics. Every value in this project must match the books exactly. If code disagrees with the book, the code is wrong — file a bug, don't rationalize the discrepancy.

---

## Critical Gotchas — Must Remember

1. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always use `var x: Type = dict["key"]`. Zero exceptions. This is the #1 cause of compile errors in new code.
2. **Three-Enum Sync Rule**: GlobalEnums, GameEnums, FiveParsecsGameEnums must stay aligned. When testing enum-dependent code, verify all three.
3. **`--headless --quit` is NOT comprehensive**: Only validates startup scripts. The Godot editor LSP loads ALL scripts. Always reboot editor after headless check.

---

## PDF Rulebooks & Python Extraction Tools

For RULES_VERIFIED status, extract values directly from source PDFs:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: `py` launcher (NOT `python`), PyPDF2 3.0.1, PyMuPDF 1.27.1 (fitz) installed
- **Example**: `py -c "import fitz; doc = fitz.open('path/to/pdf'); print(doc[PAGE].get_text())"`

Use this to cross-reference game values when promoting mechanics from MCP_VALIDATED to RULES_VERIFIED.

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
