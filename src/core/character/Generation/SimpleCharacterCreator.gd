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

# UI Components - using safe node access
var name_input: LineEdit
var combat_value: Label
var toughness_value: Label
var savvy_value: Label
var tech_value: Label
var speed_value: Label
var luck_value: Label

var randomize_button: Button
var create_button: Button
var cancel_button: Button

var current_mode: CreatorMode = CreatorMode.CREW_MEMBER
var editing_character: Character = null
var current_character: Character = null

func _ready() -> void:
	name = "SimpleCharacterCreator"
	visible = false
	_initialize_ui_components()
	_connect_signals()

func _initialize_ui_components() -> void:
	"""Initialize UI components with safe node access"""
	name_input = get_node_or_null("Dialog/VBoxContainer/NameContainer/NameInput")
	combat_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/CombatValue")
	toughness_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ToughnessValue")
	savvy_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SavvyValue")
	tech_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/TechValue")
	speed_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SpeedValue")
	luck_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/LuckValue")
	
	randomize_button = get_node_or_null("Dialog/VBoxContainer/ButtonContainer/RandomizeButton")
	create_button = get_node_or_null("Dialog/VBoxContainer/ButtonContainer/CreateButton")
	cancel_button = get_node_or_null("Dialog/VBoxContainer/ButtonContainer/CancelButton")
	
	# Log any missing components
	var missing_components = []
	if not name_input: missing_components.append("NameInput")
	if not combat_value: missing_components.append("CombatValue")
	if not toughness_value: missing_components.append("ToughnessValue")
	if not savvy_value: missing_components.append("SavvyValue")
	if not tech_value: missing_components.append("TechValue")
	if not speed_value: missing_components.append("SpeedValue")
	if not luck_value: missing_components.append("LuckValue")
	if not randomize_button: missing_components.append("RandomizeButton")
	if not create_button: missing_components.append("CreateButton")
	if not cancel_button: missing_components.append("CancelButton")
	
	if missing_components.size() > 0:
		push_warning("SimpleCharacterCreator: Missing UI components: %s" % str(missing_components))
	else:
		print("SimpleCharacterCreator: All UI components initialized successfully")

func _connect_signals() -> void:
	if randomize_button and not randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.connect(_on_randomize_pressed)
	if create_button and not create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.connect(_on_create_pressed)
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	print("SimpleCharacterCreator: Signal connections completed")

func start_creation(mode: CreatorMode = CreatorMode.CREW_MEMBER) -> void:
	current_mode = mode
	editing_character = null
	_reset_form()
	_generate_random_stats()
	show()
	print("SimpleCharacterCreator: Started creation in mode: %s" % mode)

func edit_character(character: Character) -> void:
	if not character:
		push_warning("SimpleCharacterCreator: Cannot edit null character")
		return
		
	editing_character = character
	current_character = character.duplicate()
	_populate_form(character)
	show()
	print("SimpleCharacterCreator: Started editing character: %s" % character.character_name)

func _reset_form() -> void:
	if name_input:
		name_input.text = ""
	current_character = Character.new()
	_update_stats_display()

func _populate_form(character: Character) -> void:
	if name_input and character:
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
	current_character.luck = 1 # Starting luck
	
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
	print("SimpleCharacterCreator: Generated random stats for mode: %s" % current_mode)

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
	
	print("SimpleCharacterCreator: Stats updated - Combat:%d Tough:%d Savvy:%d Tech:%d Speed:%d Luck:%d" % [
		current_character.combat, current_character.toughness, current_character.savvy,
		current_character.tech, current_character.speed, current_character.luck
	])

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
	character.luck = 1 # Starting luck
	
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
