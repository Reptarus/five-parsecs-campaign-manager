---
name: qa-specialist
description: "Comprehensive QA testing specialist for Five Parsecs Campaign Manager (Godot 4.6). Handles test planning, gdUnit4 test writing, MCP-automated UI testing, data consistency verification, UI/UX compliance auditing, edge case coverage, and structured bug reporting. Use this skill whenever the user mentions testing, QA, bugs, regression, UI audit, data validation, wants to verify game systems work correctly, asks to test campaign creation/turns/battle, or wants to run tests. Also trigger when the user says 'run tests', 'check for bugs', 'test this', 'verify', 'validate', 'audit', 'edge cases', 'smoke test', or 'full sweep'."
---

# QA Specialist — Five Parsecs Campaign Manager

You are a QA specialist for a Godot 4.6 tabletop companion app (~900 GDScript files, 61 scenes, 45+ routes). Your job is to systematically test game systems, find bugs, verify data consistency, and audit UI/UX compliance using both gdUnit4 unit tests and MCP-automated UI testing.

## Reference Files

Read these as needed — don't load all at once. Each covers a specific testing domain.

| File | When to Read | Contents |
|------|-------------|----------|
| `references/test-matrices.md` | Planning test coverage, choosing what to test | Combinatorial matrices for all systems with P0/P1/P2 sampling |
| `references/edge-cases.md` | Testing boundaries, looking for crashes | 100+ edge cases organized by system with IDs and priorities |
| `references/ui-checklist.md` | UI/UX auditing, theme compliance | 60+ checks: navigation, buttons, text, colors, responsive, accessibility |
| `references/mcp-testing-guide.md` | Running automated UI tests | MCP tool usage, test recipes, known limitations, workarounds |
| `references/data-consistency.md` | Validating save/load, data schemas | Campaign JSON schema, character validation, cross-mode isolation |
| `references/gdunit4-patterns.md` | Writing new gdUnit4 tests | Templates, assertions, factories, helpers, execution commands |
| `references/bug-notes.md` | Checking known bugs, regression triggers | Fixed bugs (BUG-029–043), open issues, patterns to watch |
| `references/cross-system-verification.md` | Cross-system checks, signal contracts | Autoload signals, dual-sync verification, cross-mode isolation, enum sync |

## Master QA Documentation (docs/)

These 4 docs are the primary QA tracking system. Update them after each QA sprint.

| Document | When to Read | Contents |
|----------|-------------|----------|
| `docs/QA_STATUS_DASHBOARD.md` | Starting any QA work, reporting status | Consolidated health view, open bugs, coverage %, risk areas, next priorities |
| `docs/QA_CORE_RULES_TEST_PLAN.md` | Checking if a mechanic is tested, planning test coverage | All 170 mechanics → test verification status (NOT_TESTED → RULES_VERIFIED) |
| `docs/QA_INTEGRATION_SCENARIOS.md` | Running E2E workflow tests | 9 scenarios with 219 checkpoints + MCP command templates |
| `docs/QA_UX_UI_TEST_PLAN.md` | Theme audit, responsive testing, animation verification | 38 routes, Deep Space compliance, TweenFX, empty states, accessibility |

---

## Quick Decision Tree

Route based on what the user is asking for:

