class_name TableLoader
extends RefCounted

const TableProcessor = preload("res://src/core/systems/TableProcessor.gd")

signal table_loaded(table_name: String)
signal loading_failed(table_name: String, reason: String)
signal validation_error(table_name: String, error: String)
signal table_saved(table_name: String, path: String)

# Configuration
const REQUIRED_FIELDS = ["name", "entries"]
const OPTIONAL_FIELDS = ["validation_rules", "modifiers", "default_result", "metadata", "custom_validation"]
const VALID_FORMATS = ["json", "binary"]

# Enhanced table loading with validation
static func load_table_from_file(file_path: String, validate: bool = true) -> TableProcessor.Table:
	if not FileAccess.file_exists(file_path):
		push_error("Table file not found: " + file_path)
		return null
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error != OK:
		push_error("Failed to parse table JSON: " + json.get_error_message())
		return null
	
	var data = json.get_data()
	
	# Validate data structure
	if validate and not _validate_table_data(data):
		push_error("Invalid table data structure")
		return null
	
	return create_table_from_data(data)

# Enhanced table creation with metadata support
static func create_table_from_data(data: Dictionary) -> TableProcessor.Table:
	if not _validate_required_fields(data):
		push_error("Invalid table data: missing required fields")
		return null
	
	var table = TableProcessor.Table.new(data["name"])
	
	# Add metadata if present
	if data.has("metadata"):
		table.metadata = data["metadata"]
	
	# Set custom validation if specified
	if data.has("custom_validation"):
		table.custom_validation = data["custom_validation"]
	
	# Add entries with enhanced validation
	for entry_data in data["entries"]:
		if not _validate_entry_data(entry_data):
			push_warning("Skipping invalid entry in table " + data["name"])
			continue
			
		var entry = _create_entry_from_data(entry_data)
		if entry:
			table.add_entry(entry)
	
	# Add validation rules if present
	if data.has("validation_rules"):
		for rule_data in data["validation_rules"]:
			var rule = _create_validation_rule(rule_data)
			if rule != null:
				table.add_validation_rule(rule)
	
	# Add modifiers if present
	if data.has("modifiers"):
		for modifier_data in data["modifiers"]:
			var modifier = _create_modifier(modifier_data)
			if modifier != null:
				table.add_modifier(modifier)
	
	# Set default result if present
	if data.has("default_result"):
		table.default_result = data["default_result"]
	
	return table

# Enhanced entry creation
static func _create_entry_from_data(data: Dictionary) -> TableProcessor.TableEntry:
	if not _validate_entry_data(data):
		return null
		
	var min_roll = data["roll_range"][0]
	var max_roll = data["roll_range"][1]
	var result = data["result"]
	var weight = data.get("weight", 1.0)
	var tags = data.get("tags", [])
	var metadata = data.get("metadata", {})
	
	return TableProcessor.TableEntry.new(min_roll, max_roll, result, weight, tags, metadata)

# Enhanced validation methods
static func _validate_table_data(data: Dictionary) -> bool:
	# Check required fields
	if not _validate_required_fields(data):
		return false
	
	# Validate entries array
	if not (data["entries"] is Array):
		return false
	
	# Validate each entry
	for entry in data["entries"]:
		if not _validate_entry_data(entry):
			return false
	
	# Validate optional fields if present
	for field in OPTIONAL_FIELDS:
		if data.has(field):
			if not _validate_optional_field(field, data[field]):
				return false
	
	return true

static func _validate_required_fields(data: Dictionary) -> bool:
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			return false
	return true

static func _validate_entry_data(data: Dictionary) -> bool:
	if not data.has("roll_range") or not data.has("result"):
		return false
	
	if not data["roll_range"] is Array or data["roll_range"].size() != 2:
		return false
	
	if not (data["roll_range"][0] is int and data["roll_range"][1] is int):
		return false
	
	if data["roll_range"][0] > data["roll_range"][1]:
		return false
	
	if data.has("weight") and not (data["weight"] is float or data["weight"] is int):
		return false
	
	if data.has("tags") and not data["tags"] is Array:
		return false
	
	if data.has("metadata") and not data["metadata"] is Dictionary:
		return false
	
	return true

