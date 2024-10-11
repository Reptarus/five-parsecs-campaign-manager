class_name BattlefieldGenerator
extends Control

signal battlefield_generated(battlefield_data: Dictionary)
signal terrain_placed(terrain_type: GlobalEnums.TerrainFeature, position: Vector2)
signal mission_started

const EnemyTypesResource := preload("res://Resources/EnemyTypes.gd")
const CrewScene := preload("res://Scenes/Scene Container/BattlefieldGeneratorCrew.tscn")
const EnemyScene := preload("res://Scenes/Scene Container/BattlefieldGeneratorEnemy.tscn")
const MissionResource := preload("res://Scripts/Missions/Mission.gd")
const CombatManagerResource := preload("res://Scripts/Missions/CombatManager.gd")
const EnemyScript := preload("res://Resources/Enemy.gd")

@export var debug_mode: bool = false
@export var table_size: GlobalEnums.TerrainSize = GlobalEnums.TerrainSize.MEDIUM

var mission: Mission
var terrain_generator: TerrainGenerator
var combat_manager: CombatManager
var deployment_condition: String = ""
var notable_sight: String = ""

@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")
@onready var battlefield_terrain: TileMap = %BattlefieldTerrain
@onready var crew_container: Node2D = %Crew
@onready var enemies_container: Node2D = %Enemies
@onready var debug_label: Label = %DebugLabel
@onready var table_size_option: OptionButton = %TableSizeOption
@onready var transition_rect: ColorRect = $TransitionRect

func _ready() -> void:
	initialize()
	_setup_ui()
	_setup_signals()

func _setup_ui() -> void:
	table_size_option.clear()
	for terrain_size in GlobalEnums.TerrainSize.values():
		table_size_option.add_item(GlobalEnums.TerrainSize.keys()[terrain_size])
	table_size_option.select(table_size)
	
	debug_label.visible = debug_mode

func _setup_signals() -> void:
	%RegenerateButton.pressed.connect(func(): _on_regenerate_pressed())
	%StartMissionButton.pressed.connect(func(): _on_start_mission_pressed())
	table_size_option.item_selected.connect(func(index: int): _on_table_size_option_item_selected(index))

func _on_regenerate_pressed() -> void:
	_generate_battlefield()

func _on_start_mission_pressed() -> void:
	mission_started.emit()

func _on_table_size_option_item_selected(index: int) -> void:
	table_size = GlobalEnums.TerrainSize.values()[index]
	_generate_battlefield()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		debug_mode = !debug_mode
		_update_debug_info()

func initialize() -> void:
	mission = game_state_manager.game_state.current_mission if game_state_manager.game_state.current_mission else _generate_placeholder_mission()
	terrain_generator = TerrainGenerator.new()
	_generate_battlefield()
	combat_manager = CombatManager.new()
	combat_manager.initialize(mission, game_state_manager.game_state.crew.crew_members, battlefield_terrain)

func _generate_battlefield() -> void:
	if mission == null:
		push_error("Cannot generate battlefield: mission is null.")
		return
	
	var battlefield_data := terrain_generator.generate_battlefield(mission, table_size)
	_generate_battlefield_terrain(battlefield_data)
	_apply_deployment_condition()
	_place_notable_sight()
	battlefield_generated.emit(battlefield_data)

func _generate_battlefield_terrain(battlefield_data: Dictionary) -> void:
	battlefield_terrain.clear()
	for cell in battlefield_data.cells:
		battlefield_terrain.set_cell(0, cell.position, 0, Vector2i(cell.tile_index, 0))
		terrain_placed.emit(cell.terrain_type, cell.position)

func _apply_deployment_condition() -> void:
	deployment_condition = terrain_generator.generate_deployment_condition()
	# Apply the deployment condition logic here

func _place_notable_sight() -> void:
	notable_sight = terrain_generator.generate_notable_sight()
	# Place the notable sight on the battlefield here

func _update_debug_info() -> void:
	if debug_mode:
		var debug_text = "Mission: %s\nTable Size: %s\nDeployment: %s\nNotable Sight: %s" % [
			str(mission.objective) if mission else "None",
			GlobalEnums.TerrainSize.keys()[table_size],
			deployment_condition,
			notable_sight
		]
		debug_label.text = debug_text
	debug_label.visible = debug_mode

func _generate_placeholder_mission() -> Mission:
	var placeholder_mission = Mission.new()
	placeholder_mission.objective = GlobalEnums.MissionObjective.FIGHT_OFF
	placeholder_mission.terrain_type = GlobalEnums.TerrainGenerationType.INDUSTRIAL
	placeholder_mission.mission_type = GlobalEnums.MissionType.FRINGE_WORLD_STRIFE
	placeholder_mission.difficulty = GlobalEnums.DifficultyMode.NORMAL
	placeholder_mission.deployment = GlobalEnums.DeploymentType.LINE
	return placeholder_mission

func place_crew() -> void:
	for crew_member in game_state_manager.game_state.crew.crew_members:
		var crew_instance = CrewScene.instantiate()
		crew_instance.initialize(crew_member)
		crew_container.add_child(crew_instance)
		# Set initial position based on deployment condition

func place_enemies() -> void:
	for enemy_data in mission.enemies:
		var enemy_instance = EnemyScene.instantiate()
		var enemy_script = enemy_instance.get_node("EnemyScript")
		if enemy_script:
			enemy_script.initialize(enemy_data)
		else:
			push_error("EnemyScript node not found in EnemyScene")
		enemies_container.add_child(enemy_instance)
		# Set initial position based on mission parameters
		# enemy_instance.position = _get_enemy_spawn_position(enemy_data)

func _get_enemy_spawn_position(_enemy_data: Dictionary) -> Vector2:
	# Implement logic to determine spawn position based on mission parameters
	# This is a placeholder implementation
	return Vector2(randf_range(0, battlefield_terrain.get_used_rect().size.x),
				   randf_range(0, battlefield_terrain.get_used_rect().size.y))

func start_mission() -> void:
	place_crew()
	place_enemies()
	
	# Initialize combat for all enemies
	for enemy in enemies_container.get_children():
		var enemy_script = enemy.get_node("EnemyScript")
		if enemy_script:
			enemy_script.initialize_combat(combat_manager)
	
	combat_manager.start_combat()
	# Additional mission start logic

func end_mission() -> void:
	# Clean up battlefield
	for child in crew_container.get_children():
		child.queue_free()
	for child in enemies_container.get_children():
		child.queue_free()
	
	# Process mission results
	var mission_results = combat_manager.get_mission_results()
	game_state_manager.process_mission_results(mission_results)
	
	# Transition back to campaign map or relevant scene
	transition_rect.show()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://Scenes/campaign/CampaignMap.tscn")

func _on_combat_manager_combat_ended() -> void:
	end_mission()
