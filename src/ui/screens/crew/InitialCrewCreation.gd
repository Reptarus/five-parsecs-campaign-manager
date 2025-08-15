class_name FPCM_InitialCrewCreationUI
extends BaseCrewComponent

## Five Parsecs Initial Crew Creation UI
## Now extends BaseCrewComponent for shared crew management functionality
## Focused on standalone crew creation workflow

# Enhanced Five Parsecs character generation system

# Additional signals specific to initial crew creation
signal crew_created(crew_data: Dictionary)
signal character_generated(character: Character)

@onready var crew_size_option := %CrewSizeOption
@onready var crew_name_input := %CrewNameInput
@onready var character_list_container := %Content  # This should be the available characters container
@onready var create_button := %CreateButton
@onready var generate_button := %GenerateButton
@onready var character_details := %CharacterDetails
@onready var patron_details := %PatronDetails
@onready var rival_details := %RivalDetails
@onready var equipment_details := %EquipmentDetails

# Crew creation specific data (BaseCrewComponent handles core crew data)
var crew_creation_data := {
	"name": "",
	"size": 4,
	"characters": []
}

# REMOVED: var character_manager: Node = null - no longer needed with static methods

# _ready() implementation moved to end of file for campaign integration

func _setup_initial_crew_creation() -> void:
	_initialize_character_system()
	_connect_signals()
	_setup_options()

func _initialize_character_system() -> void:
	"""Framework Bible compliant character generation - no Manager dependencies"""
	print("InitialCrewCreation: Using direct Character class generation")

func _connect_signals() -> void:
	# Disconnect existing connections to prevent duplicates
	if crew_size_option.item_selected.is_connected(_on_crew_size_changed):
		crew_size_option.item_selected.disconnect(_on_crew_size_changed)
	if crew_name_input.text_changed.is_connected(_on_crew_name_changed):
		crew_name_input.text_changed.disconnect(_on_crew_name_changed)
	if create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.disconnect(_on_create_pressed)
	
	# Connect signals
	crew_size_option.item_selected.connect(_on_crew_size_changed)
	crew_name_input.text_changed.connect(_on_crew_name_changed)
	create_button.pressed.connect(_on_create_pressed)

	# Connect character generation button if available
func _on_generate_character() -> void:
	"""Production-ready character generation using Framework Bible patterns"""
	print("InitialCrewCreation: Generating character via direct Character class")
	
	try:
		# Direct static call eliminates Manager dependency
		var new_character = Character.generate_character()
		
		if new_character and new_character.is_valid():
			crew_members.append(new_character)
			_update_character_display()
			_update_ui_state()
			print("Character generated successfully: %s (%s)" % [new_character.name, new_character.background])
			
			# Emit signal for parent components
			if has_signal("character_generated"):
				character_generated.emit(new_character)
		else:
			push_error("Generated character failed validation")
			_show_error_dialog("Character generation failed. Please try again.")
	except:
		push_error("Critical error in character generation")
		_show_error_dialog("System error occurred. Please restart the application.")

func _show_error_dialog(message: String) -> void:
	"""Production-ready error handling with user feedback"""
	var dialog = AcceptDialog.new()
	dialog.title = "Character Generation Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

	# Character list selection will be handled by individual character boxes

func _setup_options() -> void:
	# Setup crew size options
	crew_size_option.clear()
	for i in range(1, 9):  # Crew sizes 1-8
		crew_size_option.add_item(str(i) + " members")
	crew_size_option.selected = 3  # Default to 4 members (index 3)
	create_button.disabled = true

	# Enable character generation if components are available
	if generate_button:
		generate_button.text = "Generate Character"
		generate_button.disabled = false

	# Setup character list container
	if character_list_container:
		# Clear any existing character boxes
		for child in character_list_container.get_children():
			child.queue_free()
	
	_update_ui_state()

