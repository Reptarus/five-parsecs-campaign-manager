extends Control

## Tactics Turn Controller — Manages 8-phase operational turn flow.
## Routes phases to dedicated panels:
##   Phases 0-3 (ORDERS→DEPLOYMENT): TacticsBattleSetupPanel
##   Phase 4 (BATTLE): Battle indicator (no panel — tabletop play)
##   Phases 5-6 (POST_BATTLE→ADVANCEMENT): TacticsPostBattlePanel
##   Phase 7 (STRATEGIC): TacticsOperationalMapPanel

var PhaseManagerScript: GDScript
var BattleSetupScript: GDScript
var PostBattleScript: GDScript
var OpMapScript: GDScript

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const TouchScrollOpenerRef = preload("res://src/ui/components/common/TouchScrollOpener.gd")
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
## The turn screen's widest content column, as in TacticsCreationUI. Uncapped, a 2560 px
## tablet put each Strategic value ~2,500 px from its label and the Battle phase's
## checkboxes at the far left edge, away from the VP field they qualify.
const MAX_CONTENT_WIDTH := 800

var phase_manager: Node  # TacticsPhaseManager
var campaign: Resource  # TacticsCampaignCore

## Phase panels
var _battle_setup: Control
var _post_battle: Control
var _op_map: Control
var _battle_indicator: Control  # Shown during BATTLE phase
var _turn_end_box: Control  # Shown between turns (see _show_turn_end)
## "Play another battle this turn" (Tactics p.96). Read by _battle_payload().
var _another_check: CheckBox
## Victory Points scored (p.73: "The rulebook scenarios all use victory points"); the
## CP award is then 1 per VP (p.106). `_no_vp_check` is for a home-made scenario that
## did not use them, which falls back to the p.107 victory / draw / defeat bonus.
var _vp_spin: SpinBox
var _no_vp_check: CheckBox

## UI refs
var _turn_label: Label
var _phase_label: Label
var _dash_btn: Button
var _panel_container: Control
var _phase_strip: HBoxContainer
var _content_margin: MarginContainer

## Cached full phase text (landscape baseline) for the phase label,
## so portrait shortening never permanently loses the original string.
var _phase_label_full_text: String = "Phase: --"


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	PhaseManagerScript = load("res://src/core/campaign/TacticsPhaseManager.gd")
	BattleSetupScript = load("res://src/ui/screens/tactics/panels/TacticsBattleSetupPanel.gd")
	PostBattleScript = load("res://src/ui/screens/tactics/panels/TacticsPostBattlePanel.gd")
	OpMapScript = load("res://src/ui/screens/tactics/panels/TacticsOperationalMapPanel.gd")
	call_deferred("_initialize")


func _initialize() -> void:
	# Deferred from _ready(), so it lands a frame later and this controller may
	# already have left the tree. The /root campaign lookups below ERROR from a
	# detached node rather than returning null, and the turn would initialise
	# against no campaign at all. Same guard as the other deferred entry points.
	if not is_inside_tree():
		return
	_load_campaign()
	if not campaign:
		return
	_build_layout()
	_create_phase_manager()
	_create_panels()
	_connect_signals()
	# Kept open, not swept once: each phase panel rebuilds its rows as the phase opens,
	# so a one-shot sweep (the panels' own) left the row each panel adds last STOP, and a
	# drag that started on it never reached the panel's scroll (test_touch_scroll_sweep).
	TouchScrollOpenerRef.keep_open(self)

	# ⚠ A Tactics battle is played on the table and RECORDED here (the BATTLE phase's
	# Victory / Draw / Defeat + Victory Points). There is no Tactics hand-off to the
	# 5PFH battle screen — a `tactics_battle_result` temp-data read used to sit here
	# for a return that no producer ever wrote (TacticalBattleUI.gd:1074-1077 says so).
	if "is_campaign_over" in campaign and campaign.is_campaign_over():
		_show_campaign_over(str(campaign.campaign_result))
		return
	# ⚠ This used to start a turn only while campaign_turn was 0 and resume every later
	# entry at Operational Orders, so after turn 1 ended, "Continue Campaign" replayed
	# turn 1 and turn 2 never began. enter_campaign() reads the recorded phase instead.
	phase_manager.enter_campaign()


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
	_content_margin = margin

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
	# 48 design px is 55.7 dp at the 1.16 effective scale; 40 was 46.4 dp, under the
	# 48 dp floor, and landscape (the tablet) kept it.
	dash_btn.custom_minimum_size.y = _UC.TOUCH_TARGET_MIN
	dash_btn.pressed.connect(func():
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("tactics_dashboard"))
	top_bar.add_child(dash_btn)
	_dash_btn = dash_btn

	# Phase strip (8 dots)
	_phase_strip = HBoxContainer.new()
	_phase_strip.add_theme_constant_override("separation", 4)
	_phase_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_phase_strip)

	for i in range(PhaseManagerScript.PHASE_COUNT):
		var dot := Label.new()
		dot.text = "○"
		dot.add_theme_font_size_override("font_size", _scaled_font(14))
		dot.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_phase_strip.add_child(dot)

	# Panel container
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Responsive top bar (portrait phones) — connect once, apply now
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		if not rm.layout_class_changed.is_connected(_on_layout_class_changed):
			rm.layout_class_changed.connect(_on_layout_class_changed)
	_apply_topbar_responsive()
	get_viewport().size_changed.connect(_apply_content_max_width)
	_apply_content_max_width()


