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

	# Apply phase results to campaign
	_apply_phase_results(current_phase, result_data)

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
	phase_changed.emit(previous_phase, current_phase)
	_update_navigation()


func _get_next_phase(phase: int) -> int:
	## Linear sequence: 0 → 1 → 2 → ... → 17 → NONE
	if phase < Phase.UPDATE_TRACKING:
		return phase + 1
	return Phase.NONE


func _complete_turn() -> void:
	# Save campaign state after each turn
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() else null
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(campaign)
	elif campaign and campaign.has_method("save_to_file") and campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		campaign.save_to_file(path)

	campaign_turn_completed.emit(turn_number)


func _reset_turn_state() -> void:
	_init_phase_completion()
	_turn_casualties = 0
	_turn_colony_damage = 0
	_story_points_blocked = false


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
			# Enemy activity effects applied by panel or auto-resolve
			if data.has("colony_damage"):
				_turn_colony_damage += data.get("colony_damage", 0)
				if campaign.has_method("adjust_integrity"):
					campaign.adjust_integrity(-data.get("colony_damage", 0))

		Phase.COLONY_EVENTS:
			# Colony event effects applied by panel
			if data.has("story_points_blocked"):
				_story_points_blocked = data.get("story_points_blocked", false)

		Phase.MISSION_DETERMINATION:
			# Selected mission stored for Lock and Load
			pass

		Phase.LOCK_AND_LOAD:
			# Deployment configured, equipment assigned
			pass

		Phase.PLAY_OUT_MISSION:
			# Battle results stored in temp data by TacticalBattleUI
			pass

		Phase.INJURIES:
			# Injury processing
			if data.has("casualties_count"):
				_turn_casualties = data.get("casualties_count", 0)
			if data.has("grunt_losses"):
				var losses: int = data.get("grunt_losses", 0)
				for i in range(losses):
					if campaign.has_method("lose_grunt"):
						campaign.lose_grunt()

		Phase.EXPERIENCE:
			# XP distribution handled by panel writing to roster dicts
			pass

		Phase.MORALE_ADJUSTMENTS:
			# Automatic morale adjustments (Planetfall p.68)
			if campaign.has_method("apply_morale_adjustments"):
				campaign.apply_morale_adjustments(_turn_casualties, _turn_colony_damage)

		Phase.TRACK_ENEMY_INFO:
			# Enemy info + mission data counters updated by panel
			pass

		Phase.REPLACEMENTS:
			# New characters/grunts added by panel
			pass

		Phase.RESEARCH:
			# RP spending handled by panel + ResearchSystem
			pass

		Phase.BUILDING:
			# BP spending handled by panel + BuildingSystem
			pass

		Phase.COLONY_INTEGRITY:
			# Integrity failure check handled by panel
			pass

		Phase.CHARACTER_EVENT:
			# Character event effects applied by panel
			pass

		Phase.UPDATE_TRACKING:
			# Final save — handled by _complete_turn()
			pass
