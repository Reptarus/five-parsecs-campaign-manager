# Pre-Consolidation Validation Report
**Date**: 2025-11-29
**QA Specialist**: Agent 5 (Validation & Regression)
**Target**: File consolidation from 441 → 150-250 files

---

## Executive Summary

### Current File Counts
| Directory | File Count | Consolidation Priority |
|-----------|-----------|----------------------|
| `src/core/systems` | 45 files | HIGH |
| `src/core/managers` | 12 files | HIGH |
| `src/core/battle` | 32 files | MEDIUM |
| `src/core/` (total) | 237 files | - |
| `src/` (total) | **478 files** | - |
| `tests/` | 73 files | - |

### Test Suite Status
- **Total Test Functions**: 637 test functions across 56 test files
- **Current Pass Rate**: 76/79 minimum (96.2%)
- **Failing Tests**: 3 tests (equipment field mismatches)
- **Test Coverage**: Character Advancement, Injury System, Loot System, Battle Flow, Campaign Creation

---

## Critical Preservation Requirements

### 1. Class Names (189+ Registered)
**CRITICAL**: These class_name registrations MUST be preserved during consolidation. Only ONE class_name per merged file is allowed.

#### High-Priority Class Names (Used in Autoloads)
```gdscript
# From project.godot [autoload] section:
- CoreGameState (src/core/state/GameState.gd)
- GameStateManager (src/core/managers/GameStateManager.gd)
- DataManager (src/core/data/DataManager.gd)
- DiceManager (src/core/managers/DiceManager.gd)
- SaveManagerClass (src/core/state/SaveManager.gd)
- CampaignManager (src/core/managers/CampaignManager.gd)
- CampaignStateService (src/core/services/CampaignStateService.gd)
- SceneRouter (src/ui/screens/SceneRouter.gd)
- CampaignPhaseManager (src/core/campaign/CampaignPhaseManager.gd)
- BattleResultsManager (src/core/battle/BattleResultsManager.gd)
- BattlefieldCompanionManager (src/autoload/BattlefieldCompanionManager.gd)
- CampaignJournal (src/qol/CampaignJournal.gd)
- LegacySystem (src/qol/LegacySystem.gd)
- TurnPhaseChecklist (src/qol/TurnPhaseChecklist.gd)
- KeywordDB (src/qol/KeywordDB.gd)
- NPCTracker (src/qol/NPCTracker.gd)
- CampaignTurnEventBus (src/core/events/CampaignTurnEventBus.gd)
- ResponsiveManager (src/autoload/ResponsiveManager.gd)
- FPCM_AlphaGameManager (src/core/managers/AlphaGameManager.gd)
- ThemeManager (src/ui/themes/ThemeManager.gd)
```

#### Battle System Class Names
```gdscript
- FPCM_BattleManager
- FPCM_BattleState
- FPCM_BattleEventBus
- FPCM_BattleStateMachine
- FPCM_BattleCheckpoint
- FPCM_BattleEventsSystem
- FPCM_DeploymentConditionsSystem
- FPCM_BattlefieldGenerator
- FPCM_BattlefieldData
- BattleSetupData
- BattleResults
- CharacterUnit
- BattlePhaseController
```

#### Character & Equipment Class Names
```gdscript
- Character
- FiveParsecsCharacter
- CharacterCreationTables
- FiveParsecsCharacterGeneration
- CharacterManagerClass
- CharacterInventory
- BaseEquipment
- GameWeapon
- GameArmor
- GameGear
- GameItem
```

#### Campaign & State Class Names
```gdscript
- FiveParsecsCampaign
- SimpleCampaign
- CampaignCreationManager
- CampaignCreationStateManager
- CampaignCreationStateBridge
- CampaignTurnState
- VictoryConditionTracker
- Mission
```

---

### 2. Critical Signal Flows

#### Campaign Creation Flow Signals
**Source**: `CampaignCreationStateManager`, `CampaignFlowController`
```gdscript
signal campaign_state_available(state_data: Dictionary)
signal panel_data_requested(requesting_panel: Control)
signal phase_transition_requested(from_phase: int, to_phase: int)
signal panel_loaded(panel: Control, phase: int)
signal campaign_flow_completed(campaign_data: Dictionary)
signal campaign_flow_error(error_message: String)
```

