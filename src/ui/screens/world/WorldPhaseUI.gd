@tool
extends FPCM_CampaignResponsiveLayout
class_name WorldPhaseUI

## World Phase UI - Feature 6 Implementation
## Complete responsive layout integration with WorldPhase.gd backend
## Follows FPCM_CampaignResponsiveLayout patterns and Digital Dice System

const WorldPhase = preload("res://src/core/campaign/phases/WorldPhase.gd")
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const FPCM_DataManager = preload("res://src/core/data/DataManager.gd")
const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")

# Feature 8: Job System Integration
const JobDataAdapter = preload("res://src/core/world_phase/JobDataAdapter.gd")
const JobSelectionUI = preload("res://src/ui/screens/world/JobSelectionUI.gd")

# Signal declarations for World Phase workflow
signal world_phase_started()
signal world_phase_completed()
signal crew_task_assigned(crew_id: String, task_type: String)
signal crew_task_resolved(crew_id: String, result: WorldPhaseResources.CrewTaskResult)
signal patron_contacted(patron_data: WorldPhaseResources.PatronData)
signal contact_discovered(contact: Dictionary)
signal job_offer_generated(job: WorldPhaseResources.JobOpportunity)
signal job_accepted(job_id: String)
signal equipment_discovered(equipment: WorldPhaseResources.EquipmentDiscovery)
signal world_phase_step_changed(step: int, step_name: String)
signal automation_toggled(enabled: bool)
signal job_selected(job: Resource)
signal screen_size_changed()
signal phase_completed()

# Real-time feedback signals
signal feedback_animation_requested(animation_type: String, data: Dictionary)
signal progress_bar_updated(id: String, progress: float, status: String)
signal notification_displayed(notification: Dictionary)
signal critical_event_highlighted(event_data: Dictionary)

# Feature 8: Job System Signal Bridge
signal job_selection_opened()
signal job_selection_closed()
signal job_validation_started(job: Resource)
signal job_validation_completed(job: Resource, is_valid: bool, errors: Array[String])
signal job_acceptance_started(job: Resource)
signal job_acceptance_completed(job: Resource, success: bool)
signal job_acceptance_failed(job: Resource, error_message: String)
signal job_workflow_state_changed(new_state: String, context: Dictionary)
signal job_system_error(error_type: String, error_message: String, context: Dictionary)
signal job_offers_updated(job_offers: Array)

# Core system references
var world_phase: WorldPhase = null
var world_phase_state: WorldPhaseResources.WorldPhaseState = null
var data_manager: FPCM_DataManager = null
var signals_manager: EnhancedCampaignSignals = null
var automation_controller: WorldPhaseAutomationController = null
var game_state_manager: Node = null

# UI State management
var current_step: int = 0
var total_steps: int = 4
var step_names: Array[String] = ["Upkeep", "Crew Tasks", "Job Offers", "Mission Prep"]
var automation_enabled: bool = false
var crew_task_cards: Array[Control] = []
var job_offer_cards: Array[Control] = []

# Feature 8: Job System Components
var job_selection_ui: JobSelectionUI = null
var job_selection_container: Control = null
var job_validation_system: Node = null
var current_job_workflow_state: String = "none"
var selected_job: Resource = null
var available_job_offers: Array[Resource] = []
var job_error_count: int = 0
var job_system_initialized: bool = false

# Real-time feedback system
var task_progress_bars: Dictionary = {} # crew_id -> ProgressBar
var notification_container: Control = null
var active_notifications: Array[Control] = []
var batch_progress_bar: ProgressBar = null
var dice_animation_display: Control = null
var critical_event_overlay: Control = null
var feedback_animations_enabled: bool = true
var max_notifications: int = 5

# UI Component references (created dynamically for responsive layout)
var header_panel: Control = null
var step_navigation: Control = null
var content_container: Control = null
var sidebar_panel: Control = null
var progress_display: Control = null
var automation_controls: Control = null

# Real-time feedback UI components
var task_progress_container: Control = null
var feedback_overlay: Control = null
var dice_result_display: Control = null

# Extracted Components
const CrewTaskPanel = preload("res://src/ui/screens/world/components/CrewTaskPanel.gd")
const JobOfferPanel = preload("res://src/ui/screens/world/components/JobOfferPanel.gd")
var extracted_crew_task_panel: CrewTaskPanel = null
var extracted_job_offer_panel: JobOfferPanel = null

# Legacy UI variables for backward compatibility
var campaign_data: Resource = null
var job_system: Node = null
var current_world: String = "Unknown World"
var title_label: Label = null
var task_assignment: OptionButton = null
var resolve_task_button: Button = null

# CRITICAL FIX: UI Component References - Must be declared BEFORE usage
@onready var crew_list: ItemList
@onready var patron_list: ItemList
@onready var job_details: RichTextLabel

# CRITICAL FIX: Feature Control Flags - Must be declared before usage
var enable_component_extraction_debug: bool = false
var enable_extracted_crew_tasks: bool = true
var enable_extracted_job_offers: bool = true
var enable_extracted_upkeep: bool = true

# CRITICAL FIX: Additional missing variables
var is_automation_enabled: bool = false
var extracted_upkeep_panel: Control

func _ready() -> void:
	super._ready()
	_initialize_core_systems()
	_create_responsive_layout()
	_setup_world_phase_ui()
	_connect_world_phase_signals()
	_initialize_automation_system()
	_setup_real_time_feedback()
	_connect_automation_controller()
	# Feature 8: Initialize job system integration
	_initialize_job_system_integration()
	_setup_job_signal_bridge()
	_connect_job_system_signals()
	# Unified Features 7 & 8: Connect all panel signals for complete automation integration
	_connect_panel_signals()
	# Phase 2: Setup world phase icons
	_setup_world_phase_icons()

	extracted_job_offer_panel = JobOfferPanel.new()
	add_child(extracted_job_offer_panel)

func _initialize_core_systems() -> void:
	# Initialize core world phase systems
	world_phase = WorldPhase.new()
	world_phase_state = WorldPhaseResources.create_world_phase_state()
	
	# Get data manager instance - use safe loading
	data_manager = null
	if ClassDB.class_exists("FPCM_DataManager"):
		data_manager = FPCM_DataManager.new()
	if not data_manager:
		push_warning("WorldPhaseUI: DataManager not available - using fallback")
	
	# Get signals manager - use safe loading
	signals_manager = null
	if ClassDB.class_exists("EnhancedCampaignSignals"):
		signals_manager = EnhancedCampaignSignals.new()
	if not signals_manager:
		push_warning("WorldPhaseUI: EnhancedCampaignSignals not available - using fallback")
	
	# SPRINT ENHANCEMENT: Initialize validated backend systems
	_initialize_backend_integration_systems()
	
	# Connect world phase to data layer
	world_phase.initialize_with_data_manager(data_manager)
	world_phase.connect_to_signals(signals_manager)
	
	# Initialize automation controller
	automation_controller = WorldPhaseAutomationController.new()
	add_child(automation_controller)
	automation_controller.initialize(world_phase, null, self)
	_connect_automation_signals()

## SPRINT ENHANCEMENT: Backend Integration Systems

func _initialize_backend_integration_systems() -> void:
	"""Initialize the validated backend systems for world phase operations"""
	print("WorldPhaseUI: Initializing backend integration systems...")
	
	# Initialize ContactManager for NPC/contact tracking
	var ContactManager = preload("res://src/core/world/ContactManager.gd")
	if ContactManager:
		var contact_manager = ContactManager.new()
		add_child(contact_manager)
		contact_manager.name = "BackendContactManager"
		print("WorldPhaseUI: ContactManager initialized")
		
		# Connect contact manager signals
		contact_manager.contact_discovered.connect(_on_backend_contact_discovered)
		contact_manager.contact_reputation_changed.connect(_on_backend_contact_reputation_changed)
	else:
		push_warning("WorldPhaseUI: ContactManager not available")
	
	# Initialize PatronJobGenerator for patron missions
	var PatronJobGenerator = preload("res://src/core/patrons/PatronJobGenerator.gd")
	if PatronJobGenerator:
		var patron_generator = PatronJobGenerator.new()
		add_child(patron_generator)
		patron_generator.name = "BackendPatronGenerator"
		print("WorldPhaseUI: PatronJobGenerator initialized")
		
		# Connect patron generator signals
		patron_generator.patron_job_generated.connect(_on_backend_patron_job_generated)
		patron_generator.patron_relationship_updated.connect(_on_backend_patron_relationship_updated)
	else:
		push_warning("WorldPhaseUI: PatronJobGenerator not available")
	
	# Initialize PlanetDataManager for world persistence
	var PlanetDataManager = preload("res://src/core/world/PlanetDataManager.gd")
	if PlanetDataManager:
		var planet_manager = PlanetDataManager.new()
		add_child(planet_manager)
		planet_manager.name = "BackendPlanetManager"
		print("WorldPhaseUI: PlanetDataManager initialized")
		
		# Connect planet manager signals
		planet_manager.planet_discovered.connect(_on_backend_planet_discovered)
		planet_manager.planet_visited.connect(_on_backend_planet_visited)
	else:
		push_warning("WorldPhaseUI: PlanetDataManager not available")
	
	# Initialize RivalBattleGenerator for rival encounters
	var RivalBattleGenerator = preload("res://src/core/rivals/RivalBattleGenerator.gd")
	if RivalBattleGenerator:
		var rival_generator = RivalBattleGenerator.new()
		add_child(rival_generator)
		rival_generator.name = "BackendRivalGenerator"
		print("WorldPhaseUI: RivalBattleGenerator initialized")
		
		# Connect rival generator signals
		rival_generator.rival_battle_generated.connect(_on_backend_rival_battle_generated)
		rival_generator.rival_escalated.connect(_on_backend_rival_escalated)
	else:
		push_warning("WorldPhaseUI: RivalBattleGenerator not available")
	
	print("WorldPhaseUI: Backend integration systems initialization complete")

## Backend System Signal Handlers

func _on_backend_contact_discovered(contact) -> void:
	"""Handle contact discovery from backend ContactManager"""
	print("WorldPhaseUI: Backend contact discovered - %s" % contact.name)
	
	# Update UI to show new contact
	if patron_list:
		patron_list.add_item(contact.name + " (" + contact.contact_type + ")")
	
	# Emit UI signal for further processing
	contact_discovered.emit(contact)

func _on_backend_contact_reputation_changed(contact_id: String, old_reputation: int, new_reputation: int) -> void:
	"""Handle contact reputation changes from backend"""
	print("WorldPhaseUI: Contact %s reputation changed: %d -> %d" % [contact_id, old_reputation, new_reputation])

func _on_backend_patron_job_generated(job) -> void:
	"""Handle patron job generation from backend PatronJobGenerator"""
	print("WorldPhaseUI: Backend patron job generated - %s" % job.mission_title)
	
	# Update job details display
	if job_details:
		var job_text = "JOB: %s\n%s\nPayment: %d credits" % [job.mission_title, job.mission_description, job.base_payment]
		job_details.text = job_text
	
	# Emit UI signal for job processing
	job_offer_generated.emit(job)

func _on_backend_patron_relationship_updated(patron_id: String, relationship_level: int) -> void:
	"""Handle patron relationship updates from backend"""
	print("WorldPhaseUI: Patron %s relationship updated to %d" % [patron_id, relationship_level])

func _on_backend_planet_discovered(planet_data: Variant) -> void:
	"""Handle planet discovery from backend PlanetDataManager"""
	print("WorldPhaseUI: Backend planet discovered - %s" % planet_data.name)

func _on_backend_planet_visited(planet_id: String, visit_count: int) -> void:
	"""Handle planet visit tracking from backend"""
	print("WorldPhaseUI: Planet %s visited (count: %d)" % [planet_id, visit_count])

func _on_backend_rival_battle_generated(battle_data: Variant) -> void:
	"""Handle rival battle generation from backend RivalBattleGenerator"""
	print("WorldPhaseUI: Backend rival battle generated - %s" % battle_data.battle_type)

func _on_backend_rival_escalated(rival_id: String, new_threat_level: int) -> void:
	"""Handle rival escalation from backend"""
	print("WorldPhaseUI: Rival %s escalated to threat level %d" % [rival_id, new_threat_level])

## Backend System Interaction Methods

func generate_random_contact_backend(planet_id: String, turn_number: int = 0) -> void:
	"""Generate a random contact using the backend ContactManager"""
	var contact_manager = get_node("BackendContactManager")
	if contact_manager and contact_manager.has_method("generate_random_contact"):
		var contact = contact_manager.generate_random_contact(planet_id, turn_number)
		print("WorldPhaseUI: Generated random contact through backend - %s" % contact.name)
	else:
		print("WorldPhaseUI: ContactManager not available for random contact generation")

func generate_patron_job_backend(patron_data: Variant, crew_size: int = 4, relationship_level: int = 0) -> void:
	"""Generate a patron job using the backend PatronJobGenerator"""
	var patron_generator = get_node("BackendPatronGenerator")
	if patron_generator and patron_generator.has_method("generate_patron_job"):
		var job = patron_generator.generate_patron_job(patron_data, crew_size, relationship_level)
		print("WorldPhaseUI: Generated patron job through backend - %s" % job.mission_title)
	else:
		print("WorldPhaseUI: PatronJobGenerator not available for job generation")

func check_rival_encounter_backend(rival_data: Variant, current_turn: int, crew_size: int = 4) -> void:
	"""Check for rival encounter using the backend RivalBattleGenerator"""
	var rival_generator = get_node("BackendRivalGenerator")
	if rival_generator and rival_generator.has_method("should_rival_attack"):
		var should_attack = rival_generator.should_rival_attack(rival_data, current_turn)
		if should_attack and rival_generator.has_method("generate_rival_battle"):
			var battle = rival_generator.generate_rival_battle(rival_data, current_turn, crew_size)
			print("WorldPhaseUI: Rival encounter generated through backend - %s" % battle.battle_type)
		else:
			print("WorldPhaseUI: No rival encounter this turn")
	else:
		print("WorldPhaseUI: RivalBattleGenerator not available for encounter check")

func update_planet_data_backend(planet_id: String, campaign_turn: int = 0) -> void:
	"""Update or generate planet data using the backend PlanetDataManager"""
	var planet_manager = get_node("BackendPlanetManager")
	if planet_manager and planet_manager.has_method("get_or_generate_planet"):
		var planet_data = planet_manager.get_or_generate_planet(planet_id, campaign_turn)
		print("WorldPhaseUI: Planet data updated through backend - %s" % planet_data.name)
		
		# Update current world display
		if planet_data:
			current_world = planet_data.name
			_update_world_display()
	else:
		print("WorldPhaseUI: PlanetDataManager not available for planet data update")

func _update_world_display() -> void:
	"""Update the world display with current world information"""
	if title_label:
		title_label.text = "World Phase - %s" % current_world

func _create_responsive_layout() -> void:
	# Create header panel in sidebar for mobile, top for desktop
	header_panel = _create_header_panel()
	step_navigation = _create_step_navigation()
	content_container = _create_content_container()
	progress_display = _create_progress_display()
	automation_controls = _create_automation_controls()
	
	# Add to appropriate containers based on orientation
	if sidebar:
		sidebar.add_child(header_panel)
		sidebar.add_child(step_navigation)
		sidebar.add_child(progress_display)
		sidebar.add_child(automation_controls)
	
	if main_content:
		main_content.add_child(content_container)

func _create_header_panel() -> Control:
	var panel = VBoxContainer.new()
	panel.name = "HeaderPanel"
	
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "World Phase"
	# Use existing sci-fi theme for styling
	title_label.add_theme_font_size_override("font_size", 24)
	panel.add_child(title_label)
	
	var world_label = Label.new()
	world_label.name = "WorldLabel"
	world_label.text = "Current World: Unknown"
	world_label.add_theme_color_override("font_color", Color.GRAY)
	panel.add_child(world_label)
	
	return panel

func _create_step_navigation() -> Control:
	var nav_container = VBoxContainer.new()
	nav_container.name = "StepNavigation"
	
	var nav_label = Label.new()
	nav_label.text = "Phase Steps"
	# Use existing theme styling
	nav_label.add_theme_font_size_override("font_size", 18)
	nav_container.add_child(nav_label)
	
	# Create step buttons with touch-friendly sizing
	for i in range(total_steps):
		var step_button = Button.new()
		step_button.name = "Step%dButton" % (i + 1)
		step_button.text = "%d. %s" % [i + 1, step_names[i]]
		step_button.add_to_group("touch_buttons")
		step_button.pressed.connect(_on_step_button_pressed.bind(i))
		step_button.disabled = i > 0 # Only first step enabled initially
		nav_container.add_child(step_button)
	
	return nav_container

