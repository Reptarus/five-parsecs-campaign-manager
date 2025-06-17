class_name GdUnitGameTest
extends "res://tests/fixtures/base/gdunit_base_test.gd"

## Game-specific test utilities for Five Parsecs Campaign Manager
## Extends GdUnitBaseTest with game-specific functionality

# Game system references
var game_data_manager: Node
var game_state_manager: Node
var character_manager: Node

# Test data tracking
var _test_campaigns: Array[Resource] = []
var _test_characters: Array[Resource] = []
var _test_missions: Array[Resource] = []

func before():
	"""Initialize game systems before tests"""
	super.before()
	_initialize_game_systems()

func after():
	"""Clean up game systems after tests"""
	_cleanup_game_data()
	super.after()

func before_test():
	"""Set up game state before each test"""
	super.before_test()
	_reset_game_state()

func after_test() -> void:
	# Clean up any remaining signal connections
	_cleanup_signal_connections()
	
	# Process frames to ensure cleanup
	await get_tree().process_frame
	await get_tree().process_frame
	
	super.after_test()

## Game System Initialization
func _initialize_game_systems() -> void:
	"""Initialize core game systems for testing"""
	# Get autoload references
	game_data_manager = get_node_or_null("/root/GameDataManager")
	game_state_manager = get_node_or_null("/root/GameStateManager")
	character_manager = get_node_or_null("/root/CharacterManager")
	
	# Verify systems are available
	assert_that(game_data_manager).is_not_null()
	assert_that(game_state_manager).is_not_null()
	assert_that(character_manager).is_not_null()

func _reset_game_state() -> void:
	"""Reset game state to clean slate for testing"""
	if game_state_manager and game_state_manager.has_method("reset_to_defaults"):
		game_state_manager.reset_to_defaults()

## Test Data Creation Utilities
func create_test_campaign(name: String = "Test Campaign") -> Resource:
	"""Create a test campaign resource"""
	var campaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd").new()
	campaign.campaign_name = name
	campaign.turn_number = 1
	_test_campaigns.append(campaign)
	return track_resource(campaign)

func create_test_character(name: String = "Test Character") -> Resource:
	"""Create a test character resource"""
	var character = preload("res://src/game/character/Character.gd").new()
	character.character_name = name
	character.reactions = 1
	character.speed = 4
	character.combat_skill = 1
	character.toughness = 3
	character.savvy = 1
	_test_characters.append(character)
	return track_resource(character)

func create_test_crew(size: int = 4) -> Array[Resource]:
	"""Create a test crew of specified size"""
	var crew: Array[Resource] = []
	for i in range(size):
		var character = create_test_character("Crew Member %d" % (i + 1))
		crew.append(character)
	return crew

func create_test_mission(mission_type: String = "Patrol") -> Resource:
	"""Create a test mission resource"""
	var mission = preload("res://src/game/mission/five_parsecs_mission.gd").new()
	mission.mission_type = mission_type
	mission.difficulty = 1
	_test_missions.append(mission)
	return track_resource(mission)

## Game State Assertions
func assert_campaign_valid(campaign: Resource, message: String = "") -> GdUnitObjectAssert:
	"""Assert that a campaign resource is valid"""
	assert_that(campaign).is_not_null()
	assert_that(campaign.campaign_name).is_not_empty()
	assert_that(campaign.turn_number).is_greater(0)
	return assert_that(campaign)

func assert_character_valid(character: Resource, message: String = "") -> GdUnitObjectAssert:
	"""Assert that a character resource is valid"""
	assert_that(character).is_not_null()
	assert_that(character.character_name).is_not_empty()
	assert_that(character.reactions).is_greater_equal(0)
	assert_that(character.speed).is_greater(0)
	assert_that(character.combat_skill).is_greater_equal(0)
	assert_that(character.toughness).is_greater(0)
	assert_that(character.savvy).is_greater_equal(0)
	return assert_that(character)

func assert_crew_size(crew: Array, expected_size: int, message: String = "") -> GdUnitArrayAssert:
	"""Assert crew has expected size"""
	return assert_that(crew).has_size(expected_size)

