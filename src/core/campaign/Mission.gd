@tool
extends Resource
class_name Mission

## Mission Resource - Represents a job or objective for the crew
## Used for patron jobs, opportunities, and story missions

signal mission_status_changed(new_status: MissionStatus)
signal objective_updated(objective_key: String, new_value)

enum MissionType {
	PATRON_JOB,
	OPPORTUNITY,
	STORY_MISSION,
	QUEST_STEP,
	RIVALRY
}

enum MissionStatus {
	AVAILABLE,
	ACCEPTED,
	IN_PROGRESS,
	COMPLETED,
	FAILED,
	EXPIRED
}

enum ObjectiveType {
	PATROL,           # Reach center with 2+ crew, Hold Field
	FIGHT,            # Defeat all enemies
	DEFEND,           # Protect target for X rounds
	SEARCH,           # Find items on battlefield
	DELIVER,          # Get item to extraction point
	SABOTAGE,         # Destroy target
	RESCUE,           # Extract friendly
	ELIMINATE         # Kill specific enemy
}

# === Core Properties ===
@export var mission_id: String = ""
@export var mission_name: String = ""
@export var description: String = ""
@export var mission_type: MissionType = MissionType.PATRON_JOB

# === Patron Info ===
@export var patron_name: String = ""
@export var patron_faction: String = ""
@export var patron_reputation_required: int = 0

# === Objective ===
@export var objective_type: ObjectiveType = ObjectiveType.FIGHT
@export var objective_description: String = ""
@export var objective_parameters: Dictionary = {}  # e.g., {"crew_required": 2, "hold_rounds": 1}

# === Rewards ===
@export var reward_credits: int = 0
@export var reward_reputation: int = 0
@export var reward_loot_rolls: int = 0
@export var reward_story_points: int = 0
@export var bonus_rewards: Array[Dictionary] = []  # e.g., [{"type": "item", "name": "Rare Weapon"}]

# === Requirements & Conditions ===
@export var required_crew_size: int = 1
@export var danger_level: int = 1  # 1-5
@export var time_limit_turns: int = -1  # -1 = no limit
@export var special_conditions: Array[String] = []

# === State ===
@export var status: MissionStatus = MissionStatus.AVAILABLE
@export var turns_accepted: int = 0
@export var turns_remaining: int = -1


func _init() -> void:
	if mission_id.is_empty():
		mission_id = _generate_mission_id()


func _generate_mission_id() -> String:
	return "mission_%s_%d" % [mission_type, Time.get_unix_time_from_system()]


# === Status Management ===

func accept_mission() -> bool:
	if status != MissionStatus.AVAILABLE:
		return false
	status = MissionStatus.ACCEPTED
	turns_accepted = 0
	if time_limit_turns > 0:
		turns_remaining = time_limit_turns
	mission_status_changed.emit(status)
	return true


func start_mission() -> bool:
	if status != MissionStatus.ACCEPTED:
		return false
	status = MissionStatus.IN_PROGRESS
	mission_status_changed.emit(status)
	return true


func complete_mission() -> Dictionary:
	if status != MissionStatus.IN_PROGRESS:
		return {}
	status = MissionStatus.COMPLETED
	mission_status_changed.emit(status)
	return get_rewards()


func fail_mission(reason: String = "") -> void:
	status = MissionStatus.FAILED
	mission_status_changed.emit(status)


func expire_mission() -> void:
	if status in [MissionStatus.AVAILABLE, MissionStatus.ACCEPTED]:
		status = MissionStatus.EXPIRED
		mission_status_changed.emit(status)


# === Reward Retrieval ===

func get_rewards() -> Dictionary:
	return {
		"credits": reward_credits,
		"reputation": reward_reputation,
		"loot_rolls": reward_loot_rolls,
		"story_points": reward_story_points,
		"bonus": bonus_rewards.duplicate()
	}


func get_reward_summary() -> String:
	var parts: Array[String] = []
	if reward_credits > 0:
		parts.append("%d Credits" % reward_credits)
	if reward_reputation > 0:
		parts.append("+%d Rep" % reward_reputation)
	if reward_loot_rolls > 0:
		parts.append("%d Loot Roll%s" % [reward_loot_rolls, "s" if reward_loot_rolls > 1 else ""])
	if reward_story_points > 0:
		parts.append("+%d SP" % reward_story_points)
	return " • ".join(parts) if parts.size() > 0 else "No rewards"


# === Objective Helpers ===

func get_objective_display() -> Dictionary:
	## Get formatted objective for UI display
	return {
		"type": ObjectiveType.keys()[objective_type],
		"description": objective_description,
		"short_name": _get_objective_short_name(),
		"details": _get_objective_details()
	}


