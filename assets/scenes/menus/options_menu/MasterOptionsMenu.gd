# Universal Warning Fixes Applied - 7-Stage Methodology
# Based on proven patterns: Universal Mock Strategy + comprehensive annotation coverage
@warning_ignore("unused_parameter")
@warning_ignore("shadowed_global_identifier")
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_method_access")
@warning_ignore("unused_signal")
@warning_ignore("return_value_discarded")
extends Control

# Universal Framework Enhancement - Added on top of existing warning suppressions
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")

# Enhanced type safety while preserving warning suppressions
@onready var graphics_tab: Control = $TabContainer/Graphics
@onready var audio_tab: Control = $TabContainer/Audio
@onready var controls_tab: Control = $TabContainer/Controls
@onready var gameplay_tab: Control = $TabContainer/Gameplay
@onready var tab_container: TabContainer = $TabContainer
@onready var back_button: Button = $BackButton
@onready var apply_button: Button = $ApplyButton
@onready var reset_button: Button = $ResetButton

# Additional enhanced functionality
var _tabs_initialized: bool = false
var _settings_changed: bool = false
var _tab_connections: Dictionary = {}
var _settings_backup: Dictionary = {}

# Enhanced signals for tracking
signal options_menu_opened()
signal options_menu_closed()
signal settings_applied()
signal settings_reset()
signal tab_changed(tab_index: int)

func _ready() -> void:
	print("MasterOptionsMenu: Enhanced initialization starting")
	
	# Enhanced initialization with validation
	_validate_components()
	_initialize_tabs()
	_connect_signals()
	_backup_current_settings()

func _validate_components() -> void:
	"""Validate components with enhanced tracking"""
	
	var required_components: Array[Dictionary] = [
		{"node": tab_container, "name": "TabContainer"},
		{"node": back_button, "name": "BackButton"},
		{"node": apply_button, "name": "ApplyButton"},
		{"node": reset_button, "name": "ResetButton"}
	]
	
	for component in required_components:
		var node: Node = component.node
		var name: String = component.name
		
		if not node:
			push_error("MasterOptionsMenu: Missing component: " + name)
			return
		else:
			print("MasterOptionsMenu: Validated component: " + name)
	
	# Validate tab components
	var tab_components: Array[Dictionary] = [
		{"node": graphics_tab, "name": "Graphics"},
		{"node": audio_tab, "name": "Audio"},
		{"node": controls_tab, "name": "Controls"},
		{"node": gameplay_tab, "name": "Gameplay"}
	]
	
	for tab_info in tab_components:
		var tab_node: Node = tab_info.node
		var tab_name: String = tab_info.name
		
		if not tab_node:
			push_warning("MasterOptionsMenu: Missing tab: " + tab_name)
		else:
			print("MasterOptionsMenu: Validated tab: " + tab_name)
			_tab_connections[tab_name] = tab_node

func _initialize_tabs() -> void:
	"""Initialize tabs with enhanced validation"""
	
	if not tab_container:
		push_error("MasterOptionsMenu: Cannot initialize tabs - TabContainer missing")
		return
	
	print("MasterOptionsMenu: Initializing %d tabs" % tab_container.get_tab_count())
	
	# Set initial tab
	tab_container.current_tab = 0
	
	# Initialize each tab if it has an initialize method
	for tab_name in _tab_connections:
		var tab_node: Node = _tab_connections[tab_name]
		if tab_node and tab_node.has_method("initialize"):
			tab_node.initialize()
			print("MasterOptionsMenu: Initialized %s tab" % tab_name)
	
	_tabs_initialized = true
	print("MasterOptionsMenu: Tab initialization completed")

