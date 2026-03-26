extends PanelContainer

## CampaignTimelinePanel - Shows all campaign journal entries with filtering and export

signal back_pressed()
signal character_selected(character_id: String)

## Deep Space theme colors
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

## Entry type colors for timeline markers
const TYPE_COLORS = {
	"battle": Color("#DC2626"),
	"milestone": Color("#F59E0B"),
	"story": Color("#8B5CF6"),
	"purchase": Color("#10B981"),
	"injury": Color("#EF4444"),
	"custom": Color("#6B7280"),
	# Post-battle entry types (Phase 49)
	"payment": Color("#10B981"),
	"loot": Color("#F59E0B"),
	"experience": Color("#3B82F6"),
	"campaign_event": Color("#8B5CF6"),
	"character_event": Color("#A855F7"),
	"galactic_war": Color("#EF4444"),
}

var _type_filter: String = "all"
var _filtered_entries: Array[Dictionary] = []
var _content_vbox: VBoxContainer = null
var _stats_container: VBoxContainer = null
var _export_dialog: FileDialog = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# Header
	_add_header(main_vbox)

	# Filter bar
	_add_filter_bar(main_vbox)

	# Stats summary
	_add_stats_summary(main_vbox)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Scrollable entries
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_content_vbox)

	# Export buttons
	_add_export_bar(main_vbox)

	# Load initial entries
	_refresh_entries()

