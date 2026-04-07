class_name FPCM_StoryTrackSystem
extends Resource

## Story Track System — Core Rules Appendix V (pp.153-160)
##
## Manages the 7-event Q'narr revenge arc that overlays on the
## normal campaign turn flow. Uses a tick-based Story Clock to
## pace events, with each event modifying the campaign turn and
## providing a scripted battle.

# ── Dependencies ────────────────────────────────────────────────────
const StoryMissionLoaderClass = preload(
	"res://src/core/story/StoryMissionLoader.gd")

## Dice manager reference (injected by campaign system)
var dice_manager: Node = null

# ── Signals ─────────────────────────────────────────────────────────
signal story_clock_advanced(ticks_remaining: int)
signal story_event_triggered(event: StoryEvent)
signal story_track_completed(won: bool)
signal evidence_discovered(total_evidence: int)
signal story_track_started()

# ── Story Clock State (Core Rules p.153) ────────────────────────────
## Current ticks remaining before next event triggers
var story_clock_ticks: int = 5
## Whether the story track is active for this campaign
var is_story_track_active: bool = false
## Current event index (0-6, maps to events 1-7)
var current_event_index: int = 0

# ── Story Event Turn State ──────────────────────────────────────────
## True during a campaign turn that IS a Story Event
var is_story_event_turn: bool = false
## True when clock hit 0 — next turn will be a Story Event
var pending_story_event: bool = false

# ── Evidence Mechanic (Events 5-6, Core Rules pp.157-158) ──────────
var evidence_pieces: int = 0
## True after Event 5 completes, while searching for Event 6
var in_evidence_search: bool = false
## How many turns spent searching for companion location
var evidence_search_turns: int = 0

# ── Event 7 Delay (Core Rules p.159) ───────────────────────────────
## Turns remaining that player can delay Event 7 (max 3)
var delay_turns_remaining: int = 0
## True when Event 6 is done and Event 7 is available
var event_7_available: bool = false

# ── Companion State ─────────────────────────────────────────────────
## Whether the companion was rescued in Event 6
var companion_rescued: bool = false
## Whether mercenary was captured in Event 2 (affects Event 3)
var mercenary_captured: bool = false

# ── Story Track Outcome ─────────────────────────────────────────────
## "active", "won", "lost", "inactive"
var story_outcome: String = "inactive"

# ── Event Data ──────────────────────────────────────────────────────
var story_events: Array[StoryEvent] = []
var completed_event_ids: Array[String] = []
var _mission_loader: FPCM_StoryMissionLoader = null


# ── Initialization ──────────────────────────────────────────────────

func _init() -> void:
	_mission_loader = StoryMissionLoaderClass.new()


## Inject dice manager reference (called by campaign system)
func set_dice_manager(dm: Node) -> void:
	dice_manager = dm


## Start the Story Track. Called when campaign begins with
## story_track_enabled = true. (Core Rules p.153: "set Clock at 5")
func start_story_track() -> void:
	if is_story_track_active:
		return
	is_story_track_active = true
	story_outcome = "active"
	story_clock_ticks = 5
	current_event_index = 0
	evidence_pieces = 0
	in_evidence_search = false

	# Load all 7 events from JSON
	story_events = _mission_loader.load_all_events()
	if story_events.is_empty():
		push_error("StoryTrackSystem: No events loaded from JSON")
		is_story_track_active = false
		story_outcome = "inactive"
		return

	story_track_started.emit()


# ── Story Clock (Core Rules p.153) ──────────────────────────────────

## Advance story clock at end of campaign turn.
## Core Rules: Won → -1 tick. Not won → D6 (1:0, 2-5:1, 6:2).
## Clock does NOT tick during Story Event turns.
func advance_clock_end_of_turn(won_mission: bool) -> Dictionary:
	if not is_story_track_active:
		return {"advanced": false, "reason": "inactive"}
	if is_story_event_turn:
		return {"advanced": false, "reason": "story_event_turn"}
	if in_evidence_search:
		return {"advanced": false, "reason": "evidence_search"}

	var ticks_reduced: int = 0
	var roll: int = 0

	if won_mission:
		ticks_reduced = 1
	else:
		roll = _roll_d6("Story Clock")
		match roll:
			1:
				ticks_reduced = 0
			6:
				ticks_reduced = 2
			_:
				ticks_reduced = 1

	story_clock_ticks = maxi(0, story_clock_ticks - ticks_reduced)
	story_clock_advanced.emit(story_clock_ticks)

	var triggered: bool = story_clock_ticks <= 0
	if triggered:
		pending_story_event = true

	return {
		"roll": roll,
		"ticks_reduced": ticks_reduced,
		"ticks_remaining": story_clock_ticks,
		"event_triggered": triggered
	}


