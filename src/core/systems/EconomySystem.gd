@warning_ignore("return_value_discarded")
# UNSAFE_METHOD_ACCESS and UNTYPED_DECLARATION warnings fixed with type safety patterns
class_name EconomySystem
extends Node

## Consolidated Economy System for Five Parsecs Campaign Manager
##
## Unified system combining:
	## - ResourceManager: Resource tracking, history, and analytics
## - EconomyManager: Market pricing, supply/demand, trading
## - WorldEconomyManager: Planetary economies, trade routes
##
## Implements IGameSystem interface for standardized integration

# Safe imports
const IGameSystem = preload("res://src/core/systems/IGameSystem.gd")

# Proper dependency imports - compile-time validation
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

# Remove these runtime variables
# # GlobalEnums available as autoload singleton
# # ValidationManager accessed as autoload when needed

# Resource Management Signals
signal resource_changed(resource_type: int, old_value: int, new_value: int, source: String)
signal resource_threshold_reached(resource_type: int, threshold: int, current_value: int)
signal resource_depleted(resource_type: int)
signal resource_history_updated(resource_type: int, history_entry: Dictionary)

# Market Management Signals
signal market_updated(prices: Dictionary)
signal trade_completed(item: String, is_buying: bool, quantity: int, price: int)
signal transaction_failed(reason: String)
signal global_event_triggered(event: int)

# World Economy Signals
signal economy_updated(planet: String, new_status: int)
signal trade_route_established(from_planet: String, to_planet: String)
signal market_fluctuation(planet: String, resource_type: int, change: float)

# System state
var _initialized: bool = false
var _game_state: Node = null # Type-safe managed by system
var _errors: Array[String] = []
var _last_update: int = 0

# Resource Management Data with strong typing
var resources: Dictionary = {} # resource_type:int -> amount:int
var resource_history: Dictionary = {} # resource_type:int -> Array[ResourceTransaction]
var resource_thresholds: Dictionary = {} # resource_type:int -> Dictionary[threshold:String -> value:int]

# Market Management Data with strong typing
var market_prices: Dictionary = {} # item_type:String -> price_multiplier:float
var supply_demand: Dictionary = {} # item_type:String -> {supply:float, demand:float}
var global_economic_modifier: float = 1.0
var current_market_state: int = 0
var trade_restricted_items: Array[String] = []
var scarce_resources: Array[String] = []

# World Economy Data
var planetary_economies: Dictionary = {} # planet_name -> EconomyStatus
var trade_routes: Array[Dictionary] = []
var market_conditions: Dictionary = {} # planet_name -> conditions

# Configuration constants
const MAX_HISTORY_ENTRIES = 100
const HISTORY_PRUNE_THRESHOLD = 120
const BASE_ITEM_MARKUP: float = 1.2
const BASE_ITEM_MARKDOWN: float = 0.8
const GLOBAL_EVENT_CHANCE: float = 0.1
const MAX_PRICE_FLUCTUATION: float = 0.3
const MIN_PRICE_MULTIPLIER: float = 0.5
const MAX_PRICE_MULTIPLIER: float = 2.0

# Enums
enum EconomyStatus {
	DEPRESSION,
	RECESSION,
	STABLE,
	GROWTH,
	BOOM
}

# Resource transaction class
class ResourceTransaction:
	var resource_type: int
	var old_value: int
	var new_value: int
	var change_amount: int
	var source: String
	var timestamp: int
	var turn_number: int

	func _init(p_type: int, p_old: int, p_new: int, p_source: String, p_turn: int) -> void:
		resource_type = p_type
		old_value = p_old
		new_value = p_new
		change_amount = p_new - p_old
		source = p_source
		timestamp = Time.get_unix_time_from_system()
		turn_number = p_turn

func _init() -> void:
	name = "EconomySystem"

# =====================================================
# IGameSystem Interface Implementation
# =====================================================

