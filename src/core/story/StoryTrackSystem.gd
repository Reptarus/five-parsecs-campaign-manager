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
# GlobalEnums available as autoload singleton
const StoryEvent = preload("res://src/core/story/StoryEvent.gd")

# Manager references for dice system integration (accessed as autoload)
var dice_manager: Node = null

# Signals - following tested patterns
signal story_clock_advanced(ticks_remaining: int)
signal story_event_triggered(event: StoryEvent)
signal story_choice_made(choice: Dictionary)
signal evidence_discovered(evidence_count: int)
signal story_track_completed()
signal story_milestone_reached(milestone: int)

# Tutorial integration signals (for guided campaign mode)
signal tutorial_requested(event_id: String, companion_tools: Array, story_context: String)

# Story Clock mechanics (from Core Rules Appendix V, p.153)
# Clock starts at 5 ticks. After each event, clock resets to event's clock_ticks value.
var story_clock_ticks: int = 5 # Initial clock setting (Core Rules: "set the Clock at 5 Ticks")
var max_clock_ticks: int = 5
var evidence_pieces: int = 0
var current_event_index: int = 0

# Story events array (6 interconnected events per Appendix V)
var story_events: Array[StoryEvent] = []
var completed_events: Array[StoryEvent] = []
var _available_choices: Array[Dictionary] = []

# Player progress tracking
var story_choices_made: Array[Dictionary] = []
var story_branches_unlocked: Array[String] = []
var story_rewards_earned: Array[Dictionary] = []

# Story track state
var is_story_track_active: bool = false
var story_track_phase: String = "inactive" # inactive, active, climax, completed
var turns_since_discovery: int = 0

# Tutorial integration (for guided campaign mode)
var guided_mode_enabled: bool = false  # Toggle for tutorial overlays
var tutorial_config: Dictionary = {}  # Loaded from story_companion_tutorials.json

## Initialize story track with default events
func _init() -> void:
	_initialize_dice_manager()
	_initialize_story_events()
	_load_tutorial_config()

## Initialize dice manager reference
func _initialize_dice_manager() -> void:
	# Dice manager will be injected by CampaignManager since Resource class doesn't have access to scene tree
	pass

## Set dice manager reference (called by CampaignManager)
func set_dice_manager(dm: Node) -> void:
	dice_manager = dm