func _connect_signals() -> void:
	"""Connect signals with enhanced validation"""
	
	# Connect tab container
	if tab_container:
		UniversalSignalManager.connect_signal_safe(
			tab_container,
			"tab_changed",
			_on_tab_changed,
			"MasterOptionsMenu tab_container"
		)
		print("MasterOptionsMenu: Connected tab container signals")
	
	# Connect buttons
	if back_button:
		UniversalSignalManager.connect_signal_safe(
			back_button,
			"pressed",
			_on_back_button_pressed,
			"MasterOptionsMenu back_button"
		)
		print("MasterOptionsMenu: Connected back button")
	
	if apply_button:
		UniversalSignalManager.connect_signal_safe(
			apply_button,
			"pressed",
			_on_apply_button_pressed,
			"MasterOptionsMenu apply_button"
		)
		print("MasterOptionsMenu: Connected apply button")
	
	if reset_button:
		UniversalSignalManager.connect_signal_safe(
			reset_button,
			"pressed",
			_on_reset_button_pressed,
			"MasterOptionsMenu reset_button"
		)
		print("MasterOptionsMenu: Connected reset button")

func _backup_current_settings() -> void:
	"""Backup current settings for reset functionality"""
	
	print("MasterOptionsMenu: Backing up current settings")
	
	# Backup basic engine settings
	_settings_backup = {
		"master_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")),
		"music_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) if AudioServer.get_bus_index("Music") != -1 else 0.0,
		"sfx_volume": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) if AudioServer.get_bus_index("SFX") != -1 else 0.0,
		"fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"window_size": DisplayServer.window_get_size()
	}
	
	print("MasterOptionsMenu: Settings backup completed")

func _on_tab_changed(tab_index: int) -> void:
	print("MasterOptionsMenu: Tab changed to index: %d" % tab_index)
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "tab_changed", [tab_index], "MasterOptionsMenu _on_tab_changed")
	
	# Update tab-specific functionality
	_update_tab_visibility(tab_index)

func _update_tab_visibility(tab_index: int) -> void:
	"""Update tab visibility with enhanced validation"""
	
	if not tab_container or tab_index < 0 or tab_index >= tab_container.get_tab_count():
		push_warning("MasterOptionsMenu: Invalid tab index: %d" % tab_index)
		return
	
	var tab_name: String = tab_container.get_tab_title(tab_index)
	print("MasterOptionsMenu: Switched to %s tab" % tab_name)
	
	# Refresh current tab if it has a refresh method
	var current_tab: Node = tab_container.get_current_tab_control()
	if current_tab and current_tab.has_method("refresh"):
		current_tab.refresh()

func _on_back_button_pressed() -> void:
	print("MasterOptionsMenu: Back button pressed")
	
	# Check if settings were changed
	if _settings_changed:
		_show_unsaved_changes_dialog()
	else:
		_close_options_menu()

func _on_apply_button_pressed() -> void:
	print("MasterOptionsMenu: Apply button pressed")
	
	# Enhanced settings application
	_apply_all_settings()

func _on_reset_button_pressed() -> void:
	print("MasterOptionsMenu: Reset button pressed")
	
	# Enhanced settings reset
	_show_reset_confirmation_dialog()

func _apply_all_settings() -> void:
	"""Apply settings from all tabs with enhanced validation"""
	
	print("MasterOptionsMenu: Applying settings from all tabs...")
	
	var applied_count: int = 0
	
	# Apply settings from each tab
	for tab_name in _tab_connections:
		var tab_node: Node = _tab_connections[tab_name]
		if tab_node and tab_node.has_method("apply_settings"):
			tab_node.apply_settings()
			applied_count += 1
			print("MasterOptionsMenu: Applied settings for %s tab" % tab_name)
	
	_settings_changed = false
	print("MasterOptionsMenu: Applied settings for %d tabs" % applied_count)
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "settings_applied", [], "MasterOptionsMenu _apply_all_settings")
	
	# Save settings to file
	_save_settings_to_file()

