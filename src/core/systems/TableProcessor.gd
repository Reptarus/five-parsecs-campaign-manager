class_name TableProcessor
extends Node

signal roll_processed(table_name: String, result: Dictionary)
signal validation_failed(table_name: String, reason: String)
signal custom_roll_processed(table_name: String, roll: int, result: Dictionary)

# Table Entry class for defining table rows
class TableEntry:
	var roll_range: Vector2i # min and max values for this entry
	var result: Variant # The result value (can be any type)
	var weight: float = 1.0 # For weighted random selection
	var tags: Array[String] = [] # For filtering and special handling
	
	func _init(min_roll: int, max_roll: int, res: Variant, w: float = 1.0, t: Array[String] = []) -> void:
		roll_range = Vector2i(min_roll, max_roll)
		result = res
		weight = w
		tags = t
	
	func matches_roll(roll: int) -> bool:
		return roll >= roll_range.x and roll <= roll_range.y
	
	func has_tag(tag: String) -> bool:
		return tag in tags

# Table class for managing collections of entries
class Table:
	var name: String
	var entries: Array[TableEntry] = []
	var validation_rules: Array[Callable] = []
	var modifiers: Array[Callable] = []
	var default_result: Variant = null
	
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

# Main processor variables
var _tables: Dictionary = {} # name -> Table
var _history: Array[Dictionary] = []
const MAX_HISTORY_SIZE: int = 100

func _init() -> void:
	pass

# Table management methods
func register_table(table: Table) -> void:
	_tables[table.name] = table

func has_table(table_name: String) -> bool:
	return _tables.has(table_name)

func get_table(table_name: String) -> Table:
	return _tables.get(table_name)

# Rolling methods
func roll_table(table_name: String, custom_roll: int = -1) -> Dictionary:
	if not has_table(table_name):
		validation_failed.emit(table_name, "Table not found")
		return {"success": false, "reason": "Table not found"}
	
	var table = get_table(table_name)
	var roll = custom_roll if custom_roll >= 0 else randi() % 100 + 1
	
	# Apply validation rules
	for rule in table.validation_rules:
		var validation = rule.call(roll)
		if not validation["valid"]:
			validation_failed.emit(table_name, validation["reason"])
			return {"success": false, "reason": validation["reason"]}
	
	# Get base result
	var result = table.get_result(roll)
	
	# Apply modifiers
	for modifier in table.modifiers:
		result = modifier.call(result)
	
	# Record in history
	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"table": table_name,
		"roll": roll,
		"result": result
	}
	_add_to_history(entry)
	
	# Emit appropriate signal
	if custom_roll >= 0:
		custom_roll_processed.emit(table_name, roll, {"success": true, "result": result})
	else:
		roll_processed.emit(table_name, {"success": true, "result": result})
	
	return {"success": true, "result": result}

func roll_weighted_table(table_name: String) -> Dictionary:
	if not has_table(table_name):
		validation_failed.emit(table_name, "Table not found")
		return {"success": false, "reason": "Table not found"}
	
	var table = get_table(table_name)
	var result = table.get_weighted_result()
	
	# Apply modifiers
	for modifier in table.modifiers:
		result = modifier.call(result)
	
	# Record in history
	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"table": table_name,
		"weighted": true,
		"result": result
	}
	_add_to_history(entry)
	
	roll_processed.emit(table_name, {"success": true, "result": result})
	return {"success": true, "result": result}

# History management
func _add_to_history(entry: Dictionary) -> void:
	_history.append(entry)
	while _history.size() > MAX_HISTORY_SIZE:
		_history.pop_front()

func get_roll_history(table_name: String = "") -> Array:
	if table_name.is_empty():
		return _history.duplicate()
	return _history.filter(func(entry): return entry["table"] == table_name)

func clear_history() -> void:
	_history.clear()

# Serialization
func serialize() -> Dictionary:
	var history = []
	for entry in _history:
		# Only serialize basic types
		if entry["result"] is Array or entry["result"] is Dictionary:
			history.append(entry.duplicate())
		else:
			var serialized_entry = entry.duplicate()
			serialized_entry["result"] = str(entry["result"])
			history.append(serialized_entry)
	
	return {
		"history": history
	}

func deserialize(data: Dictionary) -> void:
	if data.has("history"):
		_history = data["history"].duplicate()