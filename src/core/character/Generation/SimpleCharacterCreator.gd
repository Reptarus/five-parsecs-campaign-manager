extends Control
class_name SimpleCharacterCreator

## Enhanced Character Creator for Five Parsecs
## Includes Origin (species), Background, Motivation with rulebook descriptions

const UniversalResourceLoader = preload("res://src/core/systems/UniversalResourceLoader.gd")

signal character_created(character: Character)
signal character_edited(character: Character)
signal character_creation_cancelled()
signal character_editing_cancelled()

enum CreatorMode {
	CREW_MEMBER,
	CAPTAIN,
	CUSTOM
}

# UI Components - using safe node access
var name_input: LineEdit
var origin_options: OptionButton
var background_options: OptionButton
var motivation_options: OptionButton

var combat_value: Label
var reactions_value: Label
var toughness_value: Label
var savvy_value: Label
var tech_value: Label
var speed_value: Label
var luck_value: Label

var randomize_button: Button
var create_button: Button
var cancel_button: Button
var back_button: Button

var description_label: RichTextLabel

var current_mode: CreatorMode = CreatorMode.CREW_MEMBER
var editing_character: Character = null
var current_character: Character = null

# Data from JSON files
var species_data: Dictionary = {}
var backgrounds_data: Dictionary = {}
var motivations_data: Dictionary = {}

func _ready() -> void:
	pass # _ready() called
	name = "SimpleCharacterCreator"
	visible = false
	
	_load_character_data()
	
	# Wait for the scene tree to be fully ready before initializing UI
	await get_tree().process_frame
	await get_tree().process_frame # Double frame wait for complex UI
	
	_initialize_ui_components()
	_connect_signals()
	
	pass # _ready() completed

func _load_character_data() -> void:
	## Load character creation data from JSON files
	species_data = UniversalResourceLoader.load_json_safe("res://data/character_species.json", "Character Species")
	backgrounds_data = UniversalResourceLoader.load_json_safe("res://data/character_backgrounds.json", "Character Backgrounds")
	motivations_data = UniversalResourceLoader.load_json_safe("res://data/character_creation_tables/motivation_table.json", "Character Motivations")
	
	pass # Character data loaded

func _initialize_ui_components() -> void:
	## Initialize UI components with safe node access
	
	# Input fields - using unique names
	name_input = get_node_or_null("%NameInput")
	origin_options = get_node_or_null("%OriginOptions")
	background_options = get_node_or_null("%BackgroundOptions")
	motivation_options = get_node_or_null("%MotivationOptions")
	
	# Stat displays - using unique names
	combat_value = get_node_or_null("%CombatValue")
	reactions_value = get_node_or_null("%ReactionsValue")
	toughness_value = get_node_or_null("%ToughnessValue")
	savvy_value = get_node_or_null("%SavvyValue")
	tech_value = get_node_or_null("%TechValue")
	speed_value = get_node_or_null("%SpeedValue")
	luck_value = get_node_or_null("%LuckValue")
	
	# Buttons - using unique names
	randomize_button = get_node_or_null("%RandomizeButton")
	create_button = get_node_or_null("%CreateButton")
	cancel_button = get_node_or_null("%CancelButton")
	back_button = get_node_or_null("%BackButton")
	
	# Description - using unique names
	description_label = get_node_or_null("%DescriptionLabel")
	
	
	# Scene tree debug removed
	
	# Log any missing components
	var missing_components = []
	if not name_input: missing_components.append("NameInput")
	if not origin_options: missing_components.append("OriginOptions")
	if not background_options: missing_components.append("BackgroundOptions")
	if not motivation_options: missing_components.append("MotivationOptions")
	if not combat_value: missing_components.append("CombatValue")
	if not reactions_value: missing_components.append("ReactionsValue")
	if not toughness_value: missing_components.append("ToughnessValue")
	if not savvy_value: missing_components.append("SavvyValue")
	if not tech_value: missing_components.append("TechValue")
	if not speed_value: missing_components.append("SpeedValue")
	if not luck_value: missing_components.append("LuckValue")
	if not randomize_button: missing_components.append("RandomizeButton")
	if not create_button: missing_components.append("CreateButton")
	if not cancel_button: missing_components.append("CancelButton")
	if not back_button: missing_components.append("BackButton")
	if not description_label: missing_components.append("DescriptionLabel")
	
	if missing_components.size() > 0:
		push_warning("SimpleCharacterCreator: Missing UI components: %s" % str(missing_components))
		# Try to find nodes with different paths
		_try_alternative_node_paths()
	else:
		_populate_options()

