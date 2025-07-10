class_name EquipmentManagerUI
extends Control

signal equipment_assigned(equipment_item: Dictionary, crew_member: Dictionary)
signal equipment_unassigned(equipment_item: Dictionary, crew_member: Dictionary)

@onready var equipment_grid: GridContainer = %EquipmentGrid
@onready var crew_list: VBoxContainer = %CrewList
@onready var details_container: VBoxContainer = %DetailsContainer

var selected_equipment: Dictionary = {}
var selected_crew_member: Dictionary = {}
var equipment_database: Array[Dictionary] = []
var crew_roster: Array[Dictionary] = []

func _ready() -> void:
	print("EquipmentManager: Initializing...")
	_load_equipment_database()
	_load_crew_roster()
	_refresh_equipment_display()
	_refresh_crew_display()

func _load_equipment_database() -> void:
	"""Load equipment from data systems"""
	# TODO: Connect to equipment database
	equipment_database = [
		{"name": "Military Rifle", "type": "weapon", "range": 24, "shots": 1, "damage": 1, "traits": ["Military"]},
		{"name": "Scrap Pistol", "type": "weapon", "range": 12, "shots": 1, "damage": 1, "traits": ["Pistol"]},
		{"name": "Combat Armor", "type": "armor", "save": 5, "traits": ["Heavy"]},
		{"name": "Analyzer", "type": "gadget", "traits": ["Tech"]},
		{"name": "Medkit", "type": "gear", "traits": ["Medical"]},
	]

func _load_crew_roster() -> void:
	"""Load current crew from campaign data"""
	# TODO: Connect to campaign manager
	crew_roster = [
		{"name": "Captain Reynolds", "class": "Soldier", "equipment": []},
		{"name": "Dr. Chen", "class": "Scientist", "equipment": []},
		{"name": "Sgt. Martinez", "class": "Military", "equipment": []},
		{"name": "Tech Walker", "class": "Engineer", "equipment": []},
	]

func _refresh_equipment_display() -> void:
	"""Refresh the equipment grid display"""
	# Clear existing items
	for child in equipment_grid.get_children():
		child.queue_free()

	# Add equipment items
	for equipment in equipment_database:
		var item_button: Button = Button.new()
		item_button.text = equipment.name
		item_button.custom_minimum_size = Vector2(150, 60)
		item_button.pressed.connect(_on_equipment_selected.bind(equipment))
		equipment_grid.add_child(item_button)

func _refresh_crew_display() -> void:
	"""Refresh the crew assignment display"""
	# Clear existing items
	for child in crew_list.get_children():
		child.queue_free()

	# Add crew members
	for crew_member in crew_roster:
		var crew_panel: Panel = _create_crew_panel(crew_member)
		crew_list.add_child(crew_panel)

func _create_crew_panel(crew_member: Dictionary) -> Control:
	"""Create a panel for crew _member equipment assignment"""
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Crew _member name
	var name_label: Label = Label.new()
	name_label.text = crew_member.name + " (" + crew_member.class +")"
	vbox.add_child(name_label)

	# Equipment list
	var equipment_list = VBoxContainer.new()
	for equipment in crew_member.get("equipment", []):
		var equipment_label: Label = Label.new()
		equipment_label.text = "- " + equipment.name
		equipment_list.add_child(equipment_label)
	vbox.add_child(equipment_list)

	# Assign button
	var assign_button: Button = Button.new()
	assign_button.text = "Assign Equipment"
	assign_button.pressed.connect(_on_crew_selected.bind(crew_member))
	vbox.add_child(assign_button)

	return panel

func _update_equipment_details(equipment: Dictionary) -> void:
	"""Update the equipment details panel"""
	# Clear existing details
	for child in details_container.get_children():
		child.queue_free()

	if (safe_call_method(equipment, "is_empty") == true):
		return

	# Equipment name
	var name_label: Label = Label.new()
	name_label.text = equipment.name
	name_label.add_theme_font_size_override("font_size", 18)
	details_container.add_child(name_label)

	# Equipment type
	var type_label: Label = Label.new()
	type_label.text = "Type: " + equipment.type.capitalize()
	details_container.add_child(type_label)

	# Equipment stats
	match equipment.type:
		"weapon":
			var range_label: Label = Label.new()
			range_label.text = "Range: " + str(equipment.range) + "\""
			details_container.add_child(range_label)

			var shots_label: Label = Label.new()
			shots_label.text = "Shots: " + str(equipment.shots)
			details_container.add_child(shots_label)

			var damage_label: Label = Label.new()
			damage_label.text = "Damage: +" + str(equipment.damage)
			details_container.add_child(damage_label)

		"armor":
			var save_label: Label = Label.new()
			save_label.text = "Saving Throw: " + str(equipment.save) + "+"
			details_container.add_child(save_label)

	# Traits
	if equipment.has("traits"):
		var traits_label: Label = Label.new()
		traits_label.text = "Traits: " + ", ".join(equipment.traits)
		details_container.add_child(traits_label)

func _on_equipment_selected(equipment: Dictionary) -> void:
	"""Handle equipment selection"""
	selected_equipment = equipment
	_update_equipment_details(equipment)
	print("Equipment selected: ", equipment.name)

func _on_crew_selected(crew_member: Dictionary) -> void:
	"""Handle crew _member selection for equipment assignment"""
	selected_crew_member = crew_member

	if not (safe_call_method(selected_equipment, "is_empty") == true):
		_assign_equipment_to_crew()

func _assign_equipment_to_crew() -> void:
	"""Assign selected equipment to selected crew member"""
	if (safe_call_method(selected_equipment, "is_empty") == true) or (safe_call_method(selected_crew_member, "is_empty") == true):
		return

	# Add equipment to crew member
	if not selected_crew_member.has("equipment"):
		selected_crew_member["equipment"] = []

	selected_crew_member["equipment"].append(selected_equipment.duplicate())

	# Emit signal
	equipment_assigned.emit(selected_equipment, selected_crew_member)

	# Refresh displays
	_refresh_crew_display()

	# Clear selections
	selected_equipment = {}
	selected_crew_member = {}
	_update_equipment_details({})

	print("Equipment assigned: ", selected_equipment.get("name", ""), " to ", selected_crew_member.get("name", ""))

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("EquipmentManager: Back pressed")
	if has_node("/root/SceneRouter"):
		var scene_router = get_node("/root/SceneRouter")
		scene_router.navigate_back()
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/main/MainMenu.tscn")

func _on_generate_equipment_pressed() -> void:
	"""Generate new equipment using tables"""
	print("EquipmentManager: Generate equipment pressed")
	# TODO: Implement equipment generation tables

func _on_trade_pressed() -> void:
	"""Open trade/market interface"""
	print("EquipmentManager: Trade pressed")
	# TODO: Open trade interface

func _on_repair_pressed() -> void:
	"""Open equipment repair interface"""
	print("EquipmentManager: Repair pressed")
	# TODO: Implement repair system
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null