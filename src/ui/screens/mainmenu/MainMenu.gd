# MainMenu.gd
extends Control

## Alpha-1 build scope. The closed alpha validates the Standard 5PFH loop plus
## the Battle Simulator, so the other gamemodes are hidden from the menu. Bug
## Hunt, Tactics and Planetfall are ~28k lines carrying no turn-loop test
## coverage, and a tester crash inside one of them spends alpha time on content
## that is not being validated. Battle Simulator stays because it reuses
## TacticalBattleUI, which the core loop already exercises, and it gives a
## tester the companion in two minutes without the 7-step wizard.
##
## The modes remain compiled in and reachable via SceneRouter. Flip this to
## false to restore every entry point in one edit.
const A1_BUILD := true

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

# Mode info card on the empty left half of the menu. Swaps mode on hover.
# Data lives in data/mode_info.json (verbatim rulebook copy).
const ModeShowcaseCardScript = preload("res://src/ui/screens/mainmenu/ModeShowcaseCard.gd")
const MODE_HOVER_MAP := {
	"NewCampaign": "standard",
	"BugHunt": "bug_hunt",
	"Tactics": "tactics",
	"Planetfall": "planetfall",
}
var _showcase_card: PanelContainer = null

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

## Bottom edge (design px) of the global top-right overlay strip. The SettingsOverlay
## autoload parks the "Report a Bug" button there on EVERY screen, so top-anchored
## content has to clear it or the overlay draws on top: in portrait the bug button
## landed squarely on the app title (measured 120x60 reserved at 393x851). Read live
## rather than hardcoded so the reservation tracks the overlay instead of drifting.
func _top_right_overlay_bottom() -> float:
	var so := get_node_or_null("/root/SettingsOverlay")
	if so == null or not so.has_method("get_reserved_bottom"):
		return 0.0
	return so.get_reserved_bottom()

## Line height for a Label at `font_size`, used to reserve vertical room for
## WRAPPED text. get_combined_minimum_size() cannot serve here: it still reports
## the unwrapped single-line height until the next layout pass, so sizing the box
## from it re-creates the overflow it is meant to prevent. Falls back to a 1.4x
## ratio if the theme font is unavailable.
func _title_line_height(label: Label, font_size: int) -> float:
	var f := label.get_theme_font("font")
	if f:
		return f.get_height(font_size)
	return float(font_size) * 1.4

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
	# size_changed does NOT fire on rotation under the square 1080 base (logical
	# size is unchanged), so also react to ResponsiveManager.layout_class_changed
	# (the canonical rotation signal). Adapt the int payload to the no-arg handler.
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		# Connect a METHOD REFERENCE, not a lambda. A lambda connected to a
		# persistent autoload signal is NOT auto-disconnected when this screen is
		# freed (its captured `self` dangles), so after navigating away it fires on
		# every emit with freed `self` → "Lambda capture at index 0 was freed".
		# A method ref IS torn down when the node frees.
		#
		# Godot does NOT drop a surplus signal arg — it errors ("Method expected 0
		# argument(s), but called with 1") and the handler never runs, so the menu
		# silently failed to re-lay-out on every rotation. `_on_viewport_resized`
		# therefore takes an OPTIONAL int: it is invoked three ways (viewport
		# size_changed with 0 args, this signal with 1, and directly below), and a
		# default param satisfies all three. Same shape as
		# WorldPhaseComponent._apply_responsive_boxes(_cols: int = 0).
		rm.layout_class_changed.connect(_on_viewport_resized)
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
	_apply_a1_scope()
	_build_mode_showcase()
	_wire_mode_hovers()
	_enforce_touch_targets()
	add_fade_in_animation()

func _inject_tactics_button() -> void:
	# Dynamically add Tactics button after Bug Hunt
	if A1_BUILD:
		return # out of alpha-1 scope; every later use of tactics_button is null-guarded
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
	if A1_BUILD:
		return # out of alpha-1 scope; every later use of planetfall_button is null-guarded
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

func _apply_a1_scope() -> void:
	## Hide the scene-defined buttons for modes outside alpha-1 scope. Tactics and
	## Planetfall are handled at their injection sites (never created at all), so
	## only Co-op and Bug Hunt need hiding here.
	##
	## Runs AFTER _connect_buttons so the handlers stay wired: this is a visibility
	## change, not a teardown, and flipping A1_BUILD restores the menu with no other
	## edit. A hidden Control does not emit mouse_entered, so _wire_mode_hovers
	## leaves the showcase card able to resolve only "standard".
	if not A1_BUILD:
		return
	if coop_campaign_button:
		coop_campaign_button.visible = false
	if bug_hunt_button:
		bug_hunt_button.visible = false

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
		_add_onboard_button()
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

