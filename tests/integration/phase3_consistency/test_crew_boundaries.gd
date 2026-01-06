extends GdUnitTestSuite
## Phase 3A: Backend Integration Tests - Crew Boundaries and Recruitment
## Tests CharacterManager crew size limits, recruitment validation, and removal cascades
## gdUnit4 v6.0.1 compatible
## HIGH BUG DISCOVERY PROBABILITY

# System under test
var CharacterManagerClass
var character_manager = null

# Test helper
var HelperClass
var helper = null

func before():
	"""Suite-level setup - runs once before all tests"""
	CharacterManagerClass = load("res://src/core/character/Management/CharacterManager.gd")
	HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh manager instance for each test"""
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	character_manager = auto_free(CharacterManagerClass.new())

	# Initialize manager (simulates _ready() without scene tree)
	character_manager._initialize_manager()
	character_manager.max_crew_size = 8  # Per FiveParsecsConstants

func after_test():
	"""Test-level cleanup"""
	character_manager = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	CharacterManagerClass = null

# ============================================================================
# Crew Size Limit Tests (3 tests)
# ============================================================================

func test_enforce_maximum_crew_size():
	"""Adding 9th crew member should fail (max 8 per rulebook)"""
	# Per FiveParsecsConstants.CHARACTER_CREATION.max_crew_size = 8

	# Add 8 crew members (fill roster)
	for i in range(8):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		assert_that(character).is_not_null()

	# Try to add 9th member (should fail)
	var overflow_character_data = {"name": "Overflow Crew", "class": 0}
	var overflow_character = character_manager.create_character(overflow_character_data)

	# Verify roster capped at 8
	assert_that(character_manager.get_crew_size()).is_equal(8)

func test_enforce_minimum_crew_size_validation():
	"""🐛 BUG DISCOVERY: Should prevent going below 4 crew members (rulebook minimum)"""
	# Per FiveParsecsConstants.CHARACTER_CREATION.min_crew_size = 4
	# EXPECTED: Should validate minimum crew size during character removal
	# ACTUAL: No minimum validation exists (CharacterManager.gd line 57-64)

	# Create exactly 4 crew members
	var character_ids = []
	for i in range(4):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		character_ids.append(character.character_id)

	assert_that(character_manager.get_crew_size()).is_equal(4)

	# Try to remove one (would go to 3, below minimum)
	var result = character_manager.remove_character_from_roster(character_ids[0])

	# EXPECTED: Should return false, crew size should stay at 4
	# ACTUAL: Returns true, crew size goes to 3 (BUG!)
	# This test will FAIL revealing missing minimum crew validation
	assert_that(result).is_false()
	assert_that(character_manager.get_crew_size()).is_equal(4)

func test_dynamic_max_crew_size_adjustment():
	"""Changing max crew size should be bounded (1 minimum, 8 default)"""
	# Per CharacterManager.gd line 87-88: max_crew_size = maxi(1, size)

	# Try setting to 0 (should clamp to 1)
	character_manager.set_max_crew_size(0)
	assert_that(character_manager.get_max_crew_size()).is_equal(1)

	# Try setting to negative (should clamp to 1)
	character_manager.set_max_crew_size(-10)
	assert_that(character_manager.get_max_crew_size()).is_equal(1)

	# Try setting to valid value
	character_manager.set_max_crew_size(6)
	assert_that(character_manager.get_max_crew_size()).is_equal(6)

# ============================================================================
# Recruitment Validation Tests (2 tests)
# ============================================================================

func test_prevent_duplicate_character_ids():
	"""🐛 BUG DISCOVERY: Should prevent adding same character twice"""
	# EXPECTED: Should validate character_id uniqueness
	# ACTUAL: No duplicate checking in add_character_to_roster (line 49-55)

	# Create first character
	var character_data = {"name": "Test Character", "class": 0}
	var character1 = character_manager.create_character(character_data)

	assert_that(character_manager.get_crew_size()).is_equal(1)

	# Try to add same character instance again
	var result = character_manager.add_character_to_roster(character1)

	# EXPECTED: Should return false (duplicate ID)
	# ACTUAL: Returns true, adds duplicate (BUG!)
	# This test will FAIL revealing missing duplicate validation
	assert_that(result).is_false()
	assert_that(character_manager.get_crew_size()).is_equal(1)  # Should stay at 1

func test_character_creation_assigns_unique_ids():
	"""Each created character should have unique ID"""
	var ids = []

	for i in range(5):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		ids.append(character.character_id)

	# All IDs should be unique
	var unique_ids = []
	for id in ids:
		if id not in unique_ids:
			unique_ids.append(id)

	assert_that(unique_ids.size()).is_equal(ids.size())

# ============================================================================
# Character Removal Cascade Tests (3 tests)
# ============================================================================

func test_character_removal_emits_signal():
	"""Removing character should emit character_removed signal"""
	# Create 5 characters first (minimum crew size is 4, need more than that to remove one)
	var character_ids = []
	for i in range(5):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		character_ids.append(character.character_id)

	# Setup signal monitor
	var signal_monitor = monitor_signals(character_manager)

	# Remove one character (now valid since 5 > 4 minimum)
	character_manager.remove_character_from_roster(character_ids[0])

	# Verify signal emitted with correct ID
	# NOTE: assert_signal().is_emitted() requires matching args - use any_string() for String arg
	await assert_signal(signal_monitor).is_emitted("character_removed", [any_string()])

func test_character_removal_updates_crew_size():
	"""Removing character should update crew size and emit signal"""
	# Create 5 crew members
	var character_ids = []
	for i in range(5):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		character_ids.append(character.character_id)

	assert_that(character_manager.get_crew_size()).is_equal(5)

	# Setup signal monitor
	var signal_monitor = monitor_signals(character_manager)

	# Remove one character
	character_manager.remove_character_from_roster(character_ids[2])

	# Verify size updated
	assert_that(character_manager.get_crew_size()).is_equal(4)
	# NOTE: assert_signal().is_emitted() requires matching args - use any_int() for int arg
	await assert_signal(signal_monitor).is_emitted("crew_size_changed", [any_int()])

func test_active_crew_consistency_after_removal():
	"""🐛 BUG DISCOVERY: Removing character from roster should also remove from active crew"""
	# EXPECTED: Removing character should update both roster and active_crew
	# ACTUAL: May only update roster (CharacterManager.gd line 57-64)

	# Create 5 crew members (above minimum so removal can succeed)
	var characters = []
	for i in range(5):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		characters.append(character)

	# Set all as active crew
	character_manager.set_active_crew(characters)
	assert_that(character_manager.get_active_crew().size()).is_equal(5)

	# Remove one character from roster
	character_manager.remove_character_from_roster(characters[1].character_id)

	# EXPECTED: Active crew should also be updated (size = 4)
	# ACTUAL: May still show size = 5 (BUG - stale active crew)
	# This test will FAIL if active crew is not synchronized
	assert_that(character_manager.get_active_crew().size()).is_equal(4)

	# Verify removed character is not in active crew
	var active_ids = []
	for crew in character_manager.get_active_crew():
		active_ids.append(crew.character_id)

	assert_that(active_ids).not_contains(characters[1].character_id)
