extends Control

@onready var tabs: TabContainer = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs
@onready var preview_panel: Panel = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterPreview
@onready var psionic_checkbox: CheckBox = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicCheckbox
@onready var strange_character_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/StrangeCharacterOption
@onready var species_option_button = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton
@onready var background_option = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/BackgroundSelection/BackgroundOptionButton
@onready var motivation_option = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/MotivationSelection/MotivationOptionButton
@onready var class_option = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/ClassSelection/ClassOptionButton
@onready var stat_distribution: Node = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/StatDistribution
@onready var starting_weapons_and_gear: Node = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/Equipment/StartingWeaponsAndGear
@onready var starting_weapons: Node = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/Equipment/StartingWeapons
@onready var character_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var finish_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/FinishCrewCreationButton

var character_data
var current_character
var created_characters = []

func _ready():
	print("CharacterCreationScene _ready() called")
	character_data = load("res://Scripts/Characters/CharacterCreationData.gd").new()
	character_data.load_data()
	current_character = load("res://Scripts/Characters/Character.gd").new()
	setup_tabs()
	setup_preview_panel()
	connect_signals()
	setup_species_selection()
	setup_psionic_ui()
	setup_strange_character_ui()
	create_new_character()
	populate_option_buttons()

func setup_species_selection():
	for species in character_data.species:
		if species.id is String:
			species_option_button.add_item(species.name, species.name.hash())
		elif species.id is int:
			species_option_button.add_item(species.name, species.id)
		else:
			species_option_button.add_item(species.name)
   
	species_option_button.item_selected.connect(_on_species_selected)

func create_new_character():
	current_character = load("res://Scripts/Characters/Character.gd").new()
	print("Creating new character")
	current_character.name = CharacterNameGenerator.get_random_name()
   
	var random_species = character_data.species[randi() % character_data.species.size()]
	current_character.species = random_species.name if random_species is Dictionary else random_species
   
	current_character.background = character_data.backgrounds[randi() % character_data.backgrounds.size()].name
	current_character.motivation = character_data.motivations[randi() % character_data.motivations.size()].name
	current_character.character_class = character_data.classes[randi() % character_data.classes.size()].name
   
	current_character.reactions = 1
	current_character.speed = 4
	current_character.combat_skill = 0
	current_character.toughness = 3
	current_character.savvy = 0
   
	current_character.apply_species_effects(character_data)
	current_character.apply_character_effects(character_data)
	print("New character created:", current_character.name)
	update_ui()

func update_ui():
	print("Updating UI")
	$MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/NameEntry/NameInput.text = current_character.name
	species_option_button.select(species_option_button.get_item_index(species_option_button.get_item_index(current_character.species)))
	background_option.select(background_option.get_item_index(background_option.get_item_index(current_character.background)))
	motivation_option.select(motivation_option.get_item_index(motivation_option.get_item_index(current_character.motivation)))
	class_option.select(class_option.get_item_index(class_option.get_item_index(current_character.character_class)))
	stat_distribution.update_stats(current_character)
	update_character_traits()
	starting_weapons_and_gear.update_gear(current_character)
	starting_weapons.update_weapons(current_character)
	print("UI updated")
	update_preview_panel()

func update_preview_panel():
	preview_panel.update_preview(current_character)

func setup_tabs():
	pass

func setup_preview_panel():
	pass

func connect_signals():
	$MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/NameEntry/NameInput.text_changed.connect(_on_name_changed)
	$MarginContainer/VBoxContainer/HBoxContainer/RandomCharacterButton.pressed.connect(roll_random_character)
	$MarginContainer/VBoxContainer/HBoxContainer2/SaveButton.pressed.connect(save_character)
	$MarginContainer/VBoxContainer/HBoxContainer2/ClearButton.pressed.connect(clear_character)
	$MarginContainer/VBoxContainer/HBoxContainer2/ImportButton.pressed.connect(import_character)
	$MarginContainer/VBoxContainer/HBoxContainer2/ExportButton.pressed.connect(export_character)
	$MarginContainer/VBoxContainer/HBoxContainer2/AddCharacterButton.pressed.connect(_on_add_character_pressed)
	$MarginContainer/VBoxContainer/HBoxContainer2/FinishCrewCreationButton.pressed.connect(_on_finish_crew_creation_pressed)
	background_option.item_selected.connect(_on_background_selected)
	motivation_option.item_selected.connect(_on_motivation_selected)
	class_option.item_selected.connect(_on_class_selected)

func setup_psionic_ui():
	psionic_checkbox.toggled.connect(_on_psionic_toggled)

func setup_strange_character_ui():
	for type in StrangeCharacters.StrangeCharacterType.keys():
		strange_character_option.add_item(type)
	strange_character_option.item_selected.connect(_on_strange_character_selected)

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
	var selected_species_name = species_option_button.get_item_text(index)
	current_character.species = selected_species_name
	current_character.apply_species_effects(character_data)
	update_ui()

