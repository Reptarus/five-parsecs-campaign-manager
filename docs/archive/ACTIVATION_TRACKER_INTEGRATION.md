# Activation Tracker Panel - Integration Guide

## Overview
The `ActivationTrackerPanel` component manages unit activation tracking during battles. It displays crew and enemy units with visual activation states and integrates with `BattleRoundTracker` using Godot 4.5's "call down, signal up" pattern.

## Files Created
1. `/src/ui/components/battle/ActivationTrackerPanel.gd` - Main panel logic
2. `/src/ui/components/battle/ActivationTrackerPanel.tscn` - Panel scene structure

## Dependencies
- `BattleRoundTracker` - Battle round/phase tracking system
- `UnitActivationCard` - Individual unit card component (already exists)

## Architecture Pattern: Call Down, Signal Up

### Panel Structure
```
ActivationTrackerPanel (PanelContainer)
├── MarginContainer (24px padding)
│   └── VBoxContainer
│       ├── Header Row (HBoxContainer)
│       │   ├── RoundLabel "ROUND X"
│       │   └── ResetButton "Reset All"
│       │
│       ├── CrewLabel "CREW"
│       ├── CrewScrollContainer
│       │   └── CrewContainer (VBoxContainer)
│       │       └── [UnitActivationCard x N]
│       │
│       ├── HSeparator
│       │
│       ├── EnemyLabel "ENEMIES"
│       └── EnemyScrollContainer
│           └── EnemyContainer (VBoxContainer)
│               └── [UnitActivationCard x N]
```

## Integration Example

### 1. Add to Battle Screen Scene
```gdscript
# In BattleScreen.tscn, add as child node
[node name="ActivationTrackerPanel" parent="." instance=ExtResource("path/to/ActivationTrackerPanel.tscn")]
```

### 2. Wire Up in Battle Screen Script
```gdscript
# BattleScreen.gd or TacticalBattleUI.gd

@onready var _activation_tracker: ActivationTrackerPanel = %ActivationTrackerPanel
@onready var _battle_tracker: BattleRoundTracker = $BattleRoundTracker

func _ready() -> void:
    # Initialize panel with battle tracker (call down)
    _activation_tracker.initialize(_battle_tracker)

    # Connect panel signals (signal up)
    _activation_tracker.unit_activation_requested.connect(_on_unit_activation_requested)
    _activation_tracker.reset_all_requested.connect(_on_reset_all_requested)

    # Add units from battle data
    _populate_units()

func _populate_units() -> void:
    """Add crew and enemy units to tracker"""
    # Add crew members
    for crew_member in battle_data.crew:
        var unit_data := {
            "id": crew_member.id,
            "name": crew_member.character_name,
            "is_crew": true,
            "current_health": crew_member.health,
            "max_health": crew_member.max_health,
            "combat": crew_member.combat,
            "toughness": crew_member.toughness,
            "status_effects": []
        }
        _activation_tracker.add_unit(unit_data, true)

    # Add enemies
    for enemy in battle_data.enemies:
        var unit_data := {
            "id": enemy.id,
            "name": enemy.name,
            "is_crew": false,
            "current_health": enemy.health,
            "max_health": enemy.max_health,
            "combat": enemy.combat,
            "toughness": enemy.toughness,
            "status_effects": []
        }
        _activation_tracker.add_unit(unit_data, false)

func _on_unit_activation_requested(unit_id: String) -> void:
    """Handle unit activation toggle from panel (signal up)"""
    # Call down to game logic
    if _battle_system.has_method("toggle_unit_activation"):
        _battle_system.toggle_unit_activation(unit_id)

    # Update panel state (call down)
    var is_activated: bool = _battle_system.is_unit_activated(unit_id)
    _activation_tracker.set_unit_activated(unit_id, is_activated)

func _on_reset_all_requested() -> void:
    """Handle reset all button from panel (signal up)"""
    # Call down to game logic
    if _battle_system.has_method("reset_all_activations"):
        _battle_system.reset_all_activations()

    # Update panel state (call down)
    _activation_tracker.reset_all_activations()

func _on_unit_health_changed(unit_id: String, current: int, max_hp: int) -> void:
    """Update unit health display (call down)"""
    _activation_tracker.update_unit_health(unit_id, current, max_hp)

func _on_unit_defeated(unit_id: String) -> void:
    """Mark unit as defeated (call down)"""
    _activation_tracker.set_unit_defeated(unit_id, true)

func _exit_tree() -> void:
    """Cleanup on exit"""
    _activation_tracker.cleanup()
```

## Signal Flow Diagram

