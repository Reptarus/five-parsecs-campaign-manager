extends FiveParsecsCampaignPanel

## Five Parsecs Equipment Generation Panel
## Production-ready implementation with comprehensive equipment systems

const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const CharacterClass = preload("res://src/core/character/Character.gd")

# GlobalEnums available as autoload singleton

signal equipment_generated(equipment: Array[Dictionary])
@warning_ignore("unused_signal")
signal equipment_setup_complete(equipment_data: Dictionary)
# SPRINT ENHANCEMENT: Backend integration signal
signal equipment_requested(crew_data: Array)

# Autonomous signals for coordinator pattern
signal equipment_data_complete(data: Dictionary)
signal equipment_validation_failed(errors: Array[String])
# panel_validation_changed inherited from BaseCampaignPanel

# Granular signals for real-time integration
signal equipment_data_changed(data: Dictionary)
signal equipment_generation_complete(equipment: Array)

var local_equipment_data: Dictionary = {
	"equipment": [],
	"credits": 0,
	"is_complete": false
}

# UI Components with safe access
var equipment_list: VBoxContainer
var generate_button: Button
var reroll_button: Button
var manual_button: Button
var summary_label: Label
var credits_label: Label

# PHASE 1 INTEGRATION: EquipmentManager connection
var equipment_manager_instance: Control = null
var equipment_container: Control = null

var generated_equipment: Array[Dictionary] = []
var starting_credits: int = 0
var crew_size: int = 4
var dice_manager: Node # Add dice_manager reference

# Coordinator and state management references
var coordinator: Node = null  # Store coordinator reference properly
var state_manager: Node = null  # Store state manager reference

# Guard variable to prevent duplicate panel_completed emissions
var _completion_emitted: bool = false

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	print("EquipmentPanel: Campaign state updated with keys: %s" % str(state_data.keys()))
	
	# Update panel state based on campaign state if needed
	if state_data.has("equipment") and state_data.equipment is Dictionary:
		var equipment_state_data = state_data.equipment
		if equipment_state_data.has("credits"):
			# Update local equipment state from external changes
			starting_credits = equipment_state_data.credits
			_update_display()
	
	# CRITICAL FIX: Only generate once when crew data arrives
	if generated_equipment.is_empty():
		var crew_members = _extract_crew_members(state_data)
		if crew_members.size() > 0:
			print("EquipmentPanel: First crew data received - generating equipment for %d members" % crew_members.size())
			crew_size = crew_members.size()
			_generate_five_parsecs_equipment(crew_members)
			
			# Update the hardcoded "1000" label with actual credits
			if credits_label:
				credits_label.text = str(starting_credits)
			if summary_label:
				summary_label.text = "Equipment generated for %d crew members: %d items" % [crew_members.size(), generated_equipment.size()]
		else:
			print("EquipmentPanel: Waiting for crew data...")
	else:
		print("EquipmentPanel: Equipment already generated - skipping")
	
	# Also check for captain data
	if state_data.has("captain") and state_data.captain is Dictionary:
		var captain_data = state_data.captain
		print("EquipmentPanel: Captain data found: %s" % captain_data.get("name", "Unknown"))

func _extract_crew_members(state_data) -> Array:
	"""Extract crew members from various possible data structures - more defensive"""
	var crew_members = []
	
	# More defensive type checking
	if typeof(state_data) != TYPE_DICTIONARY:
		print("EquipmentPanel: State data is not Dictionary, type: %s" % typeof(state_data))
		return []
	
	# Try path 1: state_data.crew.members (Dictionary format)
	if state_data.has("crew"):
		var crew = state_data.get("crew")
		if typeof(crew) == TYPE_DICTIONARY and crew.has("members"):
			crew_members = crew.get("members", [])
			print("EquipmentPanel: Found crew at crew.members")
		elif typeof(crew) == TYPE_ARRAY:
			crew_members = crew
			print("EquipmentPanel: Found crew as array")
	
	# Try path 2: state_data.members (Direct array)
	if crew_members.is_empty() and state_data.has("members"):
		crew_members = state_data.get("members", [])
		print("EquipmentPanel: Found crew at root members")
	
	# Try path 3: state_data.crew_members
	if crew_members.is_empty() and state_data.has("crew_members"):
		crew_members = state_data.get("crew_members", [])
		print("EquipmentPanel: Found crew at crew_members")
	
	print("EquipmentPanel: Extracted %d crew members" % crew_members.size())
	return crew_members

