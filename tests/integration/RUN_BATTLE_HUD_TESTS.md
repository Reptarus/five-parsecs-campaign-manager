# Quick Start: Running Battle HUD Signal Flow Tests

## Prerequisites

- Godot 4.5.1-stable (console executable)
- gdUnit4 v6.0.1 addon installed
- FPCM_BattleEventBus configured in project.godot autoloads

## Quick Test Execution

### Run All Battle HUD Tests (26 tests)

```powershell
cd C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager

& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_hud_signals.gd tests/integration/test_battle_ui_components.gd `
  --quit-after 90
```

### Run Individual Test Files

**EventBus Signal Flow (13 tests)**:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_hud_signals.gd `
  --quit-after 60
```

**UI Component Interactions (13 tests)**:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_ui_components.gd `
  --quit-after 60
```

## Expected Output

### Success (All 26 Tests Pass)

```
gdUnit4 Test Runner v6.0.1

Running test_battle_hud_signals.gd
  ✓ test_ui_component_registers_with_event_bus (23ms)
  ✓ test_ui_component_unregisters_cleanly (18ms)
  ✓ test_event_bus_auto_connects_component_signals (31ms)
  ✓ test_event_bus_prevents_duplicate_registrations (15ms)
  ✓ test_battle_manager_connects_to_event_bus (28ms)
  ✓ test_battle_state_updates_propagate_through_event_bus (22ms)
  ✓ test_battle_completion_triggers_event_bus_signal (19ms)
  ✓ test_ui_lock_request_broadcasts_to_components (35ms)
  ✓ test_battle_state_round_tracking (12ms)
  ✓ test_battle_state_phase_transitions (14ms)
  ✓ test_battle_state_persists_combat_data (17ms)
  ✓ test_ui_to_state_signal_chain (29ms)
  ✓ test_state_update_broadcasts_to_all_ui (33ms)

Running test_battle_ui_components.gd
  ✓ test_ui_dice_roll_request_routed_to_dice_system (26ms)
  ✓ test_dice_roll_result_returns_through_event_bus (21ms)
  ✓ test_combat_resolution_uses_dice_system (24ms)
  ✓ test_multiple_dice_rolls_tracked_independently (19ms)
  ✓ test_phase_transition_emits_old_and_new_phase (16ms)
  ✓ test_ui_components_notified_of_phase_changes (38ms)
  ✓ test_phase_completion_advances_battle_manager (31ms)
  ✓ test_battle_initialization_sets_correct_phase (18ms)
  ✓ test_ui_error_propagates_through_event_bus (22ms)
  ✓ test_missing_battle_state_handled_gracefully (11ms)
  ✓ test_concurrent_ui_updates_dont_conflict (42ms)
  ✓ test_event_bus_cleanup_removes_all_components (19ms)
  ✓ test_battle_state_memory_efficient (14ms)