func _get_objective_short_name() -> String:
	match objective_type:
		ObjectiveType.PATROL: return "Patrol"
		ObjectiveType.FIGHT: return "Fight"
		ObjectiveType.DEFEND: return "Defend"
		ObjectiveType.SEARCH: return "Search"
		ObjectiveType.DELIVER: return "Deliver"
		ObjectiveType.SABOTAGE: return "Sabotage"
		ObjectiveType.RESCUE: return "Rescue"
		ObjectiveType.ELIMINATE: return "Eliminate"
		_: return "Unknown"


func _get_objective_details() -> String:
	match objective_type:
		ObjectiveType.PATROL:
			var crew_req = objective_parameters.get("crew_required", 2)
			return "Reach center with %d+ crew, then Hold the Field" % crew_req
		ObjectiveType.FIGHT:
			return "Defeat all enemies on the battlefield"
		ObjectiveType.DEFEND:
			var rounds = objective_parameters.get("rounds", 3)
			return "Protect the target for %d rounds" % rounds
		ObjectiveType.SEARCH:
			var items = objective_parameters.get("items_required", 1)
			return "Find %d item(s) and extract" % items
		ObjectiveType.DELIVER:
			return "Carry item to extraction point"
		ObjectiveType.SABOTAGE:
			return "Destroy the target objective"
		ObjectiveType.RESCUE:
			return "Reach and extract the friendly"
		ObjectiveType.ELIMINATE:
			var target = objective_parameters.get("target_name", "target")
			return "Kill the %s" % target
		_:
			return objective_description


# === Turn Management ===

func advance_turn() -> void:
	if status == MissionStatus.ACCEPTED or status == MissionStatus.IN_PROGRESS:
		turns_accepted += 1
		if turns_remaining > 0:
			turns_remaining -= 1
			if turns_remaining <= 0:
				expire_mission()


# === Serialization ===

func to_dict() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_name": mission_name,
		"description": description,
		"mission_type": mission_type,
		"patron_name": patron_name,
		"patron_faction": patron_faction,
		"objective_type": objective_type,
		"objective_description": objective_description,
		"objective_parameters": objective_parameters,
		"reward_credits": reward_credits,
		"reward_reputation": reward_reputation,
		"reward_loot_rolls": reward_loot_rolls,
		"reward_story_points": reward_story_points,
		"bonus_rewards": bonus_rewards,
		"status": status,
		"turns_accepted": turns_accepted,
		"turns_remaining": turns_remaining
	}


static func from_dict(data: Dictionary) -> Mission:
	var _Self = load("res://src/core/campaign/Mission.gd")
	var mission = _Self.new()
	mission.mission_id = data.get("mission_id", "")
	mission.mission_name = data.get("mission_name", "")
	mission.description = data.get("description", "")
	mission.mission_type = data.get("mission_type", MissionType.PATRON_JOB)
	mission.patron_name = data.get("patron_name", "")
	mission.patron_faction = data.get("patron_faction", "")
	mission.objective_type = data.get("objective_type", ObjectiveType.FIGHT)
	mission.objective_description = data.get("objective_description", "")
	mission.objective_parameters = data.get("objective_parameters", {})
	mission.reward_credits = data.get("reward_credits", 0)
	mission.reward_reputation = data.get("reward_reputation", 0)
	mission.reward_loot_rolls = data.get("reward_loot_rolls", 0)
	mission.reward_story_points = data.get("reward_story_points", 0)
	mission.bonus_rewards = data.get("bonus_rewards", [])
	mission.status = data.get("status", MissionStatus.AVAILABLE)
	mission.turns_accepted = data.get("turns_accepted", 0)
	mission.turns_remaining = data.get("turns_remaining", -1)
	return mission


# === Factory Methods ===

static func create_patrol_mission(patron: String, credits: int) -> Mission:
	var _Self = load("res://src/core/campaign/Mission.gd")
	var mission = _Self.new()
	mission.mission_name = "Patrol Assignment"
	mission.mission_type = MissionType.PATRON_JOB
	mission.patron_name = patron
	mission.objective_type = ObjectiveType.PATROL
	mission.objective_description = "Patrol the designated area"
	mission.objective_parameters = {"crew_required": 2}
	mission.reward_credits = credits
	mission.reward_reputation = 1
	mission.reward_loot_rolls = 1
	return mission


static func create_fight_mission(patron: String, credits: int, danger: int = 2) -> Mission:
	var _Self = load("res://src/core/campaign/Mission.gd")
	var mission = _Self.new()
	mission.mission_name = "Combat Mission"
	mission.mission_type = MissionType.PATRON_JOB
	mission.patron_name = patron
	mission.objective_type = ObjectiveType.FIGHT
	mission.objective_description = "Eliminate all hostiles"
	mission.danger_level = danger
	mission.reward_credits = credits
	mission.reward_reputation = 1
	mission.reward_loot_rolls = danger
	return mission
