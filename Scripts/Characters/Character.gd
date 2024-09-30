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
@export var character_class: GlobalEnums.Class
@export var motivation: GlobalEnums.Motivation
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

# Include methods from CharacterInventory.gd
func add_item(item: Dictionary): inventory.append(item)
func remove_item(item: Dictionary): inventory.erase(item)
func get_all_items() -> Array[Dictionary]: return inventory
func clear_inventory(): inventory.clear()

# Include methods from StrangeCharacters.gd
func set_strange_character(type: String):
	is_strange = true
	strange_type = type
	# Apply special abilities based on type

# Include character creation and management methods
static func create(species: GlobalEnums.Species, background: GlobalEnums.Background, motivation: GlobalEnums.Motivation, character_class: GlobalEnums.Class, game_state_manager: GameStateManagerNode) -> Character:
	var character = Character.new()
	character.initialize(species, background, motivation, character_class, game_state_manager)
	character.name = generate_name(species)
	return character

func initialize(species: GlobalEnums.Species, background: GlobalEnums.Background, motivation: GlobalEnums.Motivation, character_class: GlobalEnums.Class, game_state_manager: GameStateManagerNode) -> void:
	self.species = species
	self.background = background
	self.motivation = motivation
	self.character_class = character_class
	initialize_default_stats()
	apply_background_effects(background)
	apply_class_effects(character_class)
	self.character_advancement = CharacterAdvancement.new(self)

func initialize_default_stats() -> void:
	# Implement default stat initialization based on species
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

func apply_background_effects(background: GlobalEnums.Background) -> void:
	# Implement background effects
	match background:
		GlobalEnums.Background.HIGH_TECH_COLONY:
			savvy += 1
		GlobalEnums.Background.OVERCROWDED_CITY:
			speed += 1
		GlobalEnums.Background.LOW_TECH_COLONY:
			# No specific stat changes
			pass
		GlobalEnums.Background.MINING_COLONY:
			toughness += 1
		GlobalEnums.Background.MILITARY_BRAT:
			combat_skill += 1
		GlobalEnums.Background.SPACE_STATION:
			# No specific stat changes
			pass

func apply_class_effects(character_class: GlobalEnums.Class) -> void:
	# Implement class effects
	match character_class:
		GlobalEnums.Class.SOLDIER:
			combat_skill += 1
			toughness += 1
		GlobalEnums.Class.TECHNICIAN:
			savvy += 1
			speed += 1
		GlobalEnums.Class.SCIENTIST:
			speed += 1
			reactions += 1
		GlobalEnums.Class.MERCENARY:
			toughness += 1
			savvy += 1

func add_xp(amount: int) -> void:
	xp += amount
	emit_signal("experience_gained", amount)
	character_advancement.apply_experience(amount)

func get_xp_for_next_level() -> int:
	return character_advancement.get_xp_for_next_level(level)

func get_available_upgrades() -> Array:
	return character_advancement.get_available_upgrades()

func apply_upgrade(upgrade: Dictionary) -> void:
	character_advancement.apply_upgrade(upgrade)

# Serialization methods
func serialize() -> Dictionary:
	var data = {
		"name": name,
		"species": species,
		"background": background,
		"character_class": character_class,
		"motivation": motivation,
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
		"status": status
	}
	return data

static func deserialize(data: Dictionary, game_state_manager: GameStateManagerNode) -> Character:
	var character = Character.new()
	character.name = data.get("name", "")
	character.species = data.get("species", GlobalEnums.Species.HUMAN)
	character.background = data.get("background", GlobalEnums.Background.HIGH_TECH_COLONY)
	character.character_class = data.get("character_class", GlobalEnums.Class.WORKING_CLASS)
	character.motivation = data.get("motivation", GlobalEnums.Motivation.ADVENTURE)
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
	character.status = data.get("status", GlobalEnums.CharacterStatus.ACTIVE)
	character.character_advancement = CharacterAdvancement.new(character)
	return character

# Static method for name generation
static func generate_name(species: GlobalEnums.Species) -> String:
	var name_part1 = ""
	var name_part2 = ""
	
	match species:
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
	var roll = randi() % 100 + 1
	for entry in table:
		var roll_range = entry.get("roll").split("-")
		if roll_range.size() == 1:
			if int(roll_range[0]) == roll:
				return entry.get("name")
		elif roll_range.size() == 2:
			if roll >= int(roll_range[0]) and roll <= int(roll_range[1]):
				return entry.get("name")
	
	return "Unknown"

static func create_temporary() -> Character:
	var temp_ally = Character.new()
	
	# Initialize temp_ally with necessary properties based on Compendium.md and Core Rules.md
	temp_ally.name = generate_name(GlobalEnums.Species.HUMAN)
	temp_ally.speed = 4
	temp_ally.combat_skill = 0
	temp_ally.toughness = 4
	temp_ally.savvy = 1
	temp_ally.weapon = "Handgun"
	temp_ally.range = 6
	temp_ally.shots = 1
	temp_ally.damage = 1
	temp_ally.traits = ["Basic"]
	temp_ally.gear_notes = "Standard issue"
	temp_ally.luck = 0
	temp_ally.xp = 0
	temp_ally.species = GlobalEnums.Species.HUMAN
	temp_ally.reactions = 1
	
	# Integrate AIController
	var ai_controller = AIController.new()
	temp_ally.add_child(ai_controller)
	temp_ally.ai_controller = ai_controller
	temp_ally.ai_enabled = false  # Toggle to control AI

	return temp_ally

# Method to toggle AI on and off
func toggle_ai(character: Character, enable: bool, combat_manager: Node, game_state: Node) -> void:
	if character.ai_controller:
		character.ai_enabled = enable
		if enable:
			character.ai_controller.initialize(combat_manager, game_state)
		else:
			character.ai_controller.queue_free()
