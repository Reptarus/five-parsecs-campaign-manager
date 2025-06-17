@tool
class_name FPCM_AutomationSettingsPanel
extends Control

## Automation & Accessibility Settings Panel
##
## Provides user-friendly interface for configuring automation levels
## and accessibility features for the Five Parsecs Campaign Manager

# Dependencies
const OptionalAutomationManager = preload("res://src/core/battle/OptionalAutomationManager.gd")

# UI References
@onready var automation_level_option: OptionButton = $VBox/AutomationSection/AutomationLevelOption
@onready var accessibility_mode_check: CheckBox = $VBox/AccessibilitySection/AccessibilityModeCheck
@onready var always_confirm_check: CheckBox = $VBox/ConfirmationSection/AlwaysConfirmCheck
@onready var show_calculations_check: CheckBox = $VBox/CalculationSection/ShowCalculationsCheck
@onready var rule_suggestions_check: CheckBox = $VBox/RulesSection/RuleSuggestionsCheck
@onready var dice_auto_roll_check: CheckBox = $VBox/DiceSection/DiceAutoRollCheck
@onready var dice_animations_check: CheckBox = $VBox/DiceSection/DiceAnimationsCheck
@onready var dice_sound_check: CheckBox = $VBox/DiceSection/DiceSoundCheck

# Settings description labels
@onready var automation_description: Label = $VBox/AutomationSection/AutomationDescription
@onready var accessibility_description: Label = $VBox/AccessibilitySection/AccessibilityDescription

# System reference
var automation_manager: OptionalAutomationManager

# Signals
signal settings_changed(settings: Dictionary)
signal accessibility_mode_toggled(enabled: bool)

func _ready():
	_setup_ui_layout()
	_setup_automation_options()
	_setup_connections()
	_load_default_settings()

## Setup the UI layout with proper grouping
func _setup_ui_layout():
	# Main layout
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Automation & Accessibility Settings"
	title_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(title_label)
	
	var separator = HSeparator.new()
	main_vbox.add_child(separator)
	
	# Accessibility Section
	_create_accessibility_section(main_vbox)
	
	# Automation Level Section
	_create_automation_section(main_vbox)
	
	# Dice Settings Section
	_create_dice_section(main_vbox)
	
	# Confirmation Settings Section
	_create_confirmation_section(main_vbox)
	
	# Rules & Calculations Section
	_create_rules_section(main_vbox)

## Create accessibility section with clear benefits
func _create_accessibility_section(parent: Node):
	var section = _create_section("Accessibility Features", parent)
	
	# Accessibility mode toggle
	accessibility_mode_check = CheckBox.new()
	accessibility_mode_check.text = "Enable Accessibility Mode"
	section.add_child(accessibility_mode_check)
	
	# Description
	accessibility_description = Label.new()
	accessibility_description.text = """Enhanced features for users with disabilities:
• Slower animations and clearer visual feedback
• Always show calculation breakdowns
• Larger text and high contrast options
• Audio cues for important events
• Simplified interface options"""
	accessibility_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	accessibility_description.add_theme_color_override("font_color", Color.GRAY)
	section.add_child(accessibility_description)

## Create automation level section
func _create_automation_section(parent: Node):
	var section = _create_section("Automation Level", parent)
	
	automation_level_option = OptionButton.new()
	section.add_child(automation_level_option)
	
	automation_description = Label.new()
	automation_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	automation_description.add_theme_color_override("font_color", Color.GRAY)
	section.add_child(automation_description)

## Create dice settings section
func _create_dice_section(parent: Node):
	var section = _create_section("Digital Dice Options", parent)
	
	dice_auto_roll_check = CheckBox.new()
	dice_auto_roll_check.text = "Auto-roll dice (can still enter manual results)"
	section.add_child(dice_auto_roll_check)
	
	dice_animations_check = CheckBox.new()
	dice_animations_check.text = "Show dice rolling animations"
	section.add_child(dice_animations_check)
	
	dice_sound_check = CheckBox.new()
	dice_sound_check.text = "Play dice rolling sounds"
	section.add_child(dice_sound_check)
	
	var dice_note = Label.new()
	dice_note.text = "Note: You can always override digital rolls with physical dice results"
	dice_note.add_theme_color_override("font_color", Color.GRAY)
	dice_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	section.add_child(dice_note)

## Create confirmation section
func _create_confirmation_section(parent: Node):
	var section = _create_section("Confirmation & Safety", parent)
	
	always_confirm_check = CheckBox.new()
	always_confirm_check.text = "Always confirm automated actions"
	section.add_child(always_confirm_check)
	
	show_calculations_check = CheckBox.new()
	show_calculations_check.text = "Show calculation steps for all automated results"
	section.add_child(show_calculations_check)

