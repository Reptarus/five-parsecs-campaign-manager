extends Control

const Character = preload("res://src/core/character/Character.gd")
const SimpleCharacterCreator = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")
# GlobalEnums available as autoload singleton

signal captain_updated(captain: Character)

@onready var character_creator: Node = $"CharacterCreator"
@onready var captain_info: Label = $"Content/CaptainInfo/Label"
@onready var create_button: Button = $"Content/Controls/CreateButton"
@onready var edit_button: Button = $"Content/Controls/EditButton"
@onready var randomize_button: Button = $"Content/Controls/RandomizeButton"

var current_captain: Character

func _ready() -> void:
	_connect_signals()
	_update_ui()

func _connect_signals() -> void:
	if create_button:
		create_button.pressed.connect(_on_create_pressed)
	if edit_button:
		edit_button.pressed.connect(_on_edit_pressed)
	if randomize_button:
		randomize_button.pressed.connect(_on_randomize_pressed)

	if character_creator:
		character_creator.character_created.connect(_on_character_created)
		character_creator.character_edited.connect(_on_character_edited)
	else:
		push_warning("CaptainPanel: CharacterCreator not found, using fallback methods")

func _on_create_pressed() -> void:
	if character_creator:
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN)
	else:
		# Fallback: create directly
		_create_basic_captain()

func _on_edit_pressed() -> void:
	if current_captain and character_creator:
		character_creator.edit_character(current_captain)
	elif current_captain:
		# Fallback: show basic creation
		_create_basic_captain()

func _on_randomize_pressed() -> void:
	if character_creator:
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN)
		character_creator._on_randomize_pressed()
		character_creator._on_create_pressed()  # Auto-create after randomize
	else:
		# Fallback: create random captain directly
		_create_random_captain()

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
		var info_text: String = "Captain Information:\n"
		info_text += "Name: %s\n" % current_captain.character_name
		info_text += "Combat: %d, Toughness: %d, Savvy: %d\n" % [
			current_captain.combat,
			current_captain.toughness,
			current_captain.savvy
		]
		info_text += "Tech: %d, Speed: %d, Luck: %d\n" % [
			current_captain.tech,
			current_captain.speed,
			current_captain.luck
		]
		info_text += "Health: %d/%d" % [
			current_captain.health,
			current_captain.max_health
		]

		if captain_info:
			captain_info.text = info_text
		if create_button:
			create_button.hide()
		if edit_button:
			edit_button.show()
		if randomize_button:
			randomize_button.hide()
	else:
		if captain_info:
			captain_info.text = "No captain created yet. Click 'Create Captain' to begin."
		if create_button:
			create_button.show()
		if edit_button:
			edit_button.hide()
		if randomize_button:
			randomize_button.show()

func get_captain_data() -> Character:
	return current_captain

func is_valid() -> bool:
	return current_captain != null

func validate() -> Array[String]:
	"""Validate captain data and return error messages"""
	var errors: Array[String] = []
	
	if current_captain == null:
		errors.append("Captain is required")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return {"captain": current_captain} if current_captain else {}

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("captain"):
		current_captain = data.captain
		_update_ui()
		captain_updated.emit(current_captain)

# Fallback methods when CharacterCreator is not available
func _create_basic_captain() -> void:
	"""Create a basic captain without the character creator dialog"""
	var captain = Character.new()
	captain.character_name = "Captain %s" % ["Steele", "Nova", "Cross", "Vale", "Storm"][randi() % 5]
	_generate_captain_stats(captain)
	current_captain = captain
	_update_ui()
	captain_updated.emit(current_captain)

func _create_random_captain() -> void:
	"""Create a random captain directly"""
	_create_basic_captain()

func _generate_captain_stats(captain: Character) -> void:
	"""Generate Five Parsecs captain stats"""
	# Captains get better stats (minimum 3 for combat stats)
	captain.combat = max(_roll_2d6(), 3)
	captain.toughness = max(_roll_2d6(), 3)
	captain.savvy = max(_roll_2d6(), 3)
	captain.tech = _roll_2d6()
	captain.speed = _roll_2d6()
	captain.luck = 2  # Captains start with 2 luck
	captain.max_health = captain.toughness + 3  # Captains get +1 extra health
	captain.health = captain.max_health

func _roll_2d6() -> int:
	"""Roll 2d6 for Five Parsecs stats"""
	return randi_range(1, 6) + randi_range(1, 6)