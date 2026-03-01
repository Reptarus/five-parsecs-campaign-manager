extends Control
class_name CampaignScreenBase

## Lightweight base class for campaign screens (dashboard, crew management,
## trading, travel, etc). Provides the UIColors design system, responsive
## layout helpers, and UI factory methods shared across all campaign screens.
##
## For campaign-creation wizard panels, use FiveParsecsCampaignPanel instead.

# ── Signals ───────────────────────────────────────────────────────────────────
signal screen_ready

# ── Autoload references ───────────────────────────────────────────────────────
@onready var _game_state: Node = get_node_or_null("/root/GameState")
@onready var _responsive_manager: Node = get_node_or_null("/root/ResponsiveManager")

# ── Responsive layout ─────────────────────────────────────────────────────────
enum LayoutMode { MOBILE, TABLET, DESKTOP }
var current_layout_mode: LayoutMode = LayoutMode.DESKTOP

# ── Design tokens — sourced from UIColors (canonical token file) ──────────────
## Spacing (8px grid)
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const SPACING_XL := UIColors.SPACING_XL

## Touch targets
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const TOUCH_TARGET_COMFORT := UIColors.TOUCH_TARGET_COMFORT

## Typography
const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const FONT_SIZE_XL := UIColors.FONT_SIZE_XL

## Breakpoints
const BREAKPOINT_MOBILE := UIColors.BREAKPOINT_MOBILE
const BREAKPOINT_TABLET := UIColors.BREAKPOINT_TABLET
const BREAKPOINT_DESKTOP := UIColors.BREAKPOINT_DESKTOP

## Color palette — deep space theme
const COLOR_PRIMARY := UIColors.COLOR_PRIMARY
const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_TERTIARY := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_BLUE := UIColors.COLOR_BLUE
const COLOR_PURPLE := UIColors.COLOR_PURPLE
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_RED := UIColors.COLOR_RED
const COLOR_CYAN := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

## Legacy aliases
const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_INPUT := UIColors.COLOR_INPUT
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_FOCUS := UIColors.COLOR_FOCUS
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS
const COLOR_WARNING := UIColors.COLOR_WARNING
const COLOR_DANGER := UIColors.COLOR_DANGER
const COLOR_TEXT_DISABLED := UIColors.COLOR_TEXT_DISABLED

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_responsive_signals()
	_apply_responsive_layout()
	_setup_screen()
	screen_ready.emit()

func _exit_tree() -> void:
	if _responsive_manager and \
			_responsive_manager.has_signal("breakpoint_changed") and \
			_responsive_manager.breakpoint_changed.is_connected(_on_responsive_breakpoint_changed):
		_responsive_manager.breakpoint_changed.disconnect(_on_responsive_breakpoint_changed)

## Override in derived screens to build or wire up screen-specific content.
func _setup_screen() -> void:
	pass

# ── Campaign data access ──────────────────────────────────────────────────────

## Convenience accessor for the current campaign object.
## Returns null if GameState is unavailable or no campaign is loaded.
func _get_campaign():
	if not _game_state:
		return null
	if _game_state.has_method("get_current_campaign"):
		return _game_state.get_current_campaign()
	return null

# ── Responsive layout system ──────────────────────────────────────────────────

func _connect_responsive_signals() -> void:
	if _responsive_manager and _responsive_manager.has_signal("breakpoint_changed"):
		_responsive_manager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		_sync_with_responsive_manager()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var w := vp.get_visible_rect().size.x
	var new_mode: LayoutMode
	if w < BREAKPOINT_MOBILE:
		new_mode = LayoutMode.MOBILE
	elif w < BREAKPOINT_TABLET:
		new_mode = LayoutMode.TABLET
	else:
		new_mode = LayoutMode.DESKTOP
	if new_mode != current_layout_mode:
		current_layout_mode = new_mode
		_update_layout_for_mode()

func _sync_with_responsive_manager() -> void:
	if not _responsive_manager:
		return
	var bp: int = _responsive_manager.current_breakpoint
	# ResponsiveManager.Breakpoint: 0=MOBILE, 1=TABLET, 2=DESKTOP, 3=WIDE
	match bp:
		0:
			current_layout_mode = LayoutMode.MOBILE
		1:
			current_layout_mode = LayoutMode.TABLET
		_:
			current_layout_mode = LayoutMode.DESKTOP
	_update_layout_for_mode()

func _on_responsive_breakpoint_changed(new_breakpoint: int) -> void:
	match new_breakpoint:
		0:
			current_layout_mode = LayoutMode.MOBILE
		1:
			current_layout_mode = LayoutMode.TABLET
		_:
			current_layout_mode = LayoutMode.DESKTOP
	_update_layout_for_mode()

