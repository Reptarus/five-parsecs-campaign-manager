extends FiveParsecsCampaignPanel

## Five Parsecs Equipment Generation Panel
## Production-ready implementation with comprehensive equipment systems

# Progress tracking
const STEP_NUMBER := 4  # Step 4 of 7 in campaign wizard (Core Rules: Equipment before Ship)

const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const CharacterClass = preload("res://src/core/character/Character.gd")

# GlobalEnums available as autoload singleton

signal equipment_generated(equipment: Array[Dictionary])
@warning_ignore("unused_signal")
signal equipment_setup_complete(equipment_data: Dictionary)
# SPRINT ENHANCEMENT: Backend integration signal
# Sprint 26.3: Crew data contains Character objects
signal equipment_requested(crew_data: Array[Character])

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
var auto_assign_button: Button
var crew_loadout_container: VBoxContainer
var assigned_count_label: Label

# PHASE 1 INTEGRATION: EquipmentManager connection
var equipment_manager_instance: Control = null
var equipment_container: Control = null

var generated_equipment: Array[Dictionary] = []
var starting_credits: int = 0
var crew_size: int = 4
var dice_manager: Node # Add dice_manager reference

# PHASE 1: Crew and assignment tracking
var crew_members: Array = []  # Stores crew member data for assignment
var equipment_assignments: Dictionary = {}  # equipment_index -> character_name

# Equipment data loaded from JSON
var equipment_tables: Dictionary = {}

# Coordinator and state management references
var coordinator: Node = null  # Store coordinator reference properly
var state_manager: Node = null  # Store state manager reference

# Guard variable to prevent duplicate panel_completed emissions
var _completion_emitted: bool = false

# Track crew composition for change detection
var _last_crew_size: int = 0

func _handle_campaign_state_update(state_data: Dictionary) -> void:
	## Override from base class - handle campaign state updates
	# CRITICAL FIX: Ignore updates that originated from this panel to prevent double-loading
	var source = state_data.get("source", "")
	if source == "equipment_panel":
		print("EquipmentPanel: Ignoring update from self (source: equipment_panel)")
		return

	var phase = state_data.get("phase", "")
	if phase == "equipment_update":
		print("EquipmentPanel: Ignoring equipment_update phase (self-update)")
		return

	print("EquipmentPanel: Campaign state updated with keys: %s" % str(state_data.keys()))

	# Update panel state based on campaign state if needed
	if state_data.has("equipment") and state_data.equipment is Dictionary:
		var equipment_state_data = state_data.equipment
		if equipment_state_data.has("credits"):
			# Update local equipment state from external changes
			starting_credits = equipment_state_data.credits
			_update_display()

	# CROSS-PANEL COMMUNICATION: React to crew changes
	var extracted_crew = _extract_crew_members(state_data)
	if extracted_crew.size() > 0:
		var crew_changed = (extracted_crew.size() != _last_crew_size)
		
		# PHASE 1: Store crew members for assignment UI
		crew_members = extracted_crew
		print("EquipmentPanel: Stored %d crew members for assignment" % crew_members.size())

		if crew_changed or generated_equipment.is_empty():
			print("EquipmentPanel: Crew composition changed (%d -> %d) - regenerating equipment" % [_last_crew_size, extracted_crew.size()])
			_last_crew_size = extracted_crew.size()
			crew_size = extracted_crew.size()
			_generate_equipment_for_actual_crew(extracted_crew)

			# Update UI
			if credits_label:
				credits_label.text = str(starting_credits)
			if summary_label:
				summary_label.text = "Equipment generated for %d crew members: %d items" % [extracted_crew.size(), generated_equipment.size()]
		else:
			# Even if crew size hasn't changed, update the loadout display
			print("EquipmentPanel: No crew changes detected, updating loadout display")
			_update_crew_loadout_display()
	else:
		print("EquipmentPanel: Waiting for crew data...")

	# Check for captain data - only add if not already merged by coordinator
	if state_data.has("captain") and state_data.captain is Dictionary:
		var captain_data = state_data.captain
		var captain_name: String = ""
		if captain_data is Character:
			captain_name = captain_data.character_name if captain_data.character_name else captain_data.name
		else:
			captain_name = captain_data.get("character_name", captain_data.get("name", ""))
		# Check if captain already in crew (via _merge_captain_into_crew or name match)
		var captain_exists = false
		for member in crew_members:
			if member is Dictionary and member.get("is_captain", false):
				captain_exists = true
				break
			var member_name: String = ""
			if "character_name" in member:
				member_name = str(member.character_name)
			elif "name" in member:
				member_name = str(member.name)
			if not member_name.is_empty() and member_name == captain_name:
				captain_exists = true
				break
		if not captain_exists and not captain_name.is_empty():
			crew_members.insert(0, captain_data)
			print("EquipmentPanel: Added captain to crew members list")

func _extract_crew_members(state_data) -> Array:
	## Extract crew members from various possible data structures - more defensive
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
	## Generate equipment according to Five Parsecs core rules
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
	
	# Add character-specific equipment based on backgrounds using JSON data
	var background_equipment = equipment_tables.get("background_equipment", {})

	for crew_member in crew_members:
		var member_name = ""
		var background = ""

		# Handle both Character objects and Dictionary data
		member_name = crew_member.character_name if "character_name" in crew_member else (crew_member.name if "name" in crew_member else "Unknown")
		var bg_raw = crew_member.background if "background" in crew_member else 0
		if bg_raw is int:
			var bg_keys: Array = GlobalEnums.Background.keys()
			if bg_raw >= 0 and bg_raw < bg_keys.size():
				background = bg_keys[bg_raw].to_lower()
			else:
				background = ""
		elif bg_raw is String:
			background = bg_raw.to_lower() if bg_raw else ""
		else:
			background = ""
		print("  Processing crew member: %s (background: %s)" % [member_name, background])

		# Use JSON background equipment if available
		if background_equipment.has(background):
			var bg_equip = background_equipment[background]
			print("  Found background equipment for %s: %s" % [background, bg_equip.keys()])

			# Add weapons from background
			for weapon in bg_equip.get("weapons", []):
				generated_equipment.append({
					"name": weapon,
					"type": "Weapon",
					"owner": member_name,
					"condition": "standard",
					"quality_modifier": 0
				})
				print("  Background weapon for %s: %s" % [member_name, weapon])

			# Add gear from background
			for gear_item in bg_equip.get("gear", []):
				generated_equipment.append({
					"name": gear_item,
					"type": "Gear",
					"owner": member_name,
					"condition": "standard",
					"quality_modifier": 0
				})
				print("  Background gear for %s: %s" % [member_name, gear_item])

			# Add background credits to total
			starting_credits += bg_equip.get("credits", 0)
		else:
			# Fallback to hardcoded logic for unrecognized backgrounds
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

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display

	# Load equipment tables from JSON
	_load_equipment_tables()

	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")

	# Initialize equipment-specific functionality
	call_deferred("_initialize_components")

