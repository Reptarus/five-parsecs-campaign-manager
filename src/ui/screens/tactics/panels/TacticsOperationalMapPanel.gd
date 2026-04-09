extends Control

## Tactics Operational Map Panel — Covers STRATEGIC phase (phase 7).
## Shows operational map state, resolves operational combat, issues orders,
## manages commando raids and force redeployment.

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
const COLOR_WARNING := _UC.COLOR_WARNING
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _phase_manager = null
var _campaign = null
var _content: VBoxContainer
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


func show_phase(_phase: int) -> void:
	_rebuild_content()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "STRATEGIC PHASE"
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Resolve operational combat, issue orders, "\
		+ "redeploy forces, and open new zones."
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_complete_btn = Button.new()
	_complete_btn.text = "Complete Strategic Phase"
	_complete_btn.custom_minimum_size = Vector2(240, TOUCH_TARGET_COMFORT)
	_complete_btn.pressed.connect(_on_complete)
	nav.add_child(_complete_btn)


func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()

	if not _campaign or not "operational_map" in _campaign:
		var lbl := Label.new()
		lbl.text = "No operational map data."
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_content.add_child(lbl)
		return

	var map: Dictionary = _campaign.operational_map

	# Cohesion display
	var p_coh: int = map.get("player_cohesion", 5)
	var e_coh: int = map.get("enemy_cohesion", 5)
	_add_stat_row("Player Cohesion", str(p_coh),
		COLOR_SUCCESS if p_coh >= 3 else COLOR_DANGER)
	_add_stat_row("Enemy Cohesion", str(e_coh),
		COLOR_DANGER if e_coh >= 3 else COLOR_SUCCESS)

	# PBP
	var pbp: int = map.get("player_battle_points", 0)
	_add_stat_row("Player Battle Points", str(pbp), COLOR_FOCUS)

	# 8-step operational turn checklist
	_add_card("Operational Turn Steps",
		"1. Play tabletop battles (done)\n"\
		+ "2. Apply Player Battle Points (+1 per win)\n"\
		+ "3. Resolve operational combat (dice pool per zone)\n"\
		+ "4. Operational orders (D6 table)\n"\
		+ "5. Commando raids (spend PBP)\n"\
		+ "6. Redeploy forces\n"\
		+ "7. Open new zones, select focus\n"\
		+ "8. Choose player commitments")

	# Zones summary
	var zones: Array = map.get("zones", [])
	if not zones.is_empty():
		var zone_lbl := Label.new()
		zone_lbl.text = "Active Zones: %d" % zones.size()
		zone_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
		zone_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		_content.add_child(zone_lbl)


func _add_stat_row(label: String, value: String, color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	_content.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", _scaled_font(18))
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)


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
	phase_completed.emit(7, {})