func _update_layout_for_mode() -> void:
	match current_layout_mode:
		LayoutMode.MOBILE:
			_apply_mobile_layout()
		LayoutMode.TABLET:
			_apply_tablet_layout()
		LayoutMode.DESKTOP:
			_apply_desktop_layout()

## Override for mobile breakpoint (< 480px).
func _apply_mobile_layout() -> void:
	pass

## Override for tablet breakpoint (480-768px).
func _apply_tablet_layout() -> void:
	pass

## Override for desktop breakpoint (> 768px).
func _apply_desktop_layout() -> void:
	pass

# ── Responsive query helpers ──────────────────────────────────────────────────

func is_mobile_layout() -> bool:
	return current_layout_mode == LayoutMode.MOBILE

func is_tablet_layout() -> bool:
	return current_layout_mode == LayoutMode.TABLET

func is_desktop_layout() -> bool:
	return current_layout_mode == LayoutMode.DESKTOP

func should_use_single_column() -> bool:
	if current_layout_mode == LayoutMode.MOBILE:
		return true
	var sz := get_viewport().get_visible_rect().size
	return sz.y > sz.x

func get_optimal_column_count() -> int:
	if should_use_single_column():
		return 1
	match current_layout_mode:
		LayoutMode.TABLET:
			return 2
		LayoutMode.DESKTOP:
			return 3
		_:
			return 2

func get_responsive_spacing(base_spacing: int) -> int:
	match current_layout_mode:
		LayoutMode.MOBILE:
			return max(SPACING_XS, base_spacing - 4)
		LayoutMode.DESKTOP:
			return base_spacing + 4
		_:
			return base_spacing

func get_responsive_font_size(base_size: int) -> int:
	match current_layout_mode:
		LayoutMode.MOBILE:
			return max(FONT_SIZE_XS, base_size - 2)
		_:
			return base_size

func get_responsive_touch_target() -> int:
	return TOUCH_TARGET_COMFORT if is_mobile_layout() else TOUCH_TARGET_MIN

# ── Style factories ───────────────────────────────────────────────────────────

func _create_glass_card_style(alpha: float = 0.8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, alpha)
	s.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	s.set_border_width_all(1)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(SPACING_LG)
	return s

func _create_glass_card_elevated() -> StyleBoxFlat:
	return _create_glass_card_style(0.9)

func _create_glass_card_subtle() -> StyleBoxFlat:
	return _create_glass_card_style(0.6)

func _create_elevated_card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_TERTIARY
	s.border_color = COLOR_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(SPACING_MD)
	return s

func _create_glass_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	s.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	s.set_border_width_all(1)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(SPACING_LG)
	return s

func _create_glass_panel_style_compact() -> StyleBoxFlat:
	var s := _create_glass_panel_style()
	s.set_content_margin_all(SPACING_MD)
	s.set_corner_radius_all(12)
	return s

func _create_accent_card_style(accent_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.1)
	s.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.2)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(SPACING_MD)
	return s

# ── Panel styling helpers (screen-specific) ───────────────────────────────────

func _apply_panel_style(panel: PanelContainer, style_name: String) -> void:
	var s: StyleBoxFlat
	match style_name:
		"glass":
			s = _create_glass_card_style()
		"glass_elevated":
			s = _create_glass_card_elevated()
		"glass_subtle":
			s = _create_glass_card_subtle()
		"elevated":
			s = _create_elevated_card_style()
		"compact":
			s = _create_glass_panel_style_compact()
		"accent_blue":
			s = _create_accent_card_style(COLOR_BLUE)
		"accent_amber":
			s = _create_accent_card_style(COLOR_AMBER)
		"accent_red":
			s = _create_accent_card_style(COLOR_RED)
		"accent_cyan":
			s = _create_accent_card_style(COLOR_CYAN)
		_:
			push_warning("CampaignScreenBase._apply_panel_style: unknown style '%s'" % style_name)
			return
	panel.add_theme_stylebox_override("panel", s)

func _style_all_panels(style_name: String = "glass") -> void:
	for child in get_children():
		_apply_panel_style_recursive(child, style_name, 0)

func _apply_panel_style_recursive(node: Node, style_name: String, depth: int) -> void:
	if depth > 1:
		return
	if node is PanelContainer:
		_apply_panel_style(node, style_name)
	for child in node.get_children():
		_apply_panel_style_recursive(child, style_name, depth + 1)

# ── UI component factories ────────────────────────────────────────────────────

