extends Control
class_name CrewTaskComponent

## Crew Task Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs crew task rules only
## Implements Core Rules pp.76-82 - Crew task assignment and resolution

const RulesHelpText = preload("res://src/data/rules_help_text.gd")

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const DiceManager = preload("res://src/core/managers/DiceManager.gd")

# Design system constants
const TOUCH_TARGET_MIN := 48  # Minimum touch target height for mobile (Sprint 26.4)

# UI Components
@onready var crew_task_container: VBoxContainer = %CrewTaskContainer
@onready var crew_member_list: ItemList = %CrewMemberList
@onready var available_tasks_list: ItemList = %AvailableTasksList
@onready var assign_task_button: Button = %AssignTaskButton
@onready var resolve_all_button: Button = %ResolveAllButton
@onready var progress_container: VBoxContainer = %ProgressContainer
@onready var help_button: Button = %HelpButton

# Help dialog reference
var _help_dialog: AcceptDialog = null

# Crew task state
var crew_data: Array = []
var assigned_tasks: Dictionary = {} # crew_member_id -> task_data
var completed_tasks: Array = []
var all_tasks_resolved: bool = false

# Five Parsecs crew tasks (Core Rules pp.76-82)
# Task mechanics: dice_target is base roll needed on D6
# max_crew: maximum crew assignable, credit_bonus: max credits for +1 each
var available_crew_tasks: Array[Dictionary] = [
	{
		"id": "find_patron",
		"name": "Find a Patron",
		"description": "Search for someone willing to offer paid work",
		"dice_target": 5,
		"max_crew": 2,
		"credit_bonus": 3,
		"success_reward": "Add 1 Patron",
		"failure_penalty": "None",
		"resolution_type": "dice_roll"
	},
	{
		"id": "train",
		"name": "Train",
		"description": "Practice combat skills or study",
		"dice_target": 0,  # Auto-success
		"max_crew": 2,
		"credit_bonus": 0,
		"success_reward": "+1 XP",
		"failure_penalty": "None",
		"resolution_type": "automatic"
	},
	{
		"id": "trade",
		"name": "Trade",
		"description": "Buy and sell goods in local markets",
		"dice_target": 0,  # Roll on Trade Table
		"max_crew": 1,
		"credit_bonus": 0,
		"success_reward": "Roll on Trade Table",
		"failure_penalty": "None",
		"resolution_type": "table_roll"
	},
	{
		"id": "recruit",
		"name": "Recruit",
		"description": "Search for new crew members to hire",
		"dice_target": 6,
		"max_crew": 2,
		"credit_bonus": 3,
		"success_reward": "New recruit available",
		"failure_penalty": "None",
		"resolution_type": "dice_roll"
	},
	{
		"id": "explore",
		"name": "Explore",
		"description": "Search the area for opportunities",
		"dice_target": 0,  # Roll on Exploration Table
		"max_crew": 2,
		"credit_bonus": 0,
		"success_reward": "Roll on Exploration Table",
		"failure_penalty": "Possible danger",
		"resolution_type": "table_roll"
	},
	{
		"id": "track",
		"name": "Track",
		"description": "Gather intel on rivals or enemies",
		"dice_target": 5,
		"max_crew": 2,
		"credit_bonus": 2,
		"success_reward": "Intel on target",
		"failure_penalty": "Target alerted",
		"resolution_type": "dice_roll"
	},
	{
		"id": "repair_kit",
		"name": "Repair Your Kit",
		"description": "Fix damaged weapons or equipment",
		"dice_target": 0,  # Requires Repair Bot or 1 credit per item
		"max_crew": 1,
		"credit_bonus": 0,
		"success_reward": "Item repaired",
		"failure_penalty": "None",
		"resolution_type": "repair"
	},
	{
		"id": "decoy",
		"name": "Decoy",
		"description": "Draw attention away from the crew",
		"dice_target": 0,  # Auto-success, but crew unavailable for battle
		"max_crew": 1,
		"credit_bonus": 0,
		"success_reward": "-1 to enemy deployment roll",
		"failure_penalty": "Unavailable for battle",
		"resolution_type": "automatic"
	}
]

# Track crew per task for multi-assignment
var task_assignments: Dictionary = {}  # task_id -> Array of crew_ids
var credits_spent_on_tasks: Dictionary = {}  # task_id -> credits spent

func _ready() -> void:
	name = "CrewTaskComponent"
	print("CrewTaskComponent: Initialized - handling Five Parsecs crew task rules")
	
	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	# Find or create event bus
	event_bus = get_node("/root/CampaignTurnEventBus")
	if not event_bus:
		# Create if doesn't exist
		event_bus = CampaignTurnEventBus.new()
		get_tree().root.add_child(event_bus)
		event_bus.name = "CampaignTurnEventBus"
	
	# Subscribe to relevant events
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)
	
	print("CrewTaskComponent: Connected to event bus")

func _exit_tree() -> void:
	"""Cleanup event bus subscriptions to prevent memory leaks"""
	if event_bus:
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

func _connect_ui_signals() -> void:
	"""Connect UI signals"""
	if assign_task_button:
		assign_task_button.pressed.connect(_on_assign_task_pressed)
	if resolve_all_button:
		resolve_all_button.pressed.connect(_on_resolve_all_pressed)
	if crew_member_list:
		crew_member_list.item_selected.connect(_on_crew_member_selected)
		# Sprint 26.4: Ensure 48px minimum touch target for mobile
		crew_member_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if available_tasks_list:
		available_tasks_list.item_selected.connect(_on_task_selected)
		# Sprint 26.4: Ensure 48px minimum touch target for mobile
		available_tasks_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)

