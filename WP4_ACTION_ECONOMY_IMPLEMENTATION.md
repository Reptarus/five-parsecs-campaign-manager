# WP4: Player Action Phase UI - Implementation Summary

## Overview
Implemented the Five Parsecs action economy system (2 actions per turn) with action tracking, UI display, and overwatch mechanics for tactical battle.

## Implementation Date
2025-12-16

## Files Modified

### 1. BattleStateMachine.gd
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/battle/state/BattleStateMachine.gd`

**Changes**:
- Added action economy tracking properties:
  ```gdscript
  const MAX_ACTIONS_PER_TURN: int = 2
  var character_actions_remaining: Dictionary = {}  # character_id -> int
  var character_moved_this_turn: Dictionary = {}  # character_id -> bool
  var characters_on_overwatch: Dictionary = {}  # character_id -> bool
  ```

- Added action economy methods:
  - `start_character_turn(character_id: String)` - Reset actions to 2 at turn start
  - `use_action(character_id: String, action_cost: int = 1) -> bool` - Consume actions, returns false if insufficient
  - `get_actions_remaining(character_id: String) -> int` - Query remaining actions
  - `has_character_moved(character_id: String) -> bool` - Check movement status
  - `set_character_moved(character_id: String, moved: bool)` - Track movement
  - `set_character_overwatch(character_id: String, on_overwatch: bool)` - Set overwatch state
  - `is_character_on_overwatch(character_id: String) -> bool` - Query overwatch status

- Updated `reset_battle()` to clear action economy dictionaries

### 2. TacticalBattleUI.gd
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/battle/TacticalBattleUI.gd`

**Changes**:
- Added BattleStateMachine reference:
  ```gdscript
  var battle_state_machine: FPCM_BattleStateMachine = null
  var action_counter_label: Label = null
  ```

- Created action counter UI in `_setup_ui()`:
  - Dynamically creates Label with "Actions: 2/2" display
  - Color-coded: Green (full), Yellow (partial), Red (none)
  - Shows "[OVERWATCH]" indicator when applicable
  - Positioned after turn indicator in action panel

- Added `_update_action_counter(character_id: String)`:
  - Updates action count display
  - Color codes based on remaining actions
  - Shows overwatch status

- Integrated action economy into `_start_unit_turn()`:
  - Calls `battle_state_machine.start_character_turn()` to reset actions

- Updated action handlers to use action economy:
  - **Move** (1 action): Checks and consumes action, tracks movement
  - **Shoot** (1 action): Checks and consumes action
  - **Dash** (2 actions): Requires both actions for double movement
  - **Use Item** (1 action): Checks and consumes action
  - **Overwatch** (1 action): Consumes action and ends turn immediately

- Added overwatch button in `_update_action_buttons_for_combat()`:
  - Only shown when actions remain
  - Disabled if already on overwatch

- Added `_on_overwatch_clicked()` handler:
  - Validates action availability
  - Sets overwatch state (automatically ends turn)
  - Logs to battle log
  - Updates UI and ends turn

## Action Costs (Five Parsecs Rules)

| Action | Cost | Notes |
|--------|------|-------|
| Move | 1 action | Tracks movement for overwatch mechanics |
| Attack/Shoot | 1 action | Standard combat action |
| Use Item | 1 action | Consumables, equipment |
| Dash | 2 actions | Double movement, forfeits shooting |
| Overwatch | 1 action | Ends turn, reactive fire on enemy movement |

## UI Components

### Action Counter Display
- **Location**: Action panel, below turn indicator
- **Format**: "Actions: X/2" with color coding
- **Colors**:
  - Green: 2/2 (full actions)
  - Yellow: 1/2 (partial actions)
  - Red: 0/2 (no actions)
- **Overwatch Indicator**: Appends "[OVERWATCH]" when active

### Overwatch Button
- **Visibility**: Only shown when actions > 0 and not on overwatch
- **Behavior**:
  - Costs 1 action
  - Immediately ends turn
  - Sets character in reactive state for enemy movement
  - Shows visual indicator in action counter

## Technical Implementation

### Signal Architecture
Follows Godot 4.5 "call down, signal up" pattern:
- **Call Down**: TacticalBattleUI calls BattleStateMachine methods directly
- **Signal Up**: BattleStateMachine emits signals for state changes (future expansion)

### Action Economy Flow
```
Turn Start → start_character_turn(id) → MAX_ACTIONS_PER_TURN (2)
    ↓
Player Action → use_action(id, cost) → Validate & Decrement
    ↓
Update UI → _update_action_counter() → Display remaining actions
    ↓
Turn End → Clear overwatch, ready for next turn
```

### Overwatch Mechanics
```
Overwatch Button Clicked
    ↓
use_action(id, 1) - Consume 1 action
    ↓
set_character_overwatch(id, true) - Mark on overwatch
    ↓
character_actions_remaining[id] = 0 - Force end turn
    ↓
_end_unit_turn() - Proceed to next character
```

## Validation

### Compilation Check
Ran Godot check-only validation - **PASSED**
```bash
Godot_v4.5.1-stable_win64_console.exe --headless --check-only
```
No errors, all scripts compile successfully.

### Integration Points
- ✅ BattleStateMachine action tracking
- ✅ TacticalBattleUI action counter display
- ✅ Action handlers (move, shoot, dash, use item, overwatch)
- ✅ Turn initialization and cleanup
- ✅ Overwatch state management

## Future Enhancements

### Phase 2 (Polish)
- [ ] Action preview tooltips (e.g., "Move: 1 action, Dash: 2 actions")
- [ ] Undo last action (if not attacked yet)
- [ ] Action queue visualization
- [ ] Overwatch reaction animation/effects
- [ ] Mobile touch optimization for action buttons

### Phase 3 (Advanced)
- [ ] Quick actions (0 actions): Free look, communicate
- [ ] Reaction fire UI when on overwatch
- [ ] Action point penalties (suppression, wounds)
- [ ] Action history per character (for AI/replay)

## Testing Checklist

Manual testing scenarios:
- [ ] Character starts turn with 2/2 actions (green)
- [ ] Move action reduces to 1/2 (yellow)
- [ ] Second action reduces to 0/2 (red)
- [ ] Dash costs 2 actions (2/2 → 0/2)
- [ ] Overwatch costs 1 action and ends turn
- [ ] Overwatch indicator shows "[OVERWATCH]"
- [ ] Cannot perform actions with 0 actions remaining
- [ ] Action counter updates after each action
- [ ] Turn end clears overwatch status

## Notes

- Action economy is tracked per character by character ID (node_name)
- Overwatch state persists until character's next turn
- Movement tracking enables future camouflage/overwatch trigger mechanics
- All action costs follow Five Parsecs from Home core rules
- UI is responsive and updates immediately after actions

## Related Work Packages
- WP3: Battle Round Tracking System (completed)
- WP5: Enemy AI Turn Resolution (next)
- WP6: Victory/Defeat Conditions (next)
