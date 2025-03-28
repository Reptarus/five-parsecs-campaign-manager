extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal captain_updated(captain: Character)

@onready var character_creator = $CharacterCreator
@onready var captain_info = $Content/CaptainInfo/Label
@onready var create_button = $Content/Controls/CreateButton
@onready var edit_button = $Content/Controls/EditButton
@onready var randomize_button = $Content/Controls/RandomizeButton

var current_captain: Character

func _ready() -> void:
	_connect_signals()
	_update_ui()

func _connect_signals() -> void:
	create_button.pressed.connect(_on_create_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)
	
	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)

func _on_create_pressed() -> void:
	character_creator.start_creation(CharacterCreator.CreatorMode.CAPTAIN)
	character_creator.show()

func _on_edit_pressed() -> void:
	if current_captain:
		character_creator.edit_character(current_captain)
		character_creator.show()

func _on_randomize_pressed() -> void:
	character_creator.start_creation(CharacterCreator.CreatorMode.CAPTAIN)
	character_creator._on_randomize_pressed() # Use existing randomization logic
	character_creator.hide()

func _on_character_created(character: Character) -> void:
	current_captain = character
	_update_ui()
	captain_updated.emit(current_captain)

func _on_character_edited(character: Character) -> void:
	current_captain = character
	_update_ui()
	captain_updated.emit(current_captain)

func _update_ui() -> void:
	if current_captain:
		var info_text = """Captain Information:
		Name:%s
		Class:%s
		Origin:%s
		Background:%s
		Motivation:%s""" % [
			current_captain.character_name,
			GameEnums.CharacterClass.keys()[current_captain.character_class],
			GameEnums.Origin.keys()[current_captain.origin],
			GameEnums.Background.keys()[current_captain.background],
			GameEnums.Motivation.keys()[current_captain.motivation]
		]
		
		captain_info.text = info_text
		create_button.hide()
		edit_button.show()
		randomize_button.hide()
	else:
		captain_info.text = "No captain created yet. Click 'Create Captain' to begin."
		create_button.show()
		edit_button.hide()
		randomize_button.show()

func get_captain_data() -> Character:
	return current_captain

func is_valid() -> bool:
	return current_captain != null