class_name FPCM_InitialCrewCreationUI
extends BaseCrewComponent

## Five Parsecs Initial Crew Creation UI
## Now extends BaseCrewComponent for shared crew management functionality
## Focused on standalone crew creation workflow

# Additional signals specific to initial crew creation
signal crew_created(crew_data: Dictionary)
signal character_generated(character: Character)

@onready var crew_size_option := %CrewSizeOption
@onready var crew_name_input := %CrewNameInput
@onready var character_list := $MarginContainer/VBoxContainer/MainContent/CharacterList
@onready var create_button := %CreateButton
@onready var generate_button := %GenerateButton
@onready var character_details := %CharacterDetails

# Crew creation specific data (BaseCrewComponent handles core crew data)
var crew_creation_data := {
	"name": "",
	"size": 4,
	"characters": []
}

var character_manager: Node = null

func _ready() -> void:
	# Call parent initialization first
	super._ready()
	
	print("InitialCrewCreation: Initializing standalone crew creation UI...")
	call_deferred("_setup_initial_crew_creation")

func _setup_initial_crew_creation() -> void:
	_initialize_character_system()
	_connect_signals()
	_setup_options()

func _initialize_character_system() -> void:
	"""Initialize connection to character generation system"""
	# Connect to CharacterManager through GameStateManager
	var game_state: Node = get_node_or_null("/root/GameStateManagerAutoload")
	if game_state and game_state and game_state.has_method("get_manager"):
		character_manager = game_state.get_manager("CharacterManager")
		if character_manager:
			print("InitialCrewCreation: Connected to CharacterManager")
		else:
			push_warning("InitialCrewCreation: CharacterManager not available")
	else:
		push_warning("InitialCrewCreation: GameStateManager not available")

func _connect_signals() -> void:
	crew_size_option.value_changed.connect(_on_crew_size_changed)
	crew_name_input.text_changed.connect(_on_crew_name_changed)
	create_button.pressed.connect(_on_create_pressed)

	# Connect character generation button if available
	if generate_button:
		generate_button.pressed.connect(_on_generate_character)

	# Connect character list selection
	if character_list and character_list.has_signal("item_selected"):
		character_list.item_selected.connect(_on_character_list_selected)

func _setup_options() -> void:
	crew_size_option.setup(4, "Select the size of your starting crew")
	create_button.disabled = true

	# Enable character generation if components are available
	if generate_button:
		generate_button.text = "Generate Character"
		generate_button.disabled = false

	# Setup character list
	if character_list:
		character_list.clear()

	_update_ui_state()

func _on_crew_size_changed(size: int) -> void:
	crew_creation_data.size = size
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

func _on_generate_character() -> void:
	"""Generate a new Five Parsecs character using BaseCrewComponent"""
	if get_crew_size() >= crew_creation_data.size:
		push_warning("InitialCrewCreation: Crew already at maximum size")
		return

	# Use BaseCrewComponent's character generation
	var character: Character = generate_random_character()

	if character:
		# Add to base component crew
		var success = add_crew_member(character)
		
		if success:
			# Add to UI list
			var character_name: String = "%s (%s)" % [
				character.character_name,
				_get_class_name(character.character_class)
			]

			if character_list:
				character_list.add_item(character_name)
				# Auto-select the new character
				character_list.select(character_list.get_item_count() - 1)
				_display_character_details(character)

			# Convert to dictionary format for crew_creation_data
			var character_dict: Dictionary = _character_to_dict(character)
			crew_creation_data.characters.append(character_dict)

			_update_ui_state()

			# Emit signal
			self.character_generated.emit(character)

			print("InitialCrewCreation: Generated character: ", character_name)
		else:
			push_error("InitialCrewCreation: Failed to add character to crew")
	else:
		push_error("InitialCrewCreation: Failed to generate character")

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
	const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

	if GlobalEnums and class_id >= 0 and class_id < GlobalEnums.CharacterClass.size():
		return GlobalEnums.CharacterClass.keys()[class_id]
	return "Unknown"

func _display_character_details(character: Character) -> void:
	"""Display character details in the UI"""
	if not character_details:
		return

	var details = "[b]%s[/b]\n\n" % (character.character_name if character.character_name else "Unknown")
	details += "Class: %s\n" % _get_class_name(character.character_class if character.character_class else 0)
	details += "\n[b]Attributes:[/b]\n"
	details += "Reactions: %d\n" % (character.reaction if character.reaction else 1)
	details += "Speed: %d\"\n" % (character.speed if character.speed else 4)
	details += "Combat Skill: +%d\n" % (character.combat if character.combat else 0)
	details += "Toughness: %d\n" % (character.toughness if character.toughness else 3)
	details += "Savvy: +%d\n" % (character.savvy if character.savvy else 0)

	character_details.text = details

func _on_character_list_selected(index: int) -> void:
	"""Handle character selection in list"""
	var crew_members_array = get_crew_members()
	if index >= 0 and index < crew_members_array.size():
		_display_character_details(crew_members_array[index])

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