class_name CampaignJournalScreen
extends "res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd"

## Campaign Journal viewer — multi-filter, two-pane, share-friendly.
## Why a class on its own screen: see audit at C:/Users/admin/.claude/plans —
## prior to v0.9.7 the autoload corpus had no UI. This is the canonical viewer.

const JET := preload("res://src/core/campaign/JournalEntryTypes.gd")

signal back_requested

## When true, BackButton emits `back_requested` instead of routing.
## Set by JournalOverlay or PostBattleSequence host before adding to tree.
@export var overlay_mode: bool = false

## Constants SPACING_*, FONT_SIZE_*, COLOR_*, TOUCH_TARGET_MIN are inherited
## from FiveParsecsCampaignPanel (BaseCampaignPanel) — do NOT redeclare or
## Godot 4.6 errors "member X already exists in parent class".

const FILTER_DEBOUNCE_SEC := 0.15
const SIDEBAR_WIDTH := 320
const EXPORT_DIR := "user://exports/journal/"
const TOP_TAG_CHIPS := 12

## Share menu item IDs
const SHARE_COPY_ENTRY_PLAIN := 0
const SHARE_COPY_ENTRY_MD := 1
const SHARE_COPY_TURN := 2
const SHARE_COPY_FILTERED := 3
const SHARE_SAVE_FULL_MD := 4
const SHARE_SAVE_FULL_JSON := 5
const SHARE_SAVE_TURN_JSON := 6
const SHARE_OPEN_FOLDER := 7

# ── State ───────────────────────────────────────────────────────────────────
var _journal: Node = null
var _all_entries: Array[Dictionary] = []
var _filtered_entries: Array[Dictionary] = []
var _selected_entry: Dictionary = {}

var _filter_type_set: Dictionary = {}      ## set semantics: type_string → true
var _filter_tag_set: Dictionary = {}       ## set semantics: tag_string → true
var _filter_character_id: String = ""       ## "" = all
var _filter_location: String = ""           ## "" = all
var _filter_mood: String = ""               ## "" = all
var _filter_search: String = ""
var _filter_turn_min: int = -1              ## -1 = unset (no lower bound)
var _filter_turn_max: int = -1              ## -1 = unset (no upper bound)
var _sort_newest_first: bool = true

# ── UI Nodes ─────────────────────────────────────────────────────────────────
var _outer: VBoxContainer
var _title_label: Label
var _share_button: MenuButton
var _back_button: Button
var _search_input: LineEdit
var _type_chip_row: HFlowContainer
var _tag_chip_row: HFlowContainer
var _character_dropdown: OptionButton
var _location_dropdown: OptionButton
var _mood_dropdown: OptionButton
var _turn_min_spin: SpinBox
var _turn_max_spin: SpinBox
var _sort_toggle: Button
var _reset_button: Button
var _results_label: Label
var _entry_list: ItemList
var _detail_richtext: RichTextLabel
var _detail_actions_hbox: HBoxContainer
var _edit_notes_button: Button
var _attach_photo_button: Button
var _view_photos_button: Button
var _photo_file_dialog: FileDialog
var _notes_dialog: Window           ## Lazy-built when first edit pressed
var _notes_editor_text: TextEdit
var _photos_dialog: Window           ## Lazy-built when first view pressed
var _photos_grid: GridContainer
var _empty_label: Label
var _debounce_timer: Timer
var _type_chip_buttons: Dictionary = {}    ## type_string → Button
var _tag_chip_buttons: Dictionary = {}     ## tag_string → Button


func _ready() -> void:
	_ensure_base_background()
	_setup_responsive_layout()
	_journal = get_node_or_null("/root/CampaignJournal")
	_build_ui()
	_setup_debounce_timer()
	_load_entries()
	_populate_filter_options()
	_consume_scene_router_context()
	_apply_filters()
	_subscribe_to_journal_signals()


func _setup_debounce_timer() -> void:
	_debounce_timer = Timer.new()
	_debounce_timer.wait_time = FILTER_DEBOUNCE_SEC
	_debounce_timer.one_shot = true
	_debounce_timer.timeout.connect(_apply_filters)
	add_child(_debounce_timer)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SPACING_LG)
	margin.add_theme_constant_override("margin_right", SPACING_LG)
	margin.add_theme_constant_override("margin_top", SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", SPACING_MD)
	add_child(margin)

	_outer = VBoxContainer.new()
	_outer.add_theme_constant_override("separation", SPACING_MD)
	margin.add_child(_outer)

	_outer.add_child(_build_header())
	_outer.add_child(_build_filter_panel())
	_outer.add_child(_build_results_label())
	_outer.add_child(_build_content_split())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_MD)

	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(_back_button)
	_back_button.pressed.connect(_on_back_pressed)
	header.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "Campaign Journal"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_sort_toggle = Button.new()
	_sort_toggle.text = "Newest first"
	_sort_toggle.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(_sort_toggle)
	_sort_toggle.pressed.connect(_on_sort_toggled)
	header.add_child(_sort_toggle)

	_share_button = MenuButton.new()
	_share_button.text = "Share..."
	_share_button.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	_share_button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_share_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	var share_popup: PopupMenu = _share_button.get_popup()
	share_popup.add_item("Copy Entry (Plain)", SHARE_COPY_ENTRY_PLAIN)
	share_popup.add_item("Copy Entry (Markdown)", SHARE_COPY_ENTRY_MD)
	share_popup.add_item("Copy Turn Summary", SHARE_COPY_TURN)
	share_popup.add_item("Copy Filtered View (Markdown)", SHARE_COPY_FILTERED)
	share_popup.add_separator()
	share_popup.add_item("Save Full Journal (Markdown)", SHARE_SAVE_FULL_MD)
	share_popup.add_item("Save Full Journal (JSON)", SHARE_SAVE_FULL_JSON)
	share_popup.add_item("Save Turn as JSON", SHARE_SAVE_TURN_JSON)
	share_popup.add_separator()
	share_popup.add_item("Open Exports Folder", SHARE_OPEN_FOLDER)
	share_popup.id_pressed.connect(_on_share_menu_item)
	header.add_child(_share_button)

	return header


