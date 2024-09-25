extends Control

var game_manager
var mission: Mission
var terrain_generator: TerrainGenerator

@onready var deployment_conditions_label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/DeploymentConditionsLabel
@onready var mission_objective_label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/MissionObjectiveLabel
@onready var mission_enemies_label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/MissionEnemiesLabel
@onready var battlefield_conditions_label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/BattlefieldConditionsLabel
@onready var suggested_terrain_label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/SuggestedTerrainLabel
@onready var battlefield_grid = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/AspectRatioContainer/BattlefieldGrid
@onready var mission_name_label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/MissionNameLabel

func _ready():
	_setup_ui()

func initialize(manager):
	game_manager = manager
	mission = game_manager.game_state.current_mission
	terrain_generator = TerrainGenerator.new(game_manager.game_state)
	_generate_battlefield()

func _setup_ui():
	var phase_buttons = {
		"TravelButton": _on_travel_pressed,
		"WorldButton": _on_world_pressed,
		"BattleButton": _on_battle_pressed,
		"PostBattleButton": _on_post_battle_pressed
	}
	
	for button_name in phase_buttons:
		var button = $MarginContainer/VBoxContainer/HBoxContainer.get_node(button_name)
		button.pressed.connect(phase_buttons[button_name])
		button.custom_minimum_size = Vector2(150, 50)  # Make buttons larger
		if button_name.to_lower().replace("button", "") == game_manager.current_phase.to_lower():
			button.add_theme_color_override("font_color", Color(0, 1, 0))  # Highlight current phase
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/PlanetInfoButton.pressed.connect(_on_planet_info_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/ShipStatsButton.pressed.connect(_on_ship_stats_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/CrewStatsButton.pressed.connect(_on_crew_stats_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/MedbayButton.pressed.connect(_on_medbay_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/StashButton.pressed.connect(_on_stash_pressed)
	$MarginContainer/VBoxContainer/StartMissionButton.pressed.connect(_on_start_mission_pressed)

func _generate_battlefield():
	_set_mission_info()
	_generate_battlefield_grid()

func _set_mission_info():
	mission_name_label.text = "Mission: %s" % mission.title
	mission_objective_label.text = "Objective: %s" % Mission.Objective.keys()[mission.objective]
	
	var enemies_text = "Enemies:\n"
	for enemy in mission.get_enemies():
		enemies_text += "- %s x%d\n" % [enemy.name, enemy.count]
	mission_enemies_label.text = enemies_text
	
	var conditions_text = "Conditions:\n"
	for condition in mission.environmental_factors:
		conditions_text += "- %s\n" % condition
	battlefield_conditions_label.text = conditions_text

func _generate_battlefield_grid():
	battlefield_grid.columns = terrain_generator.table_size.x
	var terrain_map = terrain_generator.generate_terrain()
	
	for cell in battlefield_grid.get_children():
		cell.queue_free()
	
	for y in range(terrain_generator.table_size.y):
		for x in range(terrain_generator.table_size.x):
			var cell = ColorRect.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			match terrain_map[x][y]:
				TerrainGenerator.TerrainType.LARGE:
					cell.color = Color(0.2, 0.6, 0.2)  # Green for large terrain
				TerrainGenerator.TerrainType.SMALL:
					cell.color = Color(0.6, 0.4, 0.2)  # Brown for small terrain
				TerrainGenerator.TerrainType.LINEAR:
					cell.color = Color(0.2, 0.2, 0.6)  # Blue for linear terrain
				_:
					cell.color = Color(0.2, 0.2, 0.2)  # Dark gray for empty cells
			
			battlefield_grid.add_child(cell)

func _set_mission_name():
	mission_name_label.text = "Mission: %s" % mission.title

func _on_back_pressed():
	game_manager.load_scene("res://scenes/campaign/CampaignDashboard.tscn")

func _on_travel_pressed():
	game_manager.load_scene("res://scenes/campaign/TravelScene.tscn")

func _on_world_pressed():
	game_manager.load_scene("res://scenes/campaign/WorldScene.tscn")

func _on_battle_pressed():
	game_manager.load_scene("res://scenes/campaign/BattleScene.tscn")

func _on_post_battle_pressed():
	game_manager.load_scene("res://scenes/campaign/PostBattleScene.tscn")

func _on_planet_info_pressed() -> void:
	var planet_info: Popup = $PlanetInfoPopup
	var current_world = game_manager.game_state.current_location
	var info_text: String = "Planet: %s\n" % current_world.name
	info_text += "Traits:\n"
	
	var traits = current_world.get_traits()
	var trait_count = traits.size()
	for i in range(trait_count):
		info_text += "- %s\n" % traits[i]
	
	planet_info.get_node("Label").text = info_text
	planet_info.popup_centered()

func _on_ship_stats_pressed():
	var ship_stats = $ShipStatsPopup
	ship_stats.popup_centered()
	var ship = game_manager.game_state.current_crew.ship
	var stats_text = "Ship: %s\n" % ship.name
	stats_text += "Hull: %d / %d\n" % [ship.current_hull, ship.max_hull]
	stats_text += "Fuel: %d\n" % ship.fuel
	stats_text += "Components:\n"
	for component in ship.components:
		stats_text += "- %s (%s)\n" % [component.name, GlobalEnums.ComponentType.keys()[component.component_type]]
	ship_stats.get_node("Label").text = stats_text

func _on_crew_stats_pressed():
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")

func _on_medbay_pressed():
	var medbay = game_manager.game_state.current_crew.ship.get_medical_bay()
	if medbay:
		var medbay_popup = $MedbayPopup
		medbay_popup.popup_centered()
		var medbay_text = "Medbay Status:\n"
		for patient in medbay.get_patients():
			medbay_text += "%s - %d days remaining\n" % [patient.name, patient.days_remaining]
		medbay_popup.get_node("Label").text = medbay_text
	else:
		print("No medbay available on this ship.")

func _on_stash_pressed():
	get_tree().change_scene_to_file("res://Scenes/Scene Container/ShipInventory.tscn")

func _on_start_mission_pressed():
	game_manager.start_mission()
