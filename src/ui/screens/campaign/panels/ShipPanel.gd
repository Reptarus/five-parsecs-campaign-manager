extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal ship_updated(ship_data: Dictionary)

@onready var ship_name_input: LineEdit = $"Content/ShipName/LineEdit"
@onready var ship_type_label: Label = $"Content/ShipType/Value"
@onready var hull_points_label: Label = $"Content/HullPoints/Value"
@onready var debt_label: Label = $"Content/Debt/Value"
@onready var traits_container: VBoxContainer = $"Content/Traits/Container"
@onready var generate_button: Button = $"Content/Controls/GenerateButton"
@onready var reroll_button: Button = $"Content/Controls/RerollButton"

var ship_data: Dictionary = {
	"name": "",
	"type": "",
	"hull_points": 0,
	"max_hull": 0,
	"debt": 0,
	"traits": [],
	"components": []
}

func _ready() -> void:
	_connect_signals()
	_generate_ship()

func _connect_signals() -> void:
	if ship_name_input:
		ship_name_input.text_changed.connect(_on_ship_name_changed)
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)

func _on_ship_name_changed(new_name: String) -> void:
	ship_data.name = new_name
	ship_updated.emit(ship_data)

func _on_generate_pressed() -> void:
	_generate_ship()

func _on_reroll_pressed() -> void:
	_generate_ship()

func _generate_ship() -> void:
	"""Generate ship following Five Parsecs Ship Table (Core Rules pp. 1918-1920)"""
	var ship_roll = randi_range(1, 100)
	
	# Ship Table (simplified for initial implementation)
	if ship_roll <= 12:
		_create_worn_freighter()
	elif ship_roll <= 25:
		_create_patrol_boat()
	elif ship_roll <= 40:
		_create_converted_transport()
	elif ship_roll <= 60:
		_create_scout_ship()
	elif ship_roll <= 80:
		_create_armed_trader()
	else:
		_create_custom_ship()
	
	# Set default name if empty
	if ship_data.name.is_empty():
		ship_data.name = _generate_ship_name()
	
	_update_ui()
	ship_updated.emit(ship_data)

func _create_worn_freighter() -> void:
	"""Create a Worn Freighter (most common starting ship)"""
	ship_data.type = "Worn Freighter"
	ship_data.debt = randi_range(1, 6) + 20 # 1D6+20 credits debt
	ship_data.hull_points = 30
	ship_data.max_hull = 30
	ship_data.traits = _roll_ship_traits()

func _create_patrol_boat() -> void:
	"""Create a Patrol Boat"""
	ship_data.type = "Patrol Boat"
	ship_data.debt = randi_range(2, 12) + 15 # 2D6+15 credits debt
	ship_data.hull_points = 25
	ship_data.max_hull = 25
	ship_data.traits = _roll_ship_traits()

func _create_converted_transport() -> void:
	"""Create a Converted Transport"""
	ship_data.type = "Converted Transport"
	ship_data.debt = randi_range(1, 6) + 25 # 1D6+25 credits debt
	ship_data.hull_points = 35
	ship_data.max_hull = 35
	ship_data.traits = _roll_ship_traits()

func _create_scout_ship() -> void:
	"""Create a Scout Ship"""
	ship_data.type = "Scout Ship"
	ship_data.debt = randi_range(2, 12) + 10 # 2D6+10 credits debt
	ship_data.hull_points = 20
	ship_data.max_hull = 20
	ship_data.traits = _roll_ship_traits()

func _create_armed_trader() -> void:
	"""Create an Armed Trader"""
	ship_data.type = "Armed Trader"
	ship_data.debt = randi_range(3, 18) + 20 # 3D6+20 credits debt
	ship_data.hull_points = 28
	ship_data.max_hull = 28
	ship_data.traits = _roll_ship_traits()

func _create_custom_ship() -> void:
	"""Create a custom/unique ship"""
	var ship_types = ["Modified Corvette", "Salvage Hauler", "Deep Space Explorer", "Racing Ship"]
	ship_data.type = ship_types[randi() % ship_types.size()]
	ship_data.debt = randi_range(2, 12) + randi_range(1, 20) # Variable debt
	ship_data.hull_points = randi_range(20, 35)
	ship_data.max_hull = ship_data.hull_points
	ship_data.traits = _roll_ship_traits()

func _roll_ship_traits() -> Array[String]:
	"""Roll for ship traits following Five Parsecs rules"""
	var traits: Array[String] = []
	var trait_roll = randi_range(1, 100)
	
	# Ship traits table (Core Rules p. 1896)
	if trait_roll <= 15:
		traits.append("Fuel Efficient")
	elif trait_roll <= 25:
		traits.append("Armored")
	elif trait_roll <= 35:
		traits.append("Fast")
	elif trait_roll <= 45:
		traits.append("Reliable")
	elif trait_roll <= 55:
		traits.append("Spacious")
	elif trait_roll <= 65:
		traits.append("Well-Armed")
	elif trait_roll <= 75:
		traits.append("Sensor Suite")
	elif trait_roll <= 85:
		traits.append("Standard Issue")
	elif trait_roll <= 95:
		traits.append("Dodgy Drive")
	else:
		traits.append("Fuel Hog")
	
	# 20% chance for second trait
	if randf() < 0.2:
		var second_trait_roll = randi_range(1, 100)
		var second_trait = ""
		if second_trait_roll <= 30:
			second_trait = "Hidden Compartments"
		elif second_trait_roll <= 60:
			second_trait = "Enhanced Navigation"
		else:
			second_trait = "Emergency Systems"
		
		if not traits.has(second_trait):
			traits.append(second_trait)
	
	return traits

func _generate_ship_name() -> String:
	"""Generate a thematic ship name"""
	var prefixes = ["Star", "Void", "Cosmic", "Solar", "Deep", "Far", "Wild", "Free", "Swift", "Bold"]
	var suffixes = ["Runner", "Wanderer", "Explorer", "Trader", "Hunter", "Seeker", "Drifter", "Pioneer", "Voyager", "Falcon"]
	
	return prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()]

func _update_ui() -> void:
	"""Update all UI elements with current ship data"""
	if ship_name_input and ship_data.name:
		ship_name_input.text = ship_data.name
	
	if ship_type_label:
		ship_type_label.text = ship_data.type
	
	if hull_points_label:
		hull_points_label.text = str(ship_data.hull_points) + " / " + str(ship_data.max_hull)
	
	if debt_label:
		debt_label.text = str(ship_data.debt) + " credits"
	
	# Update traits display
	if traits_container:
		# Clear existing trait labels
		for child in traits_container.get_children():
			child.queue_free()
		
		# Add new trait labels
		var traits_array = ship_data.traits
		for i in range(traits_array.size()):
			var trait_name = traits_array[i]
			var trait_label = Label.new()
			trait_label.text = "• " + trait_name
			traits_container.add_child(trait_label)

func get_ship_data() -> Dictionary:
	return ship_data.duplicate()

func set_ship_data(data: Dictionary) -> void:
	ship_data = data.duplicate()
	_update_ui()

func is_valid() -> bool:
	return not ship_data.name.strip_edges().is_empty() and not ship_data.type.is_empty()