func _on_crew_size_changed(index: int) -> void:
	crew_creation_data.size = index + 1  # Convert index to actual size
	_validate_crew()

func _on_crew_name_changed(new_name: String) -> void:
	crew_creation_data.name = new_name
	_validate_crew()

func _on_character_selected(character: Dictionary) -> void:
	if not crew_creation_data.characters.has(character):
		if crew_creation_data.characters.size() < crew_creation_data.size:
			crew_creation_data.characters.append(character)
	else:
		crew_creation_data.characters.erase(character)

	_validate_crew()

func _validate_crew() -> bool:
	var valid: bool = not crew_creation_data.name.strip_edges().is_empty() and get_crew_size() == crew_creation_data.size
	create_button.disabled = not valid
	return valid

func _create_character_box(character: Character) -> void:
	"""Create a character box UI component for the character"""
	if not character_list_container:
		return
	
	# Load the CharacterBox scene
	var character_box_scene = preload("res://src/ui/components/character/CharacterBox.tscn")
	var character_box = character_box_scene.instantiate()
	
	# Set up the character box with character data
	if character_box.has_method("setup_character"):
		character_box.setup_character(character)
	
	# Connect selection signal if available
	if character_box.has_signal("character_selected"):
		character_box.character_selected.connect(_on_character_box_selected)
	
	# Add to the container
	character_list_container.add_child(character_box)
	
	print("InitialCrewCreation: Created character box for: ", character.character_name)

func _character_to_dict(character: Character) -> Dictionary:
	"""Convert Character object to dictionary format"""
	return {
		"name": character.character_name if character and character.has_method("get") else character.character_name,
		"class": character.character_class if character and character.has_method("get") else character.character_class,
		"background": character.background if character and character.has_method("get") else character.background,
		"origin": character.origin if character and character.has_method("get") else character.origin,
		"reaction": character.reaction if character and character.has_method("get") else character.reaction,
		"speed": character.speed if character and character.has_method("get") else character.speed,
		"combat": character.combat if character and character.has_method("get") else character.combat,
		"toughness": character.toughness if character and character.has_method("get") else character.toughness,
		"savvy": character.savvy if character and character.has_method("get") else character.savvy,
		"character_object": character
	}

func _get_class_name(class_id: int) -> String:
	"""Get class name for display"""
	# GlobalEnums available as autoload singleton

	# GlobalEnums should be available as an autoload
	if GlobalEnums and GlobalEnums.has("CharacterClass") and class_id >= 0:
		var character_classes = GlobalEnums.CharacterClass
		if class_id < character_classes.size():
			return character_classes.keys()[class_id]
	return "Unknown"

func _get_background_name(background_id: int) -> String:
	"""Get background name for display"""
	if GlobalEnums and background_id >= 0 and background_id < GlobalEnums.CharacterBackground.size():
		return GlobalEnums.CharacterBackground.keys()[background_id]
	return "Unknown"

func _get_motivation_name(motivation_id: int) -> String:
	"""Get motivation name for display"""
	if GlobalEnums and motivation_id >= 0 and motivation_id < GlobalEnums.CharacterMotivation.size():
		return GlobalEnums.CharacterMotivation.keys()[motivation_id]
	return "Unknown"