func _try_alternative_node_paths() -> void:
	## Try alternative node paths in case the scene structure is different
	
	# Try full scene tree paths based on the .tscn file structure
	var full_name_input = get_node_or_null("Dialog/VBoxContainer/NameContainer/NameInput")
	if full_name_input and not name_input:
		name_input = full_name_input
	
	var full_origin_options = get_node_or_null("Dialog/VBoxContainer/OriginContainer/OriginOptions")
	if full_origin_options and not origin_options:
		origin_options = full_origin_options
	
	var full_background_options = get_node_or_null("Dialog/VBoxContainer/BackgroundContainer/BackgroundOptions")
	if full_background_options and not background_options:
		background_options = full_background_options
	
	var full_motivation_options = get_node_or_null("Dialog/VBoxContainer/MotivationContainer/MotivationOptions")
	if full_motivation_options and not motivation_options:
		motivation_options = full_motivation_options
	
	# Try stat value labels
	var full_combat_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/CombatValue")
	if full_combat_value and not combat_value:
		combat_value = full_combat_value

	var full_reactions_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ReactionsValue")
	if full_reactions_value and not reactions_value:
		reactions_value = full_reactions_value

	var full_toughness_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ToughnessValue")
	if full_toughness_value and not toughness_value:
		toughness_value = full_toughness_value
	
	var full_savvy_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SavvyValue")
	if full_savvy_value and not savvy_value:
		savvy_value = full_savvy_value
	
	var full_tech_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/TechValue")
	if full_tech_value and not tech_value:
		tech_value = full_tech_value
	
	var full_speed_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SpeedValue")
	if full_speed_value and not speed_value:
		speed_value = full_speed_value
	
	var full_luck_value = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/LuckValue")
	if full_luck_value and not luck_value:
		luck_value = full_luck_value
	
	# Try buttons
	var full_randomize_button = get_node_or_null("Dialog/VBoxContainer/ButtonContainer/RandomizeButton")
	if full_randomize_button and not randomize_button:
		randomize_button = full_randomize_button
	
	var full_create_button = get_node_or_null("Dialog/VBoxContainer/ButtonContainer/CreateButton")
	if full_create_button and not create_button:
		create_button = full_create_button
	
	var full_cancel_button = get_node_or_null("Dialog/VBoxContainer/ButtonContainer/CancelButton")
	if full_cancel_button and not cancel_button:
		cancel_button = full_cancel_button
	
	var full_back_button = get_node_or_null("Dialog/VBoxContainer/BackButton")
	if full_back_button and not back_button:
		back_button = full_back_button
	
	var full_description_label = get_node_or_null("Dialog/VBoxContainer/DescriptionContainer/DescriptionLabel")
	if full_description_label and not description_label:
		description_label = full_description_label
	
	# If we found some components, try to populate
	if name_input or origin_options or background_options or motivation_options:
		_populate_options()

