# MainMenu.gd
extends Control

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
@onready var continue_button = %Continue as Button
@onready var load_campaign_button = %LoadCampaign as Button
@onready var new_campaign_button = %NewCampaign as Button
@onready var coop_campaign_button = %CoopCampaign as Button
@onready var battle_simulator_button = %BattleSimulator as Button
@onready var bug_hunt_button = %BugHunt as Button
var tactics_button: Button
var planetfall_button: Button
@onready var options_button = %Options as Button
@onready var library_button = %Library as Button
@onready var tutorial_popup = %TutorialPopup as Panel

var game_state_manager: Node
var _active_dialogs: Array[Node] = []

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

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
	# Check legal consent before showing menu
	var consent_mgr := get_node_or_null("/root/LegalConsentManager")
	if consent_mgr and consent_mgr.needs_legal_consent():
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("eula", {}, false)
			return

	if not _validate_required_nodes():
		push_error("MainMenu: Required nodes are missing")
		return

	# Auto-initialize game_state_manager from autoload if not set via setup()
	if not game_state_manager:
		game_state_manager = get_node_or_null("/root/GameStateManager")

	setup_ui()
	_build_social_footer()
	if tutorial_popup:
		tutorial_popup.hide()
		_connect_tutorial_signals()
	update_continue_button_visibility()

	# Responsive layout
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

	# First-run tutorial (deferred so UI is fully built)
	_check_first_run_tutorial.call_deferred()

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
	_inject_tactics_button()
	_inject_planetfall_button()
	_connect_buttons()
	_enforce_touch_targets()
	add_fade_in_animation()

func _inject_tactics_button() -> void:
	# Dynamically add Tactics button after Bug Hunt
	if not bug_hunt_button:
		return
	var menu_container := bug_hunt_button.get_parent()
	if not menu_container:
		return
	tactics_button = Button.new()
	tactics_button.name = "Tactics"
	tactics_button.text = "Tactics"
	tactics_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := bug_hunt_button.get_index() + 1
	menu_container.add_child(tactics_button)
	menu_container.move_child(tactics_button, idx)

func _inject_planetfall_button() -> void:
	# Dynamically add Planetfall button after Tactics
	var anchor: Button = tactics_button if tactics_button else bug_hunt_button
	if not anchor:
		return
	var menu_container := anchor.get_parent()
	if not menu_container:
		return
	planetfall_button = Button.new()
	planetfall_button.name = "Planetfall"
	planetfall_button.text = "Planetfall"
	planetfall_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := anchor.get_index() + 1
	menu_container.add_child(planetfall_button)
	menu_container.move_child(planetfall_button, idx)

func _enforce_touch_targets() -> void:
	# Ensure all menu buttons meet TOUCH_TARGET_MIN (48px)
	for btn in [continue_button, load_campaign_button, new_campaign_button,
			coop_campaign_button, battle_simulator_button, bug_hunt_button,
			tactics_button, planetfall_button, options_button, library_button]:
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
	if tactics_button:
		_safe_connect(tactics_button, "pressed", _on_tactics_pressed)
	if planetfall_button:
		_safe_connect(planetfall_button, "pressed", _on_planetfall_pressed)
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
		_navigate_with_loading("campaign_dashboard", PackedStringArray([
			"Loading Campaign Data",
			"Loading Crew Roster",
			"Loading World State",
		]))
	else:
		show_message("No active campaign to continue")

func _on_new_campaign_pressed() -> void:
	if not is_instance_valid(game_state_manager):
		show_message("Error: Game state manager not available")
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

func _check_first_run_tutorial() -> void:
	# Show guided tutorial overlay on first launch
	var TutorialUIScript: GDScript = load(
		"res://src/ui/components/tutorial/TutorialUI.gd")
	if not TutorialUIScript:
		return
	var tui: Control = TutorialUIScript.new()
	add_child(tui)
	if tui.is_tutorial_completed("first_run"):
		tui.queue_free()
		return
	# Brief delay so buttons are laid out
	await get_tree().create_timer(0.3).timeout
	tui.start_tutorial("first_run")

