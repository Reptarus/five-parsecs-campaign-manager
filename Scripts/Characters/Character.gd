class_name Character
extends Resource

signal xp_added(amount: int)
signal skill_improved(skill: Skill)
signal stat_reduced(stat: String, amount: int)
signal killed

enum Race { HUMAN, ENGINEER, KERIN, SOULLESS, PRECURSOR, FERAL, SWIFT, BOT }
enum Background { HIGH_TECH_COLONY, OVERCROWDED_CITY, LOW_TECH_COLONY, MINING_COLONY, MILITARY_BRAT, SPACE_STATION }
enum Motivation { WEALTH, FAME, GLORY, SURVIVAL, ESCAPE, ADVENTURE }
enum Class { WORKING_CLASS, TECHNICIAN, SCIENTIST, HACKER, SOLDIER, MERCENARY }
enum AIType { CAUTIOUS, AGGRESSIVE, TACTICAL, DEFENSIVE }

@export var name: String = ""
@export var race: Race = Race.HUMAN
@export var background: Background = Background.HIGH_TECH_COLONY
@export var motivation: Motivation = Motivation.WEALTH
@export var character_class: Class = Class.WORKING_CLASS
@export var skills: Dictionary = {}
@export var portrait: String = ""

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var xp: int = 0
@export var luck: int = 0
@export var abilities: Array[String] = []

@export var position: Vector2 = Vector2.ZERO
@export var health: int = 10
@export var max_health: int = 10
@export var is_aiming: bool = false
@export var ai_type: AIType = AIType.CAUTIOUS

var inventory: CharacterInventory
var recover_time: int = 0
var became_casualty: bool = false
var killed_unique_individual: bool = false
var strange_character: StrangeCharacters = null

func _init() -> void:
	inventory = CharacterInventory.new()

func generate_random() -> void:
	name = CharacterCreationData.get_random_name()
	race = Race.values()[randi() % Race.size()]
	background = Background.values()[randi() % Background.size()]
	motivation = Motivation.values()[randi() % Motivation.size()]
	character_class = Class.values()[randi() % Class.size()]
	skills = CharacterCreationData.get_random_skills(3)
	portrait = CharacterCreationData.get_random_portrait()

	if randf() < 0.1:  # 10% chance for strange abilities
		var strange_type = StrangeCharacters.StrangeCharacterType.values()[randi() % StrangeCharacters.StrangeCharacterType.size()]
		strange_character = StrangeCharacters.new()
		strange_character.initialize(strange_type)
		strange_character.apply_special_abilities(self)

func update(new_data: Dictionary) -> void:
	for key in new_data:
		if key in self:
			set(key, new_data[key])

func add_skill(skill_name: String, skill_type: Skill.SkillType) -> void:
	var new_skill = Skill.new()
	new_skill.initialize(skill_name, skill_type)
	skills[skill_name] = new_skill

func increase_skill(skill_name: String) -> void:
	if skills.has(skill_name):
		skills[skill_name].increase_level()
		skill_improved.emit(skills[skill_name])

func add_ability(ability_name: String) -> void:
	if not ability_name in abilities:
		abilities.append(ability_name)

func has_ability(ability_name: String) -> bool:
	return ability_name in abilities

func add_xp(amount: int) -> void:
	xp += amount
	xp_added.emit(amount)

func add_luck(amount: int) -> void:
	luck += amount

func is_bot() -> bool:
	return race == Race.BOT

func kill() -> void:
	killed.emit()

func damage_all_equipment() -> void:
	for item in inventory.get_all_items():
		item.damage()

func lose_all_equipment() -> void:
	inventory.clear()

func damage_random_equipment() -> void:
	var items = inventory.get_all_items()
	if items.size() > 0:
		var random_item = items[randi() % items.size()]
		random_item.damage()

func permanent_stat_reduction() -> void:
	var stats = ["reactions", "speed", "combat_skill", "toughness", "savvy"]
	var stat = stats[randi() % stats.size()]
	set(stat, get(stat) - 1)
	stat_reduced.emit(stat, 1)

func apply_experience_upgrades() -> void:
	# TODO: Implement logic for applying XP to upgrade character stats or skills
	pass

func is_defeated() -> bool:
	return health <= 0

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		killed.emit()

func apply_stun() -> void:
	# TODO: Implement stun logic
	pass

func get_equipped_weapon() -> Weapon:
	# TODO: Implement logic to return the character's equipped weapon
	return null  # Replace with actual implementation

func has_usable_items() -> bool:
	# TODO: Implement logic to check if the character has usable items
	return false

func get_display_string() -> String:
	return "{0} - {1} {2}".format([name, Race.keys()[race], Background.keys()[background]])

func _to_string() -> String:
	return get_display_string()
	
static func create_random_character() -> Character:
	var character = Character.new()
	character.name = CharacterCreationData.get_random_name()
	character.race = CharacterCreationData.get_random_race()
	character.background = CharacterCreationData.get_random_background()
	character.motivation = CharacterCreationData.get_random_motivation()
	character.character_class = CharacterCreationData.get_random_class()
	character.skills = CharacterCreationData.get_random_skills(3)
	character.portrait = CharacterCreationData.get_random_portrait()
	return character

func serialize() -> Dictionary:
	return {
		"name": name,
		"race": Race.keys()[race],
		"background": Background.keys()[background],
		"motivation": Motivation.keys()[motivation],
		"character_class": Class.keys()[character_class],
		"skills": skills.values().map(func(s): return s.serialize()),
		"portrait": portrait,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"xp": xp,
		"luck": luck,
		"abilities": abilities,
		"position": {"x": position.x, "y": position.y},
		"health": health,
		"max_health": max_health,
		"is_aiming": is_aiming,
		"inventory": inventory.serialize(),
		"recover_time": recover_time,
		"became_casualty": became_casualty,
		"killed_unique_individual": killed_unique_individual,
		"strange_character": strange_character.serialize() if strange_character else null
	}

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	character.name = data["name"]
	character.race = Race[data["race"]]
	character.background = Background[data["background"]]
	character.motivation = Motivation[data["motivation"]]
	character.character_class = Class[data["character_class"]]
	character.skills = data["skills"].map(func(s): return Skill.deserialize(s))
	character.portrait = data["portrait"]
	character.reactions = data["reactions"]
	character.speed = data["speed"]
	character.combat_skill = data["combat_skill"]
	character.toughness = data["toughness"]
	character.savvy = data["savvy"]
	character.xp = data["xp"]
	character.luck = data["luck"]
	character.abilities = data["abilities"]
	character.position = Vector2(data["position"]["x"], data["position"]["y"])
	character.health = data["health"]
	character.max_health = data["max_health"]
	character.is_aiming = data["is_aiming"]
	character.inventory = CharacterInventory.deserialize(data["inventory"])
	character.recover_time = data["recover_time"]
	character.became_casualty = data["became_casualty"]
	character.killed_unique_individual = data["killed_unique_individual"]
	character.strange_character = data["strange_character"]
	return character
