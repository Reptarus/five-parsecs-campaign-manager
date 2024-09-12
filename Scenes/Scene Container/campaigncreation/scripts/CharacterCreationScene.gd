extends Control

@onready var tabs: TabContainer = $TabContainer
@onready var preview_panel: Panel = $PreviewPanel
@onready var psionic_checkbox: CheckBox = $PsionicCheckbox
@onready var strange_character_option: OptionButton = $StrangeCharacterOption
@onready var species_option_button: OptionButton = $CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton

var character_data: CharacterCreationData
var current_character: Character

func _ready():
	character_data = CharacterCreationData.new()
	character_data.load_data()
	current_character = Character.new()
	setup_tabs()
	setup_preview_panel()
	connect_signals()
	setup_species_selection()
	setup_psionic_ui()
	setup_strange_character_ui()
	create_new_character()

func setup_species_selection():
	var species_list = ["Human", "Engineer", "K'Erin", "Soulless", "Precursor", "Feral", "Swift", "Bot"]
	for species in species_list:
		species_option_button.add_item(species)
	species_option_button.item_selected.connect(_on_species_selected)

func create_new_character():
	current_character = Character.new()
	current_character.name = CharacterNameGenerator.get_random_name()
	current_character.race = GlobalEnums.Race.values()[randi() % GlobalEnums.Race.size()]
	current_character.background = GlobalEnums.Background.values()[randi() % GlobalEnums.Background.size()]
	current_character.motivation = GlobalEnums.Motivation.values()[randi() % GlobalEnums.Motivation.size()]
	current_character.character_class = GlobalEnums.Class.values()[randi() % GlobalEnums.Class.size()]
	current_character.portrait = character_data.get_random_portrait()
	
	# Generate random initial stats
	current_character.reactions = 1
	current_character.speed = 4
	current_character.combat_skill = 0
	current_character.toughness = 3
	current_character.savvy = 0
	
	current_character.apply_species_effects()
	current_character.apply_character_effects(character_data)
	update_ui()

func update_ui():
	$CharacterCreationTabs/BasicProfile/NameEntry/NameInput.text = current_character.name
	species_option_button.select(current_character.species)
	# Update other UI elements (background, motivation, class, etc.)
	update_preview_panel()

func update_preview_panel():
	$PreviewPanel.update_preview(current_character)

func setup_tabs():
	tabs.add_child(create_basic_info_tab())
	tabs.add_child(create_stats_abilities_tab())
	tabs.add_child(create_equipment_tab())
	tabs.add_child(create_psionics_tab())
	tabs.add_child(create_notes_tab())

func create_basic_info_tab() -> Control:
	var tab = Control.new()
	tab.name = "Basic Info"
	# Add UI elements for name, species, background, motivation, class
	return tab

func create_stats_abilities_tab() -> Control:
	var tab = Control.new()
	tab.name = "Stats & Abilities"
	# Add UI elements for stats and abilities
	return tab

func create_equipment_tab() -> Control:
	var tab = Control.new()
	tab.name = "Equipment"
	# Add UI elements for equipment selection
	return tab

func create_psionics_tab() -> Control:
	var tab = Control.new()
	tab.name = "Psionics"
	# Add UI elements for psionic abilities
	return tab

func create_notes_tab() -> Control:
	var tab = Control.new()
	tab.name = "Notes"
	# Add UI elements for character notes
	return tab

func setup_preview_panel():
	# Set up the preview panel with character information
	pass

func load_character_data():
	# Load character creation data from JSON
	pass

func connect_signals():
	# Connect UI element signals to update functions
	$CharacterCreationTabs/BasicProfile/NameEntry/NameInput.text_changed.connect(_on_name_changed)
	# Connect other UI elements (background, motivation, class, etc.)

func setup_psionic_ui():
	psionic_checkbox.connect("toggled", Callable(self, "_on_psionic_toggled"))

func setup_strange_character_ui():
	for type in StrangeCharacters.StrangeCharacterType.keys():
		strange_character_option.add_item(type)
	strange_character_option.connect("item_selected", Callable(self, "_on_strange_character_selected"))

func _on_psionic_toggled(button_pressed: bool):
	if button_pressed:
		current_character.make_psionic()
	else:
		current_character.remove_psionic()
	update_ui()

func _on_strange_character_selected(index: int):
	var type = StrangeCharacters.StrangeCharacterType.values()[index]
	current_character.set_strange_character_type(type)
	update_ui()

func _on_species_selected(index: int):
	var selected_species = species_option_button.get_item_text(index)
	current_character.set_species(selected_species)
	current_character.apply_species_effects()
	update_ui()

func _on_name_changed(new_name: String):
	current_character.name = new_name
	update_preview_panel()

func roll_random_character():
	create_new_character()
	update_ui()

func save_character():
	# Implement character saving logic
	pass

func load_character():
	# Implement character loading logic
	pass
