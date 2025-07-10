extends Control

## Five Parsecs Character Creator UI
## Manual character creation interface with full Five Parsecs rule compliance

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const CharacterCreationTables = preload("res://src/core/character/tables/CharacterCreationTables.gd")
const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const CharacterConnections = preload("res://src/core/character/connections/CharacterConnections.gd")

# UI Components - using safe access to match existing scene structure
@onready var name_input: LineEdit = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/NameSection/NameInput")
@onready var origin_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/OriginSection/OriginOptions")
@onready var background_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/BackgroundSection/BackgroundOptions")
@onready var class_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ClassSection/ClassOptions")
@onready var motivation_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/MotivationSection/MotivationOptions")

# Stat controls - not in current scene, will be null
@onready var reaction_spinner: SpinBox = null
@onready var combat_spinner: SpinBox = null
@onready var toughness_spinner: SpinBox = null
@onready var speed_spinner: SpinBox = null
@onready var savvy_spinner: SpinBox = null
@onready var luck_spinner: SpinBox = null

# Action buttons - using buttons that exist in scene
@onready var generate_random_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/RandomizeButton")
@onready var roll_stats_button: Button = null # Not in current scene
@onready var background_event_button: Button = null # Not in current scene
@onready var generate_equipment_button: Button = null # Not in current scene
@onready var create_character_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/AddToCrewButton")
@onready var cancel_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/BackButton")

# Preview/Info areas - using what exists in scene
@onready var character_preview: Control = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel")
@onready var traits_display: RichTextLabel = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PreviewInfo")
@onready var equipment_display: RichTextLabel = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PreviewInfo")
@onready var validation_label: Label = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ValidationLabel") # Assuming this exists

# State
var current_character: Character = null
var character_equipment: Dictionary = {}

# System dependencies (will be loaded on demand)
var dice_manager: Node = null

signal character_created(character: Character)
signal creation_cancelled()

func _ready() -> void:
	print("CharacterCreator: Initializing...")
	_setup_ui_validation()
	_setup_ui_components()
	_connect_signals()

	# Get singleton dependencies
	dice_manager = get_node_or_null("/root/FPCM_DiceManager")
	if not dice_manager:
		push_error("CharacterCreator: FPCM_DiceManager not found. Random generation will fail.")

	_create_new_character()

func _setup_ui_validation() -> void:
	"""Setup UI validation using Universal Safety System"""
	# Basic validation that required components exist
	if not name_input or not create_character_button:
		push_warning("CharacterCreator: Critical UI components missing")

func _setup_ui_components() -> void:
	"""Setup UI component data and constraints"""
	_setup_option_buttons()
	_setup_stat_spinners()
	_setup_validation_display()

func _setup_option_buttons() -> void:
	"""Setup option button data"""
	# Setup character class options
	if class_options and class_options.get_item_count() == 0:
		_populate_class_options()
	
	# Setup background options
	if background_options and background_options.get_item_count() == 0:
		_populate_background_options()
	
	# Setup motivation options
	if motivation_options and motivation_options.get_item_count() == 0:
		_populate_motivation_options()
	
	# Setup origin options
	if origin_options and origin_options.get_item_count() == 0:
		_populate_origin_options()

func _populate_class_options() -> void:
	"""Populate character class dropdown - Production hardcoded version"""
	class_options.clear()
	class_options.add_item("Soldier", GlobalEnums.CharacterClass.SOLDIER)
	class_options.add_item("Scout", GlobalEnums.CharacterClass.SCOUT)
	class_options.add_item("Medic", GlobalEnums.CharacterClass.MEDIC)
	class_options.add_item("Engineer", GlobalEnums.CharacterClass.ENGINEER)
	class_options.add_item("Pilot", GlobalEnums.CharacterClass.PILOT)
	class_options.add_item("Merchant", GlobalEnums.CharacterClass.MERCHANT)
	class_options.add_item("Security", GlobalEnums.CharacterClass.SECURITY)
	class_options.add_item("Broker", GlobalEnums.CharacterClass.BROKER)

func _populate_background_options() -> void:
	"""Populate background dropdown"""
	var bg_keys: Array = GlobalEnums.Background.keys()
	for bg_name in bg_keys:
		var bg_value = GlobalEnums.Background[bg_name]
		if bg_value != GlobalEnums.Background.NONE:
			background_options.add_item(bg_name.capitalize(), bg_value)

func _populate_motivation_options() -> void:
	"""Populate motivation dropdown"""
	var motivation_keys: Array = GlobalEnums.Motivation.keys()
	for m_name in motivation_keys:
		var m_value = GlobalEnums.Motivation[m_name]
		if m_value != GlobalEnums.Motivation.NONE:
			motivation_options.add_item(m_name.capitalize(), m_value)

func _populate_origin_options() -> void:
	"""Populate origin dropdown"""
	var origin_keys: Array = GlobalEnums.Origin.keys()
	for o_name in origin_keys:
		var o_value = GlobalEnums.Origin[o_name]
		if o_value != GlobalEnums.Origin.NONE:
			origin_options.add_item(o_name.capitalize(), o_value)


func _setup_stat_spinners() -> void:
	"""Setup stat spinner constraints following Five Parsecs rules"""
	var stat_spinners: Array[SpinBox] = [reaction_spinner, combat_spinner, toughness_spinner, speed_spinner, savvy_spinner, luck_spinner]

	for spinner: SpinBox in stat_spinners:
		if spinner:
			spinner.min_value = 1
			spinner.max_value = 6 # Five Parsecs attribute maximum
			spinner.step = 1
			spinner.value = 2 # Default starting value

func _setup_validation_display() -> void:
	"""Setup validation display"""
	if validation_label:
		validation_label.text = "Character validation will appear here"
		validation_label.modulate = Color.GRAY

