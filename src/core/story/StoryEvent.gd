class_name StoryEvent
extends Resource

## Story Event Resource for Five Parsecs Story Track (Core Rules Appendix V pp.153-160)
##
## Each event represents one of the 7 sequential Story Track events.
## Events define: campaign turn modifications, battle configuration,
## deployment rules, enemy composition, objectives, and post-battle effects.

# ── Identity ────────────────────────────────────────────────────────
@export var event_id: String = ""
@export var event_number: int = 0
@export var title: String = ""
@export var page_reference: String = ""

# ── Narrative ───────────────────────────────────────────────────────
@export var narrative_intro: String = ""
@export var narrative_briefing: String = ""
@export var narrative_win: String = ""
@export var narrative_lose: String = ""

# ── Campaign Turn Modifications (Core Rules per-event restrictions) ──
## Dictionary of bools/values: cannot_track_rivals, cannot_seek_patron,
## must_travel, no_rival_interference, must_send_one_to_patron, etc.
@export var campaign_turn_mods: Dictionary = {}

# ── Battle Configuration ────────────────────────────────────────────
## Full deployment + enemy + objectives loaded from JSON
@export var deployment: Dictionary = {}
@export var enemies: Dictionary = {}
@export var objectives: Dictionary = {}

# ── Post-Battle Effects ─────────────────────────────────────────────
## Win/lose consequences: rivals added/removed, rewards, companion joins, etc.
@export var post_battle_effects: Dictionary = {}

# ── Story Clock ─────────────────────────────────────────────────────
## Ticks to set clock to after this event completes. null/0 = special (evidence-gated or final)
@export var next_clock_ticks: int = 0
## Whether next event requires travel to new world first
@export var next_event_requires_travel: bool = false

# ── Evidence Mechanic (Events 5-6 only) ─────────────────────────────
## Whether this event uses the evidence collection system
@export var evidence_gated: bool = false
## Evidence mechanic configuration (marker table, post-event check rules)
@export var evidence_mechanic: Dictionary = {}

# ── Story Track Completion (Event 7 only) ────────────────────────────
@export var is_final_event: bool = false
## Event 7 can be delayed up to N turns before "Losing the Story"
@export var max_delay_turns: int = 0

# ── Runtime State (not serialized via @export, tracked by StoryTrackSystem) ──
var is_completed: bool = false


func _init(p_id: String = "", p_title: String = "") -> void:
	event_id = p_id
	title = p_title


## Load event data from a JSON dictionary (from story_track_missions/*.json)
func load_from_json(data: Dictionary) -> void:
	event_id = data.get("event_id", "")
	event_number = data.get("event_number", 0)
	title = data.get("title", "")
	page_reference = data.get("page_reference", "")

	# Narrative
	var narr: Dictionary = data.get("narrative", {})
	narrative_intro = narr.get("intro", "")
	narrative_briefing = narr.get("briefing", "")
	narrative_win = narr.get("completion_win", "")
	narrative_lose = narr.get("completion_lose", "")

	# Campaign turn modifications
	campaign_turn_mods = data.get("campaign_turn_modifications", {})

	# Battle config
	deployment = data.get("deployment", {})
	enemies = data.get("enemies", {})
	objectives = data.get("objectives", {})

	# Post-battle
	post_battle_effects = data.get("post_battle_effects", {})

	# Clock
	var clock_val: Variant = data.get("next_clock_ticks", 0)
	next_clock_ticks = clock_val if clock_val is int else 0
	next_event_requires_travel = data.get("next_event_requires_travel", false)

	# Evidence
	evidence_gated = data.get("next_clock_method", "") == "evidence_gated"
	evidence_mechanic = data.get("evidence_mechanic", {})

	# Completion
	is_final_event = data.get("story_track_completion", false)
	max_delay_turns = data.get("campaign_turn_modifications", {}).get("can_delay_up_to", 0)


