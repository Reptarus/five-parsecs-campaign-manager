class_name Character
extends Node

enum Race {
	HUMAN = GlobalEnums.Race.HUMAN,
	ENGINEER = GlobalEnums.Race.ENGINEER,
	KERIN = GlobalEnums.Race.KERIN,
	SOULLESS = GlobalEnums.Race.SOULLESS,
	PRECURSOR = GlobalEnums.Race.PRECURSOR,
	FERAL = GlobalEnums.Race.FERAL,
	SWIFT = GlobalEnums.Race.SWIFT,
	BOT = GlobalEnums.Race.BOT,
	SKULKER = GlobalEnums.Race.SKULKER,
	KRAG = GlobalEnums.Race.KRAG
}

enum Background {
	HIGH_TECH_COLONY = GlobalEnums.Background.HIGH_TECH_COLONY,
	OVERCROWDED_CITY = GlobalEnums.Background.OVERCROWDED_CITY,
	LOW_TECH_COLONY = GlobalEnums.Background.LOW_TECH_COLONY,
	MINING_COLONY = GlobalEnums.Background.MINING_COLONY,
	MILITARY_BRAT = GlobalEnums.Background.MILITARY_BRAT,
	SPACE_STATION = GlobalEnums.Background.SPACE_STATION
}

enum Motivation {
	WEALTH = GlobalEnums.Motivation.WEALTH,
	FAME = GlobalEnums.Motivation.FAME,
	GLORY = GlobalEnums.Motivation.GLORY,
	SURVIVAL = GlobalEnums.Motivation.SURVIVAL,
	ESCAPE = GlobalEnums.Motivation.ESCAPE,
	ADVENTURE = GlobalEnums.Motivation.ADVENTURE
}

enum Class {
	WORKING_CLASS = GlobalEnums.Class.WORKING_CLASS,
	TECHNICIAN = GlobalEnums.Class.TECHNICIAN,
	SCIENTIST = GlobalEnums.Class.SCIENTIST,
	HACKER = GlobalEnums.Class.HACKER,
	SOLDIER = GlobalEnums.Class.SOLDIER,
	MERCENARY = GlobalEnums.Class.MERCENARY
}

@export var character_name: String = ""
@export var race: Race = Race.HUMAN
@export var background: Background = Background.HIGH_TECH_COLONY
@export var motivation: Motivation = Motivation.WEALTH
@export var character_class: Class = Class.WORKING_CLASS

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var luck: int = 0

@export var is_psionic: bool = false
@export var psionic_powers: Array[GlobalEnums.PsionicPower] = []

var strange_character: StrangeCharacters = null
var abilities: Array[String] = []
var equipment: Array[String] = []
var armor: String = ""
var screen: String = ""
var implants: Array[String] = []
var stun_markers: int = 0
var xp: int = 0

func generate_random() -> void:
	name = CharacterNameGenerator.get_random_name()
	race = Race.values()[randi() % Race.size()]
	background = Background.values()[randi() % Background.size()]
	motivation = Motivation.values()[randi() % Motivation.size()]
	character_class = Class.values()[randi() % Class.size()]
	
	reactions = 1
	speed = 4
	combat_skill = 0
	toughness = 3
	savvy = 0
	luck = 0
	
	if randf() < 0.1:  # 10% chance of being psionic
		make_psionic()
	if randf() < 0.05:  # 5% chance of being a strange character
		set_strange_character_type(StrangeCharacters.StrangeCharacterType.values()[randi() % StrangeCharacters.StrangeCharacterType.size()])

func make_psionic() -> void:
	is_psionic = true
	var psionic_manager = PsionicManager.new()
	psionic_manager.generate_starting_powers()
	psionic_powers = psionic_manager.powers

func set_strange_character_type(type: StrangeCharacters.StrangeCharacterType) -> void:
	strange_character = StrangeCharacters.new(type)
	strange_character.apply_special_abilities(self)

func add_ability(ability: String) -> void:
	if ability not in abilities:
		abilities.append(ability)

func add_equipment(item: String) -> void:
	equipment.append(item)

func set_armor(new_armor: String) -> void:
	armor = new_armor

func set_screen(new_screen: String) -> void:
	screen = new_screen

func add_implant(implant: String) -> void:
	if implants.size() < 2 and implant not in implants:
		implants.append(implant)

func add_stun_marker() -> void:
	stun_markers += 1

func remove_stun_marker() -> void:
	if stun_markers > 0:
		stun_markers -= 1

func add_xp(amount: int) -> void:
	xp += amount

func use_luck() -> void:
	if luck > 0:
		luck -= 1

func apply_saving_throw(damage: int) -> bool:
	var save_roll = randi() % 6 + 1
	if armor == "Battle dress" and save_roll >= 5:
		return true
	elif armor == "Combat armor" and save_roll >= 5:
		return true
	elif armor == "Frag vest":
		if save_roll >= 6 or (damage > 0 and save_roll >= 5):
			return true
	elif screen == "Screen generator" and save_roll >= 5:
		return true
	return false

func serialize() -> Dictionary:
	var data = {
		"name": name,
		"race": Race.keys()[race],
		"background": Background.keys()[background],
		"motivation": Motivation.keys()[motivation],
		"character_class": Class.keys()[character_class],
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"luck": luck,
		"is_psionic": is_psionic,
		"psionic_powers": psionic_powers.map(func(power): return GlobalEnums.PsionicPower.keys()[power]),
		"abilities": abilities,
		"equipment": equipment,
		"armor": armor,
		"screen": screen,
		"implants": implants,
		"stun_markers": stun_markers,
		"xp": xp
	}
	if strange_character:
		data["strange_character"] = strange_character.serialize()
	return data

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
	character.name = data["name"]
	character.race = Race[data["race"]]
	character.background = Background[data["background"]]
	character.motivation = Motivation[data["motivation"]]
	character.character_class = Class[data["character_class"]]
	character.reactions = data["reactions"]
	character.speed = data["speed"]
	character.combat_skill = data["combat_skill"]
	character.toughness = data["toughness"]
	character.savvy = data["savvy"]
	character.luck = data["luck"]
	character.is_psionic = data["is_psionic"]
	character.psionic_powers = data["psionic_powers"].map(func(power): return GlobalEnums.PsionicPower[power])
	character.abilities = data["abilities"]
	character.equipment = data["equipment"]
	character.armor = data["armor"]
	character.screen = data["screen"]
	character.implants = data["implants"]
	character.stun_markers = data["stun_markers"]
	character.xp = data["xp"]
	if "strange_character" in data:
		character.strange_character = StrangeCharacters.deserialize(data["strange_character"])
	return character
