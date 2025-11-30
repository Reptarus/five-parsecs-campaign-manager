## Test Helper: Character Advancement Functions
## Extracts testable functions from simulate_campaign_turns.gd
## Plain class (no Node inheritance) to avoid lifecycle issues in tests

class_name CharacterAdvancementHelper

## Character Advancement Helper - Production Schema Compliant
## Uses correct stat names matching Character.gd

func _get_character_advancement_cost(stat: String) -> int:
	"""Get XP cost for increasing a stat (Five Parsecs rulebook p.6753-6760)"""
	var costs = {
		"reactions": 7,
		"combat": 7,        # CORRECT: matches Character.gd (NOT combat_skill)
		"speed": 5,
		"savvy": 5,
		"toughness": 6,
		"luck": 10,
		"tech": 6,          # ADDED: missing stat
		"move": 5           # ADDED: missing stat
	}
	return costs.get(stat.to_lower(), 999)

func _get_stat_maximum(stat: String, character: Dictionary) -> int:
	"""Get maximum value for a stat (Five Parsecs rulebook p.6753-6760)"""
	var stat_lower = stat.to_lower()

	# Check for Engineer Toughness restriction
	if stat_lower == "toughness":
		if character.get("background", "") == "Engineer" or character.get("background", "") == "ENGINEER":
			return 4  # Engineers max Toughness 4
		return 6  # Normal max Toughness 6

	# Check for Human Luck exception - use origin (not species)
	if stat_lower == "luck":
		var origin = character.get("origin", character.get("species", "HUMAN"))  # Fallback to species for compatibility
		if origin == "Human" or origin == "HUMAN":
			return 3  # Humans max Luck 3
		return 1  # Non-humans max Luck 1

	# Standard maximums - using CORRECT stat names matching Character.gd
	var maximums = {
		"reactions": 6,
		"combat": 5,        # CORRECT: matches Character.gd (NOT combat_skill)
		"speed": 8,
		"savvy": 5,
		"tech": 5,          # ADDED: missing stat
		"move": 8           # ADDED: missing stat
	}
	return maximums.get(stat_lower, 10)

func _can_character_advance(character: Dictionary) -> Array:
	"""Check which stats a character can advance"""
	var available_advancements = []
	var current_xp = character.get("experience", 0)

	# CORRECT stat names matching Character.gd
	var stats_to_check = ["reactions", "combat", "speed", "savvy", "toughness", "luck", "tech", "move"]

	for stat in stats_to_check:
		var cost = _get_character_advancement_cost(stat)
		var current_value = character.get(stat, 0)
		var max_value = _get_stat_maximum(stat, character)

		# Can advance if: enough XP AND not at maximum
		if current_xp >= cost and current_value < max_value:
			available_advancements.append(stat)

	return available_advancements

func _advance_character(character: Dictionary, stat: String) -> bool:
	"""Advance a character's stat by spending XP"""
	var cost = _get_character_advancement_cost(stat)
	var current_xp = character.get("experience", 0)
	var current_value = character.get(stat, 0)
	var max_value = _get_stat_maximum(stat, character)

	# Validate advancement
	if current_xp < cost:
		return false
	if current_value >= max_value:
		return false

	# Apply advancement
	character[stat] = current_value + 1
	character["experience"] = current_xp - cost

	return true

func _process_character_advancements(crew: Array, captain: Dictionary) -> Dictionary:
	"""Auto-advance all characters who have enough XP (POST-3)"""
	var results = {
		"captain_advancements": [],
		"crew_advancements": {}
	}

	# Priority order for stat advancement (most important first)
	# CORRECT stat names matching Character.gd
	var advancement_priority = ["combat", "reactions", "toughness", "speed", "savvy", "tech", "move", "luck"]

	# Process captain advancements
	for stat in advancement_priority:
		if _advance_character(captain, stat):
			results.captain_advancements.append(stat)

	# Process crew advancements
	for member in crew:
		var member_name = member.get("character_name", "Unknown")
		results.crew_advancements[member_name] = []

		for stat in advancement_priority:
			if _advance_character(member, stat):
				results.crew_advancements[member_name].append(stat)

	return results