func _populate_options() -> void:
	## Populate dropdown options with data from JSON files
	# Populate Origin (Species) options — schema: primary_aliens[] + strange_characters[]
	if origin_options:
		origin_options.clear()
		origin_options.add_item("Select Origin...", -1)
		for species in species_data.get("primary_aliens", []):
			origin_options.add_item(species.get("name", "Unknown"), origin_options.get_item_count())
		for species in species_data.get("strange_characters", []):
			origin_options.add_item(species.get("name", "Unknown"), origin_options.get_item_count())
	
	# Populate Background options
	if background_options:
		background_options.clear()
		background_options.add_item("Select Background...", -1)
		for background in backgrounds_data.get("backgrounds", []):
			background_options.add_item(background.get("name", "Unknown"), background_options.get_item_count())
	
	# Populate Motivation options
	if motivation_options:
		motivation_options.clear()
		motivation_options.add_item("Select Motivation...", -1)
		# Handle motivation table format — entries nested under "entries" key (D100 table, Core Rules p.26)
		var mot_entries: Dictionary = motivations_data.get("entries", motivations_data)
		for key in mot_entries.keys():
			if key != "name" and key != "description" and key != "roll_type" and key != "entries":
				var motivation = mot_entries[key]
				if motivation is Dictionary:
					motivation_options.add_item(motivation.get("name", "Unknown"), motivation_options.get_item_count())

func _connect_signals() -> void:
	## Connect all UI signals
	if randomize_button and not randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.connect(_on_randomize_pressed)
	if create_button and not create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.connect(_on_create_pressed)
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	
	# Connect option change signals
	if origin_options and not origin_options.item_selected.is_connected(_on_origin_changed):
		origin_options.item_selected.connect(_on_origin_changed)
	if background_options and not background_options.item_selected.is_connected(_on_background_changed):
		background_options.item_selected.connect(_on_background_changed)
	if motivation_options and not motivation_options.item_selected.is_connected(_on_motivation_changed):
		motivation_options.item_selected.connect(_on_motivation_changed)
	
	# Connect stat adjustment buttons
	_connect_stat_buttons()
	

func _connect_stat_buttons() -> void:
	## Connect stat adjustment buttons
	# Combat buttons
	var combat_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/CombatButtons/CombatUp")
	var combat_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/CombatButtons/CombatDown")
	if combat_up and not combat_up.pressed.is_connected(_on_combat_up):
		combat_up.pressed.connect(_on_combat_up)
	if combat_down and not combat_down.pressed.is_connected(_on_combat_down):
		combat_down.pressed.connect(_on_combat_down)

	# Reactions buttons
	var reactions_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ReactionsButtons/ReactionsUp")
	var reactions_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ReactionsButtons/ReactionsDown")
	if reactions_up and not reactions_up.pressed.is_connected(_on_reactions_up):
		reactions_up.pressed.connect(_on_reactions_up)
	if reactions_down and not reactions_down.pressed.is_connected(_on_reactions_down):
		reactions_down.pressed.connect(_on_reactions_down)

	# Toughness buttons
	var toughness_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ToughnessButtons/ToughnessUp")
	var toughness_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/ToughnessButtons/ToughnessDown")
	if toughness_up and not toughness_up.pressed.is_connected(_on_toughness_up):
		toughness_up.pressed.connect(_on_toughness_up)
	if toughness_down and not toughness_down.pressed.is_connected(_on_toughness_down):
		toughness_down.pressed.connect(_on_toughness_down)
	
	# Savvy buttons
	var savvy_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SavvyButtons/SavvyUp")
	var savvy_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SavvyButtons/SavvyDown")
	if savvy_up and not savvy_up.pressed.is_connected(_on_savvy_up):
		savvy_up.pressed.connect(_on_savvy_up)
	if savvy_down and not savvy_down.pressed.is_connected(_on_savvy_down):
		savvy_down.pressed.connect(_on_savvy_down)
	
	# Tech buttons
	var tech_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/TechButtons/TechUp")
	var tech_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/TechButtons/TechDown")
	if tech_up and not tech_up.pressed.is_connected(_on_tech_up):
		tech_up.pressed.connect(_on_tech_up)
	if tech_down and not tech_down.pressed.is_connected(_on_tech_down):
		tech_down.pressed.connect(_on_tech_down)
	
	# Speed buttons
	var speed_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SpeedButtons/SpeedUp")
	var speed_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/SpeedButtons/SpeedDown")
	if speed_up and not speed_up.pressed.is_connected(_on_speed_up):
		speed_up.pressed.connect(_on_speed_up)
	if speed_down and not speed_down.pressed.is_connected(_on_speed_down):
		speed_down.pressed.connect(_on_speed_down)
	
	# Luck buttons
	var luck_up = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/LuckButtons/LuckUp")
	var luck_down = get_node_or_null("Dialog/VBoxContainer/StatsContainer/StatsDisplay/LuckButtons/LuckDown")
	if luck_up and not luck_up.pressed.is_connected(_on_luck_up):
		luck_up.pressed.connect(_on_luck_up)
	if luck_down and not luck_down.pressed.is_connected(_on_luck_down):
		luck_down.pressed.connect(_on_luck_down)