**Connected In**: Campaign wizard panels (ConfigPanel, CaptainPanel, CrewPanel, etc.)

#### Battle Flow Signals
**Source**: `FPCM_BattleEventBus`, `FPCM_BattleManager`
```gdscript
# Battle Lifecycle
signal battle_initialized(battle_data: Dictionary)
signal battle_phase_changed(old_phase, new_phase)
signal battle_completed(results)
signal battle_error(error_code: String, context: Dictionary)

# UI Coordination
signal ui_transition_requested(target_ui: String, data: Dictionary)
signal ui_component_ready(component_name: String, component: Control)
signal ui_lock_requested(locked: bool, reason: String)
signal ui_refresh_requested(components: Array[String])

# Tactical Actions
signal tactical_action_requested(action: String, data: Dictionary)
signal unit_moved(unit_id: String, from_pos: Vector2i, to_pos: Vector2i)
signal combat_resolved(attacker_id: String, target_id: String, result: Dictionary)

# Pre-Battle Setup
signal pre_battle_setup_complete(setup_data: Dictionary)
signal crew_deployment_changed(deployment: Dictionary)
signal enemy_deployment_changed(deployment: Dictionary)

# Post-Battle
signal post_battle_acknowledged(continue_data: Dictionary)
signal rewards_calculated(rewards: Dictionary)
signal experience_applied(experience_data: Dictionary)
```

**Connected In**: BattleDashboardUI, TacticalBattleUI, PreBattleUI, PostBattleUI

#### Story Track Signals
**Source**: `StoryTrackSystem`, `UnifiedStorySystem`
```gdscript
signal story_clock_advanced(ticks_remaining: int)
signal story_event_triggered(event: StoryEvent)
signal story_choice_made(choice: Dictionary)
signal evidence_discovered(evidence_count: int)
signal story_track_completed()
signal story_milestone_reached(milestone: int)
signal quest_started(quest: StoryQuestData)
signal quest_completed(quest: StoryQuestData)
signal quest_failed(quest: StoryQuestData)
```

**Connected In**: Campaign dashboard, story track UI components

#### Victory Condition Signals
**Source**: `VictoryConditionTracker`
```gdscript
signal victory_condition_reached(condition_type: int, details: Dictionary)
signal victory_progress_updated(condition_type: int, current: int, required: int)
```

**Connected In**: VictoryProgressPanel, CampaignDashboard

#### State Management Signals
**Source**: `GameState`, `StateTracker`, `CampaignTurnEventBus`
```gdscript
signal state_changed(old_state: Dictionary, new_state: Dictionary)
signal state_updated(state: Dictionary)
signal state_validated(is_valid: bool, issues: Array)
signal turn_event_published(event_type: TurnEvent, data: Dictionary)
```

**Connected In**: Multiple UI screens, state validators

---

### 3. Autoload Path Dependencies

**CRITICAL**: These paths in `project.godot` [autoload] section MUST remain valid after consolidation:

```ini
GlobalEnums="*res://src/core/systems/GlobalEnums.gd"
GameState="*res://src/core/state/GameState.gd"
GameStateManager="*res://src/core/managers/GameStateManager.gd"
DataManager="*res://src/core/data/DataManager.gd"
DiceManager="*res://src/core/managers/DiceManager.gd"
SaveManager="*res://src/core/state/SaveManager.gd"
CampaignManager="*res://src/core/managers/CampaignManager.gd"
CampaignStateService="*res://src/core/services/CampaignStateService.gd"
SceneRouter="*res://src/ui/screens/SceneRouter.gd"
CampaignPhaseManager="*res://src/core/campaign/CampaignPhaseManager.gd"
BattleResultsManager="*res://src/core/battle/BattleResultsManager.gd"
BattlefieldCompanionManager="*res://src/autoload/BattlefieldCompanionManager.gd"
CampaignJournal="*res://src/qol/CampaignJournal.gd"
LegacySystem="*res://src/qol/LegacySystem.gd"
TurnPhaseChecklist="*res://src/qol/TurnPhaseChecklist.gd"
KeywordDB="*res://src/qol/KeywordDB.gd"
NPCTracker="*res://src/qol/NPCTracker.gd"
CampaignTurnEventBus="*res://src/core/events/CampaignTurnEventBus.gd"
ResponsiveManager="*res://src/autoload/ResponsiveManager.gd"
FPCM_AlphaGameManager="*res://src/core/managers/AlphaGameManager.gd"
ThemeManager="*res://src/ui/themes/ThemeManager.gd"
```

