@tool
extends RefCounted
class_name TableLoader

## Static utility class for loading table data from files
##
## Provides methods to load table data from JSON files in directories
## and convert them into usable table structures.

## Load all table files from a directory
static func load_tables_from_directory(directory_path: String) -> Dictionary:
	var tables: Dictionary = {}
	var dir = DirAccess.open(directory_path)
	
	if dir == null:
		push_warning("Could not open directory: " + directory_path)
		return tables
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var table_name = file_name.get_basename()
			var table_data = load_table_from_file(directory_path + "/" + file_name)
			if not table_data.is_empty():
				tables[table_name] = table_data
		file_name = dir.get_next()
	
	return tables

## Load a single table from a JSON file
static func load_table_from_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open file: " + file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_warning("Could not parse JSON in file: " + file_path)
		return {}
	
	var data = json.get_data()
	if not data is Dictionary:
		push_warning("Invalid table format in file: " + file_path)
		return {}
	
	return data

## Validate table data structure
static func validate_table_data(table_data: Dictionary) -> bool:
	if not table_data.has("name"):
		return false
	
	if not table_data.has("entries") or not table_data.entries is Array:
		return false
	
	# Validate entries have required fields
	for entry in table_data.entries:
		if not entry is Dictionary:
			return false
		if not entry.has("min_roll") or not entry.has("max_roll"):
			return false
		if not entry.has("result"):
			return false
	
	return true

## Convert loaded data to table format expected by TableProcessor
static func convert_to_table_format(table_data: Dictionary) -> Dictionary:
	if not validate_table_data(table_data):
		return {}
	
	var converted = {
		"name": table_data.get("name", ""),
		"entries": [],
		"modifiers": table_data.get("modifiers", []),
		"validation_rules": table_data.get("validation_rules", [])
	}
	
	for entry in table_data.entries:
		converted.entries.append({
			"min_roll": entry.get("min_roll", 1),
			"max_roll": entry.get("max_roll", 1),
			"result": entry.get("result", ""),
			"weight": entry.get("weight", 1.0),
			"metadata": entry.get("metadata", {})
		})
	
	return converted