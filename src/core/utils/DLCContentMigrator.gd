class_name DLCContentMigrator
extends RefCounted

## DLCContentMigrator
##
## Tool for migrating existing content to DLC system format.
## Adds DLC metadata, validates against schemas, and audits content.
##
## Usage:
##   var migrator := DLCContentMigrator.new()
##   migrator.add_dlc_metadata(data, "species", "trailblazers_toolkit")
##   migrator.validate_content(data, "species")
##   var audit = migrator.audit_file("res://data/species.json")

## DLC content schemas (loaded from schemas file)
var content_schemas: Dictionary = {}

## Migration log
var migration_log: Array = []

func _init() -> void:
	_load_schemas()

## Add DLC metadata to content item
func add_dlc_metadata(item: Dictionary, content_type: String, dlc_id: String) -> Dictionary:
	var modified := item.duplicate(true)

	# Add dlc_required field
	modified.dlc_required = dlc_id

	# Add source field
	modified.source = dlc_id

	_log("Added DLC metadata: %s -> %s" % [content_type, dlc_id])

	return modified

## Add core content marker
func mark_as_core_content(item: Dictionary) -> Dictionary:
	var modified := item.duplicate(true)

	# Set dlc_required to null for core content
	modified.dlc_required = null

	# Set source to "core"
	modified.source = "core"

	_log("Marked as core content")

	return modified

## Migrate entire array of content items
func migrate_content_array(items: Array, content_type: String, dlc_id: String, is_core: bool = false) -> Array:
	var migrated := []

	for item in items:
		if item is Dictionary:
			var migrated_item: Dictionary
			if is_core:
				migrated_item = mark_as_core_content(item)
			else:
				migrated_item = add_dlc_metadata(item, content_type, dlc_id)

			# Validate
			if validate_content(migrated_item, content_type):
				migrated.append(migrated_item)
			else:
				push_warning("DLCContentMigrator: Item failed validation, skipped.")

	_log("Migrated %d items (type: %s, dlc: %s, core: %s)" % [
		migrated.size(), content_type, dlc_id, is_core
	])

	return migrated

## Validate content against schema
func validate_content(item: Dictionary, content_type: String) -> bool:
	if not content_schemas.has(content_type):
		push_warning("DLCContentMigrator: No schema for content type '%s'" % content_type)
		return true # Allow if no schema

	var schema: Dictionary = content_schemas[content_type]
	return _validate_against_schema(item, schema)

## Audit JSON file to identify DLC content
func audit_file(file_path: String) -> Dictionary:
	var audit := {
		"file": file_path,
		"total_items": 0,
		"core_content": 0,
		"dlc_content": 0,
		"by_dlc": {},
		"missing_metadata": 0,
		"items": []
	}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("DLCContentMigrator: Failed to open file '%s'" % file_path)
		return audit

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("DLCContentMigrator: JSON parse error in '%s'" % file_path)
		return audit

	var data = json.get_data()

	# Handle different JSON structures
	var items_to_audit := []
	if data is Array:
		items_to_audit = data
	elif data is Dictionary:
		# Try common top-level keys
		for key in ["species", "equipment", "enemies", "missions", "backgrounds", "classes", "motivations"]:
			if data.has(key) and data[key] is Array:
				items_to_audit = data[key]
				break

	audit.total_items = items_to_audit.size()

	for item in items_to_audit:
		if not item is Dictionary:
			continue

		var item_audit := _audit_item(item)
		audit.items.append(item_audit)

		if item_audit.is_core:
			audit.core_content += 1
		elif item_audit.dlc_required:
			audit.dlc_content += 1
			var dlc: String = item_audit.dlc_required
			if not audit.by_dlc.has(dlc):
				audit.by_dlc[dlc] = 0
			audit.by_dlc[dlc] += 1
		else:
			audit.missing_metadata += 1

	return audit

## Print audit report
func print_audit_report(audit: Dictionary) -> void:
	print("\n=== DLC Content Audit Report ===")
	print("File: %s" % audit.file)
	print("Total Items: %d" % audit.total_items)
	print("Core Content: %d" % audit.core_content)
	print("DLC Content: %d" % audit.dlc_content)
	print("Missing Metadata: %d" % audit.missing_metadata)

	if not audit.by_dlc.is_empty():
		print("\nBy DLC:")
		for dlc in audit.by_dlc.keys():
			print("  %s: %d items" % [dlc, audit.by_dlc[dlc]])

	print("================================\n")

## Migrate JSON file
func migrate_file(input_path: String, output_path: String, content_type: String, dlc_id: String = "", is_core: bool = false) -> bool:
	# Load file
	var file := FileAccess.open(input_path, FileAccess.READ)
	if not file:
		push_error("DLCContentMigrator: Failed to open input file '%s'" % input_path)
		return false

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("DLCContentMigrator: JSON parse error in '%s'" % input_path)
		return false

	var data = json.get_data()

	# Migrate data
	var migrated_data

	if data is Array:
		migrated_data = migrate_content_array(data, content_type, dlc_id, is_core)
	elif data is Dictionary:
		migrated_data = {}
		for key in data.keys():
			if data[key] is Array:
				migrated_data[key] = migrate_content_array(data[key], content_type, dlc_id, is_core)
			else:
				migrated_data[key] = data[key]

	# Save migrated data
	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	if not output_file:
		push_error("DLCContentMigrator: Failed to open output file '%s'" % output_path)
		return false

	var json_string := JSON.stringify(migrated_data, "\t")
	output_file.store_string(json_string)
	output_file.close()

	_log("Migrated file: %s -> %s" % [input_path, output_path])
	print("DLCContentMigrator: Successfully migrated '%s' to '%s'" % [input_path, output_path])

	return true

