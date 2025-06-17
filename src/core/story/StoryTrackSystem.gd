class_name FPCM_StoryTrackSystem
extends Resource

## Story Track System implementing Five Parsecs Core Rules Appendix V
##
## Features:
## - Story Clock progression mechanics
## - 6 interconnected story events  
## - Player choice branching system
## - Evidence collection tracking
## - Rewards and consequences

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals - following tested patterns
signal story_clock_advanced(ticks_remaining: int)
signal story_event_triggered(event: StoryEvent)
signal story_choice_made(choice: StoryChoice)
signal evidence_discovered(evidence_count: int)
signal story_track_completed()
signal story_milestone_reached(milestone: int)

# Story Clock mechanics (from Core Rules Appendix V)
var story_clock_ticks: int = 6 # Initial clock setting
var max_clock_ticks: int = 6
var evidence_pieces: int = 0
var current_event_index: int = 0

# Story events array (6 interconnected events per Appendix V)
var story_events: Array[StoryEvent] = []
var completed_events: Array[StoryEvent] = []
var available_choices: Array[StoryChoice] = []

# Player progress tracking
var story_choices_made: Array[Dictionary] = []
var story_branches_unlocked: Array[String] = []
var story_rewards_earned: Array[Dictionary] = []

# Story track state
var is_story_track_active: bool = false
var story_track_phase: String = "inactive" # inactive, active, climax, completed
var turns_since_discovery: int = 0

## Initialize story track with default events
func _init() -> void:
	_initialize_story_events()

## Initialize the 6 story events from Appendix V pattern
func _initialize_story_events() -> void:
	story_events.clear()
	
	# Event 1: Initial Discovery
	var event1 = StoryEvent.new()
	event1.event_id = "discovery_signal"
	event1.title = "Mysterious Signal"
	event1.description = "Your crew picks up a mysterious signal from an abandoned research facility..."
	event1.event_index = 0
	event1.required_evidence = 0
	_add_event_choices(event1, [
		{"text": "Investigate immediately", "risk": "high", "reward": "tech_data", "evidence_gain": 2},
		{"text": "Monitor from distance", "risk": "low", "reward": "information", "evidence_gain": 1},
		{"text": "Report to authorities", "risk": "none", "reward": "credits", "evidence_gain": 0}
	])
	story_events.append(event1)
	
	# Event 2: First Contact
	var event2 = StoryEvent.new()
	event2.event_id = "first_contact"
	event2.title = "Unexpected Contact"
	event2.description = "A transmission reveals someone else is searching for the same thing..."
	event2.event_index = 1
	event2.required_evidence = 1
	_add_event_choices(event2, [
		{"text": "Attempt to make contact", "risk": "medium", "reward": "ally", "evidence_gain": 2},
		{"text": "Follow them secretly", "risk": "high", "reward": "intel", "evidence_gain": 3},
		{"text": "Avoid them entirely", "risk": "low", "reward": "none", "evidence_gain": 0}
	])
	story_events.append(event2)
	
	# Event 3: Hidden Conspiracy
	var event3 = StoryEvent.new()
	event3.event_id = "conspiracy_revealed"
	event3.title = "Corporate Conspiracy"
	event3.description = "Evidence points to a massive corporate cover-up involving illegal experiments..."
	event3.event_index = 2
	event3.required_evidence = 3
	_add_event_choices(event3, [
		{"text": "Expose the conspiracy", "risk": "very_high", "reward": "reputation", "evidence_gain": 1},
		{"text": "Blackmail for profit", "risk": "high", "reward": "credits", "evidence_gain": 1},
		{"text": "Sell data to competitors", "risk": "medium", "reward": "contacts", "evidence_gain": 0}
	])
	story_events.append(event3)
	
	# Event 4: Personal Stakes
	var event4 = StoryEvent.new()
	event4.event_id = "personal_connection"
	event4.title = "Personal Connection"
	event4.description = "You discover someone close to you was involved in the original research..."
	event4.event_index = 3
	event4.required_evidence = 4
	_add_event_choices(event4, [
		{"text": "Confront them directly", "risk": "medium", "reward": "truth", "evidence_gain": 2},
		{"text": "Search for more evidence", "risk": "low", "reward": "intel", "evidence_gain": 3},
		{"text": "Protect them from discovery", "risk": "high", "reward": "loyalty", "evidence_gain": 0}
	])
	story_events.append(event4)
	
	# Event 5: The Hunt Begins
	var event5 = StoryEvent.new()
	event5.event_id = "hunt_begins"
	event5.title = "The Hunt Begins"
	event5.description = "Your old companion has been taken by those who want to silence the truth..."
	event5.event_index = 4
	event5.required_evidence = 5
	_add_event_choices(event5, [
		{"text": "Mount immediate rescue", "risk": "very_high", "reward": "companion", "evidence_gain": 1},
		{"text": "Gather allies first", "risk": "medium", "reward": "support", "evidence_gain": 2},
		{"text": "Negotiate for release", "risk": "high", "reward": "deal", "evidence_gain": 0}
	])
	story_events.append(event5)
	
	# Event 6: Final Confrontation
	var event6 = StoryEvent.new()
	event6.event_id = "final_confrontation"
	event6.title = "We're Coming!"
	event6.description = "You've tracked down where they're holding your friend. Time for diplomacy, Fringe-style!"
	event6.event_index = 5
	event6.required_evidence = 7 # 7+ from dice roll + evidence as per rules
	_add_event_choices(event6, [
		{"text": "Full frontal assault", "risk": "extreme", "reward": "victory", "evidence_gain": 0},
		{"text": "Stealth infiltration", "risk": "very_high", "reward": "rescue", "evidence_gain": 0},
		{"text": "Create distraction", "risk": "high", "reward": "opportunity", "evidence_gain": 0}
	])
	story_events.append(event6)

