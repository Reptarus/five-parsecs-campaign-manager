class_name StatDistribution
extends Resource

signal stat_changed(stat: String, new_value: int)

var character: Character
var base_stats: Dictionary
var temporary_modifiers: Dictionary
var permanent_modifiers: Dictionary

func _init(_character: Character):
	character = _character
	base_stats = character.stats.duplicate()
	temporary_modifiers = {}
	permanent_modifiers = {}

# Core stat management functions
func update_stat(stat: String, new_value: int) -> void:
	if stat in base_stats:
		base_stats[stat] = new_value
		print("%s's %s changed to %d" % [character.name, stat, new_value])
		character.stats[stat] = new_value
		stat_changed.emit(stat, new_value)
	else:
		push_error("Invalid stat: %s" % stat)

func get_current_stat(stat: String) -> int:
	var current_value = base_stats[stat]
	
	if permanent_modifiers.has(stat):
		current_value += permanent_modifiers[stat]
	
	if temporary_modifiers.has(stat):
		for modifier in temporary_modifiers[stat]:
			current_value += modifier["value"]
	
	return current_value

func meets_stat_threshold(stat: String, threshold: int) -> bool:
	return get_current_stat(stat) >= threshold

# Modifier management
func add_temporary_modifier(stat: String, value: int, duration: int):
	if not temporary_modifiers.has(stat):
		temporary_modifiers[stat] = []
	temporary_modifiers[stat].append({"value": value, "duration": duration})
	stat_changed.emit(stat, get_current_stat(stat))

func add_permanent_modifier(stat: String, value: int):
	if not permanent_modifiers.has(stat):
		permanent_modifiers[stat] = 0
	permanent_modifiers[stat] += value
	stat_changed.emit(stat, get_current_stat(stat))

func remove_temporary_modifier(stat: String, index: int):
	if temporary_modifiers.has(stat) and index < temporary_modifiers[stat].size():
		temporary_modifiers[stat].remove_at(index)
		stat_changed.emit(stat, get_current_stat(stat))

func remove_permanent_modifier(stat: String, value: int):
	if permanent_modifiers.has(stat):
		permanent_modifiers[stat] -= value
		stat_changed.emit(stat, get_current_stat(stat))

func update_temporary_modifiers():
	for stat in temporary_modifiers.keys():
		var i = temporary_modifiers[stat].size() - 1
		while i >= 0:
			temporary_modifiers[stat][i]["duration"] -= 1
			if temporary_modifiers[stat][i]["duration"] <= 0:
				temporary_modifiers[stat].remove_at(i)
				stat_changed.emit(stat, get_current_stat(stat))
			i -= 1

# Equipment and status effect functions
func apply_equipment_modifiers(equipment: Equipment):
	for stat in equipment.stat_modifiers:
		add_temporary_modifier(stat, equipment.stat_modifiers[stat], -1)  # -1 for indefinite duration

func remove_equipment_modifiers(equipment: Equipment):
	for stat in equipment.stat_modifiers:
		var index = temporary_modifiers[stat].find(func(mod): return mod["value"] == equipment.stat_modifiers[stat] and mod["duration"] == -1)
		if index != -1:
			remove_temporary_modifier(stat, index)

func apply_status_effect(effect: StatusEffect):
	for stat in effect.stat_modifiers:
		add_temporary_modifier(stat, effect.stat_modifiers[stat], effect.duration)

# Difficulty-related functions
func get_stat_modifier_for_difficulty(stat: String) -> int:
	var difficulty_mode = GameStateManager.difficulty_mode
	match difficulty_mode:
		GlobalEnums.DifficultyMode.CHALLENGING:
			return -1 if stat in ["combat", "technical", "social", "survival"] else 0
		GlobalEnums.DifficultyMode.HARDCORE:
			return -2 if stat in ["combat", "technical", "social", "survival"] else 0
		GlobalEnums.DifficultyMode.INSANITY:
			return -3 if stat in ["combat", "technical", "social", "survival"] else 0
		_:
			return 0

func apply_difficulty_modifiers():
	for stat in base_stats.keys():
		var modifier = get_stat_modifier_for_difficulty(stat)
		if modifier != 0:
			add_permanent_modifier(stat, modifier)

# Serialization
func serialize() -> Dictionary:
	return {
		"base_stats": base_stats,
		"temporary_modifiers": temporary_modifiers,
		"permanent_modifiers": permanent_modifiers
	}

static func deserialize(data_dict: Dictionary, character_instance: Character) -> StatDistribution:
	var new_stat_distribution = StatDistribution.new(character_instance)
	if data_dict.has("base_stats"):
		new_stat_distribution.base_stats = data_dict["base_stats"]
	if data_dict.has("temporary_modifiers"):
		new_stat_distribution.temporary_modifiers = data_dict["temporary_modifiers"]
	if data_dict.has("permanent_modifiers"):
		new_stat_distribution.permanent_modifiers = data_dict["permanent_modifiers"]
	return new_stat_distribution
