extends Control
class_name CharacterEventComponent

## Character Event Component - Personal Character Events
## Implements Core Rules pp.129-132 - D100 Character Event Table
## Select random non-Bot character and roll for personal events

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# UI Components
@onready var character_label: Label = %CharacterLabel
@onready var roll_button: Button = %RollButton
@onready var event_title_label: Label = %EventTitleLabel
@onready var event_description_label: Label = %EventDescriptionLabel
@onready var event_effect_label: Label = %EventEffectLabel
@onready var resolve_button: Button = %ResolveButton
@onready var roll_result_label: Label = %RollResultLabel

# State
var crew_data: Array = []
var selected_character: Dictionary = {}
var current_event: Dictionary = {}
var event_resolved: bool = false
var last_roll: int = 0

# Character Event Table (Core Rules pp.129-132) - Simplified version
var character_events: Array[Dictionary] = [
	{"range": [1, 5], "title": "Focused Training", "description": "The character spent extra time at the range.", "effect": "+1 Combat Skill XP"},
	{"range": [6, 10], "title": "Technical Study", "description": "Time spent studying technical manuals.", "effect": "+1 Savvy XP"},
	{"range": [11, 15], "title": "Physical Training", "description": "Intense physical conditioning.", "effect": "+1 Toughness XP"},
	{"range": [16, 20], "title": "Old Friend", "description": "An old friend reaches out.", "effect": "+1 story point"},
	{"range": [21, 25], "title": "Bad Dreams", "description": "Troubled by nightmares.", "effect": "-1 to next combat roll"},
	{"range": [26, 30], "title": "Gambling", "description": "Got caught up in a game of chance.", "effect": "Roll D6: 1-2 lose 1D6 credits, 3-4 nothing, 5-6 gain 1D6 credits"},
	{"range": [31, 35], "title": "Bar Fight", "description": "Things got heated at the local cantina.", "effect": "Roll D6: 1-3 injured (1 turn), 4-6 gained respect (+1 Rival or Patron)"},
	{"range": [36, 40], "title": "Found Item", "description": "Discovered something useful.", "effect": "Gain random gear item"},
	{"range": [41, 45], "title": "Made Contact", "description": "Made a useful contact.", "effect": "+1 to next Patron search"},
	{"range": [46, 50], "title": "Personal Growth", "description": "Learned something about themselves.", "effect": "+2 XP"},
	{"range": [51, 55], "title": "Equipment Care", "description": "Took time to maintain gear.", "effect": "Repair one damaged item automatically"},
	{"range": [56, 60], "title": "Side Job", "description": "Picked up some extra work.", "effect": "Gain 1D6 credits"},
	{"range": [61, 65], "title": "Wound Heals", "description": "Old injury finally heals properly.", "effect": "If in Sick Bay, reduce time by 1 turn"},
	{"range": [66, 70], "title": "Made Enemy", "description": "Managed to upset someone.", "effect": "Gain 1 Rival"},
	{"range": [71, 75], "title": "Valuable Intel", "description": "Overheard something interesting.", "effect": "Gain 1 Rumor"},
	{"range": [76, 80], "title": "Trait Development", "description": "Character develops a notable trait.", "effect": "Gain random positive trait"},
	{"range": [81, 85], "title": "Equipment Lost", "description": "Lost a piece of equipment.", "effect": "Random item is lost permanently"},
	{"range": [86, 90], "title": "Unexpected Windfall", "description": "Received money from unexpected source.", "effect": "Gain 2D6 credits"},
	{"range": [91, 95], "title": "Moment of Glory", "description": "Did something impressive.", "effect": "+1 story point, +1 XP"},
	{"range": [96, 100], "title": "Life-Changing Event", "description": "Something significant happened.", "effect": "Reroll character Motivation"}
]

func _ready() -> void:
	name = "CharacterEventComponent"
	print("CharacterEventComponent: Initialized - Five Parsecs character event system")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		print("CharacterEventComponent: Connected to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
	if roll_button:
		roll_button.pressed.connect(_on_roll_pressed)
	if resolve_button:
		resolve_button.pressed.connect(_on_resolve_pressed)

func _setup_initial_state() -> void:
	"""Initialize component state"""
	event_resolved = false
	current_event.clear()
	selected_character.clear()
	_update_ui_display()

## Public API
func initialize_event_phase(crew: Array) -> void:
	"""Initialize character event phase with crew data"""
	crew_data = crew.duplicate(true)
	event_resolved = false
	current_event.clear()
	selected_character.clear()
	last_roll = 0

	# Select random eligible character
	_select_random_character()

	_update_ui_display()

	print("CharacterEventComponent: Event phase initialized with %d crew members" % crew.size())

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "character_event",
			"selected_character": selected_character.get("name", "Unknown")
		})

func _select_random_character() -> void:
	"""Select random non-Bot, non-Soulless character"""
	var eligible_characters: Array = []

	for member in crew_data:
		var species = ""
		if member is Dictionary:
			species = member.get("species", "Human")
		elif member is Resource and "species" in member:
			species = member.species

		# Exclude Bots and Soulless (Core Rules p.123)
		if species != "Bot" and species != "Soulless":
			eligible_characters.append(member)

	if eligible_characters.is_empty():
		print("CharacterEventComponent: No eligible characters for event")
		return

	var random_index = randi() % eligible_characters.size()
	selected_character = eligible_characters[random_index]

	var char_name = selected_character.get("name", "Unknown") if selected_character is Dictionary else "Unknown"
	print("CharacterEventComponent: Selected %s for character event" % char_name)

