@tool
extends Control

# Import required classes
const GameEnums = preload("res://src/core/enums/GameEnums.gd")

# Signals for UI interaction
signal settings_applied
signal back_pressed
signal settings_changed

# UI components
@onready var difficulty_option: OptionButton = $SettingsContainer/DifficultyOption
@onready var enable_tutorials_check: CheckButton = $SettingsContainer/EnableTutorialsCheck
@onready var auto_save_check: CheckButton = $SettingsContainer/AutoSaveCheck
@onready var language_option: OptionButton = $SettingsContainer/LanguageOption

# State tracking
var is_modified: bool = false
var default_settings: Dictionary = {
	"difficulty": GameEnums.DifficultyLevel.NORMAL,
	"enable_tutorials": true,
	"auto_save": true,
	"language": "English"
}
var current_settings: Dictionary = default_settings.duplicate(true)
var saved_settings: Dictionary = default_settings.duplicate(true)

# Initialize the menu
func _ready() -> void:
	# Initialize UI components
	_setup_difficulty_options()
	_setup_language_options()
	
	# Connect signals
	_connect_signals()
	
	# Load initial settings
	_on_load_settings()
	
	# Make sure visibility is properly set initially
	visible = false

# Setup methods
func _setup_difficulty_options() -> void:
	if not is_instance_valid(difficulty_option):
		return
		
	difficulty_option.clear()
	difficulty_option.add_item("Easy", GameEnums.DifficultyLevel.EASY)
	difficulty_option.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
	difficulty_option.add_item("Hard", GameEnums.DifficultyLevel.HARD)
	difficulty_option.add_item("Nightmare", GameEnums.DifficultyLevel.NIGHTMARE)
	difficulty_option.selected = GameEnums.DifficultyLevel.NORMAL

func _setup_language_options() -> void:
	if not is_instance_valid(language_option):
		return
		
	language_option.clear()
	language_option.add_item("English")
	language_option.add_item("Spanish")
	language_option.add_item("French")
	language_option.add_item("German")
	language_option.add_item("Japanese")
	language_option.selected = 0

func _connect_signals() -> void:
	if is_instance_valid(difficulty_option):
		difficulty_option.item_selected.connect(_on_difficulty_changed)
	
	if is_instance_valid(enable_tutorials_check):
		enable_tutorials_check.toggled.connect(_on_tutorials_toggled)
	
	if is_instance_valid(auto_save_check):
		auto_save_check.toggled.connect(_on_auto_save_toggled)
	
	if is_instance_valid(language_option):
		language_option.item_selected.connect(_on_language_changed)
	
	# Button signals
	if has_node("ButtonContainer/ApplyButton"):
		$ButtonContainer/ApplyButton.pressed.connect(_on_apply_pressed)
	
	if has_node("ButtonContainer/ResetButton"):
		$ButtonContainer/ResetButton.pressed.connect(_on_reset_pressed)
	
	if has_node("ButtonContainer/BackButton"):
		$ButtonContainer/BackButton.pressed.connect(_on_back_pressed)

# Signal handlers
func _on_difficulty_changed(index: int) -> void:
	if index >= 0 and index < GameEnums.DifficultyLevel.size():
		current_settings.difficulty = index
		_on_settings_changed()

func _on_tutorials_toggled(enabled: bool) -> void:
	current_settings.enable_tutorials = enabled
	_on_settings_changed()

func _on_auto_save_toggled(enabled: bool) -> void:
	current_settings.auto_save = enabled
	_on_settings_changed()

func _on_language_changed(index: int) -> void:
	if index >= 0 and index < language_option.item_count:
		current_settings.language = language_option.get_item_text(index)
		_on_settings_changed()

func _on_settings_changed() -> void:
	is_modified = !_are_settings_equal(current_settings, saved_settings)
	emit_signal("settings_changed")
	
	# Update UI to reflect the modified state
	if has_node("ButtonContainer/ApplyButton"):
		$ButtonContainer/ApplyButton.disabled = !is_modified

func _on_apply_pressed() -> void:
	# Save the current settings
	saved_settings = current_settings.duplicate(true)
	
	# Apply settings to the game
	_apply_settings_to_game()
	
	# Update state
	is_modified = false
	if has_node("ButtonContainer/ApplyButton"):
		$ButtonContainer/ApplyButton.disabled = true
	
	emit_signal("settings_applied")

func _on_reset_pressed() -> void:
	# Reset to default settings
	current_settings = default_settings.duplicate(true)
	
	# Update UI to reflect the defaults
	_update_ui_from_settings()
	
	# Update state
	is_modified = !_are_settings_equal(current_settings, saved_settings)
	if has_node("ButtonContainer/ApplyButton"):
		$ButtonContainer/ApplyButton.disabled = !is_modified

func _on_back_pressed() -> void:
	# Emit signal to navigate back
	emit_signal("back_pressed")

# Helper methods
func _are_settings_equal(settings1: Dictionary, settings2: Dictionary) -> bool:
	# Compare the two settings dictionaries
	for key in settings1:
		if key in settings2:
			if settings1[key] != settings2[key]:
				return false
		else:
			return false
	return true

func _update_ui_from_settings() -> void:
	# Update UI components based on current settings
	if is_instance_valid(difficulty_option):
		difficulty_option.selected = current_settings.difficulty
	
	if is_instance_valid(enable_tutorials_check):
		enable_tutorials_check.button_pressed = current_settings.enable_tutorials
	
	if is_instance_valid(auto_save_check):
		auto_save_check.button_pressed = current_settings.auto_save
	
	if is_instance_valid(language_option):
		for i in range(language_option.item_count):
			if language_option.get_item_text(i) == current_settings.language:
				language_option.selected = i
				break

func _apply_settings_to_game() -> void:
	# Get the game state manager
	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state:
		# Apply difficulty
		if "set_difficulty" in game_state:
			game_state.set_difficulty(current_settings.difficulty)
		
		# Apply tutorial setting
		if "set_tutorials_enabled" in game_state:
			game_state.set_tutorials_enabled(current_settings.enable_tutorials)
		
		# Apply auto save setting
		if "set_auto_save_enabled" in game_state:
			game_state.set_auto_save_enabled(current_settings.auto_save)
		
		# Apply language
		if "set_language" in game_state:
			game_state.set_language(current_settings.language)

# Public methods
func show_menu() -> void:
	visible = true
	# Ensure settings are up-to-date
	_on_load_settings()

func hide_menu() -> void:
	visible = false

func _on_load_settings() -> void:
	# Load current settings from the game
	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state:
		if "difficulty_level" in game_state:
			saved_settings.difficulty = game_state.difficulty_level
		
		if "enable_tutorials" in game_state:
			saved_settings.enable_tutorials = game_state.enable_tutorials
		
		if "auto_save_enabled" in game_state:
			saved_settings.auto_save = game_state.auto_save_enabled
		
		if "language" in game_state:
			saved_settings.language = game_state.language
	
	# Update current settings and UI
	current_settings = saved_settings.duplicate(true)
	_update_ui_from_settings()
	is_modified = false
	
	if has_node("ButtonContainer/ApplyButton"):
		$ButtonContainer/ApplyButton.disabled = !is_modified

func cleanup() -> void:
	# Reset to defaults
	current_settings = default_settings.duplicate(true)
	_update_ui_from_settings()
	is_modified = false
