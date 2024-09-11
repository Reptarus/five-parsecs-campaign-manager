class_name Character
extends Node

enum AIType { CAUTIOUS, AGGRESSIVE, TACTICAL, DEFENSIVE }

const Race = GlobalEnums.Race
const Background = GlobalEnums.Background
const Motivation = GlobalEnums.Motivation
const Class = GlobalEnums.Class

signal xp_added(amount: int)
signal stat_reduced(stat: String, amount: int)
signal killed

@export var character_name: String = ""
@export var race: Race = Race.HUMAN
@export var background: Background = Background.HIGH_TECH_COLONY
@export var motivation: Motivation = Motivation.WEALTH
@export var character_class: Class = Class.WORKING_CLASS
@export var portrait: String = ""
@export var notes: String = ""

@export var stats: Dictionary = {
	"reactions": 0,
	"speed": 0,
	"combat_skill": 0,
	"toughness": 0,
	"savvy": 0,
	"luck": 0
}
@export var xp: int = 0
@export var abilities: Array[String] = []

@export var position: Vector2 = Vector2.ZERO
@export var health: int = 10
@export var max_health: int = 10
@export var is_aiming: bool = false
@export var current_location: Location = null
@export var psionic_manager: PsionicManager = null
@export var is_psionic: bool = false
@export var psionic_powers: Array[String] = []

var inventory: CharacterInventory
var recover_time: int = 0
var became_casualty: bool = false
var killed_unique_individual: bool = false
var faction_standings: Dictionary = {}
var status_effects: Array[StatusEffect] = []

var strange_character: StrangeCharacters = null

func _init() -> void:
	inventory = CharacterInventory.new()

func generate_random() -> void:
	name = CharacterNameGenerator.get_random_name()
	race = Race.values()[randi() % Race.size()]
	background = Background.values()[randi() % Background.size()]
	motivation = Motivation.values()[randi() % Motivation.size()]
	character_class = Class.values()[randi() % Class.size()]
	portrait = get_random_portrait()

	for stat in ["reactions", "speed", "combat_skill", "toughness", "savvy", "luck"]:
		stats[stat] = randi() % 6 + 1  # Random value between 1 and 6

	apply_background_bonuses()
	apply_motivation_bonuses()
	apply_class_bonuses()

func apply_background_bonuses() -> void:
	var background_data = get_background_stats(background)
	for stat in background_data:
		if stat in stats:
			stats[stat] += background_data[stat]

func apply_motivation_bonuses() -> void:
	var motivation_data = get_motivation_stats(motivation)
	for stat in motivation_data:
		if stat in stats:
			stats[stat] += motivation_data[stat]

func apply_class_bonuses() -> void:
	var class_data = get_class_stats(character_class)
	for stat in class_data:
		if stat in stats:
			stats[stat] += class_data[stat]

func get_random_portrait() -> String:
	# Implement logic to get a random portrait
	return "res://path/to/default_portrait.png"

func get_background_stats(bg: Background) -> Dictionary:
	var creation_data = CharacterCreationData.new()
	creation_data.load_data()
	var background_data = creation_data.get_background_data(bg)
	var stats = {}
	if "speed" in background_data:
		stats["speed"] = background_data["speed"]
	if "savvy" in background_data:
		stats["savvy"] = background_data["savvy"]
	if "combat_skill" in background_data:
		stats["combat_skill"] = background_data["combat_skill"]
	if "toughness" in background_data:
		stats["toughness"] = background_data["toughness"]
	return stats

func get_motivation_stats(mot: Motivation) -> Dictionary:
	var creation_data = CharacterCreationData.new()
	creation_data.load_data()
	var motivation_data = creation_data.get_motivation_data(mot)
	var stats = {}
	if "speed" in motivation_data:
		stats["speed"] = motivation_data["speed"]
	if "xp" in motivation_data:
		stats["xp"] = motivation_data["xp"]
	return stats

func get_class_stats(cls: Class) -> Dictionary:
	var creation_data = CharacterCreationData.new()
	creation_data.load_data()
	var class_data = creation_data.get_class_data(cls)
	var stats = {}
	if "savvy" in class_data:
		stats["savvy"] = class_data["savvy"]
	if "combat_skill" in class_data:
		stats["combat_skill"] = class_data["combat_skill"]
	return stats

func update(new_data: Dictionary) -> void:
	for key in new_data:
		if key in self:
			set(key, new_data[key])

func add_ability(ability_name: String) -> void:
	if not ability_name in abilities:
		abilities.append(ability_name)

func has_ability(ability_name: String) -> bool:
	return ability_name in abilities

func add_xp(amount: int) -> void:
	xp += amount
	xp_added.emit(amount)

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
	var stat_names = ["reactions", "speed", "combat_skill", "toughness", "savvy"]
	var stat = stat_names[randi() % stat_names.size()]
	stats[stat] = max(1, stats[stat] - 1)
	stat_reduced.emit(stat, 1)

func is_defeated() -> bool:
	return health <= 0

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		killed.emit()

func apply_status_effect(effect: StatusEffect) -> void:
	status_effects.append(effect)

