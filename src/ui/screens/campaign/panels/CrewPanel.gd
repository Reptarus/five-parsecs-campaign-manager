extends FiveParsecsCampaignPanel

# Enhanced CrewPanel with Coordinator Pattern for campaign creation
# Extends FiveParsecsCampaignPanel for standardized interface and enhanced functionality
# Implements autonomous operation with self-management capabilities

# Import base crew component functionality
const BaseCrewComponent = preload("res://src/base/ui/BaseCrewComponent.gd")

# Security validation integration
const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")

# Character creator integration
const CharacterCreatorClass = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")

# ValidationResult is inherited from BaseCampaignPanel

# Existing signals for backward compatibility
signal crew_setup_complete(crew_data: Dictionary)
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Dictionary)

# New autonomous signals for coordinator pattern
signal crew_data_complete(data: Dictionary)
signal crew_validation_failed(errors: Array[String])

# Additional crew-specific signals
signal crew_updated(crew: Array)
signal crew_member_selected(member: Character)

# Granular signals for real-time integration
signal crew_member_added(member_data: Dictionary)
signal crew_composition_changed(composition: Array)

# Enhanced state management and validation logic
var local_crew_data: Dictionary = {
	"members": [],
	"captain": null,
	"is_complete": false
}

# Base crew component properties
var crew_members: Array[Character] = []
var current_captain: Character = null
const Character = preload("res://src/core/character/Character.gd")
const MIN_CREW_SIZE: int = 1
const MAX_CREW_SIZE: int = 8

# Panel state management - production-ready pattern
var is_panel_initialized: bool = false
var is_crew_complete: bool = false
var last_validation_errors: Array[String] = []

# Panel lifecycle signals - Framework Bible compliant
signal panel_data_updated(data: Dictionary)


# UI Components - using safe access pattern
var crew_size_option: OptionButton
var crew_list: ItemList
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

# UI component references for new standardized structure - using safe node access
@onready var content_area: VBoxContainer = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
@onready var crew_container: VBoxContainer = get_node_or_null("CrewContainer")
@onready var crew_summary: Label = get_node_or_null("CrewSummary")
@onready var instructions_label: Label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Instructions")
@onready var crew_size_option_node: OptionButton = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewSizeSection/CrewSizeOption")
@onready var crew_list_node: ItemList = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewList")
@onready var add_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/AddButton")
@onready var edit_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/EditButton")
@onready var remove_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/RemoveButton")
@onready var randomize_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/RandomizeButton")
@onready var validation_panel: PanelContainer = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewValidationPanel")
@onready var validation_icon: Label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewValidationPanel/ValidationContent/ValidationIcon")
@onready var validation_text: Label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewValidationPanel/ValidationContent/ValidationText")

# Character creator integration
var character_creator: SimpleCharacterCreator

var selected_size: int = 4

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("crew") and state_data.crew is Dictionary:
		var crew_data = state_data.crew
		if crew_data.has("members"):
			# Update local crew state from external changes
			local_crew_data.members = crew_data.members
			_update_crew_display()