## Initialize 7 story events from Core Rules Appendix V (pp.153-162)
## Clock ticks between events match the book exactly.
func _initialize_story_events() -> void:
	story_events.clear()

	# Event 1: Foiled! (Clock starts at 5 ticks — set in start_story_track)
	var event1 := StoryEvent.new()
	event1.event_id = "foiled"
	event1.title = "Foiled!"
	event1.description = "A big job lined up — mega-corp, good benefits. Then hired guns were waiting at the meeting place. What's going on?"
	event1.event_type = "story_track"
	event1.trigger_conditions = {"required_evidence": 0, "clock_ticks": 3}
	event1.tutorial_config_key = "discovery_signal"
	_add_event_choices(event1, [
		{"text": "Hold the Field and investigate", "risk": "high", "reward": "intel", "evidence_gain": 2},
		{"text": "Flee the ambush", "risk": "medium", "reward": "safety", "evidence_gain": 0}
	])
	story_events.append(event1)

	# Event 2: On the Trail (Clock: 3 ticks after Event 1)
	var event2 := StoryEvent.new()
	event2.event_id = "on_the_trail"
	event2.title = "On the Trail"
	event2.description = "Your snooping paid off. Q'narr, a smuggler from the disputed sectors — you used to be tight, but he got a dirty deal you couldn't take. Now he's quite the big shot, and he's decided to get even."
	event2.event_type = "story_track"
	event2.trigger_conditions = {"required_evidence": 1, "clock_ticks": 2}
	event2.tutorial_config_key = "first_contact"
	_add_event_choices(event2, [
		{"text": "Fight Blood Storm Mercs head-on", "risk": "high", "reward": "story_point", "evidence_gain": 1},
		{"text": "Capture a mercenary for intel", "risk": "very_high", "reward": "story_point_plus", "evidence_gain": 2}
	])
	story_events.append(event2)

	# Event 3: Disrupting the Plan (Clock: 2 ticks, must travel first)
	var event3 := StoryEvent.new()
	event3.event_id = "disrupting_the_plan"
	event3.title = "Disrupting the Plan"
	event3.description = "Your old friend is up to something big. You've found where his organization stores contraband. Time to pay them a visit."
	event3.event_type = "story_track"
	event3.trigger_conditions = {"required_evidence": 2, "clock_ticks": 5}
	event3.tutorial_config_key = "conspiracy_revealed"
	_add_event_choices(event3, [
		{"text": "Plant sabotage device at center", "risk": "high", "reward": "loot", "evidence_gain": 1},
		{"text": "Drive off all enemies first", "risk": "very_high", "reward": "loot_plus", "evidence_gain": 1}
	])
	story_events.append(event3)

	# Event 4: The Enemy Strikes Back (Clock: 5 ticks after Event 3)
	var event4 := StoryEvent.new()
	event4.event_id = "enemy_strikes_back"
	event4.title = "The Enemy Strikes Back"
	event4.description = "A direct attack on your ship while docked in port! They distracted starport security. Fight for your life!"
	event4.event_type = "story_track"
	event4.trigger_conditions = {"required_evidence": 3, "clock_ticks": 3}
	event4.tutorial_config_key = "dangerous_escalation"
	_add_event_choices(event4, [
		{"text": "Defend the ship with full crew", "risk": "extreme", "reward": "xp_bonus", "evidence_gain": 1},
		{"text": "Include Sick Bay crew (Impaired)", "risk": "extreme", "reward": "xp_plus", "evidence_gain": 1}
	])
	story_events.append(event4)

	# Event 5: Kidnap (Clock: 3 ticks after Event 4)
	var event5 := StoryEvent.new()
	event5.event_id = "kidnap"
	event5.title = "Kidnap"
	event5.description = "Q'Narr has gone after another of your old companions. They're out of the business, living clean — but goons attacked their family."
	event5.event_type = "story_track"
	event5.trigger_conditions = {"required_evidence": 4, "clock_ticks": 0}
	event5.tutorial_config_key = "final_revelation"
	_add_event_choices(event5, [
		{"text": "Travel immediately to investigate", "risk": "high", "reward": "evidence", "evidence_gain": 2},
		{"text": "Take shuttle (4 crew max, 3 cr)", "risk": "medium", "reward": "evidence", "evidence_gain": 1}
	])
	story_events.append(event5)

	# Event 6: We're Coming! (Clock: evidence-gated, 1D6+evidence >= 7)
	var event6 := StoryEvent.new()
	event6.event_id = "were_coming"
	event6.title = "We're Coming!"
	event6.description = "You've tracked down where they're holding your friend. It's time for diplomacy, Fringe-style!"
	event6.event_type = "story_track"
	event6.trigger_conditions = {"required_evidence": 6, "clock_ticks": 2}
	event6.tutorial_config_key = "story_aftermath"
	_add_event_choices(event6, [
		{"text": "Stealth approach (sneak past sentries)", "risk": "high", "reward": "rescue", "evidence_gain": 0},
		{"text": "Direct assault", "risk": "very_high", "reward": "rescue", "evidence_gain": 0}
	])
	story_events.append(event6)

	# Event 7: Time to Settle This (Clock: 2 ticks, can delay up to 3 turns)
	var event7 := StoryEvent.new()
	event7.event_id = "time_to_settle_this"
	event7.title = "Time to Settle This"
	event7.description = "This is it. You've tracked your old rival to his hideout on the dead moon of a barren world. His forces are depleted. You'll never get a better chance."
	event7.event_type = "story_track"
	event7.trigger_conditions = {"required_evidence": 7, "clock_ticks": 0}
	event7.tutorial_config_key = "story_aftermath"
	_add_event_choices(event7, [
		{"text": "Storm the compound now", "risk": "extreme", "reward": "victory", "evidence_gain": 0},
		{"text": "Delay (up to 3 turns)", "risk": "medium", "reward": "preparation", "evidence_gain": 0}
	])
	story_events.append(event7)

## Add choices to a story event using global StoryEvent structure
func _add_event_choices(event: StoryEvent, choices_data: Array) -> void:
	for choice_data: Dictionary in choices_data:
		var choice_dict: Dictionary = {
			"text": choice_data.get("text", ""),
			"risk": choice_data.get("risk", "none"),
			"outcome": {
				"reward": choice_data.get("reward", ""),
				"evidence_gain": choice_data.get("evidence_gain", 0)
			}
		}
		event.add_choice(choice_dict["text"], choice_dict["outcome"], choice_dict["risk"])

