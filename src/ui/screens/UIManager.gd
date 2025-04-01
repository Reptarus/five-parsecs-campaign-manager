@tool
extends Node

## UI Manager for handling screen navigation, dialogs, and theme management
## This class is responsible for managing the UI system, including showing/hiding
## screens, managing dialogs, and handling theme changes.

# Signals for UI state changes
signal screen_changed(screen_name)
signal dialog_opened(dialog_name, dialog_data)
signal dialog_closed(dialog_name)
signal theme_applied(theme_name)

# UI state tracking
var screen_stack: Array[String] = []
var current_screen: String = ""
var current_dialog: String = ""
var dialog_stack: Array[Dictionary] = []
var has_modal: bool = false
var theme_manager = null
var options_menu = null

# Screen management
func show_screen(screen_name: String) -> void:
	var previous_screen = current_screen
	current_screen = screen_name
	screen_stack.append(previous_screen)
	emit_signal("screen_changed", screen_name)

func hide_screen(screen_name: String = "") -> void:
	if screen_stack.size() > 0:
		current_screen = screen_stack.pop_back()
	else:
		current_screen = ""
	emit_signal("screen_changed", current_screen)

func show_screen_with_transition(screen_name: String, transition_time: float = 0.3) -> void:
	show_screen(screen_name)
	# Additional transition logic would go here

# Modal management
func show_modal(modal_name: String) -> void:
	has_modal = true
	screen_stack.append(current_screen)
	current_screen = modal_name
	emit_signal("screen_changed", modal_name)

func hide_modal() -> void:
	has_modal = false
	if screen_stack.size() > 0:
		current_screen = screen_stack.pop_back()
	else:
		current_screen = ""
	emit_signal("screen_changed", current_screen)

# Dialog management
func show_dialog(dialog_name: String, dialog_data: Dictionary = {}) -> void:
	current_dialog = dialog_name
	dialog_stack.append({"name": dialog_name, "data": dialog_data})
	emit_signal("dialog_opened", dialog_name, dialog_data)

func hide_dialog(dialog_name: String) -> void:
	if current_dialog == dialog_name:
		current_dialog = ""
		if dialog_stack.size() > 0:
			dialog_stack.pop_back()
		emit_signal("dialog_closed", dialog_name)

# Options menu management
func connect_options_menu(options_menu_node) -> void:
	options_menu = options_menu_node
	
	if options_menu and options_menu.has_signal("back_pressed"):
		if not options_menu.back_pressed.is_connected(hide_options):
			options_menu.back_pressed.connect(hide_options)
			
	if options_menu and options_menu.has_signal("settings_applied"):
		# You might want to connect to this signal for additional actions when settings are applied
		pass
		
func show_options() -> bool:
	if not options_menu:
		# Try to find options menu in the scene
		options_menu = get_node_or_null("/root/Main/OptionsMenu")
		if not options_menu:
			return false
	
	if options_menu.has_method("show_menu"):
		options_menu.show_menu()
		return true
	return false

func hide_options() -> bool:
	if not options_menu:
		return false
	
	if options_menu.has_method("hide_menu"):
		options_menu.hide_menu()
		return true
	return false

# Theme management
func connect_theme_manager(theme_mgr) -> void:
	theme_manager = theme_mgr

func apply_theme(theme_name: String) -> void:
	if theme_manager and theme_manager.has_method("set_theme"):
		theme_manager.set_theme(theme_name)
	emit_signal("theme_applied", theme_name)

func get_current_theme() -> String:
	if theme_manager and theme_manager.has_method("get_current_theme_name"):
		return theme_manager.current_theme_name
	return "default"

func set_ui_scale(scale: float) -> void:
	if theme_manager and "ui_scale" in theme_manager:
		theme_manager.ui_scale = scale

func set_high_contrast(enabled: bool) -> void:
	if theme_manager and "high_contrast_enabled" in theme_manager:
		theme_manager.high_contrast_enabled = enabled

func toggle_animations(enabled: bool) -> void:
	if theme_manager and "animations_enabled" in theme_manager:
		theme_manager.animations_enabled = enabled

func set_text_size(size: String) -> void:
	if theme_manager and theme_manager.has_method("set_text_size"):
		theme_manager.set_text_size(size)

# Settings persistence
func save_ui_settings() -> void:
	if theme_manager and theme_manager.has_method("save_settings"):
		theme_manager.save_settings()

func load_ui_settings() -> void:
	if theme_manager and theme_manager.has_method("load_settings"):
		theme_manager.load_settings()

# Cleanup
func cleanup() -> void:
	current_screen = ""
	has_modal = false
	screen_stack.clear()
	dialog_stack.clear()
	current_dialog = ""
	emit_signal("screen_changed", "")
