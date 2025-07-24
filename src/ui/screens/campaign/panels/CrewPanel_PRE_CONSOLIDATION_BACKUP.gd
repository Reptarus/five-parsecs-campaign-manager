extends Control

## Five Parsecs Campaign Creation Crew Panel
## Production-ready implementation with hybrid data architecture integration

const Character = preload("res://src/core/character/Character.gd")
const UniversalResourceLoader = preload("res://src/core/systems/UniversalResourceLoader.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const BaseEnhancedComponents = preload("res://src/ui/components/enhanced/BaseEnhancedComponents.gd")
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")

signal crew_updated(crew: Array)
signal crew_setup_complete(crew_data: Dictionary)

# UI Components using safe access pattern
var crew_size_option: OptionButton
var crew_list: ItemList
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

## UI References
@onready var crew_container: VBoxContainer = %CrewContainer
@onready var crew_summary: Label = %CrewSummary
@onready var crew_status_overview: Control = %CrewStatusOverview
@onready var crew_performance_chart: Control = %CrewPerformanceChart
@onready var crew_equipment_summary: Control = %CrewEquipmentSummary

# Crew data and state
var crew_members: Array[Character] = []
var crew_data: Array[Dictionary] = []
var selected_crew_member: String = ""
var crew_performance_data: Dictionary = {}
var selected_size: int = 4
var is_initialized: bool = false
var current_captain: Character = null
var character_creator: Node = null

# Data-driven character creation tables
var _character_data: Dictionary = {}
var _backgrounds_data: Dictionary = {}
var _skills_data: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	print("CrewPanel: Initializing with hybrid data architecture...")
	
	# Initialize data system if not already loaded
	if not DataManager._is_data_loaded:
		var success = DataManager.initialize_data_system()
		if not success:
			push_error("CrewPanel: Failed to initialize data system, using fallback mode")
	
	call_deferred("_initialize_components")

func _initialize_components() -> void:
	"""Initialize UI components with safe access patterns and hybrid data architecture"""
	var success: bool = true

	# Load data first using hybrid architecture
	_load_character_data_enhanced()
	
	# Initialize UI components
	_setup_crew_panel()
	_connect_enhanced_signals()
	_apply_responsive_layout()
	_setup_crew_size_options()
	_connect_signals()
	
	is_initialized = true
	print("CrewPanel: Initialization complete")

func _setup_crew_panel() -> void:
	# Initialize crew display components
	if not crew_container:
		push_warning("CrewPanel: Crew container not found")
		return
	
	# Setup performance tracking
	_setup_performance_tracking()
	
	# Setup equipment summary
	_setup_equipment_summary()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect crew-related signals
	enhanced_signals.connect_signal_safely("crew_status_changed", self, "_on_crew_status_changed")
	enhanced_signals.connect_signal_safely("crew_performance_updated", self, "_on_crew_performance_updated")
	enhanced_signals.connect_signal_safely("crew_equipment_changed", self, "_on_crew_equipment_changed")
	enhanced_signals.connect_signal_safely("crew_health_changed", self, "_on_crew_health_changed")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if crew_container:
		crew_container.custom_minimum_size.y = 200
		crew_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if crew_summary:
		crew_summary.text = _generate_compact_crew_summary()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if crew_container:
		crew_container.custom_minimum_size.y = 300
		crew_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if crew_summary:
		crew_summary.text = _generate_detailed_crew_summary()

## Main crew display update function
func update_crew_display(new_crew_data: Array) -> void:
	crew_data = new_crew_data
	
	# Clear existing crew cards
	_clear_crew_cards()
	
	# Create enhanced crew cards following dice system patterns
	for member in crew_data:
		var crew_card = _create_enhanced_crew_card(member)
		if crew_card:
			crew_container.add_child(crew_card)
	
	# Update summary and performance data
	_update_crew_summary()
	_update_performance_chart()
	_update_equipment_summary()

func _clear_crew_cards() -> void:
	if not crew_container:
		return
	
	# Clear existing crew cards safely
	for child in crew_container.get_children():
		child.queue_free()

func _create_enhanced_crew_card(member_data: Dictionary) -> Control:
	# Create crew stats card following dice system design
	var crew_card = BaseEnhancedComponents.CrewStatsCard.new()
	
	# Setup with safety validation (Universal safety pattern)
	crew_card.setup_with_safety_validation(member_data)
	
	# Apply visual styling from dice system
	_apply_crew_card_styling(crew_card, member_data)
	
	# Connect crew card signals
	crew_card.card_selected.connect(_on_crew_card_selected)
	crew_card.card_action_requested.connect(_on_crew_action_requested)
	
	return crew_card

func _apply_crew_card_styling(crew_card: Control, member_data: Dictionary) -> void:
	# Apply color coding based on crew status (dice system colors)
	var health_ratio = member_data.get("health_ratio", 1.0)
	var status = member_data.get("status", "active")
	
	match status:
		"injured":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"recovering":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
		"active":
			crew_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			crew_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_crew_summary() -> void:
	if not crew_summary:
		return
	
	var total_crew = crew_data.size()
	var active_crew = 0
	var injured_crew = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_crew += 1
		elif status == "injured":
			injured_crew += 1
		
		total_health += health
	
	var avg_health = total_health / total_crew if total_crew > 0 else 0.0
	
	# Update summary with contextual information
	crew_summary.text = "Crew: %d Active, %d Injured (Avg Health: %.1f%%)" % [
		active_crew, injured_crew, avg_health * 100
	]

func _update_performance_chart() -> void:
	if not crew_performance_chart:
		return
	
	# Update performance visualization
	var performance_data = _calculate_crew_performance()
	crew_performance_chart.update_performance_display(performance_data)

func _update_equipment_summary() -> void:
	if not crew_equipment_summary:
		return
	
	# Update equipment summary
	var equipment_data = _calculate_equipment_summary()
	crew_equipment_summary.update_equipment_display(equipment_data)

func _calculate_crew_performance() -> Dictionary:
	var performance = {
		"total_missions": 0,
		"successful_missions": 0,
		"average_combat_rating": 0.0,
		"average_survival_rate": 0.0
	}
	
	var total_combat = 0.0
	var total_survival = 0.0
	var crew_count = crew_data.size()
	
	for member in crew_data:
		var stats = member.get("stats", {})
		total_combat += stats.get("combat", 0)
		total_survival += stats.get("survival_rate", 0.0)
		
		var missions = member.get("missions", {})
		performance.total_missions += missions.get("total", 0)
		performance.successful_missions += missions.get("successful", 0)
	
	if crew_count > 0:
		performance.average_combat_rating = total_combat / crew_count
		performance.average_survival_rate = total_survival / crew_count
	
	return performance

func _calculate_equipment_summary() -> Dictionary:
	var equipment_summary = {
		"total_weapons": 0,
		"total_armor": 0,
		"total_gear": 0,
		"upgraded_items": 0
	}
	
	for member in crew_data:
		var equipment = member.get("equipment", {})
		equipment_summary.total_weapons += equipment.get("weapons", []).size()
		equipment_summary.total_armor += equipment.get("armor", []).size()
		equipment_summary.total_gear += equipment.get("gear", []).size()
		
		# Count upgraded items
		var upgrades = equipment.get("upgrades", [])
		equipment_summary.upgraded_items += upgrades.size()
	
	return equipment_summary

## Signal handlers
func _on_crew_card_selected(card_data: Dictionary) -> void:
	selected_crew_member = card_data.get("crew_id", "")
	enhanced_signals.emit_safe_signal("crew_member_selected", [selected_crew_member])

func _on_crew_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

func _on_crew_status_changed(crew_member: String, status: Dictionary) -> void:
	# Update crew member status in local data
	for member in crew_data:
		if member.get("id") == crew_member:
			member.merge(status)
			break
	
	# Refresh display
	update_crew_display(crew_data)

func _on_crew_performance_updated(crew_id: String, performance: Dictionary) -> void:
	crew_performance_data[crew_id] = performance
	_update_performance_chart()

func _on_crew_equipment_changed(crew_id: String, equipment: Dictionary) -> void:
	# Update crew member equipment
	for member in crew_data:
		if member.get("id") == crew_id:
			member["equipment"] = equipment
			break
	
	_update_equipment_summary()

func _on_crew_health_changed(crew_id: String, health_ratio: float) -> void:
	# Update crew member health
	for member in crew_data:
		if member.get("id") == crew_id:
			member["health_ratio"] = health_ratio
			break
	
	# Refresh display with updated health
	update_crew_display(crew_data)

## Helper functions
func _generate_compact_crew_summary() -> String:
	var active_count = 0
	for member in crew_data:
		if member.get("status") == "active":
			active_count += 1
	
	return "Crew: %d/%d Active" % [active_count, crew_data.size()]

func _generate_detailed_crew_summary() -> String:
	var active_count = 0
	var injured_count = 0
	var total_health = 0.0
	
	for member in crew_data:
		var status = member.get("status", "active")
		var health = member.get("health_ratio", 1.0)
		
		if status == "active":
			active_count += 1
		elif status == "injured":
			injured_count += 1
		
		total_health += health
	
	var avg_health = total_health / crew_data.size() if crew_data.size() > 0 else 0.0
	
	return "Crew Status: %d Active, %d Injured | Avg Health: %.1f%%" % [
		active_count, injured_count, avg_health * 100
	]

func _setup_performance_tracking() -> void:
	# Initialize performance tracking system
	crew_performance_data = {}

func _setup_equipment_summary() -> void:
	# Initialize equipment summary system
	pass

## Public API for external access
func get_crew_data() -> Array:
	return crew_data

func get_selected_crew_member() -> String:
	return selected_crew_member

func get_crew_performance_data() -> Dictionary:
	return crew_performance_data

func refresh_display() -> void:
	update_crew_display(crew_data)

## Campaign Creation Specific Functionality

func _show_error_state() -> void:
	"""Show error state when initialization fails"""
	if crew_container:
		var error_label = Label.new()
		error_label.text = "Failed to initialize crew system. Please check logs for details."
		error_label.add_theme_color_override("font_color", Color.RED)
		crew_container.add_child(error_label)

func _setup_crew_size_options() -> void:
	"""Setup crew size selection options"""
	if not crew_size_option:
		crew_size_option = OptionButton.new()
		crew_size_option.name = "CrewSizeOption"
	
	crew_size_option.clear()
	for i in range(1, 9):  # 1-8 crew members
		crew_size_option.add_item(str(i) + " Members", i)
	
	# Set default to 4
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == 4:
			crew_size_option.select(i)
			break

func _connect_signals() -> void:
	"""Connect UI signals"""
	if crew_size_option:
		crew_size_option.item_selected.connect(_on_crew_size_selected)
	
	# Connect UI buttons if they exist
	if add_button:
		add_button.pressed.connect(_on_add_member_pressed)
	if edit_button:
		edit_button.pressed.connect(_on_edit_member_pressed)
	if remove_button:
		remove_button.pressed.connect(_on_remove_member_pressed)
	if randomize_button:
		randomize_button.pressed.connect(_on_randomize_pressed)
	
	# Connect crew list selection
	if crew_list:
		crew_list.item_selected.connect(_on_crew_member_selected)

func _disconnect_signals() -> void:
	"""Safely disconnect all signals"""
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

func _generate_initial_crew() -> void:
	"""Generate initial crew based on selected size"""
	crew_members.clear()
	
	for i in range(selected_size):
		var character = _create_random_character_enhanced()
		if character:
			crew_members.append(character)
	
	# Assign first member as captain if none assigned
	if crew_members.size() > 0 and not current_captain:
		current_captain = crew_members[0]
		_assign_captain_title(current_captain)

func _create_random_character_enhanced() -> Character:
	"""Create a random character using enhanced data architecture"""
	var character = Character.new()
	
	# Use enhanced character generation with DataManager
	var origin_id = GlobalEnums.Origin.keys()[randi() % GlobalEnums.Origin.size()]
	var background_data = _get_enhanced_background_selection()
	var class_data = _get_enhanced_class_selection()
	var motivation_data = _get_enhanced_motivation_selection()
	
	# Apply enhanced character generation
	character.character_name = _generate_random_full_name()
	character.origin = GlobalEnums.Origin[origin_id]
	
	# Apply background and class bonuses using enhanced system
	_apply_enhanced_origin_bonuses(character)
	if background_data:
		_apply_enhanced_background_bonuses(character, background_data)
	
	# Generate Five Parsecs attributes
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute()
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute()
	character.tech = _generate_five_parsecs_attribute()
	character.speed = _generate_five_parsecs_attribute()
	character.luck = 1  # Starting luck
	
	# Set health based on toughness
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	print("CrewPanel: Created enhanced character: ", character.character_name)
	return character

func _create_enhanced_fallback_character() -> Character:
	"""Create a basic character when enhanced generation fails"""
	var character = Character.new()
	
	# Basic character setup
	character.character_name = _generate_fallback_name()
	character.origin = GlobalEnums.Origin.HUMAN
	character.background = GlobalEnums.Background.WANDERER
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Basic attributes
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute()
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute()
	character.tech = _generate_five_parsecs_attribute()
	character.speed = _generate_five_parsecs_attribute()
	character.luck = 1
	
	# Set health
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	return character

func _get_enhanced_background_selection() -> Dictionary:
	"""Get enhanced background data from DataManager"""
	var all_backgrounds = DataManager.get_all_backgrounds()
	if all_backgrounds.is_empty():
		push_warning("CrewPanel: No background data available")
		return {}
	
	var selected_background = all_backgrounds[randi() % all_backgrounds.size()]
	return selected_background

func _get_enhanced_class_selection() -> Dictionary:
	"""Get enhanced class data from DataManager"""
	var class_data = DataManager.get_character_class_data("SOLDIER")  # Default fallback
	
	# Try to get random class data if available
	var available_classes = ["SOLDIER", "ENGINEER", "PILOT", "SECURITY", "MEDIC"]
	var random_class = available_classes[randi() % available_classes.size()]
	var random_class_data = DataManager.get_character_class_data(random_class)
	
	if not random_class_data.is_empty():
		return random_class_data
	
	return class_data

func _get_enhanced_motivation_selection() -> Dictionary:
	"""Get enhanced motivation data from DataManager"""
	# This would integrate with DataManager when motivation data is available
	var motivations = ["SURVIVAL", "REVENGE", "WEALTH", "JUSTICE", "FREEDOM"]
	var selected_motivation = motivations[randi() % motivations.size()]
	
	return {"id": selected_motivation, "name": selected_motivation.capitalize()}

func _get_enhanced_origin_selection() -> Dictionary:
	"""Get enhanced origin data from DataManager"""
	var origin_keys = GlobalEnums.Origin.keys()
	var selected_origin = origin_keys[randi() % origin_keys.size()]
	
	var origin_data = DataManager.get_origin_data(selected_origin)
	if origin_data.is_empty():
		# Fallback to basic origin data
		return {"id": selected_origin, "name": selected_origin.capitalize()}
	
	return origin_data

func _generate_random_full_name() -> String:
	"""Generate a random full name"""
	var first_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake",
					   "Zara", "Nova", "Kai", "Aria", "Rex", "Luna", "Orion", "Sage", "Phoenix", "Storm"]
	var last_names = ["Steel", "Cross", "Vale", "Stone", "Reed", "Storm", "Blake", "Cross", "Vale", "Sharp",
					  "Nova", "Vex", "Zane", "Raven", "Stark", "Wolf", "Fox", "Hawk", "Swift", "Grey"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

func _apply_enhanced_origin_bonuses(character: Character) -> void:
	"""Apply origin bonuses using enhanced data system"""
	match character.origin:
		GlobalEnums.Origin.HUMAN:
			# Humans get versatility bonus
			character.luck += 1
		GlobalEnums.Origin.ENGINEER:
			# Engineer origin gets tech bonus
			_apply_stat_bonus(character, "tech", 2)
		GlobalEnums.Origin.KERIN:
			# Kerin get combat bonus
			_apply_stat_bonus(character, "combat", 2)
		GlobalEnums.Origin.SOULLESS:
			# Soulless get toughness bonus
			_apply_stat_bonus(character, "toughness", 1)
			_apply_stat_bonus(character, "tech", 1)
		GlobalEnums.Origin.PRECURSOR:
			# Precursor get savvy bonus
			_apply_stat_bonus(character, "savvy", 2)
		GlobalEnums.Origin.SWIFT:
			# Swift get speed bonus
			_apply_stat_bonus(character, "speed", 2)
		GlobalEnums.Origin.BOT:
			# Bot get tech and toughness bonus
			_apply_stat_bonus(character, "tech", 1)
			_apply_stat_bonus(character, "toughness", 1)

func _apply_enhanced_background_bonuses(character: Character, background_data: Dictionary) -> void:
	"""Apply background bonuses from enhanced data"""
	var stat_bonuses = background_data.get("stat_bonuses", {})
	
	for stat_name in stat_bonuses.keys():
		var bonus = stat_bonuses[stat_name]
		if typeof(bonus) == TYPE_INT:
			_apply_stat_bonus(character, stat_name, bonus)
	
	# Apply special abilities if available
	var abilities = background_data.get("abilities", [])
	for ability in abilities:
		# This would integrate with character ability system
		print("CrewPanel: Applied background ability: ", ability)

func _apply_stat_bonus(character: Character, stat_name: String, bonus: int) -> void:
	"""Apply stat bonus to character with bounds checking"""
	match stat_name.to_lower():
		"combat":
			character.combat = min(6, character.combat + bonus)
		"reaction":
			character.reaction = min(6, character.reaction + bonus)
		"toughness":
			character.toughness = min(6, character.toughness + bonus)
		"savvy":
			character.savvy = min(6, character.savvy + bonus)
		"tech":
			character.tech = min(6, character.tech + bonus)
		"speed":
			character.speed = min(6, character.speed + bonus)

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute (2d6/3 rounded up)"""
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)  # 2d6
	return int(ceil(float(roll) / 3.0))

func _generate_fallback_name() -> String:
	"""Generate a simple fallback name"""
	var names = ["Crew Alpha", "Crew Beta", "Crew Gamma", "Crew Delta", "Crew Echo"]
	return names[randi() % names.size()]

## Campaign Creation UI Event Handlers

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
			var character = _create_random_character_enhanced()
			if character:
				crew_members.append(character)
	elif current_size > selected_size:
		# Remove excess members (keep captain if possible)
		var members_to_remove = current_size - selected_size
		for i in range(members_to_remove):
			if crew_members.size() > selected_size:
				var member_to_remove = crew_members.back()
				if member_to_remove != current_captain:
					crew_members.pop_back()
				else:
					# Remove a different member instead
					crew_members.pop_front()

func _on_add_member_pressed() -> void:
	"""Handle add crew member button"""
	if crew_members.size() >= 8:  # Maximum crew size
		push_warning("CrewPanel: Cannot add more crew members (maximum 8)")
		return
	
	_create_new_character_for_customization()

func _create_new_character_for_customization() -> void:
	"""Create a new character and open customization"""
	_open_character_creator_for_new_member()

func _open_character_creator_for_new_member() -> void:
	"""Open character creator for new member"""
	# Create character creator dialog/screen
	var character_creator_scene = preload("res://src/ui/screens/character/CharacterCreator.tscn")
	if character_creator_scene:
		character_creator = character_creator_scene.instantiate()
		get_tree().current_scene.add_child(character_creator)
		
		# Connect signals
		if character_creator.has_signal("character_created"):
			character_creator.character_created.connect(_on_new_character_created)
		if character_creator.has_signal("character_creation_cancelled"):
			character_creator.character_creation_cancelled.connect(_on_new_character_creation_cancelled)
		
		print("CrewPanel: Opened character creator for new member")
	else:
		# Fallback to simple character creation
		_show_simple_character_creator()

func _show_simple_character_creator():
	"""Show simple character creation dialog as fallback"""
	var dialog = AcceptDialog.new()
	dialog.title = "Create New Crew Member"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Character Name"
	vbox.add_child(name_input)
	
	var create_button = Button.new()
	create_button.text = "Create Character"
	create_button.pressed.connect(func(): _on_simple_character_created({
		"name": name_input.text if not name_input.text.is_empty() else _generate_fallback_name()
	}))
	vbox.add_child(create_button)
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _on_simple_character_created(character_data: Dictionary):
	"""Handle simple character creation"""
	var character = Character.new()
	character.character_name = character_data.get("name", _generate_fallback_name())
	
	# Check for duplicate names
	if _is_duplicate_name(character.character_name):
		character.character_name += " " + str(randi_range(1, 99))
	
	# Set basic attributes
	character.origin = GlobalEnums.Origin.HUMAN
	character.background = GlobalEnums.Background.WANDERER
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Generate random attributes
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute()
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute()
	character.tech = _generate_five_parsecs_attribute()
	character.speed = _generate_five_parsecs_attribute()
	character.luck = 1
	
	# Set health
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Add to crew
	crew_members.append(character)
	crew_updated.emit(crew_members)
	
	print("CrewPanel: Created simple character: ", character.character_name)

func _is_duplicate_name(name: String) -> bool:
	"""Check if character name already exists in crew"""
	for member in crew_members:
		if member.character_name == name:
			return true
	return false

func _on_edit_member_pressed() -> void:
	"""Handle edit crew member button"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		push_warning("CrewPanel: No crew member selected for editing")
		return
	
	var selected_index = crew_list.get_selected_items()[0]
	if selected_index < 0 or selected_index >= crew_members.size():
		push_error("CrewPanel: Invalid crew member index for editing")
		return
	
	var character = crew_members[selected_index]
	_show_character_editor(character)

func _on_remove_member_pressed() -> void:
	"""Handle remove crew member button"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		push_warning("CrewPanel: No crew member selected for removal")
		return
	
	var selected_index = crew_list.get_selected_items()[0]
	if selected_index < 0 or selected_index >= crew_members.size():
		push_error("CrewPanel: Invalid crew member index for removal")
		return
	
	var character = crew_members[selected_index]
	crew_members.remove_at(selected_index)
	
	# If removed character was captain, assign new captain
	if character == current_captain and crew_members.size() > 0:
		current_captain = crew_members[0]
		_assign_captain_title(current_captain)
	
	crew_updated.emit(crew_members)

func _on_randomize_pressed() -> void:
	"""Handle randomize crew button"""
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "This will replace all current crew members with randomly generated ones. Continue?"
	confirmation.confirmed.connect(_generate_initial_crew)
	
	get_tree().current_scene.add_child(confirmation)
	confirmation.popup_centered()

func _on_new_character_created(character: Character) -> void:
	"""Handle new character created from character creator"""
	crew_members.append(character)
	crew_updated.emit(crew_members)
	
	if character_creator:
		character_creator.queue_free()
		character_creator = null

func _on_new_character_creation_cancelled() -> void:
	"""Handle character creation cancelled"""
	if character_creator:
		character_creator.queue_free()
		character_creator = null

func _show_character_editor(character: Character) -> void:
	"""Show character editor for existing character"""
	var editor_scene = preload("res://src/ui/screens/character/CharacterCreator.tscn")
	if editor_scene:
		var editor = editor_scene.instantiate()
		get_tree().current_scene.add_child(editor)
		
		# Set character data for editing
		if editor.has_method("set_character_data"):
			editor.set_character_data(character)
		
		# Connect signals
		if editor.has_signal("character_updated"):
			editor.character_updated.connect(_on_character_updated)
		if editor.has_signal("character_editing_cancelled"):
			editor.character_editing_cancelled.connect(_on_character_editing_cancelled)

func _on_character_updated(character: Character) -> void:
	"""Handle character updated from editor"""
	crew_updated.emit(crew_members)

func _on_character_editing_cancelled() -> void:
	"""Handle character editing cancelled"""
	pass

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection in list"""
	if index < 0 or index >= crew_members.size():
		return
	
	var character = crew_members[index]
	_show_captain_assignment_option(index)

func _show_captain_assignment_option(index: int) -> void:
	"""Show option to assign character as captain"""
	var character = crew_members[index]
	
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Make %s the crew captain?" % character.character_name
	dialog.confirmed.connect(func(): _make_captain(character))
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _make_captain(character: Character) -> void:
	"""Assign character as captain"""
	# Remove captain title from previous captain
	if current_captain:
		_remove_captain_title(current_captain)
	
	# Assign new captain
	current_captain = character
	_assign_captain_title(character)
	
	crew_updated.emit(crew_members)

func _assign_captain_title(character: Character) -> void:
	"""Add captain title to character"""
	if not character.character_name.contains("(Captain)"):
		character.character_name += " (Captain)"

func _remove_captain_title(character: Character) -> void:
	"""Remove captain title from character"""
	character.character_name = character.character_name.replace(" (Captain)", "")

func get_captain() -> Character:
	"""Get current captain"""
	return current_captain

## Data Management and Validation

func _load_character_data_enhanced() -> void:
	"""Load character data using enhanced DataManager"""
	_character_data = DataManager.get_character_creation_data()
	_backgrounds_data = DataManager.get_all_backgrounds()
	
	if _character_data.is_empty():
		push_warning("CrewPanel: Character creation data not available")
	if _backgrounds_data.is_empty():
		push_warning("CrewPanel: Background data not available")

func is_valid() -> bool:
	"""Check if crew panel data is valid"""
	return crew_members.size() >= 1 and crew_members.size() <= 8

func validate() -> Array[String]:
	"""Validate crew data and return error messages"""
	var errors: Array[String] = []
	
	if crew_members.is_empty():
		errors.append("At least one crew member is required")
	
	if crew_members.size() > 8:
		errors.append("Maximum 8 crew members allowed")
	
	if not current_captain:
		errors.append("A captain must be assigned")
	
	return errors

func get_data() -> Dictionary:
	"""Get crew data for campaign creation"""
	return {
		"crew_members": crew_members,
		"captain": current_captain,
		"crew_size": crew_members.size()
	}

func set_data(data: Dictionary) -> void:
	"""Set crew data from saved campaign"""
	crew_members = data.get("crew_members", [])
	current_captain = data.get("captain", null)
	selected_size = data.get("crew_size", 4)
	
	crew_updated.emit(crew_members)

func get_crew_summary() -> Dictionary:
	"""Get crew summary for display"""
	var summary = {
		"total_members": crew_members.size(),
		"captain": _get_captain_summary(),
		"members": _get_crew_member_summaries(),
		"average_stats": {},
		"total_health": _calculate_total_health(),
		"background_distribution": _get_background_distribution(),
		"motivation_distribution": _get_motivation_distribution()
	}
	
	# Calculate average stats
	var stat_names = ["combat", "reaction", "toughness", "savvy", "tech", "speed"]
	for stat in stat_names:
		summary.average_stats[stat] = _calculate_average_stat(stat)
	
	return summary

func _get_captain_summary() -> Dictionary:
	"""Get captain summary"""
	if not current_captain:
		return {}
	
	return {
		"name": current_captain.character_name,
		"origin": GlobalEnums.Origin.keys()[current_captain.origin],
		"background": GlobalEnums.Background.keys()[current_captain.background],
		"class": GlobalEnums.CharacterClass.keys()[current_captain.character_class]
	}

func _get_crew_member_summaries() -> Array:
	"""Get all crew member summaries"""
	var summaries = []
	
	for member in crew_members:
		summaries.append({
			"name": member.character_name,
			"origin": GlobalEnums.Origin.keys()[member.origin],
			"background": GlobalEnums.Background.keys()[member.background],
			"class": GlobalEnums.CharacterClass.keys()[member.character_class],
			"health": member.health,
			"max_health": member.max_health
		})
	
	return summaries

func _calculate_average_stat(stat_name: String) -> float:
	"""Calculate average stat value across crew"""
	if crew_members.is_empty():
		return 0.0
	
	var total = 0.0
	for member in crew_members:
		match stat_name:
			"combat":
				total += member.combat
			"reaction":
				total += member.reaction
			"toughness":
				total += member.toughness
			"savvy":
				total += member.savvy
			"tech":
				total += member.tech
			"speed":
				total += member.speed
	
	return total / crew_members.size()

func _calculate_total_health() -> int:
	"""Calculate total crew health"""
	var total = 0
	for member in crew_members:
		total += member.health
	return total

func _get_background_distribution() -> Dictionary:
	"""Get distribution of backgrounds in crew"""
	var distribution = {}
	for member in crew_members:
		var bg_key = GlobalEnums.Background.keys()[member.background]
		distribution[bg_key] = distribution.get(bg_key, 0) + 1
	return distribution

func _get_motivation_distribution() -> Dictionary:
	"""Get distribution of motivations in crew"""
	var distribution = {}
	for member in crew_members:
		var mot_key = GlobalEnums.Motivation.keys()[member.motivation]
		distribution[mot_key] = distribution.get(mot_key, 0) + 1
	return distribution

func debug_crew_status():
	"""Debug function to print crew status"""
	print("=== CREW PANEL DEBUG ===")
	print("Crew size: ", crew_members.size())
	print("Selected size: ", selected_size)
	print("Captain: ", current_captain.character_name if current_captain else "None")
	print("Is initialized: ", is_initialized)
	
	for i in range(crew_members.size()):
		var member = crew_members[i]
		print("Member %d: %s (%s)" % [i, member.character_name, GlobalEnums.Origin.keys()[member.origin]])

## Safe utility methods (consolidated from duplicated versions)
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object:
		# Handle Resource objects properly - they don't have has() method
		if obj.has_method("get"):
			var value = obj.get(property)
			return value if value != null else default_value
		else:
			return default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null