## Add choices to a story event
func _add_event_choices(event: StoryEvent, choices_data: Array) -> void:
	for choice_data in choices_data:
		var choice = StoryChoice.new()
		choice.choice_text = choice_data.text
		choice.risk_level = choice_data.risk
		choice.potential_reward = choice_data.reward
		choice.evidence_gain = choice_data.evidence_gain
		choice.parent_event = event
		event.choices.append(choice)

## Start the story track
func start_story_track() -> void:
	if is_story_track_active:
		return
	
	is_story_track_active = true
	story_track_phase = "active"
	story_clock_ticks = max_clock_ticks
	current_event_index = 0
	evidence_pieces = 0
	
	# Trigger first event
	trigger_next_event()

## Advance the story clock (per Core Rules mechanics)
func advance_story_clock(success: bool = true) -> void:
	if not is_story_track_active:
		return
	
	# Clock reduction based on success (per Appendix V)
	var tick_reduction = 2 if success else 1
	story_clock_ticks = max(0, story_clock_ticks - tick_reduction)
	
	story_clock_advanced.emit(story_clock_ticks)
	
	# Check if we should trigger next event
	if story_clock_ticks <= 0:
		trigger_next_event()

## Discover evidence (per Core Rules mechanics)
func discover_evidence(amount: int = 1) -> void:
	evidence_pieces += amount
	evidence_discovered.emit(evidence_pieces)
	
	# Check if evidence unlocks new events (per rules: 1D6 + evidence >= 7)
	_check_evidence_progression()

## Check if evidence unlocks story progression
func _check_evidence_progression() -> void:
	var dice_roll = randi_range(1, 6)
	var total_score = dice_roll + evidence_pieces
	
	# Per Appendix V: On 7+, discover companion location (Event 6)
	if total_score >= 7 and current_event_index < 5:
		current_event_index = 5 # Jump to final event
		trigger_next_event()
		return
	
	# Otherwise, gain additional evidence and continue
	if total_score < 7:
		evidence_pieces += 1 # Additional evidence per rules
		evidence_discovered.emit(evidence_pieces)

## Trigger the next story event
func trigger_next_event() -> void:
	if current_event_index >= story_events.size():
		complete_story_track()
		return
	
	var event = story_events[current_event_index]
	
	# Check if player has required evidence
	if evidence_pieces >= event.required_evidence:
		event.is_available = true
		story_event_triggered.emit(event)
		story_track_phase = "event_active"
	else:
		# Reset clock and continue searching
		story_clock_ticks = max_clock_ticks
		story_clock_advanced.emit(story_clock_ticks)

