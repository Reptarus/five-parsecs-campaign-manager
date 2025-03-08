@tool
extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/scenes/campaign/components/EventLog.gd")

# Signals
signal event_selected(event_id: String)
signal category_filter_changed(categories: Array)
signal event_action_triggered(event_id: String, action: String)

# Constants
const EVENT_CATEGORIES = {
	"upkeep": {
		"color": Color(0.2, 0.8, 0.2), # Green
		"icon": "res://assets/icons/upkeep.png",
		"description": "Crew and ship maintenance events"
	},
	"world_step": {
		"color": Color(0.4, 0.6, 0.9), # Light Blue
		"icon": "res://assets/icons/world.png",
		"description": "Local events and world activities"
	},
	"travel": {
		"color": Color(0.8, 0.6, 0.2), # Orange
		"icon": "res://assets/icons/travel.png",
		"description": "Travel and exploration events"
	},
	"patrons": {
		"color": Color(0.9, 0.8, 0.2), # Gold
		"icon": "res://assets/icons/patron.png",
		"description": "Patron interactions and job offers"
	},
	"battle": {
		"color": Color(0.8, 0.2, 0.2), # Red
		"icon": "res://assets/icons/battle.png",
		"description": "Combat and mission events"
	},
	"post_battle": {
		"color": Color(0.6, 0.4, 0.8), # Purple
		"icon": "res://assets/icons/post_battle.png",
		"description": "Post-combat outcomes and rewards"
	},
	"management": {
		"color": Color(0.2, 0.6, 1.0), # Blue
		"icon": "res://assets/icons/management.png",
		"description": "Crew and resource management events"
	},
	"story": {
		"color": Color(0.8, 0.4, 1.0), # Bright Purple
		"icon": "res://assets/icons/story.png",
		"description": "Campaign story developments"
	},
	"system": {
		"color": Color(0.7, 0.7, 0.7), # Gray
		"icon": "res://assets/icons/system.png",
		"description": "Game system notifications"
	}
}

# Event priorities
enum EventPriority {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
	CRITICAL = 3
}

# Node references
@onready var event_list: VBoxContainer = $VBoxContainer/MainContent/EventList
@onready var category_filters: HBoxContainer = $VBoxContainer/Filters/Categories
@onready var search_box: LineEdit = $VBoxContainer/Filters/SearchBox
@onready var detail_panel: Panel = $VBoxContainer/DetailPanel
@onready var detail_text: RichTextLabel = $VBoxContainer/DetailPanel/MarginContainer/DetailText

# Properties
var events: Array[Dictionary] = []
var filtered_events: Array[Dictionary] = []
var active_filters: Array[String] = []
var search_query: String = ""
var current_phase: String = ""
var max_events: int = 100 # Maximum number of events to store

# Event item scene
var event_item_scene = preload("res://src/scenes/campaign/components/EventItem.tscn")

# Factory functions for creating events instead of classes

# Generate a unique ID for events
static func _generate_event_id() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000000]

# Create a new event
static func create_event(
	p_title: String,
	p_description: String,
	p_category: String,
	p_phase: String = "",
	p_priority: int = EventPriority.NORMAL
) -> Dictionary:
	return {
		"id": _generate_event_id(),
		"title": p_title,
		"description": p_description,
		"category": p_category,
		"phase": p_phase,
		"priority": p_priority,
		"timestamp": Time.get_unix_time_from_system(),
		"actions": [],
		"metadata": {}
	}

# Add an action to an event
static func add_action(event: Dictionary, action: String) -> void:
	if not action in event.actions:
		event.actions.append(action)

# Add metadata to an event
static func add_metadata(event: Dictionary, key: String, value: Variant) -> void:
	event.metadata[key] = value

# Convert event to a serializable dictionary
static func event_to_dictionary(event: Dictionary) -> Dictionary:
	return event.duplicate(true)

# Create an event from a dictionary
static func event_from_dictionary(data: Dictionary) -> Dictionary:
	var event = create_event(
		data.title,
		data.description,
		data.category,
		data.get("phase", ""),
		data.get("priority", EventPriority.NORMAL)
	)
	
	event.id = data.get("id", event.id)
	event.timestamp = data.get("timestamp", event.timestamp)
	event.actions = data.get("actions", [])
	event.metadata = data.get("metadata", {})
	
	return event

# Get formatted time string from event
static func get_formatted_time(event: Dictionary) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(event.timestamp)
	return "%02d:%02d:%02d" % [datetime.hour, datetime.minute, datetime.second]

# Get formatted date string from event
static func get_formatted_date(event: Dictionary) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(event.timestamp)
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]