func initialize() -> bool:
	"""Initialize the economy system with all dependencies"""
	if _initialized:
		return true

	_errors.clear()

	# Dependencies are now compile-time validated via preload
	print("EconomySystem: Initializing with verified dependencies...")

	# Try to get game state through GameStateManager
	if GameStateManager and GameStateManager.has_method("get_game_state"):
		_game_state = GameStateManager.get_game_state()
	elif GameStateManager:
		_game_state = GameStateManager

	# Initialize subsystems
	_initialize_resources()
	_initialize_market()
	_initialize_world_economies()

	_initialized = _errors.is_empty()
	_last_update = Time.get_unix_time_from_system()

	if _initialized:
		print("EconomySystem: Successfully initialized")
	else:
		push_error("EconomySystem: Failed to initialize - errors: " + str(_errors))

	return _initialized

func get_data() -> Dictionary:
	"""Get all economy system data in serializable format"""
	return {
		"resources": resources.duplicate(),
		"resource_history": _serialize_resource_history(),
		"resource_thresholds": resource_thresholds.duplicate(),
		"market_prices": market_prices.duplicate(),
		"supply_demand": supply_demand.duplicate(),
		"global_economic_modifier": global_economic_modifier,
		"current_market_state": current_market_state,
		"trade_restricted_items": trade_restricted_items.duplicate(),
		"scarce_resources": scarce_resources.duplicate(),
		"planetary_economies": planetary_economies.duplicate(),
		"trade_routes": trade_routes.duplicate(),
		"market_conditions": market_conditions.duplicate(),
		"last_update": _last_update
	}

func update_data(data: Dictionary) -> bool:
	"""Update system state with provided data"""
	if not _initialized:
		_errors.append("System not initialized")
		return false

	# Update resource data with type safety
	if data.has("resources") and data["resources"] is Dictionary:
		var resource_data: Dictionary = data["resources"] as Dictionary
		resources = resource_data.duplicate()

	if data.has("resource_thresholds") and data["resource_thresholds"] is Dictionary:
		var threshold_data: Dictionary = data["resource_thresholds"] as Dictionary
		resource_thresholds = threshold_data.duplicate()

	if data.has("resource_history") and data["resource_history"] is Dictionary:
		var history_data: Dictionary = data["resource_history"] as Dictionary
		_deserialize_resource_history(history_data)

	# Update market data with type safety
	if data.has("market_prices") and data["market_prices"] is Dictionary:
		var price_data: Dictionary = data["market_prices"] as Dictionary
		market_prices = price_data.duplicate()

	if data.has("supply_demand") and data["supply_demand"] is Dictionary:
		var demand_data: Dictionary = data["supply_demand"] as Dictionary
		supply_demand = demand_data.duplicate()

	if data.has("global_economic_modifier") and data["global_economic_modifier"] is float:
		global_economic_modifier = data["global_economic_modifier"] as float

	if data.has("current_market_state") and data["current_market_state"] is int:
		current_market_state = data["current_market_state"] as int

	if data.has("trade_restricted_items") and data["trade_restricted_items"] is Array:
		var restricted_data: Array = data["trade_restricted_items"] as Array
		trade_restricted_items = []
		for item in restricted_data:
			if item is String:
				trade_restricted_items.append(item as String)

	if data.has("scarce_resources") and data["scarce_resources"] is Array:
		var scarce_data: Array = data["scarce_resources"] as Array
		scarce_resources = scarce_data.duplicate()

	# Update world economy data with type safety
	if data.has("planetary_economies") and data["planetary_economies"] is Dictionary:
		var economy_data: Dictionary = data["planetary_economies"] as Dictionary
		planetary_economies = economy_data.duplicate()

	if data.has("trade_routes") and data["trade_routes"] is Array:
		var routes_data: Array = data["trade_routes"] as Array
		trade_routes = []
		for route in routes_data:
			if route is Dictionary:
				trade_routes.append(route as Dictionary)

	if data.has("market_conditions") and data["market_conditions"] is Dictionary:
		var conditions_data: Dictionary = data["market_conditions"] as Dictionary
		market_conditions = conditions_data.duplicate()

	_last_update = Time.get_unix_time_from_system()
	return true

