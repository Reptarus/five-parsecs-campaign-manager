extends Control

## Five Parsecs Crew Creation System
## Implements full Five Parsecs From Home crew generation rules using JSON data

# Safe imports
const CoreCharacter = preload("res://src/core/character/Character.gd")
# GlobalEnums available as autoload singleton

signal crew_created(crew_data: Dictionary)
signal character_generated(character: CoreCharacter)
signal resources_updated(resources: Dictionary)

# Character creation UI nodes - use get_node_or_null for safety
@onready var character_list: ItemList = get_node_or_null("VBoxContainer/CharacterList")
@onready var generate_button: Button = get_node_or_null("VBoxContainer/GenerateButton")
@onready var finish_button: Button = get_node_or_null("VBoxContainer/FinishButton")
@onready var character_details: RichTextLabel = get_node_or_null("VBoxContainer/CharacterDetails")

# Crew data
var crew_members: Array[CoreCharacter] = []
var max_crew_size: int = 6

# Loaded JSON data
var _species_data: Dictionary = {}
var _motivation_data: Dictionary = {}
var _background_data: Dictionary = {}
var _class_data: Dictionary = {}
var _equipment_data: Dictionary = {}
var _data_loaded: bool = false

# Accumulated campaign resources from character creation
var accumulated_resources: Dictionary = {
	"credits": 0,
	"story_points": 0,
	"patrons": [],
	"rivals": [],
	"quest_rumors": [],
	"equipment_rolls": {
		"military_weapons": 3,  # Base crew gets 3
		"low_tech_weapons": 3,  # Base crew gets 3
		"high_tech_weapons": 0,  # Earned via Savvy increases
		"gear": 1,  # Base crew gets 1
		"gadgets": 1  # Base crew gets 1
	}
}

func _ready() -> void:
	_load_character_data()
	_setup_ui()
	_connect_signals()
	_initialize_resources()

func _load_character_data() -> void:
	"""Load all character creation data from JSON files"""
	# Load species/origins data
	var species_file = FileAccess.open("res://data/character_creation_data.json", FileAccess.READ)
	if species_file:
		var json = JSON.new()
		var error = json.parse(species_file.get_as_text())
		if error == OK:
			_species_data = json.data
			print("CrewCreation: Loaded species data with %d origins" % _species_data.get("origins", {}).size())
		species_file.close()

	# Load motivation table (d66)
	var motivation_file = FileAccess.open("res://data/character_creation_tables/motivation_table.json", FileAccess.READ)
	if motivation_file:
		var json = JSON.new()
		var error = json.parse(motivation_file.get_as_text())
		if error == OK:
			_motivation_data = json.data
			print("CrewCreation: Loaded %d motivations" % _motivation_data.size())
		motivation_file.close()

	# Load Core Rules background table (pp.24-25)
	var background_file = FileAccess.open("res://data/character_creation_tables/background_table.json", FileAccess.READ)
	if background_file:
		var json = JSON.new()
		var error = json.parse(background_file.get_as_text())
		if error == OK:
			_background_data = json.data
			print("CrewCreation: Loaded background table with %d entries" % _background_data.get("entries", {}).size())
		background_file.close()

	# Load Core Rules class table (pp.26-27)
	var class_file = FileAccess.open("res://data/character_creation_tables/class_table.json", FileAccess.READ)
	if class_file:
		var json = JSON.new()
		var error = json.parse(class_file.get_as_text())
		if error == OK:
			_class_data = json.data
			print("CrewCreation: Loaded class table with %d entries" % _class_data.get("entries", {}).size())
		class_file.close()

	# Load equipment tables
	var equipment_file = FileAccess.open("res://data/character_creation_tables/equipment_tables.json", FileAccess.READ)
	if equipment_file:
		var json = JSON.new()
		var error = json.parse(equipment_file.get_as_text())
		if error == OK:
			_equipment_data = json.data
			print("CrewCreation: Loaded equipment tables")
		equipment_file.close()

	_data_loaded = true

