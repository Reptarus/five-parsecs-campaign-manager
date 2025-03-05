@tool
class_name FPCM_ResourceSystem
extends Node

## A comprehensive system for managing game resources with advanced features
##
## This system handles resource tracking, validation, transaction history, 
## market simulation, asynchronous loading, and resource pooling.
## It supports dynamic resource limits, validation rules, and serialization
## for save/load operations.

## Dependencies - explicit loading to avoid circular references
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

## Signals for resource operations with proper documentation
signal resource_changed(type: int, amount: int)
signal resource_depleted(type: int)
signal resource_added(type: int, amount: int, source: String)
signal resource_removed(type: int, amount: int, source: String)
signal transaction_recorded(transaction: ResourceTransaction)
signal validation_failed(type: int, amount: int, reason: String)
## Advanced signals for async operations and pooling
signal resource_loaded(resource_path: String, resource: Resource)
signal resource_load_failed(resource_path: String, error: int)
signal pool_initialized(pool_name: String, size: int)
signal pool_resource_acquired(pool_name: String, resource: Resource)
signal pool_resource_released(pool_name: String, resource: Resource)

# Resource Transaction class for history tracking
class ResourceTransaction:
	var timestamp: int
	var type: int
	var amount: int
	var transaction_type: String # "ADD" or "REMOVE"
	var source: String
	var balance: int # Balance after transaction
	
	func _init(r_type: int, r_amount: int, t_type: String, t_source: String, t_balance: int) -> void:
		timestamp = Time.get_unix_time_from_system()
		type = r_type
		amount = r_amount
		transaction_type = t_type
		source = t_source
		balance = t_balance
	
	func serialize() -> Dictionary:
		return {
			"timestamp": timestamp,
			"type": type,
			"amount": amount,
			"transaction_type": transaction_type,
			"source": source,
			"balance": balance
		}
	
	static func deserialize(data: Dictionary) -> ResourceTransaction:
		var transaction := ResourceTransaction.new(
			int(data["type"]),
			int(data["amount"]),
			data["transaction_type"] as String,
			data["source"] as String,
			int(data["balance"])
		)
		transaction.timestamp = int(data["timestamp"])
		return transaction

# Resource Validation Rule class
class ResourceValidationRule:
	var min_value: int = 0
	var max_value: int = -1 # -1 means no upper limit
	var allowed_sources: Array[String] = [] # Empty means all sources allowed
	var validation_callback: Callable
	
	func _init(min_val: int = 0, max_val: int = -1, sources: Array[String] = [], callback: Callable = Callable()) -> void:
		min_value = min_val
		max_value = max_val
		allowed_sources = sources
		validation_callback = callback
	
	func validate_transaction(current_amount: int, change_amount: int, source: String) -> Dictionary:
		# Check source restrictions
		if not allowed_sources.is_empty() and not source in allowed_sources:
			return {"valid": false, "reason": "Invalid source: " + source}
		
		# Calculate new amount
		var new_amount := current_amount + change_amount
		
		# Check minimum value
		if new_amount < min_value:
			return {"valid": false, "reason": "Would fall below minimum value"}
		
		# Check maximum value
		if max_value >= 0 and new_amount > max_value:
			return {"valid": false, "reason": "Would exceed maximum value"}
		
		# Run custom validation if provided
		if validation_callback.is_valid():
			var custom_result := validation_callback.call(current_amount, change_amount, source) as Dictionary
			if not custom_result["valid"]:
				return custom_result
		
		return {"valid": true, "reason": ""}