func _build_filter_panel() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", SPACING_SM)
	panel.add_child(v)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search title / description..."
	_search_input.custom_minimum_size.y = TOUCH_TARGET_MIN
	_search_input.clear_button_enabled = true
	_search_input.text_changed.connect(_on_search_changed)
	v.add_child(_search_input)

	v.add_child(_build_chip_row_header("Type"))
	_type_chip_row = HFlowContainer.new()
	_type_chip_row.add_theme_constant_override("h_separation", SPACING_XS)
	_type_chip_row.add_theme_constant_override("v_separation", SPACING_XS)
	v.add_child(_type_chip_row)

	v.add_child(_build_chip_row_header("Tags"))
	_tag_chip_row = HFlowContainer.new()
	_tag_chip_row.add_theme_constant_override("h_separation", SPACING_XS)
	_tag_chip_row.add_theme_constant_override("v_separation", SPACING_XS)
	v.add_child(_tag_chip_row)

	var adv := HFlowContainer.new()
	adv.add_theme_constant_override("h_separation", SPACING_MD)
	adv.add_theme_constant_override("v_separation", SPACING_SM)
	v.add_child(adv)

	_character_dropdown = OptionButton.new()
	_character_dropdown.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	_character_dropdown.item_selected.connect(_on_character_selected)
	adv.add_child(_labeled("Character:", _character_dropdown))

	_location_dropdown = OptionButton.new()
	_location_dropdown.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	_location_dropdown.item_selected.connect(_on_location_selected)
	adv.add_child(_labeled("Planet:", _location_dropdown))

	_mood_dropdown = OptionButton.new()
	_mood_dropdown.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	_mood_dropdown.item_selected.connect(_on_mood_selected)
	adv.add_child(_labeled("Mood:", _mood_dropdown))

	var turn_box := HBoxContainer.new()
	turn_box.add_theme_constant_override("separation", SPACING_XS)
	var turn_lbl := Label.new()
	turn_lbl.text = "Turn:"
	turn_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	turn_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	turn_box.add_child(turn_lbl)
	_turn_min_spin = SpinBox.new()
	_turn_min_spin.min_value = 0
	_turn_min_spin.max_value = 9999
	_turn_min_spin.custom_minimum_size = Vector2(70, TOUCH_TARGET_MIN)
	_turn_min_spin.value_changed.connect(_on_turn_min_changed)
	turn_box.add_child(_turn_min_spin)
	var dash := Label.new()
	dash.text = "to"
	dash.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	turn_box.add_child(dash)
	_turn_max_spin = SpinBox.new()
	_turn_max_spin.min_value = 0
	_turn_max_spin.max_value = 9999
	_turn_max_spin.custom_minimum_size = Vector2(70, TOUCH_TARGET_MIN)
	_turn_max_spin.value_changed.connect(_on_turn_max_changed)
	turn_box.add_child(_turn_max_spin)
	adv.add_child(turn_box)

	_reset_button = Button.new()
	_reset_button.text = "Reset Filters"
	_reset_button.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(_reset_button)
	_reset_button.pressed.connect(_on_reset_filters)
	adv.add_child(_reset_button)

	return panel


func _build_chip_row_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return lbl


func _labeled(label_text: String, control: Control) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", SPACING_XS)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hb.add_child(lbl)
	hb.add_child(control)
	return hb


func _build_results_label() -> Label:
	_results_label = Label.new()
	_results_label.text = "Showing 0 entries"
	_results_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_results_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return _results_label


