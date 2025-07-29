extends Control
class_name SimpleCharacterCreator

## Simplified Character Creator for Five Parsecs
## Works with the CaptainPanel scene structure

const Character = preload("res://src/core/character/Character.gd")
# GlobalEnums available as autoload singleton

signal character_created(character: Character)
signal character_edited(character: Character)
signal character_creation_cancelled()
signal character_editing_cancelled()

enum CreatorMode {
	CREW_MEMBER,
	CAPTAIN,
	CUSTOM
}

# UI Components
@onready var name_input: LineEdit = $Dialog/VBoxContainer/NameContainer/NameInput
@onready var combat_value: Label = $Dialog/VBoxContainer/StatsContainer/StatsDisplay/CombatValue
@onready var toughness_value: Label = $Dialog/VBoxContainer/StatsContainer/StatsDisplay/ToughnessValue
@onready var savvy_value: Label = $Dialog/VBoxContainer/StatsContainer/StatsDisplay/SavvyValue
@onready var tech_value: Label = $Dialog/VBoxContainer/StatsContainer/StatsDisplay/TechValue
@onready var speed_value: Label = $Dialog/VBoxContainer/StatsContainer/StatsDisplay/SpeedValue
@onready var luck_value: Label = $Dialog/VBoxContainer/StatsContainer/StatsDisplay/LuckValue

@onready var randomize_button: Button = $Dialog/VBoxContainer/ButtonContainer/RandomizeButton
@onready var create_button: Button = $Dialog/VBoxContainer/ButtonContainer/CreateButton
@onready var cancel_button: Button = $Dialog/VBoxContainer/ButtonContainer/CancelButton

var current_mode: CreatorMode = CreatorMode.CREW_MEMBER
var editing_character: Character = null
var current_character: Character = null

func _ready() -> void:
	name = "SimpleCharacterCreator"
	visible = false
	_connect_signals()

