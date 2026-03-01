# StarsOfTheStoryPanel Usage Guide

## Overview
The `StarsOfTheStoryPanel` displays the four emergency abilities from Five Parsecs core rules p.67. It provides a visual interface for tracking and using one-time campaign abilities.

## Files Created
- `src/ui/components/campaign/StarsOfTheStoryPanel.gd` - Component logic
- `src/ui/components/campaign/StarsOfTheStoryPanel.tscn` - Scene file

## Quick Start

### 1. Add to Scene
```gdscript
# In your parent scene (e.g., CampaignDashboard.gd)
@onready var stars_panel: StarsOfTheStoryPanel = $StarsOfTheStoryPanel
```

### 2. Initialize with System
```gdscript
func _ready() -> void:
    # Create or get Stars system from GameState
    var stars_system = StarsOfTheStorySystem.new()
    stars_system.initialize(
        GameState.elite_ranks,     # Current elite ranks
        GameState.difficulty        # Campaign difficulty
    )
    
    # Initialize panel
    stars_panel.initialize(stars_system)
    
    # Connect signals
    stars_panel.ability_selected.connect(_on_star_ability_selected)
    stars_panel.ability_used.connect(_on_star_ability_used)
```

### 3. Handle Ability Selection
```gdscript
func _on_star_ability_selected(ability: int) -> void:
    # Show context-appropriate dialog based on ability type
    match ability:
        StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD:
            _show_injury_selection_dialog(ability)
        
        StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE:
            _show_character_selection_dialog(ability)
        
        StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO:
            _confirm_evacuation(ability)
        
        StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND:
            _use_rainy_day_fund(ability)

func _show_injury_selection_dialog(ability: int) -> void:
    # Show dialog to select character and injury to remove
    var dialog = InjurySelectionDialog.new()
    dialog.injuries_available = _get_injured_characters()
    dialog.confirmed.connect(func(character, injury):
        _use_star_ability(ability, {"character": character, "injury": injury})
    )
    add_child(dialog)
    dialog.popup_centered()

func _use_rainy_day_fund(ability: int) -> void:
    # Direct use - no dialog needed
    var result = stars_system.use_ability(ability, {})
    if result.success:
        GameState.credits += result.credits_gained
        stars_panel.refresh_display()  # Update UI
```

### 4. Handle Ability Used Callback
```gdscript
func _on_star_ability_used(ability: int, result: Dictionary) -> void:
    # Show notification
    var message = result.get("message", "Ability used!")
    _show_notification(message)
    
    # Update game state if needed
    if ability == StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND:
        GameState.credits += result.credits_gained
```

## Ability-Specific Context Requirements

### "It Wasn't That Bad!" (Remove Injury)
```gdscript
var context = {
    "character": character_resource,  # Character with injury
    "injury": injury_type             # Injury enum/string to remove
}
var result = stars_system.use_ability(
    StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD, 
    context
)
```

### "Dramatic Escape" (Survive Death)
```gdscript
var context = {
    "character": character_resource   # Character that would have died
}
var result = stars_system.use_ability(
    StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE, 
    context
)
# Result: character.current_hp = 1
```

### "It's Time To Go" (Emergency Evacuation)
```gdscript
var context = {
    "battle": battle_state_resource   # Current battle state
}
var result = stars_system.use_ability(
    StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO, 
    context
)
# Result: battle.evacuated = true, battle.held_field = false
```

### "Rainy Day Fund" (Gain Credits)
```gdscript
var context = {}  # No context needed
var result = stars_system.use_ability(
    StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND, 
    context
)
# Result: result.credits_gained = 1D6+5 (6-11 credits)
```

## Elite Ranks Bonus

Every 5 Elite Ranks grants ONE bonus use to ONE ability:
```gdscript
# When elite ranks increase
stars_system.update_elite_ranks(new_elite_ranks)
# Automatically distributes bonus uses
# Panel will update via star_ability_recharged signal
```

## Visual States

**Available Ability**:
- Green border (`COLOR_SUCCESS`)
- White text
- Enabled button
- Shows "1/1" or "2/2" uses

**Exhausted Ability**:
- Gray border (`COLOR_TEXT_DISABLED`)
- Gray text
- Disabled button
- Shows "0/1" or "0/2" uses

**Insanity Mode**:
- All abilities show "0/0"
- Warning message: "⚠ Stars of the Story NOT AVAILABLE (Insanity difficulty)"
- Red warning text

