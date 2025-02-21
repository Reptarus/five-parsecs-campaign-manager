@tool
extends "res://tests/fixtures/game_test.gd"

const TableProcessorScript: GDScript = preload("res://src/core/systems/TableProcessor.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const MissionScript: GDScript = preload("res://src/core/systems/Mission.gd")

# Test variables with type annotations
var game_state: Node = null
var _credits_changed: bool = false
var _resources_changed: bool = false

# Enhanced type-safe helper methods
func _safe_cast_to_object(value: Variant, type: String, error_message: String = "") -> Object:
	if not value is Object:
		push_error("Cannot cast to %s: %s" % [type, error_message])
		return null
	return value

func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
	if not value is String:
		push_error("Cannot cast to String: %s" % error_message)
		return ""
	return value

func _safe_method_call_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return bool(result) if result is bool else default

func _safe_method_call_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return int(result) if result is int else default

func _safe_method_call_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return result if result is Array else default

func _safe_connect_signal(source: Object, signal_name: String, target: Callable) -> bool:
	if not source or not source.has_signal(signal_name):
		push_error("Signal %s not found" % signal_name)
		return false
	var err: Error = source.connect(signal_name, target)
	return err == OK

# Helper Methods
func _create_test_character() -> Node:
	var character: Node = super.create_test_character()
	if not character:
		push_error("Failed to create character instance")
		return null
	track_test_node(character)
	return character

func _create_test_mission() -> Resource:
	var mission: Resource = MissionScript.new()
	if not mission:
		push_error("Failed to create mission instance")
		return null
	
	# Type-safe method calls
	var type_result: bool = _safe_method_call_bool(mission, "set_type", [GameEnumsScript.MissionType.PATROL])
	if not type_result:
		mission.set("type", GameEnumsScript.MissionType.PATROL)
		
	var diff_result: bool = _safe_method_call_bool(mission, "set_difficulty", [GameEnumsScript.DifficultyLevel.NORMAL])
	if not diff_result:
		mission.set("difficulty", GameEnumsScript.DifficultyLevel.NORMAL)
	
	return mission

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	if not game_state:
		push_error("Failed to create game state")
		return
		
	add_child_autofree(game_state)
	assert_valid_game_state(game_state)
	
	# Type-safe signal connections
	if game_state.has_signal("credits_changed") and game_state.has_signal("resources_changed"):
		var credits_connected: bool = _safe_connect_signal(game_state, "credits_changed", _on_credits_changed)
		var resources_connected: bool = _safe_connect_signal(game_state, "resources_changed", _on_resources_changed)
		if not credits_connected or not resources_connected:
			push_error("Failed to connect game state signals")
			return
	
	await stabilize_engine()

func after_each() -> void:
	if game_state:
		if game_state.has_signal("credits_changed") and game_state.is_connected("credits_changed", _on_credits_changed):
			game_state.disconnect("credits_changed", _on_credits_changed)
		if game_state.has_signal("resources_changed") and game_state.is_connected("resources_changed", _on_resources_changed):
			game_state.disconnect("resources_changed", _on_resources_changed)
	await super.after_each()
	game_state = null

func _on_credits_changed() -> void:
	_credits_changed = true

func _on_resources_changed() -> void:
	_resources_changed = true

# Test Methods
func test_initial_state() -> void:
	assert_not_null(game_state, "Game state should be initialized")
	
	# Type-safe property access
	var campaign: Object = _safe_cast_to_object(_get_property_safe(game_state, "current_campaign"), "Campaign")
	assert_not_null(campaign, "Campaign should be initialized")
	
	# Type-safe method calls with explicit return types
	var difficulty_level: int = _safe_method_call_int(game_state, "get_difficulty_level", [], GameEnumsScript.DifficultyLevel.NORMAL)
	assert_eq(difficulty_level, GameEnumsScript.DifficultyLevel.NORMAL, "Should start with normal difficulty")
	
	var enable_permadeath: bool = _safe_method_call_bool(game_state, "get_enable_permadeath", [], true)
	assert_true(enable_permadeath, "Should start with permadeath enabled")
	
	var use_story_track: bool = _safe_method_call_bool(game_state, "get_use_story_track", [], true)
	assert_true(use_story_track, "Should start with story track enabled")
	
	assert_valid_game_state(game_state)

func test_crew_management() -> void:
	var character: Node = _create_test_character()
	if not character:
		push_error("Failed to create test character")
		return
	
	# Type-safe property access
	var campaign: Object = _safe_cast_to_object(_get_property_safe(game_state, "current_campaign"), "Campaign")
	if not campaign:
		push_error("Campaign not initialized")
		return
	
	# Type-safe method calls
	var add_result: bool = _safe_method_call_bool(campaign, "add_crew_member", [character])
	if not add_result:
		push_error("Failed to add crew member")
		return
	
	await get_tree().create_timer(0.1).timeout
	verify_signal_emitted(campaign, "crew_changed", "Crew changed signal should be emitted")
	
	var crew_members: Array = _safe_method_call_array(campaign, "get_crew_members")
	assert_eq(crew_members.size(), 1, "Crew should have one member")
	
	var character_id: String = _safe_cast_to_string(_get_property_safe(character, "character_id"), "character_id")
	var remove_result: bool = _safe_method_call_bool(campaign, "remove_crew_member", [character_id])
	if not remove_result:
		push_error("Failed to remove crew member")
		return
	
	await get_tree().create_timer(0.1).timeout
	verify_signal_emitted(campaign, "crew_changed", "Crew changed signal should be emitted")
	
	crew_members = _safe_method_call_array(campaign, "get_crew_members")
	assert_eq(crew_members.size(), 0, "Crew should be empty")

func test_resource_management() -> void:
	if not game_state.has_method("set_credits"):
		push_error("Game state missing set_credits method")
		return
	
	var set_credits_result: bool = _safe_method_call_bool(game_state, "set_credits", [1000])
	if not set_credits_result:
		push_error("Failed to set credits")
		return
	
	await get_tree().create_timer(0.1).timeout
	assert_true(_credits_changed, "Credits changed signal should be emitted")
	
	var credits: int = _safe_method_call_int(game_state, "get_credits", [], 0)
	assert_eq(credits, 1000, "Credits should be tracked")
	
	var set_resource_result: bool = _safe_method_call_bool(game_state, "set_resource", [GameEnumsScript.ResourceType.FUEL, 50])
	if not set_resource_result:
		push_error("Failed to set resource")
		return
	
	await get_tree().create_timer(0.1).timeout
	assert_true(_resources_changed, "Resources changed signal should be emitted")
	
	var fuel: int = _safe_method_call_int(game_state, "get_resource", [GameEnumsScript.ResourceType.FUEL], 0)
	assert_eq(fuel, 50, "Resources should be tracked")

func test_mission_management() -> void:
	var mission: Resource = _create_test_mission()
	if not mission:
		push_error("Failed to create test mission")
		return
	
	track_test_resource(mission)
	
	var add_result: bool = _safe_method_call_bool(game_state, "add_mission", [mission])
	if not add_result:
		push_error("Failed to add mission")
		return
	
	await get_tree().create_timer(0.1).timeout
	verify_signal_emitted(game_state, "mission_added", "Mission added signal should be emitted")
	
	var active_missions: Array = _safe_method_call_array(game_state, "get_active_missions")
	assert_eq(active_missions.size(), 1, "Should have one active mission")
	
	var mission_id: String = _safe_cast_to_string(_get_property_safe(mission, "mission_id"), "mission_id")
	var complete_result: bool = _safe_method_call_bool(game_state, "complete_mission", [mission_id])
	if not complete_result:
		push_error("Failed to complete mission")
		return
	
	await get_tree().create_timer(0.1).timeout
	verify_signal_emitted(game_state, "mission_completed", "Mission completed signal should be emitted")
	
	active_missions = _safe_method_call_array(game_state, "get_active_missions")
	assert_eq(active_missions.size(), 0, "Should have no active missions")
	
	var completed_missions: Array = _safe_method_call_array(game_state, "get_completed_missions")
	assert_eq(completed_missions.size(), 1, "Should have one completed mission")
