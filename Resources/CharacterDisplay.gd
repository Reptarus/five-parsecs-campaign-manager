class_name CharacterDisplay
extends Control

signal character_updated(character: Character)

@export var character: Character

@onready var name_label: Label = $NameLabel
@onready var stats_container: VBoxContainer = $StatsContainer
@onready var inventory_list: ItemList = $InventoryList
@onready var traits_label: Label = $TraitsLabel
@onready var species_label: Label = $SpeciesLabel
@onready var background_label: Label = $BackgroundLabel
@onready var motivation_label: Label = $MotivationLabel
@onready var class_label: Label = $ClassLabel

func _ready() -> void:
	if character:
		update_display()

func set_character(new_character: Character) -> void:
	character = new_character
	update_display()
	character_updated.emit(character)

func update_display() -> void:
	if not character:
		return
	
	name_label.text = character.name
	species_label.text = "Species: " + GlobalEnums.Species.keys()[character.species]
	background_label.text = "Background: " + GlobalEnums.Background.keys()[character.background]
	motivation_label.text = "Motivation: " + GlobalEnums.Motivation.keys()[character.motivation]
	class_label.text = "Class: " + GlobalEnums.Class.keys()[character.character_class]
	update_stats()
	update_inventory()
	update_traits()

func update_stats() -> void:
	for stat in GlobalEnums.SkillType.keys():
		var label: Label = stats_container.get_node(stat.capitalize() + "Label")
		if label:
			label.text = "%s: %d" % [stat.capitalize(), character.get_skill(GlobalEnums.SkillType[stat])]

func update_inventory() -> void:
	inventory_list.clear()
	for item in character.get_all_items():
		inventory_list.add_item(item.name, null, false)

func update_traits() -> void:
	traits_label.text = "Traits: " + ", ".join(character.traits)

func show_detailed_view() -> void:
	var detailed_view_scene = load("res://Scenes/Management/CharacterDetailedView.tscn")
	var detailed_view = detailed_view_scene.instantiate()
	detailed_view.set_character(character)
	add_child(detailed_view)

func show_preview() -> void:
	var preview_scene = load("res://Scenes/Management/CharacterPreview.tscn")
	var preview = preview_scene.instantiate()
	preview.set_character(character)
	add_child(preview)