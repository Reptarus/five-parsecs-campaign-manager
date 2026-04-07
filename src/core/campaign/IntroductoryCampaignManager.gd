class_name FPCM_IntroductoryCampaignManager
extends Resource

## Introductory Campaign Manager — Compendium pp.104-109
##
## Manages the 6-encounter tutorial (turns 0-5) that progressively
## teaches game mechanics. The Introductory Campaign replaces normal
## mission generation with scripted encounters and restricts which
## campaign phases are available each turn, unlocking more as the
## player learns.
##
## When Story Track is also enabled, the story clock is frozen during
## the intro. On completion (turn 5), the Story Track activates with
## 5 Ticks and the player receives +2 Story Points (Compendium p.109).

# ── Dependencies ────────────────────────────────────────────────────
const CompendiumMissionsExpanded = preload(
	"res://src/data/compendium_missions_expanded.gd")

# ── Signals ─────────────────────────────────────────────────────────
signal intro_turn_started(turn: int, title: String)
signal intro_completed()
signal intro_phase_unlocked(phase_name: String)

# ── State ───────────────────────────────────────────────────────────
## Whether the introductory campaign is currently running
var is_active: bool = false
## Current introductory turn (0-5). Turn 0 = Training Battle.
var current_intro_turn: int = 0
## Whether the introductory campaign has been completed
var completed: bool = false
## Titles for each intro turn (populated from Compendium data)
var turn_titles: Array[String] = []

# ── Constants ───────────────────────────────────────────────────────
## Total number of intro turns (0-5 inclusive)
const TOTAL_TURNS: int = 6
## Story Points awarded on completion (Compendium p.109)
const COMPLETION_STORY_POINTS: int = 2


# ── Initialization ──────────────────────────────────────────────────

func start_introductory_campaign() -> void:
	if is_active or completed:
		return
	is_active = true
	current_intro_turn = 0
	completed = false
	_load_turn_titles()
	var title: String = _get_turn_title(0)
	intro_turn_started.emit(0, title)


func _load_turn_titles() -> void:
	turn_titles.clear()
	var missions: Array[Dictionary] = \
		CompendiumMissionsExpanded.get_all_introductory_missions()
	turn_titles.resize(TOTAL_TURNS)
	for i: int in range(TOTAL_TURNS):
		turn_titles[i] = ""
	for mission: Dictionary in missions:
		var turn: int = mission.get("turn", -1)
		if turn >= 0 and turn < TOTAL_TURNS:
			turn_titles[turn] = mission.get("title", "")


# ── Turn Management ─────────────────────────────────────────────────

## Called at the start of each campaign turn. Returns the intro mission
## Dictionary for this turn, or empty dict if intro is done/inactive.
func begin_campaign_turn() -> Dictionary:
	if not is_active or completed:
		return {}

	var mission: Dictionary = \
		CompendiumMissionsExpanded.get_introductory_mission(
			current_intro_turn)
	if mission.is_empty():
		# Past intro range — complete the campaign
		_complete()
		return {}

	var title: String = _get_turn_title(current_intro_turn)
	intro_turn_started.emit(current_intro_turn, title)
	return mission


## Advance to the next intro turn after post-battle processing.
## Returns true if the intro campaign is now complete.
func advance_turn() -> bool:
	if not is_active or completed:
		return completed

	current_intro_turn += 1

	# Check completion: turn 5 is the last guided turn.
	# After turn 5's post-battle, the intro is done (Compendium p.109).
	if current_intro_turn >= TOTAL_TURNS:
		_complete()
		return true

	# Notify about newly unlocked phases
	_emit_phase_unlocks(current_intro_turn)
	return false


## Complete the introductory campaign.
func _complete() -> void:
	is_active = false
	completed = true
	intro_completed.emit()


# ── Turn Restrictions (Compendium pp.105-109) ───────────────────────

## Returns a Dictionary describing which campaign phases/features are
## enabled for the current intro turn. Consuming code checks these
## flags to gate UI and gameplay.
##
## Keys returned:
##   "pre_battle_enabled": Array[String] — which pre-battle steps run
##   "post_battle_enabled": Array[String] — which post-battle steps run
##   "battle_config": Dictionary — overrides for battle setup
##   "is_training_battle": bool — true for turn 0 (no consequences)
##   "instruction": String — the Compendium instruction text
func get_turn_restrictions() -> Dictionary:
	if not is_active or completed:
		return {}
	return _restrictions_for_turn(current_intro_turn)