func _on_help_button_pressed() -> void:
	"""Show crew tasks help dialog"""
	_show_help_dialog("Crew Tasks", RulesHelpText.get_tooltip("crew_tasks"))

func _show_help_dialog(title: String, content: String) -> void:
	"""Show a help dialog with rules text"""
	if not _help_dialog:
		_help_dialog = AcceptDialog.new()
		_help_dialog.dialog_hide_on_ok = true
		add_child(_help_dialog)
	
	_help_dialog.title = title
	
	var existing_content := _help_dialog.get_node_or_null("HelpContent")
	if existing_content:
		existing_content.queue_free()
	
	var rich_text := RichTextLabel.new()
	rich_text.name = "HelpContent"
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.custom_minimum_size = Vector2(400, 250)
	rich_text.text = content
	rich_text.add_theme_color_override("default_color", Color("#f3f4f6"))
	_help_dialog.add_child(rich_text)
	
	_help_dialog.popup_centered()

func _setup_initial_state() -> void:
	"""Initialize component state"""
	assigned_tasks.clear()
	completed_tasks.clear()
	all_tasks_resolved = false
	_populate_available_tasks()

## Public API: Initialize crew tasks phase
func initialize_crew_tasks(crew: Array) -> void:
	"""Initialize crew tasks phase with current crew data"""
	crew_data = crew.duplicate()
	assigned_tasks.clear()
	completed_tasks.clear()
	all_tasks_resolved = false
	
	print("CrewTaskComponent: Initialized with %d crew members" % crew_data.size())
	
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()
	
	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_STARTED, {
			"crew_size": crew_data.size()
		})

func _populate_crew_list() -> void:
	"""Populate crew member list UI - excludes Sick Bay crew"""
	if not crew_member_list:
		return

	crew_member_list.clear()
	for i in range(crew_data.size()):
		var crew_member = crew_data[i]
		var crew_name = crew_member.get("character_name", "Crew Member %d" % (i + 1))

		# Check if in Sick Bay (Core Rules - injured crew can't perform tasks)
		var is_in_sick_bay = crew_member.get("in_sick_bay", false) or crew_member.get("status", "") == "injured"
		if is_in_sick_bay:
			crew_member_list.add_item("%s [SICK BAY]" % crew_name)
			crew_member_list.set_item_disabled(crew_member_list.item_count - 1, true)
			continue

		var task_status = ""
		var crew_id = crew_member.get("character_id", "crew_%d" % i)

		if crew_id in assigned_tasks:
			var assigned_task = assigned_tasks[crew_id]
			task_status = " [%s]" % assigned_task.task.name.to_upper()

		crew_member_list.add_item(crew_name + task_status)

func _get_eligible_crew() -> Array:
	"""Get crew members not in Sick Bay"""
	var eligible: Array = []
	for crew_member in crew_data:
		var is_in_sick_bay = crew_member.get("in_sick_bay", false) or crew_member.get("status", "") == "injured"
		if not is_in_sick_bay:
			eligible.append(crew_member)
	return eligible

func _populate_available_tasks() -> void:
	"""Populate available tasks list UI with Core Rules info"""
	if not available_tasks_list:
		return

	available_tasks_list.clear()
	for task in available_crew_tasks:
		var task_text = task.name
		var task_id = task.get("id", "")

		# Show resolution type
		match task.resolution_type:
			"dice_roll":
				task_text += " (%d+)" % task.dice_target
			"automatic":
				task_text += " (Auto)"
			"table_roll":
				task_text += " (Table)"
			"repair":
				task_text += " (Repair)"

		# Show current crew count
		var assigned_count = task_assignments.get(task_id, []).size()
		if assigned_count > 0:
			task_text += " [%d/%d crew]" % [assigned_count, task.max_crew]

		available_tasks_list.add_item(task_text)

		# Tooltip with description
		available_tasks_list.set_item_tooltip(available_tasks_list.item_count - 1, task.description)

## Task Assignment
func _on_assign_task_pressed() -> void:
	"""Handle task assignment button press with max_crew support"""
	var selected_crew = crew_member_list.get_selected_items()
	var selected_task = available_tasks_list.get_selected_items()

	if selected_crew.is_empty() or selected_task.is_empty():
		print("CrewTaskComponent: Must select both crew member and task")
		return

	var crew_index = selected_crew[0]
	var task_index = selected_task[0]

	if crew_index >= crew_data.size() or task_index >= available_crew_tasks.size():
		print("CrewTaskComponent: Invalid selection indices")
		return

	var crew_member = crew_data[crew_index]
	var task = available_crew_tasks[task_index]
	var crew_id = crew_member.get("character_id", "crew_%d" % crew_index)
	var task_id = task.get("id", "task_%d" % task_index)

	# Check if crew is in Sick Bay
	var is_in_sick_bay = crew_member.get("in_sick_bay", false) or crew_member.get("status", "") == "injured"
	if is_in_sick_bay:
		print("CrewTaskComponent: %s is in Sick Bay and cannot perform tasks" % crew_member.get("character_name", "Unknown"))
		return

	# Check if crew already assigned
	if crew_id in assigned_tasks:
		print("CrewTaskComponent: %s already has a task assigned" % crew_member.get("character_name", "Unknown"))
		return

	# Check max_crew limit
	if not task_id in task_assignments:
		task_assignments[task_id] = []

	if task_assignments[task_id].size() >= task.max_crew:
		print("CrewTaskComponent: %s already has maximum crew (%d)" % [task.name, task.max_crew])
		return

	# Assign task
	assigned_tasks[crew_id] = {
		"crew_member": crew_member,
		"task": task,
		"task_id": task_id,
		"assigned_time": Time.get_unix_time_from_system(),
		"resolved": false
	}

	# Track in task_assignments for multi-crew
	task_assignments[task_id].append(crew_id)

	print("CrewTaskComponent: Assigned %s to %s (%d/%d crew)" % [
		task.name,
		crew_member.get("character_name", "Unknown"),
		task_assignments[task_id].size(),
		task.max_crew
	])

	# Update UI
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()

	# Publish assignment event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_ASSIGNED, {
			"crew_id": crew_id,
			"crew_name": crew_member.get("character_name", "Unknown"),
			"task_name": task.name,
			"task_id": task_id,
			"crew_on_task": task_assignments[task_id].size()
		})

