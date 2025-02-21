@tool
extends "res://tests/fixtures/game_test.gd"

# Core class dependencies - using variables instead of constants since preload isn't constant
var CampaignManagerScript: GDScript = preload("res://src/core/managers/CampaignManager.gd")
var StoryQuestDataScript: GDScript = preload("res://src/core/story/StoryQuestData.gd")
var BattleDataScript: GDScript = preload("res://src/core/battle/BattleData.gd")
var StoryEventDataScript: GDScript = preload("res://src/core/story/StoryEventData.gd")
var GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")

# Test state variables
var game_state: Node = null # Using Node since GameState extends Node
var campaign_manager: Resource = null # Using Resource since CampaignManager extends Resource

# Add at the top of the file, after the script imports
const VALID_MISSION_TYPES = [
	GameEnums.MissionType.PATROL,
	GameEnums.MissionType.RESCUE,
	GameEnums.MissionType.PATRON
]

# Safe casting helper functions
func _safe_cast_object(value: Variant, error_message: String = "") -> Object:
	if not value is Object:
		push_error("Cannot cast to Object: %s" % error_message)
		return null
	return value

func _safe_cast_node(value: Variant, error_message: String = "") -> Node:
	if not value is Node:
		push_error("Cannot cast to Node: %s" % error_message)
		return null
	return value

func _safe_cast_resource(value: Variant, error_message: String = "") -> Resource:
	if not value is Resource:
		push_error("Cannot cast to Resource: %s" % error_message)
		return null
	return value

func _safe_cast_gdscript(value: Variant, error_message: String = "") -> GDScript:
	if not value is GDScript:
		push_error("Cannot cast to GDScript: %s" % error_message)
		return null
	return value

func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	if not value is Array:
		push_error("Cannot cast to Array: %s" % error_message)
		return []
	return value

func _safe_cast_dictionary(value: Variant, error_message: String = "") -> Dictionary:
	if not value is Dictionary:
		push_error("Cannot cast to Dictionary: %s" % error_message)
		return {}
	return value

func _safe_cast_bool(value: Variant, error_message: String = "") -> bool:
	if not value is bool:
		push_error("Cannot cast to bool: %s" % error_message)
		return false
	return value

func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if not value is int:
		push_error("Cannot cast to int: %s" % error_message)
		return 0
	return value

func _safe_cast_string(value: Variant, error_message: String = "") -> String:
	if not value is String:
		push_error("Cannot cast to String: %s" % error_message)
		return ""
	return value

# Helper function to safely get script
func _get_script_safe(obj: Variant) -> GDScript:
	var object := _safe_cast_object(obj, "Cannot get script from non-Object")
	if not object:
		return null
	
	if not object.has_method("get_script"):
		push_error("Object does not support get_script")
		return null
	
	var raw_script: Variant = object.get_script()
	return _safe_cast_gdscript(raw_script, "Script is not GDScript")

