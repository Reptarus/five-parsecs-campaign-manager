# ShipCreation.gd
class_name ShipCreation
extends Node

# Add these class definitions near the top of your file, with other class definitions
class ShieldComponent extends ShipComponent:
	var shield_strength: int
	func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_cost: int, p_shield_strength: int):
		super(p_name, p_description, ShipComponent.ComponentType.SHIELDS, p_power_usage, p_health, p_cost)
		shield_strength = p_shield_strength

class CargoHoldComponent extends ShipComponent:
	var capacity: int

	func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_cost: int, p_capacity: int):
		super._init(p_name, p_description, ShipComponent.ComponentType.CARGO_HOLD, p_power_usage, p_health, p_cost)
		capacity = p_capacity

class DropPodComponent extends ShipComponent:
	var pod_count: int

	func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_cost: int, p_pod_count: int):
		super._init(p_name, p_description, ShipComponent.ComponentType.DROP_PODS, p_power_usage, p_health, p_cost)
		pod_count = p_pod_count

class ShuttleComponent extends ShipComponent:
	var passenger_capacity: int

	func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_cost: int, p_passenger_capacity: int):
		super._init(p_name, p_description, ShipComponent.ComponentType.SHUTTLE, p_power_usage, p_health, p_cost)
		passenger_capacity = p_passenger_capacity

const BASE_SHIP_POWER: int = 100
const BASE_SHIP_COST: int = 1000

var game_state: GameState
var ship_components: Dictionary

@onready var hull_option: OptionButton = $VBoxContainer/ComponentsContainer/HullOption
@onready var engine_option: OptionButton = $VBoxContainer/ComponentsContainer/EngineOption
@onready var weapon_option: OptionButton = $VBoxContainer/ComponentsContainer/WeaponOption
@onready var medical_option: OptionButton = $VBoxContainer/ComponentsContainer/MedicalOption
@onready var shield_option: OptionButton = $VBoxContainer/ComponentsContainer/ShieldOption
@onready var cargo_option: OptionButton = $VBoxContainer/ComponentsContainer/CargoOption
@onready var drop_pod_option: OptionButton = $VBoxContainer/ComponentsContainer/DropPodOption
@onready var shuttle_option: OptionButton = $VBoxContainer/ComponentsContainer/ShuttleOption
@onready var ship_info_label: Label = $VBoxContainer/ShipInfoLabel
@onready var create_ship_button: Button = $VBoxContainer/CreateShipButton
@onready var back_button: Button = $VBoxContainer/BackButton

func _init(_game_state: GameState):
	game_state = _game_state
	load_ship_components()

func load_ship_components() -> void:
	var file = FileAccess.open("res://data/ship_components.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		ship_components = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message())

func create_component_from_data(component_data: Dictionary) -> ShipComponent:
	match component_data.id.split("_")[0]:
		"basic", "reinforced", "hull":
			return HullComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.armor
			)
		"standard", "advanced", "engine":
			return EngineComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.speed,
				component_data.fuel_efficiency
			)
		"laser", "missile", "weapon":
			return WeaponsComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.damage,
				component_data.range,
				component_data.accuracy
			)
		"basic_med", "advanced_med", "med":
			return MedicalBayComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.healing_capacity
			)
		"basic_shield", "advanced_shield", "shield":
			return ShieldComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.shield_strength
			)
		"small_cargo", "large_cargo", "cargo":
			return CargoHoldComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.capacity
			)
		"drop_pod":
			return DropPodComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.pod_count
			)
		"shuttle":
			return ShuttleComponent.new(
				component_data.name,
				component_data.description,
				component_data.power_usage,
				component_data.health,
				component_data.cost,
				component_data.passenger_capacity
			)
		_:
			push_error("Unknown component type: " + component_data.id)
			return null
