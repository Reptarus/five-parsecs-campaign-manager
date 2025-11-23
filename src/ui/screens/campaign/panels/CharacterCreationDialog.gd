extends AcceptDialog

## Enhanced Character Creation Dialog - Full 5-Step Implementation
## Complete character creation with background, motivation, attributes, etc.

signal character_created(character_data: Dictionary)
signal character_updated(character_data: Dictionary)

# UI Components
@onready var step_indicator: Label = $"MainContainer/Header/StepIndicator"
@onready var progress_bar: ProgressBar = $"MainContainer/ProgressBar"
@onready var step_content: Control = $"MainContainer/StepContent"

# Step panels
@onready var step1_basic_info: VBoxContainer = $"MainContainer/StepContent/Step1_BasicInfo"
@onready var step2_attributes: VBoxContainer = $"MainContainer/StepContent/Step2_Attributes"

# Navigation
@onready var previous_button: Button = $"MainContainer/StepNavigation/PreviousButton"
@onready var next_button: Button = $"MainContainer/StepNavigation/NextButton"
@onready var finish_button: Button = $"MainContainer/StepNavigation/FinishButton"
@onready var cancel_button: Button = $"MainContainer/StepNavigation/CancelButton"

# Step 1 controls
@onready var name_input: LineEdit = $"MainContainer/StepContent/Step1_BasicInfo/NameSection/NameInput"
@onready var name_generate_button: Button = $"MainContainer/StepContent/Step1_BasicInfo/NameSection/NameGenerateButton"
@onready var background_option: OptionButton = $"MainContainer/StepContent/Step1_BasicInfo/BackgroundSection/BackgroundOption"
@onready var background_description: Label = $"MainContainer/StepContent/Step1_BasicInfo/BackgroundSection/BackgroundDescription"
@onready var motivation_option: OptionButton = $"MainContainer/StepContent/Step1_BasicInfo/MotivationSection/MotivationOption"
@onready var motivation_description: Label = $"MainContainer/StepContent/Step1_BasicInfo/MotivationSection/MotivationDescription"

# Step 2 controls
@onready var combat_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/CombatValue"
@onready var reaction_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ReactionValue"
@onready var toughness_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ToughnessValue"
@onready var savvy_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/SavvyValue"
@onready var tech_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/TechValue"
@onready var move_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/MoveValue"
@onready var roll_all_button: Button = $"MainContainer/StepContent/Step2_Attributes/AttributeActions/RollAllButton"

# State management
var current_step: int = 0
var total_steps: int = 2  # Currently implementing 2 steps, will expand to 5
var editing_character: Dictionary = {}
var character_data: Dictionary = {}

# Game data
# GlobalEnums available as autoload singleton

func _ready():
	_setup_navigation()
	_setup_step1()
	_setup_step2()
	_show_step(0)

func _setup_navigation():
	"""Setup navigation button connections"""
	if not previous_button.pressed.is_connected(_on_previous_pressed):
		previous_button.pressed.connect(_on_previous_pressed)
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not finish_button.pressed.is_connected(_on_finish_pressed):
		finish_button.pressed.connect(_on_finish_pressed)
	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)

func _setup_step1():
	"""Setup Step 1: Basic Information"""
	# Name generation
	if not name_generate_button.pressed.is_connected(_on_generate_name_pressed):
		name_generate_button.pressed.connect(_on_generate_name_pressed)
	if not name_input.text_changed.is_connected(_on_name_changed):
		name_input.text_changed.connect(_on_name_changed)

	# Setup background options
	background_option.clear()
	_add_background_options()
	background_option.item_selected.connect(_on_background_selected)

	# Setup motivation options  
	motivation_option.clear()
	_add_motivation_options()
	motivation_option.item_selected.connect(_on_motivation_selected)

func _add_background_options():
	"""Add Five Parsecs background options"""
	var backgrounds = [
		{"id": "soldier", "name": "Soldier", "desc": "Military background with combat training and discipline."},
		{"id": "scavenger", "name": "Scavenger", "desc": "Survivor who makes a living from salvage and scraps."},
		{"id": "colonist", "name": "Colonist", "desc": "Frontier settler with practical skills and determination."},
		{"id": "techie", "name": "Techie", "desc": "Technical specialist with advanced knowledge of systems."},
		{"id": "merchant", "name": "Merchant", "desc": "Trader with connections and business acumen."},
		{"id": "pilot", "name": "Pilot", "desc": "Experienced spaceship pilot with navigation skills."}
	]

	for bg in backgrounds:
		background_option.add_item(bg.name, background_option.get_item_count())
		background_option.set_item_metadata(background_option.get_item_count() - 1, bg)

func _add_motivation_options():
	"""Add Five Parsecs motivation options"""
	var motivations = [
		{"id": "revenge", "name": "Revenge", "desc": "Driven by a need to settle old scores."},
		{"id": "glory", "name": "Glory", "desc": "Seeking fame and recognition in the galaxy."},
		{"id": "survival", "name": "Survival", "desc": "Fighting to stay alive in a harsh universe."},
		{"id": "wealth", "name": "Wealth", "desc": "Pursuing riches and financial security."},
		{"id": "freedom", "name": "Freedom", "desc": "Escaping oppression and seeking independence."},
		{"id": "justice", "name": "Justice", "desc": "Upholding what's right in a lawless frontier."}
	]

	for mot in motivations:
		motivation_option.add_item(mot.name, motivation_option.get_item_count())
		motivation_option.set_item_metadata(motivation_option.get_item_count() - 1, mot)

