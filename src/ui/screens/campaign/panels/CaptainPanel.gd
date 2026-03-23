extends Control

# Character class_name is globally available — do NOT preload Base/Character.gd (shadows the canonical class)
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
signal captain_updated(captain)

@onready var content = $Content
@onready var character_creator = $CharacterCreator
@onready var captain_info = $Content/CaptainInfo/Label
@onready var create_button = $Content/Controls/CreateButton
@onready var edit_button = $Content/Controls/EditButton
@onready var randomize_button = $Content/Controls/RandomizeButton

var current_captain # Untyped — CharacterCreator may return canonical Character or BaseCharacterResource

func _ready() -> void:
	_apply_base_background()
	_connect_signals()
	_update_ui()

## Apply Deep Space COLOR_BASE background
func _apply_base_background() -> void:
	var bg := ColorRect.new()
	bg.name = "__panel_bg"
	bg.color = Color("#1A1A2E")  # COLOR_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)

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
	if character and "is_captain" in character:
		character.is_captain = true
	character_creator.hide()
	content.show()
	_update_ui()
	captain_updated.emit(current_captain)

func _on_character_edited(character) -> void:
	current_captain = character
	if character and "is_captain" in character:
		character.is_captain = true
	character_creator.hide()
	content.show()
	_update_ui()
	captain_updated.emit(current_captain)

func _on_creation_cancelled() -> void:
	character_creator.hide()
	content.show()

func _update_ui() -> void:
	if current_captain:
		var fmt := "Captain Information:" \
			+ "\nName: %s\nClass: %s\nOrigin: %s" \
			+ "\nBackground: %s\nMotivation: %s" \
			+ "\n\nStats:" \
			+ "\n  Combat: %d    Reactions: %d    Toughness: %d" \
			+ "\n  Speed: %d     Savvy: %d       Luck: %d"
		var info_text = fmt % [
			current_captain.character_name,
			_enum_value_name(
				GlobalEnums.CharacterClass,
				current_captain.character_class),
			_enum_value_name(
				GlobalEnums.Origin,
				current_captain.origin),
			_enum_value_name(
				GlobalEnums.Background,
				current_captain.background),
			_enum_value_name(
				GlobalEnums.Motivation,
				current_captain.motivation),
			current_captain.combat,
			current_captain.reaction,
			current_captain.toughness,
			current_captain.speed,
			current_captain.savvy,
			current_captain.luck,
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

func _enum_value_name(enum_dict: Dictionary, value: Variant) -> String:
	if value is String:
		if value.is_empty():
			return "None"
		return value.capitalize()
	for key in enum_dict:
		if enum_dict[key] == value:
			return key.capitalize()
	return "Unknown"

func get_captain_data():
	return current_captain

func is_valid() -> bool:
	return current_captain != null