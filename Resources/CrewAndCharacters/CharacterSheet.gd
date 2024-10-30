extends Control

@onready var name_label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var stats_display = $Panel/MarginContainer/VBoxContainer/StatsDisplay
@onready var traits_display = $Panel/MarginContainer/VBoxContainer/TraitsDisplay
@onready var equipment_list = $Panel/MarginContainer/VBoxContainer/EquipmentList
@onready var xp_label = $Panel/MarginContainer/VBoxContainer/XPLabel
@onready var medbay_status = $Panel/MarginContainer/VBoxContainer/MedbayStatus
@onready var background_label = $Panel/MarginContainer/VBoxContainer/BackgroundLabel
@onready var class_label = $Panel/MarginContainer/VBoxContainer/ClassLabel
@onready var motivation_label = $Panel/MarginContainer/VBoxContainer/MotivationLabel
@onready var equipment_popup = $EquipmentPopup
@onready var weapon_button = $Panel/MarginContainer/VBoxContainer/EquipmentSection/WeaponButton
@onready var armor_button = $Panel/MarginContainer/VBoxContainer/EquipmentSection/ArmorButton
@onready var gear_button = $Panel/MarginContainer/VBoxContainer/EquipmentSection/GearButton
@onready var inventory_list = $EquipmentPopup/MarginContainer/VBoxContainer/InventoryList
@onready var mission_history_list = $Panel/MarginContainer/VBoxContainer/MissionHistorySection/MissionList
@onready var training_section = $Panel/MarginContainer/VBoxContainer/TrainingSection
@onready var available_courses_list = $Panel/MarginContainer/VBoxContainer/TrainingSection/AvailableCourses
@onready var event_history = $Panel/MarginContainer/VBoxContainer/EventHistorySection/EventList

var character: Character
var ship_inventory: ShipInventory
var equipment_manager: EquipmentManager

func _ready() -> void:
	equipment_manager = get_node("/root/GameStateManager").equipment_manager
	ship_inventory = get_node("/root/GameStateManager").game_state.current_ship.inventory
	
	# Connect signals
	ship_inventory.item_added.connect(_on_inventory_updated)
	ship_inventory.item_removed.connect(_on_inventory_updated)

func set_character(new_character: Character) -> void:
	character = new_character
	update_display()

func update_display():
	name_label.text = character.name
	stats_display.text = """
	Reactions: %d
	Speed: %d
	Combat Skill: %d
	Toughness: %d
	Savvy: %d
	Luck: %d
	""" % [
		character.reactions,
		character.speed,
		character.combat_skill,
		character.toughness,
		character.savvy,
		character.luck
	]
	
	xp_label.text = "XP: %d" % character.xp
	
	traits_display.text = "Traits: " + ", ".join(character.traits)
	
	equipment_list.clear()
	if character.equipped_weapon:
		equipment_list.add_item("Weapon: " + character.equipped_weapon.name)
	for item in character.equipped_items:
		equipment_list.add_item(item.name)
	
	medbay_status.text = "In Medbay: %s (%d turns left)" % ["Yes" if character.is_in_medbay() else "No", character.medbay_turns_left]
	
	background_label.text = "Background: " + GlobalEnums.Background.keys()[character.background]
	class_label.text = "Class: " + GlobalEnums.Class.keys()[character.character_class]
	motivation_label.text = "Motivation: " + GlobalEnums.Motivation.keys()[character.motivation]
	update_mission_history()
	update_training_options()
	update_event_history()

func _on_close_button_pressed():
	queue_free()

func _on_weapon_button_pressed() -> void:
	show_equipment_popup(GlobalEnums.ItemType.WEAPON)

func _on_armor_button_pressed() -> void:
	show_equipment_popup(GlobalEnums.ItemType.ARMOR)

func _on_gear_button_pressed() -> void:
	show_equipment_popup(GlobalEnums.ItemType.GEAR)

func show_equipment_popup(type: GlobalEnums.ItemType) -> void:
	inventory_list.clear()
	var available_items = ship_inventory.get_items_by_type(type)
	
	for item in available_items:
		inventory_list.add_item(item.name, null, true)
	
	equipment_popup.popup_centered()
	equipment_popup.current_type = type

func _on_inventory_item_selected(index: int) -> void:
	var type = equipment_popup.current_type
	var available_items = ship_inventory.get_items_by_type(type)
	var selected_item = available_items[index]
	
	# Remove currently equipped item and add to ship inventory
	match type:
		GlobalEnums.ItemType.WEAPON:
			if character.equipped_weapon:
				ship_inventory.add_item(character.equipped_weapon)
			character.equipped_weapon = selected_item
		GlobalEnums.ItemType.ARMOR:
			if character.equipped_armor:
				ship_inventory.add_item(character.equipped_armor)
			character.equipped_armor = selected_item
		GlobalEnums.ItemType.GEAR:
			# Handle gear equipping logic
			pass
	
	ship_inventory.remove_item(selected_item)
	equipment_popup.hide()
	update_display()

func update_mission_history() -> void:
	mission_history_list.clear()
	var missions = character.get_mission_history()
	for mission in missions:
		var text = "%s - %s (%s)" % [
			mission.date,
			mission.name,
			"Success" if mission.success else "Failure"
		]
		mission_history_list.add_item(text)

func update_training_options() -> void:
	available_courses_list.clear()
	var adv_training_manager = AdvTrainingManager.new(game_state_manager.game_state)
	var available_courses = adv_training_manager.get_available_courses(character)
	
	for course in available_courses:
		var text = "%s - %d credits" % [course.name, course.cost]
		available_courses_list.add_item(text)

func _on_enroll_pressed() -> void:
	var selected_idx = available_courses_list.get_selected_items()[0]
	var course = available_courses_list.get_item_text(selected_idx)
	var adv_training_manager = AdvTrainingManager.new(game_state_manager.game_state)
	
	if adv_training_manager.apply_for_training(character, course):
		if adv_training_manager.enroll_in_course(character, course):
			update_display()
		else:
			game_state_manager.ui_manager.show_message("Not enough credits for training")
	else:
		game_state_manager.ui_manager.show_message("Application rejected")

func update_event_history() -> void:
	event_history.clear()
	var events = character.get_event_history()
	for event in events:
		var text = "%s - %s" % [event.date, event.description]
		event_history.add_item(text)