# Resource Table Entry class for table-based generation
class ResourceTableEntry:
	var type: int
	var base_value: int
	var min_value: int
	var max_value: int
	var rarity: float # 0.0 to 1.0
	var market_volatility: float # 0.0 to 1.0
	var dependencies: Array[int] # Resource types that affect this resource
	
	func _init(r_type: int, base: int = 0, min_val: int = 0, max_val: int = -1,
			   rare: float = 0.5, vol: float = 0.0, deps: Array[int] = []) -> void:
		type = r_type
		base_value = base
		min_value = min_val
		max_value = max_val
		rarity = rare
		market_volatility = vol
		dependencies = deps
	
	func calculate_value(market_state: float = 0.0, dependency_values: Dictionary = {}) -> int:
		var value := base_value
		
		# Apply market volatility
		if market_volatility > 0:
			value += int(base_value * market_volatility * market_state)
		
		# Apply dependency effects
		for dep_type in dependencies:
			if dependency_values.has(dep_type):
				var dep_effect: int = dependency_values[dep_type] - base_value
				value += int(dep_effect * 0.1) # 10% influence from each dependency
		
		# Ensure within bounds
		if max_value >= 0:
			value = mini(value, max_value)
		value = maxi(value, min_value)
		
		return value

# Resource Market class for handling market-based resources
class ResourceMarket:
	var market_state: float = 0.0 # -1.0 to 1.0
	var resource_tables: Dictionary = {} # type -> ResourceTableEntry
	var last_update_time: int = 0
	const UPDATE_INTERVAL: int = 300 # 5 minutes
	
	func _init() -> void:
		last_update_time = Time.get_unix_time_from_system()
	
	func add_resource_table(entry: ResourceTableEntry) -> void:
		resource_tables[entry.type] = entry
	
	func update_market_state() -> void:
		var current_time := Time.get_unix_time_from_system()
		if current_time - last_update_time < UPDATE_INTERVAL:
			return
			
		# Update market state with some randomness
		market_state = clampf(market_state + randf_range(-0.2, 0.2), -1.0, 1.0)
		last_update_time = current_time
	
	func get_resource_value(type: int, dependency_values: Dictionary = {}) -> int:
		if not resource_tables.has(type):
			return 0
			
		update_market_state()
		return resource_tables[type].calculate_value(market_state, dependency_values)

# New ResourcePool class for object pooling
class ResourcePool:
	var pool_name: String
	var resource_scene: PackedScene
	var active_resources: Array[Resource] = []
	var available_resources: Array[Resource] = []
	var max_size: int = 20
	var auto_expand: bool = true
	
	func _init(name: String, scene: PackedScene, initial_size: int = 5, max_pool_size: int = 20, auto_expand_pool: bool = true) -> void:
		pool_name = name
		resource_scene = scene
		max_size = max_pool_size
		auto_expand = auto_expand_pool
		
		# Initialize the pool with resources
		for i in range(initial_size):
			var resource = _create_resource()
			if resource:
				available_resources.append(resource)
	
	func _create_resource() -> Resource:
		if resource_scene:
			var instance = resource_scene.instantiate()
			if instance is Resource:
				return instance
		return null
	
	## Get a resource from the pool
	## If no resources are available and auto_expand is true, creates a new one
	## @return: A resource from the pool or null if none available
	func acquire() -> Resource:
		if available_resources.is_empty():
			if auto_expand and active_resources.size() < max_size:
				var new_resource = _create_resource()
				if new_resource:
					active_resources.append(new_resource)
					return new_resource
			return null
		
		var resource = available_resources.pop_back()
		active_resources.append(resource)
		return resource
	
	## Return a resource to the pool for reuse
	## @param resource: The resource to return to the pool
	## @return: Whether the operation was successful
	func release(resource: Resource) -> bool:
		var index = active_resources.find(resource)
		if index != -1:
			active_resources.remove_at(index)
			available_resources.append(resource)
			return true
		return false
	
	## Clear all resources from the pool
	func clear() -> void:
		for i in range(active_resources.size() - 1, -1, -1):
			var resource = active_resources[i]
			if resource is Node and resource.is_inside_tree():
				resource.queue_free()
		
		for i in range(available_resources.size() - 1, -1, -1):
			var resource = available_resources[i]
			if resource is Node and resource.is_inside_tree():
				resource.queue_free()
		
		active_resources.clear()
		available_resources.clear()

