extends Control
class_name CharacterCreatorUI

## Five Parsecs Character Creator UI - Unified Implementation
## Manual character creation interface with full Five Parsecs rule compliance
## Enhanced with hybrid data architecture integration and BaseCharacterCreationSystem
## Consolidates features from CharacterCreatorUI and CharacterCreatorEnhanced

# Safe imports
const BaseCharacterCreationSystem = preload("res://src/base/character/BaseCharacterCreationSystem.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const CharacterCreationTables = preload("res://src/core/character/tables/CharacterCreationTables.gd")
const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const CharacterConnections = preload("res://src/core/character/connections/CharacterConnections.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# UI Components - using safe access to match existing scene structure
@onready var name_input: LineEdit = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/NameSection/NameInput")
@onready var origin_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/OriginSection/OriginOptions")
@onready var background_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/BackgroundSection/BackgroundOptions")
@onready var class_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ClassSection/ClassOptions")
@onready var motivation_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/MotivationSection/MotivationOptions")

# Portrait management
@onready var portrait_dialog: FileDialog = get_node_or_null("PortraitDialog")
@onready var portrait_display: TextureRect = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PortraitSection/PortraitContainer/PortraitDisplay")
@onready var portrait_placeholder: Label = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PortraitSection/PortraitContainer/PlaceholderLabel")
@onready var select_portrait_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PortraitSection/PortraitControls/SelectPortraitButton")
@onready var clear_portrait_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PortraitSection/PortraitControls/ClearPortraitButton")
@onready var export_portrait_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PortraitSection/PortraitControls/ExportPortraitButton")

# Stat controls - not in current scene, will be null
@onready var reaction_spinner: SpinBox = null
@onready var combat_spinner: SpinBox = null
@onready var toughness_spinner: SpinBox = null
@onready var speed_spinner: SpinBox = null
@onready var savvy_spinner: SpinBox = null
@onready var luck_spinner: SpinBox = null

# Action buttons - using buttons that exist in scene
@onready var generate_random_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/RandomizeButton")
@onready var clear_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/ClearButton")
@onready var roll_stats_button: Button = null # Not in current scene
@onready var background_event_button: Button = null # Not in current scene
@onready var generate_equipment_button: Button = null # Not in current scene
@onready var create_character_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/AddToCrewButton")
@onready var cancel_button: Button = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ButtonSection/BackButton")

# Preview/Info areas - using what exists in scene
@onready var character_preview: Control = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel")
@onready var traits_display: RichTextLabel = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PreviewInfo")
@onready var equipment_display: RichTextLabel = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PreviewInfo")
@onready var validation_label: Label = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ValidationSection/ValidationLabel")

# Character creation system (handles all logic)
var creation_system: BaseCharacterCreationSystem = null

# State (managed by creation system)
var character_equipment: Dictionary = {}
var current_portrait_path: String = ""
var portrait_texture: Texture2D = null

# System dependencies (will be loaded on demand)
var dice_manager: Node = null

signal character_created(character: Character)
signal character_updated(character: Character)
signal creation_cancelled()
signal portrait_loaded(path: String)
signal portrait_cleared()
signal portrait_exported(path: String)

func _ready() -> void:
	print("CharacterCreator: Initializing unified character creator with BaseCharacterCreationSystem...")
	
	# Initialize creation system
	creation_system = BaseCharacterCreationSystem.new()
	_connect_creation_system_signals()
	
	_setup_ui_validation()
	_setup_ui_components()
	_connect_signals()

	# Get singleton dependencies
	dice_manager = get_node_or_null("/root/DiceManager")
	if not dice_manager:
		push_error("CharacterCreator: DiceManager not found. Random generation will fail.")

	# Start character creation
	var current_character = creation_system.get_current_character()
	if not current_character:
		creation_system.start_creation(BaseCharacterCreationSystem.CreationMode.STANDARD)
	
	_update_ui_from_character()
	_update_portrait_preview() # Initialize portrait display state

func _connect_creation_system_signals() -> void:
	"""Connect to creation system signals"""
	if creation_system:
		creation_system.character_created.connect(_on_system_character_created)
		creation_system.character_updated.connect(_on_system_character_updated)
		creation_system.creation_cancelled.connect(_on_system_creation_cancelled)
		creation_system.validation_failed.connect(_on_system_validation_failed)

func _exit_tree() -> void:
	"""Clean up signal connections when exiting"""
	_disconnect_all_signals()
	print("CharacterCreator: Cleaned up signal connections")

func _initialize_editing_mode() -> void:
	"""Initialize editing mode after _ready() completes"""
	print("CharacterCreator: Initializing editing mode for: ", current_character.character_name if current_character else "Unknown")
	_update_ui_from_character()
	_validate_and_update()

func _setup_ui_validation() -> void:
	"""Setup UI validation using Universal Safety System"""
	# Basic validation that required components exist
	if not name_input or not create_character_button:
		push_warning("CharacterCreator: Critical UI components missing")

func _setup_ui_components() -> void:
	"""Setup UI component data and constraints with hybrid data architecture"""
	_setup_option_buttons_enhanced()
	_setup_stat_spinners()
	_setup_validation_display()

func _setup_option_buttons_enhanced() -> void:
	"""Setup option button data using BaseCharacterCreationSystem with enhanced data"""
	# Setup origin options first (most fundamental choice)
	if origin_options:
		_populate_origin_options_enhanced()
	
	# Setup background options
	if background_options:
		_populate_background_options_enhanced()
	
	# Setup character class options
	if class_options:
		_populate_class_options_enhanced()
	
	# Setup motivation options
	if motivation_options:
		_populate_motivation_options_enhanced()

func _populate_origin_options_enhanced() -> void:
	"""Populate origin dropdown using BaseCharacterCreationSystem data"""
	if not origin_options or not creation_system:
		return
		
	origin_options.clear()
	
	# Get enhanced origin data from creation system
	var origins_data = creation_system.get_available_origins()
	for origin_data in origins_data:
		var display_name = origin_data.get("name", "Unknown")
		var tooltip_text = origin_data.get("description", "")
		var enum_id = origin_data.get("id", -1)
		
		if enum_id >= 0:
			origin_options.add_item(display_name, enum_id)
			# Set tooltip if available
			if not tooltip_text.is_empty():
				var item_count = origin_options.get_item_count()
				origin_options.set_item_tooltip(item_count - 1, tooltip_text)
	
	print("CharacterCreator: Populated %d origin options with enhanced data" % origin_options.get_item_count())
		{"id": GlobalEnums.Origin.SOULLESS, "name": "Soulless"},
		{"id": GlobalEnums.Origin.PRECURSOR, "name": "Precursor"},
		{"id": GlobalEnums.Origin.FERAL, "name": "Feral"},
		{"id": GlobalEnums.Origin.SWIFT, "name": "Swift"},
		{"id": GlobalEnums.Origin.BOT, "name": "Bot"},
		{"id": GlobalEnums.Origin.CORE_WORLDS, "name": "Core Worlds"},
		{"id": GlobalEnums.Origin.FRONTIER, "name": "Frontier"},
		{"id": GlobalEnums.Origin.DEEP_SPACE, "name": "Deep Space"},
		{"id": GlobalEnums.Origin.COLONY, "name": "Colony"},
		{"id": GlobalEnums.Origin.HIVE_WORLD, "name": "Hive World"},
		{"id": GlobalEnums.Origin.FORGE_WORLD, "name": "Forge World"}
	]
	
	for origin_data in all_origins:
		origin_options.add_item(origin_data.name, origin_data.id)
	
	print("CharacterCreator: Populated %d origin options (complete set)" % origin_options.get_item_count())

func _populate_background_options_enhanced() -> void:
	"""Populate background dropdown using BaseCharacterCreationSystem data"""
	if not background_options or not creation_system:
		return
		
	background_options.clear()
	
	# Get enhanced background data from creation system
	var backgrounds_data = creation_system.get_available_backgrounds()
	for background_data in backgrounds_data:
		var display_name = background_data.get("name", "Unknown")
		var tooltip_text = background_data.get("description", "")
		var enum_id = background_data.get("id", -1)
		
		if enum_id >= 0:
			background_options.add_item(display_name, enum_id)
			# Set tooltip if available
			if not tooltip_text.is_empty():
				var item_count = background_options.get_item_count()
				background_options.set_item_tooltip(item_count - 1, tooltip_text)
	
	print("CharacterCreator: Populated %d background options with enhanced data" % background_options.get_item_count())

func _populate_class_options_enhanced() -> void:
	"""Populate character class dropdown using BaseCharacterCreationSystem data"""
	if not class_options or not creation_system:
		return
		
	class_options.clear()
	
	# Get enhanced class data from creation system
	var classes_data = creation_system.get_available_classes()
	for class_data in classes_data:
		var display_name = class_data.get("name", "Unknown")
		var tooltip_text = class_data.get("description", "")
		var enum_id = class_data.get("id", -1)
		
		if enum_id >= 0:
			class_options.add_item(display_name, enum_id)
			# Set tooltip if available
			if not tooltip_text.is_empty():
				var item_count = class_options.get_item_count()
				class_options.set_item_tooltip(item_count - 1, tooltip_text)
	
	print("CharacterCreator: Populated %d class options with enhanced data" % class_options.get_item_count())

func _populate_motivation_options_enhanced() -> void:
	"""Populate motivation dropdown using BaseCharacterCreationSystem data"""
	if not motivation_options or not creation_system:
		return
		
	motivation_options.clear()
	
	# Get enhanced motivation data from creation system
	var motivations_data = creation_system.get_available_motivations()
	for motivation_data in motivations_data:
		var display_name = motivation_data.get("name", "Unknown")
		var tooltip_text = motivation_data.get("description", "")
		var enum_id = motivation_data.get("id", -1)
		
		if enum_id >= 0:
			motivation_options.add_item(display_name, enum_id)
			# Set tooltip if available
			if not tooltip_text.is_empty():
				var item_count = motivation_options.get_item_count()
				motivation_options.set_item_tooltip(item_count - 1, tooltip_text)
	
	print("CharacterCreator: Populated %d motivation options with enhanced data" % motivation_options.get_item_count())

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
	"""Connect UI signals with proper type safety and duplicate prevention"""
	# Disconnect any existing connections first to prevent duplicates
	_disconnect_all_signals()
	
	# Connect dropdown changes - these emit item_selected(int)
	if origin_options and not origin_options.item_selected.is_connected(_on_origin_changed):
		origin_options.item_selected.connect(_on_origin_changed)
	if background_options and not background_options.item_selected.is_connected(_on_background_changed):
		background_options.item_selected.connect(_on_background_changed)
	if class_options and not class_options.item_selected.is_connected(_on_class_changed):
		class_options.item_selected.connect(_on_class_changed)
	if motivation_options and not motivation_options.item_selected.is_connected(_on_motivation_changed):
		motivation_options.item_selected.connect(_on_motivation_changed)
	
	# Connect text input - this emits text_changed(String)
	if name_input and not name_input.text_changed.is_connected(_on_name_changed):
		name_input.text_changed.connect(_on_name_changed)
	
	# Connect action buttons
	if generate_random_button and not generate_random_button.pressed.is_connected(_on_generate_random_pressed):
		generate_random_button.pressed.connect(_on_generate_random_pressed)
	if clear_button and not clear_button.pressed.is_connected(_on_clear_character_pressed):
		clear_button.pressed.connect(_on_clear_character_pressed)
	if create_character_button and not create_character_button.pressed.is_connected(_on_create_character_pressed):
		create_character_button.pressed.connect(_on_create_character_pressed)
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_button_pressed):
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# Connect portrait dialog
	if portrait_dialog:
		if not portrait_dialog.file_selected.is_connected(_on_portrait_selected):
			portrait_dialog.file_selected.connect(_on_portrait_selected)
		if not portrait_dialog.canceled.is_connected(_on_portrait_cancelled):
			portrait_dialog.canceled.connect(_on_portrait_cancelled)
	
	# Connect portrait control buttons
	if select_portrait_button and not select_portrait_button.pressed.is_connected(_on_portrait_button_clicked):
		select_portrait_button.pressed.connect(_on_portrait_button_clicked)
	if clear_portrait_button and not clear_portrait_button.pressed.is_connected(_on_clear_portrait_pressed):
		clear_portrait_button.pressed.connect(_on_clear_portrait_pressed)
	if export_portrait_button and not export_portrait_button.pressed.is_connected(_on_export_portrait_pressed):
		export_portrait_button.pressed.connect(_on_export_portrait_pressed)
	
	# Connect RichTextLabel URL signals for legacy portrait link
	if traits_display and not traits_display.meta_clicked.is_connected(_on_preview_meta_clicked):
		traits_display.meta_clicked.connect(_on_preview_meta_clicked)

