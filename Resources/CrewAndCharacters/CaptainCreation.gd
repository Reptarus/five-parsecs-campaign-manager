class_name CaptainCreation
extends Node

enum CharacterStat {
	REACTIONS,
	SPEED,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY
}

enum DifficultyMode {
	EASY,
	NORMAL,
	HARD,
	HARDCORE,
	INSANITY
}

# Base stats according to Core Rules
const BASE_STATS = {
	CharacterStat.REACTIONS: 1,
	CharacterStat.SPEED: 4,
	CharacterStat.COMBAT_SKILL: 0,
	CharacterStat.TOUGHNESS: 3,
	CharacterStat.SAVVY: 0
}

const MAX_STATS = {
	CharacterStat.REACTIONS: 6,
	CharacterStat.SPEED: 8,
	CharacterStat.COMBAT_SKILL: 3,
	CharacterStat.TOUGHNESS: 6,
	CharacterStat.SAVVY: 3
}

const REQUIRED_STATS = {
	CharacterStat.REACTIONS: {"min": 1, "max": 6},
	CharacterStat.SPEED: {"min": 4, "max": 8},
	CharacterStat.COMBAT_SKILL: {"min": 0, "max": 3},
	CharacterStat.TOUGHNESS: {"min": 3, "max": 6},
	CharacterStat.SAVVY: {"min": 0, "max": 3}
}

var current_captain: Character
var stat_points_remaining: int = 5
var current_stats: Dictionary = {}

func _init() -> void:
	current_captain = Character.new()
	_initialize_stats()

func _initialize_stats() -> void:
	for stat in CharacterStat.values():
		current_stats[stat] = BASE_STATS[stat]

func set_difficulty(difficulty: DifficultyMode) -> void:
	match difficulty:
		DifficultyMode.EASY:
			stat_points_remaining = 6  # Extra point for easy mode
		DifficultyMode.HARDCORE, DifficultyMode.INSANITY:
			stat_points_remaining = 4  # Fewer points for hard modes
		_:
			stat_points_remaining = 5  # Default points

func _validate_captain() -> bool:
	if not current_captain:
		push_error("No captain to validate")
		return false
		
	# Print current stats for debugging
	print("Current Stats:")
	for stat in REQUIRED_STATS:
		var current_value = current_stats[stat]
		var required = REQUIRED_STATS[stat]
		print("%s: %d (min: %d, max: %d)" % [
			CharacterStat.keys()[stat],
			current_value,
			required["min"],
			required["max"]
		])
	
	# Check if all required stats are present and within range
	for stat in REQUIRED_STATS:
		var current_value = current_stats[stat]
		var required = REQUIRED_STATS[stat]
		
		if current_value < required["min"]:
			push_error("Stat %s below minimum: %d < %d" % [
				CharacterStat.keys()[stat],
				current_value,
				required["min"]
			])
			return false
			
		if current_value > required["max"]:
			push_error("Stat %s above maximum: %d > %d" % [
				CharacterStat.keys()[stat],
				current_value,
				required["max"]
			])
			return false
	
	return true

func update_stat(stat_name: String, value: int) -> bool:
	if not current_captain:
		push_error("No captain to update stats for")
		return false
		
	var stat_enum = CharacterStat[stat_name]
	var old_value = current_stats[stat_enum]
	var change = value - old_value
	
	# Validate point allocation
	if change > 0 and stat_points_remaining < change:
		push_error("Not enough stat points remaining")
		return false
		
	if change < 0:
		stat_points_remaining -= change
	else:
		stat_points_remaining -= change
		
	current_stats[stat_enum] = value
	return true

func apply_background_effects(background: int) -> void:
	# Restore core stats
	for stat in REQUIRED_STATS:
		current_stats[stat] = current_stats.get(stat, REQUIRED_STATS[stat]["min"])
	
	# Apply background-specific bonuses
	match background:
		0:  # Soldier
			current_stats[CharacterStat.COMBAT_SKILL] += 1
		1:  # Merchant
			current_stats[CharacterStat.SAVVY] += 1
		2:  # Explorer
			current_stats[CharacterStat.SPEED] += 1
		3:  # Scholar
			current_stats[CharacterStat.TOUGHNESS] += 1
		4:  # Rogue
			current_stats[CharacterStat.REACTIONS] += 1
		_:
			push_warning("Unknown background type: " + str(background))

func preview_captain_stats(preview_label: Label) -> void:
	if not current_captain or not preview_label:
		return
		
	var preview_text = "Captain Stats Preview:\n"
	for stat in CharacterStat.values():
		var stat_name = CharacterStat.keys()[stat].capitalize()
		var stat_value = current_stats[stat]
		preview_text += "%s: %d\n" % [stat_name, stat_value]
	
	preview_label.text = preview_text

func finalize_captain() -> void:
	if not _validate_captain():
		push_error("Captain validation failed")
		return
		
	# Apply final stats
	for stat in current_stats:
		current_captain.stats[stat] = current_stats[stat]
	
	# Set captain-specific properties
	current_captain.role = 0  # Captain is always role 0 (leader)
	current_captain.motivation = 0  # Default motivation
