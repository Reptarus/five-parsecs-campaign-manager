class_name BlackZoneSystem
extends RefCounted

## Black Zone Jobs System — Core Rules Appendix III (pp.91-92)
##
## Near-suicide missions for secretive Unity government forces. The most
## dangerous content in the game with massive rewards for victory.
##
## Requires 10+ campaign turns in a Red Zone before access.
##
## Usage:
##   var can_access = BlackZoneSystem.can_accept_mission(campaign)
##   var mission = BlackZoneSystem.roll_mission_type()
##   var rewards = BlackZoneSystem.calculate_rewards(battle_result)

# Cached data from JSON
static var _data: Dictionary = {}
static var _data_loaded: bool = false

# MARK: - Data Loading

static func _load_data() -> void:
	if _data_loaded:
		return
	var file := FileAccess.open("res://data/black_zone_jobs.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_data = json.data
	_data_loaded = true

static func _get_data() -> Dictionary:
	if not _data_loaded:
		_load_data()
	return _data

# MARK: - Access Requirements

## Check if the crew can accept a Black Zone mission.
## Returns Dictionary with "can_accept", "reasons", "requirements".
static func can_accept_mission(campaign: Resource) -> Dictionary:
	var data := _get_data()
	var reqs: Dictionary = data.get("access_requirements", {})
	var reasons: Array[String] = []

	# Must be Red Zone licensed
	if not ("red_zone_licensed" in campaign and campaign.red_zone_licensed):
		reasons.append("Must have Red Zone license")

	# Must have 10+ turns in Red Zone
	var min_rz_turns: int = reqs.get("min_red_zone_turns", 10)
	var rz_turns: int = campaign.red_zone_turns_completed if "red_zone_turns_completed" in campaign else 0
	if rz_turns < min_rz_turns:
		reasons.append("Need %d+ Red Zone turns (have %d)" % [min_rz_turns, rz_turns])

	return {
		"can_accept": reasons.is_empty(),
		"reasons": reasons,
		"requirements": {
			"red_zone_licensed": "red_zone_licensed" in campaign and campaign.red_zone_licensed,
			"red_zone_turns": {"required": min_rz_turns, "current": rz_turns}
		}
	}

# MARK: - Advantages (Applied During Campaign Turn)

## Get advantages granted during a Black Zone campaign turn.
## Returns Dictionary of advantages to apply.
static func get_turn_advantages() -> Dictionary:
	var data := _get_data()
	return data.get("advantages", {
		"no_rival_interference": true,
		"no_upkeep_payment": true,
		"ship_loan_no_increase": true,
		"ship_cannot_be_seized": true,
		"free_weapon_rolls": 3
	})

# MARK: - Mission Type (D10 Table)

## Roll for Black Zone mission type.
## Returns Dictionary with mission details.
static func roll_mission_type() -> Dictionary:
	var data := _get_data()
	var missions: Array = data.get("mission_types", [])
	var roll: int = randi_range(1, 10)

	for mission in missions:
		var roll_range: Array = mission.get("roll_range", [0, 0])
		if roll >= roll_range[0] and roll <= roll_range[1]:
			return {
				"roll": roll,
				"name": mission.get("name", "Unknown"),
				"description": mission.get("description", ""),
				"objective": mission.get("objective", ""),
				"required_kills": mission.get("required_kills", 0),
				"required_rounds": mission.get("required_rounds", 0),
				"required_exits": mission.get("required_exits", 0),
				"savvy_check": mission.get("savvy_check", 0),
				"target_toughness": mission.get("target_toughness", 0)
			}

	return {"roll": roll, "name": "Unknown Mission", "objective": "unknown"}

# MARK: - Opposition Setup

## Get Black Zone opposition rules (Active/Passive team system).
## Returns Dictionary with team composition and AI rules.
static func get_opposition_rules() -> Dictionary:
	var data := _get_data()
	return data.get("opposition", {
		"enemy_source": "roving_threats",
		"team_size": 4,
		"initial_teams": 4,
		"reinforcement_schedule": "every_round"
	})

## Get Active/Passive team rules.
static func get_active_passive_rules() -> Dictionary:
	var data := _get_data()
	return data.get("active_passive_rules", {})

# MARK: - Setup Rules

## Get battlefield setup rules for Black Zone missions.
static func get_setup_rules() -> Dictionary:
	var data := _get_data()
	return data.get("setup", {
		"no_notable_sights": true,
		"no_deployment_conditions": true,
		"seize_initiative_allowed": true,
		"seize_initiative_bonus": 1
	})

# MARK: - Ending Rules

## Get mission ending rules.
static func get_ending_rules() -> Dictionary:
	var data := _get_data()
	return data.get("ending", {
		"win_evac_delay": 1,
		"flee_penalty": "casualty"
	})

# MARK: - Reward Calculation

## Calculate Black Zone rewards based on battle result.
## Returns Dictionary with all rewards to apply.
static func calculate_rewards(battle_result: Dictionary) -> Dictionary:
	var data := _get_data()
	var success: bool = battle_result.get("success", false)

	if success:
		var victory_rewards: Dictionary = data.get("rewards", {}).get("victory", {})
		return {
			"is_victory": true,
			"clear_all_rivals": victory_rewards.get("clear_all_rivals", true),
			"add_patrons": victory_rewards.get("add_patrons", 2),
			"patron_type": victory_rewards.get("patron_type", "persistent"),
			"bonus_credits": victory_rewards.get("bonus_credits", 5),
			"ship_loan_payoff": victory_rewards.get("ship_loan_payoff", 5),
			"loot_rolls": victory_rewards.get("loot_rolls", 3),
			"xp_bonus_all_crew": victory_rewards.get("xp_bonus_all_crew", 1)
		}
	else:
		var failure_rewards: Dictionary = data.get("rewards", {}).get("failure", {})
		var casualties: int = battle_result.get("casualties_count", 0)
		return {
			"is_victory": false,
			"standard_failed_rewards": true,
			"unity_casualty_pay": failure_rewards.get("unity_casualty_pay", 1) * casualties
		}

# MARK: - Utility

## Get complete rules summary for UI display.
static func get_rules_summary() -> String:
	return """BLACK ZONE JOBS (Core Rules Appendix III)
• Requires 10+ turns in Red Zone
• No Rival interference, no Upkeep, loan frozen
• 3 free Weapon Table rolls before mission
• Roving Threats enemies in teams of 4
• 4 initial Active teams + reinforcement every round
• Passive teams activate on proximity (8") or fire
• 5 mission types: Destroy Strongpoint, Hold 10 Rounds,
  Eliminate Target, Destroy Platoon (25 kills), Penetrate Lines
• Victory: Clear ALL Rivals, +2 Patrons, 5cr, 3 Loot, +1 XP all crew
• Failure: Standard rewards + 1cr per casualty from Unity"""