func _build_content_split() -> Control:
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", SPACING_MD)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = SIDEBAR_WIDTH
	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = COLOR_ELEVATED
	sidebar_style.border_color = COLOR_BORDER
	sidebar_style.set_border_width_all(1)
	sidebar_style.set_corner_radius_all(6)
	sidebar_style.set_content_margin_all(SPACING_SM)
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	_entry_list = ItemList.new()
	_entry_list.add_theme_constant_override("v_separation", 4)
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.item_selected.connect(_on_entry_selected)
	sidebar.add_child(_entry_list)
	split.add_child(sidebar)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = COLOR_ELEVATED
	detail_style.border_color = COLOR_BORDER
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(6)
	detail_style.set_content_margin_all(SPACING_MD)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	var detail_inner := MarginContainer.new()
	detail_inner.add_theme_constant_override("margin_right", 16)
	detail_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_inner)
	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", SPACING_MD)
	detail_inner.add_child(detail_vbox)

	_detail_richtext = RichTextLabel.new()
	_detail_richtext.bbcode_enabled = true
	_detail_richtext.fit_content = true
	_detail_richtext.scroll_active = false
	_detail_richtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_richtext.add_theme_font_size_override("normal_font_size", FONT_SIZE_MD)
	_detail_richtext.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_detail_richtext.meta_clicked.connect(_on_meta_clicked)
	detail_vbox.add_child(_detail_richtext)

	_detail_actions_hbox = HBoxContainer.new()
	_detail_actions_hbox.add_theme_constant_override("separation", SPACING_SM)
	_detail_actions_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(_detail_actions_hbox)

	_edit_notes_button = Button.new()
	_edit_notes_button.text = "Edit Notes"
	_edit_notes_button.tooltip_text = "Add or edit your personal notes for this entry"
	_edit_notes_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_edit_notes_button.pressed.connect(_on_edit_notes_pressed)
	_detail_actions_hbox.add_child(_edit_notes_button)

	_attach_photo_button = Button.new()
	_attach_photo_button.text = "Attach Photo"
	_attach_photo_button.tooltip_text = (
		"Attach a PNG/JPG screenshot or tabletop photo to this entry")
	_attach_photo_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_attach_photo_button.pressed.connect(_on_attach_photo_pressed)
	_detail_actions_hbox.add_child(_attach_photo_button)

	_view_photos_button = Button.new()
	_view_photos_button.text = "View Photos"
	_view_photos_button.tooltip_text = "Open the attached photos for this entry"
	_view_photos_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_view_photos_button.pressed.connect(_on_view_photos_pressed)
	_detail_actions_hbox.add_child(_view_photos_button)

	split.add_child(detail_panel)

	return split


# ── Filter Option Population ────────────────────────────────────────────────

func _populate_filter_options() -> void:
	_populate_type_chips()
	_populate_tag_chips()
	_populate_character_dropdown()
	_populate_location_dropdown()
	_populate_mood_dropdown()
	_initialize_turn_range()


func _populate_type_chips() -> void:
	for child in _type_chip_row.get_children():
		child.queue_free()
	_type_chip_buttons.clear()
	var used_types: Array[String] = []
	if _journal and _journal.has_method("get_used_types"):
		used_types = _journal.get_used_types()
	for t_str: String in JET.get_all_type_strings():
		if not used_types.is_empty() and not used_types.has(t_str):
			continue
		var btn := _make_chip(JET.type_to_label(t_str), JET.type_to_color(t_str))
		btn.toggled.connect(_on_type_chip_toggled.bind(t_str))
		_type_chip_row.add_child(btn)
		_type_chip_buttons[t_str] = btn


func _populate_tag_chips() -> void:
	for child in _tag_chip_row.get_children():
		child.queue_free()
	_tag_chip_buttons.clear()
	var freq: Dictionary = {}
	if _journal and _journal.has_method("get_tag_frequency"):
		freq = _journal.get_tag_frequency()
	var sorted_tags: Array = freq.keys()
	sorted_tags.sort_custom(func(a, b): return int(freq[a]) > int(freq[b]))
	var to_show: Array = sorted_tags.slice(0, TOP_TAG_CHIPS)
	for tag_value in to_show:
		var tag_str: String = str(tag_value)
		var btn := _make_chip(JET.tag_label(tag_str), JET.tag_color(tag_str))
		btn.toggled.connect(_on_tag_chip_toggled.bind(tag_str))
		_tag_chip_row.add_child(btn)
		_tag_chip_buttons[tag_str] = btn


func _populate_character_dropdown() -> void:
	_character_dropdown.clear()
	_character_dropdown.add_item("All Crew", 0)
	_character_dropdown.add_item("No Character", 1)
	var crew_ids: Array[String] = []
	if _journal and _journal.has_method("get_all_character_ids"):
		crew_ids = _journal.get_all_character_ids()
	for char_id: String in crew_ids:
		_character_dropdown.add_item(char_id, _character_dropdown.item_count)
		_character_dropdown.set_item_metadata(
			_character_dropdown.item_count - 1, char_id)


func _populate_location_dropdown() -> void:
	_location_dropdown.clear()
	_location_dropdown.add_item("All Locations", 0)
	var locations: Array[String] = []
	if _journal and _journal.has_method("get_used_locations"):
		locations = _journal.get_used_locations()
	for loc: String in locations:
		_location_dropdown.add_item(loc, _location_dropdown.item_count)
		_location_dropdown.set_item_metadata(
			_location_dropdown.item_count - 1, loc)


func _populate_mood_dropdown() -> void:
	_mood_dropdown.clear()
	_mood_dropdown.add_item("All Moods", 0)
	_mood_dropdown.add_item("Triumph", 1)
	_mood_dropdown.set_item_metadata(1, "triumph")
	_mood_dropdown.add_item("Defeat", 2)
	_mood_dropdown.set_item_metadata(2, "defeat")
	_mood_dropdown.add_item("Neutral", 3)
	_mood_dropdown.set_item_metadata(3, "neutral")
	_mood_dropdown.add_item("Somber", 4)
	_mood_dropdown.set_item_metadata(4, "somber")
	_mood_dropdown.add_item("Exciting", 5)
	_mood_dropdown.set_item_metadata(5, "exciting")


