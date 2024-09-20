extends Button

# Add this line at the top of the script
const Character = preload("res://Scripts/Characters/Character.gd")

@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var species_label = $MarginContainer/VBoxContainer/SpeciesLabel
@onready var background_label = $MarginContainer/VBoxContainer/BackgroundLabel
@onready var class_label = $MarginContainer/VBoxContainer/ClassLabel
@onready var motivation_label = $MarginContainer/VBoxContainer/MotivationLabel
@onready var health_status = $MarginContainer/VBoxContainer/HealthStatus
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
	motivation_label.text = character.motivation
	health_status.text = "Health: " + character.health_status
	
	equipment_list.clear()
	for item in character.equipped_items:
		equipment_list.add_item(item.name)

func _ready():
	if character:
		update_display()