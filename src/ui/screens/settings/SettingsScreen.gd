class_name SettingsScreen
extends Control

## Settings Screen - Wrapper for accessibility and game settings
## Provides navigation back to Campaign Dashboard

const AccessibilitySettingsPanelScript = preload("res://src/ui/screens/settings/AccessibilitySettingsPanel.gd")

# UI References
@onready var back_button: Button = %BackButton
@onready var settings_container: VBoxContainer = %SettingsContainer

# Design system colors (from BaseCampaignPanel)
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")

func _ready() -> void:
	_setup_background()
	_connect_signals()
	_setup_accessibility_panel()
	print("SettingsScreen: Ready")

func _setup_background() -> void:
	"""Apply consistent background styling"""
	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_BASE
	add_theme_stylebox_override("panel", bg)

func _connect_signals() -> void:
	"""Connect button signals"""
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _setup_accessibility_panel() -> void:
	"""Add accessibility settings panel to container"""
	if not settings_container:
		push_warning("SettingsScreen: Settings container not found")
		return

	# Create accessibility panel instance
	var accessibility_panel := AccessibilitySettingsPanel.new()
	accessibility_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessibility_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_container.add_child(accessibility_panel)

	# Connect theme selection signal
	accessibility_panel.theme_selected.connect(_on_theme_selected)

func _on_back_pressed() -> void:
	"""Navigate back to Campaign Dashboard"""
	print("SettingsScreen: Returning to Campaign Dashboard")
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/campaign/CampaignDashboard.tscn")

func _on_theme_selected(theme_variant: int) -> void:
	"""Handle theme selection - auto-save preference"""
	print("SettingsScreen: Theme selected - %d" % theme_variant)
	# Theme is applied by AccessibilitySettingsPanel via ThemeManager
