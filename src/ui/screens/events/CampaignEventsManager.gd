class_name CampaignEventsManagerUI
extends Control

signal event_resolved(event: Dictionary, choice: String)
signal event_skipped(event: Dictionary)

@onready var event_type_selector: OptionButton = %EventTypeSelector
@onready var last_roll: Label = %LastRoll
@onready var event_content: VBoxContainer = %EventContent
@onready var history_container: VBoxContainer = %HistoryContainer
@onready var resolve_event_button: Button = %ResolveEventButton

var current_event: Dictionary = {}
var event_history: Array[Dictionary] = []

# Event tables (simplified for demonstration)
var campaign_events: Array[Dictionary] = [
	{"roll": 1, "title": "Patron Contact", "description": "A patron offers you a special job opportunity."},
	{"roll": 2, "title": "Rival Appears", "description": "An old rival shows up in the area."},
	{"roll": 3, "title": "Equipment Malfunction", "description": "One piece of equipment breaks down."},
	{"roll": 4, "title": "Information Broker", "description": "Someone offers valuable information for a price."},
	{"roll": 5, "title": "Local Trouble", "description": "The local authorities are cracking down."},
	{"roll": 6, "title": "Lucky Break", "description": "Something good happens unexpectedly."}
]

var character_events: Array[Dictionary] = [
	{"roll": 1, "title": "Character Development", "description": "A crew member gains insight and experience."},
	{"roll": 2, "title": "Personal Mission", "description": "A crew member has a personal matter to attend to."},
	{"roll": 3, "title": "Old Enemy", "description": "Someone from a crew member's past appears."},
	{"roll": 4, "title": "Romance", "description": "A crew member develops a romantic interest."},
	{"roll": 5, "title": "Family News", "description": "A crew member receives news from home."},
	{"roll": 6, "title": "Skill Discovery", "description": "A crew member discovers a hidden talent."}
]

var travel_events: Array[Dictionary] = [
	{"roll": 1, "title": "Navigation Error", "description": "You get lost and use extra fuel."},
	{"roll": 2, "title": "Distress Signal", "description": "You receive a distress call from another ship."},
	{"roll": 3, "title": "Pirates", "description": "Space pirates demand payment for safe passage."},
	{"roll": 4, "title": "Asteroid Field", "description": "You must navigate through dangerous asteroids."},
	{"roll": 5, "title": "Fuel Station", "description": "You discover a discount fuel station."},
	{"roll": 6, "title": "Smooth Journey", "description": "Travel proceeds without incident."}
]

func _ready() -> void:
	print("CampaignEventsManager: Initializing...")
	_refresh_display()

func _refresh_display() -> void:
	"""Refresh the event display"""
	_update_current_event_display()
	_refresh_history_display()

func _update_current_event_display() -> void:
	"""Update the current event display"""
	# Clear existing content
	for child in event_content.get_children():
		child.queue_free()

	if (safe_call_method(current_event, "is_empty") == true):
		var no_event_label: Label = Label.new()
		no_event_label.text = "No current event"
		no_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_content.add_child(no_event_label)
		resolve_event_button.disabled = true
		return

	# Event title
	var title_label: Label = Label.new()
	title_label.text = current_event.title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_content.add_child(title_label)

	# Event description
	var desc_label: Label = Label.new()
	desc_label.text = current_event.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_content.add_child(desc_label)

	# Add choices if available
	if current_event.has("choices"):
		var choices_label: Label = Label.new()
		choices_label.text = "Choose your response:"
		choices_label.add_theme_font_size_override("font_size", 16)
		event_content.add_child(choices_label)

		for choice in current_event.choices:
			var choice_button: Button = Button.new()
			choice_button.text = choice.text
			choice_button.pressed.connect(_on_choice_selected.bind(choice.id))
			event_content.add_child(choice_button)

	resolve_event_button.disabled = false