func _create_content_container() -> Control:
	var container = VBoxContainer.new()
	container.name = "ContentContainer"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Create navigation buttons for main content
	var nav_buttons = HBoxContainer.new()
	nav_buttons.name = "NavigationButtons"
	
	var back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "← Back"
	back_button.add_to_group("touch_buttons")
	back_button.pressed.connect(_on_back_pressed)
	nav_buttons.add_child(back_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_buttons.add_child(spacer)
	
	var next_button = Button.new()
	next_button.name = "NextButton"
	next_button.text = "Next →"
	next_button.add_to_group("touch_buttons")
	next_button.pressed.connect(_on_next_pressed)
	nav_buttons.add_child(next_button)
	
	container.add_child(nav_buttons)
	
	# Create content area
	var content_area = VBoxContainer.new()
	content_area.name = "ContentArea"
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(content_area)
	
	return container

func _create_progress_display() -> Control:
	var display = VBoxContainer.new()
	display.name = "ProgressDisplay"
	
	var progress_label = Label.new()
	progress_label.text = "Progress"
	# Use existing theme styling
	progress_label.add_theme_font_size_override("font_size", 18)
	display.add_child(progress_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.name = "PhaseProgressBar"
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	display.add_child(progress_bar)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Ready to begin"
	status_label.add_theme_color_override("font_color", Color.GRAY)
	display.add_child(status_label)
	
	return display

func _create_automation_controls() -> Control:
	var controls = VBoxContainer.new()
	controls.name = "AutomationControls"
	
	# Automation header
	var auto_label = Label.new()
	auto_label.text = "Automation & Controls"
	# Use existing theme styling
	auto_label.add_theme_font_size_override("font_size", 18)
	controls.add_child(auto_label)
	
	# Master automation toggle
	var auto_toggle = CheckBox.new()
	auto_toggle.name = "AutomationToggle"
	auto_toggle.text = "Enable Automation"
	auto_toggle.toggled.connect(_on_automation_toggled)
	controls.add_child(auto_toggle)
	
	# Separator
	var separator1 = HSeparator.new()
	controls.add_child(separator1)
	
	# Crew task automation section
	var crew_section = VBoxContainer.new()
	crew_section.name = "CrewAutomationSection"
	
	var crew_label = Label.new()
	crew_label.text = "Crew Tasks"
	crew_label.add_theme_color_override("font_color", Color.CYAN)
	crew_section.add_child(crew_label)
	
	var auto_crew_button = Button.new()
	auto_crew_button.name = "AutoResolveCrewButton"
	auto_crew_button.text = "Auto-Resolve Crew Tasks"
	auto_crew_button.add_to_group("touch_buttons")
	auto_crew_button.pressed.connect(_on_auto_resolve_crew_tasks)
	auto_crew_button.disabled = true
	crew_section.add_child(auto_crew_button)
	
	controls.add_child(crew_section)
	
	# Job selection automation section
	var job_section = VBoxContainer.new()
	job_section.name = "JobAutomationSection"
	
	var job_label = Label.new()
	job_label.text = "Job Selection"
	job_label.add_theme_color_override("font_color", Color.GREEN)
	job_section.add_child(job_label)
	
	var auto_job_button = Button.new()
	auto_job_button.name = "AutoSelectJobButton"
	auto_job_button.text = "Auto-Select Best Job"
	auto_job_button.add_to_group("touch_buttons")
	auto_job_button.pressed.connect(_on_auto_select_job)
	auto_job_button.disabled = true
	job_section.add_child(auto_job_button)
	
	controls.add_child(job_section)
	
	# Separator
	var separator2 = HSeparator.new()
	controls.add_child(separator2)
	
	# Complete automation section
	var complete_section = VBoxContainer.new()
	complete_section.name = "CompleteAutomationSection"
	
	var complete_label = Label.new()
	complete_label.text = "Full Automation"
	complete_label.add_theme_color_override("font_color", Color.ORANGE)
	complete_section.add_child(complete_label)
	
	var auto_all_button = Button.new()
	auto_all_button.name = "AutoResolveAllButton"
	auto_all_button.text = "Auto-Complete Phase"
	auto_all_button.add_to_group("touch_buttons")
	auto_all_button.pressed.connect(_on_auto_complete_phase)
	auto_all_button.disabled = true
	complete_section.add_child(auto_all_button)
	
	controls.add_child(complete_section)
	
	# Separator
	var separator3 = HSeparator.new()
	controls.add_child(separator3)
	
	# Manual override section
	var override_section = VBoxContainer.new()
	override_section.name = "ManualOverrideSection"
	
	var override_label = Label.new()
	override_label.text = "Manual Override"
	override_label.add_theme_color_override("font_color", Color.RED)
	override_section.add_child(override_label)
	
	var pause_button = Button.new()
	pause_button.name = "PauseAutomationButton"
	pause_button.text = "Pause Automation"
	pause_button.add_to_group("touch_buttons")
	pause_button.pressed.connect(_on_pause_automation)
	pause_button.disabled = true
	override_section.add_child(pause_button)
	
	var reset_button = Button.new()
	reset_button.name = "ResetPhaseButton"
	reset_button.text = "Reset Phase"
	reset_button.add_to_group("touch_buttons")
	reset_button.pressed.connect(_on_reset_phase)
	override_section.add_child(reset_button)
	
	controls.add_child(override_section)
	
	return controls

func _setup_world_phase_ui() -> void:
	# Initialize with first step
	current_step = 0
	_show_step(current_step)
	_update_progress_display()
	_update_step_navigation()

func setup_phase(campaign_data: Resource) -> void:
	if not campaign_data:
		push_error("WorldPhaseUI: No campaign data provided")
		return
	
	# Initialize world phase with campaign data
	world_phase.setup_campaign_data(campaign_data)
	world_phase_state.world_name = world_phase.get_current_world_name()
	world_phase_state.world_traits = world_phase.get_current_world_traits()
	world_phase_state.start_phase()
	
	# Update UI with world information
	_update_world_display()
	_refresh_content_for_step(current_step)
	
	# Emit startup signal
	world_phase_started.emit()
	if signals_manager:
		signals_manager.emit_world_phase_started(world_phase_state.serialize())

func _connect_world_phase_signals() -> void:
	if not signals_manager:
		return
	
	# Connect to world phase signals - with safe fallbacks
	if signals_manager.has_signal("crew_task_started"):
		signals_manager.crew_task_started.connect(_on_crew_task_started)
	if signals_manager.has_signal("crew_task_completed"):
		signals_manager.crew_task_completed.connect(_on_crew_task_completed)
	if signals_manager.has_signal("patron_contacted"):
		signals_manager.patron_contacted.connect(_on_patron_contacted)
	if signals_manager.has_signal("job_offer_generated"):
		signals_manager.job_offer_generated.connect(_on_job_offer_generated)
	if signals_manager.has_signal("equipment_discovered"):
		signals_manager.equipment_discovered.connect(_on_equipment_discovered)
	if signals_manager.has_signal("world_phase_automation_update"):
		signals_manager.world_phase_automation_update.connect(_on_automation_update)
	
	# Connect internal signals
	world_phase_step_changed.connect(_on_step_changed)
	automation_toggled.connect(_on_automation_mode_changed)
	
	# Add missing signal handlers
	_register_missing_signal_handlers()
	
	# Connect to CampaignPhaseManager for campaign flow integration
	var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if campaign_phase_manager:
		# Connect UI completion signal to phase manager
		world_phase_completed.connect(campaign_phase_manager._on_world_phase_completed)
		print("WorldPhaseUI: Connected to CampaignPhaseManager")
	else:
		push_warning("WorldPhaseUI: CampaignPhaseManager not found - phase transitions may not work")

func _connect_automation_signals() -> void:
	if not automation_controller:
		return
	
	# Connect automation feedback signals
	automation_controller.task_progress_updated.connect(_on_task_progress_updated)
	automation_controller.critical_event_occurred.connect(_on_critical_event_occurred)
	automation_controller.batch_progress_updated.connect(_on_batch_progress_updated)
	automation_controller.notification_triggered.connect(_on_notification_triggered)
	automation_controller.visual_feedback_requested.connect(_on_visual_feedback_requested)
	automation_controller.dice_animation_triggered.connect(_on_dice_animation_triggered)
	
	print("WorldPhaseUI: Automation controller signals connected")

## =================================================================
## UNIFIED FEATURES 7 & 8: COMPREHENSIVE PANEL SIGNAL INTEGRATION
## =================================================================

## Connect all panel signals for unified automation and manual control
func _connect_panel_signals() -> void:
	print("WorldPhaseUI: Connecting unified panel signals for Features 7 & 8")
	
	# Core panel signal connections
	_connect_core_automation_panel_signals()
	_connect_crew_task_panel_signals()
	_connect_job_selection_panel_signals()
	_connect_manual_override_panel_signals()
	_connect_progress_tracking_panel_signals()
	_connect_responsive_layout_signals()
	
	# Connect unified workflow signals
	_connect_unified_workflow_signals()
	
	print("WorldPhaseUI: All panel signals connected successfully")

## Connect core automation panel signals
func _connect_core_automation_panel_signals() -> void:
	if not automation_controls:
		print("WorldPhaseUI: Automation controls not available for signal connection")
		return
	
	# Enhanced automation toggle with unified features
	var auto_toggle = automation_controls.get_node_or_null("AutomationToggle")
	if auto_toggle and not auto_toggle.toggled.is_connected(_on_unified_automation_toggled):
		auto_toggle.toggled.connect(_on_unified_automation_toggled)
	
	# Enhanced auto-resolve button for both crew tasks and jobs
	var auto_resolve_button = automation_controls.get_node_or_null("AutoResolveButton")
	if auto_resolve_button and not auto_resolve_button.pressed.is_connected(_on_unified_auto_resolve_all):
		auto_resolve_button.pressed.connect(_on_unified_auto_resolve_all)
	
	# Add new automation controls for unified features
	_create_unified_automation_controls()

## Connect crew task panel signals (Feature 7)
func _connect_crew_task_panel_signals() -> void:
	# Connect to automation controller crew task signals
	if automation_controller:
		if not automation_controller.all_crew_tasks_resolved.is_connected(_on_all_crew_tasks_resolved):
			automation_controller.all_crew_tasks_resolved.connect(_on_all_crew_tasks_resolved)
		
		if not automation_controller.phase_step_completed.is_connected(_on_automation_phase_step_completed):
			automation_controller.phase_step_completed.connect(_on_automation_phase_step_completed)
	
	# Connect internal crew task workflow signals
	crew_task_assigned.connect(_on_unified_crew_task_assigned)
	crew_task_resolved.connect(_on_unified_crew_task_resolved)

## Connect job selection panel signals (Feature 8)
func _connect_job_selection_panel_signals() -> void:
	# Internal job system signals are already connected in _setup_job_signal_bridge()
	# Add unified workflow connections
	job_selected.connect(_on_unified_job_selected)
	job_acceptance_completed.connect(_on_unified_job_acceptance_completed)
	job_system_error.connect(_on_unified_job_system_error)

## Connect manual override panel signals
func _connect_manual_override_panel_signals() -> void:
	# These will be created dynamically based on current step
	# Connected when panels are created in _create_step_content methods
	pass

## Connect progress tracking panel signals
func _connect_progress_tracking_panel_signals() -> void:
	# Connect to existing progress tracking system
	progress_bar_updated.connect(_on_unified_progress_bar_updated)
	notification_displayed.connect(_on_unified_notification_displayed)
	critical_event_highlighted.connect(_on_unified_critical_event_highlighted)

## Connect responsive layout signals
func _connect_responsive_layout_signals() -> void:
	# Connect to base responsive layout signals if available
	if has_signal("orientation_changed"):
		orientation_changed.connect(_on_unified_orientation_changed)
	
	if has_signal("screen_size_changed"):
		screen_size_changed.connect(_on_unified_screen_size_changed)

## Connect unified workflow signals that coordinate Features 7 & 8
func _connect_unified_workflow_signals() -> void:
	# World phase progression signals
	world_phase_step_changed.connect(_on_unified_step_changed)
	world_phase_completed.connect(_on_unified_world_phase_completed)
	automation_toggled.connect(_on_unified_automation_state_changed)
	
	# Cross-feature coordination signals
	_connect_cross_feature_coordination_signals()

## Connect signals that coordinate between crew tasks and job selection
func _connect_cross_feature_coordination_signals() -> void:
	# When crew tasks complete, automatically move to job selection if enabled
	if automation_controller and automation_controller.has_signal("automation_step_completed"):
		automation_controller.automation_step_completed.connect(_on_automation_step_completed_unified)
	
	# When job is selected/accepted, coordinate with crew assignments
	job_workflow_state_changed.connect(_on_job_workflow_state_changed_unified)

## =================================================================
## UNIFIED AUTOMATION CONTROLS CREATION
## =================================================================

## Create unified automation controls that handle both Features 7 & 8
func _create_unified_automation_controls() -> void:
	if not automation_controls:
		return
	
	# Create automation mode selector
	var mode_selector = _create_automation_mode_selector()
	automation_controls.add_child(mode_selector)
	
	# Create unified progress display
	var unified_progress = _create_unified_progress_display()
	automation_controls.add_child(unified_progress)
	
	# Create manual override controls
	var manual_controls = _create_manual_override_controls()
	automation_controls.add_child(manual_controls)
	
	# Create automation status display
	var status_display = _create_automation_status_display()
	automation_controls.add_child(status_display)

## Create automation mode selector (crew only, jobs only, or unified)
func _create_automation_mode_selector() -> Control:
	var container = VBoxContainer.new()
	container.name = "AutomationModeSelector"
	
	var label = Label.new()
	label.text = "Automation Mode"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.CYAN)
	container.add_child(label)
	
	var mode_options = OptionButton.new()
	mode_options.name = "AutomationModeOptions"
	mode_options.add_item("Manual Only")
	mode_options.add_item("Crew Tasks Only")
	mode_options.add_item("Job Selection Only")
	mode_options.add_item("Full Automation")
	mode_options.selected = 0 # Default to manual
	mode_options.item_selected.connect(_on_automation_mode_selected)
	container.add_child(mode_options)
	
	return container

## Create unified progress display for both crew tasks and jobs
func _create_unified_progress_display() -> Control:
	var container = VBoxContainer.new()
	container.name = "UnifiedProgressDisplay"
	
	var label = Label.new()
	label.text = "Unified Progress"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.GREEN)
	container.add_child(label)
	
	# Overall phase progress
	var phase_progress = ProgressBar.new()
	phase_progress.name = "PhaseProgress"
	phase_progress.max_value = 100.0
	phase_progress.value = 0.0
	phase_progress.show_percentage = true
	container.add_child(phase_progress)
	
	# Current operation status
	var status_label = Label.new()
	status_label.name = "CurrentOperationStatus"
	status_label.text = "Ready"
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color.GRAY)
	container.add_child(status_label)
	
	return container

## Create manual override controls for fine-grained control
func _create_manual_override_controls() -> Control:
	var container = VBoxContainer.new()
	container.name = "ManualOverrideControls"
	
	var label = Label.new()
	label.text = "Manual Overrides"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.ORANGE)
	container.add_child(label)
	
	# Stop automation button
	var stop_button = Button.new()
	stop_button.name = "StopAutomationButton"
	stop_button.text = "Stop Automation"
	stop_button.add_to_group("touch_buttons")
	stop_button.pressed.connect(_on_stop_automation)
	stop_button.disabled = true # Enabled when automation is running
	container.add_child(stop_button)
	
	# Skip current operation button
	var skip_button = Button.new()
	skip_button.name = "SkipOperationButton"
	skip_button.text = "Skip Current Operation"
	skip_button.add_to_group("touch_buttons")
	skip_button.pressed.connect(_on_skip_current_operation)
	skip_button.disabled = true
	container.add_child(skip_button)
	
	# Manual job selection override
	var manual_job_button = Button.new()
	manual_job_button.name = "ManualJobButton"
	manual_job_button.text = "Manual Job Selection"
	manual_job_button.add_to_group("touch_buttons")
	manual_job_button.pressed.connect(_on_manual_job_selection_override)
	container.add_child(manual_job_button)
	
	return container

## Create automation status display
func _create_automation_status_display() -> Control:
	var container = VBoxContainer.new()
	container.name = "AutomationStatusDisplay"
	
	var label = Label.new()
	label.text = "System Status"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.YELLOW)
	container.add_child(label)
	
	# Automation state indicator
	var state_label = Label.new()
	state_label.name = "AutomationStateLabel"
	state_label.text = "🔴 Automation Disabled"
	state_label.add_theme_font_size_override("font_size", 10)
	container.add_child(state_label)
	
	# Active operations counter
	var operations_label = Label.new()
	operations_label.name = "ActiveOperationsLabel"
	operations_label.text = "Active Operations: 0"
	operations_label.add_theme_font_size_override("font_size", 10)
	operations_label.add_theme_color_override("font_color", Color.GRAY)
	container.add_child(operations_label)
	
	# Performance indicator
	var performance_label = Label.new()
	performance_label.name = "PerformanceLabel"
	performance_label.text = "Performance: Good"
	performance_label.add_theme_font_size_override("font_size", 10)
	performance_label.add_theme_color_override("font_color", Color.GREEN)
	container.add_child(performance_label)
	
	return container