func start_creation(mode: CreatorMode = CreatorMode.CREW_MEMBER) -> void:
	current_mode = mode
	editing_character = null
	_reset_form()
	_generate_random_stats()
	show()

func edit_character(character: Character) -> void:
	if not character:
		push_warning("SimpleCharacterCreator: Cannot edit null character")
		return
		
	editing_character = character
	current_character = character.duplicate()
	_populate_form(character)
	show()

func _reset_form() -> void:
	## Reset the form to default values
	if name_input:
		name_input.text = ""
	
	if origin_options:
		origin_options.selected = 0
	if background_options:
		background_options.selected = 0
	if motivation_options:
		motivation_options.selected = 0
	
	current_character = Character.new()
	_update_stats_display()
	_update_description()

func _populate_form(character: Character) -> void:
	## Populate form with character data
	if not character:
		return
		
	if name_input:
		name_input.text = character.character_name
	
	# Set origin (species)
	if origin_options and character.origin:
		for i in range(origin_options.get_item_count()):
			if origin_options.get_item_text(i) == character.origin:
				origin_options.selected = i
				break
	
	# Set background
	if background_options and character.background:
		for i in range(background_options.get_item_count()):
			if background_options.get_item_text(i) == str(character.background):
				background_options.selected = i
				break
	
	# Set motivation
	if motivation_options and character.motivation:
		for i in range(motivation_options.get_item_count()):
			if motivation_options.get_item_text(i) == str(character.motivation):
				motivation_options.selected = i
				break
	
	_update_stats_display()
	_update_description()

func _generate_random_stats() -> void:
	## Generate random stats using Five Parsecs rules
	if not current_character:
		current_character = Character.new()
	
	# Generate base stats: ceil(2D6 / 3) gives 1-4 range (Core Rules)
	current_character.combat = _roll_stat()
	current_character.reactions = _roll_stat()
	current_character.toughness = _roll_stat()
	current_character.savvy = _roll_stat()
	current_character.tech = _roll_stat()
	current_character.speed = _roll_stat()
	current_character.luck = 1 # Starting luck

	# Captains get better stats
	if current_mode == CreatorMode.CAPTAIN:
		current_character.combat = maxi(current_character.combat, 3)
		current_character.reactions = maxi(current_character.reactions, 2)
		current_character.toughness = maxi(current_character.toughness, 3)
		current_character.savvy = maxi(current_character.savvy, 3)
		current_character.luck = 2
	
	# Calculate health
	# Set max health based on toughness (use properties or setter methods)
	if current_character.has_method("set_max_health"):
		current_character.set_max_health(current_character.toughness + 2)
		current_character.set_health(current_character.toughness + 2)
	else:
		# If character doesn't have setter methods, store in metadata
		current_character.set_meta("max_health", current_character.toughness + 2)
		current_character.set_meta("health", current_character.toughness + 2)
	
	_update_stats_display()
	_update_description()

func _roll_2d6() -> int:
	## Roll 2d6 (raw, used for non-stat rolls)
	return randi_range(1, 6) + randi_range(1, 6)

func _roll_stat() -> int:
	## Roll stat: ceil(2D6 / 3), clamped to 1-6 (Core Rules)
	var raw: int = randi_range(1, 6) + randi_range(1, 6)
	return clampi(ceili(raw / 3.0), 1, 6)