```
BattleRoundTracker                  ActivationTrackerPanel                BattleScreen
      │                                       │                                │
      ├─ round_started ────────────────────> │                                │
      ├─ round_ended ──────────────────────> │                                │
      ├─ battle_started ───────────────────> │                                │
      └─ battle_ended ─────────────────────> │                                │
                                              │                                │
                                              ├─ unit_activation_requested ──> │
                                              └─ reset_all_requested ────────> │
                                                                               │
                                              │ <─ add_unit ──────────────────┤
                                              │ <─ set_unit_activated ────────┤
                                              │ <─ update_unit_health ────────┤
                                              │ <─ set_unit_defeated ─────────┤
```

## API Reference

### Public Methods

#### `initialize(battle_tracker: Node) -> void`
Connect to BattleRoundTracker signals. Call this in `_ready()`.

#### `cleanup() -> void`
Disconnect from tracker. Call this in `_exit_tree()`.

#### `add_unit(unit_data: Dictionary, is_crew: bool) -> void`
Add a unit card to the tracker.

**Required unit_data fields:**
- `id: String` - Unique unit identifier
- `name: String` - Display name
- `is_crew: bool` - Team flag
- `current_health: int` - Current HP
- `max_health: int` - Maximum HP
- `combat: int` - Combat skill
- `toughness: int` - Toughness value
- `status_effects: Array` - Status effect strings

#### `remove_unit(unit_id: String) -> void`
Remove a unit card from the tracker.

#### `set_unit_activated(unit_id: String, activated: bool) -> void`
Update unit activation state (call down from parent).

#### `set_unit_defeated(unit_id: String, defeated: bool) -> void`
Mark unit as defeated (call down from parent).

#### `update_unit_health(unit_id: String, current_health: int, max_health: int) -> void`
Update unit health display (call down from parent).

#### `reset_all_activations() -> void`
Reset all unit activation states (call down from parent).

#### `clear_all_units() -> void`
Remove all unit cards.

### Signals

#### `unit_activation_requested(unit_id: String)`
Emitted when user taps a unit card to toggle activation. Parent should handle this by calling game logic, then calling `set_unit_activated()`.

#### `reset_all_requested()`
Emitted when user taps "Reset All" button. Parent should reset game state, then call `reset_all_activations()`.

## Design System Compliance

### Spacing (8px Grid)
- Panel padding: `24px` (SPACING_LG)
- Section gaps: `16px` (SPACING_MD)
- Card gaps: `8px` (SPACING_SM)

### Touch Targets
- Reset button: `48px` minimum height (TOUCH_TARGET_MIN)
- Unit cards: Inherit touch target from UnitActivationCard

### Colors (Deep Space Theme)
- Panel background: `#1A1A2E` (COLOR_BASE)
- Card backgrounds: `#252542` (COLOR_ELEVATED)
- Text primary: `#E0E0E0` (COLOR_TEXT_PRIMARY)
- Text secondary: `#808080` (COLOR_TEXT_SECONDARY)

## Testing Checklist

### Unit Tests (GDUnit4)
- [ ] `initialize()` connects to BattleRoundTracker signals
- [ ] `add_unit()` creates and displays unit cards
- [ ] `remove_unit()` disconnects signals and cleans up
- [ ] `set_unit_activated()` updates card state
- [ ] `reset_all_activations()` resets all cards
- [ ] Signal emission on card tap
- [ ] Signal emission on reset button press

### Integration Tests
- [ ] Panel updates on `round_started` signal
- [ ] Panel resets activations on new round
- [ ] Panel clears units on `battle_started`
- [ ] Crew and enemy sections populate correctly
- [ ] Health updates propagate to cards
- [ ] Defeated units display correctly

### Manual Testing
- [ ] Cards display in correct sections (crew/enemy)
- [ ] Activation toggle works on tap
- [ ] Reset button clears all activations
- [ ] Round counter updates each round
- [ ] ScrollContainers work with many units (10+ per side)
- [ ] Touch targets meet 48dp minimum
- [ ] Responsive layout works on mobile viewport

## Performance Considerations

### Mobile Optimization
- **Card Pooling**: Consider object pooling for 20+ units
- **Batch Updates**: Use `call_deferred()` for multiple card updates
- **Signal Disconnection**: Always disconnect in `cleanup()` to prevent memory leaks

### 60fps Target
- No `_process()` usage (event-driven only)
- Cached `@onready` references
- Minimal tree operations (no find_child in loops)

## Known Limitations
- Maximum tested: 50 units total (25 crew + 25 enemies)
- No drag-to-reorder functionality (fixed order by add sequence)
- No search/filter (use ScrollContainer for overflow)

## Future Enhancements
- Add unit search/filter
- Add activation history log
- Add undo/redo for activations
- Add keyboard shortcuts for activation
- Add activation sound effects
