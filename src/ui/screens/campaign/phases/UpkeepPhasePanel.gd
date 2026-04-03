extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/UpkeepPhasePanel.gd")

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var upkeep_cost_label: Label = $VBoxContainer/UpkeepCostLabel
@onready var crew_costs_panel: PanelContainer = $VBoxContainer/CrewCostsPanel
@onready var crew_costs_label: Label = $VBoxContainer/CrewCostsPanel/VBoxContainer/Label
@onready var crew_list: ItemList = $VBoxContainer/CrewCostsPanel/VBoxContainer/CrewList
@onready var resources_panel: PanelContainer = $VBoxContainer/ResourcesPanel
@onready var resources_label: Label = $VBoxContainer/ResourcesPanel/VBoxContainer/Label
@onready var resources_list: ItemList = $VBoxContainer/ResourcesPanel/VBoxContainer/ResourcesList
@onready var pay_upkeep_button: Button = $VBoxContainer/PayUpkeepButton

var total_upkeep_cost: int = 0

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_section_label(upkeep_cost_label)
	_style_sub_panel(crew_costs_panel)
	_style_section_label(crew_costs_label)
	_style_item_list(crew_list)
	_style_sub_panel(resources_panel)
	_style_section_label(resources_label)
	_style_item_list(resources_list)
	_style_phase_button(pay_upkeep_button, true)
	_style_button_disabled(pay_upkeep_button)
	if pay_upkeep_button:
		pay_upkeep_button.pressed.connect(_on_pay_upkeep_pressed)
		_setup_validation_hint(pay_upkeep_button)

func setup_phase() -> void:
	super.setup_phase()
	_process_injury_recovery()
	_update_crew_list()
	_calculate_upkeep()
	_update_resources_list()

func _get_crew_members() -> Array:
	var campaign = game_state.campaign if game_state else null
	if not campaign:
		return []
	if campaign.has_method("get_active_crew_members"):
		return campaign.get_active_crew_members()
	elif "crew_data" in campaign:
		return campaign.crew_data.get("members", [])
	return []

func _process_injury_recovery() -> void:
	## Decrement recovery_turns for injured crew. Transition to ACTIVE when healed.
	var members = _get_crew_members()
	for member in members:
		if not member is Dictionary:
			continue
		var status: String = member.get("status", "ACTIVE")
		if status not in ["INJURED", "RECOVERING"]:
			continue
		var injuries_arr: Array = member.get("injuries", [])
		# Decrement recovery counters, remove healed injuries
		for i in range(injuries_arr.size() - 1, -1, -1):
			var injury: Dictionary = injuries_arr[i]
			var turns_left: int = injury.get("recovery_turns", 0)
			if turns_left > 0:
				injury["recovery_turns"] = turns_left - 1
			if injury.get("recovery_turns", 0) <= 0:
				injury["healed"] = true
				injuries_arr.remove_at(i)
		# Update status if all injuries resolved
		if injuries_arr.is_empty():
			member["status"] = "ACTIVE"
			member["in_sick_bay"] = false
		else:
			member["status"] = "RECOVERING"

func _update_crew_list() -> void:
	if not crew_list:
		return
	crew_list.clear()
	var members = _get_crew_members()
	if members.is_empty():
		crew_list.add_item("No Crew Members")
		return
	for member in members:
		var name_str: String = ""
		if member is Dictionary:
			name_str = member.get("character_name", member.get("name", "Unknown"))
			var member_status: String = member.get("status", "ACTIVE")
			if member_status in ["INJURED", "RECOVERING"]:
				var injuries_arr: Array = member.get("injuries", [])
				var injury_text: String = ""
				for inj in injuries_arr:
					var t: String = inj.get("type", "Wound")
					var r: int = inj.get("recovery_turns", 0)
					injury_text += "%s (%d turns) " % [t, r]
				name_str += " [RECOVERING: %s]" % injury_text.strip_edges()
		elif "character_name" in member:
			name_str = member.character_name
		else:
			name_str = str(member)
		crew_list.add_item(name_str)

func _calculate_upkeep() -> void:
	# Core Rules p.76: 1 credit for 4-6 crew, +1 per crew member past 6
	# Crew in Sick Bay don't count toward upkeep cost
	var members = _get_crew_members()
	var active_count: int = 0
	for member in members:
		var in_sick_bay: bool = false
		if member is Dictionary:
			in_sick_bay = member.get("in_sick_bay", false)
		elif member.has_method("get") and member.get("in_sick_bay"):
			in_sick_bay = true
		if not in_sick_bay:
			active_count += 1
	if active_count < 4:
		total_upkeep_cost = 0
	else:
		total_upkeep_cost = 1 + max(0, active_count - 6)
	if upkeep_cost_label:
		upkeep_cost_label.text = "Total Upkeep Cost: %s" % _format_credits_long(total_upkeep_cost)

func _update_resources_list() -> void:
	if not resources_list:
		return
	resources_list.clear()
	var campaign = game_state.campaign if game_state else null
	var credits: int = campaign.credits if campaign else 0
	resources_list.add_item("Credits: %s" % _format_credits(credits))
	if pay_upkeep_button:
		var can_pay: bool = credits >= total_upkeep_cost
		pay_upkeep_button.disabled = not can_pay
		if not can_pay:
			var msg := "Not enough credits — need %s, have %s" \
				% [_format_credits(total_upkeep_cost), _format_credits(credits)]
			_show_validation_hint(msg)
		else:
			_hide_validation_hint()

func _on_pay_upkeep_pressed() -> void:
	var campaign = game_state.campaign if game_state else null
	if campaign and "credits" in campaign:
		campaign.credits -= total_upkeep_cost
	# Log upkeep to CampaignJournal
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry") and total_upkeep_cost > 0:
		var turn_num: int = 0
		if campaign and "progress_data" in campaign:
			turn_num = campaign.progress_data.get("turns_played", 0)
		journal.create_entry({
			"turn_number": turn_num,
			"type": "purchase",
			"auto_generated": true,
			"title": "Upkeep Paid",
			"description": "Paid %d credits upkeep for %d crew members." % [total_upkeep_cost, _get_crew_members().size()],
			"mood": "neutral",
			"tags": ["upkeep"],
			"stats": {"credits_spent": total_upkeep_cost},
		})
	_update_resources_list()
	complete_phase()

func validate_phase_requirements() -> bool:
	var campaign = game_state.campaign if game_state else null
	if not campaign:
		return false
	return campaign.credits >= total_upkeep_cost

func get_phase_data() -> Dictionary:
	return {
		"total_upkeep_cost": total_upkeep_cost,
		"crew_count": _get_crew_members().size(),
		"can_pay": validate_phase_requirements()
	}
