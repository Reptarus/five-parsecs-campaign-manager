extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

signal global_event_triggered(event: GameEnums.GlobalEvent)
signal economy_updated
signal market_updated(prices: Dictionary)
signal trade_completed
signal transaction_failed(reason: String)

const BASE_ITEM_MARKUP: float = 1.2
const BASE_ITEM_MARKDOWN: float = 0.8
const GLOBAL_EVENT_CHANCE: float = 0.1
const ECONOMY_NORMALIZATION_RATE: float = 0.1
const MAX_PRICE_FLUCTUATION: float = 0.3
const MIN_PRICE_MULTIPLIER: float = 0.5
const MAX_PRICE_MULTIPLIER: float = 2.0

var location_price_modifiers: Dictionary = {} # location_name: float
var global_economic_modifier: float = 1.0
var trade_restricted_items: Array[String] = []
var scarce_resources: Array[GameEnums.ItemType] = []
var new_tech_items: Array[GameEnums.ItemType] = []
var current_market_state: GameEnums.MarketState = GameEnums.MarketState.NORMAL
var market_prices: Dictionary = {}
var supply_demand: Dictionary = {}

func _init() -> void:
	randomize()
	_initialize_market()

func _initialize_market() -> void:
	market_prices.clear()
	supply_demand.clear()
	
	# Initialize base prices for all item types
	for item_type in GameEnums.ItemType.values():
		if item_type == GameEnums.ItemType.NONE:
			continue
		market_prices[item_type] = 1.0
		supply_demand[item_type] = {
			"supply": randf_range(0.5, 1.5),
			"demand": randf_range(0.5, 1.5)
		}

func update_market() -> void:
	_update_market_state()
	_update_supply_demand()
	_update_prices()
	_check_for_global_events()
	market_updated.emit(market_prices)

func _update_market_state() -> void:
	var state_change_roll := randf()
	
	match current_market_state:
		GameEnums.MarketState.NORMAL:
			if state_change_roll < 0.1:
				current_market_state = GameEnums.MarketState.BOOM if randf() < 0.6 else GameEnums.MarketState.RESTRICTED
		GameEnums.MarketState.BOOM:
			if state_change_roll < 0.2:
				current_market_state = GameEnums.MarketState.NORMAL
			elif state_change_roll < 0.25:
				current_market_state = GameEnums.MarketState.CRISIS
		GameEnums.MarketState.RESTRICTED:
			if state_change_roll < 0.15:
				current_market_state = GameEnums.MarketState.NORMAL
			elif state_change_roll < 0.2:
				current_market_state = GameEnums.MarketState.CRISIS
		GameEnums.MarketState.CRISIS:
			if state_change_roll < 0.1:
				current_market_state = GameEnums.MarketState.NORMAL

func _update_supply_demand() -> void:
	for item_type in supply_demand.keys():
		var data: Dictionary = supply_demand[item_type]
		
		# Natural supply/demand fluctuation
		data.supply += randf_range(-0.1, 0.1)
		data.demand += randf_range(-0.1, 0.1)
		
		# Clamp values
		data.supply = clampf(data.supply, 0.1, 2.0)
		data.demand = clampf(data.demand, 0.1, 2.0)
		
		# Apply market state effects
		match current_market_state:
			GameEnums.MarketState.BOOM:
				data.demand *= 1.2
			GameEnums.MarketState.RESTRICTED:
				data.demand *= 0.8
			GameEnums.MarketState.CRISIS:
				data.supply *= 0.7
				data.demand *= 0.6

func _update_prices() -> void:
	for item_type in market_prices.keys():
		var base_modifier := 1.0
		
		# Apply supply/demand effects
		var supply_demand_ratio: Dictionary = supply_demand[item_type]
		base_modifier *= supply_demand_ratio.demand / supply_demand_ratio.supply
		
		# Apply market state effects
		match current_market_state:
			GameEnums.MarketState.BOOM:
				base_modifier *= 1.3
			GameEnums.MarketState.RESTRICTED:
				base_modifier *= 0.7
			GameEnums.MarketState.CRISIS:
				base_modifier *= 0.5
		
		# Apply random fluctuation
		base_modifier *= (1.0 + randf_range(-MAX_PRICE_FLUCTUATION, MAX_PRICE_FLUCTUATION))
		
		# Apply global modifier
		base_modifier *= global_economic_modifier
		
		# Clamp final modifier
		base_modifier = clampf(base_modifier, MIN_PRICE_MULTIPLIER, MAX_PRICE_MULTIPLIER)
		
		# Update price
		market_prices[item_type] = base_modifier

