@tool
extends "res://tests/fixtures/base/game_test.gd"

const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")

const Patron: GDScript = preload("res://src/core/rivals/Patron.gd")

var patron: Patron = null

func before_each() -> void:
	await super.before_each()
	
	# Create patron instance with safer handling
	var patron_instance = Patron.new()
	
	# Check if Patron is a Resource or Node
	if patron_instance is Resource:
		patron = patron_instance
		track_test_resource(patron)
	else:
		push_error("Patron is not a Resource as expected")
		return
		
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	patron = null

func test_initialization() -> void:
	assert_not_null(patron, "Patron should be initialized")
	
	# Get properties with checks
	var name = ""
	if patron.has_method("get_name"):
		name = patron.get_name()
	
	var description = ""
	if patron.has_method("get_description"):
		description = patron.get_description()
	
	var influence = 0
	if patron.has_method("get_influence"):
		influence = patron.get_influence()
	
	var reputation_requirement = 0
	if patron.has_method("get_reputation_requirement"):
		reputation_requirement = patron.get_reputation_requirement()
	
	var quest_count = 0
	if patron.has_method("get_quest_count"):
		quest_count = patron.get_quest_count()
	
	var is_active = false
	if patron.has_method("is_active"):
		is_active = patron.is_active()
	
	assert_ne(name, "", "Should initialize with a name")
	assert_ne(description, "", "Should initialize with a description")
	assert_gt(influence, 0, "Should initialize with positive influence")
	assert_gt(reputation_requirement, 0, "Should initialize with positive reputation requirement")
	assert_eq(quest_count, 0, "Should initialize with no quests")
	assert_false(is_active, "Should initialize as inactive")

func test_quest_management() -> void:
	# Test adding quests
	var success = false
	if patron.has_method("add_quest"):
		success = patron.add_quest()
	assert_true(success, "Should successfully add quest")
	
	var quest_count = 0
	if patron.has_method("get_quest_count"):
		quest_count = patron.get_quest_count()
	assert_eq(quest_count, 1, "Should update quest count")
	
	# Test quest limit
	for i in range(TestEnums.MAX_PATRON_QUESTS - 1):
		if patron.has_method("add_quest"):
			patron.add_quest()
	
	if patron.has_method("add_quest"):
		success = patron.add_quest()
	assert_false(success, "Should fail to add quest beyond limit")
	
	if patron.has_method("get_quest_count"):
		quest_count = patron.get_quest_count()
	assert_eq(quest_count, TestEnums.MAX_PATRON_QUESTS, "Should not exceed quest limit")
	
	# Test completing quests
	if patron.has_method("complete_quest"):
		success = patron.complete_quest()
	assert_true(success, "Should successfully complete quest")
	
	if patron.has_method("get_quest_count"):
		quest_count = patron.get_quest_count()
	assert_eq(quest_count, TestEnums.MAX_PATRON_QUESTS - 1, "Should update quest count after completion")
	
	# Test failing quests
	if patron.has_method("fail_quest"):
		success = patron.fail_quest()
	assert_true(success, "Should successfully fail quest")
	
	if patron.has_method("get_quest_count"):
		quest_count = patron.get_quest_count()
	assert_eq(quest_count, TestEnums.MAX_PATRON_QUESTS - 2, "Should update quest count after failure")

func test_reputation_effects() -> void:
	# Test reputation changes
	var initial_reputation = 0
	if patron.has_method("get_reputation"):
		initial_reputation = patron.get_reputation()
	
	if patron.has_method("add_reputation"):
		patron.add_reputation(TestEnums.REPUTATION_GAIN_AMOUNT)
	
	var new_reputation = 0
	if patron.has_method("get_reputation"):
		new_reputation = patron.get_reputation()
	assert_eq(new_reputation, initial_reputation + TestEnums.REPUTATION_GAIN_AMOUNT, "Should increase reputation")
	
	if patron.has_method("remove_reputation"):
		patron.remove_reputation(TestEnums.REPUTATION_LOSS_AMOUNT)
	
	if patron.has_method("get_reputation"):
		new_reputation = patron.get_reputation()
	assert_eq(new_reputation, initial_reputation + TestEnums.REPUTATION_GAIN_AMOUNT - TestEnums.REPUTATION_LOSS_AMOUNT, "Should decrease reputation")
	
	# Test activation based on reputation
	var reputation_requirement = 0
	if patron.has_method("get_reputation_requirement"):
		reputation_requirement = patron.get_reputation_requirement()
	
	if patron.has_method("set_reputation"):
		patron.set_reputation(reputation_requirement)
	
	var is_active = false
	if patron.has_method("is_active"):
		is_active = patron.is_active()
	assert_true(is_active, "Should activate when reputation meets requirement")
	
	if patron.has_method("set_reputation"):
		patron.set_reputation(reputation_requirement - 1)
	
	if patron.has_method("is_active"):
		is_active = patron.is_active()
	assert_false(is_active, "Should deactivate when reputation falls below requirement")

