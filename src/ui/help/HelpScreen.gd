extends CampaignScreenBase

## Full-page help browser for the User Guide.
## Displays markdown chapters from docs/user_guide/ in Deep Space themed UI.
## Features: sidebar TOC, search, chapter navigation, cross-reference links.

var _content_loader: RefCounted  # HelpContentLoader
var _md_converter: RefCounted    # MarkdownToRichText

# UI references
var _header_bar: HBoxContainer
var _back_button: Button
var _title_label: Label
var _search_input: LineEdit
var _body_split: HSplitContainer
var _sidebar_scroll: ScrollContainer
var _sidebar_vbox: VBoxContainer
var _content_scroll: ScrollContainer
var _content_label: RichTextLabel
var _mobile_toc_button: Button
var _mobile_toc_popup: PopupPanel

# State
var _current_chapter_id: String = ""
var _toc_buttons: Dictionary = {}  # chapter_id -> Button

# Preload helpers
const HelpContentLoaderScript = preload("res://src/ui/help/HelpContentLoader.gd")
const MarkdownToRichTextScript = preload("res://src/ui/help/MarkdownToRichText.gd")


func _setup_screen() -> void:
	_content_loader = HelpContentLoaderScript.new()
	_md_converter = MarkdownToRichTextScript.new()

	_build_ui()
	_populate_toc()

	# Check if we should open a specific chapter from SceneRouter context
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("get_scene_context"):
		var ctx: Dictionary = router.get_scene_context("help")
		if ctx.has("chapter_id"):
			_navigate_to_chapter(ctx["chapter_id"], ctx.get("section_id", ""))
			return

	# Default: show index/first chapter
	var order: Array[String] = _content_loader.get_chapter_order()
	if order.size() > 1:
		_navigate_to_chapter(order[1])  # Skip 00_index, show ch01
	elif not order.is_empty():
		_navigate_to_chapter(order[0])


func _build_ui() -> void:
	# Root layout
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Apply background
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BASE
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# ── Header bar ──
	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.9)
	header_style.set_content_margin_all(SPACING_MD)
	header_style.border_color = COLOR_BORDER
	header_style.border_width_bottom = 1
	header_panel.add_theme_stylebox_override("panel", header_style)
	root.add_child(header_panel)

	_header_bar = HBoxContainer.new()
	_header_bar.add_theme_constant_override("separation", SPACING_MD)
	header_panel.add_child(_header_bar)

	# Back button
	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	_style_button(_back_button)
	_back_button.pressed.connect(_on_back_pressed)
	_header_bar.add_child(_back_button)

	# Mobile TOC button (hidden on desktop)
	_mobile_toc_button = Button.new()
	_mobile_toc_button.text = "Chapters"
	_mobile_toc_button.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	_style_button(_mobile_toc_button)
	_mobile_toc_button.pressed.connect(_on_mobile_toc_pressed)
	_mobile_toc_button.visible = false
	_header_bar.add_child(_mobile_toc_button)

	# Title
	_title_label = Label.new()
	_title_label.text = "USER GUIDE"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(_title_label)

	# Search input
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search..."
	_search_input.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	_style_line_edit(_search_input)
	_search_input.text_submitted.connect(_on_search_submitted)
	_header_bar.add_child(_search_input)

	# ── Body: sidebar + content ──
	_body_split = HSplitContainer.new()
	_body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_body_split)

	# Sidebar
	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(260, 0)
	sidebar_panel.size_flags_horizontal = Control.SIZE_FILL
	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.7)
	sidebar_style.set_content_margin_all(SPACING_SM)
	sidebar_style.border_color = COLOR_BORDER
	sidebar_style.border_width_right = 1
	sidebar_panel.add_theme_stylebox_override("panel", sidebar_style)
	_body_split.add_child(sidebar_panel)

	_sidebar_scroll = ScrollContainer.new()
	_sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_panel.add_child(_sidebar_scroll)

	_sidebar_vbox = VBoxContainer.new()
	_sidebar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_vbox.add_theme_constant_override("separation", SPACING_XS)
	_sidebar_scroll.add_child(_sidebar_vbox)

	# Content area
	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = COLOR_BASE
	content_style.set_content_margin_all(SPACING_XL)
	content_panel.add_theme_stylebox_override("panel", content_style)
	_body_split.add_child(content_panel)

	_content_scroll = ScrollContainer.new()
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(_content_scroll)

	_content_label = RichTextLabel.new()
	_content_label.bbcode_enabled = true
	_content_label.fit_content = true
	_content_label.scroll_active = false  # Outer ScrollContainer handles scrolling
	_content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_MD)
	_content_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_content_label.meta_clicked.connect(_on_meta_clicked)
	_content_scroll.add_child(_content_label)

	# Mobile TOC popup
	_mobile_toc_popup = PopupPanel.new()
	_mobile_toc_popup.size = Vector2i(300, 500)
	add_child(_mobile_toc_popup)


func _populate_toc() -> void:
	var toc: Array[Dictionary] = _content_loader.get_table_of_contents()
	for entry in toc:
		var ch_id: String = entry["id"]
		var title: String = entry["title"]
		# Skip the index itself
		if ch_id == "00_index":
			continue

		var btn := Button.new()
		btn.text = title
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 36

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color.TRANSPARENT
		btn_style.set_content_margin_all(SPACING_SM)
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style := btn_style.duplicate()
		hover_style.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.15)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

		btn.pressed.connect(_on_toc_button_pressed.bind(ch_id))
		_sidebar_vbox.add_child(btn)
		_toc_buttons[ch_id] = btn