func _initialize_resources() -> void:
	"""Initialize starting resources for crew creation"""
	accumulated_resources.credits = 0  # Will add 1 per crew member + table bonuses
	accumulated_resources.story_points = 0
	accumulated_resources.patrons.clear()
	accumulated_resources.rivals.clear()
	accumulated_resources.quest_rumors.clear()
	accumulated_resources.equipment_rolls = {
		"military_weapons": 3,
		"low_tech_weapons": 3,
		"high_tech_weapons": 0,
		"gear": 1,
		"gadgets": 1
	}

func _setup_ui() -> void:
	if character_list:
		character_list.clear()
	if finish_button:
		finish_button.disabled = true
	_update_ui_state()

func _connect_signals() -> void:
	if generate_button:
		if not generate_button.pressed.is_connected(_on_generate_character):
			generate_button.pressed.connect(_on_generate_character)
	if finish_button:
		if not finish_button.pressed.is_connected(_on_finish_crew_creation):
			finish_button.pressed.connect(_on_finish_crew_creation)
	if character_list:
		if not character_list.item_selected.is_connected(_on_character_selected):
			character_list.item_selected.connect(_on_character_selected)

func _update_ui_state() -> void:
	if generate_button:
		generate_button.disabled = crew_members.size() >= max_crew_size
	if finish_button:
		finish_button.disabled = crew_members.size() == 0
		finish_button.text = "Finish Crew (%d/%d)" % [crew_members.size(), max_crew_size]

## Generate a new Five Parsecs character using official rules and JSON data
func _on_generate_character() -> void:
	if crew_members.size() >= max_crew_size:
		return

	var character: CoreCharacter = _generate_five_parsecs_character()
	crew_members.append(character)

	# Add to UI list
	var display_name: String = "%s (%s - %s)" % [
		character.character_name,
		_get_origin_display_name(character.origin),
		character.character_class
	]
	if character_list:
		character_list.add_item(display_name)

	_update_ui_state()
	character_generated.emit(character)
	resources_updated.emit(accumulated_resources)

	# Auto-select the new character
	if character_list:
		character_list.select(character_list.get_item_count() - 1)
	_display_character_details(character)

## Generate character using Five Parsecs From Home rules with JSON data
func _generate_five_parsecs_character() -> CoreCharacter:
	var character: CoreCharacter = CoreCharacter.new()

	# Step 1: Determine species/origin (for now random, will be player choice in CrewPanel)
	var origin_key = _select_random_origin()
	var origin_data = _get_origin_data(origin_key)

	# Step 2: Apply base stats from species
	_apply_species_base_stats(character, origin_data)
	character.origin = origin_key

	# Step 3: Roll background (D100 table) and apply bonuses
	var background_result = _roll_and_apply_background(character)

	# Step 4: Roll motivation (D66 table) and apply bonuses
	var motivation_result = _roll_and_apply_motivation(character)

	# Step 5: Roll class (D100 table) and apply bonuses
	var class_result = _roll_and_apply_class(character)

	# Step 6: Generate name
	character.character_name = _generate_character_name()

	# Step 7: Add 1 credit per crew member
	accumulated_resources.credits += 1

	# Step 8: Check for Savvy increase → High-tech weapon roll
	if character.savvy > 0:
		# Each Savvy increase allows converting a Military roll to High-tech
		accumulated_resources.equipment_rolls.high_tech_weapons += 1

	return character

func _select_random_origin() -> String:
	"""Select a random origin for character generation"""
	var origins = _species_data.get("origins", {})
	if origins.is_empty():
		return "HUMAN"

	var origin_keys = origins.keys()
	return origin_keys[randi() % origin_keys.size()]

func _get_origin_data(origin_key: String) -> Dictionary:
	"""Get origin data from loaded species data"""
	var origins = _species_data.get("origins", {})
	return origins.get(origin_key, {})

func _apply_species_base_stats(character: CoreCharacter, origin_data: Dictionary) -> void:
	"""Apply base stats from species definition"""
	var base_stats = origin_data.get("base_stats", {})

	# Apply base stats (Core Rules values)
	character.reactions = base_stats.get("REACTIONS", 1)
	character.speed = base_stats.get("SPEED", 4)
	character.combat = base_stats.get("COMBAT_SKILL", 0)
	character.toughness = base_stats.get("TOUGHNESS", 3)
	character.savvy = base_stats.get("SAVVY", 0)

	# Apply species-specific characteristics
	var characteristics = origin_data.get("characteristics", [])

	# Check for Luck (only Humans can exceed 1)
	if character.origin == "HUMAN":
		character.luck = 0  # Will be set to 1 if designated as leader
	else:
		character.luck = 0  # Non-humans can have max 1 Luck