func _restrictions_for_turn(turn: int) -> Dictionary:
	match turn:
		0:
			# Training Battle — no campaign steps, no consequences
			return {
				"pre_battle_enabled": [],
				"post_battle_enabled": [],
				"battle_config": {
					"no_deployment_conditions": true,
					"no_notable_sights": true,
					"no_unique_individuals": true,
					"no_seize_initiative": true,
				},
				"is_training_battle": true,
			}
		1:
			# Campaign Turn 1 — no pre-battle, limited post-battle
			return {
				"pre_battle_enabled": [],
				"post_battle_enabled": [
					"get_paid", "battlefield_finds", "gather_loot",
					"injuries", "experience",
				],
				"battle_config": {
					"no_deployment_conditions": true,
					"no_notable_sights": true,
					"no_unique_individuals": true,
					"seize_initiative_bonus": 1,
				},
				"is_training_battle": false,
			}
		2:
			# Campaign Turn 2 — medical + limited crew tasks + equipment
			return {
				"pre_battle_enabled": [
					"medical", "crew_tasks_limited", "assign_equipment",
				],
				"post_battle_enabled": [
					"get_paid", "battlefield_finds", "gather_loot",
					"injuries", "experience",
					"purchase", "campaign_event", "character_event",
				],
				"battle_config": {
					"has_deployment_conditions": true,
					"no_notable_sights": true,
					"no_unique_individuals": true,
				},
				"is_training_battle": false,
			}
		3:
			# Campaign Turn 3 — travel + upkeep + crew tasks + equipment
			return {
				"pre_battle_enabled": [
					"travel", "upkeep", "crew_tasks_limited",
					"assign_equipment",
				],
				"post_battle_enabled": [
					"get_paid", "battlefield_finds", "gather_loot",
					"injuries", "experience",
					"purchase", "campaign_event", "character_event",
				],
				"battle_config": {
					"no_deployment_conditions": true,
					"has_notable_sights": true,
					"no_unique_individuals": true,
					"seize_initiative_bonus": -1,
				},
				"is_training_battle": false,
			}
		4:
			# Campaign Turn 4 — full pre-battle, combat skill cap
			return {
				"pre_battle_enabled": [
					"upkeep", "crew_tasks_full", "find_patron",
					"job_offers", "assign_equipment", "resolve_rumors",
				],
				"post_battle_enabled": [
					"get_paid", "battlefield_finds", "check_invasion",
					"gather_loot", "injuries", "experience",
					"purchase", "campaign_event", "character_event",
				],
				"battle_config": {
					"has_deployment_conditions": true,
					"has_notable_sights": true,
					"has_unique_individuals": true,
					"enemy_combat_skill_cap": 1,
				},
				"is_training_battle": false,
			}
		5:
			# Campaign Turn 5 — ALL standard rules, tutorial complete
			return {
				"pre_battle_enabled": ["all"],
				"post_battle_enabled": ["all"],
				"battle_config": {},
				"is_training_battle": false,
			}
		_:
			return {}


func _emit_phase_unlocks(turn: int) -> void:
	match turn:
		2:
			intro_phase_unlocked.emit("crew_tasks")
			intro_phase_unlocked.emit("equipment")
		3:
			intro_phase_unlocked.emit("travel")
			intro_phase_unlocked.emit("upkeep")
		4:
			intro_phase_unlocked.emit("patrons")
			intro_phase_unlocked.emit("rumors")
		5:
			intro_phase_unlocked.emit("all")


# ── Status ──────────────────────────────────────────────────────────

func get_status() -> Dictionary:
	return {
		"is_active": is_active,
		"completed": completed,
		"current_turn": current_intro_turn,
		"total_turns": TOTAL_TURNS,
		"title": _get_turn_title(current_intro_turn),
		"progress": float(current_intro_turn) / float(TOTAL_TURNS),
	}


func _get_turn_title(turn: int) -> String:
	if turn >= 0 and turn < turn_titles.size():
		return turn_titles[turn]
	return ""


# ── Serialization ───────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"is_active": is_active,
		"current_intro_turn": current_intro_turn,
		"completed": completed,
	}


func deserialize(data: Dictionary) -> void:
	is_active = data.get("is_active", false)
	current_intro_turn = data.get("current_intro_turn", 0)
	completed = data.get("completed", false)
	if is_active or completed:
		_load_turn_titles()
