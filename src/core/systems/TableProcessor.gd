@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/systems/TableProcessor.gd")

## Forward declarations for dependencies
## This helps avoid circular references and clarifies dependencies
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Signals for table operations
## Now documented with proper types for Godot 4.4
signal roll_processed(table_name: String, result: Dictionary)
signal validation_failed(table_name: String, reason: String)
signal custom_roll_processed(table_name: String, roll: int, result: Dictionary)
signal history_exported(success: bool, file_path: String)
signal validation_rule_added(table_name: String, rule_name: String)
signal table_modified(table_name: String, modification_type: String)

# Table Entry class for defining table rows
class TableEntry:
	var roll_range: Vector2i # min and max values for this entry
	var result: Variant # The result value (can be any type)
	var weight: float = 1.0 # For weighted random selection
	var tags: Array[String] = [] # For filtering and special handling
	var metadata: Dictionary = {} # Additional data for complex results
	
	func _init(min_roll: int, max_roll: int, res: Variant, w: float = 1.0, t: Array[String] = [], meta: Dictionary = {}) -> void:
		roll_range = Vector2i(min_roll, max_roll)
		result = res
		weight = w
		tags = t
		metadata = meta
	
	func matches_roll(roll: int) -> bool:
		return roll >= roll_range.x and roll <= roll_range.y
	
	func has_tag(tag: String) -> bool:
		return tag in tags
	
	func serialize() -> Dictionary:
		return {
			"roll_range": {"x": roll_range.x, "y": roll_range.y},
			"result": result if result is Array or result is Dictionary else str(result),
			"weight": weight,
			"tags": tags,
			"metadata": metadata
		}

# Table class for managing collections of entries
class Table:
	var name: String
	var entries: Array[TableEntry] = []
	var validation_rules: Array[Callable] = []
	var modifiers: Array[Callable] = []
	var default_result: Variant = null
	var metadata: Dictionary = {} # Table-level metadata
	var custom_validation: bool = false # Whether to use custom validation logic
	
	func _init(table_name: String) -> void:
		name = table_name
	
	func add_entry(entry: TableEntry) -> void:
		entries.append(entry)
	
	func add_validation_rule(rule: Callable) -> void:
		validation_rules.append(rule)
	
	func add_modifier(modifier: Callable) -> void:
		modifiers.append(modifier)
	
	func get_result(roll: int) -> Variant:
		for entry in entries:
			if entry.matches_roll(roll):
				return entry.result
		return default_result
	
	func get_weighted_result() -> Variant:
		var total_weight = 0.0
		for entry in entries:
			total_weight += entry.weight
		
		var roll = randf() * total_weight
		var current_weight = 0.0
		
		for entry in entries:
			current_weight += entry.weight
			if roll <= current_weight:
				return entry.result
		
		return default_result
	
	func serialize() -> Dictionary:
		var serialized_entries = []
		for entry in entries:
			serialized_entries.append(entry.serialize())
		
		return {
			"name": name,
			"entries": serialized_entries,
			"default_result": default_result if default_result is Array or default_result is Dictionary else str(default_result),
			"metadata": metadata,
			"custom_validation": custom_validation
		}

# Main processor variables
var _tables: Dictionary = {} # name -> Table
var _history: Array[Dictionary] = []
var _history_metadata: Dictionary = {} # Additional history tracking data
const MAX_HISTORY_SIZE: int = 1000 # Increased from 100
const HISTORY_BATCH_SIZE: int = 100 # For batch processing

# History tracking enhancements
var _history_enabled: bool = true
var _detailed_history: bool = false # Track additional metadata
var _history_categories: Dictionary = {} # Organize history by categories

func _init() -> void:
	_setup_history_tracking()

func _setup_history_tracking() -> void:
	_history_categories = {
		"combat": [],
		"exploration": [],
		"character": [],
		"mission": [],
		"loot": []
	}

# Enhanced table management methods
func register_table(table: Table) -> void:
	if table == null:
		push_error("Attempted to register a null table")
		return
		
	_tables[table.name] = table
	table_modified.emit(table.name, "registered")

func has_table(table_name: String) -> bool:
	return table_name != "" and _tables.has(table_name)

func get_table(table_name: String) -> Table:
	if not has_table(table_name):
		return null
	return _tables.get(table_name)

# Enhanced rolling methods with validation
func roll_table(table_name: String, custom_roll: int = -1, category: String = "") -> Dictionary:
	if not has_table(table_name):
		validation_failed.emit(table_name, "Table not found")
		return {"success": false, "reason": "Table not found"}
	
	var table = get_table(table_name)
	if table == null:
		validation_failed.emit(table_name, "Table is null")
		return {"success": false, "reason": "Table is null"}
		
	var roll = custom_roll if custom_roll >= 0 else randi() % 100 + 1
	
	# Enhanced validation with custom rules
	if table.custom_validation:
		var validation_result = _run_custom_validation(table, roll)
		if not validation_result.success:
			validation_failed.emit(table_name, validation_result.reason)
			return validation_result
	else:
		# Standard validation rules
		for rule in table.validation_rules:
			if not rule.is_valid():
				push_warning("Invalid validation rule in table " + table_name)
				continue
				
			var validation = rule.call(roll)
			if not validation["valid"]:
				validation_failed.emit(table_name, validation["reason"])
				return {"success": false, "reason": validation["reason"]}
	
	# Get base result
	var result = table.get_result(roll)
	
	# Apply modifiers
	for modifier in table.modifiers:
		result = modifier.call(result)
	
	# Enhanced history tracking
	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"table": table_name,
		"roll": roll,
		"result": result,
		"category": category,
		"custom_roll": custom_roll >= 0,
		"metadata": {} # For additional tracking data
	}
	
	if _detailed_history:
		entry.metadata = {
			"modifiers_applied": table.modifiers.size(),
			"validation_rules": table.validation_rules.size(),
			"entry_count": table.entries.size()
		}
	
	_add_to_history(entry)
	
	# Emit appropriate signal
	if custom_roll >= 0:
		custom_roll_processed.emit(table_name, roll, {"success": true, "result": result})
	else:
		roll_processed.emit(table_name, {"success": true, "result": result})
	
	return {"success": true, "result": result}

