extends WorldPhaseComponent
class_name CrewTaskComponent

## Crew Task Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs crew task rules only
## Implements Core Rules pp.76-82 - Crew task assignment and resolution

const RulesHelpText = preload("res://src/data/rules_help_text.gd")
const ItemChoicePopupScript = preload("res://src/ui/components/dialogs/ItemChoicePopup.gd")
const GrenadeCombinationPopupScript = preload("res://src/ui/components/dialogs/GrenadeCombinationPopup.gd")
const CrewTaskEventDialogScript = preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const DiceManager = preload("res://src/core/managers/DiceManager.gd")

# Design system constants


# UI Components
@onready var crew_task_container: VBoxContainer = %CrewTaskContainer
@onready var crew_member_list: ItemList = %CrewMemberList
@onready var available_tasks_list: ItemList = %AvailableTasksList
@onready var assign_task_button: Button = %AssignTaskButton
@onready var resolve_all_button: Button = %ResolveAllButton
@onready var progress_container: VBoxContainer = %ProgressContainer
@onready var help_button: Button = %HelpButton

# Crew task state
var crew_data: Array = []
var assigned_tasks: Dictionary = {} # crew_member_id -> task_data
var completed_tasks: Array = []
var all_tasks_resolved: bool = false

# Choice popup state — tracks pending item choices from task results
var _pending_choice_results: Array = [] # Queue of {result, item_string, options}
var _choice_popup: Window = null
var _auto_resolve_mode: bool = false

# Event queue — interactive dialog for each crew task result
var _event_queue: Array[Dictionary] = []
var _current_event_dialog: Window = null

# Five Parsecs crew tasks — loaded from data/crew_tasks.json (Core Rules pp.76-82)
var available_crew_tasks: Array[Dictionary] = []

func _load_crew_tasks() -> void:
	var path := "res://data/crew_tasks.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("CrewTaskComponent: Failed to open crew_tasks.json at %s" % path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("CrewTaskComponent: Failed to parse crew_tasks.json: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	var tasks: Array = data.get("tasks", [])
	available_crew_tasks.clear()
	for task: Dictionary in tasks:
		available_crew_tasks.append({
			"id": task.get("id", ""),
			"name": task.get("name", ""),
			"description": task.get("description", ""),
			"dice_target": int(task.get("dice_target", 0)),
			"max_crew": int(task.get("max_crew", 2)),
			"credit_bonus": int(task.get("credit_bonus_max", 0)),
			"success_reward": task.get("success_reward", ""),
			"failure_penalty": task.get("failure_penalty", "None"),
			"resolution_type": task.get("resolution_type", "dice_roll")
		})

# Track crew per task for multi-assignment
var task_assignments: Dictionary = {} # task_id -> Array of crew_ids
var credits_spent_on_tasks: Dictionary = {} # task_id -> credits spent


func _ready() -> void:
	name = "CrewTaskComponent"
	_load_crew_tasks()
	super._ready()

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	_subscribe(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

func _connect_ui_signals() -> void:
	## Connect UI signals
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
	## Show crew tasks help dialog
	_show_help_dialog("Crew Tasks", RulesHelpText.get_tooltip("crew_tasks"))

func _setup_initial_state() -> void:
	## Initialize component state
	assigned_tasks.clear()
	completed_tasks.clear()
	all_tasks_resolved = false
	_populate_available_tasks()

## Public API: Initialize crew tasks phase
func initialize_crew_tasks(crew: Array) -> void:
	## Initialize crew tasks phase with current crew data
	crew_data = crew.duplicate()
	assigned_tasks.clear()
	completed_tasks.clear()
	all_tasks_resolved = false
	
	pass # Initialized with crew members
	
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()
	
	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_STARTED, {
			"crew_size": crew_data.size()
		})

func _populate_crew_list() -> void:
	## Populate crew member list UI - excludes Sick Bay crew
	if not crew_member_list:
		return

	crew_member_list.clear()
	for i in range(crew_data.size()):
		var crew_member = crew_data[i]
		var crew_name = crew_member.get("character_name", "Crew Member %d" % (i + 1))

		# Check if in Sick Bay (Core Rules - injured crew can't perform tasks)
		var is_in_sick_bay = crew_member.get("in_sick_bay", false) or crew_member.get("status", "") == "injured"

		# Time to Burn: extra action even in Sick Bay (Core Rules p.130)
		var has_extra_action := false
		for eff in crew_member.get("status_effects", []):
			if str(eff.get("type", "")) == "extra_action":
				has_extra_action = true
				break

		if is_in_sick_bay and not has_extra_action:
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
	## Get crew members not in Sick Bay and not blocked by Character Events.
	## Time to Burn (Core Rules p.130): extra_action allows tasks even in Sick Bay.
	var eligible: Array = []
	for crew_member in crew_data:
		var is_in_sick_bay = crew_member.get("in_sick_bay", false) \
			or crew_member.get("status", "") == "injured"
		# Time to Burn overrides Sick Bay restriction
		var has_extra_action := false
		for eff in crew_member.get("status_effects", []):
			if str(eff.get("type", "")) == "extra_action":
				has_extra_action = true
				break
		if is_in_sick_bay and not has_extra_action:
			continue
		# Character Event restrictions (Core Rules pp.128-130)
		var has_task_block := false
		for eff in crew_member.get("status_effects", []):
			var eff_type: String = str(eff.get("type", ""))
			if eff_type == "skip_tasks" or eff_type == "unavailable" or eff_type == "departed":
				has_task_block = true
				break
		if has_task_block:
			continue
		eligible.append(crew_member)
	return eligible

func _populate_available_tasks() -> void:
	## Populate available tasks list UI with Core Rules info
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

		# Show current crew count and full indicator
		var assigned_count = task_assignments.get(task_id, []).size()
		if assigned_count >= task.max_crew:
			task_text += " [FULL %d/%d]" % [assigned_count, task.max_crew]
		elif assigned_count > 0:
			task_text += " [%d/%d crew]" % [assigned_count, task.max_crew]

		available_tasks_list.add_item(task_text)

		# Tooltip with description
		available_tasks_list.set_item_tooltip(available_tasks_list.item_count - 1, task.description)

## Task Assignment
func _on_assign_task_pressed() -> void:
	## Handle task assignment button press with max_crew support
	var selected_crew = crew_member_list.get_selected_items()
	var selected_task = available_tasks_list.get_selected_items()

	if selected_crew.is_empty() or selected_task.is_empty():
		return

	var crew_index = selected_crew[0]
	var task_index = selected_task[0]

	if crew_index >= crew_data.size() or task_index >= available_crew_tasks.size():
		return

	var crew_member = crew_data[crew_index]
	var task = available_crew_tasks[task_index]
	var crew_id = crew_member.get("character_id", "crew_%d" % crew_index)
	var task_id = task.get("id", "task_%d" % task_index)

	# Check if crew is in Sick Bay
	var is_in_sick_bay = crew_member.get("in_sick_bay", false) or crew_member.get("status", "") == "injured"
	if is_in_sick_bay:
		push_warning("CrewTaskComponent: %s is in Sick Bay and cannot be assigned" % crew_member.get("character_name", "Crew"))
		return

	# Mutant: cannot Recruit or Find a Patron (Core Rules p.21)
	var crew_species: String = crew_member.get(
		"species_id", crew_member.get("origin", "")).to_lower()
	if crew_species == "mutant" and task_id in [
		"recruit", "find_patron"]:
		var task_name: String = task.get("name", task_id)
		push_warning(
			"CrewTaskComponent: Mutant %s cannot perform %s"
			+ " (Core Rules p.21)"
			% [crew_member.get("character_name", "Crew"),
			task_name])
		return

	# Check if crew already assigned
	if crew_id in assigned_tasks:
		push_warning("CrewTaskComponent: %s already has a task assigned" % crew_member.get("character_name", "Crew"))
		return

	# Check max_crew limit
	if not task_id in task_assignments:
		task_assignments[task_id] = []

	if task_assignments[task_id].size() >= task.max_crew:
		var task_name: String = task.get("name", task_id)
		push_warning("CrewTaskComponent: %s is full (%d/%d crew)" % [task_name, task_assignments[task_id].size(), task.max_crew])
		# Refresh task list to show updated capacity indicators
		_populate_available_tasks()
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

	pass # Task assigned to crew member

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
	## Resolve all assigned crew tasks using Five Parsecs rules
	if assigned_tasks.is_empty():
		return
	
	pass # Resolving crew tasks
	
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

	# Build event queue — each result becomes an interactive dialog
	_build_event_queue()
	_process_event_queue()

