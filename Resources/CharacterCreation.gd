extends Control

var character_data: Dictionary
@onready var species_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton
@onready var background_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/BackgroundSelection/BackgroundOptionButton
@onready var motivation_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/MotivationSelection/MotivationOptionButton
@onready var class_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/ClassSelection/ClassOptionButton
@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/NameEntry/NameInput
@onready var random_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/RandomCharacterButton
@onready var clear_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/ClearButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var finish_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/FinishCrewCreationButton
@onready var psionic_option: CheckBox = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicSection/PsionicCheckbox
@onready var abilities_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/SpecialAbilities/AbilitiesList
@onready var character_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var psionic_abilities: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicSection/PsionicAbilities
@onready var psionic_description: Label = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicSection/PsionicDescription
@onready var finish_creation_dialog: ConfirmationDialog = $FinishCreationDialog

const StrangeCharacters = preload("res://Scripts/Characters/StrangeCharacters.gd")

func _ready() -> void:
	randomize()
	load_character_data()
	populate_option_buttons()
	connect_signals()
	update_character_info()
	finish_creation_dialog.connect("confirmed", _on_finish_creation_confirmed)

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
	random_button.pressed.connect(_on_random_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)
	save_button.pressed.connect(_on_save_pressed)
	finish_button.pressed.connect(_on_finish_pressed)
	psionic_option.pressed.connect(update_character_info)
	psionic_option.toggled.connect(update_psionic_info)

func update_character_info() -> void:
	var selected_race: Dictionary = character_data.races[species_option.get_selected_id()]
	var selected_background: Dictionary = character_data.backgrounds[background_option.get_selected_id()]
	var _selected_motivation: Dictionary = character_data.motivations[motivation_option.get_selected_id()]
	var selected_class: Dictionary = character_data.classes[class_option.get_selected_id()]

	var strange_character = StrangeCharacters.new()
	
	update_abilities_list(selected_race, selected_background, selected_class, strange_character)
	update_psionic_info(psionic_option.is_pressed())

func update_abilities_list(race: Dictionary, background: Dictionary, character_class: Dictionary, strange_character: StrangeCharacters):
	abilities_list.clear()
	
	# Add race special features
	if "special_features" in race:
		for feature in race["special_features"]:
			abilities_list.add_item(feature)
	
	# Add background abilities
	if "background_abilities" in background:
		for ability in background["background_abilities"]:
			abilities_list.add_item(ability)
	
	# Add class abilities
	if "class_abilities" in character_class:
		for ability in character_class["class_abilities"]:
			abilities_list.add_item(ability)
	
	# Add strange character special attributes
	for ability in strange_character.special_abilities:
		abilities_list.add_item(ability)
	
	# Add psionic abilities if the character is psionic
	if psionic_option.is_pressed():
		if "psionic_abilities" in character_class:
			for ability in character_class["psionic_abilities"]:
				abilities_list.add_item(ability)

func update_psionic_info(is_psionic: bool):
	psionic_abilities.visible = is_psionic
	if is_psionic:
		psionic_description.text = "This character has psionic abilities. Select from the list below:"
		# Populate psionic abilities based on the character's class or other factors
		psionic_abilities.clear()
		var psionic_ability_list = get_psionic_abilities()  # Implement this function to return a list of psionic abilities
		for ability in psionic_ability_list:
			psionic_abilities.add_item(ability)
	else:
		psionic_description.text = "This character does not have psionic abilities."
		psionic_abilities.clear()

func get_psionic_abilities() -> Array:
	# Implement this function to return a list of psionic abilities based on the character's class or other factors
	# For now, we'll return a placeholder list
	return ["Telepathy", "Telekinesis", "Precognition", "Psychometry"]

func _on_random_button_pressed():
	species_option.selected = randi() % species_option.item_count
	background_option.selected = randi() % background_option.item_count
	motivation_option.selected = randi() % motivation_option.item_count
	class_option.selected = randi() % class_option.item_count
	update_character_info()

func _on_clear_button_pressed():
	species_option.selected = 0
	background_option.selected = 0
	motivation_option.selected = 0
	class_option.selected = 0
	name_input.text = ""
	update_character_info()

func _on_save_pressed():
	var character = {}  # Use a dictionary instead of a custom class
	character["name"] = name_input.text
	character["species"] = species_option.get_item_text(species_option.selected)
	character["background"] = background_option.get_item_text(background_option.selected)
	character["motivation"] = motivation_option.get_item_text(motivation_option.selected)
	character["class"] = class_option.get_item_text(class_option.selected)
	character["is_psionic"] = psionic_option.pressed
	
	# Add character to the list
	character_list.add_item(character["name"])
	update_character_count()

func _on_finish_pressed():
	finish_creation_dialog.popup_centered()

func _on_finish_creation_confirmed():
	# Implement the logic to finalize the character creation
	var character = create_character()
	add_character_to_crew(character)
	clear_character_creation_form()
	update_character_count()
	# You might want to emit a signal or call a function to indicate that character creation is complete

func create_character() -> Dictionary:
	return {
		"name": name_input.text,
		"species": species_option.get_item_text(species_option.selected),
		"background": background_option.get_item_text(background_option.selected),
		"motivation": motivation_option.get_item_text(motivation_option.selected),
		"class": class_option.get_item_text(class_option.selected),
		"is_psionic": psionic_option.button_pressed,
		"psionic_abilities": get_selected_psionic_abilities() if psionic_option.button_pressed else [],
		# Add other character attributes as needed
	}

func get_selected_psionic_abilities() -> Array:
	var selected_abilities = []
	for index in psionic_abilities.get_selected_items():
		selected_abilities.append(psionic_abilities.get_item_text(index))
	return selected_abilities

func add_character_to_crew(character: Dictionary):
	character_list.add_item(character["name"])
	# You might want to store the full character data somewhere, not just the name

func clear_character_creation_form():
	name_input.text = ""
	species_option.selected = 0
	background_option.selected = 0
	motivation_option.selected = 0
	class_option.selected = 0
	psionic_option.button_pressed = false
	update_psionic_info(false)
	# Clear other form elements as needed

func update_character_count():
	var count = character_list.get_item_count()
	character_count_label.text = "Characters: %d/8" % count
