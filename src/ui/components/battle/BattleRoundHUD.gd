class_name BattleRoundHUD
extends Control

## Battle Round HUD - Visual display of round and phase progression
##
## Displays:
## - Current round number (prominently)
## - All 5 battle phases with active phase highlighted
## - Battle event indicator for rounds 2 and 4
## - Phase transitions with animations

# Preload BattleRoundTracker for type access
const BattleRoundTrackerClass = preload("res://src/core/battle/BattleRoundTracker.gd")

# Signals (call-down-signal-up pattern)
signal phase_clicked(phase: int)
signal round_info_requested()
signal next_phase_requested()

# Constants from UIColors design system
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG

const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const FONT_SIZE_XL := UIColors.FONT_SIZE_XL

const COLOR_PRIMARY := UIColors.COLOR_PRIMARY
const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_TERTIARY := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER

const COLOR_BLUE := UIColors.COLOR_BLUE
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_RED := UIColors.COLOR_RED

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

# UI references
var _round_label: Label
var _phase_container: HBoxContainer
var _event_indicator: PanelContainer
var _event_label: Label
var _phase_buttons: Array[Button] = []
var _reminder_label: Label
var _next_phase_button: Button
var _auto_prompt_label: Label

# Current state
var _current_round: int = 1
var _current_phase: int = BattleRoundTrackerClass.BattlePhase.REACTION_ROLL
var _display_tier: int = 0 # 0=LOG_ONLY, 1=ASSISTED, 2=FULL_ORACLE
var _casualties_this_round: int = 0

# Session 48: Battle context for contextual phase reminders
var _battle_context: Dictionary = {}

## AI type descriptions for contextual enemy reminder (Core Rules pp.94-103)
const AI_BRIEF: Dictionary = {
	"A": "Aggressive — charge closest",
	"C": "Cautious — cover + shoot",
	"D": "Defensive — hold + shoot if approached",
	"G": "Guardian — protect assigned unit",
	"R": "Rampage — rush + melee",
	"T": "Tactical — advance to cover, best target",
	"B": "Beast — move to nearest, attack",
}

func _ready() -> void:
	_build_ui()
	_update_display()

func _get_minimum_size() -> Vector2:
	## Propagate internal VBox minimum size so parent containers allocate enough space.
	## BattleRoundHUD extends Control (not Container), so this override is required.
	var vbox: VBoxContainer = get_node_or_null("MainVBox")
	if vbox:
		return vbox.get_combined_minimum_size()
	return Vector2.ZERO

## Connect to BattleRoundTracker signals
func connect_to_tracker(tracker: BattleRoundTrackerClass) -> void:
	## Wire up signals from BattleRoundTracker (call-down pattern)
	if not tracker:
		push_error("BattleRoundHUD: Cannot connect to null tracker")
		return

	tracker.phase_changed.connect(_on_tracker_phase_changed)
	tracker.round_changed.connect(_on_tracker_round_changed)
	tracker.battle_event_triggered.connect(_on_tracker_battle_event)
	tracker.battle_started.connect(_on_tracker_battle_started)
	tracker.battle_ended.connect(_on_tracker_battle_ended)

## Disconnect from tracker (cleanup)
func disconnect_from_tracker(tracker: BattleRoundTrackerClass) -> void:
	## Clean disconnect from tracker
	if not tracker:
		return

	if tracker.phase_changed.is_connected(_on_tracker_phase_changed):
		tracker.phase_changed.disconnect(_on_tracker_phase_changed)
	if tracker.round_changed.is_connected(_on_tracker_round_changed):
		tracker.round_changed.disconnect(_on_tracker_round_changed)
	if tracker.battle_event_triggered.is_connected(_on_tracker_battle_event):
		tracker.battle_event_triggered.disconnect(_on_tracker_battle_event)
	if tracker.battle_started.is_connected(_on_tracker_battle_started):
		tracker.battle_started.disconnect(_on_tracker_battle_started)
	if tracker.battle_ended.is_connected(_on_tracker_battle_ended):
		tracker.battle_ended.disconnect(_on_tracker_battle_ended)

# Signal handlers (receive data from tracker)

func _on_tracker_phase_changed(new_phase: int, phase_name: String) -> void:
	## Handle phase change from tracker
	_current_phase = new_phase
	_update_phase_display()
	_animate_phase_transition()

