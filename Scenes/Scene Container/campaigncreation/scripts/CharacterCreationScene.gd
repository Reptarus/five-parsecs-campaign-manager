extends Control

const CharacterCreationDataClass = preload("res://Scripts/Characters/CharacterCreationData.gd")

@onready var character_portrait: TextureRect = $CrewPictureAndStats/PictureandBMCcontrols/CharacterPortrait
@onready var character_name_input: LineEdit = $CrewStatsAndInfo/NameEntry/NameInput
@onready var species_selection: OptionButton = $CrewStatsAndInfo/SpeciesSelection/SpeciesSelection
@onready var random_species_button: Button = $CrewStatsAndInfo/SpeciesSelection/RandomSpeciesButton
@onready var stat_distribution: GridContainer = $CrewStatsAndInfo/StatDistribution
@onready var species_info_label: RichTextLabel = $CrewPictureAndStats/CharacterFlavorBreakdown/SpeciesInfoLabel
@onready var weapons_list: ItemList = $CrewStatsAndInfo/StartingWeapons
@onready var user_notes: TextEdit = $CrewStatsAndInfo/UserNotes

# New UI elements
@onready var save_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Save
@onready var clear_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Clear
@onready var import_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Import
@onready var export_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Export
@onready var background_left: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/LeftArrow
@onready var background_right: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/RightArrow
@onready var motivation_left: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/LeftArrow
@onready var motivation_right: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/RightArrow
@onready var class_left: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/LeftArrow
@onready var class_right: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/RightArrow

var character: Character
var character_creation_data: CharacterCreationData

func _ready() -> void:
	character = Character.new()
	character_creation_data = CharacterCreationData.new()
	
	setup_ui()
	populate_species_options()
	setup_stat_spinboxes()
	connect_signals()
	update_character_display()

func setup_ui() -> void:
	populate_species_options()
	setup_stat_spinboxes()
	update_character_display()

func populate_species_options() -> void:
	for species in Character.Race.keys():
		species_selection.add_item(species)

func setup_stat_spinboxes() -> void:
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spinbox: SpinBox = stat_distribution.get_node(stat + "/" + stat + "SpinBox")
		spinbox.min_value = 0
		spinbox.max_value = 5
		spinbox.value = character.stats.get(stat.to_lower(), 0)
		spinbox.editable = false  # Make spinboxes non-editable

func connect_signals() -> void:
	character_name_input.text_changed.connect(_on_name_changed)
	species_selection.item_selected.connect(_on_species_selected)
	random_species_button.pressed.connect(_on_random_character_pressed)
	
	save_button.pressed.connect(_on_save_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	import_button.pressed.connect(_on_import_pressed)
	export_button.pressed.connect(_on_export_pressed)
	
	background_left.pressed.connect(_on_background_changed.bind(-1))
	background_right.pressed.connect(_on_background_changed.bind(1))
	motivation_left.pressed.connect(_on_motivation_changed.bind(-1))
	motivation_right.pressed.connect(_on_motivation_changed.bind(1))
	class_left.pressed.connect(_on_class_changed.bind(-1))
	class_right.pressed.connect(_on_class_changed.bind(1))

func _on_name_changed(new_name: String) -> void:
	character.name = new_name

func _on_species_selected(index: int) -> void:
	character.race = Character.Race.values()[index]
	update_character_display()
	update_portrait()

func _on_random_character_pressed() -> void:
	character = character_creation_data.generate_random_character()
	update_character_display()
	update_portrait()

func update_character_display() -> void:
	character_name_input.text = character.name
	species_selection.selected = character.race
	
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spinbox: SpinBox = stat_distribution.get_node(stat + "/" + stat + "SpinBox")
		spinbox.value = character.stats.get(stat.to_lower(), 0)
	
	update_species_info()
	update_weapons_gear()

func update_species_info() -> void:
	var info = """
	Species: {species}
	Background: {background}
	Motivation: {motivation}
	Class: {class}
	
	{species_traits}
	
	{background_info}
	{motivation_info}
	{class_info}
	""".format({
		"species": Character.Race.keys()[character.race],
		"background": character.background,
		"motivation": character.motivation,
		"class": character.character_class,
		"species_traits": CharacterCreationDataClass.get_race_traits(character.race),
		"background_info": character_creation_data.get_background_info(character.background),
		"motivation_info": character_creation_data.get_motivation_info(character.motivation),
		"class_info": character_creation_data.get_class_info(character.character_class)
	})
	species_info_label.text = info

func update_weapons_gear() -> void:
	var weapon_node = weapons_list.get_node("Weapon")
	var range_node = weapons_list.get_node("Range")
	var shots_node = weapons_list.get_node("Shots")
	var damage_node = weapons_list.get_node("Damage")
	var traits_node = weapons_list.get_node("Traits")

	weapon_node.get_node("Weapons").text = ""
	range_node.get_node("Range").text = ""
	shots_node.get_node("Shots").text = ""
	damage_node.get_node("Damage").text = ""
	traits_node.get_node("Traits").text = ""

	for item in character.inventory.items:
		if item is Weapon:
			weapon_node.get_node("Weapons").text += item.name + "\n"
			range_node.get_node("Range").text += str(item.range) + "\n"
			shots_node.get_node("Shots").text += str(item.shots) + "\n"
			damage_node.get_node("Damage").text += str(item.weapon_damage) + "\n"
			traits_node.get_node("Traits").text += ", ".join(item.traits) + "\n"

func update_portrait() -> void:
	var portrait_path = "res://assets/portraits/" + Character.Race.keys()[character.race].to_lower() + ".png"
	var texture = load(portrait_path)
	if texture:
		character_portrait.texture = texture
	else:
		print("Portrait not found: " + portrait_path)

func _on_background_changed(direction: int) -> void:
	var backgrounds = Character.Background.values()
	var current_index = backgrounds.find(character.background)
	var new_index = (current_index + direction + backgrounds.size()) % backgrounds.size()
	character.background = backgrounds[new_index]
	update_character_display()

func _on_motivation_changed(direction: int) -> void:
	var motivations = Character.Motivation.values()
	var current_index = motivations.find(character.motivation)
	var new_index = (current_index + direction + motivations.size()) % motivations.size()
	character.motivation = motivations[new_index]
	update_character_display()

func _on_class_changed(direction: int) -> void:
	var classes = Character.Class.values()
	var current_index = classes.find(character.character_class)
	var new_index = (current_index + direction + classes.size()) % classes.size()
	character.character_class = classes[new_index]
	update_character_display()

func _on_save_pressed() -> void:
	# Implement save functionality
	pass

func _on_clear_pressed() -> void:
	character = Character.new()
	update_character_display()
	update_portrait()

func _on_import_pressed() -> void:
	# Implement JSON import functionality
	pass

func _on_export_pressed() -> void:
	# Implement JSON export functionality
	pass