func _refresh_history_display() -> void:
	"""Refresh the event history display"""
	# Clear existing history
	for child in history_container.get_children():
		child.queue_free()

	# Add recent events (last 10)
	var recent_events = event_history.slice(-10)
	for event in recent_events:
		var event_panel: Panel = _create_history_panel(event)
		history_container.add_child(event_panel)

func _create_history_panel(event: Dictionary) -> Control:
	"""Create a panel for event history"""
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Event title and type
	var title_label: Label = Label.new()
	title_label.text = event.title + " (" + event.type + ")"
	title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_label)

	# Event result if resolved
	if event.has("result"):
		var result_label: Label = Label.new()
		result_label.text = "Result: " + event.result
		result_label.add_theme_font_size_override("font_size", 10)
		result_label.modulate = Color.GREEN
		vbox.add_child(result_label)

	return panel

func _get_event_table(event_type: String) -> Array[Dictionary]:
	"""Get the appropriate event table"""
	match event_type:
		"campaign":
			return campaign_events
		"character":
			return character_events
		"travel":
			return travel_events
		_:
			return campaign_events

func _roll_on_table(table: Array[Dictionary]) -> Dictionary:
	"""Roll on an event table"""
	var roll = randi_range(1, 6) # D6 roll for simplified tables

	for event in table:
		if event.roll == roll:
			var result: Variant = event.duplicate()
			result["roll_result"] = roll
			return result

	# Fallback
	return table[0].duplicate()

func _get_event_type_name(index: int) -> String:
	"""Get event type name from selector index"""
	match index:
		0:
			return "campaign"
		1:
			return "character"
		2:
			return "travel"
		_:
			return "campaign"

func _on_roll_event_pressed() -> void:
	"""Handle roll event button press"""
	var event_type_index = event_type_selector.selected
	var event_type = _get_event_type_name(event_type_index)
	var event_table = _get_event_table(event_type)

	# Roll for event
	var rolled_event = _roll_on_table(event_table)
	rolled_event["type"] = event_type
	rolled_event["timestamp"] = Time.get_unix_time_from_system()

	# Set as current event
	current_event = rolled_event

	# Update display
	last_roll.text = "Rolled: " + str(rolled_event.roll_result) + " (" + event_type.capitalize() + ")"
	_update_current_event_display()

	print("Rolled event: ", rolled_event.title, " (", event_type, ")")

func _on_choice_selected(choice_id: String) -> void:
	"""Handle event choice selection"""
	current_event["selected_choice"] = choice_id
	resolve_event_button.disabled = false
	print("Choice selected: ", choice_id)

func _on_resolve_event_pressed() -> void:
	"""Handle resolve event button press"""
	if (safe_call_method(current_event, "is_empty") == true):
		return

	# Add result to event
	var choice = current_event.get("selected_choice", "default")
	current_event["result"] = "Resolved with choice: " + choice
	current_event["resolved_timestamp"] = Time.get_unix_time_from_system()

	# Add to history
	event_history.append(current_event.duplicate())

	# Emit signal
	event_resolved.emit(current_event, choice)

	# Clear current event
	current_event = {}

	# Refresh display
	_refresh_display()

	print("Event resolved with choice: ", choice)

func _on_skip_event_pressed() -> void:
	"""Handle skip event button press"""
	if (safe_call_method(current_event, "is_empty") == true):
		return

	# Add to history as skipped
	current_event["result"] = "Skipped"
	current_event["resolved_timestamp"] = Time.get_unix_time_from_system()
	event_history.append(current_event.duplicate())

	# Emit signal
	event_skipped.emit(current_event)

	# Clear current event
	current_event = {}

	# Refresh display
	_refresh_display()

	print("Event skipped")

func _on_clear_history_pressed() -> void:
	"""Handle clear history button press"""
	event_history.clear()
	_refresh_history_display()
	print("Event history cleared")

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("CampaignEventsManager: Back pressed")
	if has_node("/root/SceneRouter"):
		var scene_router = get_node("/root/SceneRouter")
		scene_router.navigate_back()
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/main/MainMenu.tscn")
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null