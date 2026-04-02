class_name MoraleSystem
extends RefCounted

## Crew Morale System - Five Parsecs Campaign Manager
##
## Tracks crew morale (0-100 scale) and applies gameplay effects:
## - High morale (70+): Combat bonuses, loyalty
## - Neutral morale (30-69): No modifiers
## - Low morale (10-29): Desertion risk, combat penalties
## - Critical morale (0-9): High desertion risk, severe penalties
##
## Morale changes from:
## - Battle victories (+5 to +15)
## - Battle losses (-5 to -15)
## - Crew deaths (-10 to -20)
## - Crew injuries (-2 to -5)
## - Upkeep paid (+2)
## - Upkeep failed (-10)
## - Luxury living (+5)
## - Story events (variable)

signal morale_changed(old_value: int, new_value: int)
signal desertion_check(crew_member_name: String, deserted: bool)
signal morale_event(message: String)

## Data loaded from res://data/campaign_config.json morale_system section
static var _morale_data: Dictionary = {}
static var _morale_loaded: bool = false

static func _ensure_morale_loaded() -> void:
	if _morale_loaded:
		return
	_morale_loaded = true
	var file := FileAccess.open("res://data/campaign_config.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_morale_data = json.data.get("morale_system", {})
	file.close()

static func _get_threshold(key: String, default_val: int) -> int:
	_ensure_morale_loaded()
	return int(_morale_data.get("thresholds", {}).get(key, default_val))

static func _get_adjustment(key: String, default_val: int) -> int:
	_ensure_morale_loaded()
	return int(_morale_data.get("adjustments", {}).get(key, default_val))

static func _get_desertion(key: String, default_val: int) -> int:
	_ensure_morale_loaded()
	return int(_morale_data.get("desertion", {}).get(key, default_val))

## Morale thresholds (loaded from JSON)
static var MORALE_MAX: int:
	get: return _get_threshold("max", 100)
static var MORALE_HIGH: int:
	get: return _get_threshold("high", 70)
static var MORALE_LOW: int:
	get: return _get_threshold("low", 30)
static var MORALE_CRITICAL: int:
	get: return _get_threshold("critical", 10)
static var MORALE_MIN: int:
	get: return _get_threshold("min", 0)
static var MORALE_DEFAULT: int:
	get: return _get_threshold("default", 50)

## Morale adjustment values (loaded from JSON)
static var VICTORY_BONUS: int:
	get: return _get_adjustment("victory", 10)
static var VICTORY_DECISIVE_BONUS: int:
	get: return _get_adjustment("victory_decisive", 15)
static var LOSS_PENALTY: int:
	get: return _get_adjustment("loss", -10)
static var LOSS_ROUT_PENALTY: int:
	get: return _get_adjustment("loss_rout", -15)
static var CREW_DEATH_PENALTY: int:
	get: return _get_adjustment("crew_death", -15)
static var CREW_INJURY_PENALTY: int:
	get: return _get_adjustment("crew_injury", -3)
static var UPKEEP_PAID_BONUS: int:
	get: return _get_adjustment("upkeep_paid", 2)
static var UPKEEP_FAILED_PENALTY: int:
	get: return _get_adjustment("upkeep_failed", -10)
static var LUXURY_LIVING_BONUS: int:
	get: return _get_adjustment("luxury_living", 5)
static var NATURAL_RECOVERY: int:
	get: return _get_adjustment("natural_recovery", 3)

## Desertion chance at low morale (loaded from JSON)
static var DESERTION_CHANCE_LOW: int:
	get: return _get_desertion("chance_low", 10)
static var DESERTION_CHANCE_CRITICAL: int:
	get: return _get_desertion("chance_critical", 25)


## Adjust morale on a campaign, clamping to valid range
##
## @param campaign: Campaign resource with crew_morale property
## @param amount: Positive or negative adjustment
## @param reason: Human-readable reason for the change
## @return: New morale value
static func adjust_morale(campaign, amount: int, reason: String = "") -> int:
	if not campaign or not "progress_data" in campaign:
		return MORALE_DEFAULT

	var pd: Dictionary = campaign.progress_data
	var old_value: int = pd.get("crew_morale", MORALE_DEFAULT)
	var new_value: int = clampi(old_value + amount, MORALE_MIN, MORALE_MAX)
	pd["crew_morale"] = new_value

	if reason != "" and old_value != new_value:
		var direction = "+" if amount > 0 else ""
		pass

	return new_value


## Apply post-battle morale changes
##
## @param campaign: Campaign resource
## @param battle_won: Whether the battle was won
## @param crew_deaths: Number of crew deaths this battle
## @param crew_injuries: Number of crew injuries this battle
## @param held_field: Whether crew held the field (decisive victory)
## @return: Dictionary with morale changes applied
static func apply_post_battle_morale(campaign, battle_won: bool, crew_deaths: int = 0, crew_injuries: int = 0, held_field: bool = false) -> Dictionary:
	var changes := {}
	var total_change := 0

	if battle_won:
		var bonus := VICTORY_DECISIVE_BONUS if held_field else VICTORY_BONUS
		total_change += bonus
		changes["victory"] = bonus
	else:
		total_change += LOSS_PENALTY
		changes["defeat"] = LOSS_PENALTY

	if crew_deaths > 0:
		var death_penalty := CREW_DEATH_PENALTY * crew_deaths
		total_change += death_penalty
		changes["crew_deaths"] = death_penalty

	if crew_injuries > 0:
		var injury_penalty := CREW_INJURY_PENALTY * crew_injuries
		total_change += injury_penalty
		changes["crew_injuries"] = injury_penalty

	var new_morale := adjust_morale(campaign, total_change, "Post-battle")
	changes["total_change"] = total_change
	changes["new_morale"] = new_morale
	return changes


## Apply upkeep morale effects
##
## @param campaign: Campaign resource
## @param upkeep_paid: Whether upkeep was successfully paid
## @param luxury: Whether luxury living was purchased
## @return: New morale value
static func apply_upkeep_morale(campaign, upkeep_paid: bool, luxury: bool = false) -> int:
	if upkeep_paid:
		adjust_morale(campaign, UPKEEP_PAID_BONUS, "Upkeep paid")
		if luxury:
			adjust_morale(campaign, LUXURY_LIVING_BONUS, "Luxury living")
	else:
		adjust_morale(campaign, UPKEEP_FAILED_PENALTY, "Upkeep failed")

	if "progress_data" in campaign:
		return campaign.progress_data.get("crew_morale", MORALE_DEFAULT)
	return MORALE_DEFAULT


## Apply natural morale recovery (drift toward 50 each turn)
##
## @param campaign: Campaign resource
## @return: New morale value
static func apply_natural_recovery(campaign) -> int:
	if not campaign or not "progress_data" in campaign:
		return MORALE_DEFAULT

	var pd: Dictionary = campaign.progress_data
	var current: int = pd.get("crew_morale", MORALE_DEFAULT)
	if current < MORALE_DEFAULT:
		var recovery := mini(NATURAL_RECOVERY, MORALE_DEFAULT - current)
		adjust_morale(campaign, recovery, "Natural recovery")
	elif current > MORALE_DEFAULT:
		var decay := mini(NATURAL_RECOVERY, current - MORALE_DEFAULT)
		adjust_morale(campaign, -decay, "Natural decay")

	return pd.get("crew_morale", MORALE_DEFAULT)


## Check for crew desertion due to low morale
##
## @param campaign: Campaign resource with crew_members
## @return: Array of crew member names who deserted
static func check_desertion(campaign) -> Array:
	var deserted := []
	if not campaign or not "progress_data" in campaign:
		return deserted

	var morale: int = campaign.progress_data.get("crew_morale", MORALE_DEFAULT)
	if morale >= MORALE_LOW:
		return deserted  # No desertion risk above low threshold

	var chance: int = DESERTION_CHANCE_CRITICAL if morale < MORALE_CRITICAL else DESERTION_CHANCE_LOW

	var crew: Array = []
	if campaign.has_method("get_crew_members"):
		crew = campaign.get_crew_members()
	elif "crew_data" in campaign:
		crew = campaign.crew_data.get("members", [])
	if crew.is_empty():
		return deserted
	# Captain never deserts; skip index 0 or check is_captain
	for i in range(crew.size()):
		var member = crew[i]
		if member == null:
			continue
		# Skip captain
		var is_captain: bool = false
		if member.has_method("get") and member.get("is_captain"):
			is_captain = true
		elif "is_captain" in member and member.is_captain:
			is_captain = true
		if is_captain:
			continue
		# Skip dead/wounded
		if member.get("is_dead") == true:
			continue

		var roll := randi_range(1, 100)
		if roll <= chance:
			var name_str: String = ""
			if member.has_method("get"):
				name_str = str(member.get("character_name"))
			elif "character_name" in member:
				name_str = str(member.character_name)
			else:
				name_str = "Crew Member %d" % i
			deserted.append(name_str)
			pass

	return deserted


## Get morale status string for UI display
##
## @param morale_value: Current morale (0-100)
## @return: Status string
static func get_morale_status(morale_value: int) -> String:
	if morale_value >= MORALE_HIGH:
		return "Excellent"
	elif morale_value >= MORALE_DEFAULT:
		return "Good"
	elif morale_value >= MORALE_LOW:
		return "Fair"
	elif morale_value >= MORALE_CRITICAL:
		return "Poor"
	else:
		return "Critical"


## Get combat modifier from morale
##
## @param morale_value: Current morale (0-100)
## @return: Combat modifier (-1, 0, or +1)
static func get_combat_modifier(morale_value: int) -> int:
	if morale_value >= MORALE_HIGH:
		return 1
	elif morale_value < MORALE_CRITICAL:
		return -1
	return 0