func _setup_step2():
	"""Setup Step 2: Attributes"""
	if not roll_all_button.pressed.is_connected(_on_roll_all_attributes):
		roll_all_button.pressed.connect(_on_roll_all_attributes)

	# Setup individual attribute roll buttons
	var attribute_buttons = [
		$"MainContainer/StepContent/Step2_Attributes/AttributesGrid/CombatRollButton",
		$"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ReactionRollButton",
		$"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ToughnessRollButton",
		$"MainContainer/StepContent/Step2_Attributes/AttributesGrid/SavvyRollButton",
		$"MainContainer/StepContent/Step2_Attributes/AttributesGrid/TechRollButton",
		$"MainContainer/StepContent/Step2_Attributes/AttributesGrid/MoveRollButton"
	]

	var attributes = ["combat", "reactions", "toughness", "savvy", "tech", "move"]

	for i: int in range(attribute_buttons.size()):
		var button: Button = attribute_buttons[i]
		var attribute = attributes[i]
		if button and not button.pressed.is_connected(_on_roll_attribute.bind(attribute)):
			button.pressed.connect(_on_roll_attribute.bind(attribute))

func _show_step(step: int):
	"""Show the specified step"""
	current_step = step

	# Hide all step panels
	for child in step_content.get_children():
		child.visible = false

	# Show current step
	match step:
		0:
			step1_basic_info.visible = true
			step_indicator.text = "Step 1 of %d: Basic Information" % total_steps
		1:
			step2_attributes.visible = true
			step_indicator.text = "Step 2 of %d: Attributes" % total_steps

	# Update progress bar
	progress_bar.value = step + 1

	# Update navigation buttons
	previous_button.disabled = (step == 0)
	next_button.visible = (step < total_steps - 1)
	finish_button.visible = (step == total_steps - 1)

func _on_previous_pressed():
	"""Go to previous step"""
	if current_step > 0:
		_show_step(current_step - 1)

func _on_next_pressed():
	"""Go to next step"""
	if _validate_current_step() and current_step < total_steps - 1:
		_show_step(current_step + 1)

func _on_finish_pressed():
	"""Finish character creation"""
	if _validate_all_steps():
		_create_character()

func _on_cancel_pressed():
	"""Cancel character creation"""
	hide()

func _validate_current_step() -> bool:
	"""Validate current step data"""
	match current_step:
		0:
			return _validate_basic_info()
		1:
			return _validate_attributes()
		_:
			return true

func _validate_basic_info() -> bool:
	"""Validate Step 1: Basic Information"""
	if name_input.text.strip_edges().is_empty():
		_show_error("Character name is required")
		return false

	if background_option.selected == -1:
		_show_error("Please select a background")
		return false

	if motivation_option.selected == -1:
		_show_error("Please select a motivation")
		return false

	return true

func _validate_attributes() -> bool:
	"""Validate Step 2: Attributes"""
	var attributes = ["combat", "reactions", "toughness", "savvy", "tech", "move"]
	for attr in attributes:	
		if character_data.get(attr, 0) < 1:
			_show_error("All attributes must be rolled")
			return false
	return true

func _validate_all_steps() -> bool:
	"""Validate all steps"""
	for step: int in range(total_steps):
		var old_step = current_step
		current_step = step
		if not _validate_current_step():
			current_step = old_step
			return false
		current_step = old_step
	return true

