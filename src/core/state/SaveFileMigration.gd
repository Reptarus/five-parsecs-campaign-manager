extends Resource
class_name SaveFileMigration

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

## Current schema version - increment when adding migrations
const CURRENT_SCHEMA_VERSION: int = 1

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
	
	# Final validation
	var validation_result = _validate_migrated_data(migrated_data, to_version)
	if not validation_result.valid:
		return _create_error_result(MigrationError.VALIDATION_FAILED,
			"Post-migration validation failed: %s" % validation_result.error, migration_log)
	
	# Add migration metadata
	migrated_data["_migration_log"] = migration_log
	migrated_data["_migrated_from"] = from_version
	migrated_data["schema_version"] = to_version
	
	return migrated_data

## Apply a single migration step
static func _apply_migration_step(data: Dictionary, target_version: int, log: Array[String]) -> Dictionary:
	var step_data = data.duplicate(true)
	var error_msg = ""
	
	match target_version:
		2:
			var result = _migrate_v1_to_v2(step_data)
			if result.has("error"):
				error_msg = result.error
			else:
				step_data = result
				log.append("v1→v2: Added battle_results field")
		
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

## Migration: v1 → v2 (Add battle_results field)
## Introduced: 2025-11-27
## Reason: battle_results was missing from initial schema, causing data loss
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var migrated = data.duplicate(true)
	
	# Add battle_results if missing
	if not migrated.has("battle_results"):
		migrated["battle_results"] = {}
	
	# Ensure it's a Dictionary (defensive)
	if not migrated["battle_results"] is Dictionary:
		push_warning("SaveFileMigration: battle_results was not a Dictionary, resetting to {}")
		migrated["battle_results"] = {}
	
	return migrated

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
	# Check schema version
	if not data.has("schema_version"):
		return {"valid": false, "error": "Missing schema_version field"}
	
	# Basic structure validation
	var required_fields = ["current_phase", "turn_number", "battle_results"]
	for field in required_fields:
		if not data.has(field):
			return {"valid": false, "error": "Missing required field: %s" % field}
	
	# Type validation
	if not data["battle_results"] is Dictionary:
		return {"valid": false, "error": "battle_results must be a Dictionary"}
	
	return {"valid": true}

## Create error result Dictionary
static func _create_error_result(error_type: MigrationError, message: String, log: Array[String] = []) -> Dictionary:
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
