# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Control
class_name MainGameScene

## Main Game Scene for Five Parsecs Campaign Manager
## Primary scene for campaign management and gameplay

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

signal scene_changed(scene_name: String)
signal game_state_updated(state: Dictionary)

@onready var campaign_ui: Control = UniversalNodeAccess.get_node_safe(self, "CampaignUI", "MainGameScene CampaignUI")
@onready var battle_ui: Control = UniversalNodeAccess.get_node_safe(self, "BattleUI", "MainGameScene BattleUI")
@onready var menu_ui: Control = UniversalNodeAccess.get_node_safe(self, "MenuUI", "MainGameScene MenuUI")

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
		var autoload_node = get_node_or_null("/root/" + autoload_name)
		if not autoload_node:
			push_warning("SCENE DEPENDENCY MISSING: %s not available (MainGameScene)" % autoload_name)

func _create_fallback_ui() -> void:
	"""Create a simple fallback UI when scene nodes are missing"""
	print("MainGameScene: Creating fallback main game UI...")
	
	# Create simple container safely
	_fallback_ui = VBoxContainer.new()
	if not UniversalNodeAccess.add_child_safe(self, _fallback_ui, "MainGameScene fallback UI container"):
		push_error("CRASH PREVENTION: Failed to add fallback UI container")
		return
	
	# Add title safely
	var title := Label.new()
	title.text = "Five Parsecs Campaign Manager - Main Game"
	title.add_theme_font_size_override("font_size", 28)
	if not UniversalNodeAccess.add_child_safe(_fallback_ui, title, "MainGameScene title"):
		push_error("CRASH PREVENTION: Failed to add title to fallback UI")
		return
	
	# Add subtitle safely
	var subtitle := Label.new()
	subtitle.text = "Fallback Mode - Basic Navigation Available"
	subtitle.add_theme_font_size_override("font_size", 16)
	UniversalNodeAccess.add_child_safe(_fallback_ui, subtitle, "MainGameScene subtitle")
	
	# Add navigation buttons safely
	var nav_container := HBoxContainer.new()
	if not UniversalNodeAccess.add_child_safe(_fallback_ui, nav_container, "MainGameScene nav container"):
		return
	
	var menu_btn := Button.new()
	menu_btn.text = "Campaign Menu"
	UniversalSignalManager.connect_signal_safe(menu_btn, "pressed", _on_campaign_menu_pressed, "MainGameScene menu button")
	UniversalNodeAccess.add_child_safe(nav_container, menu_btn, "MainGameScene menu button")
	
	var battle_btn := Button.new()
	battle_btn.text = "Battle Simulator"
	UniversalSignalManager.connect_signal_safe(battle_btn, "pressed", _on_battle_simulator_pressed, "MainGameScene battle button")
	UniversalNodeAccess.add_child_safe(nav_container, battle_btn, "MainGameScene battle button")
	
	var back_btn := Button.new()
	back_btn.text = "Back to Main Menu"
	UniversalSignalManager.connect_signal_safe(back_btn, "pressed", _return_to_main_menu, "MainGameScene back button")
	UniversalNodeAccess.add_child_safe(nav_container, back_btn, "MainGameScene back button")
	
	# Status info safely
	var status := Label.new()
	status.text = "This is a placeholder main game screen. UI components are being loaded..."
	UniversalNodeAccess.add_child_safe(_fallback_ui, status, "MainGameScene status")

func show_menu_ui() -> void:
	if menu_ui:
		current_scene_mode = "menu"
		menu_ui.show()
		if campaign_ui:
			campaign_ui.hide()
		if battle_ui:
			battle_ui.hide()
		UniversalSignalManager.emit_signal_safe(self, "scene_changed", ["menu"], "MainGameScene show_menu_ui")
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
		UniversalSignalManager.emit_signal_safe(self, "scene_changed", ["campaign"], "MainGameScene show_campaign_ui")
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
		UniversalSignalManager.emit_signal_safe(self, "scene_changed", ["battle"], "MainGameScene show_battle_ui")
	else:
		print("MainGameScene: battle_ui not available")

func get_current_scene_mode() -> String:
	return current_scene_mode

func set_game_state(state: Resource) -> void:
	game_state = state
	if state and state.has_method("serialize"):
		var serialized_data = state.serialize()
		UniversalSignalManager.emit_signal_safe(self, "game_state_updated", [serialized_data], "MainGameScene set_game_state")
	else:
		UniversalSignalManager.emit_signal_safe(self, "game_state_updated", [{}], "MainGameScene set_game_state fallback")

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
	var scene_router = UniversalNodeAccess.get_node_safe(get_tree().root, "/root/SceneRouter", "MainGameScene scene router access")
	if scene_router and scene_router.has_method("return_to_main_menu"):
		scene_router.return_to_main_menu()
	else:
		# Safe fallback navigation using Universal scene management
		var main_menu_scene = UniversalResourceLoader.load_resource_safe("res://src/ui/screens/mainmenu/MainMenu.tscn", "PackedScene", "MainGameScene main menu fallback")
		if main_menu_scene:
			UniversalSceneManager.change_scene_safe(get_tree(), main_menu_scene, "MainGameScene return to main menu")
		else:
			push_error("CRASH PREVENTION: Could not load main menu scene for fallback navigation")