## Task Resolution - Five Parsecs dice mechanics
func _on_resolve_all_pressed() -> void:
	"""Resolve all assigned crew tasks using Five Parsecs rules"""
	if assigned_tasks.is_empty():
		print("CrewTaskComponent: No tasks assigned to resolve")
		return
	
	print("CrewTaskComponent: Resolving %d crew tasks" % assigned_tasks.size())
	
	var resolution_results: Array = []
	
	for crew_id in assigned_tasks:
		var task_data = assigned_tasks[crew_id]
		if task_data.resolved:
			continue # Skip already resolved tasks
		
		var result = _resolve_single_task(crew_id, task_data)
		resolution_results.append(result)
		
		# Mark as resolved
		task_data.resolved = true
		task_data.result = result
	
	# Update completion state
	all_tasks_resolved = _check_all_tasks_resolved()
	completed_tasks = resolution_results
	
	_update_progress_display()
	_update_ui_state()
	
	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_RESOLVED, {
			"results": resolution_results,
			"all_resolved": all_tasks_resolved
		})
	
	print("CrewTaskComponent: All tasks resolved, success rate: %.1f%%" % _calculate_success_rate())

func _resolve_single_task(crew_id: String, task_data: Dictionary) -> Dictionary:
	"""Resolve a single crew task using Five Parsecs Core Rules"""
	var crew_member: Dictionary = task_data.crew_member
	var task: Dictionary = task_data.task
	var task_id: String = task_data.get("task_id", "")

	var result: Dictionary = {
		"crew_id": crew_id,
		"crew_name": crew_member.get("character_name", "Unknown"),
		"task_name": task.name,
		"task_id": task_id,
		"roll": 0,
		"modified_roll": 0,
		"target": task.dice_target,
		"success": false,
		"reward": "None",
		"penalty": "None",
		"details": ""
	}

	# Handle by resolution type (Core Rules pp.76-82)
	match task.resolution_type:
		"automatic":
			result = _resolve_automatic_task(result, task, crew_member)
		"dice_roll":
			result = _resolve_dice_task(result, task, task_id, crew_member)
		"table_roll":
			result = _resolve_table_task(result, task, crew_member)
		"repair":
			result = _resolve_repair_task(result, task, crew_member)

	var status = "SUCCESS" if result.success else "FAILED"
	print("CrewTaskComponent: %s - %s: %s (%s)" % [result.crew_name, result.task_name, status, result.details])

	return result

func _resolve_automatic_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	"""Resolve automatic tasks (Train, Decoy)"""
	result.success = true
	result.reward = task.success_reward

	match task.id:
		"train":
			result.details = "+1 XP awarded"
			_apply_xp_to_character(crew_member, 1, "train_task")
		"decoy":
			result.details = "Crew unavailable for battle, -1 enemy deployment"

	return result

func _resolve_dice_task(result: Dictionary, task: Dictionary, task_id: String, crew_member: Dictionary) -> Dictionary:
	"""Resolve dice roll tasks (Find Patron, Recruit, Track)"""
	var roll: int = randi() % 6 + 1
	var modified_roll: int = roll

	# Apply crew count bonus (+1 if 2 crew on task)
	var crew_on_task = task_assignments.get(task_id, []).size()
	if crew_on_task >= 2:
		modified_roll += 1
		result.details = "+1 for 2 crew"

	# Apply credit bonus
	var credits_spent = credits_spent_on_tasks.get(task_id, 0)
	if credits_spent > 0:
		var bonus = mini(credits_spent, task.credit_bonus)
		modified_roll += bonus
		result.details += ", +%d for %d credits" % [bonus, credits_spent]

	# Character bonus
	var character_bonus: int = crew_member.get("task_bonus", 0) as int
	if character_bonus > 0:
		modified_roll += character_bonus
		result.details += ", +%d skill" % character_bonus

	result.roll = roll
	result.modified_roll = modified_roll
	result.success = modified_roll >= task.dice_target

	if result.success:
		result.reward = task.success_reward
		result.details = "Roll %d → %d vs %d. %s" % [roll, modified_roll, task.dice_target, result.details]
	else:
		result.penalty = task.failure_penalty
		result.details = "Roll %d → %d vs %d. %s" % [roll, modified_roll, task.dice_target, result.details]

	return result

func _resolve_table_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	"""Resolve table roll tasks (Trade, Explore)"""
	var d100_roll: int = randi() % 100 + 1
	result.roll = d100_roll
	result.modified_roll = d100_roll
	result.success = true  # Table rolls always "succeed" - just determine outcome

	var table_result: Dictionary = {}
	match task.id:
		"trade":
			table_result = _get_trade_table_result(d100_roll)
			result.details = "Trade Table roll: %d - %s" % [d100_roll, table_result.name]
			result.reward = table_result.effect
			result.table_result = table_result  # Store full result for UI
		"explore":
			table_result = _get_exploration_table_result(d100_roll)
			result.details = "Exploration Table roll: %d - %s" % [d100_roll, table_result.name]
			result.reward = table_result.effect
			result.table_result = table_result  # Store full result for UI

	# Cache deferred events if result has a trigger
	if table_result.has("deferred_trigger") and table_result.deferred_trigger != "":
		var crew_id = crew_member.get("id", crew_member.get("character_name", "unknown"))
		_cache_deferred_event(
			table_result.deferred_trigger,
			table_result.name,
			crew_id,
			table_result
		)

	return result

