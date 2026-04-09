extends Control

## Tactics Turn Controller — Manages 8-phase operational turn flow.
## Routes phases to dedicated panels:
##   Phases 0-3 (ORDERS→DEPLOYMENT): TacticsBattleSetupPanel
##   Phase 4 (BATTLE): Battle indicator (no panel — tabletop play)
##   Phases 5-6 (POST_BATTLE→ADVANCEMENT): TacticsPostBattlePanel
##   Phase 7 (STRATEGIC): TacticsOperationalMapPanel

const PhaseManagerScript = preload(
	"res://src/core/campaign/TacticsPhaseManager.gd")
const BattleSetupScript = preload(
	"res://src/ui/screens/tactics/panels/TacticsBattleSetupPanel.gd")
const PostBattleScript = preload(
	"res://src/ui/screens/tactics/panels/TacticsPostBattlePanel.gd")
const OpMapScript = preload(
	"res://src/ui/screens/tactics/panels/TacticsOperationalMapPanel.gd")

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_FOCUS := _UC.COLOR_FOCUS
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var phase_manager: Node  # TacticsPhaseManager
var campaign: Resource  # TacticsCampaignCore

## Phase panels
var _battle_setup: Control
var _post_battle: Control
var _op_map: Control
var _battle_indicator: Control  # Shown during BATTLE phase

## UI refs
var _turn_label: Label
var _phase_label: Label
var _panel_container: Control
var _phase_strip: HBoxContainer


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	_load_campaign()
	if not campaign:
		return
	_build_layout()
	_create_phase_manager()
	_create_panels()
	_connect_signals()

	# Check for returning from battle
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	var battle_result = null
	if gs_mgr and gs_mgr.has_method("get_temp_data"):
		battle_result = gs_mgr.get_temp_data(
			"tactics_battle_result")

	if battle_result is Dictionary and not battle_result.is_empty():
		_resume_after_battle(battle_result)
		if gs_mgr.has_method("set_temp_data"):
			gs_mgr.set_temp_data("tactics_battle_result", null)
	else:
		var turn: int = campaign.campaign_turn \
			if "campaign_turn" in campaign else 0
		if turn <= 0:
			phase_manager.start_new_turn()
		else:
			phase_manager.turn_number = turn
			phase_manager.campaign_turn_started.emit(turn)
			phase_manager.go_to_phase(
				TacticsPhaseManager.Phase.ORDERS)


func _load_campaign() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_campaign"):
		campaign = gs.get_current_campaign()
	if not campaign and gs and "current_campaign" in gs:
		campaign = gs.current_campaign

	if campaign and not "campaign_units" in campaign:
		push_warning(
			"TacticsTurnController: Not a TacticsCampaignCore")
		campaign = null
		var router = get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("main_menu")


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Top bar
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	vbox.add_child(top_bar)

	_turn_label = Label.new()
	_turn_label.text = "Turn 0"
	_turn_label.add_theme_font_size_override(
		"font_size", _scaled_font(18))
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT)
	top_bar.add_child(_turn_label)

	_phase_label = Label.new()
	_phase_label.text = "Phase: --"
	_phase_label.add_theme_font_size_override(
		"font_size", _scaled_font(16))
	_phase_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_phase_label)

	# Dashboard button
	var dash_btn := Button.new()
	dash_btn.text = "Dashboard"
	dash_btn.custom_minimum_size.y = 40
	dash_btn.pressed.connect(func():
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("tactics_dashboard"))
	top_bar.add_child(dash_btn)

	# Phase strip (8 dots)
	_phase_strip = HBoxContainer.new()
	_phase_strip.add_theme_constant_override("separation", 4)
	_phase_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_phase_strip)

	for i in range(TacticsPhaseManager.PHASE_COUNT):
		var dot := Label.new()
		dot.text = "○"
		dot.add_theme_font_size_override("font_size", _scaled_font(14))
		dot.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_phase_strip.add_child(dot)

	# Panel container
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)


func _create_phase_manager() -> void:
	phase_manager = PhaseManagerScript.new()
	add_child(phase_manager)
	phase_manager.setup(campaign)