# Core resource properties
var _resources: Dictionary = {}
var _resource_limits: Dictionary = {}
var _transaction_history: Array[ResourceTransaction] = []
var _validation_rules: Dictionary = {}
const MAX_HISTORY_SIZE: int = 100

var _market: ResourceMarket = ResourceMarket.new()

# Resource loading and pooling variables
var _loading_resources: Dictionary = {} # path -> loading_status
var _resource_pools: Dictionary = {} # name -> ResourcePool
var _resource_cache: Dictionary = {} # path -> {resource, timestamp, ref_count}

# Configuration
const MAX_CONCURRENT_LOADS: int = 6
const CACHE_CLEANUP_INTERVAL: int = 300 # 5 minutes
const MAX_CACHE_SIZE: int = 50
var _last_cache_cleanup: int = 0
var _current_loads: int = 0

## Initialize the resource system
func _init() -> void:
	_initialize_resources()
	_last_cache_cleanup = Time.get_unix_time_from_system()

## Process function to handle background tasks
func _process(delta: float) -> void:
	_check_cache_cleanup()

## Initialize resource tracking
func _initialize_resources() -> void:
	for type: int in GameEnums.ResourceType.values():
		_resources[type] = 0
		_resource_limits[type] = -1 # -1 means no limit
		_validation_rules[type] = ResourceValidationRule.new()

## Periodically check if cache cleanup is needed
func _check_cache_cleanup() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - _last_cache_cleanup > CACHE_CLEANUP_INTERVAL:
		_cleanup_resource_cache()
		_last_cache_cleanup = current_time

## Clean up rarely used resources from cache
func _cleanup_resource_cache() -> void:
	# Skip if cache is small
	if _resource_cache.size() <= MAX_CACHE_SIZE / 2:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var items_to_remove = []
	
	# Identify old or unused resources
	for path in _resource_cache:
		var cache_entry = _resource_cache[path]
		if cache_entry.ref_count <= 0 and current_time - cache_entry.timestamp > CACHE_CLEANUP_INTERVAL:
			items_to_remove.append(path)
	
	# Remove identified resources
	for path in items_to_remove:
		_resource_cache.erase(path)

## Add a validation rule for a resource type
## @param type: Resource type to add the rule for
## @param rule: Validation rule to apply
func add_validation_rule(type: int, rule: ResourceValidationRule) -> void:
	_validation_rules[type] = rule

## Validate a resource transaction against rules
## @param type: Resource type to validate
## @param amount: Amount to add or remove
## @param source: Source of the transaction
## @return: Dictionary with validity and reason if invalid
func validate_transaction(type: int, amount: int, source: String) -> Dictionary:
	if not _validation_rules.has(type):
		return {"valid": true, "reason": ""}
	return _validation_rules[type].validate_transaction(_resources.get(type, 0), amount, source)

## Record a resource transaction in history
## @param type: Resource type involved
## @param amount: Amount changed
## @param t_type: Transaction type (ADD/REMOVE)
## @param source: Source of the transaction
func record_transaction(type: int, amount: int, t_type: String, source: String) -> void:
	var transaction := ResourceTransaction.new(
		type,
		amount,
		t_type,
		source,
		_resources.get(type, 0)
	)
	_transaction_history.append(transaction)
	
	# Keep history size in check
	while _transaction_history.size() > MAX_HISTORY_SIZE:
		_transaction_history.pop_front()
	
	transaction_recorded.emit(transaction)

## Get transaction history for a specific resource type or all types
## @param type: Resource type to filter by, or -1 for all
## @return: Array of transaction objects
func get_transaction_history(type: int = -1) -> Array[ResourceTransaction]:
	if type == -1:
		return _transaction_history.duplicate()
	return _transaction_history.filter(func(t): return t.type == type)

## Check if a resource type is tracked
## @param type: Resource type to check
## @return: Whether the resource exists
func has_resource(type: int) -> bool:
	return _resources.has(type)

## Get the current amount of a resource
## @param type: Resource type to check
## @return: Current amount of the resource
func get_resource_amount(type: int) -> int:
	return _resources.get(type, 0)