func cleanup() -> void:
	"""Clean up system resources and connections"""
	resources.clear()
	resource_history.clear()
	resource_thresholds.clear()
	market_prices.clear()
	supply_demand.clear()
	planetary_economies.clear()
	trade_routes.clear()
	market_conditions.clear()
	trade_restricted_items.clear()
	scarce_resources.clear()
	_errors.clear()
	_initialized = false

func get_status() -> Dictionary:
	"""Get system status information"""
	return {
		"initialized": _initialized,
		"active": _initialized,
		"errors": _errors.duplicate(),
		"last_update": _last_update,
		"resource_count": (safe_call_method(resources, "size") as int),
		"market_state": current_market_state,
		"planet_count": (safe_call_method(planetary_economies, "size") as int),
		"trade_route_count": (safe_call_method(trade_routes, "size") as int),
		"global_economic_modifier": global_economic_modifier
	}

func validate_state() -> Dictionary:
	"""Validate system state integrity with type safety"""
	var result: Dictionary = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Validate resource consistency with type safety
	for resource_type_variant: Variant in resources.keys():
		if not resource_type_variant is int:
			result["errors"].append("Invalid resource type: " + str(resource_type_variant))
			continue
			
		var resource_type: int = resource_type_variant as int
		var resource_value = resources[resource_type]
		
		if not resource_value is int:
			result["errors"].append("Invalid resource value type for " + str(resource_type))
			continue
			
		var value: int = resource_value as int
		if value < 0:
			result["warnings"].append("Resource " + str(resource_type) + " has negative value")

	# Validate market prices with type safety
	for item_type_variant: Variant in market_prices.keys():
		if not item_type_variant is String:
			result["errors"].append("Invalid market item type: " + str(item_type_variant))
			continue
			
		var item_type: String = item_type_variant as String
		var price_value = market_prices[item_type]
		
		if not price_value is float:
			result["errors"].append("Invalid price type for " + item_type)
			continue
			
		var price: float = price_value as float
		if price < MIN_PRICE_MULTIPLIER or price > MAX_PRICE_MULTIPLIER:
			result["warnings"].append("Price for " + item_type + " outside normal range")

	# Validate planetary economies
	for planet in planetary_economies.keys():
		var status = planetary_economies[planet]
		if not status in range(EconomyStatus.DEPRESSION, EconomyStatus.BOOM + 1):
			result.errors.append("Invalid economy status for " + planet)
			result.valid = false

	return result

# =====================================================
# RESOURCE MANAGEMENT (formerly ResourceManager)
# =====================================================

func set_resource(resource_type: int, value: int, source: String = "system") -> void:
	"""Set resource to specific value with history tracking"""
	if not GlobalEnums or not "ResourceType" in GlobalEnums:
		_errors.append("Cannot set resource - GlobalEnums.ResourceType not available")
		return

	if not resource_type in GlobalEnums.ResourceType.values():
		_errors.append("Invalid resource type: " + str(resource_type))
		return

	var old_value = resources.get(resource_type) if resources.has(resource_type) else 0
	resources[resource_type] = value

	_add_history_entry(resource_type, old_value, value, source)
	_check_thresholds(resource_type, value)

	resource_changed.emit(resource_type, old_value, value, source)

	if value <= 0:
		resource_depleted.emit(resource_type)

func modify_resource(resource_type: int, amount: int, source: String = "system") -> void:
	"""Modify resource by amount"""
	var current_value = get_resource(resource_type)
	set_resource(resource_type, current_value + amount, source)

func get_resource(resource_type: int) -> int:
	"""Get current resource amount"""
	return resources.get(resource_type) if resources.has(resource_type) else 0

func has_resource(resource_type: int) -> bool:
	"""Check if resource type exists"""
	return resource_type in resources

func set_resource_threshold(resource_type: int, threshold: int, value: int) -> void:
	"""Set resource threshold for alerts"""
	if not resource_type in resource_thresholds:
		resource_thresholds[resource_type] = {}

	resource_thresholds[resource_type][threshold] = value

