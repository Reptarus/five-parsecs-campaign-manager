class_name FPCM_RewardsPanel
extends Control

# TooltipManager removed - file does not exist

signal rewards_confirmed(selected_rewards: Array)

@onready var rewards_container := $RewardsContainer
@onready var confirm_button := $ConfirmButton

var available_rewards: Array
var selected_rewards: Array
var max_selections: int = 3

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true

func setup(rewards: Array, max_select: int = 3) -> void:
	available_rewards = rewards
	max_selections = max_select
	selected_rewards.clear()
	_update_display()

func _update_display() -> void:
	# Clear existing rewards
	for child in rewards_container.get_children():
		child.queue_free()

	# Add new reward options
	for reward in available_rewards:
		var reward_item = _create_reward_item(reward)
		rewards_container.add_child(reward_item)

	_update_confirm_button()

func _create_reward_item(reward: Dictionary) -> Control:
	var item := PanelContainer.new()
	var vbox := VBoxContainer.new()
	item.add_child(vbox)

	# Add reward type label
	var type_label := Label.new()
	type_label.text = _get_reward_type_text(reward.type)
	vbox.add_child(type_label)

	# Add reward _value/description
	var value_label := Label.new()
	value_label.text = _get_reward_value_text(reward)
	vbox.add_child(value_label)

	# Add selection checkbox
	var checkbox := CheckBox.new()
	checkbox.text = "Select"
	checkbox.toggled.connect(_on_reward_toggled.bind(reward))
	vbox.add_child(checkbox)

	# Tooltip functionality disabled (TooltipManager removed)
	# TODO: Re-implement tooltips when tooltip system is available

	return item

func _get_reward_type_text(type: String) -> String:
	match type:
		"credits":
			return "Credits"
		"item":
			return "Item"
		"reputation":
			return "Reputation"
		"experience":
			return "Experience"
		"skill":
			return "Skill Point"
		"trait":
			return "Character Trait"
		_:
			return "Unknown Reward"

func _get_reward_value_text(reward: Dictionary) -> String:
	match reward.type:
		"credits":
			return str(reward.amount) + " Credits"
		"item":
			return reward.item_name
		"reputation":
			return str(reward.amount) + " Reputation"
		"experience":
			return str(reward.amount) + " XP"
		"skill":
			return reward.skill_name
		"trait":
			return reward.trait_name
		_:
			return "Unknown"

func _get_reward_tooltip(reward: Dictionary) -> String:
	var tooltip: String = ""

	match reward.type:
		"credits":
			tooltip = "Credits earned from completing the mission"
		"reputation":
			tooltip = "Reputation gained with various factions"
		"item":
			if reward.has("description"):
				tooltip = reward.description
		"skill":
			if reward.has("description"):
				tooltip = reward.description
		"trait":
			if reward.has("description"):
				tooltip = reward.description

	if reward.has("rarity"):
		tooltip += "\nRarity: " + str(reward.rarity)

	return tooltip

func _on_reward_toggled(button_pressed: bool, reward: Dictionary) -> void:
	if button_pressed:
		if selected_rewards.size() < max_selections:
			selected_rewards.append(reward)
		else:
			# Uncheck the checkbox if we're at max selections
			var checkbox = get_viewport().gui_get_focus_owner()
			if checkbox is CheckBox:
				checkbox.button_pressed = false
	else:
		selected_rewards.erase(reward)

	_update_confirm_button()

func _update_confirm_button() -> void:
	confirm_button.disabled = selected_rewards.is_empty()

func _on_confirm_pressed() -> void:
	rewards_confirmed.emit(selected_rewards)

func get_selected_rewards() -> Array:
	return selected_rewards

