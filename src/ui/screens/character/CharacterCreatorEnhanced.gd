extends Control

## Enhanced Character Creator Integration with DataManager
## Updated dropdown population to use rich JSON data with enum validation
## Complete hybrid approach implementation

# Safe imports
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# UI Components - using safe access to match existing scene structure
@onready var origin_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/OriginSection/OriginOptions")
@onready var background_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/BackgroundSection/BackgroundOptions")
@onready var class_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/ClassSection/ClassOptions")
@onready var motivation_options: OptionButton = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/CreationPanel/MotivationSection/MotivationOptions")
@onready var traits_display: RichTextLabel = get_node_or_null("MainPanel/MarginContainer/HBoxContainer/PreviewPanel/PreviewInfo")

# State
var current_character: Character = null
var dice_manager: Node = null
var is_initialized: bool = false

func _ready() -> void:
	print("CharacterCreatorEnhanced: Initializing with hybrid data architecture...")

	# Initialize data system if not already loaded
	if not DataManager._is_data_loaded:
		var success = DataManager.initialize_data_system()
		if not success:
			push_error("CharacterCreatorEnhanced: Failed to initialize data system, falling back to enum-only mode")
			_setup_fallback_options()
			return
	
	_setup_ui_components()
	_connect_signals()
	
	# Get singleton dependencies
	dice_manager = get_node_or_null("/root/DiceManager")
	if not dice_manager:
		push_warning("CharacterCreatorEnhanced: DiceManager not found. Random generation will fail.")
	
	is_initialized = true
	print("CharacterCreatorEnhanced: Initialization complete")

func _setup_ui_components() -> void:
	"""Setup UI component data using hybrid data architecture"""
	_setup_option_buttons_with_data()
	_setup_stat_spinners()
	_setup_validation_display()

func _setup_option_buttons_with_data() -> void:
	"""Setup option buttons using rich JSON data with enum validation"""
	_populate_origin_options_enhanced()
	_populate_background_options_enhanced()
	_populate_class_options_enhanced()
	_populate_motivation_options_enhanced()

func _populate_origin_options_enhanced() -> void:
	"""Populate origin dropdown with ALL available origins from JSON data and enums"""
	if not origin_options:
		return
		
	origin_options.clear()
	
	# Get all available origins from JSON data
	var origins_data = DataManager._character_data.get("origins", {})
	var added_origins = []
	
	# Add origins from JSON data first
	for origin_key in origins_data.keys():
		# Validate against enum for type safety
		var enum_id = GlobalEnums.Origin.get(origin_key, -1)
		if enum_id == -1:
			push_warning("CharacterCreatorEnhanced: Origin '%s' not found in enum, skipping" % origin_key)
			continue
		
		var origin_data = origins_data[origin_key]
		var display_name = origin_data.get("name", origin_key.capitalize())
		
		origin_options.add_item(display_name, enum_id)
		added_origins.append(origin_key)
	
	# Add additional origins from enums that might not be in JSON
	var additional_origins = [
		{"id": GlobalEnums.Origin.CORE_WORLDS, "name": "Core Worlds"},
		{"id": GlobalEnums.Origin.FRONTIER, "name": "Frontier"},
		{"id": GlobalEnums.Origin.DEEP_SPACE, "name": "Deep Space"},
		{"id": GlobalEnums.Origin.COLONY, "name": "Colony"},
		{"id": GlobalEnums.Origin.HIVE_WORLD, "name": "Hive World"},
		{"id": GlobalEnums.Origin.FORGE_WORLD, "name": "Forge World"}
	]
	
	for origin_data in additional_origins:
		origin_options.add_item(origin_data.name, origin_data.id)
	
	print("CharacterCreatorEnhanced: Populated %d origin options (complete set)" % origin_options.get_item_count())