func _disconnect_all_signals() -> void:
	"""Safely disconnect all signals to prevent duplicate connections"""
	if origin_options and origin_options.item_selected.is_connected(_on_origin_changed):
		origin_options.item_selected.disconnect(_on_origin_changed)
	if background_options and background_options.item_selected.is_connected(_on_background_changed):
		background_options.item_selected.disconnect(_on_background_changed)
	if class_options and class_options.item_selected.is_connected(_on_class_changed):
		class_options.item_selected.disconnect(_on_class_changed)
	if motivation_options and motivation_options.item_selected.is_connected(_on_motivation_changed):
		motivation_options.item_selected.disconnect(_on_motivation_changed)
	if name_input and name_input.text_changed.is_connected(_on_name_changed):
		name_input.text_changed.disconnect(_on_name_changed)

## Portrait Management Functions

func _on_portrait_button_clicked() -> void:
	"""Handle portrait selection button click"""
	if portrait_dialog:
		portrait_dialog.popup_centered()
	else:
		push_error("CharacterCreator: Portrait dialog not found")

func _on_portrait_selected(path: String) -> void:
	"""Handle portrait file selection"""
	if not _validate_portrait_file(path):
		_show_portrait_error("Invalid portrait file. Please select a PNG, JPG, or JPEG image.")
		return
	
	# Load and process the image
	var success = _load_and_process_portrait(path)
	if success:
		current_portrait_path = path
		_update_portrait_preview()
		portrait_loaded.emit(path)
		print("CharacterCreator: Portrait loaded successfully: ", path)
	else:
		_show_portrait_error("Failed to load portrait. Please try a different image.")

