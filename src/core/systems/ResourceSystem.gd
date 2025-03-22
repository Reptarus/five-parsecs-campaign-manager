@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/systems/ResourceSystem.gd")

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
signal resource_changed(resource_type: int, old_value: int, new_value: int, source: String)
signal resource_threshold_reached(resource_type: int, threshold: int, current_value: int)
signal resource_depleted(resource_type: int)
signal resource_added(type: int, amount: int, source: String)
signal resource_removed(type: int, amount: int, source: String)
signal transaction_recorded(transaction: Dictionary)
signal validation_failed(type: int, amount: int, reason: String)
## Advanced signals for async operations and pooling
signal resource_loaded(resource_path: String, resource: Resource)
signal resource_load_failed(resource_path: String, error: int)
signal pool_initialized(pool_name: String, size: int)
signal pool_resource_acquired(pool_name: String, resource: Resource)
signal pool_resource_released(pool_name: String, resource: Resource)

# Template for transaction dictionary
var transaction_template = {
	"resource_type": 0,
	"old_value": 0,
	"new_value": 0,
	"change_amount": 0,
	"source": "",
	"timestamp": 0,
	"transaction_type": ""
}

# Template for ResourceTableEntry dictionary
var resource_table_entry_template = {
	"type": 0,
	"base_value": 0,
	"min_value": 0,
	"max_value": - 1,
	"rarity": 0.5,
	"volatility": 0.0,
	"dependencies": []
}

# Template for ResourceValidationRule dictionary
var validation_rule_template = {
	"min_amount": 0,
	"max_amount": - 1,
	"allowed_sources": [],
	"disallowed_sources": [],
	"require_source": false,
	"allow_transactions": true
}

# Template for ResourcePool dictionary
var resource_pool_template = {
	"name": "",
	"resource_scene_path": "",
	"resources": [],
	"in_use": [],
	"max_size": 10,
	"auto_expand": true
}

# Template for ResourceMarket dictionary
var resource_market_template = {
	"market_state": 0.0,
	"last_update_time": 0,
	"update_interval": 3600,
	"resource_tables": {}
}

## Variables to track state
var resources: Dictionary = {}
var resource_thresholds: Dictionary = {}
var resource_cache: Dictionary = {}
var _validation_rules: Dictionary = {}
var _transaction_history: Array = []
var _resource_pools: Dictionary = {}

const MAX_HISTORY_SIZE: int = 100

var _market = resource_market_template.duplicate(true)

# Resource loading and pooling variables
var _loading_resources: Dictionary = {} # path -> loading_status
var _last_cache_cleanup: int = 0
const CACHE_CLEANUP_INTERVAL: int = 1800
const MAX_CACHE_SIZE: int = 50

func _init() -> void:
	# Initialize market system
	_market.market_state = randf_range(-1.0, 1.0)
	_market.last_update_time = Time.get_unix_time_from_system()

func _ready() -> void:
	# Schedule regular cache cleanup
	var cleanup_timer = Timer.new()
	add_child(cleanup_timer)
	cleanup_timer.wait_time = 300.0 # 5 minutes
	cleanup_timer.one_shot = false
	cleanup_timer.connect("timeout", _check_cache_cleanup)
	cleanup_timer.start()

## Register a new resource type in the system
## @param resource_type: Enum value for the resource type
## @param initial_amount: Starting amount
## @param threshold: Maximum amount (-1 for no limit)
func register_resource(resource_type: int, initial_amount: int = 0, threshold: int = -1) -> void:
	if has_resource(resource_type):
		return
		
	resources[resource_type] = initial_amount
	resource_thresholds[resource_type] = threshold
	
	# Create a validation rule dictionary
	var rule = validation_rule_template.duplicate(true)
	_validation_rules[resource_type] = rule

## Periodically check if cache cleanup is needed
func _check_cache_cleanup() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - _last_cache_cleanup > CACHE_CLEANUP_INTERVAL:
		cleanup_resource_cache()
		_last_cache_cleanup = current_time

