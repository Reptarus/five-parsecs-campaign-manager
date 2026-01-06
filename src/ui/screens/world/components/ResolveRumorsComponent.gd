extends Control
class_name ResolveRumorsComponent

## Resolve Rumors Component - Quest Generation System
## Implements Core Rules p.85 - Resolve rumors to generate quests
## Roll D6 - if equal or below number of rumors, convert to Quest

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# UI Components
@onready var rumors_count_label: Label = %RumorsCountLabel
@onready var rumors_list: ItemList = %RumorsList
@onready var quest_status_label: Label = %QuestStatusLabel
@onready var roll_button: Button = %RollButton
@onready var result_label: Label = %ResultLabel
@onready var quest_description_label: Label = %QuestDescriptionLabel

# State
var rumors: Array = []
var quest_rumors: Array = []  # Rumors specifically for current quest
var current_quest: Dictionary = {}
var has_active_quest: bool = false
var rumors_resolved: bool = false
var last_roll: int = 0

func _ready() -> void:
	name = "ResolveRumorsComponent"
	print("ResolveRumorsComponent: Initialized - Five Parsecs rumor/quest system")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()
	_apply_touch_target_sizing()

## Sprint C: Apply 48px minimum touch targets for mobile UX
func _apply_touch_target_sizing() -> void:
	"""Apply 48px minimum item height to ItemLists for touch compliance"""
	const TOUCH_TARGET_MIN := 48
	if rumors_list:
		rumors_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		print("ResolveRumorsComponent: Connected to event bus")

func _exit_tree() -> void:
	"""Cleanup event bus subscriptions to prevent memory leaks"""
	if event_bus:
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
	if roll_button:
		roll_button.pressed.connect(_on_roll_pressed)

func _setup_initial_state() -> void:
	"""Initialize component state"""
	rumors_resolved = false
	last_roll = 0
	_update_ui_display()

## Public API
func initialize_rumors_phase(rumor_list: Array, active_quest: Dictionary) -> void:
	"""Initialize rumors phase with current rumors and quest status"""
	rumors = rumor_list.duplicate(true)
	current_quest = active_quest.duplicate(true)
	has_active_quest = not current_quest.is_empty()
	rumors_resolved = false
	last_roll = 0

	_populate_rumors_list()
	_update_ui_display()

	print("ResolveRumorsComponent: Initialized with %d rumors, quest active: %s" % [rumors.size(), has_active_quest])

	# AUTO-COMPLETE: If no rumors to resolve, mark as complete
	if rumors.size() == 0:
		rumors_resolved = true
		print("ResolveRumorsComponent: >>> No rumors to resolve - auto-completing phase")
		if result_label:
			result_label.text = "No rumors to resolve"
			result_label.modulate = Color(0.7, 0.7, 0.7)
		_update_ui_display()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "resolve_rumors",
			"rumor_count": rumors.size(),
			"has_quest": has_active_quest
		})

func _populate_rumors_list() -> void:
	"""Populate rumors list"""
	if not rumors_list:
		return

	rumors_list.clear()
	for i in range(rumors.size()):
		var rumor = rumors[i]
		var rumor_text = ""
		if rumor is Dictionary:
			rumor_text = rumor.get("description", "Rumor %d" % (i + 1))
		elif rumor is String:
			rumor_text = rumor
		else:
			rumor_text = "Rumor %d" % (i + 1)
		rumors_list.add_item(rumor_text)

## Core Mechanic - Resolve Rumors (Core Rules p.85)
func _on_roll_pressed() -> void:
	"""Roll to resolve rumors"""
	if has_active_quest:
		print("ResolveRumorsComponent: Already have active quest - cannot resolve rumors")
		if result_label:
			result_label.text = "Cannot resolve - Quest already active"
			result_label.modulate = Color(1.0, 0.5, 0.5)
		return

	if rumors.is_empty():
		print("ResolveRumorsComponent: No rumors to resolve")
		if result_label:
			result_label.text = "No rumors to resolve"
			result_label.modulate = Color(0.8, 0.8, 0.8)
		return

	# Roll D6 - if equal or below rumor count, generate quest
	last_roll = randi() % 6 + 1
	var rumor_count = rumors.size()

	print("ResolveRumorsComponent: Rolled %d vs %d rumors" % [last_roll, rumor_count])

	if last_roll <= rumor_count:
		# Success! Convert rumors to quest
		_generate_quest_from_rumors()
		if result_label:
			result_label.text = "Rolled %d ≤ %d rumors - QUEST GENERATED!" % [last_roll, rumor_count]
			result_label.modulate = Color(0.5, 1.0, 0.5)
	else:
		# Failed - rumors remain
		if result_label:
			result_label.text = "Rolled %d > %d rumors - No quest this turn" % [last_roll, rumor_count]
			result_label.modulate = Color(1.0, 0.8, 0.5)

	rumors_resolved = true
	_update_ui_display()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "resolve_rumors",
			"roll": last_roll,
			"rumor_count": rumor_count,
			"quest_generated": last_roll <= rumor_count
		})

func _generate_quest_from_rumors() -> void:
	"""Generate a quest from accumulated rumors"""
	# Remove all rumors - they've resolved into a quest
	var old_rumors = rumors.duplicate()
	rumors.clear()

	# Generate quest (simplified - expand with full quest generation)
	current_quest = {
		"id": "quest_%d" % randi(),
		"name": _generate_quest_name(),
		"description": _generate_quest_description(old_rumors),
		"type": _get_random_quest_type(),
		"objectives": _generate_quest_objectives(),
		"rewards": _generate_quest_rewards(),
		"turns_remaining": -1,  # -1 = no time limit until abandoned
		"quest_rumors": []  # Rumors collected during quest
	}

	has_active_quest = true

	_populate_rumors_list()
	_update_ui_display()

	if quest_description_label:
		quest_description_label.text = "New Quest: %s\n%s" % [current_quest.name, current_quest.description]
		quest_description_label.visible = true

	print("ResolveRumorsComponent: Generated quest - %s" % current_quest.name)

	# Save quest to campaign data
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign:
			# Set active quest
			if campaign is Dictionary:
				campaign["active_quest"] = current_quest
				# Also clear the rumors since they're now a quest
				campaign["rumors"] = []
			print("ResolveRumorsComponent: Saved quest '%s' to campaign" % current_quest.name)

