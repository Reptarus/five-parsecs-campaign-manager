# QuestProgressTracker Component

**Location**: `src/ui/components/postbattle/QuestProgressTracker.gd` and `.tscn`

## Overview

Visual quest progress tracker for the Five Parsecs post-battle quest system (p.119). Displays quest progress rolls with color-coded outcomes, modifiers, and travel requirements.

## Features

- **Three Quest Outcomes** (Five Parsecs p.119):
  - Dead End (≤3): Amber warning, quest continues but no progress
  - Progress (4-6): Green success, gain 1 Quest Rumor
  - Finale Ready (7+): Blue accent with glow, finale next battle

- **Visual Roll Breakdown**: Shows D6 roll + Quest Rumors + modifiers
- **Battle Loss Modifier**: Displays -2 penalty from lost battles in red
- **Travel Requirements**: Shows if quest requires travel to continue
- **Progress Bar**: Visual quest advancement indicator
- **Signal Architecture**: Emits `quest_finale_ready` when quest reaches climax

## Signal Architecture

### Signals Emitted (Up Communication)

```gdscript
signal quest_finale_ready(quest_name: String)  # Quest reached finale (roll 7+)
```

### Public Interface (Call Down)

```gdscript
func setup(data: Dictionary) -> void
```

## Data Structure

```gdscript
{
    "quest_name": String,           # Quest title
    "base_roll": int,               # D6 result (1-6)
    "rumors": int,                  # Quest Rumors bonus
    "modifier": int,                # Battle outcome (-2 if lost, 0 if won)
    "total": int,                   # Final roll total
    "outcome": QuestOutcome,        # DEAD_END, PROGRESS, or FINALE_READY
    "travel_required": bool,        # Must travel to continue
    "progress_percent": float       # Visual progress (0-100)
}
```

## Quest Outcome Calculation

From Five Parsecs Campaign Rulebook p.119:

| Total Roll | Outcome | Effect |
|-----------|---------|--------|
| ≤3 | Dead End | Quest continues, no progress |
| 4-6 | Progress | Gain 1 Quest Rumor |
| 7+ | Finale Ready | Finale can trigger next battle |

**Modifiers**:
- Lost battle: -2 to roll
- Quest Rumors: +1 per rumor

## Usage Examples

### Example 1: Progress Made (Won Battle)

```gdscript
var tracker := QuestProgressTracker.new()
tracker.setup({
    "quest_name": "Hunt for the Crimson Star",
    "base_roll": 4,
    "rumors": 2,
    "modifier": 0,  # Won battle
    "total": 6,
    "outcome": QuestProgressTracker.QuestOutcome.PROGRESS,
    "travel_required": false,
    "progress_percent": 60.0
})
tracker.quest_finale_ready.connect(_on_quest_finale_ready)
add_child(tracker)
```

**Display**:
- Title: "Hunt for the Crimson Star"
- Roll: "D6 (4) + Rumors (2) = 6"
- Outcome: "✓ Progress! Gained 1 Quest Rumor" (green)
- Progress bar: 60%

### Example 2: Dead End (Lost Battle)

```gdscript
var tracker := QuestProgressTracker.new()
tracker.setup({
    "quest_name": "Retrieve the Lost Artifact",
    "base_roll": 5,
    "rumors": 0,
    "modifier": -2,  # Lost battle
    "total": 3,
    "outcome": QuestProgressTracker.QuestOutcome.DEAD_END,
    "travel_required": false,
    "progress_percent": 30.0
})
add_child(tracker)
```

**Display**:
- Title: "Retrieve the Lost Artifact"
- Roll: "D6 (5) + Rumors (0) = 3"
- Modifier: "-2 (Lost battle)" (red)
- Outcome: "⚠ Dead End - Quest continues, no progress" (amber)
- Progress bar: 30%

### Example 3: Finale Ready