func _load_equipment_tables() -> void:
	## Load equipment data from equipment_tables.json
	var file_path = "res://data/character_creation_tables/equipment_tables.json"
	if not FileAccess.file_exists(file_path):
		push_warning("EquipmentPanel: equipment_tables.json not found at %s" % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("EquipmentPanel: Failed to open equipment_tables.json")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("EquipmentPanel: Failed to parse equipment_tables.json: %s" % json.get_error_message())
		return

	equipment_tables = json.get_data()
	print("EquipmentPanel: Loaded equipment tables with keys: %s" % str(equipment_tables.keys()))

# NOTE: _add_progress_indicator() removed - CampaignCreationUI handles progress display centrally

func _setup_panel_content() -> void:
	## Override from BaseCampaignPanel - setup equipment-specific content
	# This will be called after BaseCampaignPanel structure is ready
	pass

func set_coordinator(coord: Node) -> void:
	## Store coordinator reference properly for equipment panel
	# Set both local and base class coordinator references
	coordinator = coord
	_coordinator = coord  # BUGFIX: Also set base class variable so get_coordinator() works
	print("EquipmentPanel: Coordinator stored successfully")

	# TYPE-SAFE: Get state manager if available
	if coord and is_instance_valid(coord):
		if coord.has_method("get_state_manager"):
			var manager = coord.call("get_state_manager")
			if manager and is_instance_valid(manager):
				state_manager = manager
				_state_manager = manager  # Also set base class variable
				print("EquipmentPanel: State manager reference stored")

	# Defer _on_coordinator_set to ensure panel is ready
	call_deferred("_on_coordinator_set")

func _on_coordinator_set() -> void:
	## Called when coordinator is set - connect to campaign state updates
	print("EquipmentPanel: _on_coordinator_set called")

	if coordinator and is_instance_valid(coordinator):
		# Connect to campaign_state_updated signal for cross-panel communication
		if coordinator.has_signal("campaign_state_updated"):
			if not coordinator.campaign_state_updated.is_connected(_on_campaign_state_updated):
				coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
				print("EquipmentPanel: ✅ Connected to campaign_state_updated signal")
			else:
				print("EquipmentPanel: Already connected to campaign_state_updated signal")
		else:
			print("EquipmentPanel: ⚠️ Coordinator missing campaign_state_updated signal")

		# Also try to get current campaign state immediately
		if coordinator.has_method("get_unified_campaign_state"):
			var state = coordinator.get_unified_campaign_state()
			if state:
				print("EquipmentPanel: Fetching initial campaign state")
				_handle_campaign_state_update(state)
	else:
		print("EquipmentPanel: ⚠️ Coordinator not valid in _on_coordinator_set")

func _initialize_components() -> void:
	## Initialize equipment panel by connecting to actual scene nodes
	print("========== EquipmentPanel: FINDING ACTUAL SCENE NODES ==========")
	
	# Use unique name access (marked with unique_name_in_owner = true) with fallback paths
	equipment_list = get_node_or_null("%Container")
	if not equipment_list:
		equipment_list = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/MainSplit/EquipmentSection/EquipmentScroll/Container")
	print("EquipmentPanel: equipment_list: %s" % ("FOUND" if equipment_list else "NOT FOUND"))
	
	generate_button = get_node_or_null("%GenerateButton")
	if not generate_button:
		generate_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/GenerateButton")
	print("EquipmentPanel: generate_button: %s" % ("FOUND" if generate_button else "NOT FOUND"))
	
	reroll_button = get_node_or_null("%RerollButton")
	if not reroll_button:
		reroll_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/RerollButton")
	print("EquipmentPanel: reroll_button: %s" % ("FOUND" if reroll_button else "NOT FOUND"))
	
	manual_button = get_node_or_null("%ManualButton")
	if not manual_button:
		manual_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls/ManualButton")
	print("EquipmentPanel: manual_button: %s" % ("FOUND" if manual_button else "NOT FOUND"))
	
	summary_label = get_node_or_null("%Label")
	if not summary_label:
		summary_label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/SummarySection/Summary/Label")
	print("EquipmentPanel: summary_label: %s" % ("FOUND" if summary_label else "NOT FOUND"))

	credits_label = get_node_or_null("%Value")
	if not credits_label:
		credits_label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/SummarySection/Credits/Value")
	print("EquipmentPanel: credits_label: %s" % ("FOUND" if credits_label else "NOT FOUND"))
	
	# PHASE 1: New assignment UI components with fallback paths
	auto_assign_button = get_node_or_null("%AutoAssignButton")
	if not auto_assign_button:
		auto_assign_button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/MainSplit/EquipmentSection/EquipmentHeader/AutoAssignButton")
	print("EquipmentPanel: auto_assign_button: %s" % ("FOUND" if auto_assign_button else "NOT FOUND"))

	crew_loadout_container = get_node_or_null("%CrewLoadoutContainer")
	if not crew_loadout_container:
		crew_loadout_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/MainSplit/CrewSection/CrewScroll/CrewLoadoutContainer")
	print("EquipmentPanel: crew_loadout_container: %s" % ("FOUND" if crew_loadout_container else "NOT FOUND"))

	assigned_count_label = get_node_or_null("%AssignedCount")
	if not assigned_count_label:
		assigned_count_label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/SummarySection/Summary/AssignedCount")
	print("EquipmentPanel: assigned_count_label: %s" % ("FOUND" if assigned_count_label else "NOT FOUND"))

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
	## Skip EquipmentManager integration to prevent overlay issues
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
	## Stub function - no EquipmentManager to connect
	print("EquipmentPanel: Equipment management handled directly in panel")

func _initialize_equipment_manager_data() -> void:
	## Stub function - no EquipmentManager to initialize
	print("EquipmentPanel: Equipment data managed internally")
	
	# Use existing crew data if available from coordinator
	var crew_data = _get_current_crew_data()
	print("EquipmentPanel: Working with %d crew members for equipment generation" % crew_data.size())

func _get_current_crew_data() -> Array:
	## Get current crew data from campaign state
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
	## Get current equipment data from local state
	return local_equipment_data

# EquipmentManager signal handlers
func _on_equipment_assigned(equipment_item: Dictionary, crew_member: Dictionary) -> void:
	## Handle equipment assignment from EquipmentManager
	print("EquipmentPanel: Equipment assigned - %s to %s" % [equipment_item.get("name", "Unknown"), crew_member.get("name", "Unknown")])
	
	# Update local equipment data
	_update_equipment_data_from_manager()
	
	# Emit signal to coordinator
	equipment_data_changed.emit(local_equipment_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_equipment_update()

func _notify_coordinator_of_equipment_update() -> void:
	## Notify coordinator of equipment updates using stored reference
	# Use stored coordinator instead of searching
	if coordinator and coordinator.has_method("update_equipment_state"):
		coordinator.update_equipment_state(local_equipment_data)
		print("EquipmentPanel: Notified coordinator of equipment update")
	elif coordinator:
		print("EquipmentPanel: Coordinator found but missing update_equipment_state method")
	else:
		print("EquipmentPanel: Warning - coordinator not available")

func _on_equipment_unassigned(equipment_item: Dictionary, crew_member: Dictionary) -> void:
	## Handle equipment unassignment from EquipmentManager
	print("EquipmentPanel: Equipment unassigned - %s from %s" % [equipment_item.get("name", "Unknown"), crew_member.get("name", "Unknown")])
	
	# Update local equipment data
	_update_equipment_data_from_manager()
	
	# Emit signal to coordinator
	equipment_data_changed.emit(local_equipment_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_equipment_update()

func _update_equipment_data_from_manager() -> void:
	## Update local equipment data from EquipmentManager
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
	## Connect to actual scene buttons with proper validation
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
	
	# PHASE 1: Connect auto-assign button
	if auto_assign_button and not auto_assign_button.pressed.is_connected(_on_auto_assign_pressed):
		auto_assign_button.pressed.connect(_on_auto_assign_pressed)
		print("EquipmentPanel: ✅ Connected Auto-Assign button from scene")

func set_crew_data(crew: Array) -> void:
	## Set crew data and generate equipment
	# This is the intended entry point from the campaign wizard
	crew_size = crew.size()
	_generate_starting_equipment(crew)

# SPRINT ENHANCEMENT: Backend integration methods
func request_equipment_generation(crew_data: Array) -> void:
	## Request equipment generation through backend systems
	print("EquipmentPanel: Requesting equipment generation for %d crew members via backend" % crew_data.size())
	equipment_requested.emit(crew_data)

func set_generated_equipment(equipment: Array, credits: int) -> void:
	## Receive equipment generated by backend systems
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
	## Generate equipment for actual crew from campaign state (CRITICAL FIX)
	print("EquipmentPanel: Generating equipment for %d actual crew members" % crew_members.size())
	generated_equipment.clear()
	starting_credits = 0
	
	for crew_member in crew_members:
		# Handle Character, BaseCharacterResource, and Dictionary
		var character: Character = null
		if crew_member is Character:
			character = crew_member
		else:
			# Convert BaseCharacterResource or Dictionary to Character
			character = Character.new()
			if "character_name" in crew_member:
				character.character_name = str(crew_member.character_name)
			elif crew_member is Dictionary and crew_member.has("character_name"):
				character.character_name = str(crew_member["character_name"])
			else:
				character.character_name = "Unknown"
			# Convert int enum → string name for character_class
			var raw_class = crew_member.character_class if "character_class" in crew_member else 0
			if raw_class is int:
				var cls_keys: Array = GlobalEnums.CharacterClass.keys()
				if raw_class >= 0 and raw_class < cls_keys.size():
					character.character_class = cls_keys[raw_class].to_lower()
				else:
					character.character_class = "soldier"
			elif raw_class is String:
				character.character_class = raw_class.to_lower()
			# Convert int enum → string name for background
			var raw_bg = crew_member.background if "background" in crew_member else 0
			if raw_bg is int:
				var bg_keys: Array = GlobalEnums.Background.keys()
				if raw_bg >= 0 and raw_bg < bg_keys.size():
					character.background = bg_keys[raw_bg].to_lower()
				else:
					character.background = "military"
			elif raw_bg is String:
				character.background = raw_bg.to_lower()

		if not character:
			push_warning("EquipmentPanel: Invalid crew member data type: %s" % typeof(crew_member))
			continue

		print("EquipmentPanel: Generating equipment for %s (%s, %s)" % [
			character.character_name, character.character_class, character.background
		])

		var char_equipment: Dictionary = StartingEquipmentGenerator.generate_starting_equipment(character, dice_manager)
		StartingEquipmentGenerator.apply_equipment_condition(char_equipment, dice_manager)

		# Merge equipment into a single list with proper attribution
		_merge_character_equipment(char_equipment, character.character_name)
		starting_credits += char_equipment.get("credits", 0)
	
	print("EquipmentPanel: Generated %d equipment items, %d credits for actual crew" % [generated_equipment.size(), starting_credits])
	
	_update_equipment_display()
	_update_summary()
	equipment_generated.emit(generated_equipment)
	
	# Emit granular signal for real-time integration
	equipment_data_changed.emit(get_data())
	_validate_and_complete()

func _merge_character_equipment(char_equipment: Dictionary, owner_name: String) -> void:
	## Merge character equipment into generated_equipment list
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
	## Create standardized equipment item dictionary
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

func _generate_starting_equipment(crew: Array = []) -> void:
	## Generate starting equipment using StartingEquipmentGenerator (LEGACY FALLBACK)
	print("EquipmentPanel: Using legacy equipment generation (fallback)")
	generated_equipment.clear()
	starting_credits = 0

	var current_crew: Array = crew
	if current_crew.is_empty():
		# If no crew is passed, create a mock crew for demonstration
		current_crew = _create_mock_crew()

	# Generate equipment for each character
	for character in current_crew:
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
	## Creates a mock crew for testing and demonstration purposes
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
	## Update equipment summary and credits display
	if summary_label:
		summary_label.text = "Equipment generated for %d crew members: %d items" % [crew_size, generated_equipment.size()]

	if credits_label:
		credits_label.text = str(starting_credits)

# Signal handlers
func _on_generate_pressed() -> void:
	## Generate starting equipment and update navigation state
	print("========== EquipmentPanel: GENERATE BUTTON PRESSED ==========")
	print("EquipmentPanel: Coordinator available: %s" % (coordinator != null))
	print("EquipmentPanel: Class crew_members has %d members" % crew_members.size())

	# If equipment already generated and working, refresh display and validate
	if generated_equipment.size() > 0:
		print("EquipmentPanel: Equipment already generated (%d items), refreshing display..." % generated_equipment.size())
		_update_display()
		_validate_and_complete()  # CRITICAL FIX: Call validation instead of early return
		return

	# Clear existing equipment for regeneration
	generated_equipment.clear()
	starting_credits = 0

	# TYPE-SAFE: Try to get crew from coordinator first
	var local_crew_members: Array = []
	if coordinator and is_instance_valid(coordinator):
		print("EquipmentPanel: Coordinator is valid, checking for get_unified_campaign_state method")
		if coordinator.has_method("get_unified_campaign_state"):
			var state = coordinator.call("get_unified_campaign_state")
			print("EquipmentPanel: Got state from coordinator: %s" % (state != null))
			if state is Dictionary:
				print("EquipmentPanel: State received, extracting crew...")
				local_crew_members = _extract_crew_members(state)
		else:
			print("EquipmentPanel: Coordinator doesn't have get_unified_campaign_state method")
	else:
		print("EquipmentPanel: Coordinator is null or invalid")

	# CRITICAL FIX: Fall back to class variable if coordinator lookup failed
	if local_crew_members.is_empty() and crew_members.size() > 0:
		print("EquipmentPanel: Using class crew_members (%d members) as fallback" % crew_members.size())
		local_crew_members = crew_members

	if local_crew_members.size() > 0:
		print("EquipmentPanel: Generating for %d crew members" % local_crew_members.size())
		_generate_equipment_for_actual_crew(local_crew_members)

		# CRITICAL FIX: Persist equipment to EquipmentManager
		_persist_equipment_to_manager(local_crew_members)

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

func _persist_equipment_to_manager(crew_members: Array) -> void:
	## Persist generated equipment to EquipmentManager autoload for use in World/Battle phases
	print("========== EquipmentPanel: PERSISTING EQUIPMENT TO MANAGER ==========")

	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if not equipment_manager:
		push_error("EquipmentPanel: EquipmentManager autoload not found!")
		return

	var persisted_count: int = 0
	var failed_count: int = 0

	for equipment_item: Dictionary in generated_equipment:
		# Ensure equipment has a unique ID
		if not equipment_item.has("id") or equipment_item.id.is_empty():
			equipment_item["id"] = "equip_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

		var owner_name: String = equipment_item.get("owner", "Unassigned")

		# Add to ship stash if unassigned, or to character if assigned
		if owner_name == "Unassigned" or owner_name.is_empty():
			# Add to ship stash (for later assignment in World Phase)
			if equipment_manager.add_to_ship_stash(equipment_item):
				persisted_count += 1
				print("  → Added to ship stash: %s" % equipment_item.get("name", "Unknown"))
			else:
				failed_count += 1
				push_warning("  → Failed to add to stash: %s (stash may be full)" % equipment_item.get("name", "Unknown"))
		else:
			# Find character ID from crew_members
			var character_id = _get_character_id_from_name(crew_members, owner_name)

			if character_id.is_empty():
				# Character not found, add to stash as fallback
				if equipment_manager.add_to_ship_stash(equipment_item):
					persisted_count += 1
					print("  → Character '%s' not found, added to stash: %s" % [owner_name, equipment_item.get("name")])
				else:
					failed_count += 1
			else:
				# Add to equipment storage then assign to character
				if equipment_manager.add_equipment(equipment_item):
					if equipment_manager.assign_equipment_to_character(character_id, equipment_item.id):
						persisted_count += 1
						print("  → Assigned to %s (%s): %s" % [owner_name, character_id, equipment_item.get("name")])
					else:
						push_warning("  → Equipment added but assignment failed: %s" % equipment_item.get("name"))
						failed_count += 1
				else:
					failed_count += 1
					push_warning("  → Failed to add equipment: %s" % equipment_item.get("name"))

	print("Equipment persistence complete: %d succeeded, %d failed" % [persisted_count, failed_count])

func _get_character_id_from_name(crew_members: Array, character_name: String) -> String:
	## Get character ID from crew member name
	for member in crew_members:
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		var name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "")
		var id: String = member.character_id if "character_id" in member else ""

		if name == character_name:
			return id

	return ""

func _on_reroll_equipment_pressed() -> void:
	print("========== EquipmentPanel: REROLL BUTTON PRESSED ==========")
	print("EquipmentPanel: Current equipment count: %d" % generated_equipment.size())
	_generate_starting_equipment()
	print("EquipmentPanel: After reroll - equipment count: %d" % generated_equipment.size())
	_validate_and_complete()  # CRITICAL FIX: Maintain validation state after reroll

func _on_manual_select_pressed() -> void:
	## Show manual equipment selection dialog using EquipmentManager
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
	## Generate default equipment for testing when no crew data is available
	# Use class variable crew_size if set, otherwise fallback to 4
	var effective_crew_size = crew_size if crew_size > 0 else 4
	print("EquipmentPanel: Generating default equipment for %d crew members" % effective_crew_size)

	generated_equipment.clear()

	# Generate default equipment following Five Parsecs rules
	# Generate starting credits: (1D6+1) × 100
	var dice_roll = randi_range(1, 6)
	starting_credits = (dice_roll + 1) * 100 + effective_crew_size
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
			"owner": "Crew Member %d" % ((i % effective_crew_size) + 1)
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
	## Check if equipment setup is complete
	return generated_equipment.size() > 0

func _update_equipment_display() -> void:
	## Update the equipment list display with assignment dropdowns
	print("EquipmentPanel: Updating display with %d items" % generated_equipment.size())
	
	if not equipment_list:
		push_error("EquipmentPanel: No equipment_list container found!")
		return
	
	# Clear existing children
	for child in equipment_list.get_children():
		child.queue_free()

	# Wait one frame for old children to be removed (with null safety)
	if not is_inside_tree():
		return
	await get_tree().process_frame

	# Double-check we're still in tree after await
	if not is_inside_tree():
		return
	
	# Build crew options for dropdown
	var crew_options = _get_crew_assignment_options()
	
	# Add equipment items to the visible list with assignment dropdowns (GLASS MORPHISM)
	for i in range(generated_equipment.size()):
		var item: Dictionary = generated_equipment[i]
		var item_type: String = str(item.get("type", "Misc"))
		
		# GLASS MORPHISM: Create styled equipment card
		var item_container: PanelContainer = PanelContainer.new()
		item_container.add_theme_stylebox_override("panel", _create_glass_card_style(0.7))
		item_container.custom_minimum_size.y = TOUCH_TARGET_MIN
		
		var item_hbox: HBoxContainer = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", SPACING_SM)
		
		# SEMANTIC TYPE BADGE: Visual equipment type indicator
		var type_badge: PanelContainer = _create_equipment_type_badge(item_type)
		item_hbox.add_child(type_badge)
		
		# Equipment name
		var name_label: Label = Label.new()
		name_label.text = str(item.get("name", "Unknown Item"))
		name_label.custom_minimum_size.x = 180
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		item_hbox.add_child(name_label)
		
		# Condition indicator (smaller badge style)
		var condition: String = str(item.get("condition", "standard"))
		var condition_badge: PanelContainer = PanelContainer.new()
		condition_badge.custom_minimum_size = Vector2(80, 24)
		var cond_style := StyleBoxFlat.new()
		cond_style.bg_color = Color(_get_condition_color(condition), 0.2)
		cond_style.border_color = _get_condition_color(condition)
		cond_style.set_border_width_all(1)
		cond_style.set_corner_radius_all(4)
		cond_style.set_content_margin_all(SPACING_XS)
		condition_badge.add_theme_stylebox_override("panel", cond_style)
		
		var condition_label: Label = Label.new()
		condition_label.text = condition.capitalize()
		condition_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		condition_label.add_theme_color_override("font_color", _get_condition_color(condition))
		condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		condition_badge.add_child(condition_label)
		item_hbox.add_child(condition_badge)
		
		# PHASE 1: Assignment dropdown (styled)
		var assign_dropdown: OptionButton = OptionButton.new()
		assign_dropdown.custom_minimum_size.x = 150
		assign_dropdown.name = "AssignDropdown_%d" % i
		_style_option_button(assign_dropdown)
		
		# Add options
		assign_dropdown.add_item("Unassigned", 0)
		assign_dropdown.add_item("Ship Stash", 1)
		for j in range(crew_options.size()):
			assign_dropdown.add_item(crew_options[j], j + 2)
		
		# Set current selection based on item owner
		var current_owner: String = str(item.get("owner", "Unassigned"))
		var selected_index: int = _get_owner_dropdown_index(current_owner, crew_options)
		assign_dropdown.select(selected_index)
		
		# Connect signal with item index
		assign_dropdown.item_selected.connect(_on_equipment_assignment_changed.bind(i))
		
		item_hbox.add_child(assign_dropdown)
		
		item_container.add_child(item_hbox)
		equipment_list.add_child(item_container)
	
	# Update summary and credits labels
	_update_summary_labels()
	
	# Update crew loadout display
	_update_crew_loadout_display()
	
	print("EquipmentPanel: ✅ Display updated with %d visible items" % generated_equipment.size())

func _get_type_color(item_type: String) -> Color:
	## Get color for equipment type display using design system semantic colors
	match item_type.to_lower():
		"military weapon", "weapon":
			return COLOR_BLUE  # Blue for weapons (design system)
		"low-tech weapon":
			return COLOR_CYAN  # Cyan for low-tech weapons
		"gear":
			return COLOR_AMBER  # Amber for gear (design system)
		"gadget":
			return COLOR_PURPLE  # Purple for gadgets (design system)
		"armor":
			return COLOR_PURPLE  # Purple for armor (design system)
		_:
			return COLOR_TEXT_SECONDARY  # Gray for misc

func _create_equipment_type_badge(item_type: String) -> PanelContainer:
	## Create semantic type badge for equipment with icon and color coding
	var badge = PanelContainer.new()
	badge.custom_minimum_size = Vector2(32, 32)
	
	# Semantic color styling
	var type_color = _get_type_color(item_type)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(type_color.r, type_color.g, type_color.b, 0.2)
	badge_style.border_color = type_color
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	badge_style.set_content_margin_all(SPACING_XS)
	badge.add_theme_stylebox_override("panel", badge_style)
	
	# Icon label (simple text icon for now)
	var icon_label = Label.new()
	match item_type.to_lower():
		"military weapon", "weapon":
			icon_label.text = "⚔"  # Weapon icon
		"low-tech weapon":
			icon_label.text = "🔫"  # Gun icon
		"gear":
			icon_label.text = "⚙"  # Gear icon
		"gadget":
			icon_label.text = "🔧"  # Tool icon
		"armor":
			icon_label.text = "🛡"  # Shield icon
		_:
			icon_label.text = "📦"  # Box icon
	
	icon_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	icon_label.add_theme_color_override("font_color", type_color)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(icon_label)
	
	return badge

func _get_condition_color(condition: String) -> Color:
	## Get color for equipment condition display
	match condition.to_lower():
		"pristine", "excellent":
			return Color(0.4, 1.0, 0.4)  # Bright green
		"standard", "good":
			return Color(0.8, 0.8, 0.8)  # White/gray
		"worn":
			return Color(1.0, 0.8, 0.4)  # Yellow/orange
		"damaged", "poor":
			return Color(1.0, 0.4, 0.4)  # Red
		_:
			return Color(0.8, 0.8, 0.8)

func _get_crew_assignment_options() -> Array[String]:
	## Get list of crew member names for assignment dropdown
	var options: Array[String] = []

	for member in crew_members:
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		var name: String = member.character_name if "character_name" in member else (member.name if "name" in member else str(member))

		if not name.is_empty():
			options.append(name)

	return options

func _get_owner_dropdown_index(owner: String, crew_options: Array) -> int:
	## Get dropdown index for given owner name
	if owner == "Unassigned" or owner.is_empty():
		return 0
	if owner == "Ship Stash" or owner == "Ship Inventory":
		return 1
	
	# Search in crew options
	for i in range(crew_options.size()):
		if crew_options[i] == owner:
			return i + 2
	
	return 0  # Default to unassigned

func _on_equipment_assignment_changed(selected_index: int, equipment_index: int) -> void:
	## Handle equipment assignment dropdown change
	if equipment_index < 0 or equipment_index >= generated_equipment.size():
		push_error("EquipmentPanel: Invalid equipment index: %d" % equipment_index)
		return
	
	var crew_options = _get_crew_assignment_options()
	var new_owner: String = "Unassigned"
	
	match selected_index:
		0:
			new_owner = "Unassigned"
		1:
			new_owner = "Ship Stash"
		_:
			var crew_index = selected_index - 2
			if crew_index >= 0 and crew_index < crew_options.size():
				new_owner = crew_options[crew_index]
	
	# Update equipment data
	var old_owner: String = generated_equipment[equipment_index].get("owner", "Unassigned")
	generated_equipment[equipment_index]["owner"] = new_owner
	
	print("EquipmentPanel: Assigned '%s' from '%s' to '%s'" % [
		generated_equipment[equipment_index].get("name", "Unknown"),
		old_owner,
		new_owner
	])
	
	# Update displays
	_update_summary_labels()
	_update_crew_loadout_display()
	
	# Emit data change signal
	equipment_data_changed.emit(get_data())
	panel_data_changed.emit(get_data())
	
	# Validate and potentially complete
	_validate_and_complete()

func _update_summary_labels() -> void:
	## Update summary labels including assignment count
	if summary_label:
		summary_label.text = "Equipment generated: %d items" % generated_equipment.size()
		summary_label.visible = true
	
	if credits_label:
		credits_label.text = str(starting_credits)
		credits_label.visible = true
	
	# Update assigned count
	if assigned_count_label:
		var assigned_count: int = 0
		for item in generated_equipment:
			var owner: String = item.get("owner", "Unassigned")
			if owner != "Unassigned" and not owner.is_empty():
				assigned_count += 1
		
		assigned_count_label.text = "Assigned: %d / %d" % [assigned_count, generated_equipment.size()]
		
		# Color based on completion
		if assigned_count == generated_equipment.size():
			assigned_count_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
		elif assigned_count > 0:
			assigned_count_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		else:
			assigned_count_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)

func _update_crew_loadout_display() -> void:
	## Update the crew loadout display showing each character's equipment
	if not crew_loadout_container:
		return
	
	# Clear existing
	for child in crew_loadout_container.get_children():
		child.queue_free()
	
	# Build loadout per character
	var loadouts: Dictionary = {"Ship Stash": []}

	# Initialize loadouts for all crew members
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	for member in crew_members:
		var name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "")

		if not name.is_empty():
			loadouts[name] = []

	# Populate loadouts from equipment
	for item in generated_equipment:
		var owner: String = item.get("owner", "Unassigned")
		if owner != "Unassigned" and not owner.is_empty():
			if not loadouts.has(owner):
				loadouts[owner] = []
			loadouts[owner].append(item)

	# Create UI for each character
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	for member in crew_members:
		var name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "")
		var bg_val = member.background if "background" in member else 0
		var background: String = ""
		if bg_val is int:
			var bg_keys: Array = GlobalEnums.Background.keys()
			if bg_val >= 0 and bg_val < bg_keys.size():
				background = bg_keys[bg_val].capitalize()
		elif bg_val is String:
			background = bg_val

		if name.is_empty():
			continue

		var char_panel = _create_character_loadout_panel(name, background, loadouts.get(name, []))
		crew_loadout_container.add_child(char_panel)
	
	# Add ship stash section
	if loadouts.get("Ship Stash", []).size() > 0:
		var stash_panel = _create_character_loadout_panel("Ship Stash", "spare equipment", loadouts["Ship Stash"])
		crew_loadout_container.add_child(stash_panel)

