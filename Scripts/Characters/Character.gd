class_name Character
extends Resource

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

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var xp: int = 0
@export var level: int = 1
@export var luck: int = 0

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
				p_motivation: GlobalEnums.Motivation, p_character_class: GlobalEnums.Class, 
				_game_state_manager: GameStateManager) -> void:
	self.species = p_species
	self.background = p_background
	self.motivation = p_motivation
	self.character_class = p_character_class
	initialize_default_stats()
	apply_background_effects(background)
	apply_class_effects(character_class)
	self.character_advancement = CharacterAdvancement.new(self)

func initialize_default_stats() -> void:
	match species:
		GlobalEnums.Species.HUMAN:
			reactions = 2
			speed = 4
			combat_skill = 1
			toughness = 3
			savvy = 1
		GlobalEnums.Species.ENGINEER:
			reactions = 1
			speed = 4
			combat_skill = 0
			toughness = 5
			savvy = 0
		GlobalEnums.Species.KERIN:
			reactions = 3
			speed = 4
			combat_skill = 0
			toughness = 3
			savvy = 2
		GlobalEnums.Species.FERAL:
			reactions = 3
			speed = 5
			combat_skill = 1
			toughness = 4
			savvy = 0
		GlobalEnums.Species.SKULKER:
			reactions = 4
			speed = 7
			combat_skill = 1
			toughness = 4
			savvy = 0

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

func add_xp(amount: int) -> void:
	xp += amount
	experience_gained.emit(amount)
	character_advancement.apply_experience(amount)
	_update_experience()

func _update_experience() -> void:
	var xp_for_next = character_advancement.get_xp_for_next_level(level)
	experience_updated.emit(xp, xp_for_next)
	if xp >= xp_for_next:
		_level_up()

func _level_up() -> void:
	level += 1
	var available_upgrades = character_advancement.get_available_upgrades()
	leveled_up.emit(level, available_upgrades)
	request_new_trait.emit()

func _on_upgrade_available(upgrades: Array) -> void:
	request_upgrade_choice.emit(upgrades)

func apply_upgrade(upgrade: Dictionary) -> void:
	character_advancement.apply_upgrade(upgrade)
	_update_experience()

func add_item(item: Dictionary) -> void:
	inventory.append(item)

func remove_item(item: Dictionary) -> void:
	inventory.erase(item)

func get_all_items() -> Array[Dictionary]:
	return inventory

func clear_inventory() -> void:
	inventory.clear()

func set_strange_character(type: String) -> void:
	is_strange = true
	strange_type = type
	# Apply special abilities based on type

static func create(p_species: GlobalEnums.Species, p_background: GlobalEnums.Background, p_motivation: GlobalEnums.Motivation, p_character_class: GlobalEnums.Class, _game_state_manager: GameStateManager) -> Character:
	var character = Character.new()
	character.initialize(p_species, p_background, p_motivation, p_character_class, _game_state_manager)
	character.name = generate_name(p_species)
	return character

func get_xp_for_next_level() -> int:
	return character_advancement.get_xp_for_next_level(level)

func get_available_upgrades() -> Array:
	return character_advancement.get_available_upgrades()

func serialize() -> Dictionary:
	return {
		"name": name,
		"species": GlobalEnums.Species.keys()[species],
		"background": GlobalEnums.Background.keys()[background],
		"character_class": GlobalEnums.Class.keys()[character_class],
		"motivation": GlobalEnums.Motivation.keys()[motivation],
		"is_strange": is_strange,
		"strange_type": strange_type,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"xp": xp,
		"level": level,
		"luck": luck,
		"inventory": inventory,
		"traits": traits,
		"medbay_turns_left": medbay_turns_left,
		"injuries": injuries,
		"status": GlobalEnums.CharacterStatus.keys()[status]
	}

static func deserialize(data: Dictionary, _game_state_manager: GameStateManager) -> Character:
	var character = Character.new()
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

func toggle_ai(enable: bool, combat_manager: Node, game_state: Node) -> void:
	if enable and not ai_controller:
		ai_controller = AIController.new()
		ai_controller.initialize(combat_manager, game_state)
	elif not enable and ai_controller:
		ai_controller.queue_free()
		ai_controller = null
	
	ai_enabled = enable
