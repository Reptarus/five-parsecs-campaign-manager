extends BasePhasePanel

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

@onready var mission_info = $VBoxContainer/MissionInfo
@onready var deployment_container = $VBoxContainer/DeploymentContainer
@onready var crew_list = $VBoxContainer/CrewList
@onready var equipment_list = $VBoxContainer/EquipmentList
@onready var start_battle_button = $VBoxContainer/StartBattleButton

var deployment_manager: DeploymentManager
var escalating_battles_manager: EscalatingBattlesManager
var deployed_crew: Array[Character] = []
var equipped_items: Dictionary = {}
var deployment_zones: Array = []
var current_deployment_type: GameEnums.DeploymentType = GameEnums.DeploymentType.STANDARD

## Safe Property Access Methods
func _get_game_state_property(property: String, default_value = null) -> Variant:
	if not game_state:
		push_error("Trying to access property '%s' on null game state" % property)
		return default_value
	if not property in game_state:
		push_error("Game state missing required property: %s" % property)
		return default_value
	return game_state.get(property)

func _get_campaign_property(property: String, default_value = null) -> Variant:
	var campaign = _get_game_state_property("campaign")
	if not campaign:
		push_error("Trying to access property '%s' on null campaign" % property)
		return default_value
	if not property in campaign:
		push_error("Campaign missing required property: %s" % property)
		return default_value
	return campaign.get(property)

func _get_mission_property(property: String, default_value = null) -> Variant:
	var mission = _get_campaign_property("current_mission")
	if not mission:
		push_error("Trying to access property '%s' on null mission" % property)
		return default_value
	if not property in mission:
		push_error("Mission missing required property: %s" % property)
		return default_value
	return mission.get(property)

func _get_location_property(property: String, default_value = null) -> Variant:
	var location = _get_campaign_property("current_location")
	if not location:
		push_error("Trying to access property '%s' on null location" % property)
		return default_value
	if not property in location:
		push_error("Location missing required property: %s" % property)
		return default_value
	return location.get(property)

func _ready() -> void:
	super._ready()
	deployment_manager = DeploymentManager.new()
	escalating_battles_manager = EscalatingBattlesManager.new(game_state)
	
	deployment_manager.deployment_zones_generated.connect(_on_deployment_zones_generated)
	deployment_manager.terrain_generated.connect(_on_terrain_generated)
	
	_connect_signals()

func _connect_signals() -> void:
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	crew_list.item_selected.connect(_on_crew_selected)
	crew_list.item_activated.connect(_on_crew_deployed)
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
	deployment_zones = deployment_manager.generate_deployment_zones()
	
	# Generate terrain based on location
	var location = _get_campaign_property("current_location")
	var terrain_features = _get_terrain_features_for_location(location)
	deployment_manager.generate_terrain_layout(terrain_features)
	
	_setup_deployment_zones()
	_load_mission_info()
	_load_crew()
	_load_equipment()
	_update_ui()

func _get_deployment_type_for_mission(mission: Resource) -> GameEnums.DeploymentType:
	if not mission:
		return GameEnums.DeploymentType.STANDARD
		
	if _get_mission_property("deployment_type", null) != null:
		return _get_mission_property("deployment_type")
	
	# Default deployment types based on mission objectives
	var objectives = _get_mission_property("objectives", [])
	if objectives.is_empty():
		return GameEnums.DeploymentType.STANDARD
		
	var first_objective = objectives[0].to_lower()
	
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

func _get_terrain_features_for_location(location: Dictionary) -> Array:
	if not location:
		return []
	
	if _get_location_property("terrain_features", null) != null:
		return _get_location_property("terrain_features")
	
	# Default terrain based on location type
	var location_type = _get_location_property("type", "")
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
		label.text = "Zone %d (%s)" % [i + 1, zone.type]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(label)
		
		var crew_name = Label.new()
		crew_name.text = "Empty"
		crew_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(crew_name)
		
		panel.gui_input.connect(_on_zone_clicked.bind(i))
		deployment_container.add_child(panel)

func _load_mission_info() -> void:
	var mission = _get_campaign_property("current_mission")
	var location = _get_campaign_property("current_location")
	
	var info = "[b]Mission: %s[/b]\n" % _get_mission_property("title", "Unknown")
	info += _get_mission_property("description", "") + "\n\n"
	
	info += "[b]Location: %s[/b]\n" % _get_location_property("name", "Unknown")
	info += _get_location_property("description", "") + "\n\n"
	
	info += "[b]Deployment Type: %s[/b]\n" % current_deployment_type
	info += _get_deployment_description(current_deployment_type) + "\n\n"
	
	info += "[b]Objectives:[/b]\n"
	for objective in _get_mission_property("objectives", []):
		info += "• " + objective + "\n"
	
	info += "\n[b]Special Rules:[/b]\n"
	for rule in _get_location_property("special_rules", []):
		info += "• " + rule + "\n"
	
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
	crew_list.clear()
	var crew_members = _get_campaign_property("crew_members", [])
	for member in crew_members:
		if not member in deployed_crew:
			var text = "%s (%s)" % [member.character_name, member.character_class]
			crew_list.add_item(text)

