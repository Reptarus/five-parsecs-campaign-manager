# Battle HUD Signal Flow & State Management Tests

## Overview

This test suite validates the complete signal flow architecture for the battle system, ensuring proper communication between UI components, the EventBus, BattleManager, and BattleState.

## Test Files

### test_battle_hud_signals.gd (13 tests)
**Focus**: Core EventBus infrastructure and signal propagation

#### EventBus Component Registration (4 tests)
- `test_ui_component_registers_with_event_bus` - UI components register successfully
- `test_ui_component_unregisters_cleanly` - Clean unregistration and signal disconnection
- `test_event_bus_auto_connects_component_signals` - Auto-connection of standard signals
- `test_event_bus_prevents_duplicate_registrations` - Duplicate registration handling

#### Battle Manager Signal Flow (4 tests)
- `test_battle_manager_connects_to_event_bus` - BattleManager ↔ EventBus integration
- `test_battle_state_updates_propagate_through_event_bus` - State update propagation
- `test_battle_completion_triggers_event_bus_signal` - Battle completion signaling
- `test_ui_lock_request_broadcasts_to_components` - UI lock mechanism

#### State Synchronization (3 tests)
- `test_battle_state_round_tracking` - Round progression tracking
- `test_battle_state_phase_transitions` - Phase transition validation
- `test_battle_state_persists_combat_data` - Combat data persistence

#### Integration Signal Chains (2 tests)
- `test_ui_to_state_signal_chain` - Complete UI → EventBus → Manager → State flow
- `test_state_update_broadcasts_to_all_ui` - State updates broadcast to all UIs

### test_battle_ui_components.gd (13 tests)
**Focus**: UI component interactions and system integration

#### Dice System Integration (4 tests)
- `test_ui_dice_roll_request_routed_to_dice_system` - Dice roll routing
- `test_dice_roll_result_returns_through_event_bus` - Result propagation
- `test_combat_resolution_uses_dice_system` - Combat resolution integration
- `test_multiple_dice_rolls_tracked_independently` - Concurrent roll tracking

#### Phase Transition Signals (4 tests)
- `test_phase_transition_emits_old_and_new_phase` - Phase change signal validation
- `test_ui_components_notified_of_phase_changes` - UI notification broadcast
- `test_phase_completion_advances_battle_manager` - Phase advancement triggering
- `test_battle_initialization_sets_correct_phase` - Initialization phase setup

#### Error Handling & Edge Cases (3 tests)
- `test_ui_error_propagates_through_event_bus` - Error propagation
- `test_missing_battle_state_handled_gracefully` - Null state handling
- `test_concurrent_ui_updates_dont_conflict` - Concurrent update safety

#### Performance & Cleanup (2 tests)
- `test_event_bus_cleanup_removes_all_components` - Cleanup verification
- `test_battle_state_memory_efficient` - Memory efficiency validation

## Signal Flow Architecture

### Primary Signal Chains

#### 1. User Action → State Update
```
UI Component (BattleCompanionUI/BattleResolutionUI)
  ↓ emit: phase_completed / battle_action_triggered
EventBus (FPCM_BattleEventBus)
  ↓ forward signal
BattleManager (FPCM_BattleManager)
  ↓ update state
BattleState (FPCM_BattleState)
  ↓ emit: battle_state_updated
EventBus
  ↓ broadcast to all registered UIs
UI Components (refresh displays)
```

#### 2. Dice Roll Request → Result
```
UI Component
  ↓ emit: dice_roll_requested(pattern, context)
EventBus
  ↓ forward to DiceSystem
DiceSystem
  ↓ execute roll
  ↓ emit: dice_rolled(result)
EventBus
  ↓ emit: dice_roll_completed(result)
UI Component
  ↓ display result
```

#### 3. Phase Transition
```
BattleManager
  ↓ change phase
  ↓ emit: phase_changed(old_phase, new_phase)
EventBus
  ↓ emit: battle_phase_changed(old_phase, new_phase)
All Registered UI Components
  ↓ update displays for new phase
```