func _update_character_relationship_displays(character: Character) -> void:
	"""Update patron, rival, and equipment displays for character"""
	if not character:
		return
	
	# Update patron details
	if patron_details:
		var patrons = character.get_meta("generated_patrons", []) if character.has_method("get_meta") else []
		if patrons.is_empty():
			patron_details.text = "[color=gray]No patrons generated for this character[/color]"
		else:
			var patron_text = ""
			for patron in patrons:
				patron_text += "[b]%s[/b] (%s)\n" % [patron.get("name", "Unknown"), patron.get("type", "Unknown")]
				patron_text += "Reputation: %d\n" % patron.get("reputation", 0)
				patron_text += "Job Rate: %d%%\n\n" % patron.get("job_rate", 50)
			patron_details.text = patron_text
	
	# Update rival details  
	if rival_details:
		var rivals = character.get_meta("generated_rivals", []) if character.has_method("get_meta") else []
		if rivals.is_empty():
			rival_details.text = "[color=gray]No rivals generated for this character[/color]"
		else:
			var rival_text = ""
			for rival in rivals:
				rival_text += "[b][color=red]%s[/color][/b] (%s)\n" % [rival.get("name", "Unknown"), _get_enemy_type_name(rival.get("type", 0))]
				rival_text += "Threat Level: %d\n" % rival.get("level", 1)
				rival_text += "Reputation: %d\n\n" % rival.get("reputation", 0)
			rival_details.text = rival_text
	
	# Update equipment details
	if equipment_details:
		var equipment = character.get_meta("personal_equipment", {}) if character.has_method("get_meta") else {}
		if equipment.is_empty():
			equipment_details.text = "[color=gray]No starting equipment assigned[/color]"
		else:
			var equipment_text = ""
			for category in ["weapons", "armor", "gear"]:
				if equipment.has(category) and not equipment[category].is_empty():
					equipment_text += "[b]%s:[/b]\n" % category.capitalize()
					for item in equipment[category]:
						equipment_text += "• %s\n" % str(item)
					equipment_text += "\n"
			
			if equipment.has("credits") and equipment.credits > 0:
				equipment_text += "[b]Credits:[/b] %d\n" % equipment.credits
			
			if equipment_text.is_empty():
				equipment_details.text = "[color=gray]No equipment items listed[/color]"
			else:
				equipment_details.text = equipment_text

func _get_enemy_type_name(type_id: int) -> String:
	"""Get enemy type name for display"""
	if GlobalEnums and type_id >= 0 and type_id < GlobalEnums.EnemyType.size():
		return GlobalEnums.EnemyType.keys()[type_id]
	return "Unknown"

func _display_character_details(character: Character) -> void:
	"""Display character details in the UI"""
	if not character_details:
		return

	var details = "[b]%s[/b]\n\n" % (character.character_name if character.character_name else "Unknown")
	details += "Class: %s\n" % _get_class_name(character.character_class if character.character_class else 0)
	
	# Add background and motivation if available
	if character.has_method("get") or character.has_meta("background"):
		var background_id = character.get("background") if character.has_method("get") else character.get_meta("background", 0)
		var motivation_id = character.get("motivation") if character.has_method("get") else character.get_meta("motivation", 0)
		details += "Background: %s\n" % _get_background_name(background_id)
		details += "Motivation: %s\n" % _get_motivation_name(motivation_id)
	
	details += "\n[b]Attributes:[/b]\n"
	details += "Reactions: %d\n" % (character.reaction if character.reaction else 1)
	details += "Speed: %d\"\n" % (character.speed if character.speed else 4)
	details += "Combat Skill: +%d\n" % (character.combat if character.combat else 0)
	details += "Toughness: %d\n" % (character.toughness if character.toughness else 3)
	details += "Savvy: +%d\n" % (character.savvy if character.savvy else 0)

	character_details.text = details
	
	# Update patron, rival, and equipment details
	_update_character_relationship_displays(character)

func _on_character_box_selected(character: Character) -> void:
	"""Handle character box selection"""
	if character:
		_display_character_details(character)

func _update_ui_state() -> void:
	"""Update UI state based on current crew data"""
	var current_crew_size = get_crew_size()
	
	# Update generate button
	if generate_button:
		generate_button.disabled = current_crew_size >= crew_creation_data.size
		if current_crew_size >= crew_creation_data.size:
			generate_button.text = "Crew Complete"
		else:
			generate_button.text = "Generate Character (%d/%d)" % [current_crew_size, crew_creation_data.size]

	# Update create button
	_validate_crew()

