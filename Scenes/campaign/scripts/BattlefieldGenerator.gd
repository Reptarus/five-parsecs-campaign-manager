class_name BattlefieldGenerator
extends Control

const GRID_SIZE := Vector2i(24, 24)
const CELL_SIZE := Vector2i(32, 32)

var mission: Mission
var terrain_generator: TerrainGenerator

@onready var game_manager: Control = get_node("res://Resources/GameManager.gd") as Control
@onready var battlefield_generator: Control = self
@onready var deployment_conditions_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/DeploymentConditionsLabel
@onready var mission_objective_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/MissionObjectiveLabel
@onready var mission_enemies_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/MissionEnemiesLabel
@onready var battlefield_conditions_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/BattlefieldConditionsLabel
@onready var suggested_terrain_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/SuggestedTerrainLabel
@onready var battlefield_grid: GridContainer = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/AspectRatioContainer/BattlefieldGrid
@onready var mission_name_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/MissionNameLabel

func _ready() -> void:
	_setup_ui()

func initialize(game_state_manager_node: GameStateManagerNode) -> void:
	var game_state = game_state_manager_node.get_game_state()
	mission = game_state.current_mission
	terrain_generator = TerrainGenerator.new()
	_generate_battlefield()

func _setup_ui() -> void:
	var phase_buttons := {
		"TravelButton": _on_travel_pressed,
		"WorldButton": _on_world_pressed,
		"BattleButton": _on_battle_pressed,
		"PostBattleButton": _on_post_battle_pressed
	}
	
	for button_name in phase_buttons:
		var button: Button = $MarginContainer/VBoxContainer/HBoxContainer.get_node(button_name)
		button.pressed.connect(phase_buttons[button_name])
		button.custom_minimum_size = Vector2(150, 50)  # Make buttons larger
		if button_name.to_lower().replace("button", "") == game_manager.current_phase.to_lower():
			button.add_theme_color_override("font_color", Color.GREEN)  # Highlight current phase
	
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/PlanetInfoButton.pressed.connect(_on_planet_info_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/ShipStatsButton.pressed.connect(_on_ship_stats_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/CrewStatsButton.pressed.connect(_on_crew_stats_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/MedbayButton.pressed.connect(_on_medbay_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/HBoxContainer/StashButton.pressed.connect(_on_stash_pressed)
	$MarginContainer/StartMissionButton.pressed.connect(_on_start_mission_pressed)

func _generate_battlefield() -> void:
	_set_mission_info()
	var battlefield_data := generate_battlefield(mission)
	_generate_battlefield_grid(battlefield_data)

func _set_mission_info() -> void:
	mission_name_label.text = "Mission: %s" % mission.title
	mission_objective_label.text = "Objective: %s" % GlobalEnums.MissionObjective.keys()[mission.objective]
	
	var enemies_text := "Enemies:\n"
	for enemy in mission.get_enemies():
		enemies_text += "- %s x%d\n" % [enemy.name, enemy.count]
	mission_enemies_label.text = enemies_text
	
	var conditions_text := "Conditions:\n"
	for condition in mission.environmental_factors:
		conditions_text += "- %s\n" % condition
	battlefield_conditions_label.text = conditions_text

func generate_battlefield(mission: Mission) -> Dictionary:
	var terrain := _generate_terrain()
	var player_positions := _generate_player_positions(mission.required_crew_size)
	var enemy_positions := _generate_enemy_positions(mission.get_enemies().size())

	return {
		"terrain": terrain,
		"player_positions": player_positions,
		"enemy_positions": enemy_positions
	}

func _generate_terrain() -> Array[Dictionary]:
	var terrain_generator := TerrainGenerator.new()
	var terrain_map: Array = terrain_generator.generate_terrain(GRID_SIZE)
	var terrain: Array[Dictionary] = []

	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			match terrain_map[x][y]:
				GlobalEnums.TerrainSize.LARGE:
					terrain.append({
						"position": Vector2i(x, y) * CELL_SIZE,
						"size": Vector2i(2, 2) * CELL_SIZE,
						"type": "large"
					})
				GlobalEnums.TerrainSize.SMALL:
					terrain.append({
						"position": Vector2i(x, y) * CELL_SIZE,
						"size": Vector2i(1, 1) * CELL_SIZE,
						"type": "small"
					})
				GlobalEnums.TerrainFeature.LINEAR:
					var is_horizontal: bool = x < GRID_SIZE.x - 1 and terrain_map[x + 1][y] == GlobalEnums.TerrainFeature.LINEAR
					var length: int = 1
					if is_horizontal:
						while x + length < GRID_SIZE.x and terrain_map[x + length][y] == GlobalEnums.TerrainFeature.LINEAR:
							length += 1
					else:
						while y + length < GRID_SIZE.y and terrain_map[x][y + length] == GlobalEnums.TerrainFeature.LINEAR:
							length += 1
					terrain.append({
						"position": Vector2i(x, y) * CELL_SIZE,
						"size": (Vector2i(length, 1) if is_horizontal else Vector2i(1, length)) * CELL_SIZE,
						"type": "linear"
					})

	return terrain

func _generate_player_positions(num_players: int) -> Array[Vector2]:
	var player_positions: Array[Vector2] = []
	for _i in range(num_players):
		var position: Vector2 = Vector2(
			randf_range(0, float(GRID_SIZE.x - 1)),
			randf_range(0, float(GRID_SIZE.y - 1))
		) * Vector2(CELL_SIZE)
		player_positions.append(position)
	return player_positions

func _generate_enemy_positions(num_enemies: int) -> Array[Vector2]:
	var enemy_positions: Array[Vector2] = []
	for _i in range(num_enemies):
		var position: Vector2 = Vector2(
			randf_range(0, float(GRID_SIZE.x - 1)),
			randf_range(0, float(GRID_SIZE.y - 1))
		) * Vector2(CELL_SIZE)
		enemy_positions.append(position)
	return enemy_positions

func _generate_battlefield_grid(_battlefield_data: Dictionary) -> void:
	battlefield_grid.columns = GRID_SIZE.x
	var terrain_map := terrain_generator.generate_terrain(GRID_SIZE)
	
	for cell in battlefield_grid.get_children():
		cell.queue_free()
	
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := ColorRect.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.custom_minimum_size = CELL_SIZE
			
			match terrain_map[x][y]:
				GlobalEnums.TerrainSize.LARGE:
					cell.color = Color(0.2, 0.6, 0.2)  # Green for large terrain
				GlobalEnums.TerrainSize.SMALL:
					cell.color = Color(0.6, 0.4, 0.2)  # Brown for small terrain
				GlobalEnums.TerrainFeature.LINEAR:
					cell.color = Color(0.2, 0.2, 0.6)  # Blue for linear terrain
				_:
					cell.color = Color(0.2, 0.2, 0.2)  # Dark gray for empty cells
			
			battlefield_grid.add_child(cell)

func _set_mission_name() -> void:
	mission_name_label.text = "Mission: %s" % mission.title

func _on_back_pressed() -> void:
	game_manager.load_scene("res://scenes/campaign/CampaignDashboard.tscn")

func _on_travel_pressed() -> void:
	game_manager.load_scene("res://scenes/campaign/TravelScene.tscn")

func _on_world_pressed() -> void:
	game_manager.load_scene("res://scenes/campaign/WorldScene.tscn")

func _on_battle_pressed() -> void:
	game_manager.load_scene("res://scenes/campaign/BattleScene.tscn")

func _on_post_battle_pressed() -> void:
	game_manager.load_scene("res://scenes/campaign/PostBattleScene.tscn")

func _on_planet_info_pressed() -> void:
	var planet_info: Popup = $PlanetInfoPopup
	var game_state_manager: GameStateManagerNode = get_node("/root/GameStateManagerNode")
	var current_location: Location = game_state_manager.get_game_state().current_location
	var info_text: String = "Planet: %s\n" % current_location.name
	info_text += "Traits:\n"
	var traits: Array[String] = current_location.get_traits()
	info_text += "- " + "\n- ".join(traits)
	
	# Add licensing requirement information
	var licensing_requirement: String = current_location.get_licensing_requirement()
	info_text += "\n\nLicensing: %s\n" % licensing_requirement
	
	# Add invasion information if scheduled
	if current_location.is_invasion_scheduled():
		info_text += "\nWARNING: Invasion scheduled in %d turns!\n" % current_location.get_invasion_countdown()
	
	planet_info.get_node("Label").text = info_text
	planet_info.popup_centered()

func _on_ship_stats_pressed() -> void:
	var ship_stats: Popup = $ShipStatsPopup
	ship_stats.popup_centered()
	var game_state_manager: GameStateManagerNode = get_node("/root/GameStateManagerNode")
	var ship: Ship = game_state_manager.get_game_state().current_crew.ship
	var stats_text: String = "Ship: %s\n" % ship.name
	stats_text += "Hull: %d / %d\n" % [ship.current_hull, ship.max_hull]
	stats_text += "Fuel: %d\n" % ship.fuel
	stats_text += "Components:\n"
	for component in ship.components:
		stats_text += "- %s (%s)\n" % [component.name, GlobalEnums.ComponentType.keys()[component.component_type]]
	ship_stats.get_node("Label").text = stats_text

func _on_crew_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")

func _on_medbay_pressed() -> void:
	var game_state_manager: GameStateManagerNode = get_node("/root/GameStateManagerNode")
	var ship = game_state_manager.get_game_state().current_crew.ship
	var medbay: MedicalBayComponent = ship.get_component(GlobalEnums.ComponentType.MEDICAL_BAY)
	if medbay:
		var medbay_popup: Popup = $MedbayPopup
		medbay_popup.popup_centered()
		var medbay_text: String = "Medbay Status:\n"
		for patient in medbay.patients:
			medbay_text += "%s - Recovering\n" % patient.name
		medbay_popup.get_node("Label").text = medbay_text
	else:
		print("No medbay available on this ship.")

func _on_stash_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Scene Container/ShipInventory.tscn")

func _on_start_mission_pressed() -> void:
	var game_state_manager: GameStateManagerNode = get_node("/root/GameStateManagerNode")
	game_state_manager.get_game_state().start_mission(get_tree())
