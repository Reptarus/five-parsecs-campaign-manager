extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/CampaignPhasePanel.gd")

signal mission_selected(mission_data)
signal mission_accepted(mission_data)
signal location_changed(location_data: Dictionary)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var location_label: Label = $VBoxContainer/LocationLabel
@onready var location_description: RichTextLabel = $VBoxContainer/LocationDescription
@onready var mission_label: Label = $VBoxContainer/MissionLabel
@onready var mission_container: VBoxContainer = $VBoxContainer/MissionContainer
@onready var mission_details: RichTextLabel = $VBoxContainer/MissionDetails
@onready var accept_button: Button = $VBoxContainer/AcceptButton

var campaign_manager: Node
var world_economy: Node
var current_location: Dictionary = {}
var available_missions: Array = []
var selected_mission = null

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_section_label(location_label)
	_style_rich_text(location_description)
	_style_section_label(mission_label)
	_style_rich_text(mission_details)
	_style_phase_button(accept_button, true)

	campaign_manager = get_node_or_null("/root/CampaignManager")
	world_economy = get_node_or_null("/root/WorldEconomyManager")

	if campaign_manager:
		if campaign_manager.has_signal("mission_available"):
			campaign_manager.mission_available.connect(_on_mission_available)
	if world_economy:
		if world_economy.has_signal("economy_updated"):
			world_economy.economy_updated.connect(_on_economy_updated)

	if accept_button:
		accept_button.pressed.connect(_on_accept_pressed)
		accept_button.disabled = true
		_style_button_disabled(accept_button)
		_setup_validation_hint(accept_button)

func setup_phase() -> void:
	super.setup_phase()
	available_missions.clear()
	selected_mission = null
	_check_location()
	_generate_missions()
	_update_ui()

func _check_location() -> void:
	if game_state and game_state.has_method("get_current_location"):
		current_location = game_state.get_current_location()
	else:
		var campaign = game_state.campaign if game_state else null
		if campaign and "world_data" in campaign and not campaign.world_data.is_empty():
			current_location = {
				"name": campaign.world_data.get("name", "Unknown"),
				"description": campaign.world_data.get("description", ""),
				"threat_level": campaign.world_data.get("threat_level", 1)
			}
		else:
			current_location = {
				"name": "Unknown Location",
				"description": "No location data available",
				"threat_level": 1
			}
	location_changed.emit(current_location)

func _generate_missions() -> void:
	available_missions.clear()
	if campaign_manager and campaign_manager.has_method("generate_available_missions"):
		campaign_manager.generate_available_missions()
		if campaign_manager.has_method("get_available_missions"):
			available_missions = campaign_manager.get_available_missions()

func _update_ui() -> void:
	if location_label:
		location_label.text = current_location.get("name", "Unknown")
	if location_description:
		var desc: String = current_location.get("description", "")
		desc += "\n\n[b]Threat Level:[/b] %d" % current_location.get("threat_level", 1)
		location_description.text = desc

	if mission_container:
		for child in mission_container.get_children():
			child.queue_free()
		for mission in available_missions:
			var button = Button.new()
			var title: String = ""
			if mission is Dictionary:
				title = mission.get("title", "Unknown Mission")
			elif "title" in mission:
				title = mission.title
			button.text = title
			_style_phase_button(button)
			button.pressed.connect(_on_mission_button_pressed.bind(mission))
			mission_container.add_child(button)

	if mission_details and not selected_mission:
		mission_details.text = "Select a mission to view details"
	if accept_button:
		var no_mission: bool = selected_mission == null
		accept_button.disabled = no_mission
		if no_mission:
			_show_validation_hint("Select a mission to accept")
		else:
			_hide_validation_hint()

func _on_mission_button_pressed(mission) -> void:
	selected_mission = mission
	if mission_details:
		var title: String = ""
		var desc: String = ""
		if mission is Dictionary:
			title = mission.get("title", "Unknown")
			desc = mission.get("description", "")
		elif "title" in mission:
			title = mission.title
			desc = mission.description if "description" in mission else ""
		mission_details.text = "[b]%s[/b]\n\n%s" % [title, desc]
	if accept_button:
		accept_button.disabled = false
	mission_selected.emit(mission)

func _on_accept_pressed() -> void:
	if not selected_mission:
		return
	if campaign_manager and campaign_manager.has_method("start_mission"):
		campaign_manager.start_mission(selected_mission)
	mission_accepted.emit(selected_mission)
	complete_phase()

func _on_mission_available(mission) -> void:
	if not mission in available_missions:
		available_missions.append(mission)
		_update_ui()

func _on_economy_updated() -> void:
	_update_ui()

func validate_phase_requirements() -> bool:
	return game_state != null

func get_phase_data() -> Dictionary:
	return {
		"current_location": current_location,
		"available_missions": available_missions,
		"selected_mission": selected_mission,
	}
