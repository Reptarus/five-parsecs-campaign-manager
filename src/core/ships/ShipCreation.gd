# ShipCreation.gd
class_name ShipCreation
extends CampaignResponsiveLayout

signal ship_created(ship: Ship)
signal creation_cancelled

const Ship = preload("res://src/core/ships/Ship.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const WeaponsComponent = preload("res://src/core/ships/components/WeaponsComponent.gd")
const HullComponent = preload("res://src/core/ships/components/HullComponent.gd")
const EngineComponent = preload("res://src/core/ships/components/EngineComponent.gd")
const MedicalBayComponent = preload("res://src/core/ships/components/MedicalBayComponent.gd")

# Core rules ship types and their base stats
const SHIP_TYPES = {
	"WORN_FREIGHTER": {
		"base_debt": 20,
		"hull_points": 30,
		"traits": []
	},
	"RETIRED_TROOP_TRANSPORT": {
		"base_debt": 30,
		"hull_points": 35,
		"traits": ["EMERGENCY_DRIVES"]
	},
	"STRANGE_ALIEN_VESSEL": {
		"base_debt": 15,
		"hull_points": 25,
		"traits": []
	},
	"UPGRADED_SHUTTLE": {
		"base_debt": 10,
		"hull_points": 20,
		"traits": []
	},
	"RETIRED_SCOUT_SHIP": {
		"base_debt": 20,
		"hull_points": 25,
		"traits": ["FUEL_EFFICIENT"]
	},
	"REPURPOSED_SCIENCE_VESSEL": {
		"base_debt": 10,
		"hull_points": 20,
		"traits": []
	},
	"BATTERED_MINING_SHIP": {
		"base_debt": 20,
		"hull_points": 35,
		"traits": ["FUEL_HOG"]
	},
	"UNRELIABLE_MERCHANT_CRUISER": {
		"base_debt": 20,
		"hull_points": 30,
		"traits": []
	},
	"FORMER_DIPLOMATIC_VESSEL": {
		"base_debt": 15,
		"hull_points": 25,
		"traits": []
	},
	"ANCIENT_LOW_TECH_CRAFT": {
		"base_debt": 20,
		"hull_points": 35,
		"traits": ["DODGY_DRIVE"]
	},
	"SALVAGED_WRECK": {
		"base_debt": 20,
		"hull_points": 30,
		"traits": []
	},
	"WORN_COLONY_SHIP": {
		"base_debt": 20,
		"hull_points": 25,
		"traits": ["STANDARD_ISSUE"]
	},
	"RETIRED_MILITARY_PATROL": {
		"base_debt": 35,
		"hull_points": 40,
		"traits": ["ARMORED"]
	}
}

@onready var ship_name_input := $VBoxContainer/ShipNameInput
@onready var ship_type_option := $VBoxContainer/ShipTypeOption
@onready var components_container := $VBoxContainer/ComponentsContainer
@onready var hull_option := $VBoxContainer/ComponentsContainer/HullOption
@onready var engine_option := $VBoxContainer/ComponentsContainer/EngineOption
@onready var weapon_options_container := $VBoxContainer/ComponentsContainer/WeaponOptionsContainer
@onready var medical_option := $VBoxContainer/ComponentsContainer/MedicalOption
@onready var ship_info_label := $VBoxContainer/ShipInfoLabel
@onready var add_weapon_button := $VBoxContainer/ComponentsContainer/AddWeaponButton

const PORTRAIT_COMPONENTS_RATIO := 0.6 # Components take 60% in portrait mode
const MAX_WEAPONS := 4 # Maximum number of weapons a ship can have

var current_ship: Ship
var weapon_options: Array[OptionButton] = []

func _ready() -> void:
	super._ready()
	_setup_ship_creation()
	_connect_signals()

func _setup_ship_creation() -> void:
	_setup_ship_types()
	_setup_component_options()
	_setup_buttons()
	current_ship = Ship.new()
	_add_weapon_option() # Add initial weapon option

func _setup_ship_types() -> void:
	for ship_type in SHIP_TYPES.keys():
		ship_type_option.add_item(ship_type.capitalize().replace("_", " "))

func _setup_component_options() -> void:
	# Add options to groups for touch controls
	for option in [hull_option, engine_option, medical_option]:
		option.add_to_group("touch_controls")
	
	# Populate hull options
	for hull in GlobalEnums.ShipComponentType.values():
		if str(GlobalEnums.ShipComponentType.keys()[hull]).begins_with("HULL_"):
			hull_option.add_item(GlobalEnums.ShipComponentType.keys()[hull].trim_prefix("HULL_"))
			
	# Populate engine options
	for engine in GlobalEnums.ShipComponentType.values():
		if str(GlobalEnums.ShipComponentType.keys()[engine]).begins_with("ENGINE_"):
			engine_option.add_item(GlobalEnums.ShipComponentType.keys()[engine].trim_prefix("ENGINE_"))
			
	# Populate medical bay options
	for medical in GlobalEnums.ShipComponentType.values():
		if str(GlobalEnums.ShipComponentType.keys()[medical]).begins_with("MEDICAL_"):
			medical_option.add_item(GlobalEnums.ShipComponentType.keys()[medical].trim_prefix("MEDICAL_"))

func _setup_buttons() -> void:
	var create_button = $VBoxContainer/CreateShipButton
	var back_button = $VBoxContainer/BackButton
	
	create_button.add_to_group("touch_controls")
	back_button.add_to_group("touch_controls")
	add_weapon_button.add_to_group("touch_controls")
	
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_on_back_pressed)
	add_weapon_button.pressed.connect(_on_add_weapon_pressed)

