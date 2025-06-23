# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
extends Control

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Developer Quick Start Panel for playtesting efficiency
const DeveloperQuickStart = preload("res://src/ui/debug/DeveloperQuickStart.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameStateManager = null
var GameEnums = null

# Node references using safe access
@onready var continue_button = UniversalNodeAccess.get_node_safe(self, "%Continue", "MainMenu continue_button") as Button
@onready var new_campaign_button = UniversalNodeAccess.get_node_safe(self, "%NewCampaign", "MainMenu new_campaign_button") as Button
@onready var coop_campaign_button = UniversalNodeAccess.get_node_safe(self, "%CoopCampaign", "MainMenu coop_campaign_button") as Button
@onready var battle_simulator_button = UniversalNodeAccess.get_node_safe(self, "%BattleSimulator", "MainMenu battle_simulator_button") as Button
@onready var bug_hunt_button = UniversalNodeAccess.get_node_safe(self, "%BugHunt", "MainMenu bug_hunt_button") as Button
@onready var options_button = UniversalNodeAccess.get_node_safe(self, "%Options", "MainMenu options_button") as Button
@onready var library_button = UniversalNodeAccess.get_node_safe(self, "%Library", "MainMenu library_button") as Button
@onready var tutorial_popup = UniversalNodeAccess.get_node_safe(self, "%TutorialPopup", "MainMenu tutorial_popup") as Panel

var game_state_manager: Node
var _active_dialogs: Array[Node] = []

# Developer panel variables
var developer_panel: Control
var developer_mode: bool = false
var show_developer_button: Button

func _exit_tree() -> void:
	_cleanup_dialogs()
	if game_state_manager:
		game_state_manager = null
	if developer_panel:
		developer_panel = null

func setup(manager: Node) -> void:
	if not manager:
		push_error("MainMenu: Invalid game state manager provided")
		return
	
	game_state_manager = manager
	update_continue_button_visibility()

func _ready() -> void:
	print("MainMenu: Starting initialization...")
	
	# Load dependencies safely at runtime
	GameStateManager = UniversalResourceLoader.load_script_safe("res://src/core/managers/GameStateManager.gd", "MainMenu GameStateManager")
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "MainMenu GameEnums")
	
	if not _validate_required_nodes():
		push_error("MainMenu: Required nodes are missing")
		return
	
	# Try to connect to autoloaded game state manager
	_try_connect_to_autoloads()
	
	setup_ui()
	if tutorial_popup:
		tutorial_popup.hide()
		_connect_tutorial_signals()
	
	# Setup developer panel if in debug mode
	_setup_developer_panel()
	
	print("MainMenu: Initialization complete!")

func _try_connect_to_autoloads() -> void:
	"""Safely connect to autoloaded managers"""
	print("MainMenu: Attempting to connect to autoloads...")
	
	# Try to get GameStateManager
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm:
		game_state_manager = gsm
		print("MainMenu: Connected to GameStateManager")
		update_continue_button_visibility()
	else:
		print("MainMenu: GameStateManager not found - some features will be limited")
	
	# Test other critical autoloads
	var campaign_mgr = get_node_or_null("/root/CampaignManager")
	if campaign_mgr:
		print("MainMenu: CampaignManager found and working")
	else:
		print("MainMenu: CampaignManager not available")
	
	var dice_mgr = get_node_or_null("/root/DiceManager")
	if dice_mgr:
		print("MainMenu: DiceManager found and working")
	else:
		print("MainMenu: DiceManager not available")

func _validate_required_nodes() -> bool:
	var required_nodes := [
		continue_button,
		new_campaign_button,
		coop_campaign_button,
		battle_simulator_button,
		bug_hunt_button,
		options_button,
		library_button,
		tutorial_popup
	]
	
	for node in required_nodes:
		if not node:
			return false
	return true

func _connect_tutorial_signals() -> void:
	var tutorial_container := tutorial_popup.get_node_or_null("VBoxContainer")
	if not tutorial_container:
		push_error("MainMenu: Tutorial container not found")
		return
	
	var buttons := {
		"StoryTrackButton": "story_track",
		"CompendiumButton": "compendium",
		"SkipButton": "skip"
	}
	
	for button_name in buttons:
		var button := tutorial_container.get_node_or_null(button_name) as Button
		if button:
			# Safely disconnect if connected
			if button.is_connected("pressed", _on_tutorial_popup_button_pressed):
				button.pressed.disconnect(_on_tutorial_popup_button_pressed)
			button.pressed.connect(_on_tutorial_popup_button_pressed.bind(buttons[button_name]))