func _add_header(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var back_btn = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.pressed.connect(func(): back_pressed.emit())
	hbox.add_child(back_btn)

	var title = Label.new()
	title.text = "Campaign Timeline"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

func _add_filter_bar(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hbox.add_child(filter_label)

	var type_filter = OptionButton.new()
	type_filter.add_item("All Types", 0)
	type_filter.add_item("Battles", 1)
	type_filter.add_item("Milestones", 2)
	type_filter.add_item("Story", 3)
	type_filter.add_item("Purchases", 4)
	type_filter.add_item("Injuries", 5)
	type_filter.add_item("Custom", 6)
	type_filter.add_item("Payment", 7)
	type_filter.add_item("Loot", 8)
	type_filter.add_item("Experience", 9)
	type_filter.add_item("Campaign Events", 10)
	type_filter.add_item("Galactic War", 11)
	type_filter.custom_minimum_size = Vector2(160, 36)
	type_filter.item_selected.connect(_on_type_filter_changed)
	hbox.add_child(type_filter)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Entry count label
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	count_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(count_label)

func _add_stats_summary(parent: VBoxContainer) -> void:
	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 4)
	parent.add_child(_stats_container)
	_refresh_stats()

func _refresh_stats() -> void:
	if not _stats_container:
		return

	for child in _stats_container.get_children():
		child.queue_free()

	var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
	if not journal:
		return

	var card = _create_card()
	_stats_container.add_child(card)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	card.add_child(grid)

	var crew_stats = journal.get_crew_stats_summary()

	var stat_items = [
		["Crew", crew_stats.get("total_characters", 0)],
		["Total Kills", crew_stats.get("total_kills", 0)],
		["Total Battles", crew_stats.get("total_battles", 0)],
		["Total Injuries", crew_stats.get("total_injuries", 0)],
	]

	for item in stat_items:
		var stat_vbox = VBoxContainer.new()
		stat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(stat_vbox)

		var value_label = Label.new()
		value_label.text = str(item[1])
		value_label.add_theme_font_size_override("font_size", 20)
		value_label.add_theme_color_override("font_color", COLOR_ACCENT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_vbox.add_child(value_label)

		var name_label = Label.new()
		name_label.text = item[0]
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_vbox.add_child(name_label)

	# Top performers section
	var performers = journal.get_top_performers("kills", 3)
	if performers.size() > 0:
		var perf_label = Label.new()
		perf_label.text = "Top Performers (Kills)"
		perf_label.add_theme_font_size_override("font_size", 14)
		perf_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		_stats_container.add_child(perf_label)

		var perf_hbox = HBoxContainer.new()
		perf_hbox.add_theme_constant_override("separation", 12)
		_stats_container.add_child(perf_hbox)

		for perf in performers:
			if perf.value > 0:
				var perf_item = Label.new()
				perf_item.text = "%s: %d" % [perf.character_id, perf.value]
				perf_item.add_theme_font_size_override("font_size", 13)
				perf_item.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
				perf_hbox.add_child(perf_item)

func _add_export_bar(parent: VBoxContainer) -> void:
	var sep = HSeparator.new()
	parent.add_child(sep)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(hbox)

	var md_btn = Button.new()
	md_btn.text = "Export Markdown"
	md_btn.custom_minimum_size = Vector2(140, 36)
	md_btn.pressed.connect(func(): _show_export_dialog("markdown"))
	hbox.add_child(md_btn)

	var json_btn = Button.new()
	json_btn.text = "Export JSON"
	json_btn.custom_minimum_size = Vector2(120, 36)
	json_btn.pressed.connect(func(): _show_export_dialog("json"))
	hbox.add_child(json_btn)

func _on_type_filter_changed(index: int) -> void:
	var type_map = {0: "all", 1: "battle", 2: "milestone", 3: "story", 4: "purchase", 5: "injury", 6: "custom", 7: "payment", 8: "loot", 9: "experience", 10: "campaign_event", 11: "galactic_war"}
	_type_filter = type_map.get(index, "all")
	_refresh_entries()

func _refresh_entries() -> void:
	if not _content_vbox:
		return

	for child in _content_vbox.get_children():
		child.queue_free()

	var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
	if not journal:
		var empty_label = Label.new()
		empty_label.text = "Campaign Journal not available"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_content_vbox.add_child(empty_label)
		return

	if _type_filter == "all":
		_filtered_entries = journal.get_all_entries()
	else:
		_filtered_entries = journal.filter_entries({"type": _type_filter})

	# Update count label
	var count_label = _find_node_by_name(self, "CountLabel")
	if count_label:
		count_label.text = "%d entries" % _filtered_entries.size()

	if _filtered_entries.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No journal entries yet. Entries are automatically created during battles and milestones."
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(empty_label)
		return

	# Display entries newest first
	var display_entries = _filtered_entries.duplicate()
	display_entries.reverse()

	for entry in display_entries:
		_add_entry_card(entry)

func _add_entry_card(entry: Dictionary) -> void:
	var card = _create_card()
	_content_vbox.add_child(card)

	var entry_vbox = VBoxContainer.new()
	entry_vbox.add_theme_constant_override("separation", 4)
	card.add_child(entry_vbox)

	# Header row: type badge + title + turn
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	entry_vbox.add_child(header_hbox)

	# Type badge
	var type_label = Label.new()
	var entry_type = entry.get("type", "custom")
	type_label.text = "[%s]" % entry_type.to_upper()
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", TYPE_COLORS.get(entry_type, COLOR_TEXT_SECONDARY))
	header_hbox.add_child(type_label)

	# Title
	var title_label = Label.new()
	title_label.text = entry.get("title", "Untitled")
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	# Turn number
	var turn_label = Label.new()
	turn_label.text = "Turn %d" % entry.get("turn_number", 0)
	turn_label.add_theme_font_size_override("font_size", 12)
	turn_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	header_hbox.add_child(turn_label)

	# Description
	var desc = entry.get("description", "")
	if not desc.is_empty():
		var desc_label = Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry_vbox.add_child(desc_label)

	# Stats row if present
	var stats = entry.get("stats", {})
	if not stats.is_empty():
		var stats_hbox = HBoxContainer.new()
		stats_hbox.add_theme_constant_override("separation", 16)
		entry_vbox.add_child(stats_hbox)

		for key in stats.keys():
			var stat_label = Label.new()
			stat_label.text = "%s: %s" % [key.replace("_", " ").capitalize(), str(stats[key])]
			stat_label.add_theme_font_size_override("font_size", 11)
			stat_label.add_theme_color_override("font_color", COLOR_ACCENT)
			stats_hbox.add_child(stat_label)

	# Tags
	var tags = entry.get("tags", [])
	if tags.size() > 0:
		var tags_label = Label.new()
		tags_label.text = "Tags: " + ", ".join(tags)
		tags_label.add_theme_font_size_override("font_size", 11)
		tags_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		entry_vbox.add_child(tags_label)

	# Player notes
	var notes = entry.get("player_notes", "")
	if not notes.is_empty():
		var notes_label = Label.new()
		notes_label.text = "Notes: " + notes
		notes_label.add_theme_font_size_override("font_size", 12)
		notes_label.add_theme_color_override("font_color", COLOR_WARNING)
		notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry_vbox.add_child(notes_label)

func _show_export_dialog(format: String) -> void:
	if _export_dialog and is_instance_valid(_export_dialog):
		_export_dialog.queue_free()

	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.title = "Export Campaign Journal"

	if format == "markdown":
		_export_dialog.add_filter("*.md", "Markdown Files")
		_export_dialog.current_file = "campaign_journal.md"
	else:
		_export_dialog.add_filter("*.json", "JSON Files")
		_export_dialog.current_file = "campaign_journal.json"

	_export_dialog.file_selected.connect(func(path: String): _do_export(format, path))
	add_child(_export_dialog)
	_export_dialog.popup_centered(Vector2i(600, 400))

func _do_export(format: String, path: String) -> void:
	var journal = Engine.get_main_loop().root.get_node_or_null("CampaignJournal")
	if not journal:
		push_error("CampaignJournal not available for export")
		return

	var success = false
	if format == "markdown":
		success = journal.export_to_markdown(path)
	else:
		success = journal.export_to_json(path)

	if success:
		pass
	else:
		push_error("CampaignTimelinePanel: Export failed for %s" % path)

func _create_card() -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null