func _initialize_automation_system() -> void:
	# Setup automation system with Digital Dice System patterns
	automation_enabled = false
	if automation_controls:
		var toggle = automation_controls.get_node("AutomationToggle")
		if toggle:
			toggle.button_pressed = automation_enabled

## Setup real-time feedback system with UI components
func _setup_real_time_feedback() -> void:
	_create_notification_system()
	_create_progress_tracking_system()
	_create_dice_feedback_display()
	_create_critical_event_overlay()
	print("Real-time feedback system initialized for WorldPhaseUI")

## Connect to automation controller for real-time feedback
func _connect_automation_controller() -> void:
	# Create automation controller if it doesn't exist
	if not automation_controller:
		automation_controller = WorldPhaseAutomationController.new()
		add_child(automation_controller)
		automation_controller.initialize(world_phase, null, self)
	
	# Connect real-time feedback signals
	if automation_controller:
		automation_controller.task_progress_updated.connect(_on_task_progress_updated)
		automation_controller.critical_event_occurred.connect(_on_critical_event_occurred)
		automation_controller.batch_progress_updated.connect(_on_batch_progress_updated)
		automation_controller.notification_triggered.connect(_on_notification_triggered)
		automation_controller.visual_feedback_requested.connect(_on_visual_feedback_requested)
		automation_controller.dice_animation_triggered.connect(_on_dice_animation_triggered)
		print("Automation controller connected with real-time feedback")

## Create notification system UI components
func _create_notification_system() -> void:
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.add_theme_constant_override("separation", 8)
	
	# Position notification container in top-right corner
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notification_container.position.x -= 300 # Offset from right edge
	notification_container.position.y += 20 # Offset from top
	add_child(notification_container)

## Create progress tracking system for individual tasks
func _create_progress_tracking_system() -> void:
	task_progress_container = VBoxContainer.new()
	task_progress_container.name = "TaskProgressContainer"
	task_progress_container.add_theme_constant_override("separation", 4)
	
	if progress_display:
		progress_display.add_child(task_progress_container)
	
	# Create batch progress bar
	batch_progress_bar = ProgressBar.new()
	batch_progress_bar.name = "BatchProgressBar"
	batch_progress_bar.max_value = 100.0
	batch_progress_bar.value = 0.0
	batch_progress_bar.show_percentage = true
	
	if progress_display:
		progress_display.add_child(batch_progress_bar)

## Create dice feedback display system
func _create_dice_feedback_display() -> void:
	dice_result_display = VBoxContainer.new()
	dice_result_display.name = "DiceResultDisplay"
	dice_result_display.modulate.a = 0.0 # Start transparent
	
	var dice_label = Label.new()
	dice_label.name = "DiceLabel"
	dice_label.text = "🎲 Rolling..."
	dice_label.add_theme_font_size_override("font_size", 16)
	dice_result_display.add_child(dice_label)
	
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.text = ""
	result_label.add_theme_font_size_override("font_size", 14)
	result_label.add_theme_color_override("font_color", Color.GRAY)
	dice_result_display.add_child(result_label)
	
	add_child(dice_result_display)

## Create critical event overlay system
func _create_critical_event_overlay() -> void:
	critical_event_overlay = ColorRect.new()
	critical_event_overlay.name = "CriticalEventOverlay"
	critical_event_overlay.color = Color(1.0, 0.8, 0.0, 0.3) # Golden overlay
	critical_event_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	critical_event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	critical_event_overlay.visible = false
	add_child(critical_event_overlay)

## =================================================================
## UNIFIED AUTOMATION SIGNAL HANDLERS (FEATURES 7 & 8)
## =================================================================

## Enhanced automation toggle that handles both crew tasks and job selection
func _on_unified_automation_toggled(enabled: bool) -> void:
	automation_enabled = enabled
	automation_toggled.emit(enabled)
	
	print("WorldPhaseUI: Unified automation toggled: %s" % enabled)
	
	# Update automation controller
	if automation_controller:
		automation_controller.set_feedback_system_enabled(enabled)
	
	# Update UI state for both features
	_update_unified_automation_ui_state(enabled)
	
	# Emit unified automation state change
	_on_unified_automation_state_changed(enabled)

## Enhanced auto-resolve that handles both crew tasks and jobs
func _on_unified_auto_resolve_all() -> void:
	if not automation_enabled:
		show_notification(
			"Automation Disabled",
			"Enable automation to use unified auto-resolve",
			"info",
			2.0
		)
		return
	
	print("WorldPhaseUI: Starting unified auto-resolve for crew tasks and jobs")
	
	# Get automation mode to determine what to automate
	var automation_mode = _get_current_automation_mode()
	
	match automation_mode:
		"Manual Only":
			show_notification("Manual Mode", "Automation is disabled", "info", 2.0)
		"Crew Tasks Only":
			_automate_crew_tasks_only()
		"Job Selection Only":
			_automate_job_selection_only()
		"Full Automation":
			_automate_full_workflow()
		_:
			show_notification("Unknown Mode", "Unknown automation mode", "critical", 2.0)

## Handle automation mode selection
func _on_automation_mode_selected(index: int) -> void:
	var mode_names = ["Manual Only", "Crew Tasks Only", "Job Selection Only", "Full Automation"]
	var selected_mode = mode_names[index] if index < mode_names.size() else "Manual Only"
	
	print("WorldPhaseUI: Automation mode selected: %s" % selected_mode)
	
	# Update UI elements based on mode
	_update_automation_mode_ui(selected_mode)
	
	# Update automation controller configuration
	if automation_controller:
		_configure_automation_controller_for_mode(selected_mode)
	
	show_notification(
		"Automation Mode",
		"Switched to: %s" % selected_mode,
		"info",
		2.0
	)

## Handle stop automation button
func _on_stop_automation() -> void:
	print("WorldPhaseUI: Stopping all automation")
	
	# Stop automation controller
	if automation_controller and automation_controller.has_method("stop_automation"):
		automation_controller.stop_automation()
	
	# Reset job workflow if in progress
	if current_job_workflow_state != "none":
		_reset_job_workflow()
	
	# Update UI state
	automation_enabled = false
	_update_unified_automation_ui_state(false)
	
	show_notification(
		"Automation Stopped",
		"All automated processes have been stopped",
		"info",
		2.0
	)

## Handle skip current operation button
func _on_skip_current_operation() -> void:
	print("WorldPhaseUI: Skipping current operation")
	
	# Skip automation controller operation
	if automation_controller and automation_controller.has_method("skip_current_operation"):
		automation_controller.skip_current_operation()
	
	# Skip job workflow operation if applicable
	if current_job_workflow_state in ["job_validation", "job_acceptance"]:
		_skip_current_job_operation()
	
	show_notification(
		"Operation Skipped",
		"Current operation has been skipped",
		"info",
		2.0
	)

## Handle manual job selection override
func _on_manual_job_selection_override() -> void:
	print("WorldPhaseUI: Manual job selection override activated")
	
	# Temporarily disable automation for job selection
	if current_step == 2: # Job Offers step
		_enable_manual_job_selection_mode()
	else:
		# Switch to job offers step
		_show_step(2)
		# Note: await removed since this function is not async
		_enable_manual_job_selection_mode()

## Unified crew task assignment handler
func _on_unified_crew_task_assigned(crew_id: String, task_type: String) -> void:
	print("WorldPhaseUI: Unified crew task assigned - %s: %s" % [crew_id, task_type])
	
	# Update unified progress tracking
	_update_unified_progress("crew_task_assigned", {
		"crew_id": crew_id,
		"task_type": task_type,
		"progress": 0.1
	})
	
	# Update automation status if running
	_update_automation_operation_status("Processing crew task: %s" % task_type)

## Unified crew task resolution handler
func _on_unified_crew_task_resolved(crew_id: String, result: WorldPhaseResources.CrewTaskResult) -> void:
	print("WorldPhaseUI: Unified crew task resolved - %s" % crew_id)
	
	# Update unified progress tracking
	_update_unified_progress("crew_task_resolved", {
		"crew_id": crew_id,
		"result": result,
		"progress": 1.0
	})
	
	# Check if all crew tasks are complete for automation progression
	_check_crew_tasks_completion_for_automation()

## Unified job selection handler
func _on_unified_job_selected(job: Resource) -> void:
	print("WorldPhaseUI: Unified job selected: %s" % job.get_meta("job_id", "unknown"))
	
	# Update unified progress tracking
	_update_unified_progress("job_selected", {
		"job_id": job.get_meta("job_id", ""),
		"progress": 0.5
	})
	
	# Update automation status
	_update_automation_operation_status("Job selected: %s" % job.get_meta("mission_type", "Unknown"))

## Unified job acceptance completion handler
func _on_unified_job_acceptance_completed(job: Resource, success: bool) -> void:
	print("WorldPhaseUI: Unified job acceptance completed - Success: %s" % success)
	
	if success:
		# Update unified progress tracking
		_update_unified_progress("job_accepted", {
			"job_id": job.get_meta("job_id", ""),
			"progress": 1.0
		})
		
		# Move to next step if automation is enabled
		if automation_enabled and _get_current_automation_mode() in ["Full Automation", "Job Selection Only"]:
			_auto_advance_to_next_step()
	else:
		_update_unified_progress("job_acceptance_failed", {
			"job_id": job.get_meta("job_id", ""),
			"progress": 0.0
		})

## Unified job system error handler
func _on_unified_job_system_error(error_type: String, error_message: String, context: Dictionary) -> void:
	print("WorldPhaseUI: Unified job system error - %s: %s" % [error_type, error_message])
	
	# Update unified progress with error state
	_update_unified_progress("job_system_error", {
		"error_type": error_type,
		"error_message": error_message,
		"progress": 0.0
	})
	
	# Handle automation recovery
	_handle_automation_error_recovery(error_type, error_message)

## All crew tasks resolved handler (from automation controller)
func _on_all_crew_tasks_resolved(results: Array[Dictionary]) -> void:
	print("WorldPhaseUI: All crew tasks resolved - %d results" % results.size())
	
	# Update unified progress
	_update_unified_progress("all_crew_tasks_resolved", {
		"results_count": results.size(),
		"progress": 1.0
	})
	
	# Auto-advance to job selection if full automation is enabled
	if _get_current_automation_mode() == "Full Automation":
		_auto_advance_to_job_selection()

## Automation phase step completed handler
func _on_automation_phase_step_completed(step: int, results: Dictionary) -> void:
	print("WorldPhaseUI: Automation phase step completed - Step: %d" % step)
	
	# Update unified progress
	_update_unified_progress("automation_step_completed", {
		"step": step,
		"results": results,
		"progress": float(step + 1) / float(total_steps)
	})

## Unified automation step completed handler
func _on_automation_step_completed_unified(step_name: String, results: Dictionary) -> void:
	print("WorldPhaseUI: Unified automation step completed: %s" % step_name)
	
	# Coordinate between features based on step
	match step_name:
		"crew_tasks":
			if _get_current_automation_mode() in ["Full Automation"]:
				_auto_advance_to_job_selection()
		"job_selection":
			if _get_current_automation_mode() in ["Full Automation"]:
				_auto_advance_to_mission_prep()

## Unified job workflow state change handler
func _on_job_workflow_state_changed_unified(new_state: String, context: Dictionary) -> void:
	print("WorldPhaseUI: Unified job workflow state changed: %s" % new_state)
	
	# Update automation status based on job workflow state
	match new_state:
		"job_offers_available":
			_update_automation_operation_status("Job offers available")
		"job_selected":
			_update_automation_operation_status("Job selected, validating...")
		"job_accepted":
			_update_automation_operation_status("Job accepted successfully")
		"job_workflow_complete":
			_update_automation_operation_status("Job workflow complete")

## Unified step change handler
func _on_unified_step_changed(step: int, step_name: String) -> void:
	print("WorldPhaseUI: Unified step changed - %d: %s" % [step, step_name])
	
	# Update unified progress display
	_update_unified_step_progress(step, step_name)
	
	# Update automation controls based on step
	_update_automation_controls_for_step(step)

## Unified world phase completion handler
func _on_unified_world_phase_completed() -> void:
	print("WorldPhaseUI: Unified world phase completed")
	
	# Update unified progress to 100%
	_update_unified_progress("world_phase_completed", {"progress": 1.0})
	
	# Reset automation state
	automation_enabled = false
	_update_unified_automation_ui_state(false)
	
	show_notification(
		"World Phase Complete",
		"All world phase operations completed successfully",
		"success",
		3.0
	)

## Unified automation state change handler
func _on_unified_automation_state_changed(enabled: bool) -> void:
	print("WorldPhaseUI: Unified automation state changed: %s" % enabled)
	
	# Update automation status display
	_update_automation_status_display(enabled)
	
	# Enable/disable manual override controls
	_update_manual_override_controls_state(enabled)

## Unified progress, notification, and event handlers
func _on_unified_progress_bar_updated(id: String, progress: float, status: String) -> void:
	# Update unified progress display
	_update_specific_progress_bar(id, progress, status)

func _on_unified_notification_displayed(notification: Dictionary) -> void:
	# Handle unified notifications
	var title = SafeDataAccess.safe_get(notification, "title", "Notification", "unified notification")
	var message = SafeDataAccess.safe_get(notification, "message", "", "unified notification")
	var priority = SafeDataAccess.safe_get(notification, "priority", "info", "unified notification")
	var duration = SafeDataAccess.safe_get(notification, "duration", 2.0, "unified notification")
	show_notification(title, message, priority, duration)

func _on_unified_critical_event_highlighted(event_data: Dictionary) -> void:
	# Handle unified critical events
	var event_type = SafeDataAccess.safe_get(event_data, "type", "critical", "critical event handling")
	show_critical_event(event_type, event_data)

func _on_unified_orientation_changed(new_orientation: String) -> void:
	# Handle responsive layout changes
	_adapt_automation_controls_to_orientation(new_orientation)

func _on_unified_screen_size_changed(new_size: Vector2) -> void:
	# Handle screen size changes
	_adapt_automation_controls_to_screen_size(new_size)

## REAL-TIME FEEDBACK HANDLERS

## Handle individual task progress updates
func update_task_progress(crew_member: String, task_type: String, progress: float, status: String) -> void:
	var progress_id := "%s_%s" % [crew_member, task_type]
	
	# Create or update progress bar for this task
	if not task_progress_bars.has(progress_id):
		var task_progress_item = _create_task_progress_item(crew_member, task_type)
		task_progress_container.add_child(task_progress_item)
		task_progress_bars[progress_id] = task_progress_item.get_node("ProgressBar")
	
	var progress_bar: ProgressBar = task_progress_bars[progress_id]
	var status_label: Label = progress_bar.get_parent().get_node("StatusLabel")
	
	# Animate progress bar update
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", progress * 100.0, 0.2)
	
	# Update status
	status_label.text = status
	
	# Change color based on progress
	if progress >= 1.0:
		progress_bar.add_theme_color_override("fill", Color.GREEN)
		status_label.add_theme_color_override("font_color", Color.GREEN)
		# Auto-remove completed progress bars after a delay
		# Note: await removed since this function is not async
		_remove_task_progress_item(progress_id)

## Create individual task progress item
func _create_task_progress_item(crew_member: String, task_type: String) -> Control:
	var container = VBoxContainer.new()
	container.name = "TaskProgress_%s_%s" % [crew_member, task_type]
	
	var label = Label.new()
	label.name = "TaskLabel"
	label.text = "%s - %s" % [crew_member, task_type]
	label.add_theme_font_size_override("font_size", 12)
	container.add_child(label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	container.add_child(progress_bar)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Starting..."
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color.GRAY)
	container.add_child(status_label)
	
	return container

## Remove completed task progress item
func _remove_task_progress_item(progress_id: String) -> void:
	if task_progress_bars.has(progress_id):
		var progress_bar: ProgressBar = task_progress_bars[progress_id]
		var container = progress_bar.get_parent()
		
		# Fade out animation
		var tween = create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.5)
		# Note: await removed since this function is not async
		
		# Remove from tracking and UI
		task_progress_bars.erase(progress_id)
		container.queue_free()

## Handle batch progress updates
func update_batch_progress(completed_tasks: int, total_tasks: int, current_task: String) -> void:
	if not batch_progress_bar:
		return
	
	var progress_percentage := 0.0 if total_tasks == 0 else (float(completed_tasks) / float(total_tasks)) * 100.0
	
	# Animate batch progress bar
	var tween = create_tween()
	tween.tween_property(batch_progress_bar, "value", progress_percentage, 0.3)
	
	# Update status label in progress display
	var status_label = progress_display.get_node("StatusLabel")
	if status_label:
		status_label.text = current_task

