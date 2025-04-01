@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/systems/TableLoader.gd")

## Dependencies - explicit loading to avoid circular references
const TableProcessor = preload("res://src/core/systems/TableProcessor.gd")
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

## Signals with proper type annotations
signal table_loaded(table_name: String)
signal loading_failed(table_name: String, reason: String)
signal validation_error(table_name: String, error: String)
signal table_saved(table_name: String, path: String)
signal loading_progress(table_name: String, progress: float, status: String)
signal batch_loading_completed(success_count: int, failure_count: int)

## Configuration
const REQUIRED_FIELDS = ["name", "entries"]
const OPTIONAL_FIELDS = ["validation_rules", "modifiers", "default_result", "metadata", "custom_validation"]
const VALID_FORMATS = ["json", "binary"]

## Performance settings
const MAX_CACHE_SIZE: int = 100 # Maximum number of tables to keep in memory
const BATCH_SIZE: int = 10 # Number of tables to load per batch
const CACHE_EXPIRY_TIME: int = 600 # Time in seconds before cache entry is considered stale (10 minutes)

## Cache for preloaded tables with metadata
static var _table_cache: Dictionary = {} # {file_path: {table, timestamp, access_count}}
static var _background_loading_tables: Dictionary = {} # {file_path: {status, timestamp, progress, error}}
static var _batch_operations: Dictionary = {} # {batch_id: {tables, completed, total, errors}}

## Cache management variables
static var _last_cache_cleanup: int = 0
static var _current_threads: Array[Thread] = []
static var _next_batch_id: int = 0

## Initialize the loader and set up cache management
static func initialize() -> void:
	_last_cache_cleanup = Time.get_unix_time_from_system()
	_cleanup_cache()

## Enhanced table loading with validation and caching
## @param file_path: Path to the table file
## @param validate: Whether to validate the table data
## @param force_reload: Whether to force reload from disk even if cached
## @return: The loaded table or null if failed
static func load_table_from_file(file_path: String, validate: bool = true, force_reload: bool = false) -> TableProcessor.Table:
	# Check cache first if not forcing reload
	if not force_reload and _table_cache.has(file_path):
		var cache_entry = _table_cache[file_path]
		var current_time = Time.get_unix_time_from_system()
		
		# Check if cache entry is still valid
		if current_time - cache_entry.timestamp < CACHE_EXPIRY_TIME:
			# Update access count and timestamp for cache prioritization
			cache_entry.access_count += 1
			cache_entry.timestamp = current_time
			return cache_entry.table
	
	# File loading with error handling
	if not FileAccess.file_exists(file_path):
		push_error("Table file not found: " + file_path)
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		push_error("Failed to open table file %s (Error: %d)" % [file_path, err])
		return null
		
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		push_error("Table file is empty: " + file_path)
		return null
	
	var parse_result = JSON.parse_string(json_string)
	if parse_result == null:
		push_error("Failed to parse table JSON in " + file_path)
		return null
	
	# Validate data structure
	if validate and not _validate_table_data(parse_result):
		push_error("Invalid table data structure in " + file_path)
		return null
	
	var table = create_table_from_data(parse_result)
	
	# Cache the loaded table with metadata
	if table:
		_add_to_cache(file_path, table)
		
	return table

## Add a table to the cache with metadata
## @param file_path: Path to the table file (used as key)
## @param table: The table to cache
static func _add_to_cache(file_path: String, table: TableProcessor.Table) -> void:
	var current_time = Time.get_unix_time_from_system()
	
	_table_cache[file_path] = {
		"table": table,
		"timestamp": current_time,
		"access_count": 1,
		"size": 0 # Will estimate size later if needed
	}
	
	# Clean up cache if it's been more than 10 minutes or cache is too large
	if current_time - _last_cache_cleanup > 600 or _table_cache.size() > MAX_CACHE_SIZE:
		_cleanup_cache()

## Clean up the cache by removing least recently used tables
static func _cleanup_cache() -> void:
	if _table_cache.size() <= MAX_CACHE_SIZE / 2:
		# No need to clean if cache is less than half full
		_last_cache_cleanup = Time.get_unix_time_from_system()
		return
	
	# Sort cache entries by last access time and count
	var entries = []
	for path in _table_cache:
		entries.append({
			"path": path,
			"timestamp": _table_cache[path].timestamp,
			"access_count": _table_cache[path].access_count
		})
	
	# Sort by access count (ascending) then timestamp (oldest first)
	entries.sort_custom(func(a, b):
		if a.access_count == b.access_count:
			return a.timestamp < b.timestamp
		return a.access_count < b.access_count
	)
	
	# Remove oldest/least used entries until we're under the target size
	var target_size = MAX_CACHE_SIZE / 2
	while _table_cache.size() > target_size and entries.size() > 0:
		var entry = entries.pop_front()
		_table_cache.erase(entry.path)
	
	_last_cache_cleanup = Time.get_unix_time_from_system()