func _populate_background_options_enhanced() -> void:
	"""Populate background dropdown with ALL available backgrounds from JSON data and enums"""
	if not background_options:
		return
		
	background_options.clear()
	
	# Get backgrounds from specialized background data file
	var backgrounds = DataManager.get_all_backgrounds()
	var added_backgrounds = []
	
	# Add backgrounds from JSON data first
	for background_data in backgrounds:
		var background_id = background_data.get("id", "")
		var display_name = background_data.get("name", background_id.capitalize())
		
		# Map background ID to enum value for consistency
		var enum_value = _map_background_id_to_enum(background_id)
		if enum_value == -1:
			push_warning("CharacterCreatorEnhanced: Background '%s' has no enum mapping" % background_id)
			continue
		
		background_options.add_item(display_name, enum_value)
		added_backgrounds.append(background_id)
	
	# Add additional backgrounds from enums that might not be in JSON
	var additional_backgrounds = [
		{"id": GlobalEnums.Background.MERCENARY, "name": "Mercenary"},
		{"id": GlobalEnums.Background.EXPLORER, "name": "Explorer"},
		{"id": GlobalEnums.Background.TRADER, "name": "Trader"},
		{"id": GlobalEnums.Background.NOBLE, "name": "Noble"},
		{"id": GlobalEnums.Background.SOLDIER, "name": "Soldier"},
		{"id": GlobalEnums.Background.MERCHANT, "name": "Merchant"}
	]
	
	for background_data in additional_backgrounds:
		background_options.add_item(background_data.name, background_data.id)
	
	print("CharacterCreatorEnhanced: Populated %d background options (complete set)" % background_options.get_item_count())

func _map_background_id_to_enum(background_id: String) -> int:
	"""Map JSON background IDs to enum values for consistency"""
	match background_id:
		"military": return GlobalEnums.Background.MILITARY
		"criminal": return GlobalEnums.Background.CRIMINAL
		"scientist", "academic": return GlobalEnums.Background.ACADEMIC
		"mercenary": return GlobalEnums.Background.MERCENARY
		"colonist": return GlobalEnums.Background.COLONIST
		"pilot": return GlobalEnums.Background.EXPLORER # Map pilot to explorer
		"corporate": return GlobalEnums.Background.TRADER # Map corporate to trader
		"drifter": return GlobalEnums.Background.OUTCAST
		"noble": return GlobalEnums.Background.NOBLE
		"soldier": return GlobalEnums.Background.SOLDIER
		"merchant": return GlobalEnums.Background.MERCHANT
		_:
			push_warning("CharacterCreatorEnhanced: Unknown background ID: %s" % background_id)
			return -1

func _populate_class_options_enhanced() -> void:
	"""Populate class dropdown with ALL available classes from enums"""
	if not class_options:
		return
		
	class_options.clear()
	
	# Use ALL character classes from GlobalEnums
	var all_classes = [
		{"id": GlobalEnums.CharacterClass.SOLDIER, "name": "Soldier"},
		{"id": GlobalEnums.CharacterClass.SCOUT, "name": "Scout"},
		{"id": GlobalEnums.CharacterClass.MEDIC, "name": "Medic"},
		{"id": GlobalEnums.CharacterClass.ENGINEER, "name": "Engineer"},
		{"id": GlobalEnums.CharacterClass.PILOT, "name": "Pilot"},
		{"id": GlobalEnums.CharacterClass.MERCHANT, "name": "Merchant"},
		{"id": GlobalEnums.CharacterClass.SECURITY, "name": "Security"},
		{"id": GlobalEnums.CharacterClass.BROKER, "name": "Broker"},
		{"id": GlobalEnums.CharacterClass.BOT_TECH, "name": "Bot Technician"},
		{"id": GlobalEnums.CharacterClass.ROGUE, "name": "Rogue"},
		{"id": GlobalEnums.CharacterClass.PSIONICIST, "name": "Psionicist"},
		{"id": GlobalEnums.CharacterClass.TECH, "name": "Technician"},
		{"id": GlobalEnums.CharacterClass.BRUTE, "name": "Brute"},
		{"id": GlobalEnums.CharacterClass.GUNSLINGER, "name": "Gunslinger"},
		{"id": GlobalEnums.CharacterClass.ACADEMIC, "name": "Academic"}
	]
	
	for class_data in all_classes:
		class_options.add_item(class_data.name, class_data.id)
	
	print("CharacterCreatorEnhanced: Populated %d class options (complete set)" % class_options.get_item_count())

