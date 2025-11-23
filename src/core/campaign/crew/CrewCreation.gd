extends Control

## Five Parsecs Crew Creation System
## Implements full Five Parsecs From Home crew generation rules

# Safe imports
const CoreCharacter = preload("res://src/core/character/Character.gd")
# GlobalEnums available as autoload singleton

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

func _ready() -> void:
	_setup_ui()
	_connect_signals()

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

	var character: Character = _generate_five_parsecs_character()
	crew_members.append(character)

	# Add to UI list
	var class_int = _convert_class_string_to_int(character.character_class)
	var character_name: String = "%s (%s)" % [character.character_name, _get_class_name(class_int)]
	character_list.add_item(character_name)

	_update_ui_state()
	character_generated.emit(character)

	# Auto-select the new character
	character_list.select(character_list.get_item_count() - 1)
	_display_character_details(character)

## Generate character using Five Parsecs From Home rules
func _generate_five_parsecs_character() -> CoreCharacter:
	var character: CoreCharacter = CoreCharacter.new()

	# Step 1: Generate attributes using 2D6 / 3.0 (rounded up)
	character.reactions = _roll_five_parsecs_attribute()
	character.speed = _roll_five_parsecs_attribute() + 2 # Base 4" + attribute
	character.combat = _roll_five_parsecs_attribute() - 3 # Base +0 + attribute
	character.toughness = _roll_five_parsecs_attribute() # Base 3 + attribute
	character.savvy = _roll_five_parsecs_attribute() - 3 # Base +0 + attribute

	# Step 2: Roll background (D100 table) - convert to string
	var background_roll = _roll_background()
	character.background = _get_background_string_from_roll(background_roll)

	# Step 3: Roll motivation (D100 table) - convert to string  
	var motivation_roll = _roll_motivation()
	character.motivation = _get_motivation_string_from_roll(motivation_roll)

	# Step 4: Determine character class from background roll
	var class_int = _determine_class_from_background(background_roll)
	character.character_class = _convert_class_int_to_string(class_int)

	# Step 5: Generate name
	character.character_name = _generate_character_name()

	# Step 6: Apply origin traits (using Origin enum instead of species)
	_apply_origin_traits(character)

	# Step 7: Set starting equipment based on class
	_assign_starting_equipment(character)

	return character

## Five Parsecs attribute generation: 2D6 divided by 3, rounded up
func _roll_five_parsecs_attribute() -> int:
	var roll = _roll_2d6()
	return ceili(float(roll) / 3.0)

## Roll 2D6 for attribute generation
func _roll_2d6() -> int:
	return (randi() % 6 + 1) + (randi() % 6 + 1)

## Roll D100 for background
func _roll_background() -> int:
	return randi() % 100 + 1

## Roll D100 for motivation
func _roll_motivation() -> int:
	return randi() % 100 + 1

## Convert background roll to string
func _get_background_string_from_roll(roll: int) -> String:
	if roll <= 20:
		return "MILITARY"
	elif roll <= 40:
		return "CRIMINAL" 
	elif roll <= 60:
		return "ACADEMIC"
	elif roll <= 80:
		return "MERCENARY"
	else:
		return "COLONIST"

## Convert motivation roll to string
func _get_motivation_string_from_roll(roll: int) -> String:
	if roll <= 20:
		return "SURVIVAL"
	elif roll <= 40:
		return "WEALTH"
	elif roll <= 60:
		return "POWER"
	elif roll <= 80:
		return "REVENGE"
	else:
		return "GLORY"

## Determine character class from background roll
func _determine_class_from_background(background_roll: int) -> int:
	# Simplified class determination - in full implementation this would use background tables
	if background_roll <= 20:
		return 1 # SOLDIER
	elif background_roll <= 40:
		return 2 # ENGINEER
	elif background_roll <= 60:
		return 3 # PILOT
	elif background_roll <= 80:
		return 4 # MEDIC
	else:
		return 5 # MERCHANT

## Generate character name
func _generate_character_name() -> String:
	var first_names = ["Alex", "Jordan", "Casey", "Riley", "Morgan", "Avery", "Taylor", "Cameron"]
	var last_names = ["Stone", "Cross", "Vale", "Kane", "Reed", "Fox", "Storm", "Wolf"]

	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