func _initialize_turn_range() -> void:
	var turns: Array[int] = []
	if _journal and _journal.has_method("get_used_turns"):
		turns = _journal.get_used_turns()
	if turns.is_empty():
		_turn_min_spin.value = 0
		_turn_max_spin.value = 0
	else:
		_turn_min_spin.value = turns[0]
		_turn_max_spin.value = turns[turns.size() - 1]


func _make_chip(label: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN - 12)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.5)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(SPACING_XS)
	normal.content_margin_left = SPACING_SM
	normal.content_margin_right = SPACING_SM
	btn.add_theme_stylebox_override("normal", normal)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.35)
	pressed.border_color = accent
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(12)
	pressed.set_content_margin_all(SPACING_XS)
	pressed.content_margin_left = SPACING_SM
	pressed.content_margin_right = SPACING_SM
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


# ── Data Loading + Signal Subscription ──────────────────────────────────────

func _load_entries() -> void:
	_all_entries.clear()
	if _journal and _journal.has_method("get_all_entries"):
		_all_entries = _journal.get_all_entries()


func _subscribe_to_journal_signals() -> void:
	if not _journal:
		return
	if _journal.has_signal("entry_created"):
		_journal.entry_created.connect(_on_journal_entry_changed)
	if _journal.has_signal("entry_updated"):
		_journal.entry_updated.connect(_on_journal_entry_id_changed)
	if _journal.has_signal("entry_deleted"):
		_journal.entry_deleted.connect(_on_journal_entry_id_changed)


func _on_journal_entry_changed(_entry: Dictionary) -> void:
	_load_entries()
	_populate_filter_options()
	_apply_filters()


func _on_journal_entry_id_changed(entry_id: String) -> void:
	_load_entries()
	_apply_filters()
	# If the selected entry was edited in-place, re-render the detail pane
	# with the fresh dict (otherwise we'd display the stale pre-edit copy).
	if not _selected_entry.is_empty() and str(_selected_entry.get("id", "")) == entry_id:
		for fresh: Dictionary in _all_entries:
			if str(fresh.get("id", "")) == entry_id:
				_selected_entry = fresh
				_show_entry_detail(_selected_entry)
				return


# ── Filter Application ──────────────────────────────────────────────────────

func _apply_filters() -> void:
	_filtered_entries.clear()
	for entry: Dictionary in _all_entries:
		if _entry_passes_filters(entry):
			_filtered_entries.append(entry)
	_filtered_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(a.get("turn_number", 0))
		var tb: int = int(b.get("turn_number", 0))
		if _sort_newest_first:
			return ta > tb
		return ta < tb
	)
	_rebuild_entry_list()
	_update_results_label()


func _entry_passes_filters(entry: Dictionary) -> bool:
	var t: String = str(entry.get("type", ""))
	if not _filter_type_set.is_empty() and not _filter_type_set.has(t):
		return false

	if not _filter_tag_set.is_empty():
		var entry_tags: Array = entry.get("tags", [])
		var any_tag := false
		for tag in _filter_tag_set.keys():
			if entry_tags.has(tag):
				any_tag = true
				break
		if not any_tag:
			return false

	if not _filter_character_id.is_empty():
		var involved: Array = entry.get("characters_involved", [])
		if _filter_character_id == "__none__":
			if not involved.is_empty():
				return false
		else:
			if not involved.has(_filter_character_id):
				return false

	if not _filter_location.is_empty():
		if str(entry.get("location", "")) != _filter_location:
			return false

	if not _filter_mood.is_empty():
		if str(entry.get("mood", "")) != _filter_mood:
			return false

	if _filter_turn_min >= 0:
		if int(entry.get("turn_number", 0)) < _filter_turn_min:
			return false
	if _filter_turn_max >= 0:
		if int(entry.get("turn_number", 0)) > _filter_turn_max:
			return false

	if not _filter_search.is_empty():
		var q: String = _filter_search.to_lower()
		var title: String = str(entry.get("title", "")).to_lower()
		var desc: String = str(entry.get("description", "")).to_lower()
		if not q in title and not q in desc:
			return false

	return true


func _rebuild_entry_list() -> void:
	_entry_list.clear()
	for entry: Dictionary in _filtered_entries:
		var t: String = str(entry.get("type", ""))
		var icon: String = JET.type_to_icon(t)
		var turn: int = int(entry.get("turn_number", 0))
		var title: String = str(entry.get("title", "Untitled"))
		var label: String = "%s T%d  %s" % [icon, turn, title]
		var idx: int = _entry_list.add_item(label)
		_entry_list.set_item_custom_fg_color(idx, JET.type_to_color(t))

	if _filtered_entries.is_empty():
		_selected_entry = {}
		_render_empty_detail()
	elif _selected_entry.is_empty() or not _filtered_entries.has(_selected_entry):
		_entry_list.select(0)
		_selected_entry = _filtered_entries[0]
		_show_entry_detail(_selected_entry)


func _update_results_label() -> void:
	_results_label.text = "Showing %d of %d entries" % [
		_filtered_entries.size(), _all_entries.size()]