func setup_ui() -> void:
	_connect_buttons()
	_setup_developer_button()
	add_fade_in_animation()

func _connect_buttons() -> void:
	if continue_button:
		_safe_connect(continue_button, "pressed", _on_continue_pressed)
	if new_campaign_button:
		new_campaign_button.text = "New Campaign (Test Main Game)"
		_safe_connect(new_campaign_button, "pressed", _on_new_campaign_pressed)
	if coop_campaign_button:
		_safe_connect(coop_campaign_button, "pressed", _on_coop_campaign_pressed)
	if battle_simulator_button:
		_safe_connect(battle_simulator_button, "pressed", _on_battle_simulator_pressed)
	if bug_hunt_button:
		_safe_connect(bug_hunt_button, "pressed", _on_bug_hunt_pressed)
	if options_button:
		_safe_connect(options_button, "pressed", _on_options_pressed)
	if library_button:
		library_button.text = "Test Autoloads"
		_safe_connect(library_button, "pressed", _on_library_pressed)

func _safe_connect(node: Node, signal_name: String, callback: Callable) -> void:
	if node.is_connected(signal_name, callback):
		node.disconnect(signal_name, callback)
	node.connect(signal_name, callback) # warning: return value discarded (intentional)

func add_fade_in_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func update_continue_button_visibility() -> void:
	if not continue_button:
		return
	
	continue_button.visible = false
	
	if not is_instance_valid(game_state_manager):
		return
	
	if not game_state_manager.has_method("has_active_campaign"):
		return
	
	continue_button.visible = game_state_manager.has_active_campaign()

func _on_continue_pressed() -> void:
	if not is_instance_valid(game_state_manager):
		show_message("No active campaign to continue")
		return
	
	if game_state_manager.has_method("has_active_campaign") and game_state_manager.has_active_campaign():
		request_scene_change("crew_management")
	else:
		show_message("No active campaign to continue")

func _on_new_campaign_pressed() -> void:
	print("MainMenu: New Campaign button pressed")
	
	# Transition to campaign creation UI
	_transition_to_campaign_creation()
	
	# Original logic with tutorial popup (commented out for debugging)
	#if not is_instance_valid(game_state_manager):
	#	push_error("MainMenu: Game state manager is invalid")
	#	return
	#

	#if game_state_manager.settings.get("disable_tutorial_popup", false):
	#	_start_new_campaign()
	#else:
	#	_show_tutorial_popup()

func _transition_to_campaign_creation() -> void:
	"""Transition to the campaign creation UI"""
	print("MainMenu: Transitioning to campaign creation...")
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router.has_method("start_new_campaign"):
		scene_router.start_new_campaign()
	else:
		push_warning("SceneRouter not found or method unavailable")

func _transition_to_main_game() -> void:
	"""Transition directly to the main game scene for testing"""
	print("MainMenu: Transitioning to main game scene...")
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router.has_method("enter_main_game"):
		scene_router.enter_main_game()
	else:
		push_warning("SceneRouter not found or method unavailable")

func _show_tutorial_popup() -> void:
	if not tutorial_popup:
		push_error("MainMenu: Tutorial popup not found")
		return

	var checkbox := tutorial_popup.get_node_or_null("VBoxContainer/DisableTutorialCheckbox") as CheckBox
	if checkbox and is_instance_valid(game_state_manager):
		checkbox.button_pressed = game_state_manager.settings.get("disable_tutorial_popup", false)
	
	tutorial_popup.visible = true

func _start_new_campaign() -> void:
	if not is_instance_valid(game_state_manager):
		push_error("MainMenu: Game state manager is invalid")
		return
	
	if game_state_manager.has_method("start_new_campaign"):
		game_state_manager.start_new_campaign()
		request_scene_change("campaign_setup")

func _on_tutorial_popup_button_pressed(choice: String) -> void:
	if tutorial_popup:
		tutorial_popup.visible = false
	_handle_tutorial_choice(choice)

func _handle_tutorial_choice(choice: String) -> void:
	if not is_instance_valid(game_state_manager):
		push_error("MainMenu: Game state manager is invalid")
		return
	
	if not game_state_manager.has_method("set_tutorial_state"):
		push_error("MainMenu: Game state manager missing set_tutorial_state method")
		return
	
	match choice:
		"story_track", "compendium":
			game_state_manager.set_tutorial_state(true)
			request_scene_change("tutorial_setup")
		"skip":
			game_state_manager.set_tutorial_state(false)
			_start_new_campaign()