## Get human-readable summary of campaign turn restrictions for UI display
func get_turn_restriction_strings() -> Array[String]:
	var restrictions: Array[String] = []
	if campaign_turn_mods.get("cannot_track_rivals", false):
		restrictions.append("Cannot track Rivals this turn")
	if campaign_turn_mods.get("cannot_seek_patron", false):
		restrictions.append("Cannot seek a Patron this turn")
	if campaign_turn_mods.get("no_rival_interference", false):
		restrictions.append("No Rival interference this turn")
	if campaign_turn_mods.get("must_travel_immediately", false):
		restrictions.append("Must travel immediately")
	if campaign_turn_mods.get("must_send_one_to_patron", false):
		restrictions.append("One crew member must be sent to find a Patron (auto-fail)")
	if campaign_turn_mods.get("must_assign_one_crew_to_planning", false):
		restrictions.append("One crew member must plan the attack (no other actions)")
	if campaign_turn_mods.get("can_delay_one_turn", false):
		restrictions.append("May delay one additional turn if not ready")
	var delay: int = campaign_turn_mods.get("can_delay_up_to", 0)
	if delay > 0:
		restrictions.append("Can delay up to %d turns (then lose the Story)" % delay)
	return restrictions


## Get enemy summary string for UI display
func get_enemy_summary() -> String:
	var source: String = enemies.get("source_table", "unknown")
	if source == "fixed":
		var count: int = enemies.get("fixed_count", 0)
		var comp: Array = enemies.get("composition", [])
		var parts: Array[String] = []
		for entry: Dictionary in comp:
			var type_name: String = str(
				entry.get("type", "unknown")).replace("_", " ").capitalize()
			var entry_count: int = entry.get("count", 0)
			parts.append("%d %s" % [entry_count, type_name])
		if not parts.is_empty():
			return "%d enemies: %s" % [count, ", ".join(parts)]
		return "%d enemies" % count
	if source == "hired_muscle":
		return "Hired Muscle (roll on subtable)"
	if source == "marker_spawned":
		return "Enemies spawned from investigation markers"
	return "Unknown enemy composition"


## Convert to serializable dictionary for save/load
func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_number": event_number,
		"title": title,
		"page_reference": page_reference,
		"narrative_intro": narrative_intro,
		"narrative_briefing": narrative_briefing,
		"narrative_win": narrative_win,
		"narrative_lose": narrative_lose,
		"campaign_turn_mods": campaign_turn_mods.duplicate(),
		"deployment": deployment.duplicate(),
		"enemies": enemies.duplicate(),
		"objectives": objectives.duplicate(),
		"post_battle_effects": post_battle_effects.duplicate(),
		"next_clock_ticks": next_clock_ticks,
		"next_event_requires_travel": next_event_requires_travel,
		"evidence_gated": evidence_gated,
		"evidence_mechanic": evidence_mechanic.duplicate(),
		"is_final_event": is_final_event,
		"max_delay_turns": max_delay_turns,
		"is_completed": is_completed
	}


## Load from serialized dictionary (save/load)
func from_dict(data: Dictionary) -> void:
	event_id = data.get("event_id", "")
	event_number = data.get("event_number", 0)
	title = data.get("title", "")
	page_reference = data.get("page_reference", "")
	narrative_intro = data.get("narrative_intro", "")
	narrative_briefing = data.get("narrative_briefing", "")
	narrative_win = data.get("narrative_win", "")
	narrative_lose = data.get("narrative_lose", "")
	campaign_turn_mods = data.get("campaign_turn_mods", {})
	deployment = data.get("deployment", {})
	enemies = data.get("enemies", {})
	objectives = data.get("objectives", {})
	post_battle_effects = data.get("post_battle_effects", {})
	next_clock_ticks = data.get("next_clock_ticks", 0)
	next_event_requires_travel = data.get("next_event_requires_travel", false)
	evidence_gated = data.get("evidence_gated", false)
	evidence_mechanic = data.get("evidence_mechanic", {})
	is_final_event = data.get("is_final_event", false)
	max_delay_turns = data.get("max_delay_turns", 0)
	is_completed = data.get("is_completed", false)
