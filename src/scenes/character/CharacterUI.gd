# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
extends Control

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependencies using Universal loading
var Character = null
var CharacterCreator = null
var GameEnums = null
var FiveParsecsGameState = null

# Node references using safe access
@onready var character_list: Button = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterList/ItemList", "CharacterUI character_list")
@onready var remove_button: Button = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterList/ButtonContainer/RemoveButton", "CharacterUI remove_button")

# Stats tab references using safe access
@onready var name_value: LineEdit = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/NameValue", "CharacterUI name_value")
@onready var origin_value: LineEdit = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/OriginValue", "CharacterUI origin_value")
@onready var class_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/ClassValue", "CharacterUI class_value")
@onready var background_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/BackgroundValue", "CharacterUI background_value")
@onready var motivation_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/MotivationValue", "CharacterUI motivation_value")

# Stats grid references using safe access
@onready var reactions_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/ReactionsValue", "CharacterUI reactions_value")
@onready var speed_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/SpeedValue", "CharacterUI speed_value")
@onready var combat_skill_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/CombatSkillValue", "CharacterUI combat_skill_value")
@onready var toughness_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/ToughnessValue", "CharacterUI toughness_value")
@onready var savvy_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/SavvyValue", "CharacterUI savvy_value")
@onready var luck_value = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/LuckValue", "CharacterUI luck_value")

# Equipment tab references using safe access
@onready var weapon_list = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/WeaponSection/WeaponList", "CharacterUI weapon_list")
@onready var gear_list = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/GearSection/GearList", "CharacterUI gear_list")
@onready var inventory_list = UniversalNodeAccess.get_node_safe(self, "Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/InventorySection/InventoryList", "CharacterUI inventory_list")

var character_creator
var selected_character: Node = null

func _ready() -> void:
	# Load dependencies safely at runtime
	Character = UniversalResourceLoader.load_script_safe("res://src/game/character/Character.gd", "CharacterUI Character")
	CharacterCreator = UniversalResourceLoader.load_script_safe("res://src/game/character/generation/CharacterCreator.gd", "CharacterUI CharacterCreator")
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "CharacterUI GameEnums")
	FiveParsecsGameState = UniversalResourceLoader.load_script_safe("res://src/core/state/GameState.gd", "CharacterUI GameState")
	
	_validate_universal_connections()
	_setup_character_creator()
	_connect_to_character_manager()
	_refresh_character_list()

func _validate_universal_connections() -> void:
	# Validate UI dependencies
	_validate_character_ui_connections()

func _validate_character_ui_connections() -> void:
	# Validate required dependencies
	if not CharacterCreator:
		push_error("UI SYSTEM FAILURE: CharacterCreator not loaded in CharacterUI")
	
	if not Character:
		push_error("UI SYSTEM FAILURE: Character class not loaded in CharacterUI")
	
	# Validate autoload connections
	var required_autoloads = ["CharacterManager"]
	for autoload_name in required_autoloads:
		var autoload_node = get_node_or_null("/root/" + autoload_name)
		if not autoload_node:
			push_warning("UI DEPENDENCY MISSING: %s not available (CharacterUI)" % autoload_name)

func _setup_character_creator() -> void:
	if not CharacterCreator:
		push_error("CRASH PREVENTION: Cannot create CharacterCreator - class not loaded")
		return
	
	character_creator = CharacterCreator.new()
	if character_creator:
		UniversalSignalManager.connect_signal_safe(character_creator, "character_created", _on_character_created, "CharacterUI character_created")
		UniversalSignalManager.connect_signal_safe(character_creator, "character_edited", _on_character_edited, "CharacterUI character_edited")
		UniversalSignalManager.connect_signal_safe(character_creator, "creation_cancelled", _on_creation_cancelled, "CharacterUI creation_cancelled")

func _connect_to_character_manager() -> void:
	# Connect to CharacterManager signals safely
	var character_manager = UniversalNodeAccess.get_node_safe(get_tree().root, "/root/CharacterManager", "CharacterUI character manager access")
	if character_manager:
		UniversalSignalManager.connect_signal_safe(character_manager, "character_added", _on_character_added, "CharacterUI character_added")
		UniversalSignalManager.connect_signal_safe(character_manager, "character_removed", _on_character_removed, "CharacterUI character_removed")
		UniversalSignalManager.connect_signal_safe(character_manager, "character_updated", _on_character_updated, "CharacterUI character_updated")

func _refresh_character_list() -> void:
	character_list.clear()
	
	var character_manager = get_node(" / root / CharacterManager")
	var characters = character_manager.get_all_characters()
	if characters.is_empty():
		character_list.add_item("Nocharacters")
		remove_button.disabled = true
		_clear_character_details()
		return
	
	for character in characters:
		character_list.add_item(character.character_name)
	
	remove_button.disabled = false

func _clear_character_details() -> void:
	name_value.text = " - "
	origin_value.text = " - "
	class_value.text = " - "
	background_value.text = " - "
	motivation_value.text = " - "
	
	reactions_value.text = " - "
	speed_value.text = " - "
	combat_skill_value.text = " - "
	toughness_value.text = " - "
	savvy_value.text = " - "
	luck_value.text = " - "
	
	weapon_list.clear()
	gear_list.clear()
	inventory_list.clear()

func _update_character_details(character: Node) -> void:
	if not character:
		_clear_character_details()
		return
	
	# Update basic info
	name_value.text = character.character_name
	origin_value.text = GameEnums.Origin.keys()[character.origin]
	class_value.text = GameEnums.CharacterClass.keys()[character.character_class]
	background_value.text = str(character.background)
	motivation_value.text = str(character.motivation)
	
	# Update stats
	reactions_value.text = str(character.reaction)
	speed_value.text = str(character.speed)
	combat_skill_value.text = str(character.combat)
	toughness_value.text = str(character.toughness)
	savvy_value.text = str(character.savvy)
	luck_value.text = str(character.luck)
	
	# Update equipment lists
	weapon_list.clear()
	gear_list.clear()
	inventory_list.clear()
	
	for weapon in character.weapons:
		weapon_list.add_item(str(weapon))
	
	for item in character.armor:
		gear_list.add_item(str(item))
	
	for item in character.items:
		inventory_list.add_item(str(item))

func _on_character_selected(index: int) -> void:
	if index < 0 or character_list.get_item_text(index) == "Nocharacters":
		selected_character = null
		_clear_character_details()
		return
	
	var character_manager = get_node(" / root / CharacterManager")
	selected_character = character_manager.get_character_by_index(index)
	if selected_character:
		_update_character_details(selected_character)

func _on_add_pressed() -> void:
	character_creator.start_creation()

func _on_remove_pressed() -> void:
	if selected_character:
		var character_manager = get_node(" / root / CharacterManager")
		var character_id = character_manager._generate_character_id(selected_character)
		character_manager.remove_character(character_id)

func _on_character_created(character: Node) -> void:
	var character_manager = get_node(" / root / CharacterManager")
	character_manager.add_character(character)

func _on_character_edited(character: Node) -> void:
	if selected_character:
		var character_manager = get_node(" / root / CharacterManager")
		character_manager.update_character(character)

func _on_creation_cancelled() -> void:
	print("Charactercreationcancelled")

func _on_character_added(_character: Node) -> void:
	_refresh_character_list()

func _on_character_removed(_character: Node) -> void:
	_refresh_character_list()

func _on_character_updated(_character: Node) -> void:
	_refresh_character_list()
	if selected_character and selected_character == _character:
		_update_character_details(_character)
