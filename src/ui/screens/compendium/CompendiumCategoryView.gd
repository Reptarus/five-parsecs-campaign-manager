extends FiveParsecsCampaignPanel

## Responsive item list for a single compendium category.
## Shows filter tabs (with humanized labels), search within category,
## and tapping an item opens a RulesPopup detail view.
## Extends FiveParsecsCampaignPanel for responsive layout (mobile/tablet/desktop).
## Navigate here: SceneRouter.navigate_to("compendium_category", {"category_id": "weapons"})

var _provider: CompendiumDataProvider
var _category: Dictionary
var _all_items: Array[Dictionary] = []
var _filtered_items: Array[Dictionary] = []
var _active_filter: String = ""

var _title_label: Label
var _count_label: Label
var _search_input: LineEdit
var _filter_scroll: ScrollContainer
var _filter_bar: HBoxContainer
var _item_list: VBoxContainer
var _scroll: ScrollContainer
var _header_icon: TextureRect
var _header_desc: Label
var _entrance_tween: Tween

# Pre-built row styles (create once, duplicate per row)
var _style_row_even: StyleBoxFlat
var _style_row_odd: StyleBoxFlat


func _ready() -> void:
	_provider = CompendiumDataProvider.new()
	_init_row_styles()
	_load_from_context()
	# Skip super._ready() panel structure — we build our own UI.
	# Manually init responsive system + background from base class.
	_ensure_base_background()
	_setup_responsive_layout()
	_build_ui()
	_populate()


func _init_row_styles() -> void:
	# Card-style rows matching HubFeatureCard: 3px cyan left border
	_style_row_even = StyleBoxFlat.new()
	_style_row_even.bg_color = UIColors.COLOR_SECONDARY
	_style_row_even.border_color = UIColors.COLOR_CYAN
	_style_row_even.border_width_left = 3
	_style_row_even.border_width_top = 0
	_style_row_even.border_width_right = 0
	_style_row_even.border_width_bottom = 0
	_style_row_even.set_corner_radius_all(4)
	_style_row_even.content_margin_left = UIColors.SPACING_MD
	_style_row_even.content_margin_right = UIColors.SPACING_MD
	_style_row_even.content_margin_top = UIColors.SPACING_SM
	_style_row_even.content_margin_bottom = UIColors.SPACING_SM

	_style_row_odd = _style_row_even.duplicate()
	_style_row_odd.bg_color = UIColors.COLOR_SECONDARY.lerp(
		UIColors.COLOR_TERTIARY, 0.3
	)


func _load_from_context() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if not router:
		return

	var context: Dictionary = {}
	if "scene_contexts" in router:
		context = router.scene_contexts.get("compendium_category", {})

	var category_id: String = context.get("category_id", "")
	_category = _provider.get_category(category_id)
	_all_items = _provider.get_items(category_id)
	_filtered_items = _all_items.duplicate()


func _build_ui() -> void:
	# FiveParsecsCampaignPanel auto-creates __panel_bg

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.offset_left = UIColors.SPACING_XL
	outer.offset_right = -UIColors.SPACING_XL
	outer.offset_top = UIColors.SPACING_LG
	outer.offset_bottom = -UIColors.SPACING_LG
	add_child(outer)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	# Category icon (tablet+ only)
	_header_icon = TextureRect.new()
	_header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_header_icon.custom_minimum_size = Vector2(32, 32)
	_header_icon.modulate = UIColors.COLOR_CYAN
	var icon_path: String = _category.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		_header_icon.texture = load(icon_path)
	else:
		_header_icon.visible = false
	header.add_child(_header_icon)

	_title_label = Label.new()
	_title_label.text = _category.get("title", "Category")
	_title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.custom_minimum_size.x = 100
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_count_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	header.add_child(_count_label)

	# Category description + source (tablet+ only)
	_header_desc = Label.new()
	var desc: String = _category.get("description", "")
	var source: String = _category.get("source_book", "")
	if not source.is_empty():
		_header_desc.text = "%s — %s" % [desc, source] if not desc.is_empty() else source
	else:
		_header_desc.text = desc
	_header_desc.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	_header_desc.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	_header_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_header_desc)

	# Filter tabs — wrapped in ScrollContainer for mobile overflow
	_filter_scroll = ScrollContainer.new()
	_filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_filter_scroll.custom_minimum_size.y = 40
	outer.add_child(_filter_scroll)

	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", UIColors.SPACING_XS)
	_filter_scroll.add_child(_filter_bar)
	_build_filter_tabs()

	# Search within category
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Filter %s..." % _category.get("title", "items").to_lower()
	_search_input.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_search_input.clear_button_enabled = true
	var s_style := StyleBoxFlat.new()
	s_style.bg_color = UIColors.COLOR_TERTIARY
	s_style.border_color = UIColors.COLOR_BORDER
	s_style.set_border_width_all(1)
	s_style.set_corner_radius_all(4)
	s_style.content_margin_left = UIColors.SPACING_MD
	s_style.content_margin_right = UIColors.SPACING_MD
	_search_input.add_theme_stylebox_override("normal", s_style)
	_search_input.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_search_input.add_theme_color_override("font_placeholder_color", UIColors.COLOR_TEXT_MUTED)
	_search_input.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	_search_input.text_changed.connect(_on_filter_text_changed)
	outer.add_child(_search_input)

	# Item list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	outer.add_child(_scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_item_list)

	# Apply responsive layout
	_apply_responsive_visibility()