func _on_portrait_cancelled() -> void:
	"""Handle portrait selection cancellation"""
	print("CharacterCreator: Portrait selection cancelled")

func _validate_portrait_file(path: String) -> bool:
	"""Validate that the selected file is a valid portrait image"""
	if not FileAccess.file_exists(path):
		return false
	
	# Check file extension
	var valid_extensions = ["png", "jpg", "jpeg"]
	var file_extension = path.get_extension().to_lower()
	if not valid_extensions.has(file_extension):
		return false
	
	# Check file size (max 10MB)
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	
	var file_size = file.get_length()
	file.close()
	
	if file_size > 10 * 1024 * 1024: # 10MB limit
		return false
	
	return true

func _load_and_process_portrait(path: String) -> bool:
	"""Load and process portrait image with validation and resizing"""
	var image = Image.new()
	var err = image.load(path)
	
	if err != OK:
		push_error("CharacterCreator: Failed to load image: ", path)
		return false
	
	# Validate image dimensions
	var max_size = 512
	var min_size = 64
	
	if image.get_width() < min_size or image.get_height() < min_size:
		push_warning("CharacterCreator: Image too small, minimum size is %dx%d" % [min_size, min_size])
		return false
	
	# Resize if too large
	if image.get_width() > max_size or image.get_height() > max_size:
		image.resize(max_size, max_size, Image.INTERPOLATE_LANCZOS)
		print("CharacterCreator: Resized portrait to %dx%d" % [image.get_width(), image.get_height()])
	
	# Convert to texture
	portrait_texture = ImageTexture.create_from_image(image)
	
	return true

