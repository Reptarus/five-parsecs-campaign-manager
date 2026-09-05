extends Resource
class_name SaveFileMigration

const GlobalEnumsRef = preload("res://src/core/systems/GlobalEnums.gd")

## Save File Migration System
## Handles version-safe save file upgrades for data persistence
##
## Architecture:
## - Sequential migration functions (v1→v2→v3)
## - JSON-based validation before Resource deserialization
## - Rollback support for failed migrations
## - Detailed migration logging for debugging
##
## Usage:
##   var migrated_data = SaveFileMigration.migrate_save_data(data, 1, 3)
##   if migrated_data.has("_migration_errors"):
##       # Handle migration failure
##   else:
##       # Proceed with deserialization

## Current schema version - increment when adding migrations.
##
## Bumped 1 -> 2 on 2026-09-04 so the v1->v2 step can actually run. It could not
## before: the constant was 1, so needs_migration(1) was false for every save on
## disk and the only migration defined was unreachable.
const CURRENT_SCHEMA_VERSION: int = 2

## Where the 5PFH save actually keeps its version. NOT the top level - that is
## what _validate_migrated_data used to check, and no save has ever had it there.
const SCHEMA_VERSION_PATH := ["meta", "schema_version"]

## Top-level keys FiveParsecsCampaignCore.to_dictionary() always writes. Verified
## against 21 real save files; the previous list (current_phase / turn_number /
## battle_results) matched 0 of 3 on every one of them.
const REQUIRED_TOP_LEVEL := ["meta", "crew", "progress"]

## Migration error types
enum MigrationError {
	INVALID_SOURCE_VERSION,
	INVALID_TARGET_VERSION,
	MIGRATION_FAILED,
	VALIDATION_FAILED,
	ROLLBACK_REQUIRED
}