## Validate if a transaction can be processed
## @param type: Resource type
## @param amount: Transaction amount
## @param source: Transaction source
## @return: Dictionary with validation result and reason
func validate_transaction(type: int, amount: int, source: String = "") -> Dictionary:
	if not has_resource(type):
		return {"valid": false, "reason": "Resource type not registered"}
		
	if amount <= 0:
		return {"valid": false, "reason": "Amount must be positive"}
		
	if not type in _validation_rules:
		return {"valid": true}
		
	var rule = _validation_rules[type]
	
	if not rule.get("allow_transactions", true):
		return {"valid": false, "reason": "Transactions not allowed for this resource"}
		
	if rule.get("require_source", false) and source.is_empty():
		return {"valid": false, "reason": "Source required for this resource"}
		
	var allowed_sources = rule.get("allowed_sources", [])
	if not allowed_sources.is_empty() and not source in allowed_sources:
		return {"valid": false, "reason": "Source not allowed: " + source}
		
	var disallowed_sources = rule.get("disallowed_sources", [])
	if not disallowed_sources.is_empty() and source in disallowed_sources:
		return {"valid": false, "reason": "Source disallowed: " + source}
		
	var current = get_resource(type)
	var min_amount = rule.get("min_amount", 0)
	var max_amount = rule.get("max_amount", -1)
	
	if amount < min_amount:
		return {"valid": false, "reason": "Amount below minimum: " + str(min_amount)}
		
	if max_amount >= 0 and amount > max_amount:
		return {"valid": false, "reason": "Amount above maximum: " + str(max_amount)}
		
	return {"valid": true}

## Record a resource transaction in history
## @param type: Resource type involved
## @param amount: Amount changed
## @param t_type: Transaction type (ADD/REMOVE)
## @param source: Source of the transaction
func record_transaction(type: int, amount: int, t_type: String, source: String) -> void:
	var transaction = transaction_template.duplicate(true)
	transaction.resource_type = type
	transaction.old_value = resources.get(type, 0)
	transaction.new_value = resources.get(type, 0) + amount
	transaction.change_amount = amount
	transaction.source = source
	transaction.timestamp = Time.get_unix_time_from_system()
	transaction.transaction_type = t_type
	
	_transaction_history.append(transaction)
	
	# Keep history size in check
	while _transaction_history.size() > MAX_HISTORY_SIZE:
		_transaction_history.pop_front()
	
	transaction_recorded.emit(transaction)

## Get transaction history for a specific resource type or all types
## @param type: Resource type to filter by, or -1 for all
## @return: Array of transaction dictionaries
func get_transaction_history(type: int = -1) -> Array:
	if type == -1:
		return _transaction_history.duplicate()
	
	var filtered_history = []
	for t in _transaction_history:
		if t.resource_type == type:
			filtered_history.append(t)
	
	return filtered_history

## Check if a resource type is tracked
## @param type: Resource type to check
## @return: Whether the resource exists
func has_resource(type: int) -> bool:
	return type in resources

## Get the current amount of a resource
## @param type: Resource type to check
## @return: Current amount of the resource
func get_resource(type: int) -> int:
	return resources.get(type, 0)

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
		
	var current := get_resource(type)
	var limit: int = resource_thresholds.get(type, -1)
	
	if limit >= 0:
		amount = mini(amount, limit - current)
		
	if amount > 0:
		resources[type] = current + amount
		record_transaction(type, amount, "ADD", source)
		resource_added.emit(type, amount, source)
		resource_changed.emit(type, current, resources[type], source)
		
		# Check if we reached a threshold
		if limit >= 0 and resources[type] >= limit:
			resource_threshold_reached.emit(type, limit, resources[type])

