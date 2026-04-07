extends Control

## Flat item list for a single compendium category.
## Shows filter tabs (if category has subtypes), search within category,
## and tapping an item opens a RulesPopup detail view.
## Navigate here with: SceneRouter.navigate_to("compendium_category", {"category_id": "weapons"})

const MAX_FORM_WIDTH := 800

var _provider: CompendiumDataProvider
var _category: Dictionary
var _all_items: Array[Dictionary] = []
var _filtered_items: Array[Dictionary] = []
var _active_filter: String = ""

var _title_label: Label
var _count_label: Label
var _search_input: LineEdit
var _filter_bar: HBoxContainer
var _item_list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_provider = CompendiumDataProvider.new()
	_load_from_context()
	_build_ui()
	_populate()


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
	var bg := ColorRect.new()
	bg.color = UIColors.COLOR_PRIMARY
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.offset_left = UIColors.SPACING_XL
	outer.offset_right = -UIColors.SPACING_XL
	outer.offset_top = UIColors.SPACING_LG
	outer.offset_bottom = -UIColors.SPACING_LG
	add_child(outer)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	_title_label = Label.new()
	_title_label.text = _category.get("title", "Category")
	_title_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_XL
	)
	_title_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM
	)
	_count_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	header.add_child(_count_label)

	# Source book label
	var source: String = _category.get("source_book", "")
	if not source.is_empty():
		var source_label := Label.new()
		source_label.text = source
		source_label.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_XS
		)
		source_label.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_MUTED
		)
		outer.add_child(source_label)

	# Filter tabs (only if category has filter_field)
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", UIColors.SPACING_XS)
	outer.add_child(_filter_bar)
	_build_filter_tabs()

	# Search within category
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Filter %s..." % _category.get(
		"title", "items"
	).to_lower()
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
	_search_input.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	_search_input.add_theme_color_override(
		"font_placeholder_color", UIColors.COLOR_TEXT_MUTED
	)
	_search_input.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_MD
	)
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


func _build_filter_tabs() -> void:
	var filter_field: String = _category.get("filter_field", "")
	if filter_field.is_empty():
		_filter_bar.visible = false
		return

	# Collect unique filter values
	var values: Array[String] = []
	for item: Dictionary in _all_items:
		var val: String = str(item.get(filter_field, ""))
		if not val.is_empty() and val not in values:
			values.append(val)
	values.sort()

	if values.size() < 2:
		_filter_bar.visible = false
		return

	# "All" tab
	var all_btn := _create_filter_button("All", "")
	_filter_bar.add_child(all_btn)

	for val: String in values:
		var btn := _create_filter_button(val, val)
		_filter_bar.add_child(btn)


func _create_filter_button(
	label_text: String, filter_value: String
) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size.y = 36
	btn.toggle_mode = true
	btn.button_pressed = (filter_value == _active_filter)
	btn.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	btn.toggled.connect(func(pressed: bool):
		if pressed:
			_active_filter = filter_value
			_apply_filters()
			_update_filter_button_states()
	)
	return btn


func _update_filter_button_states() -> void:
	for child: Node in _filter_bar.get_children():
		if child is Button:
			var is_all := child.text == "All"
			var matches := (
				(is_all and _active_filter.is_empty())
				or (not is_all and child.text == _active_filter)
			)
			child.button_pressed = matches


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
			var name_str: String = str(
				item.get("name", item.get("term", ""))
			).to_lower()
			var desc_str: String = str(
				item.get("description", "")
			).to_lower()
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
	for child in _item_list.get_children():
		child.queue_free()

	_count_label.text = "%d items" % _filtered_items.size()

	if _filtered_items.is_empty():
		var empty := Label.new()
		empty.text = "No items match your filter."
		empty.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_MD
		)
		empty.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_SECONDARY
		)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_list.add_child(empty)
		return

	var display_fields: Array = _category.get("display_fields", ["name"])
	var cat_id: String = _category.get("id", "")

	for item: Dictionary in _filtered_items:
		var row := _create_item_row(item, display_fields, cat_id)
		_item_list.add_child(row)


func _create_item_row(
	item: Dictionary,
	display_fields: Array,
	cat_id: String,
) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.set_corner_radius_all(4)
	style.content_margin_left = UIColors.SPACING_MD
	style.content_margin_right = UIColors.SPACING_MD
	style.content_margin_top = UIColors.SPACING_SM
	style.content_margin_bottom = UIColors.SPACING_SM
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# Name (always first, expands)
	var name_label := Label.new()
	name_label.text = str(
		item.get("name", item.get("term", item.get("type", "Unknown")))
	)
	name_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_MD
	)
	name_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	# Stat badges from display_fields (skip "name")
	for field: String in display_fields:
		if field == "name" or field == "term":
			continue
		var val: Variant = item.get(field, "")
		if val is Array:
			continue  # Skip arrays in compact view
		var val_str := str(val)
		if val_str.is_empty() or val_str == "0":
			continue

		var badge := _create_stat_badge(field, val_str)
		hbox.add_child(badge)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_MUTED
	)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow)

	# Click handler
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_item_detail(item)
	)

	return panel


