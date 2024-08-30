class_name Character
extends Resource

signal xp_added(amount: int)
signal skill_improved(skill: Skill)
signal stat_reduced(stat: String, amount: int)
signal killed

enum Race { HUMAN, ELF, DWARF, ORC, STRANGE }  # Define Race enum within Character class
enum Background { SOLDIER, MERCHANT, SCHOLAR, THIEF }  # Define Background enum within Character class
enum Motivation { WEALTH, POWER, KNOWLEDGE, REVENGE }  # Define Motivation enum within Character class
enum Class { WARRIOR, MAGE, ROGUE, CLERIC }  # Define Class enum within Character class

@export var name: String
@export var race: Race
@export var background: Background
@export var motivation: Motivation
@export var character_class: Class
@export var skills: Dictionary = {}
@export var portrait: String

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var xp: int = 0
@export var luck: int = 0
@export var abilities: Array[String] = []

var inventory: CharacterInventory
var recover_time: int = 0
var became_casualty: bool = false
var killed_unique_individual: bool = false
var strange_character: StrangeCharacters = null

func _init(_name: String = "", _race: Race = Race.HUMAN):
	name = _name
	race = _race
	inventory = CharacterInventory.new()
	if race == Race.STRANGE:
		var strange_type = StrangeCharacters.StrangeCharacterType.values()[randi() % StrangeCharacters.StrangeCharacterType.size()]
		strange_character = StrangeCharacters.new(strange_type)
		strange_character.apply_special_abilities(self)

func generate_random() -> void:
	name = CharacterCreationData.get_random_name()
	race = Race.values()[randi() % Race.size()]
	background = Background.values()[randi() % Background.size()]
	motivation = Motivation.values()[randi() % Motivation.size()]
	character_class = Class.values()[randi() % Class.size()]
	skills = CharacterCreationData.get_random_skills(3)
	portrait = CharacterCreationData.get_random_portrait()

func update(new_data: Dictionary) -> void:
	for key in new_data:
		if key in self:
			set(key, new_data[key])

func to_dict() -> Dictionary:
	return {
		"name": name,
		"race": Race.keys()[race],
		"background": Background.keys()[background],
		"motivation": Motivation.keys()[motivation],
		"character_class": Class.keys()[character_class],
		"skills": skills,
		"portrait": portrait,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"xp": xp,
		"luck": luck,
		"abilities": abilities
	}

func from_dict(data: Dictionary) -> void:
	for key in data:
		if key in self:
			if key in ["race", "background", "motivation", "character_class"]:
				set(key, get(key).find_key(data[key]))
			else:
				set(key, data[key])

func get_display_string() -> String:
	return "{0} - {1} {2}".format([name, Race.keys()[race], Background.keys()[background]])
	
	
func _to_string() -> String:
	return get_display_string()

func add_skill(skill_name: String, skill_type: Skill.SkillType):
	skills[skill_name] = Skill.new(skill_name, skill_type)

func increase_skill(skill_name: String):
	if skills.has(skill_name):
		skills[skill_name].increase_level()
		skill_improved.emit(skills[skill_name])

func add_ability(ability_name: String):
	if not ability_name in abilities:
		abilities.append(ability_name)

func has_ability(ability_name: String) -> bool:
	return ability_name in abilities

func add_xp(amount: int):
	xp += amount
	xp_added.emit(amount)

func add_luck(amount: int):
	luck += amount

func is_bot() -> bool:
	return race == Race.STRANGE and strange_character and strange_character.type == StrangeCharacters.StrangeCharacterType.BOT

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
	var data = to_dict()
	if strange_character:
		data["strange_character"] = strange_character.type
	return data

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	character.from_dict(data)
	if "strange_character" in data:
		character.strange_character = StrangeCharacters.new(data["strange_character"])
		character.strange_character.apply_special_abilities(character)
	return character
