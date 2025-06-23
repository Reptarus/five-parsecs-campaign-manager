extends Control

# Use the new core system setup
var core_systems: Node = null
var creation_manager: Node = null

# UI Components
@onready var config_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/ConfigPanel")
@onready var crew_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/CrewPanel")
@onready var captain_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/CaptainPanel")
@onready var resource_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/ResourcePanel")
@onready var final_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/FinalPanel")

@onready var step_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/StepLabel")
@onready var next_button: Button = get_node_or_null("MarginContainer/VBoxContainer/Controls/NextButton")
@onready var back_button: Button = get_node_or_null("MarginContainer/VBoxContainer/Controls/BackButton")
@onready var cancel_button: Button = get_node_or_null("MarginContainer/VBoxContainer/Controls/CancelButton")

# State
var current_step: int = 0
var step_panels: Array[Control] = []

func _ready() -> void:
	print("CampaignCreationUI: Initializing...")
	_setup_ui()
	_initialize_core_systems()

func _initialize_core_systems() -> void:
	"""Initialize connection to core systems"""
	# Get the core system setup autoload
	core_systems = get_node_or_null("/root/CoreSystemSetup")
	
	if not core_systems:
		push_error("CampaignCreationUI: CoreSystemSetup autoload not found")
		_create_fallback_ui()
		return
	
	# Check if systems are ready
	if core_systems.has_method("is_ready") and core_systems.is_ready():
		_on_core_systems_ready()
	else:
		# Wait for systems to be ready
		if core_systems.has_signal("core_systems_ready"):
			core_systems.core_systems_ready.connect(_on_core_systems_ready)
		else:
			push_warning("CampaignCreationUI: Core systems not ready, using fallback")
			_create_fallback_ui()

func _on_core_systems_ready() -> void:
	"""Handle core systems being ready"""
	print("CampaignCreationUI: Core systems ready, getting creation manager...")
	
	if core_systems.has_method("get_campaign_creation_manager"):
		creation_manager = core_systems.get_campaign_creation_manager()
		
		if creation_manager:
			_connect_creation_manager_signals()
			print("CampaignCreationUI: Connected to campaign creation manager")
		else:
			push_warning("CampaignCreationUI: Campaign creation manager not available")
			_create_fallback_ui()
	else:
		push_warning("CampaignCreationUI: Core systems don't support campaign creation manager")
		_create_fallback_ui()

func _connect_creation_manager_signals() -> void:
	"""Connect to creation manager signals"""
	if not creation_manager:
		return
	
	# Connect signals if they exist
	if creation_manager.has_signal("creation_step_changed"):
		creation_manager.creation_step_changed.connect(_on_creation_step_changed)
	
	if creation_manager.has_signal("campaign_creation_completed"):
		creation_manager.campaign_creation_completed.connect(_on_campaign_creation_completed)
	
	if creation_manager.has_signal("validation_failed"):
		creation_manager.validation_failed.connect(_on_validation_failed)

func _setup_ui() -> void:
	"""Setup the user interface"""
	# Collect step panels
	step_panels = []
	if config_panel:
		step_panels.append(config_panel)
	if crew_panel:
		step_panels.append(crew_panel)
	if captain_panel:
		step_panels.append(captain_panel)
	if resource_panel:
		step_panels.append(resource_panel)
	if final_panel:
		step_panels.append(final_panel)
	
	# Connect button signals
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# Show first step
	_update_ui_for_step(0)

func _create_fallback_ui() -> void:
	"""Create a fallback UI when core systems aren't available"""
	print("CampaignCreationUI: Creating fallback UI")
	
	# Hide all panels except the first one
	for i in range(step_panels.size()):
		if step_panels[i]:
			step_panels[i].visible = (i == 0)
	
	# Update step label
	if step_label:
		step_label.text = "Campaign Creation (Fallback Mode)"
	
	# Enable basic navigation
	if next_button:
		next_button.disabled = false
		next_button.text = "Next"
	
	if back_button:
		back_button.disabled = true