func _create_character_loadout_panel(char_name: String, background: String, equipment: Array) -> PanelContainer:
	## Create a loadout display panel for a character (GLASS MORPHISM)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_glass_card_style(0.8))
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	
	# Header with character name and background
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_XS)
	
	var name_label = Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(name_label)
	
	if not background.is_empty():
		var bg_label = Label.new()
		bg_label.text = "(%s)" % background.capitalize()
		bg_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		bg_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		header.add_child(bg_label)
	
	vbox.add_child(header)
	
	# Separator
	var sep = HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)
	
	# Equipment list
	if equipment.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No equipment assigned"
		empty_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(empty_label)
	else:
		for item in equipment:
			var item_hbox = HBoxContainer.new()
			item_hbox.add_theme_constant_override("separation", SPACING_XS)
			
			# Equipment type badge
			var item_type: String = item.get("type", "")
			var type_badge = _create_equipment_type_badge(item_type)
			type_badge.custom_minimum_size = Vector2(24, 24)  # Smaller for list
			item_hbox.add_child(type_badge)
			
			# Equipment name
			var item_label = Label.new()
			var item_name: String = item.get("name", "Unknown")
			item_label.text = item_name
			item_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			item_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			item_hbox.add_child(item_label)
			
			vbox.add_child(item_hbox)
	
	panel.add_child(vbox)
	return panel