## Make a story choice
func make_story_choice(event: StoryEvent, choice: StoryChoice) -> Dictionary:
	if not event or not choice:
		return {"success": false, "message": "Invalid event or choice"}
	
	# Apply choice effects
	var outcome = _resolve_choice_outcome(choice)
	
	# Record choice
	var choice_record = {
		"event_id": event.event_id,
		"choice_text": choice.choice_text,
		"outcome": outcome,
		"timestamp": Time.get_unix_time_from_system()
	}
	story_choices_made.append(choice_record)
	
	# Gain evidence
	if choice.evidence_gain > 0:
		discover_evidence(choice.evidence_gain)
	
	# Mark event as completed
	event.is_completed = true
	completed_events.append(event)
	
	# Advance to next event
	current_event_index += 1
	
	# Emit signals
	story_choice_made.emit(choice)
	
	# Check for story completion
	if current_event_index >= story_events.size():
		complete_story_track()
	else:
		# Reset clock for next event
		story_clock_ticks = max_clock_ticks
		advance_story_clock(outcome.success)
	
	return outcome

## Resolve choice outcome based on risk/reward
func _resolve_choice_outcome(choice: StoryChoice) -> Dictionary:
	var success_chance = _calculate_success_chance(choice.risk_level)
	var is_success = randf() < success_chance
	
	var outcome = {
		"success": is_success,
		"reward_type": choice.potential_reward,
		"description": _generate_outcome_description(choice, is_success)
	}
	
	if is_success:
		_apply_choice_rewards(choice)
	else:
		_apply_choice_consequences(choice)
	
	return outcome

## Calculate success chance based on risk level
func _calculate_success_chance(risk_level: String) -> float:
	match risk_level:
		"none": return 1.0
		"low": return 0.85
		"medium": return 0.70
		"high": return 0.55
		"very_high": return 0.40
		"extreme": return 0.25
		_: return 0.70

