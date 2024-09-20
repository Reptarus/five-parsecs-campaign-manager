class_name WorldEconomyManager
extends Node

signal local_event_triggered(event_description: String)
signal economy_updated

var game_world: Location
var economy_manager: EconomyManager
var local_market: Array[Equipment] = []

const BASE_UPKEEP_COST: int = 10
const LOCAL_EVENT_CHANCE: float = 0.2
const ECONOMY_NORMALIZATION_RATE: float = 0.1
const MAX_MARKET_ITEMS: int = 20

func _init(_game_world: Location, _economy_manager: EconomyManager) -> void:
	game_world = _game_world
	economy_manager = _economy_manager
	_initialize_local_market()

func _initialize_local_market() -> void:
	local_market.clear()
	var num_items = randi_range(10, MAX_MARKET_ITEMS)
	for i in range(num_items):
		local_market.append(economy_manager.generate_random_equipment())

func calculate_upkeep() -> int:
	var upkeep = BASE_UPKEEP_COST
	if "High Cost" in game_world.traits:
		upkeep = int(upkeep * 1.5)
	if "Economic Depression" in game_world.traits:
		upkeep = int(upkeep * 1.2)
	if "Thriving Economy" in game_world.traits:
		upkeep = int(upkeep * 0.8)
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

func pay_upkeep(crew: Crew) -> bool:
	var upkeep_cost = calculate_upkeep()
	if crew.credits >= upkeep_cost:
		crew.remove_credits(upkeep_cost)
		return true
	return false

func get_item_price(item: Equipment) -> int:
	var base_price = economy_manager.calculate_item_price(item, true)
	var modifier = economy_manager.location_price_modifiers.get(game_world.name, 1.0)
	return int(base_price * modifier)

func buy_item(crew: Crew, item: Equipment) -> bool:
	var price = get_item_price(item)
	if crew.credits >= price and local_market.has(item):
		crew.remove_credits(price)
		crew.add_equipment(item)
		local_market.erase(item)
		return true
	return false

func sell_item(crew: Crew, item: Equipment) -> bool:
	var sell_price = int(get_item_price(item) * 0.7)  # 70% of buy price
	if crew.remove_equipment(item):
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
	new_resource.value *= 0.5  # The new resource is cheaper due to abundance
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
	var remove_count = randi_range(0, 3)
	for i in range(min(remove_count, local_market.size())):
		local_market.pop_at(randi() % local_market.size())
	
	# Add some new items
	var add_count = randi_range(0, 3)
	for i in range(add_count):
		if local_market.size() < MAX_MARKET_ITEMS:
			local_market.append(economy_manager.generate_random_equipment())
