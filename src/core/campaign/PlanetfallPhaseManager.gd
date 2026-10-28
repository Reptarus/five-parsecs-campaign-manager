class_name PlanetfallPhaseManager
extends Node

## Manages the Planetfall 18-step campaign turn:
##   RECOVERY → REPAIRS → SCOUT_REPORTS → ENEMY_ACTIVITY → COLONY_EVENTS →
##   MISSION_DETERMINATION → LOCK_AND_LOAD → PLAY_OUT_MISSION →
##   INJURIES → EXPERIENCE → MORALE_ADJUSTMENTS → TRACK_ENEMY_INFO →
##   REPLACEMENTS → RESEARCH → BUILDING → COLONY_INTEGRITY →
##   CHARACTER_EVENT → UPDATE_TRACKING
## Each step must complete before the next begins.
## After UPDATE_TRACKING, the turn is complete and a new turn can start.
## Source: Planetfall pp.58-70

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
signal navigation_updated(can_back: bool, can_forward: bool)
## p.90 Campaign Failure: "Unity forces move in to secure the site and take over
## control." The turn stops; the controller shows the end screen.
signal campaign_ended(reason: String)

const ColonyCrisisScript := preload("res://src/core/systems/PlanetfallColonyCrisis.gd")
const MilestoneScript := preload("res://src/core/systems/PlanetfallMilestoneSystem.gd")
const RosterRulesScript := preload("res://src/core/systems/PlanetfallRosterRules.gd")
const BattleNormalizerScript := preload(
	"res://src/core/battle/PlanetfallBattleResultNormalizer.gd")

enum Phase {
	NONE = -1,
	RECOVERY = 0,
	REPAIRS = 1,
	SCOUT_REPORTS = 2,
	ENEMY_ACTIVITY = 3,
	COLONY_EVENTS = 4,
	MISSION_DETERMINATION = 5,
	LOCK_AND_LOAD = 6,
	PLAY_OUT_MISSION = 7,
	INJURIES = 8,
	EXPERIENCE = 9,
	MORALE_ADJUSTMENTS = 10,
	TRACK_ENEMY_INFO = 11,
	REPLACEMENTS = 12,
	RESEARCH = 13,
	BUILDING = 14,
	COLONY_INTEGRITY = 15,
	CHARACTER_EVENT = 16,
	UPDATE_TRACKING = 17
}

const PHASE_NAMES := {
	Phase.RECOVERY: "Recovery",
	Phase.REPAIRS: "Repairs",
	Phase.SCOUT_REPORTS: "Scout Reports",
	Phase.ENEMY_ACTIVITY: "Enemy Activity",
	Phase.COLONY_EVENTS: "Colony Events",
	Phase.MISSION_DETERMINATION: "Mission Determination",
	Phase.LOCK_AND_LOAD: "Lock and Load",
	Phase.PLAY_OUT_MISSION: "Play Out Mission",
	Phase.INJURIES: "Injuries",
	Phase.EXPERIENCE: "Experience Progression",
	Phase.MORALE_ADJUSTMENTS: "Colony Morale Adjustments",
	Phase.TRACK_ENEMY_INFO: "Track Enemy Info & Mission Data",
	Phase.REPLACEMENTS: "Replacements",
	Phase.RESEARCH: "Research",
	Phase.BUILDING: "Building",
	Phase.COLONY_INTEGRITY: "Colony Integrity",
	Phase.CHARACTER_EVENT: "Character Event",
	Phase.UPDATE_TRACKING: "Update Colony Sheet"
}

## Phase category labels for the indicator strip (Planetfall p.58)
const PHASE_CATEGORIES := {
	Phase.RECOVERY: "PRE-BATTLE",
	Phase.REPAIRS: "PRE-BATTLE",
	Phase.SCOUT_REPORTS: "PRE-BATTLE",
	Phase.ENEMY_ACTIVITY: "PRE-BATTLE",
	Phase.COLONY_EVENTS: "PRE-BATTLE",
	Phase.MISSION_DETERMINATION: "PRE-BATTLE",
	Phase.LOCK_AND_LOAD: "BATTLE",
	Phase.PLAY_OUT_MISSION: "BATTLE",
	Phase.INJURIES: "POST-BATTLE",
	Phase.EXPERIENCE: "POST-BATTLE",
	Phase.MORALE_ADJUSTMENTS: "POST-BATTLE",
	Phase.TRACK_ENEMY_INFO: "POST-BATTLE",
	Phase.REPLACEMENTS: "POST-BATTLE",
	Phase.RESEARCH: "POST-BATTLE",
	Phase.BUILDING: "POST-BATTLE",
	Phase.COLONY_INTEGRITY: "POST-BATTLE",
	Phase.CHARACTER_EVENT: "POST-BATTLE",
	Phase.UPDATE_TRACKING: "POST-BATTLE"
}