func _generate_quest_name() -> String:
	"""Generate random quest name"""
	var prefixes = ["The Lost", "Hidden", "Ancient", "Stolen", "Mysterious", "Dangerous"]
	var subjects = ["Artifact", "Cargo", "Data", "Weapon", "Ship", "Coordinates"]
	return "%s %s" % [prefixes[randi() % prefixes.size()], subjects[randi() % subjects.size()]]

func _generate_quest_description(source_rumors: Array) -> String:
	"""Generate quest description based on rumors"""
	var descriptions = [
		"Your accumulated intel has revealed the location of something valuable.",
		"Multiple sources confirm a significant opportunity awaits.",
		"The rumors point to a dangerous but potentially rewarding mission.",
		"Cross-referencing your leads has uncovered a hidden threat that must be addressed."
	]
	return descriptions[randi() % descriptions.size()]

func _get_random_quest_type() -> String:
	"""Get random quest type"""
	var types = ["retrieve", "eliminate", "escort", "investigate", "defend"]
	return types[randi() % types.size()]

func _generate_quest_objectives() -> Array:
	"""Generate quest objectives"""
	return [
		{"description": "Reach the target location", "completed": false},
		{"description": "Complete the primary objective", "completed": false},
		{"description": "Extract safely", "completed": false}
	]

func _generate_quest_rewards() -> Dictionary:
	"""Generate quest rewards"""
	return {
		"credits": (randi() % 6 + 1) + (randi() % 6 + 1),  # 2d6 credits
		"reputation": 1,
		"special_item_chance": 0.3
	}

## UI Updates
func _update_ui_display() -> void:
	"""Update all UI elements"""
	if rumors_count_label:
		rumors_count_label.text = "Rumors: %d" % rumors.size()

	if quest_status_label:
		if has_active_quest:
			quest_status_label.text = "Quest Active: %s" % current_quest.get("name", "Unknown")
			quest_status_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			quest_status_label.text = "No Active Quest"
			quest_status_label.modulate = Color(0.8, 0.8, 0.8)

	if roll_button:
		roll_button.disabled = has_active_quest or rumors.is_empty() or rumors_resolved
		if has_active_quest:
			roll_button.text = "Quest Already Active"
		elif rumors.is_empty():
			roll_button.text = "No Rumors"
		elif rumors_resolved:
			roll_button.text = "Already Resolved"
		else:
			roll_button.text = "Roll to Resolve (D6 ≤ %d)" % rumors.size()

## Event Handlers
func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "resolve_rumors":
		print("ResolveRumorsComponent: Rumors phase started")

## Public API
func is_rumors_resolved() -> bool:
	"""Check if rumors phase is completed"""
	return rumors_resolved

func get_current_quest() -> Dictionary:
	"""Get current quest data"""
	return current_quest.duplicate(true)

func get_remaining_rumors() -> Array:
	"""Get remaining rumors"""
	return rumors.duplicate(true)

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	"""Get step results for phase completion (standardized interface)"""
	return {
		"rumors_resolved": rumors_resolved,
		"current_quest": current_quest.duplicate(true),
		"remaining_rumors": rumors.duplicate(true),
		"quest_rumors": quest_rumors.duplicate(true),
		"has_active_quest": has_active_quest,
		"last_roll": last_roll
	}

func add_rumor(rumor: Variant) -> void:
	"""Add a new rumor (or quest rumor if quest active)"""
	if has_active_quest:
		# During quest, rumors become quest rumors
		quest_rumors.append(rumor)
		print("ResolveRumorsComponent: Added quest rumor (total: %d)" % quest_rumors.size())
	else:
		rumors.append(rumor)
		_populate_rumors_list()
		_update_ui_display()
		print("ResolveRumorsComponent: Added rumor")

## Consume quest rumors when advancing quest progress (Five Parsecs p.85)
func consume_quest_rumor() -> bool:
	"""Consume one quest rumor to advance quest progress. Returns true if rumor was consumed."""
	if not has_active_quest:
		push_warning("ResolveRumorsComponent: Cannot consume quest rumor - no active quest")
		return false

	if quest_rumors.is_empty():
		push_warning("ResolveRumorsComponent: No quest rumors to consume")
		return false

	# Remove the first quest rumor (FIFO)
	var consumed_rumor = quest_rumors.pop_front()
	print("ResolveRumorsComponent: Consumed quest rumor (remaining: %d)" % quest_rumors.size())

	# Save to campaign data
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign and "active_quest" in campaign and campaign.active_quest:
			# Update quest_rumors in saved quest
			campaign.active_quest["quest_rumors"] = quest_rumors.duplicate()
			print("ResolveRumorsComponent: Updated quest rumors in campaign save")

	return true

## Get count of quest rumors available for quest progression
func get_quest_rumor_count() -> int:
	"""Get number of quest rumors available to advance quest"""
	return quest_rumors.size()

func reset_rumors_phase() -> void:
	"""Reset for new turn"""
	rumors_resolved = false
	last_roll = 0
	if result_label:
		result_label.text = ""
	_update_ui_display()
	print("ResolveRumorsComponent: Reset for new turn")