func _render_empty_detail() -> void:
	_detail_richtext.text = (
		"[center][color=#808080][i]No entries match these filters.[/i]"
		+ "\n\nUse Reset Filters to clear all active filters.[/color][/center]")
	if _detail_actions_hbox != null:
		_detail_actions_hbox.visible = false


# ── Selection + Detail Rendering ────────────────────────────────────────────

func _on_entry_selected(idx: int) -> void:
	if idx < 0 or idx >= _filtered_entries.size():
		return
	_selected_entry = _filtered_entries[idx]
	_show_entry_detail(_selected_entry)


func _show_entry_detail(entry: Dictionary) -> void:
	var t: String = str(entry.get("type", ""))
	var type_label: String = JET.type_to_label(t)
	var type_color: Color = JET.type_to_color(t)
	var mood: String = str(entry.get("mood", "neutral"))
	var mood_color: Color = JET.mood_to_color(mood)
	var title: String = str(entry.get("title", "Untitled"))
	var description: String = str(entry.get("description", ""))
	var turn: int = int(entry.get("turn_number", 0))
	var location: String = str(entry.get("location", ""))
	var tags: Array = entry.get("tags", [])
	var characters: Array = entry.get("characters_involved", [])
	var stats: Dictionary = entry.get("stats", {})
	var player_notes: String = str(entry.get("player_notes", ""))

	var bb: String = ""
	bb += "[font_size=%d][color=#%s]%s[/color][/font_size]\n" % [
		FONT_SIZE_XL, mood_color.to_html(false), title]
	bb += "[color=#%s]Turn %d  ·  [color=#%s]%s[/color]" % [
		COLOR_TEXT_SECONDARY.to_html(false), turn,
		type_color.to_html(false), type_label]
	if not location.is_empty():
		bb += "  ·  %s" % location
	bb += "  ·  %s[/color]\n\n" % JET.mood_to_label(mood)

	if not description.is_empty():
		bb += "%s\n\n" % description

	if not tags.is_empty():
		bb += "[color=#%s]Tags:[/color] " % COLOR_TEXT_SECONDARY.to_html(false)
		var tag_strs: Array[String] = []
		for tag_v in tags:
			var tag_str: String = str(tag_v)
			tag_strs.append("[color=#%s]%s[/color]" % [
				JET.tag_color(tag_str).to_html(false),
				JET.tag_label(tag_str)])
		bb += " · ".join(tag_strs) + "\n\n"

	if not characters.is_empty():
		bb += "[color=#%s]Characters:[/color] " % COLOR_TEXT_SECONDARY.to_html(false)
		var char_strs: Array[String] = []
		for ch_v in characters:
			var ch_id: String = str(ch_v)
			char_strs.append("[url=character:%s]%s[/url]" % [ch_id, ch_id])
		bb += ", ".join(char_strs) + "\n\n"

	if not stats.is_empty():
		bb += "[color=#%s]Details:[/color]\n" % COLOR_TEXT_SECONDARY.to_html(false)
		for k in stats.keys():
			bb += "  · %s: %s\n" % [str(k).capitalize(), str(stats[k])]
		bb += "\n"

	if not player_notes.is_empty():
		bb += "[color=#%s]Notes:[/color]\n[i]%s[/i]\n" % [
			COLOR_TEXT_SECONDARY.to_html(false), player_notes]

	var photos: Array = entry.get("photos", [])
	if not photos.is_empty():
		bb += "\n[color=#%s]Photos:[/color] %d attached\n" % [
			COLOR_TEXT_SECONDARY.to_html(false), photos.size()]

	_detail_richtext.text = bb

	if _detail_actions_hbox != null:
		_detail_actions_hbox.visible = true
		_edit_notes_button.text = "Edit Notes" if player_notes.is_empty() else "Edit Notes (1)"
		_view_photos_button.visible = not photos.is_empty()
		_view_photos_button.text = "View Photos (%d)" % photos.size()


# ── Filter Signal Handlers (all debounced via _schedule_filter) ─────────────

func _schedule_filter() -> void:
	if _debounce_timer.is_stopped():
		_debounce_timer.start()
	else:
		_debounce_timer.stop()
		_debounce_timer.start()


func _on_search_changed(text: String) -> void:
	_filter_search = text
	_schedule_filter()


func _on_type_chip_toggled(pressed: bool, type_str: String) -> void:
	if pressed:
		_filter_type_set[type_str] = true
	else:
		_filter_type_set.erase(type_str)
	_schedule_filter()


func _on_tag_chip_toggled(pressed: bool, tag_str: String) -> void:
	if pressed:
		_filter_tag_set[tag_str] = true
	else:
		_filter_tag_set.erase(tag_str)
	_schedule_filter()


func _on_character_selected(idx: int) -> void:
	if idx == 0:
		_filter_character_id = ""
	elif idx == 1:
		_filter_character_id = "__none__"
	else:
		var meta: Variant = _character_dropdown.get_item_metadata(idx)
		_filter_character_id = str(meta) if meta != null else ""
	_schedule_filter()


func _on_location_selected(idx: int) -> void:
	if idx == 0:
		_filter_location = ""
	else:
		var meta: Variant = _location_dropdown.get_item_metadata(idx)
		_filter_location = str(meta) if meta != null else ""
	_schedule_filter()


