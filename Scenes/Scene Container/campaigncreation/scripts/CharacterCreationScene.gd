extends Control

const CharacterClass := preload("res://Scripts/Characters/Character.gd")
const CharacterCreationDataResource := preload("res://Scripts/Characters/CharacterCreationData.gd")
const NameGenerator := preload("res://Resources/CharacterNameGenerator.gd")
const CrewResource := preload("res://Scripts/ShipAndCrew/Crew.gd")
const StrangeCharacters := preload("res://Scripts/Characters/StrangeCharacters.gd")

@onready var tabs := $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs
@onready var preview_panel := $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterPreview
@onready var character_list := $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label := $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var finish_button := $MarginContainer/VBoxContainer/ButtonContainer/FinishCrewCreationButton
@onready var finish_creation_dialog := $FinishCreationDialog

var character_data: CharacterCreationDataResource
var current_character: CharacterClass
var created_characters: Array[CharacterClass] = []
var ui_elements: Dictionary

func _ready() -> void:
	randomize()
	if load_and_initialize_data():
		setup_ui_elements()
		connect_signals()
		create_new_character()
		populate_option_buttons()
		update_ui()
		finish_creation_dialog.confirmed.connect(_on_finish_creation_confirmed)
	else:
		printerr("Failed to load character data. Aborting initialization.")

func load_and_initialize_data() -> bool:
	character_data = CharacterCreationDataResource.new()
	return character_data != null and character_data.load_data()

func setup_ui_elements() -> void:
	ui_elements = {
		"name_input": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/NameEntry/NameInput,
		"species_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton,
		"background_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/BackgroundSelection/BackgroundOptionButton,
		"motivation_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/MotivationSelection/MotivationOptionButton,
		"class_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/ClassSelection/ClassOptionButton,
		"stat_distribution": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/StatDistribution,
		"psionic_checkbox": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicSection/PsionicCheckbox,
		"psionic_abilities": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicSection/PsionicAbilities,
		"psionic_description": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicSection/PsionicDescription,
		"abilities_list": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/SpecialAbilities/AbilitiesList,
		"strange_character_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/StrangeCharacterOption,
		"starting_weapons_and_gear": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/Equipment/StartingWeaponsAndGear,
		"starting_weapons": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/Equipment/StartingWeapons
	}

