# QA Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->

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
| BUG-033 | P1 | Battle victory flag not passed through post-battle results | OPEN |
| BUG-034 | P2 | Selected VC card description text low contrast on blue bg | CONFIRMED |
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
| BUG-033 | P1 | Battle victory flag not passed through post-battle |
| BUG-034 | P2 | VC card text contrast on blue selected bg |
| WEALTH motivation | Deferred | Needs resource bonus system architecture |
| 49% character bonus coverage | Deferred | Most gaps need resource bonuses |
| Equipment table names | Deferred | User decision: generic vs Core Rules |
| Victory condition metric tracking | Deferred | Feature addition: counters for enemies/credits/worlds |
| UX-091/092 | Medium | Mission Prep "READY" with 0/4 equipped; Assign Equipment grayed |

### MCP Testing Gotchas (updated Phase 31)

- `pressed.emit()` on InitiativeCalculator "Roll Initiative" causes 30s timeout + crash
- Multiple `RandomizeButton` nodes exist (CaptainPanel + CrewPanel) — use scoped find_child
- `click_element` with "EditButton" matches wrong node — use parent-scoped find
- Auto Deploy works via run_script but Confirm Deployment needs separate click
- Battle can only complete via programmatic `_on_battle_completed()` on CampaignTurnController
- `navigate_to("campaign_turn_controller")` recreates the full turn — use `_on_battle_completed()` instead

### Recommended Next QA Focus

1. BUG-033: Battle victory flag through post-battle (P1 — may affect campaign stats)
2. BUG-034: VC card text contrast (P2 — accessibility)
3. Full save/reload validation (confirm BUG-031 fix holds across multiple turns)
4. Equipment flow: creation → save → reload → Mission Prep (confirm BUG-035 fix)
5. UX-091/092: Mission Prep equipment display accuracy
