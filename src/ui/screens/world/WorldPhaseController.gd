extends Control
class_name WorldPhaseController

## WorldPhaseController - Orchestrator for Campaign Turn Workflow
## Replaces 3,910-line WorldPhaseUI monolith with focused component coordination
## Implements Mediator pattern for component interactions

# Signals for phase transition integration
signal phase_completed(results: Dictionary)

# Event bus integration - single source of truth for events
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Component dependencies
const UpkeepPhaseComponent = preload("res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
const CrewTaskComponent = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const JobOfferComponent = preload("res://src/ui/screens/world/components/JobOfferComponent.gd")
const MissionPrepComponent = preload("res://src/ui/screens/world/components/MissionPrepComponent.gd")
const MissionSelectionUI = preload("res://src/ui/screens/world/MissionSelectionUI.gd")
const AssignEquipmentComponent = preload("res://src/ui/screens/world/components/AssignEquipmentComponent.gd")
const ResolveRumorsComponent = preload("res://src/ui/screens/world/components/ResolveRumorsComponent.gd")
const PurchaseItemsComponent = preload("res://src/ui/screens/world/components/PurchaseItemsComponent.gd")
const CampaignEventComponent = preload("res://src/ui/screens/world/components/CampaignEventComponent.gd")
const CharacterEventComponent = preload("res://src/ui/screens/world/components/CharacterEventComponent.gd")

# Five Parsecs dependencies
const WorldPhase = preload("res://src/core/campaign/phases/WorldPhase.gd")
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const FPCM_DataManager = preload("res://src/core/data/DataManager.gd")

# UI Components (replaced monolith references)
@onready var phase_container: Control = %PhaseContainer
@onready var step_navigation: HBoxContainer = %StepNavigation
@onready var current_step_label: Label = %CurrentStepLabel
@onready var progress_bar: ProgressBar = %PhaseProgressBar
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton
@onready var automation_toggle: CheckBox = %AutomationToggle

# Component containers - properly structured scene hierarchy
@onready var upkeep_container: Control = %UpkeepContainer
@onready var crew_task_container: Control = %CrewTaskContainer
@onready var job_offer_container: Control = %JobOfferContainer
@onready var assign_equipment_container: Control = %AssignEquipmentContainer
@onready var resolve_rumors_container: Control = %ResolveRumorsContainer
@onready var mission_prep_container: Control = %MissionPrepContainer
@onready var purchase_items_container: Control = %PurchaseItemsContainer
@onready var campaign_event_container: Control = %CampaignEventContainer
@onready var character_event_container: Control = %CharacterEventContainer

# Phase management - Core Rules STEP 2 (World) + STEP 4 (Post-Battle)
enum WorldPhaseStep {
	UPKEEP = 0,
	CREW_TASKS = 1,
	JOB_OFFERS = 2,
	ASSIGN_EQUIPMENT = 3,
	RESOLVE_RUMORS = 4,
	MISSION_PREP = 5,
	PURCHASE_ITEMS = 6,      # Post-battle
	CAMPAIGN_EVENT = 7,      # Post-battle
	CHARACTER_EVENT = 8      # Post-battle
}

var current_step: WorldPhaseStep = WorldPhaseStep.UPKEEP
var step_names: Array[String] = [
	"Upkeep", "Crew Tasks", "Job Offers", "Assign Equipment",
	"Resolve Rumors", "Mission Prep", "Purchase Items",
	"Campaign Event", "Character Event"
]
var step_completed: Dictionary = {} # WorldPhaseStep -> bool
var automation_enabled: bool = false

# Component instances - directly reference scene-instanced components
@onready var upkeep_component = %UpkeepContainer/UpkeepPhaseComponent
@onready var crew_task_component = %CrewTaskContainer/CrewTaskComponent
@onready var job_offer_component = %JobOfferContainer/JobOfferComponent
@onready var assign_equipment_component = %AssignEquipmentContainer/AssignEquipmentComponent
@onready var resolve_rumors_component = %ResolveRumorsContainer/ResolveRumorsComponent
@onready var mission_prep_component = %MissionPrepContainer/MissionPrepComponent
@onready var purchase_items_component = %PurchaseItemsContainer/PurchaseItemsComponent
@onready var campaign_event_component = %CampaignEventContainer/CampaignEventComponent
@onready var character_event_component = %CharacterEventContainer/CharacterEventComponent
var mission_selection_ui: MissionSelectionUI = null

# Campaign data
var world_phase_data: Dictionary = {}
var ship_data: Dictionary = {}
var crew_data: Array = []

func _ready() -> void:
	name = "WorldPhaseController"
	print("WorldPhaseController: Initializing orchestrator - replacing 3,910 line monolith")
	
	_initialize_event_bus()
	_initialize_components()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Initialize centralized event bus - eliminates signal hell"""
	# Find or create event bus
	event_bus = get_node("/root/CampaignTurnEventBus")
	if not event_bus:
		# Create if doesn't exist
		event_bus = CampaignTurnEventBus.new()
		get_tree().root.add_child(event_bus)
		event_bus.name = "CampaignTurnEventBus"
	
	# Enable debug mode for development
	event_bus.enable_debug_mode(true)
	
	# Subscribe to component events - centralized event handling
	# Use existing event types from CampaignTurnEventBus enum
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_RESOLVED, _on_crew_task_resolved)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, _on_job_accepted)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.MISSION_PREPARED, _on_mission_prepared)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_TRANSITION_REQUESTED, _on_phase_transition_requested)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, _on_phase_completed)

	print("WorldPhaseController: Event bus initialized with centralized handling")

func _initialize_components() -> void:
	"""Verify scene-instanced components are available"""
	# Components are instanced in .tscn and referenced via @onready
	# Just verify they exist and log status
	if upkeep_component:
		print("WorldPhaseController: UpkeepPhaseComponent ready")
	if crew_task_component:
		print("WorldPhaseController: CrewTaskComponent ready")
	if job_offer_component:
		print("WorldPhaseController: JobOfferComponent ready")
	if assign_equipment_component:
		print("WorldPhaseController: AssignEquipmentComponent ready")
	if resolve_rumors_component:
		print("WorldPhaseController: ResolveRumorsComponent ready")
	if mission_prep_component:
		print("WorldPhaseController: MissionPrepComponent ready")
	if purchase_items_component:
		print("WorldPhaseController: PurchaseItemsComponent ready")
	if campaign_event_component:
		print("WorldPhaseController: CampaignEventComponent ready")
	if character_event_component:
		print("WorldPhaseController: CharacterEventComponent ready")

	# Initialize mission selection UI for Job Offers/Mission Prep phases
	_initialize_mission_selection()

	print("WorldPhaseController: Component initialization complete")

func _connect_ui_signals() -> void:
	"""Connect UI navigation signals"""
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if automation_toggle:
		automation_toggle.toggled.connect(_on_automation_toggled)

func _setup_initial_state() -> void:
	"""Setup initial UI state and fetch campaign data from GameStateManager"""
	current_step = WorldPhaseStep.UPKEEP
	step_completed = {
		WorldPhaseStep.UPKEEP: false,
		WorldPhaseStep.CREW_TASKS: false,
		WorldPhaseStep.JOB_OFFERS: false,
		WorldPhaseStep.ASSIGN_EQUIPMENT: false,
		WorldPhaseStep.RESOLVE_RUMORS: false,
		WorldPhaseStep.MISSION_PREP: false,
		WorldPhaseStep.PURCHASE_ITEMS: false,
		WorldPhaseStep.CAMPAIGN_EVENT: false,
		WorldPhaseStep.CHARACTER_EVENT: false
	}

	# Auto-fetch campaign data from GameStateManager
	_fetch_campaign_data()

	_update_ui_display()
	_show_current_step()

	# Check for deferred events at start of turn
	check_deferred_events("NEXT_TURN")

func _fetch_campaign_data() -> void:
	"""Fetch crew and ship data from GameStateManager for self-initialization"""
	# Get crew data
	if GameStateManager:
		crew_data = GameStateManager.get_crew_members()
		print("WorldPhaseController: Fetched %d crew members from GameStateManager" % crew_data.size())

		# Get ship data
		var game_state = GameStateManager.get_game_state()
		if game_state and "player_ship" in game_state:
			ship_data = game_state.player_ship if game_state.player_ship else {}
		else:
			ship_data = {"name": "Unknown Ship", "condition": "good"}

		# Build world phase data from campaign
		world_phase_data = {
			"credits": GameStateManager.get_credits(),
			"stash": [],
			"rumors": [],
			"quest": {},
			"available_items": [],
			"patrons": [],
			"location": "Unknown Location"
		}

		# Get additional campaign data from GameState autoload (not GameStateManager internal)
		var game_state_node = get_node_or_null("/root/GameState")
		if game_state_node and game_state_node.current_campaign:
			var campaign = game_state_node.current_campaign
			if campaign:
				# Access properties directly for Resource, with fallback for Dictionary
				if campaign is Dictionary:
					world_phase_data["stash"] = campaign.get("stash", [])
					world_phase_data["rumors"] = campaign.get("rumors", [])
					world_phase_data["patrons"] = campaign.get("patrons", [])
					var current_world = campaign.get("current_world", {})
					if current_world is Dictionary:
						world_phase_data["location"] = current_world.get("name", "Unknown Location")
				else:
					# Resource access
					world_phase_data["stash"] = campaign.stash if "stash" in campaign else []
					world_phase_data["rumors"] = campaign.rumors if "rumors" in campaign else []
					world_phase_data["patrons"] = campaign.patrons if "patrons" in campaign else []
					if "current_world" in campaign and campaign.current_world:
						var current_world = campaign.current_world
						if current_world is Dictionary:
							world_phase_data["location"] = current_world.get("name", "Unknown Location")
						elif "name" in current_world:
							world_phase_data["location"] = current_world.name
		else:
			print("WorldPhaseController: WARNING - GameState autoload or current_campaign not found")

		print("WorldPhaseController: Fetched %d patrons, location: %s" % [world_phase_data["patrons"].size(), world_phase_data["location"]])

		# Initialize components with fetched data
		_initialize_components_with_data()
	else:
		print("WorldPhaseController: WARNING - GameStateManager not available, using empty data")

## Public API: Initialize world phase with campaign data
func initialize_world_phase(ship: Dictionary, crew: Array, world_data: Dictionary) -> void:
	"""Initialize world phase with campaign data - orchestrator entry point"""
	ship_data = ship.duplicate()
	crew_data = crew.duplicate()
	world_phase_data = world_data.duplicate()
	
	print("WorldPhaseController: Initialized world phase - Ship: %s, Crew: %d" % [
		ship_data.get("name", "Unknown"), crew_data.size()
	])
	
	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "world_phase",
			"ship_data": ship_data,
			"crew_data": crew_data,
			"world_data": world_phase_data
		})
	
	# Initialize components with data
	_initialize_components_with_data()
	
	# Reset to first step
	current_step = WorldPhaseStep.UPKEEP
	_show_current_step()

func _initialize_components_with_data() -> void:
	"""Initialize all components with campaign data"""
	# Initialize upkeep component
	if upkeep_component and upkeep_component.has_method("initialize_upkeep_phase"):
		upkeep_component.initialize_upkeep_phase(ship_data, crew_data)

	# Initialize crew task component
	if crew_task_component and crew_task_component.has_method("initialize_crew_tasks"):
		crew_task_component.initialize_crew_tasks(crew_data)

	# Initialize job offer component
	if job_offer_component and job_offer_component.has_method("initialize_job_offers"):
		job_offer_component.initialize_job_offers(world_phase_data)

	# Initialize assign equipment component
	if assign_equipment_component and assign_equipment_component.has_method("initialize_equipment_phase"):
		var stash = world_phase_data.get("stash", [])
		assign_equipment_component.initialize_equipment_phase(crew_data, stash)

	# Initialize resolve rumors component
	if resolve_rumors_component and resolve_rumors_component.has_method("initialize_rumors_phase"):
		var rumors = world_phase_data.get("rumors", [])
		var quest = world_phase_data.get("quest", {})
		resolve_rumors_component.initialize_rumors_phase(rumors, quest)

	# Initialize mission prep component
	if mission_prep_component and mission_prep_component.has_method("initialize_mission_prep"):
		var mission = world_phase_data.get("mission", {})
		var equipment = world_phase_data.get("stash", [])
		# Convert to typed arrays for MissionPrepComponent
		var typed_crew: Array[Dictionary] = []
		for member in crew_data:
			if member is Dictionary:
				typed_crew.append(member)
		var typed_equipment: Array[Dictionary] = []
		for item in equipment:
			if item is Dictionary:
				typed_equipment.append(item)
		mission_prep_component.initialize_mission_prep(mission, typed_crew, typed_equipment)

	# Initialize purchase items component (post-battle)
	if purchase_items_component and purchase_items_component.has_method("initialize_purchase_phase"):
		var credits = world_phase_data.get("credits", 0)
		var available_items = world_phase_data.get("available_items", [])
		purchase_items_component.initialize_purchase_phase(credits, available_items)

	# Initialize campaign event component (post-battle)
	if campaign_event_component and campaign_event_component.has_method("initialize_event_phase"):
		campaign_event_component.initialize_event_phase()

	# Initialize character event component (post-battle)
	if character_event_component and character_event_component.has_method("initialize_event_phase"):
		character_event_component.initialize_event_phase(crew_data)

## Step Navigation - coordinated component management
func _show_current_step() -> void:
	"""Show current step component and hide others"""
	print("WorldPhaseController: Showing step %d - %s" % [current_step, step_names[current_step]])

	# Show/hide all 9 containers based on current step
	if upkeep_container:
		upkeep_container.visible = (current_step == WorldPhaseStep.UPKEEP)
	if crew_task_container:
		crew_task_container.visible = (current_step == WorldPhaseStep.CREW_TASKS)
	if job_offer_container:
		job_offer_container.visible = (current_step == WorldPhaseStep.JOB_OFFERS)
	if assign_equipment_container:
		assign_equipment_container.visible = (current_step == WorldPhaseStep.ASSIGN_EQUIPMENT)
	if resolve_rumors_container:
		resolve_rumors_container.visible = (current_step == WorldPhaseStep.RESOLVE_RUMORS)
	if mission_prep_container:
		mission_prep_container.visible = (current_step == WorldPhaseStep.MISSION_PREP)
	if purchase_items_container:
		purchase_items_container.visible = (current_step == WorldPhaseStep.PURCHASE_ITEMS)
	if campaign_event_container:
		campaign_event_container.visible = (current_step == WorldPhaseStep.CAMPAIGN_EVENT)
	if character_event_container:
		character_event_container.visible = (current_step == WorldPhaseStep.CHARACTER_EVENT)

	# Update UI
	_update_ui_display()

	# Publish step change event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": step_names[current_step].to_lower(),
			"step_index": current_step,
			"total_steps": step_names.size()
		})

	# AUTO-ADVANCE: If automation enabled and step already complete, advance
	if automation_enabled and _can_advance_to_next_step():
		print("WorldPhaseController: >>> Step %s already complete with automation - auto-advancing" % step_names[current_step])
		# Use call_deferred to avoid recursion issues
		call_deferred("_on_next_button_pressed")

func _update_ui_display() -> void:
	"""Update navigation UI display"""
	if current_step_label:
		current_step_label.text = "Step %d of %d: %s" % [
			current_step + 1,
			step_names.size(),
			step_names[current_step]
		]
	
	if progress_bar:
		var progress = float(current_step) / float(step_names.size() - 1)
		progress_bar.value = progress * 100.0
	
	if back_button:
		back_button.disabled = (current_step == WorldPhaseStep.UPKEEP)
	
	if next_button:
		var can_advance = _can_advance_to_next_step()
		next_button.disabled = not can_advance
		print("WorldPhaseController: Next button disabled=%s (can_advance=%s) for step %s" % [next_button.disabled, can_advance, step_names[current_step]])

		if current_step == WorldPhaseStep.CHARACTER_EVENT:
			next_button.text = "Complete World Phase"
		else:
			next_button.text = "Next Step"

func _can_advance_to_next_step() -> bool:
	"""Check if current step is completed and can advance"""
	var result = false
	match current_step:
		WorldPhaseStep.UPKEEP:
			if upkeep_component and upkeep_component.has_method("is_upkeep_completed"):
				result = upkeep_component.is_upkeep_completed()
			else:
				result = step_completed.get(WorldPhaseStep.UPKEEP, false)
		WorldPhaseStep.CREW_TASKS:
			if crew_task_component and crew_task_component.has_method("is_tasks_completed"):
				result = crew_task_component.is_tasks_completed()
			else:
				result = step_completed.get(WorldPhaseStep.CREW_TASKS, false)
		WorldPhaseStep.JOB_OFFERS:
			if job_offer_component and job_offer_component.has_method("is_job_accepted"):
				result = job_offer_component.is_job_accepted()
			else:
				result = step_completed.get(WorldPhaseStep.JOB_OFFERS, false)
		WorldPhaseStep.ASSIGN_EQUIPMENT:
			if assign_equipment_component and assign_equipment_component.has_method("is_equipment_assigned"):
				result = assign_equipment_component.is_equipment_assigned()
			else:
				result = step_completed.get(WorldPhaseStep.ASSIGN_EQUIPMENT, false)
		WorldPhaseStep.RESOLVE_RUMORS:
			if resolve_rumors_component and resolve_rumors_component.has_method("is_rumors_resolved"):
				result = resolve_rumors_component.is_rumors_resolved()
			else:
				result = step_completed.get(WorldPhaseStep.RESOLVE_RUMORS, false)
		WorldPhaseStep.MISSION_PREP:
			if mission_prep_component and mission_prep_component.has_method("is_mission_prepared"):
				result = mission_prep_component.is_mission_prepared()
			else:
				result = step_completed.get(WorldPhaseStep.MISSION_PREP, false)
		WorldPhaseStep.PURCHASE_ITEMS:
			if purchase_items_component and purchase_items_component.has_method("is_purchase_completed"):
				result = purchase_items_component.is_purchase_completed()
			else:
				result = step_completed.get(WorldPhaseStep.PURCHASE_ITEMS, false)
		WorldPhaseStep.CAMPAIGN_EVENT:
			if campaign_event_component and campaign_event_component.has_method("is_event_resolved"):
				result = campaign_event_component.is_event_resolved()
			else:
				result = step_completed.get(WorldPhaseStep.CAMPAIGN_EVENT, false)
		WorldPhaseStep.CHARACTER_EVENT:
			if character_event_component and character_event_component.has_method("is_event_resolved"):
				result = character_event_component.is_event_resolved()
			else:
				result = step_completed.get(WorldPhaseStep.CHARACTER_EVENT, false)
		_:
			result = false

	print("WorldPhaseController: _can_advance_to_next_step() for %s = %s" % [step_names[current_step], result])
	return result

## UI Event Handlers - orchestrator navigation
func _on_back_button_pressed() -> void:
	"""Handle back button navigation"""
	if current_step > WorldPhaseStep.UPKEEP:
		current_step = current_step - 1
		_show_current_step()
		print("WorldPhaseController: Navigated back to %s" % step_names[current_step])

func _on_next_button_pressed() -> void:
	"""Handle next button navigation"""
	if _can_advance_to_next_step():
		if current_step < WorldPhaseStep.CHARACTER_EVENT:
			current_step = current_step + 1
			_show_current_step()
			print("WorldPhaseController: Advanced to %s" % step_names[current_step])
		else:
			# Complete world phase
			_complete_world_phase()
	else:
		print("WorldPhaseController: Cannot advance - current step not completed")

func _on_automation_toggled(enabled: bool) -> void:
	"""Handle automation toggle"""
	automation_enabled = enabled
	print("WorldPhaseController: Automation %s" % ("enabled" if enabled else "disabled"))
	
	# Publish automation event for components
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, {
			"enabled": enabled
		})

## Component Event Handlers - centralized coordination
func _on_crew_task_resolved(data: Dictionary) -> void:
	"""Handle crew task resolution from CrewTaskComponent"""
	print("WorldPhaseController: Crew task resolved: %s" % data)
	step_completed[WorldPhaseStep.CREW_TASKS] = true
	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

func _on_job_accepted(data: Dictionary) -> void:
	"""Handle job acceptance from JobOfferComponent"""
	print("WorldPhaseController: Job accepted: %s" % data)
	step_completed[WorldPhaseStep.JOB_OFFERS] = true
	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

func _on_mission_prepared(data: Dictionary) -> void:
	"""Handle mission preparation from MissionPrepComponent"""
	print("WorldPhaseController: Mission prepared: %s" % data)
	step_completed[WorldPhaseStep.MISSION_PREP] = true
	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

func _on_phase_transition_requested(data: Dictionary) -> void:
	"""Handle phase transition requests from components"""
	print("WorldPhaseController: Phase transition requested: %s" % data)

func _on_phase_completed(data: Dictionary) -> void:
	"""Handle phase completion events from all components via PHASE_COMPLETED"""
	var phase_name = data.get("phase_name", "")
	print("WorldPhaseController: Phase completed: %s" % phase_name)

	# Route completion to correct step based on phase_name
	match phase_name:
		"upkeep":
			step_completed[WorldPhaseStep.UPKEEP] = true
		"assign_equipment":
			step_completed[WorldPhaseStep.ASSIGN_EQUIPMENT] = true
		"resolve_rumors":
			step_completed[WorldPhaseStep.RESOLVE_RUMORS] = true
		"purchase_items":
			step_completed[WorldPhaseStep.PURCHASE_ITEMS] = true
		"campaign_event":
			step_completed[WorldPhaseStep.CAMPAIGN_EVENT] = true
		"character_event":
			step_completed[WorldPhaseStep.CHARACTER_EVENT] = true

	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

## World Phase Completion
func _complete_world_phase() -> void:
	"""Complete the entire world phase and transition to battle"""
	print("WorldPhaseController: Completing world phase")

	# Gather results from all 9 components
	var upkeep_results = {}
	if upkeep_component and upkeep_component.has_method("get_upkeep_results"):
		upkeep_results = upkeep_component.get_upkeep_results()

	var crew_task_results = []
	if crew_task_component and crew_task_component.has_method("get_task_results"):
		crew_task_results = crew_task_component.get_task_results()

	var job_results = {}
	if job_offer_component and job_offer_component.has_method("get_accepted_job"):
		job_results = job_offer_component.get_accepted_job()

	var equipment_results = {}
	if assign_equipment_component and assign_equipment_component.has_method("get_equipment_assignments"):
		equipment_results = assign_equipment_component.get_equipment_assignments()

	var rumors_results = {}
	if resolve_rumors_component and resolve_rumors_component.has_method("get_resolved_rumors"):
		rumors_results = resolve_rumors_component.get_resolved_rumors()

	var mission_data = {}
	if mission_prep_component and mission_prep_component.has_method("get_mission_data"):
		mission_data = mission_prep_component.get_mission_data()

	var purchase_results = {}
	if purchase_items_component and purchase_items_component.has_method("get_purchased_items"):
		purchase_results = purchase_items_component.get_purchased_items()

	var campaign_event_results = {}
	if campaign_event_component and campaign_event_component.has_method("get_current_event"):
		campaign_event_results = campaign_event_component.get_current_event()

	var character_event_results = {}
	if character_event_component and character_event_component.has_method("get_current_event"):
		character_event_results = character_event_component.get_current_event()

	var world_phase_results = {
		"upkeep_results": upkeep_results,
		"crew_task_results": crew_task_results,
		"job_results": job_results,
		"equipment_results": equipment_results,
		"rumors_results": rumors_results,
		"mission_data": mission_data,
		"purchase_results": purchase_results,
		"campaign_event_results": campaign_event_results,
		"character_event_results": character_event_results
	}

	# PERSIST DATA TO GAMESTATE for battle phase
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign

		# Save accepted job as current_mission (required by battle system)
		if not job_results.is_empty():
			campaign["current_mission"] = {
				"objective": job_results.get("objective", "patrol"),
				"objective_description": job_results.get("objective_description", ""),
				"enemy_type": job_results.get("enemy_type", "Unknown Hostiles"),
				"pay": job_results.get("danger_pay", job_results.get("pay", 0)),
				"danger_level": job_results.get("danger_level", 1),
				"time_frame": job_results.get("time_frame", ""),
				"deployment_condition": job_results.get("deployment_condition", ""),
				"notable_sights": job_results.get("notable_sights", ""),
				"patron": job_results.get("patron_name", job_results.get("patron", "")),
				"patron_type": job_results.get("patron_type", ""),
				"benefits": job_results.get("benefits", []),
				"hazards": job_results.get("hazards", []),
				"location": job_results.get("location", "")
			}
			print("WorldPhaseController: Saved current_mission to GameState")

		# Save equipment assignments
		if not equipment_results.is_empty():
			campaign["equipment_assignments"] = equipment_results

		# Store full world phase results for summary display
		campaign["world_phase_results"] = world_phase_results
		print("WorldPhaseController: Saved world_phase_results to GameState")

	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "world_phase",
			"results": world_phase_results,
			"next_phase": "battle_phase"
		})

	print("WorldPhaseController: World phase completed successfully")

	# Emit signal for CampaignTurnController integration
	phase_completed.emit(world_phase_results)

	# TRANSITION TO WORLD PHASE SUMMARY
	# Note: CampaignTurnController should handle phase transition, but keeping this as fallback
	# print("WorldPhaseController: Transitioning to WorldPhaseSummary scene")
	# get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/world/WorldPhaseSummary.tscn")

## Public API for external integration
func get_current_step() -> WorldPhaseStep:
	"""Get current world phase step"""
	return current_step

func is_world_phase_complete() -> bool:
	"""Check if entire world phase is completed"""
	for step in step_completed.values():
		if not step:
			return false
	return true

func get_world_phase_results() -> Dictionary:
	"""Get complete world phase results"""
	return {
		"upkeep_results": upkeep_component.get_upkeep_results() if upkeep_component else {},
		"step_completed": step_completed.duplicate(),
		"automation_used": automation_enabled
	}

func reset_world_phase() -> void:
	"""Reset world phase for new turn"""
	current_step = WorldPhaseStep.UPKEEP
	step_completed = {
		WorldPhaseStep.UPKEEP: false,
		WorldPhaseStep.CREW_TASKS: false,
		WorldPhaseStep.JOB_OFFERS: false,
		WorldPhaseStep.ASSIGN_EQUIPMENT: false,
		WorldPhaseStep.RESOLVE_RUMORS: false,
		WorldPhaseStep.MISSION_PREP: false,
		WorldPhaseStep.PURCHASE_ITEMS: false,
		WorldPhaseStep.CAMPAIGN_EVENT: false,
		WorldPhaseStep.CHARACTER_EVENT: false
	}

	# Reset all components
	if upkeep_component and upkeep_component.has_method("reset_upkeep_phase"):
		upkeep_component.reset_upkeep_phase()
	if crew_task_component and crew_task_component.has_method("reset_crew_tasks"):
		crew_task_component.reset_crew_tasks()
	if job_offer_component and job_offer_component.has_method("reset_job_offers"):
		job_offer_component.reset_job_offers()
	if assign_equipment_component and assign_equipment_component.has_method("reset_equipment_phase"):
		assign_equipment_component.reset_equipment_phase()
	if resolve_rumors_component and resolve_rumors_component.has_method("reset_rumors_phase"):
		resolve_rumors_component.reset_rumors_phase()
	if mission_prep_component and mission_prep_component.has_method("reset_mission_prep"):
		mission_prep_component.reset_mission_prep()
	if purchase_items_component and purchase_items_component.has_method("reset_purchase_phase"):
		purchase_items_component.reset_purchase_phase()
	if campaign_event_component and campaign_event_component.has_method("reset_event_phase"):
		campaign_event_component.reset_event_phase()
	if character_event_component and character_event_component.has_method("reset_event_phase"):
		character_event_component.reset_event_phase()

	_update_ui_display()

## Deferred Event System - Check and resolve pending events

# Popup for resolving deferred events
var deferred_event_popup: AcceptDialog = null
var pending_deferred_events: Array = []
var current_deferred_event_index: int = 0

func check_deferred_events(trigger_type: String) -> void:
	"""Check for and display pending deferred events matching trigger type.

	Trigger types:
	- NEW_PLANET: When arriving at new planet
	- NEXT_TURN: At start of campaign turn (called from _setup_initial_state)
	- THIS_BATTLE: Before battle starts
	- ON_QUEST: When undertaking a quest
	- ON_RECRUIT: When recruiting crew
	- PERSISTENT: Check each planet for trade goods, spare parts
	"""
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		return

	var campaign = game_state.current_campaign
	if not campaign:
		return

	# Get pending events array
	var all_pending: Array = []
	if campaign is Resource and "pending_events" in campaign:
		all_pending = campaign.pending_events
	elif campaign is Dictionary and campaign.has("pending_events"):
		all_pending = campaign.get("pending_events", [])

	if all_pending.is_empty():
		return

	# Filter events by trigger type
	pending_deferred_events = []
	for event in all_pending:
		if event.get("trigger_type", "") == trigger_type and not event.get("consumed", false):
			# Check expiration
			var current_turn = campaign.campaign_turn if campaign is Resource else campaign.get("campaign_turn", 0)
			var expires = event.get("expires_turn", null)
			if expires == null or current_turn <= expires:
				pending_deferred_events.append(event)

	if pending_deferred_events.is_empty():
		return

	print("WorldPhaseController: Found %d deferred events for trigger: %s" % [pending_deferred_events.size(), trigger_type])

	# Show first event
	current_deferred_event_index = 0
	_show_deferred_event_popup()

func _show_deferred_event_popup() -> void:
	"""Show popup for current deferred event"""
	if current_deferred_event_index >= pending_deferred_events.size():
		# All events processed
		pending_deferred_events = []
		return

	var event = pending_deferred_events[current_deferred_event_index]

	# Create popup if needed
	if not deferred_event_popup:
		deferred_event_popup = AcceptDialog.new()
		deferred_event_popup.title = "Deferred Event"
		deferred_event_popup.confirmed.connect(_on_deferred_event_confirmed)
		deferred_event_popup.canceled.connect(_on_deferred_event_confirmed)  # Same behavior
		add_child(deferred_event_popup)

	# Build popup content
	var effect = event.get("effect", {})
	var event_name = event.get("event_name", "Unknown Event")
	var crew_id = event.get("crew_id", "Unknown")

	var content = "%s\n\n" % event_name
	content += "Crew: %s\n" % crew_id
	content += "Trigger: %s\n\n" % event.get("trigger_type", "")

	# Show effect details
	if effect is Dictionary:
		content += "Effect: %s\n" % effect.get("effect", "No description")

		var rewards: Array = []
		if effect.get("credits", 0) > 0:
			rewards.append("+%d credits" % effect.credits)
		if effect.get("xp", 0) > 0:
			rewards.append("+%d XP" % effect.xp)
		if effect.get("story_points", 0) > 0:
			rewards.append("+%d story point" % effect.story_points)
		if effect.get("items", []).size() > 0:
			for item in effect.items:
				rewards.append(item)

		if rewards.size() > 0:
			content += "\nRewards: %s" % ", ".join(rewards)

	deferred_event_popup.dialog_text = content
	deferred_event_popup.popup_centered()

func _on_deferred_event_confirmed() -> void:
	"""Handle deferred event confirmation - apply effects and mark consumed"""
	if current_deferred_event_index >= pending_deferred_events.size():
		return

	var event = pending_deferred_events[current_deferred_event_index]

	# Apply effects
	_apply_deferred_event_effects(event)

	# Mark event as consumed
	event["consumed"] = true

	# Check for single_use items to remove from pending
	var effect = event.get("effect", {})
	if effect is Dictionary and effect.get("single_use", false):
		_remove_consumed_event(event)

	print("WorldPhaseController: Resolved deferred event: %s" % event.get("event_name", ""))

	# Move to next event
	current_deferred_event_index += 1
	_show_deferred_event_popup()

func _apply_deferred_event_effects(event: Dictionary) -> void:
	"""Apply the effects of a deferred event to campaign state"""
	var effect = event.get("effect", {})
	if not effect is Dictionary:
		return

	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return

	# Apply credits
	var credits = effect.get("credits", 0)
	if credits != 0 and GameStateManager:
		GameStateManager.add_credits(credits)
		print("WorldPhaseController: Applied %d credits from deferred event" % credits)

	# Apply story points
	var story_points = effect.get("story_points", 0)
	if story_points > 0:
		var campaign = game_state.current_campaign
		if campaign is Resource and "story_points" in campaign:
			campaign.story_points += story_points
		elif campaign is Dictionary:
			campaign["story_points"] = campaign.get("story_points", 0) + story_points
		print("WorldPhaseController: Applied %d story points from deferred event" % story_points)

	# Apply XP to crew member
	var xp = effect.get("xp", 0)
	if xp > 0:
		var crew_id = event.get("crew_id", "")
		var campaign = game_state.current_campaign
		if campaign:
			var crew = campaign.get("crew", []) if campaign is Dictionary else []
			for character in crew:
				var char_id = character.get("id", character.get("character_id", "")) if character is Dictionary else ""
				if char_id == crew_id:
					if character is Dictionary:
						character["experience"] = character.get("experience", 0) + xp
					print("WorldPhaseController: Applied %d XP to crew %s" % [xp, crew_id])
					break

	# Handle rival generation
	if effect.get("rival", false):
		var campaign = game_state.current_campaign
		if campaign:
			# Generate new rival
			var new_rival = {
				"id": "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
				"name": "Rival %d" % (randi() % 100 + 1),
				"type": ["Criminal", "Corporate", "Military", "Pirate", "Cult"][randi() % 5],
				"hostility": randi() % 3 + 3,  # 3-5 hostility
				"resources": randi() % 3 + 1,  # 1-3 resources
				"source": "deferred_event",
				"created_turn": campaign.get("campaign_turn", 1) if campaign is Dictionary else 1
			}
			var rivals = campaign.get("rivals", []) if campaign is Dictionary else []
			rivals.append(new_rival)
			if campaign is Dictionary:
				campaign["rivals"] = rivals
			print("WorldPhaseController: Generated rival '%s' from deferred event" % new_rival.name)

	# Handle rumor generation
	if effect.get("rumor", false):
		var campaign = game_state.current_campaign
		if campaign:
			# Generate rumor per Core Rules p.3098-3110 (D10 for flavor)
			var rumor_types = [
				"An extracted data file",
				"An extracted data file",
				"Notebook with secret information",
				"Notebook with secret information",
				"Old map showing a location",
				"Old map showing a location",
				"A tip from a contact",
				"A tip from a contact",
				"An intercepted transmission",
				"An intercepted transmission"
			]
			var rumor_roll = randi() % 10
			var new_rumor = {
				"id": "rumor_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
				"type": rumor_roll + 1,
				"description": rumor_types[rumor_roll],
				"source": "deferred_event",
				"created_turn": campaign.get("campaign_turn", 1) if campaign is Dictionary else 1
			}
			var rumors = campaign.get("rumors", []) if campaign is Dictionary else []
			rumors.append(new_rumor)
			if campaign is Dictionary:
				campaign["rumors"] = rumors
			print("WorldPhaseController: Added rumor '%s' from deferred event" % new_rumor.description)

func _remove_consumed_event(event: Dictionary) -> void:
	"""Remove consumed single-use event from campaign pending events"""
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		return

	var campaign = game_state.current_campaign
	if not campaign:
		return

	var event_id = event.get("id", "")
	if event_id == "":
		return

	if campaign is Resource and "pending_events" in campaign:
		campaign.pending_events = campaign.pending_events.filter(func(e): return e.get("id", "") != event_id)
	elif campaign is Dictionary and campaign.has("pending_events"):
		campaign["pending_events"] = campaign.get("pending_events", []).filter(func(e): return e.get("id", "") != event_id)

	print("WorldPhaseController: Removed consumed event: %s" % event_id)

## Backend System Integration Methods

func update_planet_data_backend(planet_id: String, campaign_turn: int = 0) -> void:
	"""Update or generate planet data using the backend PlanetDataManager"""
	var planet_manager = get_node("BackendPlanetManager")
	if planet_manager and planet_manager.has_method("get_or_generate_planet"):
		var planet_data = planet_manager.get_or_generate_planet(planet_id, campaign_turn)
		print("WorldPhaseController: Planet data updated through backend - %s" % planet_data.name)
		
		# Update current world display if we have that functionality
		if planet_data:
			print("WorldPhaseController: Planet data received - %s" % planet_data.name)
	else:
		print("WorldPhaseController: BackendPlanetManager not available")

func generate_random_contact_backend(planet_id: String, turn_number: int = 0) -> void:
	"""Generate a random contact using the backend ContactManager"""
	var contact_manager = get_node("BackendContactManager")
	if contact_manager and contact_manager.has_method("generate_random_contact"):
		var contact = contact_manager.generate_random_contact(planet_id, turn_number)
		print("WorldPhaseController: Generated random contact through backend - %s" % contact.name)
	else:
		print("WorldPhaseController: ContactManager not available for random contact generation")

## Mission Selection Integration per Five Parsecs Rules
func _initialize_mission_selection() -> void:
	"""Mission selection handled by JobOfferComponent - no separate UI needed"""
	# JobOfferComponent already provides full job selection capabilities
	# MissionSelectionUI is deprecated to avoid duplicate UI
	pass

func _on_mission_selected(mission: Resource) -> void:
	"""Handle mission selection from MissionSelectionUI"""
	print("WorldPhaseController: Mission selected: %s" % mission)
	
	# Mark mission step as completed
	step_completed[WorldPhaseStep.JOB_OFFERS] = true
	step_completed[WorldPhaseStep.MISSION_PREP] = true
	
	# Auto-advance to next step or complete phase
	if current_step == WorldPhaseStep.JOB_OFFERS:
		_advance_to_next_step()
	elif current_step == WorldPhaseStep.MISSION_PREP:
		_complete_world_phase()

func _on_mission_selection_cancelled() -> void:
	"""Handle mission selection cancellation"""
	print("WorldPhaseController: Mission selection cancelled")
	# User can stay in current step to try again

func _advance_to_next_step() -> void:
	"""Advance to the next step in the world phase workflow"""
	print("WorldPhaseController: Advancing to next step from: ", step_names[current_step])

	if current_step < WorldPhaseStep.CHARACTER_EVENT:
		current_step = current_step + 1
		_show_current_step()
	else:
		_complete_world_phase()

func _update_phase_display() -> void:
	"""Update the UI to reflect current phase step"""
	_update_ui_display()

## Debug Mode - Developer Testing Shortcuts
func _input(event: InputEvent) -> void:
	"""Handle debug hotkeys for fast iteration during development"""
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				# Skip directly to battle with synthetic mission data
				_debug_skip_to_battle()
			KEY_F6:
				# Auto-complete current step (for testing)
				_debug_complete_current_step()

func _debug_skip_to_battle() -> void:
	"""[DEBUG] Skip directly to battle phase with generated test data"""
	print("WorldPhaseController: [DEBUG] Skipping to battle phase with test data")

	# Load test helper for mock data
	var HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	var helper = HelperClass.new()

	# Generate mock battle context
	var mock_battle_data = helper.create_mock_battle_phase_data()

	# Add crew data from current state
	mock_battle_data["crew"] = crew_data.duplicate()
	mock_battle_data["ship"] = ship_data.duplicate()

	# Create full mission context for battle transition
	var mission_context = {
		"mission_type": mock_battle_data.get("mission_type", "OPPORTUNITY"),
		"enemy_count": mock_battle_data.get("enemy_count", 5),
		"enemy_type": mock_battle_data.get("enemy_type", "RAIDERS"),
		"deployment_zones": ["north", "south"],
		"terrain_type": "urban",
		"objective": "eliminate_hostiles",
		"crew": crew_data,
		"equipment": world_phase_data.get("stash", [])
	}

	# Publish event to trigger battle transition
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "world_phase",
			"results": {"debug_skip": true},
			"next_phase": "battle_phase",
			"mission_context": mission_context
		})

	print("WorldPhaseController: [DEBUG] Battle transition triggered - Mission: %s, Enemies: %d" % [
		mission_context.mission_type, mission_context.enemy_count
	])

func _debug_complete_current_step() -> void:
	"""[DEBUG] Auto-complete current step for testing"""
	print("WorldPhaseController: [DEBUG] Auto-completing step: %s" % step_names[current_step])
	step_completed[current_step] = true
	_update_ui_display()

	# Auto-advance if enabled
	if automation_enabled:
		_on_next_button_pressed()