func _connect_signals() -> void:
	ship_name_input.text_changed.connect(_on_name_changed)
	ship_type_option.item_selected.connect(_on_ship_type_selected)
	hull_option.item_selected.connect(_on_hull_selected)
	engine_option.item_selected.connect(_on_engine_selected)
	medical_option.item_selected.connect(_on_medical_selected)

func _add_weapon_option() -> void:
	if weapon_options.size() >= MAX_WEAPONS:
		push_warning("Maximum number of weapons reached")
		return
		
	var weapon_container = HBoxContainer.new()
	var weapon_label = Label.new()
	weapon_label.text = "Weapon %d:" % (weapon_options.size() + 1)
	
	var weapon_option = OptionButton.new()
	weapon_option.add_to_group("touch_controls")
	
	# Populate weapon options
	for weapon in GlobalEnums.ShipComponentType.values():
		if str(GlobalEnums.ShipComponentType.keys()[weapon]).begins_with("WEAPON_"):
			weapon_option.add_item(GlobalEnums.ShipComponentType.keys()[weapon].trim_prefix("WEAPON_"))
	
	var remove_button = Button.new()
	remove_button.text = "X"
	remove_button.pressed.connect(func(): _remove_weapon_option(weapon_container))
	
	weapon_container.add_child(weapon_label)
	weapon_container.add_child(weapon_option)
	weapon_container.add_child(remove_button)
	
	weapon_options_container.add_child(weapon_container)
	weapon_options.append(weapon_option)
	
	weapon_option.item_selected.connect(func(index): _on_weapon_selected(index, weapon_options.size() - 1))
	
	add_weapon_button.visible = weapon_options.size() < MAX_WEAPONS

func _remove_weapon_option(container: Node) -> void:
	var index = container.get_index()
	weapon_options.remove_at(index)
	container.queue_free()
	
	# Update remaining weapon labels
	for i in range(index, weapon_options_container.get_child_count()):
		var child = weapon_options_container.get_child(i)
		var label = child.get_child(0) as Label
		label.text = "Weapon %d:" % (i + 1)
	
	add_weapon_button.visible = weapon_options.size() < MAX_WEAPONS
	_update_ship_info()

func _on_name_changed(new_name: String) -> void:
	current_ship.ship_name = new_name
	_update_ship_info()