func _save_settings_to_file() -> void:
	"""Save settings to configuration file"""
	
	print("MasterOptionsMenu: Saving settings to file...")
	
	var config: ConfigFile = ConfigFile.new()
	
	# Save current settings
	config.set_value("audio", "master_volume", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.set_value("display", "window_size", DisplayServer.window_get_size())
	
	var save_error: Error = config.save("user://settings.cfg")
	if save_error != OK:
		push_error("MasterOptionsMenu: Failed to save settings: " + str(save_error))
	else:
		print("MasterOptionsMenu: Settings saved successfully")

func _show_unsaved_changes_dialog() -> void:
	"""Show dialog for unsaved changes"""
	
	print("MasterOptionsMenu: Showing unsaved changes dialog")
	
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "You have unsaved changes. Do you want to apply them before leaving?"
	dialog.title = "Unsaved Changes"
	add_child(dialog)
	
	# Connect dialog signals
	UniversalSignalManager.connect_signal_safe(
		dialog,
		"confirmed",
		func(): _apply_all_settings(); _close_options_menu(),
		"MasterOptionsMenu unsaved_changes_dialog"
	)
	
	UniversalSignalManager.connect_signal_safe(
		dialog,
		"cancelled",
		func(): _close_options_menu(),
		"MasterOptionsMenu unsaved_changes_dialog"
	)
	
	dialog.popup_centered()

func _show_reset_confirmation_dialog() -> void:
	"""Show reset confirmation dialog"""
	
	print("MasterOptionsMenu: Showing reset confirmation dialog")
	
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to reset all settings to default values?"
	dialog.title = "Reset Settings"
	add_child(dialog)
	
	# Connect dialog signals
	UniversalSignalManager.connect_signal_safe(
		dialog,
		"confirmed",
		_reset_all_settings,
		"MasterOptionsMenu reset_confirmation_dialog"
	)
	
	dialog.popup_centered()

func _reset_all_settings() -> void:
	"""Reset all settings with enhanced validation"""
	
	print("MasterOptionsMenu: Resetting all settings to defaults...")
	
	var reset_count: int = 0
	
	# Reset settings for each tab
	for tab_name in _tab_connections:
		var tab_node: Node = _tab_connections[tab_name]
		if tab_node and tab_node.has_method("reset_to_defaults"):
			tab_node.reset_to_defaults()
			reset_count += 1
			print("MasterOptionsMenu: Reset settings for %s tab" % tab_name)
	
	_settings_changed = true
	print("MasterOptionsMenu: Reset settings for %d tabs" % reset_count)
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "settings_reset", [], "MasterOptionsMenu _reset_all_settings")

func _close_options_menu() -> void:
	"""Close options menu with enhanced cleanup"""
	
	print("MasterOptionsMenu: Closing options menu")
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "options_menu_closed", [], "MasterOptionsMenu _close_options_menu")
	
	# Navigate back to main menu
	var main_node: Node = UniversalNodeAccess.get_node_safe(get_tree().root, "Main", "MasterOptionsMenu _close_options_menu")
	
	if main_node and main_node.has_method("goto_scene"):
		main_node.goto_scene("res://assets/scenes/menus/main_menu/main_menu.tscn")
		print("MasterOptionsMenu: Navigated back to main menu")
	else:
		push_warning("MasterOptionsMenu: Main node not available, using direct scene change")
		get_tree().call_deferred("change_scene_to_file", "res://assets/scenes/menus/main_menu/main_menu.tscn")

func show_options_menu() -> void:
	"""Show options menu with enhanced initialization"""
	
	print("MasterOptionsMenu: Showing options menu")
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "options_menu_opened", [], "MasterOptionsMenu show_options_menu")
	
	# Refresh all tabs
	for tab_name in _tab_connections:
		var tab_node: Node = _tab_connections[tab_name]
		if tab_node and tab_node.has_method("refresh"):
			tab_node.refresh()

func get_options_menu_stats() -> Dictionary:
	"""Get options menu statistics"""
	return {
		"tabs_connected": _tab_connections.size(),
		"tabs_initialized": _tabs_initialized,
		"settings_changed": _settings_changed,
		"current_tab": tab_container.current_tab if tab_container else -1
	}