## Handle notification display
func show_notification(title: String, message: String, priority: String, duration: float) -> void:
	var notification = _create_notification(title, message, priority, duration)
	notification_container.add_child(notification)
	active_notifications.append(notification)
	
	# Animate notification appearance
	notification.modulate.a = 0.0
	notification.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.parallel().tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(notification, "scale", Vector2.ONE, 0.3)
	
	# Auto-remove after duration
	# Note: await removed since this function is not async
	_remove_notification(notification)
	
	# Limit number of notifications
	_enforce_notification_limit()

## Create notification UI element
func _create_notification(title: String, message: String, priority: String, duration: float) -> Control:
	var notification = PanelContainer.new()
	notification.name = "Notification_%d" % Time.get_ticks_msec()
	
	# Style based on priority
	var color: Color
	match priority:
		"critical":
			color = Color(0.8, 0.2, 0.2, 0.9) # Red
		"success":
			color = Color(0.2, 0.8, 0.2, 0.9) # Green
		"info":
			color = Color(0.2, 0.6, 0.8, 0.9) # Blue
		_:
			color = Color(0.4, 0.4, 0.4, 0.9) # Gray
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	notification.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	notification.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)
	
	return notification

## Remove notification with animation
func _remove_notification(notification: Control) -> void:
	if notification in active_notifications:
		active_notifications.erase(notification)
	
	# Fade out animation
	var tween = create_tween()
	tween.parallel().tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(notification, "scale", Vector2(0.8, 0.8), 0.3)
	await tween.finished
	
	notification.queue_free()

## Enforce notification limit
func _enforce_notification_limit() -> void:
	while active_notifications.size() > max_notifications:
		var oldest_notification = active_notifications[0]
		_remove_notification(oldest_notification)

## Handle critical event display
func show_critical_event(event_type: String, details: Dictionary) -> void:
	# Show critical event overlay
	if critical_event_overlay:
		critical_event_overlay.visible = true
		var tween = create_tween()
		tween.tween_property(critical_event_overlay, "modulate:a", 0.3, 0.2)
		tween.tween_property(critical_event_overlay, "modulate:a", 0.0, 0.2)
		await tween.finished
		critical_event_overlay.visible = false
	
	# Emit signal for additional handling
	critical_event_highlighted.emit(details)

## Handle visual feedback requests
func show_visual_feedback(feedback_type: String, data: Dictionary) -> void:
	match feedback_type:
		"dice_result":
			_show_dice_result_feedback(data)
		"step_start":
			_show_step_start_feedback(data)
		"step_complete":
			_show_step_complete_feedback(data)
		_:
			print("Unknown visual feedback type: %s" % feedback_type)

## Show dice result visual feedback
func _show_dice_result_feedback(data: Dictionary) -> void:
	if not dice_result_display:
		return
	
	var crew_member: String = SafeDataAccess.safe_get(data, "crew_member", "Unknown", "dice result feedback")
	var dice_roll: int = SafeDataAccess.safe_get(data, "dice_roll", 0, "dice result feedback")
	var success: bool = SafeDataAccess.safe_get(data, "success", false, "dice result feedback")
	
	var dice_label: Label = dice_result_display.get_node("DiceLabel")
	var result_label: Label = dice_result_display.get_node("ResultLabel")
	
	dice_label.text = "🎲 %s rolled %d" % [crew_member, dice_roll]
	result_label.text = "Success!" if success else "Failed"
	result_label.add_theme_color_override("font_color", Color.GREEN if success else Color.RED)
	
	# Animate dice result display
	var tween = create_tween()
	tween.tween_property(dice_result_display, "modulate:a", 1.0, 0.3)
	tween.tween_delay(2.0)
	tween.tween_property(dice_result_display, "modulate:a", 0.0, 0.3)

## Show step start feedback
func _show_step_start_feedback(data: Dictionary) -> void:
	var step_name: String = SafeDataAccess.safe_get(data, "step_name", "Unknown Step", "step start feedback")
	var icon: String = SafeDataAccess.safe_get(data, "icon", "🔄", "step start feedback")
	
	show_notification(
		"%s %s Starting" % [icon, step_name],
		"Beginning %s phase..." % step_name,
		"info",
		2.0
	)

## Show step completion feedback
func _show_step_complete_feedback(data: Dictionary) -> void:
	var step_name: String = SafeDataAccess.safe_get(data, "step_name", "Unknown Step", "step complete feedback")
	var duration: int = SafeDataAccess.safe_get(data, "duration_ms", 0, "step complete feedback")
	
	show_notification(
		"✅ %s Complete" % step_name,
		"Completed in %d ms" % duration,
		"success",
		2.0
	)

## SIGNAL HANDLERS FOR REAL-TIME FEEDBACK

func _on_task_progress_updated(crew_member: String, task_type: String, progress: float, status: String) -> void:
	update_task_progress(crew_member, task_type, progress, status)

func _on_critical_event_occurred(event_type: String, details: Dictionary) -> void:
	show_critical_event(event_type, details)

func _on_batch_progress_updated(completed_tasks: int, total_tasks: int, current_task: String) -> void:
	update_batch_progress(completed_tasks, total_tasks, current_task)

func _on_notification_triggered(title: String, message: String, priority: String, duration: float) -> void:
	show_notification(title, message, priority, duration)

func _on_visual_feedback_requested(feedback_type: String, data: Dictionary) -> void:
	show_visual_feedback(feedback_type, data)

func _on_dice_animation_triggered(context: String, dice_type: String) -> void:
	# Show dice animation feedback
	show_visual_feedback("dice_animation", {
		"context": context,
		"dice_type": dice_type
	})

## AUTOMATION INTEGRATION METHODS

## Handle automation toggle button (legacy - redirects to unified system)
func _on_automation_toggled(enabled: bool) -> void:
	# Redirect to unified automation toggle for consistency
	_on_unified_automation_toggled(enabled)

## Handle auto-resolve all button (legacy - redirects to unified system)
func _on_auto_resolve_all() -> void:
	# Redirect to unified auto-resolve for consistency
	_on_unified_auto_resolve_all()

## Handle step button press with automation awareness
func _on_step_button_pressed(step: int) -> void:
	if step <= current_step or step == current_step + 1:
		_show_step(step)

## UTILITY METHODS FOR INTEGRATION

## Get current automation status for external systems
func get_automation_status() -> Dictionary:
	return {
		"enabled": automation_enabled,
		"controller_available": automation_controller != null,
		"feedback_system_status": automation_controller.get_feedback_system_status() if automation_controller else {},
		"current_step": current_step,
		"total_steps": total_steps
	}

## Configure feedback system from external sources
func configure_feedback_system(settings: Dictionary) -> void:
	if automation_controller:
		automation_controller.configure_feedback_system(settings)
	
	# Update local feedback settings
	if settings.has("max_notifications"):
		max_notifications = max(1, settings.max_notifications)
	if settings.has("feedback_animations_enabled"):
		feedback_animations_enabled = settings.feedback_animations_enabled

## Manually trigger crew task automation (for external integration)
func trigger_automation(task_assignments: Dictionary) -> void:
	if not automation_controller:
		show_notification(
			"No Automation Controller",
			"Automation controller not initialized",
			"info",
			2.0
		)
		return
	
	automation_controller.automate_crew_task_resolution(task_assignments)

## Clear all feedback displays
func clear_all_feedback() -> void:
	# Clear task progress bars
	for progress_id in task_progress_bars.keys():
		_remove_task_progress_item(progress_id)
	
	# Clear notifications
	for notification in active_notifications:
		_remove_notification(notification)
	
	# Reset batch progress
	if batch_progress_bar:
		batch_progress_bar.value = 0.0
	
	# Clear automation controller feedback data
	if automation_controller:
		automation_controller.clear_feedback_data()

## Demo method for testing feedback system
func demo_feedback_system() -> void:
	show_notification("Demo Started", "Testing notification system", "info", 3.0)
	
	await get_tree().create_timer(1.0).timeout
	show_critical_event("demo_event", {"description": "Demo critical event"})
	
	await get_tree().create_timer(1.0).timeout
	update_batch_progress(1, 3, "Demo task 1/3")
	
	await get_tree().create_timer(1.0).timeout
	update_batch_progress(2, 3, "Demo task 2/3")
	
	await get_tree().create_timer(1.0).timeout
	update_batch_progress(3, 3, "Demo completed!")

# UNIFIED AUTOMATION SYSTEM - FEATURE 7 & 8 INTEGRATION

## Handle unified automation toggle (master control)
# Duplicate function removed - using the more comprehensive version at line ~809

func _update_automation_button_states(enabled: bool) -> void:
	if not automation_controls:
		return
		
	# Update crew task automation
	var crew_button = automation_controls.get_node("CrewAutomationSection/AutoResolveCrewButton")
	if crew_button:
		crew_button.disabled = not enabled
		
	# Update job automation
	var job_button = automation_controls.get_node("JobAutomationSection/AutoSelectJobButton")
	if job_button:
		job_button.disabled = not enabled
		
	# Update complete automation
	var all_button = automation_controls.get_node("CompleteAutomationSection/AutoResolveAllButton")
	if all_button:
		all_button.disabled = not enabled
		
	# Update pause button (enabled when automation is running)
	var pause_button = automation_controls.get_node("ManualOverrideSection/PauseAutomationButton")
	if pause_button:
		pause_button.disabled = not enabled

## Handle crew task automation
func _on_auto_resolve_crew_tasks() -> void:
	if not automation_controller or not automation_enabled:
		show_notification(
			"Automation Disabled",
			"Enable automation to use this feature",
			"warning",
			2.0
		)
		return
	
	# Create mock crew assignments for current crew
	var crew_data = world_phase.get_crew_data() if world_phase else []
	var crew_assignments := {}
	
	for crew_member in crew_data:
		var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "crew data processing")
		var crew_id = SafeDataAccess.safe_get(crew_dict, "id", "", "crew data processing")
		var crew_name = SafeDataAccess.safe_get(crew_dict, "name", "Unknown", "crew data processing")
		# Assign default exploration task
		crew_assignments[crew_name] = GlobalEnums.CrewTaskType.EXPLORE
	
	if crew_assignments.is_empty():
		show_notification(
			"No Crew Available",
			"Add crew members to automate tasks",
			"warning",
			2.0
		)
		return
	
	# Start automated crew task resolution
	show_notification(
		"Starting Crew Automation",
		"Resolving %d crew tasks..." % crew_assignments.size(),
		"info",
		2.0
	)
	
	automation_controller.automate_crew_task_resolution(crew_assignments)

## Handle job selection automation
func _on_auto_select_job() -> void:
	if not automation_enabled:
		show_notification(
			"Automation Disabled",
			"Enable automation to use this feature",
			"warning",
			2.0
		)
		return
	
	# Get available job offers
	var available_jobs = world_phase.get_available_job_offers() if world_phase else []
	
	if available_jobs.is_empty():
		show_notification(
			"No Jobs Available",
			"Generate job offers first",
			"warning",
			2.0
		)
		return
	
	# Auto-select best job based on payment and risk
	var best_job = _select_best_job(available_jobs)
	if best_job:
		var job_dict = SafeDataAccess.safe_dict_access(best_job, "auto job selection")
		var job_id = SafeDataAccess.safe_get(job_dict, "id", "", "auto job selection")
		_on_accept_job(job_id)
		
		show_notification(
			"Job Auto-Selected",
			"Accepted: %s" % SafeDataAccess.safe_get(job_dict, "mission_type", "Unknown", "auto job selection"),
			"success",
			3.0
		)

## Handle complete phase automation
func _on_auto_complete_phase() -> void:
	if not automation_controller or not automation_enabled:
		show_notification(
			"Automation Disabled",
			"Enable automation to use this feature",
			"warning",
			2.0
		)
		return
	
	show_notification(
		"Starting Full Automation",
		"Automating entire world phase...",
		"info",
		2.0
	)
	
	# Start with crew tasks
	_on_auto_resolve_crew_tasks()
	
	# Note: await statements removed since this function is not async
	# Wait for crew tasks to complete, then auto-select job
	_on_auto_select_job()
	
	# Complete the phase
	_complete_world_phase()

## Complete the world phase
func _complete_world_phase() -> void:
	"""Complete the world phase and transition to next phase"""
	print("WorldPhaseUI: Completing world phase")
	
	# Emit completion signal
	world_phase_completed.emit()
	
	# Reset UI state
	current_step = 0
	_show_step(0)
	
	# Clear any active automation
	if automation_controller:
		automation_controller.stop_automation()
	
	show_notification(
		"World Phase Complete",
		"World phase has been completed successfully",
		"success",
		2.0
	)

## Handle automation pause
func _on_pause_automation() -> void:
	if automation_controller:
		automation_controller.pause_automation()
		
		show_notification(
			"Automation Paused",
			"World phase automation has been paused",
			"info",
			2.0
		)

## Handle phase reset
func _on_reset_phase() -> void:
	# Reset world phase state
	world_phase_state.reset_phase()
	
	# Reset UI to first step
	current_step = 0
	_show_step(0)
	
	# Reset automation state
	if automation_controller:
		automation_controller.reset_automation_state()
	
	show_notification(
		"Phase Reset",
		"World phase has been reset to beginning",
		"info",
		2.0
	)

## Select best job based on automated criteria
func _select_best_job(available_jobs: Array) -> Dictionary:
	if available_jobs.is_empty():
		return {}
	
	var best_job = {}
	var best_score = -1
	
	for job in available_jobs:
		var job_dict = SafeDataAccess.safe_dict_access(job, "best job selection")
		var payment = SafeDataAccess.safe_get(job_dict, "payment", 0, "best job selection")
		var danger = SafeDataAccess.safe_get(job_dict, "danger_level", 1, "best job selection")
		
		# Simple scoring: prioritize high pay, low danger
		var score = payment - (danger * 100)
		
		if score > best_score:
			best_score = score
			best_job = job
	
	return best_job

## Handle unified auto-resolve all (legacy compatibility)
func _on_unified_auto_resolve_all_legacy() -> void:
	_on_auto_complete_phase()
	
	show_notification("Demo Complete", "Feedback system demo finished", "success", 2.0)

## =================================================================
## FEATURE 8: JOB SYSTEM SIGNAL BRIDGE IMPLEMENTATION
## =================================================================

## Initialize job system integration components
func _initialize_job_system_integration() -> void:
	print("WorldPhaseUI: Initializing Feature 8 job system integration")
	
	# Create job selection container
	job_selection_container = _create_job_selection_container()
	if content_container:
		content_container.add_child(job_selection_container)
	
	# Initialize job validation system
	job_validation_system = _create_job_validation_system()
	add_child(job_validation_system)
	
	# Set initial workflow state
	current_job_workflow_state = "none"
	job_system_initialized = true
	
	print("WorldPhaseUI: Job system integration initialized successfully")

## Create job selection container for embedding JobSelectionUI
func _create_job_selection_container() -> Control:
	var container = VBoxContainer.new()
	container.name = "JobSelectionContainer"
	container.visible = false # Hidden by default, shown during job offers step
	
	var header_label = Label.new()
	header_label.text = "Available Job Offers"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color.CYAN)
	container.add_child(header_label)
	
	# Container for JobSelectionUI instance
	var job_ui_container = VBoxContainer.new()
	job_ui_container.name = "JobUIContainer"
	job_ui_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_ui_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(job_ui_container)
	
	return container

## Create job validation system for validating job requirements
func _create_job_validation_system() -> Node:
	var validator = Node.new()
	validator.name = "JobValidationSystem"
	validator.set_script(preload("res://src/core/validation/JobValidator.gd"))
	return validator

## Setup comprehensive signal bridge between job systems
func _setup_job_signal_bridge() -> void:
	print("WorldPhaseUI: Setting up Feature 8 signal bridge")
	
	# Connect internal WorldPhaseUI signals
	job_selection_opened.connect(_on_job_selection_opened)
	job_selection_closed.connect(_on_job_selection_closed)
	job_validation_started.connect(_on_job_validation_started)
	job_validation_completed.connect(_on_job_validation_completed)
	job_acceptance_started.connect(_on_job_acceptance_started)
	job_acceptance_completed.connect(_on_job_acceptance_completed)
	job_acceptance_failed.connect(_on_job_acceptance_failed)
	job_workflow_state_changed.connect(_on_job_workflow_state_changed)
	job_system_error.connect(_on_job_system_error)
	job_offers_updated.connect(_on_job_offers_updated)
	
	print("WorldPhaseUI: Signal bridge setup completed")

