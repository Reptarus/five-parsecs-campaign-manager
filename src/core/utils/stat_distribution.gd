@tool
extends Resource
class_name FiveParsecsStatDistribution

## Core stat distribution system for Five Parsecs from Home
## Handles character stat management and modifiers

# GlobalEnums available as autoload singleton

signal stat_changed(stat: String, new_value: int)
signal modifier_applied(stat: String, modifier: int, duration: int)
signal modifier_removed(stat: String, modifier: int)

var base_stats: Dictionary = {}
var temporary_modifiers: Dictionary = {}
var permanent_modifiers: Dictionary = {}

# Five Parsecs stat limits as per Core Rules
const STAT_LIMITS = {
	"reactions": {"min": 1, "max": 6},
	"speed": {"min": 4, "max": 8},
	"combat_skill": {"min": - 3, "max": 3},
	"toughness": {"min": 3, "max": 6},
	"savvy": {"min": - 3, "max": 3},
	"luck": {"min": 0, "max": 3}
}

func _init() -> void:
	_initialize_default_stats()

func _initialize_default_stats() -> void:
	base_stats = {
		"reactions": 3,
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"savvy": 0,
		"luck": 0
	}
	temporary_modifiers = {}
	permanent_modifiers = {}

func get_current_stat(stat: String) -> int:
	if stat not in base_stats:
		push_error("Invalid stat: " + stat)
		return 0

	var current_value = base_stats[stat]

	# Apply permanent modifiers
	if stat in permanent_modifiers:
		current_value += permanent_modifiers[stat]

	# Apply temporary modifiers
	if stat in temporary_modifiers:
		for modifier in temporary_modifiers[stat]:
			current_value += modifier["_value"]

	# Apply stat limits
	if stat in STAT_LIMITS:
		var limits = STAT_LIMITS[stat]
		current_value = clampi(current_value, limits.min, limits.max)

	return current_value

func set_base_stat(stat: String, _value: int) -> void:
	if stat not in base_stats:
		push_error("Invalid stat: " + stat)
		return

	base_stats[stat] = _value
	stat_changed.emit(stat, get_current_stat(stat))

func add_temporary_modifier(stat: String, _value: int, duration: int) -> void:
	if stat not in temporary_modifiers:
		temporary_modifiers[stat] = []

	temporary_modifiers[stat].append({
		"_value": _value,
		"duration": duration
	})

	modifier_applied.emit(stat, _value, duration)
	stat_changed.emit(stat, get_current_stat(stat))

func add_permanent_modifier(stat: String, _value: int) -> void:
	if stat not in permanent_modifiers:
		permanent_modifiers[stat] = 0

	permanent_modifiers[stat] += _value
	stat_changed.emit(stat, get_current_stat(stat))

func remove_temporary_modifier(stat: String, index: int) -> void:
	if stat not in temporary_modifiers or index >= temporary_modifiers[stat].size():
		return

	var modifier = temporary_modifiers[stat][index]
	temporary_modifiers[stat].remove_at(index)

	modifier_removed.emit(stat, modifier._value)
	stat_changed.emit(stat, get_current_stat(stat))

func tick_temporary_modifiers() -> void:
	var expired_modifiers: Array = []

	for stat in temporary_modifiers:
		for i: int in range(temporary_modifiers[stat].size() - 1, -1, -1):
			var modifier = temporary_modifiers[stat][i]
			modifier.duration -= 1

			if modifier.duration <= 0:
				expired_modifiers.append({"stat": stat, "index": i})

	for expired in expired_modifiers:
		remove_temporary_modifier(expired.stat, expired.index)

func meets_requirement(stat: String, threshold: int) -> bool:
	return get_current_stat(stat) >= threshold

func get_stat_modifier(stat: String) -> int:
	var current = get_current_stat(stat)

	match stat:
		"combat_skill", "savvy":
			# These stats can be negative
			return current
		"reactions":
			# Reactions modifier for initiative
			return current - 3
		"toughness":
			# Toughness modifier for saves
			return current - 3
		"speed":
			# Speed modifier for movement
			return current - 4
		"luck":
			# Luck modifier for rerolls
			return current
		_:
			return 0

func serialize() -> Dictionary:
	return {
		"base_stats": base_stats,
		"temporary_modifiers": temporary_modifiers,
		"permanent_modifiers": permanent_modifiers
	}

func deserialize(data: Dictionary) -> void:
	if "base_stats" in data:
		base_stats = data.base_stats
	if "temporary_modifiers" in data:
		temporary_modifiers = data.temporary_modifiers
	if "permanent_modifiers" in data:
		permanent_modifiers = data.permanent_modifiers

	# Emit signals for all stats to update UI
	for stat in base_stats:
		stat_changed.emit(stat, get_current_stat(stat))

static func create_random_stats() -> FiveParsecsStatDistribution:
	var stats := FiveParsecsStatDistribution.new()

	# Generate stats according to Five Parsecs rules
	stats.set_base_stat("reactions", randi_range(1, 6))
	stats.set_base_stat("speed", randi_range(4, 8))
	stats.set_base_stat("combat_skill", randi_range(-1, 2))
	stats.set_base_stat("toughness", randi_range(3, 5))
	stats.set_base_stat("savvy", randi_range(-1, 2))
	stats.set_base_stat("luck", randi_range(0, 2))

	return stats

static func create_balanced_stats() -> FiveParsecsStatDistribution:
	var stats := FiveParsecsStatDistribution.new()

	# Create balanced starting stats
	stats.set_base_stat("reactions", 3)
	stats.set_base_stat("speed", 4)
	stats.set_base_stat("combat_skill", 0)
	stats.set_base_stat("toughness", 3)
	stats.set_base_stat("savvy", 0)
	stats.set_base_stat("luck", 0)

	return stats
