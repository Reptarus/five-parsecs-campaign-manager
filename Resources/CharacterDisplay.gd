class_name CharacterDisplay
extends Control

@export var character: Character

@onready var name_label: Label = $NameLabel
@onready var stats_container: VBoxContainer = $StatsContainer
@onready var inventory_list: ItemList = $InventoryList
@onready var traits_label: Label = $TraitsLabel

func _ready() -> void:
	if character:
		update_display()

func set_character(new_character: Character) -> void:
	character = new_character
	update_display()

func update_display() -> void:
	name_label.text = character.name
	update_stats()
	update_inventory()
	update_traits()

func update_stats() -> void:
	for stat in ["reactions", "speed", "combat_skill", "toughness", "savvy"]:
		var label: Label = stats_container.get_node(stat.capitalize() + "Label")
		if label:
			label.text = "%s: %d" % [stat.capitalize(), character.get(stat)]

func update_inventory() -> void:
	inventory_list.clear()
	for item in character.get_all_items():
		inventory_list.add_item(item.name)

func update_traits() -> void:
	traits_label.text = "Traits: " + ", ".join(character.traits)

func show_detailed_view() -> void:
	# Implement logic to show full character sheet
	pass

func show_preview() -> void:
	# Implement logic to show character preview
	pass