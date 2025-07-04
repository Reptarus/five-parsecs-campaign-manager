extends Control

## Five Parsecs Campaign Creation Crew Panel
## Enhanced with FiveParsecsCharacterGeneration integration

# Safe imports using Universal Safety System
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal crew_updated(crew: Array)

@onready var crew_size_option: OptionButton = $"Content/CrewSize/OptionButton"
@onready var crew_list: ItemList = $"Content/CrewList/ItemList"
@onready var character_creator: Node = $"CharacterCreator"

var crew_members: Array[Character] = []
var selected_size: int = 4

func _ready() -> void:
	_setup_crew_size_options()
	_connect_signals()
	_update_crew_list()

func _setup_crew_size_options() -> void:
	crew_size_option.clear()
	
	crew_size_option.add_item("4 Members (Small Crew)", 4)
	crew_size_option.add_item("5 Members (Medium Crew)", 5)
	crew_size_option.add_item("6 Members (Large Crew)", 6)
	
	crew_size_option.select(2) # Default to 6 members (Large Crew)
	selected_size = 6

func _connect_signals() -> void:
	crew_size_option.item_selected.connect(_on_crew_size_selected)
	$Content/Controls/AddButton.pressed.connect(_on_add_member_pressed)
	$Content/Controls/EditButton.pressed.connect(_on_edit_member_pressed)
	$Content/Controls/RemoveButton.pressed.connect(_on_remove_member_pressed)
	$Content/Controls/RandomizeButton.pressed.connect(_on_randomize_pressed)
	
	# Connect character creator signals only if available
	if character_creator and character_creator.has_signal("character_created"):
		character_creator.character_created.connect(_on_character_created)
	if character_creator and character_creator.has_signal("character_edited"):
		character_creator.character_edited.connect(_on_character_edited)
	
	if crew_list:
		crew_list.item_selected.connect(_on_crew_member_selected)

func _on_crew_size_selected(index: int) -> void:
	selected_size = crew_size_option.get_item_id(index)
	_update_crew_list()
	crew_updated.emit(crew_members) # warning: return value discarded (intentional)

func _on_add_member_pressed() -> void:
	if crew_members.size() >= selected_size:
		return
	
	if character_creator and character_creator.has_method("start_creation"):
		character_creator.start_creation()
		character_creator.show()
	else:
		# Use Five Parsecs character generation for compliance
		_create_five_parsecs_character()
		_update_crew_list()
		UniversalSignalManager.emit_signal_safe(
			self,
			"crew_updated",
			[crew_members],
			"CrewPanel add character"
		)

func _on_edit_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		character_creator.edit_character(crew_members[index])
		character_creator.show()

func _on_remove_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		crew_members.remove_at(index)
		_update_crew_list()
		crew_updated.emit(crew_members) # warning: return value discarded (intentional)

func _on_randomize_pressed() -> void:
	crew_members.clear()
	
	for i in range(selected_size):
		_create_five_parsecs_character()
	
	_update_crew_list()
	UniversalSignalManager.emit_signal_safe(
		self,
		"crew_updated",
		[crew_members],
		"CrewPanel randomize crew generation"
	)

func _on_character_created(character: Character) -> void:
	if crew_members.size() < selected_size:
		crew_members.append(character) # warning: return value discarded (intentional)
		_update_crew_list()
		crew_updated.emit(crew_members) # warning: return value discarded (intentional)

func _on_character_edited(character: Character) -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		crew_members[index] = character
		_update_crew_list()
		crew_updated.emit(crew_members) # warning: return value discarded (intentional)

func _on_crew_member_selected(index: int) -> void:
	$Content/Controls/EditButton.disabled = false
	$Content/Controls/RemoveButton.disabled = false

func _update_crew_list() -> void:
	crew_list.clear()
	
	for i in range(crew_members.size()):
		var character = crew_members[i]
		# Safe display with bounds checking
		var name = character.character_name if character.character_name else "Unnamed"
		var char_class = "Unknown Class"
		var char_origin = "Unknown Origin"
		var char_background = "Unknown Background"
		
		# Safe enum access with bounds checking
		if character.character_class >= 0 and character.character_class < GameEnums.CharacterClass.size():
			char_class = GameEnums.CharacterClass.keys()[character.character_class]
		
		if character.origin >= 0 and character.origin < GameEnums.Origin.size():
			char_origin = GameEnums.Origin.keys()[character.origin]
		
		if character.background >= 0 and character.background < GameEnums.Background.size():
			char_background = GameEnums.Background.keys()[character.background]
		
		# Enhanced display with crew member number, origin, class, and background
		var text: String = "%d. %s (%s %s) - %s" % [i + 1, name, char_origin, char_class, char_background]
		crew_list.add_item(text)
	
	# Update controls state
	$Content/Controls/AddButton.disabled = crew_members.size() >= selected_size
	$Content/Controls/EditButton.disabled = true
	$Content/Controls/RemoveButton.disabled = true

func get_crew_data() -> Array:
	return crew_members.duplicate()

func is_valid() -> bool:
	return crew_members.size() == selected_size

func _create_five_parsecs_character() -> void:
	"""Create a character using official Five Parsecs generation system"""
	# Use the sophisticated FiveParsecsCharacterGeneration system
	var character = FiveParsecsCharacterGeneration.generate_random_character()
	
	if character:
		crew_members.append(character)
		print("CrewPanel: Generated Five Parsecs character: ", character.character_name)
	else:
		# Fallback to manual creation if needed
		_create_manual_character()

