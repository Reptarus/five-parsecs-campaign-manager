# DEPRECATED: 2025-12-29 - Replaced by modern CrewPanel UI
# class_name removed to prevent global script conflict
extends BaseCrewComponent

## Five Parsecs Initial Crew Creation UI (DEPRECATED)
## This file is kept for reference only - not used in production
## Modern crew UI is built programmatically in CrewPanel.gd

# Enhanced Five Parsecs character generation system

# Additional signals specific to initial crew creation
signal crew_created(crew_data: Dictionary)
signal character_generated(character: Character)

@onready var crew_size_option := %CrewSizeOption
@onready var crew_name_input := %CrewNameInput
@onready var character_list_container := %Content # This should be the available characters container
@onready var create_button := %CreateButton
@onready var generate_button := %GenerateButton
@onready var character_details := %CharacterDetails
@onready var patron_details := %PatronDetails
@onready var rival_details := %RivalDetails
@onready var equipment_details := %EquipmentDetails
@onready var species_option := %SpeciesOption
@onready var random_species := %RandomSpecies

# Bespoke creation mode nodes
@onready var random_mode_button := %RandomModeButton
@onready var bespoke_mode_button := %BespokeModeButton
@onready var background_container := $MarginContainer/VBoxContainer/MainContent/CharacterList/VBoxContainer/BackgroundContainer
@onready var background_option := %BackgroundOption
@onready var motivation_container := $MarginContainer/VBoxContainer/MainContent/CharacterList/VBoxContainer/MotivationContainer
@onready var motivation_option := %MotivationOption
@onready var class_container := $MarginContainer/VBoxContainer/MainContent/CharacterList/VBoxContainer/ClassContainer
@onready var class_option := %ClassOption

# Character creation data loaded from JSON
var species_data: Dictionary = {}
var background_data: Dictionary = {}
var motivation_data: Dictionary = {}
var class_data: Dictionary = {}

# Bespoke creation mode flag
var bespoke_mode: bool = false

# Resource tracking via CrewCreation
const CrewCreationClass = preload("res://src/core/campaign/crew/CrewCreation.gd")
var crew_creation_tracker: Node = null

# Crew creation specific data (BaseCrewComponent handles core crew data)
var crew_creation_data := {
	"name": "",
	"size": 4,
	"characters": []
}

# PHASE 5: Coordinator integration for workflow support
var coordinator: Variant = null  # Changed from Node to Variant to accept RefCounted objects
var workflow_mode: bool = false

# REMOVED: var character_manager: Node = null - no longer needed with static methods

# _ready() implementation moved to end of file for campaign integration

# PHASE 5: Coordinator integration methods
func set_coordinator(coord: Variant) -> void:
	"""Set the coordinator for workflow integration - accepts both Node and RefCounted"""
	coordinator = coord
	workflow_mode = true
	print("InitialCrewCreation: Coordinator set - workflow mode enabled")
	_configure_workflow_mode()

func _configure_workflow_mode() -> void:
	"""Configure UI for workflow integration with coordinator"""
	if not coordinator:
		return

	print("InitialCrewCreation: Configuring workflow mode with coordinator access")
	# In workflow mode, we can leverage coordinator's state management
	# This enables better integration with the overall campaign creation flow

	# Hide redundant TitlePanel when embedded in CrewPanel (CrewPanel provides the title)
	var title_panel = get_node_or_null("MarginContainer/VBoxContainer/TitlePanel")
	if title_panel:
		title_panel.visible = false
		print("InitialCrewCreation: TitlePanel hidden (using parent panel title)")

	# Connect to coordinator signals if available
	if coordinator.has_signal("panel_transition_requested"):
		coordinator.connect("panel_transition_requested", _on_coordinator_transition_request)

func _report_workflow_completion(crew_data: Dictionary) -> void:
	"""Report crew creation completion back to coordinator in workflow mode"""
	if not coordinator or not workflow_mode:
		return
	
	print("InitialCrewCreation: Reporting workflow completion to coordinator")
	
	# Send completion data to coordinator
	if coordinator.has_method("handle_crew_completion"):
		coordinator.handle_crew_completion(crew_data)
	
	# Trigger workflow progression if coordinator supports it
	if coordinator.has_method("progress_workflow"):
		coordinator.progress_workflow("crew_creation", crew_data)

func _on_coordinator_transition_request(transition_data: Dictionary) -> void:
	"""Handle transition requests from coordinator"""
	print("InitialCrewCreation: Received transition request from coordinator")
	# Handle coordinator-driven transitions in workflow mode

