extends GdUnitTestSuite
## Phase 2A: Backend Integration Tests - Part 2: Equipment Management
## Tests EquipmentManager stash bounds, loot overflow, and equipment cascades
## gdUnit4 v6.0.1 compatible
## HIGH BUG DISCOVERY PROBABILITY

# System under test
var EquipmentManagerClass
var equipment_manager: Node = null

func before():
	"""Suite-level setup - runs once before all tests"""
	EquipmentManagerClass = load("res://src/core/equipment/EquipmentManager.gd")

func before_test():
	"""Test-level setup - create fresh manager instance for each test"""
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	# Create equipment manager instance without adding to tree
	# (avoids dependency issues with CharacterManager/GameState)
	equipment_manager = auto_free(EquipmentManagerClass.new())

func after_test():
	"""Test-level cleanup"""
	equipment_manager = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	EquipmentManagerClass = null

# ============================================================================
# Equipment Stash Bounds Tests (3 tests) - BUG DISCOVERY
# ============================================================================

func test_add_equipment_within_limit():
	"""Adding equipment within 10-item limit succeeds"""
	# Add 10 items (should all succeed)
	for i in range(10):
		var equipment = {"id": "item_%d" % i, "type": "WEAPON", "name": "Weapon %d" % i}
		var result = equipment_manager.add_equipment(equipment)
		assert_that(result).is_true()

	# Verify all 10 items are in storage
	var all_equipment = equipment_manager.get_all_equipment()
	assert_that(all_equipment.size()).is_equal(10)

func test_add_equipment_at_limit_boundary():
	"""Adding 10th equipment item succeeds (boundary test)"""
	# Add 9 items
	for i in range(9):
		var equipment = {"id": "item_%d" % i, "type": "WEAPON"}
		equipment_manager.add_equipment(equipment)

	# Add 10th item (should succeed)
	var tenth_item = {"id": "item_10", "type": "WEAPON", "name": "Tenth Item"}
	var result = equipment_manager.add_equipment(tenth_item)

	assert_that(result).is_true()
	assert_that(equipment_manager.get_all_equipment().size()).is_equal(10)

func test_add_equipment_exceeds_limit():
	"""🐛 BUG: Adding 11th equipment item should fail (Five Parsecs max 10 stash)"""
	# Add 10 items to fill stash
	for i in range(10):
		var equipment = {"id": "item_%d" % i, "type": "WEAPON"}
		equipment_manager.add_equipment(equipment)

	# Try to add 11th item (SHOULD FAIL but currently succeeds - BUG!)
	var eleventh_item = {"id": "item_11", "type": "WEAPON", "name": "Overflow Item"}
	var result = equipment_manager.add_equipment(eleventh_item)

	# EXPECTED: Should fail or require player choice to discard an item
	# ACTUAL: Currently succeeds (no bounds checking)
	# This test will FAIL until bug is fixed
	assert_that(result).is_false()  # Should reject overflow
	assert_that(equipment_manager.get_all_equipment().size()).is_less_equal(10)

# ============================================================================
# Equipment Removal Tests (3 tests)
# ============================================================================

func test_remove_equipment_from_storage():
	"""Removing equipment from storage works correctly"""
	# Add equipment
	var equipment = {"id": "test_weapon", "type": "WEAPON", "name": "Test Weapon"}
	equipment_manager.add_equipment(equipment)

	# Remove it
	var result = equipment_manager.remove_equipment("test_weapon")

	assert_that(result).is_true()
	assert_that(equipment_manager.get_equipment("test_weapon")).is_empty()

func test_remove_nonexistent_equipment_returns_false():
	"""Removing non-existent equipment returns false"""
	var result = equipment_manager.remove_equipment("nonexistent_id")

	# Should gracefully handle (currently returns false when not found)
	assert_that(result).is_false()

func test_character_removal_cascade_bug():
	"""🐛 BUG: Removing character should return their equipped items to storage"""
	# Add equipment to storage
	var weapon = {"id": "test_rifle", "type": "WEAPON", "name": "Colony Rifle"}
	equipment_manager.add_equipment(weapon)

	# Manually assign equipment to character (bypassing CharacterManager)
	var character_id = "test_captain"
	equipment_manager._character_equipment[character_id] = ["test_rifle"]

	# Manually remove weapon from storage to simulate assignment
	equipment_manager._equipment_storage.erase(weapon)

	# Verify weapon is NOT in storage (it's equipped)
	var storage_before = equipment_manager.get_all_equipment()
	assert_that(storage_before.size()).is_equal(0)

	# Simulate character removal (calls actual manager function)
	equipment_manager._on_character_removed(character_id)

	# EXPECTED: Equipment should return to storage
	# ACTUAL: Equipment is lost (just erases character_equipment entry)
	# This test will FAIL until bug is fixed
	var storage_after = equipment_manager.get_all_equipment()
	var equipment_returned = false
	for item in storage_after:
		if item.get("id", "") == "test_rifle":
			equipment_returned = true

	assert_that(equipment_returned).is_true()  # Should be back in storage

# ============================================================================
# Equipment Validation Tests (2 tests)
# ============================================================================

func test_add_equipment_duplicate_id_rejected():
	"""Adding equipment with duplicate ID is rejected"""
	# Add first equipment
	var weapon1 = {"id": "duplicate_id", "type": "WEAPON", "name": "First Weapon"}
	var result1 = equipment_manager.add_equipment(weapon1)
	assert_that(result1).is_true()

	# Try to add second equipment with same ID
	var weapon2 = {"id": "duplicate_id", "type": "WEAPON", "name": "Second Weapon"}
	var result2 = equipment_manager.add_equipment(weapon2)

	assert_that(result2).is_false()
	assert_that(equipment_manager.get_all_equipment().size()).is_equal(1)

func test_add_equipment_missing_id_rejected():
	"""Adding equipment without ID is rejected"""
	var invalid_equipment = {"type": "WEAPON", "name": "No ID Weapon"}
	var result = equipment_manager.add_equipment(invalid_equipment)

	assert_that(result).is_false()
	assert_that(equipment_manager.get_all_equipment().size()).is_equal(0)
