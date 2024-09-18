class_name Ship
extends Resource

# Remove or comment out if not used
# signal component_damaged(component: ShipComponent)
# signal component_repaired(component: ShipComponent)
# signal power_changed(available_power: int)

@export var name: String
@export var max_hull: int
@export var current_hull: int
@export var fuel: int
@export var debt: int
@export var components: Array[ShipComponent] = []
@export var traits: Array[String]

var _trait_dict: Dictionary = {}

func add_component(component: ShipComponent) -> void:
    components.append(component)

func remove_component(component: ShipComponent) -> void:
    components.erase(component)

func get_component_by_type(type: ShipComponent.ComponentType) -> ShipComponent:
    for component in components:
        if component.type == type:
            return component
    return null

# Use this method to initialize traits
func set_initial_traits(initial_traits: Array[String]) -> void:
    traits = initial_traits.duplicate()

# Method to get all traits
func get_traits() -> Array[String]:
    return traits.duplicate()

# Rewritten _find_trait_index method
func _find_trait_index(search_string: String) -> int:
    return traits.find(search_string)

# Other methods using traits
func has_trait(search_string: String) -> bool:
    return _find_trait_index(search_string) != -1

func repair(amount: int) -> void:
    current_hull = min(current_hull + amount, max_hull)

func take_damage(amount: int, game_state: GameState) -> void:
    if game_state.is_tutorial_active:
        amount = max(1, amount / 2)  # Reduce damage in tutorial mode
    current_hull = max(current_hull - amount, 0)

func is_destroyed() -> bool:
    return current_hull <= 0

func add_fuel(amount: int) -> void:
    fuel += amount

func use_fuel(amount: int) -> bool:
    if fuel >= amount:
        fuel -= amount
        return true
    return false

func setup_tutorial_ship() -> void:
    name = "Tutorial Vessel"
    max_hull = 10
    current_hull = 10
    fuel = 5
    debt = 0
    components = [
        ShipComponent.new("Basic Engine", ShipComponent.ComponentType.ENGINE, 1, 1, false),
        ShipComponent.new("Basic Laser", ShipComponent.ComponentType.WEAPONS, 1, 1, false)
    ]
    traits = ["Tutorial"]

func serialize() -> Dictionary:
    return {
        "name": name,
        "max_hull": max_hull,
        "current_hull": current_hull,
        "fuel": fuel,
        "debt": debt,
        "components": components.map(func(c): return c.serialize()),
        "traits": traits
    }

static func deserialize(data: Dictionary) -> Ship:
    var ship = Ship.new()
    ship.name = data["name"]
    ship.max_hull = data["max_hull"]
    ship.current_hull = data["current_hull"]
    ship.fuel = data["fuel"]
    ship.debt = data["debt"]
    ship.components = data["components"].map(func(c): return ShipComponent.deserialize(c))
    ship.traits = data["traits"]
    return ship

func get_total_power_consumption() -> int:
    var total_power = 0
    for component in components:
        if not component.is_damaged:
            total_power += component.power_usage
    return total_power

# If you need to serialize the traits
func get_traits_for_save() -> Array[String]:
    return get_traits()

# If you need to deserialize the traits
func load_traits_from_save(saved_traits: Array[String]) -> void:
    _trait_dict.clear()
    set_initial_traits(saved_traits)
