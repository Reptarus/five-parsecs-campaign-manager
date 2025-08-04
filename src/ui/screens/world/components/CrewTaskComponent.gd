extends Control
class_name CrewTaskComponent

## Crew Task Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs crew task rules only
## Implements Core Rules pp.76-82 - Crew task assignment and resolution

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const DiceManager = preload("res://src/core/managers/DiceManager.gd")

# UI Components
@onready var crew_task_container: VBoxContainer = %CrewTaskContainer
@onready var crew_member_list: ItemList = %CrewMemberList
@onready var available_tasks_list: ItemList = %AvailableTasksList
@onready var assign_task_button: Button = %AssignTaskButton
@onready var resolve_all_button: Button = %ResolveAllButton
@onready var progress_container: VBoxContainer = %ProgressContainer

# Crew task state
var crew_data: Array = []
var assigned_tasks: Dictionary = {} # crew_member_id -> task_data
var completed_tasks: Array = []
var all_tasks_resolved: bool = false

# Five Parsecs crew tasks (Core Rules pp.76-82)
var available_crew_tasks: Array[Dictionary] = [
	{
		"name": "Trade",
		"description": "Attempt to find good deals in the local markets",
		"dice_target": 5,
		"success_reward": "1d6 credits",
		"failure_penalty": "None"
	},
	{
		"name": "Explore",
		"description": "Search for interesting locations or opportunities",
		"dice_target": 6,
		"success_reward": "Discovery or rumor",
		"failure_penalty": "Possible danger"
	},
	{
		"name": "Train",
		"description": "Practice combat or other skills",
		"dice_target": 4,
		"success_reward": "XP or skill improvement",
		"failure_penalty": "None"
	},
	{
		"name": "Recruit",
		"description": "Search for new crew members",
		"dice_target": 7,
		"success_reward": "New crew member available",
		"failure_penalty": "None"
	},
	{
		"name": "Repair",
		"description": "Fix ship damage or equipment",
		"dice_target": 5,
		"success_reward": "Repair completed",
		"failure_penalty": "Parts cost credits"
	}
]

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

func _connect_ui_signals() -> void:
	"""Connect UI signals"""
	if assign_task_button:
		assign_task_button.pressed.connect(_on_assign_task_pressed)
	if resolve_all_button:
		resolve_all_button.pressed.connect(_on_resolve_all_pressed)
	if crew_member_list:
		crew_member_list.item_selected.connect(_on_crew_member_selected)
	if available_tasks_list:
		available_tasks_list.item_selected.connect(_on_task_selected)

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
	"""Populate crew member list UI"""
	if not crew_member_list:
		return
	
	crew_member_list.clear()
	for i in range(crew_data.size()):
		var crew_member = crew_data[i]
		var name = crew_member.get("character_name", "Crew Member %d" % (i + 1))
		var task_status = ""
		
		if crew_member.get("character_id", "") in assigned_tasks:
			task_status = " [ASSIGNED]"
		
		crew_member_list.add_item(name + task_status)

func _populate_available_tasks() -> void:
	"""Populate available tasks list UI"""
	if not available_tasks_list:
		return
	
	available_tasks_list.clear()
	for task in available_crew_tasks:
		var task_text = "%s (Target: %d+)" % [task.name, task.dice_target]
		available_tasks_list.add_item(task_text)

## Task Assignment
func _on_assign_task_pressed() -> void:
	"""Handle task assignment button press"""
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
	
	# Assign task
	assigned_tasks[crew_id] = {
		"crew_member": crew_member,
		"task": task,
		"assigned_time": Time.get_unix_time_from_system(),
		"resolved": false
	}
	
	print("CrewTaskComponent: Assigned %s to %s" % [task.name, crew_member.get("character_name", "Unknown")])
	
	# Update UI
	_populate_crew_list()
	_update_ui_state()
	
	# Publish assignment event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_ASSIGNED, {
			"crew_id": crew_id,
			"crew_name": crew_member.get("character_name", "Unknown"),
			"task_name": task.name,
			"task_target": task.dice_target
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
	"""Resolve a single crew task using Five Parsecs dice rules"""
	var crew_member: Dictionary = task_data.crew_member
	var task: Dictionary = task_data.task
	
	# Get dice manager for rolling
	var dice_manager: Node = get_node("/root/DiceManager")
	var roll: int = 0
	if not dice_manager:
		# Fallback to simple random if DiceManager not available
		roll = randi() % 6 + 1
	else:
		# Use proper dice manager (assuming DiceManager has roll_dice method)
		if dice_manager.has_method("roll_dice"):
			roll = dice_manager.roll_dice(1, 6)[0]
		else:
			roll = randi() % 6 + 1 # Fallback
	
	# Apply character modifiers (simplified - in full implementation would check character stats)
	var modified_roll: int = roll
	var character_bonus: int = crew_member.get("task_bonus", 0) as int # Character skill bonus
	modified_roll += character_bonus
	
	# Determine success
	var success: bool = modified_roll >= task.dice_target
	
	# Generate result
	var result: Dictionary = {
		"crew_id": crew_id,
		"crew_name": crew_member.get("character_name", "Unknown"),
		"task_name": task.name,
		"roll": roll,
		"modified_roll": modified_roll,
		"target": task.dice_target,
		"success": success,
		"reward": task.success_reward if success else "None",
		"penalty": task.failure_penalty if not success else "None"
	}
	
	print("CrewTaskComponent: %s - %s (%d vs %d): %s" % [
		result.crew_name,
		result.task_name,
		result.modified_roll,
		result.target,
		"SUCCESS" if success else "FAILED"
	])
	
	return result

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
		var result_label = Label.new()
		var status_text = "✓" if result.success else "✗"
		var color = Color.GREEN if result.success else Color.RED
		
		result_label.text = "%s %s - %s (Roll: %d)" % [
			status_text,
			result.crew_name,
			result.task_name,
			result.modified_roll
		]
		result_label.modulate = color
		progress_container.add_child(result_label)

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
	all_tasks_resolved = false
	_populate_crew_list()
	_update_ui_state()
	print("CrewTaskComponent: Reset for new turn")