## Create rules assistance section
func _create_rules_section(parent: Node):
	var section = _create_section("Rules Assistance", parent)
	
	rule_suggestions_check = CheckBox.new()
	rule_suggestions_check.text = "Suggest relevant rules and page references"
	section.add_child(rule_suggestions_check)
	
	var rules_note = Label.new()
	rules_note.text = "Provides helpful rule reminders - you're still the Game Master!"
	rules_note.add_theme_color_override("font_color", Color.GRAY)
	rules_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	section.add_child(rules_note)

## Helper to create labeled sections
func _create_section(title: String, parent: Node) -> VBoxContainer:
	var section_label = Label.new()
	section_label.text = title
	section_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(section_label)
	
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)
	parent.add_child(section)
	
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	parent.add_child(spacer)
	
	return section

## Setup automation level options with descriptions
func _setup_automation_options():
	automation_level_option.add_item("Manual Only - Pure Tabletop")
	automation_level_option.add_item("Dice Assistance - Digital dice with manual override")
	automation_level_option.add_item("Basic Help - Dice + calculations")
	automation_level_option.add_item("Guided Play - Suggestions with confirmation")
	automation_level_option.add_item("Full Assistance - Maximum help (still requires confirmation)")
	
	# Set default
	automation_level_option.selected = 1 # DICE_ASSISTANCE

## Setup signal connections
func _setup_connections():
	if automation_level_option:
		automation_level_option.item_selected.connect(_on_automation_level_changed)
	
	if accessibility_mode_check:
		accessibility_mode_check.toggled.connect(_on_accessibility_mode_toggled)
	
	if always_confirm_check:
		always_confirm_check.toggled.connect(_on_setting_changed)
	
	if show_calculations_check:
		show_calculations_check.toggled.connect(_on_setting_changed)
	
	if rule_suggestions_check:
		rule_suggestions_check.toggled.connect(_on_setting_changed)
	
	if dice_auto_roll_check:
		dice_auto_roll_check.toggled.connect(_on_setting_changed)
	
	if dice_animations_check:
		dice_animations_check.toggled.connect(_on_setting_changed)
	
	if dice_sound_check:
		dice_sound_check.toggled.connect(_on_setting_changed)

## Load default accessibility-friendly settings
func _load_default_settings():
	# Accessibility-first defaults
	accessibility_mode_check.button_pressed = false
	always_confirm_check.button_pressed = true
	show_calculations_check.button_pressed = true
	rule_suggestions_check.button_pressed = true
	
	# Dice defaults - user choice
	dice_auto_roll_check.button_pressed = false # Default to manual
	dice_animations_check.button_pressed = true
	dice_sound_check.button_pressed = false # Accessibility consideration
	
	_update_automation_description()

## Initialize with automation manager
func setup_automation_manager(manager: OptionalAutomationManager):
	automation_manager = manager
	_load_settings_from_manager()

## Load settings from automation manager
func _load_settings_from_manager():
	if not automation_manager:
		return
	
	var settings = automation_manager.export_settings()
	
	automation_level_option.selected = settings.get("automation_level", 1)
	accessibility_mode_check.button_pressed = settings.get("accessibility_mode", false)
	always_confirm_check.button_pressed = settings.get("always_confirm_actions", true)
	show_calculations_check.button_pressed = settings.get("show_calculation_steps", true)
	rule_suggestions_check.button_pressed = settings.get("enable_rule_suggestions", true)
	
	var dice_settings = settings.get("dice_settings", {})
	dice_auto_roll_check.button_pressed = dice_settings.get("auto_roll_enabled", false)
	dice_animations_check.button_pressed = dice_settings.get("show_animations", true)
	dice_sound_check.button_pressed = dice_settings.get("dice_sound_enabled", false)
	
	_update_automation_description()

## Handle automation level changes
func _on_automation_level_changed(index: int):
	if automation_manager:
		automation_manager.set_automation_level(index as OptionalAutomationManager.AutomationLevel)
	
	_update_automation_description()
	_emit_settings_changed()

## Handle accessibility mode toggle
func _on_accessibility_mode_toggled(pressed: bool):
	if automation_manager:
		automation_manager.enable_accessibility_mode(pressed)
	
	# Auto-adjust other settings for accessibility
	if pressed:
		show_calculations_check.button_pressed = true
		always_confirm_check.button_pressed = true
		dice_sound_check.button_pressed = false # Avoid audio clutter
	
	accessibility_mode_toggled.emit(pressed)
	_emit_settings_changed()

## Handle general setting changes
func _on_setting_changed(_pressed: bool = false):
	_apply_settings_to_manager()
	_emit_settings_changed()

## Apply current UI settings to automation manager
func _apply_settings_to_manager():
	if not automation_manager:
		return
	
	automation_manager.always_confirm_actions = always_confirm_check.button_pressed
	automation_manager.show_calculation_steps = show_calculations_check.button_pressed
	automation_manager.enable_rule_suggestions = rule_suggestions_check.button_pressed
	
	# Dice settings
	automation_manager.dice_system.auto_roll_enabled = dice_auto_roll_check.button_pressed
	automation_manager.dice_system.show_animations = dice_animations_check.button_pressed
	automation_manager.dice_system.dice_sound_enabled = dice_sound_check.button_pressed