func _build_mode_showcase() -> void:
	# Mode info card anchored to the left half of the menu. The card itself
	# is a PanelContainer (Deep Space themed) that swaps mode data on hover.
	_showcase_card = ModeShowcaseCardScript.new()
	_showcase_card.name = "ModeShowcaseCard"
	_showcase_card.layout_mode = 1
	_showcase_card.anchor_left = 0.0
	_showcase_card.anchor_top = 0.0
	_showcase_card.anchor_right = 0.5
	_showcase_card.anchor_bottom = 1.0
	_showcase_card.offset_left = 60
	_showcase_card.offset_top = 180
	_showcase_card.offset_right = -40
	_showcase_card.offset_bottom = -80
	_showcase_card.grow_horizontal = Control.GROW_DIRECTION_END
	_showcase_card.grow_vertical = Control.GROW_DIRECTION_END
	_showcase_card.modulate = Color(1, 1, 1, 0.0)
	add_child(_showcase_card)
	move_child(_showcase_card, 1)
	_showcase_card.cta_pressed.connect(_on_mode_cta_pressed)
	# Defer the initial populate by one frame so freshly-imported textures
	# (cover PNGs) finish decoding before the card tries to load them.
	_initial_mode_swap.call_deferred()

func _initial_mode_swap() -> void:
	if not _showcase_card:
		return
	_showcase_card.set_mode("standard", true)
	# Fade the card itself in for a smooth first-paint.
	var t := create_tween()
	t.tween_property(_showcase_card, "modulate:a", 1.0, 0.30)

func _wire_mode_hovers() -> void:
	var hover_pairs := [
		[new_campaign_button, "standard"],
		[bug_hunt_button, "bug_hunt"],
		[tactics_button, "tactics"],
		[planetfall_button, "planetfall"],
	]
	for pair in hover_pairs:
		var btn: Button = pair[0]
		var key: String = pair[1]
		if btn:
			btn.mouse_entered.connect(_on_mode_button_hovered.bind(key))

func _on_mode_button_hovered(mode_id: String) -> void:
	if _showcase_card:
		_showcase_card.set_mode(mode_id, false)

