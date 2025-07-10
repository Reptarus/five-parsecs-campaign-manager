# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Control
class_name MainGameScene

## Main Game Scene for Five Parsecs Campaign Manager
## Primary scene for campaign management and gameplay

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

signal scene_changed(scene_name: String)
signal game_state_updated(state: Dictionary)

@onready var campaign_ui: Control = get_node("PhaseContainer/CampaignDashboard")
@onready var battle_ui: Control = get_node("PhaseContainer/BattlePhase") 
@onready var menu_ui: Control = get_node("PhaseContainer")

var current_scene_mode: String = "menu"
var game_state: Resource
var _fallback_ui: Control

func _ready() -> void:
	print("MainGameScene: Initializing...")
	_initialize_scene()

func _initialize_scene() -> void:
	# Validate Universal connections first
	_validate_scene_connections()

	# Check if we have proper child nodes
	if not campaign_ui or not battle_ui or not menu_ui:
		print("MainGameScene: Missing UI nodes, creating fallback UI")
		_create_fallback_ui()
	else:
		show_menu_ui()

func _validate_scene_connections() -> void:
	# Validate scene dependencies
	var required_autoloads = ["GameState", "EventBus"]
	for autoload_name in required_autoloads:
		var autoload_node: Node = get_node_or_null("/root/" + str(autoload_name))
		if not autoload_node:
			push_warning("SCENE DEPENDENCY MISSING: %s not available (MainGameScene)" % autoload_name)

func _create_fallback_ui() -> void:
	"""Create a simple fallback UI when scene nodes are missing"""
	print("MainGameScene: Creating fallback main game UI...")

	# Create simple container safely
	_fallback_ui = VBoxContainer.new()
	self.add_child(_fallback_ui)

	# Add title safely
	var title := Label.new()
	title.text = "Five Parsecs Campaign Manager - Main Game"
	title.add_theme_font_size_override("font_size", 28)
	_fallback_ui.add_child(title)

	# Add subtitle safely
	var subtitle := Label.new()
	subtitle.text = "Fallback Mode - Basic Navigation Available"
	subtitle.add_theme_font_size_override("font_size", 16)
	_fallback_ui.add_child(subtitle)

	# Add navigation buttons safely
	var nav_container := HBoxContainer.new()
	_fallback_ui.add_child(nav_container)

	var menu_btn := Button.new()
	menu_btn.text = "Campaign Menu"
	menu_btn.pressed.connect(_on_campaign_menu_pressed)
	nav_container.add_child(menu_btn)

	var battle_btn := Button.new()
	battle_btn.text = "Battle Simulator"
	battle_btn.pressed.connect(_on_battle_simulator_pressed)
	nav_container.add_child(battle_btn)

	var back_btn := Button.new()
	back_btn.text = "Back to Main Menu"
	back_btn.pressed.connect(_return_to_main_menu)
	nav_container.add_child(back_btn)

	# Status info safely
	var status := Label.new()
	status.text = "This is a placeholder main game screen. UI components are being loaded..."
	_fallback_ui.add_child(status)

func show_menu_ui() -> void:
	if menu_ui:
		current_scene_mode = "menu"
		menu_ui.show()
		if campaign_ui:
			campaign_ui.hide()
		if battle_ui:
			battle_ui.hide()
		self.scene_changed.emit("menu")
	else:
		print("MainGameScene: menu_ui not available")

func show_campaign_ui() -> void:
	if campaign_ui:
		current_scene_mode = "campaign"
		if menu_ui:
			menu_ui.hide()
		campaign_ui.show()
		if battle_ui:
			battle_ui.hide()
		self.scene_changed.emit("campaign")
	else:
		print("MainGameScene: campaign_ui not available")

func show_battle_ui() -> void:
	if battle_ui:
		current_scene_mode = "battle"
		if menu_ui:
			menu_ui.hide()
		if campaign_ui:
			campaign_ui.hide()
		battle_ui.show()
		self.scene_changed.emit("battle")
	else:
		print("MainGameScene: battle_ui not available")

func get_current_scene_mode() -> String:
	return current_scene_mode

func set_game_state(state: Resource) -> void:
	game_state = state
	if state and state and state.has_method("serialize"):
		var serialized_data = state.serialize()
		self.game_state_updated.emit(serialized_data)
	else:
		self.game_state_updated.emit({})

func get_game_state() -> Resource:
	return game_state

func _on_campaign_menu_pressed() -> void:
	"""Handle campaign menu button in fallback UI"""
	print("MainGameScene: Campaign menu requested")
	show_campaign_ui()

func _on_battle_simulator_pressed() -> void:
	"""Handle battle simulator button in fallback UI"""
	print("MainGameScene: Battle simulator requested")
	show_battle_ui()

func _return_to_main_menu() -> void:
	"""Return to the main menu"""
	print("MainGameScene: Returning to main menu")
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router.has_method("return_to_main_menu"):
		scene_router.return_to_main_menu()
	else:
		# Safe fallback navigation using Universal scene management
		var main_menu_scene = load("res://src/ui/screens/mainmenu/MainMenu.tscn")
		if main_menu_scene:
			SceneRouter.change_scene_safe(get_tree(), main_menu_scene, "MainGameScene return to main menu")
		else:
			push_error("CRASH PREVENTION: Could not load main menu scene for fallback navigation")

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null