func _resolve_repair_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	"""Resolve repair tasks"""
	# Check for Repair Bot or credits
	var has_repair_bot = crew_member.get("has_repair_bot", false)

	if has_repair_bot:
		result.success = true
		result.reward = "Item repaired (Repair Bot)"
		result.details = "Used Repair Bot"
	else:
		# Costs 1 credit per item
		var game_state_manager = get_node_or_null("/root/GameStateManager")
		if game_state_manager and game_state_manager.remove_credits(1):
			result.success = true
			result.reward = "Item repaired (1 credit)"
			result.details = "Deducted 1 credit"
		else:
			result.success = false
			result.reward = "Failed - not enough credits"
			result.details = "Need 1 credit for repair"

	return result

func _get_trade_table_result(roll: int) -> Dictionary:
	"""Get result from Trade Table (Core Rules p.79) - Full D100 table"""
	var result: Dictionary = {
		"name": "",
		"effect": "",
		"credits": 0,
		"xp": 0,
		"items": [],
		"story_points": 0,
		"deferred_trigger": "",  # Trigger type for deferred events
		"single_use": false,
		"requires_roll": false,
		"roll_info": ""
	}

	if roll <= 3:
		result.name = "A personal weapon"
		result.effect = "Roll once on the Low Tech Weapon Table"
		result.items = ["Low Tech Weapon (random)"]
	elif roll <= 6:
		result.name = "Sell some cargo"
		result.effect = "Earn 2 credits"
		result.credits = 2
	elif roll <= 9:
		result.name = "Find something useful"
		result.effect = "Roll once on the Gear Table"
		result.items = ["Gear (random)"]
	elif roll <= 11:
		result.name = "Quality food and booze"
		result.effect = "Recruit a new character to your crew"
		result.single_use = true
	elif roll <= 14:
		result.name = "Instruction book"
		result.effect = "A crew member of choice can read it and earn +1 XP"
		result.xp = 1
		result.single_use = true
	elif roll <= 18:
		result.name = "Bits of scrap"
		result.effect = "You sell it on, earning 1 credit"
		result.credits = 1
	elif roll <= 22:
		result.name = "Medical pack"
		result.effect = "Receive your choice of a Stim-pack or Med-patch"
		result.items = ["Stim-pack OR Med-patch"]
	elif roll <= 24:
		result.name = "Worthless trinket"
		result.effect = "Roll 1D6. On a 6, earn +1 story point"
		result.requires_roll = true
		result.roll_info = "1D6, on 6: +1 story point"
		var trinket_roll = randi() % 6 + 1
		if trinket_roll == 6:
			result.story_points = 1
			result.effect += " - Rolled %d: SUCCESS!" % trinket_roll
		else:
			result.effect += " - Rolled %d: No luck" % trinket_roll
	elif roll <= 26:
		result.name = "Local maps"
		result.effect = "If you receive a Quest on this or the following world, add 1 Rumor"
		result.single_use = true
		result.deferred_trigger = "ON_QUEST"
	elif roll <= 28:
		result.name = "Luxury trinket"
		result.effect = "+2 bonus to Recruiting roll, OR sell it (roll twice on Trade Table)"
		result.single_use = true
		result.deferred_trigger = "ON_RECRUIT"
	elif roll <= 30:
		result.name = "Basic supplies"
		result.effect = "Skip Upkeep costs for one campaign turn"
		result.single_use = true
		result.deferred_trigger = "NEXT_TURN"
	elif roll <= 34:
		result.name = "Contraband"
		result.effect = "Accept to earn 1D6 credits (on 4-6, also gain a Rival)"
		result.requires_roll = true
		var contra_roll = randi() % 6 + 1
		result.credits = contra_roll
		if contra_roll >= 4:
			result.effect = "Earned %d credits, but gained a Rival!" % contra_roll
		else:
			result.effect = "Earned %d credits safely" % contra_roll
	elif roll <= 37:
		result.name = "Gun Upgrade Kit"
		result.effect = "Receive your choice of a Laser Sight, Bipod or Beam Light"
		result.items = ["Laser Sight OR Bipod OR Beam Light"]
	elif roll <= 39:
		result.name = "Useless trinket"
		result.effect = "Roll 1D6. On a 6, earn +1 story point"
		result.requires_roll = true
		var useless_roll = randi() % 6 + 1
		if useless_roll == 6:
			result.story_points = 1
			result.effect += " - Rolled %d: SUCCESS!" % useless_roll
		else:
			result.effect += " - Rolled %d: No luck" % useless_roll
	elif roll <= 44:
		result.name = "Trade goods"
		result.effect = "On each new planet, roll 1D6 to see how many credits they sell for. On 1, they perish"
		result.items = ["Trade Goods"]
		result.deferred_trigger = "PERSISTENT"
	elif roll <= 48:
		result.name = "Something interesting"
		result.effect = "Roll once on the Loot Table"
		result.items = ["Loot (random)"]
	elif roll <= 51:
		result.name = "Fuel"
		result.effect = "Roll 1D6 for credits worth of fuel"
		var fuel_roll = randi() % 6 + 1
		result.credits = fuel_roll
		result.effect = "Secured %d credits worth of fuel" % fuel_roll
	elif roll <= 53:
		result.name = "Spare parts"
		result.effect = "+1 when making a Repair attempt. On natural 1, parts are used up"
		result.items = ["Spare Parts"]
	elif roll <= 55:
		result.name = "Tourist garbage"
		result.effect = "Roll 1D6. On 5-6, add 1 story point"
		result.requires_roll = true
		var tourist_roll = randi() % 6 + 1
		if tourist_roll >= 5:
			result.story_points = 1
			result.effect += " - Rolled %d: +1 story point!" % tourist_roll
		else:
			result.effect += " - Rolled %d: Worthless" % tourist_roll
	elif roll == 56:
		result.name = "Don't usually see these for sale"
		result.effect = "Pay 3 credits to roll on the Loot Table (must be used by this crew member)"
		result.requires_roll = true
	elif roll <= 59:
		result.name = "Ordnance"
		result.effect = "Receive 3 grenades (Frakk or Dazzle in any combination)"
		result.items = ["3x Grenades"]
	elif roll <= 62:
		result.name = "Basic firearms"
		result.effect = "Your choice of a Handgun, Colony Rifle, or Shotgun"
		result.items = ["Handgun OR Colony Rifle OR Shotgun"]
	elif roll == 63:
		result.name = "Odd device"
		result.effect = "Pay 1 credit, then roll 1D6. On 6, roll on Loot Table. Otherwise garbage"
		result.requires_roll = true
		var odd_roll = randi() % 6 + 1
		if odd_roll == 6:
			result.items = ["Loot (random)"]
			result.effect = "Paid 1 credit - Rolled %d: It works!" % odd_roll
		else:
			result.effect = "Paid 1 credit - Rolled %d: Complete garbage" % odd_roll
		result.credits = -1
	elif roll <= 65:
		result.name = "Military fuel cell"
		result.effect = "Zero travel costs when jumping to a new planet"
		result.items = ["Military Fuel Cell"]
		result.single_use = true
		result.deferred_trigger = "NEW_PLANET"
	elif roll <= 69:
		result.name = "Hot tip"
		result.effect = "Gain 1 Quest Rumor"
	elif roll <= 71:
		result.name = "Insider information"
		result.effect = "Automatically obtain a Patron next campaign turn if you look for one"
		result.single_use = true
		result.deferred_trigger = "NEXT_TURN"
	elif roll <= 75:
		result.name = "Army surplus"
		result.effect = "Your choice of an Auto Rifle, Blast Pistol or Glare Sword"
		result.items = ["Auto Rifle OR Blast Pistol OR Glare Sword"]
	elif roll <= 78:
		result.name = "A chance to unload some stuff"
		result.effect = "A revolutionary will buy any weapons for 2 credits each (not damaged)"
	elif roll <= 81:
		result.name = "A lot of blinking lights"
		result.effect = "Roll once on the Gear subsection of the Loot Table"
		result.items = ["Gear Loot (random)"]
	elif roll <= 86:
		result.name = "\"Gently used\""
		result.effect = "Roll once on the Gear subsection of the Loot Table (item is damaged)"
		result.items = ["Gear Loot (random, damaged)"]
	elif roll <= 91:
		result.name = "\"Pre-owned\""
		result.effect = "Roll once on the Loot Table (item is damaged)"
		result.items = ["Loot (random, damaged)"]
	elif roll <= 95:
		result.name = "Medical reserves"
		result.effect = "Obtain 2 Stim-packs and 2 Med-patches"
		result.items = ["2x Stim-pack", "2x Med-patch"]
	else:  # 96-100
		result.name = "Starship repair parts"
		result.effect = "Count as 1D6 credits for repairing Hull Point damage"
		var repair_roll = randi() % 6 + 1
		result.credits = repair_roll
		result.effect = "Worth %d credits for Hull Point repairs" % repair_roll
		result.single_use = true
		result.deferred_trigger = "PERSISTENT"

	return result

