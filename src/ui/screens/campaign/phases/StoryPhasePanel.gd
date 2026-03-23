extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/StoryPhasePanel.gd")
const EventManager = preload("res://src/core/managers/EventManager.gd")

signal story_event_selected(event_data: Dictionary)
signal story_event_resolved(event_data: Dictionary)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var event_list: ItemList = $VBoxContainer/EventList
@onready var event_details: RichTextLabel = $VBoxContainer/EventDetails
@onready var choice_container: VBoxContainer = $VBoxContainer/ChoiceContainer
@onready var resolve_button: Button = $VBoxContainer/ResolveButton

var event_manager: EventManager
var available_events: Array[Dictionary] = []
var selected_event: Dictionary
var selected_choice: Dictionary
var event_history: Array[Dictionary] = []
## Story events loaded from story_events.json
var _story_events_db: Array = []

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_item_list(event_list)
	_style_rich_text(event_details)
	_style_phase_button(resolve_button, true)

	_load_story_events()
	event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		if event_manager.has_signal("event_triggered"):
			event_manager.event_triggered.connect(_on_event_triggered)
		if event_manager.has_signal("event_resolved"):
			event_manager.event_resolved.connect(_on_event_resolved)
		if event_manager.has_signal("event_effects_applied"):
			event_manager.event_effects_applied.connect(_on_event_effects_applied)
	else:
		push_warning("StoryPhasePanel: EventManager not found (panel has fallback event generation)")

	if event_list:
		event_list.item_selected.connect(_on_event_selected)
	if resolve_button:
		resolve_button.pressed.connect(_on_resolve_pressed)
		resolve_button.disabled = true
		_style_button_disabled(resolve_button)
		_setup_validation_hint(resolve_button)

func setup_phase() -> void:
	super.setup_phase()
	# Clear previous state
	available_events.clear()
	selected_event = {}
	selected_choice = {}
	
	# Generate new story events
	_generate_story_events()
	_update_ui()

func _generate_story_events() -> void:
	# Clear existing events
	available_events.clear()
	event_list.clear()
	
	# Generate 1-3 story events based on current campaign state
	var num_events = randi_range(1, 3)
	for i in range(num_events):
		var event = _create_story_event()
		available_events.append(event)
		event_list.add_item(event.title)

func _load_story_events() -> void:
	## Load story events from story_events.json
	var path := "res://data/story_events.json"
	if not FileAccess.file_exists(path):
		push_warning("StoryPhasePanel: story_events.json not found")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("StoryPhasePanel: Failed to parse story_events.json")
		return
	if json.data is Dictionary:
		_story_events_db = json.data.get("events", [])

func _create_story_event() -> Dictionary:
	## Create a story event from story_events.json (or fallback)
	if _story_events_db.size() > 0:
		var src: Dictionary = _story_events_db[randi() % _story_events_db.size()]
		return {
			"title": src.get("title", "Unknown Event"),
			"description": src.get("description", ""),
			"choices": src.get("choices", [
				{"text": "Continue", "effects": {"story_points": 0, "risk_level": "none", "potential_reward": "none"}}
			])
		}
	# Hardcoded fallback if JSON unavailable
	var sample_events = [
		{
			"title": "Mysterious Signal",
			"description": "Your crew picks up an unusual signal from a nearby system.",
			"choices": [
				{"text": "Investigate the signal", "effects": {"story_points": 2, "risk_level": "high", "potential_reward": "technology"}},
				{"text": "Ignore it and continue", "effects": {"story_points": -1, "risk_level": "none", "potential_reward": "none"}}
			]
		},
		{
			"title": "Local Conflict",
			"description": "A local settlement is caught in a dispute between rival factions.",
			"choices": [
				{"text": "Support the settlers", "effects": {"story_points": 3, "risk_level": "medium", "potential_reward": "allies"}},
				{"text": "Stay neutral", "effects": {"story_points": 0, "risk_level": "low", "potential_reward": "none"}}
			]
		}
	]
	return sample_events[randi() % sample_events.size()]

func _update_ui() -> void:
	if selected_event.is_empty():
		event_details.text = "Select a story event"
		_clear_choices()
		resolve_button.disabled = true
		_show_validation_hint("Select an event to continue")
		return

	# Update event details
	var details = "[b]%s[/b]\n\n%s\n\n[b]Choices:[/b]" % [
		selected_event.title,
		selected_event.description
	]
	_set_keyword_text(event_details, details)

	# Update choices
	_update_choices()

	# Update resolve button
	var no_choice: bool = selected_choice.is_empty()
	resolve_button.disabled = no_choice
	if no_choice:
		_show_validation_hint("Select a choice to resolve")
	else:
		_hide_validation_hint()

