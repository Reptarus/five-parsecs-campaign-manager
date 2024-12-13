extends Control
class_name CrewManagementUI

var game_state_manager: GameStateManager
var selected_character: Character

@onready var crew_list = $MainLayout/CrewList/VBoxContainer
@onready var character_name_label = $MainLayout/CharacterPanel/CharacterName
@onready var character_portrait = $MainLayout/CharacterPanel/Portrait
@onready var character_info = $MainLayout/CharacterPanel/InfoSection
@onready var equipment_panel = $MainLayout/CharacterPanel/Equipment
@onready var equipment_panel2 = $MainLayout/CharacterPanel/Equipment2
@onready var character_sheet_popup = $CharacterSheetPopup
@onready var relationships_panel := $MainLayout/RelationshipsPanel

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	update_crew_list()
	
	# Connect signals from ShipInventory for equipment updates
	game_state_manager.game_state.current_ship.inventory.item_added.connect(_on_inventory_updated)
	game_state_manager.game_state.current_ship.inventory.item_removed.connect(_on_inventory_updated)
	game_state_manager.game_state.current_crew.relationships_updated.connect(_on_relationships_updated)

func update_crew_list() -> void:
	for child in crew_list.get_children():
		child.queue_free()
	
	var crew = game_state_manager.game_state.current_crew.members
	for member in crew:
		var crew_button = create_crew_button(member)
		crew_list.add_child(crew_button)
		
	if relationships_panel:
		relationships_panel.initialize(crew)

func create_crew_button(character: Character) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(200, 60)
	button.text = "%s\n%s %s" % [character.name, character.origin, character.class_type]
	button.pressed.connect(_on_crew_button_pressed.bind(character))
	return button

func _on_crew_button_pressed(character: Character) -> void:
	selected_character = character
	update_character_display()

func update_character_display() -> void:
	if !selected_character:
		return
		
	character_name_label.text = selected_character.name
	character_portrait.texture = selected_character.portrait
	
	# Update basic info using Core Rules stats
	var info_text = """
	ORIGIN: %s
	BACKGROUND: %s
	MOTIVATION: %s
	CLASS: %s
	
	STATS:
	Reactions: %d
	Speed: %d
	Combat Skill: %+d
	Toughness: %d
	Savvy: %+d
	Luck: %d
	""" % [
		GlobalEnums.Origin.keys()[selected_character.origin],
		selected_character.background,
		selected_character.motivation,
		GlobalEnums.CharacterClass.keys()[selected_character.class_type],
		selected_character.stats.reactions,
		selected_character.stats.speed,
		selected_character.stats.combat_skill,
		selected_character.stats.toughness,
		selected_character.stats.savvy,
		selected_character.stats.luck
	]
	character_info.text = info_text
	
	# Update equipment displays
	update_equipment_display()

func _on_character_sheet_button_pressed() -> void:
	if selected_character:
		character_sheet_popup.set_character(selected_character)
		character_sheet_popup.popup_centered()

func update_equipment_display() -> void:
	# Clear existing equipment displays
	for child in equipment_panel.get_children():
		child.queue_free()
	for child in equipment_panel2.get_children():
		child.queue_free()
		
	if selected_character:
		var equipment_text = ""
		
		# Display weapon if equipped
		if selected_character.equipped_weapon:
			equipment_text += "Weapon: " + selected_character.equipped_weapon.name + "\n"
		
		# Display gear
		if not selected_character.equipped_gear.is_empty():
			equipment_text += "\nGear:\n"
			for gear in selected_character.equipped_gear:
				equipment_text += "- " + gear.name + "\n"
		
		# Display gadgets
		if not selected_character.equipped_gadgets.is_empty():
			equipment_text += "\nGadget:\n"
			for gadget in selected_character.equipped_gadgets:
				equipment_text += "- " + gadget.name + "\n"
		
		var equipment_label = Label.new()
		equipment_label.text = equipment_text
		equipment_panel.add_child(equipment_label)
		
		# Display armor if equipped
		if selected_character.equipped_armor:
			var armor_label = Label.new()
			armor_label.text = selected_character.equipped_armor.name
			equipment_panel2.add_child(armor_label)

func _on_inventory_updated(_item: Equipment) -> void:
	if selected_character:
		update_equipment_display()

func _on_relationships_updated() -> void:
	if relationships_panel:
		relationships_panel.initialize(game_state_manager.game_state.current_crew.members)
