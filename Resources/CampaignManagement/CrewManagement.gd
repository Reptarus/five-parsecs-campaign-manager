extends Control

var game_state_manager: GameStateManager
var selected_character: Character

@onready var crew_list = $MainLayout/CrewList/VBoxContainer
@onready var character_name_label = $MainLayout/CharacterPanel/CharacterName
@onready var character_portrait = $MainLayout/CharacterPanel/Portrait
@onready var character_info = $MainLayout/CharacterPanel/InfoSection
@onready var equipment_panel = $MainLayout/CharacterPanel/Equipment
@onready var equipment_panel2 = $MainLayout/CharacterPanel/Equipment2
@onready var character_sheet_popup = $CharacterSheetPopup

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	update_crew_list()
	
	# Connect signals from ShipInventory for equipment updates
	game_state_manager.game_state.current_ship.inventory.item_added.connect(_on_inventory_updated)
	game_state_manager.game_state.current_ship.inventory.item_removed.connect(_on_inventory_updated)

func update_crew_list() -> void:
	for child in crew_list.get_children():
		child.queue_free()
	
	var crew = game_state_manager.game_state.current_crew.members
	for member in crew:
		var crew_button = create_crew_button(member)
		crew_list.add_child(crew_button)

func create_crew_button(character: Character) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(200, 60)
	button.text = "%s\n%s %s" % [character.name, character.species, character.class_type]
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
	
	# Update basic info
	var info_text = """
	SPECIES: %s
	BACKGROUND: %s
	MOTIVATION: %s
	CLASS: %s
	""" % [selected_character.species, selected_character.background, 
		   selected_character.motivation, selected_character.class_type]
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
		# Display current equipment
		if selected_character.equipped_weapon:
			var weapon_label = Label.new()
			weapon_label.text = selected_character.equipped_weapon.name
			equipment_panel.add_child(weapon_label)
			
		if selected_character.equipped_armor:
			var armor_label = Label.new()
			armor_label.text = selected_character.equipped_armor.name
			equipment_panel2.add_child(armor_label)

func _on_inventory_updated(_item: Equipment) -> void:
	if selected_character:
		update_equipment_display()

func update_character_info(character: Character) -> void:
	# Updated to use new enums
	var species_text = GlobalEnums.Species.keys()[character.species]
	var class_text = GlobalEnums.Class.keys()[character.class_type]
	# ... rest of the function