const PHASE_COUNT := 18

var campaign: Resource  # PlanetfallCampaignCore
var current_phase: int = Phase.NONE
var previous_phase: int = Phase.NONE
var turn_number: int = 0

## Per-turn transient state
var _turn_casualties: int = 0
var _turn_colony_damage: int = 0
var _story_points_blocked: bool = false
var _battle_result: Dictionary = {}
## Step 11 / Step 16 receipts ({lines, ops}); non-empty means the step has resolved.
## Persisted with the turn so a resume shows the result instead of rolling again.
var _morale_receipt: Dictionary = {}
var _integrity_receipt: Dictionary = {}
## What the mission WAS, stamped before the battle (TurnController._launch_planetfall_
## battle). The controller is rebuilt on the battle return and held this in memory
## only, so before 2026-10-27 the post-battle steps had no mission id, no opposition
## and no grunt count to read.
var _mission_stamp: Dictionary = {}
## Steps 9, 10 and 12 receipts by step name ({lines} at least). Same contract as the
## two above: non-empty means resolved, persisted, never rolled again on a resume.
var _step_receipts: Dictionary = {}
var _crisis: ColonyCrisisScript
## The Milestones the last Research or Building step delivered, for the controller to
## show once (take_milestone_receipt). The milestone state itself is on the campaign.
var _milestone_receipt: Dictionary = {}

var _phase_complete: Dictionary = {}


func _init() -> void:
	_init_phase_completion()


## ============================================================================
## SETUP
## ============================================================================

func setup(campaign_resource: Resource) -> void:
	campaign = campaign_resource
	if campaign and "campaign_turn" in campaign:
		turn_number = campaign.campaign_turn


## ============================================================================
## TURN LIFECYCLE
## ============================================================================

func start_new_turn() -> void:
	turn_number += 1
	if campaign and campaign.has_method("advance_turn"):
		campaign.advance_turn()

	_reset_turn_state()
	campaign_turn_started.emit(turn_number)
	_journal_log_turn_start(turn_number)
	_go_to_phase(Phase.RECOVERY)


func get_phase_name(phase: int = -99) -> String:
	if phase == -99:
		phase = current_phase
	return PHASE_NAMES.get(phase, "Unknown")


func get_phase_category(phase: int = -99) -> String:
	if phase == -99:
		phase = current_phase
	return PHASE_CATEGORIES.get(phase, "")


## ============================================================================
## PHASE COMPLETION
## ============================================================================

func complete_current_phase(result_data: Dictionary = {}) -> void:
	## Mark the current phase as done and auto-advance to next.
	if current_phase == Phase.NONE:
		return

	_phase_complete[current_phase] = true
	phase_completed.emit(current_phase)
	_journal_log_phase_complete(current_phase, result_data)

	# Apply phase results to campaign
	_apply_phase_results(current_phase, result_data)

	if campaign and campaign.has_method("is_failed") and campaign.is_failed():
		_end_failed_campaign()
		return

	# Advance or end turn
	var next_phase: int = _get_next_phase(current_phase)
	if next_phase != Phase.NONE:
		_go_to_phase(next_phase)
	else:
		_complete_turn()


func is_phase_complete(phase: int) -> bool:
	return _phase_complete.get(phase, false)


func can_advance() -> bool:
	return _phase_complete.get(current_phase, false)


func go_to_phase(phase: int) -> void:
	## Public API for external callers (e.g. TurnController resuming after battle).
	_go_to_phase(phase)


## ============================================================================
## PRIVATE — PHASE NAVIGATION
## ============================================================================

func _go_to_phase(phase: int) -> void:
	previous_phase = current_phase
	current_phase = phase
	# Recorded BEFORE the signal: entering PLAY_OUT_MISSION navigates away and frees
	# the turn controller, so nothing after the emit is guaranteed to run.
	_persist_phase()
	phase_changed.emit(previous_phase, current_phase)
	_update_navigation()


func _get_next_phase(phase: int) -> int:
	## Linear sequence: 0 → 1 → 2 → ... → 17 → NONE
	if phase < Phase.UPDATE_TRACKING:
		return phase + 1
	return Phase.NONE


