class_name FPCM_CharacterSheet
extends Control

## Five Parsecs Character Sheet Display Component
## Displays character information in a comprehensive, readable format

# Safe imports - ensure GlobalEnums access
# Note: GlobalEnums is configured as an autoload singleton in project.godot
# but we add this check to ensure it's accessible during compilation
const Character = preload("res://src/core/character/Character.gd")

# UI Components
@onready var character_name_label: Label = get_node("VBoxContainer/HeaderSection/NameLabel")
@onready var character_class_label: Label = get_node("VBoxContainer/HeaderSection/ClassLabel")
@onready var background_label: Label = get_node("VBoxContainer/HeaderSection/BackgroundLabel")

# Stat labels
@onready var reaction_label: Label = get_node("VBoxContainer/StatsSection/StatsGrid/ReactionValue")
@onready var combat_label: Label = get_node("VBoxContainer/StatsSection/StatsGrid/CombatValue")
@onready var toughness_label: Label = get_node("VBoxContainer/StatsSection/StatsGrid/ToughnessValue")
@onready var speed_label: Label = get_node("VBoxContainer/StatsSection/StatsGrid/SpeedValue")
@onready var savvy_label: Label = get_node("VBoxContainer/StatsSection/StatsGrid/SavvyValue")
@onready var luck_label: Label = get_node("VBoxContainer/StatsSection/StatsGrid/LuckValue")

# Additional info
@onready var health_label: Label = get_node("VBoxContainer/HealthSection/HealthValue")
@onready var credits_label: Label = get_node("VBoxContainer/CreditsSection/CreditsValue")
@onready var traits_list: ItemList = get_node("VBoxContainer/TraitsSection/TraitsList")
@onready var equipment_list: ItemList = get_node("VBoxContainer/EquipmentSection/EquipmentList")

# State
var current_character: Character = null

signal character_selected(character: Character)
signal edit_character_requested(character: Character)

func _ready() -> void:
	print("CharacterSheet: Initializing...")
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	"""Setup the character sheet UI"""
	# Set default values
	_clear_display()

	# Setup traits list if available
	if traits_list:
		traits_list.select_mode = ItemList.SELECT_SINGLE
		traits_list.allow_reselect = false

	# Setup equipment list if available
	if equipment_list:
		equipment_list.select_mode = ItemList.SELECT_SINGLE
		equipment_list.allow_reselect = false

func _connect_signals() -> void:
	"""Connect UI signals"""
	# Connect double-click on character sheet to edit
	if has_signal("gui_input"):
		var _connect_result: int = gui_input.connect(_on_character_sheet_input)

func _on_character_sheet_input(event: InputEvent) -> void:
	"""Handle input on character sheet"""
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.double_click:
			if current_character:
				edit_character_requested.emit(current_character)

func display_character(character: Character) -> void:
	"""Display character information on the sheet"""
	if not character:
		_clear_display()
		return

	current_character = character

	# Update basic info
	_update_basic_info(character)
	_update_stats(character)
	_update_health_and_credits(character)
	_update_traits(character)
	_update_equipment(character)

	print("CharacterSheet: Displaying character: ", character.character_name)

func _update_basic_info(character: Character) -> void:
	"""Update basic character information"""
	# Character name
	if character_name_label:
		character_name_label.text = character.character_name if character.character_name else "Unnamed Character"

	# Character class - safe access to GlobalEnums
	if character_class_label:
		var character_class_str: String = ""
		# Check if GlobalEnums autoload is available and has the method
		if GlobalEnums and GlobalEnums.has_method("get_character_class_name"):
			character_class_str = GlobalEnums.get_character_class_name(character.get_character_class_enum())
		else:
			# Fallback: use the character class directly if available
			if character.has_method("get_character_class_string"):
				character_class_str = character.get_character_class_string()
			else:
				character_class_str = str(character.get_character_class_enum()) if character.has_method("get_character_class_enum") else "Unknown"
		character_class_label.text = "Class: " + character_class_str

	# Background
	if background_label:
		var background_name: String = character.background if not character.background.is_empty() else "Unknown"
		background_label.text = "Background: " + str(background_name)