func _ready() -> void:
	# Set panel info before base initialization
	set_panel_info("Crew Setup", "Set up your initial crew members. Each member will have unique backgrounds, motivations, and attributes.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# Initialize crew-specific functionality
	_initialize_self_management()
	print("CrewPanel: Starting enhanced initialization with coordinator pattern...")
	call_deferred("_initialize_panel")
	# Connect to the crew_updated signal
	if not crew_updated.is_connected(_on_local_crew_updated):
		crew_updated.connect(_on_local_crew_updated)

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup crew-specific content"""
	# Assign UI component references from scene nodes
	crew_size_option = crew_size_option_node if crew_size_option_node else null
	crew_list = crew_list_node if crew_list_node else null
	add_button = add_button_node if add_button_node else null
	edit_button = edit_button_node if edit_button_node else null
	remove_button = remove_button_node if remove_button_node else null
	randomize_button = randomize_button_node if randomize_button_node else null

func _initialize_self_management() -> void:
	"""Initialize state management and validation components"""
	# Create security validator for input sanitization
	security_validator = _validate_simple_input()
	
	# Initialize character creator
	character_creator = get_node_or_null("CharacterCreator")
	if not character_creator:
		print("CrewPanel: CharacterCreator not found, creating instance")
		character_creator = CharacterCreatorClass.new()
		if character_creator:
			add_child(character_creator)
			character_creator.name = "CharacterCreator"
			character_creator.visible = false
			print("CrewPanel: CharacterCreator instance created successfully")
		else:
			push_warning("CrewPanel: Failed to create CharacterCreator instance")
	else:
		print("CrewPanel: CharacterCreator found in scene")
		character_creator.visible = false

func _initialize_panel() -> void:
	"""Initialize the crew panel with fallback UI creation"""
	# Create basic UI structure if not found in scene
	_setup_fallback_ui()
	
	# Setup crew size options
	_setup_crew_size_options()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Generate initial crew
	_generate_initial_crew()
	
	# Update display
	_update_crew_display()
	
	print("CrewPanel: Enhanced initialization complete with coordinator pattern")
	
	# Emit panel ready signal after full initialization
	call_deferred("_emit_panel_ready")

func _setup_fallback_ui() -> void:
	"""Create basic UI structure if scene doesn't provide it"""
	print("CrewPanel: Setting up fallback UI - crew_container exists: ", crew_container != null)
	
	if not crew_container:
		# Create a basic container structure
		var content = VBoxContainer.new()
		content.name = "Content"
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(content)
		
		# Instructions
		instructions_label = Label.new()
		instructions_label.name = "Instructions"
		instructions_label.text = "Select your crew size and customize your crew members. One member will be designated as captain."
		instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instructions_label.add_theme_font_size_override("font_size", 14)
		content.add_child(instructions_label)
		
		# Add spacing
		var spacer1 = Control.new()
		spacer1.custom_minimum_size.y = 10
		content.add_child(spacer1)
		
		# Crew size selection
		var size_container = HBoxContainer.new()
		content.add_child(size_container)
		
		var size_label = Label.new()
		size_label.text = "Crew Size:"
		size_label.custom_minimum_size.x = 100
		size_container.add_child(size_label)
		
		crew_size_option = OptionButton.new()
		crew_size_option.name = "CrewSizeOption"
		crew_size_option.custom_minimum_size.x = 150
		size_container.add_child(crew_size_option)
		
		# Add spacing
		var spacer2 = Control.new()
		spacer2.custom_minimum_size.y = 10
		content.add_child(spacer2)
		
		# Crew list with better styling
		crew_list = ItemList.new()
		crew_list.name = "CrewList"
		crew_list.custom_minimum_size = Vector2(500, 200)
		crew_list.select_mode = ItemList.SELECT_SINGLE
		content.add_child(crew_list)
		
		# Add spacing
		var spacer3 = Control.new()
		spacer3.custom_minimum_size.y = 10
		content.add_child(spacer3)
		
		# Summary
		crew_summary = Label.new()
		crew_summary.name = "CrewSummary"
		crew_summary.text = "Crew: 0 members"
		crew_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crew_summary.add_theme_font_size_override("font_size", 12)
		content.add_child(crew_summary)
		
		# Add spacing
		var spacer4 = Control.new()
		spacer4.custom_minimum_size.y = 15
		content.add_child(spacer4)
		
		# Buttons with better layout
		var button_container = HBoxContainer.new()
		button_container.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(button_container)
		
		add_button = Button.new()
		add_button.text = "Add Member"
		add_button.name = "AddButton"
		add_button.custom_minimum_size.x = 100
		button_container.add_child(add_button)
		
		# Button spacing
		var button_spacer1 = Control.new()
		button_spacer1.custom_minimum_size.x = 10
		button_container.add_child(button_spacer1)
		
		edit_button = Button.new()
		edit_button.text = "Edit Selected"
		edit_button.name = "EditButton"
		edit_button.disabled = true
		edit_button.custom_minimum_size.x = 100
		button_container.add_child(edit_button)
		
		# Button spacing
		var button_spacer2 = Control.new()
		button_spacer2.custom_minimum_size.x = 10
		button_container.add_child(button_spacer2)
		
		remove_button = Button.new()
		remove_button.text = "Remove Selected"
		remove_button.name = "RemoveButton"
		remove_button.disabled = true
		remove_button.custom_minimum_size.x = 120
		button_container.add_child(remove_button)
		
		# Button spacing
		var button_spacer3 = Control.new()
		button_spacer3.custom_minimum_size.x = 10
		button_container.add_child(button_spacer3)
		
		randomize_button = Button.new()
		randomize_button.text = "Randomize All"
		randomize_button.name = "RandomizeButton"
		randomize_button.custom_minimum_size.x = 120
		button_container.add_child(randomize_button)
		
		crew_container = content
		print("CrewPanel: ✅ Created complete fallback UI structure with proper sizing and layout")
	else:
		# Try to find existing UI components
		_find_existing_ui_components()
		print("CrewPanel: Using existing crew_container from scene")

func _find_existing_ui_components() -> void:
	"""Find existing UI components in the scene"""
	crew_size_option = find_child("CrewSizeOption", true, false) as OptionButton
	crew_list = find_child("CrewList", true, false) as ItemList
	add_button = find_child("AddButton", true, false) as Button
	edit_button = find_child("EditButton", true, false) as Button
	remove_button = find_child("RemoveButton", true, false) as Button
	randomize_button = find_child("RandomizeButton", true, false) as Button
	
	print("CrewPanel: Found existing UI components - CrewSize: %s, CrewList: %s" % [
		crew_size_option != null, crew_list != null
	])

func _setup_crew_size_options() -> void:
	"""Setup crew size selection options"""
	if not crew_size_option:
		print("CrewPanel: Warning - crew_size_option not found, creating fallback")
		crew_size_option = OptionButton.new()
		if crew_container:
			crew_container.add_child(crew_size_option)
	
	crew_size_option.clear()
	for i in range(1, 9):
		crew_size_option.add_item(str(i) + " Members", i)
	
	# Set default to 4
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == 4:
			crew_size_option.select(i)
			break

func _connect_ui_signals() -> void:
	"""Connect UI signals with safety checks"""
	if crew_size_option and not crew_size_option.item_selected.is_connected(_on_crew_size_selected):
		crew_size_option.item_selected.connect(_on_crew_size_selected)
	
	if add_button and not add_button.pressed.is_connected(_on_add_member_pressed):
		add_button.pressed.connect(_on_add_member_pressed)
	
	if edit_button and not edit_button.pressed.is_connected(_on_edit_member_pressed):
		edit_button.pressed.connect(_on_edit_member_pressed)
	
	# Connect CharacterCreator signals if available
	if character_creator:
		print("CrewPanel: CharacterCreator available, signals will be connected when handlers are implemented")
	else:
		print("CrewPanel: CharacterCreator not available for signal connection")
	
	if remove_button and not remove_button.pressed.is_connected(_on_remove_member_pressed):
		remove_button.pressed.connect(_on_remove_member_pressed)
	
	if randomize_button and not randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.connect(_on_randomize_pressed)
	
	if crew_list and not crew_list.item_selected.is_connected(_on_crew_member_selected):
		crew_list.item_selected.connect(_on_crew_member_selected)

func _generate_initial_crew() -> void:
	"""Generate initial crew based on selected size"""
	clear_crew()
	
	for i in range(selected_size):
		var character = _generate_random_character()
		if character:
			add_crew_member(character)
	
	print("CrewPanel: Generated %d crew members" % crew_members.size())

# Base crew component methods
func add_crew_member(character: Character) -> bool:
	"""Add a crew member with validation"""
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Cannot add invalid character")
		return false
	
	if crew_members.size() >= MAX_CREW_SIZE:
		push_warning("CrewPanel: Cannot add crew member - maximum size reached")
		return false
	
	crew_members.append(character)
	
	# Auto-assign first member as captain if none assigned
	if not current_captain and crew_members.size() == 1:
		set_captain(character)
	
	# Emit granular signal for real-time integration
	var member_data = {
		"name": character.character_name if character.character_name else "Unknown",
		"combat": character.combat if character.has_method("combat") else 0,
		"toughness": character.toughness if character.has_method("toughness") else 0,
		"tech": character.tech if character.has_method("tech") else 0,
		"savvy": character.savvy if character.has_method("savvy") else 0
	}
	crew_member_added.emit(member_data)
	
	_emit_crew_updated()
	return true

func remove_crew_member(character: Character) -> bool:
	"""Remove a crew member with validation"""
	if not character or not is_instance_valid(character):
		return false
	
	var index = crew_members.find(character)
	if index == -1:
		return false
	
	crew_members.remove_at(index)
	
	# If removed character was captain, assign new captain
	if character == current_captain and crew_members.size() > 0:
		set_captain(crew_members[0])
	elif character == current_captain:
		current_captain = null
	
	_emit_crew_updated()
	return true

func clear_crew() -> void:
	"""Clear all crew members"""
	crew_members.clear()
	current_captain = null
	_emit_crew_updated()

func set_captain(character: Character) -> void:
	"""Set a crew member as captain"""
	if character and character in crew_members:
		# Remove captain status from previous captain
		if current_captain:
			current_captain.character_name = current_captain.character_name.replace(" (Captain)", "")
		
		current_captain = character
		character.character_name = character.character_name.replace(" (Captain)", "") + " (Captain)"
		_emit_crew_updated()

func _emit_crew_updated() -> void:
	"""Emit crew updated signal"""
	crew_updated.emit(crew_members)
	
	# Emit granular composition signal for real-time integration
	var composition = []
	for member in crew_members:
		if member and is_instance_valid(member):
			composition.append({
				"name": member.character_name if member.character_name else "Unknown",
				"role": "Crew Member", # Could be enhanced with actual roles
				"combat": member.combat if member.has_method("combat") else 0,
				"toughness": member.toughness if member.has_method("toughness") else 0,
				"tech": member.tech if member.has_method("tech") else 0,
				"savvy": member.savvy if member.has_method("savvy") else 0
			})
	crew_composition_changed.emit(composition)

func _generate_random_character() -> Character:
	"""Generate a random character for the crew"""
	var character = Character.new()
	var names = ["Marcus", "Sarah", "Chen", "Nova", "Rex", "Luna", "Storm", "Vale", "Cross", "Hawk"]
	character.character_name = names[randi() % names.size()] + " " + str(randi_range(100, 999))
	
	# Generate Five Parsecs attributes
	character.combat = _generate_five_parsecs_attribute()
	character.toughness = _generate_five_parsecs_attribute()
	character.tech = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute()
	character.speed = _generate_five_parsecs_attribute()
	character.reaction = _generate_five_parsecs_attribute()
	character.luck = 0
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	return character

# SPRINT ENHANCEMENT: Backend Integration Methods

func request_backend_crew_generation() -> void:
	"""Request crew generation through backend systems"""
	print("CrewPanel: Requesting backend crew generation for %d members" % selected_size)
	crew_generation_requested.emit(selected_size)

func set_generated_crew(crew: Array) -> void:
	"""Receive crew generated by backend systems"""
	print("CrewPanel: Received %d crew members from backend" % crew.size())
	
	# Clear existing crew and add the generated ones
	clear_crew()
	
	for character in crew:
		if character:
			add_crew_member(character)
	
	_update_crew_display()
	
	# Emit the standard crew updated signal
	crew_updated.emit(crew_members)

func request_character_customization(character_index: int) -> void:
	"""Request character customization through backend systems"""
	if character_index < 0 or character_index >= crew_members.size():
		return
	
	var character = crew_members[character_index]
	print("CrewPanel: Requesting character customization for %s" % character.character_name)
	character_customization_needed.emit(character_index, character)

func _update_crew_display() -> void:
	"""Update the crew list display"""
	if not crew_list:
		return
	
	crew_list.clear()
	
	for i in range(crew_members.size()):
		var member = crew_members[i]
		var display_text = "%s - Combat:%d Tough:%d Tech:%d" % [
			member.character_name,
			member.combat,
			member.toughness,
			member.tech
		]
		crew_list.add_item(display_text)
	
	_update_crew_summary()
	_update_button_states()

func _update_crew_summary() -> void:
	"""Update crew summary display"""
	if not crew_summary:
		return
	
	var captain_name = current_captain.character_name if current_captain else "None"
	crew_summary.text = "Crew: %d members | Captain: %s" % [crew_members.size(), captain_name]

func _update_button_states() -> void:
	"""Update button enabled/disabled states"""
	var has_selection = crew_list and not crew_list.get_selected_items().is_empty()
	
	if edit_button:
		edit_button.disabled = not has_selection
	
	if remove_button:
		remove_button.disabled = not has_selection or crew_members.size() <= 1
	
	if add_button:
		add_button.disabled = crew_members.size() >= MAX_CREW_SIZE

# UI Event Handlers

func _on_crew_size_selected(index: int) -> void:
	"""Handle crew size selection"""
	if not crew_size_option:
		return
	
	selected_size = crew_size_option.get_item_id(index)
	_adjust_crew_size()

func _adjust_crew_size() -> void:
	"""Adjust crew size to match selection"""
	var current_size = crew_members.size()
	
	if current_size < selected_size:
		# Add members
		for i in range(selected_size - current_size):
			var character = generate_random_character()
			if character:
				add_crew_member(character)
	elif current_size > selected_size:
		# Remove excess members (preserve captain if possible)
		while crew_members.size() > selected_size:
			var member_to_remove = crew_members.back()
			if member_to_remove != current_captain:
				remove_crew_member(member_to_remove)
			else:
				# Remove a different member instead
				if crew_members.size() > 1:
					remove_crew_member(crew_members[0])
				else:
					break
	
	_update_crew_display()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	"""Handle add crew member button with CharacterCreator integration"""
	if crew_members.size() >= MAX_CREW_SIZE:
		_show_message("Cannot add more crew members (maximum %d)" % MAX_CREW_SIZE)
		return
	
	# Use CharacterCreator if available, fallback to random generation
	if character_creator:
		print("CrewPanel: Using CharacterCreator for new crew member")
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CREW_MEMBER)
		character_creator.visible = true
	else:
		print("CrewPanel: CharacterCreator not available, using random generation")
		var character = generate_random_character()
		if character:
			add_crew_member(character)
			_update_crew_display()
			crew_updated.emit(crew_members)