func _finalize_task_resolution() -> void:
	## Complete task resolution — items/credits/effects already applied by event queue.
	## Just publish the completion event and update display.
	_update_progress_display()

	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_RESOLVED, {
			"results": completed_tasks,
			"all_resolved": all_tasks_resolved
		})

func _resolve_single_task(crew_id: String, task_data: Dictionary) -> Dictionary:
	## Resolve a single crew task using Five Parsecs Core Rules
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
	pass # Task resolved

	return result

func _resolve_automatic_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	## Resolve automatic tasks (Train, Decoy)
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
	## Resolve dice roll tasks (Find Patron, Recruit, Track)
	var roll: int = randi() % 6 + 1
	var modified_roll: int = roll

	# Apply crew count bonus (Core Rules: +N for N crew members on task)
	var crew_on_task = task_assignments.get(task_id, []).size()
	if crew_on_task > 0:
		modified_roll += crew_on_task
		result.details = "+%d for %d crew" % [crew_on_task, crew_on_task]

	# Apply credit bonus
	var credits_spent = credits_spent_on_tasks.get(task_id, 0)
	if credits_spent > 0:
		var bonus = mini(credits_spent, task.credit_bonus)
		modified_roll += bonus
		result.details += ", +%d for %d credits" % [bonus, credits_spent]

	# Character bonus (Savvy, etc.)
	var character_bonus: int = crew_member.get("task_bonus", 0) as int
	if character_bonus > 0:
		modified_roll += character_bonus
		result.details += ", +%d skill" % character_bonus

	# Empath: +1 to Recruit and Find Patron tasks (Core Rules p.22)
	# Lost permanently if character has any implants
	var crew_species: String = crew_member.get("species_id", "").to_lower()
	if crew_species == "empath" and crew_member.get("implants", []).is_empty():
		if task_id in ["recruit", "find_patron"]:
			modified_roll += 1
			result.details += ", +1 Empath"

	# --- Task-specific rules (Core Rules pp.77-78) ---

	# Find Patron: +1 per existing Patron contact, 6+ = two patrons
	if task.id == "find_patron":
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm:
			var patrons = gsm.get_patrons()
			if patrons.size() > 0:
				modified_roll += patrons.size()
				result.details += ", +%d patron(s)" % patrons.size()

	# Recruit: auto-recruit when crew < 6 (Core Rules p.78)
	if task.id == "recruit":
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.get_crew_size() < 6:
			result.roll = roll
			result.modified_roll = 0
			result.success = true
			result.reward = "Automatic recruit (crew below 6)"
			result.details = "Crew size < 6: auto-recruit"
			return result

	result.roll = roll
	result.modified_roll = modified_roll
	result.success = modified_roll >= task.dice_target

	# Find Patron: 6+ means TWO patrons (Core Rules p.77)
	if task.id == "find_patron":
		if modified_roll >= 6:
			result.success = true
			result.reward = "Found 2 Patrons (choose one job)"
			_generate_and_add_patron(2)
		elif modified_roll >= 5:
			result.success = true
			result.reward = "Found 1 Patron"
			_generate_and_add_patron(1)

	if result.success:
		if result.reward == "None" or result.reward == "":
			result.reward = task.success_reward
		result.details = "Roll %d → %d vs %d. %s" % [roll, modified_roll, task.dice_target, result.details]
	else:
		result.penalty = task.failure_penalty
		result.details = "Roll %d → %d vs %d. %s" % [roll, modified_roll, task.dice_target, result.details]

	return result

func _generate_and_add_patron(count: int) -> void:
	## Generate patron(s) using PatronJobManager and add to campaign
	var pjm = PatronJobManager.new()
	var gs = get_node_or_null("/root/GameState")
	var campaign = gs.current_campaign if gs and gs.current_campaign else null
	for i in range(count):
		var contact_result: Dictionary = pjm.roll_patron_contact()
		if contact_result.get("success", false):
			var patron_data: Dictionary = contact_result.get("patron", {})
			if not patron_data.is_empty() and campaign and "patrons" in campaign:
				campaign.patrons.append(patron_data)
				pass # Patron added
		else:
			# Fallback: generate a basic patron even if roll failed (task already succeeded)
			var fallback: Dictionary = {
				"id": "patron_" + str(randi() % 100000),
				"name": "Local Contact",
				"tier": "minor",
				"relationship": 0,
				"job": {"type": "DELIVERY", "description": "Transport goods", "pay": 4, "danger_level": 1},
			}
			if campaign and "patrons" in campaign:
				campaign.patrons.append(fallback)
	pjm.free()

func _resolve_table_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	## Resolve table roll tasks (Trade, Explore)
	var d100_roll: int = randi() % 100 + 1
	result.roll = d100_roll
	result.modified_roll = d100_roll
	result.success = true # Table rolls always "succeed" - just determine outcome

	var table_result: Dictionary = {}
	match task.id:
		"trade":
			table_result = _get_trade_table_result(d100_roll)
			result.details = "Trade Table roll: %d - %s" % [d100_roll, table_result.name]
			result.reward = table_result.effect
			result.table_result = table_result # Store full result for UI
		"explore":
			table_result = _get_exploration_table_result(d100_roll)
			result.details = "Exploration Table roll: %d - %s" % [d100_roll, table_result.name]
			result.reward = table_result.effect
			result.table_result = table_result # Store full result for UI

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
	## Resolve repair tasks (Core Rules p.78)
	## Roll 1D6 + Savvy. Engineer +1. Spare parts (credits) +1 each. 6+ = repaired. Natural 1 = unfixable.
	var roll: int = randi() % 6 + 1
	var modified_roll: int = roll
	var detail_parts: Array = []

	# Add Savvy ability score
	var savvy: int = crew_member.get("savvy", 0) as int
	if savvy != 0:
		modified_roll += savvy
		detail_parts.append("+%d Savvy" % savvy)

	# +1 if Engineer class (Core Rules p.78)
	var char_class: String = str(crew_member.get("character_class", ""))
	if char_class.to_lower() == "engineer":
		modified_roll += 1
		detail_parts.append("+1 Engineer")

	# Credit spending for spare parts (+1 per credit)
	var task_id: String = result.get("task_id", "repair_kit")
	var credits_spent: int = credits_spent_on_tasks.get(task_id, 0)
	if credits_spent > 0:
		modified_roll += credits_spent
		detail_parts.append("+%d spare parts" % credits_spent)
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm:
			gsm.remove_credits(credits_spent)

	result.roll = roll
	result.modified_roll = modified_roll
	result.target = 6

	var modifier_text = ", ".join(detail_parts) if detail_parts.size() > 0 else ""
	var roll_text = "Roll %d" % roll
	if modifier_text != "":
		roll_text += " %s" % modifier_text

	# Natural 1 always fails AND item becomes unfixable (Core Rules p.78)
	if roll == 1:
		result.success = false
		result.reward = "CRITICAL FAIL - Item is beyond repair!"
		result.details = "%s = %d vs 6. Natural 1: UNFIXABLE" % [roll_text, modified_roll]
	elif modified_roll >= 6:
		result.success = true
		result.reward = "Item repaired"
		result.details = "%s = %d vs 6. Repaired!" % [roll_text, modified_roll]
	else:
		result.success = false
		result.reward = "Repair failed - try again next turn"
		result.details = "%s = %d vs 6. Failed" % [roll_text, modified_roll]

	return result

func _get_trade_table_result(roll: int) -> Dictionary:
	## Get result from Trade Table (Core Rules p.79) — loaded from JSON via DataManager
	var dm: Node = get_node_or_null("/root/DataManager")
	if dm and dm.has_method("get_trade_table_result"):
		var json_result: Dictionary = dm.get_trade_table_result(roll)
		if not json_result.is_empty():
			var result: Dictionary = _build_result_from_json(json_result)
			_apply_runtime_rolls_trade(result, roll)
			return result
	# Fallback: return minimal result if DataManager unavailable
	push_warning("CrewTaskComponent: DataManager unavailable for trade table lookup (roll %d)" % roll)
	return {"name": "Unknown Trade Result", "effect": "DataManager unavailable", "credits": 0, "xp": 0, "items": [], "story_points": 0, "deferred_trigger": "", "single_use": false, "requires_roll": false, "roll_info": ""}