## Add resources of a specific type
## @param type: Resource type to add
## @param amount: Amount to add
## @param source: Source of the addition
func add_resource(type: int, amount: int, source: String = "system") -> void:
	if amount <= 0:
		return
	
	# Validate transaction
	var validation := validate_transaction(type, amount, source)
	if not validation["valid"]:
		validation_failed.emit(type, amount, validation["reason"])
		return
		
	var current := get_resource_amount(type)
	var limit: int = _resource_limits[type]
	
	if limit >= 0:
		amount = mini(amount, limit - current)
		
	if amount > 0:
		_resources[type] = current + amount
		record_transaction(type, amount, "ADD", source)
		resource_added.emit(type, amount, source)
		resource_changed.emit(type, _resources[type])

## Remove resources of a specific type
## @param type: Resource type to remove
## @param amount: Amount to remove
## @param source: Source of the removal
## @return: Whether the removal was successful
func remove_resource(type: int, amount: int, source: String = "system") -> bool:
	if amount <= 0:
		return true
	
	# Validate transaction
	var validation := validate_transaction(type, - amount, source)
	if not validation["valid"]:
		validation_failed.emit(type, - amount, validation["reason"])
		return false
		
	var current := get_resource_amount(type)
	if current < amount:
		return false
		
	_resources[type] = current - amount
	record_transaction(type, amount, "REMOVE", source)
	resource_removed.emit(type, amount, source)
	resource_changed.emit(type, _resources[type])
	
	if _resources[type] == 0:
		resource_depleted.emit(type)
		
	return true

## Set a limit for a resource type
## @param type: Resource type to limit
## @param limit: Maximum amount (-1 for no limit)
func set_resource_limit(type: int, limit: int) -> void:
	_resource_limits[type] = limit
	if limit >= 0:
		var current := get_resource_amount(type)
		if current > limit:
			remove_resource(type, current - limit, "limit_adjustment")

## Get the current limit for a resource type
## @param type: Resource type to check
## @return: Current limit for the resource (-1 for no limit)
func get_resource_limit(type: int) -> int:
	return _resource_limits.get(type, -1)

## Clear all resources from the system
func clear_resources() -> void:
	for type: int in _resources.keys():
		if _resources[type] > 0:
			record_transaction(type, _resources[type], "REMOVE", "clear")
		_resources[type] = 0
		resource_changed.emit(type, 0)
		resource_depleted.emit(type)

