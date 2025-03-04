@tool
extends Control
class_name FPCM_EventLog

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

class EventData:
	var id: String
	var title: String
	var description: String
	var category: String
	var timestamp: int
	var priority: EventPriority
	var phase: String
	var actions: Array[Dictionary]
	var metadata: Dictionary
	
	func _init(
		p_title: String,
		p_description: String,
		p_category: String,
		p_phase: String,
		p_priority: EventPriority = EventPriority.NORMAL
	) -> void:
		id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
		title = p_title
		description = p_description
		category = p_category
		phase = p_phase
		priority = p_priority
		timestamp = Time.get_unix_time_from_system()
		actions = []
		metadata = {}
	
	func add_action(action_name: String, action_description: String) -> void:
		actions.append({
			"name": action_name,
			"description": action_description
		})
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"title": title,
			"description": description,
			"category": category,
			"phase": phase,
			"priority": priority,
			"timestamp": timestamp,
			"actions": actions,
			"metadata": metadata
		}
	
	static func from_dictionary(data: Dictionary) -> EventData:
		var event = EventData.new(
			data.title,
			data.description,
			data.category,
			data.phase,
			data.priority
		)
		event.id = data.id
		event.timestamp = data.timestamp
		event.actions = data.actions
		event.metadata = data.metadata
		return event

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
			text += "\n• %s: %s" % [action.name, action.description]
	
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
func add_event(event: EventData) -> void:
	var event_dict = event.to_dictionary()
	events.append(event_dict)
	
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
	var event = EventData.new(title, description, category, current_phase, priority)
	add_event(event)

func add_story_event(
	title: String,
	description: String,
	priority: EventPriority = EventPriority.HIGH
) -> void:
	var event = EventData.new(title, description, "story", current_phase, priority)
	add_event(event)

func add_system_event(
	title: String,
	description: String,
	priority: EventPriority = EventPriority.LOW
) -> void:
	var event = EventData.new(title, description, "system", current_phase, priority)
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