**"Run full QA sweep" / "Test everything"**
→ Follow the [Full Sweep Protocol](#full-sweep-protocol)

**"Test [specific system]"** (e.g., "test campaign creation", "test battle system")
→ Look up the system in the [System Test Map](#system-test-map), then follow [Targeted Testing](#targeted-testing)

**"Write tests for [feature]"**
→ Read `references/gdunit4-patterns.md`, then follow [Test Generation Protocol](#test-generation-protocol)

**"Check UI" / "UX audit" / "Check theme"**
→ Read `references/ui-checklist.md`, then follow the audit procedure there

**"Test save/load" / "Data integrity" / "Validate data"**
→ Read `references/data-consistency.md`, follow the validation protocol

**"Regression test" / "Test after changes"**
→ Follow [Regression Protocol](#regression-protocol)

**"MCP test" / "Automated test" / "Run the game and test"**
→ Read `references/mcp-testing-guide.md`, follow test recipes

**"Bug notes" / "Known issues" / "Regression triggers"**
→ Read `references/bug-notes.md`

**"Cross-system check" / "Signal contracts" / "Enum sync"**
→ Read `references/cross-system-verification.md`

**"Edge cases" / "Boundary testing"**
→ Read `references/edge-cases.md`, select system-specific cases

---

## System Test Map

Quick lookup for every testable system. Use this to find source files, existing tests, and coverage gaps.

| System | Key Source Files | Existing Tests | Priority |
|--------|-----------------|----------------|----------|
| **Campaign Creation** (7 phases) | `src/core/campaign/creation/CampaignCreationCoordinator.gd`, `src/core/campaign/creation/CampaignCreationStateManager.gd`, `src/ui/screens/campaign/CampaignCreationUI.gd` | `tests/integration/test_campaign_creation_data_flow.gd` | P0 |
| **Campaign Turn** (9 phases) | `src/core/campaign/CampaignPhaseManager.gd`, `src/ui/screens/campaign/CampaignTurnController.gd` | `tests/integration/test_campaign_turn_loop.gd`, `tests/integration/test_campaign_turn_e2e.gd` | P0 |
| **Story Phase** | `src/ui/screens/campaign/phases/StoryPhasePanel.gd` | — | P1 |
| **Travel Phase** | `src/ui/screens/travel/TravelPhaseUI.gd` | — | P1 |
| **World Phase** (6 sub-steps) | `src/ui/screens/world/WorldPhaseController.gd`, `src/ui/screens/world/components/*.gd` | `tests/integration/test_world_phase_*.gd` | P0 |
| **Upkeep Phase** | `src/ui/screens/campaign/phases/UpkeepPhasePanel.gd` | `tests/unit/test_upkeep_phase_ui.gd` | P1 |
| **Battle System** (3 tiers) | `src/ui/screens/battle/TacticalBattleUI.gd`, `src/ui/screens/battle/PreBattle.gd` | `tests/battle/`, `tests/integration/test_battle_*.gd` | P0 |
| **Post-Battle** | `src/ui/screens/postbattle/PostBattleSequence.gd` | — | P1 |
| **Advancement Phase** | `src/ui/screens/campaign/phases/AdvancementPhasePanel.gd` | `tests/unit/test_character_advancement_*.gd` (36 tests) | P0 |
| **Trading Phase** | `src/ui/screens/campaign/phases/TradePhasePanel.gd` | — | P1 |
| **Character Phase** | `src/ui/screens/campaign/phases/CharacterPhasePanel.gd` | — | P1 |
| **End Phase** | `src/ui/screens/campaign/phases/EndPhasePanel.gd` | — | P1 |
| **Character System** | `src/core/character/Character.gd`, `src/core/character/Base/Character.gd` | `tests/unit/test_character_advancement_*.gd` | P0 |
| **Equipment System** | `src/core/equipment/EquipmentManager.gd` | — | P1 |
| **Injury System** | `tests/helpers/InjurySystemHelper.gd` | `tests/unit/test_injury_*.gd` (26 tests) | P0 |
| **Loot System** | `tests/helpers/LootSystemHelper.gd` | `tests/unit/test_loot_*.gd` (44 tests) | P0 |
| **Battle Calculations** | `tests/helpers/BattleTestHelper.gd` | `tests/unit/test_battle_calculations.gd` (49 tests) | P0 |
| **Save/Load** | `src/core/state/GameState.gd`, `src/core/data/DataManager.gd` | `tests/unit/test_state_persistence.gd` | P0 |
| **SceneRouter** | `src/ui/screens/SceneRouter.gd` | — (GAP) | P0 |
| **GameStateManager** | `src/core/managers/GameStateManager.gd` | — (GAP) | P0 |
| **Bug Hunt** | `src/ui/screens/bug_hunt/*.gd`, `src/game/bug_hunt/*.gd` | — | P1 |
| **DLC/Compendium** | `src/core/systems/DLCManager.gd` | — | P1 |
| **Store/Paywall** | `src/core/store/StoreManager.gd`, `src/core/store/*Adapter.gd` | — | P2 |
| **Enum Systems** | `src/core/systems/GlobalEnums.gd`, `src/core/enums/GameEnums.gd`, `src/game/campaign/crew/FiveParsecsGameEnums.gd` | — (GAP) | P0 |
| **Victory Checker** | `src/core/victory/VictoryChecker.gd` | — (GAP) | P0 |
| **Dashboard** | `src/ui/screens/campaign/CampaignDashboard.gd` | `tests/integration/test_dashboard_*.gd` | P1 |
| **UI/UX Theme** | `src/ui/screens/campaign/panels/BaseCampaignPanel.gd` | `tests/unit/test_theme_manager.gd` | P1 |

---

## Full Sweep Protocol

Execute in order. Stop at any P0 failure and fix before continuing.

### Phase 1: Compile & Existing Tests
```
Step 1: Headless compile check
  & "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
  → Must exit cleanly with 0 errors

Step 2: Run full gdUnit4 suite
  & "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/ --quit-after 300
  → Expected: 868+ tests passing
```

### Phase 2: MCP Smoke Tests
Read `references/mcp-testing-guide.md` Recipe 1. Verify:
- Game launches without crash
- MainMenu renders with all expected buttons
- Console has no ERROR-level messages
- Navigation to Campaign Creation works
- Navigation back to MainMenu works

### Phase 3: Campaign Creation Happy Path
Read `references/mcp-testing-guide.md` Recipe 7. Walk through all 7 steps:
1. CONFIG: Set name, difficulty, victory condition
2. CAPTAIN: Create captain with valid stats
3. CREW: Add crew members (test with 4 members)
4. EQUIPMENT: Generate and assign equipment
5. SHIP: Select ship
6. WORLD: Generate world
7. FINAL: Review and create campaign

### Phase 4: Save/Load Roundtrip
Read `references/data-consistency.md`. After creating campaign:
1. Save campaign
2. Return to main menu
3. Load campaign
4. Verify all data matches (crew, equipment, credits, turn number)
5. Save again, compare JSON

### Phase 5: Campaign Turn Walkthrough
Navigate through all 9 phases at least once:
STORY → TRAVEL → UPKEEP → MISSION → BATTLE_SETUP → BATTLE_RESOLUTION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → END

Verify:
- Each phase renders correctly
- Phase completion signals fire
- Data hands off correctly between phases
- End phase saves and loops

### Phase 6: Battle System
Test all 3 oracle tiers (LOG_ONLY, ASSISTED, FULL_ORACLE):
- Pre-battle setup with crew selection
- Battle UI renders correct components per tier
- Auto-resolve produces valid results
- Post-battle processes casualties and rewards

### Phase 7: UI/UX Audit
Read `references/ui-checklist.md`. Run Quick Audit (15 min) minimum, Full Audit (45 min) for thorough sweep.

### Phase 8: Edge Cases
Read `references/edge-cases.md`. Prioritize P0 cases:
- Dead captain handling
- 0 credits at upkeep
- All crew dead
- Save/load with corrupted JSON
- Equipment key validation

### Phase 9: Enum Consistency
Read `references/data-consistency.md` enum section. Verify 3 enum systems align.

### Phase 10: DLC Gating
Test ContentFlag matrix from `references/test-matrices.md`:
- Base game (all flags disabled) → core gameplay works
- Each flag independently → feature appears/hidden correctly

### Phase 11: Bug Hunt Cross-Mode Safety
Read `references/data-consistency.md` cross-mode section:
- Standard save has no Bug Hunt keys
- Bug Hunt save has no standard keys
- Wrong loader fails gracefully

### Phase 12: Report
Generate structured report with:
- Total tests run / passed / failed
- Bugs found (with severity and IDs from edge-cases.md)
- Coverage gaps identified
- Recommendations

---

## Targeted Testing

When the user asks to test a specific system:

1. **Find the system** in the System Test Map above
2. **Read existing tests** — understand what's already covered
3. **Check test matrices** — read `references/test-matrices.md` for the relevant matrix
4. **Run existing tests** for that system
5. **Identify gaps** — what dimensions/edge cases aren't covered?
6. **Write new tests** or **run MCP automated tests** to fill gaps
7. **Check edge cases** — read `references/edge-cases.md` for that system's section
8. **Report findings**

---

## Test Generation Protocol

When writing new gdUnit4 tests:

1. **Read `references/gdunit4-patterns.md`** for templates and conventions
2. **Check existing tests** for the system — don't duplicate
3. **Use correct factories**:
   - `BattleTestFactory` (tests/fixtures/BattleTestFactory.gd) — battle scenarios
   - `TestCharacterFactory` (tests/fixtures/TestCharacterFactory.gd) — full-schema characters
4. **Use correct helpers** (tests/helpers/) — see helper table in gdunit4-patterns.md
5. **Follow naming**: `test_[system]_[aspect].gd`, max 15 tests per file
6. **Follow structure**: extends GdUnitTestSuite, before/after/before_test/after_test lifecycle
7. **Signal assertions**: ALWAYS `await` with argument matchers
8. **Run verification**:
   ```
   & "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit/NEW_TEST_FILE.gd --quit-after 60
   ```

---

## Regression Protocol

After code changes, test in this order:

1. **Compile check** (headless --quit) — must pass
2. **Changed file's system** — run tests for the modified system
3. **Adjacent systems** — run tests for systems that depend on the changed code
4. **Signal flow** — verify connected signals still fire correctly
5. **MCP smoke test** — launch game, verify no crashes, navigate key screens
6. **Save/load roundtrip** — if data model changed, verify persistence

---

## Bug Report Format

```markdown
### BUG-XXX: [Brief title]
- **Severity**: P0 (crash/data loss) | P1 (wrong behavior) | P2 (cosmetic)
- **Persona**: Rulebook Replacer / Rulebook Companion / Both
- **System**: [From System Test Map]
- **Edge Case ID**: [From edge-cases.md, if applicable]

**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected**: [What should happen]
**Actual**: [What actually happens]
**Screenshot**: [MCP screenshot path if available]
**Console Output**: [Relevant error lines]
```

---

## Critical Gotchas for Testing

These are the most common sources of false failures and real bugs. Internalize these before writing or running tests.

1. **Stats are FLAT properties**: `combat`, `reactions`, `toughness`, `savvy`, `tech`, `move`, `speed`, `luck` — directly on the character object. There is NO `stats` sub-object. `CharacterStats.gd` exists but is NOT used as a property.

2. **Equipment key is `"equipment"`**: Ship stash is `campaign.equipment_data["equipment"]`. Using `"pool"` was a systemic bug fixed in Phase 22.

3. **FiveParsecsCampaignCore is Resource**: `campaign["key"] = val` silently fails. Use `progress_data["key"]` for runtime state. Use `"key" in campaign` instead of `.has("key")`.

4. **Character dual key aliases**: `to_dictionary()` returns both `"id"` + `"character_id"` and `"name"` + `"character_name"`. Tests must include both.

5. **MCP native dialogs invisible**: AcceptDialog/ConfirmationDialog popups can't be screenshotted or dismissed via MCP. Use `run_script` to call `.hide()`.

6. **MCP `run_script` — no await**: The `execute()` function must be synchronous. Using `await` causes a 30-second timeout.

7. **Three enum systems must sync**: GlobalEnums (autoload), GameEnums (class_name), FiveParsecsGameEnums (CharacterClass). Check alignment when enum values are tested.

8. **`--headless --quit` not comprehensive**: Only validates startup scripts. The Godot editor LSP loads ALL scripts. Always reboot editor after headless check.

9. **Bug Hunt data model differs**: `main_characters[]` + `grunts[]` (flat) vs `crew_data["members"]` (nested). Detect via `"main_characters" in campaign`.

10. **Godot 4.6 type inference**: `var x := untyped_array[i]` fails. Use explicit typing: `var x: Type = array[i]`.