**Action Required**: After consolidation, update these paths in `project.godot` if files are merged.

---

## Circular Dependency Risks

### Known Preload/Load Chains
Based on architectural patterns, these dependencies should be monitored for circular references:

1. **GameState ← → CampaignManager**
   - GameState loads campaign data
   - CampaignManager updates GameState
   - **Risk**: LOW (uses autoload indirection)

2. **FPCM_BattleManager ← → FPCM_BattleEventBus**
   - BattleManager emits via EventBus
   - EventBus signals trigger BattleManager methods
   - **Risk**: MEDIUM (event bus pattern should prevent cycles, but verify)

3. **Character ← → CharacterInventory ← → Equipment**
   - Character owns inventory
   - Inventory contains equipment
   - Equipment references character stats
   - **Risk**: LOW (Resource-based composition)

4. **Systems consolidation into CoreSystems**
   - Multiple systems may reference each other
   - **Risk**: HIGH if merged into single file (break into logical subsystems)

---

## Validation Checklist for Post-Consolidation

### 1. Parse Check (MANDATORY - Run First)
```bash
'/mnt/c/Users/elija/Desktop/GoDot/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe' \
  --headless \
  --check-only \
  --path "c:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager" \
  --quit-after 8
```

**Expected**: No parse errors, no missing class_name errors

### 2. Autoload Verification
```bash
# Verify all autoload paths exist
grep "^[A-Z]" project.godot | grep "res://" | while read line; do
    path=$(echo "$line" | sed 's/.*res:/res:/' | sed 's/".*$//')
    test -f "${path//res:/src\/}" && echo "✓ $path" || echo "✗ MISSING: $path"
done
```

**Expected**: All 21 autoload paths valid

### 3. Signal Flow Test Cases

#### Test Case 1: Campaign Creation Flow
```gdscript
# File: tests/integration/test_campaign_creation_data_flow.gd
# Expected: All 10 tests pass
# Critical Signals: campaign_state_available, phase_transition_requested, campaign_flow_completed
```

#### Test Case 2: Battle 4-Phase Resolution
```gdscript
# File: tests/integration/phase2_backend/test_battle_4phase_resolution.gd
# Expected: All 17 tests pass
# Critical Signals: battle_initialized, battle_phase_changed, battle_completed
```

#### Test Case 3: Save/Load Roundtrip
```gdscript
# File: tests/integration/test_campaign_save_load.gd
# Expected: All 21 tests pass
# Critical: state_changed, state_validated signals
```

#### Test Case 4: Campaign Turn Loop
```gdscript
# File: tests/integration/test_campaign_turn_loop_basic.gd
# Expected: All 16 tests pass
# Critical: turn_event_published, phase transitions
```

### 4. Scene Reference Validation
**Check all .tscn files for references to moved/merged scripts**

```bash
# Find all scene files referencing scripts in consolidation directories
grep -r "script.*res://src/core/systems" src/ui/*.tscn
grep -r "script.*res://src/core/managers" src/ui/*.tscn
grep -r "script.*res://src/core/battle" src/ui/*.tscn
```

**Action Required**: Update scene files with new script paths

### 5. Test Suite Run (Full Validation)
```powershell
# Run all integration tests in UI mode (avoid headless bug)
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration `
  --quit-after 120
