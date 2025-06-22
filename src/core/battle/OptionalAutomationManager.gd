@tool
extends RefCounted
class_name OptionalAutomationManager

## Manager for optional automation features in battle
##
## Provides configurable automation levels and accessibility features

enum AutomationLevel {
	NONE,
	BASIC,
	INTERMEDIATE,
	FULL
}

signal automation_level_changed(level: AutomationLevel)
signal accessibility_mode_changed(enabled: bool)

var current_automation_level: AutomationLevel = AutomationLevel.NONE
var accessibility_mode_enabled: bool = false
var automation_settings: Dictionary = {}

func _init() -> void:
	_initialize_default_settings()

func _initialize_default_settings() -> void:
	automation_settings = {
		"auto_calculate_damage": false,
		"auto_roll_dice": false,
		"show_calculations": true,
		"confirm_actions": true,
		"play_dice_sounds": true,
		"highlight_targets": true,
		"auto_select_weapons": false,
		"skip_animations": false
	}

## Set the automation level
func set_automation_level(level: AutomationLevel) -> void:
	if current_automation_level != level:
		current_automation_level = level
		_apply_automation_level(level)
		automation_level_changed.emit(level)  # warning: return value discarded (intentional)

## Get the current automation level
func get_automation_level() -> AutomationLevel:
	return current_automation_level

## Enable or disable accessibility mode
func enable_accessibility_mode(enabled: bool) -> void:
	if accessibility_mode_enabled != enabled:
		accessibility_mode_enabled = enabled
		_apply_accessibility_settings(enabled)
		accessibility_mode_changed.emit(enabled)  # warning: return value discarded (intentional)

## Check if accessibility mode is enabled
func is_accessibility_mode_enabled() -> bool:
	return accessibility_mode_enabled

## Apply settings based on automation level
func _apply_automation_level(level: AutomationLevel) -> void:
	match level:
		AutomationLevel.NONE:
			automation_settings["auto_calculate_damage"] = false
			automation_settings["auto_roll_dice"] = false
			automation_settings["auto_select_weapons"] = false
		
		AutomationLevel.BASIC:
			automation_settings["auto_calculate_damage"] = true
			automation_settings["auto_roll_dice"] = false
			automation_settings["auto_select_weapons"] = false
		
		AutomationLevel.INTERMEDIATE:
			automation_settings["auto_calculate_damage"] = true
			automation_settings["auto_roll_dice"] = true
			automation_settings["auto_select_weapons"] = false
		
		AutomationLevel.FULL:
			automation_settings["auto_calculate_damage"] = true
			automation_settings["auto_roll_dice"] = true
			automation_settings["auto_select_weapons"] = true

## Apply accessibility-specific settings

func _apply_accessibility_settings(enabled: bool) -> void:
	if enabled:
		automation_settings["show_calculations"] = true
		automation_settings["confirm_actions"] = true
		automation_settings["play_dice_sounds"] = false
		automation_settings["highlight_targets"] = true
		automation_settings["skip_animations"] = true

## Get a specific automation setting

func get_setting(setting_name: String) -> Variant:
	return automation_settings.get(setting_name, false)

## Set a specific automation setting
func set_setting(setting_name: String, _value: Variant) -> void:
	automation_settings[setting_name] = _value

## Get all automation settings

func get_all_settings() -> Dictionary:
	return automation_settings.duplicate()

## Load settings from dictionary
func load_settings(settings: Dictionary) -> void:
	for key in settings:
		if automation_settings.has(key):
			automation_settings[key] = settings[key]

## Check if a feature should be automated

func should_automate(feature: String) -> bool:
	return automation_settings.get(feature, false)

## Get automation level name for display
func get_automation_level_name(level: AutomationLevel) -> String:
	match level:
		AutomationLevel.NONE:
			return "None"
		AutomationLevel.BASIC:
			return "Basic"
		AutomationLevel.INTERMEDIATE:
			return "Intermediate"
		AutomationLevel.FULL:
			return "Full"
		_:
			return "Unknown"