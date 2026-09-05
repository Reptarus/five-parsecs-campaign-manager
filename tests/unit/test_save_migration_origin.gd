extends GdUnitTestSuite
## SaveFileMigration: the v1 -> v2 crew `origin` normalisation.
##
## WHAT WAS WRONG (2026-09-04). The framework existed, was tested, and could
## never have been wired:
##   * _validate_migrated_data required top-level `schema_version`,
##     `current_phase`, `turn_number` and `battle_results`. A census of 21 real
##     5PFH saves found 0 of the last 3 in ANY of them, and schema_version nested
##     under `meta` in ALL of them. Wiring it in would have rejected every save.
##   * CURRENT_SCHEMA_VERSION was 1 while the only step was _migrate_v1_to_v2, so
##     needs_migration(1) was false and that step was unreachable.
##   * The step itself added a `battle_results` key that nothing reads.
##
## THE REAL PROBLEM IT NOW SOLVES. `Character.origin` is a validated String, but
## older saves stored the GlobalEnums.Origin ORDINAL. The census:
##
##     origin shape   crew   captain
##     float             4         0
##     int              59        10
##     String           48        11
##
## 69 of 132 crew/captain records - 52% - hold a number, and `int` outnumbers
## `float` 17:1. CLAUDE.md documented only the float case, so a migration written
## from the docs would have been tested against the rarest shape. These fixtures
## use every shape actually observed on disk.