static func _validate_optional_field(field: String, value: Variant) -> bool:
	match field:
		"validation_rules":
			return value is Array
		"modifiers":
			return value is Array
		"metadata":
			return value is Dictionary
		"custom_validation":
			return value is bool
	return true

# Enhanced validation rule creation
static func _create_validation_rule(rule_data: Dictionary) -> Callable:
	if not rule_data.has("type"):
		return func(roll: int) -> Dictionary: return {"valid": true, "reason": ""}
	
	match rule_data["type"]:
		"range":
			return _create_range_validation_rule(rule_data)
		"modulo":
			return _create_modulo_validation_rule(rule_data)
		"custom":
			return _create_custom_validation_rule(rule_data)
		_:
			return func(roll: int) -> Dictionary: return {"valid": true, "reason": ""}

static func _create_range_validation_rule(rule_data: Dictionary) -> Callable:
	var min_value = rule_data.get("min", 1)
	var max_value = rule_data.get("max", 100)
	
	return func(roll: int) -> Dictionary:
		var valid = roll >= min_value and roll <= max_value
		return {
			"valid": valid,
			"reason": "Roll must be between %d and %d" % [min_value, max_value] if not valid else ""
		}

static func _create_modulo_validation_rule(rule_data: Dictionary) -> Callable:
	var divisor = rule_data.get("divisor", 1)
	var remainder = rule_data.get("remainder", 0)
	
	return func(roll: int) -> Dictionary:
		var valid = roll % divisor == remainder
		return {
			"valid": valid,
			"reason": "Roll must have remainder %d when divided by %d" % [remainder, divisor] if not valid else ""
		}

static func _create_custom_validation_rule(rule_data: Dictionary) -> Callable:
	# Implement custom validation rule creation based on rule_data
	return func(roll: int) -> Dictionary: return {"valid": true, "reason": ""}

# Enhanced modifier creation
static func _create_modifier(modifier_data: Dictionary) -> Callable:
	if not modifier_data.has("type"):
		return func(result: Variant) -> Variant: return result
	
	match modifier_data["type"]:
		"multiply":
			return _create_multiply_modifier(modifier_data)
		"add":
			return _create_add_modifier(modifier_data)
		"transform":
			return _create_transform_modifier(modifier_data)
		_:
			return func(result: Variant) -> Variant: return result

static func _create_multiply_modifier(modifier_data: Dictionary) -> Callable:
	var factor = modifier_data.get("factor", 1.0)
	return func(result: Variant) -> Variant:
		if result is int or result is float:
			return result * factor
		return result

static func _create_add_modifier(modifier_data: Dictionary) -> Callable:
	var amount = modifier_data.get("amount", 0)
	return func(result: Variant) -> Variant:
		if result is int or result is float:
			return result + amount
		return result

static func _create_transform_modifier(modifier_data: Dictionary) -> Callable:
	var transform = modifier_data.get("transform", {})
	return func(result: Variant) -> Variant:
		if result is String and transform.has(result):
			return transform[result]
		return result

# Enhanced directory loading with validation
static func load_tables_from_directory(dir_path: String, validate: bool = true) -> Dictionary:
	var tables = {}
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		push_error("Failed to open directory: " + dir_path)
		return tables
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = dir_path.path_join(file_name)
			var table = load_table_from_file(file_path, validate)
			if table != null:
				tables[table.name] = table
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return tables

# Enhanced save functionality with format options
static func save_table_to_file(table: TableProcessor.Table, file_path: String, format: String = "json") -> Error:
	if not format in VALID_FORMATS:
		return ERR_INVALID_PARAMETER
	
	match format:
		"json":
			return _save_table_as_json(table, file_path)
		"binary":
			return _save_table_as_binary(table, file_path)
		_:
			return ERR_INVALID_PARAMETER

static func _save_table_as_json(table: TableProcessor.Table, file_path: String) -> Error:
	var json = table_to_json(table)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(json)
	return OK

static func _save_table_as_binary(table: TableProcessor.Table, file_path: String) -> Error:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		return FileAccess.get_open_error()
	
	# Implement binary serialization
	return OK

# Enhanced JSON conversion with metadata
static func table_to_json(table: TableProcessor.Table) -> String:
	var data = table.serialize()
	return JSON.stringify(data, "\t")
