class_name EconomyManager
extends Node

enum ItemType { WEAPON, ARMOR, GEAR, SHIP_COMPONENT }

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

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
		if can_afford(price):
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
	if is_buying:
		base_price = int(base_price * 1.2)  # 20% markup when buying
	else:
		base_price = int(base_price * 0.8)  # 20% markdown when selling
	
	# Apply any world traits that affect pricing
	for trait in game_state.current_location.traits:
		match trait.name:
			"Free trade zone":
				base_price = int(base_price * 0.9)
			"Corporate state":
				base_price = int(base_price * 1.1)
	
	return base_price

func generate_market_items() -> Array[Equipment]:
	var market_items: Array[Equipment] = []
	var num_items: int = randi() % 6 + 5  # 5-10 items
	
	for i in range(num_items):
		var item: Equipment = generate_random_item()
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
	assert(false, "Unexpected item type")
	return null

func generate_random_weapon() -> Weapon:
	# TODO: Implement weapon generation logic
	return Weapon.new("Random Weapon", Weapon.WeaponType.LOW_TECH, 10, 1, 1)

func generate_random_armor() -> Armor:
	# TODO: Implement armor generation logic
	return Armor.new("Random Armor", 5)

func generate_random_gear() -> Gear:
	# TODO: Implement gear generation logic
	return Gear.new("Random Gear", "This is a random piece of gear", "Utility")

func generate_random_ship_component() -> ShipComponent:
	# TODO: Implement ship component generation logic
	return ShipComponent.new("Random Ship Component", "This is a random ship component", 10, 1)

func calculate_upkeep_cost() -> int:
	var base_cost: int = game_state.current_crew.members.size() * 5
	
	# Apply any relevant traits or modifiers
	for trait in game_state.current_location.traits:
		if trait.name == "High cost":
			base_cost = int(base_cost * 1.5)
	
	return base_cost

func pay_upkeep() -> bool:
	var cost: int = calculate_upkeep_cost()
	return remove_credits(cost)

func apply_economic_event() -> void:
	var events: Array[String] = [
		"Market Crash",
		"Economic Boom",
		"Trade Embargo",
		"Resource Shortage",
		"Technological Breakthrough"
	]
	var event: String = events[randi() % events.size()]
	
	match event:
		"Market Crash":
			game_state.credits = int(game_state.credits * 0.8)
		"Economic Boom":
			game_state.credits = int(game_state.credits * 1.2)
		"Trade Embargo":
			# TODO: Implement trade restrictions
			pass
		"Resource Shortage":
			# TODO: Increase prices of certain items
			pass
		"Technological Breakthrough":
			# TODO: Make certain items available or cheaper
			pass