func _on_load_campaign_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		show_message("Game state not available.")
		return
	var campaigns: Array = gs.get_available_campaigns()

	# ISSUE-048: Backdrop dimming
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.name = "__load_backdrop"
	add_child(backdrop)

	var dialog := AcceptDialog.new()
	dialog.title = "Load Campaign"
	dialog.ok_button_text = "Cancel"
	# Deep Space theme (matches Bug Hunt dialog)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.border_color = Color("#3A3A5C")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override(
		"font_color", Color("#E0E0E0"))

	# Wrap campaign list in ScrollContainer for many saves
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = mini(campaigns.size() * 56 + 80, 420)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	for info in campaigns:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var btn := Button.new()
		# ISSUE-049: Show campaign type tag + DLC badge
		var type_tag := ""
		var save_path: String = info.get("path", "")
		if save_path.find("bug_hunt") >= 0 \
				or info.get("type", "") == "bug_hunt":
			type_tag = "[BH] "
		elif save_path.find("tactics") >= 0 \
				or info.get("type", "") == "tactics":
			type_tag = "[TAC] "
		elif save_path.find("planetfall") >= 0 \
				or info.get("type", "") == "planetfall":
			type_tag = "[PF] "
		# DLC badge: peek for required packs
		var dlc_tag := ""
		var gs_ref = get_node_or_null("/root/GameState")
		var dlc_ref = get_node_or_null("/root/DLCManager")
		if gs_ref and gs_ref.has_method("peek_required_dlc"):
			var req: Array[String] = gs_ref.peek_required_dlc(
				save_path)
			for pid: String in req:
				if dlc_ref and not dlc_ref.has_dlc(pid):
					dlc_tag = "[DLC] "
					break
		btn.text = "%s%s%s  (%s)" % [
			type_tag, dlc_tag,
			info.get("name", "Unnamed"),
			info.get("date_string", "")]
		btn.custom_minimum_size.y = 48
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Deep Space button styling
		var btn_sty := StyleBoxFlat.new()
		btn_sty.bg_color = Color("#252542")
		btn_sty.border_color = Color("#3A3A5C")
		btn_sty.set_border_width_all(1)
		btn_sty.set_corner_radius_all(4)
		btn_sty.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_sty)
		var btn_hov := btn_sty.duplicate()
		btn_hov.bg_color = Color("#2D5A7B")
		btn.add_theme_stylebox_override("hover", btn_hov)
		btn.add_theme_color_override("font_color", Color("#E0E0E0"))
		btn.pressed.connect(
			_load_and_go_to_dashboard.bind(
				save_path, dialog, backdrop))
		row.add_child(btn)

		# ISSUE-050: Delete button per save
		var del_btn := Button.new()
		del_btn.text = "\u2715"  # ✕ unicode multiply sign — cleaner than "X"
		del_btn.custom_minimum_size = Vector2(48, 48)
		del_btn.tooltip_text = "Delete this save"
		del_btn.add_theme_color_override("font_color", Color("#DC2626"))
		del_btn.add_theme_color_override("font_hover_color", Color("#FF4444"))
		del_btn.pressed.connect(
			_on_delete_save.bind(save_path, row, info.get("name", ""), dialog))
		row.add_child(del_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)
	var import_btn := Button.new()
	import_btn.text = "Import from File..."
	import_btn.custom_minimum_size.y = 48
	var imp_sty := StyleBoxFlat.new()
	imp_sty.bg_color = Color("#252542")
	imp_sty.border_color = Color("#4FC3F7")
	imp_sty.set_border_width_all(1)
	imp_sty.set_corner_radius_all(4)
	imp_sty.set_content_margin_all(8)
	import_btn.add_theme_stylebox_override("normal", imp_sty)
	import_btn.add_theme_color_override(
		"font_color", Color("#4FC3F7"))
	import_btn.pressed.connect(
		_on_import_from_file.bind(dialog))
	vbox.add_child(import_btn)
	scroll.add_child(vbox)
	dialog.add_child(scroll)
	# Clean up backdrop when dialog closes
	dialog.canceled.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()