## Apply rewards for successful choices
func _apply_choice_rewards(choice: StoryChoice) -> void:
	var reward = {
		"type": choice.potential_reward,
		"source": choice.choice_text,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	match choice.potential_reward:
		"tech_data":
			reward["effect"] = "Gain advanced technology"
		"information":
			reward["effect"] = "Gain valuable intelligence"
		"credits":
			reward["effect"] = "Gain 1000 credits"
		"ally":
			reward["effect"] = "Gain powerful ally"
		"reputation":
			reward["effect"] = "Gain +10 reputation"
		"companion":
			reward["effect"] = "Rescue companion"
		_:
			reward["effect"] = "Gain story advantage"
	
	story_rewards_earned.append(reward)

## Apply consequences for failed choices
func _apply_choice_consequences(choice: StoryChoice) -> void:
	# Consequences increase with risk level
	match choice.risk_level:
		"high", "very_high", "extreme":
			# High risk failures have serious consequences
			evidence_pieces = max(0, evidence_pieces - 1)
			story_clock_ticks = max(1, story_clock_ticks - 1)

## Generate outcome description
func _generate_outcome_description(choice: StoryChoice, success: bool) -> String:
	if success:
		return "Your choice of '%s' paid off! %s" % [choice.choice_text, _get_success_flavor(choice.potential_reward)]
	else:
		return "Your choice of '%s' didn't go as planned. %s" % [choice.choice_text, _get_failure_flavor(choice.risk_level)]

## Get success flavor text
func _get_success_flavor(reward_type: String) -> String:
	match reward_type:
		"tech_data": return "You've uncovered valuable technology data."
		"ally": return "You've gained a powerful ally for future endeavors."
		"credits": return "The risk was worth it - you're richer for it."
		"companion": return "Your friend is safe and grateful."
		_: return "Things worked out better than expected."

## Get failure flavor text  
func _get_failure_flavor(risk_level: String) -> String:
	match risk_level:
		"extreme": return "The consequences are severe and far-reaching."
		"very_high": return "This setback will be difficult to overcome."
		"high": return "The situation has become more complicated."
		_: return "You'll need to find another approach."

## Complete the story track
func complete_story_track() -> void:
	is_story_track_active = false
	story_track_phase = "completed"
	story_track_completed.emit()

## Get current story event
func get_current_event() -> StoryEvent:
	if current_event_index < story_events.size():
		return story_events[current_event_index]
	return null

## Get all available events
func get_available_events() -> Array[StoryEvent]:
	return story_events.filter(func(event): return event.is_available and not event.is_completed)

## Check if story track can progress
func can_progress() -> bool:
	var current_event = get_current_event()
	return current_event != null and evidence_pieces >= current_event.required_evidence

## Get story track status
func get_story_track_status() -> Dictionary:
	return {
		"is_active": is_story_track_active,
		"phase": story_track_phase,
		"clock_ticks": story_clock_ticks,
		"evidence_pieces": evidence_pieces,
		"current_event_index": current_event_index,
		"events_completed": completed_events.size(),
		"total_events": story_events.size(),
		"choices_made": story_choices_made.size(),
		"can_progress": can_progress()
	}

## Serialization for save/load
func serialize() -> Dictionary:
	return {
		"story_clock_ticks": story_clock_ticks,
		"evidence_pieces": evidence_pieces,
		"current_event_index": current_event_index,
		"is_story_track_active": is_story_track_active,
		"story_track_phase": story_track_phase,
		"turns_since_discovery": turns_since_discovery,
		"story_choices_made": story_choices_made,
		"story_branches_unlocked": story_branches_unlocked,
		"story_rewards_earned": story_rewards_earned,
		"completed_events": completed_events.map(func(e): return e.serialize()),
		"story_events": story_events.map(func(e): return e.serialize())
	}

func deserialize(data: Dictionary) -> void:
	story_clock_ticks = data.get("story_clock_ticks", 6)
	evidence_pieces = data.get("evidence_pieces", 0)
	current_event_index = data.get("current_event_index", 0)
	is_story_track_active = data.get("is_story_track_active", false)
	story_track_phase = data.get("story_track_phase", "inactive")
	turns_since_discovery = data.get("turns_since_discovery", 0)
	story_choices_made = data.get("story_choices_made", [])
	story_branches_unlocked = data.get("story_branches_unlocked", [])
	story_rewards_earned = data.get("story_rewards_earned", [])
	
	# Deserialize events
	completed_events.clear()
	for event_data in data.get("completed_events", []):
		var event = StoryEvent.new()
		event.deserialize(event_data)
		completed_events.append(event)
	
	story_events.clear()
	for event_data in data.get("story_events", []):
		var event = StoryEvent.new()
		event.deserialize(event_data)
		story_events.append(event)

## Story Event Class
class StoryEvent extends Resource:
	var event_id: String = ""
	var title: String = ""
	var description: String = ""
	var event_index: int = 0
	var required_evidence: int = 0
	var is_available: bool = false
	var is_completed: bool = false
	var choices: Array[StoryChoice] = []
	
	func serialize() -> Dictionary:
		return {
			"event_id": event_id,
			"title": title,
			"description": description,
			"event_index": event_index,
			"required_evidence": required_evidence,
			"is_available": is_available,
			"is_completed": is_completed,
			"choices": choices.map(func(c): return c.serialize())
		}
	
	func deserialize(data: Dictionary) -> void:
		event_id = data.get("event_id", "")
		title = data.get("title", "")
		description = data.get("description", "")
		event_index = data.get("event_index", 0)
		required_evidence = data.get("required_evidence", 0)
		is_available = data.get("is_available", false)
		is_completed = data.get("is_completed", false)
		
		choices.clear()
		for choice_data in data.get("choices", []):
			var choice = StoryChoice.new()
			choice.deserialize(choice_data)
			choices.append(choice)

## Story Choice Class
class StoryChoice extends Resource:
	var choice_text: String = ""
	var risk_level: String = "medium"
	var potential_reward: String = ""
	var evidence_gain: int = 0
	var parent_event: StoryEvent = null
	
	func serialize() -> Dictionary:
		return {
			"choice_text": choice_text,
			"risk_level": risk_level,
			"potential_reward": potential_reward,
			"evidence_gain": evidence_gain
		}
	
	func deserialize(data: Dictionary) -> void:
		choice_text = data.get("choice_text", "")
		risk_level = data.get("risk_level", "medium")
		potential_reward = data.get("potential_reward", "")
		evidence_gain = data.get("evidence_gain", 0)