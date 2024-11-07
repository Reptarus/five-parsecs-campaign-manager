# ShipCreation.gd
extends CampaignResponsiveLayout

signal ship_created(ship: Ship)
signal creation_cancelled

@onready var ship_name_input := $VBoxContainer/ShipNameInput
@onready var components_container := $VBoxContainer/ComponentsContainer
@onready var hull_option := $VBoxContainer/ComponentsContainer/HullOption
@onready var engine_option := $VBoxContainer/ComponentsContainer/EngineOption
@onready var weapon_option := $VBoxContainer/ComponentsContainer/WeaponOption
@onready var medical_option := $VBoxContainer/ComponentsContainer/MedicalOption
@onready var ship_info_label := $VBoxContainer/ShipInfoLabel

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_COMPONENTS_RATIO := 0.6  # Components take 60% in portrait mode

var current_ship: Ship

func _ready() -> void:
	super._ready()
	_setup_ship_creation()
	_connect_signals()

func _setup_ship_creation() -> void:
	_setup_component_options()
	_setup_buttons()
	current_ship = Ship.new()

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	# Stack components vertically
	components_container.columns = 1
	
	# Adjust component sizes for portrait mode
	var viewport_height = get_viewport_rect().size.y
	components_container.custom_minimum_size.y = viewport_height * PORTRAIT_COMPONENTS_RATIO
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)
	
	# Adjust margins for mobile
	$VBoxContainer.add_theme_constant_override("margin_left", 10)
	$VBoxContainer.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	# Two column layout for components
	components_container.columns = 2
	
	# Reset component sizes
	components_container.custom_minimum_size = Vector2(600, 0)
	
	# Reset control sizes
	_adjust_touch_sizes(false)
	
	# Reset margins
	$VBoxContainer.add_theme_constant_override("margin_left", 20)
	$VBoxContainer.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons and option buttons
	for control in get_tree().get_nodes_in_group("touch_controls"):
		control.custom_minimum_size.y = button_height
	
	# Adjust name input
	ship_name_input.custom_minimum_size.y = button_height

func _setup_component_options() -> void:
	# Add options to groups for touch controls
	for option in [hull_option, engine_option, weapon_option, medical_option]:
		option.add_to_group("touch_controls")
	
	# Populate hull options
	for hull in GlobalEnums.HullType.values():
		hull_option.add_item(GlobalEnums.HullType.keys()[hull])
		
	# Populate engine options
	for engine in GlobalEnums.EngineType.values():
		engine_option.add_item(GlobalEnums.EngineType.keys()[engine])
		
	# Populate weapon options
	for weapon in GlobalEnums.WeaponType.values():
		weapon_option.add_item(GlobalEnums.WeaponType.keys()[weapon])
		
	# Populate medical bay options
	for medical in GlobalEnums.MedicalBayType.values():
		medical_option.add_item(GlobalEnums.MedicalBayType.keys()[medical])

func _setup_buttons() -> void:
	var create_button = $VBoxContainer/CreateShipButton
	var back_button = $VBoxContainer/BackButton
	
	create_button.add_to_group("touch_controls")
	back_button.add_to_group("touch_controls")
	
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _connect_signals() -> void:
	ship_name_input.text_changed.connect(_on_name_changed)
	hull_option.item_selected.connect(_on_hull_selected)
	engine_option.item_selected.connect(_on_engine_selected)
	weapon_option.item_selected.connect(_on_weapon_selected)
	medical_option.item_selected.connect(_on_medical_selected)

func _on_name_changed(new_name: String) -> void:
	current_ship.name = new_name
	_update_ship_info()

func _on_hull_selected(index: int) -> void:
	current_ship.hull_type = index
	_update_ship_info()

func _on_engine_selected(index: int) -> void:
	current_ship.engine_type = index
	_update_ship_info()

func _on_weapon_selected(index: int) -> void:
	current_ship.weapon_type = index
	_update_ship_info()

func _on_medical_selected(index: int) -> void:
	current_ship.medical_bay_type = index
	_update_ship_info()

func _update_ship_info() -> void:
	var info = """
	Ship Name: %s
	Hull Type: %s
	Engine Type: %s
	Weapon System: %s
	Medical Bay: %s
	
	Cargo Capacity: %d
	Crew Capacity: %d
	Combat Rating: %d
	""" % [
		current_ship.name,
		GlobalEnums.HullType.keys()[current_ship.hull_type],
		GlobalEnums.EngineType.keys()[current_ship.engine_type],
		GlobalEnums.WeaponType.keys()[current_ship.weapon_type],
		GlobalEnums.MedicalBayType.keys()[current_ship.medical_bay_type],
		current_ship.get_cargo_capacity(),
		current_ship.get_crew_capacity(),
		current_ship.get_combat_rating()
	]
	
	ship_info_label.text = info

func _on_create_pressed() -> void:
	if _validate_ship():
		ship_created.emit(current_ship)
	else:
		# Show error message
		pass

func _on_back_pressed() -> void:
	creation_cancelled.emit()

func _validate_ship() -> bool:
	return current_ship.name.length() > 0
