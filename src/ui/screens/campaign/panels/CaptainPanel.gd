extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
signal captain_updated(captain)

@onready var content = $Content
@onready var character_creator = $CharacterCreator
@onready var captain_info = $Content/CaptainInfo/Label
@onready var create_button = $Content/Controls/CreateButton
@onready var edit_button = $Content/Controls/EditButton
@onready var randomize_button = $Content/Controls/RandomizeButton

var current_captain # Character instance (untyped to avoid class_name resolution mismatch)

func _ready() -> void:
	_connect_signals()
	_update_ui()

func _connect_signals() -> void:
	create_button.pressed.connect(_on_create_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)

	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)
	character_creator.creation_cancelled.connect(_on_creation_cancelled)

func _on_create_pressed() -> void:
	content.hide()
	character_creator.start_creation(CharacterCreator.CreatorMode.CAPTAIN)
	character_creator.show()

func _on_edit_pressed() -> void:
	if current_captain:
		content.hide()
		character_creator.edit_character(current_captain)
		character_creator.show()

func _on_randomize_pressed() -> void:
	character_creator.creator_mode = CharacterCreator.CreatorMode.CAPTAIN
	character_creator.clear()
	character_creator._on_randomize_pressed()
	if character_creator._validate_character():
		_on_character_created(character_creator.current_character)

func _on_character_created(character) -> void:
	current_captain = character
	character_creator.hide()
	content.show()
	_update_ui()
	captain_updated.emit(current_captain)

func _on_character_edited(character) -> void:
	current_captain = character
	character_creator.hide()
	content.show()
	_update_ui()
	captain_updated.emit(current_captain)

func _on_creation_cancelled() -> void:
	character_creator.hide()
	content.show()

func _update_ui() -> void:
	if current_captain:
		var info_text = """Captain Information:
		Name: %s
		Class: %s
		Origin: %s
		Background: %s
		Motivation: %s""" % [
			current_captain.character_name,
			_enum_value_name(GlobalEnums.CharacterClass, current_captain.character_class),
			_enum_value_name(GlobalEnums.Origin, current_captain.origin),
			_enum_value_name(GlobalEnums.Background, current_captain.background),
			_enum_value_name(GlobalEnums.Motivation, current_captain.motivation)
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

func _enum_value_name(enum_dict: Dictionary, value: int) -> String:
	for key in enum_dict:
		if enum_dict[key] == value:
			return key.capitalize()
	return "Unknown"

func get_captain_data():
	return current_captain

func is_valid() -> bool:
	return current_captain != null