func remove_status_effect(effect_type: String) -> void:
	status_effects = status_effects.filter(func(effect): return effect.type != effect_type)

func has_status_effect(effect_type: String) -> bool:
	return status_effects.any(func(effect): return effect.type == effect_type)

func process_status_effects() -> void:
	for effect in status_effects:
		effect.process(self)
	status_effects = status_effects.filter(func(effect): return not effect.is_expired())

func get_equipped_weapon() -> Weapon:
	return inventory.get_equipped_weapon()

func has_usable_items() -> bool:
	return inventory.has_usable_items()

func get_display_string() -> String:
	return "{0} - {1} {2}".format([name, Race.keys()[race], Background.keys()[background]])

func _to_string() -> String:
	return get_display_string()

static func create_random_character() -> Character:
	var character = Character.new()
	character.generate_random()
	return character

func set_faction_standing(faction_name: String, standing: int) -> void:
	faction_standings[faction_name] = standing

func get_faction_standing(faction_name: String) -> int:
	return faction_standings.get(faction_name, 0)

func apply_character_effects(character_data: CharacterCreationData):
	# Apply race effects
	var race_data = character_data.get_race_data(GlobalEnums.Race.keys()[race])
	apply_stat_bonuses(race_data.get("base_stats", {}))
	for ability in race_data.get("special_abilities", []):
		abilities.append(ability)
	
	# Apply background effects
	var background_data = character_data.get_background_data(GlobalEnums.Background.keys()[background])
	apply_stat_bonuses(background_data.get("stat_bonuses", {}))
	for item in background_data.get("starting_gear", []):
		inventory.add_item(item)
	
	# Apply motivation effects
	var motivation_data = character_data.get_motivation_data(GlobalEnums.Motivation.keys()[motivation])
	apply_stat_bonuses(motivation_data.get("stat_bonuses", {}))
	xp += motivation_data.get("starting_xp", 0)
	
	# Apply class effects
	var class_data = character_data.get_class_data(GlobalEnums.Class.keys()[character_class])
	apply_stat_bonuses(class_data.get("stat_bonuses", {}))
	for item in class_data.get("starting_gear", []):
		inventory.add_item(item)
	
	# Apply strange character effects if applicable
	if strange_character:
		strange_character.apply_special_abilities(self)

func apply_stat_bonuses(bonuses: Dictionary):
	for stat in bonuses:
		if stat in stats:
			stats[stat] += bonuses[stat]

func make_psionic():
	is_psionic = true
	psionic_manager = PsionicManager.new()
	psionic_manager.generate_starting_powers()
	psionic_powers = psionic_manager.powers

func use_psionic_power(power: String, _target: Character) -> bool:
	if is_psionic and power in psionic_powers:
		return psionic_manager.use_power(power, self)
	return false

func set_strange_character_type(type: StrangeCharacters.StrangeCharacterType):
	strange_character = StrangeCharacters.new(type)
	strange_character.apply_special_abilities(self)

# Removed duplicate add_ability function

func serialize() -> Dictionary:
	var data = {
		"name": name,
		"race": Race.keys()[race],
		"background": Background.keys()[background],
		"motivation": Motivation.keys()[motivation],
		"character_class": Class.keys()[character_class],
		"portrait": portrait,
		"stats": stats,
		"xp": xp,
		"abilities": abilities,
		"position": {"x": position.x, "y": position.y},
		"health": health,
		"max_health": max_health,
		"is_aiming": is_aiming,
		"inventory": inventory.serialize(),
		"recover_time": recover_time,
		"became_casualty": became_casualty,
		"killed_unique_individual": killed_unique_individual,
		"faction_standings": faction_standings,
		"status_effects": status_effects.map(func(effect): return effect.serialize()),
		"is_psionic": is_psionic,
		"psionic_powers": psionic_powers
	}
	
	if current_location:
		data["current_location"] = current_location.serialize()
	
	if psionic_manager:
		data["psionic_manager"] = psionic_manager.serialize()
	
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
	character.portrait = data["portrait"]
	character.stats = data["stats"]
	character.xp = data["xp"]
	character.abilities = data["abilities"]
	character.position = Vector2(data["position"]["x"], data["position"]["y"])
	character.health = data["health"]
	character.max_health = data["max_health"]
	character.is_aiming = data["is_aiming"]
	character.inventory = CharacterInventory.deserialize(data["inventory"])
	character.recover_time = data["recover_time"]
	character.became_casualty = data["became_casualty"]
	character.killed_unique_individual = data["killed_unique_individual"]
	character.faction_standings = data["faction_standings"]
	character.status_effects = data["status_effects"].map(func(effect_data): return StatusEffect.deserialize(effect_data))
	character.is_psionic = data.get("is_psionic", false)
	character.psionic_powers = data.get("psionic_powers", [])
	
	if "current_location" in data:
		character.current_location = Location.deserialize(data["current_location"])
	
	if "psionic_manager" in data:
		character.psionic_manager = PsionicManager.deserialize(data["psionic_manager"])
	
	if "strange_character" in data:
		character.strange_character = StrangeCharacters.deserialize(data["strange_character"])
	
	return character
