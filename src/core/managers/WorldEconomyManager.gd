@tool
extends Node

signal local_event_triggered(event_description: String)
signal economy_updated

const BASE_UPKEEP_COST: int = 100
const LOCAL_EVENT_CHANCE: float = 0.2
const ECONOMY_NORMALIZATION_RATE: float = 0.1
const MAX_MARKET_ITEMS: int = 20

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const FiveParsecsLocation = preload("res://src/core/world/Location.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const WorldManager = preload("res://src/core/world/WorldManager.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const Equipment = preload("res://src/core/character/Equipment/Equipment.gd")
const CrewSystem = preload("res://src/core/campaign/crew/CrewSystem.gd")

var game_world: FiveParsecsLocation
var economy_manager: EconomyManager
var local_market: Array[Equipment] = []

func _init(_game_world: FiveParsecsLocation, _economy_manager: EconomyManager) -> void:
	game_world = _game_world
	economy_manager = _economy_manager
	_initialize_local_market()

func _initialize_local_market() -> void:
	local_market.clear()
	for i in range(MAX_MARKET_ITEMS):
		var item: Equipment = economy_manager.generate_random_equipment()
		if item:
			local_market.append(item)

## Calculates the upkeep cost based on world traits
## Returns: The total upkeep cost
func calculate_upkeep() -> int:
	var upkeep: int = BASE_UPKEEP_COST
	
	# Apply world trait modifiers
	if GameEnums.WorldTrait.INDUSTRIAL_HUB in game_world.traits:
		upkeep = int(upkeep * 1.5) # Higher costs in industrial hubs
	if GameEnums.WorldTrait.FRONTIER_WORLD in game_world.traits:
		upkeep = int(upkeep * 0.8) # Lower costs in frontier worlds
	if GameEnums.WorldTrait.TRADE_CENTER in game_world.traits:
		upkeep = int(upkeep * 1.2) # Moderate increase in trade centers
	
	return upkeep

## Triggers a random local economic event
func trigger_local_event() -> void:
	var events: Array[Callable] = [
		_market_flourish,
		_market_struggle,
		_new_trade_route,
		_trade_route_disruption,
		_local_festival,
		_resource_discovery,
		_economic_scandal
	]
	var event: Callable = events[randi() % events.size()]
	event.call()

## Updates the local economy state
func update_local_economy() -> void:
	if randf() < LOCAL_EVENT_CHANCE:
		trigger_local_event()
	else:
		_normalize_economy()
	_update_market_items()
	economy_updated.emit()

## Attempts to pay upkeep costs for the crew
## Parameters:
## - crew: The crew system to pay from
## Returns: Whether the payment was successful
func pay_upkeep(crew: CrewSystem) -> bool:
	var upkeep_cost: int = calculate_upkeep()
	if crew.credits >= upkeep_cost:
		crew.remove_credits(upkeep_cost)
		return true
	return false

## Calculates the price of an item in the local market
## Parameters:
## - item: The item to price
## Returns: The final price of the item
func get_item_price(item: Equipment) -> int:
	var base_price: int = economy_manager.calculate_item_price(item, true)
	var modifier: float = economy_manager.location_price_modifiers.get(game_world.name, 1.0)
	
	# Apply world trait price modifiers
	if GameEnums.WorldTrait.TRADE_CENTER in game_world.traits:
		modifier *= 0.9 # Better prices in trade centers
	if GameEnums.WorldTrait.PIRATE_HAVEN in game_world.traits:
		modifier *= 1.2 # Higher prices in pirate havens
	if GameEnums.WorldTrait.FREE_PORT in game_world.traits:
		modifier *= 0.85 # Best prices in free ports
	if GameEnums.WorldTrait.CORPORATE_CONTROLLED in game_world.traits:
		modifier *= 1.15 # Higher prices in corporate worlds
	
	return int(base_price * modifier)

## Attempts to buy an item from the local market
## Parameters:
## - crew: The crew system buying the item
## - item: The item to buy
## Returns: Whether the purchase was successful
func buy_item(crew: CrewSystem, item: Equipment) -> bool:
	var price: int = get_item_price(item)
	if crew.credits >= price and local_market.has(item):
		crew.remove_credits(price)
		crew.add_equipment(item)
		local_market.erase(item)
		return true
	return false

## Attempts to sell an item to the local market
## Parameters:
## - crew: The crew system selling the item
## - item: The item to sell
## Returns: Whether the sale was successful
func sell_item(crew: CrewSystem, item: Equipment) -> bool:
	var sell_price: int = int(get_item_price(item) * 0.7) # 70% of buy price
	if crew.has_equipment(item):
		crew.remove_equipment(item)
		crew.add_credits(sell_price)
		if local_market.size() < MAX_MARKET_ITEMS:
			local_market.append(item)
		return true
	return false

## Event: Market flourish - temporarily decreases prices
func _market_flourish() -> void:
	economy_manager.location_price_modifiers[game_world.name] *= 0.9
	local_event_triggered.emit("Local market flourish: Temporary decrease in prices")

## Event: Market struggle - temporarily increases prices
func _market_struggle() -> void:
	economy_manager.location_price_modifiers[game_world.name] *= 1.1
	local_event_triggered.emit("Local market struggle: Temporary increase in prices")

## Event: New trade route - adds more items to the market
func _new_trade_route() -> void:
	for i in range(5):
		if local_market.size() < MAX_MARKET_ITEMS:
			var item: Equipment = economy_manager.generate_random_equipment()
			if item:
				local_market.append(item)
	local_event_triggered.emit("New trade route established: More items available")

## Event: Trade route disruption - removes items from the market
func _trade_route_disruption() -> void:
	var remove_count: int = min(5, local_market.size())
	for i in range(remove_count):
		local_market.pop_back()
	local_event_triggered.emit("Trade route disrupted: Fewer items available")

## Event: Local festival - increases prices of certain items
func _local_festival() -> void:
	var festival_items: Array[String] = ["Food", "Drink", "Entertainment", "Decorations"]
	for item in local_market:
		if item.name in festival_items:
			economy_manager.location_price_modifiers[game_world.name] *= 1.2
	local_event_triggered.emit("Local festival: Increased demand for certain items")

## Event: Resource discovery - adds a new cheap resource
func _resource_discovery() -> void:
	var new_resource: Equipment = economy_manager.generate_random_equipment()
	if new_resource:
		new_resource.value *= 0.5 # The new resource is cheaper due to abundance
		local_market.append(new_resource)
		local_event_triggered.emit("Resource discovery: New cheap resource available")

## Event: Economic scandal - increases all prices
func _economic_scandal() -> void:
	economy_manager.location_price_modifiers[game_world.name] *= 1.15
	local_event_triggered.emit("Economic scandal: General increase in prices")

## Normalizes the local economy over time
func _normalize_economy() -> void:
	economy_manager.location_price_modifiers[game_world.name] = lerpf(
		economy_manager.location_price_modifiers[game_world.name],
		1.0,
		ECONOMY_NORMALIZATION_RATE
	)

## Updates the items available in the local market
func _update_market_items() -> void:
	# Remove some items
	var remove_count: int = randi() % 4
	for i in range(min(remove_count, local_market.size())):
		local_market.pop_at(randi() % local_market.size())
	
	# Add some new items
	var add_count: int = randi() % 4
	for i in range(add_count):
		if local_market.size() < MAX_MARKET_ITEMS:
			var item: Equipment = economy_manager.generate_random_equipment()
			if item:
				local_market.append(item)