func get_resource_analytics(resource_type: int) -> Dictionary:
	"""Get detailed resource analytics"""
	if not resource_type in resource_history:
		return {}

	var history = resource_history[resource_type]
	if history.is_empty():
		return {}

	var total_changes := 0
	var positive_changes := 0
	var negative_changes := 0
	var largest_gain := 0
	var largest_loss := 0

	for entry in history:
		var change = entry.change_amount
		total_changes += change

		if change > 0:
			positive_changes += change
			largest_gain = maxi(largest_gain, change)
		elif change < 0:
			negative_changes += change
			largest_loss = mini(largest_loss, change)

	return {
		"total_changes": total_changes,
		"positive_changes": positive_changes,
		"negative_changes": negative_changes,
		"largest_gain": largest_gain,
		"largest_loss": largest_loss,
		"average_change": float(total_changes) / history.size()
	}

# =====================================================
# MARKET MANAGEMENT (formerly EconomyManager)
# =====================================================

func update_market() -> void:
	"""Update market conditions and prices"""
	_update_market_state()
	_update_supply_demand()
	_update_prices()
	_check_for_global_events()
	market_updated.emit(market_prices)

func calculate_item_price(item: Resource, is_buying: bool, planet_name: String = "") -> int:
	"""Calculate item price with all modifiers"""
	if not item:
		push_error("Item is required for price calculation")
		return 0

	var base_price: int = safe_get_property(item, "value") if item.has("value") else 100
	var item_type = safe_get_property(item, "type") if item.has("type") else 0

	# Apply market modifier
	var market_modifier: float = market_prices.get(item_type) if market_prices.has(item_type) else 1.0

	# Apply planetary economy modifier
	var location_modifier: float = 1.0
	if planet_name != "":
		location_modifier = get_trade_modifier(planet_name)

	# Apply markup/markdown
	if is_buying:
		base_price = int(base_price * BASE_ITEM_MARKUP * location_modifier * market_modifier * global_economic_modifier)
	else:
		base_price = int(base_price * BASE_ITEM_MARKDOWN * location_modifier * market_modifier * global_economic_modifier)

	return max(1, base_price)

func can_trade_item(item: Resource) -> bool:
	"""Check if item can be traded"""
	if not item:
		return false

	var item_name = safe_get_property(item, "name") if item.has("name") else ""
	if item_name in trade_restricted_items:
		return false

	var item_type = safe_get_property(item, "type") if item.has("type") else 0
	if item_type in scarce_resources and current_market_state == GlobalEnums.MarketState.CRISIS:
		return false

	return true

func process_transaction(item: Resource, is_buying: bool, quantity: int = 1, planet_name: String = "") -> bool:
	"""Process a trade transaction"""
	if not can_trade_item(item):
		transaction_failed.emit("This item cannot be traded at this time")
		return false

	var price := calculate_item_price(item, is_buying, planet_name) * quantity
	var item_type = safe_get_property(item, "type") if item.has("type") else 0
	var item_name = safe_get_property(item, "name") if item.has("name") else "Unknown Item"

	# Update supply/demand
	if item_type in supply_demand:
		var sd_data: Dictionary = supply_demand[item_type]
		if is_buying:
			sd_data.supply = maxf(0.1, sd_data.supply - 0.1 * quantity)
			sd_data.demand = minf(2.0, sd_data.demand + 0.05 * quantity)
		else:
			sd_data.supply = minf(2.0, sd_data.supply + 0.1 * quantity)
			sd_data.demand = maxf(0.1, sd_data.demand - 0.05 * quantity)

	trade_completed.emit(item_name, is_buying, quantity, price)
	return true

# =====================================================
# WORLD ECONOMY MANAGEMENT (formerly WorldEconomyManager)
# =====================================================

func get_economy_status(planet_name: String) -> EconomyStatus:
	"""Get economy status for a planet"""
	return planetary_economies.get(planet_name) if planetary_economies.has(planet_name) else EconomyStatus.STABLE

