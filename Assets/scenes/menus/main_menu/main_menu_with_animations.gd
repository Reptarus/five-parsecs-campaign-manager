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
@onready var new_mission_button: Button = $"Menu Buttons/NewMission"
@onready var continue_mission_button: Button = $"Menu Buttons/ContinueMission"
@onready var squad_management_button: Button = $"Menu Buttons/SquadManagement"
@onready var armory_button: Button = $"Menu Buttons/Armory"
@onready var options_button: Button = $"Menu Buttons/Options"
@onready var rules_reference_button: Button = $"Menu Buttons/RulesReference"

# Additional enhanced functionality
var _buttons_initialized: bool = false
var _button_connections: Dictionary = {}
var _missing_buttons: Array[String] = []
var _animation_player: AnimationPlayer = null
var _animations_enabled: bool = true

# Enhanced signals for tracking
signal menu_button_pressed(button_name: String)
signal scene_transition_requested(scene_path: String)
signal menu_initialized()

func _ready() -> void:
	print("MainMenuWithAnimations: Enhanced initialization starting")
	
	# Enhanced component validation
	_validate_menu_components()
	
	# Enhanced button connections
	_initialize_button_connections()
	
	# Initialize animations
	_initialize_animations()

func _validate_menu_components() -> void:
	"""Validate menu components with enhanced tracking"""
	
	var button_configs: Array[Dictionary] = [
		{"node": new_mission_button, "name": "NewMission"},
		{"node": continue_mission_button, "name": "ContinueMission"},
		{"node": squad_management_button, "name": "SquadManagement"},
		{"node": armory_button, "name": "Armory"},
		{"node": options_button, "name": "Options"},
		{"node": rules_reference_button, "name": "RulesReference"}
	]
	
	for config in button_configs:
		var button: Button = config.node
		var button_name: String = config.name
		
		if not button:
			push_warning("MainMenuWithAnimations: Missing button: " + button_name)
			_missing_buttons.append(button_name)
		else:
			print("MainMenuWithAnimations: Validated button: " + button_name)
	
	# Try to find animation player
	_animation_player = UniversalNodeAccess.get_node_safe(self, "AnimationPlayer", "MainMenuWithAnimations _validate_menu_components")
	if _animation_player:
		print("MainMenuWithAnimations: AnimationPlayer found")
	else:
		push_warning("MainMenuWithAnimations: AnimationPlayer not found - animations disabled")
		_animations_enabled = false

func _initialize_button_connections() -> void:
	"""Initialize button connections with enhanced validation"""
	
	print("MainMenuWithAnimations: Initializing button connections...")
	
	# Connect buttons with enhanced error handling
	_connect_button_safe(new_mission_button, "new_mission", _on_new_mission_pressed)
	_connect_button_safe(continue_mission_button, "continue_mission", _on_continue_mission_pressed)
	_connect_button_safe(squad_management_button, "squad_management", _on_squad_management_pressed)
	_connect_button_safe(armory_button, "armory", _on_armory_pressed)
	_connect_button_safe(options_button, "options", _on_options_pressed)
	_connect_button_safe(rules_reference_button, "rules_reference", _on_rules_reference_pressed)
	
	_buttons_initialized = true
	print("MainMenuWithAnimations: Button connections completed")

func _connect_button_safe(button: Button, button_id: String, callback: Callable) -> void:
	"""Connect button safely with enhanced tracking"""
	
	if not button:
		push_warning("MainMenuWithAnimations: Cannot connect %s button - not available" % button_id)
		return
	
	var connection_success: bool = UniversalSignalManager.connect_signal_safe(
		button,
		"pressed",
		callback,
		"MainMenuWithAnimations " + button_id
	)
	
	if connection_success:
		_button_connections[button_id] = button
		print("MainMenuWithAnimations: Connected %s button successfully" % button_id)

func _initialize_animations() -> void:
	"""Initialize animation system"""
	
	if not _animations_enabled or not _animation_player:
		return
	
	print("MainMenuWithAnimations: Animation system initialized")
	
	# Play entrance animation if available
	if _animation_player.has_animation("menu_entrance"):
		_animation_player.play("menu_entrance")

func _on_new_mission_pressed() -> void:
	print("MainMenuWithAnimations: New Mission button pressed")
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "menu_button_pressed", ["new_mission"], "MainMenuWithAnimations _on_new_mission_pressed")
	
	# Enhanced navigation
	_navigate_to_scene("res://assets/scenes/bug_hunt/mission_setup.tscn", "New Mission")

