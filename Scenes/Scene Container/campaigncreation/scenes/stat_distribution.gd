class_name StatDistribution
extends Resource

var character: Character
var base_stats: Dictionary
var temporary_modifiers: Dictionary
var permanent_modifiers: Dictionary

func _init(_character: Character):
	character = _character
	base_stats = character.stats.duplicate()
	temporary_modifiers = {}
	permanent_modifiers = {}

func add_temporary_modifier(stat: String, value: int, duration: int):
	if not temporary_modifiers.has(stat):
		temporary_modifiers[stat] = []
	temporary_modifiers[stat].append({"value": value, "duration": duration})

func add_permanent_modifier(stat: String, value: int):
	if not permanent_modifiers.has(stat):
		permanent_modifiers[stat] = 0
	permanent_modifiers[stat] += value

func remove_temporary_modifier(stat: String, index: int):
	if temporary_modifiers.has(stat) and index < temporary_modifiers[stat].size():
		temporary_modifiers[stat].remove_at(index)

func remove_permanent_modifier(stat: String, value: int):
	if permanent_modifiers.has(stat):
		permanent_modifiers[stat] -= value

func get_current_stat(stat: String) -> int:
	var current_value = base_stats[stat]
	
	if permanent_modifiers.has(stat):
		current_value += permanent_modifiers[stat]
	
	if temporary_modifiers.has(stat):
		for modifier in temporary_modifiers[stat]:
			current_value += modifier["value"]
	
	return current_value

func update_temporary_modifiers():
	for stat in temporary_modifiers.keys():
		var i = temporary_modifiers[stat].size() - 1
		while i >= 0:
			temporary_modifiers[stat][i]["duration"] -= 1
			if temporary_modifiers[stat][i]["duration"] <= 0:
				temporary_modifiers[stat].remove_at(i)
			i -= 1

func apply_equipment_modifiers(equipment: Equipment):
	for stat in equipment.stat_modifiers:
		add_temporary_modifier(stat, equipment.stat_modifiers[stat], -1)  # -1 for indefinite duration

func remove_equipment_modifiers(equipment: Equipment):
	for stat in equipment.stat_modifiers:
		remove_temporary_modifier(stat, equipment.stat_modifiers[stat])

func apply_status_effect(effect: StatusEffect):
	for stat in effect.stat_modifiers:
		add_temporary_modifier(stat, effect.stat_modifiers[stat], effect.duration)

func meets_stat_threshold(stat: String, threshold: int) -> bool:
	return get_current_stat(stat) >= threshold

func serialize() -> Dictionary:
	return {
		"base_stats": base_stats,
		"temporary_modifiers": temporary_modifiers,
		"permanent_modifiers": permanent_modifiers
	}

static func deserialize(data: Dictionary, character: Character) -> StatDistribution:
	var stat_distribution = StatDistribution.new(character)
	if data.has("base_stats"):
		stat_distribution.base_stats = data["base_stats"]
	if data.has("temporary_modifiers"):
		stat_distribution.temporary_modifiers = data["temporary_modifiers"]
	if data.has("permanent_modifiers"):
		stat_distribution.permanent_modifiers = data["permanent_modifiers"]
	return stat_distribution
