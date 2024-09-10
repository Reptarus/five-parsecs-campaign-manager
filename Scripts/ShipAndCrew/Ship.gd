class_name Ship
extends Resource

signal component_damaged(component: ShipComponent)
signal component_repaired(component: ShipComponent)
signal power_changed(available_power: int)

@export var name: String
@export var components: Array[ShipComponent] = []
@export var crew: Array[Character] = []
@export var inventory: ShipInventory
@export var total_power: int
@export var available_power: int

func _init():
	inventory = ShipInventory.new()

func add_component(component: ShipComponent) -> void:
	components.append(component)
	available_power -= component.power_usage
	power_changed.emit(available_power)

func remove_component(component: ShipComponent) -> void:
	components.erase(component)
	available_power += component.power_usage
	power_changed.emit(available_power)

func get_component(type: ShipComponent.ComponentType) -> ShipComponent:
	return components.filter(func(c): return c.component_type == type).front()

func repair_component(component: ShipComponent, amount: int) -> void:
	component.repair(amount)
	component_repaired.emit(component)

func calculate_maintenance_cost(economy_manager: EconomyManager) -> int:
	var base_cost = components.reduce(func(acc, comp): return acc + comp.power_usage, 0)
	return int(base_cost * economy_manager.global_economic_modifier)

func serialize() -> Dictionary:
	return {
		"name": name,
		"components": components.map(func(c): return c.serialize()),
		"crew": crew.map(func(c): return c.serialize()),
		"inventory": inventory.serialize(),
		"total_power": total_power,
		"available_power": available_power
	}

static func deserialize(data: Dictionary) -> Ship:
	var ship = Ship.new()
	ship.name = data["name"]
	ship.components = data["components"].map(func(c): return ShipComponent.deserialize(c))
	ship.crew = data["crew"].map(func(c): return Character.deserialize(c))
	ship.inventory = ShipInventory.deserialize(data["inventory"])
	ship.total_power = data["total_power"]
	ship.available_power = data["available_power"]
	return ship

# Add these methods to the Ship class

func engage_in_combat(enemy_ship: Ship):
	# Placeholder for ship combat logic
	pass

func take_damage(amount: int):
	var hull = get_component(ShipComponent.ComponentType.HULL) as HullComponent
	if hull:
		hull.take_damage(amount)
		if hull.is_destroyed():
			# Handle ship destruction
			pass

func fire_weapons(target: Ship):
	var weapons = get_component(ShipComponent.ComponentType.WEAPONS) as WeaponsComponent
	if weapons:
		var damage = weapons.calculate_damage()
		target.take_damage(damage)