func set_economy_status(planet_name: String, status: EconomyStatus) -> void:
	"""Set economy status for a planet"""
	planetary_economies[planet_name] = status
	economy_updated.emit(planet_name, status)

func update_economy(planet_name: String, change: int) -> void:
	"""Update economy based on events"""
	var current_status = get_economy_status(planet_name)
	var new_status = clamp(current_status + change, EconomyStatus.DEPRESSION, EconomyStatus.BOOM)
	set_economy_status(planet_name, new_status)

func get_trade_modifier(planet_name: String) -> float:
	"""Get trade modifier for economy status"""
	var status = get_economy_status(planet_name)
	match status:
		EconomyStatus.DEPRESSION: return 0.5
		EconomyStatus.RECESSION: return 0.75
		EconomyStatus.STABLE: return 1.0
		EconomyStatus.GROWTH: return 1.25
		EconomyStatus.BOOM: return 1.5
		_: return 1.0

func establish_trade_route(from_planet: String, to_planet: String) -> void:
	"""Establish trade route between planets"""
	var route = {
		"from": from_planet,
		"to": to_planet,
		"established": Time.get_unix_time_from_system()
	}
	trade_routes.append(route)
	trade_route_established.emit(from_planet, to_planet)

func has_trade_route(from_planet: String, to_planet: String) -> bool:
	"""Check if trade route exists"""
	for route in trade_routes:
		if (route.from == from_planet and route.to == to_planet) or \
		   (route.from == to_planet and route.to == from_planet):
			return true
	return false

func process_economic_fluctuations() -> void:
	"""Process random economic changes"""
	for planet in planetary_economies.keys():
		if randf() < 0.1: # 10% chance per cycle
			var change = randi_range(-1, 1)
			if change != 0:
				update_economy(planet, change)

# =====================================================
# PRIVATE HELPER METHODS
# =====================================================

func _initialize_resources() -> void:
	"""Initialize resource tracking"""
	if not GlobalEnums:
		_errors.append("Cannot initialize resources - GlobalEnums not available")
		return

	# Access enum values directly as they are static enums in the class
	for resource_type in GlobalEnums.ResourceType.values():
		resources[resource_type] = 0
		resource_thresholds[resource_type] = {}
		resource_history[resource_type] = []

func _initialize_market() -> void:
	"""Initialize market system"""
	if not GlobalEnums:
		_errors.append("Cannot initialize market - GlobalEnums not available")
		return

	# Set initial market state using proper enum access
	current_market_state = GlobalEnums.MarketState.NORMAL

	# Initialize market prices and supply/demand using ItemType enum
	for item_type in GlobalEnums.ItemType.values():
		if item_type == GlobalEnums.ItemType.NONE:
			continue
		market_prices[item_type] = 1.0
		supply_demand[item_type] = {
			"supply": randf_range(0.5, 1.5),
			"demand": randf_range(0.5, 1.5)
		}

func _initialize_world_economies() -> void:
	"""Initialize world economies with defaults"""
	planetary_economies = {
		"New Dublin": EconomyStatus.STABLE,
		"Fringe World Alpha": EconomyStatus.RECESSION,
		"Trade Hub Beta": EconomyStatus.GROWTH,
		"Industrial Gamma": EconomyStatus.STABLE,
		"Mining Colony Delta": EconomyStatus.STABLE,
		"Research Station Epsilon": EconomyStatus.GROWTH
	}

func _add_history_entry(resource_type: int, old_value: int, new_value: int, source: String) -> void:
	"""Add entry to resource history"""
	var turn_number = _get_current_turn()
	var entry = ResourceTransaction.new(resource_type, old_value, new_value, source, turn_number)

	if not resource_type in resource_history:
		resource_history[resource_type] = []

	resource_history[resource_type].append(entry)
	resource_history_updated.emit(resource_type, _create_history_entry_dict(entry))

	_prune_history_if_needed(resource_type)

func _prune_history_if_needed(resource_type: int) -> void:
	"""Prune resource history if too large"""
	if resource_type in resource_history:
		var history = resource_history[resource_type]
		if history.size() > HISTORY_PRUNE_THRESHOLD:
			history = history.slice(-MAX_HISTORY_ENTRIES)
			resource_history[resource_type] = history