func _get_exploration_table_result(roll: int) -> Dictionary:
	## Get result from Exploration Table (Core Rules p.80) — loaded from JSON via DataManager
	var dm: Node = get_node_or_null("/root/DataManager")
	if dm and dm.has_method("get_exploration_table_result"):
		var json_result: Dictionary = dm.get_exploration_table_result(roll)
		if not json_result.is_empty():
			var result: Dictionary = _build_result_from_json(json_result)
			_apply_runtime_rolls_exploration(result, roll)
			return result
	push_warning("CrewTaskComponent: DataManager unavailable for exploration table lookup (roll %d)" % roll)
	return {"name": "Unknown Exploration Result", "effect": "DataManager unavailable", "credits": 0, "xp": 0, "items": [], "story_points": 0, "deferred_trigger": "", "single_use": false, "requires_roll": false, "roll_info": "", "sick_bay_turns": 0, "rumor": false, "rival": false, "patron": false}

func _build_result_from_json(json_entry: Dictionary) -> Dictionary:
	## Convert a JSON table entry into the standard result Dictionary format
	var result: Dictionary = {
		"name": str(json_entry.get("name", "")),
		"effect": str(json_entry.get("effect", "")),
		"credits": json_entry.get("credits", 0) as int,
		"xp": json_entry.get("xp", 0) as int,
		"items": [],
		"story_points": json_entry.get("story_points", 0) as int,
		"deferred_trigger": str(json_entry.get("deferred_trigger", "")),
		"single_use": json_entry.get("single_use", false),
		"requires_roll": json_entry.get("requires_roll", false),
		"roll_info": str(json_entry.get("roll_info", "")),
		# Exploration-specific fields
		"sick_bay_turns": json_entry.get("sick_bay_turns", 0) as int,
		"rumor": json_entry.get("rumor", false),
		"rival": json_entry.get("rival", false),
		"patron": json_entry.get("patron", false),
	}
	# Copy items array (JSON stores as Array of Strings)
	var json_items: Array = json_entry.get("items", [])
	for item in json_items:
		result.items.append(str(item))

	# Pass through metadata fields for event processing
	# These drive species immunity, purchases, bonuses, and narrative effects
	for key in ["immune_species", "recruit", "track_rival", "kerin_bonus",
			"precursor_bonus", "engineer_bonus", "buy_rumors", "buy_weapons",
			"pay_or_lose"]:
		if json_entry.has(key):
			result[key] = json_entry[key]

	return result

func _apply_runtime_rolls_trade(result: Dictionary, roll: int) -> void:
	## Apply runtime dice rolls for Trade Table entries that have dynamic outcomes
	## These entries have requires_roll=true and need actual dice resolution
	var entry_name: String = result.get("name", "")

	match entry_name:
		"Worthless trinket", "Useless trinket":
			var d6: int = randi() % 6 + 1
			if d6 == 6:
				result.story_points = 1
				result.effect += " - Rolled %d: SUCCESS!" % d6
			else:
				result.effect += " - Rolled %d: No luck" % d6
		"Contraband":
			var d6: int = randi() % 6 + 1
			result.credits = d6
			if d6 >= 4:
				result.effect = "Earned %d credits, but gained a Rival!" % d6
				result.rival = true
			else:
				result.effect = "Earned %d credits safely" % d6
		"Tourist garbage":
			var d6: int = randi() % 6 + 1
			if d6 >= 5:
				result.story_points = 1
				result.effect += " - Rolled %d: +1 story point!" % d6
			else:
				result.effect += " - Rolled %d: Worthless" % d6
		"Fuel":
			# D6 roll happens in the dialog (ROLL_FOR_CREDITS) — don't pre-roll
			result.effect = "Roll D6 for credits worth of fuel to offset travel costs"
		"Odd device":
			var d6: int = randi() % 6 + 1
			result.credits = -1
			if d6 == 6:
				result.items = ["Loot (random)"]
				result.effect = "Paid 1 credit - Rolled %d: It works!" % d6
			else:
				result.effect = "Paid 1 credit - Rolled %d: Complete garbage" % d6
		"Starship repair parts":
			# D6 roll happens in the dialog (ROLL_FOR_CREDITS) — don't pre-roll
			result.effect = "Roll D6 for credits worth of Hull Point repair parts"

func _apply_runtime_rolls_exploration(result: Dictionary, roll: int) -> void:
	## Apply runtime dice rolls for Exploration Table entries with dynamic outcomes
	var entry_name: String = result.get("name", "")

	match entry_name:
		"I know a good deal":
			# Recursively roll on trade table
			var trade_roll: int = randi() % 100 + 1
			var trade_result: Dictionary = _get_trade_table_result(trade_roll)
			result.name = "Good Deal: " + trade_result.name
			result.effect = trade_result.effect
			result.credits = trade_result.credits
			result.xp = trade_result.xp
			result.items = trade_result.items
			result.story_points = trade_result.story_points
		"Had a nice chat":
			var d6: int = randi() % 6 + 1
			if d6 >= 5:
				result.story_points = 1
				result.effect = "Nice chat - Rolled %d: +1 story point!" % d6
			else:
				result.effect = "Nice chat - Rolled %d: Pleasant but unproductive" % d6
		"Possible bargain":
			var d6: int = randi() % 6 + 1
			if d6 == 6:
				result.items = ["Loot (random)"]
				result.effect = "Traded weapon - Rolled %d: Got something good!" % d6
			else:
				result.credits = 1
				result.effect = "Traded weapon - Rolled %d: Got 1 credit" % d6
		"Completely lost":
			var d6: int = randi() % 6 + 1
			if d6 >= 4:
				result.effect = "Got lost - Rolled %d: Found way back in time" % d6
			else:
				result.effect = "Got lost - Rolled %d: Unable to participate in battle" % d6
		"Tech fanatic":
			var d6: int = randi() % 6 + 1
			if d6 >= 5:
				result.effect = "Tech help - Rolled %d: Item repaired for free!" % d6
			else:
				result.effect = "Tech help - Rolled %d: No luck with repair" % d6
		"Get in a bad fight":
			var turns: int = (randi() % 3) + 1
			result.sick_bay_turns = turns
			result.effect = "Bad fight - %d turns in Sick Bay, lose one item" % turns

## Deferred Event System - cache events for future triggers
func _get_current_turn_number() -> int:
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	if cpm and cpm.has_method("get_turn_number"):
		return cpm.get_turn_number()
	return 0

func _cache_deferred_event(trigger_type: String, event_name: String, crew_id: String, effect: Dictionary) -> void:
	## Cache a deferred event that will trigger on a future condition.
	##
	## Trigger types from Core Rules:
	## - NEW_PLANET: Triggers when crew arrives at new planet
	## - NEXT_TURN: Triggers at start of next campaign turn
	## - THIS_BATTLE: Triggers during next battle
	## - ON_QUEST: Triggers when undertaking a quest
	## - ON_RECRUIT: Triggers when recruiting crew
	## - PERSISTENT: Remains until used (trade goods, spare parts)
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
		"turn_created": _get_current_turn_number(),
		"expires_turn": null, # null = never expires
		"consumed": false
	}

	# Handle expiration for certain trigger types
	if trigger_type == "NEXT_TURN":
		event.expires_turn = event.turn_created + 1

	# Add to campaign pending events via progress_data
	if "progress_data" in campaign:
		if not campaign.progress_data.has("pending_events"):
			campaign.progress_data["pending_events"] = []
		campaign.progress_data["pending_events"].append(event)
		pass # Cached deferred event
	elif campaign is Dictionary:
		if not campaign.has("pending_events"):
			campaign["pending_events"] = []
		campaign["pending_events"].append(event)
		pass # Cached deferred event (dict)
	else:
		push_warning("Cannot cache deferred event - no progress_data on campaign")

func _check_all_tasks_resolved() -> bool:
	## Check if all assigned tasks have been resolved
	for task_data: Dictionary in assigned_tasks.values():
		if not task_data.get("resolved", false):
			return false
	return true

func _calculate_success_rate() -> float:
	## Calculate success rate of completed tasks
	if completed_tasks.is_empty():
		return 0.0
	
	var successful_tasks: int = 0
	for result: Dictionary in completed_tasks:
		if result.get("success", false):
			successful_tasks += 1
	
	return float(successful_tasks) / float(completed_tasks.size()) * 100.0

## UI Updates
func _update_ui_state() -> void:
	## Update UI state based on current task assignments
	if assign_task_button:
		assign_task_button.disabled = all_tasks_resolved

	if resolve_all_button:
		resolve_all_button.disabled = assigned_tasks.is_empty() or all_tasks_resolved
		if all_tasks_resolved:
			resolve_all_button.text = "All Tasks Resolved"
		else:
			resolve_all_button.text = "Resolve All Tasks (%d)" % assigned_tasks.size()

	# Lock selection lists after resolution (no ItemList.disabled — use mouse_filter)
	if crew_member_list:
		crew_member_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if all_tasks_resolved else Control.MOUSE_FILTER_STOP
		crew_member_list.modulate.a = 0.5 if all_tasks_resolved else 1.0
	if available_tasks_list:
		available_tasks_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if all_tasks_resolved else Control.MOUSE_FILTER_STOP
		available_tasks_list.modulate.a = 0.5 if all_tasks_resolved else 1.0