func _update_ui_for_step(step: int) -> void:
	"""Update UI for the current step"""
	current_step = step
	
	# Hide all panels
	for panel in step_panels:
		if panel:
			panel.visible = false
	
	# Show current panel
	if step < step_panels.size() and step_panels[step]:
		step_panels[step].visible = true
	
	# Update step label
	if step_label:
		var step_names = ["Configuration", "Crew Setup", "Captain Creation", "Resources", "Final Review"]
		if step < step_names.size():
			step_label.text = "Step " + str(step + 1) + ": " + step_names[step]
	
	# Update button states
	if back_button:
		back_button.disabled = (step == 0)
	
	if next_button:
		if step >= step_panels.size() - 1:
			next_button.text = "Create Campaign"
		else:
			next_button.text = "Next"

func _on_next_button_pressed() -> void:
	"""Handle next button press"""
	if creation_manager and creation_manager.has_method("advance_step"):
		creation_manager.advance_step()
	else:
		# Fallback navigation
		if current_step < step_panels.size() - 1:
			_update_ui_for_step(current_step + 1)
		else:
			_finalize_campaign_creation()

func _on_back_button_pressed() -> void:
	"""Handle back button press"""
	if creation_manager and creation_manager.has_method("go_back_step"):
		creation_manager.go_back_step()
	else:
		# Fallback navigation
		if current_step > 0:
			_update_ui_for_step(current_step - 1)

func _on_cancel_button_pressed() -> void:
	"""Handle cancel button press"""
	print("CampaignCreationUI: Campaign creation cancelled")
	_return_to_main_menu()

func _finalize_campaign_creation() -> void:
	"""Finalize campaign creation"""
	if creation_manager and creation_manager.has_method("finalize_campaign_creation"):
		var campaign = creation_manager.finalize_campaign_creation()
		if campaign:
			print("CampaignCreationUI: Campaign created successfully")
			_start_campaign(campaign)
		else:
			push_error("CampaignCreationUI: Failed to create campaign")
	else:
		# Fallback: just start a basic campaign
		print("CampaignCreationUI: Creating fallback campaign")
		_start_fallback_campaign()

func _start_campaign(campaign) -> void:
	"""Start the created campaign"""
	# Try to start the campaign through core systems
	if core_systems and core_systems.has_method("start_new_campaign"):
		var config = {"campaign": campaign}
		if core_systems.start_new_campaign(config):
			print("CampaignCreationUI: Campaign started successfully")
			_navigate_to_main_game()
		else:
			push_error("CampaignCreationUI: Failed to start campaign")
	else:
		push_warning("CampaignCreationUI: Core systems not available, using fallback")
		_navigate_to_main_game()

func _start_fallback_campaign() -> void:
	"""Start a basic fallback campaign"""
	if core_systems and core_systems.has_method("start_new_campaign"):
		var basic_config = {
			"name": "New Campaign",
			"difficulty": 1,
			"credits": 1000
		}
		core_systems.start_new_campaign(basic_config)
	
	_navigate_to_main_game()

func _navigate_to_main_game() -> void:
	"""Navigate to the main game scene"""
	var scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router and scene_router.has_method("navigate_to_main_game"):
		scene_router.navigate_to_main_game()
	else:
		# Fallback navigation
		get_tree().call_deferred("change_scene_to_file", "res://src/scenes/main/MainGameScene.tscn")

func _return_to_main_menu() -> void:
	"""Return to the main menu"""
	var scene_router = get_node_or_null("/root/SceneRouter")
	if scene_router and scene_router.has_method("return_to_main_menu"):
		scene_router.return_to_main_menu()
	else:
		# Fallback navigation
		get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/mainmenu/MainMenu.tscn")

# Signal handlers for creation manager
func _on_creation_step_changed(step: int) -> void:
	"""Handle creation step change"""
	_update_ui_for_step(step)

func _on_campaign_creation_completed(campaign) -> void:
	"""Handle campaign creation completion"""
	print("CampaignCreationUI: Campaign creation completed")
	_start_campaign(campaign)

func _on_validation_failed(errors: Array[String]) -> void:
	"""Handle validation failure"""
	print("CampaignCreationUI: Validation failed:")
	for error in errors:
		print("  - " + error)
	
	# Show error message to user
	# TODO: Implement proper error display UI