## Connect job system component signals
func _connect_job_system_signals() -> void:
	print("WorldPhaseUI: Connecting job system component signals")
	
	# Connect to WorldPhase job-related signals
	if world_phase:
		if not world_phase.job_offers_generated.is_connected(_on_world_phase_job_offers_generated):
			world_phase.job_offers_generated.connect(_on_world_phase_job_offers_generated)
		
		# Connect to other relevant WorldPhase signals for job workflow
		if world_phase.has_signal("job_accepted") and not world_phase.job_accepted.is_connected(_on_world_phase_job_accepted):
			world_phase.connect("job_accepted", _on_world_phase_job_accepted)
	
	# Job selection UI will be connected when created during job offers step
	print("WorldPhaseUI: Job system component signals connected")

## Create and configure JobSelectionUI for current job offers step
func _create_job_selection_ui() -> JobSelectionUI:
	if job_selection_ui:
		# Clean up existing instance
		_cleanup_job_selection_ui()
	
	# Create new JobSelectionUI instance
	job_selection_ui = JobSelectionUI.new()
	job_selection_ui.name = "JobSelectionUI"
	
	# Configure WorldPhase integration
	if world_phase:
		job_selection_ui.set_world_phase(world_phase)
		job_selection_ui.enable_world_phase_integration(true)
	
	# Connect JobSelectionUI signals to our bridge
	job_selection_ui.job_selected.connect(_on_job_selection_ui_job_selected)
	job_selection_ui.job_generation_requested.connect(_on_job_selection_ui_generation_requested)
	
	# Add to job selection container
	if job_selection_container:
		var job_ui_container = job_selection_container.get_node("JobUIContainer")
		if job_ui_container:
			job_ui_container.add_child(job_selection_ui)
	
	print("WorldPhaseUI: JobSelectionUI created and configured")
	return job_selection_ui

## Cleanup existing job selection UI
func _cleanup_job_selection_ui() -> void:
	if job_selection_ui:
		# Disconnect signals
		if job_selection_ui.job_selected.is_connected(_on_job_selection_ui_job_selected):
			job_selection_ui.job_selected.disconnect(_on_job_selection_ui_job_selected)
		if job_selection_ui.job_generation_requested.is_connected(_on_job_selection_ui_generation_requested):
			job_selection_ui.job_generation_requested.disconnect(_on_job_selection_ui_generation_requested)
		
		# Remove from scene
		job_selection_ui.queue_free()
		job_selection_ui = null

## =================================================================
## JOB WORKFLOW STATE MANAGEMENT
## =================================================================

## Change job workflow state with validation and error handling
func _change_job_workflow_state(new_state: String, context: Dictionary = {}) -> bool:
	var previous_state = current_job_workflow_state
	
	# Validate state transition
	if not _is_valid_job_workflow_transition(previous_state, new_state):
		var error_msg = "Invalid job workflow transition from '%s' to '%s'" % [previous_state, new_state]
		job_system_error.emit("invalid_state_transition", error_msg, {"previous": previous_state, "requested": new_state})
		return false
	
	# Update state
	current_job_workflow_state = new_state
	
	# Emit state change signal
	var full_context = context.duplicate()
	full_context["previous_state"] = previous_state
	full_context["timestamp"] = Time.get_datetime_string_from_system()
	job_workflow_state_changed.emit(new_state, full_context)
	
	# Handle state-specific logic
	_handle_job_workflow_state_change(new_state, full_context)
	
	print("WorldPhaseUI: Job workflow state changed from '%s' to '%s'" % [previous_state, new_state])
	return true

## Validate job workflow state transitions
func _is_valid_job_workflow_transition(from_state: String, to_state: String) -> bool:
	var valid_transitions = {
		"none": ["job_offers_available", "error"],
		"job_offers_available": ["job_selection_open", "none", "error"],
		"job_selection_open": ["job_selected", "job_selection_closed", "error"],
		"job_selected": ["job_validation", "job_selection_open", "error"],
		"job_validation": ["job_validated", "job_validation_failed", "error"],
		"job_validated": ["job_acceptance", "job_selected", "error"],
		"job_acceptance": ["job_accepted", "job_acceptance_failed", "error"],
		"job_accepted": ["job_workflow_complete", "error"],
		"job_validation_failed": ["job_selected", "job_selection_open", "error"],
		"job_acceptance_failed": ["job_selected", "job_selection_open", "error"],
		"job_selection_closed": ["none", "job_offers_available", "error"],
		"job_workflow_complete": ["none", "error"],
		"error": ["none", "job_offers_available"]
	}
	
	var allowed_states = valid_transitions.get(from_state, [])
	return to_state in allowed_states

## Handle job workflow state changes
func _handle_job_workflow_state_change(new_state: String, context: Dictionary) -> void:
	match new_state:
		"job_offers_available":
			_handle_job_offers_available_state(context)
		"job_selection_open":
			_handle_job_selection_open_state(context)
		"job_selected":
			_handle_job_selected_state(context)
		"job_validation":
			_handle_job_validation_state(context)
		"job_validated":
			_handle_job_validated_state(context)
		"job_acceptance":
			_handle_job_acceptance_state(context)
		"job_accepted":
			_handle_job_accepted_state(context)
		"job_workflow_complete":
			_handle_job_workflow_complete_state(context)
		"error":
			_handle_job_error_state(context)

## State handlers for different job workflow states

func _handle_job_offers_available_state(context: Dictionary) -> void:
	show_notification("Job Offers", "Job offers are now available for review", "info", 3.0)
	
	# Update UI to show job offers section
	if job_selection_container:
		job_selection_container.visible = true
	
	# Create job selection UI if in job offers step
	if current_step == 2: # Job Offers step
		_create_job_selection_ui()

func _handle_job_selection_open_state(context: Dictionary) -> void:
	job_selection_opened.emit()
	show_notification("Job Selection", "Job selection interface opened", "info", 2.0)

func _handle_job_selected_state(context: Dictionary) -> void:
	var job = SafeDataAccess.safe_get(context, "job", null, "job selected state")
	if job:
		selected_job = job
		show_notification("Job Selected", "Job selected for validation", "info", 2.0)
		
		# Automatically start validation
		_change_job_workflow_state("job_validation", {"job": job})

func _handle_job_validation_state(context: Dictionary) -> void:
	var job = SafeDataAccess.safe_get(context, "job", selected_job, "job validation state")
	if job:
		job_validation_started.emit(job)
		show_notification("Validating Job", "Checking job requirements...", "info", 2.0)
		
		# Start validation process
		_validate_job_async(job)

func _handle_job_validated_state(context: Dictionary) -> void:
	show_notification("Job Valid", "Job requirements validated successfully", "success", 2.0)

func _handle_job_acceptance_state(context: Dictionary) -> void:
	var job = SafeDataAccess.safe_get(context, "job", selected_job, "job acceptance state")
	if job:
		job_acceptance_started.emit(job)
		show_notification("Accepting Job", "Processing job acceptance...", "info", 2.0)
		
		# Start acceptance process
		_accept_job_async(job)

func _handle_job_accepted_state(context: Dictionary) -> void:
	var job = SafeDataAccess.safe_get(context, "job", selected_job, "job accepted state")
	if job:
		show_notification("Job Accepted", "Job successfully accepted!", "success", 3.0)
		job_acceptance_completed.emit(job, true)

func _handle_job_workflow_complete_state(context: Dictionary) -> void:
	show_notification("Workflow Complete", "Job workflow completed successfully", "success", 2.0)
	
	# Hide job selection interface
	if job_selection_container:
		job_selection_container.visible = false
	
	# Clean up job selection UI
	_cleanup_job_selection_ui()
	
	# Reset job workflow for next iteration
	selected_job = null
	available_job_offers.clear()

func _handle_job_error_state(context: Dictionary) -> void:
	var error_type = SafeDataAccess.safe_get(context, "error_type", "unknown", "job error state")
	var error_message = SafeDataAccess.safe_get(context, "error_message", "Unknown error occurred", "job error state")
	
	show_notification("Job Error", error_message, "critical", 5.0)
	job_error_count += 1
	
	# If too many errors, reset to initial state
	if job_error_count > 3:
		print("WorldPhaseUI: Too many job errors, resetting workflow")
		_reset_job_workflow()

## Reset job workflow to initial state
func _reset_job_workflow() -> void:
	print("WorldPhaseUI: Resetting job workflow")
	
	# Cleanup current state
	_cleanup_job_selection_ui()
	selected_job = null
	available_job_offers.clear()
	job_error_count = 0
	
	# Hide job selection interface
	if job_selection_container:
		job_selection_container.visible = false
	
	# Reset workflow state
	current_job_workflow_state = "none"
	
	show_notification("Workflow Reset", "Job workflow has been reset", "info", 2.0)

## =================================================================
## JOB VALIDATION AND ACCEPTANCE WORKFLOWS
## =================================================================

## Asynchronously validate a job with comprehensive error handling
func _validate_job_async(job: Resource) -> void:
	if not job:
		job_validation_completed.emit(null, false, ["Job is null"])
		_change_job_workflow_state("job_validation_failed", {"error": "null_job"})
		return
	
	var validation_errors: Array[String] = []
	var is_valid = true
	
	# Basic job data validation
	if not job.has_meta("job_id") or job.get_meta("job_id") == "":
		validation_errors.append("Job ID is missing or empty")
		is_valid = false
	
	if not job.has_meta("job_type"):
		validation_errors.append("Job type is not specified")
		is_valid = false
	
	if not job.has_meta("reward_credits") or job.get_meta("reward_credits") <= 0:
		validation_errors.append("Job reward is invalid")
		is_valid = false
	
	# Requirement validation using job validation system
	if job_validation_system and job_validation_system.has_method("validate_job_requirements"):
		var requirement_result = job_validation_system.validate_job_requirements(job)
		if not requirement_result.is_valid:
			validation_errors.append_array(requirement_result.errors)
			is_valid = false
	
	# Crew capability validation
	var crew_validation = _validate_crew_capabilities(job)
	if not crew_validation.is_valid:
		validation_errors.append_array(crew_validation.errors)
		# Note: Crew validation failures are warnings, not blocking errors
	
	# Note: await removed since this function is not async
	# Simulate async validation delay
	
	# Emit validation result
	job_validation_completed.emit(job, is_valid, validation_errors)
	
	# Update workflow state
	if is_valid:
		_change_job_workflow_state("job_validated", {"job": job, "validation_time": Time.get_ticks_msec()})
	else:
		_change_job_workflow_state("job_validation_failed", {"job": job, "errors": validation_errors})

## Validate crew capabilities for job requirements
func _validate_crew_capabilities(job: Resource) -> Dictionary:
	var result = {"is_valid": true, "errors": [], "warnings": []}
	
	var requirements = job.get_meta("requirements", [])
	if requirements.is_empty():
		return result
	
	# Check if we have access to crew data
	if not game_state_manager or not game_state_manager.has_method("get_crew_members"):
		result.warnings.append("Cannot validate crew capabilities - crew data unavailable")
		return result
	
	var crew_members = game_state_manager.get_crew_members()
	if crew_members.is_empty():
		result.warnings.append("No crew members available for mission")
		return result
	
	# Validate specific requirements
	for requirement in requirements:
		var req_text = str(requirement).to_lower()
		
		if "combat" in req_text:
			var has_combat_experience = _crew_has_combat_experience(crew_members)
			if not has_combat_experience:
				result.warnings.append("Crew lacks recommended combat experience")
		
		if "medical" in req_text:
			var has_medic = _crew_has_medic(crew_members)
			if not has_medic:
				result.warnings.append("No medic available for medical requirements")
		
		if "tech" in req_text or "repair" in req_text:
			var has_tech_specialist = _crew_has_tech_specialist(crew_members)
			if not has_tech_specialist:
				result.warnings.append("No tech specialist available for technical requirements")
	
	return result

## Check if crew has combat experience
func _crew_has_combat_experience(crew_members: Array) -> bool:
	for crew_member in crew_members:
		if typeof(crew_member) == TYPE_DICTIONARY:
			var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "combat crew check")
			var combat_skill = SafeDataAccess.safe_get(crew_dict, "combat", 0, "combat crew check")
			if combat_skill >= 2: # Minimum combat experience threshold
				return true
	return false

## Check if crew has a medic
func _crew_has_medic(crew_members: Array) -> bool:
	for crew_member in crew_members:
		if typeof(crew_member) == TYPE_DICTIONARY:
			var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "medical crew check")
			var background = SafeDataAccess.safe_get(crew_dict, "background", "", "medical crew check")
			if "medic" in str(background).to_lower():
				return true
			var skills = SafeDataAccess.safe_get(crew_dict, "skills", [], "medical crew check")
			for skill in skills:
				if "medical" in str(skill).to_lower():
					return true
	return false

## Check if crew has tech specialist
func _crew_has_tech_specialist(crew_members: Array) -> bool:
	for crew_member in crew_members:
		if typeof(crew_member) == TYPE_DICTIONARY:
			var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "tech crew check")
			var tech_skill = SafeDataAccess.safe_get(crew_dict, "tech", 0, "tech crew check")
			if tech_skill >= 2: # Minimum tech skill threshold
				return true
	return false

## Asynchronously accept a job with comprehensive workflow
func _accept_job_async(job: Resource) -> void:
	if not job:
		job_acceptance_failed.emit(null, "Job is null")
		_change_job_workflow_state("job_acceptance_failed", {"error": "null_job"})
		return
	
	print("WorldPhaseUI: Starting job acceptance workflow for job: %s" % job.get_meta("job_id", "unknown"))
	
	# Convert UI job to WorldPhase format if needed
	var world_phase_job = JobDataAdapter.convert_ui_to_world_phase(job)
	if world_phase_job.is_empty():
		job_acceptance_failed.emit(job, "Failed to convert job data")
		_change_job_workflow_state("job_acceptance_failed", {"error": "conversion_failed"})
		return
	
	# Attempt to accept job through WorldPhase
	# Note: await removed since this function is not async
	var acceptance_result = _process_job_acceptance_through_world_phase(world_phase_job)
	
	if acceptance_result.success:
		# Store accepted job in world phase state
		if world_phase_state:
			world_phase_state.accepted_job = world_phase_job
		
		# Update game state
		if game_state_manager and game_state_manager.has_method("set_current_mission"):
			game_state_manager.set_current_mission(world_phase_job)
		
		# Emit success signals
		job_accepted.emit(job.get_meta("job_id", ""))
		_change_job_workflow_state("job_accepted", {"job": job, "world_phase_job": world_phase_job})
		
		# Complete workflow
		_change_job_workflow_state("job_workflow_complete", {"job": job, "completion_time": Time.get_ticks_msec()})
	else:
		job_acceptance_failed.emit(job, acceptance_result.error_message)
		_change_job_workflow_state("job_acceptance_failed", {"error": acceptance_result.error_message, "job": job})

## Process job acceptance through WorldPhase system
func _process_job_acceptance_through_world_phase(world_phase_job: Dictionary) -> Dictionary:
	var result = {"success": false, "error_message": ""}
	
	if not world_phase:
		result.error_message = "WorldPhase system not available"
		return result
	
	# Check if WorldPhase can accept the job
	if world_phase.has_method("accept_job"):
		var acceptance_success = world_phase.accept_job(world_phase_job)
		if acceptance_success:
			result.success = true
		else:
			result.error_message = "WorldPhase rejected job acceptance"
	else:
		# Fallback: manually set job as accepted in WorldPhase
		if world_phase.has_method("set_accepted_job"):
			world_phase.set_accepted_job(world_phase_job)
			result.success = true
		else:
			result.error_message = "WorldPhase does not support job acceptance"
	
	# Simulate processing delay
	# Note: await removed since this function is not async
	
	return result

## =================================================================
## SIGNAL HANDLERS FOR JOB SYSTEM INTEGRATION
## =================================================================

## Handle WorldPhase job offers generated
func _on_world_phase_job_offers_generated(offers: Array) -> void:
	print("WorldPhaseUI: Received %d job offers from WorldPhase" % offers.size())
	
	# Convert WorldPhase jobs to UI format
	available_job_offers.clear()
	for offer in offers:
		if typeof(offer) == TYPE_DICTIONARY:
			var ui_job = JobDataAdapter.convert_world_phase_to_ui(offer)
			if ui_job:
				available_job_offers.append(ui_job)
	
	# Emit job offers updated signal
	job_offers_updated.emit(available_job_offers)
	
	# Update workflow state
	if available_job_offers.size() > 0:
		_change_job_workflow_state("job_offers_available", {"offer_count": available_job_offers.size()})
	else:
		job_system_error.emit("no_job_offers", "No valid job offers generated", {"raw_offers": offers.size()})

