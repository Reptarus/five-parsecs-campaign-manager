extends Control

## Five Parsecs Crew Creation System
## Implements full Five Parsecs From Home crew generation rules

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const CoreCharacter = preload("res://src/core/character/Base/Character.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal crew_created(crew_data: Dictionary)
signal character_generated(character: CoreCharacter)

# Character creation UI nodes
@onready var character_list: ItemList = $VBoxContainer/CharacterList
@onready var generate_button: Button = $VBoxContainer/GenerateButton
@onready var finish_button: Button = $VBoxContainer/FinishButton
@onready var character_details: RichTextLabel = $VBoxContainer/CharacterDetails

# Crew data
var crew_members: Array[CoreCharacter] = []
var max_crew_size: int = 6
var dice_manager: Node = null

func _ready() -> void:
	_validate_universal_connections()
	_setup_ui()
	_connect_signals()
func _validate_universal_connections() -> void:
	# Validate dice manager access
	dice_manager = get_node_or_null("/root/DiceManager")
	if not dice_manager:
		push_warning("CORE DEPENDENCY MISSING: DiceManager not found (CrewCreation)")

func _setup_ui() -> void:
	character_list.clear()
	finish_button.disabled = true
	_update_ui_state()

func _connect_signals() -> void:
	generate_button.pressed.connect(_on_generate_character)
	finish_button.pressed.connect(_on_finish_crew_creation)
	character_list.item_selected.connect(_on_character_selected)

func _update_ui_state() -> void:
	generate_button.disabled = crew_members.size() >= max_crew_size
	finish_button.disabled = crew_members.size() == 0
	
	# Update finish button text
	finish_button.text = "Finish Crew (%d/%d)" % [crew_members.size(), max_crew_size]

## Generate a new Five Parsecs character using official rules
func _on_generate_character() -> void:
	if crew_members.size() >= max_crew_size:
		return
	
	var character = _generate_five_parsecs_character()
	crew_members.append(character)
	
	# Add to UI list
	var character_name = "%s (%s)" % [character.character_name, _get_class_name(character.character_class)]
	character_list.add_item(character_name)
	
	_update_ui_state()
	character_generated.emit(character)
	
	# Auto-select the new character
	character_list.select(character_list.get_item_count() - 1)
	_display_character_details(character)

## Generate character using Five Parsecs From Home rules
func _generate_five_parsecs_character() -> CoreCharacter:
	var character = CoreCharacter.new()
	
	# Step 1: Generate attributes using 2D6/3 (rounded up)
	character.reaction = _roll_five_parsecs_attribute()
	character.speed = _roll_five_parsecs_attribute() + 2  # Base 4" + attribute
	character.combat = _roll_five_parsecs_attribute() - 3  # Base +0 + attribute
	character.toughness = _roll_five_parsecs_attribute()  # Base 3 + attribute  
	character.savvy = _roll_five_parsecs_attribute() - 3  # Base +0 + attribute
	
	# Step 2: Roll background (D100 table)
	character.background = _roll_background()
	
	# Step 3: Roll motivation (D100 table)  
	character.motivation = _roll_motivation()
	
	# Step 4: Determine character class from background
	character.character_class = _determine_class_from_background(character.background)
	
	# Step 5: Generate name
	character.character_name = _generate_character_name()
	
	# Step 6: Apply species traits (3 humans + 3 others rule)
	_apply_species_traits(character)
	
	# Step 7: Set starting equipment based on class
	_assign_starting_equipment(character)
	
	return character

## Five Parsecs attribute generation: 2D6 divided by 3, rounded up
func _roll_five_parsecs_attribute() -> int:
	var roll = _roll_2d6()
	return ceili(float(roll) / 3.0)

## Roll 2D6 using dice manager or fallback
func _roll_2d6() -> int:
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(2, 6)
	else:
		# Fallback dice rolling
		return (randi() % 6 + 1) + (randi() % 6 + 1)

## Roll D100 for background
func _roll_background() -> int:
	if dice_manager and dice_manager.has_method("roll_d100"):
		return dice_manager.roll_d100()
	else:
		return randi() % 100 + 1

## Roll D100 for motivation
func _roll_motivation() -> int:
	if dice_manager and dice_manager.has_method("roll_d100"):
		return dice_manager.roll_d100()
	else:
		return randi() % 100 + 1

## Determine character class from background roll
func _determine_class_from_background(background_roll: int) -> int:
	# Simplified class determination - in full implementation this would use background tables
	if background_roll <= 20:
		return GlobalEnums.CharacterClass.SOLDIER if GlobalEnums else 1
	elif background_roll <= 40:
		return GlobalEnums.CharacterClass.ENGINEER if GlobalEnums else 2
	elif background_roll <= 60:
		return GlobalEnums.CharacterClass.PILOT if GlobalEnums else 3
	elif background_roll <= 80:
		return GlobalEnums.CharacterClass.MEDIC if GlobalEnums else 4
	else:
		return GlobalEnums.CharacterClass.MERCHANT if GlobalEnums else 5

## Generate character name
func _generate_character_name() -> String:
	var first_names = ["Alex", "Jordan", "Casey", "Riley", "Morgan", "Avery", "Taylor", "Cameron"]
	var last_names = ["Stone", "Cross", "Vale", "Kane", "Reed", "Fox", "Storm", "Wolf"]
	
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

## Apply species traits (3 humans + 3 others)
func _apply_species_traits(character: CoreCharacter) -> void:
	var human_count = 0
	for member in crew_members:
		if member.is_human:
			human_count += 1
	
	if human_count < 3:
		character.is_human = true
		character.luck = 1  # Humans start with 1 luck
	else:
		# Non-human species
		character.is_human = false
		_apply_alien_traits(character)

## Apply alien species traits
func _apply_alien_traits(character: CoreCharacter) -> void:
	var alien_types = ["Bot", "Soulless", "Alien"]
	var alien_type = alien_types[randi() % alien_types.size()]
	
	match alien_type:
		"Bot":
			character.is_bot = true
			character.toughness += 1  # Bots are tougher
		"Soulless":
			character.is_soulless = true
			character.combat += 1  # Soulless are better fighters
		"Alien":
			# Generic alien - boost a random stat
			var stats = ["reaction", "speed", "combat", "toughness", "savvy"]
			var boost_stat = stats[randi() % stats.size()]
			match boost_stat:
				"reaction": character.reaction = mini(6, character.reaction + 1)
				"speed": character.speed = mini(8, character.speed + 1)
				"combat": character.combat = mini(3, character.combat + 1)
				"toughness": character.toughness = mini(6, character.toughness + 1)
				"savvy": character.savvy = mini(3, character.savvy + 1)

## Assign starting equipment based on class
func _assign_starting_equipment(character: CoreCharacter) -> void:
	# Basic starting equipment - in full implementation this would use equipment tables
	pass

## Get class name for display
func _get_class_name(class_id: int) -> String:
	if GlobalEnums and GlobalEnums.CharacterClass.size() > class_id:
		return GlobalEnums.CharacterClass.keys()[class_id]
	return "Unknown"

## Display character details in the UI
func _display_character_details(character: CoreCharacter) -> void:
	var details = "[b]%s[/b]\n\n" % character.character_name
	details += "Class: %s\n" % _get_class_name(character.character_class)
	details += "Species: %s\n\n" % _get_species_name(character)
	details += "[b]Attributes:[/b]\n"
	details += "Reactions: %d\n" % character.reaction
	details += "Speed: %d\"\n" % character.speed
	details += "Combat Skill: +%d\n" % character.combat
	details += "Toughness: %d\n" % character.toughness
	details += "Savvy: +%d\n" % character.savvy
	if character.luck > 0:
		details += "Luck: %d\n" % character.luck
	
	character_details.text = details

## Get species name for display
func _get_species_name(character: CoreCharacter) -> String:
	if character.is_human:
		return "Human"
	elif character.is_bot:
		return "Bot"
	elif character.is_soulless:
		return "Soulless"
	else:
		return "Alien"

## Handle character selection in list
func _on_character_selected(index: int) -> void:
	if index >= 0 and index < crew_members.size():
		_display_character_details(crew_members[index])

## Finish crew creation and emit data
func _on_finish_crew_creation() -> void:
	var crew_data = {
		"crew_members": [],
		"crew_size": crew_members.size()
	}
	
	for character in crew_members:
		crew_data.crew_members.append(character.serialize())
	
	crew_created.emit(crew_data)