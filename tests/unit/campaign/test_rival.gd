@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

const Rival: GDScript = preload("res://src/core/rivals/Rival.gd")

var rival: Rival = null

func before_each() -> void:
	await super.before_each()
	rival = Rival.new()
	if not rival:
		push_error("Failed to create rival")
		return
	track_test_resource(rival)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	rival = null

func test_initialization() -> void:
	assert_not_null(rival, "Rival should be initialized")
	
	var name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(rival, "get_name", []))
	var description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(rival, "get_description", []))
	var threat_level: int = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	var hostility: int = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	var resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	var is_active: bool = TypeSafeMixin._call_node_method_bool(rival, "is_active", [], false)
	
	assert_ne(name, "", "Should initialize with a name")
	assert_ne(description, "", "Should initialize with a description")
	assert_gt(threat_level, GameEnums.MIN_THREAT_LEVEL, "Should initialize with positive threat level")
	assert_eq(hostility, GameEnums.NEUTRAL_HOSTILITY, "Should initialize with neutral hostility")
	assert_gt(resources, GameEnums.MIN_RESOURCES, "Should initialize with positive resources")
	assert_true(is_active, "Should initialize as active")

func test_hostility_management() -> void:
	# Test increasing hostility
	var initial_hostility: int = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	
	TypeSafeMixin._call_node_method_bool(rival, "increase_hostility", [GameEnums.HOSTILITY_INCREASE_AMOUNT])
	var new_hostility: int = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, initial_hostility + GameEnums.HOSTILITY_INCREASE_AMOUNT, "Should increase hostility")
	
	# Test decreasing hostility
	TypeSafeMixin._call_node_method_bool(rival, "decrease_hostility", [GameEnums.HOSTILITY_DECREASE_AMOUNT])
	new_hostility = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, initial_hostility + GameEnums.HOSTILITY_INCREASE_AMOUNT - GameEnums.HOSTILITY_DECREASE_AMOUNT, "Should decrease hostility")
	
	# Test hostility limits
	TypeSafeMixin._call_node_method_bool(rival, "increase_hostility", [GameEnums.MAX_HOSTILITY])
	new_hostility = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, GameEnums.MAX_HOSTILITY, "Should not exceed maximum hostility")
	
	TypeSafeMixin._call_node_method_bool(rival, "decrease_hostility", [GameEnums.MAX_HOSTILITY * 2])
	new_hostility = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, GameEnums.MIN_HOSTILITY, "Should not fall below minimum hostility")

func test_threat_level_management() -> void:
	# Test increasing threat level
	var initial_threat: int = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	
	TypeSafeMixin._call_node_method_bool(rival, "increase_threat_level", [GameEnums.THREAT_LEVEL_INCREASE])
	var new_threat: int = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	assert_eq(new_threat, initial_threat + GameEnums.THREAT_LEVEL_INCREASE, "Should increase threat level")
	
	# Test decreasing threat level
	TypeSafeMixin._call_node_method_bool(rival, "decrease_threat_level", [GameEnums.THREAT_LEVEL_DECREASE])
	new_threat = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	assert_eq(new_threat, initial_threat, "Should decrease threat level")
	
	# Test threat level limits
	TypeSafeMixin._call_node_method_bool(rival, "decrease_threat_level", [GameEnums.MAX_THREAT_LEVEL])
	new_threat = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	assert_eq(new_threat, GameEnums.MIN_THREAT_LEVEL, "Should not fall below minimum threat level")
	
	TypeSafeMixin._call_node_method_bool(rival, "increase_threat_level", [GameEnums.MAX_THREAT_LEVEL])
	new_threat = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	assert_eq(new_threat, GameEnums.MAX_THREAT_LEVEL, "Should not exceed maximum threat level")

func test_resource_management() -> void:
	# Test gaining resources
	var initial_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	
	TypeSafeMixin._call_node_method_bool(rival, "add_resources", [GameEnums.RESOURCE_GAIN_AMOUNT])
	var new_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(new_resources, initial_resources + GameEnums.RESOURCE_GAIN_AMOUNT, "Should increase resources")
	
	# Test spending resources
	TypeSafeMixin._call_node_method_bool(rival, "spend_resources", [GameEnums.RESOURCE_SPEND_AMOUNT])
	new_resources = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(new_resources, initial_resources + GameEnums.RESOURCE_GAIN_AMOUNT - GameEnums.RESOURCE_SPEND_AMOUNT, "Should decrease resources")
	
	# Test resource limits
	TypeSafeMixin._call_node_method_bool(rival, "spend_resources", [new_resources + GameEnums.MAX_RESOURCES])
	new_resources = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(new_resources, GameEnums.MIN_RESOURCES, "Should not fall below zero resources")

