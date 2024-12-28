extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

@onready var character_list = $Panel/HSplitContainer/CharacterList/ItemList
@onready var remove_button = $Panel/HSplitContainer/CharacterList/ButtonContainer/RemoveButton

# Stats tab references
@onready var name_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/NameValue
@onready var origin_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/OriginValue
@onready var class_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/ClassValue
@onready var background_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/BackgroundValue
@onready var motivation_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/MotivationValue

# Stats grid references
@onready var reactions_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/ReactionsValue
@onready var speed_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/SpeedValue
@onready var combat_skill_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/CombatSkillValue
@onready var toughness_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/ToughnessValue
@onready var savvy_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/SavvyValue
@onready var luck_value = $Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/LuckValue

# Equipment tab references
@onready var weapon_list = $Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/WeaponSection/WeaponList
@onready var gear_list = $Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/GearSection/GearList
@onready var inventory_list = $Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/InventorySection/InventoryList

var character_creator: CharacterCreator
var selected_character: Character

func _ready() -> void:
	character_creator = CharacterCreator.new()
	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)
	character_creator.creation_cancelled.connect(_on_creation_cancelled)
	
	# Connect to CharacterManager signals
	var character_manager = get_node("/root/CharacterManager")
	character_manager.character_added.connect(_on_character_added)
	character_manager.character_removed.connect(_on_character_removed)
	character_manager.character_updated.connect(_on_character_updated)
	
	_refresh_character_list()

func _refresh_character_list() -> void:
	character_list.clear()
	
	var character_manager = get_node("/root/CharacterManager")
	var characters = character_manager.get_all_characters()
	if characters.is_empty():
		character_list.add_item("No characters")
		remove_button.disabled = true
		_clear_character_details()
		return
	
	for character in characters:
		character_list.add_item(character.character_name)
	
	remove_button.disabled = false

func _clear_character_details() -> void:
	name_value.text = "-"
	origin_value.text = "-"
	class_value.text = "-"
	background_value.text = "-"
	motivation_value.text = "-"
	
	reactions_value.text = "-"
	speed_value.text = "-"
	combat_skill_value.text = "-"
	toughness_value.text = "-"
	savvy_value.text = "-"
	luck_value.text = "-"
	
	weapon_list.clear()
	gear_list.clear()
	inventory_list.clear()

func _update_character_details(character: Character) -> void:
	if not character:
		_clear_character_details()
		return
	
	# Update basic info
	name_value.text = character.character_name
	origin_value.text = GameEnums.Origin.keys()[character.origin]
	class_value.text = GameEnums.CharacterClass.keys()[character.character_class]
	background_value.text = character.background
	motivation_value.text = character.motivation
	
	# Update stats
	if character.stats:
		reactions_value.text = str(character.stats.reactions)
		speed_value.text = str(character.stats.speed)
		combat_skill_value.text = str(character.stats.combat_skill)
		toughness_value.text = str(character.stats.toughness)
		savvy_value.text = str(character.stats.savvy)
		luck_value.text = str(character.stats.luck)
	
	# Update equipment lists
	weapon_list.clear()
	gear_list.clear()
	inventory_list.clear()
	
	for weapon in character.weapons:
		weapon_list.add_item(weapon.name)
	
	for gear in character.gear:
		gear_list.add_item(gear.name)
	
	for item in character.inventory:
		inventory_list.add_item(item.name)

func _on_character_selected(index: int) -> void:
	if index < 0 or character_list.get_item_text(index) == "No characters":
		selected_character = null
		_clear_character_details()
		return
	
	var character_manager = get_node("/root/CharacterManager")
	selected_character = character_manager.get_character_by_index(index)
	if selected_character:
		_update_character_details(selected_character)

func _on_add_pressed() -> void:
	character_creator.start_creation()

func _on_remove_pressed() -> void:
	if selected_character:
		var character_manager = get_node("/root/CharacterManager")
		var character_id = character_manager._generate_character_id(selected_character)
		character_manager.remove_character(character_id)

func _on_character_created(character: Character) -> void:
	var character_manager = get_node("/root/CharacterManager")
	character_manager.add_character(character)

func _on_character_edited(character: Character) -> void:
	if selected_character:
		var character_manager = get_node("/root/CharacterManager")
		character_manager.update_character(character)

func _on_creation_cancelled() -> void:
	print("Character creation cancelled")

func _on_character_added(_character: Character) -> void:
	_refresh_character_list()

func _on_character_removed(_character: Character) -> void:
	_refresh_character_list()

func _on_character_updated(_character: Character) -> void:
	_refresh_character_list()
	if selected_character and selected_character == _character:
		_update_character_details(_character)