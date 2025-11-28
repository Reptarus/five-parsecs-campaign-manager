extends GdUnitTestSuite

## Unit Tests for Save Persistence Gaps
## Tests the critical data persistence fixes:
## 1. battle_results serialization
## 2. Ship stash serialization (no duplicates)
## 3. Save file migration system
## 4. Equipment integrity validation

const SaveFileMigration = preload("res://src/core/state/SaveFileMigration.gd")
const Ship = preload("res://src/core/ships/Ship.gd")
const EquipmentManager = preload("res://src/core/equipment/EquipmentManager.gd")

func test_battle_results_serialization():
	# Create GameState with battle results
	var game_state = CoreGameState.new()
	
	game_state.battle_results = {
		"victory": true,
		"enemies_defeated": 5,
		"crew_casualties": 1,
		"credits_earned": 100
	}
	
	# Serialize
	var serialized = game_state.serialize()
	
	# Verify battle_results is present
	assert_bool(serialized.has("battle_results")).is_true()
	assert_dict(serialized["battle_results"]).is_not_empty()
	assert_bool(serialized["battle_results"]["victory"]).is_true()
	assert_int(serialized["battle_results"]["enemies_defeated"]).is_equal(5)
	
	# Deserialize into new instance
	var restored_state = CoreGameState.new()
	restored_state.deserialize(serialized)
	
	# Verify battle_results restored correctly
	assert_dict(restored_state.battle_results).is_not_empty()
	assert_bool(restored_state.battle_results["victory"]).is_true()
	assert_int(restored_state.battle_results["enemies_defeated"]).is_equal(5)
	assert_int(restored_state.battle_results["credits_earned"]).is_equal(100)

func test_battle_results_empty_serialization():
	# Create GameState without battle results
	var game_state = CoreGameState.new()
	
	# Serialize
	var serialized = game_state.serialize()
	
	# Verify battle_results is present but empty
	assert_bool(serialized.has("battle_results")).is_true()
	assert_dict(serialized["battle_results"]).is_empty()
	
	# Deserialize
	var restored_state = CoreGameState.new()
	restored_state.deserialize(serialized)
	
	# Verify battle_results is empty Dictionary (not null)
	assert_dict(restored_state.battle_results).is_not_null()
	assert_dict(restored_state.battle_results).is_empty()

func test_migration_v1_to_v2_adds_battle_results():
	# Create v1 save data (missing battle_results)
	var v1_data = {
		"schema_version": 1,
		"current_phase": 0,
		"turn_number": 5,
		"story_points": 2,
		"reputation": 10
		# battle_results intentionally missing
	}
	
	# Migrate to v2
	var migrated = SaveFileMigration.migrate_save_data(v1_data, 1, 2)
	
	# Verify migration succeeded
	assert_bool(migrated.has("_migration_errors")).is_false()
	assert_int(migrated["schema_version"]).is_equal(2)
	
	# Verify battle_results was added
	assert_bool(migrated.has("battle_results")).is_true()
	assert_dict(migrated["battle_results"]).is_not_null()

func test_migration_preserves_existing_battle_results():
	# Create v1 data with existing battle_results
	var v1_data = {
		"schema_version": 1,
		"current_phase": 0,
		"turn_number": 5,
		"battle_results": {
			"victory": true,
			"loot": ["item1", "item2"]
		}
	}
	
	# Migrate
	var migrated = SaveFileMigration.migrate_save_data(v1_data, 1, 2)
	
	# Verify existing data preserved
	assert_bool(migrated["battle_results"]["victory"]).is_true()
	assert_array(migrated["battle_results"]["loot"]).contains_exactly(["item1", "item2"])

func test_migration_handles_invalid_version():
	var data = {
		"schema_version": 999
	}
	
	var migrated = SaveFileMigration.migrate_save_data(data, 999, 1000)
	
	# Should return error
	assert_bool(migrated.has("_migration_errors")).is_true()
	assert_array(migrated["_migration_errors"]).is_not_empty()

func test_migration_no_op_when_versions_match():
	var data = {
		"schema_version": 2,
		"current_phase": 0,
		"battle_results": {"victory": false}
	}
	
	var migrated = SaveFileMigration.migrate_save_data(data, 2, 2)
	
	# When versions match, returns same data (no copying needed)
	assert_object(migrated).is_not_null()
	assert_bool(migrated is Dictionary).is_true()

func test_migration_needs_migration():
	assert_bool(SaveFileMigration.needs_migration(0)).is_true()
	assert_bool(SaveFileMigration.needs_migration(SaveFileMigration.CURRENT_SCHEMA_VERSION)).is_false()

func test_equipment_integrity_validation_clean_state():
	var equipment_manager = EquipmentManager.new()
	
	var report = equipment_manager.validate_equipment_integrity()
	
	# Empty state should be valid
	assert_bool(report.valid).is_true()
	assert_array(report.duplicate_ids).is_empty()
	assert_array(report.orphaned_references).is_empty()

func test_equipment_integrity_detects_missing_ids():
	var equipment_manager = EquipmentManager.new()
	
	# Add equipment without ID
	equipment_manager._equipment_storage.append({
		"name": "Test Item"
		# Missing "id" field
	})
	
	var report = equipment_manager.validate_equipment_integrity()
	
	# Should detect missing ID
	assert_bool(report.valid).is_false()
	assert_array(report.missing_required_fields).is_not_empty()

func test_ship_stash_serialization_no_duplicates():
	# This test verifies Ship.serialize() calls EquipmentManager.serialize_ship_stash()
	# and NOT duplicating stash data elsewhere
	
	var ship = Ship.new()
	var equipment_manager = EquipmentManager.new()
	ship.equipment_manager = equipment_manager
	
	# Add items to ship stash via EquipmentManager
	equipment_manager._ship_stash.append({"id": "item1", "name": "Test Item 1"})
	equipment_manager._ship_stash.append({"id": "item2", "name": "Test Item 2"})
	
	# Serialize ship
	var serialized = ship.serialize()
	
	# Verify stash is serialized once
	assert_bool(serialized.has("stash")).is_true()
	assert_array(serialized["stash"]).has_size(2)
	
	# Verify no duplicate stash keys
	var stash_key_count = 0
	for key in serialized.keys():
		if "stash" in key.to_lower():
			stash_key_count += 1
	
	assert_int(stash_key_count).is_equal(1)  # Only one "stash" key

func test_full_save_load_roundtrip_with_battle_results():
	# Create complete game state
	var original_state = CoreGameState.new()
	original_state.turn_number = 10
	original_state.story_points = 5
	original_state.battle_results = {
		"victory": true,
		"enemies_defeated": 8,
		"xp_earned": {"crew1": 3, "crew2": 2}
	}
	
	# Serialize
	var serialized = original_state.serialize()
	
	# Deserialize into new instance
	var restored_state = CoreGameState.new()
	restored_state.deserialize(serialized)
	
	# Verify all fields
	assert_int(restored_state.turn_number).is_equal(10)
	assert_int(restored_state.story_points).is_equal(5)
	assert_bool(restored_state.battle_results["victory"]).is_true()
	assert_int(restored_state.battle_results["enemies_defeated"]).is_equal(8)
	assert_dict(restored_state.battle_results["xp_earned"]).contains_key_value("crew1", 3)
