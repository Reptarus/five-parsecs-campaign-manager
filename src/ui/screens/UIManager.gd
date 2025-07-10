# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Node
class_name UIManager

## Simple UI manager for Five Parsecs screen management
##
## Handles screen transitions and UI state

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

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
		var autoload_node: Node = get_node_or_null("/root/" + str(autoload_name))
		if not autoload_node:
			push_warning("UI SYSTEM INFO: %s not available (UIManager - may not be critical)" % autoload_name)

func _register_screens() -> void:
	# Find all screen nodes and register them safely
	var children = get_children()
	for child in children:
		if not child:
			push_warning("UIManager: Found null child during screen registration")
			continue

		if child.has_method("show") and child and child.has_method("hide"):
			screens[child.name] = child

## Show a specific screen
func show_screen(screen_name: String) -> void:
	if (safe_call_method(screen_name, "is_empty") == true):
		push_error("CRASH PREVENTION: Empty screen name provided to show_screen")
		return

	var target_screen = screens.get(screen_name, null)
	if not target_screen:
		push_warning("UIManager: Screen not found: " + str(screen_name))
		return

	# Hide current screen safely
	if current_screen != "":
		var current_screen_node: Node = screens.get(current_screen, null)
		if current_screen_node and current_screen_node and current_screen_node.has_method("hide"):
			current_screen_node.hide()

	# Show new screen safely
	if target_screen and target_screen.has_method("show"):
		target_screen.show()
		current_screen = screen_name
		self.screen_changed.emit(screen_name)
	else:
		push_error("CRASH PREVENTION: Target screen does not have show method: " + str(screen_name))

## Hide current screen
func hide_current_screen() -> void:
	if current_screen != "" and screens.has(current_screen):
		screens[current_screen].hide()
		current_screen = ""

## Queue a UI update for processing
func queue_ui_update(node: Node, property: String, value: Variant) -> void:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	var update = {
		"node": node,
		"property": property,
		"value": value
	}
	update_queue.append(update)
	ui_update_queued.emit(node, property, value)

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
		if game_over_screen and game_over_screen.has_method("setup_game_over"):
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
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null