extends Control

@onready var name_label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var stats_display = $Panel/MarginContainer/VBoxContainer/StatsDisplay
@onready var traits_display = $Panel/MarginContainer/VBoxContainer/TraitsDisplay
@onready var equipment_list = $Panel/MarginContainer/VBoxContainer/EquipmentList
@onready var xp_label = $Panel/MarginContainer/VBoxContainer/XPLabel
@onready var medbay_status = $Panel/MarginContainer/VBoxContainer/MedbayStatus
@onready var background_label = $Panel/MarginContainer/VBoxContainer/BackgroundLabel
@onready var class_label = $Panel/MarginContainer/VBoxContainer/ClassLabel
@onready var motivation_label = $Panel/MarginContainer/VBoxContainer/MotivationLabel

var character: Character

func set_character(new_character: Character):
	character = new_character
	update_display()

func update_display():
	name_label.text = character.name
	stats_display.text = """
	Reactions: %d
	Speed: %d
	Combat Skill: %d
	Toughness: %d
	Savvy: %d
	Luck: %d
	""" % [
		character.reactions,
		character.speed,
		character.combat_skill,
		character.toughness,
		character.savvy,
		character.luck
	]
	
	xp_label.text = "XP: %d" % character.xp
	
	traits_display.text = "Traits: " + ", ".join(character.traits)
	
	equipment_list.clear()
	if character.equipped_weapon:
		equipment_list.add_item("Weapon: " + character.equipped_weapon.name)
	for item in character.equipped_items:
		equipment_list.add_item(item.name)
	
	medbay_status.text = "In Medbay: %s (%d turns left)" % ["Yes" if character.is_in_medbay() else "No", character.medbay_turns_left]
	
	background_label.text = "Background: " + character.background
	class_label.text = "Class: " + character.character_class
	motivation_label.text = "Motivation: " + character.motivation

func _on_close_button_pressed():
	queue_free()
