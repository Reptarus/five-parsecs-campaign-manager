@tool
class_name InitialCrewCreation
extends Control

signal creation_completed(crew_data: Dictionary)
signal creation_cancelled

# Constants
const DEBUG := true
const Character := preload("res://src/core/character/Base/Character.gd")
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")
const CrewSystem := preload("res://src/data/resources/Campaign/Crew/CrewSystem.gd")
const CharacterCreator := preload("res://src/core/character/Generation/CharacterCreator.gd")
const CaptainCreationScene := preload("res://src/data/resources/CrewAndCharacters/Scenes/CaptainCreation.tscn")

# Crew composition limits
const MIN_HUMAN_CREW := 3
const MAX_PRIMARY_ALIENS := 2
const MAX_BOTS := 1
const DEFAULT_CREW_SIZE := 4

# Stat limits
const MIN_REACTIONS := 1
const MAX_REACTIONS := 6
const MIN_SPEED := 4
const MAX_SPEED := 8
const MIN_COMBAT_SKILL := 0
const MAX_COMBAT_SKILL := 3
const MIN_TOUGHNESS := 3
const MAX_TOUGHNESS := 6
const MIN_SAVVY := 0
const MAX_SAVVY := 3

# UI References
@onready var crew_columns: Container = $MainContainer/LeftPanel/MainPanel/MainVBox/CharacterColumns
@onready var crew_preview: Node = $MainContainer/RightPanel/RightVBox/PreviewPanel/PreviewVBox/PreviewScroll/CrewPreview
@onready var confirm_button: Button = $MainContainer/LeftPanel/MainPanel/MainVBox/ConfirmButton
@onready var title_label: Label = $MainContainer/LeftPanel/MainPanel/TitleLabel
@onready var character_creator: Node = $MainContainer/LeftPanel/MainPanel/CharacterCreator
@onready var create_captain_button: Button = $MainContainer/RightPanel/RightVBox/CrewCreationPanel/CrewCreationButtons/CreateCaptainButton
@onready var add_crew_member_button: Button = $MainContainer/RightPanel/RightVBox/CrewCreationPanel/CrewCreationButtons/AddCrewMemberButton
@onready var confirm_crew_button: Button = $MainContainer/RightPanel/RightVBox/CrewCreationPanel/CrewCreationButtons/ConfirmCrewButton

# State variables
var crew_system: CrewSystem
var campaign_config: Dictionary = {}
var crew_slots: Array[Node] = []
var current_crew: Array[Character] = []
var captain: Character
var captain_creator: Node

func _print_node_tree(node: Node, indent: String = "") -> void:
	if not DEBUG:
		return
		
	var visibility_str := ""
	if node is Window:
		visibility_str = str(node.visible)
	elif node is CanvasItem:
		visibility_str = str(node.is_visible_in_tree())
	else:
		visibility_str = "N/A"
		
	print(indent + node.name + " (Visible: " + visibility_str + ") [" + node.get_class() + "]")
	
	# Skip certain node types that might cause issues
	if node is Window and node.get_class() == "FileDialog":
		return
		
	for child in node.get_children():
		_print_node_tree(child, indent + "  ")

func _ready() -> void:
	if DEBUG:
		print("[InitialCrewCreation] _ready called")
		print("[InitialCrewCreation] Node tree structure:")
		_print_node_tree(self)
	
	if not _initialize_game_state():
		return
	
	_setup_crew_creation()
	_connect_signals()
	_update_crew_preview()
	_update_button_states()
	_show_initial_guidance()

func _initialize_game_state() -> bool:
	var game_state_manager := get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found")
		return false
		
	var game_state = game_state_manager.get_game_state()
	if not game_state:
		game_state = game_state_manager.create_new_game_state()
		if not game_state:
			push_error("Failed to create new game state")
			return false
	
	crew_system = CrewSystem.new()
	crew_system.initialize(game_state)
	return true

func _show_initial_guidance() -> void:
	var guidance := """Start by creating your Captain - the most important crew member!

Required crew composition:
• %d Human crew members
• Up to %d Primary Aliens
• Up to %d Bot

Your captain leads your crew in combat, makes key decisions, and cannot be lost through events.""" % [
		MIN_HUMAN_CREW,
		MAX_PRIMARY_ALIENS,
		MAX_BOTS
	]
	_show_info_dialog(guidance)