func _get_exploration_table_result(roll: int) -> Dictionary:
	"""Get result from Exploration Table (Core Rules p.80) - Full D100 table"""
	var result: Dictionary = {
		"name": "",
		"effect": "",
		"credits": 0,
		"xp": 0,
		"items": [],
		"story_points": 0,
		"deferred_trigger": "",  # Trigger type for deferred events
		"single_use": false,
		"requires_roll": false,
		"roll_info": "",
		"sick_bay_turns": 0,
		"rumor": false,
		"rival": false,
		"patron": false
	}

	if roll <= 3:
		result.name = "I know a good deal when I see one"
		result.effect = "Roll on the Trade Table instead"
		# Recursively roll on trade table
		var trade_roll = randi() % 100 + 1
		var trade_result = _get_trade_table_result(trade_roll)
		result.name = "Good Deal: " + trade_result.name
		result.effect = trade_result.effect
		result.credits = trade_result.credits
		result.xp = trade_result.xp
		result.items = trade_result.items
		result.story_points = trade_result.story_points
	elif roll <= 6:
		result.name = "Meet a Patron"
		result.effect = "You are offered a Patron job"
		result.patron = true
	elif roll <= 8:
		result.name = "Must've been something I ate"
		result.effect = "Character must spend 1 campaign turn in Sick Bay (Soulless and K'Erin ignore)"
		result.sick_bay_turns = 1
	elif roll <= 11:
		result.name = "Meet someone interesting"
		result.effect = "Gain a Quest Rumor. Precursor: roll 1D6, on 5+ get second Rumor"
		result.rumor = true
	elif roll <= 15:
		result.name = "Had a nice chat"
		result.effect = "Roll 1D6+Savvy. On 5+ gain +1 story point"
		result.requires_roll = true
		var chat_roll = randi() % 6 + 1
		# Assume average Savvy of 0 for now
		if chat_roll >= 5:
			result.story_points = 1
			result.effect = "Nice chat - Rolled %d: +1 story point!" % chat_roll
		else:
			result.effect = "Nice chat - Rolled %d: Pleasant but unproductive" % chat_roll
	elif roll <= 18:
		result.name = "See the sights, enjoy the view"
		result.effect = "No effects - but a nice day out"
	elif roll <= 21:
		result.name = "Make a new friend"
		result.effect = "Roll up a new character and add them to the crew (Feral finds Feral)"
	elif roll <= 24:
		result.name = "Time to relax"
		result.effect = "No effects - character takes it easy"
	elif roll <= 28:
		result.name = "Possible bargain"
		result.effect = "Give up a weapon, roll 1D6. On 6: Loot Table roll. Otherwise: 1 credit"
		result.requires_roll = true
		var bargain_roll = randi() % 6 + 1
		if bargain_roll == 6:
			result.items = ["Loot (random)"]
			result.effect = "Traded weapon - Rolled %d: Got something good!" % bargain_roll
		else:
			result.credits = 1
			result.effect = "Traded weapon - Rolled %d: Got 1 credit" % bargain_roll
	elif roll <= 31:
		result.name = "Alien merchant"
		result.effect = "Give him any item, then roll on the Loot Table"
		result.items = ["Loot (random)"]
	elif roll <= 34:
		result.name = "Got yourself noticed"
		result.effect = "If you have Rivals, select one at random - you must fight them this turn"
		result.rival = true
	elif roll <= 37:
		result.name = "You hear a tip"
		result.effect = "You may opt to automatically track down a Rival to fight this campaign turn"
	elif roll <= 40:
		result.name = "Completely lost"
		result.effect = "Roll 1D6+Savvy. On 4+ find way back, otherwise miss battle. Roll again on this table"
		result.requires_roll = true
		var lost_roll = randi() % 6 + 1
		if lost_roll >= 4:
			result.effect = "Got lost - Rolled %d: Found way back in time" % lost_roll
		else:
			result.effect = "Got lost - Rolled %d: Unable to participate in battle" % lost_roll
	elif roll <= 44:
		result.name = "Someone wants a package delivered"
		result.effect = "On new world: earn 3 credits. On 1-2, gain Rival and +1 story point"
		result.credits = 3
		result.deferred_trigger = "NEW_PLANET"
	elif roll <= 47:
		result.name = "A tech fanatic offers to help out"
		result.effect = "Pick damaged item, roll 1D6. On 5-6: free repair. Engineer gets +2 XP instead"
		result.requires_roll = true
		var tech_roll = randi() % 6 + 1
		if tech_roll >= 5:
			result.effect = "Tech help - Rolled %d: Item repaired for free!" % tech_roll
		else:
			result.effect = "Tech help - Rolled %d: No luck with repair" % tech_roll
	elif roll <= 50:
		result.name = "Got a few drinks"
		result.effect = "No effects - a quiet drink"
	elif roll <= 53:
		result.name = "I don't have a gambling problem!"
		result.effect = "Discard one item from character's equipment or Stash (Soulless ignore)"
	elif roll <= 57:
		result.name = "Overheard some talk"
		result.effect = "Gain a Rumor"
		result.rumor = true
	elif roll <= 60:
		result.name = "Pick a fight"
		result.effect = "Add a Rival. K'Erin: first battle has -1 enemy (you knocked one out)"
		result.rival = true
	elif roll <= 64:
		result.name = "Found a trainer"
		result.effect = "Character earns +2 XP"
		result.xp = 2
	elif roll <= 68:
		result.name = "Information broker"
		result.effect = "Buy up to 3 Rumors for 2 credits each"
	elif roll <= 71:
		result.name = "Arms dealer"
		result.effect = "Purchase any number of rolls on Military Weapons Table for 3 credits each"
	elif roll <= 75:
		result.name = "Promising lead"
		result.effect = "Earn +3 credits if you do an Opportunity mission this campaign turn"
		result.credits = 3
	elif roll <= 79:
		result.name = "Just needs a little love"
		result.effect = "Roll on Gadget Table (item damaged, needs repair). Engineer: works right away"
		result.items = ["Gadget (random, damaged)"]
	elif roll <= 82:
		result.name = "Get in a bad fight"
		result.effect = "Character spends 1D3 turns in Sick Bay and loses one carried item"
		var bad_fight_turns = (randi() % 3) + 1
		result.sick_bay_turns = bad_fight_turns
		result.effect = "Bad fight - %d turns in Sick Bay, lose one item" % bad_fight_turns
	elif roll <= 86:
		result.name = "Offered a small job"
		result.effect = "Select random enemy figure. If your crew kills them, earn 2 credits"
		result.credits = 2
		result.deferred_trigger = "THIS_BATTLE"
	elif roll <= 90:
		result.name = "Offered a reward"
		result.effect = "Select random terrain feature. If crew member reaches it, earn 2 credits"
		result.credits = 2
		result.deferred_trigger = "THIS_BATTLE"
	elif roll <= 93:
		result.name = "Found some work"
		result.effect = "Gain a Patron job opportunity"
		result.patron = true
	elif roll <= 96:
		result.name = "Mysterious stranger"
		result.effect = "Roll 1D6: 1-3 gain Rival, 4-6 gain Quest Rumor"
		result.requires_roll = true
		var stranger_roll = randi() % 6 + 1
		if stranger_roll <= 3:
			result.rival = true
			result.effect = "Mysterious stranger - Rolled %d: Gained a Rival" % stranger_roll
		else:
			result.rumor = true
			result.effect = "Mysterious stranger - Rolled %d: Gained Quest Rumor" % stranger_roll
	else:  # 97-100
		result.name = "Trouble finds you"
		result.effect = "Fight an immediate battle against a random enemy type"
		result.rival = true

	return result