func _build_filter_tabs() -> void:
	var filter_field: String = _category.get("filter_field", "")
	if filter_field.is_empty():
		_filter_scroll.visible = false
		return

	# Collect unique filter values
	var values: Array[String] = []
	for item: Dictionary in _all_items:
		var val: String = str(item.get(filter_field, ""))
		if not val.is_empty() and val not in values:
			values.append(val)
	values.sort()

	if values.size() < 2:
		_filter_scroll.visible = false
		return

	# "All" tab
	var all_btn := _create_filter_button("All", "")
	_filter_bar.add_child(all_btn)

	for val: String in values:
		# Humanize display label: "weapon_trait" → "Weapon Trait"
		var display_label: String = val.replace("_", " ").capitalize()
		var btn := _create_filter_button(display_label, val)
		_filter_bar.add_child(btn)


func _create_filter_button(label_text: String, filter_value: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size.y = 36
	btn.toggle_mode = true
	btn.button_pressed = (filter_value == _active_filter)
	btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	# Store raw filter value as metadata (display text may differ from value)
	btn.set_meta("filter_value", filter_value)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_active_filter = filter_value
			_apply_filters()
			_update_filter_button_states()
	)
	return btn


func _update_filter_button_states() -> void:
	for child: Node in _filter_bar.get_children():
		if child is Button:
			var btn_filter: String = child.get_meta("filter_value", "")
			child.button_pressed = (btn_filter == _active_filter)


func _apply_filters() -> void:
	var filter_field: String = _category.get("filter_field", "")
	var search_text := _search_input.text.strip_edges().to_lower()

	_filtered_items.clear()
	for item: Dictionary in _all_items:
		# Filter by subcategory
		if not _active_filter.is_empty() and not filter_field.is_empty():
			if str(item.get(filter_field, "")) != _active_filter:
				continue
		# Filter by search text
		if not search_text.is_empty():
			var name_str: String = str(item.get("name", item.get("term", ""))).to_lower()
			var desc_str: String = str(item.get("description", "")).to_lower()
			if not name_str.contains(search_text) and not desc_str.contains(search_text):
				continue
		_filtered_items.append(item)

	_populate_item_list()


func _on_filter_text_changed(_new_text: String) -> void:
	_apply_filters()


func _populate() -> void:
	_filtered_items = _all_items.duplicate()
	_populate_item_list()


func _populate_item_list() -> void:
	# Kill any running entrance animation
	if _entrance_tween:
		_entrance_tween.kill()
		_entrance_tween = null

	for child in _item_list.get_children():
		child.queue_free()

	_count_label.text = "%d items" % _filtered_items.size()

	if _filtered_items.is_empty():
		var empty := EmptyStateWidget.new()
		empty.setup(
			"No Items Found",
			"Try adjusting your filters or search terms.",
			"Clear Filters",
			func() -> void:
				_active_filter = ""
				_search_input.text = ""
				_update_filter_button_states()
				_apply_filters()
		)
		_item_list.add_child(empty)
		return

	var filter_field: String = _category.get("filter_field", "")
	var use_sections: bool = _active_filter.is_empty() and not filter_field.is_empty()
	var current_section: String = ""
	var is_mobile: bool = should_use_single_column()

	# Sort by filter field first for proper grouping, then by name
	if use_sections:
		_filtered_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_group: String = str(a.get(filter_field, ""))
			var b_group: String = str(b.get(filter_field, ""))
			if a_group != b_group:
				return a_group.naturalcasecmp_to(b_group) < 0
			var a_name: String = str(a.get("name", a.get("term", "")))
			var b_name: String = str(b.get("name", b.get("term", "")))
			return a_name.naturalcasecmp_to(b_name) < 0
		)

	for i: int in _filtered_items.size():
		var item: Dictionary = _filtered_items[i]

		# Section headers when showing all items unfiltered
		if use_sections:
			var section_val: String = str(item.get(filter_field, ""))
			if section_val != current_section:
				current_section = section_val
				var section_header := _create_group_header(current_section)
				_item_list.add_child(section_header)

		var row: PanelContainer
		if is_mobile:
			row = _create_compact_item_row(item, i)
		else:
			row = _create_rich_item_row(item, i)
		_item_list.add_child(row)

	# Staggered entrance animations
	_animate_rows_entrance()


