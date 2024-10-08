class_name BattlefieldGenerator
extends Control

signal battlefield_generated(battlefield_data: Dictionary)
signal terrain_placed(terrain_type: GlobalEnums.TerrainFeature, position: Vector2)
signal mission_started

const EnemyTypes = preload("res://Resources/EnemyTypes.gd")
const CrewScene = preload("res://Scenes/Scene Container/BattlefieldGeneratorCrew.tscn")
const EnemyScene = preload("res://Scenes/Scene Container/BattlefieldGeneratorEnemy.tscn")
const Enemy = preload("res://Resources/Enemy.gd")
const Mission = preload("res://Scripts/Missions/Mission.gd")

@export var debug_mode: bool = false
@export var table_size: GlobalEnums.TerrainSize = GlobalEnums.TerrainSize.MEDIUM

var mission: Mission
var terrain_generator: TerrainGenerator

@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")
@onready var battlefield_terrain: TileMap = %BattlefieldTerrain
@onready var crew_container: Node2D = %Crew
@onready var enemies_container: Node2D = %Enemies
@onready var debug_label: Label = %DebugLabel
@onready var table_size_option: OptionButton = %TableSizeOption
@onready var transition_rect: ColorRect = $TransitionRect

func _ready() -> void:
	mission = _generate_placeholder_mission()
	_setup_ui()
	initialize()
	_setup_signals()

func _setup_signals() -> void:
	%RegenerateButton.pressed.connect(_on_regenerate_pressed)
	%StartMissionButton.pressed.connect(_on_start_mission_pressed)
	table_size_option.item_selected.connect(_on_table_size_option_item_selected)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		debug_mode = !debug_mode
		_update_debug_info()

func initialize() -> void:
	mission = game_state_manager.game_state.current_mission if game_state_manager.game_state.current_mission else _generate_placeholder_mission()
	terrain_generator = TerrainGenerator.new()
	_generate_battlefield()

func _generate_battlefield() -> void:
	if mission == null:
		push_error("Cannot generate battlefield: mission is null.")
		return
	
	var battlefield_data := terrain_generator.generate_battlefield(mission, table_size)
	_generate_battlefield_terrain(battlefield_data)
	battlefield_generated.emit(battlefield_data)

func _generate_battlefield_terrain(battlefield_data: Dictionary) -> void:
	battlefield_terrain.clear()
	var terrain_map: Array = battlefield_data.terrain
	var grid_size = TerrainGenerator.TABLE_SIZES[table_size]
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var terrain_feature = terrain_map[x][y]
			battlefield_terrain.set_cell(0, Vector2i(x, y), 0, Vector2i(terrain_feature, 0))
			
			if terrain_feature != GlobalEnums.TerrainFeature.FIELD:
				terrain_placed.emit(terrain_feature, Vector2(x, y))
	
	_place_units(battlefield_data)

func _place_units(battlefield_data: Dictionary) -> void:
	for child in crew_container.get_children():
		child.queue_free()
	for child in enemies_container.get_children():
		child.queue_free()
	
	for pos in battlefield_data.player_positions:
		var crew_instance = CrewScene.instantiate()
		crew_instance.position = battlefield_terrain.map_to_local(Vector2i(pos.x, pos.y))
		crew_container.add_child(crew_instance)

	for pos in battlefield_data.enemy_positions:
		var enemy_instance = EnemyScene.instantiate()
		enemy_instance.position = battlefield_terrain.map_to_local(Vector2i(pos.x, pos.y))
		enemies_container.add_child(enemy_instance)

func _generate_placeholder_mission() -> Mission:
	var placeholder_mission = Mission.new()
	placeholder_mission.terrain_type = GlobalEnums.TerrainGenerationType.INDUSTRIAL
	placeholder_mission.required_crew_size = 4
	
	var enemies: Array[Enemy] = []
	for i in range(3):
		var enemy = Enemy.new("Gangers", "Standard")
		enemies.append(enemy)
	
	placeholder_mission.set_enemies(enemies)
	return placeholder_mission

func _setup_ui() -> void:
	table_size_option.clear()
	for size in GlobalEnums.TerrainSize.keys():
		table_size_option.add_item(size)
	table_size_option.select(table_size)

func _update_debug_info() -> void:
	if debug_mode:
		debug_label.text = "Terrain Count:\n"
		var terrain_count = {}
		var grid_size = TerrainGenerator.TABLE_SIZES[table_size]
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var terrain_feature = battlefield_terrain.get_cell(0, Vector2i(x, y)).id
				terrain_count[terrain_feature] = terrain_count.get(terrain_feature, 0) + 1
		for feature in terrain_count:
			debug_label.text += "%s: %d\n" % [GlobalEnums.TerrainFeature.keys()[feature], terrain_count[feature]]
	else:
		debug_label.text = ""

func _on_regenerate_pressed() -> void:
	_generate_battlefield()

func _on_start_mission_pressed() -> void:
	game_state_manager.start_battle()
	_fade_transition("res://Scenes/campaign/Battle.tscn")

func _on_table_size_option_item_selected(index: int) -> void:
	table_size = GlobalEnums.TerrainSize.values()[index]
	_generate_battlefield()

func _fade_transition(next_scene: String) -> void:
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(next_scene)
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, 0.5)

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
	var battlefield_data = terrain_generator.generate_battlefield(mission, table_size)
	return battlefield_data.has("terrain") and battlefield_data.has("player_positions") and battlefield_data.has("enemy_positions")

func _test_terrain_distribution() -> bool:
	var battlefield_data = terrain_generator.generate_battlefield(mission, table_size)
	var terrain_count = {}
	for row in battlefield_data.terrain:
		for cell in row:
			terrain_count[cell] = terrain_count.get(cell, 0) + 1
	
	for terrain_type in GlobalEnums.TerrainFeature.values():
		if terrain_count.get(terrain_type, 0) == 0:
			return false
	return true

func _test_player_enemy_positions() -> bool:
	var battlefield_data = terrain_generator.generate_battlefield(mission, table_size)
	return battlefield_data.player_positions.size() > 0 and battlefield_data.enemy_positions.size() > 0