func _update_stats(character: Character) -> void:
	"""Update character statistics"""
	if reaction_label:
		reaction_label.text = str(character.reactions)

	if combat_label:
		combat_label.text = str(character.combat)

	if toughness_label:
		toughness_label.text = str(character.toughness)

	if speed_label:
		speed_label.text = str(character.speed)

	if savvy_label:
		savvy_label.text = str(character.savvy)

	if luck_label:
		luck_label.text = str(character.luck)

func _update_health_and_credits(character: Character) -> void:
	"""Update health and credits"""
	if health_label:
		var health_text: String = str(character.health) + "/" + str(character.max_health)
		health_label.text = health_text

	if credits_label:
		credits_label.text = str(character.credits_earned) + " Credits"

func _update_traits(character: Character) -> void:
	"""Update character traits list"""
	if not traits_list:
		return

	traits_list.clear()

	if character.traits and character.traits.size() > 0:
		for character_trait: String in character.traits:
			traits_list.add_item(character_trait)
	else:
		traits_list.add_item("No traits")

func _update_equipment(character: Character) -> void:
	"""Update equipment list"""
	if not equipment_list:
		return

	equipment_list.clear()

	# Add equipment from character
	if character and character.has_method("get_equipment"):
		var equipment: Array = character.get_equipment()
		if (safe_call_method(equipment, "size") as int) > 0:
			for item: Dictionary in equipment:
				var item_name: String = item.get("name", "Unknown Item")
				var condition: String = item.get("condition", "")
				var display_text: String = item_name
				if not (safe_call_method(condition, "is_empty") == true) and condition != "standard":
					display_text += " (" + condition + ")"
				equipment_list.add_item(display_text)
		else:
			equipment_list.add_item("No equipment")
	else:
		# Fallback: check for basic equipment properties
		var equipment_items: Array[String] = []

		if character and character.has("starting_equipment") and character.starting_equipment:
			for item: Variant in character.starting_equipment:
				if item is String:
					safe_call_method(equipment_items, "append", [item])
				elif item is Dictionary:
					safe_call_method(equipment_items, "append", [item.get("name", "Unknown Item")])

		if (safe_call_method(equipment_items, "size") as int) > 0:
			for item: String in equipment_items:
				equipment_list.add_item(item)
		else:
			equipment_list.add_item("No equipment")

func _clear_display() -> void:
	"""Clear all character information"""
	current_character = null

	# Clear basic info
	if character_name_label:
		character_name_label.text = "No Character Selected"

	if character_class_label:
		character_class_label.text = "Class: None"

	if background_label:
		background_label.text = "Background: None"

	# Clear stats
	var stat_labels: Array[Label] = [reaction_label, combat_label, toughness_label, speed_label, savvy_label, luck_label]
	for label: Label in stat_labels:
		if label:
			label.text = "0"

	# Clear health and credits
	if health_label:
		health_label.text = "0 / 0.0"

	if credits_label:
		credits_label.text = "0 Credits"

	# Clear lists
	if traits_list:
		traits_list.clear()
		traits_list.add_item("No character loaded")

	if equipment_list:
		equipment_list.clear()
		equipment_list.add_item("No character loaded")

func get_displayed_character() -> Character:
	"""Get the currently displayed character"""
	return current_character

func set_editable(editable: bool) -> void:
	"""Set whether the character sheet allows editing"""
	# This can be extended to show/hide edit buttons
	modulate = Color.WHITE if editable else Color(0.8, 0.8, 0.8, 1.0)

func refresh_display() -> void:
	"""Refresh the current character display"""
	if current_character:
		display_character(current_character)
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