func _complete_turn() -> void:
	# The turn is over. Until 2026-10-27 the phase stayed on UPDATE_TRACKING, and the
	# controller starts a turn only from NONE, so "Start Next Turn" re-completed step 18
	# (a second turn-end save) and turn 2 never began in-session. Set before the save so
	# the save records "between turns".
	previous_phase = current_phase
	current_phase = Phase.NONE
	_persist_phase()

	# Save campaign state after each turn
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() else null
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(campaign)
	elif campaign and campaign.has_method("save_to_file") and campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		campaign.save_to_file(path)

	campaign_turn_completed.emit(turn_number)
	_journal_log_turn_complete(turn_number)


func _end_failed_campaign() -> void:
	previous_phase = current_phase
	current_phase = Phase.NONE
	_persist_phase()
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() else null
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(campaign)
	campaign_ended.emit("crisis_collapse")


func _reset_turn_state() -> void:
	_init_phase_completion()
	_turn_casualties = 0
	_turn_colony_damage = 0
	_story_points_blocked = false
	_battle_result = {}
	_morale_receipt = {}
	_integrity_receipt = {}
	_mission_stamp = {}
	_step_receipts = {}


## ============================================================================
## RESUME — the turn's position lives on the campaign (Planetfall p.58)
## ============================================================================

## Record what this turn's mission is, before the battle (see _mission_stamp).
## stamp: id, mission_name, opposition_type, enemy_type, tactical_enemy_index,
## grunts_deployed, deployed_ids.
func stamp_mission(stamp: Dictionary) -> void:
	_mission_stamp = stamp.duplicate(true)
	_persist_phase()


func get_mission_stamp() -> Dictionary:
	return _mission_stamp


## A Story Point may be spent: the colony has one and nothing this turn blocked them.
func can_spend_story_point() -> bool:
	return campaign != null and int(campaign.story_points) > 0 and not _story_points_blocked


## The post-battle steps roll from this. It came only through temp_data, which a
## save does not carry, so a resume at Injuries had no casualties to roll. It now
## crosses PlanetfallBattleResultNormalizer, the one chokepoint that turns the battle
## screen's figure lists and the stamp into the keys pp.66-68 read.
func set_battle_result(result: Dictionary) -> void:
	_battle_result = BattleNormalizerScript.normalize(
			result.duplicate(true), _mission_stamp, _roster_snapshot(), {})
	_turn_casualties = int(_battle_result.get("battle_casualty_count", 0))
	_persist_phase()


func get_battle_result() -> Dictionary:
	return _battle_result


## The player's debrief: what only the table knows (grunt casualties, Find rolls,
## Mission Data, who killed a Boss or Leader, Cowardice, colonists lost). Applied IN
## PLACE so every post-battle panel holding this dictionary sees it. Refused once
## Step 9 has rolled, because the grunt count it carries has then been spent.
func apply_battle_debrief(debrief: Dictionary) -> Dictionary:
	if not campaign or _step_receipts.has("injuries"):
		return _battle_result
	BattleNormalizerScript.normalize(_battle_result, _mission_stamp, _roster_snapshot(),
			debrief)
	_turn_casualties = int(_battle_result.get("battle_casualty_count", 0))
	_persist_phase()
	return _battle_result


## Resolve Step 9 ONCE and apply it (p.66).
func resolve_injury_step() -> Dictionary:
	if _step_receipts.has("injuries") or not campaign:
		return _step_receipts.get("injuries", {})
	var receipt: Dictionary = _crisis_resolver().resolve_injury_step({
		"roster": _roster_snapshot(), "battle_result": _battle_result})
	(receipt.lines as Array).append_array(_apply_stability_ops(receipt.ops))
	_step_receipts["injuries"] = receipt
	_persist_phase()
	return receipt


## Steps 10 and 12 resolve in the panel (XP is written to roster dicts, Finds and
## intel through PlanetfallPostMissionSystem). The panel records what it did here, in
## the same frame as the mutation, so a resume renders the receipt and rolls nothing.
func record_step_receipt(step: String, lines: Array) -> void:
	_step_receipts[step] = {"lines": lines.duplicate()}
	_persist_phase()


func get_step_receipt(step: String) -> Dictionary:
	return _step_receipts.get(step, {})


func _roster_snapshot() -> Array:
	var roster: Array = []
	if campaign and "roster" in campaign:
		for c in campaign.roster:
			if c is Dictionary:
				roster.append(c)
	return roster