const SaveFileMigration = preload("res://src/core/state/SaveFileMigration.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


## A save in the shape FiveParsecsCampaignCore.to_dictionary() actually writes.
func _save(members: Array, captain: Variant = null, version: int = 1) -> Dictionary:
	var d: Dictionary = {
		"meta": {"campaign_id": "t", "campaign_name": "T", "schema_version": version},
		"config": {"name": "T"},
		"crew": {"members": members},
		"progress": {"turns_played": 3},
		"equipment": {"equipment": []},
	}
	if captain != null:
		d["captain"] = captain
	return d


func _migrate(save: Dictionary) -> Dictionary:
	return SaveFileMigration.migrate_save_data(
		save, 1, SaveFileMigration.CURRENT_SCHEMA_VERSION)


# --- the shapes that are actually on disk --------------------------------

func test_a_float_origin_becomes_its_enum_string() -> void:
	# Origin.SWIFT is ordinal 7. Observed live in 22222222_1775243767.save.
	var out := _migrate(_save([{"character_name": "A", "origin": 7.0}]))
	assert_bool(out.has("_migration_errors")).override_failure_message(
		"migration failed: %s" % SaveFileMigration.get_migration_status(out)
	).is_false()
	assert_str(str(out["crew"]["members"][0]["origin"])).is_equal("SWIFT")


func test_an_int_origin_becomes_its_enum_string() -> void:
	# The COMMON case: int outnumbers float 17:1 on disk, and CLAUDE.md only
	# documented float.
	var out := _migrate(_save([{"character_name": "A", "origin": 8}]))
	assert_str(str(out["crew"]["members"][0]["origin"])).is_equal("BOT")


func test_every_observed_ordinal_maps_to_a_real_enum_member() -> void:
	# The distinct numeric origins found across all 21 saves.
	var keys: Array = GlobalEnums.Origin.keys()
	for ordinal: int in [1, 2, 3, 4, 5, 6, 7, 8, 16, 17]:
		var out := _migrate(_save([{"character_name": "A", "origin": ordinal}]))
		var got: String = str(out["crew"]["members"][0]["origin"])
		assert_str(got).override_failure_message(
			"ordinal %d must map to GlobalEnums.Origin[%d]" % [ordinal, ordinal]
		).is_equal(str(keys[ordinal]))


func test_a_string_origin_is_left_alone() -> void:
	var out := _migrate(_save([{"character_name": "A", "origin": "De-converted"}]))
	assert_str(str(out["crew"]["members"][0]["origin"])).is_equal("De-converted")


func test_an_absent_origin_is_left_absent() -> void:
	var out := _migrate(_save([{"character_name": "A"}]))
	assert_bool(out["crew"]["members"][0].has("origin")).is_false()


func test_species_id_wins_over_the_ordinal() -> void:
	# 2 of the 12 affected saves carry species_id; it is the newer, more specific
	# key, so it must not be overwritten by an ordinal lookup.
	var out := _migrate(_save([
		{"character_name": "A", "origin": 7.0, "species_id": "swift"}]))
	assert_str(str(out["crew"]["members"][0]["origin"])).is_equal("SWIFT")


func test_ordinal_zero_is_erased_not_guessed() -> void:
	# Origin.NONE is "never set", not a species. 26 records held it. Erasing lets
	# Character's own validated default apply instead of inventing one here.
	var out := _migrate(_save([{"character_name": "A", "origin": 0}]))
	assert_bool(out["crew"]["members"][0].has("origin")).override_failure_message(
		"ordinal 0 is Origin.NONE — it must not be mapped to a species"
	).is_false()


func test_an_out_of_range_ordinal_is_erased_not_mismapped() -> void:
	var out := _migrate(_save([{"character_name": "A", "origin": 999}]))
	assert_bool(out["crew"]["members"][0].has("origin")).is_false()


func test_the_captain_is_migrated_too() -> void:
	# 10 captain records held an int origin.
	var out := _migrate(_save([], {"character_name": "Cap", "origin": 4}))
	assert_str(str(out["captain"]["origin"])).is_equal(str(GlobalEnums.Origin.keys()[4]))


func test_a_mixed_crew_converts_only_what_needs_it() -> void:
	# modiphiustest_1775408896.save holds both shapes in one crew.
	var out := _migrate(_save([
		{"character_name": "A", "origin": 5},
		{"character_name": "B", "origin": "HUMAN"},
		{"character_name": "C", "origin": 3.0},
	]))
	assert_int(int(out.get("_origin_values_converted", -1))).is_equal(2)
	assert_str(str(out["crew"]["members"][1]["origin"])).is_equal("HUMAN")


# --- the schema the validator now actually checks ------------------------

func test_the_version_is_read_from_meta_not_the_top_level() -> void:
	# Every real save nests it. The old validator looked at the top level and
	# would have failed all 21.
	assert_int(SaveFileMigration.read_schema_version(
		{"meta": {"schema_version": 1}})).is_equal(1)
	assert_int(SaveFileMigration.read_schema_version({})).is_equal(0)


func test_migration_stamps_the_version_where_the_loader_reads_it() -> void:
	# from_dictionary() reads meta.schema_version. If only the top level were
	# stamped, the campaign would load as v1 and re-migrate on every open.
	var out := _migrate(_save([{"character_name": "A", "origin": 7}]))
	assert_int(int(out["meta"]["schema_version"])).is_equal(
		SaveFileMigration.CURRENT_SCHEMA_VERSION)


func test_a_save_missing_the_real_required_keys_is_rejected() -> void:
	var broken: Dictionary = {"meta": {"schema_version": 1}}
	var out := SaveFileMigration.migrate_save_data(broken, 1, 2)
	assert_bool(out.has("_migration_errors")).override_failure_message(
		"a save with no crew/progress must not validate"
	).is_true()


func test_a_current_version_save_is_not_migrated_again() -> void:
	assert_bool(SaveFileMigration.needs_migration(
		SaveFileMigration.CURRENT_SCHEMA_VERSION)).is_false()
	assert_bool(SaveFileMigration.needs_migration(1)).override_failure_message(
		"a v1 save must be migratable — this was false while CURRENT was 1,"
		+ " which is why the only migration step could never run"
	).is_true()


func test_a_new_campaign_is_written_at_the_current_version() -> void:
	# Otherwise every freshly created campaign would be re-migrated on load.
	var c = CampaignCore.new()
	assert_int(c.schema_version).override_failure_message(
		"FiveParsecsCampaignCore.schema_version must track"
		+ " SaveFileMigration.CURRENT_SCHEMA_VERSION"
	).is_equal(SaveFileMigration.CURRENT_SCHEMA_VERSION)
