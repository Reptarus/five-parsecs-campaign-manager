extends RefCounted
## Helper class for rival and patron mechanics tests
## Implements core Five Parsecs From Home formulas for testing
## Plain helper class (no Node inheritance) for gdUnit4 stability

# ============================================================================
# Track Task Resolution - p.108 Five Parsecs From Home
# ============================================================================

func _resolve_track_task(die_roll: int, trackers: int) -> Dictionary:
	"""
	Track task resolution: 1D6 + trackers >= 6 = success
	@param die_roll: The 1D6 result (1-6)
	@param trackers: Number of trackers currently assigned
	@return Dictionary with success status and description
	"""
	var total = die_roll + trackers
	var success = total >= 6

	return {
		"success": success,
		"total_roll": total,
		"description": "Track task successfully completed" if success else "Track task failed to locate rival"
	}

# ============================================================================
# Decoy System - p.82 Five Parsecs From Home
# ============================================================================

func _apply_decoy_modifier(base_roll: int, decoys: int) -> int:
	"""
	Apply decoy modifier to rival attack roll
	Each decoy adds +1 to the roll (making attack less likely)
	@param base_roll: Original 1D6 roll
	@param decoys: Number of active decoys
	@return Modified roll value
	"""
	return base_roll + decoys

func _check_rival_attack(die_roll: int, campaign: Dictionary) -> Dictionary:
	"""
	Check if rivals attack based on number of rivals and decoys
	Roll 1D6, if result <= number of rivals, they attack
	Decoys add +1 to roll (helping avoid attack)
	@param die_roll: The 1D6 result (1-6)
	@param campaign: Campaign data with rivals and decoys
	@return Dictionary with attack status
	"""
	var num_rivals = campaign.get("rivals", []).size()
	var decoys = campaign.get("decoys", 0)
	var modified_roll = _apply_decoy_modifier(die_roll, decoys)

	# Attack triggers if ORIGINAL roll <= number of rivals
	# (Decoys make the modified roll higher, but don't change threshold)
	var attack_triggered = die_roll <= num_rivals

	return {
		"attack_triggered": attack_triggered,
		"original_roll": die_roll,
		"modified_roll": modified_roll,
		"threshold": num_rivals,
		"description": "Rivals attack!" if attack_triggered else "Rivals fail to locate crew"
	}

# ============================================================================
# Rival Removal - p.82 Five Parsecs From Home
# ============================================================================

func _attempt_rival_removal(die_roll: int, is_tracked: bool, is_persistent: bool) -> Dictionary:
	"""
	Attempt to remove a rival from campaign
	Base: 1D6, success on 4+ (50% chance)
	Tracked: 1D6+1, success on 4+ (67% chance)
	Persistent: 1D6-1, success on 4+ (33% chance without tracking)
	@param die_roll: The 1D6 result (1-6)
	@param is_tracked: Whether this rival has been tracked
	@param is_persistent: Whether this rival has Persistent trait
	@return Dictionary with removal success status
	"""
	var modifier = 0
	if is_tracked:
		modifier += 1
	if is_persistent:
		modifier -= 1

	var modified_roll = die_roll + modifier
	var success = modified_roll >= 4

	var description = ""
	if success:
		description = "Rival successfully removed from campaign"
	else:
		description = "Rival remains active"

	return {
		"success": success,
		"original_roll": die_roll,
		"modified_roll": modified_roll,
		"modifier": modifier,
		"description": description
	}

# ============================================================================
# Find Patron - p.50 Five Parsecs From Home
# ============================================================================

func _find_patron(die_roll: int, existing_patrons: int, credits_spent: int) -> Dictionary:
	"""
	Find patron attempt
	1D6 + modifiers >= 5 = 1 patron
	1D6 + modifiers >= 6 = 2 patrons
	Each existing patron adds +1
	Each credit spent adds +1
	@param die_roll: The 1D6 result (1-6)
	@param existing_patrons: Number of existing patrons
	@param credits_spent: Number of credits spent on search
	@return Dictionary with patrons found
	"""
	var total_roll = die_roll + existing_patrons + credits_spent

	var patrons_found = 0
	if total_roll >= 6:
		patrons_found = 2
	elif total_roll >= 5:
		patrons_found = 1

	var description = ""
	if patrons_found == 0:
		description = "No patrons found"
	elif patrons_found == 1:
		description = "Found 1 patron willing to offer work"
	else:
		description = "Found 2 patrons willing to offer work"

	return {
		"patrons_found": patrons_found,
		"total_roll": total_roll,
		"description": description
	}

# ============================================================================
# Freelancer License - p.51 Five Parsecs From Home
# ============================================================================

func _check_freelancer_license_requirement(die_roll: int) -> Dictionary:
	"""
	Check if freelancer license is required
	D6 roll of 5-6 = license required
	@param die_roll: The 1D6 result (1-6)
	@return Dictionary with license requirement status
	"""
	var license_required = die_roll >= 5

	return {
		"license_required": license_required,
		"roll": die_roll,
		"description": "Freelancer license required" if license_required else "No license needed"
	}

func _calculate_freelancer_license_cost(die_roll: int) -> int:
	"""
	Calculate cost of freelancer license
	Cost is 1D6 credits (1-6)
	@param die_roll: The 1D6 result (1-6)
	@return Cost in credits
	"""
	return clampi(die_roll, 1, 6)

# ============================================================================
# Criminal Rival Status - p.81 Five Parsecs From Home
# ============================================================================

func _check_criminal_rival_status(die1: int, die2: int) -> Dictionary:
	"""
	Check if criminal becomes rival
	2D6, 1 on either die = becomes rival
	Both dice show 1 = "hates" modifier (+1 troops always)
	@param die1: First die result (1-6)
	@param die2: Second die result (1-6)
	@return Dictionary with rival status
	"""
	var has_one = die1 == 1 or die2 == 1
	var double_ones = die1 == 1 and die2 == 1

	var becomes_rival = has_one
	var hates_crew = double_ones

	var description = ""
	if hates_crew:
		description = "Criminal becomes rival and HATES the crew (+1 troops always)"
	elif becomes_rival:
		description = "Criminal becomes rival"
	else:
		description = "Criminal does not become rival"

	return {
		"becomes_rival": becomes_rival,
		"hates_crew": hates_crew,
		"die1": die1,
		"die2": die2,
		"description": description
	}

# ============================================================================
# Persistent Patron Travel - p.51 Five Parsecs From Home
# ============================================================================

func _apply_planet_travel(patron: Dictionary, new_planet_id: String) -> Dictionary:
	"""
	Apply planet travel to patron
	Patrons with "Persistent" characteristic follow to new planet
	Regular patrons stay behind
	@param patron: Patron data dictionary
	@param new_planet_id: ID of new planet being traveled to
	@return Dictionary with retention status
	"""
	var characteristics = patron.get("characteristics", [])
	var is_persistent = "Persistent" in characteristics

	var retained = is_persistent
	var new_patron_planet = new_planet_id if is_persistent else patron.get("planet_id", "")

	var description = ""
	if is_persistent:
		description = "Patron '%s' follows crew to new planet" % patron.get("name", "Unknown")
	else:
		description = "Patron '%s' dismissed (not persistent)" % patron.get("name", "Unknown")

	return {
		"retained": retained,
		"new_planet_id": new_patron_planet,
		"patron_name": patron.get("name", "Unknown"),
		"description": description
	}