func _connect_signals() -> void:
	"""Connect remaining UI signals"""
	if origin_options: origin_options.item_selected.connect(_on_ui_changed)
	if background_options: background_options.item_selected.connect(_on_ui_changed)
	if class_options: class_options.item_selected.connect(_on_ui_changed)
	if motivation_options: motivation_options.item_selected.connect(_on_ui_changed)
	if name_input: name_input.text_changed.connect(_on_ui_changed)
	
	if generate_random_button: generate_random_button.pressed.connect(_on_generate_random_pressed)
	if create_character_button: create_character_button.pressed.connect(_on_create_character_pressed)
	if cancel_button: cancel_button.pressed.connect(creation_cancelled.emit)

func _create_new_character() -> void:
	"""Create a new character for editing"""
	current_character = Character.new()
	# Set defaults to avoid null issues, UI will update them
	FiveParsecsCharacterGeneration.generate_character_attributes(current_character)
	_update_ui_from_character()
	_validate_and_update()

func _update_ui_from_character() -> void:
	"""Update UI controls to match current character"""
	if not is_instance_valid(current_character): return
	
	name_input.text = current_character.character_name
	_select_option_by_id(origin_options, current_character.origin)
	_select_option_by_id(background_options, current_character.background)
	_select_option_by_id(class_options, current_character.character_class)
	_select_option_by_id(motivation_options, current_character.motivation)

	_update_character_preview()

func _select_option_by_id(option_button: OptionButton, id: int) -> void:
	if not is_instance_valid(option_button): return
	for i in range(option_button.get_item_count()):
		if option_button.get_item_id(i) == id:
			option_button.select(i)
			return

func _update_character_from_ui() -> void:
	"""Update character data from UI controls"""
	if not is_instance_valid(current_character): return

	current_character.character_name = name_input.text
	current_character.origin = origin_options.get_item_id(origin_options.selected) if origin_options.selected > -1 else GlobalEnums.Origin.HUMAN
	current_character.background = background_options.get_item_id(background_options.selected) if background_options.selected > -1 else GlobalEnums.Background.MILITARY
	current_character.character_class = class_options.get_item_id(class_options.selected) if class_options.selected > -1 else GlobalEnums.CharacterClass.SOLDIER
	current_character.motivation = motivation_options.get_item_id(motivation_options.selected) if motivation_options.selected > -1 else GlobalEnums.Motivation.SURVIVAL

func _update_character_preview() -> void:
	"""Update character preview panel with current stats, traits and equipment."""
	if not traits_display:
		return

	var preview_text := ""
	if not is_instance_valid(current_character):
		traits_display.text = "Create a character to see details."
		return

	preview_text += "[b]Name:[/b] %s\n" % current_character.character_name
	preview_text += "[b]Class:[/b] %s\n" % GlobalEnums.get_character_class_name(current_character.character_class)
	preview_text += "[b]Background:[/b] %s\n\n" % GlobalEnums.get_background_name(current_character.background)
	preview_text += "[b]Stats:[/b]\n"
	preview_text += "  Reaction: %d | Speed: %d\" | Combat: +%d\n" % [current_character.reaction, current_character.speed, current_character.combat]
	preview_text += "  Toughness: %d | Savvy: +%d | Luck: %d\n\n" % [current_character.toughness, current_character.savvy, current_character.luck]

	if not current_character.traits.is_empty():
		preview_text += "[b]Features:[/b]\n"
		for character_feature in current_character.traits:
			preview_text += "  - %s\n" % character_feature
		preview_text += "\n"

	traits_display.text = preview_text

func _validate_and_update() -> void:
	"""Validate character against Five Parsecs rules and update UI"""
	_update_character_from_ui()
	if not is_instance_valid(current_character): return
	
	var result := FiveParsecsCharacterGeneration.validate_character(current_character)
	if validation_label:
		if result.valid:
			validation_label.text = "Character is valid"
			validation_label.modulate = Color.GREEN
			create_character_button.disabled = false
		else:
			validation_label.text = "Errors: " + ", ".join(result.errors)
			validation_label.modulate = Color.RED
			create_character_button.disabled = true
	
	_update_character_preview()

# --- Signal Handlers ---

func _on_ui_changed(_arg) -> void:
	_validate_and_update()

func _on_generate_random_pressed() -> void:
	"""Handle random generation button press"""
	if not dice_manager:
		push_error("CharacterCreator: DiceManager not available for random generation.")
		return
	current_character = FiveParsecsCharacterGeneration.generate_rulebook_compliant_character(dice_manager)
	_update_ui_from_character()
	_validate_and_update()

func _on_create_character_pressed() -> void:
	"""Finalize character creation and emit signal"""
	_validate_and_update()
	if create_character_button.disabled:
		push_warning("CharacterCreator: Attempted to create invalid character.")
		return

	var config := {
		"name": current_character.character_name,
		"class": GlobalEnums.CharacterClass.keys()[current_character.character_class],
		"background": GlobalEnums.Background.keys()[current_character.background],
		"motivation": GlobalEnums.Motivation.keys()[current_character.motivation],
		"origin": GlobalEnums.Origin.keys()[current_character.origin]
	}
	var final_character = FiveParsecsCharacterGeneration.create_enhanced_character(
		config, dice_manager, CharacterCreationTables, StartingEquipmentGenerator, CharacterConnections
	)
	character_created.emit(final_character)
	print("CharacterCreator: Character '%s' created and emitted." % final_character.character_name)

## Safe property access helper
func safe_get_property(obj: Variant, property_name: String, default_value: Variant = null) -> Variant:
	if obj is Object and obj.has_method("get"):
		return obj.get(property_name, default_value)
	if obj is Dictionary and obj.has(property_name):
		return obj[property_name]
	return default_value