func _on_tracker_round_changed(new_round: int) -> void:
	## Handle round change from tracker
	_current_round = new_round
	_update_round_display()
	_check_battle_event_indicator()

func _on_tracker_battle_event(round: int, event_type: String) -> void:
	## Handle battle event trigger
	_show_event_indicator(round, event_type)

func _on_tracker_battle_started() -> void:
	## Handle battle start
	_current_round = 1
	_current_phase = int(BattleRoundTrackerClass.BattlePhase.REACTION_ROLL)
	_update_display()

func _on_tracker_battle_ended() -> void:
	## Handle battle end
	_hide_event_indicator()

# UI building

func _build_ui() -> void:
	## Build the HUD structure
	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Top row: Round counter + Event indicator
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", SPACING_MD)
	main_vbox.add_child(top_row)

	# Round counter
	_round_label = Label.new()
	_round_label.name = "RoundLabel"
	_round_label.text = "ROUND 1"
	_round_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_round_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_round_label)

	# Event indicator (hidden by default)
	_event_indicator = PanelContainer.new()
	_event_indicator.name = "EventIndicator"
	_event_indicator.visible = false
	top_row.add_child(_event_indicator)

	var event_stylebox := StyleBoxFlat.new()
	event_stylebox.bg_color = COLOR_AMBER
	event_stylebox.corner_radius_top_left = 4
	event_stylebox.corner_radius_top_right = 4
	event_stylebox.corner_radius_bottom_left = 4
	event_stylebox.corner_radius_bottom_right = 4
	event_stylebox.content_margin_left = SPACING_SM
	event_stylebox.content_margin_right = SPACING_SM
	event_stylebox.content_margin_top = SPACING_XS
	event_stylebox.content_margin_bottom = SPACING_XS
	_event_indicator.add_theme_stylebox_override("panel", event_stylebox)

	_event_label = Label.new()
	_event_label.text = "BATTLE EVENT"
	_event_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_event_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	_event_indicator.add_child(_event_label)

	# Phase container
	_phase_container = HBoxContainer.new()
	_phase_container.name = "PhaseContainer"
	_phase_container.add_theme_constant_override("separation", SPACING_XS)
	main_vbox.add_child(_phase_container)

	# Create phase buttons
	var phase_names: Array[String] = [
		"Reaction\nRoll",
		"Quick\nActions",
		"Enemy\nActions",
		"Slow\nActions",
		"End\nPhase"
	]

	for i in range(5):
		var phase_button := Button.new()
		phase_button.name = "Phase_%d" % i
		phase_button.text = phase_names[i]
		phase_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		phase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		phase_button.clip_text = false
		phase_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Style inactive phase
		_style_phase_button(phase_button, false)

		# Connect signal
		var phase_idx: int = i
		phase_button.pressed.connect(func(): _on_phase_button_pressed(phase_idx))

		_phase_container.add_child(phase_button)
		_phase_buttons.append(phase_button)

	# Phase reminder text (below phase buttons)
	_reminder_label = Label.new()
	_reminder_label.name = "PhaseReminder"
	_reminder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reminder_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_reminder_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(_reminder_label)

	# Auto-prompt label (Tier 2+ only, hidden by default)
	_auto_prompt_label = Label.new()
	_auto_prompt_label.name = "AutoPrompt"
	_auto_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto_prompt_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_auto_prompt_label.add_theme_color_override("font_color", COLOR_AMBER)
	_auto_prompt_label.visible = false
	main_vbox.add_child(_auto_prompt_label)

	# "Next Phase" button (touch-friendly)
	_next_phase_button = Button.new()
	_next_phase_button.name = "NextPhaseButton"
	_next_phase_button.text = "Next Phase"
	_next_phase_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_next_phase_button.pressed.connect(_on_next_phase_pressed)
	_style_next_phase_button()
	main_vbox.add_child(_next_phase_button)

	_update_reminder_text()

func _style_next_phase_button() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = COLOR_EMERALD
	stylebox.set_corner_radius_all(6)
	stylebox.set_content_margin_all(SPACING_SM)
	_next_phase_button.add_theme_stylebox_override("normal", stylebox)

	var hover := stylebox.duplicate()
	hover.bg_color = COLOR_EMERALD.lightened(0.15)
	_next_phase_button.add_theme_stylebox_override("hover", hover)

	var pressed := stylebox.duplicate()
	pressed.bg_color = COLOR_EMERALD.darkened(0.15)
	_next_phase_button.add_theme_stylebox_override("pressed", pressed)

	_next_phase_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_next_phase_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)