func generate_random_character() -> Character:
	"""Generate a random character with Five Parsecs stats"""
	var character = Character.new()
	
	# Generate random name from a pool
	var first_names = ["Alex", "Casey", "Jordan", "Sam", "Taylor", "Morgan", "Riley", "Avery", "Blake", "Cameron"]
	var last_names = ["Smith", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Thomas"]
	
	character.character_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	
	# Generate Five Parsecs stats (2d6 divided by 3, rounded up)
	character.combat = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.toughness = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.savvy = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.tech = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.speed = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.luck = 1 # Base luck
	
	# Calculate health based on toughness
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	return character

func _on_edit_member_pressed() -> void:
	"""Handle edit crew member button with CharacterCreator integration"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		return
	
	var index = crew_list.get_selected_items()[0]
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		
		# Use CharacterCreator if available, fallback to basic dialog
		if character_creator:
			print("CrewPanel: Using CharacterCreator for crew member editing")
			character_creator.edit_character(character)
			character_creator.visible = true
		else:
			print("CrewPanel: CharacterCreator not available, using fallback dialog")
			_show_edit_dialog(character)

func _on_remove_member_pressed() -> void:
	"""Handle remove crew member button"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		return
	
	if crew_members.size() <= 1:
		_show_message("Cannot remove last crew member")
		return
	
	var index = crew_list.get_selected_items()[0]
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		remove_crew_member(character)
		_update_crew_display()
		crew_updated.emit(crew_members)

func _on_randomize_pressed() -> void:
	"""Handle randomize crew button with backend integration option"""
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Replace all crew members with randomly generated ones?"
	dialog.add_to_group("crew_panel_dialogs") # Add to group for cleanup
	
	# SPRINT ENHANCEMENT: Try backend generation first, fallback to base class
	dialog.confirmed.connect(_try_backend_or_fallback_generation)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _try_backend_or_fallback_generation() -> void:
	"""Try backend crew generation, fallback to base class if unavailable"""
	# Check if we have listeners for backend generation
	if crew_generation_requested.get_connections().size() > 0:
		print("CrewPanel: Using backend crew generation")
		request_backend_crew_generation()
	else:
		print("CrewPanel: Falling back to base class crew generation")
		_generate_initial_crew()
		_update_crew_display()
		crew_updated.emit(crew_members)

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	_update_button_states()
	
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		crew_member_selected.emit(character)

# Dialog Methods

func _show_edit_dialog(character: Character) -> void:
	"""Show character edit dialog - fallback when CharacterCreator is not available"""
	var dialog = AcceptDialog.new()
	dialog.title = "Edit " + character.character_name.replace(" (Captain)", "")
	dialog.min_size = Vector2(300, 200)
	dialog.add_to_group("crew_panel_dialogs") # Add to group for cleanup
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	# Name input
	var name_container = HBoxContainer.new()
	vbox.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 80
	name_container.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.text = character.character_name.replace(" (Captain)", "")
	name_input.placeholder_text = "Character Name"
	name_container.add_child(name_input)
	
	# Captain checkbox
	var captain_check = CheckBox.new()
	captain_check.text = "Make Captain"
	captain_check.button_pressed = (character == current_captain)
	vbox.add_child(captain_check)
	
	# Stats display
	var stats_label = Label.new()
	stats_label.text = "Stats: Combat:%d Tough:%d Tech:%d Savvy:%d Speed:%d" % [
		character.combat, character.toughness, character.tech, character.savvy, character.speed
	]
	vbox.add_child(stats_label)
	
	# Reroll stats button
	var reroll_button = Button.new()
	reroll_button.text = "Reroll Stats"
	reroll_button.pressed.connect(func():
		character.combat = _generate_five_parsecs_attribute()
		character.toughness = _generate_five_parsecs_attribute()
		character.tech = _generate_five_parsecs_attribute()
		character.savvy = _generate_five_parsecs_attribute()
		character.speed = _generate_five_parsecs_attribute()
		character.reaction = _generate_five_parsecs_attribute()
		character.max_health = character.toughness + 2
		character.health = character.max_health
		stats_label.text = "Stats: Combat:%d Tough:%d Tech:%d Savvy:%d Speed:%d" % [
			character.combat, character.toughness, character.tech, character.savvy, character.speed
		]
	)
	vbox.add_child(reroll_button)
	
	dialog.confirmed.connect(func():
		var new_name = name_input.text.strip_edges()
		if not new_name.is_empty():
			# Remove old captain title
			if character == current_captain:
				character.character_name = character.character_name.replace(" (Captain)", "")
			
			character.character_name = new_name
			
			# Handle captain assignment
			if captain_check.button_pressed and character != current_captain:
				set_captain(character)
			elif not captain_check.button_pressed and character == current_captain:
				# Need to assign a different captain
				for member in crew_members:
					if member != character:
						set_captain(member)
						break
		
		_update_crew_display()
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func(): dialog.queue_free())
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _show_message(message: String) -> void:
	"""Show a simple message dialog"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.add_to_group("crew_panel_dialogs") # Add to group for cleanup
	dialog.confirmed.connect(func(): dialog.queue_free())
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute (2d6/3 rounded up) - local implementation"""
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1) # 2d6
	return int(ceil(float(roll) / 3.0))

