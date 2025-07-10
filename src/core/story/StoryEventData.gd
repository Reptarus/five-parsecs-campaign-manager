@tool
extends Resource

## Story event data class for managing campaign story events
##
## Handles story event data including:
	## - Event configuration
## - Choices and outcomes
## - Event state tracking
## - Rewards and consequences

# Event identification
var event_id: String = ""
var event_type: int = 0

# Event content
var title: String = ""
var description: String = ""
var choices: Array[Dictionary] = []

# Event state
var _is_active: bool = false
var is_resolved: bool = false
var selected_choice: int = -1

# Outcomes
var rewards: Dictionary = {}
var consequences: Dictionary = {}

func _init() -> void:
	pass
func configure(config: Dictionary) -> void:
	if config.has("event_id"):
		event_id = config.event_id
	if config.has("event_type"):
		event_type = config.event_type
	if config.has("title"):
		title = config.title
	if config.has("description"):
		description = config.description
func add_choice(choice_data: Dictionary) -> void:
	choices.append(choice_data)

func select_choice(choice_index: int) -> void:
	if choice_index >= 0 and choice_index < (safe_call_method(choices, "size") as int):
		selected_choice = choice_index
		is_resolved = true
func get_choice(index: int) -> Dictionary:
	if index >= 0 and index < (safe_call_method(choices, "size") as int):
		return choices[index]
	return {}

func set_event_rewards(reward_data: Dictionary) -> void:
	rewards = reward_data.duplicate()
func set_event_consequences(consequence_data: Dictionary) -> void:
	consequences = consequence_data.duplicate()
func get_event_outcome() -> Dictionary:
	return {
		"is_resolved": is_resolved,
		"selected_choice": selected_choice,
		"rewards": rewards,
		"consequences": consequences
	}

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null