## New Five Parsecs compliant equipment generation
func _generate_five_parsecs_equipment(crew_members: Array) -> void:
	"""Generate equipment according to Five Parsecs core rules"""
	print("EquipmentPanel: Generating Five Parsecs compliant equipment for %d crew members" % crew_members.size())
	generated_equipment.clear()
	
	# Core rules: Starting equipment
	# - 3 rolls on Military Weapon Table
	# - 3 rolls on Low-tech Weapon Table  
	# - 1 roll on Gear Table
	# - 1 roll on Gadget Table
	# - 1 credit per crew member
	
	var military_weapons = [
		"Military Rifle", "Infantry Laser", "Marksman's Rifle", "Needle Rifle",
		"Auto Rifle", "Rattle Gun", "Boarding Saber", "Shatter Axe"
	]
	
	var low_tech_weapons = [
		"Handgun", "Scrap Pistol", "Machine Pistol", "Colony Rifle",
		"Shotgun", "Hunting Rifle", "Blade", "Brutal Melee Weapon"
	]
	
	var gear_items = [
		"Assault Blade", "Beam Light", "Bipod", "Booster Pills", "Camo Cloak",
		"Combat Armor", "Communicator", "Concealed Blade", "Fake ID", "Fixer",
		"Frag Vest", "Grapple Launcher", "Hazard Suit", "Laser Sight",
		"Med-patch", "Nano-doc", "Scanner bot", "Steel Boots", "Tracker Sight"
	]
	
	var gadget_items = [
		"Analyzer", "Battle Visor", "Deflector Field", "Distraction Bot",
		"Grav Dampener", "Holo Sight", "Jump Belt", "Motion Tracker",
		"Neural Optimization", "Rage Serum", "Repair Bot", "Sonic Emitter"
	]
	
	# Generate 3 military weapons
	for i in range(3):
		var weapon = military_weapons[randi() % military_weapons.size()]
		generated_equipment.append({
			"name": weapon,
			"type": "Military Weapon",
			"owner": "Unassigned",
			"condition": "standard",
			"quality_modifier": 0
		})
		print("  Generated military weapon: %s" % weapon)
	
	# Generate 3 low-tech weapons
	for i in range(3):
		var weapon = low_tech_weapons[randi() % low_tech_weapons.size()]
		generated_equipment.append({
			"name": weapon,
			"type": "Low-tech Weapon",
			"owner": "Unassigned",
			"condition": "standard",
			"quality_modifier": 0
		})
		print("  Generated low-tech weapon: %s" % weapon)
	
	# Generate 1 gear item
	var gear = gear_items[randi() % gear_items.size()]
	generated_equipment.append({
		"name": gear,
		"type": "Gear",
		"owner": "Unassigned",
		"condition": "standard",
		"quality_modifier": 0
	})
	print("  Generated gear: %s" % gear)
	
	# Generate 1 gadget item
	var gadget = gadget_items[randi() % gadget_items.size()]
	generated_equipment.append({
		"name": gadget,
		"type": "Gadget",
		"owner": "Unassigned",
		"condition": "standard",
		"quality_modifier": 0
	})
	print("  Generated gadget: %s" % gadget)
	
	# Add character-specific equipment based on backgrounds
	for crew_member in crew_members:
		var member_name = ""
		var background = ""
		
		# CRITICAL FIX: Handle both Character objects and Dictionary data
		if crew_member is Character:
			# Direct Character object from Five Parsecs generation
			member_name = crew_member.character_name if crew_member.character_name else crew_member.name
			background = crew_member.background.to_lower() if crew_member.background else ""
			print("  Processing Character object: %s (background: %s)" % [member_name, background])
		elif crew_member is Dictionary:
			# Legacy Dictionary format
			member_name = crew_member.get("character_name", crew_member.get("name", "Unknown"))
			background = crew_member.get("background", "").to_lower()
			print("  Processing Dictionary: %s (background: %s)" % [member_name, background])
		else:
			print("  Warning: Unknown crew member type: %s" % type_string(typeof(crew_member)))
			continue
		
		# Military background gets extra military weapon
		if background == "military" or background == "soldier":
			var bonus_weapon = military_weapons[randi() % military_weapons.size()]
			generated_equipment.append({
				"name": bonus_weapon,
				"type": "Military Weapon",
				"owner": member_name,
				"condition": "standard",
				"quality_modifier": 0
			})
			print("  Bonus military weapon for %s: %s" % [member_name, bonus_weapon])
			
		# Tech/Engineer background gets extra gadget
		elif background == "tech" or background == "engineer" or background == "scientist":
			var bonus_gadget = gadget_items[randi() % gadget_items.size()]
			generated_equipment.append({
				"name": bonus_gadget,
				"type": "Gadget",
				"owner": member_name,
				"condition": "standard",
				"quality_modifier": 0
			})
			print("  Bonus gadget for %s: %s" % [member_name, bonus_gadget])
			
		# Explorer/Scout gets extra gear
		elif background == "explorer" or background == "scout":
			var bonus_gear = gear_items[randi() % gear_items.size()]
			generated_equipment.append({
				"name": bonus_gear,
				"type": "Gear",
				"owner": member_name,
				"condition": "standard",
				"quality_modifier": 0
			})
			print("  Bonus gear for %s: %s" % [member_name, bonus_gear])
	
	# Calculate starting credits: 1 credit per crew member (base)
	# Plus 1D6+1 x 100 credits total
	var dice_roll = (randi() % 6) + 1  # 1D6
	starting_credits = (dice_roll + 1) * 100 + crew_members.size()
	
	print("EquipmentPanel: Generated %d equipment items, %d credits total" % [generated_equipment.size(), starting_credits])
	
	# Update display and emit signals
	_update_equipment_display()
	_update_summary()
	equipment_generated.emit(generated_equipment)
	equipment_data_changed.emit(get_data())
	_validate_and_complete()

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("Equipment Assignment", "Distribute starting gear based on crew backgrounds. Military = combat gear, Tech = tools.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")
	
	# Initialize equipment-specific functionality
	call_deferred("_initialize_components")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup equipment-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func set_coordinator(coord: Node) -> void:
	"""Store coordinator reference properly for equipment panel"""
	coordinator = coord
	print("EquipmentPanel: Coordinator stored successfully")
	
	# TYPE-SAFE: Get state manager if available
	if coord and is_instance_valid(coord):
		if coord.has_method("get_state_manager"):
			var manager = coord.call("get_state_manager")
			if manager and is_instance_valid(manager):
				state_manager = manager
				print("EquipmentPanel: State manager reference stored")
	
	# TYPE-SAFE: Connect to coordinator signals if available
	if coord and is_instance_valid(coord):
		if coord.has_signal("campaign_state_updated"):
			if not coord.is_connected("campaign_state_updated", _on_campaign_state_updated):
				coord.connect("campaign_state_updated", _on_campaign_state_updated)
				print("EquipmentPanel: Connected to coordinator campaign_state_updated signal")

func _initialize_components() -> void:
	"""Initialize equipment panel by connecting to actual scene nodes"""
	print("========== EquipmentPanel: FINDING ACTUAL SCENE NODES ==========")
	
	# Use correct scene paths to find existing UI elements
	equipment_list = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/EquipmentList/Container")
	if not equipment_list:
		# Try unique name access (marked with unique_name_in_owner = true)
		equipment_list = get_node_or_null("%Container")
	print("EquipmentPanel: equipment_list: %s" % ("FOUND" if equipment_list else "NOT FOUND"))
	
	generate_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/GenerateButton")
	print("EquipmentPanel: generate_button: %s" % ("FOUND" if generate_button else "NOT FOUND"))
	
	reroll_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/RerollButton")
	print("EquipmentPanel: reroll_button: %s" % ("FOUND" if reroll_button else "NOT FOUND"))
	
	manual_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/ManualButton")
	print("EquipmentPanel: manual_button: %s" % ("FOUND" if manual_button else "NOT FOUND"))
	
	summary_label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Summary/Label")
	if not summary_label:
		# Try unique name access
		summary_label = get_node_or_null("%Label")
	print("EquipmentPanel: summary_label: %s" % ("FOUND" if summary_label else "NOT FOUND"))
	
	credits_label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Credits/Value")
	if not credits_label:
		# Try unique name access
		credits_label = get_node_or_null("%Value")
	print("EquipmentPanel: credits_label: %s" % ("FOUND" if credits_label else "NOT FOUND"))

	# Get DiceManager from autoload with safe access and fallback creation
	if has_node("/root/DiceManager"):
		dice_manager = get_node("/root/DiceManager")
		print("EquipmentPanel: DEBUG - DiceManager found")
	else:
		print("EquipmentPanel: DEBUG - DiceManager NOT FOUND - creating fallback")
		# Create fallback dice manager
		dice_manager = Node.new()
		dice_manager.name = "FallbackDiceManager"
		dice_manager.set_script(preload("res://src/core/systems/FallbackDiceManager.gd"))
		# Don't add to tree - use as local instance
		print("EquipmentPanel: Created fallback DiceManager for local use")
		push_warning("EquipmentPanel: Using fallback DiceManager - autoload not available")
	
	print("========== EquipmentPanel: COMPONENT INITIALIZATION COMPLETE ==========")

	# PHASE 1 INTEGRATION: Connect to existing EquipmentManager
	call_deferred("_connect_to_equipment_manager")

	_connect_signals()
	# CRITICAL FIX: Don't generate equipment before crew data arrives!
	# _generate_starting_equipment()  # REMOVED - was causing premature generation with mock crew
	
	# IMMEDIATE FIX: Display any equipment that was already generated
	call_deferred("_force_display_update")
	call_deferred("emit_panel_ready")

