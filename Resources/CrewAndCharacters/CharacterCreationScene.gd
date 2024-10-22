@tool
class_name CharacterCreationScene
extends Control

@export var character_creation_data: CharacterCreationData
@export var character_creation_logic: CharacterCreationLogic

var current_character: CrewMember
var crew: Crew
var ship_inventory: ShipInventory

@onready var name_input: LineEdit = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/NameEntry/NameInput
@onready var species_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/SpeciesSelection/SpeciesOptionButton
@onready var background_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/BackgroundSelection/BackgroundOptionButton
@onready var motivation_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/MotivationSelection/MotivationOptionButton
@onready var class_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/ClassSelection/ClassOptionButton
@onready var character_list: ItemList = $MarginContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label: Label = $MarginContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var character_stats_display: RichTextLabel = $MarginContainer/HSplitContainer/RightPanel/CharacterPreview/CharacterStatsDisplay

@onready var background_roll_result: Label = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/BackgroundSelection/BackgroundRollResult
@onready var motivation_roll_result: Label = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/MotivationSelection/MotivationRollResult
@onready var class_roll_result: Label = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/ClassSelection/ClassRollResult

var game_state_manager: GameStateManager
var editing_index: int = -1

var background_roll: int = 0
var motivation_roll: int = 0
var class_roll: int = 0

func _ready():
	if Engine.is_editor_hint():
		return  # Skip initialization in the editor
	
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found")
		return

	# Initialize crew if it doesn't exist
	if not crew:
		crew = game_state_manager.game_state.get("crew")
		if not crew:
			crew = Crew.new()
			game_state_manager.game_state.crew = crew
	
	if not character_creation_data:
		character_creation_data = CharacterCreationData.new()
	
	print("Loading character creation data")
	character_creation_data.load_data()
	print("Character creation data loaded. Species count: ", character_creation_data.get_all_species().size())
	
	print("Populating option buttons")
	_populate_option_buttons()
	_populate_species()
	_connect_signals()
	_load_character_for_editing()
	_update_character_preview()
	_update_character_count()

func _populate_option_buttons():
	print("Populating option buttons")
	var species_list = character_creation_data.get_all_species()
	print("Species list retrieved. Size: ", species_list.size())
	for species in species_list:
		print("Species: ", species)
	_populate_option_button(species_option, species_list)
	_populate_option_button(background_option, character_creation_data.get_all_backgrounds())
	_populate_option_button(motivation_option, character_creation_data.get_all_motivations())
	_populate_option_button(class_option, character_creation_data.get_all_classes())

func _populate_option_button(option_button: OptionButton, options: Array):
	print("Populating option button: ", option_button.name)
	option_button.clear()
	for option in options:
		print("Adding option: ", option.name)
		option_button.add_item(option.name)
		option_button.set_item_metadata(option_button.get_item_count() - 1, option.id)
	print("Options added: ", option_button.get_item_count())

func _populate_species():
	var species_list = character_creation_data.get_all_species()
	var strange_characters = character_creation_data.get_all_strange_characters()
	
	species_option.clear()
	
	# Add regular species
	for species in species_list:
		species_option.add_item(species.name)
		species_option.set_item_metadata(species_option.get_item_count() - 1, species.id)
	
	# Add a separator if there are strange characters
	if not strange_characters.is_empty():
		species_option.add_separator("Strange Characters")
	
	# Add strange characters
	for character in strange_characters:
		species_option.add_item(character.name)
		species_option.set_item_metadata(species_option.get_item_count() - 1, character.id)

func _update_character_count():
	if crew:
		character_count_label.text = "Characters: %d/8" % crew.get_size()
	else:
		character_count_label.text = "Characters: 0/8"

func _load_character_for_editing():
	editing_index = game_state_manager.temp_data.get("editing_character_index", -1)
	if crew and editing_index != -1 and editing_index < crew.get_size():
		var character = crew.characters[editing_index]
		if character is CrewMember:
			current_character = character
			_update_ui_with_character(current_character)
		else:
			push_error("Character at index %d is not a CrewMember" % editing_index)
			current_character = null
			_clear_selection()
	else:
		current_character = null
		_clear_selection()