func _load_and_go_to_dashboard(
	path: String, dialog: Node, backdrop: Node = null,
) -> void:
	push_warning("MainMenu: Loading campaign from path: %s" % path)
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("load_campaign"):
		_cleanup_load_ui(dialog, backdrop)
		show_message("Load system not available.")
		return

	# Check DLC requirements before loading
	var dlc_mgr = get_node_or_null("/root/DLCManager")
	var required: Array[String] = []
	if gs.has_method("peek_required_dlc"):
		required = gs.peek_required_dlc(path)
	var missing: Array[String] = []
	for pack_id: String in required:
		if dlc_mgr and not dlc_mgr.has_dlc(pack_id):
			missing.append(pack_id)

	if not missing.is_empty():
		# Show DLC requirement dialog
		var DLCReqDialog = load(
			"res://src/ui/dialogs/DLCRequirementDialog.gd")
		if DLCReqDialog:
			var req_dialog: Window = DLCReqDialog.new()
			add_child(req_dialog)
			_active_dialogs.append(req_dialog)
			req_dialog.load_requested.connect(func():
				_active_dialogs.erase(req_dialog)
				_cleanup_load_ui(dialog, backdrop)
				_do_load_campaign(gs, path)
			)
			req_dialog.store_requested.connect(func():
				_active_dialogs.erase(req_dialog)
				_cleanup_load_ui(dialog, backdrop)
				request_scene_change("store")
			)
			req_dialog.cancelled.connect(func():
				_active_dialogs.erase(req_dialog)
			)
			req_dialog.show_missing_packs(missing)
		return

	_cleanup_load_ui(dialog, backdrop)
	_do_load_campaign(gs, path)

func _cleanup_load_ui(
	dialog: Node, backdrop: Node = null,
) -> void:
	if is_instance_valid(backdrop):
		backdrop.queue_free()
	if is_instance_valid(dialog):
		dialog.queue_free()
		_active_dialogs.erase(dialog)

func _do_load_campaign(gs: Node, path: String) -> void:
	var result: Dictionary = gs.load_campaign(path)
	if result.get("success", false):
		_navigate_with_loading("campaign_turn_controller", PackedStringArray([
			"Loading Campaign Data",
			"Loading Crew Roster",
			"Loading World State",
			"Loading Equipment Tables",
			"Loading Event Tables",
		]))
	else:
		show_message(
			"Load failed: %s" % result.get("message", "Unknown error"))

