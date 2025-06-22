# UIManager.gd
@tool
extends Node
class_name UIManager

## Simple UI manager for Five Parsecs screen management
##
## Handles screen transitions and UI state

signal screen_changed(screen_name: String)
signal ui_update_queued(node: Node, property: String, _value: Variant)

var screens: Dictionary = {}
var current_screen: String = ""
var update_queue: Array = []

func _ready() -> void:
	_register_screens()

func _register_screens() -> void:
	# Find all screen nodes and register them
	for child in get_children():
		if child.has_method("show") and child.has_method("hide"):
			screens[child.name] = child

## Show a specific screen
func show_screen(screen_name: String) -> void:
	if not screens.has(screen_name):
		push_warning("Screen not found: " + screen_name)
		return
	
	# Hide current screen
	if current_screen != "" and screens.has(current_screen):
		screens[current_screen].hide()
	
	# Show new screen
	screens[screen_name].show()
	current_screen = screen_name
	screen_changed.emit(screen_name) # warning: return value discarded (intentional)

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