## Handle WorldPhase job accepted signal
func _on_world_phase_job_accepted(job_id: String) -> void:
	print("WorldPhaseUI: WorldPhase confirmed job acceptance: %s" % job_id)
	
	# Find the accepted job in our available jobs
	for job in available_job_offers:
		if job.get_meta("job_id") == job_id:
			job_acceptance_completed.emit(job, true)
			break

## Handle JobSelectionUI job selected
func _on_job_selection_ui_job_selected(job: Resource) -> void:
	print("WorldPhaseUI: JobSelectionUI selected job: %s" % job.get_meta("job_id", "unknown"))
	
	# Store selected job
	selected_job = job
	
	# Update accept button state
	_update_job_accept_button_state()
	
	# Update workflow state with selected job
	_change_job_workflow_state("job_selected", {"job": job, "source": "JobSelectionUI"})

## Handle JobSelectionUI job generation requested
func _on_job_selection_ui_generation_requested() -> void:
	print("WorldPhaseUI: JobSelectionUI requested job generation")
	
	# Trigger job generation through WorldPhase if available
	if world_phase and world_phase.has_method("_generate_job_offers"):
		world_phase._generate_job_offers()
	else:
		show_notification("Job Generation", "Requesting new job offers...", "info", 2.0)

## Internal signal handlers for job workflow

func _on_job_selection_opened() -> void:
	print("WorldPhaseUI: Job selection opened")
	update_task_progress("job_system", "selection", 0.3, "Job selection interface opened")

func _on_job_selection_closed() -> void:
	print("WorldPhaseUI: Job selection closed")
	_change_job_workflow_state("job_selection_closed", {"timestamp": Time.get_ticks_msec()})

func _on_job_validation_started(job: Resource) -> void:
	print("WorldPhaseUI: Job validation started for: %s" % job.get_meta("job_id", "unknown"))
	update_task_progress("job_system", "validation", 0.5, "Validating job requirements")

func _on_job_validation_completed(job: Resource, is_valid: bool, errors: Array[String]) -> void:
	print("WorldPhaseUI: Job validation completed - Valid: %s, Errors: %d" % [is_valid, errors.size()])
	
	if is_valid:
		update_task_progress("job_system", "validation", 1.0, "Job validation passed")
		show_notification("Job Valid", "Job requirements satisfied", "success", 2.0)
	else:
		show_notification("Job Invalid", "Job validation failed: %s" % ", ".join(errors), "critical", 4.0)
		job_system_error.emit("validation_failed", "Job validation failed", {"errors": errors, "job": job})

func _on_job_acceptance_started(job: Resource) -> void:
	print("WorldPhaseUI: Job acceptance started for: %s" % job.get_meta("job_id", "unknown"))
	update_task_progress("job_system", "acceptance", 0.7, "Processing job acceptance")

func _on_job_acceptance_completed(job: Resource, success: bool) -> void:
	print("WorldPhaseUI: Job acceptance completed - Success: %s" % success)
	
	if success:
		update_task_progress("job_system", "acceptance", 1.0, "Job accepted successfully")
		# Progress to next world phase step if appropriate
		if current_step == 2: # Job Offers step
			_show_step(3) # Move to Mission Prep step

func _on_job_acceptance_failed(job: Resource, error_message: String) -> void:
	print("WorldPhaseUI: Job acceptance failed: %s" % error_message)
	show_notification("Acceptance Failed", "Job acceptance failed: %s" % error_message, "critical", 4.0)

func _on_job_workflow_state_changed(new_state: String, context: Dictionary) -> void:
	print("WorldPhaseUI: Job workflow state changed to: %s" % new_state)
	
	# Update UI state based on workflow state
	_update_ui_for_job_workflow_state(new_state, context)

func _on_job_system_error(error_type: String, error_message: String, context: Dictionary) -> void:
	push_error("WorldPhaseUI Job System Error [%s]: %s" % [error_type, error_message])
	show_notification("Job System Error", error_message, "critical", 5.0)
	
	# Handle specific error types
	match error_type:
		"invalid_state_transition":
			_reset_job_workflow()
		"validation_failed":
			# Allow user to retry or select different job
			pass
		"conversion_failed":
			# Try fallback job generation
			_generate_fallback_jobs()
		_:
			# Generic error handling
			job_error_count += 1

func _on_job_offers_updated(job_offers: Array) -> void:
	print("WorldPhaseUI: Job offers updated - %d offers available" % job_offers.size())
	
	# Update JobSelectionUI if it exists
	if job_selection_ui:
		# JobSelectionUI will handle its own job list updates
		pass
	
	# Update our progress display
	if job_offers.size() > 0:
		update_task_progress("job_system", "offers", 1.0, "%d job offers available" % job_offers.size())

## Update UI elements based on job workflow state
func _update_ui_for_job_workflow_state(workflow_state: String, context: Dictionary) -> void:
	match workflow_state:
		"job_offers_available":
			if job_selection_container:
				job_selection_container.visible = true
		"job_selection_open":
			# Enable job selection interactions
			pass
		"job_selected":
			# Highlight selected job, show validation progress
			pass
		"job_validated":
			# Show acceptance button/option
			pass
		"job_accepted":
			# Show success feedback, prepare for next step
			pass
		"job_workflow_complete":
			if job_selection_container:
				job_selection_container.visible = false
		"error":
			# Show error state in UI
			pass

## Generate fallback jobs when main system fails
func _generate_fallback_jobs() -> void:
	print("WorldPhaseUI: Generating fallback jobs")
	
	var fallback_jobs: Array[Resource] = []
	
	# Create basic fallback jobs
	for i in range(3):
		var job = Resource.new()
		job.set_meta("job_id", "fallback_%d_%d" % [Time.get_unix_time_from_system(), i])
		job.set_meta("job_type", "opportunity")
		job.set_meta("mission_type", "Emergency Contract")
		job.set_meta("difficulty", 1)
		job.set_meta("reward_credits", 300 + (i * 100))
		job.set_meta("description", "Emergency fallback mission - standard opportunity")
		job.set_meta("requirements", [])
		job.set_meta("time_limit", 3)
		fallback_jobs.append(job)
	
	available_job_offers = fallback_jobs
	job_offers_updated.emit(available_job_offers)
	
	show_notification("Fallback Jobs", "Generated emergency job offers", "info", 3.0)

## Update accept button state based on job selection
func _update_job_accept_button_state() -> void:
	var content_area = content_container.get_node("ContentArea") if content_container else null
	if not content_area:
		return
	
	var accept_button = content_area.get_node_or_null("JobAcceptButton")
	if accept_button and accept_button is Button:
		accept_button.disabled = selected_job == null
		if selected_job:
			accept_button.text = "Accept Job: %s" % selected_job.get_meta("mission_type", "Unknown")
		else:
			accept_button.text = "Accept Selected Job"

## =================================================================
## PUBLIC API FOR EXTERNAL JOB SYSTEM INTEGRATION - FEATURE 8
## =================================================================

## Get current job workflow state
func get_job_workflow_state() -> String:
	return current_job_workflow_state

## Get currently selected job
func get_selected_job() -> Resource:
	return selected_job

## Get all available job offers
func get_available_job_offers() -> Array[Resource]:
	return available_job_offers.duplicate()

## Set external job selection (for integration with other systems)
func set_selected_job(job: Resource) -> bool:
	if not job:
		return false
	
	# Validate job is in available offers
	var job_id = job.get_meta("job_id", "")
	var is_valid_job = false
	for available_job in available_job_offers:
		if available_job.get_meta("job_id", "") == job_id:
			is_valid_job = true
			break
	
	if not is_valid_job:
		job_system_error.emit("invalid_job_selection", "Job not in available offers", {"job_id": job_id})
		return false
	
	selected_job = job
	_update_job_accept_button_state()
	_change_job_workflow_state("job_selected", {"job": job, "source": "external"})
	return true

## Force job acceptance (for testing and external integration)
func force_accept_job(job: Resource) -> bool:
	if not job:
		return false
	
	selected_job = job
	_change_job_workflow_state("job_acceptance", {"job": job, "source": "forced"})
	return true

## Reset job system to initial state
func reset_job_system() -> void:
	_reset_job_workflow()

## Get job system status for debugging
func get_job_system_status() -> Dictionary:
	return {
		"initialized": job_system_initialized,
		"workflow_state": current_job_workflow_state,
		"selected_job_id": selected_job.get_meta("job_id", "") if selected_job else "",
		"available_offers_count": available_job_offers.size(),
		"error_count": job_error_count,
		"job_selection_ui_active": job_selection_ui != null,
		"job_selection_container_visible": job_selection_container.visible if job_selection_container else false
	}

## Enable/disable job system (for troubleshooting)
func set_job_system_enabled(enabled: bool) -> void:
	if enabled and not job_system_initialized:
		_initialize_job_system_integration()
		_setup_job_signal_bridge()
		_connect_job_system_signals()
	elif not enabled and job_system_initialized:
		_cleanup_job_selection_ui()
		job_system_initialized = false
		current_job_workflow_state = "none"

## Add external job offers (for integration with other job systems)
func add_external_job_offers(external_jobs: Array[Resource]) -> int:
	var added_count = 0
	for job in external_jobs:
		if job and job.has_meta("job_id"):
			available_job_offers.append(job)
			added_count += 1
	
	if added_count > 0:
		job_offers_updated.emit(available_job_offers)
		show_notification("External Jobs", "Added %d external job offers" % added_count, "info", 2.0)
	
	return added_count

## Trigger manual job validation (for external systems)
func validate_job_external(job: Resource) -> void:
	if job:
		_validate_job_async(job)

## Get job validation errors for a specific job
func get_job_validation_errors(job: Resource) -> Array[String]:
	if not job:
		return ["Job is null"]
	
	var errors: Array[String] = []
	
	# Basic validation
	if not job.has_meta("job_id") or job.get_meta("job_id") == "":
		errors.append("Job ID missing")
	if not job.has_meta("job_type"):
		errors.append("Job type missing")
	if not job.has_meta("reward_credits") or job.get_meta("reward_credits") <= 0:
		errors.append("Invalid reward")
	
	# Crew validation
	var crew_validation = _validate_crew_capabilities(job)
	errors.append_array(crew_validation.errors)
	
	return errors

## Convert job between different formats (utility method)
func convert_job_format(job: Resource, target_format: String) -> Variant:
	match target_format:
		"world_phase":
			return JobDataAdapter.convert_ui_to_world_phase(job)
		"job_opportunity":
			return JobDataAdapter.convert_ui_to_job_opportunity(job)
		_:
			push_error("WorldPhaseUI: Unknown job format: %s" % target_format)
			return null

## =================================================================
## UNIFIED AUTOMATION HELPER METHODS (FEATURES 7 & 8)
## =================================================================

## Get current automation mode from UI
func _get_current_automation_mode() -> String:
	var mode_selector = automation_controls.get_node_or_null("AutomationModeSelector/AutomationModeOptions")
	if mode_selector and mode_selector is OptionButton:
		var mode_names = ["Manual Only", "Crew Tasks Only", "Job Selection Only", "Full Automation"]
		var selected_index = mode_selector.selected
		return mode_names[selected_index] if selected_index < mode_names.size() else "Manual Only"
	return "Manual Only"

## Update unified automation UI state
func _update_unified_automation_ui_state(enabled: bool) -> void:
	# Update automation toggle
	var auto_toggle = automation_controls.get_node_or_null("AutomationToggle")
	if auto_toggle:
		auto_toggle.button_pressed = enabled
	
	# Update auto-resolve button
	var auto_resolve_button = automation_controls.get_node_or_null("AutoResolveButton")
	if auto_resolve_button:
		auto_resolve_button.disabled = not enabled
	
	# Update manual override controls
	_update_manual_override_controls_state(enabled)
	
	# Update automation status display
	_update_automation_status_display(enabled)

## Update automation mode UI elements
func _update_automation_mode_ui(mode: String) -> void:
	# Update mode selector
	var mode_selector = automation_controls.get_node_or_null("AutomationModeSelector/AutomationModeOptions")
	if mode_selector and mode_selector is OptionButton:
		var mode_names = ["Manual Only", "Crew Tasks Only", "Job Selection Only", "Full Automation"]
		var mode_index = mode_names.find(mode)
		if mode_index != -1:
			mode_selector.selected = mode_index
	
	# Update relevant UI elements based on mode
	match mode:
		"Manual Only":
			_disable_automation_features()
		"Crew Tasks Only":
			_enable_crew_task_automation_only()
		"Job Selection Only":
			_enable_job_selection_automation_only()
		"Full Automation":
			_enable_full_automation_features()

## Configure automation controller for selected mode
func _configure_automation_controller_for_mode(mode: String) -> void:
	if not automation_controller:
		return
	
	match mode:
		"Manual Only":
			automation_controller.set_feedback_system_enabled(false)
		"Crew Tasks Only":
			automation_controller.set_feedback_system_enabled(true)
			# Configure for crew tasks only
			if automation_controller.has_method("set_automation_scope"):
				automation_controller.set_automation_scope(["crew_tasks"])
		"Job Selection Only":
			automation_controller.set_feedback_system_enabled(true)
			# Configure for job selection only
			if automation_controller.has_method("set_automation_scope"):
				automation_controller.set_automation_scope(["job_selection"])
		"Full Automation":
			automation_controller.set_feedback_system_enabled(true)
			# Configure for full automation
			if automation_controller.has_method("set_automation_scope"):
				automation_controller.set_automation_scope(["crew_tasks", "job_selection", "mission_prep"])

## Automation mode implementations
func _disable_automation_features() -> void:
	automation_enabled = false
	# Disable automation UI elements
	var stop_button = automation_controls.get_node_or_null("ManualOverrideControls/StopAutomationButton")
	if stop_button:
		stop_button.disabled = true
	
	var skip_button = automation_controls.get_node_or_null("ManualOverrideControls/SkipOperationButton")
	if skip_button:
		skip_button.disabled = true

func _enable_crew_task_automation_only() -> void:
	automation_enabled = true
	# Enable crew task automation, disable job automation
	print("WorldPhaseUI: Crew task automation only mode enabled")

func _enable_job_selection_automation_only() -> void:
	automation_enabled = true
	# Enable job selection automation, disable crew task automation
	print("WorldPhaseUI: Job selection automation only mode enabled")

func _enable_full_automation_features() -> void:
	automation_enabled = true
	# Enable all automation features
	var stop_button = automation_controls.get_node_or_null("ManualOverrideControls/StopAutomationButton")
	if stop_button:
		stop_button.disabled = false
	
	var skip_button = automation_controls.get_node_or_null("ManualOverrideControls/SkipOperationButton")
	if skip_button:
		skip_button.disabled = false
	
	print("WorldPhaseUI: Full automation mode enabled")

## Automation workflow implementations
func _automate_crew_tasks_only() -> void:
	print("WorldPhaseUI: Automating crew tasks only")
	
	if automation_controller:
		# Create mock crew assignments for crew task automation
		var crew_assignments := {
			"Captain": GlobalEnums.CrewTaskType.FIND_PATRON,
			"Engineer": GlobalEnums.CrewTaskType.TRADE,
			"Medic": GlobalEnums.CrewTaskType.TRAIN
		}
		automation_controller.automate_crew_task_resolution(crew_assignments)
	
	show_notification("Crew Automation", "Automating crew tasks only", "info", 2.0)

func _automate_job_selection_only() -> void:
	print("WorldPhaseUI: Automating job selection only")
	
	# Switch to job offers step if not already there
	if current_step != 2:
		_show_step(2)
		# Note: await removed since this function is not async
	
	# Trigger job generation and auto-selection
	if available_job_offers.is_empty():
		_trigger_job_generation()
		# Note: await removed since this function is not async
	
	# Auto-select first valid job
	if available_job_offers.size() > 0:
		var best_job = _select_best_job_automatically()
		if best_job:
			set_selected_job(best_job)
			# Note: await removed since this function is not async
			force_accept_job(best_job)
	
	show_notification("Job Automation", "Automating job selection only", "info", 2.0)

func _automate_full_workflow() -> void:
	print("WorldPhaseUI: Automating full workflow")
	
	# Start with crew tasks
	_automate_crew_tasks_only()
	
	# Crew task completion will trigger job selection automatically
	show_notification("Full Automation", "Automating complete world phase workflow", "info", 3.0)

## Automation progression helpers
func _auto_advance_to_job_selection() -> void:
	print("WorldPhaseUI: Auto-advancing to job selection")
	if current_step != 2:
		_show_step(2)
		# Note: await removed since this function is not async
		_automate_job_selection_only()

func _auto_advance_to_mission_prep() -> void:
	print("WorldPhaseUI: Auto-advancing to mission prep")
	if current_step != 3:
		_show_step(3)

func _auto_advance_to_next_step() -> void:
	if current_step < total_steps - 1:
		_show_step(current_step + 1)