# PHASE 1 INTEGRATION: Connect to existing EquipmentManager
func _connect_to_equipment_manager() -> void:
	"""Skip EquipmentManager integration to prevent overlay issues"""
	print("EquipmentPanel: Using direct equipment management without EquipmentManager overlay")
	
	# Equipment management is handled directly in the panel
	# No external manager scene needed to prevent UI stacking
	
	# Use the existing UI elements from the scene
	var content_node = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content_node:
		content_node = get_node_or_null("Content")
	
	if content_node:
		print("EquipmentPanel: Content node found for equipment display")
		# The equipment list and controls are already in the scene
		# Just use them directly without adding external managers
	else:
		push_warning("EquipmentPanel: Content node not found for equipment display")

func _connect_equipment_manager_signals() -> void:
	"""Stub function - no EquipmentManager to connect"""
	print("EquipmentPanel: Equipment management handled directly in panel")

func _initialize_equipment_manager_data() -> void:
	"""Stub function - no EquipmentManager to initialize"""
	print("EquipmentPanel: Equipment data managed internally")
	
	# Use existing crew data if available from coordinator
	var crew_data = _get_current_crew_data()
	print("EquipmentPanel: Working with %d crew members for equipment generation" % crew_data.size())

func _get_current_crew_data() -> Array:
	"""Get current crew data from campaign state"""
	# Get actual crew data from coordinator using BaseCampaignPanel method
	var coordinator = get_coordinator()
	if coordinator and coordinator.has_method("get_state"):
		var state = coordinator.get_state()
		if state.has("crew") and state.crew.has("members"):
			print("EquipmentPanel: Found %d crew members from coordinator" % state.crew.members.size())
			return state.crew.members
	
	# This will be enhanced to get actual crew data from campaign coordinator
	var default_crew = [
		{"name": "Captain", "class": "Soldier", "equipment": []},
		{"name": "Crew Member 1", "class": "Scientist", "equipment": []},
		{"name": "Crew Member 2", "class": "Military", "equipment": []},
		{"name": "Crew Member 3", "class": "Engineer", "equipment": []}
	]
	return default_crew

func _get_current_equipment_data() -> Dictionary:
	"""Get current equipment data from local state"""
	return local_equipment_data