func _connect_signals() -> void:
	if randomize_button:
		randomize_button.pressed.connect(_on_randomize_pressed)
	if create_button:
		create_button.pressed.connect(_on_create_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func start_creation(mode: CreatorMode = CreatorMode.CREW_MEMBER) -> void:
	current_mode = mode
	editing_character = null
	_reset_form()
	_generate_random_stats()
	show()

func edit_character(character: Character) -> void:
	editing_character = character
	current_character = character.duplicate()
	_populate_form(character)
	show()

func _reset_form() -> void:
	if name_input:
		name_input.text = ""
	current_character = Character.new()

func _populate_form(character: Character) -> void:
	if name_input:
		name_input.text = character.character_name
	_update_stats_display()

func _generate_random_stats() -> void:
	if not current_character:
		current_character = Character.new()
	
	# Generate stats using Five Parsecs rules (2d6 for each stat)
	current_character.combat = _roll_2d6()
	current_character.toughness = _roll_2d6()
	current_character.savvy = _roll_2d6()
	current_character.tech = _roll_2d6()
	current_character.speed = _roll_2d6()
	current_character.luck = 1  # Starting luck
	
	# Captains get better stats
	if current_mode == CreatorMode.CAPTAIN:
		current_character.combat = max(current_character.combat, 3)
		current_character.toughness = max(current_character.toughness, 3)
		current_character.savvy = max(current_character.savvy, 3)
		current_character.luck = 2
	
	# Calculate health
	current_character.max_health = current_character.toughness + 2
	current_character.health = current_character.max_health
	
	_update_stats_display()

func _roll_2d6() -> int:
	return randi_range(1, 6) + randi_range(1, 6)

func _update_stats_display() -> void:
	if not current_character:
		return
		
	if combat_value:
		combat_value.text = str(current_character.combat)
	if toughness_value:
		toughness_value.text = str(current_character.toughness)
	if savvy_value:
		savvy_value.text = str(current_character.savvy)
	if tech_value:
		tech_value.text = str(current_character.tech)
	if speed_value:
		speed_value.text = str(current_character.speed)
	if luck_value:
		luck_value.text = str(current_character.luck)

func _on_randomize_pressed() -> void:
	_generate_random_stats()

func _on_create_pressed() -> void:
	if not current_character:
		return
		
	# Set name from input
	if name_input:
		current_character.character_name = name_input.text
	
	# Default name if empty
	if current_character.character_name.is_empty():
		current_character.character_name = "Captain" if current_mode == CreatorMode.CAPTAIN else "Crew Member"
	
	# Emit appropriate signal
	if editing_character:
		character_edited.emit(current_character)
	else:
		character_created.emit(current_character)
	
	hide()

func _on_cancel_pressed() -> void:
	if editing_character:
		character_editing_cancelled.emit()
	else:
		character_creation_cancelled.emit()
	hide()

# Public API for compatibility
func get_current_character() -> Character:
	return current_character

func set_character_name(new_name: String) -> void:
	if current_character:
		current_character.character_name = new_name
	if name_input:
		name_input.text = new_name

# Core API method for backend integration
func create_character(background: GlobalEnums.CharacterBackground = GlobalEnums.CharacterBackground.MILITARY, 
					motivation: GlobalEnums.CharacterMotivation = GlobalEnums.CharacterMotivation.FAME, 
					character_class: GlobalEnums.CharacterClass = GlobalEnums.CharacterClass.BASELINE) -> Character:
	var character = Character.new()
	
	# Generate stats using Five Parsecs rules (2d6 for each stat)
	character.combat = _roll_2d6()
	character.toughness = _roll_2d6()
	character.savvy = _roll_2d6()
	character.tech = _roll_2d6()
	character.speed = _roll_2d6()
	character.luck = 1  # Starting luck
	
	# Apply background bonuses
	match background:
		GlobalEnums.CharacterBackground.MILITARY:
			character.combat = max(character.combat, 3)
		GlobalEnums.CharacterBackground.ACADEMIC:
			character.savvy = max(character.savvy, 3)
		GlobalEnums.CharacterBackground.CORPORATE:
			character.tech = max(character.tech, 3)
		GlobalEnums.CharacterBackground.CRIMINAL:
			character.combat = max(character.combat, 2)
			character.toughness = max(character.toughness, 2)
	
	# Apply motivation bonuses
	match motivation:
		GlobalEnums.CharacterMotivation.WEALTH:
			character.luck += 1
		GlobalEnums.CharacterMotivation.FAME:
			character.savvy += 1
		GlobalEnums.CharacterMotivation.REVENGE:
			character.combat += 1
	
	# Apply class bonuses
	match character_class:
		GlobalEnums.CharacterClass.CAPTAIN:
			character.combat = max(character.combat, 3)
			character.toughness = max(character.toughness, 3)
			character.savvy = max(character.savvy, 3)
			character.luck = 2
		GlobalEnums.CharacterClass.SPECIALIST:
			# One random attribute gets +1
			var attributes = ["combat", "toughness", "savvy", "tech", "speed"]
			var boost_attribute = attributes[randi() % attributes.size()]
			match boost_attribute:
				"combat": 
					character.combat += 1
				"toughness": 
					character.toughness += 1
				"savvy": 
					character.savvy += 1
				"tech": 
					character.tech += 1
				"speed": 
					character.speed += 1
	
	# Calculate health
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Set default name if not provided
	if character.character_name.is_empty():
		var default_name = "Character"
		match character_class:
			GlobalEnums.CharacterClass.CAPTAIN:
				default_name = "Captain"
			GlobalEnums.CharacterClass.SPECIALIST:
				default_name = "Specialist"
			GlobalEnums.CharacterClass.BASELINE:
				default_name = "Crew Member"
			_:
				default_name = "Character"
		character.character_name = default_name + " " + str(randi() % 1000)
	
	return character