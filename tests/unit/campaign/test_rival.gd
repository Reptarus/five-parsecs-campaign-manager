@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

const Rival: GDScript = preload("res://src/core/rivals/Rival.gd")
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")

var rival: Rival = null

func before_each() -> void:
	await super.before_each()
	
	# Create rival instance with safer handling
	var rival_instance = Rival.new()
	
	# Check if Rival is a Resource or Node
	if rival_instance is Resource:
		rival = rival_instance
		track_test_resource(rival)
	else:
		push_error("Rival is not a Resource as expected")
		return
		
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	rival = null

func test_initialization() -> void:
	assert_not_null(rival, "Rival should be initialized")
	
	# Get properties with checks
	var name = ""
	if rival.has_method("get_name"):
		name = rival.get_name()
	
	var description = ""
	if rival.has_method("get_description"):
		description = rival.get_description()
	
	var threat_level = 0
	if rival.has_method("get_threat_level"):
		threat_level = rival.get_threat_level()
	
	var crew_size = 0
	if rival.has_method("get_crew_size"):
		crew_size = rival.get_crew_size()
	
	var status = ""
	if rival.has_method("get_status"):
		status = rival.get_status()
	
	assert_ne(name, "", "Should initialize with a name")
	assert_ne(description, "", "Should initialize with a description")
	assert_gt(threat_level, 0, "Should initialize with positive threat level")
	assert_gt(crew_size, 0, "Should initialize with positive crew size")
	assert_eq(status, "active", "Should initialize as active")

func test_hostility_management() -> void:
	# Test increasing hostility
	var initial_hostility: int = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	
	TypeSafeMixin._call_node_method_bool(rival, "increase_hostility", [TestEnums.HOSTILITY_INCREASE_AMOUNT])
	var new_hostility: int = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, initial_hostility + TestEnums.HOSTILITY_INCREASE_AMOUNT, "Should increase hostility")
	
	# Test decreasing hostility
	TypeSafeMixin._call_node_method_bool(rival, "decrease_hostility", [TestEnums.HOSTILITY_DECREASE_AMOUNT])
	new_hostility = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, initial_hostility + TestEnums.HOSTILITY_INCREASE_AMOUNT - TestEnums.HOSTILITY_DECREASE_AMOUNT, "Should decrease hostility")
	
	# Test hostility limits
	TypeSafeMixin._call_node_method_bool(rival, "increase_hostility", [TestEnums.MAX_HOSTILITY])
	new_hostility = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, TestEnums.MAX_HOSTILITY, "Should not exceed maximum hostility")
	
	TypeSafeMixin._call_node_method_bool(rival, "decrease_hostility", [TestEnums.MAX_HOSTILITY * 2])
	new_hostility = TypeSafeMixin._call_node_method_int(rival, "get_hostility", [], 0)
	assert_eq(new_hostility, TestEnums.MIN_HOSTILITY, "Should not fall below minimum hostility")

func test_threat_level_management() -> void:
	# Test increasing threat level
	var initial_threat = 0
	if rival.has_method("get_threat_level"):
		initial_threat = rival.get_threat_level()
	
	if rival.has_method("increase_threat_level"):
		rival.increase_threat_level(5)
	
	var new_threat = 0
	if rival.has_method("get_threat_level"):
		new_threat = rival.get_threat_level()
	assert_eq(new_threat, initial_threat + 5, "Should increase threat level")
	
	# Test decreasing threat level
	if rival.has_method("decrease_threat_level"):
		rival.decrease_threat_level(3)
	
	if rival.has_method("get_threat_level"):
		new_threat = rival.get_threat_level()
	assert_eq(new_threat, initial_threat + 5 - 3, "Should decrease threat level")
	
	# Test threat level limits
	if rival.has_method("decrease_threat_level"):
		rival.decrease_threat_level(100)
	
	if rival.has_method("get_threat_level"):
		new_threat = rival.get_threat_level()
	assert_eq(new_threat, 1, "Should not decrease threat level below minimum")
	
	if rival.has_method("increase_threat_level"):
		rival.increase_threat_level(100)
	
	if rival.has_method("get_threat_level"):
		new_threat = rival.get_threat_level()
	assert_eq(new_threat, 10, "Should not increase threat level above maximum")

func test_resource_management() -> void:
	# Test gaining resources
	var initial_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	
	TypeSafeMixin._call_node_method_bool(rival, "add_resources", [TestEnums.RESOURCE_GAIN_AMOUNT])
	var new_resources: int = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(new_resources, initial_resources + TestEnums.RESOURCE_GAIN_AMOUNT, "Should increase resources")
	
	# Test spending resources
	TypeSafeMixin._call_node_method_bool(rival, "spend_resources", [TestEnums.RESOURCE_SPEND_AMOUNT])
	new_resources = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(new_resources, initial_resources + TestEnums.RESOURCE_GAIN_AMOUNT - TestEnums.RESOURCE_SPEND_AMOUNT, "Should decrease resources")
	
	# Test resource limits
	TypeSafeMixin._call_node_method_bool(rival, "spend_resources", [new_resources + TestEnums.MAX_RESOURCES])
	new_resources = TypeSafeMixin._call_node_method_int(rival, "get_resources", [], 0)
	assert_eq(new_resources, TestEnums.MIN_RESOURCES, "Should not fall below zero resources")

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
	if rival.has_method("set_threat_level"):
		rival.set_threat_level(2)
	
	var low_threat_encounter = null
	if rival.has_method("generate_encounter"):
		low_threat_encounter = rival.generate_encounter()
	
	assert_not_null(low_threat_encounter, "Should generate encounter for low threat")
	if low_threat_encounter:
		assert_has(low_threat_encounter, "enemy_count")
		assert_has(low_threat_encounter, "difficulty")
		assert_le(low_threat_encounter.enemy_count, 5, "Low threat should limit enemy count")
	
	if rival.has_method("set_threat_level"):
		rival.set_threat_level(8)
	
	var high_threat_encounter = null
	if rival.has_method("generate_encounter"):
		high_threat_encounter = rival.generate_encounter()
	
	assert_not_null(high_threat_encounter, "Should generate encounter for high threat")
	if high_threat_encounter:
		assert_has(high_threat_encounter, "enemy_count")
		assert_has(high_threat_encounter, "difficulty")
		assert_gt(high_threat_encounter.enemy_count, 5, "High threat should allow more enemies")