func _populate_motivation_options_enhanced() -> void:
	"""Populate motivation dropdown with ALL available motivations from enums"""
	if not motivation_options:
		return
		
	motivation_options.clear()
	
	# Use ALL motivations from GlobalEnums
	var all_motivations = [
		{"id": GlobalEnums.Motivation.WEALTH, "name": "Wealth"},
		{"id": GlobalEnums.Motivation.REVENGE, "name": "Revenge"},
		{"id": GlobalEnums.Motivation.GLORY, "name": "Glory"},
		{"id": GlobalEnums.Motivation.KNOWLEDGE, "name": "Knowledge"},
		{"id": GlobalEnums.Motivation.POWER, "name": "Power"},
		{"id": GlobalEnums.Motivation.JUSTICE, "name": "Justice"},
		{"id": GlobalEnums.Motivation.SURVIVAL, "name": "Survival"},
		{"id": GlobalEnums.Motivation.LOYALTY, "name": "Loyalty"},
		{"id": GlobalEnums.Motivation.FREEDOM, "name": "Freedom"},
		{"id": GlobalEnums.Motivation.DISCOVERY, "name": "Discovery"},
		{"id": GlobalEnums.Motivation.REDEMPTION, "name": "Redemption"},
		{"id": GlobalEnums.Motivation.DUTY, "name": "Duty"}
	]
	
	for motivation_data in all_motivations:
		motivation_options.add_item(motivation_data.name, motivation_data.id)
	
	print("CharacterCreatorEnhanced: Populated %d motivation options (complete set)" % motivation_options.get_item_count())

## Enhanced Character Generation with Rich JSON Data
func _regenerate_character_attributes() -> void:
	"""Regenerate character attributes using rich JSON data"""
	if not is_instance_valid(current_character) or not dice_manager:
		return
	
	print("CharacterCreatorEnhanced: Regenerating character with enhanced data system")
	
	# Generate base attributes using Five Parsecs rules
	FiveParsecsCharacterGeneration.generate_character_attributes(current_character)
	
	# Apply rich origin bonuses from JSON
	_apply_origin_data_bonuses()
	
	# Apply rich background bonuses from JSON
	_apply_background_data_bonuses()
	
	# Apply class bonuses (using existing system)
	FiveParsecsCharacterGeneration.apply_class_bonuses(current_character)
	
	# Apply origin effects
	FiveParsecsCharacterGeneration.set_character_flags(current_character)
	
	# Recalculate derived stats
	current_character.max_health = current_character.toughness + 2
	current_character.health = current_character.max_health
	
	print("CharacterCreatorEnhanced: Enhanced character generation complete - Health: %d, Toughness: %d" % [current_character.max_health, current_character.toughness])

func _apply_origin_data_bonuses() -> void:
	"""Apply origin bonuses from rich JSON data"""
	var origin_name = GlobalEnums.get_origin_name(current_character.origin)
	var origin_data = DataManager.get_origin_data(origin_name)
	
	if origin_data.is_empty():
		push_warning("CharacterCreatorEnhanced: No origin data found for %s" % origin_name)
		return
	
	# Apply base stat bonuses from JSON
	var base_stats = origin_data.get("base_stats", {})
	for stat_name in base_stats.keys():
		var bonus = base_stats[stat_name]
		_apply_stat_bonus(stat_name, bonus)
	
	# Add characteristics as traits
	var characteristics = origin_data.get("characteristics", [])
	for characteristic in characteristics:
		if current_character.has_method("add_trait"):
			current_character.add_trait("Origin: " + characteristic)
	
	print("CharacterCreatorEnhanced: Applied origin bonuses for %s" % origin_name)

func _apply_background_data_bonuses() -> void:
	"""Apply background bonuses from rich JSON data"""
	var background_id = _get_background_id_from_enum(current_character.background)
	var background_data = DataManager.get_background_data(background_id)
	
	if background_data.is_empty():
		push_warning("CharacterCreatorEnhanced: No background data found for %s" % background_id)
		return
	
	# Apply stat bonuses
	var stat_bonuses = background_data.get("stat_bonuses", {})
	for stat_name in stat_bonuses.keys():
		var bonus = stat_bonuses[stat_name]
		_apply_stat_bonus(stat_name, bonus)
	
	# Apply stat penalties
	var stat_penalties = background_data.get("stat_penalties", {})
	for stat_name in stat_penalties.keys():
		var penalty = stat_penalties[stat_name]
		_apply_stat_bonus(stat_name, penalty) # Penalty is negative bonus
	
	# Add starting skills as traits
	var starting_skills = background_data.get("starting_skills", [])
	for skill in starting_skills:
		if current_character.has_method("add_trait"):
			current_character.add_trait("Skill: " + skill)
	
	# Add special abilities as traits
	var special_abilities = background_data.get("special_abilities", [])
	for ability in special_abilities:
		var ability_name = ability.get("name", "Unknown Ability")
		var ability_desc = ability.get("description", "")
		if current_character.has_method("add_trait"):
			current_character.add_trait("Ability: %s - %s" % [ability_name, ability_desc])
	
	print("CharacterCreatorEnhanced: Applied background bonuses for %s" % background_id)