func _show_error(message: String):
	"""Show error dialog"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Validation Error"
	get_parent().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

# Step 1 Signal Handlers
func _on_name_changed(new_text: String):
	"""Handle name input change"""
	character_data.name = new_text

func _on_generate_name_pressed():
	"""Generate random character name"""
	var names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake", "Jamie", "Sage", "River"]
	var name = names[randi() % names.size()]
	name_input.text = name
	character_data.name = name

func _on_background_selected(index: int):
	"""Handle background selection"""
	if index >= 0 and index < background_option.get_item_count():
		var bg_data = background_option.get_item_metadata(index)
		character_data.background = bg_data.id
		background_description.text = bg_data.desc

func _on_motivation_selected(index: int):
	"""Handle motivation selection"""
	if index >= 0 and index < motivation_option.get_item_count():
		var mot_data = motivation_option.get_item_metadata(index)
		character_data.motivation = mot_data.id
		motivation_description.text = mot_data.desc

# Step 2 Signal Handlers
func _on_roll_all_attributes():
	"""Roll all character attributes using Five Parsecs 2d6/3 system"""
	character_data["combat"] = _roll_attribute_value()
	character_data["reactions"] = _roll_attribute_value()
	character_data["toughness"] = _roll_attribute_value()
	character_data["savvy"] = _roll_attribute_value()
	character_data["tech"] = _roll_attribute_value()
	character_data["move"] = _roll_attribute_value()

	_update_attribute_display()

func _on_roll_attribute(attribute: String):
	"""Roll individual attribute"""
	character_data[attribute] = _roll_attribute_value()
	_update_attribute_display()

func _roll_attribute_value() -> int:
	"""Roll attribute using Five Parsecs 2d6 / 3.0 system"""
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	return ceili(float(roll) / 3.0)

func _update_attribute_display():
	"""Update attribute value displays"""
	if combat_value:
		combat_value.text = str(character_data.get("combat", 2))
	if reaction_value:
		reaction_value.text = str(character_data.get("reactions", 2))
	if toughness_value:
		toughness_value.text = str(character_data.get("toughness", 2))
	if savvy_value:
		savvy_value.text = str(character_data.get("savvy", 2))
	if tech_value:
		tech_value.text = str(character_data.get("tech", 2))
	if move_value:
		move_value.text = str(character_data.get("move", 2))

func _create_character():
	"""Create final character data matching Character.serialize() format"""
	# Generate unique character ID
	var char_id: String = "char_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

	# Get background and motivation as uppercase strings for enum compatibility
	var bg_raw: String = character_data.get("background", "soldier")
	var mot_raw: String = character_data.get("motivation", "survival")
	var background_str: String = bg_raw.to_upper() if bg_raw else "COLONIST"
	var motivation_str: String = mot_raw.to_upper() if mot_raw else "SURVIVAL"

	# Determine character class from background
	var char_class: String = _determine_class_from_background(background_str)

	# Determine origin (default to HUMAN, can be expanded later)
	var origin_str: String = "HUMAN"

	# Get attribute values
	var combat_val: int = character_data.get("combat", 3)
	var reactions_val: int = character_data.get("reactions", character_data.get("reaction", 2))
	var toughness_val: int = character_data.get("toughness", 3)
	var savvy_val: int = character_data.get("savvy", 2)
	var tech_val: int = character_data.get("tech", 2)
	var move_val: int = character_data.get("move", 4)

	# Complete character data matching Character.serialize() format
	var final_character: Dictionary = {
		# Identity
		"type": "Character",
		"version": "2.0",
		"character_id": char_id,
		"name": character_data.get("name", "Unnamed"),
		"character_name": character_data.get("name", "Unnamed"),

		# Character creation properties
		"background": background_str,
		"motivation": motivation_str,
		"origin": origin_str,
		"character_class": char_class,

		# Core stats (both flat and nested for compatibility)
		"combat": combat_val,
		"reactions": reactions_val,
		"toughness": toughness_val,
		"savvy": savvy_val,
		"tech": tech_val,
		"move": move_val,
		"speed": move_val,
		"luck": 1,

		# Nested stats for Character.serialize() compatibility
		"stats": {
			"combat": combat_val,
			"reactions": reactions_val,
			"toughness": toughness_val,
			"savvy": savvy_val,
			"tech": tech_val,
			"move": move_val
		},

		# Health (calculated from toughness + 2)
		"health": toughness_val + 2,
		"max_health": toughness_val + 2,

		# Character state
		"experience": 0,
		"credits": 0,
		"equipment": [],
		"is_captain": false,
		"status": "ACTIVE",

		# Metadata
		"created_at": Time.get_datetime_string_from_system(),
		"serialization_version": "enhanced_v2"
	}

	character_created.emit(final_character)
	hide()

func _determine_class_from_background(background: String) -> String:
	"""Determine character class based on background"""
	match background:
		"SOLDIER", "MILITARY":
			return "SOLDIER"
		"SCAVENGER", "CRIMINAL":
			return "SCAVENGER"
		"COLONIST":
			return "COLONIST"
		"TECHIE", "ACADEMIC":
			return "ENGINEER"
		"MERCHANT":
			return "MERCHANT"
		"PILOT":
			return "PILOT"
		_:
			return "BASELINE"

func setup_for_editing(character_data: Dictionary):
	"""Setup dialog for editing existing character"""
	editing_character = character_data.duplicate()

	# Populate fields with existing data
	if name_input:
		name_input.text = character_data.get("name", "")

	# Set background if it exists
	var bg = character_data.get("background", "")
	for i: int in range(background_option.get_item_count()):
		var bg_data = background_option.get_item_metadata(i)
		if bg_data and bg_data.id == bg:
			background_option.select(i)
			_on_background_selected(i)
			break

	# Set motivation if it exists
	var mot = character_data.get("motivation", "")
	for i: int in range(motivation_option.get_item_count()):
		var mot_data = motivation_option.get_item_metadata(i)
		if mot_data and mot_data.id == mot:
			motivation_option.select(i)
			_on_motivation_selected(i)
			break

	# Set attributes
	self.character_data = character_data.duplicate()
	_update_attribute_display()

func _initialize_character_data():
	"""Initialize with default values"""
	if character_data.is_empty():
		character_data = {
			"name": "",
			"background": "",
			"motivation": "",
			"combat": 2,
			"reactions": 2,
			"toughness": 2,
			"savvy": 2,
			"tech": 2,
			"move": 2
		}
		_update_attribute_display()
