extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/BattleSetupPhasePanel.gd")

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var mission_info: RichTextLabel = $VBoxContainer/MissionInfo
@onready var deployment_label: Label = $VBoxContainer/DeploymentLabel
@onready var deployment_container: GridContainer = $VBoxContainer/DeploymentContainer
@onready var crew_label: Label = $VBoxContainer/CrewLabel
@onready var crew_list: ItemList = $VBoxContainer/CrewList
@onready var equipment_label: Label = $VBoxContainer/EquipmentLabel
@onready var equipment_list: ItemList = $VBoxContainer/EquipmentList
@onready var start_battle_button: Button = $VBoxContainer/StartBattleButton

var deployment_manager = null
var escalating_battles_manager = null
var deployed_crew: Array = []
var equipped_items: Dictionary = {}
var deployment_zones: Array = []
var current_deployment_type: GameEnums.DeploymentType = GameEnums.DeploymentType.STANDARD

## Safe Property Access Methods
func _get_game_state_property(property: String, default_value = null) -> Variant:
	if not game_state:
		return default_value
	if not property in game_state:
		return default_value
	return game_state.get(property)

func _get_campaign_property(property: String, default_value = null) -> Variant:
	var campaign = _get_game_state_property("campaign")
	if not campaign:
		return default_value
	if not property in campaign:
		return default_value
	return campaign.get(property)

func _get_mission_property(property: String, default_value = null) -> Variant:
	var mission = _get_campaign_property("current_mission")
	if not mission:
		return default_value
	if mission is Dictionary:
		return mission.get(property, default_value)
	if not property in mission:
		return default_value
	return mission.get(property)

func _get_location_property(property: String, default_value = null) -> Variant:
	var location = _get_campaign_property("current_location")
	if not location:
		return default_value
	if location is Dictionary:
		return location.get(property, default_value)
	if not property in location:
		return default_value
	return location.get(property)

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_rich_text(mission_info)
	_style_section_label(deployment_label)
	_style_section_label(crew_label)
	_style_item_list(crew_list)
	_style_section_label(equipment_label)
	_style_item_list(equipment_list)
	_style_phase_button(start_battle_button, true)
	_connect_signals()

func _connect_signals() -> void:
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if crew_list:
		crew_list.item_selected.connect(_on_crew_selected)
		crew_list.item_activated.connect(_on_crew_deployed)
	if equipment_list:
		equipment_list.item_selected.connect(_on_equipment_selected)

func setup_phase() -> void:
	super.setup_phase()

	# Clear previous state
	deployed_crew.clear()
	equipped_items.clear()
	deployment_zones.clear()

	# Set deployment type based on mission
	var mission = _get_campaign_property("current_mission")
	current_deployment_type = _get_deployment_type_for_mission(mission)

	# Generate deployment zones
	if deployment_manager and deployment_manager.has_method("generate_deployment_zones"):
		deployment_zones = deployment_manager.generate_deployment_zones()

	# Generate terrain based on location
	var location = _get_campaign_property("current_location")
	var terrain_features = _get_terrain_features_for_location(location)
	if deployment_manager and deployment_manager.has_method("generate_terrain_layout"):
		deployment_manager.generate_terrain_layout(terrain_features)

	_setup_deployment_zones()
	_load_mission_info()
	_load_crew()
	_load_equipment()
	_update_ui()

func _get_deployment_type_for_mission(mission) -> GameEnums.DeploymentType:
	if not mission:
		return GameEnums.DeploymentType.STANDARD

	var deploy_type = null
	if mission is Dictionary:
		deploy_type = mission.get("deployment_type", null)
	elif "deployment_type" in mission:
		deploy_type = mission.deployment_type
	if deploy_type != null:
		return deploy_type

	# Default deployment types based on mission objectives
	var objectives = []
	if mission is Dictionary:
		objectives = mission.get("objectives", [])
	elif "objectives" in mission:
		objectives = mission.objectives
	if objectives.is_empty():
		return GameEnums.DeploymentType.STANDARD

	var first_objective = str(objectives[0]).to_lower()

	if "defend" in first_objective:
		return GameEnums.DeploymentType.DEFENSIVE
	elif "ambush" in first_objective:
		return GameEnums.DeploymentType.AMBUSH
	elif "stealth" in first_objective:
		return GameEnums.DeploymentType.INFILTRATION
	elif "reinforce" in first_objective:
		return GameEnums.DeploymentType.REINFORCEMENT
	elif "assault" in first_objective:
		return GameEnums.DeploymentType.OFFENSIVE

	return GameEnums.DeploymentType.STANDARD

