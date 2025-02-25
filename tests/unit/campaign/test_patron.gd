@tool
extends GameTest

const Patron: GDScript = preload("res://src/core/rivals/Patron.gd")

var patron: Patron = null

func before_each() -> void:
	await super.before_each()
	patron = Patron.new()
	if not patron:
		push_error("Failed to create patron")
		return
	track_test_resource(patron)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	patron = null

func test_initialization() -> void:
	assert_not_null(patron, "Patron should be initialized")
	
	var name: String = TypeSafeMixin._safe_method_call_string(patron, "get_name", [], "")
	var description: String = TypeSafeMixin._safe_method_call_string(patron, "get_description", [], "")
	var influence: int = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	var reputation_requirement: int = TypeSafeMixin._safe_method_call_int(patron, "get_reputation_requirement", [], 0)
	var quest_count: int = TypeSafeMixin._safe_method_call_int(patron, "get_quest_count", [], 0)
	var is_active: bool = TypeSafeMixin._safe_method_call_bool(patron, "is_active", [], false)
	
	assert_ne(name, "", "Should initialize with a name")
	assert_ne(description, "", "Should initialize with a description")
	assert_gt(influence, 0, "Should initialize with positive influence")
	assert_gt(reputation_requirement, 0, "Should initialize with positive reputation requirement")
	assert_eq(quest_count, 0, "Should initialize with no quests")
	assert_false(is_active, "Should initialize as inactive")

func test_quest_management() -> void:
	# Test adding quests
	var success: bool = TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [], false)
	assert_true(success, "Should successfully add quest")
	
	var quest_count: int = TypeSafeMixin._safe_method_call_int(patron, "get_quest_count", [], 0)
	assert_eq(quest_count, 1, "Should update quest count")
	
	# Test quest limit
	for i in range(GameEnums.MAX_PATRON_QUESTS - 1):
		TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [], false)
	
	success = TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [], false)
	assert_false(success, "Should fail to add quest beyond limit")
	
	quest_count = TypeSafeMixin._safe_method_call_int(patron, "get_quest_count", [], 0)
	assert_eq(quest_count, GameEnums.MAX_PATRON_QUESTS, "Should not exceed quest limit")
	
	# Test completing quests
	success = TypeSafeMixin._safe_method_call_bool(patron, "complete_quest", [], false)
	assert_true(success, "Should successfully complete quest")
	
	quest_count = TypeSafeMixin._safe_method_call_int(patron, "get_quest_count", [], 0)
	assert_eq(quest_count, GameEnums.MAX_PATRON_QUESTS - 1, "Should update quest count after completion")
	
	# Test failing quests
	success = TypeSafeMixin._safe_method_call_bool(patron, "fail_quest", [], false)
	assert_true(success, "Should successfully fail quest")
	
	quest_count = TypeSafeMixin._safe_method_call_int(patron, "get_quest_count", [], 0)
	assert_eq(quest_count, GameEnums.MAX_PATRON_QUESTS - 2, "Should update quest count after failure")

func test_reputation_effects() -> void:
	# Test reputation changes
	var initial_reputation: int = TypeSafeMixin._safe_method_call_int(patron, "get_reputation", [], 0)
	
	TypeSafeMixin._safe_method_call_bool(patron, "add_reputation", [GameEnums.REPUTATION_GAIN_AMOUNT])
	var new_reputation: int = TypeSafeMixin._safe_method_call_int(patron, "get_reputation", [], 0)
	assert_eq(new_reputation, initial_reputation + GameEnums.REPUTATION_GAIN_AMOUNT, "Should increase reputation")
	
	TypeSafeMixin._safe_method_call_bool(patron, "remove_reputation", [GameEnums.REPUTATION_LOSS_AMOUNT])
	new_reputation = TypeSafeMixin._safe_method_call_int(patron, "get_reputation", [], 0)
	assert_eq(new_reputation, initial_reputation + GameEnums.REPUTATION_GAIN_AMOUNT - GameEnums.REPUTATION_LOSS_AMOUNT, "Should decrease reputation")
	
	# Test activation based on reputation
	var reputation_requirement: int = TypeSafeMixin._safe_method_call_int(patron, "get_reputation_requirement", [], 0)
	TypeSafeMixin._safe_method_call_bool(patron, "set_reputation", [reputation_requirement])
	
	var is_active: bool = TypeSafeMixin._safe_method_call_bool(patron, "is_active", [], false)
	assert_true(is_active, "Should activate when reputation meets requirement")
	
	TypeSafeMixin._safe_method_call_bool(patron, "set_reputation", [reputation_requirement - 1])
	is_active = TypeSafeMixin._safe_method_call_bool(patron, "is_active", [], false)
	assert_false(is_active, "Should deactivate when reputation falls below requirement")