func _check_thresholds(resource_type: int, value: int) -> void:
	"""Check resource thresholds and emit signals"""
	if not resource_type in resource_thresholds:
		return

	for threshold in resource_thresholds[resource_type]:
		if value <= threshold:
			resource_threshold_reached.emit(resource_type, threshold, value)

func _create_history_entry_dict(entry: ResourceTransaction) -> Dictionary:
	"""Convert ResourceTransaction to Dictionary"""
	return {
		"resource_type": entry.resource_type,
		"old_value": entry.old_value,
		"new_value": entry.new_value,
		"change_amount": entry.change_amount,
		"source": entry.source,
		"timestamp": entry.timestamp,
		"turn_number": safe_get_property(entry, "turn_number")
	}

func _serialize_resource_history() -> Dictionary:
	"""Serialize resource history for saving"""
	var serialized: Dictionary = {}
	for resource_type in resource_history.keys():
		serialized[resource_type] = []
		for entry in resource_history[resource_type]:
			serialized[resource_type].append(_create_history_entry_dict(entry))
	return serialized

func _deserialize_resource_history(data: Dictionary) -> void:
	"""Deserialize resource history from save data with type safety"""
	resource_history.clear()
	for resource_type_str: String in data.keys():
		if not resource_type_str is String:
			continue
			
		var resource_type: int = (resource_type_str as String).to_int()
		resource_history[resource_type] = []
		
		var entries_data = data[resource_type_str]
		if not entries_data is Array:
			continue
			
		var entries_array: Array = entries_data as Array
		for entry_variant in entries_array:
			if not entry_variant is Dictionary:
				continue
				
			var entry_dict: Dictionary = entry_variant as Dictionary
			
			# Type-safe property access
			var transaction_resource_type: int = entry_dict.get("resource_type", 0) as int
			var old_value: int = entry_dict.get("old_value", 0) as int
			var new_value: int = entry_dict.get("new_value", 0) as int
			var source: String = entry_dict.get("source", "") as String
			var turn_number: int = entry_dict.get("turn_number", 0) as int
			
			var entry := ResourceTransaction.new(
				transaction_resource_type,
				old_value,
				new_value,
				source,
				turn_number
			)
			resource_history[resource_type].append(entry)

func _update_market_state() -> void:
	"""Update overall market state"""
	if not GlobalEnums or not "MarketState" in GlobalEnums:
		return

	var state_change_roll := randf()

	match current_market_state:
		GlobalEnums.MarketState.NORMAL:
			if state_change_roll < 0.1:
				current_market_state = GlobalEnums.MarketState.BOOM if randf() < 0.6 else GlobalEnums.MarketState.RESTRICTED
		GlobalEnums.MarketState.BOOM:
			if state_change_roll < 0.2:
				current_market_state = GlobalEnums.MarketState.NORMAL
			elif state_change_roll < 0.25:
				current_market_state = GlobalEnums.MarketState.CRISIS
		GlobalEnums.MarketState.RESTRICTED:
			if state_change_roll < 0.15:
				current_market_state = GlobalEnums.MarketState.NORMAL
			elif state_change_roll < 0.2:
				current_market_state = GlobalEnums.MarketState.CRISIS
		GlobalEnums.MarketState.CRISIS:
			if state_change_roll < 0.1:
				current_market_state = GlobalEnums.MarketState.NORMAL

func _update_supply_demand() -> void:
	"""Update supply and demand for all items"""
	for item_type in supply_demand.keys():
		var data: Dictionary = supply_demand[item_type]

		# Natural fluctuation
		data.supply += randf_range(-0.1, 0.1)
		data.demand += randf_range(-0.1, 0.1)

		# Clamp values
		data.supply = clampf(data.supply, 0.1, 2.0)
		data.demand = clampf(data.demand, 0.1, 2.0)

		# Apply market state effects
		if GlobalEnums and "MarketState" in GlobalEnums:
			match current_market_state:
				GlobalEnums.MarketState.BOOM:
					data.demand *= 1.2
				GlobalEnums.MarketState.RESTRICTED:
					data.demand *= 0.8
				GlobalEnums.MarketState.CRISIS:
					data.supply *= 0.7
					data.demand *= 0.6