## Centre the content in a MAX_CONTENT_WIDTH column on a wide screen; 16 px gutters
## otherwise. Width arithmetic only, so get_visible_rect() is the right read here.
func _apply_content_max_width() -> void:
	if not is_instance_valid(_content_margin) or not is_inside_tree():
		return
	var vp_width: float = get_viewport().get_visible_rect().size.x
	var side: int = 16
	if vp_width > MAX_CONTENT_WIDTH + 64:
		side = int((vp_width - MAX_CONTENT_WIDTH) / 2.0)
	_content_margin.add_theme_constant_override("margin_left", side)
	_content_margin.add_theme_constant_override("margin_right", side)


## Portrait-phone top bar adaptation. Landscape/tablet/desktop are left
## visually identical to the original layout; only the narrow single-column
## (portrait) class hides the phase label. The Dashboard button is a full touch
## target in every class.
func _apply_topbar_responsive() -> void:
	if not is_instance_valid(_dash_btn) or not is_instance_valid(_phase_label):
		return

	var collapse := false
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("should_collapse_to_single_column"):
		collapse = rm.should_collapse_to_single_column()

	if collapse:
		# Narrow portrait: reclaim horizontal space.
		# Hide the phase text (the 8-dot strip still shows progress),
		_phase_label.visible = false
	else:
		# Landscape / wider: original behavior.
		_phase_label.visible = true
		_phase_label.text = _phase_label_full_text


func _on_layout_class_changed(_effective_columns: int) -> void:
	_apply_topbar_responsive()


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
	# p.99 Step 9. Declared and emitted since 2026-09-07 and connected by NOTHING, so a
	# war that ended kept offering turns.
	phase_manager.campaign_ended.connect(_on_campaign_ended)

	# ⚠ FORWARD THE PAYLOAD. These three lambdas used to be `func(_p, _d):
	# phase_manager.complete_current_phase()` — dropping the dictionary the panel
	# had just emitted. `complete_current_phase(result_data := {})` then ran with
	# an empty dict, so EVERY `data.has(...)` branch in TacticsPhaseManager's six
	# _apply_* consumers was permanently false: orders, intel, scenario,
	# deployed_units, story_event, skills_acquired, cp_spent, roster_changes,
	# operational_map_update and pbp_spent all had a correct consumer and no
	# producer that could reach it. `play_another` was dropped too, which made
	# MAX_BATTLES_PER_TURN unreachable (:129-137) — a Tactics turn could only ever
	# hold one battle.
	#
	# This is the transport half. It is worth nothing on its own: the three panels
	# must also emit a real payload instead of `{}`. Both halves are needed, and
	# each is independently detection-proven in
	# tests/unit/test_tactics_turn_payload.gd — reverting THIS line alone must turn
	# that suite red, or the suite is not testing the wiring.
	_battle_setup.phase_completed.connect(
		func(_p, d): phase_manager.complete_current_phase(d))
	_post_battle.phase_completed.connect(
		func(_p, d): phase_manager.complete_current_phase(d))
	_op_map.phase_completed.connect(
		func(_p, d): phase_manager.complete_current_phase(d))


