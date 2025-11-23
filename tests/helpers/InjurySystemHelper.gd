## Test Helper: Injury System Functions
## Extracts testable functions from simulate_campaign_turns.gd
## Plain class (no Node inheritance) to avoid lifecycle issues in tests

class_name InjurySystemHelper

func _determine_injury(roll: int, crippling_recovery: int = 0, serious_recovery_modifier: int = 0) -> Dictionary:
	"""Determine injury severity from D100 roll (Five Parsecs rulebook p.9445-9530)

	Args:
		roll: D100 result (1-100)
		crippling_recovery: For testing - recovery turns for crippling wound (normally 1D6)
		serious_recovery_modifier: For testing - modifier for serious injury (normally 1D3)
	"""
	var result = {
		"description": "",
		"recovery_turns": 0,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 0,
		"is_fatal": false
	}

	if roll <= 15:
		# Death (1-15)
		result.description = "DEAD - Fatal injury"
		result.is_fatal = true
	elif roll == 16:
		# Miraculous escape (16)
		result.description = "Miraculous escape - No injury"
		result.recovery_turns = 0
	elif roll <= 30:
		# Equipment loss (17-30)
		result.description = "Equipment damaged/lost"
		result.equipment_lost = true
		result.recovery_turns = 0
	elif roll <= 45:
		# Crippling wound (31-45) - 1D6 turns OR surgery
		result.description = "CRIPPLING WOUND - Requires surgery or long recovery"
		result.recovery_turns = crippling_recovery if crippling_recovery > 0 else randi() % 6 + 1
		result.requires_surgery = true
	elif roll <= 54:
		# Serious injury (46-54) - 1D3+1 turns
		result.description = "SERIOUS INJURY - Extended recovery"
		result.recovery_turns = (serious_recovery_modifier if serious_recovery_modifier > 0 else (randi() % 3 + 1)) + 1
	elif roll <= 80:
		# Minor injury (55-80) - 1 turn
		result.description = "MINOR INJURY - Short recovery"
		result.recovery_turns = 1
	elif roll <= 95:
		# Knocked out (81-95) - No sick bay
		result.description = "KNOCKED OUT - Shaken but recovers quickly"
		result.recovery_turns = 0
	else:
		# School of hard knocks (96-100) - +1 XP
		result.description = "School of Hard Knocks - Learns from experience"
		result.recovery_turns = 0
		result.bonus_xp = 1

	return result

func _process_injury_recovery(injured_characters: Array) -> Dictionary:
	"""Process sick bay recovery at start of turn (TRAVEL-0)

	Decrements recovery timers for all injured characters.
	Characters with 0 turns remaining are removed from sick bay.

	Args:
		injured_characters: Array of injury dictionaries (will be modified)

	Returns:
		Dictionary with recovery statistics
	"""
	var results = {
		"recovered": [],
		"still_injured": [],
		"total_in_sick_bay": injured_characters.size()
	}

	# Process each injured character (iterate backwards for safe removal)
	for i in range(injured_characters.size() - 1, -1, -1):
		var injury = injured_characters[i]
		injury.turns_remaining -= 1

		if injury.turns_remaining <= 0:
			# Character has recovered
			results.recovered.append(injury.name)
			injured_characters.remove_at(i)
		else:
			# Still recovering
			results.still_injured.append({
				"name": injury.name,
				"turns_remaining": injury.turns_remaining,
				"requires_surgery": injury.get("requires_surgery", false)
			})

	return results

func _get_injury_range_description(roll: int) -> String:
	"""Get the injury range category for a given roll (helper for testing)"""
	if roll <= 15:
		return "fatal"
	elif roll == 16:
		return "miraculous"
	elif roll <= 30:
		return "equipment_loss"
	elif roll <= 45:
		return "crippling"
	elif roll <= 54:
		return "serious"
	elif roll <= 80:
		return "minor"
	elif roll <= 95:
		return "knocked_out"
	else:
		return "hard_knocks"