func _create_stat_badge(field: String, value: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_TERTIARY
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	# Short field labels for compact display
	var short_label := _abbreviate_field(field)
	label.text = "%s:%s" % [short_label, value]
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)

	return badge


func _abbreviate_field(field: String) -> String:
	match field:
		"range": return "R"
		"shots": return "S"
		"damage": return "D"
		"combat_skill": return "CS"
		"toughness": return "T"
		"speed": return "Spd"
		"saving_throw": return "Sv"
		"ai": return "AI"
		"panic": return "Pnc"
		"numbers": return "Num"
		"type": return ""
		"category": return ""
		_: return field.substr(0, 3).capitalize()


func _show_item_detail(item: Dictionary) -> void:
	var title_text: String = str(
		item.get("name", item.get("term", "Unknown"))
	)
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


func _build_weapon_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []
	if item.has("description"):
		parts.append(str(item["description"]))
		parts.append("")

	parts.append(
		"[color=#06b6d4]Type:[/color] %s" % str(item.get("type", "—"))
	)
	parts.append(
		"[color=#06b6d4]Range:[/color] %s\"  "
		% str(item.get("range", "—"))
		+ "[color=#06b6d4]Shots:[/color] %s  "
		% str(item.get("shots", "—"))
		+ "[color=#06b6d4]Damage:[/color] +%s"
		% str(item.get("damage", "0"))
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
			% [str(item.get("cost", "—")), str(item.get("rarity", "—"))]
		)
	return "\n".join(parts)


func _build_enemy_detail(item: Dictionary) -> String:
	var parts: PackedStringArray = []

	if item.has("_category_name"):
		parts.append(
			"[color=#9ca3af]%s[/color]" % str(item["_category_name"])
		)
		parts.append("")

	parts.append(
		"[color=#06b6d4]Numbers:[/color] %s  "
		% str(item.get("numbers", "—"))
		+ "[color=#06b6d4]Panic:[/color] %s"
		% str(item.get("panic", "—"))
	)
	parts.append(
		"[color=#06b6d4]Speed:[/color] %s\"  "
		% str(item.get("speed", "—"))
		+ "[color=#06b6d4]Combat Skill:[/color] +%s  "
		% str(item.get("combat_skill", "0"))
		+ "[color=#06b6d4]Toughness:[/color] %s"
		% str(item.get("toughness", "—"))
	)
	parts.append(
		"[color=#06b6d4]AI:[/color] %s  "
		% str(item.get("ai", "—"))
		+ "[color=#06b6d4]Weapons:[/color] %s"
		% str(item.get("weapons", "—"))
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
			% [str(s.get("reactions", "—")), str(s.get("speed", "—"))]
		)
		parts.append(
			"  Combat Skill: +%s  |  Toughness: %s  |  Savvy: +%s"
			% [
				str(s.get("combat_skill", "0")),
				str(s.get("toughness", "—")),
				str(s.get("savvy", "0"))
			]
		)

	if item.has("special_rules") and item["special_rules"] is Array:
		parts.append("")
		parts.append("[color=#06b6d4]Special Rules:[/color]")
		for rule: Variant in item["special_rules"]:
			parts.append("  • %s" % str(rule))

	if item.has("page_reference"):
		parts.append("")
		parts.append(
			"[color=#9ca3af]%s[/color]" % str(item["page_reference"])
		)

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
		parts.append(
			"[color=#9ca3af]Core Rules p.%s[/color]"
			% str(item["rule_page"])
		)

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
				parts.append(
					"[color=#06b6d4]%s:[/color]"
					% field.capitalize().replace("_", " ")
				)
				for entry: Variant in val:
					if entry is Dictionary:
						parts.append("  • %s" % str(entry))
					else:
						parts.append("  • %s" % str(entry))
		elif val is Dictionary:
			parts.append(
				"[color=#06b6d4]%s:[/color]"
				% field.capitalize().replace("_", " ")
			)
			for key: String in val:
				parts.append("  %s: %s" % [key.capitalize(), str(val[key])])
		elif str(val) != "":
			var label := field.capitalize().replace("_", " ")
			parts.append(
				"[color=#06b6d4]%s:[/color] %s" % [label, str(val)]
			)
		parts.append("")

	return "\n".join(parts)


func _link_keywords(text: String) -> String:
	var keyword_db := Engine.get_main_loop().root.get_node_or_null(
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
