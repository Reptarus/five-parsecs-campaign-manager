class_name TableLoader
extends RefCounted

const TableProcessor = preload("res://src/core/systems/TableProcessor.gd")

signal table_loaded(table_name: String)
signal loading_failed(table_name: String, reason: String)

# Loads a table from a JSON file
static func load_table_from_file(file_path: String) -> TableProcessor.Table:
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
	return create_table_from_data(data)

# Creates a table from a dictionary
static func create_table_from_data(data: Dictionary) -> TableProcessor.Table:
	if not data.has("name") or not data.has("entries"):
		push_error("Invalid table data: missing required fields")
		return null
	
	var table = TableProcessor.Table.new(data["name"])
	
	# Add entries
	for entry_data in data["entries"]:
		if not _validate_entry_data(entry_data):
			continue
			
		var min_roll = entry_data["roll_range"][0]
		var max_roll = entry_data["roll_range"][1]
		var result = entry_data["result"]
		var weight = entry_data.get("weight", 1.0)
		var tags = entry_data.get("tags", [])
		
		var entry = TableProcessor.TableEntry.new(min_roll, max_roll, result, weight, tags)
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

# Validates entry data
static func _validate_entry_data(data: Dictionary) -> bool:
	if not data.has("roll_range") or not data.has("result"):
		return false
	
	if not data["roll_range"] is Array or data["roll_range"].size() != 2:
		return false
	
	return true

# Creates a validation rule from rule data
static func _create_validation_rule(rule_data: Dictionary) -> Callable:
	# Example validation rule creation
	# In practice, this would be more sophisticated based on rule_data
	return func(roll: int) -> Dictionary:
		return {"valid": true, "reason": ""}

# Creates a modifier from modifier data
static func _create_modifier(modifier_data: Dictionary) -> Callable:
	# Example modifier creation
	# In practice, this would be more sophisticated based on modifier_data
	return func(result: Variant) -> Variant:
		return result

# Loads all tables from a directory
static func load_tables_from_directory(dir_path: String) -> Dictionary:
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
			var table = load_table_from_file(file_path)
			if table != null:
				tables[table.name] = table
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return tables

# Converts a table to JSON format
static func table_to_json(table: TableProcessor.Table) -> String:
	var data = {
		"name": table.name,
		"entries": []
	}
	
	for entry in table.entries:
		var entry_data = {
			"roll_range": [entry.roll_range.x, entry.roll_range.y],
			"result": entry.result,
			"weight": entry.weight,
			"tags": entry.tags
		}
		data["entries"].append(entry_data)
	
	if table.default_result != null:
		data["default_result"] = table.default_result
	
	return JSON.stringify(data, "\t")

# Saves a table to a JSON file
static func save_table_to_file(table: TableProcessor.Table, file_path: String) -> Error:
	var json = table_to_json(table)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(json)
	return OK