func _roll_and_apply_background(character: CoreCharacter) -> Dictionary:
	"""Roll on background table (D100) and apply results from Core Rules pp.24-25"""
	var roll = randi() % 100 + 1
	var result = {}

	# Use loaded background table data
	var entries = _background_data.get("entries", {})
	if entries.is_empty():
		character.background = "Unknown"
		return result

	# Find the matching entry based on roll range
	var bg = _find_table_entry(entries, roll)
	if bg.is_empty():
		character.background = "Unknown"
		return result

	character.background = bg.get("name", "Unknown")
	result = bg.duplicate()

	# Apply stat bonuses
	var bonuses = bg.get("stat_bonuses", {})
	character.combat += bonuses.get("combat", 0)
	character.toughness += bonuses.get("toughness", 0)
	character.savvy += bonuses.get("savvy", 0)
	character.speed += bonuses.get("speed", 0)
	character.reactions += bonuses.get("reactions", 0)

	# Apply resources
	var resources = bg.get("resources", {})

	# Credits (roll dice if specified)
	if "credits_roll" in resources:
		var credits = _roll_dice_string(resources.credits_roll)
		accumulated_resources.credits += credits

	# Patron
	if resources.get("patron", false):
		accumulated_resources.patrons.append(character.background)

	# Story points
	accumulated_resources.story_points += resources.get("story_points", 0)

	# Quest rumors
	var rumors = resources.get("quest_rumors", 0)
	for i in range(rumors):
		accumulated_resources.quest_rumors.append("Background: %s" % character.background)

	# Rival
	if resources.get("rival", false):
		accumulated_resources.rivals.append("From %s background" % character.background)

	# Track equipment rolls
	var equipment_rolls = bg.get("equipment_rolls", [])
	for roll_type in equipment_rolls:
		match roll_type:
			"military_weapon":
				accumulated_resources.equipment_rolls.military_weapons += 1
			"low_tech_weapon":
				accumulated_resources.equipment_rolls.low_tech_weapons += 1
			"high_tech_weapon":
				accumulated_resources.equipment_rolls.high_tech_weapons += 1
			"gear":
				accumulated_resources.equipment_rolls.gear += 1
			"gadget":
				accumulated_resources.equipment_rolls.gadgets += 1

	return result

func _find_table_entry(entries: Dictionary, roll: int) -> Dictionary:
	"""Find the table entry matching a given roll value"""
	for range_key in entries.keys():
		var parts = range_key.split("-")
		if parts.size() == 2:
			var low = int(parts[0])
			var high = int(parts[1])
			if roll >= low and roll <= high:
				return entries[range_key]
		elif parts.size() == 1:
			if roll == int(parts[0]):
				return entries[range_key]
	return {}

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

func _roll_and_apply_motivation(character: CoreCharacter) -> Dictionary:
	"""Roll on motivation table (D66) and apply results"""
	# Roll D66 (two D6 dice: first is tens, second is units)
	var d1 = randi() % 6 + 1
	var d2 = randi() % 6 + 1
	var roll_key = str(d1) + str(d2)

	var result = _motivation_data.get(roll_key, {})

	if result.is_empty():
		character.motivation = "Survival"
		return result

	character.motivation = result.get("name", "Unknown")

	# Apply bonus from motivation (parsed from bonus string)
	# TODO: Parse and apply specific bonuses

	return result