# Required interface methods from ICampaignCreationPanel

func validate_panel() -> bool:
	"""Validate crew panel data - simplified validation"""
	# Clear previous errors
	last_validation_errors = []
	
	# Business rule: Minimum crew size validation
	if crew_members.size() == 0:
		last_validation_errors.append("At least one crew member is required")
		is_crew_complete = false
		return false
	
	# Business rule: Maximum crew size validation  
	if crew_members.size() > 8: # Five Parsecs maximum
		last_validation_errors.append("Crew cannot exceed 8 members")
		is_crew_complete = false
		return false
	
	# Business rule: Captain validation
	if not current_captain:
		last_validation_errors.append("A captain must be designated")
		is_crew_complete = false
		return false
	
	# Business rule: Captain must be crew member
	if current_captain and current_captain not in crew_members:
		last_validation_errors.append("Captain must be a member of the crew")
		is_crew_complete = false
		return false
	
	# All validations passed
	is_crew_complete = true
	return true

func get_panel_data() -> Dictionary:
	"""Get crew panel data for state manager"""
	return get_crew_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	clear_crew()
	selected_size = 4
	is_crew_complete = false
	local_crew_data.is_complete = false
	_generate_initial_crew()

# Public API for campaign creation

func set_data(data: Dictionary) -> void:
	"""Set crew data from saved campaign"""
	if data.has("crew_members"):
		clear_crew()
		var crew_data = data.crew_members
		var captain_name = ""
		
		if data.has("captain") and data.captain:
			captain_name = data.captain.character_name
		
		for member_data in crew_data:
			if member_data is Character:
				add_crew_member(member_data)
				if member_data.character_name == captain_name:
					set_captain(member_data)
		
		_update_crew_display()

