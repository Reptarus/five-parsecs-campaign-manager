class_name BugHuntPhaseManager
extends Node

## Manages the Bug Hunt 3-stage campaign turn:
##   SPECIAL_ASSIGNMENTS → MISSION → POST_BATTLE
## Each stage must complete before the next begins.
## After POST_BATTLE, the turn is complete and a new turn can start.

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
signal navigation_updated(can_back: bool, can_forward: bool)

enum Phase {
	NONE = -1,
	SPECIAL_ASSIGNMENTS = 0,
	MISSION = 1,
	POST_BATTLE = 2
}

const PHASE_NAMES := {
	Phase.SPECIAL_ASSIGNMENTS: "Special Assignments",
	Phase.MISSION: "Mission",
	Phase.POST_BATTLE: "Post-Battle"
}

const PHASE_COUNT := 3

var campaign: Resource  # BugHuntCampaignCore
var current_phase: int = Phase.NONE
var previous_phase: int = Phase.NONE
var turn_number: int = 0

var _phase_complete: Dictionary = {
	Phase.SPECIAL_ASSIGNMENTS: false,
	Phase.MISSION: false,
	Phase.POST_BATTLE: false
}


func setup(campaign_resource: Resource) -> void:
	campaign = campaign_resource
	if campaign and "campaign_turn" in campaign:
		turn_number = campaign.campaign_turn


func start_new_turn() -> void:
	turn_number += 1
	if campaign and campaign.has_method("advance_turn"):
		campaign.advance_turn()

	_reset_phase_completion()
	campaign_turn_started.emit(turn_number)
	_go_to_phase(Phase.SPECIAL_ASSIGNMENTS)


func get_phase_name(phase: int = -99) -> String:
	if phase == -99:
		phase = current_phase
	return PHASE_NAMES.get(phase, "Unknown")


func complete_current_phase(result_data: Dictionary = {}) -> void:
	## Mark the current phase as done and auto-advance to next.
	if current_phase == Phase.NONE:
		return

	_phase_complete[current_phase] = true
	phase_completed.emit(current_phase)

	# Apply phase results to campaign
	_apply_phase_results(current_phase, result_data)

	# Advance or end turn
	if current_phase < Phase.POST_BATTLE:
		_go_to_phase(current_phase + 1)
	else:
		_complete_turn()


func is_phase_complete(phase: int) -> bool:
	return _phase_complete.get(phase, false)


func can_advance() -> bool:
	return _phase_complete.get(current_phase, false)


func go_to_phase(phase: int) -> void:
	## Public API for external callers (e.g. TurnController resuming after battle).
	_go_to_phase(phase)


func _go_to_phase(phase: int) -> void:
	previous_phase = current_phase
	current_phase = phase
	phase_changed.emit(previous_phase, current_phase)
	_update_navigation()


func _complete_turn() -> void:
	# Save campaign state after each turn via GameState (updates last_campaign + signals)
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() else null
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(campaign)
	elif campaign and campaign.has_method("save_to_file") and campaign.has_method("get_campaign_id"):
		# Fallback: direct save if GameState unavailable
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		campaign.save_to_file(path)

	campaign_turn_completed.emit(turn_number)


func _reset_phase_completion() -> void:
	for phase_key in _phase_complete:
		_phase_complete[phase_key] = false


func _update_navigation() -> void:
	var can_back := false  # Never go back in Bug Hunt turn phases
	var can_forward := _phase_complete.get(current_phase, false)
	navigation_updated.emit(can_back, can_forward)


func _apply_phase_results(phase: int, data: Dictionary) -> void:
	if not campaign:
		return

	match phase:
		Phase.SPECIAL_ASSIGNMENTS:
			# Apply assignment results (training, support requests)
			if data.has("completed_assignments") and campaign.has_method("apply_assignments"):
				campaign.apply_assignments(data.completed_assignments)

		Phase.MISSION:
			# Battle results (casualties, objectives, priority changes)
			if data.has("battle_result"):
				_apply_battle_results(data.battle_result)

		Phase.POST_BATTLE:
			# Post-battle processing (injuries, XP, mustering out, operational progress)
			if data.has("post_battle_result"):
				_apply_post_battle_results(data.post_battle_result)


func _apply_battle_results(result: Dictionary) -> void:
	if not campaign:
		return
	# Casualty tracking
	var casualties: Array = result.get("casualties", [])
	for casualty_id in casualties:
		if campaign.has_method("add_to_sick_bay"):
			campaign.add_to_sick_bay(str(casualty_id), result.get("injury_turns", 1))

	# Objective completion
	if result.get("objectives_completed", 0) > 0 and "extra_contact_markers" in campaign:
		campaign.extra_contact_markers += result.get("extra_contact_bonus", 0)


func _apply_post_battle_results(result: Dictionary) -> void:
	if not campaign:
		return

	# XP distribution — write back to character dicts in campaign.main_characters
	var xp_awards: Dictionary = result.get("xp_awards", {})
	if "main_characters" in campaign:
		for char_id in xp_awards:
			var xp_amount: int = xp_awards[char_id]
			for mc in campaign.main_characters:
				if mc is Dictionary:
					var mc_id: String = mc.get("id", mc.get("character_id", ""))
					if mc_id == char_id:
						mc["xp"] = mc.get("xp", 0) + xp_amount
						# Increment completed missions count
						mc["completed_missions_count"] = mc.get("completed_missions_count", 0) + 1
						break

	# Sick bay from post-battle casualty processing
	var casualties_processed: Array = result.get("casualties_processed", [])
	for entry in casualties_processed:
		if entry is Dictionary and campaign.has_method("add_to_sick_bay"):
			var cid: String = str(entry.get("id", ""))
			var turns: int = entry.get("turns", 1)
			if not cid.is_empty():
				campaign.add_to_sick_bay(cid, turns)

	# Mustered-out characters — remove from campaign roster
	var mustered_out: Array = result.get("mustered_out", [])
	for char_id in mustered_out:
		if campaign.has_method("remove_main_character"):
			campaign.remove_main_character(str(char_id))

	# Reputation changes
	if result.has("reputation_change") and "reputation" in campaign:
		campaign.reputation += result.reputation_change

	# Operational progress modifier
	if result.has("op_progress_modifier") and "operational_progress_modifier" in campaign:
		campaign.operational_progress_modifier += result.op_progress_modifier

	# Tick sick bay (reduce turns remaining for pre-existing injuries)
	if campaign.has_method("tick_sick_bay"):
		campaign.tick_sick_bay()