## Asynchronously load a resource with progress tracking
## @param resource_path: Path to the resource
## @param high_priority: Whether to load with high priority
## @return: Whether the load was successfully started
func load_resource_async(resource_path: String, high_priority: bool = false) -> bool:
	# Return cached resource if available
	if _resource_cache.has(resource_path):
		var cache_entry = _resource_cache[resource_path]
		cache_entry.ref_count += 1
		cache_entry.timestamp = Time.get_unix_time_from_system()
		
		# If resource is already loaded, emit signal on next frame
		if cache_entry.resource:
			call_deferred("emit_signal", "resource_loaded", resource_path, cache_entry.resource)
			return true
	
	# Skip if already loading
	if _loading_resources.has(resource_path):
		return true
	
	# Check if path exists
	if not ResourceLoader.exists(resource_path):
		push_error("Resource does not exist: " + resource_path)
		resource_load_failed.emit(resource_path, ERR_FILE_NOT_FOUND)
		return false
	
	# Set up loading tracking
	_loading_resources[resource_path] = {
		"status": ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS,
		"progress": 0.0,
		"priority": ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Add to cache tracking
	if not _resource_cache.has(resource_path):
		_resource_cache[resource_path] = {
			"resource": null,
			"timestamp": Time.get_unix_time_from_system(),
			"ref_count": 1
		}
	else:
		_resource_cache[resource_path].ref_count += 1
	
	# Start background loading
	ResourceLoader.load_threaded_request(
		resource_path,
		"",
		ResourceLoader.get_resource_uid(resource_path),
		ResourceLoader.CacheMode.CACHE_MODE_REUSE
	)
	
	_current_loads += 1
	
	return true

## Update status of async loading resources
## Call this from _process to check loading progress
func update_resource_loading() -> void:
	var completed_loads = []
	
	for path in _loading_resources:
		var status = ResourceLoader.load_threaded_get_status(path)
		
		match status:
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
				# Update progress
				var progress = []
				var load_progress = ResourceLoader.load_threaded_get_status(path, progress)
				if not progress.is_empty():
					_loading_resources[path].progress = progress[0]
			
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
				# Resource loaded successfully
				var resource = ResourceLoader.load_threaded_get(path)
				if resource:
					if _resource_cache.has(path):
						_resource_cache[path].resource = resource
						_resource_cache[path].timestamp = Time.get_unix_time_from_system()
					
					resource_loaded.emit(path, resource)
				else:
					resource_load_failed.emit(path, ERR_CANT_CREATE)
				
				completed_loads.append(path)
				_current_loads -= 1
			
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
				# Loading failed
				resource_load_failed.emit(path, ERR_FILE_CORRUPT)
				completed_loads.append(path)
				_current_loads -= 1
	
	# Remove completed or failed loads
	for path in completed_loads:
		_loading_resources.erase(path)

## Release a reference to a loaded resource
## @param resource_path: Path to the resource
func release_resource(resource_path: String) -> void:
	if _resource_cache.has(resource_path):
		_resource_cache[resource_path].ref_count -= 1

## Create a resource pool for efficient object reuse
## @param pool_name: Name of the pool
## @param resource_scene: Scene to instantiate for pool objects
## @param initial_size: Initial number of objects to create
## @param max_size: Maximum pool size
## @param auto_expand: Whether the pool should automatically expand
## @return: Whether the pool was created successfully
func create_resource_pool(pool_name: String, resource_scene: PackedScene, initial_size: int = 5,
						max_size: int = 20, auto_expand: bool = true) -> bool:
	if _resource_pools.has(pool_name):
		push_warning("Resource pool already exists: " + pool_name)
		return false
	
	var pool = ResourcePool.new(pool_name, resource_scene, initial_size, max_size, auto_expand)
	_resource_pools[pool_name] = pool
	
	pool_initialized.emit(pool_name, initial_size)
	return true

## Get a resource from a pool
## @param pool_name: Name of the pool
## @return: A resource from the pool or null if unavailable
func acquire_from_pool(pool_name: String) -> Resource:
	if not _resource_pools.has(pool_name):
		push_error("Resource pool does not exist: " + pool_name)
		return null
	
	var resource = _resource_pools[pool_name].acquire()
	if resource:
		pool_resource_acquired.emit(pool_name, resource)
	
	return resource

## Return a resource to its pool
## @param pool_name: Name of the pool
## @param resource: Resource to return
## @return: Whether the release was successful
func release_to_pool(pool_name: String, resource: Resource) -> bool:
	if not _resource_pools.has(pool_name):
		push_error("Resource pool does not exist: " + pool_name)
		return false
	
	var success = _resource_pools[pool_name].release(resource)
	if success:
		pool_resource_released.emit(pool_name, resource)
	
	return success

## Clear a specific resource pool or all pools
## @param pool_name: Name of the pool to clear, or empty for all
func clear_resource_pools(pool_name: String = "") -> void:
	if pool_name.is_empty():
		# Clear all pools
		for name in _resource_pools:
			_resource_pools[name].clear()
		_resource_pools.clear()
	elif _resource_pools.has(pool_name):
		_resource_pools[pool_name].clear()
		_resource_pools.erase(pool_name)

## Serialize resource system state to a dictionary
## @return: Dictionary containing all resource system data
func serialize() -> Dictionary:
	var history: Array = []
	for transaction in _transaction_history:
		history.append(transaction.serialize())
	
	var market_tables: Dictionary = {}
	for type in _market.resource_tables:
		var entry := _market.resource_tables[type] as ResourceTableEntry
		market_tables[str(type)] = {
			"base_value": entry.base_value,
			"min_value": entry.min_value,
			"max_value": entry.max_value,
			"rarity": entry.rarity,
			"market_volatility": entry.market_volatility,
			"dependencies": entry.dependencies
		}
	
	# Serialize pools (just their configuration, not contents)
	var pools_data: Dictionary = {}
	for name in _resource_pools:
		var pool = _resource_pools[name]
		pools_data[name] = {
			"resource_scene_path": pool.resource_scene.resource_path if pool.resource_scene else "",
			"max_size": pool.max_size,
			"auto_expand": pool.auto_expand,
			"active_count": pool.active_resources.size(),
			"available_count": pool.available_resources.size()
		}
	
	return {
		"resources": _resources.duplicate(),
		"limits": _resource_limits.duplicate(),
		"history": history,
		"market_state": _market.market_state,
		"market_tables": market_tables,
		"last_update_time": _market.last_update_time,
		"resource_pools": pools_data,
		"version": 2 # Incremented for new format
	}

## Deserialize resource system state from a dictionary
## @param data: Dictionary containing resource system data
func deserialize(data: Dictionary) -> void:
	# Handle different versions
	var version = data.get("version", 1)
	
	# Common data for all versions
	if data.has("resources"):
		_resources = data["resources"].duplicate()
	if data.has("limits"):
		_resource_limits = data["limits"].duplicate()
	if data.has("history"):
		_transaction_history.clear()
		for t_data in data["history"]:
			_transaction_history.append(ResourceTransaction.deserialize(t_data))
	if data.has("market_state"):
		_market.market_state = float(data["market_state"])
	if data.has("last_update_time"):
		_market.last_update_time = int(data["last_update_time"])
	if data.has("market_tables"):
		_market.resource_tables.clear()
		for type_str in data["market_tables"]:
			var type := int(type_str)
			var table_data := data["market_tables"][type_str] as Dictionary
			setup_resource_table(
				type,
				int(table_data["base_value"]),
				int(table_data["min_value"]),
				int(table_data["max_value"]),
				float(table_data["rarity"]),
				float(table_data["market_volatility"]),
				table_data["dependencies"] as Array[int]
			)
	
	# Version 2+ specific data
	if version >= 2 and data.has("resource_pools"):
		# Recreate pools
		clear_resource_pools()
		for pool_name in data["resource_pools"]:
			var pool_data = data["resource_pools"][pool_name]
			if not pool_data["resource_scene_path"].is_empty():
				var scene = load(pool_data["resource_scene_path"]) as PackedScene
				if scene:
					create_resource_pool(
						pool_name,
						scene,
						1, # Start with minimal size
						pool_data["max_size"],
						pool_data["auto_expand"]
					)

## Set up a resource table entry
## @param type: Resource type for the table
## @param base_value: Base value for the resource
## @param min_value: Minimum possible value
## @param max_value: Maximum possible value (-1 for no limit)
## @param rarity: Rarity factor (0.0 to 1.0)
## @param volatility: Market volatility factor (0.0 to 1.0)
## @param dependencies: Resource types that affect this one
func setup_resource_table(type: int, base_value: int, min_value: int = 0, max_value: int = -1,
						 rarity: float = 0.5, volatility: float = 0.0, dependencies: Array[int] = []) -> void:
	var entry := ResourceTableEntry.new(type, base_value, min_value, max_value, rarity, volatility, dependencies)
	_market.add_resource_table(entry)

## Get the market value for a resource type
## @param type: Resource type to check
## @return: Current market value
func get_market_value(type: int) -> int:
	return _market.get_resource_value(type, _resources)

## Update all market-based resources
## Updates the market state and adjusts resource amounts
func update_market_resources() -> void:
	_market.update_market_state()
	for type: int in _market.resource_tables:
		var new_value := _market.get_resource_value(type, _resources)
		if new_value != get_resource_amount(type):
			add_resource(type, new_value - get_resource_amount(type), "market_update")