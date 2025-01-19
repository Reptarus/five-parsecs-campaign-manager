@tool
extends "res://tests/fixtures/game_test.gd"

const Mission := preload("res://src/core/systems/Mission.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")
const EventManager := preload("res://src/core/managers/EventManager.gd")
const MissionGenerator := preload("res://src/core/systems/MissionGenerator.gd")
const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")

# Test variables
var game_state: Node # Using Node type since GameState extends Node
var event_manager: Node # Using Node type since EventManager extends Node
var mission_generator: Node # Using Node type since MissionGenerator extends Node
var terrain_system: Node # Using Node type since TerrainSystem extends Node
var rival_system: Node # Using Node type since RivalSystem extends Node
var position_validator: Node # Using Node type since PositionValidator extends Node
var resource_system: Node # Using Node type since ResourceSystem extends Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	event_manager = EventManager.new()
	add_child(event_manager)
	track_test_node(event_manager)
	event_manager.initialize(game_state)
	
	mission_generator = MissionGenerator.new()
	add_child(mission_generator)
	track_test_node(mission_generator)
	
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)
	track_test_node(terrain_system)
	
	rival_system = RivalSystem.new()
	add_child(rival_system)
	track_test_node(rival_system)
	
	position_validator = PositionValidator.new()
	add_child(position_validator)
	track_test_node(position_validator)
	
	resource_system = ResourceSystem.new()
	add_child(resource_system)
	track_test_node(resource_system)
	
	mission_generator.setup(
		terrain_system,
		rival_system,
		position_validator,
		resource_system,
		event_manager
	)
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state = null
	event_manager = null
	mission_generator = null
	terrain_system = null
	rival_system = null
	position_validator = null
	resource_system = null

# Test Methods
func test_initial_state() -> void:
	assert_not_null(game_state, "Game state should be initialized")
	assert_not_null(event_manager, "Event manager should be initialized")
	assert_not_null(mission_generator, "Mission generator should be initialized")
	assert_valid_game_state(game_state)

func test_event_generation() -> void:
	watch_signals(event_manager)
	
	var test_event = {
		"type": "test",
		"data": {
			"message": "Test event"
		}
	}
	event_manager.trigger_event(test_event)
	assert_signal_emitted(event_manager, "event_triggered")

func test_mission_event_integration() -> void:
	watch_signals(event_manager)
	watch_signals(mission_generator)
	
	var mission = TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	
	mission_generator.generate_mission_events(mission)
	assert_signal_emitted(mission_generator, "events_generated")
	assert_signal_emitted(event_manager, "event_triggered")

func test_terrain_event_integration() -> void:
	watch_signals(event_manager)
	watch_signals(terrain_system)
	
	terrain_system.initialize_grid(Vector2(10, 10))
	var test_pos = Vector2(5, 5)
	
	terrain_system.apply_terrain_effect(test_pos, TerrainSystem.TerrainFeatureType.COVER_HIGH)
	assert_signal_emitted(terrain_system, "terrain_changed")
	assert_signal_emitted(event_manager, "event_triggered")