func _setup_initial_crew_creation() -> void:
	_load_species_data()
	_load_character_tables()
	_initialize_character_system()
	_initialize_resource_tracker()
	_connect_signals()
	_setup_options()
	_setup_mode_buttons()

func _load_character_tables() -> void:
	"""Load background, motivation, and class tables from JSON"""
	# Load background table
	var bg_path = "res://data/character_creation_tables/background_table.json"
	if FileAccess.file_exists(bg_path):
		var file = FileAccess.open(bg_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				background_data = json.get_data()
				print("InitialCrewCreation: Loaded background table with %d entries" % background_data.get("entries", {}).size())
			file.close()

	# Load motivation table
	var mot_path = "res://data/character_creation_tables/motivation_table.json"
	if FileAccess.file_exists(mot_path):
		var file = FileAccess.open(mot_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				motivation_data = json.get_data()
				print("InitialCrewCreation: Loaded motivation table with %d entries" % motivation_data.size())
			file.close()

	# Load class table
	var cls_path = "res://data/character_creation_tables/class_table.json"
	if FileAccess.file_exists(cls_path):
		var file = FileAccess.open(cls_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				class_data = json.get_data()
				print("InitialCrewCreation: Loaded class table with %d entries" % class_data.get("entries", {}).size())
			file.close()

func _setup_mode_buttons() -> void:
	"""Setup the Random/Bespoke mode toggle buttons"""
	if random_mode_button:
		random_mode_button.pressed.connect(_on_random_mode_selected)
	if bespoke_mode_button:
		bespoke_mode_button.pressed.connect(_on_bespoke_mode_selected)
	# Start in random mode
	_set_creation_mode(false)

func _on_random_mode_selected() -> void:
	_set_creation_mode(false)

func _on_bespoke_mode_selected() -> void:
	_set_creation_mode(true)

func _set_creation_mode(is_bespoke: bool) -> void:
	"""Toggle between random and bespoke creation modes"""
	bespoke_mode = is_bespoke

	# Update button states
	if random_mode_button:
		random_mode_button.button_pressed = not is_bespoke
	if bespoke_mode_button:
		bespoke_mode_button.button_pressed = is_bespoke

	# Show/hide bespoke-only fields
	if background_container:
		background_container.visible = is_bespoke
	if motivation_container:
		motivation_container.visible = is_bespoke
	if class_container:
		class_container.visible = is_bespoke

	# Hide random species checkbox in bespoke mode
	if random_species:
		random_species.visible = not is_bespoke
		if is_bespoke:
			random_species.button_pressed = false

	# Update button text
	if generate_button:
		generate_button.text = "Create Character" if is_bespoke else "Generate Character"

	print("InitialCrewCreation: Mode set to %s" % ("Bespoke" if is_bespoke else "Random"))

func _initialize_resource_tracker() -> void:
	"""Initialize CrewCreation for resource tracking"""
	crew_creation_tracker = CrewCreationClass.new()
	crew_creation_tracker.name = "CrewCreationTracker"
	add_child(crew_creation_tracker)
	print("InitialCrewCreation: Resource tracker initialized")

func _load_species_data() -> void:
	"""Load species data from character_creation_data.json"""
	var file_path = "res://data/character_creation_data.json"
	if not FileAccess.file_exists(file_path):
		push_warning("InitialCrewCreation: character_creation_data.json not found")
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("InitialCrewCreation: Failed to open character_creation_data.json")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("InitialCrewCreation: Failed to parse character_creation_data.json")
		return

	var data = json.get_data()
	if data.has("origins"):
		species_data = data.origins
		print("InitialCrewCreation: Loaded %d species from JSON" % species_data.size())

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
	if generate_button and not generate_button.pressed.is_connected(_on_generate_character):
		generate_button.pressed.connect(_on_generate_character)

func _on_generate_character() -> void:
	"""Production-ready character generation using Framework Bible patterns"""
	if bespoke_mode:
		print("InitialCrewCreation: Creating bespoke character with user selections")
		_create_bespoke_character()
	else:
		print("InitialCrewCreation: Generating random character via direct Character class")
		_create_random_character()

func _create_random_character() -> void:
	"""Generate a random character using dice rolls"""
	# Determine species to use
	var selected_species := ""
	if random_species and random_species.button_pressed:
		# Random species selection
		if species_data.size() > 0:
			var species_keys = species_data.keys()
			selected_species = species_keys[randi() % species_keys.size()]
			print("InitialCrewCreation: Random species selected: %s" % selected_species)
	elif species_option and species_option.selected >= 0:
		# Use selected species from dropdown
		selected_species = species_option.get_item_metadata(species_option.selected)
		print("InitialCrewCreation: Selected species: %s" % selected_species)

	# Direct static call eliminates Manager dependency
	var new_character = Character.generate_character(selected_species)

	if new_character and new_character.is_valid():
		# Apply species-specific stats if available
		if selected_species != "" and species_data.has(selected_species):
			_apply_species_data(new_character, species_data[selected_species])

		# Track resources through CrewCreation
		if crew_creation_tracker and crew_creation_tracker.has_method("apply_tables_to_character"):
			crew_creation_tracker.apply_tables_to_character(new_character)
			print("InitialCrewCreation: Resources tracked for %s" % new_character.character_name)

		_finalize_character(new_character, selected_species)
	else:
		push_error("Generated character failed validation")
		_show_error_dialog("Character generation failed. Please try again.")

func _create_bespoke_character() -> void:
	"""Create a character with user-selected background, motivation, and class"""
	# Get selected species
	var selected_species := ""
	if species_option and species_option.selected >= 0:
		selected_species = species_option.get_item_metadata(species_option.selected)

	# Create new character with basic generation
	var new_character = Character.generate_character(selected_species)
	if not new_character or not new_character.is_valid():
		push_error("Failed to create base character")
		_show_error_dialog("Character creation failed. Please try again.")
		return

	# Apply species-specific stats
	if selected_species != "" and species_data.has(selected_species):
		_apply_species_data(new_character, species_data[selected_species])

	# Apply selected background
	if background_option and background_option.selected >= 0:
		var bg_key = background_option.get_item_metadata(background_option.selected)
		var entries = background_data.get("entries", {})
		if entries.has(bg_key):
			var bg = entries[bg_key]
			new_character.background = bg.get("name", "Unknown")
			_apply_table_bonuses(new_character, bg)
			print("InitialCrewCreation: Applied background '%s'" % new_character.background)

	# Apply selected motivation
	if motivation_option and motivation_option.selected >= 0:
		var mot_key = motivation_option.get_item_metadata(motivation_option.selected)
		if motivation_data.has(mot_key):
			var mot = motivation_data[mot_key]
			new_character.motivation = mot.get("name", "Unknown")
			print("InitialCrewCreation: Applied motivation '%s'" % new_character.motivation)

	# Apply selected class
	if class_option and class_option.selected >= 0:
		var cls_key = class_option.get_item_metadata(class_option.selected)
		var entries = class_data.get("entries", {})
		if entries.has(cls_key):
			var cls = entries[cls_key]
			new_character.character_class = cls.get("name", "Unknown")
			_apply_table_bonuses(new_character, cls)
			print("InitialCrewCreation: Applied class '%s'" % new_character.character_class)

	# Track resources - add 1 credit per crew member
	if crew_creation_tracker:
		crew_creation_tracker.accumulated_resources.credits += 1

	_finalize_character(new_character, selected_species)

func _apply_table_bonuses(character: Character, table_entry: Dictionary) -> void:
	"""Apply stat bonuses and resources from a background or class table entry"""
	# Apply stat bonuses
	var bonuses = table_entry.get("stat_bonuses", {})
	character.combat += bonuses.get("combat", 0)
	character.toughness += bonuses.get("toughness", 0)
	character.savvy += bonuses.get("savvy", 0)
	character.speed += bonuses.get("speed", 0)
	character.reactions += bonuses.get("reactions", 0)

	# Apply special bonuses (luck, xp)
	var special = table_entry.get("special", {})
	if "luck" in special:
		character.luck = max(character.luck, int(special.luck))
	if "xp" in special:
		character.experience = int(special.xp)

	# Track resources if we have the tracker
	if not crew_creation_tracker:
		return

	var resources = table_entry.get("resources", {})

	# Credits
	if "credits_roll" in resources:
		var credits = _roll_dice_string(resources.credits_roll)
		crew_creation_tracker.accumulated_resources.credits += credits

	# Patron
	if resources.get("patron", false):
		crew_creation_tracker.accumulated_resources.patrons.append(table_entry.get("name", "Unknown"))

	# Story points
	crew_creation_tracker.accumulated_resources.story_points += resources.get("story_points", 0)

	# Quest rumors
	var rumors = resources.get("quest_rumors", 0)
	for i in range(rumors):
		crew_creation_tracker.accumulated_resources.quest_rumors.append("From: %s" % table_entry.get("name", "Unknown"))

	# Rival
	if resources.get("rival", false):
		crew_creation_tracker.accumulated_resources.rivals.append("From %s" % table_entry.get("name", "Unknown"))

func _roll_dice_string(dice_string: String) -> int:
	"""Roll dice from a string like '1D6' or '2D6'"""
	var result = 0
	dice_string = dice_string.to_upper()

	if "D6" in dice_string:
		var num_dice = 1
		var parts = dice_string.split("D")
		if parts.size() == 2 and parts[0] != "":
			num_dice = int(parts[0])
		for i in range(num_dice):
			result += randi() % 6 + 1
	elif "D10" in dice_string:
		var num_dice = 1
		var parts = dice_string.split("D")
		if parts.size() == 2 and parts[0] != "":
			num_dice = int(parts[0])
		for i in range(num_dice):
			result += randi() % 10 + 1

	return result

func _finalize_character(new_character: Character, selected_species: String) -> void:
	"""Add character to crew and update UI"""
	crew_members.append(new_character)
	_update_character_display()
	_update_ui_state()
	print("Character created successfully: %s (%s/%s/%s) - Species: %s" % [
		new_character.character_name,
		new_character.background,
		new_character.motivation,
		new_character.character_class,
		selected_species
	])

	# Emit signal for parent components
	if has_signal("character_generated"):
		character_generated.emit(new_character)

func _apply_species_data(character: Character, species_info: Dictionary) -> void:
	"""Apply species-specific stats and characteristics to character"""
	if not character or species_info.is_empty():
		return

	# Set origin/species name
	character.origin = species_info.get("name", "Human")

	# Apply base stats
	var base_stats = species_info.get("base_stats", {})
	if base_stats.has("REACTIONS"):
		character.reactions = base_stats.REACTIONS
	if base_stats.has("SPEED"):
		character.speed = base_stats.SPEED
	if base_stats.has("COMBAT_SKILL"):
		character.combat = base_stats.COMBAT_SKILL
	if base_stats.has("TOUGHNESS"):
		character.toughness = base_stats.TOUGHNESS
	if base_stats.has("SAVVY"):
		character.savvy = base_stats.SAVVY

	# Store characteristics as metadata for display
	var characteristics = species_info.get("characteristics", [])
	if characteristics.size() > 0:
		character.set_meta("species_characteristics", characteristics)

	print("InitialCrewCreation: Applied %s species data to %s" % [species_info.get("name", "Unknown"), character.character_name])

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
	for i in range(1, 9): # Crew sizes 1-8
		crew_size_option.add_item(str(i) + " members")
	crew_size_option.selected = 5 # Default to 6 members (index 5)
	create_button.disabled = true

	# Setup species dropdown
	if species_option:
		species_option.clear()
		for species_key in species_data:
			var species_info = species_data[species_key]
			var display_name = species_info.get("name", species_key)
			species_option.add_item(display_name)
			species_option.set_item_metadata(species_option.item_count - 1, species_key)

		if species_option.item_count > 0:
			species_option.selected = 0

	# Setup background dropdown
	if background_option:
		background_option.clear()
		var entries = background_data.get("entries", {})
		for range_key in entries:
			var entry = entries[range_key]
			var name = entry.get("name", "Unknown")
			background_option.add_item(name)
			background_option.set_item_metadata(background_option.item_count - 1, range_key)

		if background_option.item_count > 0:
			background_option.selected = 0
		print("InitialCrewCreation: Populated %d backgrounds" % background_option.item_count)

	# Setup motivation dropdown
	if motivation_option:
		motivation_option.clear()
		for key in motivation_data:
			var entry = motivation_data[key]
			var name = entry.get("name", "Unknown")
			motivation_option.add_item(name)
			motivation_option.set_item_metadata(motivation_option.item_count - 1, key)

		if motivation_option.item_count > 0:
			motivation_option.selected = 0
		print("InitialCrewCreation: Populated %d motivations" % motivation_option.item_count)

	# Setup class dropdown
	if class_option:
		class_option.clear()
		var entries = class_data.get("entries", {})
		for range_key in entries:
			var entry = entries[range_key]
			var name = entry.get("name", "Unknown")
			class_option.add_item(name)
			class_option.set_item_metadata(class_option.item_count - 1, range_key)

		if class_option.item_count > 0:
			class_option.selected = 0
		print("InitialCrewCreation: Populated %d classes" % class_option.item_count)
		print("InitialCrewCreation: Populated species dropdown with %d options" % species_option.item_count)

	# Connect random species checkbox
	if random_species:
		if not random_species.toggled.is_connected(_on_random_species_toggled):
			random_species.toggled.connect(_on_random_species_toggled)
		_on_random_species_toggled(random_species.button_pressed)

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

func _on_random_species_toggled(toggled_on: bool) -> void:
	"""Handle random species checkbox toggle"""
	if species_option:
		species_option.disabled = toggled_on

func _on_crew_size_changed(index: int) -> void:
	crew_creation_data.size = index + 1 # Convert index to actual size
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
		push_warning("InitialCrewCreation: character_list_container is null!")
		return

	# Load the CharacterCard scene and script (script needed for CardVariant enum)
	var character_box_scene = preload("res://src/ui/components/character/CharacterCard.tscn")
	var CharacterCardScript = preload("res://src/ui/components/character/CharacterCard.gd")
	var character_box = character_box_scene.instantiate()

	# Set compact variant for list display
	if character_box.has_method("set_variant"):
		character_box.set_variant(CharacterCardScript.CardVariant.COMPACT)

	# Set up the character box with character data - CharacterCard uses set_character, not setup_character
	if character_box.has_method("set_character"):
		character_box.set_character(character)
	else:
		push_warning("InitialCrewCreation: CharacterCard has no set_character method!")

	# Connect selection signal if available
	if character_box.has_signal("character_selected"):
		character_box.character_selected.connect(_on_character_box_selected)

	# Add to the container
	character_list_container.add_child(character_box)

	print("InitialCrewCreation: Created character box for: ", character.character_name)

func _update_character_display() -> void:
	"""Update the character display with all current crew members"""
	if not character_list_container:
		return
	
	# Clear existing character boxes
	for child in character_list_container.get_children():
		child.queue_free()
	
	# Add character boxes for all crew members
	for member in crew_members:
		_create_character_box(member)

func _character_to_dict(character: Character) -> Dictionary:
	"""Convert Character object to dictionary format"""
	return {
		"name": character.character_name,
		"class": character.character_class,
		"background": character.background,
		"origin": character.origin,
		"reactions": character.reactions,
		"speed": character.speed,
		"combat": character.combat,
		"toughness": character.toughness,
		"savvy": character.savvy,
		"character_object": character
	}

func _get_class_name(class_id: int) -> String:
	"""Get class name for display"""
	# Use Engine.get_singleton for safe access to GlobalEnums
	var global_enums = Engine.get_singleton("GlobalEnums")
	if global_enums and global_enums.has_method("get_character_class_name"):
		return global_enums.get_character_class_name(class_id)
	return "Unknown"

func _get_background_name(background_id: int) -> String:
	"""Get background name for display"""
	var global_enums = Engine.get_singleton("GlobalEnums")
	if global_enums and global_enums.has_method("get_background_name"):
		return global_enums.get_background_name(background_id)
	return "Unknown"

func _get_motivation_name(motivation_id: int) -> String:
	"""Get motivation name for display"""
	var global_enums = Engine.get_singleton("GlobalEnums")
	if global_enums and global_enums.has_method("get_motivation_name"):
		return global_enums.get_motivation_name(motivation_id)
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
	var global_enums = Engine.get_singleton("GlobalEnums")
	if global_enums and global_enums.has_method("get_enemy_type_name"):
		return global_enums.get_enemy_type_name(type_id)
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
	details += "Reactions: %d\n" % (character.reactions if character.reactions else 1)
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
		final_crew_data["members"] = get_crew_members() # Get Character objects from base component
		final_crew_data["captain"] = get_captain()
		final_crew_data["crew_statistics"] = calculate_crew_statistics()
		final_crew_data["crew_export_data"] = export_crew_data()

		# Include accumulated resources from character creation
		if crew_creation_tracker and crew_creation_tracker.has_method("get_accumulated_resources"):
			var resources = crew_creation_tracker.get_accumulated_resources()
			final_crew_data["resources"] = resources
			print("InitialCrewCreation: Including accumulated resources - Credits: %d, Story Points: %d, Patrons: %d, Rivals: %d" % [
				resources.get("credits", 0),
				resources.get("story_points", 0),
				resources.get("patrons", []).size(),
				resources.get("rivals", []).size()
			])

		self.crew_created.emit(final_crew_data)

		# PHASE 5: Report completion to coordinator in workflow mode
		_report_workflow_completion(final_crew_data)

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
	
	# PRIORITY 1: Check if coordinator is already set (preferred method)
	if coordinator != null:
		print("InitialCrewCreation: ✅ Coordinator already available - using direct integration")
		_setup_coordinator_integration()
		return
	
	# PRIORITY 2: Check for NEW workflow context manager
	var workflow_manager = get_node_or_null("/root/WorkflowContextManager")
	if workflow_manager:
		print("InitialCrewCreation: NEW workflow context manager found - using modular approach")
		_setup_workflow_integration(workflow_manager)
		return
	
	# PRIORITY 3: Fallback to legacy state bridge system
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
		print("InitialCrewCreation: ⚠️ No workflow system available - operating in standalone mode")
		print("InitialCrewCreation: This is normal if coordinator will be set later by parent panel")

func _setup_coordinator_integration() -> void:
	"""Setup direct coordinator integration (preferred method)"""
	if not coordinator:
		return
		
	print("InitialCrewCreation: Setting up direct coordinator integration")
	
	# Get existing crew data from coordinator
	if coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		if state.has("crew") and state.crew.has("members") and not state.crew.members.is_empty():
			print("InitialCrewCreation: Loading existing crew data from coordinator")
			_load_existing_crew_from_coordinator(state.crew)
	
	# Setup completion callback
	if crew_created.is_connected(_on_crew_created_for_campaign):
		crew_created.disconnect(_on_crew_created_for_campaign)
	crew_created.connect(_on_crew_created_for_campaign)
	
	print("InitialCrewCreation: ✅ Coordinator integration setup complete")

func _load_existing_crew_from_coordinator(crew_state: Dictionary) -> void:
	"""Load existing crew data from coordinator state"""
	if crew_state.has("members") and crew_state.members.size() > 0:
		print("InitialCrewCreation: Loading %d existing crew members from coordinator" % crew_state.members.size())
		
		# Update local crew data
		crew_creation_data.members = crew_state.members.duplicate()
		crew_creation_data.is_complete = crew_state.get("is_complete", false)
		
		# Update UI to reflect loaded data
		_update_ui_from_loaded_data()
		
		print("InitialCrewCreation: ✅ Existing crew data loaded successfully")

func _update_ui_from_loaded_data() -> void:
	"""Update UI elements to reflect loaded crew data"""
	if crew_creation_data.members.size() > 0:
		# Enable relevant UI elements and show loaded crew
		_update_ui_state()
		_display_loaded_crew()

func _display_loaded_crew() -> void:
	"""Display loaded crew in the UI"""
	print("InitialCrewCreation: Displaying %d loaded crew members" % crew_creation_data.members.size())
	# Implementation depends on UI structure - could be expanded as needed

func _setup_workflow_integration(workflow_manager: Node) -> void:
	"""Setup NEW workflow context manager integration"""
	print("InitialCrewCreation: Setting up NEW workflow integration")
	
	# Get current workflow context
	var context = workflow_manager.get_context()
	if context and context.has("campaign_data"):
		var campaign_data = context.campaign_data
		
		# Apply pre-configured crew settings from workflow
		if campaign_data.has("crew_size"):
			set_crew_size(campaign_data["crew_size"])
			print("InitialCrewCreation: Applied workflow crew size: ", campaign_data["crew_size"])

		if campaign_data.has("crew_name"):
			set_crew_name(campaign_data["crew_name"])
			print("InitialCrewCreation: Applied workflow crew name: ", campaign_data.get("crew_name", ""))

		# Load existing crew data if available
		if campaign_data.has("crew") and not campaign_data["crew"].is_empty():
			_load_existing_crew_from_workflow(campaign_data["crew"])
	
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
		crew_size_option.selected = crew_data.size - 1 # Convert size to index
	
	# Load existing crew members
	var existing_members = crew_data.get("members", [])
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
	print("InitialCrewCreation: Crew created for workflow with %d members" % crew_data.get("members", []).size())
	
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
			crew_size_option.selected = crew_data.size - 1 # Convert size to index
		
		# Load existing crew members
		var existing_members = crew_data.get("members", [])
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
	print("InitialCrewCreation: Crew created for campaign with %d members" % crew_data.get("members", []).size())
	
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
		crew_size_option.selected = 5 # Index 5 = 6 members
	
	if crew_name_input:
		crew_name_input.text = ""
	
	if create_button:
		create_button.disabled = true
	
	# Clear any stored crew members
	clear_crew()
	
	print("InitialCrewCreation: Cleanup completed")