func _on_mood_selected(idx: int) -> void:
	if idx == 0:
		_filter_mood = ""
	else:
		var meta: Variant = _mood_dropdown.get_item_metadata(idx)
		_filter_mood = str(meta) if meta != null else ""
	_schedule_filter()


func _on_turn_min_changed(v: float) -> void:
	_filter_turn_min = int(v) if v > 0 else -1
	_schedule_filter()


func _on_turn_max_changed(v: float) -> void:
	_filter_turn_max = int(v) if v > 0 else -1
	_schedule_filter()


func _on_sort_toggled() -> void:
	_sort_newest_first = not _sort_newest_first
	_sort_toggle.text = "Newest first" if _sort_newest_first else "Oldest first"
	_apply_filters()


func _on_reset_filters() -> void:
	_filter_type_set.clear()
	_filter_tag_set.clear()
	_filter_character_id = ""
	_filter_location = ""
	_filter_mood = ""
	_filter_search = ""
	_filter_turn_min = -1
	_filter_turn_max = -1
	_search_input.text = ""
	for btn in _type_chip_buttons.values():
		btn.set_pressed_no_signal(false)
	for btn in _tag_chip_buttons.values():
		btn.set_pressed_no_signal(false)
	_character_dropdown.select(0)
	_location_dropdown.select(0)
	_mood_dropdown.select(0)
	_initialize_turn_range()
	_apply_filters()


# ── Share Menu ──────────────────────────────────────────────────────────────

func _on_share_menu_item(id: int) -> void:
	match id:
		SHARE_COPY_ENTRY_PLAIN:
			_share_copy_entry_plain()
		SHARE_COPY_ENTRY_MD:
			_share_copy_entry_md()
		SHARE_COPY_TURN:
			_share_copy_turn_summary()
		SHARE_COPY_FILTERED:
			_share_copy_filtered_view()
		SHARE_SAVE_FULL_MD:
			_share_save_full_markdown()
		SHARE_SAVE_FULL_JSON:
			_share_save_full_json()
		SHARE_SAVE_TURN_JSON:
			_share_save_turn_json()
		SHARE_OPEN_FOLDER:
			_share_open_exports_folder()


func _share_copy_entry_plain() -> void:
	if _selected_entry.is_empty():
		_notify_warning("No entry selected.")
		return
	var text: String = "Turn %d — %s\n%s" % [
		int(_selected_entry.get("turn_number", 0)),
		str(_selected_entry.get("title", "Untitled")),
		str(_selected_entry.get("description", "")),
	]
	var tags: Array = _selected_entry.get("tags", [])
	if not tags.is_empty():
		var tag_strs: Array[String] = []
		for t in tags:
			tag_strs.append(str(t))
		text += "\nTags: " + ", ".join(tag_strs)
	DisplayServer.clipboard_set(text)
	_notify_success("Copied entry to clipboard")


func _share_copy_entry_md() -> void:
	if _selected_entry.is_empty():
		_notify_warning("No entry selected.")
		return
	var md: String = "## Turn %d — %s\n\n" % [
		int(_selected_entry.get("turn_number", 0)),
		str(_selected_entry.get("title", "Untitled"))]
	md += "**Type:** %s · **Mood:** %s\n\n" % [
		JET.type_to_label(str(_selected_entry.get("type", ""))),
		JET.mood_to_label(str(_selected_entry.get("mood", "neutral")))]
	md += "%s\n\n" % str(_selected_entry.get("description", ""))
	var tags: Array = _selected_entry.get("tags", [])
	if not tags.is_empty():
		var tag_strs: Array[String] = []
		for t in tags:
			tag_strs.append("`%s`" % str(t))
		md += "Tags: " + " ".join(tag_strs) + "\n"
	DisplayServer.clipboard_set(md)
	_notify_success("Copied entry (Markdown) to clipboard")


func _share_copy_turn_summary() -> void:
	var turn: int = _resolve_turn_for_share()
	if turn < 0:
		_notify_warning("No turn selected.")
		return
	if not _journal or not _journal.has_method("export_turn_markdown"):
		_notify_error("Journal autoload missing export_turn_markdown")
		return
	var md: String = _journal.export_turn_markdown(turn, _campaign_name())
	DisplayServer.clipboard_set(md)
	_notify_success("Copied Turn %d summary to clipboard" % turn)


func _share_copy_filtered_view() -> void:
	if _filtered_entries.is_empty():
		_notify_warning("No entries match current filters.")
		return
	var md: String = "# Campaign Journal — Filtered View\n\n"
	md += "**%d entries**\n\n" % _filtered_entries.size()
	for entry: Dictionary in _filtered_entries:
		md += "- **Turn %d — %s** (%s): %s\n" % [
			int(entry.get("turn_number", 0)),
			str(entry.get("title", "Untitled")),
			JET.type_to_label(str(entry.get("type", ""))),
			str(entry.get("description", "")).split("\n")[0],
		]
	DisplayServer.clipboard_set(md)
	_notify_success("Copied filtered view (Markdown) to clipboard")


