extends PanelContainer

## CharacterEventTimeline — Filterable event log for a single character.
## Merges CampaignJournal character timeline + journal entries into a
## unified, filterable reverse-chronological list.

# ── Deep Space Theme Constants ──────────────────────────────────
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ACCENT := Color("#2D5A7B")

const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

const TOUCH_TARGET_MIN := 48
const MAX_VISIBLE := 50

# ── Event Type Colors ───────────────────────────────────────────
const EVENT_COLORS: Dictionary = {
	"battle": Color("#DC2626"),
	"injury": Color("#D97706"),
	"advancement": Color("#10B981"),
	"story_event": Color("#8B5CF6"),
	"story_complete": Color("#8B5CF6"),
	"story": Color("#8B5CF6"),
	"milestone": Color("#8B5CF6"),
	"kill": Color("#EF4444"),
}
const DEFAULT_COLOR := Color("#808080")

const EVENT_LABELS: Dictionary = {
	"battle": "Battle",
	"injury": "Injury",
	"advancement": "Adv",
	"story_event": "Story",
	"story_complete": "Story",
	"story": "Story",
	"milestone": "Milestone",
	"kill": "Kill",
}

const FILTER_TYPES: Array[String] = [
	"battle", "injury", "advancement", "story", "kill",
]

# ── State ───────────────────────────────────────────────────────
var _char_id: String = ""
var _all_events: Array[Dictionary] = []
var _filtered_events: Array[Dictionary] = []
var _active_filters: Array[String] = []  # empty = show all
var _filter_buttons: Dictionary = {}  # type → Button

# ── UI References ───────────────────────────────────────────────
var _events_vbox: VBoxContainer = null
var _empty_label: Label = null
var _show_more_btn: Button = null
var _visible_count: int = MAX_VISIBLE


func _ready() -> void:
	_apply_panel_style()
	_build_ui()


## Public API: set character and load events
func setup(character_id: String) -> void:
	_char_id = character_id
	_load_events()
	_apply_filters()


## Public API: refresh event list (after new events logged)
func refresh() -> void:
	_load_events()
	_apply_filters()


# ── UI Construction ─────────────────────────────────────────────

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override(
		"separation", SPACING_SM)
	add_child(root_vbox)

	# Header
	var header := Label.new()
	header.text = "EVENT LOG"
	header.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	header.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	root_vbox.add_child(header)

	# Filter bar
	var filter_flow := HFlowContainer.new()
	filter_flow.add_theme_constant_override(
		"h_separation", SPACING_XS)
	filter_flow.add_theme_constant_override(
		"v_separation", SPACING_XS)
	root_vbox.add_child(filter_flow)

	# "All" button
	var all_btn := _create_filter_button("All", "")
	all_btn.button_pressed = true
	filter_flow.add_child(all_btn)
	_filter_buttons[""] = all_btn

	# Per-type buttons
	for filter_type: String in FILTER_TYPES:
		var label: String = EVENT_LABELS.get(
			filter_type, filter_type.capitalize())
		var btn := _create_filter_button(label, filter_type)
		filter_flow.add_child(btn)
		_filter_buttons[filter_type] = btn

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	root_vbox.add_child(sep)

	# Scrollable event list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	_events_vbox = VBoxContainer.new()
	_events_vbox.add_theme_constant_override(
		"separation", SPACING_XS)
	_events_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_events_vbox)

	# Empty state label (hidden by default)
	_empty_label = Label.new()
	_empty_label.text = "No events recorded yet"
	_empty_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	_empty_label.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	_empty_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER)
	_empty_label.visible = false
	_events_vbox.add_child(_empty_label)

	# Show more button (hidden by default)
	_show_more_btn = Button.new()
	_show_more_btn.text = "Show more..."
	_show_more_btn.custom_minimum_size.y = 36
	_show_more_btn.visible = false
	_show_more_btn.pressed.connect(_on_show_more)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COLOR_BORDER
	btn_style.set_corner_radius_all(4)
	_show_more_btn.add_theme_stylebox_override(
		"normal", btn_style)
	root_vbox.add_child(_show_more_btn)


func _create_filter_button(
	label: String, filter_type: String
) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(60, 32)
	btn.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)

	# Style: border-only when inactive, filled when active
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(COLOR_ELEVATED.r,
		COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.5)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(SPACING_XS)
	btn.add_theme_stylebox_override("normal", normal)

	var pressed_style := StyleBoxFlat.new()
	var type_color: Color = EVENT_COLORS.get(
		filter_type, COLOR_ACCENT)
	pressed_style.bg_color = Color(
		type_color.r, type_color.g, type_color.b, 0.3)
	pressed_style.border_color = type_color
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(SPACING_XS)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.toggled.connect(
		_on_filter_toggled.bind(filter_type))
	return btn


