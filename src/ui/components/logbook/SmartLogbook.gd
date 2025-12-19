# SmartLogbook - Campaign Turn History Browser
# Displays all historical events per campaign turn in chronological order
class_name SmartLogbook
extends Control

# ============ DESIGN SYSTEM CONSTANTS ============
const SPACING_MD := 16
const SPACING_SM := 8
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

# ============ NODE REFERENCES ============
@onready var search_bar: LineEdit = $MarginContainer/VBoxContainer/SearchBar
@onready var filter_panel: HBoxContainer = $MarginContainer/VBoxContainer/FilterPanel
@onready var suggestions_panel: VBoxContainer = $MarginContainer/VBoxContainer/SuggestionsPanel
@onready var crew_select: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/CrewSelect
@onready var entry_list: ItemList = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/EntryList
@onready var new_entry_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/ButtonsContainer/NewEntryButton
@onready var delete_entry_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/ButtonsContainer/DeleteEntryButton
@onready var export_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/ExportButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/BackButton
@onready var logbook_entries: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/LogbookEntries
@onready var search_results: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/SearchResults
@onready var entry_content: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/EntryContent
@onready var notes_edit: TextEdit = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/NotesEdit
@onready var save_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/SaveButton
@onready var analysis_summary: Label = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/AnalysisSummary

# ============ STATE ============
var current_campaign = null
var turn_history: Array[Dictionary] = []
var selected_turn: int = -1
var current_filter: String = "all"  # all, travel, world, battle, postbattle, crew, resource

# Event type icons and colors for display
const EVENT_TYPE_CONFIG = {
	"travel": {"icon": "\u2708", "color": "#4FC3F7", "name": "Travel"},
	"world": {"icon": "\ud83c\udf0d", "color": "#81C784", "name": "World"},
	"battle": {"icon": "\u2694", "color": "#EF5350", "name": "Battle"},
	"postbattle": {"icon": "\ud83c\udfc6", "color": "#FFD54F", "name": "Post-Battle"},
	"crew": {"icon": "\ud83d\udc65", "color": "#9575CD", "name": "Crew"},
	"resource": {"icon": "\ud83d\udcb0", "color": "#4DB6AC", "name": "Resource"},
	"story": {"icon": "\ud83d\udcd6", "color": "#FF8A65", "name": "Story"},
	"unknown": {"icon": "\u2022", "color": "#808080", "name": "Other"}
}

func _ready() -> void:
	print("SmartLogbook: Initializing...")

	# Hide elements not needed for read-only history view
	if new_entry_button:
		new_entry_button.visible = false
	if delete_entry_button:
		delete_entry_button.visible = false
	if notes_edit:
		notes_edit.visible = false
	if save_button:
		save_button.visible = false

	# Setup filter buttons
	_setup_filter_panel()

	# Setup crew selector (will show turn filter options)
	_setup_turn_filter()

	# Connect signals
	if search_bar:
		search_bar.text_changed.connect(_on_search_text_changed)

	# Load campaign data
	_load_campaign_history()

	print("SmartLogbook: Ready")

func _setup_filter_panel() -> void:
	"""Create filter buttons for event types"""
	if not filter_panel:
		return

	# Clear existing children
	for child in filter_panel.get_children():
		child.queue_free()

	# Add "All" filter button
	var all_btn = Button.new()
	all_btn.text = "All"
	all_btn.toggle_mode = true
	all_btn.button_pressed = true
	all_btn.pressed.connect(_on_filter_pressed.bind("all"))
	filter_panel.add_child(all_btn)

	# Add filter buttons for each event type
	for event_type in EVENT_TYPE_CONFIG:
		if event_type == "unknown":
			continue
		var config = EVENT_TYPE_CONFIG[event_type]
		var btn = Button.new()
		btn.text = "%s %s" % [config.icon, config.name]
		btn.toggle_mode = true
		btn.pressed.connect(_on_filter_pressed.bind(event_type))
		filter_panel.add_child(btn)

func _setup_turn_filter() -> void:
	"""Setup turn selection dropdown"""
	if not crew_select:
		return

	crew_select.clear()
	crew_select.add_item("All Turns")