func _on_continue_mission_pressed() -> void:
	print("MainMenuWithAnimations: Continue Mission button pressed")
	
	UniversalSignalManager.emit_signal_safe(self, "menu_button_pressed", ["continue_mission"], "MainMenuWithAnimations _on_continue_mission_pressed")
	
	# Enhanced game loading
	_load_game_safe()

func _on_squad_management_pressed() -> void:
	print("MainMenuWithAnimations: Squad Management button pressed")
	
	UniversalSignalManager.emit_signal_safe(self, "menu_button_pressed", ["squad_management"], "MainMenuWithAnimations _on_squad_management_pressed")
	
	_navigate_to_scene("res://assets/scenes/bug_hunt/squad_management.tscn", "Squad Management")

func _on_armory_pressed() -> void:
	print("MainMenuWithAnimations: Armory button pressed")
	
	UniversalSignalManager.emit_signal_safe(self, "menu_button_pressed", ["armory"], "MainMenuWithAnimations _on_armory_pressed")
	
	_navigate_to_scene("res://assets/scenes/bug_hunt/armory.tscn", "Armory")

func _on_options_pressed() -> void:
	print("MainMenuWithAnimations: Options button pressed")
	
	UniversalSignalManager.emit_signal_safe(self, "menu_button_pressed", ["options"], "MainMenuWithAnimations _on_options_pressed")
	
	_navigate_to_scene("res://assets/scenes/menus/options_menu/options_menu.tscn", "Options")

func _on_rules_reference_pressed() -> void:
	print("MainMenuWithAnimations: Rules Reference button pressed")
	
	UniversalSignalManager.emit_signal_safe(self, "menu_button_pressed", ["rules_reference"], "MainMenuWithAnimations _on_rules_reference_pressed")
	
	_navigate_to_scene("res://assets/scenes/bug_hunt/rules_reference.tscn", "Rules Reference")

func _navigate_to_scene(scene_path: String, scene_name: String) -> void:
	"""Navigate to scene with enhanced validation"""
	
	print("MainMenuWithAnimations: Navigating to %s: %s" % [scene_name, scene_path])
	
	# Validate scene exists
	if not ResourceLoader.exists(scene_path):
		push_error("MainMenuWithAnimations: Scene not found: " + scene_path)
		_show_navigation_error("Scene not found: " + scene_name)
		return
	
	# Enhanced signal emission
	UniversalSignalManager.emit_signal_safe(self, "scene_transition_requested", [scene_path], "MainMenuWithAnimations _navigate_to_scene")
	
	# Play exit animation if available
	if _animations_enabled and _animation_player and _animation_player.has_animation("menu_exit"):
		_animation_player.play("menu_exit")
	
	# Enhanced navigation
	var main_node: Node = UniversalNodeAccess.get_node_safe(get_tree().root, "Main", "MainMenuWithAnimations _navigate_to_scene")
	
	if main_node and main_node.has_method("goto_scene"):
		main_node.goto_scene(scene_path)
		print("MainMenuWithAnimations: Navigation successful to: " + scene_name)
	else:
		push_warning("MainMenuWithAnimations: Main node not available, using direct scene change")
		_direct_scene_change(scene_path)

func _load_game_safe() -> void:
	"""Load game with enhanced validation"""
	
	print("MainMenuWithAnimations: Attempting to load game")
	
	var main_node: Node = UniversalNodeAccess.get_node_safe(get_tree().root, "Main", "MainMenuWithAnimations _load_game_safe")
	
	if main_node and main_node.has_method("load_game"):
		main_node.load_game()
		print("MainMenuWithAnimations: Game load request sent")
	else:
		push_error("MainMenuWithAnimations: Cannot load game - Main node not available")
		_show_navigation_error("Cannot load game - Main system not available")

func _direct_scene_change(scene_path: String) -> void:
	"""Direct scene change fallback"""
	
	var tree: SceneTree = get_tree()
	if tree:
		tree.call_deferred("change_scene_to_file", scene_path)
		print("MainMenuWithAnimations: Direct scene change initiated")
	else:
		push_error("MainMenuWithAnimations: Cannot change scene - SceneTree not available")

func _show_navigation_error(error_message: String) -> void:
	"""Show navigation error dialog"""
	
	print("MainMenuWithAnimations: Navigation error: " + error_message)
	
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.dialog_text = "Navigation Error: " + error_message
	dialog.title = "Main Menu Error"
	add_child(dialog)
	dialog.popup_centered()

func get_menu_stats() -> Dictionary:
	"""Get menu statistics"""
	return {
		"buttons_connected": _button_connections.size(),
		"buttons_missing": _missing_buttons.size(),
		"animations_enabled": _animations_enabled,
		"initialization_complete": _buttons_initialized
	}
