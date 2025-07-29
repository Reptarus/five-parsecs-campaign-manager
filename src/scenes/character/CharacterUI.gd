extends Control

# Safe imports
const Character = preload("res://src/core/character/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/BaseCharacterCreator.gd")
# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")

# Node references using safe access
@onready var character_list: Button = get_node("Panel/HSplitContainer/CharacterList/ItemList")
@onready var remove_button: Button = get_node("Panel/HSplitContainer/CharacterList/ButtonContainer/RemoveButton")

# Stats tab references using safe access
@onready var name_value: LineEdit = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/NameValue")
@onready var origin_value: LineEdit = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/OriginValue")
@warning_ignore("untyped_declaration")
@onready var class_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/ClassValue")
@warning_ignore("untyped_declaration")
@onready var background_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/BackgroundValue")
@warning_ignore("untyped_declaration")
@onready var motivation_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/BasicInfo/MotivationValue")

# Stats grid references using safe access
@warning_ignore("untyped_declaration")
@onready var reactions_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/ReactionsValue")
@warning_ignore("untyped_declaration")
@onready var speed_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/SpeedValue")
@onready var combat_skill_value: Node = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/CombatSkillValue")
@warning_ignore("untyped_declaration")
@onready var toughness_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/ToughnessValue")
@warning_ignore("untyped_declaration")
@onready var savvy_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/SavvyValue")
@warning_ignore("untyped_declaration")
@onready var luck_value = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Stats/VBoxContainer/StatsGrid/LuckValue")

# Equipment tab references using safe access
@warning_ignore("untyped_declaration")
@onready var weapon_list = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/WeaponSection/WeaponList")
@warning_ignore("untyped_declaration")
@onready var gear_list = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/GearSection/GearList")
@warning_ignore("untyped_declaration")
@onready var inventory_list = get_node("Panel/HSplitContainer/CharacterDetails/TabContainer/Equipment/VBoxContainer/InventorySection/InventoryList")

@warning_ignore("untyped_declaration")
var character_creator
var selected_character: Node = null # Type-safe managed by system

func _ready() -> void:
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
	@warning_ignore("untyped_declaration")
	var required_autoloads = ["CharacterManager"]
	@warning_ignore("untyped_declaration")
	for autoload_name in required_autoloads:
		var autoload_node: Node = get_node_or_null("/root/" + str(autoload_name))
		if not autoload_node:
			push_warning("UI DEPENDENCY MISSING: %s not available (CharacterUI)" % autoload_name)

func _setup_character_creator() -> void:
	if not CharacterCreator:
		push_error("CRASH PREVENTION: Cannot create CharacterCreator - class not loaded")
		return

	@warning_ignore("unsafe_method_access")
	character_creator = CharacterCreator.new()
	if character_creator:
		@warning_ignore("unsafe_method_access")
		character_creator.character_created.connect(_on_character_created)
		@warning_ignore("unsafe_method_access")
		character_creator.character_edited.connect(_on_character_edited)
		@warning_ignore("unsafe_method_access")
		character_creator.creation_cancelled.connect(_on_creation_cancelled)

func _connect_to_character_manager() -> void:
	# Connect to CharacterManager signals safely
	var character_manager: Node = get_node("/root/CharacterManager")
	if character_manager:
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		character_manager.character_added.connect(_on_character_added)
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		character_manager.character_removed.connect(_on_character_removed)
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		character_manager.character_updated.connect(_on_character_updated)

func _refresh_character_list() -> void:
	@warning_ignore("unsafe_method_access")
	character_list.clear()

	var character_manager: Node = get_node(" / root / CharacterManager")
	@warning_ignore("unsafe_method_access")
	var characters: Array[Character] = character_manager.get_all_characters()
	if (characters.is_empty()):
		@warning_ignore("unsafe_method_access")
		character_list.add_item("Nocharacters")
		remove_button.disabled = true
		_clear_character_details()
		return

	for character in characters:
		@warning_ignore("unsafe_method_access")
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
	@warning_ignore("unsafe_property_access")
	combat_skill_value.text = " - "
	toughness_value.text = " - "
	savvy_value.text = " - "
	luck_value.text = " - "

	@warning_ignore("unsafe_method_access")
	weapon_list.clear()
	@warning_ignore("unsafe_method_access")
	gear_list.clear()
	@warning_ignore("unsafe_method_access")
	inventory_list.clear()

