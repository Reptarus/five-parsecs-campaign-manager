extends BasePhasePanel
class_name StoryPhasePanel

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const EventManager = preload("res://src/core/managers/EventManager.gd")

signal story_event_selected(event_data: Dictionary)
signal story_event_resolved(event_data: Dictionary)

@onready var event_list: ItemList = $VBoxContainer/EventList
@onready var event_details: RichTextLabel = $VBoxContainer/EventDetails
@onready var choice_container: VBoxContainer = $VBoxContainer/ChoiceContainer
@onready var resolve_button: Button = $VBoxContainer/ResolveButton

var event_manager: EventManager
var available_events: Array[Dictionary] = []
var selected_event: Dictionary
var selected_choice: Dictionary

func _ready() -> void:
	super._ready()
	event_manager = get_node("/root/Game/Managers/EventManager")
	if not event_manager:
		push_error("Failed to get EventManager node")
		return
	
	event_manager.event_triggered.connect(_on_event_triggered)
	event_manager.event_resolved.connect(_on_event_resolved)
	event_manager.event_effects_applied.connect(_on_event_effects_applied)
	
	event_list.item_selected.connect(_on_event_selected)
	resolve_button.pressed.connect(_on_resolve_pressed)
	resolve_button.disabled = true

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

func _create_story_event() -> Dictionary:
	# TODO: Replace with actual story event generation from EventManager
	# For now, using sample events
	var sample_events = [
		{
			"title": "Mysterious Signal",
			"description": "Your crew picks up an unusual signal from a nearby system.",
			"choices": [
				{
					"text": "Investigate the signal",
					"effects": {
						"story_points": 2,
						"risk_level": "high",
						"potential_reward": "technology"
					}
				},
				{
					"text": "Ignore it and continue",
					"effects": {
						"story_points": - 1,
						"risk_level": "none",
						"potential_reward": "none"
					}
				}
			]
		},
		{
			"title": "Local Conflict",
			"description": "A local settlement is caught in a dispute between rival factions.",
			"choices": [
				{
					"text": "Support the settlers",
					"effects": {
						"story_points": 3,
						"risk_level": "medium",
						"potential_reward": "allies"
					}
				},
				{
					"text": "Stay neutral",
					"effects": {
						"story_points": 0,
						"risk_level": "low",
						"potential_reward": "none"
					}
				}
			]
		}
	]
	
	return sample_events[randi() % sample_events.size()]

func _update_ui() -> void:
	if selected_event.is_empty():
		event_details.text = "Select a story event"
		_clear_choices()
		resolve_button.disabled = true
		return
	
	# Update event details
	var details = "[b]%s[/b]\n\n%s\n\n[b]Choices:[/b]" % [
		selected_event.title,
		selected_event.description
	]
	event_details.text = details
	
	# Update choices
	_update_choices()
	
	# Update resolve button
	resolve_button.disabled = selected_choice.is_empty()

func _update_choices() -> void:
	_clear_choices()
	
	if not selected_event.has("choices"):
		return
	
	for choice in selected_event.choices:
		var button = Button.new()
		button.text = choice.text
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
	
	# Apply story points
	if effects.has("story_points"):
		game_state.add_story_points(effects.story_points)
	
	# Apply other effects based on the choice
	match effects.potential_reward:
		"technology":
			game_state.add_tech_level(1)
		"allies":
			game_state.add_reputation(5)
	
	# Trigger any related campaign events
	if effects.has("trigger_event"):
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
	return {
		"available_events": available_events,
		"resolved_events": event_history,
		"current_story_points": game_state.get_story_points()
	}

# Event Manager Signal Handlers
func _on_event_triggered(event_type: int) -> void:
	if event_type == GameEnums.GlobalEvent.STORY_EVENT:
		_update_ui()

func _on_event_resolved(event_type: int) -> void:
	if event_type == GameEnums.GlobalEvent.STORY_EVENT:
		_update_ui()

func _on_event_effects_applied(effects: Dictionary) -> void:
	_update_ui()