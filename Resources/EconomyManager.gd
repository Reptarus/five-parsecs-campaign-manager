class_name EconomyManager
extends Node

signal global_event_triggered(event: GlobalEnums.GlobalEvent)
signal economy_updated

@export var economic_range: Vector2 = Vector2(0, 100)

var game_state_manager: GameStateManagerNode
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

func _init() -> void:
	game_state_manager = get_node("/root/GameState")
	if not game_state_manager:
		push_error("GameStateManagerNode not found. Make sure it's properly set up as an AutoLoad.")
		return
	
	game_state = game_state_manager.get_game_state()
	if not game_state:
		push_error("GameState not found in GameStateManagerNode.")
		return
	
	initialize_location_price_modifiers()

func initialize_location_price_modifiers() -> void:
	for location in game_state.get_all_locations():
		location_price_modifiers[location.name] = randf_range(0.8, 1.2)

func add_credits(amount: int) -> void:
	game_state.current_crew.add_credits(amount)

func remove_credits(amount: int) -> bool:
	return game_state.current_crew.remove_credits(amount)

func can_afford(amount: int) -> bool:
	return game_state.current_crew.credits >= amount

func trade_item(item: Equipment, is_buying: bool) -> bool:
	var price: int = calculate_item_price(item, is_buying)
	if is_buying:
		if can_afford(price) and not item.name in trade_restricted_items:
			if remove_credits(price):
				game_state.current_crew.inventory.add_item(item)
				return true
	else:
		if game_state.current_crew.inventory.remove_item(item):
			add_credits(price)
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
	var item_type: GlobalEnums.ItemType = GlobalEnums.ItemType.values()[randi() % GlobalEnums.ItemType.size()]
	
	match item_type:
		GlobalEnums.ItemType.WEAPON:
			return generate_random_weapon()
		GlobalEnums.ItemType.ARMOR:
			return generate_random_armor()
		GlobalEnums.ItemType.GEAR:
			return generate_random_gear()
		GlobalEnums.ItemType.CONSUMABLE:
			return generate_random_consumable()
		_:
			push_error("Unexpected item type")
			return Equipment.new("Generic Item", GlobalEnums.ItemType.GEAR, 0)

func generate_random_weapon() -> Weapon:
	var weapon_types = GlobalEnums.WeaponType.values()
	var weapon_type = weapon_types[randi() % weapon_types.size()]
	var weapon_name = "Generic " + GlobalEnums.WeaponType.keys()[weapon_type]
	var damage = randi() % 5 + 1
	var weapon_range = randi() % 10 + 1
	return Weapon.new(weapon_name, weapon_type, weapon_range, 1, damage)

func generate_random_armor() -> Equipment:
	var armor_types = GlobalEnums.ArmorType.values()
	var armor_type = armor_types[randi() % armor_types.size()]
	var armor_name = "Generic " + GlobalEnums.ArmorType.keys()[armor_type]
	var defense = randi() % 5 + 1
	return Equipment.new(armor_name, GlobalEnums.ItemType.ARMOR, defense)

func generate_random_gear() -> Equipment:
	var gear_types = ["Medkit", "Repair Kit", "Stealth Field", "Jetpack"]
	var gear_name = gear_types[randi() % gear_types.size()]
	var gear_type = Gear.GearType[gear_name.to_upper()]
	return Gear.new(gear_name, "A useful piece of equipment", gear_type, 1)

func generate_random_consumable() -> Equipment:
	var consumable_types = ["Stim Pack", "Grenade", "Repair Nanites", "Energy Cell"]
	var consumable_name = consumable_types[randi() % consumable_types.size()]
	return Equipment.new(consumable_name, GlobalEnums.ItemType.CONSUMABLE, 1)

func calculate_upkeep_cost() -> int:
	var base_cost: int = game_state.current_crew.members.size() * 5
	if game_state.current_location != null:
		var location_traits = game_state.current_location.get_traits()
		
		if location_traits is Array and not location_traits.is_empty():
			if GlobalEnums.WorldTrait.RICH in location_traits:
				base_cost = int(base_cost * 1.5)
			elif GlobalEnums.WorldTrait.POOR in location_traits:
				base_cost = int(base_cost * 0.8)
	
	return base_cost

func pay_upkeep() -> bool:
	var cost: int = calculate_upkeep_cost()
	return remove_credits(cost)

func trigger_global_event() -> void:
	var event = GlobalEnums.GlobalEvent.values()[randi() % GlobalEnums.GlobalEvent.size()]
	match event:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			global_economic_modifier = 0.8
			print("A market crash has occurred! Prices are generally lower.")
		GlobalEnums.GlobalEvent.ECONOMIC_BOOM:
			global_economic_modifier = 1.2
			print("An economic boom is happening! Prices are generally higher.")
		GlobalEnums.GlobalEvent.TRADE_EMBARGO:
			trade_restricted_items = ["Weapon", "Armor", "Ship Component"]
			print("A trade embargo has been imposed. Weapons, armor, and ship components are unavailable.")
		GlobalEnums.GlobalEvent.RESOURCE_SHORTAGE:
			scarce_resources = ["Fuel", "Medical Supplies", "Food"]
			print("A resource shortage is affecting the market. Fuel, medical supplies, and food are more expensive.")
		GlobalEnums.GlobalEvent.TECHNOLOGICAL_BREAKTHROUGH:
			new_tech_items = ["Advanced AI", "Quantum Computer", "Nanotech Fabricator"]
			print("A technological breakthrough has occurred. Advanced AI, Quantum Computers, and Nanotech Fabricators are now available.")
	
	global_event_triggered.emit(event)

func update_global_economy() -> void:
	if randf() < GLOBAL_EVENT_CHANCE:
		trigger_global_event()
	else:
		global_economic_modifier = lerp(global_economic_modifier, 1.0, ECONOMY_NORMALIZATION_RATE)
		trade_restricted_items.clear()
		scarce_resources.clear()
		new_tech_items.clear()
	
	for location_name in location_price_modifiers.keys():
		location_price_modifiers[location_name] = lerp(location_price_modifiers[location_name], 1.0, ECONOMY_NORMALIZATION_RATE)
	
	economy_updated.emit()

func apply_economic_event() -> void:
	update_global_economy()
	var event = GlobalEnums.GlobalEvent.values()[randi() % GlobalEnums.GlobalEvent.size()]
	
	match event:
		GlobalEnums.GlobalEvent.MARKET_CRASH:
			remove_credits(int(game_state.current_crew.credits * 0.2))
		GlobalEnums.GlobalEvent.ECONOMIC_BOOM:
			add_credits(int(game_state.current_crew.credits * 0.2))
		_:
			pass  # Logic for other events is handled in trigger_global_event
	
	print("Economic event occurred: " + GlobalEnums.GlobalEvent.keys()[event])