## Load tutorial configuration from JSON (for guided campaign mode)
func _load_tutorial_config() -> void:
	var config_path := "res://data/tutorial/story_companion_tutorials.json"

	var file := FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		push_error("StoryTrackSystem: Failed to parse tutorial config JSON")
		return

	tutorial_config = json.data as Dictionary
	pass

## Enable or disable guided campaign mode
func set_guided_mode(enabled: bool) -> void:
	guided_mode_enabled = enabled
	if enabled:
		pass
	else:
		pass

## Emit tutorial request for a story event (helper)
func _emit_tutorial_request_for_event(event: StoryEvent) -> void:
	if tutorial_config.is_empty():
		return

	var tutorials := tutorial_config.get("tutorials", {}) as Dictionary
	var event_tutorial := tutorials.get(event.tutorial_config_key, {}) as Dictionary

	if event_tutorial.is_empty():
		return

	# Extract companion tools from tutorial config
	var companion_tools_config := event_tutorial.get("companion_tools", []) as Array
	var companion_tools: Array[String] = []

	for tool_data in companion_tools_config:
		if tool_data is Dictionary:
			var tool_name := tool_data.get("tool", "") as String
			if not tool_name.is_empty():
				companion_tools.append(tool_name)

	# Get story context
	var story_context := event_tutorial.get("story_context", "") as String

	# Emit tutorial request signal
	if not companion_tools.is_empty():
		tutorial_requested.emit(event.event_id, companion_tools, story_context)
		pass

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

## Advance the story track at end of campaign turn (Core Rules p.153 Appendix V)
## Roll 1D6: On 3+, advance clock by 1 tick
## Modifiers: +1 if 10+ turns, +1 per Quest Rumor, +1 per completed Quest
func advance_turn(campaign_turn: int = 0, quest_rumors: int = 0, quests_completed: int = 0) -> Dictionary:
	if not is_story_track_active:
		return {"advanced": false, "reason": "Story track not active"}

	turns_since_discovery += 1

	# Roll 1D6 for story clock advancement
	var roll: int = _roll_dice("Story Clock Advancement", "D6")

	# Calculate modifiers (Core Rules p.153)
	var modifier: int = 0
	if campaign_turn >= 10:
		modifier += 1  # +1 if 10+ turns completed
	modifier += quest_rumors  # +1 per Quest Rumor held
	modifier += quests_completed  # +1 per Quest completed this campaign

	var total: int = roll + modifier
	var advanced: bool = total >= 3

	var result: Dictionary = {
		"roll": roll,
		"modifier": modifier,
		"total": total,
		"threshold": 3,
		"advanced": advanced,
		"new_ticks": story_clock_ticks
	}

	if advanced:
		# Advance story clock by 1 tick (reduce remaining ticks)
		story_clock_ticks = max(0, story_clock_ticks - 1)
		result["new_ticks"] = story_clock_ticks
		story_clock_advanced.emit(story_clock_ticks)

		# Check if clock reached zero - trigger story event
		if story_clock_ticks <= 0:
			trigger_next_event()
			result["event_triggered"] = true
	else:
		pass

	return result

## Advance the story clock (per Core Rules mechanics)
func advance_story_clock(success: bool = true) -> void:
	if not is_story_track_active:
		return

	# Clock reduction based on success (per Appendix V)
	var tick_reduction: int = 2 if success else 1
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
	var dice_roll: int = _roll_dice("Story Evidence Check", "D6")
	var total_score: int = dice_roll + evidence_pieces

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

	var event: StoryEvent = story_events[current_event_index]

	# Check if player has required evidence (stored in trigger_conditions)
	var required_evidence: int = event.trigger_conditions.get("required_evidence", 0)
	if evidence_pieces >= required_evidence:
		story_event_triggered.emit(event)
		story_track_phase = "event_active"

		# Emit tutorial request if guided mode is enabled
		if guided_mode_enabled and not event.tutorial_config_key.is_empty():
			_emit_tutorial_request_for_event(event)
	else:
		# Reset clock and continue searching
		story_clock_ticks = max_clock_ticks
		story_clock_advanced.emit(story_clock_ticks)

## Make a story choice using global StoryEvent structure
func make_story_choice(event: StoryEvent, choice: Dictionary) -> Dictionary:
	if not event or choice.is_empty():
		return {"success": false, "message": "Invalid event or choice"}

	# Apply choice effects
	var outcome: Dictionary = _resolve_choice_outcome(choice)

	# Record choice
	var choice_record: Dictionary = {
		"event_id": event.event_id,
		"choice_text": choice.get("text", ""),
		"outcome": outcome,
		"timestamp": Time.get_unix_time_from_system()
	}

	story_choices_made.append(choice_record)

	# Gain evidence from choice outcome
	var evidence_gain: int = choice.get("outcome", {}).get("evidence_gain", 0)
	if evidence_gain > 0:
		discover_evidence(evidence_gain)

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
		advance_story_clock(outcome.get("success", false))

	return outcome