## Begin background loading a table file
## @param file_path: Path to the table file
## @param high_priority: Whether to give this table loading priority
## @return: Whether the loading request was successfully started
static func load_table_in_background(file_path: String, high_priority: bool = false) -> bool:
	# Skip if already cached or loading
	if _table_cache.has(file_path) or _background_loading_tables.has(file_path):
		return true
		
	if not FileAccess.file_exists(file_path):
		push_error("Table file not found for background loading: " + file_path)
		return false
	
	# Setup tracking info
	_background_loading_tables[file_path] = {
		"status": "loading",
		"timestamp": Time.get_unix_time_from_system(),
		"progress": 0.0,
		"high_priority": high_priority
	}
	
	# Clean up any stopped threads
	_cleanup_threads()
	
	# Use a thread to load the data
	var thread = Thread.new()
	thread.start(_load_table_thread_func.bind(file_path, thread))
	_current_threads.append(thread)
	
	return true

## Clean up completed threads
static func _cleanup_threads() -> void:
	var active_threads: Array[Thread] = []
	
	for thread in _current_threads:
		if not thread.is_alive():
			thread.wait_to_finish()
		else:
			active_threads.append(thread)
	
	_current_threads = active_threads

## Thread function to load table data in background
static func _load_table_thread_func(file_path: String, thread: Thread) -> void:
	# Update progress
	_update_loading_progress(file_path, 0.1, "Opening file")
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		_background_loading_tables[file_path] = {
			"status": "error",
			"error": "Failed to open file (Error: %d)" % err,
			"timestamp": Time.get_unix_time_from_system(),
			"progress": 0.0
		}
		return
	
	# Update progress
	_update_loading_progress(file_path, 0.3, "Reading file")
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		_background_loading_tables[file_path] = {
			"status": "error",
			"error": "File is empty",
			"timestamp": Time.get_unix_time_from_system(),
			"progress": 0.0
		}
		return
	
	# Update progress
	_update_loading_progress(file_path, 0.5, "Parsing JSON")
	
	var parse_result = JSON.parse_string(json_string)
	
	if parse_result == null:
		_background_loading_tables[file_path] = {
			"status": "error",
			"error": "Failed to parse JSON",
			"timestamp": Time.get_unix_time_from_system(),
			"progress": 0.0
		}
		return
	
	# Update progress
	_update_loading_progress(file_path, 0.7, "Validating data")
	
	if not _validate_table_data(parse_result):
		_background_loading_tables[file_path] = {
			"status": "error",
			"error": "Invalid table data",
			"timestamp": Time.get_unix_time_from_system(),
			"progress": 0.0
		}
		return
	
	# Update progress
	_update_loading_progress(file_path, 0.9, "Creating table")
	
	var table = create_table_from_data(parse_result)
	
	if table:
		_add_to_cache(file_path, table)
		_background_loading_tables[file_path] = {
			"status": "completed",
			"timestamp": Time.get_unix_time_from_system(),
			"progress": 1.0
		}
	else:
		_background_loading_tables[file_path] = {
			"status": "error",
			"error": "Failed to create table",
			"timestamp": Time.get_unix_time_from_system(),
			"progress": 0.0
		}

## Update loading progress for a table
static func _update_loading_progress(file_path: String, progress: float, status: String) -> void:
	if _background_loading_tables.has(file_path):
		_background_loading_tables[file_path].progress = progress
		_background_loading_tables[file_path].status_text = status

## Check status of background loading
## @param file_path: Path to the table file
## @return: Dictionary with loading status information
static func get_background_loading_status(file_path: String) -> Dictionary:
	if _table_cache.has(file_path):
		return {
			"status": "completed",
			"cached": true,
			"progress": 1.0
		}
		
	if not _background_loading_tables.has(file_path):
		return {
			"status": "not_started",
			"progress": 0.0
		}
		
	return _background_loading_tables[file_path]