func is_valid() -> bool:
	"""Check if crew panel data is valid"""
	var validation = validate_panel()
	return validation.valid

func validate() -> Array[String]:
	"""Validate crew data and return error messages"""
	var validation = validate_panel()
	return validation.errors if validation.errors else []

func get_panel_name() -> String:
	"""Get panel display name"""
	return "Crew Setup"

func get_panel_description() -> String:
	"""Get panel description"""
	return "Configure your crew size and customize crew members"

func _notification(what: int) -> void:
	"""Handle notifications for cleanup"""
	if what == NOTIFICATION_PREDELETE:
		# Cleanup all signal connections to prevent memory leaks
		_cleanup_connections()
		
		# Properly free dynamically created dialogs and UI components
		_cleanup_dynamic_resources()
		
		# Cleanup complete

func _cleanup_connections() -> void:
	"""Cleanup all signal connections to prevent memory leaks"""
	if crew_size_option and crew_size_option.item_selected.is_connected(_on_crew_size_selected):
		crew_size_option.item_selected.disconnect(_on_crew_size_selected)
	
	if add_button and add_button.pressed.is_connected(_on_add_member_pressed):
		add_button.pressed.disconnect(_on_add_member_pressed)
	
	if edit_button and edit_button.pressed.is_connected(_on_edit_member_pressed):
		edit_button.pressed.disconnect(_on_edit_member_pressed)
	
	if remove_button and remove_button.pressed.is_connected(_on_remove_member_pressed):
		remove_button.pressed.disconnect(_on_remove_member_pressed)
	
	if randomize_button and randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.disconnect(_on_randomize_pressed)
	
	if crew_list and crew_list.item_selected.is_connected(_on_crew_member_selected):
		crew_list.item_selected.disconnect(_on_crew_member_selected)

