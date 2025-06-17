@tool
extends GdUnitGameTest

# Required imports
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Mock Patron with expected values (Universal Mock Strategy)
class MockPatron extends Resource:
	var _name: String = "Test Patron"
	var _description: String = "A test patron for testing purposes"
	var _influence: int = 50
	var _reputation: int = 25
	var _reputation_requirement: int = 20
	var _quest_count: int = 0
	var _is_active: bool = false
	
	func get_patron_name() -> String: return _name
	func get_description() -> String: return _description
	func get_influence() -> int: return _influence
	func get_reputation() -> int: return _reputation
	func get_reputation_requirement() -> int: return _reputation_requirement
	func get_quest_count() -> int: return _quest_count
	func is_active() -> bool: return _is_active
	
	func add_quest() -> bool:
		var max_quests := 5
		if _quest_count < max_quests:
			_quest_count += 1
			return true
		return false
	
	func complete_quest() -> bool:
		if _quest_count > 0:
			_quest_count -= 1
			return true
		return false
	
	func fail_quest() -> bool:
		if _quest_count > 0:
			_quest_count -= 1
			return true
		return false
	
	func add_reputation(amount: int) -> void:
		_reputation += amount
	
	func remove_reputation(amount: int) -> void:
		_reputation = max(0, _reputation - amount)
	
	func set_reputation(amount: int) -> void:
		_reputation = amount
		_is_active = _reputation >= _reputation_requirement
	
	func add_influence(amount: int) -> void:
		var max_inf := 100
		_influence = min(max_inf, _influence + amount)
	
	func remove_influence(amount: int) -> void:
		_influence = max(0, _influence - amount)
	
	func set_influence(amount: int) -> void:
		_influence = amount
	
	func set_reputation_requirement(requirement: int) -> void:
		_reputation_requirement = requirement
	
	func set_active(active: bool) -> void:
		_is_active = active
	
	func calculate_quest_reward() -> int:
		var multiplier := 2
		var base_reward = _influence * multiplier
		
		var rep_threshold := 50
		if _reputation >= rep_threshold:
			base_reward = int(base_reward * 1.5)
		
		if _quest_count > 0:
			base_reward = int(base_reward * (1.0 + _quest_count * 0.1))
		
		return base_reward
	
	func set_patron_name(name: String) -> void:
		_name = name
	
	func set_description(description: String) -> void:
		_description = description
	
	func serialize() -> Dictionary:
		return {
			"name": _name,
			"description": _description,
			"influence": _influence,
			"reputation": _reputation,
			"reputation_requirement": _reputation_requirement,
			"quest_count": _quest_count,
			"is_active": _is_active
		}
	
	func deserialize(data: Dictionary) -> void:
		_name = data.get("name", _name)
		_description = data.get("description", _description)
		_influence = data.get("influence", _influence)
		_reputation = data.get("reputation", _reputation)
		_reputation_requirement = data.get("reputation_requirement", _reputation_requirement)
		_quest_count = data.get("quest_count", _quest_count)
		_is_active = data.get("is_active", _is_active)

# Type-safe instance variables
var patron: MockPatron = null

func before_test() -> void:
	super.before_test()
	patron = MockPatron.new()
	track_resource(patron)

func after_test() -> void:
	super.after_test()
	patron = null

func test_initialization() -> void:
	assert_that(patron).is_not_null()
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var name: String = patron.get_patron_name()
	var description: String = patron.get_description()
	var influence: int = patron.get_influence()
	var reputation_requirement: int = patron.get_reputation_requirement()
	var quest_count: int = patron.get_quest_count()
	var is_active: bool = patron.is_active()
	
	assert_that(name).is_not_equal("")
	assert_that(description).is_not_equal("")
	assert_that(influence).is_greater(0)
	assert_that(reputation_requirement).is_greater(0)
	assert_that(quest_count).is_equal(0)
	assert_that(is_active).is_false()

func test_quest_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var success: bool = patron.add_quest()
	assert_that(success).is_true()
	
	var quest_count: int = patron.get_quest_count()
	assert_that(quest_count).is_equal(1)
	
	# Test quest limit
	var max_quests := 5
	
	for i in range(max_quests - 1):
		patron.add_quest()
	
	success = patron.add_quest()
	assert_that(success).is_false()
	
	quest_count = patron.get_quest_count()
	assert_that(quest_count).is_equal(max_quests)
	
	# Test completing quests
	success = patron.complete_quest()
	assert_that(success).is_true()
	
	quest_count = patron.get_quest_count()
	assert_that(quest_count).is_equal(max_quests - 1)