func _update_progress_display() -> void:
	## Update progress display with task results
	if not progress_container:
		return

	# Clear existing progress display
	for child in progress_container.get_children():
		child.queue_free()

	# Summary header
	if completed_tasks.size() > 0:
		var success_count: int = 0
		var total_credits: int = 0
		var total_xp: int = 0
		for r in completed_tasks:
			if r.get("success", false):
				success_count += 1
			if r.has("table_result"):
				total_credits += r.table_result.get("credits", 0) as int
				total_xp += r.table_result.get("xp", 0) as int

		var summary_text = "Results: %d/%d succeeded" % [success_count, completed_tasks.size()]
		if total_credits > 0:
			summary_text += "  |  +%d credits" % total_credits
		if total_xp > 0:
			summary_text += "  |  +%d XP" % total_xp

		var summary_label = Label.new()
		summary_label.text = summary_text
		summary_label.add_theme_font_size_override("font_size", _scaled_font(16))
		if success_count == completed_tasks.size():
			summary_label.modulate = Color(0.063, 0.725, 0.506) # Emerald
		elif success_count > 0:
			summary_label.modulate = Color(0.851, 0.467, 0.024) # Orange
		else:
			summary_label.modulate = Color(0.863, 0.149, 0.149) # Red
		progress_container.add_child(summary_label)

		var summary_sep = HSeparator.new()
		summary_sep.modulate = Color(0.4, 0.6, 0.8)
		progress_container.add_child(summary_sep)

	# Show individual results
	for result in completed_tasks:
		var result_container = VBoxContainer.new()

		# Main result line
		var result_label = Label.new()
		var status_text = "✓" if result.success else "✗"
		var color = UIColors.COLOR_EMERALD if result.success else UIColors.COLOR_RED

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
			detail_label.modulate = Color(0.8, 0.8, 1.0) # Light blue
			result_container.add_child(detail_label)

			var effect_label = Label.new()
			effect_label.text = "      %s" % table_data.effect
			effect_label.modulate = Color(0.7, 0.7, 0.7) # Gray
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
				reward_label.modulate = Color(1.0, 0.9, 0.5) # Gold
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

## Choice Popup Flow — handles item choices from Trade/Explore task results

func _is_choice_item(item_string: String) -> bool:
	## Check if an item string contains OR-separated choices
	return " OR " in item_string

func _is_grenade_combination(item_string: String) -> bool:
	## Check if an item is the grenade combination special case
	return "Grenades" in item_string and ("Frakk" in item_string or "Dazzle" in item_string)

func _needs_player_input(item_string: String) -> bool:
	## Check if an item requires any form of player input (choice or grenade picker)
	return _is_choice_item(item_string) or _is_grenade_combination(item_string)

func _parse_choice_options(item_string: String) -> Array:
	## Split "A OR B OR C" into ["A", "B", "C"]
	var parts: Array = []
	for part in item_string.split(" OR "):
		parts.append(part.strip_edges())
	return parts

func _show_next_choice_popup() -> void:
	## Show the next pending choice popup, or finalize if none remain
	if _pending_choice_results.is_empty():
		_finalize_task_resolution()
		return

	var choice_data: Dictionary = _pending_choice_results[0]
	var choice_type: String = choice_data.get("type", "item_choice")

	# Auto-resolve mode: pick defaults without showing popup
	if _auto_resolve_mode:
		if choice_type == "grenade_combo":
			_on_grenades_chosen(3, 0, choice_data)
		else:
			var opts: Array = choice_data.get("options", [])
			var first: String = opts[0] if opts.size() > 0 else ""
			if not first.is_empty():
				_on_choice_made(first, choice_data)
			else:
				_pending_choice_results.erase(choice_data)
				_show_next_choice_popup()
		return

	if choice_type == "grenade_combo":
		var popup: Window = GrenadeCombinationPopupScript.new()
		popup.grenades_chosen.connect(
			_on_grenades_chosen.bind(choice_data)
		)
		add_child(popup)
		_choice_popup = popup
		popup.show_grenade_picker()
	else:
		var popup: Window = ItemChoicePopupScript.new()
		popup.item_chosen.connect(_on_choice_made.bind(choice_data))
		add_child(popup)
		_choice_popup = popup
		var result_name: String = ""
		if choice_data.result.has("table_result"):
			result_name = choice_data.result.table_result.get("name", "")
		popup.show_choices(
			result_name, choice_data.get("options", [])
		)

func _on_choice_made(item_name: String, choice_data: Dictionary) -> void:
	## Handle player's item choice — add to stash and advance queue
	_add_item_to_stash(item_name)

	# Replace "A OR B OR C" with chosen item name in the result for display
	var items: Array = choice_data.result.table_result.get("items", [])
	var idx: int = items.find(choice_data.item_string)
	if idx >= 0:
		items[idx] = item_name

	_pending_choice_results.erase(choice_data)
	_choice_popup = null
	_update_progress_display()
	_show_next_choice_popup()

func _on_grenades_chosen(
	frakk: int, dazzle: int, choice_data: Dictionary
) -> void:
	## Handle grenade combination choice — add grenades to stash
	for i in range(frakk):
		_add_item_to_stash("Frakk Grenade")
	for i in range(dazzle):
		_add_item_to_stash("Dazzle Grenade")

	# Update display text
	var items: Array = choice_data.result.table_result.get("items", [])
	var idx: int = items.find(choice_data.item_string)
	var summary: String = ""
	if frakk > 0:
		summary += "%dx Frakk" % frakk
	if dazzle > 0:
		if not summary.is_empty():
			summary += " + "
		summary += "%dx Dazzle" % dazzle
	if idx >= 0:
		items[idx] = summary

	_pending_choice_results.erase(choice_data)
	_choice_popup = null
	_update_progress_display()
	_show_next_choice_popup()

func _add_consumable_credits(pool_key: String, amount: int) -> void:
	## Store special-purpose credits in campaign progress_data.
	## Core Rules p.79: Fuel = offset travel costs. Repair parts = Hull Point repairs.
	## These are consumed when the relevant cost is paid, not general credits.
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.campaign or not "progress_data" in gs.campaign:
		# Fallback: add as general credits if no progress_data
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm:
			gsm.add_credits(amount)
		return
	var current: int = int(gs.campaign.progress_data.get(pool_key, 0))
	gs.campaign.progress_data[pool_key] = current + amount

func _add_item_to_stash(item_name: String) -> void:
	## Add an item to the ship stash via EquipmentManager
	## Resolves "(random)" items via loot table rolls first
	var equip_mgr: Node = get_node_or_null("/root/EquipmentManager")
	if not equip_mgr or not equip_mgr.has_method("add_equipment"):
		push_warning(
			"CrewTaskComponent: No EquipmentManager for '%s'" % item_name
		)
		return

	# Handle quantity prefixes like "2x Stim-pack"
	var quantity: int = 1
	var clean_name: String = item_name
	if item_name.begins_with("2x ") or item_name.begins_with("3x "):
		quantity = item_name.substr(0, 1).to_int()
		clean_name = item_name.substr(3)

	# Resolve random loot items
	if "(random" in clean_name:
		var is_damaged: bool = "damaged" in clean_name
		var resolved: Array = _resolve_random_loot(clean_name)
		for resolved_name in resolved:
			var item_dict: Dictionary = _lookup_equipment_from_db(
				equip_mgr, resolved_name
			)
			item_dict["id"] = "task_reward_%d_%d" % [
				Time.get_ticks_msec(), randi() % 10000
			]
			if is_damaged:
				item_dict["condition"] = "damaged"
			equip_mgr.add_equipment(item_dict)
		return

	# Standard item addition (with quantity support)
	for i in range(quantity):
		var item_dict: Dictionary = _lookup_equipment_from_db(
			equip_mgr, clean_name
		)
		item_dict["id"] = "task_reward_%d_%d" % [
			Time.get_ticks_msec(), randi() % 10000
		]
		if not equip_mgr.add_equipment(item_dict):
			push_warning(
				"CrewTaskComponent: Failed to add '%s' to stash"
				% clean_name
			)

func _lookup_equipment_from_db(
	equip_mgr: Node, item_name: String
) -> Dictionary:
	## Search EquipmentManager's loaded DB arrays by name
	for db_list in [
		equip_mgr._db_weapons,
		equip_mgr._db_armor,
		equip_mgr._db_gear
	]:
		for item in db_list:
			if item is Dictionary and item.get("name", "") == item_name:
				return item.duplicate()
	# Fallback: minimal dict for items not in DB
	return {"name": item_name}

