extends BaseCrewComponent

# Simplified CrewPanel for campaign creation
# Extends BaseCrewComponent to leverage existing functionality
# Removes complex dependencies and focuses on core crew setup

signal crew_setup_complete(crew_data: Dictionary)
# SPRINT ENHANCEMENT: Backend integration signals  
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Variant)

# UI Components - using safe access pattern
var crew_size_option: OptionButton
var crew_list: ItemList  
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

# UI component references (safe fallback if not found in scene)
@onready var crew_container: VBoxContainer = $Content/CrewContainer if has_node("Content/CrewContainer") else null
@onready var crew_summary: Label = $Content/CrewSummary if has_node("Content/CrewSummary") else null
@onready var instructions_label: Label = $Content/Instructions if has_node("Content/Instructions") else null

var selected_size: int = 4
var is_panel_initialized: bool = false

func _ready() -> void:
	super._ready()
	print("CrewPanel: Starting simplified initialization...")
	call_deferred("_initialize_panel")

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
	
	is_panel_initialized = true
	print("CrewPanel: Simplified initialization complete")

func _setup_fallback_ui() -> void:
	"""Create basic UI structure if scene doesn't provide it"""
	if not crew_container:
		# Create a basic container structure
		var content = VBoxContainer.new()
		content.name = "Content"
		add_child(content)
		
		# Instructions
		instructions_label = Label.new()
		instructions_label.name = "Instructions"
		instructions_label.text = "Select your crew size and customize your crew members. One member will be designated as captain."
		instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(instructions_label)
		
		# Crew size selection
		var size_container = HBoxContainer.new()
		content.add_child(size_container)
		
		var size_label = Label.new()
		size_label.text = "Crew Size:"
		size_container.add_child(size_label)
		
		crew_size_option = OptionButton.new()
		crew_size_option.name = "CrewSizeOption"
		size_container.add_child(crew_size_option)
		
		# Crew list
		crew_list = ItemList.new()
		crew_list.name = "CrewList"
		crew_list.custom_minimum_size = Vector2(400, 200)
		content.add_child(crew_list)
		
		# Summary
		crew_summary = Label.new()
		crew_summary.name = "CrewSummary"
		crew_summary.text = "Crew: 0 members"
		content.add_child(crew_summary)
		
		# Buttons
		var button_container = HBoxContainer.new()
		button_container.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(button_container)
		
		add_button = Button.new()
		add_button.text = "Add Member"
		add_button.name = "AddButton"
		button_container.add_child(add_button)
		
		edit_button = Button.new()
		edit_button.text = "Edit Selected"
		edit_button.name = "EditButton"
		edit_button.disabled = true
		button_container.add_child(edit_button)
		
		remove_button = Button.new()
		remove_button.text = "Remove Selected"
		remove_button.name = "RemoveButton"
		remove_button.disabled = true
		button_container.add_child(remove_button)
		
		randomize_button = Button.new()
		randomize_button.text = "Randomize All"
		randomize_button.name = "RandomizeButton"
		button_container.add_child(randomize_button)
		
		crew_container = content
		print("CrewPanel: Created fallback UI structure")
	else:
		# Try to find existing UI components
		_find_existing_ui_components()

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
	
	if remove_button and not remove_button.pressed.is_connected(_on_remove_member_pressed):
		remove_button.pressed.connect(_on_remove_member_pressed)
	
	if randomize_button and not randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.connect(_on_randomize_pressed)
	
	if crew_list and not crew_list.item_selected.is_connected(_on_crew_member_selected):
		crew_list.item_selected.connect(_on_crew_member_selected)

func _generate_initial_crew() -> void:
	"""Generate initial crew based on selected size"""
	clear_crew()  # Use base class method
	
	for i in range(selected_size):
		var character = generate_random_character()  # Use base class method
		if character:
			add_crew_member(character)  # Use base class method
	
	print("CrewPanel: Generated %d crew members" % crew_members.size())

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
	"""Handle add crew member button"""
	if crew_members.size() >= MAX_CREW_SIZE:
		_show_message("Cannot add more crew members (maximum %d)" % MAX_CREW_SIZE)
		return
	
	var character = generate_random_character()
	if character:
		add_crew_member(character)
		_update_crew_display()
		crew_updated.emit(crew_members)

func _on_edit_member_pressed() -> void:
	"""Handle edit crew member button"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		return
	
	var index = crew_list.get_selected_items()[0]
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
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
	dialog.add_to_group("crew_panel_dialogs")  # Add to group for cleanup
	
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
	"""Show character edit dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Edit " + character.character_name.replace(" (Captain)", "")
	dialog.min_size = Vector2(300, 200)
	dialog.add_to_group("crew_panel_dialogs")  # Add to group for cleanup
	
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
	dialog.add_to_group("crew_panel_dialogs")  # Add to group for cleanup
	dialog.confirmed.connect(func(): dialog.queue_free())
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute (2d6/3 rounded up) - local implementation"""
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)  # 2d6
	return int(ceil(float(roll) / 3.0))

# Public API for campaign creation

func get_data() -> Dictionary:
	"""Get crew data for campaign creation"""
	return {
		"crew_members": crew_members.duplicate(),
		"captain": current_captain,
		"crew_size": crew_members.size()
	}

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
	var validation = validate_crew()
	return validation.valid

func validate() -> Array[String]:
	"""Validate crew data and return error messages"""
	var validation = validate_crew()
	return validation.errors

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
	# Find and cleanup any remaining dialogs
	var dialogs = get_tree().get_nodes_in_group("crew_panel_dialogs")
	for dialog in dialogs:
		if is_instance_valid(dialog):
			dialog.queue_free()
	
	# Clear any cached references
	crew_size_option = null
	crew_list = null
	add_button = null
	edit_button = null
	remove_button = null
	randomize_button = null

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