func _share_save_full_markdown() -> void:
	_ensure_export_dir()
	var path: String = "%s%s_full_%s.md" % [
		EXPORT_DIR, _safe_campaign_filename(),
		Time.get_datetime_string_from_system().replace(":", "-")]
	if _journal and _journal.has_method("export_to_markdown") and _journal.export_to_markdown(path):
		_notify_success("Saved Markdown to %s" % path)
	else:
		_notify_error("Failed to save Markdown")


func _share_save_full_json() -> void:
	_ensure_export_dir()
	var path: String = "%s%s_full_%s.json" % [
		EXPORT_DIR, _safe_campaign_filename(),
		Time.get_datetime_string_from_system().replace(":", "-")]
	if _journal and _journal.has_method("export_to_json") and _journal.export_to_json(path):
		_notify_success("Saved JSON to %s" % path)
	else:
		_notify_error("Failed to save JSON")


func _share_save_turn_json() -> void:
	var turn: int = _resolve_turn_for_share()
	if turn < 0:
		_notify_warning("No turn selected.")
		return
	_ensure_export_dir()
	var path: String = "%s%s_T%d_%s.json" % [
		EXPORT_DIR, _safe_campaign_filename(), turn,
		Time.get_datetime_string_from_system().replace(":", "-")]
	if not _journal or not _journal.has_method("export_turn_json"):
		_notify_error("Journal autoload missing export_turn_json")
		return
	var content: String = _journal.export_turn_json(turn)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_notify_error("Failed to open %s for writing" % path)
		return
	file.store_string(content)
	file.close()
	_notify_success("Saved Turn %d JSON to %s" % [turn, path])


func _share_open_exports_folder() -> void:
	_ensure_export_dir()
	OS.shell_open(ProjectSettings.globalize_path(EXPORT_DIR))


# ── Helpers ────────────────────────────────────────────────────────────────

func _ensure_export_dir() -> void:
	if not DirAccess.dir_exists_absolute(EXPORT_DIR):
		DirAccess.make_dir_recursive_absolute(EXPORT_DIR)


func _resolve_turn_for_share() -> int:
	if not _selected_entry.is_empty():
		return int(_selected_entry.get("turn_number", 0))
	if not _filtered_entries.is_empty():
		return int(_filtered_entries[0].get("turn_number", 0))
	return -1


func _campaign_name() -> String:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_campaign" in gs and gs.current_campaign:
		var camp = gs.current_campaign
		if "campaign_name" in camp:
			return str(camp.campaign_name)
	return ""


func _safe_campaign_filename() -> String:
	var n: String = _campaign_name()
	if n.is_empty():
		n = "campaign"
	return n.replace(" ", "_").replace("/", "_").replace("\\", "_")


func _notify_success(msg: String) -> void:
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_success"):
		nm.show_success(msg)
	else:
		print("[Journal] ", msg)


func _notify_warning(msg: String) -> void:
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_warning"):
		nm.show_warning(msg)
	else:
		print("[Journal] ", msg)


func _notify_error(msg: String) -> void:
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_error"):
		nm.show_error(msg)
	else:
		push_error(msg)


# ── Navigation ─────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if overlay_mode:
		back_requested.emit()
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_back"):
		router.navigate_back()


func _on_meta_clicked(meta: Variant) -> void:
	## Character links: [url=character:vex_001]Vex[/url]
	var s: String = str(meta)
	var parts: PackedStringArray = s.split(":", false, 1)
	if parts.size() < 2:
		return
	if parts[0] == "character":
		var router: Node = get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to("character_details", {"character_id": parts[1]})


# ── Notes Editor (lazy-built Window with TextEdit) ─────────────────────────

func _on_edit_notes_pressed() -> void:
	if _selected_entry.is_empty():
		return
	_ensure_notes_dialog()
	_notes_editor_text.text = str(_selected_entry.get("player_notes", ""))
	_notes_dialog.title = "Notes — %s" % str(_selected_entry.get("title", "Entry"))
	_notes_dialog.popup_centered(Vector2i(560, 320))


func _ensure_notes_dialog() -> void:
	if _notes_dialog != null:
		return
	_notes_dialog = Window.new()
	_notes_dialog.title = "Player Notes"
	_notes_dialog.exclusive = true
	_notes_dialog.transient = true
	_notes_dialog.close_requested.connect(func() -> void: _notes_dialog.hide())
	add_child(_notes_dialog)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", SPACING_MD)
	pad.add_theme_constant_override("margin_right", SPACING_MD)
	pad.add_theme_constant_override("margin_top", SPACING_MD)
	pad.add_theme_constant_override("margin_bottom", SPACING_MD)
	_notes_dialog.add_child(pad)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	pad.add_child(vbox)

	var hint := Label.new()
	hint.text = "Add a free-form note for sharing or future reference."
	hint.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hint.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	vbox.add_child(hint)

	_notes_editor_text = TextEdit.new()
	_notes_editor_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes_editor_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_editor_text.custom_minimum_size = Vector2(0, 180)
	_notes_editor_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_notes_editor_text)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(actions)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	cancel_btn.pressed.connect(func() -> void: _notes_dialog.hide())
	actions.add_child(cancel_btn)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size.y = TOUCH_TARGET_MIN
	save_btn.pressed.connect(_on_notes_save_pressed)
	actions.add_child(save_btn)