func calculate_item_price(item: Resource, is_buying: bool) -> int:
	if not item:
		return 0
		
	var base_price: int = item.value
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var location_name = ""
	
	if game_state_manager and game_state_manager.game_state and game_state_manager.game_state.current_location:
		location_name = game_state_manager.game_state.current_location.name
	
	var location_modifier: float = location_price_modifiers.get(location_name, 1.0)
	var market_modifier: float = market_prices.get(item.type, 1.0)
	
	# Calculate markup/markdown
	if is_buying:
		return int(base_price * BASE_ITEM_MARKUP * location_modifier * market_modifier)
	else:
		return int(base_price * BASE_ITEM_MARKDOWN * location_modifier * market_modifier)

func can_trade_item(item: Resource) -> bool:
	if not item:
		return false
		
	if item.name in trade_restricted_items:
		return false
		
	if item.type in scarce_resources and current_market_state == GameEnums.MarketState.CRISIS:
		return false
		
	return true

func process_transaction(item: Resource, is_buying: bool, quantity: int = 1) -> bool:
	if not can_trade_item(item):
		transaction_failed.emit("This item cannot be traded at this time")
		return false
		
	var price := calculate_item_price(item, is_buying) * quantity
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not game_state_manager or not game_state_manager.game_state:
		transaction_failed.emit("Cannot access game state")
		return false
	
	var game_state = game_state_manager.game_state
	
	if is_buying:
		if game_state.credits < price:
			transaction_failed.emit("Insufficient credits")
			return false
			
		game_state.spend_credits(price)
		game_state.add_item(item, quantity)
	else:
		if not game_state.has_item(item, quantity):
			transaction_failed.emit("Insufficient items")
			return false
			
		game_state.remove_item(item, quantity)
		game_state.add_credits(price)
	
	# Update supply/demand
	var sd_data: Dictionary = supply_demand[item.type]
	if is_buying:
		sd_data.supply = maxf(0.1, sd_data.supply - 0.1 * quantity)
		sd_data.demand = minf(2.0, sd_data.demand + 0.05 * quantity)
	else:
		sd_data.supply = minf(2.0, sd_data.supply + 0.1 * quantity)
		sd_data.demand = maxf(0.1, sd_data.demand - 0.05 * quantity)
	
	trade_completed.emit()
	return true

func _check_for_global_events() -> void:
	if randf() < GLOBAL_EVENT_CHANCE:
		var event := _generate_global_event()
		_apply_global_event(event)
		global_event_triggered.emit(event)

func _generate_global_event() -> GameEnums.GlobalEvent:
	var events := GameEnums.GlobalEvent.values()
	return events[randi() % events.size()]

func _apply_global_event(event: GameEnums.GlobalEvent) -> void:
	match event:
		GameEnums.GlobalEvent.TRADE_DISRUPTION:
			global_economic_modifier *= 0.8
		GameEnums.GlobalEvent.ECONOMIC_BOOM:
			global_economic_modifier *= 1.2
		GameEnums.GlobalEvent.RESOURCE_SHORTAGE:
			var resource_types := GameEnums.ItemType.values()
			var new_resource: GameEnums.ItemType = resource_types[randi() % resource_types.size()]
			if new_resource != GameEnums.ItemType.NONE and not new_resource in scarce_resources:
				scarce_resources.append(new_resource)
		GameEnums.GlobalEvent.NEW_TECHNOLOGY:
			var tech_items := GameEnums.ItemType.values()
			var new_tech: GameEnums.ItemType = tech_items[randi() % tech_items.size()]
			if new_tech != GameEnums.ItemType.NONE and not new_tech in new_tech_items:
				new_tech_items.append(new_tech)
	
	# Normalize global modifier over time
	global_economic_modifier = lerpf(global_economic_modifier, 1.0, ECONOMY_NORMALIZATION_RATE)