## This turn's battle casualties and the Colony Damage TAKEN so far. The post-battle
## panels are three separate instances and only the Injuries one counts casualties, so
## the Morale panel reads them here rather than from its own always-zero copy. The
## damage is informational: p.87/p.89 charge Morale when it is taken.
func get_morale_inputs() -> Dictionary:
	return {"casualties": _turn_casualties, "colony_damage": _turn_colony_damage}


## ============================================================================
## STEP 11 / STEP 16 — the colony's stability (pp.68, 87-90)
## ============================================================================

func _crisis_resolver() -> ColonyCrisisScript:
	if _crisis == null:
		_crisis = ColonyCrisisScript.new()
	return _crisis


## What Step 11 will do, for the panel to show before the player commits a Story
## Point: {in_crisis, change, before, after, incident, story_points, can_spend}.
func preview_morale_step() -> Dictionary:
	var ctx: Dictionary = _stability_context()
	var change: int = 0 if ctx.in_crisis else ColonyCrisisScript.morale_change(
			int(ctx.casualties), str(ctx.mission_id), int(ctx.colonists_lost))
	var after: int = int(ctx.morale) + change
	return {
		"in_crisis": ctx.in_crisis,
		"change": change,
		"before": int(ctx.morale),
		"after": after,
		"incident": not ctx.in_crisis and after <= _crisis_resolver().incident_threshold(),
		"upheaval": int(ctx.upheaval),
		"story_points": int(ctx.story_points),
		"can_spend": int(ctx.story_points) > 0 and not _story_points_blocked,
		"colonist_demands": bool(ctx.colonist_demands),
		"resolved": not _morale_receipt.is_empty(),
	}


## Resolve Step 11 ONCE and apply it. options: personal_appeals, crisis_reroll,
## supervisors (character ids). A second call returns the first receipt.
func resolve_morale_step(options: Dictionary = {}) -> Dictionary:
	if not _morale_receipt.is_empty() or not campaign:
		return _morale_receipt
	var ctx: Dictionary = _stability_context()
	ctx.merge(options, true)
	var receipt: Dictionary = _crisis_resolver().resolve_morale_step(ctx)
	(receipt.lines as Array).append_array(_apply_stability_ops(receipt.ops))
	_morale_receipt = receipt
	_persist_phase()
	return receipt


## Resolve Step 16 ONCE and apply it. options: emergency_repairs.
func resolve_integrity_step(options: Dictionary = {}) -> Dictionary:
	if not _integrity_receipt.is_empty() or not campaign:
		return _integrity_receipt
	var ctx: Dictionary = _stability_context()
	ctx.merge(options, true)
	var receipt: Dictionary = _crisis_resolver().resolve_integrity_step(ctx)
	(receipt.lines as Array).append_array(_apply_stability_ops(receipt.ops))
	_integrity_receipt = receipt
	_persist_phase()
	return receipt


func get_morale_receipt() -> Dictionary:
	return _morale_receipt


func get_integrity_receipt() -> Dictionary:
	return _integrity_receipt


func _stability_context() -> Dictionary:
	var roster: Array = []
	for c in campaign.roster:
		if c is Dictionary:
			roster.append(c)
	var owned: Array = campaign.research_data.get("augmentations_owned", []) \
			if campaign.research_data is Dictionary else []
	return {
		"morale": int(campaign.colony_morale),
		"integrity": int(campaign.colony_integrity),
		"casualties": _turn_casualties,
		"colonists_lost": int(_battle_result.get("colonists_lost", 0)),
		"mission_id": str(_battle_result.get("mission_id", "")),
		"mission_played": not _battle_result.is_empty(),
		"mission_won": bool(_battle_result.get("won", false)),
		"upheaval": int(campaign.political_upheaval),
		"in_crisis": bool(campaign.in_crisis),
		"colonist_demands": bool(campaign.colonist_demands),
		"story_points": int(campaign.story_points),
		"story_points_blocked": _story_points_blocked,
		"turn": int(campaign.campaign_turn),
		"roster": roster,
		"psionic_cohesion": owned.has("psionic_cohesion"),
	}