func _cleanup_dynamic_resources() -> void:
	"""Cleanup dynamically created resources to prevent memory leaks"""
	# Find and cleanup any remaining dialogs - with null check
	if get_tree():
		var dialogs = get_tree().get_nodes_in_group("crew_panel_dialogs")
		for dialog in dialogs:
			if is_instance_valid(dialog):
				dialog.queue_free()
	
	# Clear any cached references with null safety
	if crew_size_option:
		crew_size_option = null
	if crew_list:
		crew_list = null
	if add_button:
		add_button = null
	if edit_button:
		edit_button = null
	if remove_button:
		remove_button = null
	if randomize_button:
		randomize_button = null
	
	print("CrewPanel: Dynamic resources cleaned up successfully")

# Debug helper
func debug_crew_status() -> void:
	"""Debug function to print crew status"""
	print("=== CREW PANEL DEBUG ===")
	print("Panel initialized: ", is_panel_initialized)
	print("Crew size: ", crew_members.size())
	print("Selected size: ", selected_size)
	print("Captain: ", current_captain.character_name if current_captain else "None")
	print("Valid: ", is_valid())
	
	for i in range(crew_members.size()):
		var member = crew_members[i]
		print("Member %d: %s (Combat:%d Tough:%d)" % [
			i, member.character_name, member.combat, member.toughness
		])

