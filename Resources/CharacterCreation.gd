# CharacterCreation.gd
extends Control

const CharacterCreationData = preload("res://Scripts/Characters/CharacterCreationData.gd")
const Character = preload("res://Scripts/Characters/Character.gd")

@onready var species_option_button: OptionButton = $CrewStatsAndInfo/SpeciesSelection/SpeciesSelection
@onready var background_option: OptionButton = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/BackgroundSelection
@onready var motivation_option: OptionButton = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/MotivationSelection
@onready var class_option: OptionButton = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/ClassSelection
@onready var name_input: LineEdit = $CrewStatsAndInfo/NameEntry/NameInput
@onready var portrait: TextureRect = $CrewPictureAndStats/PictureandBMCcontrols/CharacterPortrait
@onready var info_box: RichTextLabel = $CrewPictureAndStats/CharacterFlavorBreakdown/SpeciesInfoLabel
@onready var stat_spinboxes: Dictionary = {
	"reactions": $CrewStatsAndInfo/StatDistribution/Reactions/ReactionsSpinBox,
	"speed": $CrewStatsAndInfo/StatDistribution/Speed/SpeedSpinBox,
	"combat_skill": $CrewStatsAndInfo/StatDistribution/Combat/CombatSpinBox,
	"toughness": $CrewStatsAndInfo/StatDistribution/Toughness/ToughnessSpinBox,
	"savvy": $CrewStatsAndInfo/StatDistribution/Savvy/SavvySpinBox,
	"luck": $CrewStatsAndInfo/StatDistribution/Luck/LuckSpinBox
}
@onready var species_option: OptionButton = $CrewStatsAndInfo/SpeciesSelection/SpeciesSelection
@onready var weapon_option: OptionButton = $CrewStatsAndInfo/StartingWeaponsAndGear/WeaponOption
@onready var armor_option: OptionButton = $CrewStatsAndInfo/StartingWeaponsAndGear/ArmorOption
@onready var gear_option: OptionButton = $CrewStatsAndInfo/StartingWeaponsAndGear/GearOption


var equipment_manager: EquipmentManager
var current_character: Character
var character_data: Dictionary

func _ready():
	equipment_manager = EquipmentManager.new()
	load_character_data()
	populate_option_buttons()
	connect_signals()
	update_character_info()

func _populate_option_buttons() -> void:
	for race in creation_data.races:
		species_option_button.add_item(race.name)
	for background in creation_data.backgrounds:
		background_option.add_item(background.name)
	for motivation in creation_data.motivations:
		motivation_option.add_item(motivation.name)
	for character_class in creation_data.classes:
		class_option.add_item(character_class.name)

func _connect_signals() -> void:
	species_option_button.item_selected.connect(_on_species_selected)
	background_option.item_selected.connect(_on_background_selected)
	motivation_option.item_selected.connect(_on_motivation_selected)
	class_option.item_selected.connect(_on_class_selected)
	name_input.text_changed.connect(_on_name_changed)
	for spinbox in stat_spinboxes.values():
		spinbox.value_changed.connect(_on_stat_changed)

func update_character_info():
	var selected_race = character_data.races[species_option.get_selected_id()]
	var selected_background = character_data.backgrounds[background_option.get_selected_id()]
	var selected_motivation = character_data.motivations[motivation_option.get_selected_id()]
	var selected_class = character_data.classes[class_option.get_selected_id()]

	update_stats(selected_race)
	generate_equipment(selected_background, selected_motivation, selected_class)
	update_info_box(selected_race, selected_background, selected_motivation, selected_class)

func generate_equipment(background, motivation, class_type):
	var generated_equipment = {
		"background": equipment_manager.generate_equipment_from_background(background),
		"motivation": equipment_manager.generate_equipment_from_motivation(motivation),
		"class": equipment_manager.generate_equipment_from_class(class_type)
	}
	update_equipment_display(generated_equipment)

func update_equipment_display(generated_equipment):
	var equipment_text = ""
	for trait in generated_equipment.keys():
		equipment_text += "\n" + trait.capitalize() + " Equipment:\n"
		for item in generated_equipment[trait]:
			equipment_text += "- " + item.name + "\n"
			add_equipment_to_options(item)
	info_box.text += equipment_text

