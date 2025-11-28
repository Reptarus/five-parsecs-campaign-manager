class_name StoryEvent
extends Resource

## Story Event Resource for Five Parsecs Campaign Manager
##
## Represents a story event that can occur during campaign progression.
## Contains event data, player choices, and consequences following
## Five Parsecs From Home story progression rules.

@export var event_id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var event_type: String = "standard"
@export var trigger_conditions: Dictionary = {}
@export var choices: Array[Dictionary] = []
@export var auto_resolve: bool = false
@export var one_time_only: bool = false
@export var priority: int = 0

# Event outcomes and consequences
@export var default_outcome: Dictionary = {}
@export var risk_level: String = "none"  # none, low, medium, high
@export var campaign_effects: Dictionary = {}
@export var crew_effects: Dictionary = {}

# Story progression tracking
@export var story_track_progress: Dictionary = {}
@export var prerequisite_events: Array[String] = []
@export var follow_up_events: Array[String] = []

# Metadata
@export var source_book: String = "Core Rules"
@export var page_reference: String = ""
@export var tags: Array[String] = []

# Tutorial integration (for guided campaign mode)
@export var tutorial_config_key: String = ""  # References tutorial config in story_companion_tutorials.json

var _is_active: bool = false
var is_resolved: bool = false
var selected_choice: int = -1

# Outcomes
var rewards: Dictionary = {}
var consequences: Dictionary = {}

func _init(p_id: String = "", p_title: String = "", p_description: String = "") -> void:
	event_id = p_id
	title = p_title
	description = p_description

## Create a standard story event
func setup_standard_event(id: String, event_title: String, event_desc: String) -> void:
	event_id = id
	title = event_title
	description = event_desc
	event_type = "standard"
	auto_resolve = false

## Create a random encounter event
func setup_encounter_event(id: String, event_title: String, event_desc: String) -> void:
	event_id = id
	title = event_title
	description = event_desc
	event_type = "encounter"
	risk_level = "medium"

## Create a story track progression event
func setup_story_track_event(id: String, event_title: String, track_name: String, progress: int) -> void:
	event_id = id
	title = event_title
	event_type = "story_track"
	story_track_progress[track_name] = progress

## Add a choice to this event
func add_choice(choice_text: String, outcome: Dictionary, risk: String = "none") -> void:
	var choice_data: Dictionary = {
		"text": choice_text,
		"outcome": outcome,
		"risk": risk,
		"requirements": {}
	}
	choices.append(choice_data)

## Add a choice with requirements
func add_conditional_choice(choice_text: String, outcome: Dictionary, requirements: Dictionary, risk: String = "none") -> void:
	var choice_data: Dictionary = {
		"text": choice_text,
		"outcome": outcome,
		"risk": risk,
		"requirements": requirements
	}
	choices.append(choice_data)

## Set default outcome for auto-resolve events
func set_default_outcome(outcome: Dictionary) -> void:
	default_outcome = outcome
	auto_resolve = true

## Check if event can be triggered given current conditions
func can_trigger(game_state: Dictionary) -> bool:
	# Check prerequisite events
	for prereq: String in prerequisite_events:
		if not game_state.get("completed_events", []).has(prereq):
			return false
	
	# Check trigger conditions
	for condition: String in trigger_conditions.keys():
		var required_value: Variant = trigger_conditions[condition]
		var current_value: Variant = game_state.get(condition)
		
		if current_value != required_value:
			return false
	
	# Check if one-time event has already been triggered
	if one_time_only and game_state.get("completed_events", []).has(event_id):
		return false
	
	return true

## Get available choices for current game state
func get_available_choices(game_state: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	
	for choice: Dictionary in choices:
		var requirements: Dictionary = choice.get("requirements", {})
		var can_choose: bool = true
		
		# Check choice requirements
		for req: String in requirements.keys():
			var required_value: Variant = requirements[req]
			var current_value: Variant = game_state.get(req)
			
			if current_value != required_value:
				can_choose = false
				break
		
		if can_choose:
			available.append(choice)
	
	return available

## Convert event to serializable dictionary
func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"title": title,
		"description": description,
		"event_type": event_type,
		"trigger_conditions": trigger_conditions.duplicate(),
		"choices": choices.duplicate(),
		"auto_resolve": auto_resolve,
		"one_time_only": one_time_only,
		"priority": priority,
		"default_outcome": default_outcome.duplicate(),
		"risk_level": risk_level,
		"campaign_effects": campaign_effects.duplicate(),
		"crew_effects": crew_effects.duplicate(),
		"story_track_progress": story_track_progress.duplicate(),
		"prerequisite_events": prerequisite_events.duplicate(),
		"follow_up_events": follow_up_events.duplicate(),
		"source_book": source_book,
		"page_reference": page_reference,
		"tags": tags.duplicate(),
		"tutorial_config_key": tutorial_config_key
	}

## Load event from dictionary data
func from_dict(data: Dictionary) -> void:
	event_id = data.get("event_id", "")
	title = data.get("title", "")
	description = data.get("description", "")
	event_type = data.get("event_type", "standard")
	trigger_conditions = data.get("trigger_conditions", {})
	choices = data.get("choices", [])
	auto_resolve = data.get("auto_resolve", false)
	one_time_only = data.get("one_time_only", false)
	priority = data.get("priority", 0)
	default_outcome = data.get("default_outcome", {})
	risk_level = data.get("risk_level", "none")
	campaign_effects = data.get("campaign_effects", {})
	crew_effects = data.get("crew_effects", {})
	story_track_progress = data.get("story_track_progress", {})
	prerequisite_events = data.get("prerequisite_events", [])
	follow_up_events = data.get("follow_up_events", [])
	source_book = data.get("source_book", "Core Rules")
	page_reference = data.get("page_reference", "")
	tags = data.get("tags", [])
	tutorial_config_key = data.get("tutorial_config_key", "")

## Validate event data integrity
func validate() -> Dictionary:
	var result: Dictionary = {
		"valid": true,
		"errors": []
	}
	
	if event_id.is_empty():
		result.errors.append("Event ID cannot be empty")
		result.valid = false
	
	if title.is_empty():
		result.errors.append("Event title cannot be empty")
		result.valid = false
	
	if description.is_empty():
		result.errors.append("Event description cannot be empty")
		result.valid = false
	
	# Validate choices have required fields
	for i: int in range(choices.size()):
		var choice: Dictionary = choices[i]
		if not choice.has("text") or choice.text.is_empty():
			result.errors.append("Choice %d missing text" % i)
			result.valid = false
		
		if not choice.has("outcome"):
			result.errors.append("Choice %d missing outcome" % i)
			result.valid = false
	
	return result

func configure(config: Dictionary) -> void:
	if config.has("event_id"):
		event_id = config.event_id
	if config.has("event_type"):
		event_type = config.event_type
	if config.has("title"):
		title = config.title
	if config.has("description"):
		description = config.description

func select_choice(choice_index: int) -> void:
	if choice_index >= 0 and choice_index < choices.size():
		selected_choice = choice_index
		is_resolved = true

func get_choice(index: int) -> Dictionary:
	if index >= 0 and index < choices.size():
		return choices[index]
	return {}

func set_event_rewards(reward_data: Dictionary) -> void:
	rewards = reward_data.duplicate()
func set_event_consequences(consequence_data: Dictionary) -> void:
	consequences = consequence_data.duplicate()

func get_event_outcome() -> Dictionary:
	return {
		"is_resolved": is_resolved,
		"selected_choice": selected_choice,
		"rewards": rewards,
		"consequences": consequences
	}

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
