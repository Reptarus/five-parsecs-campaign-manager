extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal resources_updated(resources: Dictionary)

@onready var credits_label: Label = $"Content/Resources/Credits/Value"
@onready var story_points_label: Label = $"Content/Resources/StoryPoints/Value"
@onready var patrons_label: Label = $"Content/Resources/Patrons/Value"
@onready var rivals_label: Label = $"Content/Resources/Rivals/Value"
@onready var quest_rumors_label: Label = $"Content/Resources/QuestRumors/Value"
@onready var calculate_button: Button = $"Content/Controls/CalculateButton"

var current_resources: Dictionary = {
	"credits": 0,
	"story_points": 1, # Default starting story point
	"patrons": 0,
	"rivals": 0,
	"quest_rumors": 0,
	"equipment_rolls": {
		"military_weapons": 3,
		"low_tech_weapons": 3,
		"gear": 1,
		"gadgets": 1
	}
}

var crew_data: Array = []

func _ready() -> void:
	_connect_signals()
	_update_ui()

func _connect_signals() -> void:
	if calculate_button:
		calculate_button.pressed.connect(_on_calculate_pressed)

func set_crew_data(crew: Array) -> void:
	"""Set crew data to calculate starting resources"""
	crew_data = crew
	_calculate_starting_resources()

func _on_calculate_pressed() -> void:
	"""Manually recalculate resources based on crew"""
	_calculate_starting_resources()

func _calculate_starting_resources() -> void:
	"""Calculate starting resources based on Five Parsecs core rules"""
	# Reset resources
	current_resources.credits = crew_data.size() # 1 credit per crew member base
	current_resources.story_points = 1 # Default starting story point
	current_resources.patrons = 0
	current_resources.rivals = 0
	current_resources.quest_rumors = 0
	
	# Process each crew member's background bonuses
	for character in crew_data:
		_apply_background_bonuses(character)
		_apply_motivation_bonuses(character)
		_apply_class_bonuses(character)
	
	_update_ui()
	resources_updated.emit(current_resources)

func _apply_background_bonuses(character) -> void:
	"""Apply bonuses from character background (Core Rules pp. 1520-1733)"""
	if not character.has("background"):
		return
	
	match character.background:
		GameEnums.Background.MILITARY:
			# Peaceful, High-Tech Colony: +1D6 credits
			current_resources.credits += randi_range(1, 6)
		GameEnums.Background.ACADEMIC:
			# Space Station: +1 Gear roll (equipment)
			# Already included in base equipment rolls
			pass
		GameEnums.Background.TRADER:
			# Trader class: +2D6 credits
			current_resources.credits += randi_range(2, 12)
		GameEnums.Background.CRIMINAL:
			# Ganger: +1 Low-tech Weapon
			# Equipment handled separately
			pass
		GameEnums.Background.NOBLE:
			# Negotiator: Patron + 1 story point
			current_resources.patrons += 1
			current_resources.story_points += 1

func _apply_motivation_bonuses(character) -> void:
	"""Apply bonuses from character motivation"""
	if not character.has("motivation"):
		return
	
	match character.motivation:
		GameEnums.Motivation.WEALTH:
			# Wealth: +1D6 credits
			current_resources.credits += randi_range(1, 6)
		GameEnums.Motivation.POWER:
			# Power: +2 XP and Rival
			current_resources.rivals += 1
		GameEnums.Motivation.KNOWLEDGE:
			# Fame: +1 story point
			current_resources.story_points += 1
		GameEnums.Motivation.REVENGE:
			# Often comes with Rival
			current_resources.rivals += 1

func _apply_class_bonuses(character) -> void:
	"""Apply bonuses from character class"""
	if not character.has("character_class"):
		return
	
	match character.character_class:
		GameEnums.CharacterClass.MERCHANT:
			# Trader: +2D6 credits
			current_resources.credits += randi_range(2, 12)
		GameEnums.CharacterClass.SECURITY:
			# Often comes with patron connections
			if randf() < 0.3: # 30% chance
				current_resources.patrons += 1

func set_resources(resources: Dictionary) -> void:
	current_resources = resources.duplicate()
	_update_ui()
	resources_updated.emit(current_resources)

func _update_ui() -> void:
	if credits_label:
		credits_label.text = str(current_resources.credits)
	if story_points_label:
		story_points_label.text = str(current_resources.story_points)
	if patrons_label:
		patrons_label.text = str(current_resources.patrons)
	if rivals_label:
		rivals_label.text = str(current_resources.rivals)
	if quest_rumors_label:
		quest_rumors_label.text = str(current_resources.quest_rumors)

func get_resources() -> Dictionary:
	return current_resources.duplicate()

func is_valid() -> bool:
	return current_resources.credits >= 0 # Must have non-negative credits