func connect_signals() -> void:
	ui_elements.name_input.text_changed.connect(_on_name_changed)
	$MarginContainer/VBoxContainer/HeaderContainer/RandomCharacterButton.pressed.connect(roll_random_character)
	$MarginContainer/VBoxContainer/ButtonContainer/SaveButton.pressed.connect(_on_save_character_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/ClearButton.pressed.connect(_on_clear_character_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/ImportButton.pressed.connect(_on_import_character_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/ExportButton.pressed.connect(_on_export_character_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/AddCharacterButton.pressed.connect(_on_add_character_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/FinishCrewCreationButton.pressed.connect(_on_finish_crew_creation_pressed)
	
	for option in ["species", "background", "motivation", "class"]:
		ui_elements[option + "_option"].item_selected.connect(
			func(index): _on_attribute_selected(index, option)
		)
	
	ui_elements.psionic_checkbox.toggled.connect(_on_psionic_toggled)
	ui_elements.strange_character_option.item_selected.connect(_on_strange_character_selected)

func create_new_character() -> void:
	current_character = CharacterClass.new()
	current_character.name = NameGenerator.get_random_name()
	for attribute in ["species", "background", "motivation", "character_class"]:
		current_character[attribute] = get_random_item(character_data[attribute + "es" if attribute == "species" else attribute + "s"]).name
	current_character.initialize_default_stats()
	if not current_character.apply_species_effects(character_data) or not current_character.apply_character_effects(character_data):
		push_error("Failed to apply character effects")

func populate_option_buttons() -> void:
	var options_data := {
		"species_option": character_data.species,
		"background_option": character_data.backgrounds,
		"motivation_option": character_data.motivations,
		"class_option": character_data.classes
	}
   
	for option in options_data:
		populate_option_button(ui_elements[option], options_data[option])
   
	populate_strange_character_option()

func populate_option_button(option_button: OptionButton, items: Array) -> void:
	option_button.clear()
	for item in items:
		option_button.add_item(item.name, item.get("id", item.name.hash()))

func populate_strange_character_option() -> void:
	ui_elements.strange_character_option.clear()
	ui_elements.strange_character_option.add_item_array(character_data.strange_character_types)

func update_ui() -> void:
	if not current_character:
		push_error("No current character to update UI with.")
		return

	ui_elements.name_input.text = current_character.name
	for attribute in ["species", "background", "motivation", "character_class"]:
		update_option_button(ui_elements[attribute.replace("character_", "") + "_option"], current_character[attribute])
	ui_elements.psionic_checkbox.button_pressed = current_character.is_psionic
	update_option_button(ui_elements.strange_character_option, current_character.strange_character_type)
	update_abilities_list()
	ui_elements.stat_distribution.update_stats(current_character)
	ui_elements.starting_weapons_and_gear.update_gear(current_character)
	ui_elements.starting_weapons.update_weapons(current_character)
	preview_panel.update_preview(current_character)
	update_character_list()
	update_psionic_info(current_character.is_psionic)

func update_option_button(option_button: OptionButton, value: String) -> void:
	var index := option_button.get_item_index(option_button.get_item_id(value.hash()))
	option_button.select(index if index != -1 else 0)

func update_abilities_list() -> void:
	ui_elements.abilities_list.clear()
	ui_elements.abilities_list.add_item_array(current_character.abilities)

func update_character_list() -> void:
	character_list.clear()
	for character in created_characters:
		character_list.add_item("%s - %s" % [character.name, character.background])
	character_count_label.text = "Characters: %d/8" % created_characters.size()
	var character_count := created_characters.size()
	finish_button.disabled = character_count < 3 or character_count > 8

func _on_name_changed(new_name: String) -> void:
	current_character.name = new_name
	preview_panel.update_preview(current_character)

func _on_attribute_selected(index: int, attribute: String) -> void:
	current_character[attribute] = ui_elements[attribute + "_option"].get_item_text(index)
	if attribute == "species" and not current_character.apply_species_effects(character_data):
		push_error("Failed to apply species effects")
	update_ui()

func _on_psionic_toggled(button_pressed: bool) -> void:
	if button_pressed:
		current_character.make_psionic()
	else:
		current_character.remove_psionic()
	update_ui()

func _on_strange_character_selected(index: int) -> void:
	current_character.set_strange_character_type(ui_elements.strange_character_option.get_item_text(index))
	update_ui()

func roll_random_character() -> void:
	create_new_character()
	update_ui()

func _on_add_character_pressed() -> void:
	if created_characters.size() < 8:
		var new_character := CharacterClass.new()
		new_character.copy_from(current_character)
		created_characters.append(new_character)
		update_character_list()
		create_new_character()
	else:
		show_error("Maximum crew size reached (8 characters)")

func _on_finish_crew_creation_pressed() -> void:
	var crew_size := created_characters.size()
	if crew_size >= 3 and crew_size <= 8:
		finish_creation_dialog.popup_centered()
	else:
		show_error("Crew must have between 3 and 8 members")

func _on_finish_creation_confirmed() -> void:
	create_crew()

func get_random_item(array: Array):
	return array[randi() % array.size()] if not array.is_empty() else null

func verify_ui_elements() -> bool:
	return not ui_elements.values().has(null)

func show_error(message: String) -> void:
	var error_dialog := AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()

func create_crew() -> void:
	var new_crew := CrewResource.new("New Crew")
	for character in created_characters:
		new_crew.add_member(character)
	
	var game_state := get_node("/root/GameState")
	if game_state:
		game_state.current_crew = new_crew
		game_state.change_state(GameState.State.CAMPAIGN_TURN)
		get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")
	else:
		push_error("Error: GameState not found")

func _on_clear_character_pressed() -> void:
	create_new_character()
	update_ui()

func _on_save_character_pressed() -> void:
	var save_manager := SaveManager.new()
	var save_name := "character_" + current_character.name.to_lower().replace(" ", "_")
	var game_state := GameState.new()
	game_state.current_character = current_character
	var result := save_manager.save_game(game_state, save_name)
	print("Character " + ("saved successfully" if result == OK else "failed to save: " + str(result)))

func _on_import_character_pressed() -> void:
	var save_manager := SaveManager.new()
	var save_list := save_manager.get_save_list()
	if save_list.is_empty():
		show_error("No saved characters found")
		return
	# TODO: Implement a UI for selecting a save file
	var selected_save: String = save_list[0]  # For now, just use the first save
	
	var loaded_game_state: GameState = save_manager.load_game(selected_save)
	if loaded_game_state and loaded_game_state.current_character is CharacterClass:
		current_character = loaded_game_state.current_character
		update_ui()
		print("Character imported successfully")
	else:
		push_error("Failed to import character")

func _on_export_character_pressed() -> void:
	var save_manager := SaveManager.new()
	var export_name := "character_export_" + current_character.name.to_lower().replace(" ", "_")
	var game_state := GameState.new()
	game_state.current_character = current_character
	var result := save_manager.save_game(game_state, export_name)
	print("Character " + ("exported successfully to: " + SaveManager.SAVE_DIR + export_name + SaveManager.SAVE_FILE_EXTENSION if result == OK else "failed to export: " + str(result)))

func update_psionic_info(is_psionic: bool) -> void:
	ui_elements.psionic_abilities.visible = is_psionic
	ui_elements.psionic_description.text = "This character " + ("has psionic abilities. Select from the list below:" if is_psionic else "does not have psionic abilities.")
	if is_psionic:
		ui_elements.psionic_abilities.clear()
		ui_elements.psionic_abilities.add_item_array(get_psionic_abilities())
	else:
		ui_elements.psionic_abilities.clear()

func get_psionic_abilities() -> Array:
	# Implement this function to return a list of psionic abilities based on the character's class or other factors
	# For now, we'll return a placeholder list
	return ["Telepathy", "Telekinesis", "Precognition", "Psychometry"]
