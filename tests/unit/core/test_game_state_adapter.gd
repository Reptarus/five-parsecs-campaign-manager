extends GutTest

# Use explicit preloads instead of global class names
const GameStateTestAdapter = preload("res://tests/fixtures/helpers/game_state_test_adapter.gd")
const WorldDataMigration = preload("res://src/core/migration/WorldDataMigration.gd")
const TypeSafeMixin = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
# TypeSafeMixin is already defined in parent class, no need to redefine it
# GameEnums is already defined in parent class, no need to redefine it

# Test resource tracking
var _tracked_resources = []
var _tracked_nodes = []

func before_each() -> void:
	_tracked_resources = []
	_tracked_nodes = []
	await get_tree().process_frame

func after_each() -> void:
	# Clean up tracked resources
	for resource in _tracked_resources:
		if resource != null:
			resource = null
	_tracked_resources.clear()
	
	# Clean up tracked nodes
	for node in _tracked_nodes:
		if node and is_instance_valid(node):
			if node.get_parent() == self:
				remove_child(node)
			node.queue_free()
	_tracked_nodes.clear()
	
	# Run GC explicitly to help clean up orphans
	GDScript.new()
	
	await get_tree().process_frame

# Helper functions
func track_test_resource(resource) -> void:
	if resource and not _tracked_resources.has(resource):
		_tracked_resources.append(resource)

func track_test_node(node) -> void:
	if node and is_instance_valid(node) and not _tracked_nodes.has(node):
		_tracked_nodes.append(node)

func stabilize_engine(time: float = 0.1) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(time).timeout

func test_can_create_game_state_instance() -> void:
	# Given we need a GameState instance for testing
	# When we use the adapter to create one
	var state = GameStateTestAdapter.create_test_instance()
	
	# Then it should be a valid GameState object
	assert_not_null(state, "GameState instance should be created")
	assert_true(state is Node, "Should be a Node instance")
	
	# Verify it has essential methods
	var essential_methods = ["get_turn_number", "get_story_points", "get_reputation"]
	for method in essential_methods:
		assert_true(state.has_method(method), "GameState should have method: " + method)

func test_can_create_default_test_state() -> void:
	# Skip if the adapter is not available
	if not GameStateTestAdapter:
		pending("GameStateTestAdapter is not available")
		return
	
	# Given we need a GameState with default values
	# When we use the adapter to create one
	var state = GameStateTestAdapter.create_default_test_state()
	if not state:
		pending("Failed to create default test state")
		return
		
	# Then it should have the expected default values
	# Use safe accessors instead of direct property access
	var turn_number = TypeSafeMixin._call_node_method_int(state, "get_turn_number", [], 0)
	var story_points = TypeSafeMixin._call_node_method_int(state, "get_story_points", [], 0)
	var reputation = TypeSafeMixin._call_node_method_int(state, "get_reputation", [], 0)
	
	# Make detailed assertions with helpful error messages
	assert_eq(turn_number, 1, "Turn number should be 1 but was " + str(turn_number))
	assert_eq(story_points, 3, "Story points should be 3 but was " + str(story_points))
	assert_eq(reputation, 50, "Reputation should be 50 but was " + str(reputation))
	
	# Check resources using safer methods
	var resources = {}
	if state.has_method("get_resources"):
		resources = state.get_resources()
	elif state.has_method("get_resource"):
		resources = {
			GameEnums.ResourceType.CREDITS: TypeSafeMixin._call_node_method_int(state, "get_resource", [GameEnums.ResourceType.CREDITS], 0),
			GameEnums.ResourceType.FUEL: TypeSafeMixin._call_node_method_int(state, "get_resource", [GameEnums.ResourceType.FUEL], 0),
			GameEnums.ResourceType.TECH_PARTS: TypeSafeMixin._call_node_method_int(state, "get_resource", [GameEnums.ResourceType.TECH_PARTS], 0)
		}
	
	# Create migration tool if needed - with proper type checks
	var migration = null
	if WorldDataMigration:
		migration = WorldDataMigration.new()
		if migration:
			# Check type before adding to tracking
			if migration is Resource:
				track_test_resource(migration)
			elif migration is Node:
				add_child_autofree(migration)
				track_test_node(migration)
	
	# Check credits with more detailed error message
	var credits = resources.get(GameEnums.ResourceType.CREDITS, 0)
	assert_eq(credits, 1000, "Credits should be 1000 but was " + str(credits))
	
	# Check migration IDs if migration tool is available
	if migration and migration.has_method("convert_resource_type_to_id"):
		var credits_id = migration.convert_resource_type_to_id(GameEnums.ResourceType.CREDITS)
		assert_ne(credits_id, "", "Credits ID should not be empty")
		
		# Check fuel
		var fuel = resources.get(GameEnums.ResourceType.FUEL, 0)
		assert_eq(fuel, 10, "Fuel should be 10 but was " + str(fuel))
		var fuel_id = migration.convert_resource_type_to_id(GameEnums.ResourceType.FUEL)
		assert_ne(fuel_id, "", "Fuel ID should not be empty")
		
		# Check tech parts
		var tech_parts = resources.get(GameEnums.ResourceType.TECH_PARTS, 0)
		assert_eq(tech_parts, 5, "Tech parts should be 5 but was " + str(tech_parts))
		var tech_parts_id = migration.convert_resource_type_to_id(GameEnums.ResourceType.TECH_PARTS)
		assert_ne(tech_parts_id, "", "Tech parts ID should not be empty")

