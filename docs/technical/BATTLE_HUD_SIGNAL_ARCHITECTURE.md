# Battle HUD Signal Architecture

**Status**: Updated 2026-02-28 (originally 2025-11-27)
**Pattern**: Call Down, Signal Up (Godot Best Practice)
**Performance Target**: 60 FPS
**Note**: BattleHUDCoordinator and BattleScreen.gd were deleted in Phase 16-17. TacticalBattleUI.gd now serves as the signal hub. See `docs/technical/BATTLE_SYSTEM_ARCHITECTURE.md` for current architecture. The patterns described below remain valid.

## Overview

The battle HUD follows Godot's "call down, signal up" principle:
- **Parents call DOWN**: Direct method calls to update child components
- **Children signal UP**: Signals to notify parent of events/interactions
- **No get_parent()**: Children never directly access parents (brittle!)

## Architecture Diagram (Current — Feb 2026)

```
TacticalBattleUI (Top Level — 1,694 lines, signal hub)
    │
    ├─ BattleRoundTracker (Logic — phases, rounds)
    │   ├─ Signals UP: phase_changed, round_started, round_ended, battle_event_triggered
    │   └─ Called DOWN: start_battle(), advance_phase()
    │
    └─ 26 Battle Components (three-zone tabbed layout)
        │
        ├─ CharacterStatusCard (per crew member)
        │   ├─ Signals UP: action_used, damage_taken
        │   └─ Called DOWN: set_character_data(), set_display_tier()
        │
        ├─ VictoryProgressPanel
        │   ├─ Signals UP: victory_condition_met, defeat_condition_triggered, objective_status_changed
        │   └─ Called DOWN: (display updates)
        │
        ├─ MoralePanicTracker
        │   ├─ Signals UP: morale_check_triggered, enemy_fled
        │   └─ Called DOWN: (setup via instantiation)
        │
        ├─ BattleJournal (central log — receives from all components)
        │
        └─ ... 22 more components (see BATTLE_SYSTEM_ARCHITECTURE.md)
```

### Legacy Diagram (Pre-Phase 16 — BattleHUDCoordinator, now deleted)

```
BattleScreen (Top Level) — DELETED
    ├─ BattleStateMachine — DELETED
    └─ BattleHUDCoordinator — DELETED, replaced by TacticalBattleUI
```

## Signal Flow Examples

### Example 1: Player Clicks "Use Action" Button

**Flow**:
```
1. User clicks button in CharacterStatusCard
2. CharacterStatusCard signals UP: action_used.emit(character_name, action_type)
3. BattleHUDCoordinator receives signal via _on_character_action_used()
4. BattleHUDCoordinator signals UP: character_action_requested.emit(character_name, action_type)
5. BattleScreen receives signal via _on_character_action_requested()
6. BattleScreen calls DOWN: battle_state_machine.complete_unit_action()
7. BattleStateMachine signals UP: unit_action_completed.emit(unit, action)
8. BattleHUDCoordinator receives signal and updates UI
```

**Code**:
```gdscript
# CharacterStatusCard.gd (Child signals UP)
func _on_use_action_button_pressed() -> void:
    use_action()

func use_action() -> void:
    if actions_remaining > 0:
        actions_remaining -= 1
        action_used.emit(character_data.get("character_name", ""), "generic_action")

# BattleHUDCoordinator.gd (Coordinator relays UP)
func _on_character_action_used(character_name: String, action_type: String) -> void:
    character_action_requested.emit(character_name, action_type)
    
    # Also call DOWN to BattleStateMachine if needed
    if battle_state_machine:
        var character_node: Node = _find_character_node(character_name)
        if character_node:
            battle_state_machine.complete_unit_action()

# BattleScreen.gd (Parent handles and calls DOWN)
func _on_character_action_requested(character_name: String, action_type: String) -> void:
    print("Action requested: ", character_name, " - ", action_type)
    # Apply action through BattleStateMachine (call DOWN)
    # battle_state_machine.process_character_action(character_index, action_type)
```

### Example 2: New Round Starts

**Flow**:
```
1. BattleStateMachine detects new round condition
2. BattleStateMachine calls DOWN: start_round()
3. BattleStateMachine signals UP: round_started.emit(round_number)
4. BattleScreen receives signal (logs it)
5. BattleHUDCoordinator receives signal via _on_round_started()
6. BattleHUDCoordinator calls DOWN to all CharacterStatusCards: card.reset_round()
7. BattleHUDCoordinator calls DOWN to MoralePanicTracker: morale_tracker.new_round()
8. Each component updates its UI
```