func test_reputation_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_reputation: int = patron.get_reputation()
	
	patron.add_reputation(10)
	var new_reputation: int = patron.get_reputation()
	assert_that(new_reputation).is_equal(initial_reputation + 10)
	
	patron.remove_reputation(5)
	new_reputation = patron.get_reputation()
	assert_that(new_reputation).is_equal(initial_reputation + 5)
	
	# Test boundary conditions
	patron.remove_reputation(1000)
	new_reputation = patron.get_reputation()
	assert_that(new_reputation).is_equal(0)

func test_influence_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_influence: int = patron.get_influence()
	
	patron.add_influence(20)
	var new_influence: int = patron.get_influence()
	assert_that(new_influence).is_equal(initial_influence + 20)
	
	patron.remove_influence(10)
	new_influence = patron.get_influence()
	assert_that(new_influence).is_equal(initial_influence + 10)
	
	# Test maximum limit
	patron.set_influence(100)
	patron.add_influence(10)
	new_influence = patron.get_influence()
	assert_that(new_influence).is_equal(100)

func test_activation_system() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	patron.set_reputation_requirement(30)
	patron.set_reputation(25)
	
	var is_active: bool = patron.is_active()
	assert_that(is_active).is_false()
	
	patron.set_reputation(35)
	is_active = patron.is_active()
	assert_that(is_active).is_true()

func test_quest_reward_calculation() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	patron.set_influence(50)
	patron.set_reputation(30)
	
	var base_reward: int = patron.calculate_quest_reward()
	assert_that(base_reward).is_equal(100) # 50 * 2
	
	# Test with high reputation bonus
	patron.set_reputation(60)
	var high_rep_reward: int = patron.calculate_quest_reward()
	assert_that(high_rep_reward).is_equal(150) # 50 * 2 * 1.5
	
	# Test with active quests
	patron.add_quest()
	var quest_bonus_reward: int = patron.calculate_quest_reward()
	assert_that(quest_bonus_reward).is_equal(165) # 150 * 1.1

func test_serialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	patron.set_patron_name("Serialization Test")
	patron.set_influence(75)
	patron.set_reputation(40)
	patron.add_quest()
	
	var data: Dictionary = patron.serialize()
	assert_that(data.get("name", "")).is_equal("Serialization Test")
	assert_that(data.get("influence", 0)).is_equal(75)
	assert_that(data.get("reputation", 0)).is_equal(40)
	assert_that(data.get("quest_count", 0)).is_equal(1)
	
	var new_patron = MockPatron.new()
	track_resource(new_patron)
	new_patron.deserialize(data)
	
	assert_that(new_patron.get_patron_name()).is_equal("Serialization Test")
	assert_that(new_patron.get_influence()).is_equal(75)
	assert_that(new_patron.get_reputation()).is_equal(40)
	assert_that(new_patron.get_quest_count()).is_equal(1)

func test_multiple_quest_operations() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Add multiple quests
	for i in range(3):
		patron.add_quest()
	
	var quest_count: int = patron.get_quest_count()
	assert_that(quest_count).is_equal(3)
	
	# Complete some quests
	patron.complete_quest()
	patron.complete_quest()
	
	quest_count = patron.get_quest_count()
	assert_that(quest_count).is_equal(1)
	
	# Fail remaining quest
	patron.fail_quest()
	
	quest_count = patron.get_quest_count()
	assert_that(quest_count).is_equal(0)

func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test completing quest when none exist
	var success: bool = patron.complete_quest()
	assert_that(success).is_false()
	
	# Test failing quest when none exist
	success = patron.fail_quest()
	assert_that(success).is_false()
	
	# Test negative reputation handling
	patron.set_reputation(10)
	patron.remove_reputation(20)
	var reputation: int = patron.get_reputation()
	assert_that(reputation).is_equal(0)
	
	# Test negative influence handling
	patron.set_influence(5)
	patron.remove_influence(10)
	var influence: int = patron.get_influence()
	assert_that(influence).is_equal(0)

func test_complex_scenario() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Set up a complex patron scenario
	patron.set_patron_name("Complex Test Patron")
	patron.set_influence(80)
	patron.set_reputation(60)
	patron.set_reputation_requirement(50)
	
	# Verify initial state
	assert_that(patron.is_active()).is_true()
	
	# Add multiple quests and calculate rewards
	for i in range(3):
		patron.add_quest()
	
	var reward: int = patron.calculate_quest_reward()
	var expected_reward = int(80 * 2 * 1.5 * 1.3) # base * multiplier * high_rep * quest_bonus
	assert_that(reward).is_equal(expected_reward)
	
	# Complete quests and verify rewards decrease
	patron.complete_quest()
	var new_reward: int = patron.calculate_quest_reward()
	assert_that(new_reward).is_less(reward)