## CTA on the info card was pressed. If unlocked, route through the existing
## per-mode button so we reuse all existing flow (save detection, dialogs,
## etc.). If locked, route to the store screen.
func _on_mode_cta_pressed(mode_id: String, is_unlocked: bool) -> void:
	if not is_unlocked:
		request_scene_change("store")
		return
	# Trigger the underlying mode button so existing handlers run unchanged.
	var btn_name: String = ""
	for n in MODE_HOVER_MAP:
		if MODE_HOVER_MAP[n] == mode_id:
			btn_name = n
			break
	if btn_name.is_empty():
		return
	var btn = get_node_or_null("MenuScroll/MenuButtons/" + btn_name)
	if not btn:
		# Dynamically-injected buttons (Tactics/Planetfall) live by name on the
		# menu container; find_child handles them.
		btn = find_child(btn_name, true, false)
	if btn and btn is Button:
		btn.pressed.emit()

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
		# Route by the campaign's OWN type. This used to hardcode
		# "campaign_dashboard", so a boot-auto-loaded Bug Hunt / Planetfall /
		# Tactics campaign opened the 5PFH dashboard. Paired with the boot loader
		# fix in GameState.load_campaign_typed(): that stops the save being
		# mis-parsed, this stops it being shown on the wrong screen.
		#
		# Only the three newer cores declare campaign_type (BugHuntCampaignCore:16,
		# PlanetfallCampaignCore:22, TacticsCampaignCore:18). FiveParsecsCampaignCore
		# does not, which is also why its saves carry no type field and the detector
		# treats an absent field as 5PFH.
		var dashboard := "campaign_dashboard"
		var gs := get_node_or_null("/root/GameState")
		var active = gs.current_campaign if gs else null
		if active != null and "campaign_type" in active:
			match str(active.campaign_type):
				"bug_hunt": dashboard = "bug_hunt_dashboard"
				"planetfall": dashboard = "planetfall_dashboard"
				"tactics": dashboard = "tactics_dashboard"
		_navigate_with_loading(dashboard, PackedStringArray([
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

## Code-add an "Onboard Existing Game" button as a sibling of New Campaign (avoids a
## .tscn edit). Starts the normal creation wizard but flags onboarding mode, so on
## finalize CampaignCreationUI hands off to the Campaign Editor (set the mid-campaign
## accumulated state) instead of jumping straight into the turn controller.
func _add_onboard_button() -> void:
	if new_campaign_button == null or not is_instance_valid(new_campaign_button):
		return
	var parent = new_campaign_button.get_parent()
	if parent == null:
		return
	var onboard_btn := Button.new()
	onboard_btn.name = "OnboardExisting"
	onboard_btn.text = "Onboard Existing Game"
	onboard_btn.tooltip_text = "Enter a tabletop campaign already in progress (set turn, credits, crew)"
	onboard_btn.custom_minimum_size.y = maxf(new_campaign_button.custom_minimum_size.y, 48.0)
	onboard_btn.size_flags_horizontal = new_campaign_button.size_flags_horizontal
	onboard_btn.size_flags_vertical = new_campaign_button.size_flags_vertical
	onboard_btn.pressed.connect(_on_onboard_existing_pressed)
	parent.add_child(onboard_btn)
	parent.move_child(onboard_btn, new_campaign_button.get_index() + 1)

func _on_onboard_existing_pressed() -> void:
	if not is_instance_valid(game_state_manager):
		show_message("Error: Game state manager not available")
		return
	# Flag consumed by CampaignCreationUI._on_campaign_finalized / CampaignEditorScreen.
	if game_state_manager.has_method("set_temp_data"):
		game_state_manager.set_temp_data("onboarding_mode", true)
	_start_new_campaign()

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
	panel_style.bg_color = UIColors.COLOR_PRIMARY
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)

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
		btn_sty.bg_color = UIColors.COLOR_SECONDARY
		btn_sty.border_color = UIColors.COLOR_BORDER
		btn_sty.set_border_width_all(1)
		btn_sty.set_corner_radius_all(4)
		btn_sty.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_sty)
		var btn_hov := btn_sty.duplicate()
		btn_hov.bg_color = UIColors.COLOR_BLUE
		btn.add_theme_stylebox_override("hover", btn_hov)
		btn.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		btn.pressed.connect(
			_load_and_go_to_dashboard.bind(
				save_path, dialog, backdrop))
		row.add_child(btn)

		# ISSUE-050: Delete button per save
		var del_btn := Button.new()
		del_btn.text = "\u2715"  # ✕ unicode multiply sign — cleaner than "X"
		del_btn.custom_minimum_size = Vector2(48, 48)
		del_btn.tooltip_text = "Delete this save"
		del_btn.add_theme_color_override("font_color", UIColors.COLOR_RED)
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
	imp_sty.bg_color = UIColors.COLOR_SECONDARY
	imp_sty.border_color = UIColors.COLOR_CYAN
	imp_sty.set_border_width_all(1)
	imp_sty.set_corner_radius_all(4)
	imp_sty.set_content_margin_all(8)
	import_btn.add_theme_stylebox_override("normal", imp_sty)
	import_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_CYAN)
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
		# Route by the loaded campaign's OWN type, exactly as _on_continue_pressed
		# does. This used to hardcode "campaign_turn_controller", so picking a Bug
		# Hunt / Planetfall / Tactics save out of the Load list opened the 5PFH turn
		# controller: load_campaign() parses the save correctly, but the screen was
		# chosen before anyone looked at what had been loaded, so the tester saw the
		# 5PFH World Phase with an empty crew, no ship and no world — their squad
		# apparently gone.
		#
		# Continue was fixed for this and Load was not: the same guard on one of two
		# doors. Only the three newer cores declare campaign_type; an absent field
		# means 5PFH.
		var target := "campaign_turn_controller"
		var loaded = gs.current_campaign
		if loaded != null and "campaign_type" in loaded:
			match str(loaded.campaign_type):
				"bug_hunt": target = "bug_hunt_dashboard"
				"planetfall": target = "planetfall_dashboard"
				"tactics": target = "tactics_dashboard"
		_navigate_with_loading(target, PackedStringArray([
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
			# Remove the .bak generation too. SaveFileWriter keeps the previous
			# generation beside every save and load_from_file() now falls back to it,
			# so deleting only the primary would let the campaign reappear on the very
			# next load — a delete that quietly undoes itself.
			var bak := path + ".bak"
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(bak)
			# Evict it from memory as well. GameState holds the loaded campaign, and
			# nothing here told it the file is gone: Continue would reopen the deleted
			# campaign from RAM and the next autosave would write the file straight
			# back to the same path.
			_forget_deleted_campaign(path)
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

func _forget_deleted_campaign(path: String) -> void:
	## Evict a just-deleted campaign from GameState. Saves are written as
	## user://saves/<campaign_id>.save, so the basename IS the id.
	var campaign_id := path.get_file().get_basename()
	if campaign_id.is_empty():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("forget_campaign"):
		gs.forget_campaign(campaign_id)
	# Continue is only meaningful while a campaign is loaded; re-evaluate now that
	# one may have just been dropped.
	update_continue_button_visibility()


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
	panel_style.bg_color = UIColors.COLOR_PRIMARY
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)

	var info_lbl := Label.new()
	info_lbl.text = "Found %d Bug Hunt campaign(s)." % bh_saves.size()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)
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
	panel_style.bg_color = UIColors.COLOR_PRIMARY
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)

	var info_lbl := Label.new()
	info_lbl.text = "Found %d Tactics campaign(s)." % tac_saves.size()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
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
	panel_style.bg_color = UIColors.COLOR_PRIMARY
	panel_style.border_color = UIColors.COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(400, 0)

	var info_lbl := Label.new()
	info_lbl.text = "Found %d Planetfall campaign(s)." % pf_saves.size()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
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
	# Wider so the Community + 4 social links + Credits/Privacy don't overflow the
	# 480px box and collide (the bar is hidden on narrow widths anyway).
	footer.offset_right = 760
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
	label.add_theme_font_size_override("font_size", ScreenChrome.font_size(13))
	label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY)
	_social_bar.add_child(label)

	# Link buttons
	for link: Dictionary in SOCIAL_LINKS:
		var btn := Button.new()
		btn.text = link.get("label", "")
		btn.tooltip_text = link.get("tooltip", "")
		btn.flat = true
		btn.custom_minimum_size.y = 36
		btn.add_theme_font_size_override("font_size", ScreenChrome.font_size(13))
		btn.add_theme_color_override(
			"font_color", UIColors.COLOR_CYAN)
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
	credits_btn.add_theme_font_size_override("font_size", ScreenChrome.font_size(13))
	credits_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY)
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
	privacy_btn.add_theme_font_size_override("font_size", ScreenChrome.font_size(11))
	privacy_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY)
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
	version_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(11))
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