func _on_auto_assign_pressed() -> void:
	## Auto-assign equipment to crew based on backgrounds
	print("EquipmentPanel: Auto-assigning equipment to crew...")
	
	if crew_members.is_empty():
		push_warning("EquipmentPanel: No crew members available for auto-assign")
		return
	
	# Build preference map based on backgrounds
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	var preferences: Dictionary = {}
	for member in crew_members:
		var name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "")
		var bg_raw = member.background if "background" in member else 0
		var background: String = ""
		if bg_raw is int:
			var bg_keys: Array = GlobalEnums.Background.keys()
			if bg_raw >= 0 and bg_raw < bg_keys.size():
				background = bg_keys[bg_raw].to_lower()
		elif bg_raw is String:
			background = bg_raw.to_lower() if bg_raw else ""

		if not name.is_empty():
			preferences[name] = {
				"background": background,
				"assigned_count": 0,
				"prefers_weapons": background in ["military", "soldier", "bounty hunter", "mercenary"],
				"prefers_tech": background in ["tech", "engineer", "scientist", "hacker"],
				"prefers_gear": background in ["explorer", "scout", "colonist", "trader"]
			}
	
	# Track who has what to ensure fair distribution
	var assigned_weapons: Dictionary = {}
	var assigned_items: Dictionary = {}
	
	for name in preferences.keys():
		assigned_weapons[name] = 0
		assigned_items[name] = 0
	
	# First pass: Assign weapons (everyone needs at least one)
	for i in range(generated_equipment.size()):
		var item = generated_equipment[i]
		var item_type = item.get("type", "").to_lower()
		
		if "weapon" in item_type:
			# Find crew member who needs a weapon most
			var best_match: String = ""
			var best_score: int = -1
			
			for name in preferences.keys():
				if assigned_weapons[name] == 0:  # Prioritize those without weapons
					var score: int = 100
					if preferences[name]["prefers_weapons"]:
						score += 50
					if score > best_score:
						best_score = score
						best_match = name
			
			# If everyone has a weapon, give to weapon-preferring characters
			if best_match.is_empty():
				for name in preferences.keys():
					var score: int = assigned_weapons[name] * -10  # Fewer weapons = higher priority
					if preferences[name]["prefers_weapons"]:
						score += 20
					if score > best_score:
						best_score = score
						best_match = name
			
			if not best_match.is_empty():
				generated_equipment[i]["owner"] = best_match
				assigned_weapons[best_match] += 1
				assigned_items[best_match] += 1
	
	# Second pass: Assign gear and gadgets based on preferences
	for i in range(generated_equipment.size()):
		var item = generated_equipment[i]
		var item_type = item.get("type", "").to_lower()
		var current_owner = item.get("owner", "Unassigned")
		
		# Skip already assigned items
		if current_owner != "Unassigned" and not current_owner.is_empty():
			continue
		
		var best_match: String = ""
		var best_score: int = -1
		
		for name in preferences.keys():
			var score: int = 10 - assigned_items[name]  # Favor balanced distribution
			
			# Apply preference bonuses
			if "gadget" in item_type and preferences[name]["prefers_tech"]:
				score += 15
			elif "gear" in item_type and preferences[name]["prefers_gear"]:
				score += 15
			elif "armor" in item_type:
				score += 5  # Everyone can use armor
			
			if score > best_score:
				best_score = score
				best_match = name
		
		if not best_match.is_empty():
			generated_equipment[i]["owner"] = best_match
			assigned_items[best_match] += 1
		else:
			# Put in ship stash if no good match
			generated_equipment[i]["owner"] = "Ship Stash"
	
	print("EquipmentPanel: Auto-assignment complete")
	
	# Update display
	_update_equipment_display()
	_validate_and_complete()

