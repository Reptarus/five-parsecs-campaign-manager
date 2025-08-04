extends Control
class_name WorldPhaseController

## WorldPhaseController - Orchestrator for Campaign Turn Workflow
## Replaces 3,910-line WorldPhaseUI monolith with focused component coordination
## Implements Mediator pattern for component interactions

# Event bus integration - single source of truth for events
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Component dependencies
const UpkeepPhaseComponent = preload("res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
const MissionSelectionUI = preload("res://src/ui/screens/world/MissionSelectionUI.gd")

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
@onready var mission_prep_container: Control = %MissionPrepContainer

# Phase management
enum WorldPhaseStep {
	UPKEEP = 0,
	CREW_TASKS = 1,
	JOB_OFFERS = 2,
	MISSION_PREP = 3
}

var current_step: WorldPhaseStep = WorldPhaseStep.UPKEEP
var step_names: Array[String] = ["Upkeep", "Crew Tasks", "Job Offers", "Mission Prep"]
var step_completed: Dictionary = {} # WorldPhaseStep -> bool
var automation_enabled: bool = false

# Component instances - focused single-responsibility components
var upkeep_component: UpkeepPhaseComponent = null
var crew_task_component: Node = null
var job_offer_component: Node = null
var mission_prep_component: Node = null
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
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.UPKEEP_COMPLETED, _on_upkeep_completed)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_RESOLVED, _on_crew_task_resolved)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, _on_job_accepted)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.MISSION_PREPARED, _on_mission_prepared)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_TRANSITION_REQUESTED, _on_phase_transition_requested)
	
	print("WorldPhaseController: Event bus initialized with centralized handling")

func _initialize_components() -> void:
	"""Initialize focused components - replacing monolith responsibilities"""
	# Initialize Upkeep Component
	if upkeep_container:
		upkeep_component = UpkeepPhaseComponent.new()
		upkeep_container.add_child(upkeep_component)
		print("WorldPhaseController: UpkeepPhaseComponent initialized")
	
	# TODO: Initialize other components as they are extracted
	# crew_task_component = CrewTaskComponent.new()
	# job_offer_component = JobOfferComponent.new()
	# mission_prep_component = MissionPrepComponent.new()
	
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
	"""Setup initial UI state"""
	current_step = WorldPhaseStep.UPKEEP
	step_completed = {
		WorldPhaseStep.UPKEEP: false,
		WorldPhaseStep.CREW_TASKS: false,
		WorldPhaseStep.JOB_OFFERS: false,
		WorldPhaseStep.MISSION_PREP: false
	}
	
	_update_ui_display()
	_show_current_step()

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
	if upkeep_component:
		upkeep_component.initialize_upkeep_phase(ship_data, crew_data)
	
	# TODO: Initialize other components when extracted
	# if crew_task_component:
	#     crew_task_component.initialize_crew_tasks(crew_data, world_phase_data)

## Step Navigation - coordinated component management
func _show_current_step() -> void:
	"""Show current step component and hide others"""
	print("WorldPhaseController: Showing step %d - %s" % [current_step, step_names[current_step]])
	
	# Hide all containers
	if upkeep_container:
		upkeep_container.visible = (current_step == WorldPhaseStep.UPKEEP)
	if crew_task_container:
		crew_task_container.visible = (current_step == WorldPhaseStep.CREW_TASKS)
	if job_offer_container:
		job_offer_container.visible = (current_step == WorldPhaseStep.JOB_OFFERS)
	if mission_prep_container:
		mission_prep_container.visible = (current_step == WorldPhaseStep.MISSION_PREP)
	
	# Update UI
	_update_ui_display()
	
	# Publish step change event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": step_names[current_step].to_lower(),
			"step_index": current_step,
			"total_steps": step_names.size()
		})

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
		
		if current_step == WorldPhaseStep.MISSION_PREP:
			next_button.text = "Complete World Phase"
		else:
			next_button.text = "Next Step"