## Remove resources of a specific type
## @param type: Resource type to remove
## @param amount: Amount to remove
## @param source: Source of the removal
## @return: True if successful, false if insufficient resources
func remove_resource(type: int, amount: int, source: String = "system") -> bool:
	if amount <= 0:
		return true
	
	var current := get_resource(type)
	if current < amount:
		validation_failed.emit(type, amount, "Insufficient resources")
		return false
		
	resources[type] = current - amount
	record_transaction(type, amount, "REMOVE", source)
	resource_removed.emit(type, amount, source)
	resource_changed.emit(type, current, resources[type], source)
	
	if resources[type] <= 0:
		resource_depleted.emit(type)
		
	return true

## Set the validation rule for a resource type
## @param type: Resource type to set rules for
## @param min_amount: Minimum transaction amount
## @param max_amount: Maximum transaction amount
## @param allowed_sources: Sources allowed to modify this resource
## @param disallowed_sources: Sources not allowed to modify this resource
## @param require_source: Whether a source is required for transactions
## @param allow_transactions: Whether transactions are allowed at all
func set_validation_rule(type: int, min_amount: int = 0, max_amount: int = -1,
						 allowed_sources: Array = [], disallowed_sources: Array = [],
						 require_source: bool = false, allow_transactions: bool = true) -> void:
	if not has_resource(type):
		register_resource(type)
		
	var rule = validation_rule_template.duplicate(true)
	rule.min_amount = min_amount
	rule.max_amount = max_amount
	rule.allowed_sources = allowed_sources
	rule.disallowed_sources = disallowed_sources
	rule.require_source = require_source
	rule.allow_transactions = allow_transactions
	
	_validation_rules[type] = rule

## Set threshold for a resource type
## @param type: Resource type
## @param threshold: Maximum amount (-1 for no limit)
func set_resource_threshold(type: int, threshold: int) -> void:
	if not has_resource(type):
		register_resource(type, 0, threshold)
		return
		
	resource_thresholds[type] = threshold
	
	# Check if current amount exceeds new threshold
	var current := get_resource(type)
	if threshold >= 0 and current > threshold:
		resources[type] = threshold
		resource_changed.emit(type, current, threshold, "system")

## Clear a cached resource
## @param path: Path of the resource to clear
func clear_cached_resource(path: String) -> void:
	if path in resource_cache:
		resource_cache.erase(path)

## Cleanup the resource cache
func cleanup_resource_cache() -> void:
	var keys = resource_cache.keys()
	
	# If we're under the size limit, no need to clean
	if keys.size() <= MAX_CACHE_SIZE:
		return
		
	# Sort by last access time
	keys.sort_custom(func(a, b):
		return resource_cache[a].get("last_access", 0) < resource_cache[b].get("last_access", 0)
	)
	
	# Remove the oldest entries until we're under the limit
	var to_remove = keys.size() - MAX_CACHE_SIZE
	for i in range(to_remove):
		if i < keys.size():
			clear_cached_resource(keys[i])

## Create a resource pool
## @param pool_name: Name for the pool
## @param resource_scene: PackedScene to instantiate
## @param initial_size: Initial number of resources
## @param max_size: Maximum pool size
## @param auto_expand: Whether to auto-expand when empty
## @return: Whether pool was created successfully
func create_resource_pool(pool_name: String, resource_scene: PackedScene, initial_size: int = 5,
						max_size: int = 20, auto_expand: bool = true) -> bool:
	if pool_name in _resource_pools:
		return false
	
	var pool = resource_pool_template.duplicate(true)
	pool.name = pool_name
	pool.resource_scene_path = resource_scene.resource_path
	pool.max_size = max_size
	pool.auto_expand = auto_expand
	_resource_pools[pool_name] = pool
	
	pool_initialized.emit(pool_name, initial_size)
	
	# Pre-populate the pool
	for i in range(initial_size):
		if pool.resources.size() < max_size:
			var instance = resource_scene.instantiate()
			if instance:
				pool.resources.append(instance)
	
	return true

