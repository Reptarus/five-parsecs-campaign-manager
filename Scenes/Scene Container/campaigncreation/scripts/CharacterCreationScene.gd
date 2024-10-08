@tool
class_name CharacterCreationScene
extends Control

@export var character_creation_data_res: CharacterCreationData
@export var character_creation_logic_res: CharacterCreationLogic
@export var character_creation_manager: CharacterCreationManager

var current_character: CrewMember
var created_characters: Array[CrewMember] = []
var ship_inventory: ShipInventory

@onready var name_input: LineEdit = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/NameEntry/NameInput
@onready var species_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/SpeciesSelection/SpeciesOptionButton
@onready var background_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/BackgroundSelection/BackgroundOptionButton
@onready var motivation_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/MotivationSelection/MotivationOptionButton
@onready var class_option: OptionButton = $MarginContainer/HSplitContainer/LeftPanel/ScrollContainer/VBoxContainer/ClassSelection/ClassOptionButton
@onready var character_list: ItemList = $MarginContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label: Label = $MarginContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var character_stats_display: RichTextLabel = $MarginContainer/HSplitContainer/RightPanel/CharacterPreview/CharacterStatsDisplay

var game_state_manager: GameStateManager

func _ready():
	game_state_manager = get_node("/root/GameStateManager")
	if not character_creation_data_res:
		character_creation_data_res = CharacterCreationData.new()
		character_creation_data_res.load_data()
	
	if not character_creation_logic_res:
		character_creation_logic_res = CharacterCreationLogic.new()
	
	if not character_creation_manager:
		var manager_scene = load("res://Scenes/campaign/CharacterCreationManager.tscn")
		character_creation_manager = manager_scene.instantiate()
		add_child(character_creation_manager)
	
	ship_inventory = ShipInventory.new()
	_populate_option_buttons()
	_update_character_count()

func _populate_option_buttons():
	_populate_option_button(species_option, character_creation_manager.get_all_species())
	_populate_option_button(background_option, character_creation_manager.get_all_backgrounds())
	_populate_option_button(motivation_option, character_creation_manager.get_all_motivations())
	_populate_option_button(class_option, character_creation_manager.get_all_classes())

func _populate_option_button(option_button: OptionButton, options: Array):
	option_button.clear()
	for option in options:
		option_button.add_item(option.name, option.id)

func _update_character_count():
	character_count_label.text = "Characters: %d/8" % created_characters.size()

func _on_random_character_button_pressed():
	current_character = character_creation_manager.character_creation.create_random_character(game_state_manager)
	_update_character_preview()

func _on_add_character_pressed() -> void:
	if created_characters.size() < 8:
		var new_character = character_creation_manager.create_character(
			GlobalEnums.Species.values()[species_option.selected],
			GlobalEnums.Background.values()[background_option.selected],
			GlobalEnums.Motivation.values()[motivation_option.selected],
			GlobalEnums.Class.values()[class_option.selected],
			game_state_manager.game_state
		)
		new_character.name = name_input.text
		_apply_starting_rolls(new_character)
		game_state_manager.recruit_crew_member(new_character)
		created_characters.append(new_character)
		character_list.add_item(new_character.name)
		_update_character_count()
		_update_character_preview()
	else:
		print("Maximum crew size reached (8 characters)")

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

func _roll_bonus_equipment() -> Array:
	# Implement logic to roll for bonus equipment based on Core Rules
	return []

func _roll_bonus_weapon() -> Item:
	# Implement logic to roll for bonus weapon based on Core Rules
	return Item.new()

func _update_character_preview():
	if current_character:
		var preview_text = "[b]Character Preview:[/b]\n\n"
		preview_text += "Name: %s\n" % current_character.name
		preview_text += "Species: %s\n" % GlobalEnums.Species.keys()[current_character.species]
		preview_text += "Background: %s\n" % GlobalEnums.Background.keys()[current_character.background]
		preview_text += "Motivation: %s\n" % GlobalEnums.Motivation.keys()[current_character.motivation]
		preview_text += "Class: %s\n\n" % GlobalEnums.Class.keys()[current_character.character_class]
		
		preview_text += "[b]Stats:[/b]\n"
		preview_text += "Reactions: %d\n" % current_character.reactions
		preview_text += "Speed: %d\"\n" % current_character.speed
		preview_text += "Combat Skill: %d\n" % current_character.combat_skill
		preview_text += "Toughness: %d\n" % current_character.toughness
		preview_text += "Savvy: %d\n\n" % current_character.savvy
		
		preview_text += "[b]Equipment:[/b]\n"
		for item in current_character.inventory:
			preview_text += "- %s\n" % item.name
		
		preview_text += "\n[b]Ship Inventory:[/b]\n"
		for item in ship_inventory.items:
			preview_text += "- %s\n" % item.name
		
		character_stats_display.text = preview_text

func _on_option_button_item_selected(_index: int):
	_update_character_preview()

func _on_save_character_pressed():
	if current_character:
		# Implement save logic
		pass

func _on_clear_character_pressed():
	name_input.text = ""
	species_option.select(0)
	background_option.select(0)
	motivation_option.select(0)
	class_option.select(0)
	current_character = null
	_update_character_preview()

func _on_import_character_pressed():
	# Implement import logic
	pass

func _on_export_character_pressed():
	if current_character:
		# Implement export logic
		pass

func _on_finish_crew_creation_pressed():
	if created_characters.size() > 0:
		var crew_members = []
		for character in created_characters:
			if character is CrewMember:
				crew_members.append(character)
			else:
				print("Error: Character is not a CrewMember")
				return
		game_state_manager.game_state.current_ship.crew = crew_members
		game_state_manager.game_state.current_ship.inventory = ship_inventory
		game_state_manager.transition_to_state(GlobalEnums.CampaignPhase.UPKEEP)
	else:
		print("Please create at least one character before finishing crew creation")

func _on_back_to_crew_management_pressed():
	get_tree().change_scene_to_file("res://Scenes/Management/CrewManagement.tscn")

func _on_create_character_pressed():
	var species = GlobalEnums.Species.values()[species_option.selected]
	var background = GlobalEnums.Background.values()[background_option.selected]
	var motivation = GlobalEnums.Motivation.values()[motivation_option.selected]
	var character_class = GlobalEnums.Class.values()[class_option.selected]
	
	var new_character = character_creation_logic_res.create_character(
		species,
		background,
		motivation,
		character_class,
		game_state_manager.game_state
	)
	
	if new_character:
		created_characters.append(new_character)
		_update_character_count()
		_clear_selection()
	else:
		print("Failed to create character")

func _clear_selection():
	# Clear the selected options in the UI
	name_input.text = ""
	species_option.select(0)
	background_option.select(0)
	motivation_option.select(0)
	class_option.select(0)
	current_character = null
	_update_character_preview()
