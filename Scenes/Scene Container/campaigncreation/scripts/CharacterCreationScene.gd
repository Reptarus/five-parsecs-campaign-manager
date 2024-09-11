extends Control

@onready var tabs: TabContainer = $TabContainer
@onready var preview_panel: Panel = $PreviewPanel
@onready var psionic_checkbox: CheckBox = $PsionicCheckbox
@onready var strange_character_option: OptionButton = $StrangeCharacterOption

var character_data: CharacterCreationData
var current_character: Character

func _ready():
	character_data = CharacterCreationData.new()
	character_data.load_data()
	current_character = Character.new()
	setup_tabs()
	setup_preview_panel()
	connect_signals()
	create_new_character()
	setup_psionic_ui()
	setup_strange_character_ui()

func create_new_character():
	current_character = Character.new()
	current_character.name = CharacterNameGenerator.get_random_name()
	current_character.race = GlobalEnums.Race.values()[randi() % GlobalEnums.Race.size()]
	current_character.background = GlobalEnums.Background.values()[randi() % GlobalEnums.Background.size()]
	current_character.motivation = GlobalEnums.Motivation.values()[randi() % GlobalEnums.Motivation.size()]
	current_character.character_class = GlobalEnums.Class.values()[randi() % GlobalEnums.Class.size()]
	current_character.portrait = character_data.get_random_portrait()
	
	# Generate random initial stats
	for stat in current_character.stats:
		current_character.stats[stat] = randi() % 6 + 1
	
	current_character.apply_character_effects(character_data)
	update_ui()

func update_ui():
	# Update all UI elements with the current character data
	$CrewStatsAndInfo/NameEntry/NameInput.text = current_character.name
	$CrewStatsAndInfo/SpeciesSelection/SpeciesSelection.select(current_character.race)
	# ... (update other UI elements)
	
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
	pass

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
		current_character.is_psionic = false
		current_character.psionic_powers.clear()
	update_ui()

func _on_strange_character_selected(index: int):
	var type = StrangeCharacters.StrangeCharacterType.values()[index]
	current_character.set_strange_character_type(type)
	update_ui()