func _update_ui_with_character(character: CrewMember):
	name_input.text = character.name
	_select_option_by_metadata(species_option, character.species)
	_select_option_by_metadata(background_option, character.background)
	_select_option_by_metadata(motivation_option, character.motivation)
	_select_option_by_metadata(class_option, character.character_class)
	_roll_and_update_attributes()

func _select_option_by_metadata(option_button: OptionButton, value):
	for i in range(option_button.get_item_count()):
		if option_button.get_item_metadata(i) == value:
			option_button.select(i)
			return
	push_warning("Could not find option with metadata: " + str(value))

func _on_add_character_pressed() -> void:
	if not crew:
		crew = Crew.new()
		game_state_manager.game_state.crew = crew

	if crew.get_size() < Crew.MAX_CREW_SIZE:
		var new_character = CrewMember.new()
		new_character.name = name_input.text
		new_character.species = species_option.get_selected_metadata()
		new_character.background = background_option.get_selected_metadata()
		new_character.motivation = motivation_option.get_selected_metadata()
		new_character.character_class = class_option.get_selected_metadata()
		
		character_creation_logic.initialize_character(new_character, game_state_manager.game_state)
		_apply_starting_rolls(new_character)
		
		if editing_index != -1 and editing_index < crew.get_size():
			crew.characters[editing_index] = new_character
		else:
			crew.add_character(new_character)
		
		game_state_manager.game_state.crew = crew
		game_state_manager.save_game()
		
		print("Character added successfully: ", new_character.name)
		get_tree().change_scene_to_file("res://Scenes/Scene Container/InitialCrewCreation.tscn")
	else:
		print("Maximum crew size reached (%d characters)" % Crew.MAX_CREW_SIZE)

func _apply_starting_rolls(character: Character):
	var bonus_equipment = _roll_bonus_equipment()
	var bonus_weapon = _roll_bonus_weapon()
	
	for item in bonus_equipment:
		if character.inventory.size() < 3:
			character.add_item(item)
		else:
			ship_inventory.add_item(item)
	
	if character.inventory.size() < 2:
		character.add_item(bonus_weapon)
	else:
		ship_inventory.add_item(bonus_weapon)

	# Apply background roll effects
	var background_effect = character_creation_data.get_background_roll_effect(background_option.get_selected_metadata(), background_roll)
	_apply_roll_effect(character, background_effect)

	# Apply motivation roll effects
	var motivation_effect = character_creation_data.get_motivation_roll_effect(motivation_option.get_selected_metadata(), motivation_roll)
	_apply_roll_effect(character, motivation_effect)

	# Apply class roll effects
	var class_effect = character_creation_data.get_class_roll_effect(class_option.get_selected_metadata(), class_roll)
	_apply_roll_effect(character, class_effect)

func _apply_roll_effect(character: Character, effect: String):
	# Implement the logic to apply the roll effect to the character
	# This might involve adding items, modifying stats, or applying special abilities
	print("Applying roll effect to character: ", effect)
	# TODO: Implement the actual effect application based on the game rules

func _roll_bonus_equipment() -> Array:
	# Implement logic to roll for bonus equipment based on Core Rules
	return []

func _roll_bonus_weapon() -> Item:
	# Implement logic to roll for bonus weapon based on Core Rules
	return Item.new()

func _update_character_preview():
	var preview_text = ""
	
	# Add species/strange character information
	var species_id = species_option.get_selected_metadata()
	var species_data = character_creation_data.get_data_by_id(character_creation_data.species, species_id)
	if not species_data:
		species_data = character_creation_data.get_data_by_id(character_creation_data.strange_characters, species_id)
	
	if species_data:
		preview_text += "[b]Species/Character Type:[/b] " + species_data.get("name", "Unknown") + "\n"
		preview_text += species_data.get("description", "No description available.") + "\n\n"
	
	# Add background information
	var background_id = background_option.get_selected_metadata()
	preview_text += "[b]Background:[/b] " + character_creation_data.get_background_description(background_id) + "\n"
	preview_text += "Roll Result: " + str(background_roll) + "\n"
	preview_text += "Effect: " + character_creation_data.get_background_roll_effect(background_id, background_roll) + "\n\n"
	
	# Add motivation information
	var motivation_id = motivation_option.get_selected_metadata()
	preview_text += "[b]Motivation:[/b] " + character_creation_data.get_motivation_description(motivation_id) + "\n"
	preview_text += "Roll Result: " + str(motivation_roll) + "\n"
	preview_text += "Effect: " + character_creation_data.get_motivation_roll_effect(motivation_id, motivation_roll) + "\n\n"
	
	# Add class information
	var class_id = class_option.get_selected_metadata()
	preview_text += "[b]Class:[/b] " + character_creation_data.get_class_description(class_id) + "\n"
	preview_text += "Roll Result: " + str(class_roll) + "\n"
	preview_text += "Effect: " + character_creation_data.get_class_roll_effect(class_id, class_roll) + "\n\n"
	
	character_stats_display.text = preview_text

