enum ItemType { WEAPON, ARMOR, GEAR, SHIP_COMPONENT }
enum GlobalEvent { MARKET_CRASH, ECONOMIC_BOOM, TRADE_EMBARGO, RESOURCE_SHORTAGE, TECHNOLOGICAL_BREAKTHROUGH }

signal global_event_triggered(event: GlobalEvent)
signal economy_updated

var game_state: GameState
var location_price_modifiers: Dictionary = {}
var global_economic_modifier: float = 1.0
var trade_restricted_items: Array[String] = []
var scarce_resources: Array[String] = []
var new_tech_items: Array[String] = []

const BASE_ITEM_MARKUP: float = 1.2
const BASE_ITEM_MARKDOWN: float = 0.8
const GLOBAL_EVENT_CHANCE: float = 0.1
const ECONOMY_NORMALIZATION_RATE: float = 0.1

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	initialize_location_price_modifiers()

func initialize_location_price_modifiers() -> void:
	for location in game_state.get_all_locations():
		location_price_modifiers[location.name] = randf_range(0.8, 1.2)

func add_credits(amount: int) -> void:
	game_state.credits += amount

func remove_credits(amount: int) -> bool:
	if game_state.credits >= amount:
		game_state.credits -= amount
		return true
	return false

func can_afford(amount: int) -> bool:
	return game_state.credits >= amount

func trade_item(item: Equipment, is_buying: bool) -> bool:
	var price: int = calculate_item_price(item, is_buying)
	if is_buying:
		if can_afford(price) and not item.name in trade_restricted_items:
			remove_credits(price)
			game_state.current_crew.equipment.append(item)
			return true
	else:
		add_credits(price)
		game_state.current_crew.equipment.erase(item)
		return true
	return false

func calculate_item_price(item: Equipment, is_buying: bool) -> int:
	var base_price: int = item.value
	var location_modifier = location_price_modifiers.get(game_state.current_location.name, 1.0)
	
	if is_buying:
		base_price = int(base_price * BASE_ITEM_MARKUP * location_modifier * global_economic_modifier)
	else:
		base_price = int(base_price * BASE_ITEM_MARKDOWN * location_modifier * global_economic_modifier)
	
	if item.name in scarce_resources:
		base_price = int(base_price * 1.5)
	elif item.name in new_tech_items:
		base_price = int(base_price * 0.8)
	
	return base_price

func generate_market_items() -> Array[Equipment]:
	var market_items: Array[Equipment] = []
	var num_items: int = randi() % 6 + 5  # 5-10 items
	
	for i in range(num_items):
		var item: Equipment = generate_random_item()
		if not item.name in trade_restricted_items:
			market_items.append(item)
	
	return market_items

func generate_random_item() -> Equipment:
	var item_type: ItemType = ItemType.values()[randi() % ItemType.size()]
	
	match item_type:
		ItemType.WEAPON:
			return generate_random_weapon()
		ItemType.ARMOR:
			return generate_random_armor()
		ItemType.GEAR:
			return generate_random_gear()
		ItemType.SHIP_COMPONENT:
			return generate_random_ship_component()
	
	# This should never happen, but we need to return something to satisfy the type system
	push_error("Unexpected item type")
	return Equipment.new()

func generate_random_weapon() -> Weapon:
	var weapon_types = ["Pistol", "Rifle", "Shotgun", "Heavy Weapon"]
	var weapon_name = weapon_types[randi() % weapon_types.size()]
	var damage = randi() % 5 + 1
	var range = randi() % 10 + 1
	return Weapon.new(weapon_name, Weapon.WeaponType.MILITARY, range, 1, damage)

func generate_random_armor() -> Armor:
	var armor_types = ["Light Armor", "Medium Armor", "Heavy Armor"]
	var armor_name = armor_types[randi() % armor_types.size()]
	var defense = randi() % 5 + 1
	return Armor.new(armor_name, defense)

func generate_random_gear() -> Gear:
	var gear_types = ["Medkit", "Repair Kit", "Stealth Field", "Jetpack"]
	var gear_name = gear_types[randi() % gear_types.size()]
	return Gear.new(gear_name, "A useful piece of equipment", "Utility")

func generate_random_ship_component() -> ShipComponent:
	var component_types = ["Engine Booster", "Shield Generator", "Weapon System", "Life Support"]
	var component_name = component_types[randi() % component_types.size()]
	var power_usage = randi() % 10 + 1
	var health = randi() % 50 + 50
	return ShipComponent.new(component_name, "A crucial ship component", power_usage, health)

func calculate_upkeep_cost() -> int:
	var base_cost: int = game_state.current_crew.members.size() * 5

	# Ensure the current location is valid and traits can be retrieved
	if game_state.current_location != null:
		var location_traits = game_state.current_location.get_traits()
		
		# Check if location_traits is a valid list or array
		if location_traits and typeof(location_traits) == TYPE_ARRAY and location_traits.size() > 0:
			for trait in location_traits:
				if trait == "High cost":  # Adjusting cost based on "High cost" trait
					base_cost = int(base_cost * 1.5)

	return base_cost



func pay_upkeep() -> bool:
	var cost: int = calculate_upkeep_cost()
	return remove_credits(cost)



func trigger_global_event() -> void:
	var event = GlobalEvent.values()[randi() % GlobalEvent.size()]
	match event:
		GlobalEvent.MARKET_CRASH:
			global_economic_modifier = 0.8
			print("A market crash has occurred! Prices are generally lower.")
		GlobalEvent.ECONOMIC_BOOM:
			global_economic_modifier = 1.2
			print("An economic boom is happening! Prices are generally higher.")
		GlobalEvent.TRADE_EMBARGO:
			trade_restricted_items = ["Weapon", "Armor", "Ship Component"]
			print("A trade embargo has been imposed. Weapons, armor, and ship components are unavailable.")
		GlobalEvent.RESOURCE_SHORTAGE:
			scarce_resources = ["Fuel", "Medical Supplies", "Food"]
			print("A resource shortage is affecting the market. Fuel, medical supplies, and food are more expensive.")
		GlobalEvent.TECHNOLOGICAL_BREAKTHROUGH:
			new_tech_items = ["Advanced AI", "Quantum Computer", "Nanotech Fabricator"]
			print("A technological breakthrough has occurred. Advanced AI, Quantum Computers, and Nanotech Fabricators are now available.")
	
	global_event_triggered.emit(event)

func update_global_economy() -> void:
	if randf() < GLOBAL_EVENT_CHANCE:
		trigger_global_event()
	else:
		# Gradually return the economy to normal if no event occurs
		global_economic_modifier = lerp(global_economic_modifier, 1.0, ECONOMY_NORMALIZATION_RATE)
		trade_restricted_items.clear()
		scarce_resources.clear()
		new_tech_items.clear()
	
	# Update location-specific modifiers
	for location in location_price_modifiers.keys():
		location_price_modifiers[location] = lerp(location_price_modifiers[location], 1.0, ECONOMY_NORMALIZATION_RATE)
	
	economy_updated.emit()

func apply_economic_event() -> void:
	update_global_economy()
	var events = [
		"Market Crash",
		"Economic Boom",
		"Trade Embargo",
		"Resource Shortage",
		"Technological Breakthrough"
	]
	var event = events[randi() % events.size()]
	
	match event:
		"Market Crash":
			game_state.credits = int(game_state.credits * 0.8)
		"Economic Boom":
			game_state.credits = int(game_state.credits * 1.2)
		"Trade Embargo", "Resource Shortage", "Technological Breakthrough":
			pass  # Logic for these events is handled in trigger_global_event
	
	print("Economic event occurred: " + event)