## Get a resource from a pool
## @param pool_name: Name of the pool
## @return: Resource or null if none available
func get_pool_resource(pool_name: String) -> Node:
	if not pool_name in _resource_pools:
		return null
	
	var pool = _resource_pools[pool_name]
	
	# Handle empty pool
	if pool.resources.is_empty():
		if not pool.auto_expand or pool.in_use.size() >= pool.max_size:
			return null
			
		# Create new resource
		var scene = load(pool.resource_scene_path) as PackedScene
		if not scene:
			return null
			
		var instance = scene.instantiate()
		if not instance:
			return null
			
		pool.in_use.append(instance)
		pool_resource_acquired.emit(pool_name, instance)
		return instance
	
	# Get existing resource
	var resource = pool.resources.pop_front()
	pool.in_use.append(resource)
	
	pool_resource_acquired.emit(pool_name, resource)
	return resource

## Return a resource to the pool
## @param pool_name: Name of the pool
## @param resource: Resource to return
## @return: Whether resource was returned to the pool
func release_pool_resource(pool_name: String, resource: Node) -> bool:
	if not pool_name in _resource_pools:
		return false
	
	var pool = _resource_pools[pool_name]
	
	var idx = pool.in_use.find(resource)
	if idx >= 0:
		pool.in_use.remove_at(idx)
		
		if pool.resources.size() < pool.max_size:
			pool.resources.append(resource)
			pool_resource_released.emit(pool_name, resource)
			return true
		else:
			# Pool is full, destroy the resource
			resource.queue_free()
			return true
	
	return false

## Clear all resources in a pool
## @param pool_name: Name of the pool
func clear_resource_pool(pool_name: String) -> void:
	if not pool_name in _resource_pools:
		return
	
	var pool = _resource_pools[pool_name]
	
	# Free in-use resources
	for resource in pool.in_use:
		if is_instance_valid(resource):
			resource.queue_free()
	
	# Free pooled resources
	for resource in pool.resources:
		if is_instance_valid(resource):
			resource.queue_free()
	
	pool.in_use.clear()
	pool.resources.clear()

## Clear all resource pools
func clear_resource_pools() -> void:
	for pool_name in _resource_pools.keys():
		clear_resource_pool(pool_name)
		_resource_pools.clear()

## Serialize resource system state to a dictionary
## @return: Dictionary with resource system data
func serialize() -> Dictionary:
	var data := {
		"version": 2,
		"resources": resources.duplicate(),
		"thresholds": resource_thresholds.duplicate(),
		"market_state": _market.market_state,
		"last_update_time": _market.last_update_time
	}
	
	# Serialize transaction history
	var history := []
	for t in _transaction_history:
		history.append(t.duplicate())
	data["history"] = history
	
	# Serialize market tables
	data["market_tables"] = {}
	for type in _market.resource_tables:
		var table = _market.resource_tables[type]
		data["market_tables"][str(type)] = {
			"base_value": table.base_value,
			"min_value": table.min_value,
			"max_value": table.max_value,
			"rarity": table.rarity,
			"market_volatility": table.volatility,
			"dependencies": table.dependencies
		}
	
	# Serialize resource pools
	data["resource_pools"] = {}
	for name in _resource_pools:
		var pool = _resource_pools[name]
		data["resource_pools"][name] = {
			"resource_scene_path": pool.resource_scene_path,
			"max_size": pool.max_size,
			"auto_expand": pool.auto_expand
		}
	
	return data

## Deserialize resource system state from a dictionary
## @param data: Dictionary containing resource system data
func deserialize(data: Dictionary) -> void:
	# Handle different versions
	var version = data.get("version", 1)
	
	# Common data for all versions
	if data.has("resources"):
		resources = data["resources"].duplicate()
	if data.has("thresholds"):
		resource_thresholds = data["thresholds"].duplicate()
	if data.has("history"):
		_transaction_history.clear()
		for t_data in data["history"]:
			_transaction_history.append(t_data)
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
				table_data["dependencies"] as Array
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
						 rarity: float = 0.5, volatility: float = 0.0, dependencies: Array = []) -> void:
	# Create a table entry dictionary
	var entry = resource_table_entry_template.duplicate(true)
	entry.type = type
	entry.base_value = base_value
	entry.min_value = min_value
	entry.max_value = max_value
	entry.rarity = rarity
	entry.volatility = volatility
	entry.dependencies = dependencies
	
	# Add to market tables
	_market.resource_tables[type] = entry

