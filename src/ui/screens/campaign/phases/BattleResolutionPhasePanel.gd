extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/BattleResolutionPhasePanel.gd")

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var results_container: RichTextLabel = $VBoxContainer/BattleSummary
@onready var objectives_label: Label = $VBoxContainer/ObjectivesLabel
@onready var objectives_container: ItemList = $VBoxContainer/ObjectivesList
@onready var casualties_label: Label = $VBoxContainer/CasualtiesLabel
@onready var casualty_container: ItemList = $VBoxContainer/CasualtiesList
@onready var rewards_label: Label = $VBoxContainer/RewardsLabel
@onready var rewards_list: ItemList = $VBoxContainer/RewardsList
@onready var complete_button: Button = $VBoxContainer/CompleteButton

var completed_objectives: Array = []
var failed_objectives: Array = []
var casualties: Array = []
var rewards: Dictionary = {}
var battle_state: Dictionary = {}

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_rich_text(results_container)
	_style_section_label(objectives_label)
	_style_item_list(objectives_container)
	_style_section_label(casualties_label)
	_style_item_list(casualty_container)
	_style_section_label(rewards_label)
	_style_item_list(rewards_list)
	_style_phase_button(complete_button, true)
	if complete_button:
		complete_button.pressed.connect(_on_complete_button_pressed)

func _get_campaign_safe():
	return game_state.campaign if game_state else null

func setup_phase() -> void:
	super.setup_phase()
	var campaign = _get_campaign_safe()
	if campaign and "battle_state" in campaign:
		battle_state = campaign.battle_state
	else:
		battle_state = {}
	_resolve_battle()
	_calculate_rewards()
	_update_ui()

func _resolve_battle() -> void:
	completed_objectives.clear()
	failed_objectives.clear()
	casualties.clear()
	var campaign = _get_campaign_safe()
	if not campaign:
		return
	var mission: Dictionary = {}
	if "current_mission" in campaign and campaign.current_mission is Dictionary:
		mission = campaign.current_mission
	var crew_members: Array = battle_state.get("crew_members", [])

	for objective in mission.get("objectives", []):
		var obj_dict: Dictionary = objective if objective is Dictionary else {"description": str(objective)}
		var success_chance: float = 0.7 + 0.05 * crew_members.size()
		success_chance -= 0.1 * obj_dict.get("difficulty", 1)
		success_chance = clampf(success_chance, 0.1, 0.9)
		if randf() <= success_chance:
			completed_objectives.append(obj_dict)
		else:
			failed_objectives.append(obj_dict)

func _calculate_rewards() -> void:
	rewards.clear()
	var campaign = _get_campaign_safe()
	var mission: Dictionary = {}
	if campaign and "current_mission" in campaign and campaign.current_mission is Dictionary:
		mission = campaign.current_mission
	rewards["credits"] = mission.get("reward_credits", 100)
	for objective in completed_objectives:
		rewards["credits"] += objective.get("bonus_credits", 50)
	if failed_objectives.is_empty():
		rewards["credits"] += mission.get("completion_bonus", 200)
	rewards["credits"] -= casualties.size() * 50
	rewards["items"] = []

func _update_ui() -> void:
	_update_battle_summary()
	_update_objectives()
	_update_casualties()

func _update_battle_summary() -> void:
	if not results_container:
		return
	var summary: String = "[b]Battle Summary[/b]\n\n"

	# DLC: Show battle type if non-conventional
	var bt: String = battle_state.get("battle_type", "")
	if not bt.is_empty() and bt != "conventional":
		var bt_label: String = bt.replace("_", " ").capitalize()
		summary += "[b]Battle Type:[/b] [color=#4FC3F7]%s[/color]\n" % bt_label

	summary += "Objectives Completed: %d/%d\n" % [
		completed_objectives.size(),
		completed_objectives.size() + failed_objectives.size()
	]
	summary += "Casualties: %d\n" % casualties.size()

	# DLC: Show escalation effect if one occurred
	var esc: Dictionary = battle_state.get("escalation_effect", {})
	if not esc.is_empty():
		summary += "\n[b]Escalation:[/b]\n"
		summary += "[color=#D97706]%s[/color]\n" % esc.get(
			"instruction", "Unknown effect")

	summary += "\n[b]Rewards:[/b]\n"
	summary += "Credits: %s\n" % _format_credits(
		rewards.get("credits", 0))
	results_container.text = summary

func _update_objectives() -> void:
	if not objectives_container:
		return
	objectives_container.clear()
	for objective in completed_objectives:
		var desc: String = objective.get("description", "Objective")
		objectives_container.add_item("Completed: " + desc)
	for objective in failed_objectives:
		var desc: String = objective.get("description", "Objective")
		objectives_container.add_item("Failed: " + desc)

func _update_casualties() -> void:
	if not casualty_container:
		return
	casualty_container.clear()
	if casualties.is_empty():
		casualty_container.add_item("No casualties")
		return
	for casualty in casualties:
		var name_str: String = "Unknown"
		if casualty.member is Dictionary:
			name_str = casualty.member.get("character_name", "Unknown")
		elif "character_name" in casualty.member:
			name_str = casualty.member.character_name
		casualty_container.add_item("%s - %s" % [name_str, casualty.get("type", "INJURY")])

func _apply_battle_results() -> void:
	var campaign = _get_campaign_safe()
	if not campaign:
		return
	if "credits" in campaign:
		campaign.credits += rewards.get("credits", 0)

func _on_complete_button_pressed() -> void:
	_apply_battle_results()
	complete_phase()

func validate_phase_requirements() -> bool:
	return game_state != null and _get_campaign_safe() != null

func get_phase_data() -> Dictionary:
	return {
		"completed_objectives": completed_objectives,
		"failed_objectives": failed_objectives,
		"casualties": casualties,
		"rewards": rewards
	}
