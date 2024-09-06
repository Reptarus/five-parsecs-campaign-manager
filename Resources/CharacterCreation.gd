extends Control

signal character_created(character: Character)

const MIN_STAT_VALUE: int = 0
const MAX_STAT_VALUE: int = 5
const STARTING_SKILL_POINTS: int = 3

var character_data: Dictionary
var equipment_data: Dictionary

@onready var race_selection: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/RaceSelection
@onready var background_selection: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/BackgroundSelection
@onready var motivation_selection: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/MotivationSelection
@onready var class_selection: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/ClassSelection
@onready var stat_distribution: Control = $MarginContainer/VBoxContainer/HBoxContainer/RightColumn/StatDistribution
@onready var skill_selection: Control = $MarginContainer/VBoxContainer/SkillSelection
@onready var equipment_selection: Control = $MarginContainer/VBoxContainer/EquipmentSelection
@onready var character_name_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/CharacterNameInput
@onready var character_summary: TextEdit = $MarginContainer/VBoxContainer/CharacterSummary
@onready var create_character_button: Button = $MarginContainer/VBoxContainer/CreateCharacterButton

var character: Character

func _ready() -> void:
	load_character_data()
	load_equipment_data()
	character = Character.new()
	_setup_option_buttons()
	_setup_stat_spinboxes()
	_setup_skill_checkboxes()
	_setup_equipment_list()
	create_character_button.pressed.connect(_on_create_character_pressed)
	character_name_input.text_changed.connect(_on_character_name_changed)

func load_character_data() -> void:
	var file = FileAccess.open("res://data/character_creation_data.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		character_data = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message())

func load_equipment_data() -> void:
	var file = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		equipment_data = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message())

func _setup_option_buttons() -> void:
	_populate_option_button(race_selection, character_data.races)
	_populate_option_button(background_selection, character_data.backgrounds)
	_populate_option_button(motivation_selection, character_data.motivations)
	_populate_option_button(class_selection, character_data.classes)

func _populate_option_button(option_button: OptionButton, data: Array) -> void:
	for item in data:
		option_button.add_item(item.name)
	option_button.item_selected.connect(_on_option_selected.bind(option_button.name))

func _setup_stat_spinboxes() -> void:
	for stat in character.stats.keys():
		var spinbox: SpinBox = stat_distribution.get_node(stat.capitalize())
		spinbox.value = character.stats[stat]
		spinbox.min_value = MIN_STAT_VALUE
		spinbox.max_value = MAX_STAT_VALUE
		spinbox.value_changed.connect(_on_stat_changed.bind(stat))

func _setup_skill_checkboxes() -> void:
	for skill in character_data.skills:
		var checkbox := CheckBox.new()
		checkbox.text = skill.name
		checkbox.toggled.connect(_on_skill_toggled.bind(skill.id))
		skill_selection.add_child(checkbox)

func _setup_equipment_list() -> void:
	for category in ["weapons", "armor", "gear", "consumables"]:
		for item in equipment_data[category]:
			equipment_selection.add_item(item.name)
	equipment_selection.item_selected.connect(_on_equipment_selected)

func _on_option_selected(index: int, option_name: String) -> void:
	var selected_option: String = get_node("MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/" + option_name).get_item_text(index)
	match option_name:
		"RaceSelection":
			character.race = character_data.races[index].id
		"BackgroundSelection":
			character.background = character_data.backgrounds[index].id
		"MotivationSelection":
			character.motivation = character_data.motivations[index].id
		"ClassSelection":
			character.character_class = character_data.classes[index].id
	_apply_option_effects(option_name, index)
	_update_character_summary()

func _apply_option_effects(option_name: String, index: int) -> void:
	match option_name:
		"RaceSelection":
			var race_data = character_data.races[index]
			for stat, value in race_data.base_stats.items():
				character.stats[stat] += value
		"BackgroundSelection":
			var background_data = character_data.backgrounds[index]
			for stat, value in background_data.stat_bonuses.items():
				character.stats[stat] += value
			character.credits += background_data.starting_credits
		"MotivationSelection":
			var motivation_data = character_data.motivations[index]
			if "starting_credits" in motivation_data.effect:
				character.credits += motivation_data.effect.starting_credits
			if "story_points" in motivation_data.effect:
				character.story_points += motivation_data.effect.story_points
		"ClassSelection":
			var class_data = character_data.classes[index]
			for stat, value in class_data.stat_bonuses.items():
				character.stats[stat] += value
	_update_stat_spinboxes()

func _update_stat_spinboxes() -> void:
	for stat in character.stats.keys():
		var spinbox: SpinBox = stat_distribution.get_node(stat.capitalize())
		spinbox.value = character.stats[stat]

func _on_stat_changed(value: int, stat_name: String) -> void:
	character.stats[stat_name] = value
	_update_character_summary()

func _on_skill_toggled(button_pressed: bool, skill_id: String) -> void:
	if button_pressed:
		character.skills.append(skill_id)
	else:
		character.skills.erase(skill_id)
	_update_character_summary()

func _on_equipment_selected(index: int) -> void:
	var selected_equipment: String = equipment_selection.get_item_text(index)
	if selected_equipment in character.equipment:
		character.equipment.erase(selected_equipment)
	else:
		character.equipment.append(selected_equipment)
	_update_character_summary()

func _on_character_name_changed(new_text: String) -> void:
	character.name = new_text
	_update_character_summary()

func _update_character_summary() -> void:
	var summary: String = """
	Name: {name}
	Race: {race}
	Background: {background}
	Motivation: {motivation}
	Class: {character_class}
	
	Stats:
	- Reactions: {stats.reactions}
	- Speed: {stats.speed}
	- Combat Skill: {stats.combat_skill}
	- Toughness: {stats.toughness}
	- Savvy: {stats.savvy}
	
	Skills: {skills}
	
	Equipment: {equipment}
	""".format(character.to_dict())
	
	character_summary.text = summary

func _on_create_character_pressed() -> void:
	if _validate_character():
		character_created.emit(character)
	else:
		_show_error_message("Please fill in all required fields and make valid selections.")

func _validate_character() -> bool:
	return character.name != "" and \
		   character.race != "" and \
		   character.background != "" and \
		   character.motivation != "" and \
		   character.character_class != "" and \
		   character.skills.size() > 0 and \
		   character.equipment.size() > 0

func _show_error_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func get_race_name(race_id: String) -> String:
	for race in character_data.races:
		if race.id == race_id:
			return race.name
	return "Unknown Race"

func get_background_name(background_id: String) -> String:
	for background in character_data.backgrounds:
		if background.id == background_id:
			return background.name
	return "Unknown Background"

func get_motivation_name(motivation_id: String) -> String:
	for motivation in character_data.motivations:
		if motivation.id == motivation_id:
			return motivation.name
	return "Unknown Motivation"

func get_class_name(class_id: String) -> String:
	for character_class in character_data.classes:
		if character_class.id == class_id:
			return character_class.name
	return "Unknown Class"

func get_skill_names(skill_ids: Array) -> Array:
	var skill_names = []
	for skill in character_data.skills:
		if skill.id in skill_ids:
			skill_names.append(skill.name)
	return skill_names

func get_equipment_names(equipment_ids: Array) -> Array:
	var equipment_names = []
	for category in ["weapons", "armor", "gear", "consumables"]:
		for item in equipment_data[category]:
			if item.id in equipment_ids:
				equipment_names.append(item.name)
	return equipment_names