func _on_ship_type_selected(index: int) -> void:
	var ship_type = SHIP_TYPES.keys()[index]
	var ship_data = SHIP_TYPES[ship_type]
	
	current_ship.base_debt = ship_data.base_debt
	current_ship.hull_points = ship_data.hull_points
	current_ship.characteristics = ship_data.traits.duplicate()
	
	_update_ship_info()

func _on_hull_selected(index: int) -> void:
	var hull = HullComponent.new()
	hull.component_type = GlobalEnums.ShipComponentType.values()[index]
	current_ship.add_component(hull)
	_update_ship_info()

func _on_engine_selected(index: int) -> void:
	var engine = EngineComponent.new()
	engine.component_type = GlobalEnums.ShipComponentType.values()[index]
	current_ship.add_component(engine)
	_update_ship_info()

func _on_weapon_selected(index: int, weapon_slot: int) -> void:
	var weapon = WeaponsComponent.new()
	weapon.component_type = GlobalEnums.ShipComponentType.values()[index]
	current_ship.add_component(weapon)
	_update_ship_info()

func _on_medical_selected(index: int) -> void:
	var medical = MedicalBayComponent.new()
	medical.component_type = GlobalEnums.ShipComponentType.values()[index]
	current_ship.add_component(medical)
	_update_ship_info()

func _on_add_weapon_pressed() -> void:
	_add_weapon_option()
	_update_ship_info()

func _update_ship_info() -> void:
	var ship_type = SHIP_TYPES.keys()[ship_type_option.selected]
	var weapons_info = ""
	var weapons = current_ship.get_weapons()
	
	for i in range(weapons.size()):
		var weapon = weapons[i]
		weapons_info += "\n  %d. %s (Damage: %d, Range: %d, Accuracy: %d)" % [
			i + 1,
			weapon.name if not weapon.name.is_empty() else "Unnamed Weapon",
			weapon.get_damage(),
			weapon.get_range(),
			weapon.get_accuracy()
		]
	
	if weapons_info.is_empty():
		weapons_info = "\n  None"
	
	var info = """
	Ship Name:%s
	Ship Type:%s
	Base Debt:%d credits
	Hull Points:%d
	Traits:%s
	
	Components:
	- Hull:%s
	- Engine:%s
	- Weapons:%s
	- Medical Bay:%s
	
	Cargo Capacity:%d
	Crew Capacity:%d
	Combat Rating:%d
	Power Usage:%d
	Maintenance Cost:%d
	""" % [
		current_ship.ship_name,
		ship_type.capitalize().replace("_", " "),
		current_ship.base_debt,
		current_ship.hull_points,
		", ".join(current_ship.characteristics) if not current_ship.characteristics.is_empty() else "None",
		_get_component_name(current_ship.hull_component.component_type) if current_ship.hull_component else "None",
		_get_component_name(current_ship.engine_component.component_type) if current_ship.engine_component else "None",
		weapons_info,
		_get_component_name(current_ship.medical_component.component_type) if current_ship.medical_component else "None",
		current_ship.get_cargo_capacity(),
		current_ship.get_crew_capacity(),
		current_ship.get_combat_rating(),
		current_ship.get_power_usage(),
		current_ship.get_maintenance_cost()
	]
	
	ship_info_label.text = info

func _on_create_pressed() -> void:
	if _validate_ship():
		# Add random debt modifier per core rules (1d6)
		current_ship.base_debt += (randi() % 6 + 1)
		ship_created.emit(current_ship)
	else:
		# Show error message
		pass

func _on_back_pressed() -> void:
	creation_cancelled.emit()

func _validate_ship() -> bool:
	if current_ship.ship_name.strip_edges().is_empty():
		return false
		
	# Validate required components
	if not current_ship.hull_component or not current_ship.engine_component:
		return false
	
	return true

func _get_component_name(component_type: GlobalEnums.ShipComponentType) -> String:
	var type_name = GlobalEnums.ShipComponentType.keys()[component_type]
	var display_name = type_name.split("_")
	if display_name.size() >= 2:
		return "%s %s" % [display_name[0].capitalize(), display_name[1]]
	return type_name.capitalize()
