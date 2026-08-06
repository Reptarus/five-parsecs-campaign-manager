class_name FPCM_TierSelectionPanel
extends PanelContainer

## Tier Selection Panel - Choose tracking level before battle
##
## Presents three large, touch-friendly buttons for selecting the companion
## tracking tier. Shown before battle begins. Remembers last selection.
##
## Reference: Five Parsecs From Home - Companion Philosophy
## "Minimal for veterans, full oracle for learning, player always chooses."

const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")

signal tier_selected(tier: int)
## Emitted when a MID-BATTLE change is dismissed without changing anything.
## Deliberately distinct from tier_selected(LOG_ONLY): the pre-battle skip button
## legitimately MEANS "log only", but a mid-battle dismiss must never silently
## downgrade the player's tracking level.
signal change_cancelled

# Design system constants (from UIColors)
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const SPACING_XL := UIColors.SPACING_XL
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const FONT_SIZE_XL := UIColors.FONT_SIZE_XL
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

var _tier_buttons: Array[Button] = []
var _title: Label = null
var _subtitle: Label = null
var _skip_btn: Button = null
## -1 = pre-battle first pick. >= 0 = a mid-battle change FROM that tier, which
## disables every lower option: BattleTierController refuses a mid-battle
## downgrade, and offering a button that silently does nothing is the exact
## defect family this component sits inside.
var _change_from_tier: int = -1

func _ready() -> void:
	_setup_panel_style()
	_build_ui()
	if _change_from_tier >= 0:
		_apply_change_mode()


func configure_for_change(current_tier: int) -> void:
	## Switch this panel from "pick your level" to "change your level mid-battle".
	## Safe to call before OR after the node enters the tree: _build_ui() runs in
	## _ready(), so an early request is stored and applied there (the project's
	## pending-data pattern for Control/Window construction races).
	_change_from_tier = current_tier
	if is_node_ready():
		_apply_change_mode()


func _apply_change_mode() -> void:
	## Re-dress the pre-battle panel as a mid-battle change. Only copy and enabled
	## state change — the buttons still emit the same tier_selected signal, so the
	## consumer decides what a change MEANS.
	if _title:
		_title.text = "Change Companion Level"
	if _subtitle:
		_subtitle.text = "You can add help mid-battle. Reducing it is not " \
			+ "possible once the battle has started."
	for i in range(_tier_buttons.size()):
		var btn: Button = _tier_buttons[i]
		if not is_instance_valid(btn):
			continue
		# _tier_buttons is built in LOG_ONLY/ASSISTED/FULL_ORACLE order, so the
		# index IS the tier value.
		if i < _change_from_tier:
			btn.disabled = true
			btn.tooltip_text = "Cannot reduce tracking mid-battle"
		elif i == _change_from_tier:
			btn.disabled = true
			btn.tooltip_text = "This is your current level"
	if _skip_btn:
		_skip_btn.text = "Keep current level"

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = COLOR_BORDER
	style.set_content_margin_all(SPACING_XL)
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Choose Your Companion Level"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# These two lines set this whole overlay's minimum width. Unwrapped, the title
	# needs 367px and the subtitle 336 — both wider than a 339px phone — so the
	# overlay was dragged off the screen edge and the tier buttons underneath it went
	# with it. Autowrap is safe here: this is a plain VBox, and the tier buttons below
	# already wrap the same way.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)
	_title = title

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "How much help do you want during this battle?"
	subtitle.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(subtitle)
	_subtitle = subtitle

	# Tier buttons
	for tier_value: int in [
		BattleTierControllerClass.TrackingTier.LOG_ONLY,
		BattleTierControllerClass.TrackingTier.ASSISTED,
		BattleTierControllerClass.TrackingTier.FULL_ORACLE
	]:
		var info: Dictionary = BattleTierControllerClass.TIER_INFO.get(tier_value, {})
		var btn := _create_tier_button(tier_value, info)
		vbox.add_child(btn)
		_tier_buttons.append(btn)

	# Skip/dismiss button — defaults to LOG_ONLY so user isn't stuck
	_skip_btn = _create_skip_button()
	vbox.add_child(_skip_btn)

func _create_tier_button(tier: int, info: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = "TierButton_%d" % tier
	btn.text = "%s\n%s" % [info.get("name", "Unknown"), info.get("description", "")]
	btn.custom_minimum_size = Vector2(0, 72)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = false

	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = COLOR_BORDER
	style.border_width_left = 4
	style.set_content_margin_all(SPACING_MD)

	# Accent color per tier
	match tier:
		BattleTierControllerClass.TrackingTier.LOG_ONLY:
			style.border_color = Color("#6b7280")
		BattleTierControllerClass.TrackingTier.ASSISTED:
			style.border_color = Color("#3b82f6")
		BattleTierControllerClass.TrackingTier.FULL_ORACLE:
			style.border_color = Color("#f59e0b")

	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = COLOR_ACCENT
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = COLOR_ACCENT_HOVER
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)

	btn.pressed.connect(_on_tier_button_pressed.bind(tier))
	return btn

func _create_skip_button() -> Button:
	var btn := Button.new()
	btn.text = "Skip — Use Log Only"
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)

	var hover := style.duplicate()
	hover.bg_color = Color(COLOR_ELEVATED.r + 0.05, COLOR_ELEVATED.g + 0.05, COLOR_ELEVATED.b + 0.05, 0.7)
	btn.add_theme_stylebox_override("hover", hover)

	btn.pressed.connect(func():
		# Pre-battle this button MEANS "log only". Mid-battle the same gesture
		# means "leave my level alone" — emitting LOG_ONLY there would be a
		# silent downgrade triggered by a dismiss.
		if _change_from_tier >= 0:
			change_cancelled.emit()
		else:
			tier_selected.emit(BattleTierControllerClass.TrackingTier.LOG_ONLY)
	)
	return btn

func _on_tier_button_pressed(tier: int) -> void:
	tier_selected.emit(tier)
