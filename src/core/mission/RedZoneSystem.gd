class_name RedZoneSystem
extends RefCounted

## Red Zone Jobs System — Core Rules Appendix III (pp.89-91)
##
## Endgame content for experienced crews. Provides increased challenge and rewards
## through licensing, threat conditions, time constraints, and enhanced opposition.
##
## Usage:
##   var can_license = RedZoneSystem.can_obtain_license(campaign)
##   var threat = RedZoneSystem.roll_threat_condition()
##   var rewards = RedZoneSystem.calculate_rewards(battle_result)

# Cached data from JSON
static var _data: Dictionary = {}
static var _data_loaded: bool = false

# MARK: - Data Loading

static func _load_data() -> void:
	if _data_loaded:
		return
	var file := FileAccess.open("res://data/red_zone_jobs.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_data = json.data
	_data_loaded = true

static func _get_data() -> Dictionary:
	if not _data_loaded:
		_load_data()
	return _data

# MARK: - License Management

## Check if the crew can obtain a Red Zone license.
## Returns Dictionary with "can_license", "reasons" (failures), and "requirements".
static func can_obtain_license(campaign: Resource) -> Dictionary:
	var data := _get_data()
	var reqs: Dictionary = data.get("license_requirements", {})
	var reasons: Array[String] = []

	var min_turns: int = reqs.get("min_campaign_turns", 10)
	var fee: int = reqs.get("license_fee_credits", 15)
	var min_crew: int = reqs.get("min_crew_members", 7)

	# Check turns played
	var turns_played: int = 0
	if "progress_data" in campaign:
		turns_played = campaign.progress_data.get("turns_played", 0)
	if turns_played < min_turns:
		reasons.append("Need %d+ campaign turns (have %d)" % [min_turns, turns_played])

	# Check credits (apply Broker discount if available)
	var actual_fee: int = fee
	# TODO: Check for Broker training in crew to apply discount
	var credits: int = campaign.credits if "credits" in campaign else 0
	if credits < actual_fee:
		reasons.append("Need %d credits for license (have %d)" % [actual_fee, credits])

	# Check crew size
	var crew_size: int = 0
	if campaign.has_method("get_crew_members"):
		crew_size = campaign.get_crew_members().size()
	elif "crew_data" in campaign:
		crew_size = campaign.crew_data.get("members", []).size()
	if crew_size < min_crew:
		reasons.append("Need %d+ crew members (have %d)" % [min_crew, crew_size])

	return {
		"can_license": reasons.is_empty(),
		"reasons": reasons,
		"fee": actual_fee,
		"requirements": {
			"turns": {"required": min_turns, "current": turns_played},
			"credits": {"required": actual_fee, "current": credits},
			"crew": {"required": min_crew, "current": crew_size}
		}
	}

## Purchase a Red Zone license. Returns true on success.
static func purchase_license(campaign: Resource) -> bool:
	var check := can_obtain_license(campaign)
	if not check.can_license:
		return false

	var fee: int = check.fee

	# Deduct credits
	if "credits" in campaign:
		campaign.credits -= fee

	# Set licensed flag
	if "red_zone_licensed" in campaign:
		campaign.red_zone_licensed = true

	return true

## Check if a campaign has a Red Zone license.
static func is_licensed(campaign: Resource) -> bool:
	if "red_zone_licensed" in campaign:
		return campaign.red_zone_licensed
	return false

# MARK: - Threat Conditions (D6 Table)

## Roll for a Threat Condition applied to Red Zone missions.
## Returns Dictionary with threat details.
static func roll_threat_condition() -> Dictionary:
	var data := _get_data()
	var conditions: Array = data.get("threat_conditions", [])
	var roll: int = randi_range(1, 6)

	for condition in conditions:
		if condition.get("roll", 0) == roll:
			return {
				"roll": roll,
				"name": condition.get("name", "Unknown"),
				"description": condition.get("description", ""),
			}

	return {"roll": roll, "name": "None", "description": "No threat condition"}

# MARK: - Time Constraints (D6 at End of Round 6)

## Roll for a Time Constraint at end of Round 6.
## Returns Dictionary with constraint details.
static func roll_time_constraint() -> Dictionary:
	var data := _get_data()
	var constraints: Array = data.get("time_constraints", [])
	var roll: int = randi_range(1, 6)

	for constraint in constraints:
		if constraint.get("roll", 0) == roll:
			return {
				"roll": roll,
				"name": constraint.get("name", "Unknown"),
				"description": constraint.get("description", ""),
				"effect": constraint.get("effect", "none"),
				"enemy_count": constraint.get("enemy_count", 0),
				"specialist_count": constraint.get("specialist_count", 0),
				"unique_individual": constraint.get("unique_individual", false),
				"lieutenant_count": constraint.get("lieutenant_count", 0),
			}

	return {"roll": roll, "name": "None", "effect": "none"}

# MARK: - Opposition Rules

## Get Red Zone increased opposition rules.
## Returns Dictionary with fixed force composition.
static func get_opposition_rules() -> Dictionary:
	var data := _get_data()
	return data.get("increased_opposition", {
		"base_enemy_count": 7,
		"specialist_count": 3,
		"lieutenant_count": 1,
		"unique_individual_modifier": 1
	})

# MARK: - Reward Calculation

## Calculate Red Zone improved rewards.
## Returns Dictionary with reward modifiers to apply to standard post-battle rewards.
static func calculate_rewards(battle_result: Dictionary) -> Dictionary:
	var data := _get_data()
	var reward_rules: Dictionary = data.get("improved_rewards", {})
	var held_field: bool = battle_result.get("held_field", false)
	var won: bool = battle_result.get("success", false)

	var rewards: Dictionary = {
		"xp_bonus_per_survivor": reward_rules.get("xp_bonus_per_survivor", 1) if held_field else 0,
		"credits_roll_twice": reward_rules.get("credits_roll_twice_pick_best", true),
		"quest_bonus": reward_rules.get("quest_roll_three_dice_pick_best_plus_one", true),
		"extra_loot_roll": reward_rules.get("extra_loot_roll_on_win", true) if won else false,
	}

	return rewards

## Get Red Zone invasion modifiers for post-battle checks.
static func get_invasion_modifiers() -> Dictionary:
	var data := _get_data()
	return data.get("invasion_modifiers", {
		"invasion_roll_modifier": 2,
		"galactic_war_modifier": -1
	})

# MARK: - Utility

## Get a summary string describing Red Zone rules for UI display.
static func get_rules_summary() -> String:
	return """RED ZONE JOBS (Core Rules Appendix III)
• License required: 10+ turns, 15 credits, 7+ crew
• Fixed opposition: 7 enemies, 3 Specialists, 1 Lieutenant
• Threat Condition rolled before each mission
• Time Constraint checked at end of Round 6
• +2 Invasion rolls, -1 Galactic War progress
• Improved rewards: +1 XP/survivor, double credit roll, extra Loot"""
