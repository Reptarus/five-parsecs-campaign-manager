extends Control

var character_data: Dictionary
@onready var species_option: OptionButton = $CrewStatsAndInfo/SpeciesSelection/SpeciesSelection
@onready var background_option: OptionButton = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/BackgroundSelection
@onready var motivation_option: OptionButton = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/MotivationSelection
@onready var class_option: OptionButton = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/ClassSelection
@onready var info_box: RichTextLabel = $CrewPictureAndStats/CharacterFlavorBreakdown/SpeciesInfoLabel
@onready var stat_spinboxes: Dictionary = {
	"reactions": $CrewStatsAndInfo/StatDistribution/Reactions/ReactionsSpinBox,
	"speed": $CrewStatsAndInfo/StatDistribution/Speed/SpeedSpinBox,
	"combat_skill": $CrewStatsAndInfo/StatDistribution/Combat/CombatSpinBox,
	"toughness": $CrewStatsAndInfo/StatDistribution/Toughness/ToughnessSpinBox,
	"savvy": $CrewStatsAndInfo/StatDistribution/Savvy/SavvySpinBox,
	"luck": $CrewStatsAndInfo/StatDistribution/Luck/LuckSpinBox
}

func _ready() -> void:
	randomize()
	load_character_data()
	populate_option_buttons()
	connect_signals()
	update_character_info()

func load_character_data() -> void:
	var file = FileAccess.open("res://data/character_creation_data.json", FileAccess.READ)
	if file == null:
		print("Failed to open character_creation_data.json")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error == OK:
		character_data = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message())
		print("Error at line ", json.get_error_line())

func populate_option_buttons():
	for race in character_data.races:
		species_option.add_item(race.name)
	for background in character_data.backgrounds:
		background_option.add_item(background.name)
	for motivation in character_data.motivations:
		motivation_option.add_item(motivation.name)
	for character_class in character_data.classes:
		class_option.add_item(character_class.name)

func connect_signals():
	species_option.item_selected.connect(update_character_info)
	background_option.item_selected.connect(update_character_info)
	motivation_option.item_selected.connect(update_character_info)
	class_option.item_selected.connect(update_character_info)

func update_character_info() -> void:
	var selected_race: Dictionary = character_data.races[species_option.get_selected_id()]
	var selected_background: Dictionary = character_data.backgrounds[background_option.get_selected_id()]
	var selected_motivation: Dictionary = character_data.motivations[motivation_option.get_selected_id()]
	var selected_class: Dictionary = character_data.classes[class_option.get_selected_id()]

	update_stats(selected_race)
	update_info_box(selected_race, selected_background, selected_motivation, selected_class)

func update_stats(race: Dictionary) -> void:
	for stat in stat_spinboxes:
		stat_spinboxes[stat].value = race.base_stats.get(stat, 0)

func _init():
	pass

func update_info_box(race, background, motivation, character_class):
	var info_text = """
Species: {race_name}
{race_description}
Special Abilities: {race_abilities}

Background: {background_name}
{background_description}
{background_effects}

Motivation: {motivation_name}
{motivation_description}
{motivation_effects}

Class: {class_name}
{class_description}
{class_effects}
	""".format({
		"race_name": race.name,
		"race_description": race.description,
		"race_abilities": ", ".join(race.special_abilities),
		"background_name": background.name,
		"background_description": background.description,
		"background_effects": get_background_effects(background),
		"motivation_name": motivation.name,
		"motivation_description": motivation.description,
		"motivation_effects": get_motivation_effects(motivation),
		"class_name": character_class.name,
		"class_description": character_class.description,
		"class_effects": get_class_effects(character_class)
	})
	info_box.text = info_text

func get_background_effects(background: Dictionary) -> String:
	var effects = []
	for stat in background.stat_bonuses:
		effects.append("+{0} {1}".format([background.stat_bonuses[stat], stat.capitalize()]))
	if "starting_credits" in background:
		effects.append("{0} starting credits".format([background.starting_credits]))
	if "starting_gear" in background:
		effects.append("Starting gear: " + ", ".join(background.starting_gear))
	return ", ".join(effects)

func get_motivation_effects(motivation: Dictionary) -> String:
	var effects = []
	for effect in motivation.effect:
		effects.append("{0}: {1}".format([effect.capitalize(), motivation.effect[effect]]))
	return ", ".join(effects)

func get_class_effects(character_class: Dictionary) -> String:
	var effects = []
	for stat in character_class.stat_bonuses:
		effects.append("+{0} {1}".format([character_class.stat_bonuses[stat], stat.capitalize()]))
	if "starting_gear" in character_class:
		effects.append("Starting gear: " + ", ".join(character_class.starting_gear))
	return ", ".join(effects)

func _on_random_button_pressed():
	species_option.selected = randi() % species_option.item_count
	background_option.selected = randi() % background_option.item_count
	motivation_option.selected = randi() % motivation_option.item_count
	class_option.selected = randi() % class_option.item_count
	update_character_info()

func _on_clear_button_pressed():
	species_option.selected = 0  # Assuming Human is the first option
	background_option.selected = 0
	motivation_option.selected = 0
	class_option.selected = 0
	update_character_info()