func _get_terrain_features_for_location(location) -> Array:
	if not location:
		return []

	var terrain = null
	if location is Dictionary:
		terrain = location.get("terrain_features", null)
	elif "terrain_features" in location:
		terrain = location.terrain_features
	if terrain != null:
		return terrain

	# Default terrain based on location type
	var location_type = ""
	if location is Dictionary:
		location_type = location.get("type", "")
	elif "type" in location:
		location_type = str(location.type)
	match location_type:
		"urban":
			return [
				GameEnums.TerrainFeatureType.WALL,
				GameEnums.TerrainFeatureType.COVER,
				GameEnums.TerrainFeatureType.OBSTACLE
			]
		"wilderness":
			return [
				GameEnums.TerrainFeatureType.COVER,
				GameEnums.TerrainFeatureType.HAZARD,
				GameEnums.TerrainFeatureType.OBSTACLE
			]
		"industrial":
			return [
				GameEnums.TerrainFeatureType.WALL,
				GameEnums.TerrainFeatureType.OBSTACLE,
				GameEnums.TerrainFeatureType.HAZARD
			]
		_:
			return [
				GameEnums.TerrainFeatureType.COVER,
				GameEnums.TerrainFeatureType.OBSTACLE
			]

func _setup_deployment_zones() -> void:
	if not deployment_container:
		return
	# Clear existing zones
	for child in deployment_container.get_children():
		child.queue_free()

	# Create deployment zone buttons based on generated zones
	for i in range(deployment_zones.size()):
		var zone = deployment_zones[i]
		var panel = PanelContainer.new()
		var layout = VBoxContainer.new()
		panel.add_child(layout)

		var label = Label.new()
		var zone_type: String = zone.get("type", "standard") if zone is Dictionary else str(zone.type) if "type" in zone else "standard"
		label.text = "Zone %d (%s)" % [i + 1, zone_type]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(label)

		var crew_name = Label.new()
		crew_name.text = "Empty"
		crew_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(crew_name)

		_style_sub_panel(panel)
		panel.gui_input.connect(_on_zone_clicked.bind(i))
		deployment_container.add_child(panel)

func _load_mission_info() -> void:
	if not mission_info:
		return
	var info = "[b]Mission: %s[/b]\n" % _get_mission_property("title", "Unknown")
	info += str(_get_mission_property("description", "")) + "\n\n"

	info += "[b]Location: %s[/b]\n" % _get_location_property("name", "Unknown")
	info += str(_get_location_property("description", "")) + "\n\n"

	info += "[b]Deployment Type: %s[/b]\n" % current_deployment_type
	info += _get_deployment_description(current_deployment_type) + "\n\n"

	info += "[b]Objectives:[/b]\n"
	for objective in _get_mission_property("objectives", []):
		info += "• " + str(objective) + "\n"

	info += "\n[b]Special Rules:[/b]\n"
	for rule in _get_location_property("special_rules", []):
		info += "• " + str(rule) + "\n"

	mission_info.text = info

func _get_deployment_description(type: GameEnums.DeploymentType) -> String:
	match type:
		GameEnums.DeploymentType.STANDARD:
			return "Standard deployment zones at opposite corners"
		GameEnums.DeploymentType.LINE:
			return "Linear deployment across the battlefield"
		GameEnums.DeploymentType.AMBUSH:
			return "Flanking positions for tactical advantage"
		GameEnums.DeploymentType.SCATTERED:
			return "Multiple small deployment zones across the map"
		GameEnums.DeploymentType.DEFENSIVE:
			return "Central defensive position with surrounding enemy zones"
		GameEnums.DeploymentType.INFILTRATION:
			return "Hidden deployment zones for stealth approach"
		GameEnums.DeploymentType.REINFORCEMENT:
			return "Staged deployment with reinforcement zones"
		GameEnums.DeploymentType.OFFENSIVE:
			return "Forward deployment for aggressive tactics"
		_:
			return "Standard deployment configuration"