# --- Additions to CrewPanel.gd ---

# 3. Add local state update and validation functions
func _on_local_crew_updated(updated_crew: Array) -> void:
	"""Enhanced crew update handler with coordinator pattern integration"""
	local_crew_data.members = updated_crew
	local_crew_data.captain = current_captain

	# Emit panel data update for signal-based architecture
	var crew_data = get_crew_data()
	panel_data_updated.emit(self, crew_data)
	print("CrewPanel: Updated crew data via signals: ", crew_data.keys())

	# Perform enhanced validation and emit completion signals
	_validate_and_complete()
	
	# Emit backward compatibility signal
	crew_setup_complete.emit(get_crew_data())

func _validate_and_complete() -> void:
	"""Enhanced validation with coordinator pattern and security integration"""
	last_validation_errors = _validate_crew_data()
	
	if not last_validation_errors.is_empty():
		is_crew_complete = false
		local_crew_data.is_complete = false
		crew_validation_failed.emit(last_validation_errors)
		print("CrewPanel: Validation failed: ", last_validation_errors)
	else:
		var was_complete = is_crew_complete
		is_crew_complete = _check_completion_requirements()
		local_crew_data.is_complete = is_crew_complete
		
		# Emit completion signal when transitioning to complete state
		if is_crew_complete and not was_complete:
			var crew_data = get_crew_data()
			crew_data_complete.emit(crew_data)
			panel_completed.emit(crew_data) # Maintain backward compatibility
			print("CrewPanel: Crew setup completed autonomously: ", crew_data.keys())
		elif is_crew_complete:
			print("CrewPanel: Crew setup validation passed, already complete")

func _check_completion_requirements() -> bool:
	"""Check if all requirements for crew completion are met"""
	# Required: At least minimum crew size with valid members
	if crew_members.size() < 1:
		return false
	
	# Required: Captain assigned
	if not current_captain:
		return false
	
	# Required: All crew members have valid names
	for member in crew_members:
		var name = member.character_name.strip_edges()
		if name.is_empty() or name.length() < 2:
			return false
		
		# Validate name using SecurityValidator
		if security_validator:
			var validation_result = security_validator.validate_character_name(name)
			if not validation_result.valid:
				return false
	
	# Required: Crew size within acceptable range (1-8)
	if crew_members.size() < 1 or crew_members.size() > 8:
		return false
	
	return true

func _validate_crew_data() -> Array[String]:
	"""Performs validation on the crew data."""
	var errors: Array[String] = []
	
	# Rule: Must have between 4 and 8 members
	if local_crew_data.members.size() < 4 or local_crew_data.members.size() > 8:
		errors.append("Crew must have between 4 and 8 members.")
		
	# Rule: Must have a captain
	if local_crew_data.captain == null:
		errors.append("A captain must be assigned.")
		
	# Rule: All characters must have a name
	for member in local_crew_data.members:
		if member.character_name.is_empty():
			errors.append("All crew members must have a name.")
			break # No need to report for every unnamed member
			
	return errors

# Override get_data to include completion status
func get_data() -> Dictionary:
	"""Get crew data for campaign creation, including completion status."""
	var data = get_crew_data()
	data["is_complete"] = local_crew_data.is_complete
	return data

## Public API for Coordinator Pattern Integration

func get_completion_status() -> bool:
	"""Get current completion status"""
	return is_crew_complete

func get_validation_errors() -> Array[String]:
	"""Get current validation errors"""
	return last_validation_errors.duplicate()

