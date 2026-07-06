class_name BattleObjectiveTracker
extends RefCounted

## Single owner of ONE battle's end-state progress.
##
## This is the missing pipe between three pre-existing-but-disconnected pieces:
##   - MissionObjectiveSystem.check_completion() (the rules math, was never called)
##   - VictoryProgressPanel (the UI, was never fed)
##   - the post-battle `success` signal (was never populated for non-LOG_ONLY tiers)
##
## Design: this tracker does NOT own a parallel progress dict. It drives
## MissionObjectiveSystem's *internal* state via update_progress() and reads back
## check_completion(). It adds NO game values — every threshold is mirrored from,
## or delegated to, MissionObjectiveSystem (Core Rules pp.89-91).

const MissionObjectiveSystem = preload("res://src/core/battle/MissionObjectiveSystem.gd")

## Objective IDs whose completion MissionObjectiveSystem.check_completion() can evaluate.
const COVERED_IDS: Array[String] = [
	"FIGHT_OFF", "ACQUIRE", "MOVE_THROUGH", "PATROL",
	"DEFEND", "SEARCH", "PROTECT", "DELIVER",
]

## Counter caps MIRROR MissionObjectiveSystem.check_completion() (L98, L100).
## NOT new game data — kept here only because that switch does not expose them.
## KEEP IN SYNC with MissionObjectiveSystem.check_completion() if it changes.
const COUNTER_TARGETS: Dictionary = {
	# Core Rules p.90 + mission_objectives.json (the SSOT): Move Through = 2 crew,
	# Patrol = 3 points. Were 3/4 — Patrol was unwinnable (only 3 markers placed).
	"MOVE_THROUGH": {"key": "crew_exited", "target": 2},     # check_completion MOVE_THROUGH
	"PATROL": {"key": "markers_checked", "target": 3},        # check_completion PATROL
}

## Survival objectives: complete when rounds_survived >= target.
## DEFEND target mirrors check_completion() L102. INVASION_SURVIVE has no
## check_completion() case (Compendium invasion battles) — it maps to the same
## survival semantics; the round count is BattlePhase's own victory_condition
## text ("Survive 6 rounds"), not a value invented here.
const SURVIVE_TARGETS: Dictionary = {
	"DEFEND": 6,
	"INVASION_SURVIVE": 6,
}

## Boolean covered objectives (progress is 0 or 1, evaluated by check_completion()).
const BOOL_COVERED: Array[String] = ["ACQUIRE", "SEARCH", "PROTECT", "DELIVER"]

var _system: Resource = null            # FPCM_MissionObjectiveSystem instance
var _objective_id: String = ""          # normalized objective id (join key)
var _objective_name: String = ""
var _victory_text: String = ""
var _has_objective: bool = false        # false => caller must use victory/held_field fallback
var _is_covered: bool = false           # check_completion() can evaluate this id
var _is_counter: bool = false
var _is_survival: bool = false
var _is_bool_covered: bool = false
var _enemy_count_initial: int = 0
var _round: int = 0
var _turn_limit: int = -1               # -1 = no turn limit
var _manual_met: bool = false           # uncovered objectives: player-driven completion
var _is_fight_off: bool = false         # FIGHT_OFF: player-driven enemy-defeated counter