func _update_stats_display() -> void:
	## Update the stats display with current character values
	if not current_character:
		return
		
	if combat_value:
		combat_value.text = str(current_character.combat)
	if reactions_value:
		reactions_value.text = str(current_character.reactions)
	if toughness_value:
		toughness_value.text = str(current_character.toughness)
	if savvy_value:
		savvy_value.text = str(current_character.savvy)
	if tech_value:
		tech_value.text = str(current_character.tech)
	if speed_value:
		speed_value.text = str(current_character.speed)
	if luck_value:
		luck_value.text = str(current_character.luck)

	pass # Stats display updated

func _update_description() -> void:
	## Update the description panel with current selections
	if not description_label:
		return
	
	var description_text = "[color=lime]Name:[/color] %s\n\n" % (current_character.character_name if current_character.character_name else "Unnamed")
	
	# Add origin description
	var selected_origin = origin_options.get_item_text(origin_options.selected) if origin_options and origin_options.selected > 0 else ""
	if selected_origin:
		description_text += "[color=lime]Origin:[/color] %s\n" % selected_origin
		var origin_data = _get_species_data(selected_origin)
		if origin_data:
			description_text += "[color=#666666]%s[/color]\n\n" % origin_data.get("description", "")
			# Add special abilities
			var abilities = origin_data.get("special_abilities", [])
			if abilities.size() > 0:
				description_text += "[color=yellow]Special Abilities:[/color]\n"
				for ability in abilities:
					description_text += "[color=#666666]• %s: %s[/color]\n" % [ability.get("name", ""), ability.get("description", "")]
				description_text += "\n"
	
	# Add background description
	var selected_background = background_options.get_item_text(background_options.selected) if background_options and background_options.selected > 0 else ""
	if selected_background:
		description_text += "[color=lime]Background:[/color] %s\n" % selected_background
		var background_data = _get_background_data(selected_background)
		if background_data:
			description_text += "[color=#666666]%s[/color]\n\n" % background_data.get("description", "")
	
	# Add motivation description
	var selected_motivation = motivation_options.get_item_text(motivation_options.selected) if motivation_options and motivation_options.selected > 0 else ""
	if selected_motivation:
		description_text += "[color=lime]Motivation:[/color] %s\n" % selected_motivation
		var motivation_data = _get_motivation_data(selected_motivation)
		if motivation_data:
			description_text += "[color=#666666]%s[/color]\n\n" % motivation_data.get("description", "")
	
	# Add stats
	description_text += "[color=lime]Stats:[/color]\n"
	description_text += "[color=yellow]Combat:[/color] %d\n" % current_character.combat
	description_text += "[color=yellow]Reactions:[/color] %d\n" % current_character.reactions
	description_text += "[color=yellow]Toughness:[/color] %d\n" % current_character.toughness
	description_text += "[color=yellow]Savvy:[/color] %d\n" % current_character.savvy
	description_text += "[color=yellow]Tech:[/color] %d\n" % current_character.tech
	description_text += "[color=yellow]Speed:[/color] %d\n" % current_character.speed
	description_text += "[color=yellow]Luck:[/color] %d\n" % current_character.luck
	
	description_label.text = description_text


func _get_species_data(species_name: String) -> Dictionary:
	## Get species data by name — searches primary_aliens + strange_characters
	for species in species_data.get("primary_aliens", []):
		if species.get("name", "") == species_name:
			return species
	for species in species_data.get("strange_characters", []):
		if species.get("name", "") == species_name:
			return species
	return {}

func _get_background_data(background_name: String) -> Dictionary:
	## Get background data by name
	for background in backgrounds_data.get("backgrounds", []):
		if background.get("name", "") == background_name:
			return background
	return {}

func _get_motivation_data(motivation_name: String) -> Dictionary:
	## Get motivation data by name from D100 entries
	var mot_entries: Dictionary = motivations_data.get("entries", motivations_data)
	for key in mot_entries.keys():
		var motivation = mot_entries[key]
		if motivation is Dictionary and motivation.get("name", "") == motivation_name:
			return motivation
	return {}

