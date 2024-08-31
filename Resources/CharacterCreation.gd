class_name CharacterCreation
extends Control

signal character_created(character: Character)

const MIN_STAT_VALUE: int = 0
const MAX_STAT_VALUE: int = 5
const STARTING_SKILL_POINTS: int = 3

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
	character = Character.new()
	_setup_option_buttons()
	_setup_stat_spinboxes()
	_setup_skill_checkboxes()
	_setup_equipment_list()
	create_character_button.pressed.connect(_on_create_character_pressed)
	character_name_input.text_changed.connect(_on_character_name_changed)

func _setup_option_buttons() -> void:
	_populate_option_button(race_selection, CharacterCreationData.Race.keys())
	_populate_option_button(background_selection, CharacterCreationData.Background.keys())
	_populate_option_button(motivation_selection, CharacterCreationData.Motivation.keys())
	_populate_option_button(class_selection, CharacterCreationData.Class.keys())

func _populate_option_button(option_button: OptionButton, options: Array[String]) -> void:
	for option in options:
		option_button.add_item(option)
	option_button.item_selected.connect(_on_option_selected.bind(option_button.name))

func _setup_stat_spinboxes() -> void:
	for stat in character.stats.keys():
		var spinbox: SpinBox = stat_distribution.get_node(stat.capitalize())
		assert(spinbox != null, "SpinBox not found for stat: " + stat)
		spinbox.value = character.stats[stat]
		spinbox.value_changed.connect(_on_stat_changed.bind(stat))

func _setup_skill_checkboxes() -> void:
	for skill in CharacterCreationData.SKILLS:
		var checkbox := CheckBox.new()
		checkbox.text = skill
		checkbox.toggled.connect(_on_skill_toggled.bind(skill))
		skill_selection.add_child(checkbox)

func _setup_equipment_list() -> void:
	for equipment in CharacterCreationData.EQUIPMENT:
		equipment_selection.add_item(equipment)
	equipment_selection.item_selected.connect(_on_equipment_selected)

func _on_option_selected(index: int, option_name: String) -> void:
	var selected_option: String = get_node("MarginContainer/VBoxContainer/HBoxContainer/LeftColumn/" + option_name).get_item_text(index)
	match option_name:
		"RaceSelection":
			character.race = CharacterCreationData.Race[selected_option]
		"BackgroundSelection":
			character.background = CharacterCreationData.Background[selected_option]
		"MotivationSelection":
			character.motivation = CharacterCreationData.Motivation[selected_option]
		"ClassSelection":
			character.character_class = CharacterCreationData.Class[selected_option]
	_apply_option_effects(option_name, selected_option)
	_update_character_summary()

func _apply_option_effects(option_name: String, selected_option: String) -> void:
	match option_name:
		"RaceSelection":
			var race_traits: Dictionary = CharacterCreationData.get_race_traits(CharacterCreationData.Race[selected_option])
			_apply_traits(race_traits)
		"BackgroundSelection":
			var background_stats: Dictionary = CharacterCreationData.get_background_stats(CharacterCreationData.Background[selected_option])
			_apply_stats(background_stats)
		"MotivationSelection":
			var motivation_stats: Dictionary = CharacterCreationData.get_motivation_stats(CharacterCreationData.Motivation[selected_option])
			_apply_stats(motivation_stats)
		"ClassSelection":
			var class_stats: Dictionary = CharacterCreationData.get_class_stats(CharacterCreationData.Class[selected_option])
			_apply_stats(class_stats)

func _apply_traits(traits: Dictionary) -> void:
	if "base_stats" in traits:
		for stat, value in traits["base_stats"].items():
			character.stats[stat] += value
			_update_stat_spinbox(stat)

func _apply_stats(stats: Dictionary) -> void:
	for stat, value in stats.items():
		if stat in character.stats:
			character.stats[stat] += value
			_update_stat_spinbox(stat)

func _update_stat_spinbox(stat: String) -> void:
	var spinbox: SpinBox = stat_distribution.get_node(stat.capitalize())
	assert(spinbox != null, "SpinBox not found for stat: " + stat)
	spinbox.value = character.stats[stat]

func _on_stat_changed(value: int, stat_name: String) -> void:
	character.stats[stat_name] = value
	_update_character_summary()

func _on_skill_toggled(button_pressed: bool, skill_name: String) -> void:
	if button_pressed:
		character.skills.append(skill_name)
	else:
		character.skills.erase(skill_name)
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
		   character.race != CharacterCreationData.Race.NONE and \
		   character.background != CharacterCreationData.Background.NONE and \
		   character.motivation != CharacterCreationData.Motivation.NONE and \
		   character.character_class != CharacterCreationData.Class.NONE and \
		   character.skills.size() > 0 and \
		   character.equipment.size() > 0

func _show_error_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	return character