func _update_portrait_preview() -> void:
	"""Update the portrait preview in the UI"""
	if not portrait_display or not portrait_placeholder:
		return
	
	if portrait_texture:
		portrait_display.texture = portrait_texture
		portrait_display.modulate = Color.WHITE
		portrait_placeholder.visible = false
		# Enable control buttons
		if clear_portrait_button:
			clear_portrait_button.disabled = false
		if export_portrait_button:
			export_portrait_button.disabled = false
	else:
		# Show placeholder
		portrait_display.texture = null
		portrait_display.modulate = Color.GRAY
		portrait_placeholder.visible = true
		# Disable control buttons
		if clear_portrait_button:
			clear_portrait_button.disabled = true
		if export_portrait_button:
			export_portrait_button.disabled = true

func _show_portrait_error(message: String) -> void:
	"""Show portrait-related error message"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Portrait Error"
	get_viewport().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

func export_portrait(character_name: String) -> String:
	"""Export portrait to user directory with proper naming"""
	if not portrait_texture or current_portrait_path.is_empty():
		return ""
	
	# Create portraits directory if it doesn't exist
	var portraits_dir = "user://portraits/"
	if not DirAccess.dir_exists_absolute(portraits_dir):
		DirAccess.make_dir_recursive_absolute(portraits_dir)
	
	# Generate safe filename
	var safe_name = character_name.to_lower().replace(" ", "_").replace("/", "_").replace("\\", "_")
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename = "%s_portrait_%s.png" % [safe_name, timestamp]
	var export_path = portraits_dir + filename
	
	# Save the image
	var image = portrait_texture.get_image()
	var err = image.save_png(export_path)
	
	if err == OK:
		portrait_exported.emit(export_path)
		print("CharacterCreator: Portrait exported to: ", export_path)
		return export_path
	else:
		push_error("CharacterCreator: Failed to export portrait: ", export_path)
		return ""

func clear_portrait() -> void:
	"""Clear the current portrait"""
	current_portrait_path = ""
	portrait_texture = null
	_update_portrait_preview()
	portrait_cleared.emit()
	print("CharacterCreator: Portrait cleared")

func _create_new_character() -> void:
	"""Create a new character for editing with proper Five Parsecs defaults"""
	current_character = Character.new()
	is_editing_mode = false
	original_character = null
	
	# Set proper Five Parsecs default values
	current_character.character_name = "New Character"
	current_character.origin = GlobalEnums.Origin.HUMAN
	current_character.background = GlobalEnums.Background.MILITARY
	current_character.character_class = GlobalEnums.CharacterClass.SOLDIER
	current_character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Generate base attributes using Five Parsecs rules (includes health calculation)
	FiveParsecsCharacterGeneration.generate_character_attributes(current_character)
	
	# Apply default bonuses
	FiveParsecsCharacterGeneration.apply_background_bonuses(current_character)
	FiveParsecsCharacterGeneration.apply_class_bonuses(current_character)
	FiveParsecsCharacterGeneration.set_character_flags(current_character)
	
	# Update UI to match character
	_update_ui_from_character()
	_validate_and_update()

## NEW: Character Editing Functionality
func set_character_for_editing(character: Character) -> void:
	"""Initialize the creator for editing an existing character"""
	if not character or not is_instance_valid(character):
		push_error("CharacterCreator: Invalid character provided for editing")
		_create_new_character() # Fallback to new character
		return
	
	print("CharacterCreator: Setting up character for editing: ", character.character_name)
	
	# Store original character state for cancel functionality
	original_character = character.duplicate()
	current_character = character
	is_editing_mode = true
	
	# Load character's portrait if it exists
	var portrait_path = safe_get_property(character, "portrait_path", "")
	if portrait_path and not portrait_path.is_empty():
		current_portrait_path = portrait_path
	
	# Don't update UI immediately - let _ready() complete first
	# UI update will happen in _initialize_editing_mode() via call_deferred
	
	print("CharacterCreator: Character editing setup complete, waiting for scene ready")

func _load_existing_portrait(portrait_path: String) -> void:
	"""Load existing character portrait"""
	if not portrait_path or portrait_path.is_empty():
		return
	
	# Check if the portrait file still exists
	if not FileAccess.file_exists(portrait_path):
		push_warning("CharacterCreator: Portrait file not found: ", portrait_path)
		return
	
	# Load the existing portrait
	if _load_and_process_portrait(portrait_path):
		current_portrait_path = portrait_path
		_update_portrait_preview()
		print("CharacterCreator: Loaded existing portrait: ", portrait_path)
	else:
		push_warning("CharacterCreator: Failed to load existing portrait: ", portrait_path)

func _update_ui_from_character() -> void:
	"""Update UI controls to match current character from creation system"""
	if not creation_system:
		print("CharacterCreator: Cannot update UI - creation system not available")
		return
	
	var current_character = creation_system.get_current_character()
	if not is_instance_valid(current_character):
		print("CharacterCreator: Cannot update UI - invalid character from creation system")
		return
	
	# Safety check - ensure all UI components are ready
	if not name_input or not origin_options or not background_options or not class_options or not motivation_options:
		print("CharacterCreator: UI components not ready, skipping update")
		return
	
	print("CharacterCreator: Updating UI from character: ", current_character.character_name)
	print("  Character state being applied to UI:")
	print("    Origin: ID %d" % current_character.origin)
	print("    Background: ID %d" % current_character.background)
	print("    Class: ID %d" % current_character.character_class)
	print("    Motivation: ID %d" % current_character.motivation)
	
	# Update input fields safely
	if name_input:
		name_input.text = current_character.character_name if current_character.character_name else ""
	
	if origin_options:
		_select_option_by_id(origin_options, current_character.origin)
		print("    UI Origin selection: %d" % origin_options.selected)
	
	if background_options:
		_select_option_by_id(background_options, current_character.background)
		print("    UI Background selection: %d" % background_options.selected)
	
	if class_options:
		_select_option_by_id(class_options, current_character.character_class)
		print("    UI Class selection: %d" % class_options.selected)
	
	if motivation_options:
		_select_option_by_id(motivation_options, current_character.motivation)
		print("    UI Motivation selection: %d" % motivation_options.selected)

	# Update button text for editing mode
	if is_editing_mode and create_character_button:
		create_character_button.text = "Update Character"

	_update_character_preview()

func _select_option_by_id(option_button: OptionButton, id: int) -> void:
	if not is_instance_valid(option_button):
		print("CharacterCreator: Invalid option button for selection")
		return
	for i in range(option_button.get_item_count()):
		if option_button.get_item_id(i) == id:
			option_button.select(i)
			print("CharacterCreator: Selected option %d with ID %d" % [i, id])
			return
	print("CharacterCreator: Could not find option with ID %d" % id)

func _update_character_from_ui() -> void:
	"""Update character data from UI controls"""
	if not is_instance_valid(current_character):
		print("CharacterCreator: Cannot update character - invalid character")
		return

	# Safety check - ensure all UI components are ready
	if not name_input or not origin_options or not background_options or not class_options or not motivation_options:
		print("CharacterCreator: UI components not ready, skipping character update")
		return

	print("CharacterCreator: Updating character from UI")

	# Update character properties safely
	if name_input:
		current_character.character_name = name_input.text
	
	if origin_options and origin_options.selected > -1:
		current_character.origin = origin_options.get_item_id(origin_options.selected)
	else:
		current_character.origin = GlobalEnums.Origin.HUMAN
	
	if background_options and background_options.selected > -1:
		current_character.background = background_options.get_item_id(background_options.selected)
	else:
		current_character.background = GlobalEnums.Background.MILITARY
	
	if class_options and class_options.selected > -1:
		current_character.character_class = class_options.get_item_id(class_options.selected)
	else:
		current_character.character_class = GlobalEnums.CharacterClass.SOLDIER
	
	if motivation_options and motivation_options.selected > -1:
		current_character.motivation = motivation_options.get_item_id(motivation_options.selected)
	else:
		current_character.motivation = GlobalEnums.Motivation.SURVIVAL

# Original _update_character_preview function removed - replaced with enhanced version below

func _validate_and_update() -> void:
	"""Validate character against Five Parsecs rules and update UI"""
	# Remove _update_character_from_ui() call since signal handlers already update character properties
	if not is_instance_valid(current_character): return
	
	var result: Dictionary = FiveParsecsCharacterGeneration.validate_character(current_character)
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

## Specific UI change handlers with proper character regeneration
func _on_name_changed(new_text: String) -> void:
	"""Handle character name changes using creation system"""
	if not creation_system:
		return
	creation_system.set_character_name(new_text)
	_validate_and_update()

func _on_origin_changed(index: int) -> void:
	"""Handle origin selection changes using creation system"""
	if not origin_options or index < 0 or not creation_system:
		return
	var origin_id = origin_options.get_item_id(index)
	creation_system.set_character_origin(origin_id)
	print("CharacterCreator: Origin changed to ID: %d" % origin_id)
	_update_ui_from_character()
	_validate_and_update()

func _on_background_changed(index: int) -> void:
	"""Handle background selection changes using creation system"""
	if not background_options or index < 0 or not creation_system:
		return
	var background_id = background_options.get_item_id(index)
	creation_system.set_character_background(background_id)
	print("CharacterCreator: Background changed to ID: %d" % background_id)
	_update_ui_from_character()
	_validate_and_update()

func _on_class_changed(index: int) -> void:
	"""Handle class selection changes using creation system"""
	if not class_options or index < 0 or not creation_system:
		return
	var class_id = class_options.get_item_id(index)
	creation_system.set_character_class(class_id)
	print("CharacterCreator: Class changed to ID: %d" % class_id)
	_update_ui_from_character()
	_validate_and_update()

func _on_motivation_changed(index: int) -> void:
	"""Handle motivation selection changes using creation system"""
	if not motivation_options or index < 0 or not creation_system:
		return
	var motivation_id = motivation_options.get_item_id(index)
	creation_system.set_character_motivation(motivation_id)
	print("CharacterCreator: Motivation changed to ID: %d" % motivation_id)
	_update_ui_from_character()
	_validate_and_update()

## Creation system signal handlers
func _on_system_character_created(character: Character) -> void:
	"""Handle character created from creation system"""
	print("CharacterCreator: Character created by system: %s" % character.character_name)
	character_created.emit(character)

func _on_system_character_updated(character: Character) -> void:
	"""Handle character updated from creation system"""
	print("CharacterCreator: Character updated by system: %s" % character.character_name)
	character_updated.emit(character)
	_update_ui_from_character()

func _on_system_creation_cancelled() -> void:
	"""Handle creation cancelled from creation system"""
	print("CharacterCreator: Creation cancelled by system")
	creation_cancelled.emit()

func _on_system_validation_failed(errors: Array[String]) -> void:
	"""Handle validation failed from creation system"""
	print("CharacterCreator: Validation failed: %s" % str(errors))
	if validation_label:
		validation_label.text = "Validation errors: " + ", ".join(errors)
		validation_label.modulate = Color.RED

## Character regeneration logic
## Enhanced Character Generation with Rich JSON Data
func _regenerate_character_attributes() -> void:
	"""Regenerate character attributes using Five Parsecs rules"""
	if not is_instance_valid(current_character):
		return
	
	print("CharacterCreator: Regenerating character attributes")
	
	# Clear existing traits to prevent accumulation
	current_character.traits.clear()
	
	# Generate base attributes using Five Parsecs rules (includes health calculation)
	FiveParsecsCharacterGeneration.generate_character_attributes(current_character)
	
	# Apply background bonuses
	FiveParsecsCharacterGeneration.apply_background_bonuses(current_character)
	
	# Apply class bonuses
	FiveParsecsCharacterGeneration.apply_class_bonuses(current_character)
	
	# Apply origin effects
	FiveParsecsCharacterGeneration.set_character_flags(current_character)
	
	print("CharacterCreator: Character attributes regenerated - Health: %d, Toughness: %d" % [current_character.max_health, current_character.toughness])

func _apply_stat_bonus(stat_name: String, bonus: int) -> void:
	"""Apply stat bonus using correct property mapping"""
	match stat_name.to_lower():
		"combat", "combat_skill":
			current_character.combat = clampi(current_character.combat + bonus, 0, 3)
		"reactions", "reaction":
			current_character.reaction = clampi(current_character.reaction + bonus, 1, 6)
		"toughness":
			current_character.toughness = clampi(current_character.toughness + bonus, 1, 6)
		"speed":
			current_character.speed = clampi(current_character.speed + bonus, 4, 8)
		"savvy":
			current_character.savvy = clampi(current_character.savvy + bonus, 0, 3)

## Enhanced Character Preview with Rich Data
func _update_character_preview() -> void:
	"""Update character preview with proper Five Parsecs enum values"""
	if not traits_display:
		return

	var preview_text := ""
	if not is_instance_valid(current_character):
		traits_display.text = "Create a character to see details."
		return

	# Use proper Five Parsecs enum display names
	var character_class_name = GlobalEnums.get_class_display_name(current_character.character_class)
	var background_name = GlobalEnums.get_background_display_name(current_character.background)
	var origin_name = GlobalEnums.get_origin_display_name(current_character.origin)
	var motivation_name = GlobalEnums.get_motivation_display_name(current_character.motivation)

	preview_text += "[b]Name:[/b] %s\n" % current_character.character_name
	preview_text += "[b]Class:[/b] %s\n" % character_class_name
	preview_text += "[b]Background:[/b] %s\n" % background_name
	preview_text += "[b]Origin:[/b] %s\n" % origin_name
	preview_text += "[b]Motivation:[/b] %s\n\n" % motivation_name
	
	preview_text += "[b]Stats:[/b]\n"
	preview_text += "  Reaction: %d | Speed: %d\" | Combat: +%d\n" % [current_character.reaction, current_character.speed, current_character.combat]
	preview_text += "  Toughness: %d | Savvy: +%d | Luck: %d\n\n" % [current_character.toughness, current_character.savvy, current_character.luck]

	if not current_character.traits.is_empty():
		preview_text += "[b]Features:[/b]\n"
		for character_feature in current_character.traits:
			preview_text += "  - %s\n" % character_feature
		preview_text += "\n"
	
	# Add background description if available
	var background_description = _get_background_description(current_character.background)
	if not background_description.is_empty():
		preview_text += "[b]Background:[/b] %s\n\n" % background_description

	traits_display.text = preview_text

func _get_background_description(background_enum: int) -> String:
	"""Get background description from Five Parsecs rules"""
	match background_enum:
		GlobalEnums.Background.MILITARY: return "You served in a military or security force, gaining combat experience and discipline."
		GlobalEnums.Background.MERCENARY: return "You worked as a hired gun, learning to fight for profit and survival."
		GlobalEnums.Background.CRIMINAL: return "You lived on the wrong side of the law, developing street smarts and stealth skills."
		GlobalEnums.Background.COLONIST: return "You grew up on a frontier colony, learning practical skills for survival."
		GlobalEnums.Background.ACADEMIC: return "You received formal education, developing analytical and research skills."
		GlobalEnums.Background.EXPLORER: return "You traveled extensively, mapping new worlds and discovering ancient ruins."
		GlobalEnums.Background.TRADER: return "You worked in commerce, developing negotiation and business skills."
		GlobalEnums.Background.NOBLE: return "You were born to privilege, learning leadership and social skills."
		GlobalEnums.Background.OUTCAST: return "You were rejected by society, developing independence and survival skills."
		GlobalEnums.Background.SOLDIER: return "You served in organized military forces, gaining tactical training."
		GlobalEnums.Background.MERCHANT: return "You worked in trade and commerce, developing business acumen."
		_: return ""

func _on_ui_changed(_arg) -> void:
	_validate_and_update()

func _on_generate_random_pressed() -> void:
	"""Handle random generation button press with proper UI updates"""
	print("CharacterCreator: Random generation requested")
	
	if not dice_manager:
		push_error("CharacterCreator: DiceManager not available for random generation.")
		return
	
	# Generate random character
	current_character = FiveParsecsCharacterGeneration.generate_random_character()
	
	if not current_character:
		push_error("CharacterCreator: Failed to generate random character")
		return
	
	print("CharacterCreator: Random character generated - Name: %s, Class: %s, Background: %s" % [
		current_character.character_name,
		GlobalEnums.get_class_display_name(current_character.character_class),
		GlobalEnums.get_background_display_name(current_character.background)
	])
	
	# Update UI to reflect the new character
	_update_ui_from_character()
	
	# Validate and update display
	_validate_and_update()
	
	print("CharacterCreator: Random generation completed successfully")

func _on_clear_character_pressed() -> void:
	"""Handle clear character button press - reset to proper Five Parsecs defaults"""
	print("CharacterCreator: Clearing character data")
	
	# Reset character to proper Five Parsecs default state
	current_character = Character.new()
	
	# Set proper Five Parsecs default values
	current_character.character_name = "New Character"
	current_character.origin = GlobalEnums.Origin.HUMAN
	current_character.background = GlobalEnums.Background.MILITARY
	current_character.character_class = GlobalEnums.CharacterClass.SOLDIER
	current_character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Generate base attributes using Five Parsecs rules (includes health calculation)
	FiveParsecsCharacterGeneration.generate_character_attributes(current_character)
	
	# Apply default bonuses
	FiveParsecsCharacterGeneration.apply_background_bonuses(current_character)
	FiveParsecsCharacterGeneration.apply_class_bonuses(current_character)
	FiveParsecsCharacterGeneration.set_character_flags(current_character)
	
	# Clear portrait
	clear_portrait()
	
	# Update UI to match character
	_update_ui_from_character()
	_validate_and_update()
	
	print("CharacterCreator: Character cleared and reset to Five Parsecs defaults")

func _on_create_character_pressed() -> void:
	"""Finalize character creation/editing and emit appropriate signal"""
	_validate_and_update()
	if create_character_button.disabled:
		push_warning("CharacterCreator: Attempted to create/update invalid character.")
		return

	if is_editing_mode:
		# We're editing an existing character
		_update_character_from_ui()
		
		# Handle portrait export and assignment for edited character
		if portrait_texture and not current_portrait_path.is_empty():
			var exported_path = export_portrait(current_character.character_name)
			if not exported_path.is_empty():
				current_character.portrait_path = exported_path
				print("CharacterCreator: Portrait updated for character: ", exported_path)
		
		character_updated.emit(current_character)
		print("CharacterCreator: Character '%s' updated and emitted." % current_character.character_name)
	else:
		# We're creating a new character
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
		
		# Handle portrait export and assignment for new character
		if portrait_texture and not current_portrait_path.is_empty():
			var exported_path = export_portrait(final_character.character_name)
			if not exported_path.is_empty():
				final_character.portrait_path = exported_path
				print("CharacterCreator: Portrait assigned to character: ", exported_path)
		
		character_created.emit(final_character)
		print("CharacterCreator: Character '%s' created and emitted." % final_character.character_name)

## NEW: Cancel functionality for editing mode
func _on_cancel_button_pressed() -> void:
	"""Handle cancel button with proper restoration for editing mode"""
	if is_editing_mode and original_character:
		# Restore the original character state
		_restore_original_character()
		print("CharacterCreator: Character editing cancelled, original state restored")
	
	creation_cancelled.emit()

func _restore_original_character() -> void:
	"""Restore character to original state when cancelling edit"""
	if not original_character or not current_character:
		return
	
	# Copy original character properties back
	current_character.character_name = original_character.character_name
	current_character.origin = original_character.origin
	current_character.background = original_character.background
	current_character.character_class = original_character.character_class
	current_character.motivation = original_character.motivation
	current_character.reaction = original_character.reaction
	current_character.combat = original_character.combat
	current_character.toughness = original_character.toughness
	current_character.speed = original_character.speed
	current_character.savvy = original_character.savvy
	current_character.luck = original_character.luck
	
	# Restore portrait if it exists - Godot 4 safe property check
	var original_portrait_path = safe_get_property(original_character, "portrait_path", "")
	if original_portrait_path and not original_portrait_path.is_empty():
		# Use direct property assignment for Resources
		if current_character.has_property("portrait_path"):
			current_character.portrait_path = original_portrait_path
		else:
			# Fallback for objects without direct property access
			current_character.set("portrait_path", original_portrait_path)
		_load_existing_portrait(original_portrait_path)
	else:
		clear_portrait()
	
	print("CharacterCreator: Character restored to original state")

func _on_clear_portrait_pressed() -> void:
	"""Handle clear portrait button press"""
	clear_portrait()

func _on_export_portrait_pressed() -> void:
	"""Handle export portrait button press"""
	if not current_character or current_character.character_name.is_empty():
		_show_portrait_error("Please enter a character name before exporting portrait.")
		return
	
	var exported_path = export_portrait(current_character.character_name)
	if not exported_path.is_empty():
		var success_dialog = AcceptDialog.new()
		success_dialog.dialog_text = "Portrait exported successfully to:\n" + exported_path
		success_dialog.title = "Export Successful"
		get_viewport().add_child(success_dialog)
		success_dialog.popup_centered()
		success_dialog.confirmed.connect(func(): success_dialog.queue_free())
	else:
		_show_portrait_error("Failed to export portrait. Please try again.")

func _on_preview_meta_clicked(meta: Variant) -> void:
	"""Handle clicked links in the preview RichTextLabel"""
	if meta == "select_portrait":
		_on_portrait_button_clicked()

## Safe property access helper
func safe_get_property(obj: Variant, property_name: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	
	if obj is Object and obj.has_method("get"):
		# For Resources, we need to handle the case where get() only accepts one argument
		var value = obj.get(property_name)
		return value if value != null else default_value
	elif obj is Dictionary and obj.has(property_name):
		return obj[property_name]
	
	return default_value
