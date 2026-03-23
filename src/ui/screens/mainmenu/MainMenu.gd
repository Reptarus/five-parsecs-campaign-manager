# MainMenu.gd
extends Control

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
@onready var continue_button = %Continue as Button
@onready var load_campaign_button = %LoadCampaign as Button
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
	if not _validate_required_nodes():
		push_error("MainMenu: Required nodes are missing")
		return

	# Auto-initialize game_state_manager from autoload if not set via setup()
	if not game_state_manager:
		game_state_manager = get_node_or_null("/root/GameStateManager")

	setup_ui()
	if tutorial_popup:
		tutorial_popup.hide()
		_connect_tutorial_signals()
	update_continue_button_visibility()

func _validate_required_nodes() -> bool:
	var required_nodes := [
		continue_button,
		load_campaign_button,
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
	_enforce_touch_targets()
	add_fade_in_animation()

func _enforce_touch_targets() -> void:
	# Ensure all menu buttons meet TOUCH_TARGET_MIN (48px)
	for btn in [continue_button, load_campaign_button, new_campaign_button,
			coop_campaign_button, battle_simulator_button, bug_hunt_button,
			options_button, library_button]:
		if btn:
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 48.0)

func _connect_buttons() -> void:
	if continue_button:
		_safe_connect(continue_button, "pressed", _on_continue_pressed)
	if load_campaign_button:
		_safe_connect(load_campaign_button, "pressed", _on_load_campaign_pressed)
	if new_campaign_button:
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
		_safe_connect(library_button, "pressed", _on_library_pressed)

func _safe_connect(node: Node, signal_name: String, callback: Callable) -> void:
	if node.is_connected(signal_name, callback):
		node.disconnect(signal_name, callback)
	node.connect(signal_name, callback)

func add_fade_in_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func update_continue_button_visibility() -> void:
	if not continue_button:
		return

	continue_button.visible = false

	# Try GameStateManager first
	if is_instance_valid(game_state_manager) and game_state_manager.has_method("has_active_campaign"):
		continue_button.visible = game_state_manager.has_active_campaign()
		return

	# Fallback: check GameState autoload directly
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("has_active_campaign"):
		continue_button.visible = gs.has_active_campaign()

func _on_continue_pressed() -> void:
	if not is_instance_valid(game_state_manager):
		show_message("No active campaign to continue")
		return
	
	if game_state_manager.has_method("has_active_campaign") and game_state_manager.has_active_campaign():
		request_scene_change("campaign_turn_controller")
	else:
		show_message("No active campaign to continue")

func _on_new_campaign_pressed() -> void:
	if not is_instance_valid(game_state_manager):
		push_error("MainMenu: Game state manager is invalid")
		return
	_start_new_campaign()

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

func _on_load_campaign_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		show_message("Game state not available.")
		return
	# Show dialog with saved campaigns + import from file option
	var campaigns: Array = gs.get_available_campaigns()
	var dialog := AcceptDialog.new()
	dialog.title = "Load Campaign"
	dialog.ok_button_text = "Cancel"
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 0)
	for info in campaigns:
		var btn := Button.new()
		btn.text = "%s  (%s)" % [info.get("name", "Unnamed"), info.get("date_string", "")]
		var p: String = info.get("path", "")
		btn.pressed.connect(_load_and_go_to_dashboard.bind(p, dialog))
		vbox.add_child(btn)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var import_btn := Button.new()
	import_btn.text = "Import from File..."
	import_btn.pressed.connect(_on_import_from_file.bind(dialog))
	vbox.add_child(import_btn)
	dialog.add_child(vbox)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()

func _load_and_go_to_dashboard(path: String, dialog: Node) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
		_active_dialogs.erase(dialog)
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("load_campaign"):
		show_message("Load system not available.")
		return
	var result: Dictionary = gs.load_campaign(path)
	if result.get("success", false):
		request_scene_change("campaign_turn_controller")
	else:
		show_message("Load failed: %s" % result.get("message", "Unknown error"))

func _on_import_from_file(load_dialog: Node) -> void:
	if is_instance_valid(load_dialog):
		load_dialog.hide()
		load_dialog.queue_free()
		_active_dialogs.erase(load_dialog)
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.save ; Campaign Save Files", "*.json ; JSON Files"])
	file_dialog.title = "Import Campaign File"
	file_dialog.size = Vector2i(800, 500)
	file_dialog.file_selected.connect(_on_import_file_selected.bind(file_dialog))
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
		_active_dialogs.erase(file_dialog)
	)
	add_child(file_dialog)
	_active_dialogs.append(file_dialog)
	file_dialog.popup_centered()

func _on_import_file_selected(path: String, file_dialog: Node) -> void:
	if is_instance_valid(file_dialog):
		file_dialog.queue_free()
		_active_dialogs.erase(file_dialog)
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		show_message("Game state not available.")
		return
	if gs.has_method("import_campaign"):
		var result: Dictionary = gs.import_campaign(path)
		if result.get("success", false):
			request_scene_change("campaign_turn_controller")
		else:
			show_message("Import failed: %s" % result.get("message", "Unknown error"))
	else:
		show_message("Import not supported.")

func _on_coop_campaign_pressed() -> void:
	show_message("Co-op Campaign feature is coming soon!")

func _on_battle_simulator_pressed() -> void:
	show_message("Battle Simulator feature is coming soon!")

func _on_bug_hunt_pressed() -> void:
	request_scene_change("bug_hunt_creation")

func _on_options_pressed() -> void:
	request_scene_change("options")

func _on_library_pressed() -> void:
	request_scene_change("help")

func _cleanup_dialogs() -> void:
	for dialog in _active_dialogs:
		if is_instance_valid(dialog):
			dialog.queue_free()
	_active_dialogs.clear()

func show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	if is_instance_valid(dialog):
		dialog.queue_free()
	_active_dialogs.erase(dialog)

func request_scene_change(scene_name: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if not router:
		push_error("MainMenu: SceneRouter not found")
		return

	# Map MainMenu scene names to SceneRouter keys
	var scene_map := {
		"crew_management": "crew_management",
		"campaign_setup": "campaign_creation",
		"tutorial_setup": "tutorial_selection",
		"options": "settings",
		"campaign_dashboard": "campaign_turn_controller",
		"campaign_turn_controller": "campaign_turn_controller",
		"bug_hunt_creation": "bug_hunt_creation",
		"help": "help",
	}

	var router_key: String = scene_map.get(scene_name, "")
	if router_key.is_empty():
		show_message("%s feature is coming soon!" % scene_name.replace("_", " ").capitalize())
		return

	router.navigate_to(router_key)