func _update_prices() -> void:
	"""Update market prices based on supply/demand"""
	for item_type in market_prices.keys():
		var base_modifier := 1.0

		# Apply supply/demand effects
		if item_type in supply_demand:
			var supply_demand_ratio: Dictionary = supply_demand[item_type]
			base_modifier *= supply_demand_ratio.demand / supply_demand_ratio.supply

		# Apply market state effects
		if GlobalEnums and "MarketState" in GlobalEnums:
			match current_market_state:
				GlobalEnums.MarketState.BOOM:
					base_modifier *= 1.3
				GlobalEnums.MarketState.RESTRICTED:
					base_modifier *= 0.7
				GlobalEnums.MarketState.CRISIS:
					base_modifier *= 0.5

		# Apply random fluctuation
		base_modifier *= (1.0 + randf_range(-MAX_PRICE_FLUCTUATION, MAX_PRICE_FLUCTUATION))

		# Apply global modifier
		base_modifier *= global_economic_modifier

		# Clamp final modifier
		base_modifier = clampf(base_modifier, MIN_PRICE_MULTIPLIER, MAX_PRICE_MULTIPLIER)

		market_prices[item_type] = base_modifier

func _check_for_global_events() -> void:
	"""Check for global economic events"""
	if randf() < GLOBAL_EVENT_CHANCE:
		var event_type = randi_range(1, 5)
		global_event_triggered.emit(event_type)
		_apply_global_event(event_type)

func _apply_global_event(event_type: int) -> void:
	"""Apply effects of global economic event"""
	match event_type:
		1: # Economic boom
			global_economic_modifier *= 1.2
		2: # Economic recession
			global_economic_modifier *= 0.8
		3: # Resource shortage
			scarce_resources = market_prices.keys().slice(0, 3)
		4: # Trade disruption
			trade_restricted_items.append("rare_materials")
		5: # Market stabilization
			global_economic_modifier = 1.0
			scarce_resources.clear()
			trade_restricted_items.clear()

func _get_current_turn() -> int:
	"""Get current campaign turn number"""
	if _game_state and _game_state and _game_state.has_method("get_current_turn"):
		return _game_state.get_current_turn()
	return 1

# Public API methods
func get_all_resources() -> Dictionary:
	"""Get all current resource amounts"""
	return resources.duplicate()

func get_market_state_name() -> String:
	"""Get human-readable market state name"""
	if not GlobalEnums or not "MarketState" in GlobalEnums:
		return "Unknown"

	match current_market_state:
		GlobalEnums.MarketState.NORMAL: return "Normal"
		GlobalEnums.MarketState.BOOM: return "Boom"
		GlobalEnums.MarketState.RESTRICTED: return "Restricted"
		GlobalEnums.MarketState.CRISIS: return "Crisis"
		_: return "Unknown"

func get_economy_status_name(status: EconomyStatus) -> String:
	"""Get human-readable economy status name"""
	match status:
		EconomyStatus.DEPRESSION: return "Depression"
		EconomyStatus.RECESSION: return "Recession"
		EconomyStatus.STABLE: return "Stable"
		EconomyStatus.GROWTH: return "Growth"
		EconomyStatus.BOOM: return "Boom"
		_: return "Unknown"

func get_all_planets() -> Array[String]:
	"""Get list of all known planets"""
	var planets: Array[String] = []
	for planet in planetary_economies.keys():
		planets.append(planet)
	return planets

func get_trade_routes_for_planet(planet_name: String) -> Array[Dictionary]:
	"""Get all trade routes connected to a planet"""
	var routes: Array[Dictionary] = []
	for route in trade_routes:
		if route.from == planet_name or route.to == planet_name:
			routes.append(route)
	return routes
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