## Signals

### `ability_selected(ability: int)`
Emitted when user presses "Use Ability" button. Parent should show context-appropriate dialog before actually using the ability.

### `ability_used(ability: int, result: Dictionary)`
Emitted when ability is successfully used. Contains result details from `StarsOfTheStorySystem.use_ability()`.

## Responsive Behavior

- **Mobile Portrait**: 2-column grid (stacks vertically on very narrow screens)
- **Tablet/Desktop**: 2-column grid with larger cards
- Touch targets: 48dp minimum (buttons)
- Card minimum size: 280x160px

## Integration Points

### Campaign Dashboard
```gdscript
# Add to campaign_resources section
var stars_panel = preload("res://src/ui/components/campaign/StarsOfTheStoryPanel.tscn").instantiate()
resources_container.add_child(stars_panel)
stars_panel.initialize(GameState.stars_system)
```

### Battle UI (for Dramatic Escape / It's Time To Go)
```gdscript
# When character takes lethal damage
if character.would_die:
    if stars_system.can_use(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE):
        _show_dramatic_escape_prompt(character)
```

### Post-Battle UI (for It Wasn't That Bad!)
```gdscript
# After battle, if crew has injuries
if crew_has_injuries and stars_system.can_use(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD):
    stars_panel.refresh_display()  # Show available ability
```

## Save/Load Integration

The `StarsOfTheStorySystem` handles serialization:
```gdscript
# Save
var save_data = stars_system.serialize()
campaign_save_data["stars_system"] = save_data

# Load
var stars_system = StarsOfTheStorySystem.new()
stars_system.deserialize(campaign_save_data["stars_system"])
stars_panel.initialize(stars_system)
```

## Testing Checklist

- [ ] All 4 abilities display with correct names/descriptions
- [ ] Uses counter updates when ability used
- [ ] Button disables when uses = 0
- [ ] Visual state changes (green → gray)
- [ ] Elite Ranks bonus adds uses correctly
- [ ] Insanity mode shows all abilities as unavailable
- [ ] Signals emit with correct data
- [ ] Ability use validates context correctly
- [ ] Save/load preserves ability states
- [ ] Responsive layout works on mobile/tablet/desktop

## Common Integration Pattern

```gdscript
# Full integration example
class_name CampaignDashboard
extends Control

@onready var stars_panel: StarsOfTheStoryPanel = $StarsPanel

func _ready() -> void:
    # Get or create system
    if not GameState.has("stars_system"):
        GameState.stars_system = StarsOfTheStorySystem.new()
        GameState.stars_system.initialize(
            GameState.elite_ranks,
            GameState.difficulty
        )
    
    # Initialize panel
    stars_panel.initialize(GameState.stars_system)
    stars_panel.ability_selected.connect(_on_star_ability_selected)
    stars_panel.ability_used.connect(_on_star_ability_used)

func _on_star_ability_selected(ability: int) -> void:
    # Validate context before using
    var context = _prepare_ability_context(ability)
    if context.is_empty():
        _show_error("Cannot use ability - missing required context")
        return
    
    # Use ability
    var result = GameState.stars_system.use_ability(ability, context)
    if not result.success:
        _show_error(result.error)
    else:
        stars_panel.refresh_display()

func _on_star_ability_used(ability: int, result: Dictionary) -> void:
    # Apply effects and notify
    _apply_ability_effects(result)
    _show_notification(result.message)
```

## Design Philosophy

This component follows the project's design principles:

1. **Mobile-First**: Touch targets, responsive grid, readable text sizes
2. **Progressive Disclosure**: Abilities always visible, context shown on selection
3. **Glanceability**: Status visible at a glance (green/gray, uses counter)
4. **Offline-First**: No loading states, instant UI updates
5. **Game Enhancement**: Complements physical play, doesn't replace it
6. **Infinity Army Standard**: Could add keyword tooltips to descriptions (future enhancement)

## Future Enhancements

- [ ] Animation when ability becomes available/exhausted
- [ ] Keyword tooltips on ability descriptions
- [ ] Confirmation dialogs before critical abilities (It's Time To Go)
- [ ] Ability history log (when each was used)
- [ ] Player choice for Elite Ranks bonus distribution
- [ ] Achievement tracking (e.g., "Never used any Star ability")
