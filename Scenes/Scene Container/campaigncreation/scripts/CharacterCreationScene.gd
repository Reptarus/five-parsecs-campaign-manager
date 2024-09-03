extends Control

@onready var character_portrait: TextureRect = $MainContent/LeftColumn/CharacterPortrait
@onready var character_name_input: LineEdit = $MainContent/LeftColumn/LineEdit
@onready var species_selection: OptionButton = $MainContent/RightColumn/SpeciesSelection/SpeciesSelection
@onready var random_species_button: Button = $MainContent/RightColumn/SpeciesSelection/RandomSpeciesButton
@onready var stat_distribution: GridContainer = $MainContent/RightColumn/StatDistribution
@onready var species_info_label: RichTextLabel = $MainContent/RightColumn/SpeciesInfoLabel
@onready var weapons_list: ItemList = $MainContent/RightColumn/WeaponsList
@onready var user_notes: TextEdit = $MainContent/RightColumn/UserNotes

var character: Character
var character_creation_data: CharacterCreationData

func _ready() -> void:
	character = Character.new()
	character_creation_data = CharacterCreationData.new()
	
	_setup_ui()
	_populate_species_options()
	_setup_stat_spinboxes()
	_connect_signals()
	_update_character_display()
	_connect_signals()

func _setup_ui() -> void:
	_populate_species_options()
	_setup_stat_spinboxes()
	_update_character_display()

func _populate_species_options() -> void:
	for species in character_creation_data.get_all_species():
		species_selection.add_item(species)

func _setup_stat_spinboxes() -> void:
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spinbox: SpinBox = stat_distribution.get_node(stat + "/" + stat + "SpinBox")
		spinbox.min_value = 0
		spinbox.max_value = 5
		spinbox.value = character.stats.get(stat.to_lower(), 0)

func _connect_signals() -> void:
	character_name_input.text_changed.connect(_on_name_changed)
	species_selection.item_selected.connect(_on_species_selected)
	random_species_button.pressed.connect(_on_random_species_pressed)
	
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spinbox: SpinBox = stat_distribution.get_node(stat + "/" + stat + "SpinBox")
		spinbox.value_changed.connect(_on_stat_changed.bind(stat.to_lower()))

func _on_name_changed(new_name: String) -> void:
	character.name = new_name

func _on_species_selected(index: int) -> void:
	var selected_species = character_creation_data.get_species_by_index(index)
	character.race = selected_species
	_update_character_display()

func _on_random_species_pressed() -> void:
	var random_index = randi() % species_selection.get_item_count()
	species_selection.select(random_index)
	_on_species_selected(random_index)

func _on_stat_changed(value: float, stat: String) -> void:
	character.stats[stat] = int(value)

func _update_character_display() -> void:
	character_name_input.text = character.name
	species_selection.selected = character_creation_data.get_species_index(character.race)
	
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spinbox: SpinBox = stat_distribution.get_node(stat + "/" + stat + "SpinBox")
		spinbox.value = character.stats.get(stat.to_lower(), 0)
	
	_update_species_info()
	_update_weapons_gear()

func _update_species_info() -> void:
	var info = """
	Species: {species}
	Background: {background}
	Motivation: {motivation}
	Class: {class}
	
	{species_traits}
	""".format({
		"species": Character.Race.keys()[character.race],
		"background": character.background,
		"motivation": character.motivation,
		"class": character.character_class,
		"species_traits": character_creation_data.get_race_traits(CharacterCreationData.Race)
	})
	species_info_label.text = info

func _update_weapons_gear() -> void:
	weapons_list.clear()
	for item in character.inventory.items:
		weapons_list.add_item(item.name)
