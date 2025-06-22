# MainMenu.gd
extends Control

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var continue_button = %Continue as Button
@onready var new_campaign_button = %NewCampaign as Button
@onready var coop_campaign_button = %CoopCampaign as Button
@onready var battle_simulator_button = %BattleSimulator as Button
@onready var bug_hunt_button = %BugHunt as Button
@onready var options_button = %Options as Button
@onready var library_button = %Library as Button
@onready var tutorial_popup = %TutorialPopup as Panel

var game_state_manager: Node
var _active_dialogs: Array[Node] = []

func _exit_tree() -> void:
	_cleanup_dialogs()
	if game_state_manager:
		game_state_manager = null

func setup(manager: Node) -> void:
	if not manager:
		push_error("MainMenu: Invalid game state manager provided")
		return
	
	game_state_manager = manager
	update_continue_button_visibility()

func _ready() -> void:
	print("MainMenu: Starting initialization...")
	
	if not _validate_required_nodes():
		push_error("MainMenu: Required nodes are missing")
		return
	
	# Try to connect to autoloaded game state manager
	_try_connect_to_autoloads()
	
	setup_ui()
	if tutorial_popup:
		tutorial_popup.hide()
		_connect_tutorial_signals()
	
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
