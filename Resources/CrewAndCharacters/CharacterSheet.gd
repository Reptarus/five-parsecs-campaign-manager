extends CampaignResponsiveLayout

signal character_updated(character: Character)

const Character = preload("res://Resources/CrewAndCharacters/Character.gd")

@onready var name_label := $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var portrait := $Panel/MarginContainer/VBoxContainer/Portrait
@onready var stats_container := $Panel/MarginContainer/VBoxContainer/StatsDisplay
@onready var equipment_section := $Panel/MarginContainer/VBoxContainer/EquipmentSection
@onready var skills_display := $Panel/MarginContainer/VBoxContainer/SkillsDisplay
@onready var equipment_popup := $EquipmentPopup

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_SIZE_RATIO := 0.3  # 30% of screen height in portrait mode

var character: Character

func _ready() -> void:
	super._ready()
	_setup_character_sheet()
	_connect_signals()

func _setup_character_sheet() -> void:
	_setup_equipment_buttons()
	_setup_equipment_popup()
	equipment_popup.hide()

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	var portrait_size = get_viewport_rect().size.y * PORTRAIT_SIZE_RATIO
	portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	
	$Panel/MarginContainer.add_theme_constant_override("margin_left", 10)
	$Panel/MarginContainer.add_theme_constant_override("margin_right", 10)
	
	_adjust_touch_sizes(true)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	portrait.custom_minimum_size = Vector2(300, 300)
	
	$Panel/MarginContainer.add_theme_constant_override("margin_left", 20)
	$Panel/MarginContainer.add_theme_constant_override("margin_right", 20)
	
	_adjust_touch_sizes(false)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height
	
	if equipment_popup.visible:
		var inventory_list = equipment_popup.get_node("MarginContainer/VBoxContainer/InventoryList")
		inventory_list.fixed_item_height = button_height

func _setup_equipment_buttons() -> void:
	var buttons = equipment_section.get_node("WeaponButton")
	buttons.add_to_group("touch_buttons")
	buttons = equipment_section.get_node("ArmorButton")
	buttons.add_to_group("touch_buttons")
	buttons = equipment_section.get_node("GearButton")
	buttons.add_to_group("touch_buttons")

func _setup_equipment_popup() -> void:
	var close_button = equipment_popup.get_node("MarginContainer/VBoxContainer/CloseButton")
	close_button.add_to_group("touch_buttons")

func initialize(char: Character) -> void:
	character = char
	_update_display()
	character.connect("stats_changed", _on_character_stats_changed)
	character.connect("equipment_changed", _on_character_equipment_changed)
	character.connect("traits_changed", _on_character_traits_changed)

func _update_display() -> void:
	if not character:
		return
		
	name_label.text = character.character_name
	_update_portrait()
	_update_stats()
	_update_skills()
	_update_equipment()
	_update_traits()

func _update_portrait() -> void:
	if character.portrait_path:
		var texture = load(character.portrait_path)
		if texture:
			portrait.texture = texture

func _update_stats() -> void:
	for stat in GlobalEnums.CharacterStats.values():
		var stat_label = stats_container.get_node_or_null(str(GlobalEnums.CharacterStats.keys()[stat]) + "Label")
		if stat_label:
			stat_label.text = str(character.stats.get_stat(stat))

func _update_skills() -> void:
	for i in character.skills.size():
		var skill = character.skills[i]
		var skill_label = skills_display.get_node_or_null(str(skill) + "Label")
		if skill_label:
			skill_label.text = str(skill)

func _update_equipment() -> void:
	for child in equipment_section.get_children():
		child.queue_free()
	
	for item in character.equipment:
		var item_label = Label.new()
		item_label.text = item.name
		equipment_section.add_child(item_label)

func _update_traits() -> void:
	for child in equipment_section.get_children():
		child.queue_free()
	
	for current_trait in character.traits:
		var trait_label = Label.new()
		trait_label.text = str(current_trait)
		equipment_section.add_child(trait_label)

func _on_character_stats_changed() -> void:
	_update_stats()
	character_updated.emit(character)

func _on_character_equipment_changed() -> void:
	_update_equipment()
	character_updated.emit(character)

func _on_character_traits_changed() -> void:
	_update_traits()
	character_updated.emit(character)
