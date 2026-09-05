extends GdUnitTestSuite
## Phase 3C: Backend Integration Tests - Edge Cases and Negative Paths
## Tests error recovery, null handling, and boundary conditions.
##
## Trimmed 2026-09-04 from 12 cases to 3. Two drove src/core/systems/EconomySystem.gd,
## deleted as production-dead — UpkeepSystem.gd:277-282 already records that its
## "PRIORITY 1: use EconomySystem" branch was permanently dead and that the credit
## authority is the campaign itself. Its construction lived in the SHARED before_test(),
## so it had to come out of setup before any case could survive.
##
## The other seven were removed because they assert NOTHING. Six had comment-only
## bodies that "document expected behavior" (null equipment rejection, negative damage,
## stat clamping, empty stash, config validation, exception handling) and one
## (invalid_phase_transition_prevented) set current_phase twice and checked no result.
## They reported PASS on every run while testing no product code, which is worse than
## absent coverage: it reads as a green edge-case suite that does not exist. If those
## behaviours are worth guarding, they need real assertions against the real APIs.

# System under test
var CharacterManagerClass
var CampaignPhaseManagerClass

var character_manager = null
var phase_manager = null

func before():
	"""Suite-level setup - runs once before all tests"""
	CharacterManagerClass = load("res://src/core/character/Management/CharacterManager.gd")
	CampaignPhaseManagerClass = load("res://src/core/campaign/CampaignPhaseManager.gd")

func before_test():
	"""Test-level setup - create fresh instances for each test"""
	seed(12345)

	character_manager = auto_free(CharacterManagerClass.new())
	phase_manager = auto_free(CampaignPhaseManagerClass.new())

	# crew_roster is typed Array[Character], so clear() rather than reassign
	character_manager.crew_roster.clear()
	character_manager.max_crew_size = 8

	phase_manager.turn_number = 1
	phase_manager.current_phase = 0  # NONE

func after_test():
	"""Test-level cleanup"""
	character_manager = null
	phase_manager = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	CharacterManagerClass = null
	CampaignPhaseManagerClass = null

# ============================================================================
# Null Safety Tests
# ============================================================================

func test_null_character_reference_handling():
	"""🐛 BUG DISCOVERY: Operations with null characters should fail gracefully"""
	# EXPECTED: Should validate character exists before operations
	# ACTUAL: May crash with null reference error

	# Real API is remove_character() (the old remove_character_from_roster
	# never existed on the current CharacterManager)
	var result = character_manager.remove_character("")

	# Should return false (not crash)
	assert_that(result).is_false()

	# Try with completely invalid ID (non-existent)
	# Note: GDScript typed functions don't accept null for String parameters,
	# so we test with an obviously invalid ID instead
	result = character_manager.remove_character("__invalid_nonexistent_id__")

	# Should handle missing character gracefully (return false, not crash)
	assert_that(result).is_false()

func test_empty_array_handling():
	"""Empty arrays should be handled without errors (real registry API:
	get_all_characters/get_active_characters — get_crew_size/get_active_crew
	never existed on the current CharacterManager)"""
	assert_that(character_manager.get_all_characters().size()).is_equal(0)

	# Empty crew should still return valid (empty) array
	var crew = character_manager.get_active_characters()
	assert_that(crew).is_not_null()
	assert_that(crew.size()).is_equal(0)

# ============================================================================
# Invalid Input Tests (3 tests)
# ============================================================================

# ============================================================================
# Boundary Condition Tests
# ============================================================================

func test_maximum_turn_number_overflow():
	"""🐛 BUG DISCOVERY: Turn number should handle very large values"""
	# EXPECTED: Turn number should have reasonable bounds or use int64
	# ACTUAL: GDScript int is 64-bit, so overflow happens at much larger values
	# Note: In GDScript 4.x, int is 64-bit signed, so INT32_MAX + 1 doesn't overflow

	# Set to near-maximum 32-bit value
	phase_manager.turn_number = 2147483647  # INT32_MAX

	# Increment turn - in 64-bit int this just becomes 2147483648
	phase_manager.turn_number += 1

	# In GDScript 4.x (64-bit int), this should be positive
	# This documents that modern GDScript handles "32-bit overflow" gracefully
	assert_that(phase_manager.turn_number).is_equal(2147483648)

