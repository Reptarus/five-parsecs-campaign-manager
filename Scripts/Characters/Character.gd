class_name Character
extends Resource

<<<<<<< HEAD
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
=======
signal experience_gained(amount: int)
signal leveled_up(new_level: int, available_upgrades: Array)
signal experience_updated(new_xp: int, xp_for_next_level: int)
signal request_new_trait
signal request_upgrade_choice(upgrade_options: Array)

var character_advancement: CharacterAdvancement

@export var name: String
@export var species: GlobalEnums.Species
@export var background: GlobalEnums.Background
@export var motivation: GlobalEnums.Motivation
@export var character_class: GlobalEnums.Class
@export var is_strange: bool = false
@export var strange_type: String = ""
>>>>>>> parent of 1efa334 (worldphase functionality)

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var xp: int = 0
@export var luck: int = 0
@export var abilities: Array[String] = []

<<<<<<< HEAD
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
=======
@export var inventory: Array[Dictionary] = []
@export var traits: Array[String] = []

var medbay_turns_left: int = 0
var injuries: Array[String] = []
var position: Vector2i
var weapon: Weapon
var is_defeated: bool = false
var is_priority_target: bool = false
var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.ACTIVE
var ai_controller: AIController
var ai_enabled: bool = false

func _init() -> void:
	character_advancement = CharacterAdvancement.new(self)
	character_advancement.upgrade_available.connect(_on_upgrade_available)

func initialize(p_species: GlobalEnums.Species, p_background: GlobalEnums.Background, 
				p_motivation: GlobalEnums.Motivation, p_character_class: GlobalEnums.Class) -> void:
	self.species = p_species
	self.background = p_background
	self.motivation = p_motivation
	self.character_class = p_character_class
	initialize_default_stats()
	apply_background_effects(background)
	apply_class_effects(character_class)
	self.character_advancement = CharacterAdvancement.new(self)
>>>>>>> parent of 1efa334 (worldphase functionality)

	if randf() < 0.1:  # 10% chance for strange abilities
		var strange_type = StrangeCharacters.StrangeCharacterType.values()[randi() % StrangeCharacters.StrangeCharacterType.size()]
		strange_character = StrangeCharacters.new()
		strange_character.initialize(strange_type)
		strange_character.apply_special_abilities(self)

<<<<<<< HEAD
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
=======
func apply_background_effects(bg: GlobalEnums.Background) -> void:
	var background_data = GameStateManager.character_creation_data.get_background_data(GlobalEnums.Background.keys()[bg].to_lower())
	if background_data:
		for stat in background_data.get("effects", {}):
			var value = background_data["effects"][stat]
			if self.get(stat) != null:
				self.set(stat, self.get(stat) + value)
			else:
				push_warning("Attempted to modify non-existent stat: " + stat)

func apply_class_effects(class_type: GlobalEnums.Class) -> void:
	var class_data = GameStateManager.character_creation_data.get_class_data(GlobalEnums.Class.keys()[class_type].to_lower())
	if class_data:
		for ability in class_data.get("abilities", []):
			traits.append(ability)
		for stat in class_data.get("effects", {}):
			var value = class_data["effects"][stat]
			if self.get(stat) != null:
				self.set(stat, self.get(stat) + value)
			else:
				push_warning("Attempted to modify non-existent stat: " + str(stat))
>>>>>>> parent of 1efa334 (worldphase functionality)

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

func serialize() -> Dictionary:
	var serialized_skills = {}
	for skill_name in skills:
		serialized_skills[skill_name] = skills[skill_name].to_dict()
	
	return {
		"name": name,
		"race": Race.keys()[race],
		"background": Background.keys()[background],
		"motivation": Motivation.keys()[motivation],
		"character_class": Class.keys()[character_class],
		"skills": serialized_skills,
		"portrait": portrait,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"xp": xp,
		"luck": luck,
<<<<<<< HEAD
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
=======
		"inventory": inventory,
		"traits": traits,
		"medbay_turns_left": medbay_turns_left,
		"injuries": injuries,
		"status": GlobalEnums.CharacterStatus.keys()[status]
>>>>>>> parent of 1efa334 (worldphase functionality)
	}

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

static func deserialize(data: Dictionary) -> Character:
	var character = Character.new()
<<<<<<< HEAD
	character.name = data["name"]
	character.race = Race[data["race"]]
	character.background = Background[data["background"]]
	character.motivation = Motivation[data["motivation"]]
	character.character_class = Class[data["character_class"]]
	character.skills = {}
	for skill_name in data["skills"]:
		character.skills[skill_name] = Skill.from_dict(data["skills"][skill_name])
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
	if data["strange_character"]:
		character.strange_character = StrangeCharacters.new()
		character.strange_character.from_dict(data["strange_character"])
	return character