func _on_name_changed(new_name: String):
	current_character.name = new_name
	update_preview_panel()

func roll_random_character():
	create_new_character()
	update_ui()

func save_character():
	var save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
	save_dialog.current_path = "user://characters/"
	save_dialog.connect("file_selected", Callable(self, "_on_save_file_selected"))
	add_child(save_dialog)
	save_dialog.popup_centered(Vector2(800, 600))

func _on_save_file_selected(path):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(current_character.to_dict()))
	file.close()

func clear_character():
	create_new_character()
	update_ui()

func import_character():
	var import_dialog = FileDialog.new()
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
	import_dialog.current_path = "user://characters/"
	import_dialog.connect("file_selected", Callable(self, "_on_import_file_selected"))
	add_child(import_dialog)
	import_dialog.popup_centered(Vector2(800, 600))

func _on_import_file_selected(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error == OK:
		var character_dict = json.get_data()
		current_character.from_dict(character_dict, character_data)
		update_ui()
	else:
		print("JSON Parse Error: ", json.get_error_message())

func export_character():
	var export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
	export_dialog.current_path = "user://characters/"
	export_dialog.connect("file_selected", Callable(self, "_on_export_file_selected"))
	add_child(export_dialog)
	export_dialog.popup_centered(Vector2(800, 600))

func _on_export_file_selected(path):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(current_character.to_dict()))
	file.close()

func _on_add_character_pressed():
	if created_characters.size() < 8:
		var new_character = load("res://Scripts/Characters/Character.gd").new()
		new_character.copy_from(current_character)
		created_characters.append(new_character)
		update_character_list()
		create_new_character()
	else:
		show_error("Maximum crew size reached (8 characters)")

func update_character_list():
	character_list.clear()
	
	for character in created_characters:
		var character_info = "%s - %s" % [character.name, character.background]
		character_list.add_item(character_info)
	
	character_count_label.text = "Characters: %d/8" % created_characters.size()
	finish_button.disabled = created_characters.size() < 3 or created_characters.size() > 8

func _on_finish_crew_creation_pressed():
	if created_characters.size() >= 3 and created_characters.size() <= 8:
		create_crew()
	else:
		show_error("Crew must have between 3 and 8 members")

func create_crew():
	var new_crew = Crew.new("New Crew")
	for character in created_characters:
		new_crew.add_member(character)
   
	var game_state = get_node("/root/GameState")
	if game_state:
		game_state.current_crew = new_crew
		game_state.change_state(GameState.State.CAMPAIGN_TURN)
	else:
		print("Error: GameState not found")
   
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")

func show_error(message: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()

func update_character_traits():
	var traits_list = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/TraitsList
	traits_list.clear()
	var index = 0
	while index < current_character.traits.size():
		var current_trait = current_character.traits[index]
		traits_list.add_item(current_trait)
		index += 1

func populate_option_buttons():
	var creation_data = load_character_creation_data()
	if creation_data == null:
		print("Failed to load character data")
		return
   
	print("Backgrounds:", creation_data.backgrounds)
	for background in creation_data.backgrounds:
		background_option.add_item(background.name)
   
	print("Motivations:", creation_data.motivations)
	for motivation in creation_data.motivations:
		motivation_option.add_item(motivation.name)
   
	print("Classes:", creation_data.classes)
	for character_class in creation_data.classes:
		class_option.add_item(character_class.name)

func _on_background_selected(index):
	var selected_background = background_option.get_item_text(index)
	print("Selected background: ", selected_background)
	current_character.background = selected_background
	update_character_stats_based_on_background(selected_background)

func _on_motivation_selected(index):
	var selected_motivation = motivation_option.get_item_text(index)
	print("Selected motivation: ", selected_motivation)
	current_character.motivation = selected_motivation

func _on_class_selected(index):
	var selected_class = class_option.get_item_text(index)
	print("Selected class: ", selected_class)
	current_character.character_class = selected_class
	update_character_stats_based_on_class(selected_class)

func load_character_creation_data():
	var file = FileAccess.open("res://Data/character_creation_data.json", FileAccess.READ)
	if file == null:
		print("Failed to open character_creation_data.json")
		return null
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return null
	return json.get_data()

func update_character_stats_based_on_background(background: String):
	var creation_data = load_character_creation_data()
	if background in creation_data.background_stats:
		var stats = creation_data.background_stats[background]
		current_character.combat = stats.combat
		current_character.toughness = stats.toughness
		current_character.savvy = stats.savvy
		current_character.science = stats.science
		current_character.update_derived_stats()

func update_character_stats_based_on_class(character_class: String):
	var creation_data = load_character_creation_data()
	if character_class in creation_data.class_traits:
		current_character.traits = creation_data.class_traits[character_class]
	update_character_traits()