## Migrate save data from one version to another
## @param data: Raw Dictionary from JSON load (NOT deserialized Resource)
## @param from_version: Source schema version
## @param to_version: Target schema version
## @return: Migrated Dictionary or Dictionary with "_migration_errors" key on failure
static func migrate_save_data(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	# Validation
	if from_version < 0 or to_version < 0:
		return _create_error_result(MigrationError.INVALID_SOURCE_VERSION,
			"Invalid version numbers: from=%d, to=%d" % [from_version, to_version])

	if from_version > CURRENT_SCHEMA_VERSION:
		return _create_error_result(MigrationError.INVALID_SOURCE_VERSION,
			"Save file version (%d) is newer than current schema (%d)" % [from_version, CURRENT_SCHEMA_VERSION])

	if from_version == to_version:
		return data # No migration needed

	# Create working copy for migration
	var migrated_data = data.duplicate(true)
	var migration_log: Array[String] = []

	# Apply migrations sequentially
	for version in range(from_version + 1, to_version + 1):
		var result = _apply_migration_step(migrated_data, version, migration_log)
		if not result.success:
			return _create_error_result(MigrationError.MIGRATION_FAILED,
				"Migration to v%d failed: %s" % [version, result.error], migration_log)
		migrated_data = result.data

	# Stamp the new version BEFORE validating, so the validator checks the
	# state actually about to be returned. Validating first meant asserting
	# meta.schema_version == to_version against data still carrying the OLD
	# version - it can never have been true.
	migrated_data["_migration_log"] = migration_log
	migrated_data["_migrated_from"] = from_version
	# Stamp it where from_dictionary() reads it (FiveParsecsCampaignCore:587),
	# not only at the top level - otherwise the campaign loads still believing it
	# is the old version and would migrate again on the next open.
	if migrated_data.get("meta", null) is Dictionary:
		migrated_data["meta"]["schema_version"] = to_version
	migrated_data["schema_version"] = to_version

	# Final validation
	var validation_result = _validate_migrated_data(migrated_data, to_version)
	if not validation_result.valid:
		return _create_error_result(MigrationError.VALIDATION_FAILED,
			"Post-migration validation failed: %s" % validation_result.error, migration_log)

	return migrated_data

## Apply a single migration step
static func _apply_migration_step(data: Dictionary, target_version: int, log: Array) -> Dictionary:
	var step_data = data.duplicate(true)
	var error_msg = ""

	match target_version:
		2:
			var result = _migrate_v1_to_v2(step_data)
			if result.has("error"):
				error_msg = result.error
			else:
				step_data = result
				log.append("v1->v2: normalised numeric crew origin to enum strings")

		# Future migrations go here:
		# 3:
		#     step_data = _migrate_v2_to_v3(step_data)
		#     log.append("v2→v3: Added equipment validation")

		_:
			error_msg = "No migration defined for version %d" % target_version

	if error_msg:
		return {"success": false, "error": error_msg, "data": data}
	else:
		return {"success": true, "data": step_data}

## Migration: v1 -> v2 - normalise numeric crew `origin` to its enum String.
## Introduced: 2026-09-04
##
## THE PROBLEM. `Character.origin` is an @export var of type String, validated
## against GlobalEnums.Origin. Saves written before that change stored the enum
## ORDINAL instead. A census of 21 real 5PFH saves found:
##
##     origin shape   crew   captain
##     float             4         0
##     int              59        10
##     String           48        11
##
## i.e. 69 of 132 crew/captain records - 52% - hold a number. (Godot's JSON
## parser returns both int and float as float, so the in-engine symptom is
## identical; the on-disk spelling differs only because the value was written by
## different code paths.)
##
## WHY IT MATTERS. Crew members stay Dictionaries on a loaded save, so the
## validating setter never runs and the number survives. Every species check
## then does str(7.0).to_lower() == "swift" and silently fails, so species rules
## do not apply. Only 2 of the 12 affected saves carry a `species_id` for the
## band-aids to fall back on; the other 10 resolve to "8", "4", "0".
##
## MAPPING. Strictly through GlobalEnums.Origin ordinals - the same table
## `origin_bonuses` is keyed by - and nothing is invented. Ordinal 0 is NONE,
## which is not a species: it means "never set", so it is left alone rather than
## guessed at, and Character's own default ("HUMAN") continues to apply.
## `species_id` wins when present, because it is the newer and more specific key.
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var migrated = data.duplicate(true)
	var converted := 0

	var crew: Variant = migrated.get("crew", null)
	if crew is Dictionary:
		var members: Variant = (crew as Dictionary).get("members", null)
		if members is Array:
			for member: Variant in (members as Array):
				if _normalise_origin(member):
					converted += 1

	if migrated.get("captain", null) is Dictionary:
		if _normalise_origin(migrated["captain"]):
			converted += 1

	migrated["_origin_values_converted"] = converted
	return migrated


## Convert one member's numeric `origin` to its enum String, in place.
## Returns true when a conversion happened.
static func _normalise_origin(member: Variant) -> bool:
	if not (member is Dictionary):
		return false
	var d: Dictionary = member
	if not d.has("origin"):
		return false
	var origin: Variant = d["origin"]
	if origin is String:
		return false
	if not (origin is int or origin is float):
		return false

	var ordinal: int = int(origin)

	# species_id is a String and is the more specific key, so prefer it.
	var sid: String = str(d.get("species_id", "")).strip_edges()
	if not sid.is_empty():
		d["origin"] = sid.to_upper()
		return true

	# Ordinal 0 is Origin.NONE - "never set", not a species. Erase it so
	# Character's validated setter applies its own default rather than us
	# inventing one.
	if ordinal <= 0:
		d.erase("origin")
		return true

	var keys: Array = GlobalEnumsRef.Origin.keys()
	if ordinal >= keys.size():
		# Out of range: an ordinal from a build whose enum had more members.
		# Dropping it is safer than mapping it to the wrong species.
		d.erase("origin")
		return true
	d["origin"] = str(keys[ordinal])
	return true


## Example future migration (commented out - template for v2→v3)
# static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
#     var migrated = data.duplicate(true)
#
#     # Example: Add equipment integrity validation
#     if migrated.has("campaign"):
#         var campaign = migrated["campaign"]
#         if campaign.has("equipment"):
#             # Validate equipment IDs are unique
#             var seen_ids = {}
#             for item in campaign.equipment:
#                 var id = item.get("id", "")
#                 if seen_ids.has(id):
#                     push_warning("Duplicate equipment ID found: %s" % id)
#                     item["id"] = "%s_%d" % [id, Time.get_ticks_msec()]
#                 seen_ids[id] = true
#
#     return migrated

## Validate migrated data structure
static func _validate_migrated_data(data: Dictionary, expected_version: int) -> Dictionary:
	## Validate against the shape FiveParsecsCampaignCore.to_dictionary() writes.
	##
	## The previous version required top-level `schema_version`, `current_phase`,
	## `turn_number` and `battle_results`. A census of 21 real saves found NONE of
	## the last three present in any of them, and schema_version nested under
	## `meta` in all of them - so wiring this in would have rejected every save.
	if read_schema_version(data) <= 0:
		return {"valid": false, "error": "Missing meta.schema_version"}

	for field: String in REQUIRED_TOP_LEVEL:
		if not data.has(field):
			return {"valid": false, "error": "Missing required field: %s" % field}

	if not (data["crew"] is Dictionary):
		return {"valid": false, "error": "crew must be a Dictionary"}
	if not (data["progress"] is Dictionary):
		return {"valid": false, "error": "progress must be a Dictionary"}

	if read_schema_version(data) != expected_version:
		return {"valid": false, "error": "meta.schema_version is %d, expected %d"
			% [read_schema_version(data), expected_version]}

	return {"valid": true}


## The save's schema version, read from where it actually lives.
## Returns 0 when absent, which callers treat as "unknown/pre-versioned".
static func read_schema_version(data: Dictionary) -> int:
	var meta: Variant = data.get("meta", null)
	if meta is Dictionary:
		return int((meta as Dictionary).get("schema_version", 0))
	# Tolerated for hand-built fixtures and any future top-level writer.
	return int(data.get("schema_version", 0))

## Create error result Dictionary
static func _create_error_result(error_type: MigrationError, message: String, log: Array = []) -> Dictionary:
	return {
		"_migration_errors": [
			{
				"type": error_type,
				"message": message,
				"timestamp": Time.get_datetime_string_from_system()
			}
		],
		"_migration_log": log
	}

## Get human-readable migration status
static func get_migration_status(data: Dictionary) -> String:
	if data.has("_migration_errors"):
		var errors = data["_migration_errors"]
		if errors.size() > 0:
			return "FAILED: %s" % errors[0].message

	if data.has("_migrated_from"):
		return "SUCCESS: Migrated from v%d to v%d" % [data["_migrated_from"], data.get("schema_version", 0)]

	return "NO_MIGRATION_NEEDED"

## Check if migration is needed
static func needs_migration(save_version: int) -> bool:
	return save_version < CURRENT_SCHEMA_VERSION
