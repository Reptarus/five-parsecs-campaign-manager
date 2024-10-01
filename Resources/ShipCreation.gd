# ShipCreation.gd
class_name ShipCreation
extends Resource

class ShieldComponent extends ShipComponent:
	var shield_strength: int
	
	func _init(p_name: String = "", p_description: String = "", p_power_usage: int = 0, p_health: int = 0, p_shield_strength: int = 0) -> void:
		super._init(p_name, p_description, GlobalEnums.ComponentType.SHIELDS, p_power_usage, p_health)
		shield_strength = p_shield_strength

class CargoHoldComponent extends ShipComponent:
	var capacity: int
	
	func _init(p_name: String = "", p_description: String = "", p_power_usage: int = 0, p_health: int = 0, p_capacity: int = 0) -> void:
		super._init(p_name, p_description, GlobalEnums.ComponentType.CARGO_HOLD, p_power_usage, p_health)
		capacity = p_capacity

class DropPodComponent extends ShipComponent:
	var pod_count: int
	
	func _init(p_name: String = "", p_description: String = "", p_power_usage: int = 0, p_health: int = 0, p_pod_count: int = 0) -> void:
		super._init(p_name, p_description, GlobalEnums.ComponentType.DROP_POD, p_power_usage, p_health)
		pod_count = p_pod_count

class ShuttleBayComponent extends ShipComponent:
	var passenger_capacity: int
	
	func _init(p_name: String = "", p_description: String = "", p_power_usage: int = 0, p_health: int = 0, p_passenger_capacity: int = 0) -> void:
		super._init(p_name, p_description, GlobalEnums.ComponentType.SHUTTLE_BAY, p_power_usage, p_health)
		passenger_capacity = p_passenger_capacity

const BASE_SHIP_POWER: int = 100
const BASE_SHIP_COST: int = 1000

var ship_components: Dictionary = {}

func _init() -> void:
	load_ship_components()

func load_ship_components() -> void:
	var file := FileAccess.open("res://data/ship_components.json", FileAccess.READ)
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error == OK:
		ship_components = json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func create_component_from_data(component_data: Dictionary) -> ShipComponent:
	var component_type: GlobalEnums.ComponentType = GlobalEnums.ComponentType[component_data.id.split("_")[0].to_upper()]
	match component_type:
		GlobalEnums.ComponentType.SHIELDS:
			return ShieldComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.shield_strength
			)
		GlobalEnums.ComponentType.CARGO_HOLD:
			return CargoHoldComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.capacity
			)
		GlobalEnums.ComponentType.DROP_POD:
			return DropPodComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.pod_count
			)
		GlobalEnums.ComponentType.SHUTTLE_BAY:
			return ShuttleBayComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.passenger_capacity
			)
		_:
			return ShipComponent.new(
				component_data.name,
				component_data.description,
				component_type,
				component_data.power_usage,
				component_data.health
			)
