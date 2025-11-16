class_name DLCContentValidator
extends RefCounted

## DLCContentValidator
##
## Validates DLC content against schemas and game rules.
## Checks for consistency, completeness, and correctness.
##
## Usage:
##   var validator := DLCContentValidator.new()
##   var errors = validator.validate_file("res://data/species.json")
##   validator.print_validation_report(errors)

## Content schemas
var content_schemas: Dictionary = {}

## Validation rules
var validation_rules: Dictionary = {}

## DLC dependencies
const DLC_DEPENDENCIES := {
	"trailblazers_toolkit": [],
	"freelancers_handbook": [],
	"fixers_guidebook": [],
	"bug_hunt": [],
	"complete_compendium": ["trailblazers_toolkit", "freelancers_handbook", "fixers_guidebook", "bug_hunt"]
}

func _init() -> void:
	_load_schemas()
	_setup_validation_rules()

## Validate content item
func validate_item(item: Dictionary, content_type: String) -> Array:
	var errors := []

	# Schema validation
	if content_schemas.has(content_type):
		var schema_errors := _validate_schema(item, content_schemas[content_type], content_type)
		errors.append_array(schema_errors)

	# Custom validation rules
	if validation_rules.has(content_type):
		var rule_func: Callable = validation_rules[content_type]
		var rule_errors := rule_func.call(item)
		errors.append_array(rule_errors)

	return errors

## Validate entire file
func validate_file(file_path: String) -> Dictionary:
	var result := {
		"file": file_path,
		"valid": true,
		"errors": [],
		"warnings": [],
		"items_checked": 0
	}

	# Load file
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.valid = false
		result.errors.append("Failed to open file: %s" % file_path)
		return result

	var json_text := file.get_as_text()
	file.close()

	# Parse JSON
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		result.valid = false
		result.errors.append("JSON parse error at line %d" % json.get_error_line())
		return result

	var data = json.get_data()

	# Determine content type from file path
	var content_type := _infer_content_type(file_path)

	# Validate items
	var items := _extract_items(data)
	result.items_checked = items.size()

	for item in items:
		var item_errors := validate_item(item, content_type)
		if not item_errors.is_empty():
			result.valid = false
			var item_name := item.get("name", "Unknown")
			for err in item_errors:
				result.errors.append("[%s] %s" % [item_name, err])

	return result

## Validate cross-DLC references
func validate_cross_dlc_reference(item: Dictionary, referenced_dlc: String) -> Array:
	var errors := []

	var item_dlc: String = item.get("dlc_required", "")

	# Check if item requires DLC that references another DLC
	if item_dlc and referenced_dlc:
		# Ensure the referenced DLC is either the same or a dependency
		if item_dlc != referenced_dlc:
			if not _is_dlc_dependency(item_dlc, referenced_dlc):
				errors.append("Invalid cross-DLC reference: %s references %s but doesn't have dependency" % [
					item_dlc, referenced_dlc
				])

	return errors

## Check if all required DLC are present
func check_dlc_completeness(available_dlc: Array) -> Dictionary:
	var completeness := {
		"complete": true,
		"missing": [],
		"warnings": []
	}

	# Check bundles
	if "complete_compendium" in available_dlc:
		var required := DLC_DEPENDENCIES.complete_compendium
		for dlc in required:
			if not dlc in available_dlc:
				completeness.complete = false
				completeness.missing.append(dlc)
				completeness.warnings.append("Complete Compendium requires %s" % dlc)

	return completeness

## Print validation report
func print_validation_report(validation: Dictionary) -> void:
	print("\n=== Validation Report ===")
	print("File: %s" % validation.file)
	print("Items Checked: %d" % validation.items_checked)
	print("Status: %s" % ("✓ VALID" if validation.valid else "✗ INVALID"))

	if not validation.errors.is_empty():
		print("\nErrors (%d):" % validation.errors.size())
		for error in validation.errors:
			print("  • %s" % error)

	if not validation.warnings.is_empty():
		print("\nWarnings (%d):" % validation.warnings.size())
		for warning in validation.warnings:
			print("  • %s" % warning)

	print("========================\n")

## Batch validate multiple files
func batch_validate(file_paths: Array) -> Dictionary:
	var results := {
		"total": file_paths.size(),
		"valid": 0,
		"invalid": 0,
		"total_errors": 0,
		"files": []
	}

	for path in file_paths:
		var validation := validate_file(path)
		results.files.append(validation)

		if validation.valid:
			results.valid += 1
		else:
			results.invalid += 1
			results.total_errors += validation.errors.size()

	return results

## Print batch validation report
func print_batch_report(batch_results: Dictionary) -> void:
	print("\n=== Batch Validation Report ===")
	print("Total Files: %d" % batch_results.total)
	print("Valid: %d" % batch_results.valid)
	print("Invalid: %d" % batch_results.invalid)
	print("Total Errors: %d" % batch_results.total_errors)

	if batch_results.invalid > 0:
		print("\nInvalid Files:")
		for file_result in batch_results.files:
			if not file_result.valid:
				print("  ✗ %s (%d errors)" % [file_result.file, file_result.errors.size()])

	print("================================\n")

