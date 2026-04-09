extends Control

## Tactics Post-Battle Panel — Covers POST_BATTLE + ADVANCEMENT phases.
## Process casualties, award CP, check story events, spend CP on upgrades.
## Covers phases 5-6 of the 8-phase turn.

signal phase_completed(phase: int, data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_FOCUS := _UC.COLOR_FOCUS
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_DANGER := _UC.COLOR_DANGER
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
var _phase_title: Label
var _complete_btn: Button


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func setup(phase_mgr, campaign_res) -> void:
	_phase_manager = phase_mgr
	_campaign = campaign_res


func show_phase(phase: int) -> void:
	if not _phase_title:
		return

	for child in _content.get_children():
		child.queue_free()

	if phase == 5:  # POST_BATTLE
		_phase_title.text = "Post-Battle"
		_build_post_battle_content()
	elif phase == 6:  # ADVANCEMENT
		_phase_title.text = "Advancement"
		_build_advancement_content()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_phase_title = Label.new()
	_phase_title.text = "Post-Battle"
	_phase_title.add_theme_font_size_override("font_size", _scaled_font(22))
	_phase_title.add_theme_color_override("font_color", COLOR_TEXT)
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_complete_btn = Button.new()
	_complete_btn.text = "Complete Phase"
	_complete_btn.custom_minimum_size = Vector2(200, TOUCH_TARGET_COMFORT)
	_complete_btn.pressed.connect(_on_complete)
	nav.add_child(_complete_btn)


func _build_post_battle_content() -> void:
	# Battle result summary
	_add_card("Battle Result",
		"Process casualties and award Campaign Points. "\
		+ "Each battle earns 1 CP, +1 for victory, +1 for secondary objectives.")

	# CP earned display
	if _campaign:
		var cp: int = 0
		if _campaign.has_method("get_available_cp"):
			cp = _campaign.get_available_cp()
		var cp_lbl := Label.new()
		cp_lbl.text = "Available CP: %d" % cp
		cp_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
		cp_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(cp_lbl)

	# Casualty list
	_add_card("Casualties",
		"Review unit losses from this battle. "\
		+ "Destroyed units can be replaced by spending CP during Advancement.")

	# Story event check
	_add_card("Story Events",
		"Roll on the D100 story event table to see "\
		+ "if anything changes on the strategic level.")


func _build_advancement_content() -> void:
	_add_card("Spend Campaign Points",
		"Use your earned CP to improve your force:\n"\
		+ "- Unit Upgrade (1 CP): Acquire a veteran skill\n"\
		+ "- Roster Change (1 CP): Add or replace a unit\n"\
		+ "- Battle Advantage (1 CP): One-time bonus for next battle")

	if _campaign:
		var cp: int = 0
		if _campaign.has_method("get_available_cp"):
			cp = _campaign.get_available_cp()
		var cp_lbl := Label.new()
		cp_lbl.text = "CP Available to Spend: %d" % cp
		cp_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
		cp_lbl.add_theme_color_override("font_color",
			COLOR_SUCCESS if cp > 0 else COLOR_TEXT_SEC)
		cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(cp_lbl)


func _add_card(card_title: String, body: String) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	var t := Label.new()
	t.text = card_title
	t.add_theme_font_size_override("font_size", _scaled_font(16))
	t.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(t)

	var b := Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", _scaled_font(14))
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(b)

	_content.add_child(card)


func _on_complete() -> void:
	var current: int = _phase_manager.current_phase \
		if _phase_manager else 5
	phase_completed.emit(current, {})