func _can_advance_to_next_step() -> bool:
	"""Check if current step is completed and can advance"""
	match current_step:
		WorldPhaseStep.UPKEEP:
			return upkeep_component and upkeep_component.is_upkeep_completed()
		WorldPhaseStep.CREW_TASKS:
			# TODO: Check crew task completion when component is extracted
			return step_completed.get(WorldPhaseStep.CREW_TASKS, false)
		WorldPhaseStep.JOB_OFFERS:
			# TODO: Check job offer completion when component is extracted
			return step_completed.get(WorldPhaseStep.JOB_OFFERS, false)
		WorldPhaseStep.MISSION_PREP:
			# TODO: Check mission prep completion when component is extracted
			return step_completed.get(WorldPhaseStep.MISSION_PREP, false)
		_:
			return false

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
		if current_step < WorldPhaseStep.MISSION_PREP:
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
func _on_upkeep_completed(data: Dictionary) -> void:
	"""Handle upkeep completion from UpkeepPhaseComponent"""
	print("WorldPhaseController: Upkeep completed with data: %s" % data)
	step_completed[WorldPhaseStep.UPKEEP] = true
	_update_ui_display()
	
	# If automation enabled, auto-advance
	if automation_enabled:
		await get_tree().create_timer(1.0).timeout # Brief pause for user feedback
		_on_next_button_pressed()

func _on_crew_task_resolved(data: Dictionary) -> void:
	"""Handle crew task resolution from CrewTaskComponent"""
	print("WorldPhaseController: Crew task resolved: %s" % data)
	# TODO: Implement when CrewTaskComponent is extracted

func _on_job_accepted(data: Dictionary) -> void:
	"""Handle job acceptance from JobOfferComponent"""
	print("WorldPhaseController: Job accepted: %s" % data)
	# TODO: Implement when JobOfferComponent is extracted

func _on_mission_prepared(data: Dictionary) -> void:
	"""Handle mission preparation from MissionPrepComponent"""
	print("WorldPhaseController: Mission prepared: %s" % data)
	# TODO: Implement when MissionPrepComponent is extracted

func _on_phase_transition_requested(data: Dictionary) -> void:
	"""Handle phase transition requests from components"""
	print("WorldPhaseController: Phase transition requested: %s" % data)
	# Handle component-requested phase transitions

## World Phase Completion
func _complete_world_phase() -> void:
	"""Complete the entire world phase and transition to battle"""
	print("WorldPhaseController: Completing world phase")
	
	# Gather results from all components
	var world_phase_results = {
		"upkeep_results": upkeep_component.get_upkeep_results() if upkeep_component else {},
		"crew_task_results": {}, # TODO: Get from CrewTaskComponent
		"job_results": {}, # TODO: Get from JobOfferComponent
		"mission_data": {} # TODO: Get from MissionPrepComponent
	}
	
	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "world_phase",
			"results": world_phase_results,
			"next_phase": "battle_phase"
		})
	
	print("WorldPhaseController: World phase completed successfully")

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
		WorldPhaseStep.MISSION_PREP: false
	}
	
	# Reset components
	if upkeep_component:
		upkeep_component.reset_upkeep_phase()
	
	_update_ui_display()
	_show_current_step()
	
	print("WorldPhaseController: Reset for new campaign turn")

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
	"""Initialize mission selection UI for Job Offers step"""
	if job_offer_container:
		# Load mission selection UI scene
		var mission_selection_scene = load("res://src/ui/screens/world/MissionSelectionUI.tscn")
		if mission_selection_scene:
			mission_selection_ui = mission_selection_scene.instantiate()
			job_offer_container.add_child(mission_selection_ui)
			
			# Connect mission selection signals
			if mission_selection_ui.has_signal("mission_selected"):
				mission_selection_ui.mission_selected.connect(_on_mission_selected)
			if mission_selection_ui.has_signal("mission_selection_cancelled"):
				mission_selection_ui.mission_selection_cancelled.connect(_on_mission_selection_cancelled)
			
			print("WorldPhaseController: Mission selection UI initialized")
		else:
			push_error("WorldPhaseController: Failed to load MissionSelectionUI scene")
	else:
		push_error("WorldPhaseController: job_offer_container not found")

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
	
	# Determine next step based on current step
	match current_step:
		WorldPhaseStep.UPKEEP:
			current_step = WorldPhaseStep.CREW_TASKS
			_update_ui_display()
		WorldPhaseStep.CREW_TASKS:
			current_step = WorldPhaseStep.JOB_OFFERS
			_update_ui_display()
		WorldPhaseStep.JOB_OFFERS:
			current_step = WorldPhaseStep.MISSION_PREP
			_update_ui_display()
		WorldPhaseStep.MISSION_PREP:
			_complete_world_phase()
		_:
			push_warning("WorldPhaseController: Unknown step, completing phase")
			_complete_world_phase()

func _update_phase_display() -> void:
	"""Update the UI to reflect current phase step"""
	_update_ui_display()