func _create_panels() -> void:
	_battle_setup = BattleSetupScript.new()
	_battle_setup.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT)
	_battle_setup.visible = false
	_battle_setup.setup(phase_manager, campaign)
	_panel_container.add_child(_battle_setup)

	_post_battle = PostBattleScript.new()
	_post_battle.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT)
	_post_battle.visible = false
	_post_battle.setup(phase_manager, campaign)
	_panel_container.add_child(_post_battle)

	_op_map = OpMapScript.new()
	_op_map.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT)
	_op_map.visible = false
	_op_map.setup(phase_manager, campaign)
	_panel_container.add_child(_op_map)

	# Battle indicator (phase 4 — tabletop play, no panel)
	_battle_indicator = _create_battle_indicator()
	_battle_indicator.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT)
	_battle_indicator.visible = false
	_panel_container.add_child(_battle_indicator)


func _connect_signals() -> void:
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.campaign_turn_started.connect(_on_turn_started)
	phase_manager.campaign_turn_completed.connect(_on_turn_completed)

	_battle_setup.phase_completed.connect(
		func(_p, _d): phase_manager.complete_current_phase())
	_post_battle.phase_completed.connect(
		func(_p, _d): phase_manager.complete_current_phase())
	_op_map.phase_completed.connect(
		func(_p, _d): phase_manager.complete_current_phase())


func _on_turn_started(turn: int) -> void:
	_turn_label.text = "Turn %d" % turn


func _on_phase_changed(_old: int, new_phase: int) -> void:
	_phase_label.text = "Phase: %s" % phase_manager.get_phase_name(
		new_phase)

	# Update phase strip
	for i in range(_phase_strip.get_child_count()):
		var dot: Label = _phase_strip.get_child(i)
		if i < new_phase:
			dot.text = "●"
			dot.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif i == new_phase:
			dot.text = "◉"
			dot.add_theme_color_override("font_color", COLOR_FOCUS)
		else:
			dot.text = "○"
			dot.add_theme_color_override("font_color", COLOR_TEXT_SEC)

	# Route to correct panel
	_hide_all_panels()

	match new_phase:
		0, 1, 2, 3:  # ORDERS → DEPLOYMENT
			_battle_setup.visible = true
			_battle_setup.show_phase(new_phase)
		4:  # BATTLE
			_battle_indicator.visible = true
		5, 6:  # POST_BATTLE → ADVANCEMENT
			_post_battle.visible = true
			_post_battle.show_phase(new_phase)
		7:  # STRATEGIC
			_op_map.visible = true
			_op_map.show_phase(new_phase)


func _on_turn_completed(_turn: int) -> void:
	_phase_label.text = "Turn Complete!"
	# Mark all dots as complete
	for i in range(_phase_strip.get_child_count()):
		var dot: Label = _phase_strip.get_child(i)
		dot.text = "●"
		dot.add_theme_color_override("font_color", COLOR_SUCCESS)


func _hide_all_panels() -> void:
	_battle_setup.visible = false
	_post_battle.visible = false
	_op_map.visible = false
	_battle_indicator.visible = false


func _create_battle_indicator() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	var title := Label.new()
	title.text = "BATTLE IN PROGRESS"
	title.add_theme_font_size_override("font_size", _scaled_font(28))
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Fight the tabletop battle. When finished, "\
		+ "record the result below."
	desc.add_theme_font_size_override("font_size", _scaled_font(16))
	desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Victory / Defeat buttons
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	var win_btn := Button.new()
	win_btn.text = "Victory"
	win_btn.custom_minimum_size = Vector2(150, TOUCH_TARGET_COMFORT)
	win_btn.pressed.connect(func():
		phase_manager.complete_current_phase(
			{"battle_result": {"won": true}}))
	btn_box.add_child(win_btn)

	var lose_btn := Button.new()
	lose_btn.text = "Defeat"
	lose_btn.custom_minimum_size = Vector2(150, TOUCH_TARGET_COMFORT)
	lose_btn.pressed.connect(func():
		phase_manager.complete_current_phase(
			{"battle_result": {"won": false}}))
	btn_box.add_child(lose_btn)

	# Play another battle option
	var another_btn := Button.new()
	another_btn.text = "Play Another Battle"
	another_btn.custom_minimum_size = Vector2(200, 44)
	another_btn.visible = false  # Shown after first battle
	btn_box.add_child(another_btn)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)

	return vbox


func _resume_after_battle(result: Dictionary) -> void:
	phase_manager.turn_number = campaign.campaign_turn \
		if "campaign_turn" in campaign else 1
	phase_manager.go_to_phase(TacticsPhaseManager.Phase.POST_BATTLE)
	phase_manager.complete_current_phase(
		{"battle_result": result})
