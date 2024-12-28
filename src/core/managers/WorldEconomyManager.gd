extends Node

signal local_event_triggered(event_description: String)
signal economy_updated

var game_world: Location
var economy_manager: EconomyManager
var local_market: Array[Equipment] = []

const BASE_UPKEEP_COST: int = 100
const LOCAL_EVENT_CHANCE: float = 0.2
const ECONOMY_NORMALIZATION_RATE: float = 0.1
const MAX_MARKET_ITEMS: int = 20
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Location = preload("res://src/core/world/Location.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const WorldManager = preload("res://src/core/world/WorldManager.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

func _init(_game_world: Location, _economy_manager: EconomyManager) -> void:
	game_world = _game_world
	economy_manager = _economy_manager
	_initialize_local_market()

func _initialize_local_market() -> void:
	local_market.clear()
	for i in range(MAX_MARKET_ITEMS):
		var item = economy_manager.generate_random_equipment()
		if item:
			local_market.append(item)

func calculate_upkeep() -> int:
	var upkeep = BASE_UPKEEP_COST
	
	# Apply world trait modifiers
	if GlobalEnums.WorldTrait.INDUSTRIAL_HUB in game_world.traits:
		upkeep = int(upkeep * 1.5) # Higher costs in industrial hubs
	if GlobalEnums.WorldTrait.FRONTIER_WORLD in game_world.traits:
		upkeep = int(upkeep * 0.8) # Lower costs in frontier worlds
	if GlobalEnums.WorldTrait.TRADE_CENTER in game_world.traits:
		upkeep = int(upkeep * 1.2) # Moderate increase in trade centers
	
	return upkeep

func trigger_local_event() -> void:
	var events = [
		_market_flourish,
		_market_struggle,
		_new_trade_route,
		_trade_route_disruption,
		_local_festival,
		_resource_discovery,
		_economic_scandal
	]
	var event = events[randi() % events.size()]
	event.call()

func update_local_economy() -> void:
	if randf() < LOCAL_EVENT_CHANCE:
		trigger_local_event()
	else:
		_normalize_economy()
	_update_market_items()
	economy_updated.emit()

func pay_upkeep(crew: CrewSystem) -> bool:
	var upkeep_cost = calculate_upkeep()
	if crew.credits >= upkeep_cost:
		crew.remove_credits(upkeep_cost)
		return true
	return false

func get_item_price(item: Equipment) -> int:
	var base_price = economy_manager.calculate_item_price(item, true)
	var modifier = economy_manager.location_price_modifiers.get(game_world.name, 1.0)
	
	# Apply world trait price modifiers
	if GlobalEnums.WorldTrait.TRADE_CENTER in game_world.traits:
		modifier *= 0.9 # Better prices in trade centers
	if GlobalEnums.WorldTrait.PIRATE_HAVEN in game_world.traits:
		modifier *= 1.2 # Higher prices in pirate havens
	if GlobalEnums.WorldTrait.FREE_PORT in game_world.traits:
		modifier *= 0.85 # Best prices in free ports
	if GlobalEnums.WorldTrait.CORPORATE_CONTROLLED in game_world.traits:
		modifier *= 1.15 # Higher prices in corporate worlds
	
	return int(base_price * modifier)

func buy_item(crew: CrewSystem, item: Equipment) -> bool:
	var price = get_item_price(item)
	if crew.credits >= price and local_market.has(item):
		crew.remove_credits(price)
		crew.add_equipment(item)
		local_market.erase(item)
		return true
	return false

func sell_item(crew: CrewSystem, item: Equipment) -> bool:
	var sell_price = int(get_item_price(item) * 0.7) # 70% of buy price
	if crew.has_equipment(item):
		crew.remove_equipment(item)
		crew.add_credits(sell_price)
		if local_market.size() < MAX_MARKET_ITEMS:
			local_market.append(item)
		return true
	return false

func _market_flourish() -> void:
	economy_manager.location_price_modifiers[game_world.name] *= 0.9
	local_event_triggered.emit("Local market flourish: Temporary decrease in prices")

func _market_struggle() -> void:
	economy_manager.location_price_modifiers[game_world.name] *= 1.1
	local_event_triggered.emit("Local market struggle: Temporary increase in prices")

func _new_trade_route() -> void:
	for i in range(5):
		if local_market.size() < MAX_MARKET_ITEMS:
			local_market.append(economy_manager.generate_random_equipment())
	local_event_triggered.emit("New trade route established: More items available")

func _trade_route_disruption() -> void:
	var remove_count = min(5, local_market.size())
	for i in range(remove_count):
		local_market.pop_back()
	local_event_triggered.emit("Trade route disrupted: Fewer items available")

func _local_festival() -> void:
	var festival_items = ["Food", "Drink", "Entertainment", "Decorations"]
	for item in local_market:
		if item.name in festival_items:
			economy_manager.location_price_modifiers[game_world.name] *= 1.2
	local_event_triggered.emit("Local festival: Increased demand for certain items")

func _resource_discovery() -> void:
	var new_resource = economy_manager.generate_random_equipment()
	new_resource.value *= 0.5 # The new resource is cheaper due to abundance
	local_market.append(new_resource)
	local_event_triggered.emit("Resource discovery: New cheap resource available")

func _economic_scandal() -> void:
	economy_manager.location_price_modifiers[game_world.name] *= 1.15
	local_event_triggered.emit("Economic scandal: General increase in prices")

func _normalize_economy() -> void:
	economy_manager.location_price_modifiers[game_world.name] = lerp(
		economy_manager.location_price_modifiers[game_world.name],
		1.0,
		ECONOMY_NORMALIZATION_RATE
	)

func _update_market_items() -> void:
	# Remove some items
	var remove_count = randi() % 4
	for i in range(min(remove_count, local_market.size())):
		local_market.pop_at(randi() % local_market.size())
	
	# Add some new items
	var add_count = randi() % 4
	for i in range(add_count):
		if local_market.size() < MAX_MARKET_ITEMS:
			local_market.append(economy_manager.generate_random_equipment())
