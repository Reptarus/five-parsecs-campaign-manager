extends PanelContainer

## Tap-a-sector popover — the ONE on-map interaction (map-primary redesign).
## Answers "what do I physically put in this sector?": the sector's features,
## each with its Core Rules terrain category + LOS/cover/movement rules
## (pp.37-39), plus the best-cover chip. During SETUP it also offers a
## per-sector Re-roll (Compendium Step 5 sanctions swapping pieces for
## playability, p.95).
##
## Ported from the retired BattlefieldGridPanel popover. Presented by the
## host (TacticalBattleUI OverlayLayer); tap-outside dismissal is the
## host's responsibility via the overlay background.

signal re_roll_requested(sector_label: String)
signal dismissed

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_NOTABLE := Color("#D97706")
const TOUCH_TARGET_MIN := 48

var _label: RichTextLabel
var _reroll_button: Button
var _dismiss_button: Button
var _sector_label: String = ""

func _init() -> void:
	name = "SectorRulesPopover"
	visible = false
	custom_minimum_size = Vector2(360, 0)
	z_index = 10

	var pop_style := StyleBoxFlat.new()
	pop_style.bg_color = Color(0.102, 0.102, 0.18, 0.95)
	pop_style.border_width_left = 2
	pop_style.border_width_top = 2
	pop_style.border_width_right = 2
	pop_style.border_width_bottom = 2
	pop_style.border_color = COLOR_NOTABLE
	pop_style.corner_radius_top_left = 8
	pop_style.corner_radius_top_right = 8
	pop_style.corner_radius_bottom_right = 8
	pop_style.corner_radius_bottom_left = 8
	pop_style.content_margin_left = 16.0
	pop_style.content_margin_right = 16.0
	pop_style.content_margin_top = 12.0
	pop_style.content_margin_bottom = 12.0
	pop_style.shadow_color = Color(0, 0, 0, 0.4)
	pop_style.shadow_size = 8
	add_theme_stylebox_override("panel", pop_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_label.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	_reroll_button = Button.new()
	_reroll_button.text = "Re-roll Sector"
	_reroll_button.tooltip_text = \
		"Swap this sector's rolled feature for a new one (Compendium Step 5, p.95)"
	_reroll_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_button.add_theme_font_size_override("font_size", 13)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	button_row.add_child(_reroll_button)

	_dismiss_button = Button.new()
	_dismiss_button.text = "Dismiss"
	_dismiss_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_dismiss_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dismiss_button.add_theme_font_size_override("font_size", 13)
	_dismiss_button.pressed.connect(hide_popover)
	button_row.add_child(_dismiss_button)

## Show details for a sector. allow_reroll: SETUP stage only — once the
## physical table is built, editing affordances disappear (desync hazard).
func show_sector(sector_label: String, features: Array,
		allow_reroll: bool = false) -> void:
	_sector_label = sector_label
	_label.text = _build_bbcode(sector_label, features)
	_reroll_button.visible = allow_reroll
	visible = true

func hide_popover() -> void:
	visible = false
	dismissed.emit()

func _on_reroll_pressed() -> void:
	if not _sector_label.is_empty():
		re_roll_requested.emit(_sector_label)

func _build_bbcode(sector_label: String, features: Array) -> String:
	var bbcode: String = "[b][font_size=18]Sector %s[/font_size][/b]\n\n" % sector_label
	if features.is_empty():
		bbcode += "[color=#808080]Open ground — no terrain features placed here.[/color]"
		return bbcode

	for feat: String in features:
		if feat.begins_with("NOTABLE:"):
			bbcode += "[color=#10B981][b]%s[/b][/color]\n" % feat
		elif feat.begins_with("Scatter:"):
			bbcode += "[color=#808080]%s[/color]\n" % feat
		else:
			bbcode += "%s\n" % feat

		# Core Rules terrain category (pp.37-39) with LOS/cover/movement rules
		if not feat.begins_with("Scatter:"):
			var category: String = \
				BattlefieldShapeLibrary.classify_terrain_rules_category(feat)
			var rules_text: String = \
				BattlefieldShapeLibrary.get_terrain_rules_text(category)
			bbcode += "  [color=#9CA3AF][i][%s] %s — %s[/i][/color]\n" % [
				BattlefieldShapeLibrary.get_category_badge(category),
				category, rules_text]

	var cover: String = _infer_cover(features)
	if not cover.is_empty():
		var cover_color: String = "#10B981" if cover == "FULL" else "#D97706"
		bbcode += "\n[color=%s]Best Cover: %s[/color]" % [cover_color, cover]

	return bbcode

func _infer_cover(features: Array) -> String:
	var cover: String = ""
	for feat: String in features:
		var lower: String = feat.to_lower()
		if "full cover" in lower:
			return "FULL"
		if "partial cover" in lower:
			cover = "PARTIAL"
	return cover
