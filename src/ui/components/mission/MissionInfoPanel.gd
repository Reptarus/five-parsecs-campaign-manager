class_name FPCM_MissionInfoPanel
extends Control

signal mission_selected(mission_data: Dictionary)

@onready var title_label := $TitleLabel
@onready var description_label := $DescriptionLabel
@onready var difficulty_label := $DifficultyLabel
@onready var rewards_label := $RewardsLabel

func setup(mission_data: Dictionary) -> void:

	title_label.text = mission_data.get("title", "Unknown Mission")

	description_label.text = mission_data.get("description", "No description available")

	var difficulty = mission_data.get("difficulty", 1)
	difficulty_label.text = "Difficulty: " + _get_difficulty_text(difficulty)

	var rewards = mission_data.get("rewards", {})
	rewards_label.text = _format_rewards(rewards)

func _get_difficulty_text(difficulty: int) -> String:
	match difficulty:
		0: return "Easy"
		1: return "Normal"
		2: return "Hard"
		3: return "Very Hard"
		_: return "Unknown"

func _format_rewards(rewards: Dictionary) -> String:
	var reward_text := "Rewards:\n"

	if rewards.has("credits"):
		reward_text += "- %d Credits\n" % rewards.credits
	if rewards.has("items"):
		for item in rewards.items:
			reward_text += "- %s\n" % item.name
	if rewards.has("reputation"):
		reward_text += "- %d Reputation\n" % rewards.reputation

	return reward_text

func _on_accept_button_pressed() -> void:
	mission_selected.emit({
		"title": title_label.text,
		"description": description_label.text
	})

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null