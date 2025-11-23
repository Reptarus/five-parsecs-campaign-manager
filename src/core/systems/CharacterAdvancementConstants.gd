class_name CharacterAdvancementConstants
## Character Advancement Constants for Five Parsecs Campaign Manager
## Transferred from test helpers to production code
## Based on Five Parsecs Core Rulebook p.67-76 (Character Advancement rules)
##
## Usage: Reference these constants in CharacterManager and advancement systems
## Architecture: Pure constants class - no state, no dependencies

## XP costs for stat advancement (Five Parsecs rulebook p.67)
const ADVANCEMENT_COSTS: Dictionary = {
	"reactions": 7,
	"combat_skill": 7,
	"speed": 5,
	"savvy": 5,
	"toughness": 6,
	"luck": 10
}

## Base stat maximum values (without species/background modifications)
const BASE_STAT_MAXIMUMS: Dictionary = {
	"reactions": 6,
	"combat_skill": 5,  # +5 combat modifier maximum
	"speed": 8,
	"savvy": 5,  # +5 savvy modifier maximum
	"toughness": 6,  # Normal maximum (Engineers limited to 4)
	"luck": 3  # Human maximum (non-humans limited to 1)
}

## Background-specific stat restrictions
const BACKGROUND_RESTRICTIONS: Dictionary = {
	"Engineer": {
		"toughness": 4  # Engineers max out at Toughness 4
	}
}

## Species-specific stat restrictions
const SPECIES_RESTRICTIONS: Dictionary = {
	"Human": {
		"luck": 3  # Humans can reach Luck 3
	},
	# All non-human species default to luck maximum of 1
	"non_human_default": {
		"luck": 1
	}
}

## Priority order for auto-advancement (most important first)
## Used in campaign turn processing for characters with sufficient XP
const ADVANCEMENT_PRIORITY: Array[String] = [
	"combat_skill",  # Most important for combat effectiveness
	"reactions",     # Initiative in combat
	"toughness",     # Survivability
	"speed",         # Movement and positioning
	"savvy",         # Task rolls and world interactions
	"luck"           # Rerolls and critical saves
]

## Minimum XP required for first advancement
const MIN_ADVANCEMENT_XP: int = 5  # Cheapest stat (speed/savvy) is 5 XP

## Maximum possible stat value (absolute ceiling)
const ABSOLUTE_STAT_MAX: int = 8  # Speed maximum, no stat can exceed this

## Helper function: Get advancement cost for a stat
static func get_advancement_cost(stat: String) -> int:
	"""Get XP cost for advancing a stat

	Args:
		stat: Stat name (reactions, combat_skill, speed, savvy, toughness, luck)

	Returns:
		XP cost, or 999 if invalid stat name
	"""
	return ADVANCEMENT_COSTS.get(stat.to_lower(), 999)

## Helper function: Get stat maximum for a character
static func get_stat_maximum(stat: String, character_data: Dictionary) -> int:
	"""Get maximum value for a stat considering background and species

	Args:
		stat: Stat name
		character_data: Dictionary with "background" and "species" keys

	Returns:
		Maximum value for the stat, considering character restrictions
	"""
	var stat_lower: String = stat.to_lower()

	# Check Engineer Toughness restriction
	if stat_lower == "toughness":
		var background: String = character_data.get("background", "")
		if background == "Engineer":
			return BACKGROUND_RESTRICTIONS.Engineer.toughness
		return BASE_STAT_MAXIMUMS.toughness

	# Check species Luck restriction
	if stat_lower == "luck":
		var species: String = character_data.get("species", "Human")
		if species == "Human":
			return SPECIES_RESTRICTIONS.Human.luck
		return SPECIES_RESTRICTIONS.non_human_default.luck

	# Return base maximum for other stats
	return BASE_STAT_MAXIMUMS.get(stat_lower, ABSOLUTE_STAT_MAX)

## Helper function: Check if character can advance a stat
static func can_advance_stat(character_data: Dictionary, stat: String) -> bool:
	"""Check if character has enough XP and hasn't reached maximum

	Args:
		character_data: Dictionary with "experience" and stat value keys
		stat: Stat to check for advancement

	Returns:
		True if character can advance the stat
	"""
	var current_xp: int = character_data.get("experience", 0)
	var cost: int = get_advancement_cost(stat)
	var current_value: int = character_data.get(stat, 0)
	var max_value: int = get_stat_maximum(stat, character_data)

	return current_xp >= cost and current_value < max_value

## Helper function: Get all available advancements for a character
static func get_available_advancements(character_data: Dictionary) -> Array[String]:
	"""Get list of stats the character can currently advance

	Args:
		character_data: Dictionary with character stats and experience

	Returns:
		Array of stat names that can be advanced
	"""
	var available: Array[String] = []

	for stat in ADVANCEMENT_COSTS.keys():
		if can_advance_stat(character_data, stat):
			available.append(stat)

	return available