func _on_viewport_resized(_cols: int = 0) -> void:
	## `_cols` is unused: the effective-column count arrives from
	## ResponsiveManager.layout_class_changed, but this screen re-derives what it
	## needs from should_collapse_to_single_column() below. The parameter exists so
	## one handler can serve both that 1-arg signal and the 0-arg viewport
	## size_changed. See the connection site in _ready().
	var vp := get_viewport()
	if not vp:
		return
	# Portrait detection MUST use physical density-independent size, not the
	# viewport rect. The project uses a square 1080x1080 base with
	# canvas_items+expand, so get_visible_rect().size.x is always ~1080 and
	# CANNOT distinguish portrait from landscape. ResponsiveManager is the SSOT
	# (it classifies by window_get_size()/screen_get_scale()). See
	# docs/sop/responsive-adaptive-ui.md.
	var is_narrow := false
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("should_collapse_to_single_column"):
		is_narrow = rm.should_collapse_to_single_column()
	else:
		# Defensive fallback if the autoload is unavailable.
		var scale := DisplayServer.screen_get_scale()
		if scale <= 0.0:
			scale = 1.0
		is_narrow = (DisplayServer.window_get_size().x / scale) < 768
	# The column lives inside a ScrollContainer: anchors/offsets go on the SCROLL,
	# never on the VBox. A phone in landscape has only ~339 design px of height and
	# the menu's own minimum is ~351 at the touch-target floor, so at some sizes the
	# list simply cannot fit and MUST scroll rather than clip items off-screen.
	var menu_scroll := $MenuScroll
	var menu_buttons := $MenuScroll/MenuButtons
	var title := $Title

	# Both of these were gated on WIDTH alone, which is why they survived into a
	# phone in LANDSCAPE — wide enough to count as roomy, but only ~338 design px
	# tall. The showcase card is anchored 180px from the top with an 80px bottom
	# inset, so its own content minimum then ran 567px past the bottom edge. Chrome
	# needs BOTH dimensions to be worth showing.
	var short_viewport: bool = vp.get_visible_rect().size.y < 420.0
	var hide_chrome: bool = is_narrow or short_viewport

	# Social footer: hide on very narrow or very short, show when there is room
	var social_footer := get_node_or_null("SocialFooter")
	if social_footer:
		social_footer.visible = not hide_chrome

	# Mode info card: hide when the buttons need the space (mobile, or any short
	# viewport where the card physically cannot fit between its own anchors)
	if _showcase_card:
		_showcase_card.visible = not hide_chrome

	# Every box below is derived from the LIVE design space, never hardcoded.
	# SettingsManager._apply_ui_scale() cancels the square-1080 base stretch, so the
	# design space is always `window_dp / 1.16` -- only ~339 wide at a 393dp phone,
	# NOT the ~1080 the old constants assumed. Those constants sized the title at
	# 473px inside a 339px space (clipped 67px off BOTH edges) and left it 103px
	# UNDERNEATH the button column, so the app title was unreadable on the first
	# screen in the primary alpha form factor. Measured via MCP at 393x851.
	var ds: Vector2 = vp.get_visible_rect().size
	var half_w: float = ds.x * 0.5
	var half_h: float = ds.y * 0.5
	var margin := 12.0
	# Wrap rather than overflow: a box that is too narrow costs a second line, not
	# clipped glyphs.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if is_narrow:
		# Portrait/narrow: title across the full usable width, buttons stacked below.
		var narrow_font := _scaled_font(36)
		title.add_theme_font_size_override("font_size", ScreenChrome.font_size(narrow_font))
		# Re-centre: the short-landscape branch below left-anchors the title, and a
		# rotation can land here afterwards.
		title.anchor_left = 0.5
		title.anchor_right = 0.5
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.offset_left = -(half_w - margin)
		title.offset_right = half_w - margin
		# A full-width title spans under the top-right overlay strip, so start below
		# it. The landscape branch instead sits in the left gutter, which never
		# reaches that far right, and needs no such offset.
		title.offset_top = maxf(margin, _top_right_overlay_bottom() + margin)
		# Reserve two wrapped lines. Derived from the font metrics rather than
		# get_combined_minimum_size(), which still reports the UNWRAPPED single-line
		# height until the next layout pass.
		title.offset_bottom = title.offset_top + _title_line_height(title, narrow_font) * 2.0

		menu_scroll.anchor_left = 0.5
		menu_scroll.anchor_right = 0.5
		menu_scroll.anchor_top = 0.5
		menu_scroll.anchor_bottom = 0.5
		menu_scroll.offset_left = -minf(160.0, half_w - margin)
		menu_scroll.offset_right = minf(160.0, half_w - margin)
		# Start below the title instead of centring over it.
		menu_scroll.offset_top = (title.offset_bottom + margin) - half_h
		menu_scroll.offset_bottom = (ds.y - margin) - half_h
	else:
		# Landscape/wide: right-aligned buttons (original layout)
		menu_scroll.anchor_left = 1.0
		menu_scroll.anchor_right = 1.0
		menu_scroll.anchor_top = 0.5
		menu_scroll.anchor_bottom = 0.5
		var col_w: float = minf(400.0, half_w - margin)
		menu_scroll.offset_left = -col_w
		menu_scroll.offset_right = -minf(50.0, margin)
		# Taller bounds so the full ~10-item menu column (Continue…Library) fits
		# without clipping top/bottom at 720p -- but CLAMPED to the design space. A
		# phone on its side is 851dp wide, so it lands in the DESKTOP bucket and runs
		# this branch with only ~339 design px of HEIGHT, where the fixed +-340
		# column overflowed 170px off BOTH ends. Measured via MCP at 851x393.
		var col_half: float = minf(340.0, half_h - margin)
		# The column is right-aligned, so on a SHORT landscape its top rises into the
		# reserved top-right band and the "Report a Bug" button lands on the first
		# menu item. Clamp the top below that band; on a full-height desktop window
		# the column already starts lower and this changes nothing.
		menu_scroll.offset_top = maxf(-col_half, (_top_right_overlay_bottom() + margin) - half_h)
		menu_scroll.offset_bottom = col_half

		# The centred title is only safe when the free LEFT gutter beside the
		# right-hand button column is wide enough to contain its 800px box. On a
		# 1280x800 tablet the gutter is 679 and the centred title RAN UNDER the
		# column (measured collision 248x139 via MCP); on desktop the gutter is 1231
		# and centring is correct. So: centre when it fits, otherwise left-align into
		# the gutter. A short landscape (a phone on its side) also drops the point
		# size -- 48pt would eat a third of a 339px-tall screen.
		var gutter: float = ds.x - col_w - margin * 2.0
		var use_gutter: bool = gutter < 800.0
		var short_landscape: bool = ds.y < 420.0
		# 48, not 75: at 75 (×responsive scale ≈ 86) the title overflowed its
		# 800px box and rendered clipped ("…Manag"). 48 fits the full title.
		var wide_font := _scaled_font(28 if short_landscape else 48)
		title.add_theme_font_size_override("font_size", ScreenChrome.font_size(wide_font))
		var line_h := _title_line_height(title, wide_font)
		if use_gutter:
			title.anchor_left = 0.0
			title.anchor_right = 0.0
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			title.offset_left = margin
			# Stop short of the button column's left edge (ds.x - col_w).
			title.offset_right = maxf(margin + 120.0, ds.x - col_w - margin)
			title.offset_top = margin
			title.offset_bottom = margin + line_h * 3.0
		else:
			title.anchor_left = 0.5
			title.anchor_right = 0.5
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# 400 when there is room (unchanged on desktop), clamped when there is
			# not: the old fixed 800px box overflowed a 733px design space.
			var wide_box: float = minf(400.0, half_w - margin)
			title.offset_left = -wide_box
			title.offset_right = wide_box
			title.offset_top = 50.0
			title.offset_bottom = 50.0 + maxf(100.0, line_h * 2.0)

	# Fill-or-scroll. A ScrollContainer sizes its child to the child's MINIMUM on
	# the scrolling axis, which would collapse every button to its 48px floor and
	# shrink the desktop menu. Pushing the viewport height onto the VBox as a
	# minimum keeps the buttons expanding to fill whenever there IS room, and lets
	# the content exceed the viewport (i.e. scroll) only when there genuinely is
	# not. Deferred because the scroll's own size is not final until this layout
	# pass completes.
	_apply_menu_fill.call_deferred()