## Get the market value for a resource type
## @param type: Resource type to check
## @return: Current market value
func get_market_value(type: int) -> int:
	return _calculate_resource_value(type)

## Update market prices based on time elapsed
## @param force: Whether to force update regardless of time
func update_market_prices(force: bool = false) -> void:
	var current_time = Time.get_unix_time_from_system()
	if not force and current_time - _market.last_update_time < _market.update_interval:
		return
	
	# Generate new market state
	_market.market_state = clamp(_market.market_state + randf_range(-0.3, 0.3), -1.0, 1.0)
	_market.last_update_time = current_time
	
	# Recalculate all resource values
	for type in _market.resource_tables:
		_calculate_resource_value(type)

## Simulate market fluctuations over time
## @param days: Number of days to simulate
## @return: Dictionary mapping resource types to arrays of values
func simulate_market_trends(days: int) -> Dictionary:
	var trends := {}
	
	# Save current state
	var original_state = _market.market_state
	var original_time = _market.last_update_time
	
	# For each resource type
	for type in _market.resource_tables:
		trends[type] = []
		
		# Reset to current state
		_market.market_state = original_state
		_market.last_update_time = original_time
		
		# Simulate for each day
		for day in range(days):
			# Add random fluctuation
			_market.market_state = clamp(_market.market_state + randf_range(-0.1, 0.1), -1.0, 1.0)
			trends[type].append(_calculate_resource_value(type))
			
	# Restore original state
	_market.market_state = original_state
	_market.last_update_time = original_time
	
	return trends

## Get all resource types in the system
## @return: Array of resource type IDs
func get_resource_types() -> Array:
	return resources.keys()

## Get resources that match a filter predicate
## @param predicate: Function taking (type, amount) and returning bool
## @return: Dictionary of filtered resources
func filter_resources(predicate: Callable) -> Dictionary:
	var result := {}
	
	for type in resources:
		var amount = resources[type]
		if predicate.call(type, amount):
			result[type] = amount
			
	return result

## Get resources by threshold proximity
## @param percentage: How close to threshold (0.0 to 1.0)
## @return: Dictionary of resources meeting the criteria
func get_resources_by_threshold_proximity(percentage: float) -> Dictionary:
	var filtered := {}
	
	for type in resources:
		var threshold = resource_thresholds.get(type, -1)
		if threshold > 0:
			var ratio = float(resources[type]) / float(threshold)
			if ratio >= percentage:
				filtered[type] = resources[type]
				
	return filtered

## Helper function to calculate a resource's market value
## @param type: Resource type to calculate
## @return: Current market value
func _calculate_resource_value(type: int) -> int:
	if not type in _market.resource_tables:
		return 0
		
	var entry = _market.resource_tables[type]
	
	var value = entry.base_value
	
	# Apply market state with volatility factor
	value += int(entry.base_value * _market.market_state * entry.volatility)
	
	# Apply dependency effects
	for dep_type in entry.dependencies:
		if dep_type in resources:
			var dep_amount = resources[dep_type]
			var dep_effect = 0.05 * entry.volatility * dep_amount
			value += int(entry.base_value * dep_effect)
	
	# Apply rarity factor
	value += int(entry.base_value * entry.rarity * (1.0 - float(resources.get(type, 0)) / 100.0))
	
	# Clamp to min/max
	if entry.min_value >= 0:
		value = maxi(value, entry.min_value)
	if entry.max_value >= 0:
		value = mini(value, entry.max_value)
		
	return value