## Deferred Event System - cache events for future triggers
func _cache_deferred_event(trigger_type: String, event_name: String, crew_id: String, effect: Dictionary) -> void:
	"""Cache a deferred event that will trigger on a future condition.

	Trigger types from Core Rules:
	- NEW_PLANET: Triggers when crew arrives at new planet
	- NEXT_TURN: Triggers at start of next campaign turn
	- THIS_BATTLE: Triggers during next battle
	- ON_QUEST: Triggers when undertaking a quest
	- ON_RECRUIT: Triggers when recruiting crew
	- PERSISTENT: Remains until used (trade goods, spare parts)
	"""
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		push_warning("Cannot cache deferred event - no GameState")
		return

	var campaign = game_state.current_campaign
	if not campaign:
		push_warning("Cannot cache deferred event - no campaign")
		return

	# Create event structure
	var event: Dictionary = {
		"id": str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000),
		"trigger_type": trigger_type,
		"event_name": event_name,
		"crew_id": crew_id,
		"effect": effect.duplicate(true),
		"turn_created": campaign.campaign_turn if campaign.has_method("get") else 0,
		"expires_turn": null,  # null = never expires
		"consumed": false
	}

	# Handle expiration for certain trigger types
	if trigger_type == "NEXT_TURN":
		event.expires_turn = event.turn_created + 1

	# Add to campaign pending events
	if campaign is Resource and "pending_events" in campaign:
		campaign.pending_events.append(event)
		print("Cached deferred event: %s (trigger: %s) for crew %s" % [event_name, trigger_type, crew_id])
	else:
		# Fallback: store in campaign dictionary
		if not campaign.has("pending_events"):
			campaign["pending_events"] = []
		campaign["pending_events"].append(event)
		print("Cached deferred event (dict): %s (trigger: %s) for crew %s" % [event_name, trigger_type, crew_id])