func test_activity_status() -> void:
	# Test deactivation
	TypeSafeMixin._call_node_method_bool(rival, "set_active", [false])
	var is_active: bool = TypeSafeMixin._call_node_method_bool(rival, "is_active", [], true)
	assert_false(is_active, "Should be inactive after deactivation")
	
	# Test reactivation
	TypeSafeMixin._call_node_method_bool(rival, "set_active", [true])
	is_active = TypeSafeMixin._call_node_method_bool(rival, "is_active", [], false)
	assert_true(is_active, "Should be active after reactivation")
	
	# Test activity effects on resource generation
	var initial_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	TypeSafeMixin._call_node_method_bool(rival, "generate_resources", [])
	var active_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_gt(active_resources, initial_resources, "Should generate resources when active")
	
	TypeSafeMixin._call_node_method_bool(rival, "set_active", [false])
	initial_resources = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	TypeSafeMixin._call_node_method_bool(rival, "generate_resources", [])
	var inactive_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(inactive_resources, initial_resources, "Should not generate resources when inactive")

func test_encounter_generation() -> void:
	# Test encounter generation based on threat level
	var initial_threat: int = TypeSafeMixin._call_node_method_int(rival, "get_threat_level", [], 0)
	var encounter: Dictionary = TypeSafeMixin._call_node_method_dict(rival, "generate_encounter", [], {})
	
	assert_not_null(encounter, "Should generate an encounter")
	assert_has(encounter, "difficulty", "Encounter should have difficulty")
	assert_has(encounter, "reward", "Encounter should have reward")
	
	var difficulty: int = encounter.get("difficulty", 0)
	assert_gt(difficulty, GameEnums.MIN_ENCOUNTER_DIFFICULTY, "Encounter difficulty should scale with threat level")
	
	# Test encounter scaling with higher threat
	TypeSafeMixin._call_node_method_bool(rival, "increase_threat_level", [GameEnums.THREAT_LEVEL_INCREASE])
	var harder_encounter: Dictionary = TypeSafeMixin._call_node_method_dict(rival, "generate_encounter", [], {})
	var harder_difficulty: int = harder_encounter.get("difficulty", 0)
	
	assert_gt(harder_difficulty, difficulty, "Encounter difficulty should increase with threat level")
	
	# Test encounter generation when inactive
	TypeSafeMixin._call_node_method_bool(rival, "set_active", [false])
	var inactive_encounter: Dictionary = TypeSafeMixin._call_node_method_dict(rival, "generate_encounter", [], {})
	assert_eq(inactive_encounter.size(), 0, "Should not generate encounters when inactive")

func test_serialization() -> void:
	# Modify rival state
	TypeSafeMixin._call_node_method_bool(rival, "set_name", ["Test Rival"])
	TypeSafeMixin._call_node_method_bool(rival, "set_description", ["Test Description"])
	TypeSafeMixin._call_node_method_bool(rival, "set_threat_level", [GameEnums.DEFAULT_THREAT_LEVEL])
	TypeSafeMixin._call_node_method_bool(rival, "set_hostility", [GameEnums.DEFAULT_HOSTILITY])
	TypeSafeMixin._call_node_method_bool(rival, "set_resources", [GameEnums.DEFAULT_RESOURCES])
	TypeSafeMixin._call_node_method_bool(rival, "set_active", [true])
	
	# Serialize and deserialize
	var data: Dictionary = TypeSafeMixin._call_node_method_dict(rival, "serialize", [], {})
	var new_rival: Rival = Rival.new()
	track_test_resource(new_rival)
	TypeSafeMixin._call_node_method_bool(new_rival, "deserialize", [data])
	
	# Verify rival properties
	var name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(new_rival, "get_name", []))
	var description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(new_rival, "get_description", []))
	var threat_level: int = TypeSafeMixin._call_node_method_int(new_rival, "get_threat_level", [], 0)
	var hostility: int = TypeSafeMixin._call_node_method_int(new_rival, "get_hostility", [], 0)
	var resources: int = TypeSafeMixin._call_node_method_int(new_rival, "get_resources", [], 0)
	var is_active: bool = TypeSafeMixin._call_node_method_bool(new_rival, "is_active", [], false)
	
	assert_eq(name, "Test Rival", "Should preserve name")
	assert_eq(description, "Test Description", "Should preserve description")
	assert_eq(threat_level, GameEnums.DEFAULT_THREAT_LEVEL, "Should preserve threat level")
	assert_eq(hostility, GameEnums.DEFAULT_HOSTILITY, "Should preserve hostility")
	assert_eq(resources, GameEnums.DEFAULT_RESOURCES, "Should preserve resources")
	assert_true(is_active, "Should preserve active state")