func force_validation_check() -> void:
	"""Force a validation check and emit appropriate signals"""
	_validate_and_complete()

func get_crew_data() -> Dictionary:
	"""Get crew data in the format expected by FiveParsecsCampaignCreationStateManager"""
	var crew_data = {
		"members": crew_members.duplicate(),
		"captain": current_captain,
		"size": crew_members.size(),
		"completion_level": _calculate_completion_level(),
		"backend_generated": false, # Set to true if generated via backend systems
		"created_date": Time.get_datetime_string_from_system(),
		"version": "1.0"
	}
	return crew_data

func _calculate_completion_level() -> float:
	"""Calculate completion level percentage"""
	if crew_members.is_empty():
		return 0.0
	
	var completion_factors = 0.0
	var total_factors = 4.0 # Name, stats, captain assignment, size appropriateness
	
	# Factor 1: All members have valid names
	var valid_names = true
	for member in crew_members:
		if member.character_name.strip_edges().length() < 2:
			valid_names = false
			break
	if valid_names:
		completion_factors += 1.0
	
	# Factor 2: All members have reasonable stats
	var valid_stats = true
	for member in crew_members:
		if member.combat < 1 or member.toughness < 1:
			valid_stats = false
			break
	if valid_stats:
		completion_factors += 1.0
	
	# Factor 3: Captain is assigned
	if current_captain:
		completion_factors += 1.0
	
	# Factor 4: Crew size is appropriate (4-6 is ideal)
	if crew_members.size() >= 4 and crew_members.size() <= 6:
		completion_factors += 1.0
	elif crew_members.size() >= 1 and crew_members.size() <= 8:
		completion_factors += 0.5 # Partial credit for acceptable size
	
	return completion_factors / total_factors

func get_panel_phase() -> CampaignStateManager.Phase:
	"""Get the phase this panel corresponds to"""
	return CampaignStateManager.Phase.CREW_SETUP

# Duplicate functions removed - using original declarations earlier in the file

# --- End of additions ---

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("CrewPanel: No data to restore")
		return
	
	print("CrewPanel: Restoring panel data: ", data.keys())
	
	# Clear existing crew first
	clear_crew()
	
	# Restore crew members
	if data.has("members") and data.members is Array:
		var members_data = data.members
		var captain_name = ""
		
		# Identify captain if available
		if data.has("captain") and data.captain:
			if data.captain is Dictionary and data.captain.has("character_name"):
				captain_name = data.captain.character_name
			elif data.captain is Character:
				captain_name = data.captain.character_name
		
		print("CrewPanel: Restoring %d crew members, captain: %s" % [members_data.size(), captain_name])
		
		# Restore each crew member
		for member_data in members_data:
			var character: Character
			
			# Handle different data formats
			if member_data is Character:
				character = member_data
			elif member_data is Dictionary:
				character = _create_character_from_dict(member_data)
			else:
				print("CrewPanel: Warning - invalid member data format: ", typeof(member_data))
				continue
			
			if character:
				add_crew_member(character)
				
				# Assign captain if this is the captain
				if character.character_name == captain_name or character.character_name.contains("(Captain)"):
					set_captain(character)
					print("CrewPanel: Restored captain: ", character.character_name)
	
	# Restore crew size selection
	if data.has("size"):
		selected_size = data.size
		_set_crew_size_selection(selected_size)
		print("CrewPanel: Restored crew size: ", selected_size)
	
	# Update UI after restoration
	_update_crew_display()
	_validate_and_complete()
	
	print("CrewPanel: Panel data restoration complete - %d members restored" % crew_members.size())

func _create_character_from_dict(data: Dictionary) -> Character:
	"""Create a Character object from dictionary data"""
	var character = Character.new()
	
	# Restore basic properties
	if data.has("character_name"):
		character.character_name = data.character_name
	if data.has("combat"):
		character.combat = data.combat
	if data.has("toughness"):
		character.toughness = data.toughness
	if data.has("tech"):
		character.tech = data.tech
	if data.has("savvy"):
		character.savvy = data.savvy
	if data.has("speed"):
		character.speed = data.speed
	if data.has("reaction"):
		character.reaction = data.reaction
	if data.has("luck"):
		character.luck = data.luck
	if data.has("health"):
		character.health = data.health
	if data.has("max_health"):
		character.max_health = data.max_health
	else:
		# Calculate max health from toughness if not provided
		character.max_health = character.toughness + 2
		character.health = character.max_health
	
	return character

func _set_crew_size_selection(size: int) -> void:
	"""Set crew size selection safely"""
	if not crew_size_option:
		return
	
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == size:
			crew_size_option.select(i)
			break