func _navigate_to_chapter(chapter_id: String, section_id: String = "") -> void:
	var chapter: Dictionary = _content_loader.load_chapter(chapter_id)
	if chapter.is_empty():
		_content_label.text = "[color=#DC2626]Chapter not found: %s[/color]" % chapter_id
		return

	_current_chapter_id = chapter_id

	# Update sidebar highlight
	for ch_id in _toc_buttons:
		var btn: Button = _toc_buttons[ch_id]
		if ch_id == chapter_id:
			btn.add_theme_color_override("font_color", COLOR_FOCUS)
		else:
			btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	# Render chapter content
	var raw: String = chapter.get("raw", "")
	var bbcode: String = _md_converter.convert(raw)
	_content_label.text = bbcode

	# Scroll to top (or to section if specified)
	_content_scroll.scroll_vertical = 0

	# Update title with chapter name
	var ch_title: String = chapter.get("title", "User Guide")
	_title_label.text = ch_title.to_upper()

	# Animate content if TweenFX available
	var tweenfx := get_node_or_null("/root/TweenFX")
	if tweenfx and tweenfx.has_method("fade_in"):
		_content_label.modulate.a = 0.0
		tweenfx.fade_in(_content_label, 0.3)


func _on_toc_button_pressed(chapter_id: String) -> void:
	_navigate_to_chapter(chapter_id)
	if _mobile_toc_popup.visible:
		_mobile_toc_popup.hide()


func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_back()


func _on_search_submitted(query: String) -> void:
	if query.strip_edges().is_empty():
		return

	var results: Array[Dictionary] = _content_loader.search(query)
	if results.is_empty():
		_content_label.text = "[color=%s]No results found for:[/color] [b]%s[/b]\n\nTry different keywords." % [
			"#808080", query]
		_title_label.text = "SEARCH RESULTS"
		return

	# Build search results display
	var bbcode := "[font_size=22][b]Search Results for: %s[/b][/font_size]\n\n" % query
	bbcode += "[color=#808080]Found %d result(s)[/color]\n\n" % results.size()

	for result in results:
		var r: Dictionary = result
		var ch_title: String = r.get("chapter_title", "")
		var sec_heading: String = r.get("section_heading", "")
		var ch_id: String = r.get("chapter_id", "")

		bbcode += "[color=#4FC3F7][url=chapter:%s]%s[/url][/color]" % [ch_id, ch_title]
		if not sec_heading.is_empty():
			bbcode += " > %s" % sec_heading
		bbcode += "\n"

	_content_label.text = bbcode
	_title_label.text = "SEARCH RESULTS"
	_content_scroll.scroll_vertical = 0


func _on_meta_clicked(meta: Variant) -> void:
	var meta_str: String = str(meta)
	if meta_str.begins_with("chapter:"):
		var target := meta_str.substr(8)  # Remove "chapter:" prefix
		# Could be "01" or "01_getting_started"
		var resolved: String = _content_loader._resolve_chapter_id(target)
		_navigate_to_chapter(resolved)


func _on_mobile_toc_pressed() -> void:
	if _mobile_toc_popup.visible:
		_mobile_toc_popup.hide()
		return

	# Populate mobile popup with TOC buttons
	for child in _mobile_toc_popup.get_children():
		child.queue_free()

	var popup_scroll := ScrollContainer.new()
	popup_scroll.custom_minimum_size = Vector2(280, 400)
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mobile_toc_popup.add_child(popup_scroll)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_vbox.add_theme_constant_override("separation", SPACING_XS)
	popup_scroll.add_child(popup_vbox)

	var toc: Array[Dictionary] = _content_loader.get_table_of_contents()
	for entry in toc:
		var ch_id: String = entry["id"]
		if ch_id == "00_index":
			continue
		var btn := Button.new()
		btn.text = entry["title"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = TOUCH_TARGET_COMFORT
		btn.pressed.connect(_on_toc_button_pressed.bind(ch_id))
		popup_vbox.add_child(btn)

	_mobile_toc_popup.popup_centered()


# ── Responsive layout overrides ──────────────────────────────────────────────

func _apply_mobile_layout() -> void:
	# Hide sidebar, show mobile TOC button
	if _body_split and _body_split.get_child_count() > 0:
		_body_split.get_child(0).visible = false  # sidebar
	if _mobile_toc_button:
		_mobile_toc_button.visible = true
	if _search_input:
		_search_input.custom_minimum_size.x = 120

func _apply_tablet_layout() -> void:
	# Show sidebar but narrower
	if _body_split and _body_split.get_child_count() > 0:
		_body_split.get_child(0).visible = true
		_body_split.get_child(0).custom_minimum_size.x = 200
	if _mobile_toc_button:
		_mobile_toc_button.visible = false
	if _search_input:
		_search_input.custom_minimum_size.x = 160

func _apply_desktop_layout() -> void:
	# Full sidebar
	if _body_split and _body_split.get_child_count() > 0:
		_body_split.get_child(0).visible = true
		_body_split.get_child(0).custom_minimum_size.x = 260
	if _mobile_toc_button:
		_mobile_toc_button.visible = false
	if _search_input:
		_search_input.custom_minimum_size.x = 200