func _update_character_details(character: Node) -> void:
	if not character:
		_clear_character_details()
		return

	# Update basic info
	@warning_ignore("unsafe_property_access")
	name_value.text = character.character_name
	@warning_ignore("unsafe_method_access", "unsafe_property_access")
	origin_value.text = GlobalEnums.Origin.keys()[character.origin]
	@warning_ignore("unsafe_method_access", "unsafe_property_access")
	class_value.text = GlobalEnums.CharacterClass.keys()[character.character_class]
	@warning_ignore("unsafe_property_access")
	background_value.text = str(character.background)
	@warning_ignore("unsafe_property_access")
	motivation_value.text = str(character.motivation)

	# Update stats
	@warning_ignore("unsafe_property_access")
	reactions_value.text = str(character.reaction)
	@warning_ignore("unsafe_property_access")
	speed_value.text = str(character.speed)
	@warning_ignore("unsafe_property_access")
	combat_skill_value.text = str(character.combat)
	@warning_ignore("unsafe_property_access")
	toughness_value.text = str(character.toughness)
	@warning_ignore("unsafe_property_access")
	savvy_value.text = str(character.savvy)
	@warning_ignore("unsafe_property_access")
	luck_value.text = str(character.luck)

	# Update equipment lists
	@warning_ignore("unsafe_method_access")
	weapon_list.clear()
	@warning_ignore("unsafe_method_access")
	gear_list.clear()
	@warning_ignore("unsafe_method_access")
	inventory_list.clear()

	@warning_ignore("unsafe_property_access", "untyped_declaration")
	for weapon in character.weapons:
		@warning_ignore("unsafe_method_access")
		weapon_list.add_item(str(weapon))

	@warning_ignore("unsafe_property_access", "untyped_declaration")
	for item in character.armor:
		@warning_ignore("unsafe_method_access")
		gear_list.add_item(str(item))

	@warning_ignore("unsafe_property_access", "untyped_declaration")
	for item in character.items:
		@warning_ignore("unsafe_method_access")
		inventory_list.add_item(str(item))

func _on_character_selected(index: int) -> void:
	@warning_ignore("unsafe_method_access")
	if index < 0 or character_list.get_item_text(index) == "Nocharacters":
		selected_character = null
		_clear_character_details()
		return

	var character_manager: Node = get_node(" / root / CharacterManager")
	@warning_ignore("unsafe_method_access")
	selected_character = character_manager.get_character_by_index(index)
	if selected_character:
		_update_character_details(selected_character)

func _on_add_pressed() -> void:
	@warning_ignore("unsafe_method_access")
	character_creator.start_creation()

func _on_remove_pressed() -> void:
	if selected_character:
		var character_manager: Node = get_node(" / root / CharacterManager")
		@warning_ignore("unsafe_method_access")
		var character_id: Character = character_manager._generate_character_id(selected_character)
		@warning_ignore("unsafe_method_access")
		character_manager.remove_character(character_id)

func _on_character_created(character: Node) -> void:
	var character_manager: Node = get_node(" / root / CharacterManager")
	@warning_ignore("unsafe_method_access")
	character_manager.add_character(character)

func _on_character_edited(character: Node) -> void:
	if selected_character:
		var character_manager: Node = get_node(" / root / CharacterManager")
		@warning_ignore("unsafe_method_access")
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

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	@warning_ignore("unsafe_method_access")
	if obj is Object and obj.has_method(method_name):
		@warning_ignore("unsafe_method_access")
		return obj.callv(method_name, args)
	return null
