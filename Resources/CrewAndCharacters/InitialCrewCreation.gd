class_name InitialCrewCreation
extends Control

signal crew_created(crew: Array[Character])
signal creation_cancelled

const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const CharacterCreator = preload("res://Resources/CrewAndCharacters/CharacterCreator.gd")
const CrewManager = preload("res://Resources/CrewAndCharacters/CrewManager.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@onready var crew_columns := $MainContainer/LeftPanel/Panel/VBoxContainer/CharacterColumns
@onready var crew_preview := $MainContainer/RightPanel/Panel/MarginContainer/VBoxContainer/ScrollContainer/CrewPreview
@onready var confirm_button := $MainContainer/LeftPanel/Panel/VBoxContainer/ConfirmButton
@onready var title_label := $MainContainer/LeftPanel/Panel/TitleLabel

var character_creator: CharacterCreator
var crew_manager: CrewManager
var campaign_config: Dictionary
var crew_slots: Array[Node] = []
var current_crew: Array[Character] = []
var captain: Character

func _ready() -> void:
	character_creator = CharacterCreator.new()
	crew_manager = CrewManager.new()
	_setup_crew_creation()
	_connect_signals()

func initialize(config: Dictionary) -> void:
	campaign_config = config
	crew_manager.set_max_crew_size(config.crew_size)
	
	# Get captain from GameStateManager
	captain = GameStateManager.get_instance().game_state.captain
	if captain:
		current_crew.append(captain)
	
	_setup_crew_slots(config.crew_size)
	_update_preview()
	_update_captain_slot()

func _setup_crew_creation() -> void:
	_setup_crew_columns()
	_setup_crew_preview()
	_setup_buttons()

func _setup_crew_slots(crew_size: int) -> void:
	# Hide all slots first
	for column in crew_columns.get_children():
		for slot in column.get_children():
			slot.hide()
	
	# Show only the needed slots based on crew size
	var slot_count := 0
	for column in crew_columns.get_children():
		for slot in column.get_children():
			if slot_count < crew_size:
				slot.show()
				crew_slots.append(slot)
				slot_count += 1
			else:
				break

func _update_captain_slot() -> void:
	if captain and not crew_slots.is_empty():
		var captain_slot = crew_slots[0]
		_update_slot_display(captain_slot, captain)
		# Disable the captain slot since it can't be modified here
		captain_slot.disabled = true
		captain_slot.tooltip_text = "Captain already assigned"

func _setup_crew_columns() -> void:
	for column in crew_columns.get_children():
		for character_box in column.get_children():
				character_box.add_to_group("character_boxes")
				character_box.pressed.connect(_on_character_box_pressed.bind(character_box))

func _setup_crew_preview() -> void:
	crew_preview.initialize(current_crew)

func _setup_buttons() -> void:
	confirm_button.add_to_group("touch_buttons")
	confirm_button.pressed.connect(_on_confirm_pressed)

func _on_character_box_pressed(box: Button) -> void:
	var slot_index = crew_slots.find(box)
	if slot_index == -1 or (slot_index == 0 and captain):
		return
	
	# Create or edit character
	var character: Character
	if slot_index < current_crew.size():
		character = current_crew[slot_index]
		character_creator.edit_character(character)
	else:
		character = character_creator.create_character()
		if character:
			if slot_index >= current_crew.size():
				# Fill any gaps with null
				while current_crew.size() < slot_index:
					current_crew.append(null)
				current_crew.append(character)
			else:
				current_crew[slot_index] = character
			_update_preview()
			_update_slot_display(box, character)

func _update_slot_display(slot: Button, character: Character) -> void:
	var name_label = slot.get_node("HBoxContainer/VBoxContainer/Name")
	var origin_label = slot.get_node("HBoxContainer/VBoxContainer/Species")
	var class_label = slot.get_node("HBoxContainer/VBoxContainer/Class")
	
	if character:
		name_label.text = character.character_name
		origin_label.text = GlobalEnums.Origin.keys()[character.origin].capitalize()
		class_label.text = GlobalEnums.Class.keys()[character.class_type].capitalize()
		
		# Add visual indicator for captain
		if character == captain:
			name_label.text += " (Captain)"
			slot.modulate = Color(1.2, 1.2, 0.8)  # Slight gold tint for captain

func _update_preview() -> void:
	crew_preview.update_crew(current_crew)
	_validate_crew()

func _validate_crew() -> bool:
	# Ensure we have the minimum required crew members
	var valid_crew_count = 0
	for member in current_crew:
		if member != null:
			valid_crew_count += 1
	
	return valid_crew_count == campaign_config.crew_size

func _on_confirm_pressed() -> void:
	if _validate_crew():
		crew_created.emit(current_crew)
	else:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "You must create all %d crew members before continuing." % campaign_config.crew_size
		add_child(dialog)
		dialog.popup_centered()

func _on_cancel_pressed() -> void:
	creation_cancelled.emit()

func _connect_signals() -> void:
	if character_creator:
		character_creator.character_created.connect(_on_character_created)
		character_creator.character_edited.connect(_on_character_edited)
	
	if crew_preview:
		crew_preview.crew_member_selected.connect(_on_crew_member_selected)

func _on_character_created(character: Character) -> void:
	_update_preview()
	_update_title()

func _on_character_edited(character: Character) -> void:
	_update_preview()
	_update_title()

func _on_crew_member_selected(index: int) -> void:
	if index >= 0 and index < current_crew.size():
		var character = current_crew[index]
		if character and character != captain:
			character_creator.edit_character(character)

func _update_title() -> void:
	var valid_crew_count = 0
	for member in current_crew:
		if member != null:
			valid_crew_count += 1
			
	title_label.text = "Initial Crew Creation (%d/%d)" % [
		valid_crew_count,
		campaign_config.crew_size
	]
	
	# Update confirm button state
	confirm_button.disabled = valid_crew_count != campaign_config.crew_size