## Guards _apply_menu_fill against the re-entry its own writes provoke: changing
## custom_minimum_size re-emits minimum_size_changed on the very node we listen to.
var _menu_fill_busy := false

## Keep the button column filling the scroll viewport when it fits, scrolling when
## it does not. Split out of _on_viewport_resized so it can run deferred.
##
## Driven by TWO triggers, and it needs both: a viewport resize (handled by the
## caller) and a change to the VISIBLE BUTTON SET, which happens well after layout
## -- update_continue_button_visibility() toggles Continue, and the A1 gate hides
## whole modes. With only the resize trigger a stale minimum from a taller previous
## layout survives, and the menu scrolls with "Library" clipped off the bottom on a
## screen it actually fits. Subscribing to minimum_size_changed covers every future
## caller for free, instead of a list of sites to keep in sync.
func _apply_menu_fill() -> void:
	if _menu_fill_busy:
		return
	var menu_scroll := get_node_or_null("MenuScroll")
	if menu_scroll == null:
		return
	var menu_buttons := menu_scroll.get_node_or_null("MenuButtons")
	if menu_buttons == null:
		return
	if not menu_buttons.minimum_size_changed.is_connected(_on_menu_min_size_changed):
		menu_buttons.minimum_size_changed.connect(_on_menu_min_size_changed)
	_menu_fill_busy = true
	# Clear first: a stale minimum from a LARGER previous layout would otherwise be
	# reported as the content minimum and never shrink back.
	menu_buttons.custom_minimum_size.y = 0.0
	var content_min: float = menu_buttons.get_combined_minimum_size().y
	menu_buttons.custom_minimum_size.y = maxf(content_min, menu_scroll.size.y)
	_menu_fill_busy = false

func _on_menu_min_size_changed() -> void:
	if _menu_fill_busy:
		return
	_apply_menu_fill.call_deferred()

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