func initialize(config: Dictionary) -> void:
	campaign_config = config
	var crew_size := config.get("crew_size", DEFAULT_CREW_SIZE) as int
	crew_system.set_max_crew_size(crew_size)
	
	captain = config.get("captain") as Character
	if captain:
		current_crew.append(captain)
		_update_crew_preview()
		_update_button_states()

func _setup_crew_creation() -> void:
	_setup_character_slots()
	_setup_buttons()
	_update_crew_preview()
	_update_button_states()

func _setup_character_slots() -> void:
	var slot_count := campaign_config.get("crew_size", DEFAULT_CREW_SIZE) as int
	for i in range(slot_count):
		var slot := Button.new()
		slot.text = "Add Crew Member"
		slot.pressed.connect(_on_character_box_pressed.bind(slot))
		crew_slots.append(slot)
		crew_columns.add_child(slot)

func _setup_buttons() -> void:
	if not create_captain_button or not add_crew_member_button or not confirm_crew_button or not confirm_button:
		push_error("Required buttons not found")
		return
		
	create_captain_button.pressed.connect(_on_create_captain_pressed)
	add_crew_member_button.pressed.connect(_on_add_crew_member_pressed)
	confirm_crew_button.pressed.connect(_on_confirm_pressed)
	confirm_button.add_to_group("touch_buttons")
	confirm_button.pressed.connect(_on_confirm_pressed)

func _update_button_states() -> void:
	if not create_captain_button or not add_crew_member_button or not confirm_crew_button or not confirm_button:
		push_error("Required buttons not found")
		return
		
	var has_captain := captain != null
	create_captain_button.disabled = has_captain
	add_crew_member_button.disabled = not has_captain
	confirm_crew_button.disabled = not _validate_crew()
	confirm_button.disabled = not _validate_crew()

func _on_create_captain_pressed() -> void:
	_debug_log("Create Captain button pressed")
	
	if captain_creator:
		captain_creator.queue_free()
	
	captain_creator = CaptainCreationScene.instantiate()
	if not captain_creator:
		push_error("Failed to instantiate CaptainCreation scene")
		return
	
	captain_creator.visible = false
	$MainContainer/LeftPanel/MainPanel.add_child(captain_creator)
	
	if not captain_creator.captain_created.is_connected(_on_captain_created):
		captain_creator.captain_created.connect(_on_captain_created)
	if not captain_creator.back_pressed.is_connected(_on_captain_creation_cancelled):
		captain_creator.back_pressed.connect(_on_captain_creation_cancelled)
	
	_handle_scene_transition(true, true)

func _on_captain_created(new_captain: Character) -> void:
	if not new_captain:
		push_error("Received null captain")
		return
		
	_debug_log("Captain created: " + new_captain.character_name)
	
	captain = new_captain
	
	var game_state_manager := get_node("/root/GameStateManager")
	if game_state_manager:
		var game_state = game_state_manager.get_game_state()
		if game_state:
			game_state.set_captain(captain)
	
	if not current_crew.has(captain):
		current_crew.append(captain)
	
	_update_crew_preview()
	_update_button_states()
	_handle_scene_transition(false, true)
	_show_info_dialog("Captain created successfully! Now add crew members to complete your team.")

func _on_captain_creation_cancelled() -> void:
	_handle_scene_transition(false, true)

func _on_add_crew_member_pressed() -> void:
	_debug_log("Add Crew Member button pressed")
	if not captain:
		_show_error_dialog("You must create a captain first!")
		return
	
	var max_crew_size := campaign_config.get("crew_size", DEFAULT_CREW_SIZE) as int
	if current_crew.size() >= max_crew_size:
		_show_error_dialog("Maximum crew size reached!")
		return
	
	if not character_creator:
		push_error("Character creator not found")
		return
		
	character_creator.initialize(CharacterCreator.CreatorMode.INITIAL_CREW, self)
	_handle_scene_transition(true)

func _on_character_box_pressed(box: Button) -> void:
	_debug_log("Character box pressed")
	var slot_index := crew_slots.find(box)
	if slot_index == -1:
		push_error("Invalid character slot")
		return
	
	if not character_creator:
		push_error("Character creator not found")
		return
	
	if slot_index < current_crew.size():
		var character := current_crew[slot_index]
		_debug_log("Editing existing character at slot " + str(slot_index))
		character_creator.edit_character(character)
	else:
		_debug_log("Creating new character for slot " + str(slot_index))
		character_creator.initialize(CharacterCreator.CreatorMode.INITIAL_CREW, self)
	
	_debug_log("Transitioning to CharacterCreator")
	_handle_scene_transition(true)