func _load_campaign_history() -> void:
	"""Load turn history from the current campaign"""
	if not GameStateManager:
		push_error("SmartLogbook: GameStateManager not available")
		_show_empty_state()
		return

	var game_state = GameStateManager.game_state
	if not game_state:
		push_warning("SmartLogbook: No active game state")
		_show_empty_state()
		return

	# Try to get current campaign
	if "current_campaign" in game_state and game_state.current_campaign:
		current_campaign = game_state.current_campaign
	else:
		push_warning("SmartLogbook: No active campaign")
		_show_empty_state()
		return

	# Get turn history from campaign
	if current_campaign.has_method("get_full_history"):
		turn_history = current_campaign.get_full_history()
	elif "turn_history" in current_campaign:
		turn_history = current_campaign.turn_history
	else:
		turn_history = []

	print("SmartLogbook: Loaded %d turns of history" % turn_history.size())

	# Populate UI
	_populate_turn_list()
	_update_analysis_summary()

func _show_empty_state() -> void:
	"""Display empty state when no history available"""
	if entry_content:
		entry_content.text = "[center][color=#808080]No campaign history available.\n\nStart a campaign and complete some turns to see your adventure chronicle here.[/color][/center]"

	if entry_list:
		entry_list.clear()
		entry_list.add_item("No history")

	if analysis_summary:
		analysis_summary.text = "Analysis: No campaign data"

func _populate_turn_list() -> void:
	"""Populate the sidebar list with turns"""
	if not entry_list:
		return

	entry_list.clear()

	if turn_history.is_empty():
		entry_list.add_item("No turns recorded")
		return

	# Add turns in reverse order (newest first)
	for i in range(turn_history.size() - 1, -1, -1):
		var turn_entry = turn_history[i]
		var turn_num: int = turn_entry.get("turn", 0)
		var events: Array = turn_entry.get("events", [])
		var event_count: int = events.size()

		var label = "Turn %d (%d events)" % [turn_num, event_count]
		entry_list.add_item(label)
		entry_list.set_item_metadata(entry_list.item_count - 1, turn_num)

	# Update crew_select with turn numbers
	if crew_select:
		crew_select.clear()
		crew_select.add_item("All Turns")
		for i in range(turn_history.size() - 1, -1, -1):
			var turn_num: int = turn_history[i].get("turn", 0)
			crew_select.add_item("Turn %d" % turn_num)
			crew_select.set_item_metadata(crew_select.item_count - 1, turn_num)

func _update_analysis_summary() -> void:
	"""Generate analysis summary from history data"""
	if not analysis_summary:
		return

	if turn_history.is_empty():
		analysis_summary.text = "Analysis: No campaign data"
		return

	# Count events by type
	var event_counts: Dictionary = {}
	var total_events: int = 0

	for turn_entry in turn_history:
		var events: Array = turn_entry.get("events", [])
		for event in events:
			var event_type: String = event.get("event_type", "unknown")
			if not event_counts.has(event_type):
				event_counts[event_type] = 0
			event_counts[event_type] += 1
			total_events += 1

	# Build summary
	var summary_parts: Array[String] = []
	summary_parts.append("Turns: %d" % turn_history.size())
	summary_parts.append("Events: %d" % total_events)

	# Add top event types
	var sorted_types: Array = event_counts.keys()
	sorted_types.sort_custom(func(a, b): return event_counts[a] > event_counts[b])

	for i in range(mini(3, sorted_types.size())):
		var event_type: String = sorted_types[i]
		var config = EVENT_TYPE_CONFIG.get(event_type, EVENT_TYPE_CONFIG.unknown)
		summary_parts.append("%s: %d" % [config.name, event_counts[event_type]])

	analysis_summary.text = "Analysis: " + " | ".join(summary_parts)

func _on_entry_selected(index: int) -> void:
	"""Handle turn selection from list"""
	if not entry_list or index < 0:
		return

	var turn_num = entry_list.get_item_metadata(index)
	if turn_num == null:
		return

	selected_turn = turn_num
	_display_turn_details(turn_num)

