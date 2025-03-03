@tool
class_name InitialCrewCreation
extends Control

signal creation_completed(crew_data: Dictionary)
signal creation_cancelled
signal initial_crew_created(crew_data: Dictionary)
signal crew_created(crew_data: Dictionary)

# Constants
const DEBUG := true
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const CharacterStats := preload("res://src/core/character/Base/CharacterStats.gd")
const CharacterTableRoller := preload("res://src/core/character/Generation/CharacterTableRoller.gd")

# References to classes whose files don't exist
# Define simple local classes to use instead of missing preloads
class CrewSystemClass:
	pass

class CrewRelationshipManagerClass:
	pass

const CaptainCreation := preload("res://src/core/campaign/crew/CaptainCreation.gd")
const CrewCreation := preload("res://src/core/campaign/crew/CrewCreation.gd")
const CrewPreviewList := preload("res://src/core/campaign/crew/CrewPreviewList.gd")

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
@onready var crew_preview: CrewPreviewList = $MainContainer/RightPanel/RightVBox/PreviewPanel/PreviewVBox/PreviewScroll/CrewPreview
@onready var confirm_button: Button = $MainContainer/LeftPanel/MainPanel/MainVBox/ConfirmButton
@onready var title_label: Label = $MainContainer/LeftPanel/MainPanel/TitleLabel
@onready var captain_creator: CaptainCreation = $MainContainer/LeftPanel/MainPanel/CaptainCreation
@onready var crew_creator: CrewCreation = $MainContainer/LeftPanel/MainPanel/CrewCreation
@onready var create_captain_button: Button = $MainContainer/RightPanel/RightVBox/CrewCreationPanel/CrewCreationButtons/CreateCaptainButton
@onready var add_crew_member_button: Button = $MainContainer/RightPanel/RightVBox/CrewCreationPanel/CrewCreationButtons/AddCrewMemberButton
@onready var confirm_crew_button: Button = $MainContainer/RightPanel/RightVBox/CrewCreationPanel/CrewCreationButtons/ConfirmCrewButton

# State variables
var crew_system: CrewSystemClass
var campaign_config: Dictionary = {}
var current_crew: Array[Character] = []
var captain: Character
var relationship_manager: CrewRelationshipManagerClass

func _ready() -> void:
	if DEBUG:
		print("[InitialCrewCreation] _ready called")
	
	if not _initialize_systems():
		return
	
	_setup_crew_creation()
	_connect_signals()
	_update_crew_preview()
	_update_button_states()
	_show_initial_guidance()

func _initialize_systems() -> bool:
	crew_system = CrewSystemClass.new()
	relationship_manager = CrewRelationshipManagerClass.new()
	
	add_child(crew_system)
	add_child(relationship_manager)
	
	return true

