extends Control

## Compendium hub screen — category grid with global search bar.
## Each category displayed as a HubFeatureCard with game-icons.net SVG icon.
## Search debounces 300ms and shows flat result list across all categories.

const MAX_FORM_WIDTH := 800

var _provider: CompendiumDataProvider
var _search_input: LineEdit
var _results_label: Label
var _content_container: VBoxContainer
var _category_container: VBoxContainer
var _search_results_container: VBoxContainer
var _search_timer: Timer
var _is_searching := false


func _ready() -> void:
	_provider = CompendiumDataProvider.new()
	_build_ui()
	_show_categories()


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

	var title := Label.new()
	title.text = "Compendium"
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	var count_label := Label.new()
	count_label.text = "%d items" % _provider.get_total_item_count()
	count_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	count_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	header.add_child(count_label)

	# Search bar
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search weapons, enemies, species..."
	_search_input.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_search_input.clear_button_enabled = true
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = UIColors.COLOR_TERTIARY
	search_style.border_color = UIColors.COLOR_BORDER
	search_style.set_border_width_all(1)
	search_style.set_corner_radius_all(4)
	search_style.content_margin_left = UIColors.SPACING_MD
	search_style.content_margin_right = UIColors.SPACING_MD
	_search_input.add_theme_stylebox_override("normal", search_style)
	_search_input.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_search_input.add_theme_color_override("font_placeholder_color", UIColors.COLOR_TEXT_MUTED)
	_search_input.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	_search_input.text_changed.connect(_on_search_text_changed)
	outer.add_child(_search_input)

	# Search results label (hidden until searching)
	_results_label = Label.new()
	_results_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_results_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	_results_label.visible = false
	outer.add_child(_results_label)

	# Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	outer.add_child(scroll)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", UIColors.SPACING_SM)
	scroll.add_child(_content_container)

	# Category cards container
	_category_container = VBoxContainer.new()
	_category_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_category_container.add_theme_constant_override("separation", UIColors.SPACING_SM)
	_content_container.add_child(_category_container)

	# Search results container (hidden until searching)
	_search_results_container = VBoxContainer.new()
	_search_results_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_results_container.add_theme_constant_override("separation", UIColors.SPACING_XS)
	_search_results_container.visible = false
	_content_container.add_child(_search_results_container)

	# Source footer
	var footer := Label.new()
	footer.text = "Source: Five Parsecs From Home Core Rules & Compendium"
	footer.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	footer.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(footer)

	# Debounce timer
	_search_timer = Timer.new()
	_search_timer.wait_time = 0.3
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_execute_search)
	add_child(_search_timer)


func _show_categories() -> void:
	for child in _category_container.get_children():
		child.queue_free()

	for cat: Dictionary in _provider.get_categories():
		var card := HubFeatureCard.new()
		_category_container.add_child(card)

		var icon_path: String = cat.get("icon_path", "")
		var cat_title: String = cat.get("title", "")
		var cat_desc: String = cat.get("description", "")
		var item_count := _provider.get_items(cat.get("id", "")).size()
		var desc_with_count := "%s (%d)" % [cat_desc, item_count]

		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var tex: Texture2D = load(icon_path)
			card.setup_with_icon(tex, cat_title, desc_with_count)
		else:
			card.setup("📖", cat_title, desc_with_count)

		var cat_id: String = cat.get("id", "")
		card.card_pressed.connect(_on_category_pressed.bind(cat_id))


func _on_search_text_changed(new_text: String) -> void:
	if new_text.length() < 2:
		_exit_search_mode()
		return
	_search_timer.start()


func _execute_search() -> void:
	var query := _search_input.text.strip_edges()
	if query.length() < 2:
		_exit_search_mode()
		return

	var results := _provider.search(query)
	_enter_search_mode(query, results)


func _enter_search_mode(query: String, results: Array[Dictionary]) -> void:
	_is_searching = true
	_category_container.visible = false
	_search_results_container.visible = true
	_results_label.visible = true
	_results_label.text = "%d results for \"%s\"" % [results.size(), query]

	for child in _search_results_container.get_children():
		child.queue_free()

	if results.is_empty():
		var empty := Label.new()
		empty.text = "No items found. Try a different search term."
		empty.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
		empty.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_search_results_container.add_child(empty)
		return

	for item: Dictionary in results:
		var row := _create_search_result_row(item)
		_search_results_container.add_child(row)


func _exit_search_mode() -> void:
	_is_searching = false
	_category_container.visible = true
	_search_results_container.visible = false
	_results_label.visible = false


func _create_search_result_row(item: Dictionary) -> PanelContainer:
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

	# Item name
	var name_label := Label.new()
	name_label.text = str(item.get("name", item.get("term", "Unknown")))
	name_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	# Category badge
	var badge := Label.new()
	badge.text = str(item.get("_category_title", ""))
	badge.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
	badge.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(badge)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow)

	# Click handler
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_item_detail(item)
	)

	return panel


func _show_item_detail(item: Dictionary) -> void:
	var title_text: String = str(item.get("name", item.get("term", "Unknown")))
	var body := _build_detail_body(item)
	RulesPopup.show_rules(self, title_text, body)


func _build_detail_body(item: Dictionary) -> String:
	var parts: PackedStringArray = []

	if item.has("description"):
		parts.append(str(item["description"]))
		parts.append("")

	# Stats line
	var stat_parts: PackedStringArray = []
	for key: String in ["type", "range", "shots", "damage", "saving_throw", "speed", "combat_skill", "toughness", "ai", "panic", "numbers"]:
		if item.has(key) and str(item[key]) != "":
			var label := key.capitalize().replace("_", " ")
			stat_parts.append("[color=#06b6d4]%s:[/color] %s" % [label, str(item[key])])
	if not stat_parts.is_empty():
		parts.append("  ".join(stat_parts))
		parts.append("")

	# Traits
	if item.has("traits") and item["traits"] is Array and not item["traits"].is_empty():
		var trait_strs: PackedStringArray = []
		for t: Variant in item["traits"]:
			trait_strs.append(str(t))
		var keyword_db := Engine.get_main_loop().root.get_node_or_null("/root/KeywordDB") if Engine.get_main_loop() else null
		var traits_text := ", ".join(trait_strs)
		if keyword_db and keyword_db.has_method("parse_text_for_keywords"):
			traits_text = keyword_db.parse_text_for_keywords(traits_text)
		parts.append("[color=#06b6d4]Traits:[/color] %s" % traits_text)
		parts.append("")

	# Special rules
	if item.has("special_rules") and item["special_rules"] is Array:
		parts.append("[color=#06b6d4]Special Rules:[/color]")
		for rule: Variant in item["special_rules"]:
			parts.append("  • %s" % str(rule))
		parts.append("")

	# Base stats (for species)
	if item.has("base_stats") and item["base_stats"] is Dictionary:
		parts.append("[color=#06b6d4]Base Stats:[/color]")
		var stats: Dictionary = item["base_stats"]
		for key: String in stats:
			parts.append("  %s: %s" % [key.capitalize().replace("_", " "), str(stats[key])])
		parts.append("")

	# Category
	if item.has("_category_name"):
		parts.append("[color=#9ca3af]Category: %s[/color]" % str(item["_category_name"]))

	# Source
	if item.has("page_reference"):
		parts.append("[color=#9ca3af]%s[/color]" % str(item["page_reference"]))

	return "\n".join(parts)


func _on_category_pressed(category_id: String) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("compendium_category", {"category_id": category_id})


func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("go_back"):
		router.go_back()
	elif router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")