```gdscript
var tracker := QuestProgressTracker.new()
tracker.setup({
    "quest_name": "Destroy the Unity Stronghold",
    "base_roll": 6,
    "rumors": 3,
    "modifier": 0,
    "total": 9,
    "outcome": QuestProgressTracker.QuestOutcome.FINALE_READY,
    "travel_required": false,
    "progress_percent": 100.0
})
tracker.quest_finale_ready.connect(_on_quest_finale_ready)
add_child(tracker)

func _on_quest_finale_ready(quest_name: String) -> void:
    print("Quest finale ready: %s - trigger climax battle!" % quest_name)
```

**Display**:
- Title: "Destroy the Unity Stronghold"
- Roll: "D6 (6) + Rumors (3) = 9"
- Outcome: "★ Finale Ready! Quest climax next battle" (blue with glow)
- Progress bar: 100%
- Signal: `quest_finale_ready("Destroy the Unity Stronghold")` emitted

### Example 4: Travel Required

```gdscript
var tracker := QuestProgressTracker.new()
tracker.setup({
    "quest_name": "Chase the Pirate Fleet",
    "base_roll": 4,
    "rumors": 1,
    "modifier": 0,
    "total": 5,
    "outcome": QuestProgressTracker.QuestOutcome.PROGRESS,
    "travel_required": true,
    "progress_percent": 50.0
})
add_child(tracker)
```

**Display**:
- Title: "Chase the Pirate Fleet"
- Roll: "D6 (4) + Rumors (1) = 5"
- Outcome: "✓ Progress! Gained 1 Quest Rumor" (green)
- Next step: "Must travel to continue quest"
- Progress bar: 50%

## Design System Integration

### Colors

- **Dead End**: `COLOR_WARNING` (#f59e0b - Amber)
- **Progress**: `COLOR_SUCCESS` (#10b981 - Green)
- **Finale Ready**: `COLOR_ACCENT` (#3b82f6 - Blue)
- **Lost Battle**: `#ef4444` (Red)

### Typography

- Quest Title: `FONT_SIZE_LG` (18px)
- Roll Details: `FONT_SIZE_MD` (16px)
- Modifier: `FONT_SIZE_SM` (14px)
- Next Step: `FONT_SIZE_SM` (14px)

### Spacing

- Panel padding: `SPACING_MD` (16px)
- Element separation: `SPACING_SM` (8px)

### Visual Effects

When finale is ready:
- Blue border glow (2px border)
- Enhanced panel styling
- Dice icon changes to blue

## Integration with Post-Battle Flow

```gdscript
# In PostBattleScreen.gd or similar
func _display_quest_results(quest_data: Dictionary) -> void:
    var tracker := QuestProgressTracker.new()
    tracker.setup(quest_data)
    tracker.quest_finale_ready.connect(_on_quest_finale_ready)
    $QuestResultsContainer.add_child(tracker)

func _on_quest_finale_ready(quest_name: String) -> void:
    # Unlock finale battle option
    _enable_finale_battle(quest_name)
    # Show notification
    _show_notification("Quest finale ready: %s" % quest_name)
```

## Testing

Run the example scene to see all outcomes:

```bash
godot --path "path/to/project" res://src/ui/components/postbattle/QuestProgressTracker_example.gd
```

## Quest System Rules Reference

From Five Parsecs Campaign Rulebook p.119:

1. **After Each Battle**: Roll D6 + Quest Rumors
2. **Battle Loss**: Apply -2 modifier
3. **Outcomes**:
   - ≤3: Dead end, no progress
   - 4-6: Gain 1 Quest Rumor
   - 7+: Finale ready
4. **Travel**: Some quests require travel between steps
5. **Finale**: Can trigger quest climax battle when ready

## Performance Notes

- Touch-friendly: 48px minimum height
- Responsive: Auto-wraps text on narrow screens
- Efficient: Programmatic layout, no scene dependencies
- Signal-based: Clean parent-child communication

## Future Enhancements

- [ ] Animated progress bar fill
- [ ] Sound effects for outcomes
- [ ] Quest history tracking
- [ ] Multiple quest display
- [ ] Quest failure conditions