## Resolve the active objective and seed progress. Safe to call with an empty
## dict — leaves _has_objective false so the caller falls back to won/held_field.
func init_from_context(mission_objective: Dictionary, enemy_count: int) -> void:
	if mission_objective == null or mission_objective.is_empty():
		_has_objective = false
		return

	var raw_type: String = str(mission_objective.get("type", "")).to_upper().strip_edges()
	if raw_type == "":
		_has_objective = false
		return

	_objective_id = raw_type
	_objective_name = str(mission_objective.get("name", raw_type))
	_victory_text = str(mission_objective.get("victory_condition", ""))
	_enemy_count_initial = maxi(enemy_count, 0)
	_has_objective = true

	_is_covered = COVERED_IDS.has(raw_type)
	_is_counter = COUNTER_TARGETS.has(raw_type)
	_is_survival = SURVIVE_TARGETS.has(raw_type)
	_is_bool_covered = BOOL_COVERED.has(raw_type)
	# FIGHT_OFF: the app cannot reliably tell which token died on the physical
	# table (the unit right-click handler exposes an ambiguous index), so the
	# player drives "enemies defeated" via a counter — hybrid companion model.
	_is_fight_off = raw_type == "FIGHT_OFF"
	if _is_survival:
		_turn_limit = int(SURVIVE_TARGETS[raw_type])

	_system = MissionObjectiveSystem.new()
	# get_objective_by_id() may be null when the registry came from JSON without
	# this id — construct a minimal Objective so check_completion()'s switch
	# (which keys on objective_id) still resolves.
	var obj = _system.get_objective_by_id(raw_type)
	if obj == null:
		obj = MissionObjectiveSystem.Objective.new()
		obj.objective_id = raw_type
		obj.name = _objective_name
		obj.victory_condition = _victory_text
	_system.current_objective = obj

	# Seed the progress dict with neutral defaults so check_completion()'s
	# `.get(key, default)` calls behave before any live update.
	_system.update_progress("enemies_remaining", _enemy_count_initial)
	_system.update_progress("enemies_fled", false)
	_system.update_progress("rounds_survived", 0)
	_system.update_progress("objective_intact", true)
	_system.update_progress("crew_exited", 0)
	_system.update_progress("markers_checked", 0)
	_system.update_progress("item_secured", false)
	_system.update_progress("exited_with_item", false)
	_system.update_progress("item_found", false)
	_system.update_progress("vip_alive", true)
	_system.update_progress("battle_won", false)
	_system.update_progress("delivered", false)

## Round driver — called from TacticalBattleUI._on_round_started().
func on_round_advanced(round_number: int) -> void:
	if not _has_objective:
		return
	_round = maxi(round_number, _round)
	_system.update_progress("rounds_survived", _round)

## Casualty driver — called at the existing battle_round_hud.report_casualty() site.
func on_enemy_casualty(count: int = 1) -> void:
	if not _has_objective:
		return
	var remaining: int = int(_system.objective_progress.get(
		"enemies_remaining", _enemy_count_initial))
	_system.update_progress("enemies_remaining", maxi(remaining - count, 0))

## Player override — from VictoryProgressPanel.objective_progress_input.
func set_manual(key: String, value: Variant) -> void:
	if not _has_objective:
		return
	if key == "objective_met":
		_manual_met = bool(value)
		return
	_system.update_progress(key, value)

## Route a VictoryProgressPanel override (panel only knows the objective id;
## the key-mapping lives here, the single owner). value is int for counters,
## bool for toggles.
func apply_panel_input(value: Variant) -> void:
	if not _has_objective:
		return
	if _is_fight_off:
		# value = enemies the player reports defeated → remaining.
		var defeated: int = clampi(int(value), 0, _enemy_count_initial)
		set_manual("enemies_remaining",
			maxi(_enemy_count_initial - defeated, 0))
	elif _is_counter:
		set_manual(COUNTER_TARGETS[_objective_id]["key"], int(value))
	elif _is_bool_covered:
		match _objective_id:
			"ACQUIRE":
				set_manual("item_secured", bool(value))
				set_manual("exited_with_item", bool(value))
			"SEARCH":
				set_manual("item_found", bool(value))
			"PROTECT":
				set_manual("battle_won", bool(value))
			"DELIVER":
				set_manual("delivered", bool(value))
	else:
		set_manual("objective_met", bool(value))

## Mark/clear the DEFEND-style "objective held by enemy" failure flag.
func set_objective_intact(intact: bool) -> void:
	if _has_objective:
		_system.update_progress("objective_intact", intact)

func is_complete() -> bool:
	if not _has_objective:
		return false
	if _is_survival:
		var target: int = int(SURVIVE_TARGETS[_objective_id])
		if not bool(_system.objective_progress.get("objective_intact", true)):
			return false
		return int(_system.objective_progress.get("rounds_survived", 0)) >= target
	if _is_covered:
		return _system.check_completion()
	# Uncovered (ACCESS / ELIMINATE / SECURE / AMBUSH / ESCAPE / unknown):
	# no rules-sourced completion math — player-driven only.
	return _manual_met