func _show_initial_guidance() -> void:
	var guidance := """Start by creating your Captain - the most important crew member!

Required crew composition:
•%d Human crew members
• Up to%d Primary Aliens
• Up to%d Bot

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
	
	if config.has("captain"):
		captain = config.captain as Character
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
		slot.pressed.connect(_on_character_slot_pressed.bind(i))
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

func _connect_signals() -> void:
	if captain_creator:
		captain_creator.captain_created.connect(_on_captain_created)
		captain_creator.back_pressed.connect(_on_captain_creation_cancelled)
	
	if crew_creator:
		crew_creator.crew_created.connect(_on_crew_member_created)
		crew_creator.back_pressed.connect(_on_crew_creation_cancelled)
	
	if crew_preview:
		crew_preview.crew_member_selected.connect(_on_crew_member_selected)
	
	if crew_system:
		crew_system.crew_changed.connect(_on_crew_changed)
	
	if relationship_manager:
		relationship_manager.relationship_changed.connect(_on_relationship_changed)

func _update_button_states() -> void:
	if not create_captain_button or not add_crew_member_button or not confirm_crew_button or not confirm_button:
		push_error("Required buttons not found")
		return
		
	var has_captain := captain != null
	create_captain_button.disabled = has_captain
	add_crew_member_button.disabled = not has_captain or current_crew.size() >= campaign_config.get("crew_size", DEFAULT_CREW_SIZE)
	confirm_crew_button.disabled = not _validate_crew()
	confirm_button.disabled = not _validate_crew()

func _on_create_captain_pressed() -> void:
	_debug_log("Create Captain button pressed")
	if captain_creator:
		captain_creator.show()
		crew_creator.hide()
		_handle_scene_transition(true, true)

func _on_captain_created(captain_data: Dictionary) -> void:
	_debug_log("Captain created: " + str(captain_data))
	
	captain = Character.new()
	captain.initialize_from_data(captain_data)
	captain.set_as_captain()
	
	crew_system.set_captain(captain)
	current_crew.append(captain)
	
	_update_crew_preview()
	_update_button_states()
	_handle_scene_transition(false, true)
	_show_info_dialog("Captain created successfully! Now add crew members to complete your team.")

func _on_add_crew_member_pressed() -> void:
	_debug_log("Add Crew Member button pressed")
	if not captain:
		_show_error_dialog("You must create a captain first!")
		return
	
	if current_crew.size() >= campaign_config.get("crew_size", DEFAULT_CREW_SIZE):
		_show_error_dialog("Maximum crew size reached!")
		return
	
	if crew_creator:
		captain_creator.hide()
		crew_creator.show()
		_handle_scene_transition(true)

func _on_crew_member_created(crew_data: Dictionary) -> void:
	_debug_log("Crew member created: " + str(crew_data))
	
	var member := Character.new()
	member.initialize_from_data(crew_data)
	
	if _validate_crew_member(member):
		current_crew.append(member)
		crew_system.add_crew_member(member)
		relationship_manager.add_crew_member(member)
		
		_update_crew_preview()
		_update_button_states()
		_handle_scene_transition(false)
		
		if current_crew.size() < campaign_config.get("crew_size", DEFAULT_CREW_SIZE):
			_show_info_dialog("Crew member added. Add more crew members or confirm your crew.")
		else:
			_show_info_dialog("Maximum crew size reached. Please confirm your crew.")
	else:
		member.free()

func _validate_crew_member(member: Character) -> bool:
	if not member:
		return false
		
	# Check species limits
	var human_count := 0
	var alien_count := 0
	var bot_count := 0
	
	for crew in current_crew:
		match crew.get_species():
			"Human": human_count += 1
			"Bot": bot_count += 1
			_: alien_count += 1
	
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
	
	return true

func _validate_crew() -> bool:
	if current_crew.is_empty():
		return false
	
	var human_count := 0
	var alien_count := 0
	var bot_count := 0
	
	for member in current_crew:
		match member.get_species():
			"Human": human_count += 1
			"Bot": bot_count += 1
			_: alien_count += 1
	
	if human_count < MIN_HUMAN_CREW:
		return false
	
	if alien_count > MAX_PRIMARY_ALIENS:
		return false
	
	if bot_count > MAX_BOTS:
		return false
	
	var required_size := campaign_config.get("crew_size", DEFAULT_CREW_SIZE) as int
	return current_crew.size() == required_size

func _on_confirm_pressed() -> void:
	if not _validate_crew():
		return
	
	var crew_data := {
		"captain": captain,
		"crew_members": current_crew,
		"relationships": relationship_manager.get_relationships()
	}
	
	crew_system.finalize_crew(crew_data)
	creation_completed.emit(crew_data)

func _on_crew_changed(crew_data: Dictionary) -> void:
	_update_crew_preview()
	_update_button_states()

func _on_relationship_changed(_relationship_data: Dictionary) -> void:
	_update_crew_preview()

func _handle_scene_transition(show_creator: bool, is_captain: bool = false) -> void:
	_debug_log("Scene transition - show_creator: " + str(show_creator) + ", is_captain: " + str(is_captain))
	
	if show_creator:
		if is_captain:
			if captain_creator:
				captain_creator.show()
			if crew_creator:
				crew_creator.hide()
		else:
			if captain_creator:
				captain_creator.hide()
			if crew_creator:
				crew_creator.show()
				
		if crew_columns:
			crew_columns.hide()
		if confirm_button:
			confirm_button.hide()
		if title_label:
			title_label.hide()
	else:
		if captain_creator:
			captain_creator.hide()
		if crew_creator:
			crew_creator.hide()
			
		if crew_columns:
			crew_columns.show()
		if confirm_button:
			confirm_button.show()
		if title_label:
			title_label.show()

func _update_crew_preview() -> void:
	if crew_preview:
		crew_preview.update_crew(current_crew)

func _show_error_dialog(message: String) -> void:
	_debug_log("Showing error: " + message)
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Crew Creation Error"
	add_child(dialog)
	dialog.popup_centered()

func _show_info_dialog(message: String) -> void:
	_debug_log("Showing info: " + message)
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Crew Creation"
	add_child(dialog)
	dialog.popup_centered()

func _debug_log(message: String) -> void:
	if DEBUG:
		print("[InitialCrewCreation] " + message)

func _on_character_slot_pressed(slot_index: int) -> void:
	_debug_log("Character slot " + str(slot_index) + " pressed")
	if slot_index < current_crew.size():
		_show_info_dialog("This slot already has a crew member.")
		return
	
	_on_add_crew_member_pressed()

func _on_captain_creation_cancelled() -> void:
	_debug_log("Captain creation cancelled")
	_handle_scene_transition(false, true)

func _on_crew_creation_cancelled() -> void:
	_debug_log("Crew member creation cancelled")
	_handle_scene_transition(false)

func _on_crew_member_selected(index: int) -> void:
	_debug_log("Crew member " + str(index) + " selected")
	if index >= 0 and index < current_crew.size():
		var member := current_crew[index]
		if member:
			_show_info_dialog("Selected crew member: " + member.character_name)