## Update the description based on current automation level
func _update_automation_description():
	var descriptions = [
		"Pure tabletop experience - no digital assistance, roll your own dice",
		"Digital dice available but you can always input your physical dice results",
		"Dice assistance plus automatic calculation of modifiers and movement costs",
		"AI suggests actions and provides rule references - you confirm everything",
		"Maximum assistance while maintaining your control and decision-making"
	]
	
	var index = automation_level_option.selected
	if index >= 0 and index < descriptions.size():
		automation_description.text = descriptions[index]

## Emit settings changed signal
func _emit_settings_changed():
	var current_settings = {
		"automation_level": automation_level_option.selected,
		"accessibility_mode": accessibility_mode_check.button_pressed,
		"always_confirm_actions": always_confirm_check.button_pressed,
		"show_calculation_steps": show_calculations_check.button_pressed,
		"enable_rule_suggestions": rule_suggestions_check.button_pressed,
		"dice_auto_roll": dice_auto_roll_check.button_pressed,
		"dice_animations": dice_animations_check.button_pressed,
		"dice_sound": dice_sound_check.button_pressed
	}
	
	settings_changed.emit(current_settings)

## Export current settings for saving
func export_settings() -> Dictionary:
	return {
		"automation_level": automation_level_option.selected,
		"accessibility_mode": accessibility_mode_check.button_pressed,
		"always_confirm_actions": always_confirm_check.button_pressed,
		"show_calculation_steps": show_calculations_check.button_pressed,
		"enable_rule_suggestions": rule_suggestions_check.button_pressed,
		"dice_settings": {
			"auto_roll_enabled": dice_auto_roll_check.button_pressed,
			"show_animations": dice_animations_check.button_pressed,
			"dice_sound_enabled": dice_sound_check.button_pressed
		}
	}

## Import settings from save data
func import_settings(settings: Dictionary):
	automation_level_option.selected = settings.get("automation_level", 1)
	accessibility_mode_check.button_pressed = settings.get("accessibility_mode", false)
	always_confirm_check.button_pressed = settings.get("always_confirm_actions", true)
	show_calculations_check.button_pressed = settings.get("show_calculation_steps", true)
	rule_suggestions_check.button_pressed = settings.get("enable_rule_suggestions", true)
	
	var dice_settings = settings.get("dice_settings", {})
	dice_auto_roll_check.button_pressed = dice_settings.get("auto_roll_enabled", false)
	dice_animations_check.button_pressed = dice_settings.get("show_animations", true)
	dice_sound_check.button_pressed = dice_settings.get("dice_sound_enabled", false)
	
	_update_automation_description()
	_apply_settings_to_manager()

## Show/hide advanced options based on accessibility mode
func _update_ui_for_accessibility():
	if accessibility_mode_check.button_pressed:
		# Accessibility mode - show everything with clear descriptions
		_show_all_options()
	else:
		# Standard mode - can hide some advanced options
		_show_standard_options()

func _show_all_options():
	# Show all controls with enhanced descriptions
	pass

func _show_standard_options():
	# Standard layout
	pass

## Create quick preset buttons for common use cases
func _add_preset_buttons(parent: Node):
	var presets_section = _create_section("Quick Presets", parent)
	
	var preset_container = HBoxContainer.new()
	presets_section.add_child(preset_container)
	
	# Tabletop purist preset
	var tabletop_button = Button.new()
	tabletop_button.text = "Tabletop Purist"
	tabletop_button.pressed.connect(_apply_tabletop_preset)
	preset_container.add_child(tabletop_button)
	
	# Accessibility preset
	var accessibility_button = Button.new()
	accessibility_button.text = "Accessibility"
	accessibility_button.pressed.connect(_apply_accessibility_preset)
	preset_container.add_child(accessibility_button)
	
	# Convenience preset
	var convenience_button = Button.new()
	convenience_button.text = "Digital Convenience"
	convenience_button.pressed.connect(_apply_convenience_preset)
	preset_container.add_child(convenience_button)

## Preset configurations
func _apply_tabletop_preset():
	automation_level_option.selected = 0 # MANUAL_ONLY
	accessibility_mode_check.button_pressed = false
	dice_auto_roll_check.button_pressed = false
	always_confirm_check.button_pressed = true
	_on_setting_changed()

func _apply_accessibility_preset():
	automation_level_option.selected = 2 # BASIC_HELP
	accessibility_mode_check.button_pressed = true
	show_calculations_check.button_pressed = true
	always_confirm_check.button_pressed = true
	dice_sound_check.button_pressed = false
	_on_setting_changed()

func _apply_convenience_preset():
	automation_level_option.selected = 3 # GUIDED_PLAY
	accessibility_mode_check.button_pressed = false
	dice_auto_roll_check.button_pressed = true
	rule_suggestions_check.button_pressed = true
	_on_setting_changed()