```

**Expected**: 76/79 minimum pass rate (current status)
**Blocker**: Any NEW failures introduced by consolidation

---

## Identified Risks

### HIGH RISK
1. **Autoload path breakage**: 21 autoloads must be manually updated in project.godot
2. **Scene script references**: Unknown number of .tscn files may reference consolidated scripts
3. **Class_name conflicts**: Merging files with multiple class_name declarations will cause parse errors
4. **Signal disconnections**: 300+ signal definitions across files may lose connections if not carefully preserved

### MEDIUM RISK
1. **Circular dependencies**: Consolidating interdependent systems may create load cycles
2. **Test failures**: 637 test functions assume specific file structure
3. **Preload paths**: Static type hints using preload() may break

### LOW RISK
1. **Resource references**: Resource files (.tres) using class_name references
2. **Documentation**: README/docs may reference old file paths
3. **Git history**: File renames vs moves may complicate blame tracking

---

## Test Files Requiring Updates

Based on grep analysis, these test files may need path updates:

### Integration Tests (High Priority)
```
tests/integration/test_campaign_creation_data_flow.gd (10 tests)
tests/integration/test_battle_integration_validation.gd (8 tests)
tests/integration/phase2_backend/test_battle_initialization.gd (10 tests)
tests/integration/phase2_backend/test_phase_transitions.gd (8 tests)
tests/integration/test_ui_backend_bridge.gd (6 tests)
tests/integration/test_battle_data_flow.gd (8 tests)
```

### Unit Tests (Medium Priority)
```
tests/unit/test_battle_calculations.gd (49 tests)
tests/unit/test_character_advancement_*.gd (36 tests total)
tests/unit/test_loot_*.gd (44 tests total)
tests/unit/test_injury_*.gd (28 tests total)
```

**Action Required**: Search-and-replace old paths with consolidated paths in all test files

---

## Post-Consolidation Validation Steps

### Step 1: Immediate Validation (0-5 minutes)
1. ✓ Run parse check (--check-only)
2. ✓ Verify autoload paths exist
3. ✓ Check for duplicate class_name declarations
4. ✓ Verify no orphaned signal connections

### Step 2: Test Suite Validation (5-15 minutes)
1. ✓ Run unit tests (expect 100% pass)
2. ✓ Run integration tests (expect 76/79 minimum)
3. ✓ Check for NEW test failures (blocker)
4. ✓ Verify signal flow tests pass

### Step 3: Manual Smoke Testing (15-30 minutes)
1. ✓ Launch main menu
2. ✓ Create new campaign (full wizard flow)
3. ✓ Navigate campaign dashboard
4. ✓ Initiate battle (pre-battle → tactical → post-battle)
5. ✓ Save campaign
6. ✓ Load campaign
7. ✓ Verify character advancement
8. ✓ Verify equipment management

### Step 4: Performance Baseline (30-45 minutes)
1. ✓ Campaign load time < 500ms (95th percentile)
2. ✓ Memory usage < 200MB peak
3. ✓ Frame rate > 58 FPS sustained (dashboard)
4. ✓ No frame drops during UI interactions

---

## Rollback Plan

If consolidation breaks critical functionality:

1. **Immediate Rollback**: `git reset --hard HEAD~1` (if committed)
2. **Partial Rollback**: `git checkout HEAD -- src/core/systems` (restore specific directories)
3. **Test-Driven Repair**: Identify failing tests, fix consolidated files, re-run
4. **Emergency**: Revert to pre-consolidation commit tag

---

## Success Criteria

### Minimum Viable Consolidation
- ✓ File count: 441 → 350 files (21% reduction)
- ✓ Test pass rate: 76/79 maintained (no new failures)
- ✓ All autoloads functional
- ✓ Parse check passes
- ✓ Campaign creation flow works

### Target Consolidation
- ✓ File count: 441 → 250 files (43% reduction)
- ✓ Test pass rate: 79/79 (100%)
- ✓ All signal flows validated
- ✓ Performance maintained (< 500ms load, < 200MB RAM)
- ✓ Manual smoke tests pass

### Stretch Goal
- ✓ File count: 441 → 150 files (66% reduction)
- ✓ Test coverage increased
- ✓ Zero circular dependencies
- ✓ Architectural documentation updated

---

## QA Agent Status: READY FOR VALIDATION

**Prepared By**: QA & Integration Specialist (Agent 5)
**Date**: 2025-11-29
**Next Action**: Execute validation steps immediately after consolidation agents complete work

**Validation Tools Ready**:
- ✓ Parse check command prepared
- ✓ Autoload verification script ready
- ✓ Test suite commands prepared
- ✓ Manual testing checklist created
- ✓ Rollback plan documented

**Critical Watchlist**:
1. project.godot autoload section (21 paths)
2. Signal connections (300+ signals)
3. Class_name registrations (189+)
4. Test pass rate (maintain 76/79 minimum)

---