## Resolve choice outcome based on risk/reward
func _resolve_choice_outcome(choice: Dictionary) -> Dictionary:
	# Use dice system for outcome determination
	var outcome_roll: int = _roll_dice("Story Choice: " + choice.get("text", ""), "D6")
	var success_threshold: int = _get_success_threshold(choice.get("risk", "none"))
	var is_success: bool = outcome_roll >= success_threshold

	var outcome: Dictionary = {
		"success": is_success,
		"reward_type": choice.get("outcome", {}).get("reward", ""),
		"description": _generate_outcome_description(choice, is_success),
		"dice_roll": outcome_roll,
		"threshold": success_threshold
	}

	if is_success:
		_apply_choice_rewards(choice)
	else:
		_apply_choice_consequences(choice)

	return outcome

## Get success threshold for dice rolls (lower threshold = easier)
func _get_success_threshold(risk_level: String) -> int:
	match risk_level:
		"none": return 1 # Always succeeds
		"low": return 2 # 5 / 6.0 chance (83%)
		"medium": return 3 # 4 / 6.0 chance (67%)
		"high": return 4 # 3 / 6.0 chance (50%)
		"very_high": return 5 # 2 / 6.0 chance (33%)
		"extreme": return 6 # 1 / 6.0 chance (17%)
		_: return 3

## Apply rewards for successful choices
func _apply_choice_rewards(choice: Dictionary) -> void:
	var reward_type: String = choice.get("outcome", {}).get("reward", "")
	var reward: Dictionary = {
		"type": reward_type,
		"source": choice.get("text", ""),
		"timestamp": Time.get_unix_time_from_system()
	}

	match reward_type:
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
func _apply_choice_consequences(choice: Dictionary) -> void:
	# Consequences increase with risk level
	var risk_level: String = choice.get("risk", "none")
	match risk_level:
		"high", "very_high", "extreme":
			# High risk failures have serious consequences
			evidence_pieces = max(0, evidence_pieces - 1)
			story_clock_ticks = max(1, story_clock_ticks - 1)

## Generate outcome description
func _generate_outcome_description(choice: Dictionary, success: bool) -> String:
	var choice_text: String = choice.get("text", "Unknown choice")
	var reward_type: String = choice.get("outcome", {}).get("reward", "none")
	var risk_level: String = choice.get("risk", "none")
	
	if success:
		return "Your choice of '%s' paid off! %s" % [choice_text, _get_success_flavor(reward_type)]
	else:
		return "Your choice of '%s' didn't go as planned. %s" % [choice_text, _get_failure_flavor(risk_level)]

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
	return story_events.filter(func(event: StoryEvent): return event.can_trigger({}))

## Check if story track can progress
func can_progress() -> bool:
	var current_event: StoryEvent = get_current_event()
	if not current_event:
		return false
	var required_evidence: int = current_event.trigger_conditions.get("required_evidence", 0)
	return evidence_pieces >= required_evidence

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
		"completed_events": completed_events.map(func(e: StoryEvent): return e.to_dict() if e else {}),
		"story_events": story_events.map(func(e: StoryEvent): return e.to_dict() if e else {})
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

	# Reinitialize dice manager after deserialization
	_initialize_dice_manager()

	# Deserialize events
	completed_events.clear()
	for event_data: Dictionary in data.get("completed_events", []):
		var event := StoryEvent.new()
		if event: event.from_dict(event_data)
		completed_events.append(event)

	story_events.clear()
	for event_data: Dictionary in data.get("story_events", []):
		var event := StoryEvent.new()
		if event: event.from_dict(event_data)
		story_events.append(event)

## Helper function for dice rolling with context
func _roll_dice(context: String, pattern: String) -> int:
	## Roll dice using the dice system with proper context
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		# Fallback to basic random if dice system unavailable
		match pattern:
			"D6":
				return randi_range(1, 6)
			"D10":
				return randi_range(1, 10)
			"D66":
				return randi_range(1, 6) * 10 + randi_range(1, 6)
			"D100":
				return randi_range(1, 100)
			_:
				return randi_range(1, 6)