func _create_group_header(section_text: String) -> HBoxContainer:
	## Section header with label + separator line
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	row.custom_minimum_size.y = UIColors.SPACING_LG

	var label := Label.new()
	label.text = section_text.replace("_", " ").to_upper()
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(label)

	var sep := HSeparator.new()
	sep.size_flags_horizontal = SIZE_EXPAND_FILL
	sep.modulate = UIColors.COLOR_BORDER
	row.add_child(sep)

	return row


func _create_rich_item_row(item: Dictionary, index: int) -> PanelContainer:
	## Card-style item row matching HubFeatureCard: cyan left border, icon, hover
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = (
		_style_row_even if index % 2 == 0 else _style_row_odd
	).duplicate()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = UIColors.TOUCH_TARGET_COMFORT
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColors.SPACING_MD)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# Type icon (24x24, cyan modulate)
	var type_val: String = str(item.get("type", item.get("category", "")))
	var cat_id: String = _category.get("id", "")
	var icon_path: String = CompendiumDataProvider.get_type_icon_path(
		cat_id, type_val
	)
	# Fallback to category icon
	if icon_path.is_empty():
		icon_path = _category.get("icon_path", "")

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = UIColors.COLOR_CYAN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	# Text column (two lines)
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	# Line 1: Name + Type badge
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = str(
		item.get("name", item.get("term", item.get("type", "Unknown")))
	)
	name_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	name_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)

	if not type_val.is_empty():
		var badge := _create_type_badge(type_val)
		name_row.add_child(badge)

	# Line 2: Stat preview
	var display_fields: Array = _category.get("display_fields", ["name"])
	var stat_text: String = CompendiumDataProvider.build_stat_preview(
		item, display_fields
	)
	if not stat_text.is_empty():
		var stat_label := Label.new()
		stat_label.text = stat_text
		stat_label.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_XS
		)
		stat_label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(stat_label)

	# Preview button (desktop+ only)
	if current_layout_mode in [LayoutMode.DESKTOP, LayoutMode.WIDE]:
		var preview_btn := PreviewButton.new()
		preview_btn.set_preview_data(item)
		hbox.add_child(preview_btn)

	# Hover effect (matching HubFeatureCard)
	var row_index: int = index
	panel.mouse_entered.connect(func() -> void:
		var hover_s: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		hover_s.border_color = UIColors.COLOR_ACCENT_HOVER
		hover_s.bg_color = UIColors.COLOR_TERTIARY
		panel.add_theme_stylebox_override("panel", hover_s)
	)
	panel.mouse_exited.connect(func() -> void:
		var base_s: StyleBoxFlat = (
			_style_row_even if row_index % 2 == 0 else _style_row_odd
		).duplicate()
		panel.add_theme_stylebox_override("panel", base_s)
	)

	# Click handler with press feedback
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				TweenFX.press(panel, 0.15)
				_show_item_detail(item)
	)

	return panel


func _create_compact_item_row(item: Dictionary, index: int) -> PanelContainer:
	## Compact card-style row for mobile: icon + name + type badge + arrow
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = (
		_style_row_even if index % 2 == 0 else _style_row_odd
	).duplicate()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = UIColors.TOUCH_TARGET_COMFORT
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# Type icon (20x20, cyan)
	var type_val: String = str(item.get("type", item.get("category", "")))
	var cat_id: String = _category.get("id", "")
	var icon_path: String = CompendiumDataProvider.get_type_icon_path(
		cat_id, type_val
	)
	if icon_path.is_empty():
		icon_path = _category.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		icon.modulate = UIColors.COLOR_CYAN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = str(item.get("name", item.get("term", item.get("type", "Unknown"))))
	name_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	# Compact type badge
	if not type_val.is_empty():
		var badge := _create_type_badge(type_val)
		hbox.add_child(badge)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow)

	# Hover effect
	var row_index: int = index
	panel.mouse_entered.connect(func() -> void:
		var hover_s: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		hover_s.border_color = UIColors.COLOR_ACCENT_HOVER
		hover_s.bg_color = UIColors.COLOR_TERTIARY
		panel.add_theme_stylebox_override("panel", hover_s)
	)
	panel.mouse_exited.connect(func() -> void:
		var base_s: StyleBoxFlat = (
			_style_row_even if row_index % 2 == 0 else _style_row_odd
		).duplicate()
		panel.add_theme_stylebox_override("panel", base_s)
	)

	# Click handler with press feedback
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				TweenFX.press(panel, 0.15)
				_show_item_detail(item)
	)

	return panel


