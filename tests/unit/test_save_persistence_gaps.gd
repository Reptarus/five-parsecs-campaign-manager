extends GdUnitTestSuite

## Save-persistence gap tests (rewritten 2026-07-02).
##
## The original file was written against a GameState API that no longer
## exists (serialize(), public battle_results / turn_number / story_points
## properties, EquipmentManager.validate_equipment_integrity(),
## EquipmentManager._ship_stash, Ship.serialize(), Ship.equipment_manager)
## and constructed DETACHED GameState nodes — which triggered the
## _restore_equipment_from_campaign infinite self-defer segfault on any
## machine with a real save on disk, killing every full-suite run.
##
## Cut cases (tested removed APIs; nothing equivalent to assert):
##   - test_equipment_integrity_validation_clean_state
##   - test_equipment_integrity_detects_missing_ids
##   - test_ship_stash_serialization_no_duplicates
## Ship-stash persistence is covered by
## tests/unit/test_equipment_persistence.gd and
## tests/unit/test_equipment_transfer_service.gd.

const CoreGameState = preload("res://src/core/state/GameState.gd")
const SaveFileMigration = preload("res://src/core/state/SaveFileMigration.gd")


func _make_game_state():
	# In-tree instance — the equipment-restore path is tree-dependent, so
	# GameState nodes in tests follow the test_ship_stash_persistence.gd
	# idiom: auto_free + add_child.
	var game_state = auto_free(CoreGameState.new())
	add_child(game_state)
	return game_state


func test_battle_results_transient_roundtrip():
	# battle_results is transient runtime state held between battle end and
	# post-battle processing (set/get/clear API over private _battle_results).
	var game_state = _make_game_state()
	game_state.set_battle_results({
		"victory": true,
		"enemies_defeated": 5,
		"crew_casualties": 1,
		"credits_earned": 100
	})

	var results: Dictionary = game_state.get_battle_results()
	assert_bool(results["victory"]).is_true()
	assert_int(results["enemies_defeated"]).is_equal(5)
	assert_int(results["credits_earned"]).is_equal(100)

	game_state.clear_battle_results()
	assert_dict(game_state.get_battle_results()).is_empty()


func test_battle_results_defaults_empty():
	var game_state = _make_game_state()
	assert_dict(game_state.get_battle_results()).is_empty()


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
	assert_bool(SaveFileMigration.needs_migration(
		SaveFileMigration.CURRENT_SCHEMA_VERSION)).is_false()


func test_deserialize_restores_core_fields():
	var game_state = _make_game_state()

	var result: Dictionary = game_state.deserialize({
		"turn_number": 10,
		"story_points": 5,
		"reputation": 42,
		"current_phase": 2
	})

	assert_bool(result.get("success", false)).is_true()
	assert_int(game_state.get_turn_number()).is_equal(10)
	assert_int(game_state.get_story_points()).is_equal(5)
	assert_int(game_state.get_reputation()).is_equal(42)


func test_deserialize_rejects_empty_data():
	var game_state = _make_game_state()

	var result: Dictionary = game_state.deserialize({})

	assert_bool(result.get("success", true)).is_false()


func test_detached_game_state_construction_does_not_crash():
	# Regression guard for the infinite self-defer segfault (GameState.gd
	# _restore_equipment_from_campaign): constructing a DETACHED GameState —
	# whose _init auto-load path may queue an equipment restore — must not
	# requeue deferred calls forever. The node never enters the tree; the
	# queued restore simply stays pending.
	var game_state = auto_free(CoreGameState.new())
	assert_object(game_state).is_not_null()

	# Survive several deferred-queue flushes (the old code segfaulted here).
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(game_state.is_inside_tree()).is_false()