func _generate_random_character() -> void:
	current_character = Character.new()
	current_character.generate_random()
	_update_ui()

func add_equipment_to_options(item: Equipment):
	match item.type:
		Equipment.Type.WEAPON:
			weapon_option.add_item(item.name)
		Equipment.Type.ARMOR:
			armor_option.add_item(item.name)
		Equipment.Type.GEAR:
			gear_option.add_item(item.name)

func _update_ui() -> void:
	name_input.text = current_character.name
	species_option_button.selected = current_character.race
	background_option.selected = current_character.background
	motivation_option.selected = current_character.motivation
	class_option.selected = current_character.character_class
	portrait.texture = load(current_character.portrait)
	_update_info_box()
	_update_stats()

func _update_info_box() -> void:
	var info_text = """
	Species: {race}
	{race_description}
	
	Background: {background}
	{background_description}
	
	Motivation: {motivation}
	{motivation_description}
	
	Class: {class}
	{class_description}
	""".format({
		"race": creation_data.races[current_character.race].name,
		"race_description": creation_data.races[current_character.race].description,
		"background": creation_data.backgrounds[current_character.background].name,
		"background_description": creation_data.backgrounds[current_character.background].description,
		"motivation": creation_data.motivations[current_character.motivation].name,
		"motivation_description": creation_data.motivations[current_character.motivation].description,
		"class": creation_data.classes[current_character.character_class].name,
		"class_description": creation_data.classes[current_character.character_class].description
	})
	info_box.text = info_text

func _update_stats() -> void:
	for stat in stat_spinboxes:
		stat_spinboxes[stat].value = current_character.stats[stat]

func _on_species_selected(index: int) -> void:
	current_character.race = index
	_apply_race_modifiers()
	_update_ui()

func _on_background_selected(index: int) -> void:
	current_character.background = index
	_apply_background_modifiers()
	_update_ui()

func _on_motivation_selected(index: int) -> void:
	current_character.motivation = index
	_apply_motivation_modifiers()
	_update_ui()

func _on_class_selected(index: int) -> void:
	current_character.character_class = index
	_apply_class_modifiers()
	_update_ui()

func _on_name_changed(new_name: String) -> void:
	current_character.name = new_name

func _on_stat_changed(value: float, stat: String) -> void:
	current_character.stats[stat] = int(value)

func _apply_race_modifiers() -> void:
	var race_data = creation_data.races[current_character.race]
	for stat in race_data.base_stats:
		current_character.stats[stat] += race_data.base_stats[stat]
	current_character.abilities = race_data.special_abilities.duplicate()

func _apply_background_modifiers() -> void:
	var background_data = creation_data.backgrounds[current_character.background]
	for stat in background_data.stat_bonuses:
		current_character.stats[stat] += background_data.stat_bonuses[stat]
	# Apply starting credits and gear

func _apply_motivation_modifiers() -> void:
	var motivation_data = creation_data.motivations[current_character.motivation]
	# Apply motivation effects (e.g., starting credits, story points, etc.)

func _apply_class_modifiers() -> void:
	var class_data = creation_data.classes[current_character.character_class]
	for stat in class_data.stat_bonuses:
		current_character.stats[stat] += class_data.stat_bonuses[stat]
	# Apply class-specific bonuses (e.g., starting gear, skills)

func create_character() -> Character:
	# Finalize character creation, including any final calculations or validations
	return current_character

func randomize_character() -> void:
	current_character.race = randi() % creation_data.races.size()
	current_character.background = randi() % creation_data.backgrounds.size()
	current_character.motivation = randi() % creation_data.motivations.size()
	current_character.character_class = randi() % creation_data.classes.size()
	current_character.name = creation_data.get_random_name()
	current_character.portrait = creation_data.get_random_portrait()
	_apply_race_modifiers()
	_apply_background_modifiers()
	_apply_motivation_modifiers()
	_apply_class_modifiers()
	_update_ui()