## The one place a Step 11 / Step 16 result reaches the campaign. Returns the lines
## only the application can know (mitigation, the Loyalty level reached).
func _apply_stability_ops(ops: Array) -> Array:
	var notes: Array = []
	for op in ops:
		if not op is Dictionary:
			continue
		match str(op.get("op", "")):
			"morale_adjust":
				campaign.adjust_morale(int(op.get("amount", 0)))
			"morale_set":
				campaign.set_morale(int(op.get("value", 0)))
			"story_point":
				campaign.spend_story_point()
			"upheaval":
				campaign.change_political_upheaval(int(op.get("amount", 0)))
			"upheaval_set":
				campaign.set_political_upheaval(int(op.get("value", 0)))
			"crisis":
				campaign.set_crisis(bool(op.get("active", false)))
			"campaign_failure":
				campaign.fail_campaign()
			"colony_damage":
				var res: Dictionary = campaign.take_colony_damage(
						int(op.get("amount", 0)), bool(op.get("mitigable", true)))
				_turn_colony_damage += int(res.get("taken", 0))
				notes.append("Colony Damage taken: %d%s. Integrity is now %d." % [
						int(res.get("taken", 0)),
						" (%d mitigated)" % int(res.mitigated) if int(res.get("mitigated", 0)) > 0 else "",
						int(campaign.colony_integrity)])
			"income_penalty":
				campaign.add_income_penalty(int(op.get("turn", 0)),
						int(op.get("bp", 0)), int(op.get("rp", 0)))
			"injury":
				var hurt: String = str(op.get("character_id", ""))
				var turns: int = int(op.get("turns", 0))
				# p.71 Excellent health, saved: "reduce the time required by 2 turns".
				if turns > 0 and bool(campaign.get_character_note(hurt, "saved_health", false)):
					campaign.clear_character_note(hurt, "saved_health")
					turns = maxi(turns - 2, 0)
					notes.append("Excellent health (saved, p.71): recovery 2 turns shorter.")
				if turns > 0:
					campaign.add_to_sick_bay(hurt, turns)
			"loyalty_gain":
				var up: Dictionary = campaign.raise_loyalty(str(op.get("character_id", "")))
				if not up.is_empty():
					notes.append("%s: Loyalty %s -> %s." % [up.name,
							str(up.from).capitalize(), str(up.to).capitalize()])
			"enemy_info":
				campaign.increment_enemy_info(int(op.get("enemy_index", 0)), int(op.get("amount", 1)))
			"sick_bay_extend":
				campaign.extend_recovery(str(op.get("character_id", "")), int(op.get("turns", 0)))
			"reduce_recovery":
				campaign.reduce_recovery(str(op.get("character_id", "")), int(op.get("turns", 0)))
			"recover_fully":
				campaign.reduce_recovery(str(op.get("character_id", "")), 999)
			"departed":
				campaign.dismiss_character(str(op.get("character_id", "")))
			"away":
				campaign.set_character_note(str(op.get("character_id", "")), "away_until",
						int(op.get("until_turn", 0)))
			"dispute":
				campaign.add_dispute(str(op.get("a", "")), str(op.get("b", "")), int(op.get("turn", 0)))
			"note":
				campaign.set_character_note(str(op.get("character_id", "")), str(op.get("key", "")),
						op.get("value"))
			"story_point_gain":
				campaign.add_story_points(int(op.get("amount", 0)))
			"slain":
				campaign.slay_character(str(op.get("character_id", "")))
			"xp":
				campaign.award_xp(str(op.get("character_id", "")), int(op.get("amount", 0)))
			"loyalty_loss":
				var lv: Dictionary = campaign.lower_loyalty(str(op.get("character_id", "")))
				if not lv.is_empty():
					notes.append("%s: Loyalty %s -> %s." % [lv.name,
							str(lv.from).capitalize(), str(lv.to).capitalize()])
			"protest":
				campaign.mark_protest_pending()
			"colonist_demands":
				campaign.set_colonist_demands(bool(op.get("active", false)))
			"bot_broken":
				campaign.break_bot()
			"grunt_lost":
				campaign.lose_grunt()
	return notes


## A step's REPORTED Colony Damage: `colony_damage` can be mitigated by buildings,
## `colony_damage_unmitigable` cannot (Catastrophic malfunction, p.63).
func _take_reported_damage(data: Dictionary) -> void:
	if not campaign.has_method("take_colony_damage"):
		return
	for key in ["colony_damage", "colony_damage_unmitigable"]:
		var amount: int = int(data.get(key, 0))
		if amount > 0:
			var res: Dictionary = campaign.take_colony_damage(
					amount, key == "colony_damage")
			_turn_colony_damage += int(res.get("taken", 0))


## p.90 Protests: the player picks the trooper who sits out next turn.
func assign_protest(character_id: String) -> void:
	if campaign and campaign.has_method("assign_protest"):
		campaign.assign_protest(character_id)


