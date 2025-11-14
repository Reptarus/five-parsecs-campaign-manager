extends Node
class_name FallbackCampaignManager

## Fallback Campaign Manager
## Minimal implementation for UI components that need CampaignManager fallback
## Used when CampaignManager autoload is not available

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals
signal campaign_turn_completed(turn_number: int)
signal campaign_progress_updated(progress: Dictionary)

# Properties
var game_state: Node = null
var campaign_system: Node = null

func _init():
	# Create minimal campaign system stub
	campaign_system = Node.new()
	campaign_system.name = "FallbackCampaignSystem"

	# Add signals to stub
	if not campaign_system.has_signal("campaign_turn_completed"):
		campaign_system.add_user_signal("campaign_turn_completed", [{"name": "turn_number", "type": TYPE_INT}])
	if not campaign_system.has_signal("campaign_progress_updated"):
		campaign_system.add_user_signal("campaign_progress_updated", [{"name": "progress", "type": TYPE_DICTIONARY}])

	# Create minimal game state stub
	game_state = Node.new()
	game_state.name = "FallbackGameState"

	# Add minimal properties
	game_state.set_meta("campaign_victory_condition", GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20 if GlobalEnums else 0)
	game_state.set_meta("current_turn", 0)
	game_state.set_meta("campaign_name", "Fallback Campaign")

func get_current_turn() -> int:
	if game_state:
		return game_state.get_meta("current_turn", 0)
	return 0

func get_victory_condition():
	if game_state:
		return game_state.get_meta("campaign_victory_condition", 0)
	return 0