## Begin batch loading multiple tables
## @param file_paths: Array of table file paths to load
## @param batch_name: Optional name for the batch
## @return: Batch ID for tracking status
static func batch_load_tables(file_paths: Array, batch_name: String = "") -> int:
	var batch_id = _next_batch_id
	_next_batch_id += 1
	
	_batch_operations[batch_id] = {
		"tables": file_paths.duplicate(),
		"completed": 0,
		"total": file_paths.size(),
		"errors": [],
		"name": batch_name,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Start loading tables in batches to avoid overloading
	var current_batch = []
	for i in range(min(BATCH_SIZE, file_paths.size())):
		current_batch.append(file_paths[i])
	
	# Start loading the initial batch
	for path in current_batch:
		load_table_in_background(path)
	
	# Start a thread to monitor and manage the batch loading
	var thread = Thread.new()
	thread.start(_batch_loading_monitor.bind(batch_id, thread))
	_current_threads.append(thread)
	
	return batch_id

## Thread function to monitor batch loading progress
static func _batch_loading_monitor(batch_id: int, thread: Thread) -> void:
	if not _batch_operations.has(batch_id):
		return
		
	var batch = _batch_operations[batch_id]
	var tables = batch.tables.duplicate()
	var batch_size = min(BATCH_SIZE, tables.size())
	var current_index = batch_size
	
	while batch.completed < batch.total:
		var completed_count = 0
		var error_count = 0
		
		# Check status of all tables
		for path in tables:
			var status = get_background_loading_status(path)
			
			# Safely check the status dictionary properties
			if status.has("status") and status["status"] == "completed":
				completed_count += 1
			elif status.has("cached") and status["cached"] == true:
				completed_count += 1
			elif status.has("status") and status["status"] == "error":
				error_count += 1
				if not path in batch.errors:
					batch.errors.append(path)
		
		# Update batch progress
		batch.completed = completed_count
		
		# Start loading next batch if current one is mostly done
		if current_index < tables.size() and completed_count + error_count >= current_index - batch_size / 2:
			var next_batch_size = min(BATCH_SIZE, tables.size() - current_index)
			for i in range(next_batch_size):
				if current_index < tables.size():
					load_table_in_background(tables[current_index])
					current_index += 1
		
		# Exit if all tables are accounted for
		if completed_count + error_count >= batch.total:
			break
			
		# Sleep to avoid hogging the CPU
		OS.delay_msec(100)
	
	# Clean up and signal completion
	batch.timestamp_completed = Time.get_unix_time_from_system()
	batch.status = "completed"
	
	# Clean up thread
	thread.wait_to_finish()

## Check status of a batch loading operation
## @param batch_id: ID of the batch to check
## @return: Dictionary with batch status information
static func get_batch_status(batch_id: int) -> Dictionary:
	if not _batch_operations.has(batch_id):
		return {
			"status": "not_found"
		}
		
	var batch = _batch_operations[batch_id]
	var progress = float(batch.completed) / float(batch.total) if batch.total > 0 else 1.0
	
	return {
		"status": batch.get("status", "in_progress"),
		"completed": batch.completed,
		"total": batch.total,
		"progress": progress,
		"errors": batch.errors,
		"name": batch.name
	}

## Preload a batch of tables for faster access later
## @param file_paths: Array of table file paths to preload
## @return: Batch ID for tracking status
static func preload_tables(file_paths: Array) -> int:
	return batch_load_tables(file_paths, "preload")

## Force reload all cached tables from disk
static func refresh_cache() -> void:
	var paths = _table_cache.keys().duplicate()
	_table_cache.clear()
	
	for path in paths:
		load_table_in_background(path)

## Clear cache for specific tables or all tables
## @param file_paths: Optional array of specific tables to clear
static func clear_cache(file_paths: Array = []) -> void:
	if file_paths.is_empty():
		_table_cache.clear()
	else:
		for path in file_paths:
			if _table_cache.has(path):
				_table_cache.erase(path)

## Enhanced table creation with metadata support
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

# Enhanced directory loading with validation and caching
static func load_tables_from_directory(dir_path: String, validate: bool = true, use_cache: bool = true) -> Dictionary:
	var tables = {}
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		push_error("Failed to open directory: " + dir_path)
		return tables
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# Collect all json files first
	var json_files = []
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			json_files.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# If we have files, start a batch load
	if not json_files.is_empty():
		var batch_id = batch_load_tables(json_files, "directory_" + dir_path.get_file())
		
		# For synchronous loading, wait for batch to complete
		if not use_cache:
			while true:
				var status = get_batch_status(batch_id)
				if status.status == "completed" or status.status == "not_found":
					break
				OS.delay_msec(50)
			
			# Collect results
			for file_path in json_files:
				var table_name = file_path.get_file().get_basename()
				if _table_cache.has(file_path):
					tables[table_name] = _table_cache[file_path].table
	
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
	
	# Write to temporary file first
	var temp_path = file_path + ".tmp"
	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return FileAccess.get_open_error()
	
	temp_file.store_string(json)
	temp_file.close()
	
	# Replace the original file with the temp file
	var dir = DirAccess.open(file_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	
	# Delete original if it exists
	if FileAccess.file_exists(file_path):
		var err = dir.remove(file_path.get_file())
		if err != OK:
			return err
	
	# Rename temp to final
	var err = dir.rename(temp_path.get_file(), file_path.get_file())
	if err != OK:
		return err
	
	# Update cache if this table was cached
	if _table_cache.has(file_path):
		_table_cache.erase(file_path)
		load_table_in_background(file_path)
	
	return OK

static func _save_table_as_binary(table: TableProcessor.Table, file_path: String) -> Error:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		return FileAccess.get_open_error()
	
	# Implement binary serialization
	# For now, just store JSON data
	var json_data = table.serialize()
	file.store_var(json_data)
	file.close()
	
	return OK

# Enhanced JSON conversion with metadata
static func table_to_json(table: TableProcessor.Table) -> String:
	var data = table.serialize()
	return JSON.stringify(data, "\t")