func _display_turn_details(turn_num: int) -> void:
	"""Display detailed events for a specific turn"""
	if not entry_content:
		return

	# Find turn entry
	var turn_entry: Dictionary = {}
	for entry in turn_history:
		if entry.get("turn", -1) == turn_num:
			turn_entry = entry
			break

	if turn_entry.is_empty():
		entry_content.text = "[color=#808080]Turn %d: No data[/color]" % turn_num
		return

	var events: Array = turn_entry.get("events", [])
	var date: String = turn_entry.get("date", "Unknown")

	# Build BBCode content
	var bbcode: String = ""
	bbcode += "[font_size=24][b]CAMPAIGN TURN %d[/b][/font_size]\n" % turn_num
	bbcode += "[color=#808080]%s[/color]\n\n" % date

	if events.is_empty():
		bbcode += "[color=#808080]No events recorded for this turn.[/color]"
	else:
		# Filter events if needed
		var filtered_events = events
		if current_filter != "all":
			filtered_events = events.filter(func(e): return e.get("event_type", "").to_lower() == current_filter)

		if filtered_events.is_empty():
			bbcode += "[color=#808080]No %s events in this turn.[/color]" % current_filter
		else:
			for event in filtered_events:
				bbcode += _format_event(event) + "\n"

	entry_content.text = bbcode

func _format_event(event: Dictionary) -> String:
	"""Format a single event as BBCode"""
	var event_type: String = event.get("event_type", "unknown").to_lower()
	var config = EVENT_TYPE_CONFIG.get(event_type, EVENT_TYPE_CONFIG.unknown)
	var phase: String = event.get("phase", "")
	var description: String = event.get("description", "No description")

	var result: String = ""
	result += "[color=%s]%s[/color] " % [config.color, config.icon]

	if not phase.is_empty():
		result += "[color=#808080][%s][/color] " % phase

	result += "[color=%s]%s[/color]" % [config.color, config.name.to_upper()]
	result += "\n   %s\n" % description

	# Add any additional data in a structured way
	var data: Dictionary = event.get("data", {})
	if not data.is_empty():
		for key in data:
			var value = data[key]
			if value != null and str(value) != "":
				result += "   [color=#808080]%s:[/color] %s\n" % [key.capitalize(), str(value)]

	return result

func _on_filter_pressed(filter_type: String) -> void:
	"""Handle filter button press"""
	current_filter = filter_type

	# Update button states
	if filter_panel:
		for child in filter_panel.get_children():
			if child is Button and child.toggle_mode:
				var btn_filter = "all"
				if child.text != "All":
					# Extract filter type from button text
					for etype in EVENT_TYPE_CONFIG:
						if EVENT_TYPE_CONFIG[etype].name in child.text:
							btn_filter = etype
							break
				child.button_pressed = (btn_filter == filter_type)

	# Refresh display if a turn is selected
	if selected_turn >= 0:
		_display_turn_details(selected_turn)

	print("SmartLogbook: Filter changed to '%s'" % filter_type)

func _on_search_text_changed(new_text: String) -> void:
	"""Handle search input"""
	if new_text.is_empty():
		# Show normal turn list
		_populate_turn_list()
		if search_results:
			search_results.visible = false
		return

	# Search through all events
	_perform_search(new_text)

func _perform_search(query: String) -> void:
	"""Search through all turn events"""
	var query_lower = query.to_lower()
	var results: Array[Dictionary] = []

	for turn_entry in turn_history:
		var turn_num: int = turn_entry.get("turn", 0)
		var events: Array = turn_entry.get("events", [])

		for event in events:
			var description: String = event.get("description", "")
			var event_type: String = event.get("event_type", "")
			var phase: String = event.get("phase", "")

			# Search in description, event_type, and phase
			if description.to_lower().contains(query_lower) \
				or event_type.to_lower().contains(query_lower) \
				or phase.to_lower().contains(query_lower):
				results.append({
					"turn": turn_num,
					"event": event
				})

	_display_search_results(results, query)

func _display_search_results(results: Array, query: String) -> void:
	"""Display search results"""
	if not entry_content:
		return

	var bbcode: String = ""
	bbcode += "[font_size=20][b]SEARCH RESULTS[/b][/font_size]\n"
	bbcode += "[color=#808080]Found %d matches for \"%s\"[/color]\n\n" % [results.size(), query]

	if results.is_empty():
		bbcode += "[color=#808080]No events match your search.[/color]"
	else:
		for result in results:
			var turn_num: int = result.turn
			var event: Dictionary = result.event
			bbcode += "[color=#4FC3F7]Turn %d:[/color] " % turn_num
			bbcode += _format_event(event) + "\n"

	entry_content.text = bbcode