func _on_create_pressed() -> void:
	if _validate_crew():
		# Use BaseCrewComponent crew data with creation-specific metadata
		var final_crew_data = crew_creation_data.duplicate()
		final_crew_data["crew_members"] = get_crew_members() # Get Character objects from base component
		final_crew_data["captain"] = get_captain()
		final_crew_data["crew_statistics"] = calculate_crew_statistics()
		final_crew_data["crew_export_data"] = export_crew_data()

		self.crew_created.emit(final_crew_data)

		print("InitialCrewCreation: Crew created with %d characters" % get_crew_size())

		# Navigate to crew management after successful creation
		_navigate_after_crew_creation()

func _navigate_after_crew_creation() -> void:
	"""Navigate to appropriate screen after crew creation"""
	var scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router and scene_router and scene_router.has_method("navigate_to"):
		# Navigate to advancement manager to view and manage the crew
		scene_router.navigate_to("advancement_manager")
		print("InitialCrewCreation: Navigating to crew management")
	else:
		# Fallback: Show success message
		push_warning("InitialCrewCreation: SceneRouter not available, crew created but navigation unavailable")
		_show_crew_creation_success()

func _show_crew_creation_success() -> void:
	"""Show success message when navigation unavailable"""
	# Update generate button to show success
	if generate_button:
		generate_button.text = "Crew Created Successfully!"
		generate_button.modulate = Color.GREEN

	# Disable create button to prevent duplicate creation
	if create_button:
		create_button.disabled = true
		create_button.text = "Crew Created"

## Additional public methods for initial crew creation
func get_crew_creation_data() -> Dictionary:
	"""Get crew creation specific data"""
	return crew_creation_data

func set_crew_size(size: int) -> void:
	"""Set the target crew size for creation"""
	crew_creation_data.size = size
	_update_ui_state()

func set_crew_name(name: String) -> void:
	"""Set the crew name"""
	crew_creation_data.name = name
	_validate_crew()

## Campaign Creation State Bridge Integration

func setup_for_campaign_creation() -> void:
	"""Setup InitialCrewCreation for campaign creation workflow integration"""
	print("InitialCrewCreation: Setting up for campaign creation workflow")
	
	# Check for NEW workflow context manager first
	var workflow_manager = get_node_or_null("/root/WorkflowContextManager")
	if workflow_manager:
		print("InitialCrewCreation: NEW workflow context manager found - using modular approach")
		_setup_workflow_integration(workflow_manager)
		return
	
	# Fallback to legacy state bridge system
	var state_bridge = get_node_or_null("/root/CampaignCreationStateBridge")
	if state_bridge:
		print("InitialCrewCreation: Connected to CampaignCreationStateBridge (legacy mode)")
		
		# Get scene context from bridge
		var scene_context = state_bridge.get_scene_context()
		print("InitialCrewCreation: Scene context: ", scene_context)
		
		# Apply any pre-configured crew settings
		if scene_context.has("crew_size"):
			set_crew_size(scene_context.crew_size)
		if scene_context.has("crew_name"):
			set_crew_name(scene_context.crew_name)
		
		# Connect our signals to the state bridge
		_connect_state_bridge_signals(state_bridge)
		
		# Load any existing crew data from campaign state
		_load_existing_crew_from_campaign(state_bridge)
	else:
		push_warning("InitialCrewCreation: No workflow system found - operating in standalone mode")

