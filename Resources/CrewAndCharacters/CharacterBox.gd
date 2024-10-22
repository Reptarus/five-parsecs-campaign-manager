extends Button

@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var species_label = $MarginContainer/VBoxContainer/SpeciesLabel
@onready var background_label = $MarginContainer/VBoxContainer/BackgroundLabel
@onready var class_label = $MarginContainer/VBoxContainer/ClassLabel
@onready var motivation_label = $MarginContainer/VBoxContainer/MotivationLabel
@onready var health_status = $MarginContainer/VBoxContainer/HealthStatus
@onready var equipment_list = $MarginContainer/VBoxContainer/EquipmentList

var character: Character

signal edit_character(character: Character)
signal remove_character(character: Character)

func set_character(new_character: Character) -> void:
	character = new_character
	update_display()

func update_display() -> void:
	if character:
		name_label.text = character.name
		species_label.text = GlobalEnums.Species.keys()[character.species]
		background_label.text = GlobalEnums.Background.keys()[character.background]
		class_label.text = GlobalEnums.Class.keys()[character.character_class]
		motivation_label.text = GlobalEnums.Motivation.keys()[character.motivation]
		health_status.text = "Health: " + GlobalEnums.CharacterStatus.keys()[character.health_status]
		
		equipment_list.clear()
		for item in character.equipped_items:
			equipment_list.add_item(item.name)
	else:
		set_empty()

func set_empty() -> void:
	name_label.text = "Empty Slot"
	species_label.text = ""
	background_label.text = ""
	class_label.text = ""
	motivation_label.text = ""
	health_status.text = ""
	equipment_list.clear()

func _ready() -> void:
	if character:
		update_display()
	else:
		set_empty()
	$MarginContainer/VBoxContainer/EditButton.pressed.connect(_on_edit_button_pressed)
	$MarginContainer/VBoxContainer/RemoveButton.pressed.connect(_on_remove_button_pressed)

func _on_edit_button_pressed() -> void:
	edit_character.emit(character)

func _on_remove_button_pressed() -> void:
	remove_character.emit(character)

func _on_pressed() -> void:
	if character:
		edit_character.emit(character)
	else:
		# Start the process of creating a new character
		var character_creator = preload("res://Resources/CampaignManagement/Scenes/CharacterCreator.tscn").instantiate()
		character_creator.connect("character_created", _on_character_created)
		get_tree().root.add_child(character_creator)

func _on_character_created(new_character: Character) -> void:
	set_character(new_character)
	get_parent().get_parent().update_crew_display()