# ── Story Event Turn Management ─────────────────────────────────────

## Call at the START of a campaign turn to check if this is a
## Story Event turn. Returns the StoryEvent if yes, null if no.
func begin_campaign_turn() -> StoryEvent:
	if not is_story_track_active:
		return null

	# Evidence search phase (between Events 5 and 6)
	if in_evidence_search:
		return _check_evidence_search()

	# Event 7 delay check
	if event_7_available:
		return _check_event_7_delay()

	# Normal pending event
	if pending_story_event:
		pending_story_event = false
		is_story_event_turn = true
		var event: StoryEvent = get_current_event()
		if event:
			story_event_triggered.emit(event)
		return event

	is_story_event_turn = false
	return null


## Get campaign turn modifications for the current Story Event.
## Returns empty dict if not a Story Event turn.
func get_turn_modifications() -> Dictionary:
	if not is_story_event_turn:
		return {}
	var event: StoryEvent = get_current_event()
	if not event:
		return {}
	return event.campaign_turn_mods


## Get battle configuration for the current Story Event.
func get_battle_config() -> Dictionary:
	if not is_story_event_turn:
		return {}
	var event: StoryEvent = get_current_event()
	if not event:
		return {}
	return {
		"deployment": event.deployment,
		"enemies": event.enemies,
		"objectives": event.objectives,
		"is_story_battle": true,
		"event_id": event.event_id,
		"event_number": event.event_number,
	}


## Apply post-battle effects after a Story Event battle.
## Advances to next event and sets new clock value.
func apply_post_battle(won: bool) -> Dictionary:
	if not is_story_event_turn:
		return {}

	var event: StoryEvent = get_current_event()
	if not event:
		return {}

	is_story_event_turn = false
	completed_event_ids.append(event.event_id)
	event.is_completed = true

	var effects: Dictionary = event.post_battle_effects.duplicate()
	effects["won"] = won
	effects["event_id"] = event.event_id
	effects["event_number"] = event.event_number

	# Handle Event 7 (final event)
	if event.is_final_event:
		return _complete_story_track(won, effects)

	# Handle Event 5 → evidence search
	if event.evidence_gated:
		in_evidence_search = true
		evidence_search_turns = 0
		effects["entering_evidence_search"] = true

	# Set clock for next event
	current_event_index += 1
	if event.next_clock_ticks > 0:
		story_clock_ticks = event.next_clock_ticks
		story_clock_advanced.emit(story_clock_ticks)

	return effects


# ── Evidence Mechanic (Core Rules pp.157-158) ───────────────────────

## Add evidence pieces (from marker investigation during Event 5)
func add_evidence(amount: int = 1) -> void:
	evidence_pieces += amount
	evidence_discovered.emit(evidence_pieces)


## Check evidence search at start of campaign turn.
## Roll 1D6 + evidence. On 7+: Event 6 unlocks.
## Otherwise: +1 evidence, play normal turn.
func _check_evidence_search() -> StoryEvent:
	evidence_search_turns += 1
	var roll: int = _roll_d6("Evidence Search")
	var total: int = roll + evidence_pieces

	if total >= 7:
		# Found companion location — Event 6 triggers
		in_evidence_search = false
		is_story_event_turn = true
		pending_story_event = false
		var event: StoryEvent = get_current_event()
		if event:
			story_event_triggered.emit(event)
		return event

	# Still searching — gain +1 evidence, normal turn
	evidence_pieces += 1
	evidence_discovered.emit(evidence_pieces)
	is_story_event_turn = false
	return null


# ── Event 7 Delay (Core Rules p.159) ───────────────────────────────