func _setup_workflow_integration(workflow_manager: Node) -> void:
	"""Setup NEW workflow context manager integration"""
	print("InitialCrewCreation: Setting up NEW workflow integration")
	
	# Get current workflow context
	var context = workflow_manager.get_context()
	if context and context.has("campaign_data"):
		var campaign_data = context.campaign_data
		
		# Apply pre-configured crew settings from workflow
		if campaign_data.has("crew_size"):
			set_crew_size(campaign_data.crew_size)
			print("InitialCrewCreation: Applied workflow crew size: ", campaign_data.crew_size)
		
		if campaign_data.has("crew_name"):
			set_crew_name(campaign_data.crew_name)
			print("InitialCrewCreation: Applied workflow crew name: ", campaign_data.crew_name)
		
		# Load existing crew data if available
		if campaign_data.has("crew") and not campaign_data.crew.is_empty():
			_load_existing_crew_from_workflow(campaign_data.crew)
	
	# Connect completion signal to workflow callback
	if context and context.has("completion_callback"):
		# Disconnect any existing crew_created connections to avoid duplicates
		if crew_created.is_connected(_on_crew_created_for_campaign):
			crew_created.disconnect(_on_crew_created_for_campaign)
		
		# Connect to workflow completion handler
		crew_created.connect(_on_crew_created_for_workflow)
		print("InitialCrewCreation: Connected to workflow completion system")

func _load_existing_crew_from_workflow(crew_data: Dictionary) -> void:
	"""Load existing crew data from workflow context"""
	if crew_data.is_empty():
		return
	
	print("InitialCrewCreation: Loading existing crew data from workflow")
	
	# Load crew metadata
	if crew_data.has("name"):
		crew_name_input.text = crew_data.name
		crew_creation_data.name = crew_data.name
	
	if crew_data.has("size"):
		crew_creation_data.size = crew_data.size
		crew_size_option.selected = crew_data.size - 1  # Convert size to index
	
	# Load existing crew members
	var existing_members = crew_data.get("crew_members", [])
	for member in existing_members:
		if member is Character:
			# Add existing character to crew
			add_crew_member(member)
			
			# Add to UI using character box
			_create_character_box(member)
	
	_update_ui_state()
	print("InitialCrewCreation: Loaded %d existing crew members from workflow" % existing_members.size())

func _on_crew_created_for_workflow(crew_data: Dictionary) -> void:
	"""Handle crew creation completion in NEW workflow context"""
	print("InitialCrewCreation: Crew created for workflow with %d members" % crew_data.get("crew_members", []).size())
	
	var workflow_manager = get_node_or_null("/root/WorkflowContextManager")
	if not workflow_manager:
		push_error("InitialCrewCreation: WorkflowContextManager not available for completion")
		return
	
	# Get current context to access completion callback
	var context = workflow_manager.get_context()
	if context and context.has("completion_callback"):
		var completion_callback = context.completion_callback
		if completion_callback.is_valid():
			print("InitialCrewCreation: Calling workflow completion callback")
			completion_callback.call(crew_data)
		else:
			push_warning("InitialCrewCreation: Workflow completion callback is invalid")
	else:
		push_warning("InitialCrewCreation: No workflow completion callback found")

func _connect_state_bridge_signals(state_bridge: Node) -> void:
	"""Connect InitialCrewCreation signals to CampaignCreationStateBridge"""
	if not state_bridge:
		return
	
	# Connect crew creation signals to bridge
	if not crew_created.is_connected(_on_crew_created_for_campaign):
		crew_created.connect(_on_crew_created_for_campaign)

func _load_existing_crew_from_campaign(state_bridge: Node) -> void:
	"""Load existing crew data from campaign state if available"""
	if not state_bridge or not state_bridge.has_method("get_campaign_data"):
		return
	
	var campaign_data = state_bridge.get_campaign_data()
	var crew_data = campaign_data.get("crew", {})
	
	if not crew_data.is_empty():
		print("InitialCrewCreation: Loading existing crew data from campaign")
		
		# Load crew metadata
		if crew_data.has("name"):
			crew_name_input.text = crew_data.name
			crew_creation_data.name = crew_data.name
		
		if crew_data.has("size"):
			crew_creation_data.size = crew_data.size
			crew_size_option.selected = crew_data.size - 1  # Convert size to index
		
		# Load existing crew members
		var existing_members = crew_data.get("crew_members", [])
		for member in existing_members:
			if member is Character:
				# Add existing character to crew
				add_crew_member(member)
				
				# Add to UI using character box
				_create_character_box(member)
		
		_update_ui_state()
		print("InitialCrewCreation: Loaded %d existing crew members" % existing_members.size())