Total: 26 tests
Passed: 26 (100%)
Failed: 0
Skipped: 0
Time: ~45 seconds
```

### Failure Scenarios

**EventBus Not Found**:
```
FPCM_BattleEventBus autoload not found - check project.godot
```
**Fix**: Verify autoload configuration in project.godot

**Signal Timeout**:
```
Timeout waiting for signal 'battle_phase_changed'
```
**Fix**: Increase --quit-after to 120 seconds, check for signal connection issues

**Memory Leak Warning**:
```
Warning: EventBus has 25 registered components
```
**Fix**: Check cleanup_for_scene_change() called in after_test()

## What Each Test Validates

### test_battle_hud_signals.gd

| Test | Validates | Critical For |
|------|-----------|--------------|
| `test_ui_component_registers_with_event_bus` | Registration mechanism | UI component lifecycle |
| `test_ui_component_unregisters_cleanly` | Cleanup & signal disconnection | Memory leak prevention |
| `test_event_bus_auto_connects_component_signals` | Auto-connection on registration | Developer convenience |
| `test_event_bus_prevents_duplicate_registrations` | Duplicate handling | Stability |
| `test_battle_manager_connects_to_event_bus` | BattleManager integration | Signal routing |
| `test_battle_state_updates_propagate_through_event_bus` | State propagation | UI synchronization |
| `test_battle_completion_triggers_event_bus_signal` | Completion signaling | Phase transitions |
| `test_ui_lock_request_broadcasts_to_components` | UI lock mechanism | User interaction blocking |
| `test_battle_state_round_tracking` | Round progression | Combat tracking |
| `test_battle_state_phase_transitions` | Phase state machine | Battle flow |
| `test_battle_state_persists_combat_data` | Data persistence | Save/load |
| `test_ui_to_state_signal_chain` | Complete signal flow | End-to-end integration |
| `test_state_update_broadcasts_to_all_ui` | Multi-UI synchronization | Concurrent updates |

### test_battle_ui_components.gd

| Test | Validates | Critical For |
|------|-----------|--------------|
| `test_ui_dice_roll_request_routed_to_dice_system` | Dice roll routing | Combat resolution |
| `test_dice_roll_result_returns_through_event_bus` | Result propagation | UI feedback |
| `test_combat_resolution_uses_dice_system` | Combat integration | Game mechanics |
| `test_multiple_dice_rolls_tracked_independently` | Concurrent rolls | Complex combat |
| `test_phase_transition_emits_old_and_new_phase` | Phase change signals | State tracking |
| `test_ui_components_notified_of_phase_changes` | Multi-UI notification | UI consistency |
| `test_phase_completion_advances_battle_manager` | Phase advancement | Battle progression |
| `test_battle_initialization_sets_correct_phase` | Initialization | Battle startup |
| `test_ui_error_propagates_through_event_bus` | Error handling | Debugging |
| `test_missing_battle_state_handled_gracefully` | Null safety | Crash prevention |
| `test_concurrent_ui_updates_dont_conflict` | Race condition prevention | Stability |
| `test_event_bus_cleanup_removes_all_components` | Cleanup verification | Memory management |
| `test_battle_state_memory_efficient` | Memory efficiency | Performance |

## Troubleshooting

### Tests Pass Locally But Fail in CI

**Symptom**: Tests pass on Windows but fail on Linux CI
**Cause**: File path case sensitivity or headless mode issues
**Fix**: 
1. Verify all resource paths use correct case
2. Ensure CI uses UI mode (not headless)
3. Check autoload paths in project.godot

### Intermittent Failures

**Symptom**: Test passes sometimes, fails other times
**Cause**: Timing issues with signal propagation
**Fix**:
1. Add `await get_tree().process_frame` after signal emissions
2. Increase timeout on `await_signal_on` calls
3. Check for order dependencies between tests

### Performance Degradation

**Symptom**: Tests take >90 seconds to complete
**Cause**: EventBus accumulating connections or components
**Fix**:
1. Verify `cleanup_for_scene_change()` called in `after_test()`
2. Check for leaked signal connections
3. Monitor EventBus status with `get_event_bus_status()`

## Next Steps After Testing

1. **All Tests Pass**:
   - Integrate into CI/CD pipeline
   - Add to pre-commit hooks
   - Document baseline performance metrics

2. **Some Tests Fail**:
   - Review test output for specific failures
   - Check BATTLE_HUD_TESTS_README.md troubleshooting section
   - Verify EventBus configuration in project.godot

3. **Performance Issues**:
   - Profile with Godot profiler
   - Check EventBus component count
   - Review signal connection lifecycle

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Battle HUD Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.5.1-stable
      - name: Run Battle HUD Tests
        run: |
          godot --path . --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
            -a tests/integration/test_battle_hud_signals.gd \
               tests/integration/test_battle_ui_components.gd \
            --quit-after 90
```

## Documentation References

- **Architecture**: `tests/integration/BATTLE_HUD_TESTS_README.md`
- **Summary**: `BATTLE_HUD_TEST_SUMMARY.md`
- **General Testing**: `tests/TESTING_GUIDE.md`
- **System Architecture**: `docs/technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md`