func _create_type_badge(type_text: String) -> PanelContainer:
	## Colored pill badge for item type
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = _get_type_color(type_text).darkened(0.6)
	badge_style.set_corner_radius_all(8)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 1
	badge_style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = type_text
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	label.add_theme_color_override("font_color", _get_type_color(type_text))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)

	return badge


func _get_type_color(type_str: String) -> Color:
	match type_str.to_lower():
		"energy": return UIColors.COLOR_CYAN
		"slug": return UIColors.COLOR_TEXT_SECONDARY
		"melee": return UIColors.COLOR_RED
		"grenade", "special": return UIColors.COLOR_AMBER
		"consumable": return UIColors.COLOR_EMERALD
		"utility device": return UIColors.COLOR_BLUE
		"armor": return UIColors.COLOR_BLUE
		"screen": return UIColors.COLOR_PURPLE
		_: return UIColors.COLOR_TEXT_MUTED


func _animate_rows_entrance() -> void:
	var children: Array[Node] = []
	for child: Node in _item_list.get_children():
		if child is Control:
			children.append(child)

	var cap: int = mini(children.size(), 15)
	for i: int in cap:
		var child: Control = children[i] as Control
		child.modulate.a = 0
		get_tree().create_timer(i * 0.03).timeout.connect(func() -> void:
			if is_instance_valid(child):
				TweenFX.fade_in(child, 0.2)
		)
	# Items beyond cap appear immediately
	for i: int in range(cap, children.size()):
		(children[i] as Control).modulate.a = 1.0


func _apply_responsive_visibility() -> void:
	## Show/hide elements based on current layout mode
	if not _header_icon or not _header_desc:
		return
	var is_mobile: bool = should_use_single_column()
	_header_icon.visible = not is_mobile and _header_icon.texture != null
	_header_desc.visible = not is_mobile


func _update_layout_for_mode() -> void:
	## Override from FiveParsecsCampaignPanel — update on breakpoint change
	super._update_layout_for_mode()
	if not _item_list:
		return
	_apply_responsive_visibility()
	# Repopulate with new row style (compact vs rich)
	if _item_list.get_child_count() > 0:
		_populate_item_list()


func _show_item_detail(item: Dictionary) -> void:
	var title_text: String = str(item.get("name", item.get("term", "Unknown")))
	var body := _build_detail_body(item)
	RulesPopup.show_rules(self, title_text, body)


func _build_detail_body(item: Dictionary) -> String:
	var cat_id: String = _category.get("id", "")
	match cat_id:
		"weapons":
			return _build_weapon_detail(item)
		"enemies", "bug_hunt_enemies":
			return _build_enemy_detail(item)
		"species":
			return _build_species_detail(item)
		"keywords":
			return _build_keyword_detail(item)
		_:
			return _build_generic_detail(item)


func _fmt_val(val: Variant) -> String:
	## Format a value for display — strip trailing .0 from floats
	var s := str(val)
	if s.ends_with(".0"):
		return s.substr(0, s.length() - 2)
	return s


func _build_weapon_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []
	if item.has("description"):
		parts.append(str(item["description"]))
		parts.append("")

	parts.append("[color=#06b6d4]Type:[/color] %s" % _fmt_val(item.get("type", "—")))
	parts.append(
		"[color=#06b6d4]Range:[/color] %s\"  " % _fmt_val(item.get("range", "—"))
		+ "[color=#06b6d4]Shots:[/color] %s  " % _fmt_val(item.get("shots", "—"))
		+ "[color=#06b6d4]Damage:[/color] +%s" % _fmt_val(item.get("damage", "0"))
	)

	if item.has("traits") and item["traits"] is Array and not item["traits"].is_empty():
		var traits_text := ", ".join(PackedStringArray(item["traits"]))
		traits_text = _link_keywords(traits_text)
		parts.append("")
		parts.append("[color=#06b6d4]Traits:[/color] %s" % traits_text)

	if item.has("cost"):
		parts.append("")
		parts.append(
			"[color=#9ca3af]Cost: %s cr  |  Rarity: %s[/color]"
			% [_fmt_val(item.get("cost", "—")), str(item.get("rarity", "—"))]
		)
	return "\n".join(parts)