func _roll_and_apply_class(character: CoreCharacter) -> Dictionary:
	"""Roll on class table (D100) and apply results from Core Rules pp.26-27"""
	var roll = randi() % 100 + 1
	var result = {}

	# Use loaded class table data
	var entries = _class_data.get("entries", {})
	if entries.is_empty():
		character.character_class = "Unknown"
		return result

	# Find the matching entry based on roll range
	var cls = _find_table_entry(entries, roll)
	if cls.is_empty():
		character.character_class = "Unknown"
		return result

	character.character_class = cls.get("name", "Unknown")
	result = cls.duplicate()

	# Apply stat bonuses
	var bonuses = cls.get("stat_bonuses", {})
	character.combat += bonuses.get("combat", 0)
	character.toughness += bonuses.get("toughness", 0)
	character.savvy += bonuses.get("savvy", 0)
	character.speed += bonuses.get("speed", 0)
	character.reactions += bonuses.get("reactions", 0)

	# Apply special bonuses (luck, xp)
	var special = cls.get("special", {})
	if "luck" in special:
		character.luck = max(character.luck, int(special.luck))
	if "xp" in special:
		character.experience = int(special.xp)

	# Apply resources
	var resources = cls.get("resources", {})

	# Credits (roll dice if specified)
	if "credits_roll" in resources:
		var credits = _roll_dice_string(resources.credits_roll)
		accumulated_resources.credits += credits

	# Patron
	if resources.get("patron", false):
		accumulated_resources.patrons.append(character.character_class)

	# Story points
	accumulated_resources.story_points += resources.get("story_points", 0)

	# Quest rumors
	var rumors = resources.get("quest_rumors", 0)
	for i in range(rumors):
		accumulated_resources.quest_rumors.append("Class: %s" % character.character_class)

	# Rival
	if resources.get("rival", false):
		accumulated_resources.rivals.append("From %s profession" % character.character_class)

	# Track equipment rolls
	var equipment_rolls = cls.get("equipment_rolls", [])
	for roll_type in equipment_rolls:
		match roll_type:
			"military_weapon":
				accumulated_resources.equipment_rolls.military_weapons += 1
			"low_tech_weapon":
				accumulated_resources.equipment_rolls.low_tech_weapons += 1
			"high_tech_weapon":
				accumulated_resources.equipment_rolls.high_tech_weapons += 1
			"gear":
				accumulated_resources.equipment_rolls.gear += 1
			"gadget":
				accumulated_resources.equipment_rolls.gadgets += 1

	return result

## Generate character name using name tables
func _generate_character_name() -> String:
	var first_names = [
		"Alex", "Jordan", "Casey", "Riley", "Morgan", "Avery", "Taylor", "Cameron",
		"Kai", "Quinn", "Rowan", "Sage", "River", "Phoenix", "Blake", "Dakota",
		"Flint", "Kersh", "Milli", "Simon", "Shi", "Neenet", "Zara", "Marcus"
	]
	var last_names = [
		"Stone", "Cross", "Vale", "Kane", "Reed", "Fox", "Storm", "Wolf",
		"Vance", "Chen", "Okonkwo", "Santos", "Kim", "Petrov", "Al-Hassan", "Nakamura",
		"Williamson", "Filjan", "Cershaw", "Kurchler", "Jiang", "Torres"
	]

	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _get_origin_display_name(origin: String) -> String:
	"""Get display name for origin/species"""
	match origin:
		"HUMAN": return "Human"
		"ENGINEER": return "Engineer"
		"KERIN": return "K'Erin"
		"SOULLESS": return "Soulless"
		"PRECURSOR": return "Precursor"
		"FERAL": return "Feral"
		"SWIFT": return "Swift"
		"BOT": return "Bot"
		_: return origin.capitalize()

## Display character details in the UI
func _display_character_details(character: CoreCharacter) -> void:
	var details = "[b]%s[/b]\n\n" % character.character_name
	details += "Origin: %s\n" % _get_origin_display_name(character.origin)
	details += "Background: %s\n" % character.background
	details += "Motivation: %s\n" % character.motivation
	details += "Class: %s\n\n" % character.character_class

	details += "[b]Attributes:[/b]\n"
	details += "Reactions: %d\n" % character.reactions
	details += "Speed: %d\"\n" % character.speed
	details += "Combat Skill: +%d\n" % character.combat
	details += "Toughness: %d\n" % character.toughness
	details += "Savvy: +%d\n" % character.savvy
	if character.luck > 0:
		details += "Luck: %d\n" % character.luck

	# Show species characteristics
	var origin_data = _get_origin_data(character.origin)
	var characteristics = origin_data.get("characteristics", [])
	if not characteristics.is_empty():
		details += "\n[b]Species Abilities:[/b]\n"
		for ability in characteristics:
			details += "• %s\n" % ability

	if character_details:
		character_details.text = details