# Get formatted date and time string from event
static func get_formatted_datetime(event: Dictionary) -> String:
	return get_formatted_date(event) + " " + get_formatted_time(event)

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	# Set up category filters
	for category in EVENT_CATEGORIES:
		var filter_button = CheckBox.new()
		filter_button.text = category.capitalize()
		filter_button.button_pressed = true
		category_filters.add_child(filter_button)
		filter_button.toggled.connect(_on_category_filter_toggled.bind(category))
		
	# Set up search box
	if search_box:
		search_box.placeholder_text = "Search events..."
		
	# Set up detail panel
	if detail_text:
		detail_text.bbcode_enabled = true
		detail_text.fit_content = true
		
	# Initial update
	_update_event_list()

func _connect_signals() -> void:
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)

func set_phase(phase_name: String) -> void:
	current_phase = phase_name
	_update_event_list()

func _update_event_list() -> void:
	# Clear existing events
	for child in event_list.get_children():
		child.queue_free()
	
	# Apply filters
	filtered_events = events.filter(func(event: Dictionary) -> bool:
		# Category filter
		if not active_filters.is_empty() and not event.category in active_filters:
			return false
			
		# Search filter
		if not search_query.is_empty():
			var search_text = search_query.to_lower()
			var event_text = (event.title + " " + event.description).to_lower()
			if not search_text in event_text:
				return false
				
		return true
	)
	
	# Sort events by priority and timestamp
	filtered_events.sort_custom(func(a, b) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.timestamp > b.timestamp
	)
	
	# Add filtered events
	for event in filtered_events:
		_add_event_item(event)

func _add_event_item(event_data: Dictionary) -> void:
	var event_item = event_item_scene.instantiate()
	event_list.add_child(event_item)
	
	event_item.setup(
		event_data.id,
		event_data.title,
		event_data.description,
		event_data.timestamp,
		EVENT_CATEGORIES[event_data.category].color,
		event_data.priority
	)
	
	# Connect signals
	event_item.event_selected.connect(_on_event_item_selected)
	if not event_data.actions.is_empty():
		event_item.action_triggered.connect(_on_event_action_triggered.bind(event_data.id))

func _on_event_item_selected(event_id: String) -> void:
	_show_event_details(event_id)
	emit_signal("event_selected", event_id)

func _on_event_action_triggered(action: String, event_id: String) -> void:
	emit_signal("event_action_triggered", event_id, action)

func _show_event_details(event_id: String) -> void:
	var event = events.filter(func(e): return e.id == event_id)[0]
	if not event:
		return
		
	var text = "[b]%s[/b]\n\n%s\n\n[color=#888888]%s[/color]" % [
		event.title,
		event.description,
		Time.get_datetime_string_from_unix_time(event.timestamp)
	]
	
	# Add actions if available
	if not event.actions.is_empty():
		text += "\n\n[b]Available Actions:[/b]"
		for action in event.actions:
			text += "\n• %s" % action
	
	if detail_text:
		detail_text.text = text

# Signal handlers
func _on_category_filter_toggled(pressed: bool, category: String) -> void:
	if pressed:
		active_filters.append(category)
	else:
		active_filters.erase(category)
	
	_update_event_list()
	emit_signal("category_filter_changed", active_filters)

func _on_search_text_changed(new_text: String) -> void:
	search_query = new_text
	_update_event_list()

# Public methods
func add_event(event: Dictionary) -> void:
	events.append(event_to_dictionary(event))
	
	# Maintain maximum event count
	while events.size() > max_events:
		events.pop_front()
	
	_update_event_list()

func add_phase_event(
	title: String,
	description: String,
	category: String,
	priority: EventPriority = EventPriority.NORMAL
) -> void:
	var event = create_event(title, description, category, current_phase, priority)
	add_event(event)

func add_story_event(
	title: String,
	description: String,
	priority: EventPriority = EventPriority.HIGH
) -> void:
	var event = create_event(title, description, "story", current_phase, priority)
	add_event(event)

func add_system_event(
	title: String,
	description: String,
	priority: EventPriority = EventPriority.LOW
) -> void:
	var event = create_event(title, description, "system", current_phase, priority)
	add_event(event)

func clear_events() -> void:
	events.clear()
	_update_event_list()

func get_event_count() -> int:
	return events.size()

func get_filtered_event_count() -> int:
	return filtered_events.size()

func get_phase_events(phase: String) -> Array[Dictionary]:
	return events.filter(func(e): return e.phase == phase)

func get_category_events(category: String) -> Array[Dictionary]:
	return events.filter(func(e): return e.category == category)

func set_max_events(count: int) -> void:
	max_events = count
	while events.size() > max_events:
		events.pop_front()
	_update_event_list()

func get_event_by_id(event_id: String) -> Dictionary:
	var matching_events = events.filter(func(e): return e.id == event_id)
	return matching_events[0] if not matching_events.is_empty() else {}

func update_event(event_id: String, updates: Dictionary) -> bool:
	for i in range(events.size()):
		if events[i].id == event_id:
			events[i].merge(updates)
			_update_event_list()
			return true
	return false