func _build_enemy_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []

	if item.has("_category_name"):
		parts.append("[color=#06b6d4]%s[/color]" % str(item["_category_name"]))
		parts.append("")

	parts.append(
		"[color=#06b6d4]Numbers:[/color] %s  " % _fmt_val(item.get("numbers", "—"))
		+ "[color=#06b6d4]Panic:[/color] %s" % _fmt_val(item.get("panic", "—"))
	)
	parts.append(
		"[color=#06b6d4]Speed:[/color] %s\"  " % _fmt_val(item.get("speed", "—"))
		+ "[color=#06b6d4]Combat Skill:[/color] +%s  " % _fmt_val(item.get("combat_skill", "0"))
		+ "[color=#06b6d4]Toughness:[/color] %s" % _fmt_val(item.get("toughness", "—"))
	)
	parts.append(
		"[color=#06b6d4]AI:[/color] %s  " % str(item.get("ai", "—"))
		+ "[color=#06b6d4]Weapons:[/color] %s" % str(item.get("weapons", "—"))
	)

	if item.has("special_rules") and item["special_rules"] is Array:
		parts.append("")
		parts.append("[color=#06b6d4]Special Rules:[/color]")
		for rule: Variant in item["special_rules"]:
			parts.append("  • %s" % str(rule))

	return "\n".join(parts)


func _build_species_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []

	if item.has("base_stats") and item["base_stats"] is Dictionary:
		var s: Dictionary = item["base_stats"]
		parts.append("[color=#06b6d4]Base Profile:[/color]")
		parts.append(
			"  Reactions: %s  |  Speed: %s\""
			% [_fmt_val(s.get("reactions", "—")), _fmt_val(s.get("speed", "—"))]
		)
		parts.append(
			"  Combat Skill: +%s  |  Toughness: %s  |  Savvy: +%s"
			% [_fmt_val(s.get("combat_skill", "0")), _fmt_val(s.get("toughness", "—")), _fmt_val(s.get("savvy", "0"))]
		)

	if item.has("special_rules") and item["special_rules"] is Array:
		parts.append("")
		parts.append("[color=#06b6d4]Special Rules:[/color]")
		for rule: Variant in item["special_rules"]:
			parts.append("  • %s" % str(rule))

	if item.has("page_reference"):
		parts.append("")
		parts.append("[color=#9ca3af]%s[/color]" % _fmt_val(item["page_reference"]))

	return "\n".join(parts)


func _build_keyword_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []

	if item.has("definition"):
		parts.append(str(item["definition"]))

	if item.has("category"):
		parts.append("")
		parts.append(
			"[color=#9ca3af]Category: %s[/color]"
			% str(item["category"]).capitalize().replace("_", " ")
		)

	if item.has("related") and item["related"] is Array and not item["related"].is_empty():
		parts.append("")
		var related := ", ".join(PackedStringArray(item["related"]))
		parts.append("[color=#06b6d4]Related:[/color] %s" % related)

	if item.has("rule_page"):
		parts.append("")
		parts.append("[color=#9ca3af]Core Rules p.%s[/color]" % _fmt_val(item["rule_page"]))

	return "\n".join(parts)


func _build_generic_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []
	var detail_fields: Array = _category.get("detail_fields", [])

	for field: String in detail_fields:
		if field.begins_with("_"):
			continue
		var val: Variant = item.get(field, "")
		if val is Array:
			if not val.is_empty():
				parts.append("[color=#06b6d4]%s:[/color]" % field.capitalize().replace("_", " "))
				for entry: Variant in val:
					parts.append("  • %s" % str(entry))
		elif val is Dictionary:
			parts.append("[color=#06b6d4]%s:[/color]" % field.capitalize().replace("_", " "))
			for key: String in val:
				parts.append("  %s: %s" % [key.capitalize(), str(val[key])])
		elif str(val) != "":
			var label := field.capitalize().replace("_", " ")
			parts.append("[color=#06b6d4]%s:[/color] %s" % [label, _fmt_val(val)])
		parts.append("")

	return "\n".join(parts)


func _link_keywords(text: String) -> String:
	var keyword_db = Engine.get_main_loop().root.get_node_or_null(
		"/root/KeywordDB"
	) if Engine.get_main_loop() else null
	if keyword_db and keyword_db.has_method("parse_text_for_keywords"):
		return keyword_db.parse_text_for_keywords(text)
	return text


func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("go_back"):
		router.go_back()
	elif router and router.has_method("navigate_to"):
		router.navigate_to("compendium")
