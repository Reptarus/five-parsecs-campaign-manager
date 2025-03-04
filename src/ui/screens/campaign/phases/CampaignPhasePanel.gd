extends BasePhasePanel
class_name FPCM_CampaignPhasePanel

const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const WorldEconomyManager = preload("res://src/core/managers/WorldEconomyManager.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")

signal mission_selected(mission_data: StoryQuestData)
signal mission_accepted(mission_data: StoryQuestData)
signal location_changed(location_data: Dictionary)

@onready var location_label: Label = $VBoxContainer/LocationLabel
@onready var location_description: RichTextLabel = $VBoxContainer/LocationDescription
@onready var mission_container: VBoxContainer = $VBoxContainer/MissionContainer
@onready var mission_details: RichTextLabel = $VBoxContainer/MissionDetails
@onready var accept_button: Button = $VBoxContainer/AcceptButton

var campaign_manager: Node
var world_economy: Node
var current_location: Dictionary = {}
var available_missions: Array[StoryQuestData] = []
var selected_mission: StoryQuestData

func _ready() -> void:
	super._ready()
	campaign_manager = get_node("/root/Game/Managers/CampaignManager")
	world_economy = get_node("/root/Game/Managers/WorldEconomyManager")
	
	if not campaign_manager:
		push_error("Failed to get CampaignManager node")
		return
	
	if not world_economy:
		push_error("Failed to get WorldEconomyManager node")
		return
	
	if campaign_manager.has_signal("mission_available"):
		campaign_manager.mission_available.connect(_on_mission_available)
	if campaign_manager.has_signal("validation_failed"):
		campaign_manager.validation_failed.connect(_on_validation_failed)
	if world_economy.has_signal("local_event_triggered"):
		world_economy.local_event_triggered.connect(_on_local_event_triggered)
	if world_economy.has_signal("economy_updated"):
		world_economy.economy_updated.connect(_on_economy_updated)
	
	accept_button.pressed.connect(_on_accept_pressed)
	accept_button.disabled = true

func setup_phase() -> void:
	super.setup_phase()
	# Clear previous state
	available_missions.clear()
	selected_mission = null
	
	# Check current location and generate missions
	_check_location()
	_generate_missions()
	_update_ui()

func _check_location() -> void:
	# Get current location from game state
	current_location = game_state.get_current_location()
	
	# Apply location effects
	if world_economy:
		world_economy.update_local_economy()
	
	location_changed.emit(current_location)

func _generate_missions() -> void:
	if not campaign_manager:
		return
	
	# Clear existing missions
	available_missions.clear()
	
	# Generate new missions
	campaign_manager.generate_available_missions()
	available_missions = campaign_manager.get_available_missions()

func _update_ui() -> void:
	# Update location info
	location_label.text = current_location.name
	var location_text = current_location.description + "\n\n"
	location_text += "[b]Threat Level:[/b] %d\n" % current_location.threat_level
	if current_location.has("special_rules"):
		location_text += "\n[b]Special Rules:[/b]\n"
		for rule in current_location.special_rules:
			location_text += "• %s\n" % rule
	location_description.text = location_text
	
	# Clear existing mission buttons
	for child in mission_container.get_children():
		child.queue_free()
	
	# Add mission buttons
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var button = Button.new()
		button.text = "%s (Threat Level: %d)" % [mission.title, mission.threat_level]
		button.pressed.connect(_on_mission_selected.bind(mission))
		
		# Disable button if mission requirements aren't met
		if not _can_accept_mission(mission):
			button.disabled = true
			button.tooltip_text = "Requirements not met"
		
		mission_container.add_child(button)
	
	_update_mission_details()

func _update_mission_details() -> void:
	if not selected_mission:
		mission_details.text = "Select a mission to view details"
		accept_button.disabled = true
		return
	
	var details = "[b]%s[/b]\n\n" % selected_mission.title
	details += selected_mission.description + "\n\n"
	
	details += "[b]Objectives:[/b]\n"
	for objective in selected_mission.objectives:
		details += "• %s\n" % objective
	
	if selected_mission.bonus_objectives:
		details += "\n[b]Bonus Objectives:[/b]\n"
		for bonus in selected_mission.bonus_objectives:
			details += "• %s\n" % bonus
	
	details += "\n[b]Rewards:[/b]\n"
	details += "• Credits: %d\n" % selected_mission.reward_credits
	if selected_mission.bonus_rewards:
		for reward in selected_mission.bonus_rewards:
			details += "• %s\n" % reward
	
	details += "\n[b]Requirements:[/b]\n"
	var requirements_met = _can_accept_mission(selected_mission)
	details += "[color=%s]%s[/color]" % [
		"green" if requirements_met else "red",
		"All requirements met" if requirements_met else "Missing requirements"
	]
	
	mission_details.text = details
	accept_button.disabled = not requirements_met

func _can_accept_mission(mission: StoryQuestData) -> bool:
	# Check crew size
	if mission.min_crew_size > game_state.get_crew_size():
		return false
	
	# Check required resources
	for resource in mission.required_resources:
		if not game_state.has_resource(resource.type) or game_state.get_resource(resource.type) < resource.amount:
			return false
	
	# Check reputation requirement
	if mission.required_reputation > game_state.get_reputation():
		return false
	
	# Check if threat level is manageable
	if mission.threat_level > game_state.get_max_threat_level():
		return false
	
	return true

func _on_mission_selected(mission: StoryQuestData) -> void:
	selected_mission = mission
	
	# Update button visuals
	for button in mission_container.get_children():
		if button.text.begins_with(mission.title):
			button.add_theme_color_override("font_color", Color.GREEN)
		else:
			button.add_theme_color_override("font_color", Color.WHITE)
	
	_update_mission_details()
	mission_selected.emit(mission)

func _on_accept_pressed() -> void:
	if not selected_mission:
		return
	
	if campaign_manager.start_mission(selected_mission):
		game_state.set_current_mission(selected_mission)
		game_state.set_current_location(current_location)
		mission_accepted.emit(selected_mission)
		complete_phase()
	else:
		push_warning("Failed to start mission")

func _on_mission_available(mission: StoryQuestData) -> void:
	if not mission in available_missions:
		available_missions.append(mission)
		_update_ui()

func _on_validation_failed(errors: Array[String]) -> void:
	push_warning("Campaign validation failed: %s" % errors)
	_update_ui()

func _on_local_event_triggered(event_description: String) -> void:
	# Update location description with event
	var current_text = location_description.text
	location_description.text = current_text + "\n\n[b]Local Event:[/b]\n" + event_description

func _on_economy_updated() -> void:
	# Update mission rewards based on new economic conditions
	_update_mission_details()

func validate_phase_requirements() -> bool:
	if not game_state:
		return false
	
	if not game_state.has_crew():
		return false
	
	return true

func get_phase_data() -> Dictionary:
	return {
		"current_location": current_location,
		"available_missions": available_missions,
		"selected_mission": selected_mission,
		"local_economy_state": world_economy.get_economy_state() if world_economy else {}
	}