**Code**:
```gdscript
# BattleStateMachine.gd (Logic signals UP)
func start_round() -> void:
    current_round = max(1, current_round)
    transition_to(_get_safe_enum_value(GlobalEnums, "BattleState", "ROUND", BATTLE_STATE_ROUND))
    _emit_round_started(current_round)

# BattleHUDCoordinator.gd (Coordinator calls DOWN to children)
func _on_round_started(round_number: int) -> void:
    print("Battle HUD: Round ", round_number, " started")
    
    # Reset all character cards (Call DOWN)
    for card in character_cards.values():
        if is_instance_valid(card):
            card.reset_round()
    
    # Reset morale tracker (Call DOWN)
    if morale_tracker:
        morale_tracker.new_round()

# CharacterStatusCard.gd (Child component updates itself)
func reset_round() -> void:
    """Reset per-round values - called at start of new round"""
    actions_remaining = character_data.get("max_actions", 2)
    movement_remaining = character_data.get("max_movement", 6)
    _update_display()
```

### Example 3: Enemy Casualty → Morale Check

**Flow**:
```
1. Enemy takes fatal damage (handled externally)
2. BattleScreen calls DOWN: hud_coordinator.register_enemy_casualty()
3. BattleHUDCoordinator calls DOWN: morale_tracker.add_casualty()
4. BattleHUDCoordinator signals UP: enemy_casualty_registered.emit()
5. MoralePanicTracker detects first casualty this round
6. MoralePanicTracker signals UP: morale_check_triggered.emit(enemies_remaining, casualties)
7. BattleHUDCoordinator receives signal via _on_morale_check_triggered()
8. BattleHUDCoordinator calls DOWN: morale_tracker.roll_morale_check()
9. MoralePanicTracker calculates result and updates UI
10. MoralePanicTracker signals UP: enemy_fled.emit(fled_count) if enemies fled
11. BattleHUDCoordinator relays UP: enemies_fled.emit(fled_count)
12. BattleScreen applies fled enemies to battle state
```

**Code**:
```gdscript
# BattleScreen.gd (Parent calls DOWN)
func _on_enemy_casualty_registered() -> void:
    print("Enemy casualty registered")
    if battle_state:
        var enemies_remaining: int = _count_active_enemies()
        if enemies_remaining == 0:
            battle_state_machine.end_battle(1) # Victory!

# BattleHUDCoordinator.gd (Coordinator orchestrates)
func register_enemy_casualty() -> void:
    if morale_tracker:
        morale_tracker.add_casualty()  # Call DOWN
    enemy_casualty_registered.emit()  # Signal UP

func _on_morale_check_triggered(enemies_remaining: int, casualties: int) -> void:
    if morale_tracker:
        var result: Dictionary = morale_tracker.roll_morale_check()  # Call DOWN
        morale_check_completed.emit(result)  # Signal UP

# MoralePanicTracker.gd (Child component logic)
func add_casualty() -> void:
    if enemies_remaining > 0:
        enemies_remaining -= 1
        casualties_this_round += 1
        _update_display()
        
        if _needs_morale_check():
            morale_check_triggered.emit(enemies_remaining, casualties_this_round)  # Signal UP
```

## Performance Optimization

### Batch UI Updates
The HUD uses batched updates to maintain 60 FPS:

```gdscript
# BattleHUDCoordinator.gd
const UPDATE_THROTTLE: float = 1.0 / 60.0 # 60 FPS target
var update_batch_queued: bool = false
var last_update_time: float = 0.0

func _queue_batch_update() -> void:
    """Queue a batched UI update (60fps throttle)"""
    if update_batch_queued:
        return
    
    var current_time: float = Time.get_ticks_msec() / 1000.0
    if current_time - last_update_time < UPDATE_THROTTLE:
        # Too soon, queue for next frame
        call_deferred("_execute_batch_update")
        update_batch_queued = true
    else:
        # Can update now
        _execute_batch_update()

func _execute_batch_update() -> void:
    """Execute batched UI updates"""
    update_batch_queued = false
    last_update_time = Time.get_ticks_msec() / 1000.0
    _update_character_highlighting()
```

### @onready Caching
All node references are cached with `@onready` to avoid repeated `get_node()` calls:

```gdscript
@onready var objective_display: FPCM_ObjectiveDisplay = $ObjectiveDisplay
@onready var morale_tracker: FPCM_MoralePanicTracker = $MoraleTracker
@onready var crew_container: HBoxContainer = $CrewContainer
```

## Anti-Patterns to Avoid

### ❌ WRONG: Child Accessing Parent
```gdscript
# CharacterStatusCard.gd - NEVER DO THIS!
func _on_button_pressed():
    get_parent().update_battle_state()  # Brittle! Breaks if scene tree changes
```

### ✅ CORRECT: Child Signals Up
```gdscript
# CharacterStatusCard.gd
signal action_used(character_name: String, action_type: String)

func _on_button_pressed():
    action_used.emit(character_data.get("character_name", ""), "action")
```

### ❌ WRONG: Parent Using Signals to Children
```gdscript
# BattleHUDCoordinator.gd - NEVER DO THIS!
signal update_character_health(character_name: String, health: int)

func apply_damage():
    update_character_health.emit("John", 2)  # Wrong direction!
```

### ✅ CORRECT: Parent Calls Down
```gdscript
# BattleHUDCoordinator.gd
func update_character_health(character_name: String, new_health: int) -> void:
    var card: FPCM_CharacterStatusCard = character_cards.get(character_name)
    if card:
        card.apply_damage(card.current_health - new_health)  # Direct call DOWN
```

### ❌ WRONG: Signal Chains
```gdscript
# Signal triggering another signal (hard to debug!)
signal action_completed()
signal round_ended()

func _on_action_completed():
    round_ended.emit()  # Confusing chain
```

### ✅ CORRECT: Direct Logic Flow
```gdscript
# Clear method calls
func _on_action_completed():
    _check_round_completion()  # Direct method call

func _check_round_completion():
    if _all_actions_complete():
        _end_round()  # Clear flow
```

## Testing the Signal Flow

To verify the signal architecture works correctly:

1. **Unit Test**: Verify signals are emitted correctly
```gdscript
# test_character_status_card.gd
func test_action_used_signal():
    var card = CharacterStatusCard.new()
    var signal_watcher = watch_signals(card)
    
    card.use_action()
    
    assert_signal_emitted(signal_watcher, card, "action_used")
```

2. **Integration Test**: Verify signal chain from child to parent
```gdscript
# test_battle_hud_integration.gd
func test_action_propagates_to_coordinator():
    var coordinator = BattleHUDCoordinator.new()
    var card = CharacterStatusCard.new()
    coordinator.character_cards["Test"] = card
    
    var signal_watcher = watch_signals(coordinator)
    card.action_used.emit("Test", "move")
    
    assert_signal_emitted(signal_watcher, coordinator, "character_action_requested")
```

3. **E2E Test**: Verify full battle flow
```gdscript
# test_battle_screen_e2e.gd
func test_complete_round_cycle():
    var battle_screen = BattleScreen.new()
    battle_screen.start_battle(mission, crew, enemies)
    
    # Simulate round
    battle_screen.battle_state_machine.start_round()
    
    # Verify HUD updated
    assert_eq(battle_screen.hud_coordinator.character_cards.size(), crew.size())
```

## File Locations

- **BattleScreen**: `src/ui/screens/battle/BattleScreen.gd`
- **BattleHUDCoordinator**: `src/ui/screens/battle/BattleHUDCoordinator.gd` + `.tscn`
- **CharacterStatusCard**: `src/ui/components/battle/CharacterStatusCard.gd` + `.tscn`
- **ObjectiveDisplay**: `src/ui/components/battle/ObjectiveDisplay.gd` + `.tscn`
- **MoralePanicTracker**: `src/ui/components/battle/MoralePanicTracker.gd` + `.tscn`
- **BattleStateMachine**: `src/core/battle/state/BattleStateMachine.gd`

## Summary

The battle HUD signal architecture demonstrates:
- ✅ **Clean separation**: Logic (BattleStateMachine) vs UI (HUD)
- ✅ **Godot best practices**: Call down, signal up
- ✅ **Performance**: 60 FPS with batched updates
- ✅ **Maintainability**: No brittle `get_parent()` calls
- ✅ **Testability**: Clear signal flow, easy to unit test
- ✅ **Scalability**: Easy to add new HUD components

This pattern should be used for all UI-to-logic integration in the Five Parsecs Campaign Manager.