## Restore the turn-scoped state and return the step a resume should open on.
## PHASE_UNRECORDED (a save older than the field) keeps the old answer, RECOVERY.
## LOCK_AND_LOAD and PLAY_OUT_MISSION fall back to MISSION_DETERMINATION: the chosen
## mission and the deployment are held by the controller in memory only, and neither
## of those steps writes the campaign, so redoing them repeats no effect.
func restore_from_campaign() -> int:
	if not campaign or not campaign.has_method("has_recorded_turn_phase"):
		return Phase.RECOVERY
	var state: Dictionary = campaign.turn_state if campaign.turn_state is Dictionary else {}
	_turn_casualties = int(state.get("casualties", 0))
	_turn_colony_damage = int(state.get("colony_damage", 0))
	_story_points_blocked = bool(state.get("story_points_blocked", false))
	var br: Variant = state.get("battle_result", {})
	_battle_result = (br as Dictionary).duplicate(true) if br is Dictionary else {}
	var mr: Variant = state.get("morale_receipt", {})
	_morale_receipt = (mr as Dictionary).duplicate(true) if mr is Dictionary else {}
	var ir: Variant = state.get("integrity_receipt", {})
	_integrity_receipt = (ir as Dictionary).duplicate(true) if ir is Dictionary else {}
	var ms: Variant = state.get("mission_stamp", {})
	_mission_stamp = (ms as Dictionary).duplicate(true) if ms is Dictionary else {}
	var sr: Variant = state.get("step_receipts", {})
	_step_receipts = (sr as Dictionary).duplicate(true) if sr is Dictionary else {}
	if not campaign.has_recorded_turn_phase():
		return Phase.RECOVERY
	var phase: int = int(campaign.turn_phase)
	if phase == Phase.LOCK_AND_LOAD or phase == Phase.PLAY_OUT_MISSION:
		return Phase.MISSION_DETERMINATION
	if phase < Phase.NONE or phase > Phase.UPDATE_TRACKING:
		return Phase.RECOVERY
	for i in range(maxi(phase, 0)):
		_phase_complete[i] = true
	return phase


func _persist_phase() -> void:
	if campaign and campaign.has_method("record_turn_phase"):
		campaign.record_turn_phase(current_phase, {
			"casualties": _turn_casualties,
			"colony_damage": _turn_colony_damage,
			"story_points_blocked": _story_points_blocked,
			"battle_result": _battle_result,
			"morale_receipt": _morale_receipt,
			"integrity_receipt": _integrity_receipt,
			"mission_stamp": _mission_stamp,
			"step_receipts": _step_receipts,
		})


func _init_phase_completion() -> void:
	_phase_complete = {}
	for i in range(PHASE_COUNT):
		_phase_complete[i] = false


func _update_navigation() -> void:
	var can_back := false  # Never go back in Planetfall turn phases
	var can_forward := _phase_complete.get(current_phase, false)
	navigation_updated.emit(can_back, can_forward)


## ============================================================================
## PHASE RESULT APPLICATION
## ============================================================================

## pp.156-158. Every newly owned source on the Milestone list grants one Milestone, and
## everything it owes is resolved now. Public so a test (or a later caller) can drive it.
func deliver_milestones() -> Dictionary:
	if not campaign:
		return {}
	var receipt: Dictionary = MilestoneScript.new().deliver_new_milestones(campaign)
	if not (receipt.get("lines", []) as Array).is_empty():
		_milestone_receipt = receipt
	return receipt


## The last Milestone receipt, handed over once.
func take_milestone_receipt() -> Dictionary:
	var receipt: Dictionary = _milestone_receipt
	_milestone_receipt = {}
	return receipt


## pp.70-71 Step 17. What PlanetfallCharacterEvents reads: the roster, Sick Bay, who is
## off world, how many Tactical Enemies there are, and whether this turn's mission was won
## (null when no battle result is recorded).
func character_event_context() -> Dictionary:
	if not campaign:
		return {}
	var away: Array = []
	for c in campaign.roster:
		if c is Dictionary and campaign.is_away(str(c.get("id", ""))):
			away.append(str(c.get("id", "")))
	return {
		"roster": campaign.roster.duplicate(true),
		"sick_bay": campaign.sick_bay.duplicate(),
		"campaign_turn": int(campaign.campaign_turn),
		"tactical_enemy_count": campaign.tactical_enemies.size() \
				if "tactical_enemies" in campaign else 0,
		"last_mission_won": bool(_battle_result.won) if _battle_result.has("won") else null,
		"away": away,
	}