func _on_crew_created_for_campaign(crew_data: Dictionary) -> void:
	"""Handle crew creation completion in campaign context"""
	print("InitialCrewCreation: Crew created for campaign with %d members" % crew_data.get("crew_members", []).size())
	
	var state_bridge = get_node_or_null("/root/CampaignCreationStateBridge")
	if state_bridge and state_bridge.has_method("handle_crew_creation_data"):
		state_bridge.handle_crew_creation_data(crew_data)
		
		# Mark crew creation as complete
		state_bridge.register_scene_completion("crew_creation", true)
	
	# Navigate to next step in campaign creation
	_proceed_to_next_campaign_step()

func _proceed_to_next_campaign_step() -> void:
	"""Proceed to the next step in campaign creation workflow"""
	var state_bridge = get_node_or_null("/root/CampaignCreationStateBridge")
	var scene_router = get_node_or_null("/root/SceneRouter")
	
	if state_bridge and scene_router:
		# Determine next scene based on campaign creation flow
		var next_scene = state_bridge.get_next_scene_in_flow("crew_creation")
		
		if next_scene.is_empty():
			# Default to equipment generation if no specific next scene
			next_scene = "equipment_generation"
		
		print("InitialCrewCreation: Proceeding to next campaign step: ", next_scene)
		
		# Navigate to next scene
		if scene_router.has_method("navigate_to"):
			scene_router.navigate_to(next_scene)
		else:
			state_bridge.transition_to_scene(next_scene)
	else:
		push_warning("InitialCrewCreation: Cannot proceed to next step - state bridge or scene router not available")

func request_character_editing(character: Character) -> void:
	"""Request character editing through campaign creation flow"""
	print("InitialCrewCreation: Requesting character editing for: ", character.character_name)
	
	var state_bridge = get_node_or_null("/root/CampaignCreationStateBridge")
	var scene_router = get_node_or_null("/root/SceneRouter")
	
	if state_bridge and scene_router:
		# Set up context for character editing
		var edit_context = {
			"edit_character": true,
			"character_data": character,
			"return_scene": "crew_creation"
		}
		
		# Navigate to character creator
		if scene_router.has_method("navigate_to"):
			scene_router.navigate_to("character_creator", edit_context)
		else:
			state_bridge.transition_to_scene("character_creator", edit_context)
	else:
		push_warning("InitialCrewCreation: Cannot request character editing - state bridge or scene router not available")

func add_edit_character_button() -> void:
	"""Add character editing functionality to the UI"""
	# This would be called from the UI setup to add edit buttons to character list items
	# Implementation depends on the specific UI structure
	print("InitialCrewCreation: Character editing functionality available through campaign flow")

## Enhanced _ready() for campaign integration
func _ready() -> void:
	# Call parent initialization first
	super._ready()
	
	print("InitialCrewCreation: Initializing standalone crew creation UI...")
	call_deferred("_setup_initial_crew_creation")
	
	# Setup campaign integration
	call_deferred("setup_for_campaign_creation")

func cleanup() -> void:
	"""Clean up the crew creation state when navigating away"""
	print("InitialCrewCreation: Cleaning up crew creation state")
	
	# Clear crew creation data
	crew_creation_data = {
		"name": "",
		"size": 4,
		"characters": []
	}
	
	# Clear character list container
	if character_list_container:
		for child in character_list_container.get_children():
			child.queue_free()
	
	# Reset UI state
	if crew_size_option:
		crew_size_option.selected = 3  # Index 3 = 4 members
	
	if crew_name_input:
		crew_name_input.text = ""
	
	if create_button:
		create_button.disabled = true
	
	# Clear any stored crew members
	clear_crew()
	
	print("InitialCrewCreation: Cleanup completed")
