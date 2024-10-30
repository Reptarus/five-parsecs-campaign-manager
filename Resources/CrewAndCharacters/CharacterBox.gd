extends PanelContainer

@onready var portrait = $MarginContainer/HBoxContainer/Portrait
@onready var info_container = $MarginContainer/HBoxContainer/VBoxContainer
@onready var name_label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var species_label = $MarginContainer/HBoxContainer/VBoxContainer/SpeciesLabel
@onready var class_label = $MarginContainer/HBoxContainer/VBoxContainer/ClassLabel
@onready var health_bar = $MarginContainer/HBoxContainer/VBoxContainer/HealthBar

func setup(character_data: Dictionary) -> void:
	name_label.text = "NAME: " + character_data.name
	species_label.text = "SPECIES: " + character_data.species
	class_label.text = "CLASS: " + character_data.character_class
	health_bar.value = character_data.health
	if character_data.portrait:
		portrait.texture = character_data.portrait