func _load_equipment() -> void:
	equipment_list.clear()
	var inventory = _get_campaign_property("inventory", [])
	for item in inventory:
		if _can_equip_item(item):
			equipment_list.add_item(item.name)

func _can_equip_item(item: Dictionary) -> bool:
	# Check if item is already equipped
	if item.id in equipped_items.values():
		return false
	
	# Check if item meets mission requirements
	var mission = _get_campaign_property("current_mission")
	if _get_mission_property("restricted_items", []).has(item.id):
		return false
	
	# Check if item is valid for current deployment type
	if current_deployment_type == GameEnums.DeploymentType.INFILTRATION:
		# Restrict noisy weapons in stealth missions
		if item.has("properties") and "loud" in item.properties:
			return false
	
	return true

func _update_ui() -> void:
	start_battle_button.disabled = deployed_crew.is_empty()
	
	# Update deployment zones
	for i in range(deployment_container.get_child_count()):
		var zone = deployment_container.get_child(i)
		var crew_label = zone.get_child(0).get_child(1)
		
		if i < deployed_crew.size():
			var member = deployed_crew[i]
			var equipment = equipped_items.get(member.id, "None")
			crew_label.text = "%s\n%s" % [member.character_name, equipment]
		else:
			crew_label.text = "Empty"

func _on_crew_selected(index: int) -> void:
	# Update equipment list based on selected crew member
	var crew_members = _get_campaign_property("crew_members", [])
	var member = crew_members[index]
	equipment_list.clear()
	
	var inventory = _get_campaign_property("inventory", [])
	for item in inventory:
		if _can_equip_item(item) and member.can_use_item(item):
			equipment_list.add_item(item.name)

func _on_crew_deployed(index: int) -> void:
	var crew_members = _get_campaign_property("crew_members", [])
	var member = crew_members[index]
	if not member in deployed_crew and deployed_crew.size() < deployment_zones.size():
		deployed_crew.append(member)
		_load_crew()
		_update_ui()

func _on_equipment_selected(index: int) -> void:
	var selected_crew_index = crew_list.get_selected_items()[0]
	var crew_members = _get_campaign_property("crew_members", [])
	var member = crew_members[selected_crew_index]
	var inventory = _get_campaign_property("inventory", [])
	var item = inventory[index]
	
	equipped_items[member.id] = item.id
	_update_ui()

func _on_zone_clicked(event: InputEvent, zone_index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Handle crew deployment to zone
			var selected_indices = crew_list.get_selected_items()
			if not selected_indices.is_empty():
				_on_crew_deployed(selected_indices[0])
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Handle crew removal from zone
			if zone_index < deployed_crew.size():
				var removed_member = deployed_crew[zone_index]
				deployed_crew.remove_at(zone_index)
				equipped_items.erase(removed_member.id)
				_load_crew()
				_update_ui()

func _on_start_battle_pressed() -> void:
	if not deployed_crew.is_empty():
		# Set up battle state
		var battle_state = {
			"crew_members": deployed_crew.duplicate(),
			"equipment": equipped_items.duplicate(),
			"deployment_zones": deployment_zones.duplicate(),
			"terrain_layout": deployment_manager.terrain_layout.duplicate(),
			"strife_type": _get_mission_property("strife_type", null)
		}
		
		# Check for battle escalation
		var escalation = escalating_battles_manager.check_escalation(battle_state)
		if not escalation.is_empty():
			battle_state["escalation"] = escalation
		
		_get_campaign_property("battle_state", {}).merge(battle_state)
		complete_phase()

func _on_deployment_zones_generated(zones: Array) -> void:
	deployment_zones = zones
	_setup_deployment_zones()

func _on_terrain_generated(terrain: Array) -> void:
	# Update mission info with terrain details
	var current_text = mission_info.text
	current_text += "\n[b]Terrain Features:[/b]\n"
	for feature in terrain:
		current_text += "• %s at position %s\n" % [feature.type, feature.position]
	mission_info.text = current_text

func validate_phase_requirements() -> bool:
	if not game_state:
		return false
	
	var campaign = _get_game_state_property("campaign")
	if not campaign:
		return false
	
	if not _get_campaign_property("current_mission"):
		return false
	
	if _get_campaign_property("crew_members", []).is_empty():
		return false
	
	return true