func _apply_stat_bonus(stat_name: String, bonus: int) -> void:
	"""Apply stat bonus using correct property mapping"""
	match stat_name.to_lower():
		"combat", "combat_skill":
			current_character.combat = clampi(current_character.combat + bonus, 0, 5)
		"reactions", "reaction":
			current_character.reaction = clampi(current_character.reaction + bonus, 1, 6)
		"toughness":
			current_character.toughness = clampi(current_character.toughness + bonus, 1, 6)
		"speed":
			current_character.speed = clampi(current_character.speed + bonus, 4, 8)
		"savvy":
			current_character.savvy = clampi(current_character.savvy + bonus, 0, 5)

func _get_background_id_from_enum(background_enum: int) -> String:
	"""Convert enum background to JSON background ID"""
	match background_enum:
		GlobalEnums.Background.MILITARY: return "military"
		GlobalEnums.Background.CRIMINAL: return "criminal"
		GlobalEnums.Background.ACADEMIC: return "scientist"
		GlobalEnums.Background.MERCENARY: return "mercenary"
		GlobalEnums.Background.COLONIST: return "colonist"
		GlobalEnums.Background.EXPLORER: return "pilot"
		GlobalEnums.Background.TRADER: return "corporate"
		GlobalEnums.Background.OUTCAST: return "drifter"
		_: return "drifter" # Safe default

## Enhanced Character Preview with Rich Data
func _update_character_preview() -> void:
	"""Update character preview with rich data integration"""
	if not traits_display:
		return

	var preview_text := ""
	if not is_instance_valid(current_character):
		traits_display.text = "Create a character to see details."
		return

	# Use safe enum helper functions with rich data enhancement
	var character_class_name = GlobalEnums.get_class_display_name(current_character.character_class)
	var background_name = _get_enhanced_background_name(current_character.background)
	var origin_name = _get_enhanced_origin_name(current_character.origin)
	var motivation_name = GlobalEnums.get_motivation_display_name(current_character.motivation)

	preview_text += "[b]Name:[/b] %s\n" % current_character.character_name
	preview_text += "[b]Class:[/b] %s\n" % character_class_name
	preview_text += "[b]Background:[/b] %s\n" % background_name
	preview_text += "[b]Origin:[/b] %s\n" % origin_name
	preview_text += "[b]Motivation:[/b] %s\n\n" % motivation_name
	
	preview_text += "[b]Stats:[/b]\n"
	preview_text += "  Reaction: %d | Speed: %d\" | Combat: +%d\n" % [current_character.reaction, current_character.speed, current_character.combat]
	preview_text += "  Toughness: %d | Savvy: +%d | Luck: %d\n\n" % [current_character.toughness, current_character.savvy, current_character.luck]

	if not current_character.traits.is_empty():
		preview_text += "[b]Features:[/b]\n"
		for character_feature in current_character.traits:
			preview_text += "  - %s\n" % character_feature
		preview_text += "\n"
	
	# Add rich background information if available
	var background_id = _get_background_id_from_enum(current_character.background)
	var background_data = DataManager.get_background_data(background_id)
	if not background_data.is_empty():
		var description = background_data.get("description", "")
		if not description.is_empty():
			preview_text += "[b]Background:[/b] %s\n\n" % description

	traits_display.text = preview_text

func _get_enhanced_background_name(background_enum: int) -> String:
	"""Get enhanced background name from JSON data"""
	var background_id = _get_background_id_from_enum(background_enum)
	var background_data = DataManager.get_background_data(background_id)
	
	if not background_data.is_empty():
		return background_data.get("name", GlobalEnums.get_background_display_name(background_enum))
	
	return GlobalEnums.get_background_display_name(background_enum)

func _get_enhanced_origin_name(origin_enum: int) -> String:
	"""Get enhanced origin name from JSON data"""
	var origin_name = GlobalEnums.get_origin_name(origin_enum)
	var origin_data = DataManager.get_origin_data(origin_name)
	
	if not origin_data.is_empty():
		return origin_data.get("name", GlobalEnums.get_origin_display_name(origin_enum))
	
	return GlobalEnums.get_origin_display_name(origin_enum)

## Signal Connections
func _connect_signals() -> void:
	"""Connect UI signals for character creation"""
	if origin_options:
		origin_options.item_selected.connect(_on_origin_selected)
	
	if background_options:
		background_options.item_selected.connect(_on_background_selected)
	
	if class_options:
		class_options.item_selected.connect(_on_class_selected)
	
	if motivation_options:
		motivation_options.item_selected.connect(_on_motivation_selected)

