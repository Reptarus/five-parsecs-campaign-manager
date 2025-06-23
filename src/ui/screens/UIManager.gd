# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Node
class_name UIManager

## Simple UI manager for Five Parsecs screen management
##
## Handles screen transitions and UI state

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

signal screen_changed(screen_name: String)
signal ui_update_queued(node: Node, property: String, _value: Variant)

var screens: Dictionary = {}
var current_screen: String = ""
var update_queue: Array = []

func _ready() -> void:
	_validate_universal_connections()
	_register_screens()

func _validate_universal_connections() -> void:
	# Validate UI system connections
	_validate_ui_manager_connections()

func _validate_ui_manager_connections() -> void:
	# Validate autoload connections that UI might need
	var useful_autoloads = ["GameState", "EventBus"]
	for autoload_name in useful_autoloads:
		var autoload_node = get_node_or_null("/root/" + autoload_name)
		if not autoload_node:
			push_warning("UI SYSTEM INFO: %s not available (UIManager - may not be critical)" % autoload_name)

func _register_screens() -> void:
	# Find all screen nodes and register them safely
	var children = get_children()
	for child in children:
		if not child:
			push_warning("UIManager: Found null child during screen registration")
			continue
			
		if child.has_method("show") and child.has_method("hide"):
			UniversalDataAccess.set_dict_value_safe(screens, child.name, child, "UIManager screen registration")

## Show a specific screen
func show_screen(screen_name: String) -> void:
	if screen_name.is_empty():
		push_error("CRASH PREVENTION: Empty screen name provided to show_screen")
		return
		
	var target_screen = UniversalDataAccess.get_dict_value_safe(screens, screen_name, null, "UIManager show_screen lookup")
	if not target_screen:
		push_warning("UIManager: Screen not found: " + screen_name)
		return
	
	# Hide current screen safely
	if current_screen != "":
		var current_screen_node = UniversalDataAccess.get_dict_value_safe(screens, current_screen, null, "UIManager hide current screen")
		if current_screen_node and current_screen_node.has_method("hide"):
			current_screen_node.hide()
	
	# Show new screen safely
	if target_screen.has_method("show"):
		target_screen.show()
		current_screen = screen_name
		UniversalSignalManager.emit_signal_safe(self, "screen_changed", [screen_name], "UIManager screen_changed")
	else:
		push_error("CRASH PREVENTION: Target screen does not have show method: " + screen_name)

## Hide current screen
func hide_current_screen() -> void:
	if current_screen != "" and screens.has(current_screen):
		screens[current_screen].hide()
		current_screen = ""

## Queue a UI update for processing
func queue_ui_update(node: Node, property: String, value: Variant) -> void:
	var update = {
		"node": node,
		"property": property,
		"value": value
	}
	update_queue.append(update) # warning: return value discarded (intentional)
	ui_update_queued.emit(node, property, value) # warning: return value discarded (intentional)

## Process queued UI updates
func process_ui_updates() -> void:
	for update in update_queue:
		if is_instance_valid(update.node):
			update.node.set(update.property, update.value)
	update_queue.clear()

## Show game over screen
func show_game_over_screen(victory: bool, message: String = "") -> void:
	if screens.has("GameOverScreen"):
		var game_over_screen = screens["GameOverScreen"]
		if game_over_screen.has_method("setup_game_over"):
			game_over_screen.setup_game_over(victory, message)
		show_screen("GameOverScreen")
	else:
		push_warning("GameOverScreen not found")

## Hide all screens
func hide_all_screens() -> void:
	for screen in screens.values():
		if is_instance_valid(screen):
			screen.hide()
	current_screen = ""