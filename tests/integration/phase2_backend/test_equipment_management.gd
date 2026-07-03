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

func test_add_equipment_beyond_ten_is_allowed():
	"""No stash cap exists in the Core Rules (updated 2026-07-02) — the old
	'max 10 stash' expectation was a fabricated limit. The ship stash is
	uncapped; items just sell for 1 credit each (p.125)."""
	for i in range(10):
		var equipment = {"id": "item_%d" % i, "type": "WEAPON"}
		equipment_manager.add_equipment(equipment)

	var eleventh_item = {"id": "item_11", "type": "WEAPON", "name": "Eleventh Item"}
	var result = equipment_manager.add_equipment(eleventh_item)

	assert_that(result).is_true()
	assert_that(equipment_manager.get_all_equipment().size()).is_equal(11)

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

func test_character_removal_releases_items_to_pool():
	"""Removing a character releases their items back to the unassigned
	pool (updated 2026-07-02 to the REAL ownership model: _equipment_storage
	holds ALL item dicts; _character_equipment only tracks ownership ids, so
	clearing ownership IS the return-to-stash. The old test manually deleted
	the item dict from storage — a state the real flow never produces; the
	dismiss-crew flow's 'recover 1 item' book rule lives at the flow layer)."""
	var weapon = {"id": "test_rifle", "type": "WEAPON", "name": "Colony Rifle"}
	equipment_manager.add_equipment(weapon)

	var character_id = "test_captain"
	equipment_manager._character_equipment[character_id] = ["test_rifle"]

	equipment_manager._on_character_removed(character_id)

	# Ownership cleared; the item dict still exists in the pool
	assert_that(equipment_manager._character_equipment.has(character_id)).is_false()
	var equipment_present = false
	for item in equipment_manager.get_all_equipment():
		if item.get("id", "") == "test_rifle":
			equipment_present = true

	assert_that(equipment_present).is_true()

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
