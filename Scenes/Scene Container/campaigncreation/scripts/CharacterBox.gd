extends Button

@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var species_label = $MarginContainer/VBoxContainer/SpeciesLabel
@onready var background_label = $MarginContainer/VBoxContainer/BackgroundLabel
@onready var class_label = $MarginContainer/VBoxContainer/ClassLabel
@onready var equipment_list = $MarginContainer/VBoxContainer/EquipmentList

var character: Character

func set_character(new_character: Character):
	character = new_character
	update_display()

func update_display():
	name_label.text = character.name
	species_label.text = character.species
	background_label.text = character.background
	class_label.text = character.character_class
	
	equipment_list.clear()
	for item in character.equipped_items:
		equipment_list.add_item(item.name)

func _ready():
	if character:
		update_display()