## The one place a Character Event result reaches the campaign (the Step 11/16 applier).
## Returns the lines only the application can know (the Loyalty level reached).
func apply_character_event_ops(ops: Array) -> Array:
	if not campaign:
		return []
	var notes: Array = _apply_stability_ops(ops)
	_persist_phase()
	return notes


## p.63 Hostile wildlife: "Unless you play a Patrol Mission this turn, adjust Colony
## Morale by -2." Owed only when the event was accepted (declining pays at once), and
## settled once, when the mission is chosen. Pitched Battle forced on the colony is not a
## Patrol either, so it pays too.
func _settle_patrol_commitment(data: Dictionary) -> void:
	if not "patrol_required_turn" in campaign \
			or int(campaign.patrol_required_turn) != int(campaign.campaign_turn):
		return
	campaign.patrol_required_turn = -1
	var mission: Variant = data.get("selected_mission", {})
	var mission_id: String = str(mission.get("id", "")) if mission is Dictionary else ""
	if mission_id == "patrol":
		record_step_receipt("mission_determination",
				["Hostile wildlife: the Patrol Mission keeps the colonists calm."])
		return
	campaign.adjust_morale(-2)
	record_step_receipt("mission_determination",
			["Hostile wildlife: no Patrol Mission this turn. Colony Morale -2 (p.63)."])


## p.69 Step 13. Dismissals first ("cannot be returned"), then each replacement the player
## took, as the class's standard character at Loyalty Committed, while the roster has
## room. Returns the ids added. Public so a test can drive it without the dialog.
func resolve_replacements(data: Dictionary) -> Array:
	var added: Array = []
	if not campaign or not "roster" in campaign:
		return added
	for id in data.get("dismissed", []):
		if campaign.has_method("dismiss_character"):
			campaign.dismiss_character(str(id))
	var capacity: int = RosterRulesScript.roster_capacity(campaign)
	for entry in data.get("new_characters", []):
		if campaign.roster.size() >= capacity:
			break
		var cls: String = str((entry as Dictionary).get("class", "")) if entry is Dictionary else ""
		if not RosterRulesScript.REPLACEMENT_CLASSES.has(cls):
			continue
		var id: String = RosterRulesScript.next_character_id(campaign)
		campaign.add_roster_character(RosterRulesScript.standard_character(
				cls, id, "Colonist %d" % (campaign.roster.size() + 1)))
		added.append(id)
	return added


## The extra rolls a Milestone queued for this step are spent with it, whether or not
## the step found anything to roll against.
func _spend_extra_rolls(kind: String) -> void:
	if campaign.has_method("clear_extra_rolls"):
		campaign.clear_extra_rolls(kind)


func _apply_phase_results(phase: int, data: Dictionary) -> void:
	if not campaign:
		return

	match phase:
		Phase.RECOVERY:
			# Sick bay tick handled by panel calling campaign.tick_sick_bay()
			pass

		Phase.REPAIRS:
			# Colony damage repair + RM conversion handled by panel
			if data.has("rm_spent"):
				var rm: int = data.get("rm_spent", 0)
				if campaign.has_method("spend_raw_materials"):
					campaign.spend_raw_materials(rm)

		Phase.SCOUT_REPORTS:
			# Scout explore results applied by panel
			pass

		Phase.ENEMY_ACTIVITY:
			# Enemy activity effects applied by panel or auto-resolve; Colony Damage
			# is applied here so mitigation and its Morale cost happen once (p.87).
			# p.61 Waiting for the Right Moment: the Story Point is spent HERE, on
			# completion, so a resume of the step cannot spend it and then roll anyway.
			if bool(data.get("waited", false)) and can_spend_story_point():
				campaign.spend_story_point()
			_take_reported_damage(data)
			_spend_extra_rolls("enemy_activity")

		Phase.COLONY_EVENTS:
			# Colony event effects applied by panel, except Colony Damage (as above).
			_take_reported_damage(data)
			_spend_extra_rolls("colony_event")
			if data.has("story_points_blocked"):
				_story_points_blocked = data.get("story_points_blocked", false)

		Phase.MISSION_DETERMINATION:
			# Selected mission stored for Lock and Load
			_settle_patrol_commitment(data)

		Phase.LOCK_AND_LOAD:
			# Deployment configured, equipment assigned
			pass

		Phase.PLAY_OUT_MISSION:
			# Battle results stored in temp data by TacticalBattleUI
			pass

		Phase.INJURIES:
			# p.66. The panel resolves it on its button, after the debrief; a step
			# completed without that press still rolls here, once. The Step 11 casualty
			# count is NOT taken from the panel any more: it is fixed at the battle by
			# the normalizer (battle_casualty_count), before any injury roll.
			resolve_injury_step()

		Phase.EXPERIENCE:
			# XP distribution handled by panel writing to roster dicts
			pass

		Phase.MORALE_ADJUSTMENTS:
			# p.68 Step 11. The panel resolves it when the player presses its button
			# (so a Story Point can be offered first); a step completed without that
			# press still resolves here, and resolve_morale_step() runs only once.
			resolve_morale_step()

		Phase.TRACK_ENEMY_INFO:
			# Enemy info + mission data counters updated by panel
			pass

		Phase.REPLACEMENTS:
			# p.69 Step 13. The dialog reports what the player took; nothing read it
			# before, so every replacement was announced and lost.
			resolve_replacements(data)

		Phase.RESEARCH, Phase.BUILDING:
			# RP / BP spending is handled by the panels. A source on p.156's list grants
			# its Milestone here, once (the controller used to re-grant every step).
			deliver_milestones()

		Phase.COLONY_INTEGRITY:
			# pp.87-88 Step 16, resolved once, as Step 11.
			resolve_integrity_step()

		Phase.CHARACTER_EVENT:
			# Character event effects applied by panel
			_spend_extra_rolls("character_event")

		Phase.UPDATE_TRACKING:
			# Final save — handled by _complete_turn()
			pass