# EquipmentManager signal handlers
func _on_equipment_assigned(equipment_item: Dictionary, crew_member: Dictionary) -> void:
	"""Handle equipment assignment from EquipmentManager"""
	print("EquipmentPanel: Equipment assigned - %s to %s" % [equipment_item.get("name", "Unknown"), crew_member.get("name", "Unknown")])
	
	# Update local equipment data
	_update_equipment_data_from_manager()
	
	# Emit signal to coordinator
	equipment_data_changed.emit(local_equipment_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_equipment_update()

func _notify_coordinator_of_equipment_update() -> void:
	"""Notify coordinator of equipment updates using stored reference"""
	# Use stored coordinator instead of searching
	if coordinator and coordinator.has_method("update_equipment_state"):
		coordinator.update_equipment_state(local_equipment_data)
		print("EquipmentPanel: Notified coordinator of equipment update")
	elif coordinator:
		print("EquipmentPanel: Coordinator found but missing update_equipment_state method")
	else:
		print("EquipmentPanel: Warning - coordinator not available")

func _on_equipment_unassigned(equipment_item: Dictionary, crew_member: Dictionary) -> void:
	"""Handle equipment unassignment from EquipmentManager"""
	print("EquipmentPanel: Equipment unassigned - %s from %s" % [equipment_item.get("name", "Unknown"), crew_member.get("name", "Unknown")])
	
	# Update local equipment data
	_update_equipment_data_from_manager()
	
	# Emit signal to coordinator
	equipment_data_changed.emit(local_equipment_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_equipment_update()

func _update_equipment_data_from_manager() -> void:
	"""Update local equipment data from EquipmentManager"""
	if not equipment_manager_instance:
		return
	
	# Get equipment state from manager if available
	if equipment_manager_instance.has_method("get_equipment_state"):
		var manager_state = equipment_manager_instance.get_equipment_state()
		if manager_state:
			local_equipment_data = manager_state
			_update_display()
			print("EquipmentPanel: Updated equipment data from manager")

func _connect_signals() -> void:
	"""Connect to actual scene buttons with proper validation"""
	print("EquipmentPanel: Connecting to scene button signals...")
	
	# Verify we found all required UI elements
	var missing_elements = []
	if not equipment_list:
		missing_elements.append("equipment_list")
	if not generate_button:
		missing_elements.append("generate_button")
	if not reroll_button:
		missing_elements.append("reroll_button")
	if not manual_button:
		missing_elements.append("manual_button")
	if not summary_label:
		missing_elements.append("summary_label")
	if not credits_label:
		missing_elements.append("credits_label")
	
	if missing_elements.size() > 0:
		push_error("EquipmentPanel: Missing scene elements: %s" % str(missing_elements))
		return
	
	# Connect generate button
	if not generate_button.pressed.is_connected(_on_generate_pressed):
		generate_button.pressed.connect(_on_generate_pressed)
		print("EquipmentPanel: ✅ Connected Generate button from scene")
	else:
		print("EquipmentPanel: Generate button already connected")
		
	# Connect reroll button
	if not reroll_button.pressed.is_connected(_on_reroll_equipment_pressed):
		reroll_button.pressed.connect(_on_reroll_equipment_pressed)
		print("EquipmentPanel: ✅ Connected Reroll button from scene")
	else:
		print("EquipmentPanel: Reroll button already connected")
		
	# Connect manual button
	if not manual_button.pressed.is_connected(_on_manual_select_pressed):
		manual_button.pressed.connect(_on_manual_select_pressed)
		print("EquipmentPanel: ✅ Connected Manual button from scene")
	else:
		print("EquipmentPanel: Manual button already connected")

func set_crew_data(crew: Array[CharacterClass]) -> void:
	"""Set crew data and generate equipment"""
	# This is the intended entry point from the campaign wizard
	crew_size = crew.size()
	_generate_starting_equipment(crew)

# SPRINT ENHANCEMENT: Backend integration methods
func request_equipment_generation(crew_data: Array) -> void:
	"""Request equipment generation through backend systems"""
	print("EquipmentPanel: Requesting equipment generation for %d crew members via backend" % crew_data.size())
	equipment_requested.emit(crew_data)

func set_generated_equipment(equipment: Array, credits: int) -> void:
	"""Receive equipment generated by backend systems"""
	print("EquipmentPanel: Received %d equipment items, %d credits from backend" % [equipment.size(), credits])
	generated_equipment = equipment
	starting_credits = credits
	_update_equipment_display()
	_update_summary()
	equipment_generated.emit(generated_equipment)
	
	# Emit granular signal for real-time integration
	equipment_data_changed.emit(get_data())
	_validate_and_complete()

func _generate_equipment_for_actual_crew(crew_members: Array) -> void:
	"""Generate equipment for actual crew from campaign state (CRITICAL FIX)"""
	print("EquipmentPanel: Generating equipment for %d actual crew members" % crew_members.size())
	generated_equipment.clear()
	starting_credits = 0
	
	for crew_member in crew_members:
		if crew_member is Dictionary:
			# Convert dictionary crew member to Character object
			var character = Character.new()
			character.character_name = crew_member.get("character_name", "Unknown Crew")
			character.character_class = crew_member.get("character_class", "soldier").to_lower()
			character.background = crew_member.get("background", "military").to_lower()
			
			print("EquipmentPanel: Generating equipment for %s (%s, %s)" % [
				character.character_name, character.character_class, character.background
			])
			
			var char_equipment: Dictionary = StartingEquipmentGenerator.generate_starting_equipment(character, dice_manager)
			StartingEquipmentGenerator.apply_equipment_condition(char_equipment, dice_manager)
			
			# Merge equipment into a single list with proper attribution
			_merge_character_equipment(char_equipment, character.character_name)
			starting_credits += char_equipment.get("credits", 0)
		else:
			push_warning("EquipmentPanel: Invalid crew member data type: %s" % typeof(crew_member))
	
	print("EquipmentPanel: Generated %d equipment items, %d credits for actual crew" % [generated_equipment.size(), starting_credits])
	
	_update_equipment_display()
	_update_summary()
	equipment_generated.emit(generated_equipment)
	
	# Emit granular signal for real-time integration
	equipment_data_changed.emit(get_data())
	_validate_and_complete()

func _merge_character_equipment(char_equipment: Dictionary, owner_name: String) -> void:
	"""Merge character equipment into generated_equipment list"""
	# Add weapons
	for weapon in char_equipment.get("weapons", []):
		var weapon_item = _create_equipment_item(weapon, "Weapon", owner_name)
		generated_equipment.append(weapon_item)
	
	# Add armor
	for armor in char_equipment.get("armor", []):
		var armor_item = _create_equipment_item(armor, "Armor", owner_name)
		generated_equipment.append(armor_item)
	
	# Add gear
	for gear in char_equipment.get("gear", []):
		var gear_item = _create_equipment_item(gear, "Gear", owner_name)
		generated_equipment.append(gear_item)

func _create_equipment_item(item, item_type: String, owner_name: String) -> Dictionary:
	"""Create standardized equipment item dictionary"""
	var equipment_item: Dictionary = {}
	
	if item is String:
		# Simple string item
		equipment_item = {
			"name": item,
			"type": item_type,
			"owner": owner_name,
			"condition": "standard",
			"quality_modifier": 0
		}
	elif item is Dictionary:
		# Complex item with properties
		equipment_item = item.duplicate()
		equipment_item["type"] = item_type
		equipment_item["owner"] = owner_name
		if not equipment_item.has("condition"):
			equipment_item["condition"] = "standard"
		if not equipment_item.has("quality_modifier"):
			equipment_item["quality_modifier"] = 0
	
	return equipment_item

func _generate_starting_equipment(crew: Array[CharacterClass] = []) -> void:
	"""Generate starting equipment using StartingEquipmentGenerator (LEGACY FALLBACK)"""
	print("EquipmentPanel: Using legacy equipment generation (fallback)")
	generated_equipment.clear()
	starting_credits = 0

	var current_crew: Array[CharacterClass] = crew
	if current_crew.is_empty():
		# If no crew is passed, create a mock crew for demonstration
		current_crew = _create_mock_crew()

	# Generate equipment for each character
	for character: CharacterClass in current_crew:
		var char_equipment: Dictionary = StartingEquipmentGenerator.generate_starting_equipment(character, dice_manager)
		StartingEquipmentGenerator.apply_equipment_condition(char_equipment, dice_manager)
		
		# Merge equipment into a single list
		_merge_character_equipment(char_equipment, character.character_name)
		starting_credits += char_equipment.get("credits", 0)

	_update_equipment_display()
	_update_summary()
	equipment_generated.emit(generated_equipment)
	
	# Emit granular signal for real-time integration
	equipment_data_changed.emit(get_data())
	_validate_and_complete()

func _create_mock_crew() -> Array[CharacterClass]:
	"""Creates a mock crew for testing and demonstration purposes"""
	var mock_crew: Array[CharacterClass] = []
	var class_names: Array = GlobalEnums.CharacterClass.keys()
	var background_names: Array = GlobalEnums.Background.keys()
	
	for i in range(crew_size):
		var new_char: CharacterClass = CharacterClass.new()
		new_char.character_name = "Crew Member %d" % (i + 1)
		
		# Assign random class and background, skipping the 'NONE' enum at index 0
		var random_class_name: String = class_names[1 + randi() % (class_names.size() - 1)]
		new_char.character_class = random_class_name
		
		var random_bg_name: String = background_names[1 + randi() % (background_names.size() - 1)]
		new_char.background = random_bg_name
		
		mock_crew.append(new_char)
		
	return mock_crew

func _update_summary() -> void:
	"""Update equipment summary and credits display"""
	if summary_label:
		summary_label.text = "Equipment generated for %d crew members: %d items" % [crew_size, generated_equipment.size()]

	if credits_label:
		credits_label.text = str(starting_credits)

# Signal handlers
func _on_generate_pressed() -> void:
	"""Generate starting equipment and update navigation state"""
	print("========== EquipmentPanel: GENERATE BUTTON PRESSED ==========")
	print("EquipmentPanel: Coordinator available: %s" % (coordinator != null))
	
	# If equipment already generated and working, refresh display and validate
	if generated_equipment.size() > 0:
		print("EquipmentPanel: Equipment already generated (%d items), refreshing display..." % generated_equipment.size())
		_update_display()
		_validate_and_complete()  # CRITICAL FIX: Call validation instead of early return
		return
	
	# Clear existing equipment for regeneration
	generated_equipment.clear()
	starting_credits = 0
	
	# TYPE-SAFE: Try to get crew from coordinator
	var crew_members = []
	if coordinator and is_instance_valid(coordinator):
		print("EquipmentPanel: Coordinator is valid, checking for get_unified_campaign_state method")
		if coordinator.has_method("get_unified_campaign_state"):
			var state = coordinator.call("get_unified_campaign_state")
			print("EquipmentPanel: Got state from coordinator: %s" % (state != null))
			if state is Dictionary:
				print("EquipmentPanel: State received, extracting crew...")
				crew_members = _extract_crew_members(state)
		else:
			print("EquipmentPanel: Coordinator doesn't have get_unified_campaign_state method")
	else:
		print("EquipmentPanel: Coordinator is null or invalid")
	
	if crew_members.size() > 0:
		print("EquipmentPanel: Generating for %d crew members" % crew_members.size())
		_generate_five_parsecs_equipment(crew_members)
		
		# TYPE-SAFE: Notify coordinator to update navigation state (enable Next button)
		if coordinator and is_instance_valid(coordinator):
			if coordinator.has_method("update_navigation_state"):
				coordinator.call("update_navigation_state")
				print("EquipmentPanel: Notified coordinator to update navigation")
		
		# Also emit panel data change for real-time updates
		panel_data_changed.emit(get_data())
	else:
		push_warning("EquipmentPanel: No crew data available")
		if summary_label:
			summary_label.text = "⚠️ Please complete crew generation first"
		if credits_label:
			credits_label.text = "0"

func _on_reroll_equipment_pressed() -> void:
	print("========== EquipmentPanel: REROLL BUTTON PRESSED ==========")
	print("EquipmentPanel: Current equipment count: %d" % generated_equipment.size())
	_generate_starting_equipment()
	print("EquipmentPanel: After reroll - equipment count: %d" % generated_equipment.size())
	_validate_and_complete()  # CRITICAL FIX: Maintain validation state after reroll

func _on_manual_select_pressed() -> void:
	"""Show manual equipment selection dialog using EquipmentManager"""
	print("========== EquipmentPanel: MANUAL SELECTION BUTTON PRESSED ==========")
	
	# Load and show EquipmentManager as popup dialog
	var equipment_manager_scene = load("res://src/ui/screens/equipment/EquipmentManager.tscn")
	if not equipment_manager_scene:
		print("EquipmentPanel: Could not load EquipmentManager scene, falling back to default equipment")
		_generate_default_equipment()
		_validate_and_complete()
		return
	
	var equipment_manager = equipment_manager_scene.instantiate()
	var popup_dialog = _create_equipment_selection_popup(equipment_manager)
	
	# Set crew data for equipment assignment
	var crew_data = _get_crew_for_equipment_assignment()
	if crew_data.size() > 0:
		equipment_manager.set_crew_data(crew_data)
	
	# Connect signals for equipment assignment
	if not equipment_manager.equipment_assigned.is_connected(_on_manual_equipment_assigned):
		equipment_manager.equipment_assigned.connect(_on_manual_equipment_assigned)
	
	# Show popup
	get_tree().current_scene.add_child(popup_dialog)
	popup_dialog.popup_centered_ratio(0.9)
	print("EquipmentPanel: Manual equipment selection dialog opened")

func _generate_default_equipment() -> void:
	"""Generate default equipment for testing when no crew data is available"""
	print("EquipmentPanel: Generating default equipment for 4 crew members")
	
	generated_equipment.clear()
	
	# Generate default equipment following Five Parsecs rules
	# Default crew size of 4
	var default_crew_size = 4
	
	# Generate starting credits: (1D6+1) × 100
	var dice_roll = randi_range(1, 6)
	starting_credits = (dice_roll + 1) * 100 + default_crew_size
	print("EquipmentPanel: Starting credits: %d (rolled %d)" % [starting_credits, dice_roll])
	
	# Generate default weapons
	var military_weapons = ["Colony Rifle", "Auto Rifle", "Military Rifle"]
	var low_tech_weapons = ["Handgun", "Scrap Pistol", "Colony Rifle"]
	
	# Add 3 military weapons
	for i in range(3):
		generated_equipment.append({
			"name": military_weapons[i % military_weapons.size()],
			"type": "Weapon",
			"condition": "standard",
			"owner": "Crew Member %d" % (i + 1)
		})
	
	# Add 3 low-tech weapons
	for i in range(3):
		generated_equipment.append({
			"name": low_tech_weapons[i % low_tech_weapons.size()],
			"type": "Weapon",
			"condition": "worn",
			"owner": "Crew Member %d" % ((i % default_crew_size) + 1)
		})
	
	# Add basic gear
	generated_equipment.append({
		"name": "Med-Kit",
		"type": "Gear",
		"condition": "standard",
		"owner": "Ship Inventory"
	})
	
	generated_equipment.append({
		"name": "Repair Kit",
		"type": "Gear",
		"condition": "standard",
		"owner": "Ship Inventory"
	})
	
	print("EquipmentPanel: Generated %d equipment items" % generated_equipment.size())
	
	# Update display
	_update_equipment_display()
	_update_summary()
	
	# Mark as complete to enable Next button
	local_equipment_data.equipment = generated_equipment
	local_equipment_data.credits = starting_credits
	local_equipment_data.is_complete = true
	
	# Emit signals to update UI
	panel_data_changed.emit(get_data())
	equipment_data_changed.emit(get_data())
	
	# Notify coordinator
	if coordinator and is_instance_valid(coordinator):
		if coordinator.has_method("update_navigation_state"):
			coordinator.call("update_navigation_state")
			print("EquipmentPanel: Notified coordinator - Next button should be enabled")

# get_equipment_data() function moved to line 336

func is_setup_complete() -> bool:
	"""Check if equipment setup is complete"""
	return generated_equipment.size() > 0

func _update_equipment_display() -> void:
	"""Update the equipment list display with proper scene integration"""
	print("EquipmentPanel: Updating display with %d items" % generated_equipment.size())
	
	if not equipment_list:
		push_error("EquipmentPanel: No equipment_list container found!")
		return
	
	# Clear existing children
	for child in equipment_list.get_children():
		child.queue_free()
	
	# Wait one frame for old children to be removed
	await get_tree().process_frame
	
	# Add equipment items to the visible list
	for item: Dictionary in generated_equipment:
		var item_container: PanelContainer = PanelContainer.new()
		var item_hbox: HBoxContainer = HBoxContainer.new()
		
		var name_label: Label = Label.new()
		name_label.text = str(item.get("name", "Unknown Item"))
		name_label.custom_minimum_size.x = 200
		item_hbox.add_child(name_label)
		
		var type_label: Label = Label.new()
		type_label.text = str(item.get("type", "Misc"))
		type_label.custom_minimum_size.x = 100
		item_hbox.add_child(type_label)
		
		var condition_label: Label = Label.new()
		var condition: String = str(item.get("condition", "standard"))
		condition_label.text = "Condition: %s" % condition.capitalize()
		condition_label.custom_minimum_size.x = 150
		item_hbox.add_child(condition_label)
		
		var owner_label: Label = Label.new()
		owner_label.text = "For: %s" % str(item.get("owner", "Crew"))
		owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_hbox.add_child(owner_label)
		
		item_container.add_child(item_hbox)
		equipment_list.add_child(item_container)
	
	# Update summary and credits labels
	if summary_label:
		summary_label.text = "Equipment generated: %d items" % generated_equipment.size()
		summary_label.visible = true
		print("EquipmentPanel: Updated summary label")
	
	if credits_label:
		credits_label.text = str(starting_credits)
		credits_label.visible = true
		print("EquipmentPanel: Updated credits label to %d" % starting_credits)
	
	print("EquipmentPanel: ✅ Display updated with %d visible items" % generated_equipment.size())

func validate() -> Array[String]:
	"""Validate equipment data and return error messages"""
	return _validate_equipment_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("crew"):
		var crew: Array[CharacterClass] = data.get("crew", [])
		set_crew_data(crew)
	elif data.has("crew_size"):
		crew_size = data.crew_size
		_generate_starting_equipment()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Node, method_name: String, args: Array = []):
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

func _force_display_update() -> void:
	"""Force display update after scene is fully loaded"""
	await get_tree().process_frame
	
	# Display any equipment that was already generated
	if generated_equipment.size() > 0:
		print("EquipmentPanel: Forcing display update with %d existing items" % generated_equipment.size())
		_update_equipment_display()
		_update_summary()
		print("EquipmentPanel: ✅ Force display update completed")
	else:
		print("EquipmentPanel: No equipment to force-display yet")

# --- Additions to EquipmentPanel.gd ---

func _validate_and_complete() -> void:
	local_equipment_data.equipment = generated_equipment
	local_equipment_data.credits = starting_credits
	
	# ENHANCED VALIDATION: More lenient approach for campaign progression
	# Allow progression with basic equipment or credits
	var has_equipment = generated_equipment.size() > 0
	var has_credits = starting_credits > 0
	var is_valid = has_equipment or has_credits
	
	print("EquipmentPanel: Validation - Equipment: %d items, Credits: %d, Valid: %s" % [
		generated_equipment.size(), starting_credits, is_valid
	])
	
	# CRITICAL FIX: Emit panel_validation_changed signal to unblock navigation
	# Use parent class signal signature (boolean only)
	panel_validation_changed.emit(is_valid)
	print("EquipmentPanel: Emitted panel_validation_changed(valid=%s)" % is_valid)
	
	# Also emit our custom signal with error details
	if not is_valid:
		var validation_errors: Array[String] = []
		if not has_equipment and not has_credits:
			validation_errors.append("No equipment or credits generated")
		equipment_validation_failed.emit(validation_errors)
	
	if is_valid:
		local_equipment_data.is_complete = true
		print("EquipmentPanel: Panel validation passed - ready to advance")
		
		# Emit panel data update for signal-based architecture with proper data
		panel_data_changed.emit(get_data())
		
		# Emit granular data change signal for real-time integration
		equipment_data_changed.emit(get_data())

		# Emit completion signal if the panel is valid
		if not _completion_emitted:
			panel_completed.emit(get_data())
			equipment_data_complete.emit(get_data())
			equipment_generation_complete.emit(generated_equipment)
			_completion_emitted = true  # Prevent duplicate emissions
			print("EquipmentPanel: Panel completion signals emitted")
		
		# Notify coordinator for navigation update
		if coordinator and coordinator.has_method("update_navigation_state"):
			coordinator.update_navigation_state()
			print("EquipmentPanel: Coordinator navigation updated")
	else:
		local_equipment_data.is_complete = false
		print("EquipmentPanel: Panel validation failed - no equipment or credits")
		validation_failed.emit(["Generate equipment first before proceeding"])
		equipment_validation_failed.emit(["Generate equipment first before proceeding"])

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	var data = get_equipment_data()
	data["is_complete"] = local_equipment_data.is_complete
	return data

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	"""Validate panel data and return simple boolean result"""
	var errors = _validate_equipment_data()
	return errors.is_empty()

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation"""
	return get_equipment_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	generated_equipment.clear()
	starting_credits = 0
	crew_size = 4
	local_equipment_data = {
		"equipment": [],
		"credits": 0,
		"is_complete": false
	}
	
	_update_display()

func _validate_equipment_data() -> Array[String]:
	"""Validate equipment data and return array of error messages"""
	var errors: Array[String] = []
	
	# DEFENSIVE VALIDATION: Check for minimum equipment coverage
	if generated_equipment.size() == 0:
		errors.append("No equipment generated - crew needs basic gear")
		return errors
	
	# Validate each equipment item has required fields
	for item in generated_equipment:
		if not item is Dictionary:
			errors.append("Invalid equipment item format")
			continue
			
		if not item.has("name") or item.name.strip_edges().is_empty():
			errors.append("Equipment item missing valid name")
			continue
			
		if not item.has("owner") or item.owner.strip_edges().is_empty():
			errors.append("Equipment item missing owner assignment")
			continue
			
		if not item.has("type"):
			errors.append("Equipment item missing type classification")
			continue
	
	# Credits validation 
	if starting_credits < 0:
		errors.append("Starting credits cannot be negative")
	elif starting_credits < 500:
		# Warn if credits are suspiciously low
		push_warning("EquipmentPanel: Starting credits unusually low: %d" % starting_credits)
	
	# FIVE PARSECS RULE VALIDATION: Ensure crew has basic coverage
	var weapon_owners = []
	var armor_owners = []
	
	for item in generated_equipment:
		var owner = item.get("owner", "")
		var item_type = item.get("type", "")
		
		if item_type == "Weapon" and owner not in weapon_owners:
			weapon_owners.append(owner)
		elif item_type == "Armor" and owner not in armor_owners:
			armor_owners.append(owner)
	
	# At least half the crew should have weapons
	if weapon_owners.size() < (crew_size / 2):
		push_warning("EquipmentPanel: Low weapon coverage - only %d/%d crew armed" % [weapon_owners.size(), crew_size])
	
	return errors

func get_equipment_data() -> Dictionary:
	"""Get equipment data in standardized format"""
	return {
		"equipment": generated_equipment.duplicate(),
		"starting_credits": starting_credits,
		"crew_size": crew_size,
		"is_complete": local_equipment_data.is_complete,
		"metadata": {
			"last_modified": Time.get_unix_time_from_system(),
			"version": "1.0",
			"panel_type": "equipment_generation"
		}
	}

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("EquipmentPanel: No data to restore")
		return
	
	print("EquipmentPanel: Restoring panel data: ", data.keys())
	
	# Restore equipment data
	if data.has("equipment"):
		generated_equipment = data.equipment.duplicate() if data.equipment is Array else []
	
	# Restore credits
	if data.has("starting_credits"):
		starting_credits = data.starting_credits
	
	# Restore crew size
	if data.has("crew_size"):
		crew_size = data.crew_size
	
	# Restore completion status
	if data.has("is_complete"):
		local_equipment_data.is_complete = data.is_complete
	
	print("EquipmentPanel: Restored %d equipment items, %d credits" % [generated_equipment.size(), starting_credits])
	
	# Update UI with restored data
	_update_display()
	
	# Emit signal
	if not generated_equipment.is_empty():
		equipment_generated.emit(generated_equipment)
	
	print("EquipmentPanel: Panel data restoration complete")

func _update_display() -> void:
	"""Update all UI displays - used by both testing and production"""
	_update_equipment_display()
	_update_summary()

# --- End of additions ---

func cleanup_panel() -> void:
	"""Clean up panel state when navigating away"""
	print("EquipmentPanel: Cleaning up panel state")
	
	# Clear equipment manager instance
	if equipment_manager_instance:
		if equipment_manager_instance.has_method("cleanup"):
			equipment_manager_instance.cleanup()
		equipment_manager_instance.queue_free()
		equipment_manager_instance = null
	
	# Clear equipment container
	if equipment_container:
		equipment_container.queue_free()
		equipment_container = null
	
	# Reset local equipment data
	local_equipment_data = {
		"items": [],
		"credits": 0,
		"is_complete": false
	}
	
	# Clear generated equipment
	generated_equipment.clear()
	starting_credits = 0
	
	print("EquipmentPanel: Panel cleanup completed")

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: EquipmentPanel] INITIALIZATION ====")
	print("  Phase: 5 of 7 (Equipment Assignment)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# Check for coordinator access
	# Fixed: Check owner (CampaignCreationUI) instead of direct parent (content_container)
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	var has_coordinator = campaign_ui != null and campaign_ui.has_method("get_coordinator")
	print("  Has Coordinator Access: %s" % has_coordinator)
	if has_coordinator:
		var coordinator = campaign_ui.get_coordinator() if campaign_ui.has_method("get_coordinator") else null
		print("    Coordinator Available: %s" % (coordinator != null))
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var dice_manager_autoload = get_node_or_null("/root/DiceManager")

	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    DiceManager: %s" % (dice_manager_autoload != null))
	
	# Check current equipment data
	print("  === INITIAL EQUIPMENT DATA ===")
	print("    Local Equipment Data Keys: %s" % str(local_equipment_data.keys()))
	print("    Generated Equipment: %d items" % generated_equipment.size())
	print("    Starting Credits: %d" % starting_credits)
	print("    Crew Size: %d" % crew_size)
	print("    Is Complete: %s" % local_equipment_data.get("is_complete", false))
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Equipment List: %s" % (equipment_list != null))
	print("    Generate Button: %s" % (generate_button != null))
	print("    Reroll Button: %s" % (reroll_button != null))
	print("    Manual Button: %s" % (manual_button != null))
	print("    Equipment Manager Instance: %s" % (equipment_manager_instance != null))
	
	print("==== [PANEL: EquipmentPanel] INIT COMPLETE ====\n")

# ============ FALLBACK UI CREATION METHODS ============

func _create_generate_button() -> Button:
	"""Create generate equipment button"""
	var button = Button.new()
	button.name = "GenerateButton"
	button.text = "Generate Equipment"
	print("EquipmentPanel: Created generate button")
	return button

func _create_reroll_button() -> Button:
	"""Create reroll equipment button"""
	var button = Button.new()
	button.name = "RerollButton"
	button.text = "Reroll Equipment"
	print("EquipmentPanel: Created reroll button")
	return button

func _create_manual_button() -> Button:
	"""Create manual selection button"""
	var button = Button.new()
	button.name = "ManualButton"
	button.text = "Manual Selection"
	print("EquipmentPanel: Created manual button")
	return button

func _create_summary_label() -> Label:
	"""Create equipment summary label"""
	var label = Label.new()
	label.name = "Label"
	label.text = "Equipment Summary"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	print("EquipmentPanel: Created summary label")
	return label

func _create_credits_label() -> Label:
	"""Create credits display label"""
	var label = Label.new()
	label.name = "Value"
	label.text = "Credits: 0"
	print("EquipmentPanel: Created credits label")
	return label

## Missing Signal Handlers - Added to prevent parse errors

func _on_reroll_pressed() -> void:
	"""Handle reroll equipment button press"""
	print("EquipmentPanel: Reroll equipment pressed")
	_generate_starting_equipment()
	_validate_equipment_selection()

func _on_manual_pressed() -> void:
	"""Handle manual selection button press"""
	_on_manual_select_pressed()

# --- Manual Equipment Distribution Support ---

func _create_equipment_selection_popup(equipment_manager: Control) -> AcceptDialog:
	"""Create popup dialog containing EquipmentManager"""
	var popup = AcceptDialog.new()
	popup.title = "Manual Equipment Distribution"
	popup.set_flag(Window.FLAG_RESIZE_DISABLED, false)
	popup.size = Vector2(1000, 700)
	
	# Add equipment manager to popup
	popup.add_child(equipment_manager)
	equipment_manager.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Connect close button
	popup.confirmed.connect(_on_equipment_dialog_closed.bind(popup))
	popup.canceled.connect(_on_equipment_dialog_closed.bind(popup))
	
	return popup

func _get_crew_for_equipment_assignment() -> Array:
	"""Get crew data for equipment assignment"""
	print("EquipmentPanel: ===== CREW DATA RETRIEVAL DEBUG =====")
	print("EquipmentPanel: coordinator: %s" % str(coordinator))
	
	var crew_data = []
	
	# Try multiple methods to get crew data
	if coordinator:
		print("EquipmentPanel: Coordinator found, checking methods...")
		print("  has get_crew_data(): %s" % coordinator.has_method("get_crew_data"))
		print("  has get_crew_members(): %s" % coordinator.has_method("get_crew_members"))
		print("  has crew_data property: %s" % ("crew_data" in coordinator))
		
		# Try coordinator.get_crew_data() first
		if coordinator.has_method("get_crew_data"):
			crew_data = coordinator.get_crew_data()
			print("EquipmentPanel: get_crew_data() returned: %s (%d members)" % [typeof(crew_data), crew_data.size() if crew_data is Array else 0])
		
		# Try alternative methods if first failed
		if crew_data.is_empty() and coordinator.has_method("get_crew_members"):
			crew_data = coordinator.get_crew_members()
			print("EquipmentPanel: get_crew_members() returned: %s (%d members)" % [typeof(crew_data), crew_data.size() if crew_data is Array else 0])
		
		# Try accessing crew_data property directly
		if crew_data.is_empty() and "crew_data" in coordinator:
			crew_data = coordinator.crew_data
			print("EquipmentPanel: crew_data property: %s (%d members)" % [typeof(crew_data), crew_data.size() if crew_data is Array else 0])
		
		# Try getting from campaign state
		if crew_data.is_empty() and coordinator.has_method("get_campaign_state"):
			var state = coordinator.get_campaign_state()
			if state and state.has("crew") and state.crew.has("members"):
				crew_data = state.crew.members
				print("EquipmentPanel: From campaign state: %d members" % crew_data.size())
	else:
		print("EquipmentPanel: ❌ No coordinator available")
	
	# Enhanced fallback with debug info
	if crew_data.is_empty():
		print("EquipmentPanel: ⚠️ No crew data found, using fallback")
		crew_data = [
			{"character_name": "Captain", "background": "military", "equipment": []},
			{"character_name": "Engineer", "background": "engineer", "equipment": []},
			{"character_name": "Medic", "background": "medic", "equipment": []},
			{"character_name": "Scout", "background": "colonist", "equipment": []}
		]
		print("EquipmentPanel: Created fallback crew (%d members)" % crew_data.size())
	else:
		print("EquipmentPanel: ✅ Successfully retrieved crew data:")
		for i in range(min(crew_data.size(), 3)):  # Show first 3 members
			var member = crew_data[i]
			var name = member.get("character_name", member.get("name", "Unknown"))
			var background = member.get("background", member.get("class", "unknown"))
			print("  [%d] %s (%s)" % [i, name, background])
	
	print("EquipmentPanel: ===== END CREW DATA DEBUG =====")
	return crew_data

func _on_manual_equipment_assigned(equipment_item: Dictionary, crew_member: Dictionary) -> void:
	"""Handle equipment assignment from manual selection"""
	print("EquipmentPanel: Equipment assigned - %s to %s" % [
		equipment_item.get("name", "Unknown"), 
		crew_member.get("character_name", "Unknown")
	])
	
	# Add to generated equipment with owner information
	var assigned_equipment = equipment_item.duplicate()
	assigned_equipment["owner"] = crew_member.get("character_name", "Unknown")
	assigned_equipment["assigned_via"] = "manual_selection"
	
	# Check if this equipment is already in generated_equipment
	var found = false
	for i in range(generated_equipment.size()):
		if generated_equipment[i].get("name") == equipment_item.get("name"):
			generated_equipment[i] = assigned_equipment
			found = true
			break
	
	if not found:
		generated_equipment.append(assigned_equipment)
	
	# Update display and validate
	_update_display()
	_validate_and_complete()

func _on_equipment_dialog_closed(popup: AcceptDialog) -> void:
	"""Handle equipment selection dialog close"""
	print("EquipmentPanel: Equipment selection dialog closed")
	
	# Ensure we have some equipment to proceed
	if generated_equipment.size() == 0:
		print("EquipmentPanel: No equipment selected, generating default equipment")
		_generate_default_equipment()
	
	_validate_and_complete()
	popup.queue_free()
	print("EquipmentPanel: Manual selection pressed")
	# Switch to manual equipment selection mode
	var equipment_data = get_equipment_data()
	equipment_data["manual_mode"] = true
	# Removed redundant panel_completed.emit() - completion handled by _validate_and_complete()

func _validate_equipment_selection() -> void:
	"""Validate current equipment selection"""
	print("EquipmentPanel: Validating equipment selection")
	var equipment_data = get_equipment_data()
	var total_value = equipment_data.get("total_value", 0)
	var is_valid = total_value > 0
	
	if is_valid:
		print("EquipmentPanel: Equipment selection is valid (value: %d)" % total_value)
		# Removed redundant panel_completed.emit() - completion handled by _validate_and_complete()
	else:
		print("EquipmentPanel: Equipment selection needs review")