func _on_next_phase_pressed() -> void:
	next_phase_requested.emit()

func _style_phase_button(button: Button, is_active: bool) -> void:
	## Legacy wrapper — use _style_phase_button_state instead
	_style_phase_button_state(button, "active" if is_active else "upcoming")

func _style_phase_button_state(button: Button, state: String) -> void:
	## Apply color-coded styling: "completed" (green), "active" (cyan), "upcoming" (gray)
	var stylebox := StyleBoxFlat.new()

	match state:
		"completed":
			stylebox.bg_color = COLOR_EMERALD.darkened(0.6)
			button.add_theme_color_override("font_color", COLOR_EMERALD)
			button.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		"active":
			stylebox.bg_color = COLOR_BLUE
			button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		_:  # upcoming
			stylebox.bg_color = COLOR_SECONDARY
			button.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
			button.add_theme_font_size_override("font_size", FONT_SIZE_SM)

	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = COLOR_BORDER if state != "active" else Color(0.31, 0.76, 0.97, 0.8)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	stylebox.content_margin_left = SPACING_SM
	stylebox.content_margin_right = SPACING_SM
	stylebox.content_margin_top = SPACING_SM
	stylebox.content_margin_bottom = SPACING_SM

	button.add_theme_stylebox_override("normal", stylebox)
	button.add_theme_stylebox_override("hover", stylebox)
	button.add_theme_stylebox_override("pressed", stylebox)

# Display updates

func _update_display() -> void:
	## Update full display
	_update_round_display()
	_update_phase_display()
	_check_battle_event_indicator()

func _update_round_display() -> void:
	## Update round counter
	if _round_label:
		_round_label.text = "ROUND %d" % _current_round

func _update_phase_display() -> void:
	## Update phase button states with color coding:
	## completed = green, current = cyan, upcoming = gray
	for i in range(_phase_buttons.size()):
		if i < _current_phase:
			_style_phase_button_state(_phase_buttons[i], "completed")
		elif i == _current_phase:
			_style_phase_button_state(_phase_buttons[i], "active")
		else:
			_style_phase_button_state(_phase_buttons[i], "upcoming")
	_update_reminder_text()

func _check_battle_event_indicator() -> void:
	## Show/hide battle event indicator
	if _current_round in BattleRoundTrackerClass.BATTLE_EVENT_ROUNDS:
		_show_event_indicator(_current_round, "random_event")
	else:
		_hide_event_indicator()

func _show_event_indicator(round: int, event_type: String) -> void:
	## Display battle event warning
	if _event_indicator:
		_event_indicator.visible = true
		_event_label.text = "BATTLE EVENT (Round %d)" % round

func _hide_event_indicator() -> void:
	## Hide battle event warning
	if _event_indicator:
		_event_indicator.visible = false