func _on_turn_started(turn: int) -> void:
	_turn_label.text = "Turn %d" % turn


func _on_phase_changed(_old: int, new_phase: int) -> void:
	# Cache the full label text so portrait shortening never loses it,
	# but only push it to the (possibly-hidden) label.
	_phase_label_full_text = "Phase: %s" % phase_manager.get_phase_name(
		new_phase)
	_phase_label.text = _phase_label_full_text

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
	_clear_turn_end()

	match new_phase:
		0, 1, 2, 3:  # ORDERS → DEPLOYMENT
			_battle_setup.visible = true
			_battle_setup.show_phase(new_phase)
		4:  # BATTLE
			_battle_indicator.visible = true
			# p.95 sets no ceiling on battles per operational turn, so this is always
			# offered; it is reset each time so a stale tick never loops a turn.
			if is_instance_valid(_another_check) and phase_manager:
				_another_check.visible = phase_manager.can_play_another_battle()
				_another_check.button_pressed = false
			if is_instance_valid(_vp_spin):
				_vp_spin.value = 0
		5, 6:  # POST_BATTLE → ADVANCEMENT
			_post_battle.visible = true
			_post_battle.show_phase(new_phase)
		7:  # STRATEGIC
			_op_map.visible = true
			_op_map.show_phase(new_phase)


func _on_turn_completed(turn: int) -> void:
	_phase_label.text = "Turn Complete!"
	# Mark all dots as complete
	for i in range(_phase_strip.get_child_count()):
		var dot: Label = _phase_strip.get_child(i)
		dot.text = "●"
		dot.add_theme_color_override("font_color", COLOR_SUCCESS)
	_show_turn_end(turn)


## The end of an operational turn. ⚠ It used to leave the Strategic panel on screen with
## its button disabled and "Turn Complete!" in the top bar, and nothing said what came
## next; the next turn was reachable only through the Dashboard.
func _show_turn_end(turn: int) -> void:
	if campaign and campaign.has_method("is_campaign_over") and campaign.is_campaign_over():
		return  # Step 9 ended the war; _show_campaign_over() owns the screen.
	_hide_all_panels()
	_clear_turn_end()
	_turn_end_box = VBoxContainer.new()
	_turn_end_box.name = "TurnEnd"
	_turn_end_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_turn_end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn_end_box.add_theme_constant_override("separation", SPACING_LG)
	_panel_container.add_child(_turn_end_box)
	var lbl := Label.new()
	lbl.text = "Turn %d is complete and saved." % turn
	lbl.add_theme_font_size_override("font_size", _scaled_font(20))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_end_box.add_child(lbl)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", SPACING_MD)
	row.add_theme_constant_override("v_separation", SPACING_MD)
	_turn_end_box.add_child(row)
	var next_btn := Button.new()
	next_btn.name = "StartNextTurn"
	next_btn.text = "Start Turn %d" % (turn + 1)
	next_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	next_btn.pressed.connect(func() -> void:
		_clear_turn_end()
		phase_manager.start_new_turn())
	row.add_child(next_btn)
	var dash := Button.new()
	dash.text = "Return to Dashboard"
	dash.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	dash.pressed.connect(func() -> void:
		var router := get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("tactics_dashboard"))
	row.add_child(dash)


func _clear_turn_end() -> void:
	if is_instance_valid(_turn_end_box):
		_turn_end_box.queue_free()
	_turn_end_box = null


func _hide_all_panels() -> void:
	_battle_setup.visible = false
	_post_battle.visible = false
	_op_map.visible = false
	_battle_indicator.visible = false


## The BATTLE phase payload. `battle_result` drives both `record_battle()` (CP, p.107)
## and the Player Battle Point award (p.96); `play_another` drives the loop back to
## BATTLE_PREP. Both were being dropped before 2026-09-07 — the first by the controller
## lambda, the second because nothing ever set it.
##
## `outcome` is "victory", "draw" or "defeat". A draw earns no PBP and cancels nothing
## (p.96) and +2 CP when no VP were scored (p.107); it used to be unrecordable.
func _battle_payload(outcome: String) -> Dictionary:
	var play_another: bool = (
		is_instance_valid(_another_check) and _another_check.button_pressed)
	var result: Dictionary = {
		"won": outcome == "victory",
		"draw": outcome == "draw",
	}
	if is_instance_valid(_vp_spin) and not (
			is_instance_valid(_no_vp_check) and _no_vp_check.button_pressed):
		result["victory_points"] = int(_vp_spin.value)
	return {"battle_result": result, "play_another": play_another}