func _on_origin_selected(index: int) -> void:
	"""Handle origin selection"""
	if not is_instance_valid(current_character):
		_create_new_character()
	
	current_character.origin = origin_options.get_item_id(index)
	_regenerate_character_attributes()
	_update_character_preview()

func _on_background_selected(index: int) -> void:
	"""Handle background selection"""
	if not is_instance_valid(current_character):
		_create_new_character()
	
	current_character.background = background_options.get_item_id(index)
	_regenerate_character_attributes()
	_update_character_preview()

func _on_class_selected(index: int) -> void:
	"""Handle class selection"""
	if not is_instance_valid(current_character):
		_create_new_character()
	
	current_character.character_class = class_options.get_item_id(index)
	_regenerate_character_attributes()
	_update_character_preview()

func _on_motivation_selected(index: int) -> void:
	"""Handle motivation selection"""
	if not is_instance_valid(current_character):
		_create_new_character()
	
	current_character.motivation = motivation_options.get_item_id(index)
	_regenerate_character_attributes()
	_update_character_preview()

## Character Creation
func _create_new_character() -> void:
	"""Create a new character using the hybrid approach"""
	print("CharacterCreatorEnhanced: Creating new character with hybrid approach")
	
	current_character = Character.new()
	current_character.character_name = "New Character"
	
	# Set default values from UI if available
	if origin_options and origin_options.get_item_count() > 0:
		current_character.origin = origin_options.get_item_id(0)
	
	if background_options and background_options.get_item_count() > 0:
		current_character.background = background_options.get_item_id(0)
	
	if class_options and class_options.get_item_count() > 0:
		current_character.character_class = class_options.get_item_id(0)
	
	if motivation_options and motivation_options.get_item_count() > 0:
		current_character.motivation = motivation_options.get_item_id(0)
	
	# Generate attributes using hybrid approach
	_regenerate_character_attributes()
	_update_character_preview()
	
	print("CharacterCreatorEnhanced: Character created successfully")

## Fallback System for Enum-Only Mode
func _setup_fallback_options() -> void:
	"""Fallback to enum-only mode if JSON data fails to load"""
	push_warning("CharacterCreatorEnhanced: Using fallback enum-only mode")
	
	_populate_class_options() # Uses existing enum-based method
	_populate_background_options() # Uses existing enum-based method
	_populate_motivation_options() # Uses existing enum-based method
	_populate_origin_options() # Uses existing enum-based method

# Placeholder methods for fallback system
func _populate_class_options() -> void:
	"""Placeholder for enum-based class population"""
	pass

func _populate_background_options() -> void:
	"""Placeholder for enum-based background population"""
	pass

func _populate_motivation_options() -> void:
	"""Placeholder for enum-based motivation population"""
	pass

func _populate_origin_options() -> void:
	"""Placeholder for enum-based origin population"""
	pass

func _setup_stat_spinners() -> void:
	"""Placeholder for stat spinner setup"""
	pass

func _setup_validation_display() -> void:
	"""Placeholder for validation display setup"""
	pass

## Public API for external access
func get_current_character() -> Character:
	"""Get the currently created character"""
	return current_character

func create_random_character() -> Character:
	"""Create a random character using the hybrid approach"""
	if not is_initialized:
		push_error("CharacterCreatorEnhanced: Not initialized")
		return null
	
	print("CharacterCreatorEnhanced: Creating random character")
	
	# Use FiveParsecsCharacterGeneration for random character
	current_character = FiveParsecsCharacterGeneration.generate_random_character()
	
	if current_character:
		_update_character_preview()
		print("CharacterCreatorEnhanced: Random character created: %s" % current_character.character_name)
	else:
		push_error("CharacterCreatorEnhanced: Failed to create random character")
	
	return current_character

func validate_character() -> Dictionary:
	"""Validate the current character"""
	if not is_instance_valid(current_character):
		return {"valid": false, "errors": ["No character created"]}
	
	return FiveParsecsCharacterGeneration.validate_character(current_character)

func get_character_data() -> Dictionary:
	"""Get character data for saving"""
	if not is_instance_valid(current_character):
		return {}
	
	return current_character.serialize()

func load_character_data(data: Dictionary) -> void:
	"""Load character data from saved data"""
	if data.is_empty():
		return
	
	current_character = Character.new()
	current_character.deserialize(data)
	_update_character_preview()
	print("CharacterCreatorEnhanced: Character loaded from data")