func _check_all_tasks_resolved() -> bool:
	"""Check if all assigned tasks have been resolved"""
	for task_data: Dictionary in assigned_tasks.values():
		if not task_data.get("resolved", false):
			return false
	return true

func _calculate_success_rate() -> float:
	"""Calculate success rate of completed tasks"""
	if completed_tasks.is_empty():
		return 0.0
	
	var successful_tasks: int = 0
	for result: Dictionary in completed_tasks:
		if result.get("success", false):
			successful_tasks += 1
	
	return float(successful_tasks) / float(completed_tasks.size()) * 100.0

## UI Updates
func _update_ui_state() -> void:
	"""Update UI state based on current task assignments"""
	if assign_task_button:
		assign_task_button.disabled = false # Can always assign more tasks
	
	if resolve_all_button:
		resolve_all_button.disabled = assigned_tasks.is_empty()
		if all_tasks_resolved:
			resolve_all_button.text = "All Tasks Resolved"
		else:
			resolve_all_button.text = "Resolve All Tasks (%d)" % assigned_tasks.size()

func _update_progress_display() -> void:
	"""Update progress display with task results"""
	if not progress_container:
		return

	# Clear existing progress display
	for child in progress_container.get_children():
		child.queue_free()

	# Show results
	for result in completed_tasks:
		var result_container = VBoxContainer.new()

		# Main result line
		var result_label = Label.new()
		var status_text = "✓" if result.success else "✗"
		var color = Color.GREEN if result.success else Color.RED

		result_label.text = "%s %s - %s" % [
			status_text,
			result.crew_name,
			result.task_name
		]
		result_label.modulate = color
		result_container.add_child(result_label)

		# Show table result details for Trade/Explore tasks
		if result.has("table_result"):
			var table_data = result.table_result

			# Result name and effect
			var detail_label = Label.new()
			detail_label.text = "   → %s" % table_data.name
			detail_label.modulate = Color(0.8, 0.8, 1.0)  # Light blue
			result_container.add_child(detail_label)

			var effect_label = Label.new()
			effect_label.text = "      %s" % table_data.effect
			effect_label.modulate = Color(0.7, 0.7, 0.7)  # Gray
			effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_container.add_child(effect_label)

			# Show rewards summary
			var rewards: Array = []
			if table_data.get("credits", 0) > 0:
				rewards.append("+%d credits" % table_data.credits)
			if table_data.get("xp", 0) > 0:
				rewards.append("+%d XP" % table_data.xp)
			if table_data.get("story_points", 0) > 0:
				rewards.append("+%d story point" % table_data.story_points)
			if table_data.get("items", []).size() > 0:
				for item in table_data.items:
					rewards.append(item)
			if table_data.get("rumor", false):
				rewards.append("Quest Rumor")
			if table_data.get("patron", false):
				rewards.append("Patron Job")
			if table_data.get("rival", false):
				rewards.append("Rival (danger!)")
			if table_data.get("sick_bay_turns", 0) > 0:
				rewards.append("%d turns in Sick Bay" % table_data.sick_bay_turns)

			if rewards.size() > 0:
				var reward_label = Label.new()
				reward_label.text = "      Rewards: %s" % ", ".join(rewards)
				reward_label.modulate = Color(1.0, 0.9, 0.5)  # Gold
				result_container.add_child(reward_label)
		else:
			# Standard result for non-table tasks
			if result.details != "":
				var detail_label = Label.new()
				detail_label.text = "   %s" % result.details
				detail_label.modulate = Color(0.7, 0.7, 0.7)
				result_container.add_child(detail_label)

			if result.reward != "None" and result.reward != "":
				var reward_label = Label.new()
				reward_label.text = "   Reward: %s" % result.reward
				reward_label.modulate = Color(1.0, 0.9, 0.5)
				result_container.add_child(reward_label)

		progress_container.add_child(result_container)

		# Add separator
		var separator = HSeparator.new()
		separator.modulate = Color(0.3, 0.3, 0.3)
		progress_container.add_child(separator)