# Helper function to safely get property
func _get_property_safe(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	var object := _safe_cast_object(obj, "Cannot get property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	return object.get(property)

# Helper function to safely set property
func _set_property_safe(obj: Variant, property: String, value: Variant) -> void:
	var object := _safe_cast_object(obj, "Cannot set property on non-Object")
	if not object:
		return
	
	if not property in object:
		return
	
	object.set(property, value)

# Helper function to safely call method
func _call_method_safe(obj: Variant, method: String, args: Array = [], expected_type: int = TYPE_NIL, default_value: Variant = null) -> Variant:
	var object := _safe_cast_object(obj, "Cannot call method on non-Object")
	if not object:
		return default_value
	
	if not object.has_method(method):
		push_error("Method %s not found in object" % method)
		return default_value
	
	var result: Variant = object.callv(method, args)
	
	if expected_type != TYPE_NIL and typeof(result) != expected_type:
		push_error("Expected return type %s but got %s" % [expected_type, typeof(result)])
		return default_value
	
	return result

# Helper function to safely get array property
func _get_array_property(obj: Variant, property: String, default_value: Array = []) -> Array:
	var object := _safe_cast_object(obj, "Cannot get array property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	var raw_value: Variant = object.get(property)
	return _safe_cast_array(raw_value, "Property value is not an Array")

# Helper function to safely get dictionary property
func _get_dict_property(obj: Variant, property: String, default_value: Dictionary = {}) -> Dictionary:
	var object := _safe_cast_object(obj, "Cannot get dictionary property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	var raw_value: Variant = object.get(property)
	return _safe_cast_dictionary(raw_value, "Property value is not a Dictionary")

# Helper function to safely get boolean property
func _get_bool_property(obj: Variant, property: String, default_value: bool = false) -> bool:
	var object := _safe_cast_object(obj, "Cannot get boolean property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	var value: Variant = object.get(property)
	return _safe_cast_bool(value, "Property value is not a bool")

# Helper function to safely get integer property
func _get_int_property(obj: Variant, property: String, default_value: int = 0) -> int:
	var object := _safe_cast_object(obj, "Cannot get integer property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	var value: Variant = object.get(property)
	return _safe_cast_int(value, "Property value is not an int")

# Helper function for safe resource method calls with dictionary return
func _call_resource_method_dict(resource: Variant, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
	var res := _safe_cast_resource(resource, "Cannot call method on non-Resource")
	if not res:
		return default_value
	
	var result: Variant = _call_method_safe(res, method, args)
	return _safe_cast_dictionary(result, "Method did not return a Dictionary")

# Helper function for safe resource method calls with array return
func _call_resource_method_array(resource: Variant, method: String, args: Array = [], default_value: Array = []) -> Array:
	var res := _safe_cast_resource(resource, "Cannot call method on non-Resource")
	if not res:
		return default_value
	
	var result: Variant = _call_method_safe(res, method, args)
	return _safe_cast_array(result, "Method did not return an Array")

# Helper function for safe resource method calls with boolean return
func _call_resource_method_bool(resource: Variant, method: String, args: Array = [], default_value: bool = false) -> bool:
	var res := _safe_cast_resource(resource, "Cannot call method on non-Resource")
	if not res:
		return default_value
	
	var result: Variant = _call_method_safe(res, method, args)
	return _safe_cast_bool(result, "Method did not return a bool")

# Helper function for safe resource method calls with integer return
func _call_resource_method_int(resource: Variant, method: String, args: Array = [], default_value: int = 0) -> int:
	var res := _safe_cast_resource(resource, "Cannot call method on non-Resource")
	if not res:
		return default_value
	
	var result: Variant = _call_method_safe(res, method, args)
	return _safe_cast_int(result, "Method did not return an int")

# Helper function for safe node method calls with boolean return
func _call_node_method_bool(node: Variant, method: String, args: Array = [], default_value: bool = false) -> bool:
	var n := _safe_cast_node(node, "Cannot call method on non-Node")
	if not n:
		return default_value
	
	var result: Variant = _call_method_safe(n, method, args)
	return _safe_cast_bool(result, "Method did not return a bool")

# Helper function for safe node method calls with integer return
func _call_node_method_int(node: Variant, method: String, args: Array = [], default_value: int = 0) -> int:
	var n := _safe_cast_node(node, "Cannot call method on non-Node")
	if not n:
		return default_value
	
	var result: Variant = _call_method_safe(n, method, args)
	return _safe_cast_int(result, "Method did not return an int")

# Helper function for safe node method calls
func _call_node_method(node: Variant, method: String, args: Array = [], expected_type: int = TYPE_NIL, default_value: Variant = null) -> Variant:
	var n := _safe_cast_node(node, "Cannot call method on non-Node")
	if not n:
		return default_value
	
	return _call_method_safe(n, method, args, expected_type, default_value)

# Helper function for safe resource method calls
func _call_resource_method(resource: Variant, method: String, args: Array = [], expected_type: int = TYPE_NIL, default_value: Variant = null) -> Variant:
	var res := _safe_cast_resource(resource, "Cannot call method on non-Resource")
	if not res:
		return default_value
	
	return _call_method_safe(res, method, args, expected_type, default_value)

# Safe property access methods
func _get_game_state_property(property: String, default_value: Variant = null) -> Variant:
	var node := _safe_cast_node(game_state, "Game state is not a Node")
	if not node:
		return default_value
	
	if not _validate_game_state(node):
		return default_value
	
	return _get_property_safe(node, property, default_value)

func _set_game_state_property(property: String, value: Variant) -> void:
	var node := _safe_cast_node(game_state, "Game state is not a Node")
	if not node:
		return
	
	if not _validate_game_state(node):
		return
	
	_set_property_safe(node, property, value)

func _get_campaign_manager_property(property: String, default_value: Variant = null) -> Variant:
	var resource := _safe_cast_resource(campaign_manager, "Campaign manager is not a Resource")
	if not resource:
		return default_value
	
	if not _validate_campaign_manager(resource):
		return default_value
	
	return _get_property_safe(resource, property, default_value)

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	game_state = create_test_game_state()
	var node := _safe_cast_node(game_state, "Game state is not a Node")
	if not node:
		return
	
	# Add child and track node
	var add_result := add_child_autofree(node)
	if not add_result:
		push_error("Failed to add child node")
		return
		
	track_test_node(node)
	
	# Initialize campaign manager
	campaign_manager = CampaignManagerScript.new(node)
	var resource := _safe_cast_resource(campaign_manager, "Campaign manager is not a Resource")
	if not resource:
		return
	
	# Track resource
	track_test_resource(resource)
	
	# Set up required resources
	assert_true(_call_node_method_bool(node, "add_resource", [GameEnums.ResourceType.SUPPLIES, 100]), "Should add supplies")
	assert_true(_call_node_method_bool(node, "add_resource", [GameEnums.ResourceType.FUEL, 100]), "Should add fuel")
	assert_true(_call_node_method_bool(node, "add_resource", [GameEnums.ResourceType.MEDICAL_SUPPLIES, 100]), "Should add medical supplies")
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(game_state):
		var node := _safe_cast_node(game_state, "Game state is not a Node")
		if node:
			remove_child(node)
			node.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	campaign_manager = null
	game_state = null
	
	# Let parent handle remaining cleanup
	await super.after_each()
	
	# Clear tracked resources
	_tracked_resources.clear()

# Test campaign initialization
func test_campaign_initialization() -> void:
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	
	var game_state_ref: Variant = _get_campaign_manager_property("game_state")
	var node := _safe_cast_node(game_state_ref, "Game state reference should be a Node")
	if not node:
		assert_true(false, "Game state reference should be a Node")
		return
	
	assert_not_null(node, "Game state should be set")
	
	var script: GDScript = _get_script_safe(node)
	assert_not_null(script, "Game state should have a script")
	assert_true(script == GameStateScript, "Game state should be correct type")
	
	var current_phase: int = _call_resource_method_int(campaign_manager, "get_current_phase")
	var expected_phase: int = GameEnums.FiveParcsecsCampaignPhase.NONE
	assert_eq(current_phase, expected_phase, "Should start in NONE phase")

# Test phase transitions
func test_phase_transitions() -> void:
	if not campaign_manager is Resource:
		assert_true(false, "Campaign manager should be a Resource")
		return
		
	var resource: Resource = campaign_manager as Resource
	watch_signals(resource)
	
	assert_true(_call_resource_method_bool(resource, "start_campaign"), "Should start campaign successfully")
	var current_phase: int = _call_resource_method_int(resource, "get_current_phase")
	var expected_setup_phase: int = GameEnums.FiveParcsecsCampaignPhase.SETUP
	assert_eq(current_phase, expected_setup_phase, "Should transition to SETUP phase")
	assert_signal_emitted(resource, "phase_changed")
	
	assert_true(_call_resource_method_bool(resource, "advance_phase"), "Should advance phase successfully")
	current_phase = _call_resource_method_int(resource, "get_current_phase")
	var expected_campaign_phase: int = GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN
	assert_eq(current_phase, expected_campaign_phase, "Should transition to CAMPAIGN phase")
	assert_signal_emitted(resource, "phase_changed")

# Test resource management
func test_resource_management() -> void:
	if not game_state is Node:
		assert_true(false, "Game state should be a Node")
		return
		
	var node: Node = game_state as Node
	watch_signals(node)
	
	var resources: Dictionary = {
		GameEnums.ResourceType.CREDITS: 100,
		GameEnums.ResourceType.SUPPLIES: 50
	}
	
	if not campaign_manager is Resource:
		assert_true(false, "Campaign manager should be a Resource")
		return
		
	var resource: Resource = campaign_manager as Resource
	assert_true(_call_resource_method_bool(resource, "add_resources", [resources]), "Should add resources successfully")
	
	var credits: int = _call_node_method_int(node, "get_resource", [GameEnums.ResourceType.CREDITS])
	var supplies: int = _call_node_method_int(node, "get_resource", [GameEnums.ResourceType.SUPPLIES])
	assert_eq(credits, 100, "Should add correct amount of credits")
	assert_eq(supplies, 150, "Should add correct amount of supplies")
	assert_signal_emitted(node, "resources_changed")

# Test story quest handling
func test_story_quest_handling() -> void:
	if not campaign_manager is Resource:
		assert_true(false, "Campaign manager should be a Resource")
		return
		
	var resource: Resource = campaign_manager as Resource
	watch_signals(resource)
	
	var quest_data: Dictionary = {
		"id": "test_quest",
		"title": "Test Quest",
		"description": "A test quest",
		"objectives": [],
		"rewards": {
			"credits": 100,
			"reputation": 1
		}
	}
	
	assert_true(_call_resource_method_bool(resource, "add_story_quest", [quest_data]), "Should add story quest")
	var has_quest: bool = _call_resource_method_bool(resource, "has_active_quest", ["test_quest"])
	assert_true(has_quest, "Should have active quest")
	assert_signal_emitted(resource, "quest_added")
	
	assert_true(_call_resource_method_bool(resource, "complete_quest", ["test_quest"]), "Should complete quest")
	has_quest = _call_resource_method_bool(resource, "has_active_quest", ["test_quest"])
	assert_false(has_quest, "Should not have active quest after completion")
	assert_signal_emitted(resource, "quest_completed")

# Test campaign cleanup
func test_campaign_cleanup() -> void:
	if not campaign_manager is Resource:
		assert_true(false, "Campaign manager should be a Resource")
		return
		
	var resource: Resource = campaign_manager as Resource
	assert_true(_call_resource_method_bool(resource, "start_campaign"), "Should start campaign")
	
	var resources: Dictionary = {
		GameEnums.ResourceType.CREDITS: 100
	}
	assert_true(_call_resource_method_bool(resource, "add_resources", [resources]), "Should add resources")
	
	assert_true(_call_resource_method_bool(resource, "cleanup"), "Should cleanup campaign")
	
	var current_phase: int = _call_resource_method_int(resource, "get_current_phase")
	var expected_phase: int = GameEnums.FiveParcsecsCampaignPhase.NONE
	assert_eq(current_phase, expected_phase, "Should reset to NONE phase")
	
	if not game_state is Node:
		assert_true(false, "Game state should be a Node")
		return
		
	var node: Node = game_state as Node
	var credits: int = _call_node_method_int(node, "get_resource", [GameEnums.ResourceType.CREDITS])
	assert_eq(credits, 0, "Should reset credits to 0")

# Test initial state
func test_initial_state() -> void:
	# Null checks
	assert_not_null(game_state, "Game state should be initialized")
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	
	if not game_state is Node:
		assert_true(false, "Game state should be a Node")
		return
		
	var node: Node = game_state as Node
	
	# Boolean checks
	var has_active_campaign: bool = _call_node_method_bool(node, "has_active_campaign")
	assert_false(has_active_campaign, "Game state should start with no active campaign")
	
	if not campaign_manager is Resource:
		assert_true(false, "Campaign manager should be a Resource")
		return
		
	var resource: Resource = campaign_manager as Resource
	
	# Collection size checks
	var available_missions: Array = _call_resource_method_array(resource, "get_available_missions")
	var active_missions: Array = _call_resource_method_array(resource, "get_active_missions")
	var completed_missions: Array = _call_resource_method_array(resource, "get_completed_missions")
	
	assert_eq(_get_size(available_missions), 0, "Should start with no available missions")
	assert_eq(_get_size(active_missions), 0, "Should start with no active missions")
	assert_eq(_get_size(completed_missions), 0, "Should start with no completed missions")
	
	# Instance type checks
	var script: GDScript = _get_script_safe(resource)
	assert_not_null(script, "Campaign manager should have a script")
	assert_true(script == CampaignManagerScript, "Should be a CampaignManager instance")

# Test mission history management
func test_mission_history_management() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Test history entry creation
	var mission: Resource = _create_and_validate_mission(GameEnums.MissionType.PATROL)
	if not mission is Resource:
		assert_true(false, "Failed to create mission")
		return
		
	var history_entry: Dictionary = _call_resource_method_dict(campaign_manager, "_create_mission_history_entry", [mission])
	if history_entry.is_empty():
		assert_true(false, "Failed to create history entry")
		return
	
	# Check required fields
	var required_fields: Array[String] = [
		"mission_id", "mission_type", "name", "completion_percentage",
		"is_completed", "is_failed", "objectives_completed", "total_objectives",
		"resources_consumed", "crew_involved", "timestamp"
	]
	
	for field in required_fields:
		assert_true(field in history_entry, "History entry should have %s field" % field)
	
	# Test history size limits
	var max_size: int = _get_int_property(campaign_manager, "MAX_MISSION_HISTORY")
	for i in range(max_size + 1):
		var test_mission: Resource = _create_and_validate_mission(GameEnums.MissionType.PATROL)
		if test_mission is Resource:
			var test_entry: Dictionary = _call_resource_method_dict(campaign_manager, "_create_mission_history_entry", [test_mission])
			if not test_entry.is_empty():
				var add_result := _call_resource_method_bool(campaign_manager, "add_to_mission_history", [test_entry])
				if not add_result:
					push_error("Failed to add mission to history")
	
	assert_true(_call_resource_method_bool(campaign_manager, "cleanup_campaign_state"), "Should cleanup campaign state")
	var history: Array = _call_resource_method_array(campaign_manager, "get_mission_history")
	var history_size: int = _get_size(history)
	assert_true(history_size <= max_size, "Should not exceed maximum history size")

# Test mission completion
func test_mission_completion() -> void:
	load_test_campaign(game_state)
	watch_signals(campaign_manager)
	
	# Set up initial resources
	var initial_credits: int = _call_node_method_int(game_state, "get_credits")
	var initial_reputation: int = _call_node_method_int(game_state, "get_reputation")
	var initial_supplies: int = 100
	assert_true(_call_node_method_bool(game_state, "set_resource", [GameEnums.ResourceType.SUPPLIES, initial_supplies]), "Should set supplies")
	
	# Create and configure mission
	var mission: Resource = _create_and_validate_mission(GameEnums.MissionType.PATROL, {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"risk_level": 1
	})
	
	if not mission is Resource:
		assert_true(false, "Failed to create mission")
		return
	
	# Configure mission requirements and rewards
	_set_mission_property(mission, "required_equipment", [])
	_set_mission_property(mission, "required_resources", {
		GameEnums.ResourceType.SUPPLIES: 10
	})
	_set_mission_property(mission, "reward_credits", 500)
	_set_mission_property(mission, "reward_reputation", 5)
	
	assert_true(_call_resource_method_bool(mission, "add_objective", [GameEnums.MissionObjective.PATROL, "Patrol the designated area", true]), "Should add objective")
	
	var validation: Dictionary = _call_resource_method_dict(mission, "validate")
	var is_valid: bool = _get_dict_bool(validation, "is_valid")
	assert_true(is_valid, "Mission should be valid: " + str(validation.get("errors", [])))
	
	# Ensure mission is in available missions
	assert_true(_call_resource_method_bool(campaign_manager, "add_available_mission", [mission]), "Should add to available missions")
	
	# Start mission and complete objectives
	var mission_started: bool = _call_resource_method_bool(campaign_manager, "start_mission", [mission])
	assert_true(mission_started, "Should successfully start mission")
	assert_signal_emitted(campaign_manager, "mission_started", "Mission started signal should be emitted")
	
	var active_missions: Array = _call_resource_method_array(campaign_manager, "get_active_missions")
	var is_active: bool = mission in active_missions
	assert_true(is_active, "Mission should be in active missions")
	
	assert_true(_call_resource_method_bool(mission, "complete_objective", [GameEnums.MissionObjective.PATROL]), "Should complete objective")
	
	# Complete mission
	assert_true(_call_resource_method_bool(campaign_manager, "complete_mission", [mission]), "Should complete mission")
	assert_signal_emitted(campaign_manager, "mission_completed", "Mission completed signal should be emitted")
	
	# Verify mission state changes
	var active_count: int = _get_size(_call_resource_method_array(campaign_manager, "get_active_missions"))
	var completed_count: int = _get_size(_call_resource_method_array(campaign_manager, "get_completed_missions"))
	assert_eq(active_count, 0, "Should remove from active missions")
	assert_eq(completed_count, 1, "Should add to completed missions")
	
	# Verify resource consumption
	var final_supplies: int = _call_node_method_int(game_state, "get_resource", [GameEnums.ResourceType.SUPPLIES])
	assert_eq(final_supplies, initial_supplies - 10, "Should consume required supplies")
	
	# Verify rewards
	var final_credits: int = _call_node_method_int(game_state, "get_credits")
	var final_reputation: int = _call_node_method_int(game_state, "get_reputation")
	assert_eq(final_credits, initial_credits + 500, "Should award mission credits")
	assert_eq(final_reputation, initial_reputation + 5, "Should award mission reputation")
	
	# Verify mission history
	var history: Array = _call_resource_method_array(campaign_manager, "get_mission_history")
	assert_eq(_get_size(history), 1, "Should add mission to history")
	
	if history.is_empty():
		assert_true(false, "History should not be empty")
		return
		
	if history.size() == 0:
		assert_true(false, "History should have at least one entry")
		return
		
	var entry_variant: Variant = history[0]
	var history_entry := _safe_cast_dictionary(entry_variant, "History entry should be a Dictionary")
	if not history_entry:
		assert_true(false, "History entry should be a Dictionary")
		return
	
	# Check history entry details
	assert_true("rewards" in history_entry, "History should include rewards")
	var rewards_variant: Variant = history_entry.get("rewards", {})
	var rewards := _safe_cast_dictionary(rewards_variant, "Rewards should be a Dictionary")
	if not rewards:
		assert_true(false, "Rewards should be a Dictionary")
		return
	
	var reward_credits: int = _get_dict_int(rewards, "credits")
	var reward_reputation: int = _get_dict_int(rewards, "reputation")
	assert_eq(reward_credits, 500, "History should record correct reward credits")
	assert_eq(reward_reputation, 5, "History should record correct reward reputation")
	
	assert_true("resources_consumed" in history_entry, "History should include consumed resources")
	var resources_variant: Variant = history_entry.get("resources_consumed", {})
	var resources_consumed := _safe_cast_dictionary(resources_variant, "Resources consumed should be a Dictionary")
	if not resources_consumed:
		assert_true(false, "Resources consumed should be a Dictionary")
		return
	
	var consumed_supplies: int = _get_dict_int(resources_consumed, str(GameEnums.ResourceType.SUPPLIES))
	assert_eq(consumed_supplies, 10, "History should record correct resource consumption")
	
	var is_completed: bool = _get_dict_bool(history_entry, "is_completed")
	var is_failed: bool = _get_dict_bool(history_entry, "is_failed")
	assert_true(is_completed, "Should be marked as completed in history")
	assert_false(is_failed, "Should not be marked as failed in history")

# Helper function to safely validate type
func _validate_type(obj: Variant, expected_type: int, error_message: String = "") -> bool:
	if obj == null:
		push_error("Object is null: %s" % error_message)
		return false
	if typeof(obj) != expected_type:
		push_error("Expected type %s but got %s: %s" % [expected_type, typeof(obj), error_message])
		return false
	return true

# Helper function to safely validate class
func _validate_class(obj: Variant, expected_class_name: String, error_message: String = "") -> bool:
	var object := _safe_cast_object(obj, "Object is null: %s" % error_message)
	if not object:
		return false
	
	if not object.has_method("get_class"):
		push_error("Object does not support get_class: %s" % error_message)
		return false
	
	var class_result: Variant = object.call("get_class")
	var class_str := _safe_cast_string(class_result, "get_class did not return a String")
	if not class_str:
		return false
	
	if class_str != expected_class_name:
		push_error("Expected class %s but got %s: %s" % [expected_class_name, class_str, error_message])
		return false
	
	return true

# Helper function to validate object type
func _validate_object_type(obj: Variant, expected_script: GDScript, error_message: String = "") -> bool:
	var object := _safe_cast_object(obj, "Expected Object: %s" % error_message)
	if not object:
		return false
	
	if not object.has_method("get_script"):
		push_error("Object does not support get_script: %s" % error_message)
		return false
	
	var script := _get_script_safe(object)
	if not script or script != expected_script:
		push_error("Invalid object type: %s" % error_message)
		return false
	
	return true

# Helper function to safely create and validate a mission
func _create_and_validate_mission(mission_type: int, config: Dictionary = {}) -> Resource:
	var resource := _safe_cast_resource(campaign_manager, "Campaign manager is null or invalid")
	if not resource:
		return null
	
	if not resource.has_method("create_mission"):
		push_error("Campaign manager missing create_mission method")
		return null
	
	var result: Variant = _call_resource_method(resource, "create_mission", [mission_type, config])
	var mission := _safe_cast_resource(result, "Created mission is not a Resource")
	if not mission:
		return null
	
	if not _validate_object_type(mission, StoryQuestDataScript, "Invalid mission type"):
		return null
	
	return mission

# Helper function to validate mission state
func _validate_mission_state(mission: Variant) -> bool:
	return _validate_object_type(mission, StoryQuestDataScript, "Invalid mission object provided")

# Helper function to validate game state
func _validate_game_state(state: Variant) -> bool:
	return _validate_object_type(state, GameStateScript, "Invalid game state object provided")

# Helper function to validate campaign manager
func _validate_campaign_manager(manager: Variant) -> bool:
	return _validate_object_type(manager, CampaignManagerScript, "Invalid campaign manager object provided")

# Helper function to safely get mission property
func _get_mission_property(mission: Resource, property: String, default_value: Variant = null) -> Variant:
	if not _validate_mission_state(mission):
		return default_value
	return _get_property_safe(mission, property, default_value)

# Helper function to safely set mission property
func _set_mission_property(mission: Resource, property: String, value: Variant) -> void:
	if not _validate_mission_state(mission):
		return
	_set_property_safe(mission, property, value)

# Signal watching helper functions
func watch_signals(emitter: Object) -> void:
	if emitter.has_method("get_signal_list"):
		super.watch_signals(emitter)

func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if object.has_method("get_signal_list"):
		super.verify_signal_emitted(object, signal_name, text)

# Helper function to load test campaign data
func load_test_campaign(state: Node) -> void:
	var node := _safe_cast_node(state, "Invalid game state: not a Node")
	if not node:
		return
	
	if not _validate_game_state(node):
		return
	
	var campaign_config: Dictionary = {
		"type": GameEnums.FiveParcsecsCampaignType.STANDARD,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD,
		"victory_threshold": 10000,
		"market_state": GameEnums.MarketState.NORMAL
	}
	
	if not node.has_method("start_campaign"):
		push_error("Game state missing start_campaign method")
		return
	
	node.call("start_campaign", campaign_config)
	await get_tree().process_frame

# Helper function for safe size access
func _get_size(obj: Variant, default_value: int = 0) -> int:
	if obj is Array:
		var array := _safe_cast_array(obj, "Cannot get size of non-Array")
		return array.size()
	
	var object := _safe_cast_object(obj, "Cannot get size of non-Object")
	if not object:
		return default_value
	
	if object.has_method("size"):
		var size_result: Variant = object.call("size")
		return _safe_cast_int(size_result, "size() did not return an int")
	
	return default_value

# Helper function for safe dictionary access
func _get_dict_bool(dict: Variant, key: String, default_value: bool = false) -> bool:
	var dictionary := _safe_cast_dictionary(dict, "Cannot get bool from non-Dictionary")
	if not dictionary:
		return default_value
	
	if not key in dictionary:
		return default_value
	
	var value: Variant = dictionary.get(key)
	return _safe_cast_bool(value, "Dictionary value is not a bool")

# Helper function for safe dictionary access with int values
func _get_dict_int(dict: Variant, key: String, default_value: int = 0) -> int:
	var dictionary := _safe_cast_dictionary(dict, "Cannot get int from non-Dictionary")
	if not dictionary:
		return default_value
	
	if not key in dictionary:
		return default_value
	
	var value: Variant = dictionary.get(key)
	return _safe_cast_int(value, "Dictionary value is not an int")

# Helper function for safe dictionary access with string values
func _get_dict_string(dict: Variant, key: String, default_value: String = "") -> String:
	var dictionary := _safe_cast_dictionary(dict, "Cannot get string from non-Dictionary")
	if not dictionary:
		return default_value
	
	if not key in dictionary:
		return default_value
	
	var value: Variant = dictionary.get(key)
	return _safe_cast_string(value, "Dictionary value is not a string")