# ── Journal integration (cross-mode coverage) ────────────────────────

## Curated set of phases that warrant a journal entry. The 18-step turn
## would otherwise spam ~20 entries per turn; this curated list keeps the
## chronicle readable while covering the narrative-significant beats.
const _JOURNAL_PHASES: Array[int] = [
	Phase.COLONY_EVENTS,
	Phase.PLAY_OUT_MISSION,
	Phase.COLONY_INTEGRITY,
	Phase.CHARACTER_EVENT,
]


func _journal() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/CampaignJournal")


func _colony_state_summary() -> String:
	## Compact colony-state badge for journal descriptions.
	if campaign == null or not "colony" in campaign:
		return ""
	var c: Dictionary = campaign.colony
	return "Morale: %d · Integrity: %d · Grunts: %d" % [
		int(c.get("morale", 0)),
		int(c.get("integrity", 0)),
		int(c.get("grunts", 0)),
	]


func _journal_log_turn_start(turn: int) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	var summary: String = _colony_state_summary()
	var desc: String = "Operational turn %d opens with Recovery." % turn
	if not summary.is_empty():
		desc += " %s" % summary
	j.create_entry({
		"type": "milestone",
		"title": "Planetfall — Turn %d begins" % turn,
		"description": desc,
		"turn_number": turn,
		"tags": ["planetfall", "milestone", "campaign_setup"],
		"mood": "neutral",
	})


func _journal_log_phase_complete(phase: int, _result_data: Dictionary) -> void:
	if not _JOURNAL_PHASES.has(phase):
		return  # Skip low-signal phases to keep the chronicle readable
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	var phase_name: String = PHASE_NAMES.get(phase, "Unknown")
	var summary: String = _colony_state_summary()
	var desc: String = "Phase complete: %s." % phase_name
	if not summary.is_empty():
		desc += " %s" % summary
	# Pick entry type by phase semantics for taxonomy alignment
	var entry_type: String = "milestone"
	if phase == Phase.PLAY_OUT_MISSION:
		entry_type = "battle"
	elif phase == Phase.CHARACTER_EVENT:
		entry_type = "character_event"
	j.create_entry({
		"type": entry_type,
		"title": "Planetfall — %s" % phase_name,
		"description": desc,
		"turn_number": turn_number,
		"tags": ["planetfall", "milestone"],
		"mood": "neutral",
	})


func _journal_log_turn_complete(turn: int) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	var summary: String = _colony_state_summary()
	var desc: String = "Operational turn %d finished." % turn
	if not summary.is_empty():
		desc += " %s" % summary
	var casualty_note: String = ""
	if _turn_casualties > 0:
		casualty_note = " Casualties this turn: %d." % _turn_casualties
	j.create_entry({
		"type": "milestone",
		"title": "Planetfall — Turn %d completed" % turn,
		"description": desc + casualty_note,
		"turn_number": turn,
		"tags": ["planetfall", "milestone"],
		"mood": "somber" if _turn_casualties > 0 else "neutral",
	})