func validate() -> Array[String]:
	## Validate equipment data and return error messages
	return _validate_equipment_data()

func set_data(data: Dictionary) -> void:
	## Set panel data - generic interface method
	if data.has("crew"):
		var crew: Array[CharacterClass] = data.get("crew", [])
		set_crew_data(crew)
	elif data.has("crew_size"):
		crew_size = data.crew_size
		_generate_starting_equipment()


func _force_display_update() -> void:
	## Force display update after scene is fully loaded
	if not is_inside_tree():
		return
	await get_tree().process_frame

	# Safety check after await
	if not is_inside_tree():
		return

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
	## DEPRECATED: Use get_panel_data() instead. Will be removed in future version.
	push_warning("EquipmentPanel.get_data() is deprecated - use get_panel_data() instead")
	return get_panel_data()

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	## Validate panel data and return simple boolean result
	var errors = _validate_equipment_data()
	return errors.is_empty()

func get_panel_data() -> Dictionary:
	## Get panel data - interface implementation
	return get_equipment_data()

func set_panel_data(data: Dictionary) -> void:
	## Set panel data - interface implementation. Delegates to restore_panel_data.
	restore_panel_data(data)

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	## Handle campaign state updates - interface implementation for cross-panel communication.
	_handle_campaign_state_update(state_data)

