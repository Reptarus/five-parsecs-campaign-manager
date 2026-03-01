# Training UI Integration - Fix Set C Completion

**Date**: 2025-12-17
**Status**: ✅ COMPLETE
**Files Modified**: 1

## Changes Made

### File: `/src/ui/screens/postbattle/PostBattleSequence.gd`

#### 1. Added TrainingDialog Preload (Line 10)
```gdscript
const TrainingDialog = preload("res://src/ui/components/postbattle/TrainingSelectionDialog.tscn")
```
- **Location**: After existing preloads (WarPanel at line 9)
- **Purpose**: Enable instantiation of TrainingSelectionDialog scene

#### 2. Replaced `_add_training_content()` Stub (Lines 407-433)
**Before**: Simple placeholder label
```gdscript
func _add_training_content() -> void:
    """Add training content"""
    var label: Label = Label.new()
    label.text = "Invest credits in advanced training for crew members."
    step_content.add_child(label)
```

**After**: Full TrainingSelectionDialog integration
```gdscript
func _add_training_content() -> void:
    """Add training content with TrainingSelectionDialog integration"""
    if not step_content:
        return

    # Clear existing content
    for child in step_content.get_children():
        child.queue_free()

    # Instantiate training dialog
    var dialog = TrainingDialog.instantiate()
    if dialog:
        # Get current crew and credits
        var crew = _get_current_crew()
        var credits = _get_current_credits()

        # Setup with current crew data
        if dialog.has_method("setup"):
            dialog.setup(crew, credits)

        # Connect signals
        if dialog.has_signal("training_completed"):
            dialog.training_completed.connect(_on_training_completed)
        if dialog.has_signal("dialog_closed"):
            dialog.dialog_closed.connect(_on_training_closed)

        step_content.add_child(dialog)
```

#### 3. Added Helper Methods (Lines 1106-1125)

**`_get_current_crew() -> Array[Resource]`**
- Retrieves crew members from CampaignManager
- Converts to Resource array for dialog compatibility
- Returns empty array if CampaignManager unavailable

**`_get_current_credits() -> int`**
- Retrieves current credits from GameStateManager
- Uses `get_credits()` method
- Returns 0 if GameStateManager unavailable

#### 4. Added Signal Handlers (Lines 1127-1149)

**`_on_training_completed(character: Resource, training_type: String)`**
- Handles training completion from dialog
- Stores training result in `step_results[current_step]`
- Logs training completion to results log
- Captures character, training type, and timestamp

**`_on_training_closed()`**
- Handles dialog close signal
- **Design Decision**: Does NOT auto-advance to next step
- Allows user to train multiple characters before proceeding

## Signal Flow Architecture

### Training Step Activation (Step 9)
```
PostBattleSequence._show_current_step()
    └─> _add_step_specific_content(9)
        └─> _add_training_content()
            └─> TrainingDialog.instantiate()
            └─> dialog.setup(crew, credits)
            └─> Connect signals:
                - training_completed → _on_training_completed
                - dialog_closed → _on_training_closed
```

### Training Completion Flow
```
User interacts with TrainingDialog
    └─> dialog.training_completed.emit(character, training_type)
        └─> PostBattleSequence._on_training_completed()
            └─> Store in step_results[9]
            └─> Add to results log
            └─> [Dialog remains open for additional training]

User closes dialog
    └─> dialog.dialog_closed.emit()
        └─> PostBattleSequence._on_training_closed()
            └─> [No auto-advance - user clicks Next when ready]
```

## Data Flow

### Inputs to TrainingDialog
1. **Crew Array**: `Array[Resource]` from CampaignManager
   - Retrieved via `CampaignManager.get_crew_members()`
   - Filtered to only include Resource instances

2. **Credits**: `int` from GameStateManager
   - Retrieved via `GameStateManager.get_credits()`
   - Used to determine if enrollment fee (3 credits) can be paid

### Outputs from TrainingDialog
1. **training_completed Signal**
   - `character: Resource` - Character who completed training
   - `training_type: String` - Type of training completed (e.g., "pilot", "medical")

2. **Stored Results** (in `step_results[9]`)
   ```gdscript
   {
       "training_completed": [
           {
               "character": Resource,
               "training_type": String,
               "timestamp": int
           }
       ]
   }
   ```

## Integration Points

### Required Services
- **CampaignManager** (autoload): Provides crew data
  - Method: `get_crew_members() -> Array`

- **GameStateManager** (autoload): Provides credit tracking
  - Method: `get_credits() -> int`

### TrainingSelectionDialog Interface
- **Scene Path**: `res://src/ui/components/postbattle/TrainingSelectionDialog.tscn`
- **Setup Method**: `setup(crew: Array[Resource], current_credits: int)`
- **Signals**:
  - `training_completed(character: Resource, training_type: String)`
  - `dialog_closed()`

## Testing Checklist

### Manual Testing
- [ ] Navigate to Post-Battle Sequence Step 9 (Advanced Training)
- [ ] Verify TrainingSelectionDialog displays with crew list
- [ ] Verify credit display shows current campaign credits
- [ ] Select character and training type
- [ ] Click "Roll for Approval" button
- [ ] Verify training completion logged to results
- [ ] Train second character without advancing
- [ ] Click "Next" to proceed to Step 10 (Purchase Items)
- [ ] Verify training results persist in `step_results[9]`

### Edge Cases
- [ ] Empty crew roster (no characters to train)
- [ ] Insufficient credits for enrollment fee (3 credits)
- [ ] Multiple training completions in single step
- [ ] Dialog close without training

## Design Decisions

1. **No Auto-Advance on Training Completion**
   - User may want to train multiple characters
   - Dialog remains open for convenience
   - User manually clicks "Next" when finished

2. **Signal-Based Communication**
   - Follows Godot "call down, signal up" pattern
   - PostBattleSequence calls `setup()` on dialog
   - Dialog signals back via `training_completed` and `dialog_closed`

3. **Resource Array Conversion**
   - CampaignManager may return mixed types
   - Filter to only Resource instances for type safety
   - Prevents runtime errors in TrainingSelectionDialog

4. **Graceful Fallbacks**
   - Returns empty crew array if CampaignManager missing
   - Returns 0 credits if GameStateManager missing
   - Prevents crashes when services unavailable

## Related Files
- **Dialog Implementation**: `/src/ui/components/postbattle/TrainingSelectionDialog.gd` (342 lines)
- **Dialog Scene**: `/src/ui/components/postbattle/TrainingSelectionDialog.tscn`
- **Parent Sequence**: `/src/ui/screens/postbattle/PostBattleSequence.gd` (1149 lines)

## Next Steps
1. Manual testing in-game (Step 9 of Post-Battle)
2. Verify credit deduction on training enrollment
3. Verify character stat/skill updates from training
4. Integration with CharacterAdvancementService for XP costs