## Apply origin traits
func _apply_origin_traits(character: CoreCharacter) -> void:
	var origin_roll = _roll_background() # Re-use background roll for origin

	if origin_roll <= 20:
		character.origin = "HUMAN"
		character.luck = 1 # Humans start with 1 luck
	elif origin_roll <= 40:
		character.origin = "ENGINEER"
		character.luck = 1 # Engineers start with 1 luck
	elif origin_roll <= 60:
		character.origin = "FERAL"
		character.luck = 1 # Ferals start with 1 luck
	elif origin_roll <= 80:
		character.origin = "KERIN"
		character.luck = 1 # K'Erin start with 1 luck
	else:
		character.origin = "PRECURSOR"
		character.luck = 1 # Precursors start with 1 luck

## Assign starting equipment based on class
func _assign_starting_equipment(character: CoreCharacter) -> void:
	# Basic starting equipment - in full implementation this would use equipment tables
	pass

## Get class name for display
func _get_class_name(class_id: int) -> String:
	match class_id:
		1: return "Soldier"
		2: return "Engineer"
		3: return "Pilot"
		4: return "Medic"
		5: return "Merchant"
		_: return "Unknown"

func _convert_class_int_to_string(class_int: int) -> String:
	"""Convert character class integer to string for Character property"""
	match class_int:
		1: return "SOLDIER"
		2: return "ENGINEER"
		3: return "PILOT" 
		4: return "MEDIC"
		5: return "MERCHANT"
		_: return "BASELINE"

func _convert_class_string_to_int(class_string: String) -> int:
	"""Convert character class string to integer for display functions"""
	match class_string:
		"SOLDIER": return 1
		"ENGINEER": return 2
		"PILOT": return 3
		"MEDIC": return 4
		"MERCHANT": return 5
		_: return 0

## Display character details in the UI
func _display_character_details(character: CoreCharacter) -> void:
	var details = "[b]%s[/b]\n\n" % character.character_name
	var class_int = _convert_class_string_to_int(character.character_class)
	details += "Class: %s\n" % _get_class_name(class_int)
	details += "Origin: %s\n\n" % _get_origin_name(character)
	details += "[b]Attributes:[/b]\n"
	details += "Reactions: %d\n" % character.reactions
	details += "Speed: %d\"\n" % character.speed
	details += "Combat Skill: +%d\n" % character.combat
	details += "Toughness: %d\n" % character.toughness
	details += "Savvy: +%d\n" % character.savvy
	if character.luck > 0:
		details += "Luck: %d\n" % character.luck

	character_details.text = details

## Get origin name for display
func _get_origin_name(character: CoreCharacter) -> String:
	match character.origin:
		"HUMAN":
			return "Human"
		"ENGINEER":
			return "Engineer"
		"FERAL":
			return "Feral"
		"KERIN":
			return "K'Erin"
		"PRECURSOR":
			return "Precursor"
		_:
			return "Unknown"

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

	# Serialize crew for signal emission
	for character in crew_members:
		crew_data.crew_members.append(character.serialize())

	# Save crew to GameStateManager for persistence
	_save_crew_to_game_state()

	crew_created.emit(crew_data)

## Save created crew to GameStateManager for persistence
func _save_crew_to_game_state() -> void:
	if not GameStateManager:
		push_error("CrewCreation: GameStateManager not available - crew will not be persisted")
		return

	var game_state = GameStateManager.game_state
	if not game_state:
		push_error("CrewCreation: No game_state - crew will not be persisted")
		return

	if not "current_campaign" in game_state or not game_state.current_campaign:
		push_error("CrewCreation: No current_campaign - crew will not be persisted")
		return

	# Clear existing crew and add new members
	if "crew_members" in game_state.current_campaign:
		game_state.current_campaign.crew_members.clear()
	else:
		game_state.current_campaign.crew_members = []

	# Add each character (serialized) to the campaign
	for character in crew_members:
		var serialized = character.serialize()
		game_state.current_campaign.crew_members.append(serialized)

	print("CrewCreation: Saved %d crew members to GameStateManager" % crew_members.size())