func _animate_phase_transition() -> void:
	## Animate phase change (simple pulse effect)
	var active_button: Button = _phase_buttons[_current_phase]
	
	# Create tween for pulse animation
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Pulse scale
	tween.tween_property(active_button, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(active_button, "scale", Vector2(1.0, 1.0), 0.2)

# Input handlers

func _on_phase_button_pressed(phase_idx: int) -> void:
	## Handle phase button click - signal up to parent
	phase_clicked.emit(phase_idx)

# =====================================================
# PHASE REMINDERS & TIER-AWARE FEATURES
# =====================================================

## Five Parsecs Core Rules phase instructions (p.118)
const PHASE_REMINDERS: Dictionary = {
	0: "Roll 1D6 per crew member. Results <= Reactions = Quick Actions.",
	1: "Crew who passed reactions act now. Move+Shoot OR Double Move each.",
	2: "All enemies act. Move toward closest crew, shoot if in range.",
	3: "Remaining crew act now. Same options as Quick Actions.",
	4: "Morale check (if 3+ enemies down). Battle events (R2, R4). Victory check.",
}

func _update_reminder_text() -> void:
	if not _reminder_label:
		return
	_reminder_label.text = _get_contextual_reminder()

	# Update auto-prompt for Tier 2+
	_update_auto_prompt()

	# Update next phase button text
	if _next_phase_button:
		var next_names: Dictionary = {
			0: "Start Quick Actions",
			1: "Start Enemy Actions",
			2: "Start Slow Actions",
			3: "End Phase",
			4: "Next Round",
		}
		_next_phase_button.text = next_names.get(_current_phase, "Next Phase")

func _update_auto_prompt() -> void:
	if not _auto_prompt_label:
		return

	# Auto-prompts only at Tier 2 (ASSISTED) and above
	if _display_tier < 1:
		_auto_prompt_label.visible = false
		return

	var prompt_text: String = ""

	# End phase specific prompts
	if _current_phase == 4: # END_PHASE
		if _casualties_this_round > 0:
			prompt_text = "Morale check needed - %d casualt%s this round." % [
				_casualties_this_round,
				"y" if _casualties_this_round == 1 else "ies"]

		if _current_round == 2 or _current_round == 4:
			if not prompt_text.is_empty():
				prompt_text += " "
			prompt_text += "Roll d100 for Battle Event (Core Rules p.116)."

		if _current_round > 4:
			if not prompt_text.is_empty():
				prompt_text += " "
			prompt_text += "Roll d6 for escalation: 1-2 battle ends, 6 escalation event."

	# Enemy actions phase: Tier 3 reminder
	if _current_phase == 2 and _display_tier >= 2: # ENEMY_ACTIONS + FULL_ORACLE
		prompt_text = "See AI Oracle panel for enemy behavior instructions."

	if prompt_text.is_empty():
		_auto_prompt_label.visible = false
	else:
		_auto_prompt_label.text = prompt_text
		_auto_prompt_label.visible = true

## Set the display tier for tier-aware features.
func set_display_tier(tier: int) -> void:
	_display_tier = tier
	_update_reminder_text()

## Report a casualty this round (for morale prompt tracking).
func report_casualty() -> void:
	_casualties_this_round += 1
	_update_auto_prompt()

## Reset per-round tracking (called at start of new round).
func reset_round_tracking() -> void:
	_casualties_this_round = 0
	_update_auto_prompt()

## Session 48: Set battle context for contextual phase reminders.
func set_battle_context(data: Dictionary) -> void:
	_battle_context = data
	_update_reminder_text()

func _get_contextual_reminder() -> String:
	## Generate phase reminder text with battle-specific context.
	## Max 2 lines: base instruction + one contextual line.
	var base: String = PHASE_REMINDERS.get(_current_phase, "")

	if _battle_context.is_empty():
		return base

	var deploy: Dictionary = _battle_context.get("deployment", {})
	var cond_id: String = deploy.get("condition_id", "")
	var ef: Dictionary = _battle_context.get("enemy_force", {})

	match _current_phase:
		0: # REACTION_ROLL
			if cond_id == "CAUGHT_OFF_GUARD" and _current_round == 1:
				return base + "\nCAUGHT OFF GUARD: All crew act Slow this round."
			if cond_id == "POOR_VISIBILITY" and _current_round > 1:
				return base + "\nReroll visibility: 1D6+8\" max range this round."
			if cond_id == "DELAYED" and _current_round > 1:
				return base + "\nDelayed crew: 1D6, on %d- they arrive." % _current_round
		1: # QUICK_ACTIONS
			if cond_id == "SLIPPERY_GROUND":
				return base + "\nSLIPPERY: All ground movement -1 Speed."
		2: # ENEMY_ACTIONS
			if cond_id == "SURPRISE_ENCOUNTER" and _current_round == 1:
				return base + "\nSURPRISE: Enemies skip this round!"
			var ai_code: String = str(ef.get("ai", ""))
			var enemy_name: String = ef.get("type", "")
			if not enemy_name.is_empty() and not ai_code.is_empty():
				var ai_brief: String = AI_BRIEF.get(
					ai_code, "")
				if not ai_brief.is_empty():
					return base + "\n%s (%s)" % [
						enemy_name, ai_brief]
		4: # END_PHASE
			var check_count: int = 1 # Morale always
			if cond_id in [
				"BRIEF_ENGAGEMENT", "DELAYED",
				"TOXIC_ENVIRONMENT", "POOR_VISIBILITY"]:
				check_count += 1
			if _current_round == 2 or _current_round == 4:
				check_count += 1
			if check_count > 1:
				return base + "\n%d end-of-round checks — see checklist below." % check_count

	return base