func _handle_scene_transition(show_creator: bool, is_captain: bool = false) -> void:
	_debug_log("Scene transition - show_creator: " + str(show_creator) + ", is_captain: " + str(is_captain))
	
	if show_creator:
		if is_captain:
			if captain_creator:
				captain_creator.visible = true
				captain_creator.show()
			if character_creator:
				character_creator.visible = false
				character_creator.hide()
		else:
			if captain_creator:
				captain_creator.visible = false
				captain_creator.hide()
			if character_creator:
				character_creator.visible = true
				character_creator.show()
				
		if crew_columns:
			crew_columns.visible = false
		if confirm_button:
			confirm_button.visible = false
		if title_label:
			title_label.visible = false
	else:
		if captain_creator:
			captain_creator.visible = false
		if character_creator:
			character_creator.visible = false
			
		if crew_columns:
			crew_columns.visible = true
		if confirm_button:
			confirm_button.visible = true
		if title_label:
			title_label.visible = true
			
	# Force update visibility
	if captain_creator:
		captain_creator.process_mode = Node.PROCESS_MODE_INHERIT if show_creator and is_captain else Node.PROCESS_MODE_DISABLED
	if character_creator:
		character_creator.process_mode = Node.PROCESS_MODE_INHERIT if show_creator and not is_captain else Node.PROCESS_MODE_DISABLED

func _update_crew_preview() -> void:
	if crew_preview:
		crew_preview.update_crew(current_crew)
	_validate_crew()
	_update_title()
	_update_button_states()

func _update_title() -> void:
	if title_label:
		title_label.text = "Initial Crew Creation"

func _validate_character_stats(character: Character) -> bool:
	if not character or not character.stats:
		return false
		
	var stats = character.stats
	
	# Validate stat ranges
	if stats.reactions < MIN_REACTIONS or stats.reactions > MAX_REACTIONS:
		_show_error_dialog("Invalid Reactions value for %s. Must be between %d and %d." % [character.character_name, MIN_REACTIONS, MAX_REACTIONS])
		return false
		
	if stats.speed < MIN_SPEED or stats.speed > MAX_SPEED:
		_show_error_dialog("Invalid Speed value for %s. Must be between %d\" and %d\"." % [character.character_name, MIN_SPEED, MAX_SPEED])
		return false
		
	if stats.combat_skill < MIN_COMBAT_SKILL or stats.combat_skill > MAX_COMBAT_SKILL:
		_show_error_dialog("Invalid Combat Skill value for %s. Must be between +%d and +%d." % [character.character_name, MIN_COMBAT_SKILL, MAX_COMBAT_SKILL])
		return false
		
	if stats.toughness < MIN_TOUGHNESS or stats.toughness > MAX_TOUGHNESS:
		_show_error_dialog("Invalid Toughness value for %s. Must be between %d and %d." % [character.character_name, MIN_TOUGHNESS, MAX_TOUGHNESS])
		return false
		
	if stats.savvy < MIN_SAVVY or stats.savvy > MAX_SAVVY:
		_show_error_dialog("Invalid Savvy value for %s. Must be between +%d and +%d." % [character.character_name, MIN_SAVVY, MAX_SAVVY])
		return false
		
	# Check required fields
	if character.character_name.is_empty():
		_show_error_dialog("Character name is required.")
		return false
		
	# Get background and motivation as strings
	var background := character.get_background() as String
	var motivation := character.get_motivation() as String
	
	if background.is_empty():
		_show_error_dialog("Character background is required.")
		return false
		
	if motivation.is_empty():
		_show_error_dialog("Character motivation is required.")
		return false
		
	# Check equipment
	if not character.equipped_weapon:
		_show_error_dialog("Character must have a weapon equipped.")
		return false
		
	return true

func _validate_crew() -> bool:
	if current_crew.is_empty():
		return false
		
	var human_count := 0
	var alien_count := 0
	var bot_count := 0
	
	for member in current_crew:
		if not member:
			continue
			
		if not _validate_character_stats(member):
			return false
			
		match member.get_species():
			"Human": human_count += 1
			"Bot": bot_count += 1
			_: alien_count += 1
	
	if human_count < MIN_HUMAN_CREW:
		_show_error_dialog("You need at least %d Human crew members." % MIN_HUMAN_CREW)
		return false
		
	if alien_count > MAX_PRIMARY_ALIENS:
		_show_error_dialog("You can have at most %d Primary Aliens." % MAX_PRIMARY_ALIENS)
		return false
		
	if bot_count > MAX_BOTS:
		_show_error_dialog("You can have at most %d Bot." % MAX_BOTS)
		return false
		
	var required_size := campaign_config.get("crew_size", DEFAULT_CREW_SIZE) as int
	var current_size := current_crew.size()
	
	if current_size < required_size:
		_show_error_dialog("You need %d crew members. Currently have %d." % [required_size, current_size])
		return false
		
	if current_size > required_size:
		_show_error_dialog("You have too many crew members. Maximum is %d." % required_size)
		return false
	
	return true

