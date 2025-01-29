extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal resource_changed(type: int, amount: int)
signal resource_depleted(type: int)
signal resource_added(type: int, amount: int, source: String)
signal resource_removed(type: int, amount: int, source: String)
signal transaction_recorded(transaction: ResourceTransaction)
signal validation_failed(type: int, amount: int, reason: String)

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

var _resources: Dictionary = {}
var _resource_limits: Dictionary = {}
var _transaction_history: Array[ResourceTransaction] = []
var _validation_rules: Dictionary = {}
const MAX_HISTORY_SIZE: int = 100

var _market: ResourceMarket = ResourceMarket.new()

func _init() -> void:
	_initialize_resources()

func _initialize_resources() -> void:
	for type: int in GameEnums.ResourceType.values():
		_resources[type] = 0
		_resource_limits[type] = -1 # -1 means no limit
		_validation_rules[type] = ResourceValidationRule.new()

func add_validation_rule(type: int, rule: ResourceValidationRule) -> void:
	_validation_rules[type] = rule

func validate_transaction(type: int, amount: int, source: String) -> Dictionary:
	if not _validation_rules.has(type):
		return {"valid": true, "reason": ""}
	return _validation_rules[type].validate_transaction(_resources.get(type, 0), amount, source)

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

func get_transaction_history(type: int = -1) -> Array[ResourceTransaction]:
	if type == -1:
		return _transaction_history.duplicate()
	return _transaction_history.filter(func(t): return t.type == type)

func has_resource(type: int) -> bool:
	return _resources.has(type)

func get_resource_amount(type: int) -> int:
	return _resources.get(type, 0)

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

func remove_resource(type: int, amount: int, source: String = "system") -> bool:
	if amount <= 0:
		return true
	
	# Validate transaction
	var validation := validate_transaction(type, -amount, source)
	if not validation["valid"]:
		validation_failed.emit(type, -amount, validation["reason"])
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

func set_resource_limit(type: int, limit: int) -> void:
	_resource_limits[type] = limit
	if limit >= 0:
		var current := get_resource_amount(type)
		if current > limit:
			remove_resource(type, current - limit, "limit_adjustment")

func get_resource_limit(type: int) -> int:
	return _resource_limits.get(type, -1)

func clear_resources() -> void:
	for type: int in _resources.keys():
		if _resources[type] > 0:
			record_transaction(type, _resources[type], "REMOVE", "clear")
		_resources[type] = 0
		resource_changed.emit(type, 0)
		resource_depleted.emit(type)

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
	
	return {
		"resources": _resources.duplicate(),
		"limits": _resource_limits.duplicate(),
		"history": history,
		"market_state": _market.market_state,
		"market_tables": market_tables,
		"last_update_time": _market.last_update_time
	}

func deserialize(data: Dictionary) -> void:
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

func setup_resource_table(type: int, base_value: int, min_value: int = 0, max_value: int = -1,
						 rarity: float = 0.5, volatility: float = 0.0, dependencies: Array[int] = []) -> void:
	var entry := ResourceTableEntry.new(type, base_value, min_value, max_value, rarity, volatility, dependencies)
	_market.add_resource_table(entry)

func get_market_value(type: int) -> int:
	return _market.get_resource_value(type, _resources)

func update_market_resources() -> void:
	_market.update_market_state()
	for type: int in _market.resource_tables:
		var new_value := _market.get_resource_value(type, _resources)
		if new_value != get_resource_amount(type):
			add_resource(type, new_value - get_resource_amount(type), "market_update")