func _on_delete_save(path: String, row: Node, save_name: String, dialog: Node) -> void:
	# ISSUE-050: Delete save with confirmation
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Delete save \"%s\"?\nThis cannot be undone." % save_name
	confirm.ok_button_text = "Delete"
	confirm.confirmed.connect(func():
		if DirAccess.remove_absolute(path) == OK:
			if is_instance_valid(row):
				row.queue_free()
			push_warning("MainMenu: Deleted save: %s" % path)
		else:
			show_message("Failed to delete: %s" % path)
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	if is_instance_valid(dialog):
		dialog.add_child(confirm)
	else:
		add_child(confirm)
	confirm.popup_centered()


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
			_navigate_with_loading("campaign_turn_controller", PackedStringArray([
				"Importing Campaign Data",
				"Loading Crew Roster",
				"Loading World State",
			]))
		else:
			show_message("Import failed: %s" % result.get("message", "Unknown error"))
	else:
		show_message("Import not supported.")

func _on_coop_campaign_pressed() -> void:
	show_message("Co-op Campaign feature is coming soon!")

func _on_battle_simulator_pressed() -> void:
	request_scene_change("battle_simulator")

func _on_bug_hunt_pressed() -> void:
	# Check for existing Bug Hunt saves before going to creation
	var bh_saves := _find_bug_hunt_saves()
	if bh_saves.is_empty():
		request_scene_change("bug_hunt_creation")
		return

	# Show choice dialog: Continue most recent / Load / New
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.name = "__bh_backdrop"
	add_child(backdrop)

	var dialog := AcceptDialog.new()
	dialog.title = "Bug Hunt"
	dialog.ok_button_text = "Cancel"
	# Deep Space theme for dialog
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.border_color = Color("#3A3A5C")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override(
		"font_color", Color("#E0E0E0"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)

	var info_lbl := Label.new()
	info_lbl.text = "Found %d Bug Hunt campaign(s)." % bh_saves.size()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_color_override(
		"font_color", Color("#E0E0E0"))
	vbox.add_child(info_lbl)

	# Continue most recent
	var continue_btn := Button.new()
	var latest: Dictionary = bh_saves[0]
	continue_btn.text = "Continue: %s (Turn %d)" % [
		latest.get("name", "Unknown"), int(latest.get("turn", 0))]
	continue_btn.custom_minimum_size.y = 48
	continue_btn.pressed.connect(func():
		var p: String = latest.get("path", "")
		dialog.queue_free()
		if is_instance_valid(backdrop):
			backdrop.queue_free()
		get_tree().create_timer(0.05).timeout.connect(
			func(): _load_bug_hunt_save(p))
	)
	vbox.add_child(continue_btn)

	# Show other saves if multiple
	if bh_saves.size() > 1:
		for i in range(1, mini(bh_saves.size(), 4)):
			var save_info: Dictionary = bh_saves[i]
			var load_btn := Button.new()
			load_btn.text = "Load: %s (Turn %d)" % [
				save_info.get("name", "Unknown"),
				int(save_info.get("turn", 0))]
			load_btn.custom_minimum_size.y = 44
			var path_ref: String = save_info.get("path", "")
			load_btn.pressed.connect(func():
				dialog.queue_free()
				if is_instance_valid(backdrop):
					backdrop.queue_free()
				var pr: String = path_ref
				get_tree().create_timer(0.05).timeout.connect(
					func(): _load_bug_hunt_save(pr))
			)
			vbox.add_child(load_btn)

	# New campaign option
	var new_btn := Button.new()
	new_btn.text = "New Bug Hunt Campaign"
	new_btn.custom_minimum_size.y = 48
	new_btn.pressed.connect(func():
		dialog.queue_free()
		if is_instance_valid(backdrop):
			backdrop.queue_free()
		get_tree().create_timer(0.05).timeout.connect(
			func(): request_scene_change("bug_hunt_creation"))
	)
	vbox.add_child(new_btn)

	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	dialog.canceled.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()


func _find_bug_hunt_saves() -> Array:
	## Scan user://saves/ for Bug Hunt campaign files, sorted by modification time (newest first).
	var saves: Array = []
	var dir := DirAccess.open("user://saves/")
	if not dir:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var path := "user://saves/" + file_name
			# Peek at campaign type without full load
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()
				var data = JSON.parse_string(text)
				if data is Dictionary and data.get("campaign_type", "") == "bug_hunt":
					var meta: Dictionary = data.get("meta", {})
					var state: Dictionary = data.get("state", {})
					saves.append({
						"path": path,
						"name": data.get("campaign_name",
							meta.get("campaign_name", file_name)),
						"turn": state.get("campaign_turn",
							data.get("campaign_turn", 0)),
						"modified": FileAccess.get_modified_time(path)
					})
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by modification time, newest first
	saves.sort_custom(func(a, b): return a.modified > b.modified)
	return saves


func _load_bug_hunt_save(path: String) -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("load_campaign"):
		show_message("Game state not available.")
		return
	var result: Dictionary = gs.load_campaign(path)
	if result.get("success", false):
		request_scene_change("bug_hunt_dashboard")
	else:
		show_message("Failed to load Bug Hunt: %s" % result.get("message", "Unknown error"))

func _on_tactics_pressed() -> void:
	var tac_saves := _find_tactics_saves()
	if tac_saves.is_empty():
		request_scene_change("tactics_creation")
		return

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.name = "__tac_backdrop"
	add_child(backdrop)

	var dialog := AcceptDialog.new()
	dialog.title = "Tactics"
	dialog.ok_button_text = "Cancel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.border_color = Color("#3A3A5C")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override("font_color", Color("#E0E0E0"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)

	var info_lbl := Label.new()
	info_lbl.text = "Found %d Tactics campaign(s)." % tac_saves.size()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_color_override("font_color", Color("#E0E0E0"))
	vbox.add_child(info_lbl)

	var latest: Dictionary = tac_saves[0]
	var continue_btn := Button.new()
	continue_btn.text = "Continue: %s (Turn %d)" % [
		latest.get("name", "Unknown"), int(latest.get("turn", 0))]
	continue_btn.custom_minimum_size.y = 48
	continue_btn.pressed.connect(func():
		var p: String = latest.get("path", "")
		dialog.queue_free()
		if is_instance_valid(backdrop):
			backdrop.queue_free()
		get_tree().create_timer(0.05).timeout.connect(
			func(): _load_tactics_save(p))
	)
	vbox.add_child(continue_btn)

	if tac_saves.size() > 1:
		for i in range(1, mini(tac_saves.size(), 4)):
			var save_info: Dictionary = tac_saves[i]
			var load_btn := Button.new()
			load_btn.text = "Load: %s (Turn %d)" % [
				save_info.get("name", "Unknown"),
				int(save_info.get("turn", 0))]
			load_btn.custom_minimum_size.y = 44
			var path_ref: String = save_info.get("path", "")
			load_btn.pressed.connect(func():
				dialog.queue_free()
				if is_instance_valid(backdrop):
					backdrop.queue_free()
				var pr: String = path_ref
				get_tree().create_timer(0.05).timeout.connect(
					func(): _load_tactics_save(pr))
			)
			vbox.add_child(load_btn)

	var new_btn := Button.new()
	new_btn.text = "New Tactics Campaign"
	new_btn.custom_minimum_size.y = 48
	new_btn.pressed.connect(func():
		dialog.queue_free()
		if is_instance_valid(backdrop):
			backdrop.queue_free()
		get_tree().create_timer(0.05).timeout.connect(
			func(): request_scene_change("tactics_creation"))
	)
	vbox.add_child(new_btn)

	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	dialog.canceled.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()


func _find_tactics_saves() -> Array:
	var saves: Array = []
	var dir := DirAccess.open("user://saves/")
	if not dir:
		return saves
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var path := "user://saves/" + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()
				var data = JSON.parse_string(text)
				if data is Dictionary \
						and data.get("campaign_type", "") == "tactics":
					var meta: Dictionary = data.get("meta", {})
					var state: Dictionary = data.get("state", {})
					saves.append({
						"path": path,
						"name": data.get("campaign_name",
							meta.get("campaign_name", file_name)),
						"turn": state.get("campaign_turn",
							data.get("campaign_turn", 0)),
						"modified": FileAccess.get_modified_time(path)
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a, b): return a.modified > b.modified)
	return saves


func _load_tactics_save(path: String) -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("load_campaign"):
		show_message("Game state not available.")
		return
	var result: Dictionary = gs.load_campaign(path)
	if result.get("success", false):
		request_scene_change("tactics_dashboard")
	else:
		show_message(
			"Failed to load Tactics: %s" % result.get(
				"message", "Unknown error"))


func _on_planetfall_pressed() -> void:
	var pf_saves := _find_planetfall_saves()
	if pf_saves.is_empty():
		request_scene_change("planetfall_creation")
		return

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.name = "__pf_backdrop"
	add_child(backdrop)

	var dialog := AcceptDialog.new()
	dialog.title = "Planetfall"
	dialog.ok_button_text = "Cancel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.border_color = Color("#3A3A5C")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override("font_color", Color("#E0E0E0"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)

	var info_lbl := Label.new()
	info_lbl.text = "Found %d Planetfall campaign(s)." % pf_saves.size()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_color_override("font_color", Color("#E0E0E0"))
	vbox.add_child(info_lbl)

	var latest: Dictionary = pf_saves[0]
	var continue_btn := Button.new()
	continue_btn.text = "Continue: %s (Turn %d)" % [
		latest.get("name", "Unknown"), int(latest.get("turn", 0))]
	continue_btn.custom_minimum_size.y = 48
	continue_btn.pressed.connect(func():
		var p: String = latest.get("path", "")
		dialog.queue_free()
		if is_instance_valid(backdrop):
			backdrop.queue_free()
		get_tree().create_timer(0.05).timeout.connect(
			func(): _load_planetfall_save(p))
	)
	vbox.add_child(continue_btn)

	if pf_saves.size() > 1:
		for i in range(1, mini(pf_saves.size(), 4)):
			var save_info: Dictionary = pf_saves[i]
			var load_btn := Button.new()
			load_btn.text = "Load: %s (Turn %d)" % [
				save_info.get("name", "Unknown"),
				int(save_info.get("turn", 0))]
			load_btn.custom_minimum_size.y = 44
			var path_ref: String = save_info.get("path", "")
			load_btn.pressed.connect(func():
				dialog.queue_free()
				if is_instance_valid(backdrop):
					backdrop.queue_free()
				var pr: String = path_ref
				get_tree().create_timer(0.05).timeout.connect(
					func(): _load_planetfall_save(pr))
			)
			vbox.add_child(load_btn)

	var new_btn := Button.new()
	new_btn.text = "New Planetfall Campaign"
	new_btn.custom_minimum_size.y = 48
	new_btn.pressed.connect(func():
		dialog.queue_free()
		if is_instance_valid(backdrop):
			backdrop.queue_free()
		get_tree().create_timer(0.05).timeout.connect(
			func(): request_scene_change("planetfall_creation"))
	)
	vbox.add_child(new_btn)

	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	dialog.canceled.connect(func():
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()


func _find_planetfall_saves() -> Array:
	var saves: Array = []
	var dir := DirAccess.open("user://saves/")
	if not dir:
		return saves
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".save"):
			var path := "user://saves/" + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()
				var data = JSON.parse_string(text)
				if data is Dictionary \
						and data.get("campaign_type", "") == "planetfall":
					var meta: Dictionary = data.get("meta", {})
					var progression: Dictionary = data.get("progression", {})
					saves.append({
						"path": path,
						"name": data.get("campaign_name",
							meta.get("campaign_name", file_name)),
						"turn": progression.get("campaign_turn",
							data.get("campaign_turn", 0)),
						"modified": FileAccess.get_modified_time(path)
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a, b): return a.modified > b.modified)
	return saves


func _load_planetfall_save(path: String) -> void:
	var PCC = load("res://src/game/campaign/PlanetfallCampaignCore.gd")
	var campaign = PCC.load_from_file(path)
	if not campaign:
		show_message("Failed to load Planetfall save.")
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_current_campaign"):
		gs.set_current_campaign(campaign)
		request_scene_change("planetfall_dashboard")
	else:
		show_message("Game state not available.")


func _on_options_pressed() -> void:
	request_scene_change("options")

func _on_library_pressed() -> void:
	request_scene_change("compendium")

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

## ── Social Footer ─────────────────────────────────────────────
## Publisher and community links at bottom-left of main menu.

const SOCIAL_LINKS: Array[Dictionary] = [
	{
		"label": "Modiphius",
		"url": "https://www.modiphius.net/",
		"tooltip": "Visit Modiphius Entertainment",
	},
	{
		"label": "Five Parsecs",
		"url": "https://www.modiphius.net/collections/five-parsecs-from-home",
		"tooltip": "Five Parsecs From Home at Modiphius",
	},
	{
		"label": "Discord",
		"url": "https://discord.gg/modiphius",
		"tooltip": "Join the Modiphius Discord community",
	},
	{
		"label": "Facebook",
		"url": "https://www.facebook.com/modaborgen",
		"tooltip": "Five Parsecs on Facebook",
	},
]

var _social_bar: HBoxContainer = null

func _build_social_footer() -> void:
	# Container anchored to bottom-left
	var footer := PanelContainer.new()
	footer.name = "SocialFooter"
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = Color(0, 0, 0, 0.4)
	footer_style.set_corner_radius_all(6)
	footer_style.content_margin_left = 12
	footer_style.content_margin_right = 12
	footer_style.content_margin_top = 6
	footer_style.content_margin_bottom = 6
	footer.add_theme_stylebox_override("panel", footer_style)

	footer.layout_mode = 1
	footer.anchors_preset = Control.PRESET_BOTTOM_LEFT
	footer.anchor_left = 0.0
	footer.anchor_top = 1.0
	footer.anchor_right = 0.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 20
	footer.offset_top = -56
	footer.offset_right = 500
	footer.offset_bottom = -12
	footer.grow_horizontal = Control.GROW_DIRECTION_END
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(footer)

	_social_bar = HBoxContainer.new()
	_social_bar.add_theme_constant_override("separation", 6)
	_social_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	footer.add_child(_social_bar)

	# "Community" label
	var label := Label.new()
	label.text = "Community:"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override(
		"font_color", Color("#808080"))
	_social_bar.add_child(label)

	# Link buttons
	for link: Dictionary in SOCIAL_LINKS:
		var btn := Button.new()
		btn.text = link.get("label", "")
		btn.tooltip_text = link.get("tooltip", "")
		btn.flat = true
		btn.custom_minimum_size.y = 36
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override(
			"font_color", Color("#4FC3F7"))
		btn.add_theme_color_override(
			"font_hover_color", Color("#81D4FA"))
		var url: String = link.get("url", "")
		btn.pressed.connect(_open_url.bind(url))
		_social_bar.add_child(btn)

	# Separator + Credits button
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 1
	_social_bar.add_child(sep)

	var credits_btn := Button.new()
	credits_btn.text = "Credits"
	credits_btn.flat = true
	credits_btn.custom_minimum_size.y = 36
	credits_btn.add_theme_font_size_override("font_size", 13)
	credits_btn.add_theme_color_override(
		"font_color", Color("#808080"))
	credits_btn.add_theme_color_override(
		"font_hover_color", Color("#B0B0B0"))
	credits_btn.pressed.connect(_show_credits)
	_social_bar.add_child(credits_btn)

	# Privacy policy link (App Store / Play Store requirement)
	var privacy_sep := VSeparator.new()
	privacy_sep.custom_minimum_size.x = 1
	_social_bar.add_child(privacy_sep)

	var privacy_btn := Button.new()
	privacy_btn.text = "Privacy"
	privacy_btn.flat = true
	privacy_btn.add_theme_font_size_override("font_size", 11)
	privacy_btn.add_theme_color_override(
		"font_color", Color("#808080"))
	privacy_btn.add_theme_color_override(
		"font_hover_color", Color("#B0B0B0"))
	privacy_btn.pressed.connect(func():
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("legal_viewer", {
				"file": "res://data/legal/privacy_policy.md",
				"title": "Privacy Policy"
			})
	)
	_social_bar.add_child(privacy_btn)

	# Version number — rightmost element in footer (Fallout pattern)
	var ver_sep := VSeparator.new()
	ver_sep.custom_minimum_size.x = 1
	_social_bar.add_child(ver_sep)

	var version_label := Label.new()
	var version: String = ProjectSettings.get_setting(
		"application/config/version", "dev"
	)
	version_label.text = "v%s" % version
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override(
		"font_color", Color("#606060"))
	_social_bar.add_child(version_label)

func _open_url(url: String) -> void:
	if not url.is_empty():
		OS.shell_open(url)

func _show_credits() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Credits"
	dialog.dialog_text = (
		"Five Parsecs From Home Campaign Manager\n\n"
		+ "Based on Five Parsecs From Home by Ivan Sorensen\n"
		+ "Published by Modiphius Entertainment\n\n"
		+ "App Development: ReptarusOnIce\n\n"
		+ "Five Parsecs From Home is a trademark of\n"
		+ "Modiphius Entertainment Ltd.\n"
		+ "Used with permission."
	)
	add_child(dialog)
	_active_dialogs.append(dialog)
	dialog.popup_centered()

func _on_viewport_resized() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var vp_size := vp.get_visible_rect().size
	var is_narrow := vp_size.x < 768
	var menu_buttons := $MenuButtons
	var title := $Title

	# Social footer: hide on very narrow, show on wide
	var social_footer := get_node_or_null("SocialFooter")
	if social_footer:
		social_footer.visible = not is_narrow

	if is_narrow:
		# Portrait/narrow: center buttons, scale down title
		menu_buttons.anchor_left = 0.5
		menu_buttons.anchor_right = 0.5
		menu_buttons.anchor_top = 0.5
		menu_buttons.anchor_bottom = 0.5
		menu_buttons.offset_left = -160
		menu_buttons.offset_right = 160
		menu_buttons.offset_top = -200
		menu_buttons.offset_bottom = 200
		title.add_theme_font_size_override(
			"font_size", _scaled_font(36))
		title.offset_left = -180
		title.offset_right = 180
	else:
		# Landscape/wide: right-aligned buttons (original layout)
		menu_buttons.anchor_left = 1.0
		menu_buttons.anchor_right = 1.0
		menu_buttons.anchor_top = 0.5
		menu_buttons.anchor_bottom = 0.5
		menu_buttons.offset_left = -400
		menu_buttons.offset_right = -50
		menu_buttons.offset_top = -250
		menu_buttons.offset_bottom = 250
		title.add_theme_font_size_override(
			"font_size", _scaled_font(75))
		title.offset_left = -400
		title.offset_right = 400

func request_scene_change(scene_name: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if not router:
		show_message("Error: SceneRouter not found")
		return

	# Map MainMenu scene names to SceneRouter keys
	var scene_map := {
		"crew_management": "crew_management",
		"campaign_setup": "campaign_creation",
		"tutorial_setup": "tutorial_selection",
		"options": "settings",
		"campaign_dashboard": "campaign_dashboard",
		"campaign_turn_controller": "campaign_turn_controller",
		"bug_hunt_creation": "bug_hunt_creation",
		"bug_hunt_dashboard": "bug_hunt_dashboard",
		"tactics_creation": "tactics_creation",
		"tactics_dashboard": "tactics_dashboard",
		"tactics_turn_controller": "tactics_turn_controller",
		"planetfall_creation": "planetfall_creation",
		"planetfall_dashboard": "planetfall_dashboard",
		"planetfall_turn_controller": "planetfall_turn_controller",
		"battle_simulator": "battle_simulator",
		"compendium": "compendium",
		"help": "help",
		"store": "store",
	}

	var router_key: String = scene_map.get(scene_name, "")
	if router_key.is_empty():
		show_message("%s feature is coming soon!" % scene_name.replace("_", " ").capitalize())
		return

	router.navigate_to(router_key)


func _navigate_with_loading(
	scene_name: String, tasks: PackedStringArray = PackedStringArray()
) -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if not router or not router.has_method("navigate_to_with_loading"):
		request_scene_change(scene_name)
		return
	router.navigate_to_with_loading(scene_name, tasks)