## Loot Table Resolution — rolls on loot_tables.json subtables

var _loot_tables_cache: Dictionary = {}

func _get_loot_tables() -> Dictionary:
	## Load and cache loot_tables.json
	if not _loot_tables_cache.is_empty():
		return _loot_tables_cache
	var path := "res://data/loot_tables.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("CrewTaskComponent: Cannot open loot_tables.json")
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("CrewTaskComponent: Failed to parse loot_tables.json")
		return {}
	file.close()
	if json.data is Dictionary:
		_loot_tables_cache = json.data
	return _loot_tables_cache

func _resolve_random_loot(item_string: String) -> Array:
	## Resolve a "(random)" item string into actual item names
	## Returns Array of item name strings
	var tables: Dictionary = _get_loot_tables()
	if tables.is_empty():
		return [item_string] # Can't resolve, return as-is

	var all_tables: Dictionary = tables.get("tables", {})

	# Determine which subtable to roll on
	if item_string.begins_with("Gear Loot") or item_string == "Gear (random)":
		return [_roll_on_subtable(all_tables.get("gear_subtable", []))]
	elif item_string.begins_with("Gadget"):
		# Gadgets are gun_mods + gun_sights from gear subtable
		var gear_sub: Array = all_tables.get("gear_subtable", [])
		var gadget_items: Array = []
		for entry in gear_sub:
			if entry is Dictionary:
				var cat: String = str(entry.get("category", ""))
				if cat in ["gun_mods", "gun_sights"]:
					var items: Array = entry.get("items", [])
					gadget_items.append_array(items)
		if gadget_items.size() > 0:
			return [gadget_items[randi() % gadget_items.size()]]
		return [item_string]
	elif item_string.begins_with("Low Tech Weapon"):
		# Low Tech weapons are melee from weapon subtable
		var wpn_sub: Array = all_tables.get("weapon_subtable", [])
		for entry in wpn_sub:
			if entry is Dictionary and entry.get("category") == "melee_weapons":
				var items: Array = entry.get("items", [])
				if items.size() > 0:
					return [items[randi() % items.size()]]
		return [item_string]
	else:
		# Full loot table: roll D100 on main, then roll on subtable
		return _roll_main_loot_table(all_tables)

func _roll_main_loot_table(all_tables: Dictionary) -> Array:
	## Roll on the main loot table and resolve to actual items
	var main_table: Array = all_tables.get("main_loot", [])
	var roll: int = randi() % 100 + 1
	var category: String = ""
	var count: int = 1

	for entry in main_table:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if r.size() >= 2 and roll >= (r[0] as int) and roll <= (r[1] as int):
				category = str(entry.get("category", ""))
				count = entry.get("count", 1) as int
				break

	var results: Array = []
	match category:
		"WEAPON", "DAMAGED_WEAPONS":
			var sub: Array = all_tables.get("weapon_subtable", [])
			for i in range(count):
				results.append(_roll_on_subtable(sub))
		"GEAR", "DAMAGED_GEAR":
			var sub: Array = all_tables.get("gear_subtable", [])
			for i in range(count):
				results.append(_roll_on_subtable(sub))
		"ODDS_AND_ENDS":
			var sub: Array = all_tables.get("odds_and_ends_subtable", [])
			results.append(_roll_on_subtable(sub))
		"REWARDS":
			# Rewards give credits/rumors, not equipment items
			var sub: Array = all_tables.get("rewards_subtable", [])
			var reward: Dictionary = _roll_on_reward_subtable(sub)
			if reward.get("credits", 0) > 0:
				var gsm: Node = get_node_or_null("/root/GameStateManager")
				if gsm and gsm.has_method("add_credits"):
					gsm.add_credits(reward.credits)
			# Rewards don't produce stash items
			return []
		_:
			return ["Loot (unknown category)"]

	return results

func _roll_on_subtable(subtable: Array) -> String:
	## Roll D100 on a loot subtable and return a random item name
	var roll: int = randi() % 100 + 1
	for entry in subtable:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if r.size() >= 2 and roll >= (r[0] as int) and roll <= (r[1] as int):
				var items: Array = entry.get("items", [])
				if items.size() > 0:
					return str(items[randi() % items.size()])
				var item: String = str(entry.get("item", ""))
				if not item.is_empty():
					return item
	return "Unknown Loot"

func _roll_on_reward_subtable(subtable: Array) -> Dictionary:
	## Roll on reward subtable — returns credits/rumors dict
	var roll: int = randi() % 100 + 1
	for entry in subtable:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if r.size() >= 2 and roll >= (r[0] as int) and roll <= (r[1] as int):
				return entry.duplicate()
	return {}

## Event Handlers
func _on_crew_member_selected(index: int) -> void:
	## Handle crew member selection
	_update_ui_state()

func _on_task_selected(index: int) -> void:
	## Handle task selection
	_update_ui_state()

func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "crew_tasks":
		pass

func _on_automation_toggled(data: Dictionary) -> void:
	## Handle automation toggle - auto-assign and resolve tasks
	## When automated, choice items auto-pick the first option (no popup shown)
	var automation_enabled = data.get("enabled", false)
	if automation_enabled and not assigned_tasks.is_empty():
		_auto_resolve_mode = true
		_on_resolve_all_pressed()
		_auto_resolve_mode = false

## Public API for integration
func are_tasks_completed() -> bool:
	## Check if all crew tasks are completed
	return all_tasks_resolved and not assigned_tasks.is_empty()

func is_tasks_completed() -> bool:
	## Alias for are_tasks_completed() - matches controller API
	return are_tasks_completed()

func get_task_results() -> Array:
	## Get results of all completed tasks
	return completed_tasks.duplicate()

func get_assigned_task_count() -> int:
	## Get number of currently assigned tasks
	return assigned_tasks.size()

func reset_crew_tasks() -> void:
	## Reset crew tasks for new turn
	assigned_tasks.clear()
	completed_tasks.clear()
	task_assignments.clear()
	credits_spent_on_tasks.clear()
	all_tasks_resolved = false
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()

func complete_crew_task_phase() -> void:
	## Mark the crew task phase as complete and publish event
	if not all_tasks_resolved and not assigned_tasks.is_empty():
		_auto_resolve_mode = true # Auto-pick choices when force-completing
		_on_resolve_all_pressed()
		_auto_resolve_mode = false

	# Don't publish phase completion if events are still pending
	if not _event_queue.is_empty() or _current_event_dialog != null:
		push_warning("CrewTaskComponent: Cannot complete phase — events still pending")
		return

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "crew_tasks",
			"tasks_completed": completed_tasks.size(),
			"success_rate": _calculate_success_rate()
		})


func spend_credits_on_task(task_id: String, amount: int) -> bool:
	## Spend credits on a task for bonus modifier
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
		return false

	var current_spent = credits_spent_on_tasks.get(task_id, 0)
	var total = current_spent + amount

	if total > max_bonus:
		return false

	# Check GameStateManager has enough credits and deduct
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		var available_credits = game_state_manager.get_credits()
		if available_credits < amount:
			push_warning("CrewTaskComponent: Not enough credits (%d available, need %d)" % [available_credits, amount])
			return false
		if not game_state_manager.remove_credits(amount):
			return false

	credits_spent_on_tasks[task_id] = total
	pass # Credits spent on task
	return true

## Helper function to apply XP to a character
func _apply_xp_to_character(crew_member: Dictionary, amount: int, source: String) -> void:
	## Apply XP to a character and persist to GameStateManager
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
	# Try direct lookup first (FiveParsecsCampaignCore has get_crew_member_by_id)
	if campaign.has_method("get_crew_member_by_id"):
		var character = campaign.get_crew_member_by_id(character_id)
		if character:
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
			pass # XP applied to character
			return

	# Fallback: iterate crew list
	var crew = []
	if campaign.has_method("get_crew_members"):
		crew = campaign.get_crew_members()
	elif campaign is Dictionary:
		crew = campaign.get("crew", [])

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

			pass # XP applied to character
			return

	push_warning("CrewTaskComponent: Character %s not found in crew" % character_id)

# ══════════════════════════════════════════════════════════════════════
# EVENT QUEUE SYSTEM — Interactive dialogs for crew task results
# ══════════════════════════════════════════════════════════════════════

