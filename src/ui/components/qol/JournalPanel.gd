extends ResponsiveContainer
class_name JournalPanel

## JournalPanel - Campaign journal UI
## Displays timeline, entries, and character histories

signal entry_selected(entry_id: String)
signal new_entry_requested()
signal export_requested(format: String)

## UI references
@onready var view_mode_buttons = $Header/ViewModeButtons
@onready var timeline_button = $Header/ViewModeButtons/TimelineButton
@onready var entries_button = $Header/ViewModeButtons/EntriesButton
@onready var search_box = $Header/SearchBox
@onready var content_container = $ScrollContainer/Content
@onready var action_bar = $ActionBar

## State
var current_view_mode: String = "entries"  # "entries" or "timeline"
var filtered_entries: Array[Dictionary] = []

func _ready() -> void:
	_setup_signals()
	_load_entries()

func _setup_signals() -> void:
	## Connect UI signals
	if timeline_button:
		timeline_button.pressed.connect(func(): set_view_mode("timeline"))
	if entries_button:
		entries_button.pressed.connect(func(): set_view_mode("entries"))
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
	
	# Connect to journal system
	CampaignJournal.entry_created.connect(_on_entry_created)
	CampaignJournal.entry_updated.connect(_on_entry_updated)
	CampaignJournal.entry_deleted.connect(_on_entry_deleted)

func set_view_mode(mode: String) -> void:
	## Switch between timeline and entries view
	current_view_mode = mode
	_refresh_view()

func _load_entries() -> void:
	## Load all journal entries
	filtered_entries = CampaignJournal.get_all_entries()
	_refresh_view()

func _refresh_view() -> void:
	## Refresh the current view
	_clear_content()
	
	match current_view_mode:
		"entries":
			_display_entries_view()
		"timeline":
			_display_timeline_view()

func _clear_content() -> void:
	## Clear content container
	if not content_container:
		return
	for child in content_container.get_children():
		child.queue_free()

func _display_entries_view() -> void:
	## Display entries as list
	for entry in filtered_entries:
		var entry_card = _create_entry_card(entry)
		content_container.add_child(entry_card)

func _display_timeline_view() -> void:
	## Display timeline visualization
	var timeline_data = CampaignJournal.get_timeline_data()
	
	# Create timeline items
	for entry in timeline_data.entries:
		var timeline_item = _create_timeline_item(entry)
		content_container.add_child(timeline_item)

func _create_entry_card(entry: Dictionary) -> Control:
	## Create a journal entry card
	var card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	
	# Header with turn and title
	var header = Label.new()
	header.text = "Turn %d - %s" % [entry.turn_number, entry.title]
	header.add_theme_font_size_override("font_size", 18)
	card.add_child(header)
	
	# Description
	var description = Label.new()
	description.text = entry.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description)
	
	# Tags
	if not entry.tags.is_empty():
		var tags_label = Label.new()
		tags_label.text = "Tags: " + ", ".join(entry.tags)
		tags_label.modulate = Color(0.7, 0.7, 0.7)
		card.add_child(tags_label)
	
	# Make clickable
	var button = Button.new()
	button.flat = true
	button.pressed.connect(func(): entry_selected.emit(entry.id))
	card.add_child(button)
	
	return card

func _create_timeline_item(entry: Dictionary) -> Control:
	## Create a timeline visualization item
	var item = HBoxContainer.new()
	
	# Turn marker
	var turn_label = Label.new()
	turn_label.text = "Turn %d" % entry.turn_number
	turn_label.custom_minimum_size = Vector2(80, 0)
	item.add_child(turn_label)
	
	# Connector line
	var line = ColorRect.new()
	line.color = Color(0.5, 0.5, 0.5)
	line.custom_minimum_size = Vector2(20, 2)
	item.add_child(line)
	
	# Entry title
	var title = Label.new()
	title.text = _get_entry_icon(entry.type) + " " + entry.title
	item.add_child(title)
	
	return item

func _get_entry_icon(entry_type: String) -> String:
	## Get icon emoji for entry type
	var icons = {
		"battle": "⚔️",
		"milestone": "🏆",
		"story": "📖",
		"purchase": "💰",
		"injury": "⚠️",
		"custom": "📝"
	}
	return icons.get(entry_type, "•")

## ===== SEARCH & FILTER =====

func _on_search_changed(query: String) -> void:
	## Filter entries by search query
	if query.is_empty():
		filtered_entries = CampaignJournal.get_all_entries()
	else:
		filtered_entries = []
		for entry in CampaignJournal.get_all_entries():
			if entry.title.to_lower().contains(query.to_lower()) or \
			   entry.description.to_lower().contains(query.to_lower()):
				filtered_entries.append(entry)
	
	_refresh_view()

## ===== JOURNAL EVENTS =====

func _on_entry_created(entry: Dictionary) -> void:
	## Handle new entry creation
	_load_entries()

func _on_entry_updated(entry_id: String) -> void:
	## Handle entry update
	_refresh_view()

func _on_entry_deleted(entry_id: String) -> void:
	## Handle entry deletion
	_load_entries()

## ===== ACTIONS =====

func _on_new_entry_pressed() -> void:
	## Request new manual entry
	new_entry_requested.emit()

func _on_export_pressed(format: String) -> void:
	## Request export in format (pdf/markdown/json)
	export_requested.emit(format)