func _on_option_button_item_selected(_index: int):
	_roll_and_update_attributes()
	_update_character_preview()

func _roll_and_update_attributes():
	background_roll = _roll_dice(6)
	motivation_roll = _roll_dice(6)
	class_roll = _roll_dice(6)
	
	background_roll_result.text = "Roll: " + str(background_roll)
	motivation_roll_result.text = "Roll: " + str(motivation_roll)
	class_roll_result.text = "Roll: " + str(class_roll)

func _roll_dice(sides: int) -> int:
	return randi() % sides + 1

func _clear_selection():
	name_input.text = ""
	if species_option.get_item_count() > 0:
		species_option.select(0)
	if background_option.get_item_count() > 0:
		background_option.select(0)
	if motivation_option.get_item_count() > 0:
		motivation_option.select(0)
	if class_option.get_item_count() > 0:
		class_option.select(0)
	current_character = null
	_roll_and_update_attributes()
	_update_character_preview()

func _on_back_to_crew_management_pressed():
	game_state_manager.game_state.crew = crew
	game_state_manager.save_game()
	get_tree().change_scene_to_file("res://Scenes/Scene Container/InitialCrewCreation.tscn")

func _connect_signals():
	name_input.text_changed.connect(_on_name_changed)
	species_option.item_selected.connect(_on_species_selected)
	background_option.item_selected.connect(_on_background_selected)
	motivation_option.item_selected.connect(_on_motivation_selected)
	class_option.item_selected.connect(_on_class_selected)

func _on_name_changed(new_name: String):
	if current_character:
		current_character.name = new_name
	_update_character_preview()

func _on_species_selected(index: int):
	print("Species selected: ", index)
	if current_character:
		current_character.species = species_option.get_item_metadata(index)
	_roll_and_update_attributes()
	_update_character_preview()

func _on_background_selected(index: int):
	if current_character:
		current_character.background = background_option.get_item_metadata(index)
	_roll_and_update_attributes()
	_update_character_preview()

func _on_motivation_selected(index: int):
	if current_character:
		current_character.motivation = motivation_option.get_item_metadata(index)
	_roll_and_update_attributes()
	_update_character_preview()

func _on_class_selected(index: int):
	if current_character:
		current_character.character_class = class_option.get_item_metadata(index)
	_roll_and_update_attributes()
	_update_character_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		game_state_manager.game_state.crew = crew
		game_state_manager.save_game()

func _on_save_character_pressed():
	var species_id = species_option.get_selected_metadata()
	var species_data = character_creation_data.get_data_by_id(character_creation_data.species, species_id)
	var _is_strange_character = false
	
	if not species_data:
		species_data = character_creation_data.get_data_by_id(character_creation_data.strange_characters, species_id)
		_is_strange_character = true
	
	print("Saving character with species: ", species_data.get("name", "Unknown"))
	# ... rest of your character saving logic ...
	# You might need to handle special abilities or traits differently for strange characters

func _on_random_character_button_pressed():
	_clear_selection()
	name_input.text = "Random Character " + str(randi() % 1000)
	species_option.select(randi() % species_option.get_item_count())
	background_option.select(randi() % background_option.get_item_count())
	motivation_option.select(randi() % motivation_option.get_item_count())
	class_option.select(randi() % class_option.get_item_count())
	_roll_and_update_attributes()
	_update_character_preview()