func _build_event_queue() -> void:
	## Scan completed_tasks and build event descriptors for each table result.
	## Each descriptor drives a CrewTaskEventDialog instance.
	_event_queue.clear()

	for result in completed_tasks:
		if not result.has("table_result"):
			continue

		var tr: Dictionary = result.table_result
		var crew_id: String = str(result.get("crew_id", ""))
		var crew_name: String = str(result.get("crew_name", ""))
		var task_type: String = str(result.get("task_name", ""))
		var crew_member = _get_crew_member_by_id(crew_id)

		# Base event data shared by all types
		var base := {
			"crew_id": crew_id,
			"crew_name": crew_name,
			"crew_member": crew_member,
			"task_type": task_type,
			"event_name": tr.get("name", "Event"),
			"effect_text": tr.get("effect", ""),
			"table_result": tr,
			"result_ref": result,
		}

		# Check species immunity first
		if _check_species_immunity(tr, crew_member):
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.IMMUNE
			_event_queue.append(event)
			continue

		# Detect event type(s) from result fields — build events in order
		var events: Array[Dictionary] = _classify_result(base, tr, crew_member)
		_event_queue.append_array(events)

func _classify_result(base: Dictionary, tr: Dictionary, crew_member) -> Array[Dictionary]:
	## Classify a single table result into one or more event descriptors.
	var events: Array[Dictionary] = []
	var event_name: String = str(tr.get("name", ""))

	# ── Deferred events (show info badge, already cached by _resolve_table_task) ──
	var deferred: String = str(tr.get("deferred_trigger", ""))
	if not deferred.is_empty():
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.DEFERRED
		event["deferred_trigger"] = deferred
		events.append(event)
		return events # Deferred events don't have immediate effects

	# ── Runtime roll events (requires_roll=true, already resolved by _apply_runtime_rolls) ──
	# These were pre-rolled — show the result in the dialog
	var requires_roll: bool = tr.get("requires_roll", false)

	# ── Check for specific named events with complex behavior ──
	match event_name:
		"A chance to unload some stuff":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.SELL_WEAPONS
			event["credits_per_item"] = 2
			event["equipment"] = _get_crew_weapons(crew_member)
			events.append(event)
			return events

		"Gambling problem":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.DISCARD_ITEM
			event["equipment"] = _get_crew_equipment(crew_member)
			events.append(event)
			return events

		"Get in a bad fight":
			# Compound: sick bay + discard
			var sick_event := base.duplicate()
			sick_event["type"] = CrewTaskEventDialog.EventType.SICK_BAY
			sick_event["sick_bay_turns"] = tr.get("sick_bay_turns", 1)
			events.append(sick_event)
			var discard_event := base.duplicate()
			discard_event["type"] = CrewTaskEventDialog.EventType.DISCARD_ITEM
			discard_event["equipment"] = _get_crew_equipment(crew_member)
			discard_event["event_name"] = "Get in a bad fight — Lose an item"
			events.append(discard_event)
			return events

		"Contraband":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS_RISK
			events.append(event)
			return events

		"Possible bargain":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ITEM_TRADE
			event["trade_type"] = "weapon"
			event["equipment"] = _get_crew_weapons(crew_member)
			events.append(event)
			return events

		"Alien merchant":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ITEM_TRADE
			event["trade_type"] = "item"
			event["equipment"] = _get_crew_equipment(crew_member)
			events.append(event)
			return events

		"This place is rather nice, really":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.PAY_OR_LOSE
			event["pay_or_lose_data"] = tr.get("pay_or_lose", {"cost": "1 story point", "penalty": "crew member leaves"})
			events.append(event)
			return events

		"Tech fanatic":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.TECH_FANATIC
			var char_class: String = _get_crew_class(crew_member)
			event["is_engineer"] = char_class.to_lower() == "engineer"
			var equip: Array = _get_crew_equipment(crew_member)
			if equip.size() > 0:
				event["random_damaged_item"] = equip[randi() % equip.size()]
			events.append(event)
			return events

		"Completely lost":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.SKILL_CHECK
			event["stat_name"] = "Savvy"
			event["stat_modifier"] = _get_crew_stat(crew_member, "savvy")
			event["success_threshold"] = 4
			event["failure_text"] = "Lost — will miss the battle this turn"
			events.append(event)
			return events

		"Odd device":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.CONDITIONAL_PURCHASE
			event["purchase_cost"] = 1
			events.append(event)
			return events

		"Don't usually see these for sale":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.CONDITIONAL_PURCHASE
			event["purchase_cost"] = 3
			events.append(event)
			return events

	# ── Check for buy_rumors / buy_weapons metadata ──
	if tr.has("buy_rumors"):
		var buy_data: Dictionary = tr.get("buy_rumors", {})
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.BUY_RUMORS
		event["max_quantity"] = buy_data.get("max", 3)
		event["cost_each"] = buy_data.get("cost_each", 2)
		events.append(event)
		return events

	if tr.has("buy_weapons"):
		var buy_data: Dictionary = tr.get("buy_weapons", {})
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.BUY_WEAPONS
		event["max_quantity"] = buy_data.get("max_rolls", 3)
		event["cost_each"] = buy_data.get("cost_each", 3)
		events.append(event)
		return events

	# ── Check for items with OR choices ──
	var items: Array = tr.get("items", [])
	for item_str in items:
		var s: String = str(item_str)
		if "Grenades" in s and ("Frakk" in s or "Dazzle" in s):
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.GRENADE_COMBO
			events.append(event)
			return events
		elif " OR " in s:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.CHOICE_ITEM
			event["choice_options"] = _parse_choice_options(s)
			event["choice_item_string"] = s
			events.append(event)
			return events

	# ── Items with (random) — roll on table ──
	for item_str in items:
		var s: String = str(item_str)
		if "(random" in s:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_ON_TABLE
			event["items_to_resolve"] = [s]
			events.append(event)
			return events

	# ── Roll-based events ──
	if requires_roll:
		var credits: int = tr.get("credits", 0)
		var sp: int = tr.get("story_points", 0)

		# Events where the dialog IS the roll (not pre-rolled)
		if event_name in ["Fuel", "Starship repair parts"]:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS
			events.append(event)
			return events

		# Pre-resolved roll events — show results
		if credits != 0 and sp == 0:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS
			event["credits"] = credits
			events.append(event)
		elif sp != 0 or event_name in ["Worthless trinket", "Useless trinket", "Tourist garbage", "Had a nice chat"]:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_BONUS
			event["story_points"] = sp
			events.append(event)
		else:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.INFO_ONLY
			events.append(event)
		# Also check for rival flag from roll results (e.g., contraband)
		if tr.get("rival", false):
			var rival_event := base.duplicate()
			rival_event["type"] = CrewTaskEventDialog.EventType.GAIN_RIVAL
			rival_event["event_name"] = event_name + " — Rival"
			events.append(rival_event)
		return events

	# ── Simple non-choice items — roll on table silently ──
	if items.size() > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.ROLL_ON_TABLE
		event["items_to_resolve"] = items
		events.append(event)
		return events

	# ── Narrative flags ──
	if tr.get("recruit", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.RECRUIT
		events.append(event)
		return events

	if tr.get("patron", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_PATRON
		events.append(event)
		return events

	if tr.get("rival", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_RIVAL
		event["kerin_bonus"] = str(tr.get("kerin_bonus", ""))
		events.append(event)
		return events

	if tr.get("rumor", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_RUMOR
		event["precursor_bonus"] = str(tr.get("precursor_bonus", ""))
		events.append(event)
		return events

	if tr.get("sick_bay_turns", 0) > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.SICK_BAY
		event["sick_bay_turns"] = tr.get("sick_bay_turns", 1)
		events.append(event)
		return events

	# ── Static resource gains ──
	var credits: int = tr.get("credits", 0)
	var xp: int = tr.get("xp", 0)
	var sp: int = tr.get("story_points", 0)

	if credits > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_CREDITS
		event["credits"] = credits
		events.append(event)
	if xp > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_XP
		event["xp"] = xp
		events.append(event)
	if sp > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_STORY_POINT
		event["story_points"] = sp
		events.append(event)

	# If nothing matched, show as info only
	if events.is_empty():
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.INFO_ONLY
		events.append(event)

	return events

# ── Event Queue Processing ────────────────────────────────────────────

func _process_event_queue() -> void:
	## Start processing the event queue — shows first dialog
	if _event_queue.is_empty():
		_finalize_task_resolution()
		return
	_show_next_event_dialog()

func _show_next_event_dialog() -> void:
	## Pop front of queue and show dialog, or finalize if empty
	# Clean up any lingering dialog to avoid exclusive window conflicts
	if _current_event_dialog and is_instance_valid(_current_event_dialog):
		_current_event_dialog.queue_free()
		_current_event_dialog = null

	if _event_queue.is_empty():
		_finalize_task_resolution()
		return

	var event_data: Dictionary = _event_queue.pop_front()

	# Auto-resolve mode: skip dialogs, apply defaults
	if _auto_resolve_mode:
		_auto_resolve_event(event_data)
		_show_next_event_dialog()
		return

	var dialog: Window = CrewTaskEventDialogScript.new()
	dialog.event_completed.connect(_on_event_completed.bind(event_data))
	add_child(dialog)
	_current_event_dialog = dialog
	dialog.show_event(event_data)

func _on_event_completed(outcome: Dictionary, event_data: Dictionary) -> void:
	## Apply game state changes based on event outcome, then process next event
	if _current_event_dialog and is_instance_valid(_current_event_dialog):
		_current_event_dialog.queue_free()
	_current_event_dialog = null
	var event_type: int = event_data.get("type", CrewTaskEventDialog.EventType.INFO_ONLY)
	var crew_member = event_data.get("crew_member")
	var gsm = get_node_or_null("/root/GameStateManager")

	match event_type:
		CrewTaskEventDialog.EventType.GAIN_CREDITS:
			var credits: int = event_data.get("credits", 0)
			if credits > 0 and gsm:
				gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.GAIN_XP:
			var xp: int = event_data.get("xp", 0)
			if xp > 0:
				_apply_xp_to_character(
					event_data.get("table_result", {}),
					xp,
					"crew_task_event"
				)

		CrewTaskEventDialog.EventType.GAIN_STORY_POINT:
			var sp: int = event_data.get("story_points", 0)
			if sp > 0 and gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(sp)

		CrewTaskEventDialog.EventType.ROLL_FOR_BONUS:
			var sp: int = outcome.get("story_points", 0)
			if sp > 0 and gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(sp)

		CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS:
			var credits: int = outcome.get("credits", 0)
			var event_name_str: String = str(event_data.get("event_name", ""))
			if credits > 0:
				if event_name_str == "Fuel":
					# Core Rules p.79: Fuel offsets travel costs, not general credits
					_add_consumable_credits("fuel_credits", credits)
				elif event_name_str == "Starship repair parts":
					# Core Rules p.79: Repair parts only for Hull Point damage
					_add_consumable_credits("repair_part_credits", credits)
				elif gsm:
					gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS_RISK:
			if not outcome.get("declined", false):
				var credits: int = outcome.get("credits", 0)
				if credits > 0 and gsm:
					gsm.add_credits(credits)
				# Rival is handled by the roll — check if roll >= 4
				# The dialog stores this in the outcome
				if outcome.get("rival", false):
					_apply_rival(event_data)

		CrewTaskEventDialog.EventType.ROLL_ON_TABLE:
			# Resolve loot items and add to stash
			var items_to_resolve: Array = event_data.get("items_to_resolve", [])
			for item_str in items_to_resolve:
				_add_item_to_stash(str(item_str))

		CrewTaskEventDialog.EventType.CONDITIONAL_PURCHASE:
			if outcome.get("purchased", false):
				var cost: int = event_data.get("purchase_cost", 0)
				if gsm:
					gsm.remove_credits(cost)
				# Roll on loot table (the dialog signals roll_requested)
				_add_item_to_stash("Loot (random)")

		CrewTaskEventDialog.EventType.CHOICE_ITEM:
			var item_name: String = str(outcome.get("item_name", ""))
			if not item_name.is_empty():
				_add_item_to_stash(item_name)

		CrewTaskEventDialog.EventType.GRENADE_COMBO:
			var frakk: int = outcome.get("frakk", 0)
			var dazzle: int = outcome.get("dazzle", 0)
			for i in range(frakk):
				_add_item_to_stash("Frakk Grenade")
			for i in range(dazzle):
				_add_item_to_stash("Dazzle Grenade")

		CrewTaskEventDialog.EventType.DISCARD_ITEM:
			var discarded: String = str(outcome.get("discarded_item", ""))
			if not discarded.is_empty():
				_remove_from_crew_equipment(crew_member, discarded)

		CrewTaskEventDialog.EventType.SELL_WEAPONS:
			var sold: Array = outcome.get("sold_items", [])
			for item in sold:
				_remove_from_crew_equipment(crew_member, str(item))
			var credits: int = outcome.get("credits", 0)
			if credits > 0 and gsm:
				gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.SICK_BAY:
			var turns: int = event_data.get("sick_bay_turns", 1)
			_apply_sick_bay(crew_member, turns)

		CrewTaskEventDialog.EventType.GAIN_RIVAL:
			_apply_rival(event_data)

		CrewTaskEventDialog.EventType.GAIN_RUMOR:
			_apply_rumor(event_data, outcome)

		CrewTaskEventDialog.EventType.GAIN_PATRON:
			_generate_and_add_patron(1)

		CrewTaskEventDialog.EventType.RECRUIT:
			if outcome.get("recruit", false):
				_apply_recruit()

		CrewTaskEventDialog.EventType.BUY_RUMORS:
			var qty: int = outcome.get("quantity", 0)
			var total_cost: int = outcome.get("total_cost", 0)
			if total_cost > 0 and gsm:
				gsm.remove_credits(total_cost)
			for i in range(qty):
				_apply_rumor(event_data, {})

		CrewTaskEventDialog.EventType.BUY_WEAPONS:
			var qty: int = outcome.get("quantity", 0)
			var total_cost: int = outcome.get("total_cost", 0)
			if total_cost > 0 and gsm:
				gsm.remove_credits(total_cost)
			for i in range(qty):
				var weapon: String = _roll_on_military_weapons_table()
				_add_item_to_stash(weapon)

		CrewTaskEventDialog.EventType.SKILL_CHECK:
			if not outcome.get("success", true):
				# Failed skill check — apply penalty
				if crew_member:
					if crew_member is Dictionary:
						crew_member["misses_battle"] = true
					elif "misses_battle" in crew_member:
						crew_member.misses_battle = true

		CrewTaskEventDialog.EventType.ITEM_TRADE:
			if outcome.get("traded", false):
				var traded_item: String = str(outcome.get("traded_item", ""))
				if not traded_item.is_empty():
					_remove_from_crew_equipment(crew_member, traded_item)
				# Roll result handled by dialog → roll_requested
				# For "Possible bargain": roll already determined credits vs loot
				var credits: int = outcome.get("credits", 0)
				if credits > 0 and gsm:
					gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.PAY_OR_LOSE:
			if outcome.get("paid", false):
				if gsm and gsm.has_method("modify_story_progress"):
					gsm.modify_story_progress(-1)
			elif outcome.get("crew_lost", false):
				_remove_crew_member(crew_member, event_data.get("crew_id", ""))

		CrewTaskEventDialog.EventType.TECH_FANATIC:
			if outcome.get("engineer_bonus", false):
				_apply_xp_to_character(
					event_data.get("table_result", {}),
					2,
					"tech_fanatic_engineer"
				)
			# Damage/repair handled by dialog outcome

	_update_progress_display()
	# Defer to next frame so queue_free() clears the old exclusive dialog first
	call_deferred("_show_next_event_dialog")

func _auto_resolve_event(event_data: Dictionary) -> void:
	## Auto-resolve an event without showing dialog — sensible defaults
	var event_type: int = event_data.get("type", CrewTaskEventDialog.EventType.INFO_ONLY)
	var gsm = get_node_or_null("/root/GameStateManager")
	var crew_member = event_data.get("crew_member")

	match event_type:
		CrewTaskEventDialog.EventType.GAIN_CREDITS:
			var credits: int = event_data.get("credits", 0)
			if credits > 0 and gsm:
				gsm.add_credits(credits)
		CrewTaskEventDialog.EventType.GAIN_XP:
			var xp: int = event_data.get("xp", 0)
			if xp > 0:
				_apply_xp_to_character(event_data.get("table_result", {}), xp, "auto")
		CrewTaskEventDialog.EventType.GAIN_STORY_POINT:
			var sp: int = event_data.get("story_points", 0)
			if sp > 0 and gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(sp)
		CrewTaskEventDialog.EventType.ROLL_ON_TABLE:
			for item_str in event_data.get("items_to_resolve", []):
				_add_item_to_stash(str(item_str))
		CrewTaskEventDialog.EventType.CHOICE_ITEM:
			var opts: Array = event_data.get("choice_options", [])
			if opts.size() > 0:
				_add_item_to_stash(str(opts[0]))
		CrewTaskEventDialog.EventType.GRENADE_COMBO:
			for i in range(3):
				_add_item_to_stash("Frakk Grenade")
		CrewTaskEventDialog.EventType.GAIN_RIVAL:
			_apply_rival(event_data)
		CrewTaskEventDialog.EventType.GAIN_RUMOR:
			_apply_rumor(event_data, {})
		CrewTaskEventDialog.EventType.GAIN_PATRON:
			_generate_and_add_patron(1)
		CrewTaskEventDialog.EventType.SICK_BAY:
			_apply_sick_bay(crew_member, event_data.get("sick_bay_turns", 1))
		# Skip interactive types in auto mode (no selling, no discarding, no purchases)

# ── State Mutation Helpers ────────────────────────────────────────────

func _check_species_immunity(table_result: Dictionary, crew_member) -> bool:
	## Check if crew member's species makes them immune to this result
	var immune_list: Array = table_result.get("immune_species", [])
	if immune_list.is_empty():
		return false
	var species_name: String = _get_species_name(crew_member)
	for immune_species in immune_list:
		if str(immune_species).to_lower() == species_name.to_lower():
			return true
	return false

func _get_crew_member_by_id(crew_id: String):
	## Find crew member in crew_data by character_id
	for member in crew_data:
		var mid: String = ""
		if member is Dictionary:
			mid = str(member.get("character_id", member.get("id", "")))
		elif member is Object and "character_id" in member:
			mid = str(member.character_id)
		elif member is Object and "id" in member:
			mid = str(member.id)
		if mid == crew_id:
			return member
	return null

func _get_species_name(crew_member) -> String:
	## Get species/origin name as string from crew member (Object or Dict)
	if crew_member == null:
		return ""
	var origin = null
	if crew_member is Dictionary:
		origin = crew_member.get("origin", crew_member.get("species", ""))
	elif crew_member is Object:
		if "origin" in crew_member:
			origin = crew_member.origin
		elif "species" in crew_member:
			origin = crew_member.species
	if origin == null:
		return ""
	# Handle enum ordinal → string
	if origin is int:
		var keys: Array = GlobalEnums.Origin.keys()
		if origin >= 0 and origin < keys.size():
			return str(keys[origin])
		return ""
	return str(origin)

func _get_crew_equipment(crew_member) -> Array:
	## Get equipment array from crew member
	if crew_member == null:
		return []
	if crew_member is Dictionary:
		var equip = crew_member.get("equipment", [])
		return equip.duplicate() if equip is Array else []
	if crew_member is Object and "equipment" in crew_member:
		return crew_member.equipment.duplicate()
	return []

func _get_crew_weapons(crew_member) -> Array:
	## Get only weapon items from crew member's equipment
	var all_equip: Array = _get_crew_equipment(crew_member)
	var weapons: Array = []
	for item_name in all_equip:
		if _is_weapon(str(item_name)):
			weapons.append(item_name)
	return weapons

func _is_weapon(item_name: String) -> bool:
	## Check if item name is a weapon (matches Character.weapons getter heuristic)
	var lower: String = item_name.to_lower()
	for keyword in ["weapon", "rifle", "pistol", "blade", "gun", "sword",
			"flamer", "cannon", "laser", "saber", "axe", "maul", "claw"]:
		if keyword in lower:
			return true
	return false

func _get_crew_class(crew_member) -> String:
	## Get character class as string
	if crew_member == null:
		return ""
	if crew_member is Dictionary:
		return str(crew_member.get("character_class", crew_member.get("class", "")))
	if crew_member is Object and "character_class" in crew_member:
		return str(crew_member.character_class)
	return ""

func _get_crew_stat(crew_member, stat_name: String) -> int:
	## Get a stat value from crew member
	if crew_member == null:
		return 0
	if crew_member is Dictionary:
		return crew_member.get(stat_name, 0) as int
	if crew_member is Object and stat_name in crew_member:
		return crew_member.get(stat_name) as int
	return 0

func _remove_from_crew_equipment(crew_member, item_name: String) -> void:
	## Remove an item by name from crew member's equipment array
	if crew_member == null:
		return
	if crew_member is Dictionary:
		var equip: Array = crew_member.get("equipment", [])
		if item_name in equip:
			equip.erase(item_name)
	elif crew_member is Object and "equipment" in crew_member:
		if item_name in crew_member.equipment:
			crew_member.equipment.erase(item_name)

func _apply_sick_bay(crew_member, turns: int) -> void:
	## Place crew member in sick bay
	if crew_member == null:
		return
	if crew_member is Dictionary:
		crew_member["in_sick_bay"] = true
		crew_member["sick_bay_turns_remaining"] = turns
		crew_member["status"] = "injured"
	elif crew_member is Object:
		if "status" in crew_member:
			crew_member.status = "injured"
		if "in_sick_bay" in crew_member:
			crew_member.in_sick_bay = true

func _apply_rival(event_data: Dictionary) -> void:
	## Add a rival to the campaign via NPCTracker
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	var rival_types: Array = ["Criminal", "Corporate", "Military", "Pirate", "Cult"]
	var rival_data: Dictionary = {
		"rival_id": "rival_task_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
		"name": "Rival %d" % (randi() % 100 + 1),
		"type": rival_types[randi() % rival_types.size()],
		"source": "crew_task",
		"hostility": randi() % 3 + 3,
		"resources": randi() % 3 + 1,
	}
	var kerin_bonus: String = str(event_data.get("kerin_bonus", ""))
	if not kerin_bonus.is_empty():
		rival_data["kerin_bonus"] = kerin_bonus

	if npc_tracker and npc_tracker.has_method("add_rival"):
		npc_tracker.add_rival(rival_data)
	else:
		# Fallback: add directly to campaign
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.current_campaign:
			var campaign = gs.current_campaign
			if campaign is Dictionary:
				if not campaign.has("rivals"):
					campaign["rivals"] = []
				campaign["rivals"].append(rival_data)
			elif "rivals" in campaign:
				campaign.rivals.append(rival_data)

func _apply_rumor(event_data: Dictionary, outcome: Dictionary) -> void:
	## Add a quest rumor to the campaign
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		return
	var campaign = gs.current_campaign
	var rumor_types: Array = [
		"An extracted data file", "An extracted data file",
		"Notebook with secret information", "Notebook with secret information",
		"Old map showing a location", "Old map showing a location",
		"A tip from a contact", "A tip from a contact",
		"An intercepted transmission", "An intercepted transmission"
	]
	var rumor_roll: int = randi() % 10
	var new_rumor: Dictionary = {
		"id": "rumor_task_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
		"type": rumor_roll + 1,
		"description": rumor_types[rumor_roll],
		"source": "crew_task",
		"created_turn": _get_current_turn_number()
	}
	if campaign is Dictionary:
		if not campaign.has("rumors"):
			campaign["rumors"] = []
		campaign["rumors"].append(new_rumor)
	elif "rumors" in campaign:
		campaign.rumors.append(new_rumor)

func _apply_recruit() -> void:
	## Recruit a new crew member
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		push_warning("CrewTaskComponent: Cannot recruit — no campaign")
		return
	var campaign = gs.current_campaign

	# Check crew size limit
	var crew_size: int = 0
	if campaign.has_method("get_crew_size"):
		crew_size = campaign.get_crew_size()
	if crew_size >= 8:
		push_warning("CrewTaskComponent: Crew is full (8 members)")
		return

	# Generate new character via CharacterGeneration
	var CharGen = load("res://src/core/character/CharacterGeneration.gd")
	if CharGen and CharGen.has_method("create_character"):
		var new_char = CharGen.create_character({})
		if new_char and campaign.has_method("add_crew_member"):
			if new_char.has_method("to_dictionary"):
				campaign.add_crew_member(new_char.to_dictionary())
			else:
				campaign.add_crew_member(new_char)

func _remove_crew_member(crew_member, crew_id: String) -> void:
	## Remove a crew member from the campaign (for pay_or_lose penalty)
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		return
	var campaign = gs.current_campaign
	if campaign.has_method("get_crew_members"):
		var members = campaign.get_crew_members()
		for i in range(members.size() - 1, -1, -1):
			var m = members[i]
			var mid: String = ""
			if m is Dictionary:
				mid = str(m.get("character_id", m.get("id", "")))
			elif m is Object and "character_id" in m:
				mid = str(m.character_id)
			if mid == crew_id:
				members.remove_at(i)
				break

func _roll_on_military_weapons_table() -> String:
	## Roll D100 on the Military Weapons table (gear_database.json)
	var roll: int = randi() % 100 + 1
	# Military weapons table from gear_database.json
	if roll <= 25: return "Military Rifle"
	if roll <= 45: return "Infantry Laser"
	if roll <= 50: return "Marksman's Rifle"
	if roll <= 60: return "Needle Rifle"
	if roll <= 75: return "Auto Rifle"
	if roll <= 80: return "Rattle Gun"
	if roll <= 95: return "Boarding Saber"
	return "Shatter Axe"
