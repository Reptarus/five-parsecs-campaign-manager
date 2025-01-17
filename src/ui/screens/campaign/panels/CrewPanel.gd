extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal crew_updated(crew: Array)

@onready var crew_size_option = $Content/CrewSize/OptionButton
@onready var crew_list = $Content/CrewList/ItemList
@onready var character_creator = $CharacterCreator

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
	
	crew_size_option.select(0) # Default to 4 members

func _connect_signals() -> void:
	crew_size_option.item_selected.connect(_on_crew_size_selected)
	$Content/Controls/AddButton.pressed.connect(_on_add_member_pressed)
	$Content/Controls/EditButton.pressed.connect(_on_edit_member_pressed)
	$Content/Controls/RemoveButton.pressed.connect(_on_remove_member_pressed)
	$Content/Controls/RandomizeButton.pressed.connect(_on_randomize_pressed)
	
	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)
	
	crew_list.item_selected.connect(_on_crew_member_selected)

func _on_crew_size_selected(index: int) -> void:
	selected_size = crew_size_option.get_item_id(index)
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	if crew_members.size() >= selected_size:
		return
	
	character_creator.start_creation()
	character_creator.show()

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
		crew_updated.emit(crew_members)

func _on_randomize_pressed() -> void:
	crew_members.clear()
	
	for i in range(selected_size):
		var character = Character.new()
		character_creator._on_randomize_pressed() # Use existing randomization logic
		crew_members.append(character)
	
	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_character_created(character: Character) -> void:
	if crew_members.size() < selected_size:
		crew_members.append(character)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_character_edited(character: Character) -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	if index >= 0 and index < crew_members.size():
		crew_members[index] = character
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_crew_member_selected(index: int) -> void:
	$Content/Controls/EditButton.disabled = false
	$Content/Controls/RemoveButton.disabled = false

func _update_crew_list() -> void:
	crew_list.clear()
	
	for character in crew_members:
		var text = "%s - %s (%s)" % [
			character.character_name,
			GameEnums.CharacterClass.keys()[character.character_class],
			GameEnums.Origin.keys()[character.origin]
		]
		crew_list.add_item(text)
	
	# Update controls state
	$Content/Controls/AddButton.disabled = crew_members.size() >= selected_size
	$Content/Controls/EditButton.disabled = true
	$Content/Controls/RemoveButton.disabled = true

func get_crew_data() -> Array:
	return crew_members.duplicate()

func is_valid() -> bool:
	return crew_members.size() == selected_size