## Job selection automation helpers
func _select_best_job_automatically() -> Resource:
	if available_job_offers.is_empty():
		return null
	
	# Simple scoring: prefer higher-paying, lower-difficulty jobs
	var best_job: Resource = null
	var best_score: float = -1.0
	
	for job in available_job_offers:
		var reward = job.get_meta("reward_credits", 0)
		var difficulty = job.get_meta("difficulty", 5) # Default to medium difficulty
		var score = float(reward) / float(difficulty + 1) # Avoid division by zero
		
		if score > best_score:
			best_score = score
			best_job = job
	
	return best_job

## Manual override implementations
func _skip_current_job_operation() -> void:
	match current_job_workflow_state:
		"job_validation":
			# Skip validation and mark as validated
			_change_job_workflow_state("job_validated", {"skipped": true})
		"job_acceptance":
			# Skip acceptance and mark as accepted
			if selected_job:
				job_acceptance_completed.emit(selected_job, true)
				_change_job_workflow_state("job_accepted", {"skipped": true})

func _enable_manual_job_selection_mode() -> void:
	print("WorldPhaseUI: Enabling manual job selection mode")
	
	# Disable job-related automation temporarily
	var current_mode = _get_current_automation_mode()
	if current_mode in ["Job Selection Only", "Full Automation"]:
		# Show manual override notification
		show_notification(
			"Manual Override",
			"Job selection switched to manual mode",
			"info",
			2.0
		)
	
	# Ensure job selection UI is visible and functional
	if job_selection_container:
		job_selection_container.visible = true
	
	if not job_selection_ui:
		_create_job_selection_ui()

## Automation error recovery
func _handle_automation_error_recovery(error_type: String, error_message: String) -> void:
	print("WorldPhaseUI: Handling automation error recovery: %s" % error_type)
	
	match error_type:
		"job_system_error":
			# Try to recover by generating fallback jobs
			_generate_fallback_jobs()
		"crew_task_error":
			# Skip problematic crew task and continue
			if automation_controller and automation_controller.has_method("skip_current_task"):
				automation_controller.skip_current_task()
		"validation_error":
			# Switch to manual mode for this operation
			_enable_manual_job_selection_mode()
		_:
			# Generic recovery: pause automation and notify user
			_on_stop_automation()
			show_notification(
				"Automation Error",
				"Automation stopped due to error: %s" % error_message,
				"critical",
				5.0
			)

## Progress tracking helpers
func _update_unified_progress(operation_type: String, data: Dictionary) -> void:
	var progress = SafeDataAccess.safe_get(data, "progress", 0.0, "unified progress update")
	
	# Update unified progress display
	var unified_progress = automation_controls.get_node_or_null("UnifiedProgressDisplay/PhaseProgress")
	if unified_progress and unified_progress is ProgressBar:
		# Calculate overall progress based on current step and operation progress
		var step_weight = 1.0 / float(total_steps)
		var step_progress = float(current_step) * step_weight
		var operation_progress = progress * step_weight
		var total_progress = (step_progress + operation_progress) * 100.0
		
		var tween = create_tween()
		tween.tween_property(unified_progress, "value", total_progress, 0.2)
	
	# Update operation status
	var status_text = _get_operation_status_text(operation_type, data)
	_update_automation_operation_status(status_text)

func _get_operation_status_text(operation_type: String, data: Dictionary) -> String:
	match operation_type:
		"crew_task_assigned":
			return "Assigning: %s" % SafeDataAccess.safe_get(data, "task_type", "Unknown Task", "operation status")
		"crew_task_resolved":
			return "Task completed: %s" % SafeDataAccess.safe_get(data, "crew_id", "Unknown", "operation status")
		"job_selected":
			return "Job selected: %s" % SafeDataAccess.safe_get(data, "job_id", "Unknown", "operation status")
		"job_accepted":
			return "Job accepted: %s" % SafeDataAccess.safe_get(data, "job_id", "Unknown", "operation status")
		"all_crew_tasks_resolved":
			return "All crew tasks completed (%d)" % SafeDataAccess.safe_get(data, "results_count", 0, "operation status")
		"world_phase_completed":
			return "World phase completed successfully"
		_:
			return "Processing: %s" % operation_type

## Automation status display updates
func _update_automation_status_display(enabled: bool) -> void:
	var state_label = automation_controls.get_node_or_null("AutomationStatusDisplay/AutomationStateLabel")
	if state_label:
		if enabled:
			var mode = _get_current_automation_mode()
			state_label.text = "🟢 Automation: %s" % mode
			state_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			state_label.text = "🔴 Automation Disabled"
			state_label.add_theme_color_override("font_color", Color.RED)

func _update_automation_operation_status(status: String) -> void:
	var status_label = automation_controls.get_node_or_null("UnifiedProgressDisplay/CurrentOperationStatus")
	if status_label:
		status_label.text = status

func _update_manual_override_controls_state(automation_enabled: bool) -> void:
	var stop_button = automation_controls.get_node_or_null("ManualOverrideControls/StopAutomationButton")
	if stop_button:
		stop_button.disabled = not automation_enabled
	
	var skip_button = automation_controls.get_node_or_null("ManualOverrideControls/SkipOperationButton")
	if skip_button:
		skip_button.disabled = not automation_enabled

## Step-based automation control updates
func _update_automation_controls_for_step(step: int) -> void:
	# Enable/disable specific automation features based on current step
	match step:
		0: # Upkeep
			# Enable upkeep automation if available
			pass
		1: # Crew Tasks
			# Enable crew task automation
			pass
		2: # Job Offers
			# Enable job selection automation
			pass
		3: # Mission Prep
			# Enable mission prep automation
			pass

func _update_unified_step_progress(step: int, step_name: String) -> void:
	# Update progress based on step completion
	var step_progress = float(step) / float(total_steps - 1) * 100.0
	
	var unified_progress = automation_controls.get_node_or_null("UnifiedProgressDisplay/PhaseProgress")
	if unified_progress and unified_progress is ProgressBar:
		var tween = create_tween()
		tween.tween_property(unified_progress, "value", step_progress, 0.3)
	
	_update_automation_operation_status("Step %d: %s" % [step + 1, step_name])

## Crew task completion checking for automation
func _check_crew_tasks_completion_for_automation() -> void:
	# Check if all crew tasks are completed and automation should advance
	var mode = _get_current_automation_mode()
	if mode in ["Full Automation"] and current_step == 1: # Crew Tasks step
		# Simulate crew task completion check
		# In a real implementation, this would check actual crew task states
		var all_tasks_complete = true # Placeholder
		
		if all_tasks_complete:
			_auto_advance_to_job_selection()

## Responsive design helpers
func _adapt_automation_controls_to_orientation(orientation: String) -> void:
	# Adapt automation controls layout for different orientations
	if automation_controls:
		match orientation:
			"portrait":
				# Stack automation controls vertically
				automation_controls.get_parent().move_child(automation_controls, -1)
			"landscape":
				# Arrange automation controls horizontally where possible
				pass

func _adapt_automation_controls_to_screen_size(screen_size: Vector2) -> void:
	# Adapt automation controls for different screen sizes
	if automation_controls:
		var scale_factor = min(screen_size.x / 800.0, screen_size.y / 600.0)
		scale_factor = max(0.7, min(1.2, scale_factor)) # Clamp scale factor
		
		# Apply responsive scaling to automation controls
		for child in automation_controls.get_children():
			if child is Control:
				child.scale = Vector2(scale_factor, scale_factor)

## Progress bar specific updates
func _update_specific_progress_bar(id: String, progress: float, status: String) -> void:
	# Update specific progress bars in the unified system
	if id.begins_with("unified_"):
		var unified_progress = automation_controls.get_node_or_null("UnifiedProgressDisplay/PhaseProgress")
		if unified_progress and unified_progress is ProgressBar:
			var tween = create_tween()
			tween.tween_property(unified_progress, "value", progress * 100.0, 0.2)
	
	# Update task-specific progress bars if they exist
	if task_progress_bars.has(id):
		var progress_bar = task_progress_bars[id]
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", progress * 100.0, 0.2)

## =================================================================
## ENHANCED JOB OFFERS STEP INTEGRATION
## =================================================================

func _show_step(step: int) -> void:
	if step < 0 or step >= total_steps:
		return
	
	current_step = step
	world_phase_state.current_substep = step
	world_phase_state.substep_name = step_names[step]
	
	# Clear existing content
	_clear_content_area()
	
	# Show content for current step
	_refresh_content_for_step(step)
	
	# Update UI state
	_update_step_navigation()
	_update_progress_display()
	_update_navigation_buttons()
	
	# Emit step change signal
	world_phase_step_changed.emit(step, step_names[step])
	if signals_manager:
		signals_manager.emit_world_phase_step_changed(step, step_names[step])

## Clear the content area for new step content
func _clear_content_area() -> void:
	if not content_container:
		return
	
	var content_area = content_container.get_node("ContentArea")
	if content_area:
		for child in content_area.get_children():
			child.queue_free()

## Refresh content for the current step
func _refresh_content_for_step(step: int) -> void:
	if not content_container:
		return
	
	var content_area = content_container.get_node("ContentArea")
	if not content_area:
		return
	
	# Hide all extracted panels first
	if extracted_crew_task_panel: extracted_crew_task_panel.visible = false
	if extracted_job_offer_panel: extracted_job_offer_panel.visible = false
	# Add other extracted panels here as they are consolidated
	
	match step:
		0: # Upkeep
			# Placeholder for upkeep content
			pass
		1: # Crew Tasks
			if extracted_crew_task_panel:
				extracted_crew_task_panel.visible = true
		2: # Job Offers
			if extracted_job_offer_panel:
				extracted_job_offer_panel.visible = true
				# Ensure the job selection UI is created and configured
				_create_job_selection_ui()
		3: # Mission Prep
			# Placeholder for mission prep content
			pass

## Create upkeep phase content
func _create_upkeep_content(parent: Control) -> void:
	var label = Label.new()
	label.text = "Upkeep Phase - Calculate costs and handle ship maintenance"
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	
	if automation_enabled and automation_controller:
		var auto_button = Button.new()
		auto_button.text = "Auto-Calculate Upkeep"
		auto_button.pressed.connect(_on_auto_upkeep)
		parent.add_child(auto_button)

## Create crew tasks phase content
func _create_crew_tasks_content(parent: Control) -> void:
	var label = Label.new()
	label.text = "Crew Tasks Phase - Assign and resolve crew member tasks"
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	
	# Add task progress display if available
	if task_progress_container and task_progress_container.get_child_count() > 0:
		var progress_label = Label.new()
		progress_label.text = "Current Tasks:"
		progress_label.add_theme_font_size_override("font_size", 14)
		parent.add_child(progress_label)

## Create job offers phase content - Features 7 & 8 Unified Enhanced
func _create_job_offers_content(parent: Control) -> void:
	var label = Label.new()
	label.text = "Job Offers Phase - Review and accept available jobs"
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	
	# Feature 8: Initialize job system for this step
	if job_system_initialized:
		# Show job selection container
		if job_selection_container:
			job_selection_container.visible = true
		
		# Create job selection UI if not already created
		if not job_selection_ui:
			_create_job_selection_ui()
		
		# Change workflow state to indicate job selection is open
		_change_job_workflow_state("job_selection_open", {"step": current_step})
		
		# Generate job offers if none are available
		if available_job_offers.is_empty():
			_trigger_job_generation()
		
		# Create unified automation and manual controls for job selection
		_create_job_offers_automation_controls(parent)
		
		# Add job acceptance button
		var accept_button = Button.new()
		accept_button.text = "Accept Selected Job"
		accept_button.add_to_group("touch_buttons")
		accept_button.disabled = selected_job == null
		accept_button.pressed.connect(_on_manual_job_acceptance)
		parent.add_child(accept_button)
		
		# Store reference for enabling/disabling based on job selection
		accept_button.name = "JobAcceptButton"
	else:
		# Fallback to basic content if job system not initialized
		var status_label = Label.new()
		status_label.text = "Job system initializing..."
		status_label.add_theme_color_override("font_color", Color.ORANGE)
		parent.add_child(status_label)

## Create automation and manual controls specifically for job offers step
func _create_job_offers_automation_controls(parent: Control) -> void:
	var controls_container = HBoxContainer.new()
	controls_container.name = "JobOffersControls"
	
	# Auto-select best job button
	var auto_select_button = Button.new()
	auto_select_button.name = "AutoSelectBestJob"
	auto_select_button.text = "Auto-Select Best Job"
	auto_select_button.add_to_group("touch_buttons")
	auto_select_button.pressed.connect(_on_auto_select_best_job)
	controls_container.add_child(auto_select_button)
	
	# Generate more jobs button
	var generate_more_button = Button.new()
	generate_more_button.name = "GenerateMoreJobs"
	generate_more_button.text = "Generate More Jobs"
	generate_more_button.add_to_group("touch_buttons")
	generate_more_button.pressed.connect(_on_generate_more_jobs)
	controls_container.add_child(generate_more_button)
	
	# Job automation mode toggle
	var job_auto_toggle = CheckBox.new()
	job_auto_toggle.name = "JobAutomationToggle"
	job_auto_toggle.text = "Auto-Accept Jobs"
	job_auto_toggle.toggled.connect(_on_job_automation_toggled)
	controls_container.add_child(job_auto_toggle)
	
	parent.add_child(controls_container)

## Handle auto-select best job button
func _on_auto_select_best_job() -> void:
	print("WorldPhaseUI: Auto-selecting best job")
	
	var best_job = _select_best_job_automatically()
	if best_job:
		set_selected_job(best_job)
		_update_job_accept_button_state()
		
		show_notification(
			"Best Job Selected",
			"Automatically selected: %s" % best_job.get_meta("mission_type", "Unknown"),
			"success",
			2.0
		)
	else:
		show_notification(
			"No Jobs Available",
			"No suitable jobs found for auto-selection",
			"info",
			2.0
		)

## Handle generate more jobs button
func _on_generate_more_jobs() -> void:
	print("WorldPhaseUI: Generating additional jobs")
	
	# Trigger job generation
	_trigger_job_generation()
	
	show_notification(
		"Generating Jobs",
		"Requesting additional job offers...",
		"info",
		2.0
	)

## Handle job automation toggle
func _on_job_automation_toggled(enabled: bool) -> void:
	print("WorldPhaseUI: Job automation toggled: %s" % enabled)
	
	if enabled:
		# If automation is enabled and we have a selected job, auto-accept it
		if selected_job:
			show_notification(
				"Job Auto-Accept",
				"Job auto-acceptance enabled",
				"info",
				2.0
			)
			# Note: await removed since this function is not async
			_on_manual_job_acceptance()
		else:
			# Auto-select and accept best job
			_on_auto_select_best_job()
			# Note: await removed since this function is not async
			if selected_job:
				_on_manual_job_acceptance()
	else:
		show_notification(
			"Job Auto-Accept Disabled",
			"Manual job selection mode",
			"info",
			2.0
		)

## Trigger job generation through WorldPhase
func _trigger_job_generation() -> void:
	if world_phase and world_phase.has_method("_generate_job_offers"):
		print("WorldPhaseUI: Triggering job generation through WorldPhase")
		world_phase._generate_job_offers()
	else:
		print("WorldPhaseUI: Generating fallback jobs - WorldPhase unavailable")
		_generate_fallback_jobs()

## Handle manual job acceptance button press
func _on_manual_job_acceptance() -> void:
	if selected_job:
		# Start validation and acceptance workflow
		_change_job_workflow_state("job_validation", {"job": selected_job, "source": "manual"})
	else:
		show_notification("No Job Selected", "Please select a job before accepting", "info", 2.0)

## Create mission prep phase content
func _create_mission_prep_content(parent: Control) -> void:
	var label = Label.new()
	label.text = "Mission Prep Phase - Prepare for the selected mission"
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)

## Update step navigation buttons
func _update_step_navigation() -> void:
	if not step_navigation:
		return
	
	for i in range(total_steps):
		var button_name = "Step%dButton" % (i + 1)
		var button = step_navigation.get_node(button_name)
		if button:
			button.disabled = i > current_step + 1 # Allow current and next step

## Update progress display
func _update_progress_display() -> void:
	if not progress_display:
		return
	
	var progress_bar = progress_display.get_node("PhaseProgressBar")
	if progress_bar:
		var progress = float(current_step) / float(total_steps - 1) * 100.0
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", progress, 0.3)
	
	var status_label = progress_display.get_node("StatusLabel")
	if status_label:
		status_label.text = "Step %d of %d: %s" % [current_step + 1, total_steps, step_names[current_step]]

## Update navigation buttons
func _update_navigation_buttons() -> void:
	if not content_container:
		return
	
	var nav_buttons = content_container.get_node("NavigationButtons")
	if not nav_buttons:
		return
	
	var back_button = nav_buttons.get_node("BackButton")
	var next_button = nav_buttons.get_node("NextButton")
	
	if back_button:
		back_button.disabled = current_step == 0
	
	if next_button:
		next_button.disabled = current_step >= total_steps - 1