## Core Mechanic - Roll Character Event
func _on_roll_pressed() -> void:
	"""Roll D100 on Character Event Table"""
	if selected_character.is_empty():
		print("CharacterEventComponent: No character selected")
		return

	last_roll = randi() % 100 + 1

	# Check for Precursor double-roll (Core Rules p.123)
	var is_precursor = false
	if selected_character is Dictionary:
		is_precursor = selected_character.get("species", "") == "Precursor"

	if is_precursor:
		var second_roll = randi() % 100 + 1
		print("CharacterEventComponent: Precursor rolls %d and %d (can choose)" % [last_roll, second_roll])
		# For simplicity, take higher roll - full implementation would offer choice
		last_roll = max(last_roll, second_roll)

	# Find matching event
	current_event = _get_event_for_roll(last_roll)

	var char_name = selected_character.get("name", "Unknown") if selected_character is Dictionary else "Unknown"
	print("CharacterEventComponent: %s rolled %d - %s" % [char_name, last_roll, current_event.get("title", "Unknown")])

	_update_ui_display()

	if roll_result_label:
		roll_result_label.text = "Rolled: %d" % last_roll

func _get_event_for_roll(roll: int) -> Dictionary:
	"""Get event matching the roll result"""
	for event in character_events:
		var range_arr = event.get("range", [0, 0])
		if roll >= range_arr[0] and roll <= range_arr[1]:
			return event.duplicate()

	# Default fallback
	return {
		"title": "Quiet Day",
		"description": "Nothing notable happened.",
		"effect": "+1 XP"
	}

func _on_resolve_pressed() -> void:
	"""Resolve the current event"""
	if current_event.is_empty():
		return

	event_resolved = true

	# Apply event effects using PostBattlePhase handler
	var effect_text: String = _apply_event_effects()
	
	# Show effect result in UI
	if event_effect_label:
		event_effect_label.text = "Result: " + effect_text
		event_effect_label.modulate = Color(0.5, 1.0, 0.5)

	_update_ui_display()

	var char_name = selected_character.get("name", "Unknown") if selected_character is Dictionary else "Unknown"
	print("CharacterEventComponent: Event resolved for %s - %s (%s)" % [char_name, current_event.get("title", "Unknown"), effect_text])

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "character_event",
			"character": selected_character.get("name", "Unknown") if selected_character is Dictionary else "Unknown",
			"event": current_event,
			"roll": last_roll,
			"effect": effect_text
		})

func _apply_event_effects() -> String:
	"""Apply effects of current event to character using PostBattlePhase handler"""
	var title = current_event.get("title", "")
	
	# Get PostBattlePhase handler
	var post_battle_phase = get_node_or_null("/root/PostBattlePhase")
	if not post_battle_phase:
		# Fallback: Try to find in scene tree
		post_battle_phase = get_tree().root.find_child("PostBattlePhase", true, false)
	
	if post_battle_phase and post_battle_phase.has_method("apply_character_event_effect"):
		var result = post_battle_phase.apply_character_event_effect(title, selected_character)
		print("CharacterEventComponent: %s" % result)
		return result
	else:
		push_warning("CharacterEventComponent: PostBattlePhase not found - using fallback")
		return _apply_event_effects_fallback(title)

func _apply_event_effects_fallback(title: String) -> String:
	"""Fallback event effect application if PostBattlePhase not available"""
	var char_name = selected_character.get("name", "Unknown") if selected_character is Dictionary else "Unknown"
	
	match title:
		"Old Friend", "Moment of Glory":
			if GameStateManager and GameStateManager.has_method("add_story_points"):
				GameStateManager.add_story_points(1)
			return "%s gained +1 Story Point" % char_name
		
		"Personal Growth":
			if selected_character is Dictionary:
				selected_character["experience"] = selected_character.get("experience", 0) + 2
			return "%s gained +2 XP" % char_name
		
		"Side Job":
			var credits = randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "%s earned %d Credits" % [char_name, credits]
		
		_:
			return "%s: Event requires manual resolution" % char_name

## UI Updates
func _update_ui_display() -> void:
	"""Update all UI elements"""
	var has_character = not selected_character.is_empty()
	var has_event = not current_event.is_empty()

	if character_label:
		if has_character:
			var char_name = selected_character.get("name", "Unknown") if selected_character is Dictionary else "Unknown"
			character_label.text = "Selected Character: %s" % char_name
		else:
			character_label.text = "No eligible characters"

	if roll_button:
		roll_button.disabled = not has_character or has_event

	if resolve_button:
		resolve_button.disabled = not has_event or event_resolved
		resolve_button.visible = has_event

	if event_title_label:
		event_title_label.text = current_event.get("title", "Roll for Character Event")

	if event_description_label:
		event_description_label.text = current_event.get("description", "")
		event_description_label.visible = has_event

	if event_effect_label:
		event_effect_label.text = "Effect: " + current_event.get("effect", "") if has_event else ""
		event_effect_label.visible = has_event
		if event_resolved:
			event_effect_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			event_effect_label.modulate = Color(1.0, 1.0, 1.0)

## Event Handlers
func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "character_event":
		print("CharacterEventComponent: Character event phase started")

## Public API
func is_event_resolved() -> bool:
	"""Check if event phase is completed"""
	return event_resolved

func get_current_event() -> Dictionary:
	"""Get current event data"""
	return current_event.duplicate()

func get_selected_character() -> Dictionary:
	"""Get selected character data"""
	return selected_character.duplicate() if selected_character is Dictionary else {}

func reset_event_phase() -> void:
	"""Reset for new turn"""
	event_resolved = false
	current_event.clear()
	selected_character.clear()
	last_roll = 0
	if roll_result_label:
		roll_result_label.text = ""
	_update_ui_display()
	print("CharacterEventComponent: Reset for new turn")
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           