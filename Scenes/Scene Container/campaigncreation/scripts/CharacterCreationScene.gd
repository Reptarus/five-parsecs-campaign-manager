extends Control

@onready var tabs: TabContainer = $CharacterCreationTabs
@onready var preview_panel: Panel = $CharacterPreview
@onready var psionic_checkbox: CheckBox = $CharacterCreationTabs/CharacterDetails/PsionicCheckbox
@onready var strange_character_option: OptionButton = $CharacterCreationTabs/CharacterDetails/StrangeCharacterOption
@onready var species_option_button: OptionButton = $CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton
@onready var background_selection: Node = $CharacterCreationTabs/BasicProfile/BackgroundSelection
@onready var motivation_selection: Node = $CharacterCreationTabs/BasicProfile/MotivationSelection
@onready var class_selection: Node = $CharacterCreationTabs/BasicProfile/ClassSelection
@onready var stat_distribution: Node = $CharacterCreationTabs/CharacterDetails/StatDistribution
@onready var abilities_list: ItemList = $CharacterCreationTabs/CharacterDetails/SpecialAbilities/AbilitiesList
@onready var starting_weapons_and_gear: Node = $CharacterCreationTabs/Equipment/StartingWeaponsAndGear
@onready var starting_weapons: Node = $CharacterCreationTabs/Equipment/StartingWeapons
@onready var character_list: ItemList = $CharacterList
@onready var character_count_label: Label = $CharacterCountLabel
@onready var finish_button: Button = $FinishCrewCreationButton

var character_data: CharacterCreationData
var current_character: Character
var created_characters = []

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
	for race in character_data.races:
		species_option_button.add_item(race.name, race.id)
	species_option_button.item_selected.connect(_on_species_selected)

func create_new_character():
	current_character = Character.new()
	current_character.name = CharacterNameGenerator.get_random_name()
	current_character.species = character_data.races[randi() % character_data.races.size()].id
	current_character.background = character_data.backgrounds[randi() % character_data.backgrounds.size()].id
	current_character.motivation = character_data.motivations[randi() % character_data.motivations.size()].id
	current_character.character_class = character_data.classes[randi() % character_data.classes.size()].id
	
	# Generate random initial stats
	current_character.reactions = 1
	current_character.speed = 4
	current_character.combat_skill = 0
	current_character.toughness = 3
	current_character.savvy = 0
	
	current_character.apply_species_effects(character_data)
	current_character.apply_character_effects(character_data)
	update_ui()

func update_ui():
	$CharacterCreationTabs/BasicProfile/NameEntry/NameInput.text = current_character.name
	species_option_button.select(species_option_button.get_item_index(current_character.species))
	background_selection.select_background(current_character.background)
	motivation_selection.select_motivation(current_character.motivation)
	class_selection.select_class(current_character.character_class)
	stat_distribution.update_stats(current_character)
	update_abilities_list()
	starting_weapons_and_gear.update_gear(current_character)
	starting_weapons.update_weapons(current_character)
	update_preview_panel()

func update_preview_panel():
	preview_panel.update_preview(current_character)

func setup_tabs():
	# Tabs are already set up in the scene file, no need to add them programmatically
	pass

func setup_preview_panel():
	# Preview panel is already set up in the scene file, no need to add it programmatically
	pass

func connect_signals():
	$CharacterCreationTabs/BasicProfile/NameEntry/NameInput.text_changed.connect(_on_name_changed)
	$RandomCharacterButton.pressed.connect(roll_random_character)
	$SaveButton.pressed.connect(save_character)
	$ClearButton.pressed.connect(clear_character)
	$ImportButton.pressed.connect(import_character)
	$ExportButton.pressed.connect(export_character)
	$AddCharacterButton.pressed.connect(_on_add_character_pressed)
	$FinishCrewCreationButton.pressed.connect(_on_finish_crew_creation_pressed)

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
	var selected_species = species_option_button.get_item_text(index)
	current_character.set_species(selected_species, character_data)
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
	save_dialog.filters = ["*.json ; JSON Files"]
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
	import_dialog.filters = ["*.json ; JSON Files"]
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
	export_dialog.filters = ["*.json ; JSON Files"]
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
		created_characters.append(current_character.duplicate())
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
	var new_crew = Crew.new("New Crew")  # Provide a name for the crew
	for character in created_characters:
		new_crew.add_member(character)
	
	# Get the GameState instance
	var game_state = get_node("/root/GameState")
	if game_state:
		game_state.current_crew = new_crew
		game_state.change_state(GameState.State.CAMPAIGN_TURN)  # Change the state to CAMPAIGN_TURN
	else:
		print("Error: GameState not found")
	
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")

func show_error(message: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()

func update_abilities_list():
	abilities_list.clear()
	for ability in current_character.special_abilities:
		abilities_list.add_item(ability)
