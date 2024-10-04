class_name BattlefieldGenerator
extends Control

signal battlefield_generated(battlefield_data: Dictionary)
signal terrain_placed(terrain_type: GlobalEnums.TerrainFeature, position: Vector2)

const EnemyTypes = preload("res://Resources/EnemyTypes.gd")
const CrewScene = preload("res://Scenes/Scene Container/BattlefieldGeneratorCrew.tscn")
const EnemyScene = preload("res://Scenes/Scene Container/BattlefieldGeneratorEnemy.tscn")

enum TableSize { SMALL, MEDIUM, LARGE }

@export var debug_mode: bool = false
@export var table_size: GlobalEnums.TerrainSize = GlobalEnums.TerrainSize.MEDIUM

var mission: Mission
var terrain_generator: TerrainGenerator

@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")
@onready var battlefield_grid: GridContainer = %BattlefieldGrid
@onready var debug_label: Label = %DebugLabel
@onready var table_size_option: OptionButton = %TableSizeOption

func _ready() -> void:
	_setup_ui()
	initialize()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		debug_mode = !debug_mode
		_update_debug_info()

func initialize() -> void:
	if game_state_manager.game_state.current_mission == null:
		mission = _generate_placeholder_mission()
	else:
		mission = game_state_manager.game_state.current_mission
	
	terrain_generator = TerrainGenerator.new()
	_generate_battlefield()

func _generate_battlefield() -> void:
	if mission == null:
		push_error("Cannot generate battlefield: mission is null.")
		return
	
	var battlefield_data := terrain_generator.generate_battlefield(mission, table_size)
	_generate_battlefield_grid(battlefield_data)
	emit_signal("battlefield_generated", battlefield_data)

func _generate_battlefield_grid(battlefield_data: Dictionary) -> void:
	var grid_size = TerrainGenerator.TABLE_SIZES[table_size]
	battlefield_grid.columns = grid_size.x
	var terrain_map: Array = battlefield_data.terrain
	
	for cell in battlefield_grid.get_children():
		cell.queue_free()
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := ColorRect.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.custom_minimum_size = TerrainGenerator.CELL_SIZE
			
			var terrain_feature = terrain_map[x][y]
			cell.color = _get_terrain_color(terrain_feature)
			cell.set_meta("terrain_feature", terrain_feature)
			
			battlefield_grid.add_child(cell)
			
			if terrain_feature != GlobalEnums.TerrainFeature.FIELD:
				emit_signal("terrain_placed", terrain_feature, Vector2(x, y))
	
	_place_markers(battlefield_data)

func _place_markers(battlefield_data: Dictionary) -> void:
	for pos in battlefield_data.player_positions:
		var crew_instance = CrewScene.instantiate()
		crew_instance.position = pos + TerrainGenerator.CELL_SIZE * 0.5
		battlefield_grid.add_child(crew_instance)

	for pos in battlefield_data.enemy_positions:
		var enemy_instance = EnemyScene.instantiate()
		enemy_instance.position = pos + TerrainGenerator.CELL_SIZE * 0.5
		battlefield_grid.add_child(enemy_instance)

func _get_terrain_color(terrain_feature: GlobalEnums.TerrainFeature) -> Color:
	match terrain_feature:
		GlobalEnums.TerrainFeature.BLOCK:
			return Color(0.2, 0.6, 0.2)  # Green for large terrain
		GlobalEnums.TerrainFeature.INDIVIDUAL:
			return Color(0.6, 0.4, 0.2)  # Brown for small terrain
		GlobalEnums.TerrainFeature.LINEAR:
			return Color(0.2, 0.2, 0.6)  # Blue for linear terrain
		GlobalEnums.TerrainFeature.AREA:
			return Color(0.6, 0.6, 0.2)  # Yellow for area terrain
		GlobalEnums.TerrainFeature.INTERIOR:
			return Color(0.4, 0.4, 0.4)  # Gray for interior terrain
		_:
			return Color(0.2, 0.2, 0.2)  # Dark gray for empty cells

func _generate_placeholder_mission() -> Mission:
	var placeholder_mission = Mission.new()
	placeholder_mission.terrain_type = GlobalEnums.TerrainGenerationType.INDUSTRIAL
	placeholder_mission.required_crew_size = 4
	
	var enemies = []
	for i in range(3):
		var enemy = Enemy.new()
		enemy.enemy_type = "Gangers"
		enemy.initialize(GlobalEnums.Species.HUMAN, GlobalEnums.Background.OVERCROWDED_CITY, GlobalEnums.Motivation.WEALTH, GlobalEnums.Class.WORKING_CLASS)
		enemies.append(enemy)
	
	placeholder_mission.set_enemies(enemies)
	return placeholder_mission

func _setup_ui() -> void:
	# UI setup code here (unchanged)
	pass

func _update_debug_info() -> void:
	if debug_mode:
		debug_label.text = "Terrain Count:\n"
		var terrain_count = {}
		var grid_size = TerrainGenerator.TABLE_SIZES[table_size]
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var terrain_feature = battlefield_grid.get_child(y * grid_size.x + x).get_meta("terrain_feature")
				terrain_count[terrain_feature] = terrain_count.get(terrain_feature, 0) + 1
		for feature in terrain_count:
			debug_label.text += "%s: %d\n" % [GlobalEnums.TerrainFeature.keys()[feature], terrain_count[feature]]
	else:
		debug_label.text = ""

func _on_regenerate_pressed() -> void:
	_generate_battlefield()

func _on_start_mission_pressed() -> void:
	game_state_manager.start_battle()
	get_tree().change_scene_to_file("res://Scenes/campaign/Battle.tscn")

func _on_table_size_option_item_selected(index: int) -> void:
	table_size = TableSize.values()[index]
	_generate_battlefield()

# Unit testing methods
func run_tests() -> void:
	var test_cases = [
		func(): return _test_battlefield_generation(),
		func(): return _test_terrain_distribution(),
		func(): return _test_player_enemy_positions(),
	]
	
	for test in test_cases:
		var result = test.call()
		print("Test result: ", "PASS" if result else "FAIL")

func _test_battlefield_generation() -> bool:
	var battlefield_data = terrain_generator.generate_battlefield(mission)
	return battlefield_data.has("terrain") and battlefield_data.has("player_positions") and battlefield_data.has("enemy_positions")

func _test_terrain_distribution() -> bool:
	var battlefield_data = terrain_generator.generate_battlefield(mission)
	var terrain_count = {}
	for row in battlefield_data.terrain:
		for cell in row:
			terrain_count[cell] = terrain_count.get(cell, 0) + 1
	
	for terrain_type in GlobalEnums.TerrainFeature.values():
		if terrain_count.get(terrain_type, 0) == 0:
			return false
	return true

func _test_player_enemy_positions() -> bool:
	var battlefield_data = terrain_generator.generate_battlefield(mission)
	return battlefield_data.player_positions.size() > 0 and battlefield_data.enemy_positions.size() > 0