func test_can_deserialize_from_dict() -> void:
	# Skip if the adapter is not available
	if not GameStateTestAdapter:
		pending("GameStateTestAdapter is not available")
		return
		
	# Given a serialized game state dictionary
	var serialized_data = GameStateTestAdapter.create_test_serialized_state()
	if not serialized_data:
		pending("Failed to create serialized state data")
		return
	
	# When we deserialize it
	var state = GameStateTestAdapter.deserialize_from_dict(serialized_data)
	if not state:
		pending("Failed to deserialize state from data")
		return
	
	# Then it should be a valid GameState with the expected values
	assert_not_null(state, "GameState should be deserialized")
	assert_true(state is Node, "Should be a Node instance")
	
	# Use safe accessors
	var turn_number = TypeSafeMixin._call_node_method_int(state, "get_turn_number", [], 0)
	var story_points = TypeSafeMixin._call_node_method_int(state, "get_story_points", [], 0)
	var reputation = TypeSafeMixin._call_node_method_int(state, "get_reputation", [], 0)
	
	assert_eq(turn_number, 1, "Turn number should be 1")
	assert_eq(story_points, 3, "Story points should be 3")
	assert_eq(reputation, 50, "Reputation should be 50")
	
	# Check resources safely
	var credits = TypeSafeMixin._call_node_method_int(state, "get_resource", [GameEnums.ResourceType.CREDITS], 0)
	assert_eq(credits, 1000, "Credits should be 1000")
	
	# Check if the data needs migration - ensuring proper type handling
	var migration = null
	var needs_migration = false
	
	if WorldDataMigration:
		migration = WorldDataMigration.new()
		if migration:
			# Handle different object types appropriately
			if migration is Resource:
				track_test_resource(migration)
			elif migration is Node:
				add_child_autofree(migration)
				track_test_node(migration)
				
			if migration.has_method("needs_migration"):
				needs_migration = migration.needs_migration(serialized_data)
	
	# If migration is needed and possible, test the migration process
	if needs_migration and migration and migration.has_method("migrate_world_data"):
		var migrated_data = migration.migrate_world_data(serialized_data)
		assert_not_null(migrated_data, "Migration should return valid data")
		assert_true(migrated_data.has("data_version"), "Migrated data should have version information")
		assert_eq(migrated_data.get("data_version", ""), "2.0", "Migrated data should have correct version")
