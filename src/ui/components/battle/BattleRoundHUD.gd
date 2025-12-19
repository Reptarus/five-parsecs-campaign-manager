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

# Constants from BaseCampaignPanel design system
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const COLOR_PRIMARY := Color("#0a0d14")
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")

const COLOR_BLUE := Color("#3b82f6")
const COLOR_EMERALD := Color("#10b981")
const COLOR_AMBER := Color("#f59e0b")
const COLOR_RED := Color("#ef4444")

const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")
const COLOR_TEXT_MUTED := Color("#6b7280")

const TOUCH_TARGET_MIN := 48

# UI references
var _round_label: Label
var _phase_container: HBoxContainer
var _event_indicator: PanelContainer
var _event_label: Label
var _phase_buttons: Array[Button] = []

# Current state
var _current_round: int = 1
var _current_phase: int = BattleRoundTrackerClass.BattlePhase.REACTION_ROLL

func _ready() -> void:
	_build_ui()
	_update_display()

## Connect to BattleRoundTracker signals
func connect_to_tracker(tracker: BattleRoundTrackerClass) -> void:
	"""Wire up signals from BattleRoundTracker (call-down pattern)"""
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
	"""Clean disconnect from tracker"""
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
	"""Handle phase change from tracker"""
	_current_phase = new_phase
	_update_phase_display()
	_animate_phase_transition()

func _on_tracker_round_changed(new_round: int) -> void:
	"""Handle round change from tracker"""
	_current_round = new_round
	_update_round_display()
	_check_battle_event_indicator()

func _on_tracker_battle_event(round: int, event_type: String) -> void:
	"""Handle battle event trigger"""
	_show_event_indicator(round, event_type)

func _on_tracker_battle_started() -> void:
	"""Handle battle start"""
	_current_round = 1
	_current_phase = int(BattleRoundTrackerClass.BattlePhase.REACTION_ROLL)
	_update_display()

func _on_tracker_battle_ended() -> void:
	"""Handle battle end"""
	_hide_event_indicator()

# UI building

func _build_ui() -> void:
	"""Build the HUD structure"""
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

func _style_phase_button(button: Button, is_active: bool) -> void:
	"""Apply styling to phase button"""
	var stylebox := StyleBoxFlat.new()
	
	if is_active:
		# Active phase: Blue accent
		stylebox.bg_color = COLOR_BLUE
		button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	else:
		# Inactive phase: Secondary background
		stylebox.bg_color = COLOR_SECONDARY
		button.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		button.add_theme_font_size_override("font_size", FONT_SIZE_SM)

	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = COLOR_BORDER
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
	"""Update full display"""
	_update_round_display()
	_update_phase_display()
	_check_battle_event_indicator()

func _update_round_display() -> void:
	"""Update round counter"""
	if _round_label:
		_round_label.text = "ROUND %d" % _current_round

func _update_phase_display() -> void:
	"""Update phase button states"""
	for i in range(_phase_buttons.size()):
		var is_active: bool = (i == _current_phase)
		_style_phase_button(_phase_buttons[i], is_active)

func _check_battle_event_indicator() -> void:
	"""Show/hide battle event indicator"""
	if _current_round in BattleRoundTrackerClass.BATTLE_EVENT_ROUNDS:
		_show_event_indicator(_current_round, "random_event")
	else:
		_hide_event_indicator()

func _show_event_indicator(round: int, event_type: String) -> void:
	"""Display battle event warning"""
	if _event_indicator:
		_event_indicator.visible = true
		_event_label.text = "BATTLE EVENT (Round %d)" % round

func _hide_event_indicator() -> void:
	"""Hide battle event warning"""
	if _event_indicator:
		_event_indicator.visible = false

func _animate_phase_transition() -> void:
	"""Animate phase change (simple pulse effect)"""
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
	"""Handle phase button click - signal up to parent"""
	phase_clicked.emit(phase_idx)