func reset_panel() -> void:
	## Reset panel to default state
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
	## Validate equipment data and return array of error messages
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
	## DEPRECATED: Use get_panel_data() instead. Will be removed in future version.
	push_warning("EquipmentPanel.get_equipment_data() is deprecated - use get_panel_data() instead")
	return {
		"equipment": generated_equipment.duplicate(),
		"credits": starting_credits,
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
	## Restore panel data from persistence system
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
	## Update all UI displays - used by both testing and production
	_update_equipment_display()
	_update_summary()

# --- End of additions ---

func cleanup_panel() -> void:
	## Clean up panel state when navigating away
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
	
	# Reset local equipment data (Sprint 26.7: Standardized to equipment key)
	local_equipment_data = {
		"equipment": [],
		"credits": 0,
		"is_complete": false
	}
	
	# Clear generated equipment
	generated_equipment.clear()
	starting_credits = 0
	
	print("EquipmentPanel: Panel cleanup completed")

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	## Comprehensive debug output for panel initialization
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
	## Create generate equipment button
	var button = Button.new()
	button.name = "GenerateButton"
	button.text = "Generate Equipment"
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	print("EquipmentPanel: Created generate button")
	return button

func _create_reroll_button() -> Button:
	## Create reroll equipment button
	var button = Button.new()
	button.name = "RerollButton"
	button.text = "Reroll Equipment"
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	print("EquipmentPanel: Created reroll button")
	return button

func _create_manual_button() -> Button:
	## Create manual selection button
	var button = Button.new()
	button.name = "ManualButton"
	button.text = "Manual Selection"
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	print("EquipmentPanel: Created manual button")
	return button

func _create_summary_label() -> Label:
	## Create equipment summary label
	var label = Label.new()
	label.name = "Label"
	label.text = "Equipment Summary"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	print("EquipmentPanel: Created summary label")
	return label

func _create_credits_label() -> Label:
	## Create credits display label
	var label = Label.new()
	label.name = "Value"
	label.text = "Credits: 0"
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	print("EquipmentPanel: Created credits label")
	return label

## Missing Signal Handlers - Added to prevent parse errors

func _on_reroll_pressed() -> void:
	## Handle reroll equipment button press
	print("EquipmentPanel: Reroll equipment pressed")
	_generate_starting_equipment()
	_validate_equipment_selection()

func _on_manual_pressed() -> void:
	## Handle manual selection button press
	_on_manual_select_pressed()

# --- Manual Equipment Distribution Support ---

func _create_equipment_selection_popup(equipment_manager: Control) -> AcceptDialog:
	## Create popup dialog containing EquipmentManager
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
	## Get crew data for equipment assignment
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
	## Handle equipment assignment from manual selection
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
	## Handle equipment selection dialog close
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
	## Validate current equipment selection
	print("EquipmentPanel: Validating equipment selection")
	var equipment_data = get_equipment_data()
	var total_value = equipment_data.get("total_value", 0)
	var is_valid = total_value > 0

	if is_valid:
		print("EquipmentPanel: Equipment selection is valid (value: %d)" % total_value)
		# Removed redundant panel_completed.emit() - completion handled by _validate_and_complete()
	else:
		print("EquipmentPanel: Equipment selection needs review")

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	## Mobile: Single column, 56dp targets, compact equipment list
	super._apply_mobile_layout()

	# Get main split container and convert to vertical layout for mobile
	var main_split := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/MainSplit")
	if main_split and main_split is HSplitContainer:
		main_split.vertical = true  # Stack equipment and crew sections vertically

	# Increase touch targets for mobile
	var controls := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls")
	if controls:
		for child in controls.get_children():
			if child is Button:
				child.custom_minimum_size.y = TOUCH_TARGET_COMFORT  # 56dp

	# Make summary section vertical for mobile
	var summary_section := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/SummarySection")
	if summary_section and summary_section is HBoxContainer:
		# Cannot change container type at runtime, but we can adjust alignment
		summary_section.alignment = BoxContainer.ALIGNMENT_CENTER

	# Adjust auto-assign button for mobile
	var auto_assign := get_node_or_null("%AutoAssignButton")
	if auto_assign:
		auto_assign.custom_minimum_size = Vector2(100, TOUCH_TARGET_COMFORT)

func _apply_tablet_layout() -> void:
	## Tablet: Two columns, 48dp targets, detailed equipment list
	super._apply_tablet_layout()

	# Restore horizontal split for tablet
	var main_split := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/MainSplit")
	if main_split and main_split is HSplitContainer:
		main_split.vertical = false  # Side-by-side layout

	# Standard touch targets for tablet
	var controls := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls")
	if controls:
		for child in controls.get_children():
			if child is Button:
				child.custom_minimum_size.y = TOUCH_TARGET_MIN  # 48dp

	# Restore horizontal summary
	var summary_section := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/SummarySection")
	if summary_section and summary_section is HBoxContainer:
		summary_section.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Standard auto-assign button
	var auto_assign := get_node_or_null("%AutoAssignButton")
	if auto_assign:
		auto_assign.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)

func _apply_desktop_layout() -> void:
	## Desktop: Multi-column, 48dp targets, full equipment details
	super._apply_desktop_layout()

	# Full horizontal layout for desktop
	var main_split := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/MainSplit")
	if main_split and main_split is HSplitContainer:
		main_split.vertical = false  # Side-by-side layout

	# Standard touch targets for desktop (mouse precision)
	var controls := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Controls")
	if controls:
		for child in controls.get_children():
			if child is Button:
				child.custom_minimum_size.y = TOUCH_TARGET_MIN  # 48dp

	# Full horizontal summary
	var summary_section := get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/SummarySection")
	if summary_section and summary_section is HBoxContainer:
		summary_section.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Standard auto-assign button with more width for desktop
	var auto_assign := get_node_or_null("%AutoAssignButton")
	if auto_assign:
		auto_assign.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
