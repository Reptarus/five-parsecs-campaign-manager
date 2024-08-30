class_name Character
extends Resource

signal xp_added(amount: int)
signal skill_improved(skill: String)
signal stat_reduced(stat: String, amount: int)
signal killed

@export var name: String
@export var race: CharacterCreationData.Race
@export var background: CharacterCreationData.Background
@export var motivation: CharacterCreationData.Motivation
@export var character_class: CharacterCreationData.Class
@export var skills: Dictionary = {}
@export var portrait: String

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var xp: int = 0
@export var luck: int = 0

var inventory: CharacterInventory
var recover_time: int = 0
var became_casualty: bool = false
var killed_unique_individual: bool = false
var implants: Array[String] = []

func _init():
	inventory = CharacterInventory.new()

func generate_random() -> void:
	name = CharacterCreationData.get_random_name()
	race = CharacterCreationData.get_random_race()
	background = CharacterCreationData.get_random_background()
	motivation = CharacterCreationData.get_random_motivation()
	character_class = CharacterCreationData.get_random_class()
	skills = CharacterCreationData.get_random_skills(3)
	portrait = CharacterCreationData.get_random_portrait()
	apply_race_traits()
	apply_background_stats()
	apply_motivation_stats()
	apply_class_stats()

func apply_race_traits() -> void:
	var race_traits = CharacterCreationData.get_race_traits(race)
	if "base_stats" in race_traits:
		for stat in race_traits["base_stats"]:
			set(stat, get(stat) + race_traits["base_stats"][stat])

func apply_background_stats() -> void:
	var background_stats = CharacterCreationData.get_background_stats(background)
	for stat in background_stats:
		if stat in self:
			set(stat, get(stat) + background_stats[stat])

func apply_motivation_stats() -> void:
	var motivation_stats = CharacterCreationData.get_motivation_stats(motivation)
	for stat in motivation_stats:
		if stat in self:
			set(stat, get(stat) + motivation_stats[stat])

func apply_class_stats() -> void:
	var class_stats = CharacterCreationData.get_class_stats(character_class)
	for stat in class_stats:
		if stat in self:
			set(stat, get(stat) + class_stats[stat])

func update(new_data: Dictionary) -> void:
	for key in new_data:
		if key in self:
			set(key, new_data[key])

func to_dict() -> Dictionary:
	return {
		"name": name,
		"race": CharacterCreationData.Race.keys()[race],
		"background": CharacterCreationData.Background.keys()[background],
		"motivation": CharacterCreationData.Motivation.keys()[motivation],
		"character_class": CharacterCreationData.Class.keys()[character_class],
		"skills": skills,
		"portrait": portrait,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"xp": xp,
		"luck": luck,
		"implants": implants
	}

func from_dict(data: Dictionary) -> void:
	for key in data:
		if key in self:
			match key:
				"race":
					race = CharacterCreationData.Race[data[key]]
				"background":
					background = CharacterCreationData.Background[data[key]]
				"motivation":
					motivation = CharacterCreationData.Motivation[data[key]]
				"character_class":
					character_class = CharacterCreationData.Class[data[key]]
				_:
					set(key, data[key])

func get_display_string() -> String:
	return "{0} - {1} {2}".format([name, CharacterCreationData.Race.keys()[race], CharacterCreationData.Background.keys()[background]])

func _to_string() -> String:
	return get_display_string()

func add_skill(skill_name: String):
	if skill_name not in skills:
		skills[skill_name] = 1
	else:
		skills[skill_name] += 1
	skill_improved.emit(skill_name)

func has_skill(skill_name: String) -> bool:
	return skill_name in skills

func add_implant(implant_name: String):
	if not implant_name in implants:
		implants.append(implant_name)

func has_implant(implant_name: String) -> bool:
	return implant_name in implants

func add_xp(amount: int):
	xp += amount
	xp_added.emit(amount)

func add_luck(amount: int):
	luck += amount

func is_bot() -> bool:
	return race == CharacterCreationData.Race.BOT

func kill():
	killed.emit()

func damage_all_equipment():
	for item in inventory.get_all_items():
		item.damage()

func lose_all_equipment():
	inventory.clear()

func damage_random_equipment():
	var items = inventory.get_all_items()
	if items.size() > 0:
		var random_item = items[randi() % items.size()]
		random_item.damage()

func permanent_stat_reduction():
	var stats = ["reactions", "speed", "combat_skill", "toughness", "savvy"]
	var stat = stats[randi() % stats.size()]
	set(stat, get(stat) - 1)
	stat_reduced.emit(stat, 1)

func apply_experience_upgrades():
	# TODO: Implement logic for applying XP to upgrade character stats or skills
	pass

func serialize() -> Dictionary:
	return to_dict()

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	character.from_dict(data)
	return character