func _on_search_submitted(query: String) -> void:
	"""Handle search submission"""
	_perform_search(query)

func _on_crew_selected(index: int) -> void:
	"""Handle turn selection from dropdown"""
	if not crew_select or index < 0:
		return

	if index == 0:
		# "All Turns" selected - show summary
		_display_all_turns_summary()
	else:
		var turn_num = crew_select.get_item_metadata(index)
		if turn_num != null:
			selected_turn = turn_num
			_display_turn_details(turn_num)

func _display_all_turns_summary() -> void:
	"""Display summary of all turns"""
	if not entry_content:
		return

	selected_turn = -1

	var bbcode: String = ""
	bbcode += "[font_size=24][b]CAMPAIGN CHRONICLE[/b][/font_size]\n"
	bbcode += "[color=#808080]Complete history of your campaign[/color]\n\n"

	if turn_history.is_empty():
		bbcode += "[color=#808080]Your adventure awaits. Complete campaign turns to see your chronicle grow.[/color]"
	else:
		# Show recent events from each turn
		for i in range(turn_history.size() - 1, -1, -1):
			var turn_entry = turn_history[i]
			var turn_num: int = turn_entry.get("turn", 0)
			var events: Array = turn_entry.get("events", [])

			bbcode += "[font_size=18][b]Turn %d[/b][/font_size]\n" % turn_num

			if events.is_empty():
				bbcode += "   [color=#808080]No events recorded[/color]\n\n"
			else:
				# Show first 3 events per turn in summary
				var shown = 0
				for event in events:
					if shown >= 3:
						bbcode += "   [color=#808080]... and %d more events[/color]\n" % (events.size() - 3)
						break
					bbcode += _format_event(event)
					shown += 1
				bbcode += "\n"

	entry_content.text = bbcode

func _on_new_entry_pressed() -> void:
	"""Not used for read-only logbook"""
	pass

func _on_delete_entry_pressed() -> void:
	"""Not used for read-only logbook"""
	pass

func _on_export_pressed() -> void:
	"""Export logbook to text file"""
	print("SmartLogbook: Export requested")

	# Generate export text
	var export_text: String = _generate_export_text()

	# Copy to clipboard (simple export)
	DisplayServer.clipboard_set(export_text)

	# Show feedback
	if analysis_summary:
		analysis_summary.text = "Logbook copied to clipboard!"
		# Reset after 2 seconds
		await get_tree().create_timer(2.0).timeout
		_update_analysis_summary()

func _generate_export_text() -> String:
	"""Generate plain text export of the logbook"""
	var text: String = "CAMPAIGN CHRONICLE\n"
	text += "===================\n\n"

	if current_campaign and "campaign_name" in current_campaign:
		text += "Campaign: %s\n" % current_campaign.campaign_name

	text += "Exported: %s\n\n" % Time.get_datetime_string_from_system()

	for turn_entry in turn_history:
		var turn_num: int = turn_entry.get("turn", 0)
		var date: String = turn_entry.get("date", "")
		var events: Array = turn_entry.get("events", [])

		text += "--- TURN %d ---\n" % turn_num
		if not date.is_empty():
			text += "Date: %s\n" % date

		for event in events:
			var config = EVENT_TYPE_CONFIG.get(event.get("event_type", "unknown"), EVENT_TYPE_CONFIG.unknown)
			text += "[%s] %s\n" % [config.name, event.get("description", "")]

		text += "\n"

	return text

func _on_save_notes_pressed() -> void:
	"""Not used for read-only logbook"""
	pass

func _on_back_pressed() -> void:
	"""Return to previous screen"""
	print("SmartLogbook: Back pressed")

	# Try SceneRouter navigation
	if SceneRouter and SceneRouter.has_method("navigate_back"):
		SceneRouter.navigate_back()
		return

	# Fallback to campaign dashboard
	if GameStateManager and GameStateManager.has_method("navigate_to_screen"):
		GameStateManager.navigate_to_screen("campaign_dashboard")