func _show_error_dialog(message: String) -> void:
	_debug_log("Showing error: " + message)
	_show_dialog("Crew Creation Error", message)

func _show_info_dialog(message: String) -> void:
	_debug_log("Showing info: " + message)
	_show_dialog("Crew Creation", message)

func _show_dialog(title: String, message: String) -> void:
	for child in get_children():
		if child is AcceptDialog:
			child.queue_free()
	
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = title
	add_child(dialog)
	dialog.popup_centered()

func _on_confirm_pressed() -> void:
	if not _validate_crew():
		return
		
	var game_state_manager := get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found")
		return
		
	var game_state = game_state_manager.get_game_state()
	if game_state:
		for member in current_crew:
			game_state.add_crew_member(member)
		get_tree().change_scene_to_file("res://src/data/resources/CampaignManagement/CampaignSetup.tscn")
	else:
		push_error("GameState not found when trying to save crew")

func _on_cancel_pressed() -> void:
	creation_cancelled.emit()

func _connect_signals() -> void:
	if character_creator:
		if not character_creator.character_created.is_connected(_on_character_created):
			character_creator.character_created.connect(_on_character_created)
		if not character_creator.character_edited.is_connected(_on_character_edited):
			character_creator.character_edited.connect(_on_character_edited)
		if not character_creator.back_pressed.is_connected(_on_creator_back_pressed):
			character_creator.back_pressed.connect(_on_creator_back_pressed)
	
	if crew_preview:
		if not crew_preview.crew_member_selected.is_connected(_on_crew_member_selected):
			crew_preview.crew_member_selected.connect(_on_crew_member_selected)

func _on_creator_back_pressed() -> void:
	_debug_log("Back button pressed in CharacterCreator")
	_handle_scene_transition(false)

func _on_character_created(character: Character) -> void:
	_debug_log("Character created signal received")
	if not character:
		push_error("Received null character")
		return
		
	if not _validate_character_stats(character):
		_debug_log("Character validation failed")
		return
	
	if not captain:
		captain = character
		current_crew.append(captain)
		_update_crew_preview()
		_debug_log("Captain added to crew")
		
		var dialog := AcceptDialog.new()
		dialog.title = "Captain Created"
		dialog.dialog_text = "Captain has been created. You can now add crew members."
		add_child(dialog)
		dialog.popup_centered()
		_handle_scene_transition(false)
	else:
		var slot_index := current_crew.size()
		if slot_index < crew_slots.size():
			current_crew.append(character)
			_update_crew_preview()
			_debug_log("Character added to crew at slot " + str(slot_index))
			
			var dialog := ConfirmationDialog.new()
			dialog.title = "Character Added"
			dialog.dialog_text = "Character has been added to your crew. Would you like to create another character?"
			dialog.get_ok_button().text = "Create Another"
			dialog.get_cancel_button().text = "Back to Crew"
			add_child(dialog)
			
			dialog.confirmed.connect(func():
				dialog.queue_free()
				if slot_index + 1 < crew_slots.size():
					_on_character_box_pressed(crew_slots[slot_index + 1])
			)
			dialog.canceled.connect(func():
				dialog.queue_free()
				_handle_scene_transition(false)
			)
			
			dialog.popup_centered()
		else:
			_debug_log("No available slot for new character")
			_handle_scene_transition(false)

func _on_character_edited(character: Character) -> void:
	_debug_log("Character edited signal received")
	if not character:
		push_error("Received null character")
		return
		
	var index := current_crew.find(character)
	if index != -1:
		current_crew[index] = character
		_update_crew_preview()
		_handle_scene_transition(false)
	else:
		push_error("Edited character not found in crew")

func _on_crew_member_selected(index: int) -> void:
	if index >= 0 and index < current_crew.size():
		var character := current_crew[index]
		if character and character_creator:
			character_creator.edit_character(character)
			_handle_scene_transition(true)

func _debug_log(message: String) -> void:
	if DEBUG:
		print("[InitialCrewCreation] " + message)