func is_failed() -> bool:
	if not _has_objective:
		return false
	if not bool(_system.objective_progress.get("objective_intact", true)):
		return true
	if _turn_limit >= 0 and _round > _turn_limit and not is_complete():
		return true
	return false

## -1 = no turn limit (matches VictoryProgressPanel.set_turns_remaining contract).
func get_turns_remaining() -> int:
	if _turn_limit < 0:
		return -1
	return maxi(_turn_limit - _round, 0)

## Rows for VictoryProgressPanel.set_conditions(). One row per objective; the
## `interactive` flag tells the panel to render a player-override control for
## state the app cannot see on the physical table.
func get_panel_conditions() -> Array:
	if not _has_objective:
		return []
	var status: String = "pending"
	if is_complete():
		status = "complete"
	elif is_failed():
		status = "failed"
	var interactive: bool = (_is_counter or _is_bool_covered
		or _is_fight_off or not _is_covered)
	return [{
		"id": _objective_id,
		"name": _objective_name,
		"description": _victory_text,
		"progress": _progress_fraction(),
		"status": status,
		"interactive": interactive,
		"input_kind": _input_kind(),
		"input_max": _input_max(),
	}]

## 0.0-1.0 progress for the panel bar/row.
func _progress_fraction() -> float:
	if not _has_objective:
		return 0.0
	if is_complete():
		return 1.0
	if _objective_id == "FIGHT_OFF":
		if _enemy_count_initial <= 0:
			return 0.0
		var remaining: int = int(_system.objective_progress.get(
			"enemies_remaining", _enemy_count_initial))
		return clampf(
			1.0 - (float(remaining) / float(_enemy_count_initial)), 0.0, 1.0)
	if _is_counter:
		var spec: Dictionary = COUNTER_TARGETS[_objective_id]
		var target: int = int(spec["target"])
		if target <= 0:
			return 0.0
		var have: int = int(_system.objective_progress.get(spec["key"], 0))
		return clampf(float(have) / float(target), 0.0, 1.0)
	if _is_survival:
		var s_target: int = int(SURVIVE_TARGETS[_objective_id])
		if s_target <= 0:
			return 0.0
		var survived: int = int(_system.objective_progress.get(
			"rounds_survived", 0))
		return clampf(float(survived) / float(s_target), 0.0, 1.0)
	return 0.0

## Hint for the panel: which override widget (if any) to render.
func _input_kind() -> String:
	if _is_counter or _is_fight_off:
		return "counter"
	if _is_bool_covered:
		return "bool"
	if not _is_covered:
		return "bool"  # uncovered: manual "objective met" toggle
	return "none"

func _input_max() -> int:
	if _is_fight_off:
		return _enemy_count_initial
	if _is_counter:
		return int(COUNTER_TARGETS[_objective_id]["target"])
	return 1

## Authoritative post-battle success signal. For covered/survival objectives
## this is the rules-accurate result; for uncovered objectives, rival battles,
## or no objective it falls back to the caller's existing heuristic so behavior
## is NEVER worse than before this change.
func get_mission_success(won_fallback: bool, held_field_fallback: bool) -> bool:
	if not _has_objective:
		return won_fallback or held_field_fallback
	if _is_covered or _is_survival:
		return is_complete()
	# Uncovered objective: trust the player's manual mark if set, else fall back.
	if _manual_met:
		return true
	return won_fallback or held_field_fallback

## Pre-fill payload for BattleResultsInputForm (LOG_ONLY) / result-dict enrichment.
func get_result_prefill() -> Dictionary:
	var enemies_remaining: int = int(_system.objective_progress.get(
		"enemies_remaining", _enemy_count_initial)) if _has_objective else _enemy_count_initial
	return {
		"victory": is_complete(),
		"enemies_defeated": maxi(_enemy_count_initial - enemies_remaining, 0),
		"rounds": _round,
		"held_field": is_complete(),
	}

## True when completion can be derived from rounds + enemy counts alone
## (no player table-state needed) — safe to trust in the auto-resolve path.
func is_auto_derivable() -> bool:
	return _is_fight_off or _is_survival

func get_objective_id() -> String:
	return _objective_id

func get_objective_name() -> String:
	return _objective_name

func has_objective() -> bool:
	return _has_objective