## Validate DLC dependencies
func validate_dependencies(dlc_id: String, available_dlc: Array) -> Array:
	var errors := []

	if DLC_DEPENDENCIES.has(dlc_id):
		var dependencies: Array = DLC_DEPENDENCIES[dlc_id]
		for dep in dependencies:
			if not dep in available_dlc:
				errors.append("Missing dependency: %s requires %s" % [dlc_id, dep])

	return errors

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _load_schemas() -> void:
	var schemas_path := "res://docs/schemas/dlc_data_schemas.json"
	var file := FileAccess.open(schemas_path, FileAccess.READ)

	if not file:
		push_warning("DLCContentValidator: Could not load schemas")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("schemas"):
			content_schemas = data.schemas

func _setup_validation_rules() -> void:
	# Custom validation rules for each content type
	validation_rules = {
		"species": _validate_species,
		"psionic_power": _validate_psionic_power,
		"elite_enemy": _validate_elite_enemy,
		"difficulty_modifier": _validate_difficulty_modifier,
		"mission_template": _validate_mission_template
	}

func _validate_schema(item: Dictionary, schema: Dictionary, content_type: String) -> Array:
	var errors := []

	# Check required fields
	if schema.has("required"):
		for field in schema.required:
			if not item.has(field):
				errors.append("Missing required field: %s" % field)

	# Check enum values
	if schema.has("properties"):
		for prop_name in item.keys():
			if schema.properties.has(prop_name):
				var prop_schema: Dictionary = schema.properties[prop_name]
				if prop_schema.has("enum"):
					var value = item[prop_name]
					if not value in prop_schema.enum:
						errors.append("Invalid value for %s: %s (expected one of %s)" % [
							prop_name, value, prop_schema.enum
						])

	return errors

func _validate_species(item: Dictionary) -> Array:
	var errors := []

	# Species-specific validation
	if item.get("playable", false):
		if not item.has("starting_bonus"):
			errors.append("Playable species must have starting_bonus")

	# Check traits are reasonable
	var traits: Array = item.get("traits", [])
	if traits.size() > 5:
		errors.append("Species has too many traits (%d > 5)" % traits.size())

	return errors

func _validate_psionic_power(item: Dictionary) -> Array:
	var errors := []

	# Check target type is valid
	var target_type: String = item.get("target_type", "")
	if not target_type in ["self", "enemy", "any"]:
		errors.append("Invalid target_type: %s" % target_type)

	# Check activation has required fields
	if item.has("activation"):
		var activation: Dictionary = item.activation
		if not activation.has("activation_roll"):
			errors.append("Activation missing activation_roll")

	return errors

func _validate_elite_enemy(item: Dictionary) -> Array:
	var errors := []

	# Check deployment points are reasonable
	var dp: int = item.get("deployment_points", 0)
	if dp < 1 or dp > 10:
		errors.append("Deployment points out of reasonable range: %d" % dp)

	# Check special abilities
	var abilities: Array = item.get("special_abilities", [])
	for ability in abilities:
		if not ability is Dictionary:
			errors.append("Special ability must be a dictionary")
		elif not ability.has("name") or not ability.has("effect"):
			errors.append("Special ability missing name or effect")

	return errors

func _validate_difficulty_modifier(item: Dictionary) -> Array:
	var errors := []

	# Check category
	var category: String = item.get("category", "")
	var valid_categories := ["enemy_strength", "battle_size", "rewards", "danger", "campaign_pressure"]
	if not category in valid_categories:
		errors.append("Invalid category: %s" % category)

	# Check mechanical changes exist
	if not item.has("mechanical_changes"):
		errors.append("Missing mechanical_changes")

	return errors

func _validate_mission_template(item: Dictionary) -> Array:
	var errors := []

	# Check objectives
	if not item.has("objectives"):
		errors.append("Missing objectives")
	else:
		var objectives: Array = item.objectives
		if objectives.is_empty():
			errors.append("Mission must have at least one objective")

	# Check rewards structure
	if item.has("rewards"):
		var rewards: Dictionary = item.rewards
		if not rewards.has("base_credits"):
			errors.append("Rewards missing base_credits")

	return errors

func _infer_content_type(file_path: String) -> String:
	var filename := file_path.get_file().to_lower()

	if "species" in filename:
		return "species"
	elif "psionic" in filename:
		return "psionic_power"
	elif "elite" in filename:
		return "elite_enemy"
	elif "difficulty" in filename:
		return "difficulty_modifier"
	elif "mission" in filename:
		return "mission_template"
	elif "equipment" in filename:
		return "equipment_item"
	elif "world" in filename:
		return "world_trait"

	return "unknown"

func _extract_items(data) -> Array:
	if data is Array:
		return data
	elif data is Dictionary:
		# Try to find array of items
		for key in data.keys():
			if data[key] is Array:
				return data[key]

	return []

func _is_dlc_dependency(dlc_id: String, referenced_dlc: String) -> bool:
	if not DLC_DEPENDENCIES.has(dlc_id):
		return false

	var dependencies: Array = DLC_DEPENDENCIES[dlc_id]
	return referenced_dlc in dependencies