func test_influence_effects() -> void:
	# Test influence changes
	var initial_influence = 0
	if patron.has_method("get_influence"):
		initial_influence = patron.get_influence()
	
	if patron.has_method("add_influence"):
		patron.add_influence(TestEnums.INFLUENCE_GAIN_AMOUNT)
	
	var new_influence = 0
	if patron.has_method("get_influence"):
		new_influence = patron.get_influence()
	assert_eq(new_influence, initial_influence + TestEnums.INFLUENCE_GAIN_AMOUNT, "Should increase influence")
	
	if patron.has_method("remove_influence"):
		patron.remove_influence(TestEnums.INFLUENCE_LOSS_AMOUNT)
	
	if patron.has_method("get_influence"):
		new_influence = patron.get_influence()
	assert_eq(new_influence, initial_influence + TestEnums.INFLUENCE_GAIN_AMOUNT - TestEnums.INFLUENCE_LOSS_AMOUNT, "Should decrease influence")
	
	# Test influence limits
	if patron.has_method("remove_influence"):
		patron.remove_influence(TestEnums.MAX_INFLUENCE)
	
	if patron.has_method("get_influence"):
		new_influence = patron.get_influence()
	assert_eq(new_influence, 0, "Should not reduce influence below 0")
	
	if patron.has_method("add_influence"):
		patron.add_influence(TestEnums.MAX_INFLUENCE)
	
	if patron.has_method("get_influence"):
		new_influence = patron.get_influence()
	assert_eq(new_influence, TestEnums.MAX_INFLUENCE, "Should not increase influence above maximum")

func test_quest_rewards() -> void:
	# Test base reward calculation
	var base_reward = 0
	if patron.has_method("calculate_quest_reward"):
		base_reward = patron.calculate_quest_reward()
	
	var influence = 0
	if patron.has_method("get_influence"):
		influence = patron.get_influence()
	
	assert_eq(base_reward, influence * TestEnums.QUEST_REWARD_MULTIPLIER, "Should calculate base reward from influence")
	
	# Test reward scaling with reputation
	if patron.has_method("set_reputation"):
		patron.set_reputation(TestEnums.REPUTATION_REWARD_THRESHOLD)
	
	var scaled_reward = 0
	if patron.has_method("calculate_quest_reward"):
		scaled_reward = patron.calculate_quest_reward()
	assert_gt(scaled_reward, base_reward, "Should scale reward with reputation")
	
	# Test reward scaling with quest count
	if patron.has_method("add_quest"):
		patron.add_quest()
		patron.add_quest()
	
	var quest_scaled_reward = 0
	if patron.has_method("calculate_quest_reward"):
		quest_scaled_reward = patron.calculate_quest_reward()
	assert_gt(quest_scaled_reward, scaled_reward, "Should scale reward with quest count")

func test_serialization() -> void:
	# Modify patron state
	if patron.has_method("set_name"):
		patron.set_name("Test Patron")
	
	if patron.has_method("set_description"):
		patron.set_description("Test Description")
	
	if patron.has_method("set_influence"):
		patron.set_influence(TestEnums.DEFAULT_INFLUENCE)
	
	if patron.has_method("set_reputation"):
		patron.set_reputation(TestEnums.DEFAULT_REPUTATION)
	
	if patron.has_method("set_reputation_requirement"):
		patron.set_reputation_requirement(TestEnums.MIN_REPUTATION_REQUIREMENT)
	
	if patron.has_method("add_quest"):
		patron.add_quest()
		patron.add_quest()
	
	# Serialize and deserialize
	var data = {}
	if patron.has_method("serialize"):
		data = patron.serialize()
	
	var new_patron = null
	if Patron:
		new_patron = Patron.new()
		track_test_resource(new_patron)
	
	if new_patron and new_patron.has_method("deserialize") and data.size() > 0:
		new_patron.deserialize(data)
	
	# Verify patron properties with safe checks
	var name = ""
	if new_patron and new_patron.has_method("get_name"):
		name = new_patron.get_name()
	
	var description = ""
	if new_patron and new_patron.has_method("get_description"):
		description = new_patron.get_description()
	
	var influence = 0
	if new_patron and new_patron.has_method("get_influence"):
		influence = new_patron.get_influence()
	
	var reputation = 0
	if new_patron and new_patron.has_method("get_reputation"):
		reputation = new_patron.get_reputation()
	
	var reputation_requirement = 0
	if new_patron and new_patron.has_method("get_reputation_requirement"):
		reputation_requirement = new_patron.get_reputation_requirement()
	
	var quest_count = 0
	if new_patron and new_patron.has_method("get_quest_count"):
		quest_count = new_patron.get_quest_count()
	
	var is_active = false
	if new_patron and new_patron.has_method("is_active"):
		is_active = new_patron.is_active()
	
	assert_eq(name, "Test Patron", "Should preserve name")
	assert_eq(description, "Test Description", "Should preserve description")
	assert_eq(influence, TestEnums.DEFAULT_INFLUENCE, "Should preserve influence")
	assert_eq(reputation, TestEnums.DEFAULT_REPUTATION, "Should preserve reputation")
	assert_eq(reputation_requirement, TestEnums.MIN_REPUTATION_REQUIREMENT, "Should preserve reputation requirement")
	assert_eq(quest_count, 2, "Should preserve quest count")
	assert_true(is_active, "Should preserve active state")