func _on_notes_save_pressed() -> void:
	if _selected_entry.is_empty() or _journal == null:
		return
	var entry_id: String = str(_selected_entry.get("id", ""))
	if entry_id.is_empty():
		return
	var new_notes: String = _notes_editor_text.text
	var ok: bool = _journal.update_entry(entry_id, {"player_notes": new_notes})
	if ok:
		_notes_dialog.hide()
		_notify_success("Notes saved")
	else:
		_notify_error("Failed to save notes")


# ── Photo Attachment (lazy-built FileDialog + viewer Window) ───────────────

func _on_attach_photo_pressed() -> void:
	if _selected_entry.is_empty():
		return
	_ensure_photo_file_dialog()
	_photo_file_dialog.popup_centered_ratio(0.6)


func _ensure_photo_file_dialog() -> void:
	if _photo_file_dialog != null:
		return
	_photo_file_dialog = FileDialog.new()
	_photo_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_photo_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_photo_file_dialog.title = "Attach Photo"
	_photo_file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; Image Files",
	])
	_photo_file_dialog.file_selected.connect(_on_photo_file_selected)
	add_child(_photo_file_dialog)


func _on_photo_file_selected(path: String) -> void:
	if _selected_entry.is_empty() or _journal == null:
		return
	var image := Image.new()
	var err: int = image.load(path)
	if err != OK:
		_notify_error("Failed to load image: %s" % path)
		return
	var entry_id: String = str(_selected_entry.get("id", ""))
	var ok: bool = _journal.attach_photo_to_entry(entry_id, image, path.get_file())
	if ok:
		_notify_success("Photo attached")
	else:
		_notify_error("Failed to attach photo (entry full or save error)")


# ── Photo Viewer (lazy-built Window with TextureRect grid) ─────────────────

func _on_view_photos_pressed() -> void:
	if _selected_entry.is_empty():
		return
	_ensure_photos_dialog()
	_populate_photos_grid(_selected_entry.get("photos", []))
	_photos_dialog.title = "Photos — %s" % str(_selected_entry.get("title", "Entry"))
	_photos_dialog.popup_centered(Vector2i(640, 480))


func _ensure_photos_dialog() -> void:
	if _photos_dialog != null:
		return
	_photos_dialog = Window.new()
	_photos_dialog.title = "Photos"
	_photos_dialog.exclusive = true
	_photos_dialog.transient = true
	_photos_dialog.close_requested.connect(func() -> void: _photos_dialog.hide())
	add_child(_photos_dialog)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", SPACING_MD)
	pad.add_theme_constant_override("margin_right", SPACING_MD)
	pad.add_theme_constant_override("margin_top", SPACING_MD)
	pad.add_theme_constant_override("margin_bottom", SPACING_MD)
	_photos_dialog.add_child(pad)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(scroll)
	_photos_grid = GridContainer.new()
	_photos_grid.columns = 2
	_photos_grid.add_theme_constant_override("h_separation", SPACING_MD)
	_photos_grid.add_theme_constant_override("v_separation", SPACING_MD)
	_photos_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_photos_grid)


func _populate_photos_grid(photos: Array) -> void:
	for child in _photos_grid.get_children():
		child.queue_free()
	if photos.is_empty():
		var hint := Label.new()
		hint.text = "No photos attached yet."
		hint.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_photos_grid.add_child(hint)
		return
	for photo_v in photos:
		var photo: Dictionary = photo_v as Dictionary
		var path: String = str(photo.get("path", ""))
		var caption: String = str(photo.get("caption", ""))
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", SPACING_XS)
		_photos_grid.add_child(cell)
		var tex_rect := TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tex_rect.custom_minimum_size = Vector2(260, 180)
		var img := Image.new()
		if img.load(path) == OK:
			tex_rect.texture = ImageTexture.create_from_image(img)
		cell.add_child(tex_rect)
		var caption_label := Label.new()
		caption_label.text = caption if not caption.is_empty() else path.get_file()
		caption_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		caption_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(caption_label)


func _notify_success(msg: String) -> void:
	var nm: Node = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_success"):
		nm.show_success(msg)
	else:
		print("[Journal] ", msg)


func _consume_scene_router_context() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if not router:
		return
	var ctx: Dictionary = {}
	if "scene_contexts" in router:
		ctx = router.scene_contexts.get("campaign_journal", {})
	if ctx.is_empty():
		return
	var pre_char: String = str(ctx.get("pre_filter_character_id", ""))
	if not pre_char.is_empty():
		_filter_character_id = pre_char
		for i in range(_character_dropdown.item_count):
			if _character_dropdown.get_item_metadata(i) == pre_char:
				_character_dropdown.select(i)
				break
	var pre_loc: String = str(ctx.get("pre_filter_location", ""))
	if not pre_loc.is_empty():
		_filter_location = pre_loc
		for i in range(_location_dropdown.item_count):
			if _location_dropdown.get_item_metadata(i) == pre_loc:
				_location_dropdown.select(i)
				break
	var pre_type: String = str(ctx.get("pre_filter_type", ""))
	if not pre_type.is_empty():
		_filter_type_set[pre_type] = true
		if _type_chip_buttons.has(pre_type):
			_type_chip_buttons[pre_type].set_pressed_no_signal(true)