## Update world display information (duplicate removed)
# This function is already defined earlier in the file

## Handle auto upkeep button
func _on_auto_upkeep() -> void:
	if automation_controller:
		show_notification("Starting Upkeep", "Automating upkeep calculation...", "info", 2.0)
		automation_controller._automate_upkeep_calculation()

## Handle missing signal connections
func _on_step_changed(step: int, step_name: String) -> void:
	# Additional step change handling if needed
	pass

func _on_automation_mode_changed(enabled: bool) -> void:
	# Additional automation mode change handling if needed
	pass

func _update_crew_list() -> void:
	"""Update the crew list for task assignment"""
	crew_list.clear()

	if not campaign_data:
		return

	var crew_data = campaign_data.get_meta("crew", [])
	for crew_member in crew_data:
		var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "crew display setup")
		var name = SafeDataAccess.safe_get(crew_dict, "name", "Unknown", "crew display setup")
		var status = SafeDataAccess.safe_get(crew_dict, "status", "Available", "crew display setup")
		crew_list.add_item("%s (%s)" % [name, status])

func _update_job_offers() -> void:
	"""Update available job offers"""
	patron_list.clear()

	if not job_system or not campaign_data:
		job_details.text = "No job system available"
		return

	var available_jobs = job_system.generate_job_offers(campaign_data)
	for job in available_jobs:
		var job_dict = SafeDataAccess.safe_dict_access(job, "patron list update")
		var patron_name = SafeDataAccess.safe_get(job_dict, "patron", "Unknown Patron", "patron list update")
		var job_type = SafeDataAccess.safe_get(job_dict, "type", "Standard", "patron list update")
		patron_list.add_item("%s - %s" % [patron_name, job_type])

	if available_jobs.size() > 0:
		job_details.text = "Select a patron to view job details"
	else:
		job_details.text = "No jobs available in this system"

func _update_step_availability() -> void:
	"""Update which steps are available based on progress"""
	# Logic to enable/disable steps based on completion
	pass

# Signal handlers

func _on_back_pressed() -> void:
	"""Handle back button press"""
	if current_step > 0:
		_show_step(current_step - 1)

func _on_next_pressed() -> void:
	"""Handle next button press"""
	if current_step < 3:
		_show_step(current_step + 1)
	else:
		phase_completed.emit()

func _on_options_pressed() -> void:
	"""Handle options button press"""
	# Show world phase options menu
	var options_menu = AcceptDialog.new()
	options_menu.title = "World Phase Options"
	
	var vbox = VBoxContainer.new()
	vbox.add_child(Label.new())
	vbox.get_child(0).text = "World Phase Settings:"
	
	var auto_resolve_check = CheckBox.new()
	auto_resolve_check.text = "Auto-resolve simple tasks"
	vbox.add_child(auto_resolve_check)
	
	options_menu.add_child(vbox)
	add_child(options_menu)
	options_menu.popup_centered()

func _on_resolve_tasks() -> void:
	"""Handle resolving crew tasks"""
	var selected_indices = crew_list.get_selected_items()
	if selected_indices.size() == 0:
		return

	# Get crew data from game state
	var crew_data = []
	if game_state_manager:
		crew_data = game_state_manager.get_crew_members()
	
	var task_type = task_assignment.get_item_text(task_assignment.selected)
	print("Resolving %s task for crew members" % task_type)

	# Implement actual task resolution
	var dice_mgr = get_node_or_null("/root/DiceManager")
	for index in selected_indices:
		var crew_member = crew_data[index]
		var task_result = _resolve_crew_task(crew_member, task_type, dice_mgr)
		var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "task resolution")
		var crew_name = SafeDataAccess.safe_get(crew_dict, "name", "Unknown", "task resolution")
		print("Task result for %s: %s" % [crew_name, task_result])
	
	resolve_task_button.text = "Tasks Resolved ✓"
	resolve_task_button.disabled = true

func _resolve_crew_task(crew_member: Dictionary, task_type: String, dice_mgr) -> String:
	"""Resolve a crew member's task"""
	var crew_dict = SafeDataAccess.safe_dict_access(crew_member, "crew task resolution")
	var base_skill = SafeDataAccess.safe_get(crew_dict, "savvy", 3, "crew task resolution")
	var roll = 0
	
	if dice_mgr and dice_mgr.has_method("roll_dice"):
		roll = dice_mgr.roll_dice(1, 6)
	else:
		roll = randi_range(1, 6)
	
	var total = base_skill + roll
	
	match task_type:
		"Trade":
			if total >= 8:
				return "Successful trade (+2 credits)"
			else:
				return "Trade failed"
		"Explore":
			if total >= 7:
				return "Found something interesting"
			else:
				return "Nothing found"
		"Recruit":
			if total >= 9:
				return "Potential recruit found"
			else:
				return "No suitable candidates"
		_:
			return "Task completed"

func _on_accept_job(job_id: String = "") -> void:
	"""Handle accepting a job with optional job_id parameter"""
	
	# Legacy support: if no job_id provided, try to get from selected indices
	if job_id.is_empty():
		var selected_indices = patron_list.get_selected_items() if patron_list else []
		if selected_indices.size() > 0:
			var job_index = selected_indices[0]
			if job_system:
				var available_jobs = job_system.generate_job_offers(campaign_data)
				if job_index < available_jobs.size():
					selected_job = available_jobs[job_index]
					job_selected.emit(selected_job)
					# Update legacy UI elements if they exist
					var accept_job_button = get_node_or_null("AcceptJobButton")
					if accept_job_button:
						accept_job_button.text = "Job Accepted ✓"
						accept_job_button.disabled = true
					var next_button = get_node_or_null("NextButton")
					if next_button:
						next_button.disabled = false
					return
	
	# New system: handle job_id parameter
	if job_id.is_empty() and selected_job:
		job_id = selected_job.get_meta("job_id", "")
	
	if job_id.is_empty():
		show_notification("No Job Selected", "Please select a job before accepting", "warning", 2.0)
		return
	
	print("WorldPhaseUI: Accepting job: %s" % job_id)
	
	# Find the job in available offers
	var job_to_accept: Resource = null
	for job in available_job_offers:
		if job.get_meta("job_id", "") == job_id:
			job_to_accept = job
			break
	
	if job_to_accept:
		selected_job = job_to_accept
		_change_job_workflow_state("job_acceptance", {"job": job_to_accept, "source": "manual_accept"})
	else:
		show_notification("Job Not Found", "Selected job not found in available offers", "critical", 3.0)


func get_phase_status() -> Dictionary:
	"""Get the current phase status"""
	return {
		"current_step": current_step,
		"selected_job": selected_job,
		"current_world": current_world,
		"can_advance": not selected_job.is_empty()
	}

func load_campaign_data(data: Resource) -> void:
	"""Load campaign data for this phase"""
	campaign_data = data
	current_world = data.get_meta("current_world", "Unknown World") if data else "Unknown World"
	title_label.text = "World Phase: %s" % current_world
	_update_crew_list()
	_update_job_offers()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## Setup world phase icons for enhanced visual navigation
func _setup_world_phase_icons() -> void:
	"""Setup icons for world phase buttons to improve visual clarity"""
	# Phase 2: World Phase Icons Integration
	
	# Apply world phase icon to primary navigation buttons
	if content_container:
		var nav_buttons = content_container.get_node_or_null("NavigationButtons")
		if nav_buttons:
			var next_button = nav_buttons.get_node_or_null("NextButton")
			if next_button and next_button is Button:
				next_button.icon = preload("res://assets/basic icons/icon_campaign_world.svg")
				next_button.expand_icon = true
				next_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
				print("WorldPhaseUI: World phase icon applied to next button successfully")
			else:
				push_warning("WorldPhaseUI: Next button not found for icon assignment")
		else:
			push_warning("WorldPhaseUI: NavigationButtons container not found for icon assignment")
	else:
		push_warning("WorldPhaseUI: Content container not available for icon assignment")

## PRODUCTION READINESS: Component Extraction System


func _initialize_extracted_crew_task_panel() -> void:
	"""Initialize the extracted crew task panel"""
	extracted_crew_task_panel = CrewTaskPanel.new()
	extracted_crew_task_panel.set_parent_ui(self)
	extracted_crew_task_panel.set_data_manager(data_manager)
	extracted_crew_task_panel.enable_feature(true)
	
	# Add to content container
	if content_container:
		content_container.add_child(extracted_crew_task_panel)
		if enable_component_extraction_debug:
			print("WorldPhaseUI: CrewTaskPanel successfully initialized and added")
	else:
		push_error("WorldPhaseUI: Cannot add CrewTaskPanel - content_container not available")

func _initialize_extracted_job_offer_panel() -> void:
	"""Initialize the extracted job offer panel"""
	extracted_job_offer_panel = JobOfferPanel.new()
	extracted_job_offer_panel.set_parent_ui(self)
	extracted_job_offer_panel.set_data_manager(data_manager)
	extracted_job_offer_panel.enable_feature(true)
	
	# Add to content container
	if content_container:
		content_container.add_child(extracted_job_offer_panel)
		if enable_component_extraction_debug:
			print("WorldPhaseUI: JobOfferPanel successfully initialized and added")
	else:
		push_error("WorldPhaseUI: Cannot add JobOfferPanel - content_container not available")

## PRODUCTION READINESS: Component extraction debugging
func get_component_extraction_status() -> Dictionary:
	"""Get status of component extraction for monitoring/debugging"""
	return {
		"crew_tasks_extracted": enable_extracted_crew_tasks,
		"job_offers_extracted": enable_extracted_job_offers,
		"upkeep_extracted": enable_extracted_upkeep,
		"debug_enabled": enable_component_extraction_debug,
		"crew_task_panel_active": extracted_crew_task_panel != null and is_instance_valid(extracted_crew_task_panel),
		"job_offer_panel_active": extracted_job_offer_panel != null and is_instance_valid(extracted_job_offer_panel),
		"total_line_count": 3354, # Will decrease as more components are extracted
		"estimated_extracted_lines": _get_estimated_extracted_lines()
	}

func _get_estimated_extracted_lines() -> int:
	"""Estimate how many lines have been extracted from the monolith"""
	var extracted_lines = 0
	if enable_extracted_crew_tasks:
		extracted_lines += 600 # Estimated CrewTaskPanel size
	if enable_extracted_job_offers:
		extracted_lines += 500 # Estimated JobOfferPanel size
	if enable_extracted_upkeep:
		extracted_lines += 400 # Estimated UpkeepPanel size
	return extracted_lines

## =================================================================
## MISSING SIGNAL HANDLERS - FIXING LINTER ERRORS
## =================================================================

## Handle crew task started signal
func _on_crew_task_started(crew_id: String, task_type: String) -> void:
	print("WorldPhaseUI: Crew task started - %s: %s" % [crew_id, task_type])
	
	# Update progress tracking
	update_task_progress(crew_id, task_type, 0.1, "Starting %s task" % task_type)
	
	# Show notification
	show_notification(
		"Task Started",
		"%s began %s task" % [crew_id, task_type],
		"info",
		2.0
	)

## Handle crew task completed signal
func _on_crew_task_completed(crew_id: String, result: WorldPhaseResources.CrewTaskResult) -> void:
	print("WorldPhaseUI: Crew task completed - %s" % crew_id)
	
	# Update progress tracking
	update_task_progress(crew_id, "task", 1.0, "Task completed")
	
	# Show result notification
	var result_text = "Success" if result.success else "Failed"
	show_notification(
		"Task Complete",
		"%s completed task: %s" % [crew_id, result_text],
		"success" if result.success else "warning",
		3.0
	)

## Handle patron contacted signal
func _on_patron_contacted(patron_data: WorldPhaseResources.PatronData) -> void:
	print("WorldPhaseUI: Patron contacted - %s" % patron_data.patron_name)
	
	# Update UI to show patron information
	_update_patron_display(patron_data)
	
	# Show notification
	show_notification(
		"Patron Contacted",
		"Contacted %s" % patron_data.patron_name,
		"info",
		2.0
	)

## Handle job offer generated signal
func _on_job_offer_generated(job: WorldPhaseResources.JobOpportunity) -> void:
	print("WorldPhaseUI: Job offer generated - %s" % job.job_id)
	
	# Add to available job offers
	# Convert JobOpportunity to Dictionary format for JobDataAdapter
	var job_dict = {
		"job_id": job.job_id,
		"mission_type": job.mission_type,
		"reward_credits": job.reward_credits,
		"difficulty": job.difficulty,
		"description": job.description,
		"requirements": job.requirements,
		"time_limit": job.time_limit
	}
	var ui_job = JobDataAdapter.convert_world_phase_to_ui(job_dict)
	if ui_job:
		available_job_offers.append(ui_job)
		job_offers_updated.emit(available_job_offers)
	
	# Show notification
	show_notification(
		"Job Offer",
		"New job offer: %s" % job.mission_type,
		"info",
		2.0
	)

## Handle equipment discovered signal
func _on_equipment_discovered(equipment: WorldPhaseResources.EquipmentDiscovery) -> void:
	print("WorldPhaseUI: Equipment discovered - %s" % equipment.equipment_name)
	
	# Update equipment display
	_update_equipment_display(equipment)
	
	# Show notification
	show_notification(
		"Equipment Found",
		"Discovered: %s" % equipment.equipment_name,
		"success",
		3.0
	)

## Handle automation update signal
func _on_automation_update(update_data: Dictionary) -> void:
	print("WorldPhaseUI: Automation update received")
	
	# Update automation status display
	var status = SafeDataAccess.safe_get(update_data, "status", "Unknown", "automation update")
	var progress = SafeDataAccess.safe_get(update_data, "progress", 0.0, "automation update")
	
	_update_automation_operation_status(status)
	
	# Update progress if provided
	if update_data.has("progress"):
		_update_unified_progress("automation_update", update_data)

## Handle missing signal handlers registration
func _register_missing_signal_handlers() -> void:
	"""Register any missing signal handlers to prevent linter errors"""
	print("WorldPhaseUI: Registering missing signal handlers")
	
	# This function ensures all signal handlers are properly registered
	# The actual handlers are implemented above
	
	# Connect to automation controller if available
	if automation_controller:
		if automation_controller.has_signal("crew_task_started") and not automation_controller.crew_task_started.is_connected(_on_crew_task_started):
			automation_controller.crew_task_started.connect(_on_crew_task_started)
		
		if automation_controller.has_signal("crew_task_completed") and not automation_controller.crew_task_completed.is_connected(_on_crew_task_completed):
			automation_controller.crew_task_completed.connect(_on_crew_task_completed)


## Update patron display helper
func _update_patron_display(patron_data: WorldPhaseResources.PatronData) -> void:
	"""Update UI to show patron information"""
	if not content_container:
		return
	
	var content_area = content_container.get_node("ContentArea")
	if not content_area:
		return
	
	# Create or update patron display
	var patron_display = content_area.get_node_or_null("PatronDisplay")
	if not patron_display:
		patron_display = VBoxContainer.new()
		patron_display.name = "PatronDisplay"
		content_area.add_child(patron_display)
	
	# Clear existing content
	for child in patron_display.get_children():
		child.queue_free()
	
	# Add patron information
	var name_label = Label.new()
	name_label.text = "Patron: %s" % patron_data.patron_name
	name_label.add_theme_font_size_override("font_size", 14)
	patron_display.add_child(name_label)
	
	var type_label = Label.new()
	type_label.text = "Type: %s" % patron_data.patron_type
	type_label.add_theme_font_size_override("font_size", 12)
	patron_display.add_child(type_label)

## Update equipment display helper
func _update_equipment_display(equipment: WorldPhaseResources.EquipmentDiscovery) -> void:
	"""Update UI to show equipment information"""
	if not content_container:
		return
	
	var content_area = content_container.get_node("ContentArea")
	if not content_area:
		return
	
	# Create or update equipment display
	var equipment_display = content_area.get_node_or_null("EquipmentDisplay")
	if not equipment_display:
		equipment_display = VBoxContainer.new()
		equipment_display.name = "EquipmentDisplay"
		content_area.add_child(equipment_display)
	
	# Clear existing content
	for child in equipment_display.get_children():
		child.queue_free()
	
	# Add equipment information
	var name_label = Label.new()
	name_label.text = "Equipment: %s" % equipment.equipment_name
	name_label.add_theme_font_size_override("font_size", 14)
	equipment_display.add_child(name_label)
	
	var type_label = Label.new()
	type_label.text = "Type: %s" % equipment.equipment_type
	type_label.add_theme_font_size_override("font_size", 12)
	equipment_display.add_child(type_label)

## =================================================================
## ENHANCED JOB OFFERS STEP INTEGRATION
## =================================================================