func test_influence_effects() -> void:
	# Test influence changes
	var initial_influence: int = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	
	TypeSafeMixin._safe_method_call_bool(patron, "add_influence", [GameEnums.INFLUENCE_GAIN_AMOUNT])
	var new_influence: int = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	assert_eq(new_influence, initial_influence + GameEnums.INFLUENCE_GAIN_AMOUNT, "Should increase influence")
	
	TypeSafeMixin._safe_method_call_bool(patron, "remove_influence", [GameEnums.INFLUENCE_LOSS_AMOUNT])
	new_influence = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	assert_eq(new_influence, initial_influence + GameEnums.INFLUENCE_GAIN_AMOUNT - GameEnums.INFLUENCE_LOSS_AMOUNT, "Should decrease influence")
	
	# Test influence limits
	TypeSafeMixin._safe_method_call_bool(patron, "remove_influence", [GameEnums.MAX_INFLUENCE])
	new_influence = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	assert_eq(new_influence, 0, "Should not reduce influence below 0")
	
	TypeSafeMixin._safe_method_call_bool(patron, "add_influence", [GameEnums.MAX_INFLUENCE])
	new_influence = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	assert_eq(new_influence, GameEnums.MAX_INFLUENCE, "Should not increase influence above maximum")

func test_quest_rewards() -> void:
	# Test base reward calculation
	var base_reward: int = TypeSafeMixin._safe_method_call_int(patron, "calculate_quest_reward", [], 0)
	var influence: int = TypeSafeMixin._safe_method_call_int(patron, "get_influence", [], 0)
	assert_eq(base_reward, influence * GameEnums.QUEST_REWARD_MULTIPLIER, "Should calculate base reward from influence")
	
	# Test reward scaling with reputation
	TypeSafeMixin._safe_method_call_bool(patron, "set_reputation", [GameEnums.REPUTATION_REWARD_THRESHOLD])
	var scaled_reward: int = TypeSafeMixin._safe_method_call_int(patron, "calculate_quest_reward", [], 0)
	assert_gt(scaled_reward, base_reward, "Should scale reward with reputation")
	
	# Test reward scaling with quest count
	TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [])
	TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [])
	var quest_scaled_reward: int = TypeSafeMixin._safe_method_call_int(patron, "calculate_quest_reward", [], 0)
	assert_gt(quest_scaled_reward, scaled_reward, "Should scale reward with quest count")

func test_serialization() -> void:
	# Modify patron state
	TypeSafeMixin._safe_method_call_bool(patron, "set_name", ["Test Patron"])
	TypeSafeMixin._safe_method_call_bool(patron, "set_description", ["Test Description"])
	TypeSafeMixin._safe_method_call_bool(patron, "set_influence", [GameEnums.DEFAULT_INFLUENCE])
	TypeSafeMixin._safe_method_call_bool(patron, "set_reputation", [GameEnums.DEFAULT_REPUTATION])
	TypeSafeMixin._safe_method_call_bool(patron, "set_reputation_requirement", [GameEnums.MIN_REPUTATION_REQUIREMENT])
	TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [])
	TypeSafeMixin._safe_method_call_bool(patron, "add_quest", [])
	
	# Serialize and deserialize
	var data: Dictionary = TypeSafeMixin._safe_method_call_dict(patron, "serialize", [], {})
	var new_patron: Patron = Patron.new()
	track_test_resource(new_patron)
	TypeSafeMixin._safe_method_call_bool(new_patron, "deserialize", [data])
	
	# Verify patron properties
	var name: String = TypeSafeMixin._safe_method_call_string(new_patron, "get_name", [], "")
	var description: String = TypeSafeMixin._safe_method_call_string(new_patron, "get_description", [], "")
	var influence: int = TypeSafeMixin._safe_method_call_int(new_patron, "get_influence", [], 0)
	var reputation: int = TypeSafeMixin._safe_method_call_int(new_patron, "get_reputation", [], 0)
	var reputation_requirement: int = TypeSafeMixin._safe_method_call_int(new_patron, "get_reputation_requirement", [], 0)
	var quest_count: int = TypeSafeMixin._safe_method_call_int(new_patron, "get_quest_count", [], 0)
	var is_active: bool = TypeSafeMixin._safe_method_call_bool(new_patron, "is_active", [], false)
	
	assert_eq(name, "Test Patron", "Should preserve name")
	assert_eq(description, "Test Description", "Should preserve description")
	assert_eq(influence, GameEnums.DEFAULT_INFLUENCE, "Should preserve influence")
	assert_eq(reputation, GameEnums.DEFAULT_REPUTATION, "Should preserve reputation")
	assert_eq(reputation_requirement, GameEnums.MIN_REPUTATION_REQUIREMENT, "Should preserve reputation requirement")
	assert_eq(quest_count, 2, "Should preserve quest count")
	assert_true(is_active, "Should preserve active state")