## Batch migrate multiple files
func batch_migrate(migration_plan: Array) -> Dictionary:
	var results := {
		"total": migration_plan.size(),
		"success": 0,
		"failed": 0,
		"errors": []
	}

	for plan in migration_plan:
		var input_path: String = plan.get("input", "")
		var output_path: String = plan.get("output", "")
		var content_type: String = plan.get("content_type", "")
		var dlc_id: String = plan.get("dlc_id", "")
		var is_core: bool = plan.get("is_core", false)

		if migrate_file(input_path, output_path, content_type, dlc_id, is_core):
			results.success += 1
		else:
			results.failed += 1
			results.errors.append("Failed to migrate: %s" % input_path)

	return results

## Get migration log
func get_migration_log() -> Array:
	return migration_log.duplicate()

## Print migration log
func print_migration_log() -> void:
	print("\n=== Migration Log ===")
	for entry in migration_log:
		print(entry)
	print("=====================\n")

## Clear migration log
func clear_log() -> void:
	migration_log.clear()

## Generate migration plan for common files
func generate_migration_plan() -> Array:
	return [
		# Core content
		{
			"input": "res://data/species.json",
			"output": "res://data/migrated/species_core.json",
			"content_type": "species",
			"is_core": true
		},
		{
			"input": "res://data/equipment.json",
			"output": "res://data/migrated/equipment_core.json",
			"content_type": "equipment",
			"is_core": true
		},
		{
			"input": "res://data/enemies.json",
			"output": "res://data/migrated/enemies_core.json",
			"content_type": "enemies",
			"is_core": true
		},

		# Trailblazer's Toolkit DLC
		{
			"input": "res://data/dlc/trailblazers_toolkit_species.json",
			"output": "res://data/migrated/tt_species.json",
			"content_type": "species",
			"dlc_id": "trailblazers_toolkit"
		},
		{
			"input": "res://data/dlc/trailblazers_toolkit_psionic_powers.json",
			"output": "res://data/migrated/tt_psionic_powers.json",
			"content_type": "psionic_power",
			"dlc_id": "trailblazers_toolkit"
		},

		# Freelancer's Handbook DLC
		{
			"input": "res://data/dlc/freelancers_handbook_elite_enemies.json",
			"output": "res://data/migrated/fh_elite_enemies.json",
			"content_type": "elite_enemy",
			"dlc_id": "freelancers_handbook"
		},
		{
			"input": "res://data/dlc/freelancers_handbook_difficulty_modifiers.json",
			"output": "res://data/migrated/fh_difficulty_modifiers.json",
			"content_type": "difficulty_modifier",
			"dlc_id": "freelancers_handbook"
		},

		# Fixer's Guidebook DLC
		{
			"input": "res://data/dlc/fixers_guidebook_missions.json",
			"output": "res://data/migrated/fg_missions.json",
			"content_type": "mission_template",
			"dlc_id": "fixers_guidebook"
		}
	]

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _load_schemas() -> void:
	var schemas_path := "res://docs/schemas/dlc_data_schemas.json"
	var file := FileAccess.open(schemas_path, FileAccess.READ)

	if not file:
		push_warning("DLCContentMigrator: Could not load schemas from '%s'" % schemas_path)
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)

	if error == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("schemas"):
			content_schemas = data.schemas
			print("DLCContentMigrator: Loaded %d content schemas." % content_schemas.size())
	else:
		push_error("DLCContentMigrator: Failed to parse schemas JSON.")

func _validate_against_schema(item: Dictionary, schema: Dictionary) -> bool:
	# Check required fields
	if schema.has("required"):
		var required_fields: Array = schema.required
		for field in required_fields:
			if not item.has(field):
				push_warning("DLCContentMigrator: Missing required field '%s'" % field)
				return false

	# Type checking (simplified)
	if schema.has("properties"):
		var properties: Dictionary = schema.properties
		for prop_name in item.keys():
			if properties.has(prop_name):
				var prop_schema: Dictionary = properties[prop_name]
				if not _validate_type(item[prop_name], prop_schema):
					push_warning("DLCContentMigrator: Type mismatch for field '%s'" % prop_name)
					return false

	return true

func _validate_type(value, type_schema: Dictionary) -> bool:
	if not type_schema.has("type"):
		return true

	var expected_type: String = type_schema.type

	match expected_type:
		"string":
			return value is String
		"number", "integer":
			return value is int or value is float
		"boolean":
			return value is bool
		"array":
			return value is Array
		"object":
			return value is Dictionary
		_:
			return true

func _audit_item(item: Dictionary) -> Dictionary:
	var item_audit := {
		"name": item.get("name", "Unknown"),
		"dlc_required": item.get("dlc_required", null),
		"source": item.get("source", null),
		"is_core": false,
		"has_metadata": false
	}

	# Determine if core content
	if item_audit.dlc_required == null or item_audit.source == "core":
		item_audit.is_core = true

	# Check if has metadata
	if item.has("dlc_required") and item.has("source"):
		item_audit.has_metadata = true

	return item_audit

func _log(message: String) -> void:
	var timestamp := Time.get_datetime_string_from_system()
	migration_log.append("[%s] %s" % [timestamp, message])