func assert_mission_valid(mission: Resource, message: String = "") -> GdUnitObjectAssert:
	"""Assert that a mission resource is valid"""
	assert_that(mission).is_not_null()
	assert_that(mission.mission_type).is_not_empty()
	assert_that(mission.difficulty).is_greater(0)
	return assert_that(mission)

## Game System Testing Utilities
func simulate_campaign_turn() -> void:
	"""Simulate a complete campaign turn"""
	if game_state_manager and game_state_manager.has_method("advance_turn"):
		game_state_manager.advance_turn()
	await stabilize_engine()

func simulate_battle_setup(crew: Array, enemies: Array = []) -> Dictionary:
	"""Simulate battle setup and return battle data"""
	var battle_data = {
		"crew": crew,
		"enemies": enemies,
		"battlefield_size": Vector2i(20, 20),
		"terrain": "Open Ground"
	}
	await stabilize_engine()
	return battle_data

func simulate_character_action(character: Resource, action_type: String) -> bool:
	"""Simulate a character performing an action"""
	if not character:
		return false
	
	# Mock action simulation
	match action_type:
		"move":
			return true
		"shoot":
			return character.combat_skill > 0
		"dash":
			return character.speed > 0
		_:
			return false

## Performance Testing for Game Systems
func measure_campaign_turn_performance(iterations: int = 100) -> Dictionary:
	"""Measure performance of campaign turn processing"""
	return measure_performance(simulate_campaign_turn, iterations)

func measure_character_creation_performance(iterations: int = 1000) -> Dictionary:
	"""Measure performance of character creation"""
	var create_char = func(): create_test_character()
	return measure_performance(create_char, iterations)

func measure_battle_setup_performance(crew_size: int = 6, iterations: int = 100) -> Dictionary:
	"""Measure performance of battle setup"""
	var crew = create_test_crew(crew_size)
	var setup_battle = func(): simulate_battle_setup(crew)
	return measure_performance(setup_battle, iterations)

## Enhanced performance measurement with timeout protection
func measure_performance_with_timeout(callable: Callable, timeout_seconds: float = 10.0, iterations: int = 100) -> Dictionary:
	"""Measure performance with timeout protection to prevent infinite loops"""
	var start_time = Time.get_ticks_msec()
	var timeout_ms = timeout_seconds * 1000.0
	var completed_iterations = 0
	
	for i in range(iterations):
		var current_time = Time.get_ticks_msec()
		if current_time - start_time > timeout_ms:
			push_warning("Performance test timeout after %d iterations" % completed_iterations)
			break
		
		callable.call()
		completed_iterations += 1
		
		# Yield occasionally to prevent blocking
		if i % 10 == 0:
			await get_tree().process_frame
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	return {
		"duration_ms": duration,
		"iterations": completed_iterations,
		"avg_per_iteration_ms": float(duration) / max(1, completed_iterations),
		"timed_out": completed_iterations < iterations
	}

## Stress test with safety limits
func stress_test_safe(callable: Callable, duration_seconds: float = 5.0, max_fps_failures: int = 10) -> void:
	"""Run stress test with safety limits"""
	var start_time = Time.get_ticks_msec()
	var end_time = start_time + (duration_seconds * 1000.0)
	var fps_failures = 0
	
	while Time.get_ticks_msec() < end_time:
		var frame_start = Time.get_ticks_msec()
		
		callable.call()
		await get_tree().process_frame
		
		var frame_time = Time.get_ticks_msec() - frame_start
		if frame_time > 100: # Frame took more than 100ms (less than 10 FPS)
			fps_failures += 1
			if fps_failures > max_fps_failures:
				push_warning("Stress test stopped due to excessive FPS drops")
				break