=======
	character.name = data.get("name", "")
	character.species = GlobalEnums.Species[data.get("species", "HUMAN")]
	character.background = GlobalEnums.Background[data.get("background", "HIGH_TECH_COLONY")]
	character.character_class = GlobalEnums.Class[data.get("character_class", "WORKING_CLASS")]
	character.motivation = GlobalEnums.Motivation[data.get("motivation", "ADVENTURE")]
	character.is_strange = data.get("is_strange", false)
	character.strange_type = data.get("strange_type", "")
	character.reactions = data.get("reactions", 1)
	character.speed = data.get("speed", 4)
	character.combat_skill = data.get("combat_skill", 0)
	character.toughness = data.get("toughness", 3)
	character.savvy = data.get("savvy", 0)
	character.xp = data.get("xp", 0)
	character.level = data.get("level", 1)
	character.luck = data.get("luck", 0)
	character.inventory = data.get("inventory", [])
	character.traits = data.get("traits", [])
	character.medbay_turns_left = data.get("medbay_turns_left", 0)
	character.injuries = data.get("injuries", [])
	character.status = GlobalEnums.CharacterStatus[data.get("status", "ACTIVE")]
	character.character_advancement = CharacterAdvancement.new(character)
	return character

static func generate_name(species_type: GlobalEnums.Species) -> String:
	var name_part1 := ""
	var name_part2 := ""
	
	match species_type:
		GlobalEnums.Species.HUMAN:
			name_part1 = get_random_name_part("World Names Generator")
			name_part2 = get_random_name_part("Colony Names Generator", "Part 2")
		GlobalEnums.Species.KERIN:
			name_part1 = get_random_name_part("Ship Names Generator", "Part 1")
			name_part2 = get_random_name_part("Ship Names Generator", "Part 2")
		GlobalEnums.Species.BOT:
			name_part1 = get_random_name_part("Corporate Patron Names Generator", "Part 1")
			name_part2 = get_random_name_part("Corporate Patron Names Generator", "Part 2")
		_:
			name_part1 = get_random_name_part("World Names Generator")
			name_part2 = get_random_name_part("Colony Names Generator", "Part 2")
	
	return name_part1 + " " + name_part2

static func get_random_name_part(generator_title: String, part: String = "") -> String:
	var name_tables = load("res://data/RulesReference/NameGenerationTables.json").get("NameGenerationTables").get("content")
	
	for table in name_tables:
		if table.get("title") == generator_title:
			if part == "":
				return get_random_name_from_table(table.get("table"))
			else:
				for sub_table in table.get("tables"):
					if sub_table.get("name") == part:
						return get_random_name_from_table(sub_table.get("table"))
	
	return "Unknown"

static func get_random_name_from_table(table: Array) -> String:
	var roll := randi() % 100 + 1
	for entry in table:
		var roll_range: PackedStringArray = entry.get("roll").split("-")
		if roll_range.size() == 1:
			if int(roll_range[0]) == roll:
				return entry.get("name")
		elif roll_range.size() == 2:
			if roll >= int(roll_range[0]) and roll <= int(roll_range[1]):
				return entry.get("name")
	
	return "Unknown"

static func create_temporary() -> Character:
	var temp_ally := Character.new()
	
	temp_ally.name = generate_name(GlobalEnums.Species.HUMAN)
	temp_ally.speed = 4
	temp_ally.combat_skill = 0
	temp_ally.toughness = 4
	temp_ally.savvy = 1
	temp_ally.weapon = Weapon.new("Handgun", GlobalEnums.WeaponType.PISTOL, 6, 1, 1)
	temp_ally.traits = ["Basic"]
	temp_ally.luck = 0
	temp_ally.xp = 0
	temp_ally.species = GlobalEnums.Species.HUMAN
	temp_ally.reactions = 1
	
	temp_ally.ai_controller = AIController.new()
	temp_ally.ai_enabled = false

	return temp_ally

func toggle_ai(enable: bool) -> void:
	if enable and not ai_controller:
		ai_controller = AIController.new()
		ai_controller.initialize(GameStateManager.combat_manager, GameStateManager)
	elif not enable and ai_controller:
		ai_controller.queue_free()
		ai_controller = null
	
	ai_enabled = enable
>>>>>>> parent of 1efa334 (worldphase functionality)