## Handle character selection in list
func _on_character_selected(index: int) -> void:
	if index >= 0 and index < crew_members.size():
		_display_character_details(crew_members[index])

## Finish crew creation and emit data
func _on_finish_crew_creation() -> void:
	var crew_data = {
		"crew_members": [],
		"crew_size": crew_members.size(),
		"resources": accumulated_resources.duplicate(true)
	}

	# Serialize crew for signal emission
	for character in crew_members:
		crew_data.crew_members.append(character.serialize())

	# Save crew to GameStateManager for persistence
	_save_crew_to_game_state()

	crew_created.emit(crew_data)

## Save created crew to GameStateManager for persistence
func _save_crew_to_game_state() -> void:
	if not GameStateManager:
		push_error("CrewCreation: GameStateManager not available - crew will not be persisted")
		return

	var game_state = GameStateManager.game_state
	if not game_state:
		push_error("CrewCreation: No game_state - crew will not be persisted")
		return

	if not "current_campaign" in game_state or not game_state.current_campaign:
		push_error("CrewCreation: No current_campaign - crew will not be persisted")
		return

	# Clear existing crew and add new members
	if "crew_members" in game_state.current_campaign:
		game_state.current_campaign.crew_members.clear()
	else:
		game_state.current_campaign.crew_members = []

	# Add each character (serialized) to the campaign
	for character in crew_members:
		var serialized = character.serialize()
		game_state.current_campaign.crew_members.append(serialized)

	# Save accumulated resources via GameStateManager (SSOT pattern for credits/story_points)
	# Use GameStateManager for credits and story points (single source of truth)
	if GameStateManager.has_method("set_credits"):
		GameStateManager.set_credits(accumulated_resources.credits)
	if GameStateManager.has_method("set_story_progress"):
		GameStateManager.set_story_progress(accumulated_resources.story_points)

	# Store other resources in campaign.resources Dictionary (patrons, rivals, rumors)
	if not "resources" in game_state.current_campaign:
		game_state.current_campaign.resources = {}

	game_state.current_campaign.resources.patrons = accumulated_resources.patrons.duplicate()
	game_state.current_campaign.resources.rivals = accumulated_resources.rivals.duplicate()
	game_state.current_campaign.resources.quest_rumors = accumulated_resources.quest_rumors.duplicate()

	print("CrewCreation: Saved %d crew members and resources to GameStateManager" % crew_members.size())
	print("CrewCreation: Resources - Credits: %d, Story Points: %d, Patrons: %d, Rivals: %d" % [
		accumulated_resources.credits,
		accumulated_resources.story_points,
		accumulated_resources.patrons.size(),
		accumulated_resources.rivals.size()
	])

## Get current accumulated resources
func get_accumulated_resources() -> Dictionary:
	return accumulated_resources.duplicate(true)

## Apply Core Rules tables to an existing character and track resources
func apply_tables_to_character(character: CoreCharacter) -> void:
	"""Apply background and class tables to track accumulated resources for an existing character"""
	if not character:
		push_warning("CrewCreation: Cannot apply tables to null character")
		return

	# Add 1 credit per crew member (Core Rules)
	accumulated_resources.credits += 1

	# Apply background table
	var bg_result = _roll_and_apply_background(character)
	print("CrewCreation: Applied background '%s' to %s" % [bg_result.get("name", "Unknown"), character.character_name])

	# Apply class table
	var class_result = _roll_and_apply_class(character)
	print("CrewCreation: Applied class '%s' to %s" % [class_result.get("name", "Unknown"), character.character_name])

	# Emit update signal
	resources_updated.emit(accumulated_resources)

	print("CrewCreation: Resources tracked for %s - Total Credits: %d, Story Points: %d" % [
		character.character_name,
		accumulated_resources.credits,
		accumulated_resources.story_points
	])

## Set a specific character as the leader (grants +1 Luck)
func set_leader(character_index: int) -> void:
	if character_index < 0 or character_index >= crew_members.size():
		return

	# Remove leader status from all characters
	for character in crew_members:
		if character.origin == "HUMAN":
			character.luck = 0

	# Set the selected character as leader
	var leader = crew_members[character_index]
	leader.luck = 1  # Leader gets +1 Luck

	print("CrewCreation: %s designated as Leader (+1 Luck)" % leader.character_name)