func _on_origin_changed(index: int) -> void:
	## Handle origin (species) selection change
	if index > 0 and current_character:
		var selected_origin = origin_options.get_item_text(index)
		# Store the origin as a string for display purposes
		current_character.origin = selected_origin
		
		# Apply species stat modifiers
		var species_data = _get_species_data(selected_origin)
		if species_data:
			var modifiers = species_data.get("stat_modifiers", {})
			current_character.combat += modifiers.get("combat", 0)
			current_character.toughness += modifiers.get("toughness", 0)
			current_character.savvy += modifiers.get("savvy", 0)
			current_character.tech += modifiers.get("tech", 0)
			current_character.speed += modifiers.get("speed", 0)
			
			# Recalculate health
			current_character.max_health = current_character.toughness + 2
			current_character.health = current_character.max_health
		
		_update_stats_display()
		_update_description()

func _on_background_changed(index: int) -> void:
	## Handle background selection change
	if index > 0 and current_character:
		var selected_background = background_options.get_item_text(index)
		current_character.background = selected_background
		_update_description()

func _on_motivation_changed(index: int) -> void:
	## Handle motivation selection change
	if index > 0 and current_character:
		var selected_motivation = motivation_options.get_item_text(index)
		current_character.motivation = selected_motivation
		_update_description()

func _on_randomize_pressed() -> void:
	## Handle randomize button press
	_generate_random_stats()

func _on_create_pressed() -> void:
	## Handle create button press
	if not current_character:
		return
		
	# Set name from input
	if name_input:
		current_character.character_name = name_input.text
	
	# Default name if empty
	if current_character.character_name.is_empty():
		current_character.character_name = "Captain" if current_mode == CreatorMode.CAPTAIN else "Crew Member"
	
	# Emit appropriate signal
	if editing_character:
		character_edited.emit(current_character)
	else:
		character_created.emit(current_character)
	
	hide()

func _on_cancel_pressed() -> void:
	## Handle cancel button press
	if editing_character:
		character_editing_cancelled.emit()
	else:
		character_creation_cancelled.emit()
	hide()

func _on_back_pressed() -> void:
	## Handle back button press - return to previous step in campaign creation
	hide()
	# The parent campaign creation flow will handle the navigation

# Public API for compatibility
func get_current_character() -> Character:
	return current_character

# Stat adjustment methods
func _on_combat_up() -> void:
	if current_character and current_character.combat < 6:
		current_character.combat += 1
		_update_stats_display()

func _on_combat_down() -> void:
	if current_character and current_character.combat > 1:
		current_character.combat -= 1
		_update_stats_display()

func _on_reactions_up() -> void:
	if current_character and current_character.reactions < 6:
		current_character.reactions += 1
		_update_stats_display()

func _on_reactions_down() -> void:
	if current_character and current_character.reactions > 1:
		current_character.reactions -= 1
		_update_stats_display()

func _on_toughness_up() -> void:
	if current_character and current_character.toughness < 6:
		current_character.toughness += 1
		_update_stats_display()

func _on_toughness_down() -> void:
	if current_character and current_character.toughness > 1:
		current_character.toughness -= 1
		_update_stats_display()

func _on_savvy_up() -> void:
	if current_character and current_character.savvy < 6:
		current_character.savvy += 1
		_update_stats_display()

func _on_savvy_down() -> void:
	if current_character and current_character.savvy > 1:
		current_character.savvy -= 1
		_update_stats_display()

func _on_tech_up() -> void:
	if current_character and current_character.tech < 6:
		current_character.tech += 1
		_update_stats_display()

func _on_tech_down() -> void:
	if current_character and current_character.tech > 1:
		current_character.tech -= 1
		_update_stats_display()

func _on_speed_up() -> void:
	if current_character and current_character.speed < 6:
		current_character.speed += 1
		_update_stats_display()

func _on_speed_down() -> void:
	if current_character and current_character.speed > 1:
		current_character.speed -= 1
		_update_stats_display()

func _on_luck_up() -> void:
	if current_character and current_character.luck < 6:
		current_character.luck += 1
		_update_stats_display()

func _on_luck_down() -> void:
	if current_character and current_character.luck > 1:
		current_character.luck -= 1
		_update_stats_display()