func test_crew_management() -> void:
	# Test adding crew members
	var initial_crew = 0
	if rival.has_method("get_crew_size"):
		initial_crew = rival.get_crew_size()
	
	if rival.has_method("add_crew_members"):
		rival.add_crew_members(3)
	
	var new_crew = 0
	if rival.has_method("get_crew_size"):
		new_crew = rival.get_crew_size()
	assert_eq(new_crew, initial_crew + 3, "Should add crew members")
	
	# Test removing crew members
	if rival.has_method("remove_crew_members"):
		rival.remove_crew_members(2)
	
	if rival.has_method("get_crew_size"):
		new_crew = rival.get_crew_size()
	assert_eq(new_crew, initial_crew + 3 - 2, "Should remove crew members")
	
	# Test crew size limits
	if rival.has_method("remove_crew_members"):
		rival.remove_crew_members(100)
	
	if rival.has_method("get_crew_size"):
		new_crew = rival.get_crew_size()
	assert_gt(new_crew, 0, "Should maintain minimum crew size")
	
	if rival.has_method("add_crew_members"):
		rival.add_crew_members(100)
	
	if rival.has_method("get_crew_size"):
		new_crew = rival.get_crew_size()
	assert_le(new_crew, 20, "Should not exceed maximum crew size")

func test_status_changes() -> void:
	# Test deactivating rival
	if rival.has_method("deactivate"):
		rival.deactivate()
	
	var status = ""
	if rival.has_method("get_status"):
		status = rival.get_status()
	assert_eq(status, "inactive", "Should change status to inactive")
	
	# Test activating rival
	if rival.has_method("activate"):
		rival.activate()
	
	if rival.has_method("get_status"):
		status = rival.get_status()
	assert_eq(status, "active", "Should change status to active")
	
	# Test defeating rival
	if rival.has_method("defeat"):
		rival.defeat()
	
	if rival.has_method("get_status"):
		status = rival.get_status()
	assert_eq(status, "defeated", "Should change status to defeated")
	
	# Test reviving rival
	if rival.has_method("revive"):
		rival.revive()
	
	if rival.has_method("get_status"):
		status = rival.get_status()
	assert_eq(status, "active", "Should revive to active status")

func test_reward_calculation() -> void:
	# Test reward calculation based on threat level
	if rival.has_method("set_threat_level"):
		rival.set_threat_level(2)
	
	var low_threat_reward = 0
	if rival.has_method("calculate_reward"):
		low_threat_reward = rival.calculate_reward()
	
	if rival.has_method("set_threat_level"):
		rival.set_threat_level(8)
	
	var high_threat_reward = 0
	if rival.has_method("calculate_reward"):
		high_threat_reward = rival.calculate_reward()
	
	assert_gt(high_threat_reward, low_threat_reward, "Higher threat should yield greater rewards")
	
	# Test reward calculation based on crew size
	if rival.has_method("set_crew_size"):
		rival.set_crew_size(3)
	
	var small_crew_reward = 0
	if rival.has_method("calculate_reward"):
		small_crew_reward = rival.calculate_reward()
	
	if rival.has_method("set_crew_size"):
		rival.set_crew_size(15)
	
	var large_crew_reward = 0
	if rival.has_method("calculate_reward"):
		large_crew_reward = rival.calculate_reward()
	
	assert_gt(large_crew_reward, small_crew_reward, "Larger crew should yield greater rewards")

func test_serialization() -> void:
	# Modify rival state
	if rival.has_method("set_name"):
		rival.set_name("Test Rival")
	
	if rival.has_method("set_description"):
		rival.set_description("Test Description")
	
	if rival.has_method("set_threat_level"):
		rival.set_threat_level(5)
	
	if rival.has_method("set_crew_size"):
		rival.set_crew_size(10)
	
	if rival.has_method("deactivate"):
		rival.deactivate()
	
	# Serialize and deserialize
	var data = {}
	if rival.has_method("serialize"):
		data = rival.serialize()
	
	var new_rival = null
	if Rival:
		new_rival = Rival.new()
		track_test_resource(new_rival)
	
	if new_rival and new_rival.has_method("deserialize") and data.size() > 0:
		new_rival.deserialize(data)
	
	# Verify rival properties with safe checks
	var name = ""
	if new_rival and new_rival.has_method("get_name"):
		name = new_rival.get_name()
	
	var description = ""
	if new_rival and new_rival.has_method("get_description"):
		description = new_rival.get_description()
	
	var threat_level = 0
	if new_rival and new_rival.has_method("get_threat_level"):
		threat_level = new_rival.get_threat_level()
	
	var crew_size = 0
	if new_rival and new_rival.has_method("get_crew_size"):
		crew_size = new_rival.get_crew_size()
	
	var status = ""
	if new_rival and new_rival.has_method("get_status"):
		status = new_rival.get_status()
	
	assert_eq(name, "Test Rival", "Should preserve name")
	assert_eq(description, "Test Description", "Should preserve description")
	assert_eq(threat_level, 5, "Should preserve threat level")
	assert_eq(crew_size, 10, "Should preserve crew size")
	assert_eq(status, "inactive", "Should preserve status")