func _load_crew() -> void:
	if not crew_list:
		return
	crew_list.clear()
	var crew_members = _get_crew_members()
	for member in crew_members:
		if member in deployed_crew:
			continue
		var name_str: String = "Unknown"
		if member is Dictionary:
			name_str = member.get("character_name", member.get("name", "Unknown"))
		elif "character_name" in member:
			name_str = member.character_name
		crew_list.add_item(name_str)

func _get_crew_members() -> Array:
	var campaign = _get_game_state_property("campaign")
	if not campaign:
		return []
	if campaign.has_method("get_active_crew_members"):
		return campaign.get_active_crew_members()
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	if "crew_data" in campaign:
		return campaign.crew_data.get("members", [])
	return []

func _load_equipment() -> void:
	if not equipment_list:
		return
	equipment_list.clear()
	var inventory = _get_campaign_property("inventory", [])
	for item in inventory:
		if item is Dictionary:
			equipment_list.add_item(item.get("name", "Unknown Item"))
		elif "name" in item:
			equipment_list.add_item(item.name)

func _update_ui() -> void:
	if start_battle_button:
		start_battle_button.disabled = deployed_crew.is_empty()

	if not deployment_container:
		return
	# Update deployment zones
	for i in range(deployment_container.get_child_count()):
		var zone = deployment_container.get_child(i)
		if zone.get_child_count() == 0:
			continue
		var layout = zone.get_child(0)
		if layout.get_child_count() < 2:
			continue
		var crew_label = layout.get_child(1)

		if i < deployed_crew.size():
			var member = deployed_crew[i]
			var name_str: String = "Unknown"
			if member is Dictionary:
				name_str = member.get("character_name", "Unknown")
			elif "character_name" in member:
				name_str = member.character_name
			crew_label.text = name_str
		else:
			crew_label.text = "Empty"

func _on_crew_selected(_index: int) -> void:
	# Update equipment list based on selected crew member
	_load_equipment()

func _on_crew_deployed(index: int) -> void:
	var crew_members = _get_crew_members()
	# Build list of non-deployed members (matching the crew_list display)
	var available: Array = []
	for m in crew_members:
		if m not in deployed_crew:
			available.append(m)
	if index >= 0 and index < available.size() and deployed_crew.size() < max(deployment_zones.size(), 6):
		deployed_crew.append(available[index])
		_load_crew()
		_update_ui()

func _on_equipment_selected(_index: int) -> void:
	pass

func _on_zone_clicked(event: InputEvent, zone_index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Handle crew deployment to zone
			if crew_list:
				var selected_indices = crew_list.get_selected_items()
				if not selected_indices.is_empty():
					_on_crew_deployed(selected_indices[0])
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Handle crew removal from zone
			if zone_index < deployed_crew.size():
				deployed_crew.remove_at(zone_index)
				_load_crew()
				_update_ui()

func _on_start_battle_pressed() -> void:
	if deployed_crew.is_empty():
		return
	# Set up battle state
	var terrain_layout: Dictionary = {}
	if deployment_manager and "terrain_layout" in deployment_manager:
		terrain_layout = deployment_manager.terrain_layout.duplicate()
	var battle_data = {
		"crew_members": deployed_crew.duplicate(),
		"equipment": equipped_items.duplicate(),
		"deployment_zones": deployment_zones.duplicate(),
		"terrain_layout": terrain_layout,
		"strife_type": _get_mission_property("strife_type", null)
	}

	# Check for battle escalation
	if escalating_battles_manager and escalating_battles_manager.has_method("check_escalation"):
		var escalation = escalating_battles_manager.check_escalation(battle_data)
		if not escalation.is_empty():
			battle_data["escalation"] = escalation

	complete_phase()

func validate_phase_requirements() -> bool:
	return game_state != null and _get_game_state_property("campaign") != null

func get_phase_data() -> Dictionary:
	return {
		"deployed_crew_count": deployed_crew.size(),
		"deployment_type": current_deployment_type
	}