func _update_choices() -> void:
	_clear_choices()
	
	if not selected_event.has("choices"):
		return
	
	for choice in selected_event.choices:
		var button = Button.new()
		button.text = choice.text
		_style_phase_button(button)
		button.pressed.connect(_on_choice_selected.bind(choice))
		choice_container.add_child(button)

func _clear_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

func _on_event_selected(index: int) -> void:
	if index >= 0 and index < available_events.size():
		selected_event = available_events[index]
		selected_choice = {}
		_update_ui()
		story_event_selected.emit(selected_event)

func _on_choice_selected(choice: Dictionary) -> void:
	selected_choice = choice
	resolve_button.disabled = false
	
	# Update UI to show selected choice
	for button in choice_container.get_children():
		if button.text == choice.text:
			button.add_theme_color_override("font_color", Color.GREEN)
		else:
			button.add_theme_color_override("font_color", Color.WHITE)

func _on_resolve_pressed() -> void:
	if selected_event.is_empty() or selected_choice.is_empty():
		return
	
	# Apply choice effects
	_apply_choice_effects(selected_choice.effects)
	
	# Emit resolution signal
	var resolution_data = {
		"event": selected_event,
		"choice": selected_choice,
		"outcome": _generate_outcome()
	}
	story_event_resolved.emit(resolution_data)

	# Log story event to CampaignJournal
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("auto_create_milestone_entry"):
		var turn_num: int = 0
		var campaign = game_state.campaign if game_state else null
		if campaign and "progress_data" in campaign:
			turn_num = campaign.progress_data.get("turns_played", 0)
		var event_title: String = selected_event.get("title", selected_event.get("name", "Story Event"))
		journal.auto_create_milestone_entry("story_track", {
			"turn": turn_num,
			"stats": {"event_title": event_title, "choice": selected_choice.get("text", "")},
		})

	# Remove resolved event
	var event_index = available_events.find(selected_event)
	if event_index != -1:
		available_events.remove_at(event_index)
		event_list.remove_item(event_index)
	
	# Clear selection
	selected_event = {}
	selected_choice = {}
	_update_ui()
	
	# Check if we can complete the phase
	if available_events.is_empty():
		complete_phase()

func _apply_choice_effects(effects: Dictionary) -> void:
	if not effects:
		return
	if effects.has("story_points") and game_state and game_state.has_method("add_story_points"):
		game_state.add_story_points(effects.story_points)
	if effects.has("potential_reward"):
		match effects.potential_reward:
			"technology":
				if game_state and game_state.has_method("add_tech_level"):
					game_state.add_tech_level(1)
			"allies":
				if game_state and game_state.has_method("add_reputation"):
					game_state.add_reputation(5)
				# Track new patron in NPCTracker
				var npc = get_node_or_null("/root/NPCTracker")
				if npc and npc.has_method("add_patron"):
					var pid := "patron_story_%d" % Time.get_ticks_msec()
				npc.add_patron({"name": "Story Ally", "patron_id": pid})
	if effects.has("trigger_event") and event_manager and event_manager.has_method("trigger_campaign_event"):
		event_manager.trigger_campaign_event(effects.trigger_event)

func _generate_outcome() -> Dictionary:
	# Generate outcome based on choice effects and random chance
	var success_chance = 0.7 # Base 70% success rate
	
	# Modify based on risk level
	match selected_choice.effects.risk_level:
		"high":
			success_chance = 0.5
		"medium":
			success_chance = 0.6
		"low":
			success_chance = 0.8
		"none":
			success_chance = 1.0
	
	var success = randf() < success_chance
	return {
		"success": success,
		"description": _generate_outcome_description(success)
	}

func _generate_outcome_description(success: bool) -> String:
	if success:
		return "Your choice led to a favorable outcome!"
	else:
		return "Despite your best efforts, things didn't go as planned."

func validate_phase_requirements() -> bool:
	return true # No specific requirements for story phase

func get_phase_data() -> Dictionary:
	var sp: int = 0
	if game_state and game_state.has_method("get_story_points"):
		sp = game_state.get_story_points()
	return {
		"available_events": available_events,
		"resolved_events": event_history,
		"current_story_points": sp
	}

# Event Manager Signal Handlers
func _on_event_triggered(_event_type: int) -> void:
	_update_ui()

func _on_event_resolved(_event_type: int) -> void:
	_update_ui()

func _on_event_effects_applied(_effects: Dictionary) -> void:
	_update_ui()