func _create_manual_character() -> void:
	"""Fallback manual character creation following Five Parsecs crew generation rules"""
	var character = Character.new()
	
	# Step 1: Roll for crew type (Core Rules p.764)
	var crew_type_roll = randi_range(1, 100)
	var character_origin: GameEnums.Origin
	
	if crew_type_roll <= 60:
		# Baseline Human
		character_origin = GameEnums.Origin.HUMAN
	elif crew_type_roll <= 80:
		# Primary Alien - roll on subtable
		var alien_roll = randi_range(1, 100)
		if alien_roll <= 20:
			character_origin = GameEnums.Origin.ENGINEER
		elif alien_roll <= 40:
			character_origin = GameEnums.Origin.KERIN
		elif alien_roll <= 55:
			character_origin = GameEnums.Origin.SOULLESS
		elif alien_roll <= 70:
			character_origin = GameEnums.Origin.PRECURSOR
		elif alien_roll <= 90:
			character_origin = GameEnums.Origin.FERAL
		else:
			character_origin = GameEnums.Origin.SWIFT
	elif crew_type_roll <= 90:
		# Bot
		character_origin = GameEnums.Origin.BOT
	else:
		# Strange Character (for now, treat as human with special background)
		character_origin = GameEnums.Origin.HUMAN
	
	# Set character properties according to origin
	character.origin = character_origin
	character.character_name = _generate_name_for_origin(character_origin) + " " + str(crew_members.size() + 1)
	
	# Roll for Background, Motivation, and Class if Human or Strange Character
	if character_origin == GameEnums.Origin.HUMAN:
		character.background = randi_range(1, GameEnums.Background.size() - 1)
		character.motivation = randi_range(1, GameEnums.Motivation.size() - 1)
		character.character_class = randi_range(1, GameEnums.CharacterClass.size() - 1)
	else:
		# Aliens get appropriate defaults
		character.background = GameEnums.Background.COLONIST
		character.motivation = GameEnums.Motivation.SURVIVAL
		character.character_class = _get_class_for_origin(character_origin)
	
	crew_members.append(character)
	_update_crew_list()
	UniversalSignalManager.emit_signal_safe(
		self,
		"crew_updated",
		[crew_members],
		"CrewPanel manual character creation"
	)

func _generate_name_for_origin(origin: GameEnums.Origin) -> String:
	"""Generate appropriate names for different character origins"""
	match origin:
		GameEnums.Origin.HUMAN:
			var human_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake"]
			return human_names[randi() % human_names.size()]
		GameEnums.Origin.ENGINEER:
			var engineer_names = ["Zyx-7", "Klet-Prime", "Vel-9", "Nix-Alpha", "Qor-Beta"]
			return engineer_names[randi() % engineer_names.size()]
		GameEnums.Origin.KERIN:
			var kerin_names = ["Thrakk", "Gorvak", "Zarneth", "Kromax", "Balthon"]
			return kerin_names[randi() % kerin_names.size()]
		GameEnums.Origin.SOULLESS:
			var soulless_names = ["Unit-47", "Nexus-12", "Prime-3", "Node-89", "Link-156"]
			return soulless_names[randi() % soulless_names.size()]
		GameEnums.Origin.PRECURSOR:
			var precursor_names = ["Ethereal-One", "Ancient-Sage", "Star-Walker", "Void-Singer", "Time-Keeper"]
			return precursor_names[randi() % precursor_names.size()]
		GameEnums.Origin.FERAL:
			var feral_names = ["Claw", "Fang", "Shadow", "Hunter", "Prowler", "Stalker", "Swift-Paw"]
			return feral_names[randi() % feral_names.size()]
		GameEnums.Origin.SWIFT:
			var swift_names = ["Chirp-Quick", "Dash-Wing", "Fleet-Scale", "Rapid-Tail", "Quick-Dart"]
			return swift_names[randi() % swift_names.size()]
		GameEnums.Origin.BOT:
			var bot_names = ["Bot-" + str(randi_range(100, 999)), "Droid-" + str(randi_range(10, 99)), "Mech-" + str(randi_range(1, 50))]
			return bot_names[randi() % bot_names.size()]
		_:
			return "Crew"

func _get_class_for_origin(origin: GameEnums.Origin) -> GameEnums.CharacterClass:
	"""Get appropriate class for character origin"""
	match origin:
		GameEnums.Origin.ENGINEER:
			return GameEnums.CharacterClass.ENGINEER
		GameEnums.Origin.KERIN:
			return GameEnums.CharacterClass.SOLDIER
		GameEnums.Origin.SOULLESS:
			return GameEnums.CharacterClass.SECURITY
		GameEnums.Origin.PRECURSOR:
			return GameEnums.CharacterClass.PILOT
		GameEnums.Origin.FERAL:
			return GameEnums.CharacterClass.SECURITY
		GameEnums.Origin.SWIFT:
			return GameEnums.CharacterClass.PILOT
		GameEnums.Origin.BOT:
			return GameEnums.CharacterClass.BOT_TECH
		_:
			return GameEnums.CharacterClass.SOLDIER