## Test Execution

### Running Individual Test Files

```powershell
# Test EventBus signal flow
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_hud_signals.gd `
  --quit-after 60

# Test UI component interactions
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_ui_components.gd `
  --quit-after 60
```

### Running Both Test Files
```powershell
# Run complete battle HUD test suite
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_hud_signals.gd tests/integration/test_battle_ui_components.gd `
  --quit-after 90
```

## Expected Results

### Success Criteria
- **All 26 tests passing** (13 per file)
- No memory leaks in EventBus component registration
- Signal propagation < 1 frame delay
- No race conditions in concurrent UI updates
- Clean cleanup on scene transitions

### Known Constraints
- **DO NOT use `--headless`** - causes crashes after 8-18 tests
- **Max 13 tests per file** - runner stability limit
- **UI mode required** - use console executable
- **Timeout: 60-90 seconds** - allows for async signal processing

## Integration Points Tested

### 1. EventBus Lifecycle
✅ Component registration
✅ Signal auto-connection
✅ Duplicate handling
✅ Clean unregistration
✅ Scene transition cleanup

### 2. BattleManager Integration
✅ Phase change signaling
✅ State update propagation
✅ Battle completion handling
✅ UI lock coordination

### 3. BattleState Persistence
✅ Round tracking
✅ Phase transitions
✅ Combat data accumulation
✅ Memory efficiency

### 4. DiceSystem Integration
✅ Roll request routing
✅ Result propagation
✅ Context preservation
✅ Concurrent roll tracking

### 5. UI Component Coordination
✅ Multi-component registration
✅ Broadcast updates
✅ Phase synchronization
✅ Error propagation

## Regression Prevention

These tests prevent regressions in:

1. **Signal disconnection bugs** - UI components not receiving state updates
2. **Memory leaks** - Components not cleaning up on scene change
3. **Race conditions** - Concurrent UI updates conflicting
4. **State desync** - BattleState not matching UI display
5. **Phase transition failures** - UI not updating on phase changes

## Future Enhancements

### Potential Additional Tests
- [ ] Load testing with 20+ registered UI components
- [ ] Stress testing with 1000+ triggered events
- [ ] Network latency simulation for multiplayer prep
- [ ] Save/load state during active battle
- [ ] UI performance profiling (frame time impact)

### Integration with E2E Tests
These unit/integration tests complement existing E2E tests:
- `test_campaign_turn_loop_e2e.gd` - Full turn loop including battle
- `test_battle_integration_validation.gd` - Battle system validation
- `test_world_to_battle_flow.gd` - World → Battle transition

## Troubleshooting

### Test Failures

**EventBus not found**
- Verify `FPCM_BattleEventBus` configured in `project.godot` autoloads
- Check path: `res://src/core/battle/FPCM_BattleEventBus.gd`

**Signal timeout failures**
- Increase `--quit-after` timeout to 90+ seconds
- Check for infinite loops in signal handlers
- Verify `await get_tree().process_frame` in async tests

**Memory leak warnings**
- Check `event_bus.cleanup_for_scene_change()` called in `after_test()`
- Verify all UI components use `auto_free()`
- Look for unreleased signal connections

**Inconsistent pass/fail rates**
- Avoid headless mode (use UI mode)
- Check for order dependencies between tests
- Ensure `before_test()` fully resets state

## Maintenance

### When to Update These Tests

✅ **Always update when**:
- Adding new signals to EventBus
- Changing BattleManager phase enum
- Modifying BattleState structure
- Adding new UI components to battle system

⚠️ **Consider updating when**:
- Performance degradation detected
- New edge cases discovered
- Integration with new systems (inventory, crew management)

## Contact & Support

For questions about these tests, see:
- **Architecture**: `docs/technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md`
- **Battle System**: `BATTLE_SYSTEM_TEST_GUIDE.md`
- **General Testing**: `tests/TESTING_GUIDE.md`
