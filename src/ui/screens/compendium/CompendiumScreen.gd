extends FiveParsecsCampaignPanel

## Library hub screen — responsive category grid with global search bar.
## Each category displayed as a HubFeatureCard with game-icons.net SVG icon.
## Search debounces 300ms and shows flat result list across all categories.
## Extends FiveParsecsCampaignPanel for responsive layout (mobile/tablet/desktop).

var _provider: CompendiumDataProvider
var _search_input: LineEdit
var _results_label: Label
var _category_container: HFlowContainer
var _search_results_container: VBoxContainer
var _search_timer: Timer
var _is_searching := false
var _entrance_tween: Tween


func _ready() -> void:
	_provider = CompendiumDataProvider.new()
	# Skip super._ready() panel structure — we build our own UI.
	# Manually init responsive system + background from base class.
	_ensure_base_background()
	_setup_responsive_layout()
	_build_ui()
	_show_categories()


func _build_ui() -> void:
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
	title.text = "Library"
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	var count_label := Label.new()
	count_label.text = "%d items" % _provider.get_total_item_count()
	count_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	count_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	count_label.custom_minimum_size.x = 120
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	scroll.add_child(content_vbox)

	# Category cards container — HFlowContainer for responsive grid
	_category_container = HFlowContainer.new()
	_category_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_category_container.add_theme_constant_override("h_separation", UIColors.SPACING_SM)
	_category_container.add_theme_constant_override("v_separation", UIColors.SPACING_SM)
	content_vbox.add_child(_category_container)

	# Search results container (hidden until searching)
	_search_results_container = VBoxContainer.new()
	_search_results_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_results_container.add_theme_constant_override("separation", UIColors.SPACING_XS)
	_search_results_container.visible = false
	content_vbox.add_child(_search_results_container)

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

	# Apply responsive sizing for current layout mode
	_update_card_sizes()

	# Entrance animations deferred so nodes are fully in tree
	call_deferred("_animate_cards_entrance")


func _animate_cards_entrance() -> void:
	if _entrance_tween:
		_entrance_tween.kill()
		_entrance_tween = null

	var controls: Array[Control] = []
	for child: Node in _category_container.get_children():
		if child is Control:
			controls.append(child as Control)

	if controls.is_empty():
		return

	# Set all invisible first
	for ctrl: Control in controls:
		ctrl.modulate.a = 0.0

	# Use a single sequential tween for staggered reveal
	_entrance_tween = create_tween()
	for i: int in controls.size():
		var ctrl: Control = controls[i]
		_entrance_tween.tween_callback(func() -> void:
			if is_instance_valid(ctrl):
				ctrl.modulate.a = 1.0
				TweenFX.pop_in(ctrl, 0.25)
		)
		_entrance_tween.tween_interval(0.06)


func _update_card_sizes() -> void:
	## Adjust card minimum width based on current layout mode for responsive grid
	if not _category_container:
		return
	var card_min_width: float = 0.0
	match current_layout_mode:
		LayoutMode.MOBILE:
			card_min_width = 0  # Full width
		LayoutMode.TABLET:
			card_min_width = 340
		LayoutMode.DESKTOP, LayoutMode.WIDE:
			card_min_width = 400
	for child: Node in _category_container.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = card_min_width


func _update_layout_for_mode() -> void:
	## Override from FiveParsecsCampaignPanel — update layout on breakpoint change
	super._update_layout_for_mode()
	_update_card_sizes()


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
		var empty := EmptyStateWidget.new()
		empty.setup("No Results", "No items found matching \"%s\".\nTry a different search term." % query)
		_search_results_container.add_child(empty)
		return

	for i: int in results.size():
		var row := _create_search_result_row(results[i], i)
		_search_results_container.add_child(row)


func _exit_search_mode() -> void:
	_is_searching = false
	_category_container.visible = true
	_search_results_container.visible = false
	_results_label.visible = false


func _create_search_result_row(item: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Alternating row tints
	if index % 2 == 0:
		style.bg_color = UIColors.COLOR_SECONDARY
	else:
		style.bg_color = UIColors.COLOR_SECONDARY.lerp(UIColors.COLOR_TERTIARY, 0.3)
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

	# Two-line layout: name + stats preview
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	# Line 1: Item name
	var name_label := Label.new()
	name_label.text = str(item.get("name", item.get("term", "Unknown")))
	name_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(name_label)

	# Line 2: Stat preview (if available)
	var cat_id: String = str(item.get("_category_id", ""))
	var cat_config: Dictionary = _provider.get_category(cat_id)
	var display_fields: Array = cat_config.get("display_fields", [])
	var stat_text: String = CompendiumDataProvider.build_stat_preview(item, display_fields)
	if not stat_text.is_empty():
		var stat_label := Label.new()
		stat_label.text = stat_text
		stat_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XS)
		stat_label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(stat_label)

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
	panel.gui_input.connect(func(event: InputEvent) -> void:
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
			var val_str := str(item[key])
			if val_str.ends_with(".0"):
				val_str = val_str.substr(0, val_str.length() - 2)
			stat_parts.append("[color=#06b6d4]%s:[/color] %s" % [label, val_str])
	if not stat_parts.is_empty():
		parts.append("  ".join(stat_parts))
		parts.append("")

	# Traits
	if item.has("traits") and item["traits"] is Array and not item["traits"].is_empty():
		var trait_strs: PackedStringArray = []
		for t: Variant in item["traits"]:
			trait_strs.append(str(t))
		var keyword_db = Engine.get_main_loop().root.get_node_or_null("/root/KeywordDB") if Engine.get_main_loop() else null
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
