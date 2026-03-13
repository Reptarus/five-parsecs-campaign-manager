class_name SettingsScreen
extends Control

## Settings Screen - Wrapper for accessibility and game settings
## Provides navigation back to Campaign Dashboard

const AccessibilitySettingsPanelScript = preload("res://src/ui/screens/settings/AccessibilitySettingsPanel.gd")
const DifficultyTogglesPanelScript = preload("res://src/ui/screens/settings/DifficultyTogglesPanel.gd")

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
	_setup_difficulty_toggles_panel()

func _setup_background() -> void:
	## Apply consistent background styling
	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_BASE
	add_theme_stylebox_override("panel", bg)

func _connect_signals() -> void:
	## Connect button signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _setup_accessibility_panel() -> void:
	## Add accessibility settings panel to container
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

func _setup_difficulty_toggles_panel() -> void:
	## Add difficulty toggles panel (Compendium DLC)
	if not settings_container:
		return
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 16)
	settings_container.add_child(separator)
	var toggles_panel = DifficultyTogglesPanelScript.new()
	toggles_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_container.add_child(toggles_panel)

func _on_back_pressed() -> void:
	## Navigate back to Campaign Dashboard
	SceneRouter.navigate_back()

func _on_theme_selected(theme_variant: int) -> void:
	## Handle theme selection - auto-save preference
	# Theme is applied by AccessibilitySettingsPanel via ThemeManager
	pass
