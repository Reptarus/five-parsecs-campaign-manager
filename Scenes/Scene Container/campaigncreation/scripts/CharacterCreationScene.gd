extends Control

# Import necessary classes
const Character = preload("res://Scripts/Characters/Character.gd")
const CharacterCreationData = preload("res://Scripts/Characters/CharacterCreationData.gd")
const CharacterNameGenerator = preload("res://Resources/CharacterNameGenerator.gd")
const Crew = preload("res://Scripts/ShipAndCrew/Crew.gd")

# Onready variables for frequently accessed nodes
@onready var tabs: TabContainer = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs
@onready var preview_panel: Panel = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterPreview
@onready var character_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var finish_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/FinishCrewCreationButton

# Variables to store character data and UI elements
var character_data: CharacterCreationData
var current_character: Character
var created_characters: Array[Character] = []
var ui_elements: Dictionary

func _ready():
    print("CharacterCreationScene _ready() called")
    if not load_and_initialize_data():
        printerr("Failed to load character data. Aborting initialization.")
        return
    setup_ui_elements()
    connect_signals()
    create_new_character()
    populate_option_buttons()
    update_ui()

func load_and_initialize_data() -> bool:
    character_data = CharacterCreationData.new()
    if not character_data or not character_data.load_data():
        return false
    return true

func setup_ui_elements():
    ui_elements = {
        "name_input": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/NameEntry/NameInput,
        "species_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton,
        "background_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/BackgroundSelection/BackgroundOptionButton,
        "motivation_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/MotivationSelection/MotivationOptionButton,
        "class_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/ClassSelection/ClassOptionButton,
        "psionic_checkbox": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/PsionicCheckbox,
        "strange_character_option": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/StrangeCharacterOption,
        "abilities_list": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/SpecialAbilities/AbilitiesList,
        "stat_distribution": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/CharacterDetails/StatDistribution,
        "starting_weapons_and_gear": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/Equipment/StartingWeaponsAndGear,
        "starting_weapons": $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/Equipment/StartingWeapons,
    }
    
    if not verify_ui_elements():
        printerr("Some UI elements are missing. The scene may not function correctly.")

func connect_signals():
    ui_elements.name_input.text_changed.connect(_on_name_changed)
    $MarginContainer/VBoxContainer/HBoxContainer/RandomCharacterButton.pressed.connect(roll_random_character)
    $MarginContainer/VBoxContainer/HBoxContainer2/SaveButton.pressed.connect(_on_save_character_pressed)
    $MarginContainer/VBoxContainer/HBoxContainer2/ClearButton.pressed.connect(_on_clear_character_pressed)
    $MarginContainer/VBoxContainer/HBoxContainer2/ImportButton.pressed.connect(_on_import_character_pressed)
    $MarginContainer/VBoxContainer/HBoxContainer2/ExportButton.pressed.connect(_on_export_character_pressed)
    $MarginContainer/VBoxContainer/HBoxContainer2/AddCharacterButton.pressed.connect(_on_add_character_pressed)
    $MarginContainer/VBoxContainer/HBoxContainer2/FinishCrewCreationButton.pressed.connect(_on_finish_crew_creation_pressed)
    ui_elements.species_option.item_selected.connect(_on_species_selected)
    ui_elements.background_option.item_selected.connect(_on_background_selected)
    ui_elements.motivation_option.item_selected.connect(_on_motivation_selected)
    ui_elements.class_option.item_selected.connect(_on_class_selected)
    ui_elements.psionic_checkbox.toggled.connect(_on_psionic_toggled)
    ui_elements.strange_character_option.item_selected.connect(_on_strange_character_selected)

func create_new_character():
    current_character = Character.new()
    current_character.name = CharacterNameGenerator.get_random_name()
    current_character.species = get_random_item(character_data.species).name
    current_character.background = get_random_item(character_data.backgrounds).name
    current_character.motivation = get_random_item(character_data.motivations).name
    current_character.character_class = get_random_item(character_data.classes).name
    current_character.initialize_default_stats()
    if not current_character.apply_species_effects(character_data):
        printerr("Failed to apply species effects")
    if not current_character.apply_character_effects(character_data):
        printerr("Failed to apply character effects")

func populate_option_buttons():
    populate_option_button(ui_elements.species_option, character_data.species)
    populate_option_button(ui_elements.background_option, character_data.backgrounds)
    populate_option_button(ui_elements.motivation_option, character_data.motivations)
    populate_option_button(ui_elements.class_option, character_data.classes)
    populate_strange_character_option()

func populate_option_button(option_button: OptionButton, items: Array):
    option_button.clear()
    for item in items:
        option_button.add_item(item.name, item.id if item.has("id") else item.name.hash())

func populate_strange_character_option():
    ui_elements.strange_character_option.clear()
    for type in character_data.strange_character_types:
        ui_elements.strange_character_option.add_item(type)