func _create_section_card(
		title: String,
		content: Control,
		description: String = "",
		icon: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_glass_card_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)

	if not icon.is_empty():
		var hdr := HBoxContainer.new()
		hdr.add_theme_constant_override("separation", SPACING_SM)
		var icon_lbl := Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		icon_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
		hdr.add_child(icon_lbl)
		var title_lbl := Label.new()
		title_lbl.text = title.to_upper()
		title_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		title_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		hdr.add_child(title_lbl)
		vbox.add_child(hdr)
	else:
		var title_lbl := Label.new()
		title_lbl.text = title.to_upper()
		title_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		title_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	panel.add_child(vbox)
	return panel

func _create_section_header(title: String, icon: String = "") -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)

	if not icon.is_empty():
		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(32, 32)
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.2)
		icon_style.set_corner_radius_all(8)
		icon_panel.add_theme_stylebox_override("panel", icon_style)
		var icon_lbl := Label.new()
		icon_lbl.text = icon
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		icon_panel.add_child(icon_lbl)
		hbox.add_child(icon_panel)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	hbox.add_child(title_lbl)
	return hbox

func _create_section_with_header(title: String, content: Control, icon: String = "") -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_create_section_header(title, icon))
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)
	return vbox

func _create_info_row(
		label: String,
		value: String,
		value_color: Color = COLOR_TEXT_PRIMARY) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	val_lbl.add_theme_color_override("font_color", value_color)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	return hbox

func _create_stat_display(stat_name: String, value) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(64, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_lbl := Label.new()
	name_lbl.text = stat_name.to_upper()
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	val_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(val_lbl)
	panel.add_child(vbox)
	return panel

func _create_stats_grid(stats: Dictionary, columns: int = 4) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_SM)
	for stat_name in stats:
		grid.add_child(_create_stat_display(stat_name, stats[stat_name]))
	return grid

func _create_stat_badge(stat_name: String, value: int, show_plus: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(80, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_INPUT.r, COLOR_INPUT.g, COLOR_INPUT.b, 0.6)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_XS)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_XS)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_lbl := Label.new()
	name_lbl.text = stat_name.to_upper()
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hbox.add_child(name_lbl)
	var val_lbl := Label.new()
	var val_text: String
	if show_plus:
		val_text = ("+" + str(value)) if value >= 0 else str(value)
	else:
		val_text = str(value)
	val_lbl.text = val_text
	val_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	val_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	hbox.add_child(val_lbl)
	panel.add_child(hbox)
	return panel

func _create_character_card(
		char_name: String,
		subtitle: String,
		stats: Dictionary = {}) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 80
	panel.add_theme_stylebox_override("panel", _create_elevated_card_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.color = COLOR_BORDER
	hbox.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = char_name
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	info.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	sub_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info.add_child(sub_lbl)

	if not stats.is_empty():
		var stats_txt := ""
		for key in stats:
			if not stats_txt.is_empty():
				stats_txt += "  "
			stats_txt += "%s:%s" % [key, stats[key]]
		var stats_lbl := Label.new()
		stats_lbl.text = stats_txt
		stats_lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		stats_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		info.add_child(stats_lbl)

	hbox.add_child(info)
	panel.add_child(hbox)
	return panel

func _create_labeled_input(label_text: String, input: Control) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_XS)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not label_text.is_empty():
		var lbl := Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		container.add_child(lbl)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.y = TOUCH_TARGET_MIN
	container.add_child(input)
	return container

func _create_add_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_TEXT_SECONDARY
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_MD)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return btn

# ── Input / button styling ────────────────────────────────────────────────────

func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	line_edit.add_theme_stylebox_override("normal", style)
	var focus_style := style.duplicate()
	focus_style.border_color = COLOR_FOCUS
	focus_style.set_border_width_all(2)
	line_edit.add_theme_stylebox_override("focus", focus_style)

func _style_option_button(option_btn: OptionButton) -> void:
	option_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	option_btn.add_theme_stylebox_override("normal", style)

func _style_button(button: Button, is_primary: bool = false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BLUE if is_primary else COLOR_TERTIARY
	style.set_corner_radius_all(8)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	var hover := style.duplicate()
	hover.bg_color = COLOR_ACCENT_HOVER if is_primary \
			else Color(COLOR_TERTIARY.r + 0.1, COLOR_TERTIARY.g + 0.1, COLOR_TERTIARY.b + 0.1)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(style.bg_color.r - 0.1, style.bg_color.g - 0.1, style.bg_color.b - 0.1)
	button.add_theme_stylebox_override("pressed", pressed)

func _style_danger_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_RED
	style.set_corner_radius_all(8)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	var hover := style.duplicate()
	hover.bg_color = Color(COLOR_RED.r + 0.1, COLOR_RED.g, COLOR_RED.b)
	button.add_theme_stylebox_override("hover", hover)
