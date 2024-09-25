# Scenes/Scene Container/campaigncreation/scripts/CharacterCreationScene.gd
extends Control

var character_creation_logic: CharacterCreationLogic
var character_creation_data: CharacterCreationData
var current_character: Character
var created_characters: Array[Character] = []
var ship_inventory: ShipInventory

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/NameEntry/NameInput
@onready var species_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/SpeciesSelection/SpeciesOptionButton
@onready var background_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/BackgroundSelection/BackgroundOptionButton
@onready var motivation_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/MotivationSelection/MotivationOptionButton
@onready var class_option: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/ClassSelection/ClassOptionButton
@onready var character_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterList
@onready var character_count_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/CharacterCountLabel
@onready var character_stats_display: Label = $MarginContainer/VBoxContainer/HSplitContainer/CharacterCreationTabs/BasicProfile/CharacterStatsDisplay

func _ready():
	character_creation_logic = CharacterCreationLogic.new()
	character_creation_data = CharacterCreationData.new()
	character_creation_data.load_data()
	ship_inventory = ShipInventory.new()
	_populate_option_buttons()
	_update_character_count()

func _populate_option_buttons():
	_populate_option_button(species_option, character_creation_data.get_all_races())
	_populate_option_button(background_option, character_creation_data.get_all_backgrounds())
	_populate_option_button(motivation_option, character_creation_data.get_all_motivations())
	_populate_option_button(class_option, character_creation_data.get_all_classes())

func _populate_option_button(option_button: OptionButton, options: Array):
	option_button.clear()
	for option in options:
		option_button.add_item(option.name, option.id)

func _update_character_count():
	character_count_label.text = "Characters: %d/8" % created_characters.size()

func _on_random_character_button_pressed():
	species_option.select(randi() % species_option.item_count)
	background_option.select(randi() % background_option.item_count)
	motivation_option.select(randi() % motivation_option.item_count)
	class_option.select(randi() % class_option.item_count)
	name_input.text = Character.generate_name(species_option.get_item_text(species_option.selected))
	_update_character_preview()

func _on_add_character_pressed():
	if created_characters.size() < 8:
		var new_character = character_creation_logic.create_character(
			species_option.get_selected_id(),
			background_option.get_selected_id(),
			motivation_option.get_selected_id(),
			class_option.get_selected_id()
		)
		new_character.name = name_input.text
		_apply_starting_rolls(new_character)
		created_characters.append(new_character)
		character_list.add_item(new_character.name)
		_update_character_count()
		_update_character_preview()
	else:
		print("Maximum crew size reached (8 characters)")

func _apply_starting_rolls(character: Character):
	# Apply bonus equipment and weapon rolls
	var bonus_equipment = _roll_bonus_equipment()
	var bonus_weapon = _roll_bonus_weapon()
	
	for item in bonus_equipment:
		if character.inventory.size() < 3:  # 2 weapons + 1 pistol/blade
			character.add_item(item)
		else:
			ship_inventory.add_item(item)
	
	if character.inventory.size() < 2:
		character.add_item(bonus_weapon)
	else:
		ship_inventory.add_item(bonus_weapon)

	# Generate and assign rivals, patrons, and rumors
	character.rivals = _generate_rivals()
	character.patrons = _generate_patrons()
	character.rumors = _generate_rumors()

func _roll_bonus_equipment() -> Array:
	# Implement bonus equipment roll logic
	return []  # Return an array of equipment items

func _roll_bonus_weapon() -> Dictionary:
	# Implement bonus weapon roll logic
	return {}  # Return a weapon item

func _generate_rivals() -> Array:
	# Implement rival generation logic
	return []  # Return an array of rivals

func _generate_patrons() -> Array:
	# Implement patron generation logic
	return []  # Return an array of patrons

func _generate_rumors() -> Array:
	# Implement rumor generation logic
	return []  # Return an array of rumors

func _update_character_preview():
	if current_character:
		character_stats_display.text = """
		Name: {name}
		Species: {species}
		Background: {background}
		Motivation: {motivation}
		Class: {character_class}
		
		Reactions: {reactions}
		Speed: {speed}
		Combat Skill: {combat_skill}
		Toughness: {toughness}
		Savvy: {savvy}
		Luck: {luck}
		
		Inventory: {inventory}
		Traits: {traits}
		""".format(current_character)

func _on_finish_crew_creation_pressed():
	if created_characters.size() >= 3 and created_characters.size() <= 8:
		# Save created characters and return to crew management
		get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")
	else:
		print("Crew must have between 3 and 8 members")

func _on_back_to_crew_management_pressed():
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")

func _on_clear_character_pressed():
	name_input.text = ""
	species_option.select(0)
	background_option.select(0)
	motivation_option.select(0)
	class_option.select(0)
	current_character = null
	_update_character_preview()

# ... (keep the existing import/export functions)

func _on_option_button_item_selected(index: int):
	_update_character_preview()