## Check Event 7 delay at start of campaign turn.
func _check_event_7_delay() -> StoryEvent:
	if delay_turns_remaining > 0:
		delay_turns_remaining -= 1
		is_story_event_turn = false
		return null

	# Delay exhausted or player chose to go now
	event_7_available = false
	is_story_event_turn = true
	var event: StoryEvent = get_current_event()
	if event:
		story_event_triggered.emit(event)
	return event


## Player chooses to play Event 7 now (instead of delaying)
func trigger_event_7_now() -> StoryEvent:
	if not event_7_available:
		return null
	delay_turns_remaining = 0
	event_7_available = false
	is_story_event_turn = true
	var event: StoryEvent = get_current_event()
	if event:
		story_event_triggered.emit(event)
	return event


## After Event 6 completes, set up Event 7 availability
func _setup_event_7_delay() -> void:
	event_7_available = true
	delay_turns_remaining = 3


# ── Story Track Completion (Core Rules p.160) ───────────────────────

func _complete_story_track(
	won: bool, effects: Dictionary
) -> Dictionary:
	is_story_track_active = false
	is_story_event_turn = false
	story_outcome = "won" if won else "lost"
	effects["story_track_complete"] = true
	effects["story_outcome"] = story_outcome
	story_track_completed.emit(won)
	return effects


# ── Accessors ───────────────────────────────────────────────────────

func get_current_event() -> StoryEvent:
	if current_event_index < story_events.size():
		return story_events[current_event_index]
	return null


func get_status() -> Dictionary:
	return {
		"is_active": is_story_track_active,
		"outcome": story_outcome,
		"clock_ticks": story_clock_ticks,
		"current_event_index": current_event_index,
		"current_event_title": get_current_event().title if get_current_event() else "",
		"is_story_event_turn": is_story_event_turn,
		"pending_story_event": pending_story_event,
		"evidence_pieces": evidence_pieces,
		"in_evidence_search": in_evidence_search,
		"evidence_search_turns": evidence_search_turns,
		"event_7_available": event_7_available,
		"delay_turns_remaining": delay_turns_remaining,
		"companion_rescued": companion_rescued,
		"mercenary_captured": mercenary_captured,
		"events_completed": completed_event_ids.size(),
		"total_events": story_events.size(),
	}


# ── Serialization ───────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"story_clock_ticks": story_clock_ticks,
		"is_story_track_active": is_story_track_active,
		"current_event_index": current_event_index,
		"is_story_event_turn": is_story_event_turn,
		"pending_story_event": pending_story_event,
		"evidence_pieces": evidence_pieces,
		"in_evidence_search": in_evidence_search,
		"evidence_search_turns": evidence_search_turns,
		"delay_turns_remaining": delay_turns_remaining,
		"event_7_available": event_7_available,
		"companion_rescued": companion_rescued,
		"mercenary_captured": mercenary_captured,
		"story_outcome": story_outcome,
		"completed_event_ids": completed_event_ids.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	story_clock_ticks = data.get("story_clock_ticks", 5)
	is_story_track_active = data.get("is_story_track_active", false)
	current_event_index = data.get("current_event_index", 0)
	is_story_event_turn = data.get("is_story_event_turn", false)
	pending_story_event = data.get("pending_story_event", false)
	evidence_pieces = data.get("evidence_pieces", 0)
	in_evidence_search = data.get("in_evidence_search", false)
	evidence_search_turns = data.get("evidence_search_turns", 0)
	delay_turns_remaining = data.get("delay_turns_remaining", 0)
	event_7_available = data.get("event_7_available", false)
	companion_rescued = data.get("companion_rescued", false)
	mercenary_captured = data.get("mercenary_captured", false)
	story_outcome = data.get("story_outcome", "inactive")
	completed_event_ids = []
	for eid: String in data.get("completed_event_ids", []):
		completed_event_ids.append(eid)

	# Reload events from JSON after deserialize
	if is_story_track_active or story_outcome != "inactive":
		_mission_loader = StoryMissionLoaderClass.new()
		story_events = _mission_loader.load_all_events()
		# Mark completed events
		for event: StoryEvent in story_events:
			if event.event_id in completed_event_ids:
				event.is_completed = true


# ── Dice Helper ─────────────────────────────────────────────────────

func _roll_d6(context: String) -> int:
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, "D6")
	return randi_range(1, 6)