func update_ui():
    if not current_character:
        printerr("No current character to update UI with.")
        return

    ui_elements.name_input.text = current_character.name
    update_option_button(ui_elements.species_option, current_character.species)
    update_option_button(ui_elements.background_option, current_character.background)
    update_option_button(ui_elements.motivation_option, current_character.motivation)
    update_option_button(ui_elements.class_option, current_character.character_class)
    ui_elements.psionic_checkbox.button_pressed = current_character.is_psionic
    update_option_button(ui_elements.strange_character_option, current_character.strange_character_type)
    update_abilities_list()
    ui_elements.stat_distribution.update_stats(current_character)
    ui_elements.starting_weapons_and_gear.update_gear(current_character)
    ui_elements.starting_weapons.update_weapons(current_character)
    preview_panel.update_preview(current_character)
    update_character_list()

func update_option_button(option_button: OptionButton, value: String):
    var index = find_option_index(option_button, value)
    option_button.select(index)

func find_option_index(option_button: OptionButton, value: String) -> int:
    for i in range(option_button.get_item_count()):
        if option_button.get_item_text(i).to_lower() == value.to_lower():
            return i
    printerr("Value not found in OptionButton: ", value)
    return 0  # Default to first item if not found

func update_abilities_list():
    ui_elements.abilities_list.clear()
    for ability in current_character.abilities:
        ui_elements.abilities_list.add_item(ability)

func update_character_list():
    character_list.clear()
    for character in created_characters:
        character_list.add_item("%s - %s" % [character.name, character.background])
    character_count_label.text = "Characters: %d/8" % created_characters.size()
    finish_button.disabled = created_characters.size() < 3 or created_characters.size() > 8

func _on_name_changed(new_name: String):
    current_character.name = new_name
    preview_panel.update_preview(current_character)

func _on_species_selected(index: int):
    var selected_species = ui_elements.species_option.get_item_text(index)
    current_character.species = selected_species
    if not current_character.apply_species_effects(character_data):
        printerr("Failed to apply species effects")
    update_ui()

func _on_background_selected(index: int):
    current_character.background = ui_elements.background_option.get_item_text(index)
    update_ui()

func _on_motivation_selected(index: int):
    current_character.motivation = ui_elements.motivation_option.get_item_text(index)
    update_ui()

func _on_class_selected(index: int):
    current_character.character_class = ui_elements.class_option.get_item_text(index)
    update_ui()

func _on_psionic_toggled(button_pressed: bool):
    if button_pressed:
        current_character.make_psionic()
    else:
        current_character.remove_psionic()
    update_ui()

func _on_strange_character_selected(index: int):
    var type = ui_elements.strange_character_option.get_item_text(index)
    current_character.set_strange_character_type(type)
    update_ui()

func roll_random_character():
    create_new_character()
    update_ui()

func _on_add_character_pressed():
    if created_characters.size() < 8:
        var new_character = Character.new()
        new_character.copy_from(current_character)
        created_characters.append(new_character)
        update_character_list()
        create_new_character()
    else:
        show_error("Maximum crew size reached (8 characters)")

func _on_finish_crew_creation_pressed():
    if created_characters.size() >= 3 and created_characters.size() <= 8:
        create_crew()
    else:
        show_error("Crew must have between 3 and 8 members")

func get_random_item(array: Array):
    if array.is_empty():
        printerr("Attempted to get random item from empty array")
        return null
    return array[randi() % array.size()]

func verify_ui_elements() -> bool:
    for key in ui_elements:
        if not ui_elements[key]:
            printerr("UI element not found: ", key)
            return false
    return true

func show_error(message: String):
    var error_dialog = AcceptDialog.new()
    error_dialog.dialog_text = message
    add_child(error_dialog)
    error_dialog.popup_centered()

func create_crew():
    var new_crew = Crew.new("New Crew")
    for character in created_characters:
        new_crew.add_member(character)
    
    var game_state = get_node("/root/GameState")
    if game_state:
        game_state.current_crew = new_crew
        game_state.change_state(GameState.State.CAMPAIGN_TURN)
    else:
        printerr("Error: GameState not found")
    
    get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")

func _on_clear_character_pressed():
    create_new_character()
    update_ui()

func _on_save_character_pressed():
    var save_manager = SaveManager.new()
    var save_name = "character_" + current_character.name.to_lower().replace(" ", "_")
    var game_state = GameState.new()
    game_state.current_character = current_character
    var result = save_manager.save_game(game_state, save_name)
    if result == OK:
        print("Character saved successfully")
    else:
        printerr("Failed to save character: ", result)

func _on_import_character_pressed():
    var save_manager = SaveManager.new()
    var save_list = save_manager.get_save_list()
    if save_list.is_empty():
        show_error("No saved characters found")
        return
    
    # TODO: Implement a UI for selecting a save file
    var selected_save = save_list[0]  # For now, just use the first save
    
    var loaded_character = save_manager.load_game(selected_save)
    if loaded_character is Character:
        current_character = loaded_character
        update_ui()
        print("Character imported successfully")
    else:
        printerr("Failed to import character")

func _on_export_character_pressed():
    var save_manager = SaveManager.new()
    var export_name = "character_export_" + current_character.name.to_lower().replace(" ", "_")
    var game_state = GameState.new()
    game_state.current_character = current_character
    var result = save_manager.save_game(game_state, export_name)
    if result == OK:
        print("Character exported successfully to: ", SaveManager.SAVE_DIR + export_name + SaveManager.SAVE_FILE_EXTENSION)
    else:
        printerr("Failed to export character: ", result)