func _on_campaign_ended(result: String) -> void:
	if "end_campaign" in campaign:
		campaign.end_campaign(result)
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(campaign)
	_show_campaign_over(result)


## The war is over (p.99): show the result instead of another turn.
func _show_campaign_over(result: String) -> void:
	if not is_instance_valid(_panel_container):
		return
	_hide_all_panels()
	var text: String = {
		"player": "VICTORY — the enemy's Cohesion is broken. Only your faction remains.",
		"enemy": "DEFEAT — your faction's Cohesion is broken.",
		"inconclusive": "INCONCLUSIVE — every faction reached 0 Cohesion together; "
			+ "both sides are completely exhausted.",
	}.get(result, "The campaign is over.")
	var lbl := Label.new()
	lbl.text = "%s\n\n(Tactics p.99, Step 9)" % text
	lbl.add_theme_font_size_override("font_size", _scaled_font(20))
	lbl.add_theme_color_override("font_color",
		COLOR_SUCCESS if result == "player" else COLOR_TEXT_SEC)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_container.add_child(lbl)
	if is_instance_valid(_phase_label):
		_phase_label.text = "Campaign over"


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

	# Victory / Draw / Defeat buttons (placed below the VP row further down)
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	# Victory Points first: p.73 "The rulebook scenarios all use victory points", and
	# p.106 awards 1 CP per VP when they are used.
	var vp_row := HBoxContainer.new()
	vp_row.add_theme_constant_override("separation", SPACING_MD)
	vp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(vp_row)
	var vp_lbl := Label.new()
	vp_lbl.text = "Victory Points you scored:"
	vp_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	vp_row.add_child(vp_lbl)
	_vp_spin = SpinBox.new()
	_vp_spin.min_value = 0
	_vp_spin.max_value = 99
	_vp_spin.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	vp_row.add_child(_vp_spin)
	_no_vp_check = CheckBox.new()
	_no_vp_check.text = "This scenario did not use Victory Points"
	_no_vp_check.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_no_vp_check.toggled.connect(func(on: bool) -> void: _vp_spin.editable = not on)
	# Wrapped: unwrapped, its text set a 310 px phone's page width (318). It fills the
	# row rather than shrinking to centre, because a wrapping CheckBox's minimum is one
	# word wide; the turn screen's content width keeps it near the VP field instead.
	_no_vp_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_no_vp_check)

	for outcome in ["victory", "draw", "defeat"]:
		var b := Button.new()
		b.text = String(outcome).capitalize()
		b.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
		b.pressed.connect(func():
			phase_manager.complete_current_phase(_battle_payload(outcome)))
		btn_box.add_child(b)

	# Play-another option (Tactics p.96: "you may have multiple battles per campaign
	# turn"). ⚠ This was a Button with `visible = false` and NO `pressed` connection at
	# all — the `play_another` key had no producer, so TacticsPhaseManager's loop back
	# to BATTLE_PREP was unreachable and a Tactics turn could only ever hold one battle.
	# (The invented three-battle ceiling it once sat behind is gone: p.95 allows "any
	# number of tabletop battles".)
	#
	# It is a CheckBox rather than a button on purpose: another button would complete
	# the phase with no battle result at all, losing the outcome the PBP award (p.96)
	# is computed from. The player records the outcome; this only says whether another
	# battle follows. It sits on its own row so the outcome buttons fit a phone width.
	# ⚠ It sits ABOVE the outcome buttons: pressing one completes the phase at once, so
	# an option placed below them (as it was until 2026-10-28) had to be ticked before
	# the button it qualifies, against the reading order.
	_another_check = CheckBox.new()
	_another_check.text = "Play another battle this turn"
	_another_check.custom_minimum_size = Vector2(0, TOUCH_TARGET_COMFORT)
	_another_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_another_check.visible = false  # Shown when the BATTLE phase opens
	vbox.add_child(_another_check)
	vbox.move_child(btn_box, vbox.get_child_count() - 1)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)

	return vbox