## Game Data Validation
func validate_game_data_integrity() -> bool:
	"""Validate that core game data is properly loaded"""
	if not game_data_manager:
		return false
	
	# Check if core data tables are loaded
	var required_tables = ["weapons", "armor", "enemies", "missions"]
	for table in required_tables:
		if game_data_manager.has_method("get_table") and not game_data_manager.get_table(table):
			print("❌ Missing required data table: ", table)
			return false
	
	return true

func assert_game_data_loaded(message: String = "") -> GdUnitBoolAssert:
	"""Assert that game data is properly loaded"""
	return assert_that(validate_game_data_integrity()).override_failure_message(message).is_true()

## Test Data Cleanup
func _cleanup_test_game_data() -> void:
	"""Clean up test-specific game data"""
	_test_campaigns.clear()
	_test_characters.clear()
	_test_missions.clear()

func _cleanup_game_data() -> void:
	"""Final cleanup of all game data"""
	_cleanup_test_game_data()
	
	# Reset game systems if possible
	if game_state_manager and game_state_manager.has_method("reset_to_defaults"):
		game_state_manager.reset_to_defaults()

## Mock Data Generators
func generate_random_character_stats() -> Dictionary:
	"""Generate random but valid character stats"""
	return {
		"reactions": randi_range(1, 3),
		"speed": randi_range(3, 6),
		"combat_skill": randi_range(0, 2),
		"toughness": randi_range(3, 5),
		"savvy": randi_range(0, 2)
	}

func generate_test_equipment() -> Array[Dictionary]:
	"""Generate test equipment data"""
	return [
		{"name": "Test Pistol", "type": "weapon", "damage": "1d6"},
		{"name": "Test Armor", "type": "armor", "protection": 1},
		{"name": "Test Gear", "type": "gear", "effect": "test"}
	]

## Scenario Testing Utilities
func setup_basic_campaign_scenario() -> Dictionary:
	"""Set up a basic campaign scenario for testing"""
	var campaign = create_test_campaign("Test Campaign")
	var crew = create_test_crew(4)
	var mission = create_test_mission("Patrol")
	
	return {
		"campaign": campaign,
		"crew": crew,
		"mission": mission
	}

func setup_battle_scenario(crew_size: int = 4, enemy_count: int = 3) -> Dictionary:
	"""Set up a battle scenario for testing"""
	var crew = create_test_crew(crew_size)
	var enemies: Array[Resource] = []
	
	for i in range(enemy_count):
		var enemy = Resource.new()
		enemy.set_meta("name", "Test Enemy %d" % (i + 1))
		enemies.append(track_resource(enemy))
	
	return await simulate_battle_setup(crew, enemies)

func _cleanup_signal_connections() -> void:
	# Disconnect any remaining signal connections to prevent orphan nodes
	var children = get_children()
	for child in children:
		if is_instance_valid(child):
			# Get list of all signals the child has
			var signal_list = child.get_signal_list()
			for signal_info in signal_list:
				var signal_name = signal_info.name
				# Get connections for this specific signal
				var connections = child.get_signal_connection_list(signal_name)
				for connection in connections:
					if connection.has("signal") and connection.has("callable"):
						# Use signal name string instead of Signal object
						child.disconnect(signal_name, connection.callable)

# Safe node creation pattern - use this instead of directly adding children
func create_test_node(node_class, node_name: String = "") -> Node:
	var node = node_class.new()
	if not node_name.is_empty():
		node.name = node_name
	add_child(node)
	auto_free(node) # This ensures cleanup
	return node

# Safe property checking pattern
func safe_get_property(object: Object, property_name: String, default_value = null):
	if not is_instance_valid(object):
		return default_value
	if property_name in object:
		return object.get(property_name)
	return default_value

# Safe method calling pattern  
func safe_call_method(object: Object, method_name: String, args: Array = []):
	if not is_instance_valid(object):
		return null
	if object.has_method(method_name):
		return object.callv(method_name, args)
	return null

# Safe signal emission pattern
func safe_emit_signal(object: Object, signal_name: String, args: Array = []):
	if not is_instance_valid(object):
		return false
	if object.has_signal(signal_name):
		object.callv("emit_signal", [signal_name] + args)
		return true
	return false