# Enhanced history management
func _add_to_history(entry: Dictionary) -> void:
	_history.append(entry)
	
	# Categorize the entry if category is provided
	if entry.has("category") and entry.category in _history_categories:
		_history_categories[entry.category].append(entry)
	
	# Maintain history size limits
	while _history.size() > MAX_HISTORY_SIZE:
		var removed = _history.pop_front()
		# Also remove from category if present
		if removed.has("category") and removed.category in _history_categories:
			_history_categories[removed.category].erase(removed)

# Enhanced history retrieval methods
func get_roll_history(table_name: String = "", category: String = "") -> Array:
	if not _history_enabled:
		return []
	
	if category != "" and category in _history_categories:
		if table_name != "":
			return _history_categories[category].filter(func(entry): return entry["table"] == table_name)
		return _history_categories[category].duplicate()
	
	if table_name != "":
		return _history.filter(func(entry): return entry["table"] == table_name)
	return _history.duplicate()

func get_history_stats() -> Dictionary:
	var stats = {
		"total_rolls": _history.size(),
		"categories": {},
		"tables": {}
	}
	
	for category in _history_categories:
		stats.categories[category] = _history_categories[category].size()
	
	for entry in _history:
		if not stats.tables.has(entry.table):
			stats.tables[entry.table] = 0
		stats.tables[entry.table] += 1
	
	return stats

# Enhanced export capabilities
func export_history(file_path: String, format: String = "json") -> Error:
	var data = serialize()
	var result = OK
	
	match format.to_lower():
		"json":
			result = _export_json(file_path, data)
		"csv":
			result = _export_csv(file_path, _history)
		_:
			result = ERR_INVALID_PARAMETER
	
	history_exported.emit(result == OK, file_path)
	return result

func _export_json(file_path: String, data: Dictionary) -> Error:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(JSON.stringify(data, "\t"))
	return OK

func _export_csv(file_path: String, history: Array) -> Error:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	# Write CSV header
	file.store_line("timestamp,table,roll,result,category,custom_roll")
	
	# Write entries
	for entry in history:
		var line = "%d,%s,%d,%s,%s,%s" % [
			entry.timestamp,
			entry.table,
			entry.roll,
			str(entry.result).replace(",", ";"),
			entry.get("category", ""),
			str(entry.get("custom_roll", false))
		]
		file.store_line(line)
	
	return OK

# Enhanced serialization with validation
func serialize() -> Dictionary:
	var tables_data = {}
	for table_name in _tables:
		tables_data[table_name] = _tables[table_name].serialize()
	
	var history = []
	for entry in _history:
		var serialized_entry = entry.duplicate()
		if not (entry.result is Array or entry.result is Dictionary):
			serialized_entry.result = str(entry.result)
		history.append(serialized_entry)
	
	return {
		"tables": tables_data,
		"history": history,
		"history_metadata": _history_metadata,
		"categories": _history_categories
	}

# Factory method to instantiate a new Table instance
func _create_table(table_name: String) -> Table:
	# Create a table object without using the class directly
	var table = Table.new(table_name)
	table.name = table_name
	return table

func deserialize(data: Dictionary) -> void:
	if data.has("tables"):
		_tables.clear()
		for table_name in data.tables:
			var table_data = data.tables[table_name]
			
			# Create a table instance directly
			var table_name_to_use = table_name if table_name != "" else "unnamed_table"
			var table = Table.new(table_name_to_use)
			
			# Implement table deserialization with the existing Table class
			# Load entries from table_data here if needed
			
			_tables[table_name] = table
	
	if data.has("history"):
		_history = data.history.duplicate()
	
	if data.has("history_metadata"):
		_history_metadata = data.history_metadata.duplicate()
	
	if data.has("categories"):
		_history_categories = data.categories.duplicate()

# Custom validation handling
func _run_custom_validation(table: Table, roll: int) -> Dictionary:
	# Implement custom validation logic here
	return {"success": true, "reason": ""}

# Process table data for the tests
func process_data(table_data: Dictionary) -> Dictionary:
	if table_data == null or table_data.is_empty():
		return {"success": false, "reason": "Empty or null table data"}
	
	var result = {"success": true, "processed_rows": 0, "warnings": []}
	
	# Process the table data based on its structure
	if "rows" in table_data and table_data.rows is Array:
		result.processed_rows = table_data.rows.size()
		
		# Process each row
		for i in range(table_data.rows.size()):
			var row = table_data.rows[i]
			if row == null or not _validate_row(row):
				result.warnings.append("Invalid row at index " + str(i))
	
	# Log processing attempt to history
	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"operation": "process_data",
		"row_count": result.processed_rows,
		"warning_count": result.warnings.size()
	}
	_add_to_history(entry)
	
	return result

# Alternative name for the same functionality (for backward compatibility)
func process_table(table_data: Dictionary) -> Dictionary:
	return process_data(table_data)

# Helper to validate a row of data
func _validate_row(row) -> bool:
	if not row is Dictionary:
		return false
	
	# Basic validation - can be expanded based on requirements
	return true
