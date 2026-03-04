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

## Morale thresholds
const MORALE_MAX := 100
const MORALE_HIGH := 70
const MORALE_LOW := 30
const MORALE_CRITICAL := 10
const MORALE_MIN := 0
const MORALE_DEFAULT := 50

## Morale adjustment values
const VICTORY_BONUS := 10
const VICTORY_DECISIVE_BONUS := 15
const LOSS_PENALTY := -10
const LOSS_ROUT_PENALTY := -15
const CREW_DEATH_PENALTY := -15
const CREW_INJURY_PENALTY := -3
const UPKEEP_PAID_BONUS := 2
const UPKEEP_FAILED_PENALTY := -10
const LUXURY_LIVING_BONUS := 5
const NATURAL_RECOVERY := 3  # Per turn toward 50

## Desertion chance at low morale (percentage per crew member per turn)
const DESERTION_CHANCE_LOW := 10      # 10% at morale 10-29
const DESERTION_CHANCE_CRITICAL := 25  # 25% at morale 0-9


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
