# StoryPointSpendingDialog - Usage Guide

## Overview

The `StoryPointSpendingDialog` is a Window-based dialog that allows players to spend story points during their campaign. It follows the Deep Space design system and matches the visual style of the campaign wizard panels.

## Files

- `/src/ui/components/story/StoryPointSpendingDialog.gd` - Dialog script
- `/src/ui/components/story/StoryPointSpendingDialog.tscn` - Scene file

## Core Rules Implementation (p.66-67)

The dialog implements all 5 story point spending options:

1. **Roll Twice, Pick One** - Roll on any table twice, choose preferred result (unlimited)
2. **Reroll Result** - Reroll any result, must accept new result (unlimited)
3. **Get 3 Credits** - Instantly gain 3 credits (once per turn)
4. **Get +3 XP** - Grant +3 XP to one character (once per turn)
5. **Extra Campaign Action** - Take additional campaign action (once per turn)

## Basic Usage

```gdscript
# 1. Preload the scene
const StoryPointDialog = preload("res://src/ui/components/story/StoryPointSpendingDialog.tscn")

# 2. Instantiate and add to scene tree
var dialog = StoryPointDialog.instantiate()
add_child(dialog)

# 3. Connect signals
dialog.option_selected.connect(_on_story_point_spent)
dialog.dialog_cancelled.connect(_on_dialog_cancelled)

# 4. Show the dialog with current state
var current_points = GameState.campaign.story_point_system.get_current_points()
var spending_status = GameState.campaign.story_point_system.get_turn_spending_status()
dialog.show_dialog(current_points, spending_status)
```

## Signal Handlers

```gdscript
func _on_story_point_spent(spend_type: int, details: Dictionary) -> void:
	# Use StoryPointSystem to process the spending
	var story_system = GameState.campaign.story_point_system

	# For GET_XP, you may need to show character picker first
	if spend_type == StoryPointSystem.SpendType.GET_XP:
		if details.get("needs_character_selection", false):
			_show_character_picker_for_xp()
			return

	# Attempt to spend the story point
	var success = story_system.spend_point(spend_type, details)

	if success:
		# Apply the effect based on spend_type
		match spend_type:
			StoryPointSystem.SpendType.GET_CREDITS:
				GameState.campaign.credits += 3
				show_notification("Gained 3 credits from story point!")

			StoryPointSystem.SpendType.GET_XP:
				var character_id = details.get("character_id")
				var character = GameState.campaign.get_character(character_id)
				if character:
					character.xp += 3
					show_notification("%s gained 3 XP!" % character.name)

			StoryPointSystem.SpendType.EXTRA_ACTION:
				# Grant extra campaign action
				_grant_extra_campaign_action()

			# ROLL_TWICE_PICK_ONE and REROLL_RESULT are handled by calling code
			# (used during table rolls, not as immediate effects)

func _on_dialog_cancelled() -> void:
	print("Story point spending cancelled")
```

## Integration with StoryPointSystem

The dialog is designed to work seamlessly with `StoryPointSystem`:

```gdscript
# Get current state from StoryPointSystem
var story_system = GameState.campaign.story_point_system
var current_points = story_system.get_current_points()
var spending_status = story_system.get_turn_spending_status()

# Show dialog
dialog.show_dialog(current_points, spending_status)

# Process spending (in signal handler)
var success = story_system.spend_point(spend_type, details)
```

## Spending Status Dictionary

The `spending_status` parameter expects a Dictionary with these keys:

```gdscript
{
	"credits_available": bool,  # Can still spend for credits this turn?
	"xp_available": bool,       # Can still spend for XP this turn?
	"action_available": bool    # Can still spend for extra action this turn?
}
```

This controls which buttons are enabled/disabled based on per-turn limits.

## Character Selection for XP

When `GET_XP` is selected, the dialog emits with `details = {"needs_character_selection": true}`. You should:

1. Show a character picker dialog
2. Once character is selected, call `story_system.spend_point()` with character details:

```gdscript
func _show_character_picker_for_xp() -> void:
	var picker = CharacterPickerDialog.new()
	add_child(picker)
	picker.character_selected.connect(_on_character_selected_for_xp)
	picker.show_dialog()

func _on_character_selected_for_xp(character_id: String) -> void:
	var story_system = GameState.campaign.story_point_system
	var details = {"character_id": character_id}

	var success = story_system.spend_point(StoryPointSystem.SpendType.GET_XP, details)

	if success:
		var character = GameState.campaign.get_character(character_id)
		character.xp += 3
		show_notification("%s gained 3 XP!" % character.name)
```

## Design System Compliance

The dialog uses the same design constants as `BaseCampaignPanel`:

- **Spacing**: 8px grid (XS=4, SM=8, MD=16, LG=24, XL=32)
- **Touch Targets**: Minimum 48dp, comfortable 56dp
- **Colors**: Deep Space theme (base, elevated, accent, text)
- **Typography**: Font sizes from XS (11px) to XL (24px)

## Accessibility Features

- Touch-friendly button sizes (48dp minimum)
- Color-coded difficulty badges
- Clear visual hierarchy
- Disabled state styling for unavailable options
- Informative limit badges ("Once per turn" vs "Unlimited uses")

## Example Integration in CampaignDashboard

```gdscript
# CampaignDashboard.gd
const StoryPointDialog = preload("res://src/ui/components/story/StoryPointSpendingDialog.tscn")

var story_point_dialog: StoryPointSpendingDialog

func _ready() -> void:
	# Create dialog once
	story_point_dialog = StoryPointDialog.instantiate()
	add_child(story_point_dialog)
	story_point_dialog.option_selected.connect(_on_story_point_spent)
	story_point_dialog.dialog_cancelled.connect(_on_story_dialog_cancelled)

func _on_spend_story_point_button_pressed() -> void:
	var story_system = GameState.campaign.story_point_system
	var current_points = story_system.get_current_points()
	var spending_status = story_system.get_turn_spending_status()

	story_point_dialog.show_dialog(current_points, spending_status)

func _on_story_point_spent(spend_type: int, details: Dictionary) -> void:
	var story_system = GameState.campaign.story_point_system

	# Handle XP character selection
	if spend_type == StoryPointSystem.SpendType.GET_XP:
		if details.get("needs_character_selection", false):
			_show_character_picker_for_xp()
			return

	# Process spending
	var success = story_system.spend_point(spend_type, details)

	if success:
		_apply_story_point_effect(spend_type, details)
		_refresh_story_point_display()
```

## Testing

You can test the dialog by:

1. Opening the scene in Godot editor
2. Running the scene (F6)
3. Calling `show_dialog(5, {"credits_available": true, "xp_available": false, "action_available": true})`

This will show the dialog with 5 story points, credits available, XP already spent this turn, and extra action available.