func _on_disable_tutorial_toggled(button_pressed: bool) -> void:
	if not is_instance_valid(game_state_manager):
		return
	
	game_state_manager.settings["disable_tutorial_popup"] = button_pressed
	if game_state_manager.has_method("save_settings"):
		game_state_manager.save_settings()

func _on_coop_campaign_pressed() -> void:
	show_message("Co-op Campaign feature is coming soon!")

func _on_battle_simulator_pressed() -> void:
	request_scene_change("battle_simulator")

func _on_bug_hunt_pressed() -> void:
	show_message("Bug Hunt feature is coming soon!")

func _on_options_pressed() -> void:
	request_scene_change("options")

func _on_library_pressed() -> void:
	# Use Library button as system test for now
	_test_autoload_systems()
	#request_scene_change("library")

func _test_autoload_systems() -> void:
	"""Test all autoload systems and report their status"""
	print("=== AUTOLOAD SYSTEM TEST ===")
	var test_results: Array[String] = []
	
	# Test GameStateManager
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm:
		test_results.append("✓ GameStateManager: WORKING") # warning: return value discarded (intentional)
		if gsm.has_method("get_active_campaign"):
			test_results.append("  - get_active_campaign method: ✓") # warning: return value discarded (intentional)
		else:
			test_results.append("  - get_active_campaign method: ✗") # warning: return value discarded (intentional)
	else:
		test_results.append("✗ GameStateManager: NOT FOUND") # warning: return value discarded (intentional)
	
	# Test CampaignManager
	var cm = get_node_or_null("/root/CampaignManager")
	if cm:
		test_results.append("✓ CampaignManager: WORKING") # warning: return value discarded (intentional)
		if cm.has_method("start_campaign_turn"):
			test_results.append("  - start_campaign_turn method: ✓") # warning: return value discarded (intentional)
		else:
			test_results.append("  - start_campaign_turn method: ✗") # warning: return value discarded (intentional)
	else:
		test_results.append("✗ CampaignManager: NOT FOUND") # warning: return value discarded (intentional)
	
	# Test DiceManager
	var dm = get_node_or_null("/root/DiceManager")
	if dm:
		test_results.append("✓ DiceManager: WORKING") # warning: return value discarded (intentional)
		if dm.has_method("roll_d6"):
			test_results.append("  - roll_d6 method: ✓") # warning: return value discarded (intentional)
		else:
			test_results.append("  - roll_d6 method: ✗") # warning: return value discarded (intentional)
	else:
		test_results.append("✗ DiceManager: NOT FOUND") # warning: return value discarded (intentional)
	
	# Test AlphaGameManager
	var agm = get_node_or_null("/root/AlphaGameManager")
	if agm:
		test_results.append("✓ AlphaGameManager: WORKING") # warning: return value discarded (intentional)
		if agm.has_method("start_new_campaign"):
			test_results.append("  - start_new_campaign method: ✓") # warning: return value discarded (intentional)
		else:
			test_results.append("  - start_new_campaign method: ✗") # warning: return value discarded (intentional)
	else:
		test_results.append("✗ AlphaGameManager: NOT FOUND") # warning: return value discarded (intentional)
	
	print("=== TEST RESULTS ===")
	for result in test_results:
		print(result)
	print("====================")
	
	# Show results in dialog
	var result_text: String = "\n".join(test_results)
	show_message("Autoload System Test Results:\n\n" + result_text)

## Developer Panel Methods

func _setup_developer_panel() -> void:
	"""Setup developer quick start panel if in debug mode"""
	developer_mode = OS.is_debug_build()
	if not developer_mode:
		return
	
	print("MainMenu: Setting up developer panel for playtesting efficiency...")
	
	# Load and instantiate developer panel
	var developer_scene = UniversalResourceLoader.load_resource_safe(
		"res://src/ui/debug/DeveloperQuickStart.tscn", 
		"PackedScene", 
		"MainMenu developer panel scene"
	)
	
	if developer_scene:
		developer_panel = developer_scene.instantiate()
		if developer_panel:
			developer_panel.hide()  # Start hidden
			UniversalNodeAccess.add_child_safe(self, developer_panel, "MainMenu developer panel")
			_connect_developer_signals()
			print("MainMenu: Developer panel ready - press F11 to toggle")
		else:
			push_error("MainMenu: Failed to instantiate developer panel")
	else:
		print("MainMenu: Developer panel scene not available")