# ── Data Loading ────────────────────────────────────────────────

func _load_events() -> void:
	_all_events.clear()
	var journal: Node = _get_journal()
	if not journal:
		return

	# Source 1: Character timeline (per-character events)
	if journal.has_method("get_character_timeline"):
		var timeline: Array = journal.get_character_timeline(
			_char_id)
		for entry: Dictionary in timeline:
			_all_events.append({
				"turn": entry.get("turn", 0),
				"type": entry.get("event", "other"),
				"text": entry.get("details", ""),
				"source": "timeline",
			})

	# Source 2: Journal entries involving this character
	if journal.has_method("get_character_entries"):
		var entries: Array = journal.get_character_entries(
			_char_id)
		for entry: Dictionary in entries:
			var entry_type: String = entry.get("type", "")
			# Only add types not already covered by timeline
			if entry_type in [
				"battle", "story", "milestone"
			]:
				_all_events.append({
					"turn": entry.get("turn_number", 0),
					"type": entry_type,
					"text": "%s: %s" % [
						entry.get("title", ""),
						entry.get("description", "")],
					"source": "journal",
				})

	# Sort by turn descending (most recent first)
	_all_events.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("turn", 0) > b.get("turn", 0))


func _get_journal() -> Node:
	var tree: SceneTree = Engine.get_main_loop()
	if not tree:
		return null
	return tree.root.get_node_or_null("/root/CampaignJournal")


# ── Filtering ───────────────────────────────────────────────────

func _on_filter_toggled(
	pressed: bool, filter_type: String
) -> void:
	if filter_type.is_empty():
		# "All" button — clear other filters
		_active_filters.clear()
		for key: String in _filter_buttons:
			if not key.is_empty():
				_filter_buttons[key].set_pressed_no_signal(false)
		_filter_buttons[""].set_pressed_no_signal(true)
	else:
		# Individual filter toggle
		_filter_buttons[""].set_pressed_no_signal(false)
		if pressed:
			if filter_type not in _active_filters:
				_active_filters.append(filter_type)
		else:
			_active_filters.erase(filter_type)
		# If no filters active, re-enable "All"
		if _active_filters.is_empty():
			_filter_buttons[""].set_pressed_no_signal(true)

	_visible_count = MAX_VISIBLE
	_apply_filters()


func _apply_filters() -> void:
	if _active_filters.is_empty():
		_filtered_events = _all_events.duplicate()
	else:
		_filtered_events.clear()
		for event: Dictionary in _all_events:
			var etype: String = _normalize_type(
				event.get("type", ""))
			if etype in _active_filters:
				_filtered_events.append(event)
	_rebuild_event_list()


func _normalize_type(raw_type: String) -> String:
	## Map sub-types to filter categories
	match raw_type:
		"story_event", "story_complete", "milestone":
			return "story"
		_:
			return raw_type


# ── Event List Rendering ────────────────────────────────────────

func _rebuild_event_list() -> void:
	if not _events_vbox:
		return

	# Clear old entries (keep _empty_label)
	for child in _events_vbox.get_children():
		if child != _empty_label:
			child.queue_free()

	if _filtered_events.is_empty():
		_empty_label.visible = true
		if _show_more_btn:
			_show_more_btn.visible = false
		return

	_empty_label.visible = false
	var count: int = mini(
		_visible_count, _filtered_events.size())

	for i: int in range(count):
		var event: Dictionary = _filtered_events[i]
		var row := _create_event_row(event)
		_events_vbox.add_child(row)

	if _show_more_btn:
		_show_more_btn.visible = count < _filtered_events.size()


func _create_event_row(event: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation", SPACING_SM)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Turn badge
	var turn: int = event.get("turn", 0)
	var turn_lbl := Label.new()
	turn_lbl.text = "T%d" % turn
	turn_lbl.custom_minimum_size = Vector2(36, 0)
	turn_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)
	turn_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	turn_lbl.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(turn_lbl)

	# Type badge (colored dot + label)
	var raw_type: String = event.get("type", "other")
	var type_color: Color = EVENT_COLORS.get(
		raw_type, DEFAULT_COLOR)
	var type_label: String = EVENT_LABELS.get(
		raw_type, raw_type.capitalize())

	var badge := Label.new()
	badge.text = type_label
	badge.custom_minimum_size = Vector2(52, 0)
	badge.add_theme_font_size_override(
		"font_size", FONT_SIZE_XS)
	badge.add_theme_color_override("font_color", type_color)
	row.add_child(badge)

	# Description
	var desc := Label.new()
	desc.text = event.get("text", "")
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	desc.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	desc.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS)
	desc.clip_text = true
	row.add_child(desc)

	return row


func _on_show_more() -> void:
	_visible_count += MAX_VISIBLE
	_rebuild_event_list()