## Event Handlers
func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	_update_ui_state()

func _on_task_selected(index: int) -> void:
	"""Handle task selection"""
	_update_ui_state()

func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "crew_tasks":
		print("CrewTaskComponent: Crew tasks phase started")

func _on_automation_toggled(data: Dictionary) -> void:
	"""Handle automation toggle - auto-assign and resolve tasks"""
	var automation_enabled = data.get("enabled", false)
	if automation_enabled and not assigned_tasks.is_empty():
		print("CrewTaskComponent: Auto-resolving tasks due to automation")
		_on_resolve_all_pressed()

## Public API for integration
func are_tasks_completed() -> bool:
	"""Check if all crew tasks are completed"""
	return all_tasks_resolved and not assigned_tasks.is_empty()

func is_tasks_completed() -> bool:
	"""Alias for are_tasks_completed() - matches controller API"""
	return are_tasks_completed()

func get_task_results() -> Array:
	"""Get results of all completed tasks"""
	return completed_tasks.duplicate()

func get_assigned_task_count() -> int:
	"""Get number of currently assigned tasks"""
	return assigned_tasks.size()

func reset_crew_tasks() -> void:
	"""Reset crew tasks for new turn"""
	assigned_tasks.clear()
	completed_tasks.clear()
	task_assignments.clear()
	credits_spent_on_tasks.clear()
	all_tasks_resolved = false
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()
	print("CrewTaskComponent: Reset for new turn")

func complete_crew_task_phase() -> void:
	"""Mark the crew task phase as complete and publish event"""
	if not all_tasks_resolved and not assigned_tasks.is_empty():
		_on_resolve_all_pressed()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "crew_tasks",
			"tasks_completed": completed_tasks.size(),
			"success_rate": _calculate_success_rate()
		})

	print("CrewTaskComponent: Crew task phase completed")

func spend_credits_on_task(task_id: String, amount: int) -> bool:
	"""Spend credits on a task for bonus modifier"""
	# Get task info
	var task: Dictionary = {}
	for t in available_crew_tasks:
		if t.get("id", "") == task_id:
			task = t
			break

	if task.is_empty():
		return false

	var max_bonus = task.get("credit_bonus", 0)
	if max_bonus <= 0:
		print("CrewTaskComponent: %s doesn't support credit bonuses" % task.name)
		return false

	var current_spent = credits_spent_on_tasks.get(task_id, 0)
	var total = current_spent + amount

	if total > max_bonus:
		print("CrewTaskComponent: Can only spend up to %d credits on %s" % [max_bonus, task.name])
		return false

	# Check GameStateManager has enough credits and deduct
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		var available_credits = game_state_manager.get_credits()
		if available_credits < amount:
			print("CrewTaskComponent: Not enough credits (%d available, need %d)" % [available_credits, amount])
			return false
		if not game_state_manager.remove_credits(amount):
			print("CrewTaskComponent: Failed to deduct %d credits" % amount)
			return false

	credits_spent_on_tasks[task_id] = total
	print("CrewTaskComponent: Spent %d credits on %s (total: %d/%d)" % [amount, task.name, total, max_bonus])
	return true

## Helper function to apply XP to a character
func _apply_xp_to_character(crew_member: Dictionary, amount: int, source: String) -> void:
	"""Apply XP to a character and persist to GameStateManager"""
	var character_id = crew_member.get("id", "")
	if character_id.is_empty():
		character_id = crew_member.get("character_id", "")

	if character_id.is_empty():
		push_warning("CrewTaskComponent: Cannot apply XP - no character ID found")
		return

	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		push_warning("CrewTaskComponent: Cannot apply XP - no GameState")
		return

	var campaign = game_state.current_campaign
	if not campaign:
		push_warning("CrewTaskComponent: Cannot apply XP - no campaign")
		return

	# Find character in crew and apply XP
	var crew = []
	if campaign is Dictionary:
		crew = campaign.get("crew", [])
	elif campaign.has_method("get"):
		crew = campaign.get("crew") if campaign.get("crew") else []

	for character in crew:
		# Sprint 26.3: Character-Everywhere - check Object/Character first
		var char_id = ""
		if character is Object and "character_id" in character:
			char_id = character.character_id
		elif character is Object and "id" in character:
			char_id = character.id
		elif character is Dictionary:
			char_id = character.get("id", character.get("character_id", ""))

		if char_id == character_id:
			# Sprint 26.3: Character-Everywhere - handle Character objects first
			# Sprint 27.4: Cleaned up dead xp code path - canonical property is 'experience'
			var current_xp = 0
			if character is Object and character.has_method("add_experience"):
				current_xp = character.experience if "experience" in character else 0
				character.add_experience(amount)
			elif character is Object and "experience" in character:
				current_xp = character.experience if character.experience else 0
				character.experience = current_xp + amount
			elif character is Dictionary:
				current_xp = character.get("experience", 0)
				character["experience"] = current_xp + amount

			print("CrewTaskComponent: Applied %d XP to character %s from %s (total: %d)" % [
				amount, character_id, source, current_xp + amount
			])
			return

	push_warning("CrewTaskComponent: Character %s not found in crew" % character_id)
