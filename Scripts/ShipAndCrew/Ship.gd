class_name Ship
extends Resource

signal component_damaged(component: ShipComponent)
signal component_repaired(component: ShipComponent)
signal power_changed(available_power: int)

@export var name: String
@export var components: Array[ShipComponent] = []
@export var crew: Array = []
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

func engage_in_combat(enemy_ship: Ship):
	var combat_result = {}
	var has_shuttle = self.components.any(func(c): return c.component_type == ShipComponent.ComponentType.SHUTTLE)
	var has_drop_launcher = self.components.any(func(c): return c.component_type == ShipComponent.ComponentType.DROP_PODS)
	
	for combat_round in range(3):
		var damage_dealt = self.fire_weapons(enemy_ship)
		var damage_received = enemy_ship.fire_weapons(self)
		
		combat_result["round_" + str(combat_round)] = {
			"damage_dealt": damage_dealt,
			"damage_received": damage_received
		}
		
		if self.is_destroyed() or enemy_ship.is_destroyed():
			break
	
	if has_shuttle:
		combat_result["escape_bonus"] = 2
	
	if has_drop_launcher and randf() <= 0.25:
		combat_result["boarding_opportunity"] = true
	
	return combat_result

func is_destroyed() -> bool:
	var hull = get_component(ShipComponent.ComponentType.HULL)
	return hull.health <= 0 if hull else true

func take_damage(amount: int):
	var hull = get_component(ShipComponent.ComponentType.HULL) as HullComponent
	if hull:
		hull.take_damage(amount)
		component_damaged.emit(hull)
		if hull.is_destroyed():
			# Handle ship destruction
			pass

func fire_weapons(target: Ship):
	var weapons = get_component(ShipComponent.ComponentType.WEAPONS) as WeaponsComponent
	if weapons:
		var damage = weapons.calculate_damage()
		target.take_damage(damage)
		return damage
	return 0