func _setup_developer_button() -> void:
	"""Add developer button to main menu if in debug mode"""
	if not developer_mode:
		return
	
	# Create developer access button
	show_developer_button = Button.new()
	show_developer_button.text = "🚀 DEVELOPER PANEL (F11)"
	show_developer_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	show_developer_button.add_theme_color_override("font_color", Color.YELLOW)
	
	_safe_connect(show_developer_button, "pressed", _on_show_developer_panel_pressed)
	
	# Add to main menu layout (position at bottom)
	UniversalNodeAccess.add_child_safe(self, show_developer_button, "MainMenu developer button")
	
	print("MainMenu: Developer button added")

func _connect_developer_signals() -> void:
	"""Connect developer panel signals"""
	if not developer_panel:
		return
	
	# Connect panel signals to appropriate handlers
	UniversalSignalManager.connect_signal_safe(
		developer_panel, "test_campaign_requested",
		_on_test_campaign_requested, "MainMenu developer test_campaign_requested"
	)
	
	UniversalSignalManager.connect_signal_safe(
		developer_panel, "direct_phase_requested",
		_on_direct_phase_requested, "MainMenu developer direct_phase_requested"
	)
	
	UniversalSignalManager.connect_signal_safe(
		developer_panel, "test_scenario_requested",
		_on_test_scenario_requested, "MainMenu developer test_scenario_requested"
	)

func _input(event: InputEvent) -> void:
	"""Handle developer panel hotkey"""
	if not developer_mode or not developer_panel:
		return
	
	# Toggle developer panel with F11
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_developer_panel()

func _toggle_developer_panel() -> void:
	"""Toggle developer panel visibility"""
	if not developer_panel:
		return
	
	if developer_panel.visible:
		developer_panel.hide()
		print("MainMenu: Developer panel hidden")
	else:
		developer_panel.show()
		print("MainMenu: Developer panel shown")

func _on_show_developer_panel_pressed() -> void:
	"""Handle developer panel button press"""
	_toggle_developer_panel()

## Developer Panel Event Handlers

func _on_test_campaign_requested(campaign_data: Dictionary) -> void:
	"""Handle test campaign creation request"""
	print("MainMenu: Test campaign requested - ", campaign_data.get("name", "Unknown"))
	
	# Create the test campaign via GameStateManager if available
	if game_state_manager and game_state_manager.has_method("create_test_campaign"):
		game_state_manager.create_test_campaign(campaign_data)
	
	# Navigate to the target phase or main game
	var target_phase = campaign_data.get("phase", "world")
	var scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router:
		if target_phase == "world":
			scene_router.navigate_to("main_game")
		else:
			scene_router.navigate_to_campaign_phase(target_phase)
	
	# Hide the developer panel
	if developer_panel:
		developer_panel.hide()

func _on_direct_phase_requested(phase_name: String) -> void:
	"""Handle direct phase navigation request"""
	print("MainMenu: Direct phase navigation requested - ", phase_name)
	
	var scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router and scene_router.has_method("navigate_to_campaign_phase"):
		scene_router.navigate_to_campaign_phase(phase_name)
	
	# Hide the developer panel
	if developer_panel:
		developer_panel.hide()

func _on_test_scenario_requested(scenario_name: String) -> void:
	"""Handle test scenario setup request"""
	print("MainMenu: Test scenario requested - ", scenario_name)
	
	# Apply scenario setup via GameStateManager if available
	if game_state_manager and game_state_manager.has_method("apply_test_scenario"):
		game_state_manager.apply_test_scenario(scenario_name)
	
	# Navigate to main game
	var scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router:
		scene_router.navigate_to("main_game")
	
	# Hide the developer panel
	if developer_panel:
		developer_panel.hide()

func _cleanup_dialogs() -> void:
	for dialog in _active_dialogs:
		if is_instance_valid(dialog):
			dialog.queue_free()
	_active_dialogs.clear()

func show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	_active_dialogs.append(dialog) # warning: return value discarded (intentional)
	dialog.popup_centered()
	await dialog.confirmed
	if is_instance_valid(dialog):
		dialog.queue_free()
	_active_dialogs.erase(dialog)

func request_scene_change(scene_name: String) -> void:
	var parent := get_parent()
	if not parent:
		push_error("MainMenu: Parent node not found")
		return
	
	var game_scene := parent.get_parent()
	if not game_scene:
		push_error("MainMenu: Game scene node not found")
		return
	
	if game_scene.has_method("change_scene"):
		game_scene.change_scene(scene_name)
	else:
		push_error("MainMenu: Game scene missing change_scene method")
