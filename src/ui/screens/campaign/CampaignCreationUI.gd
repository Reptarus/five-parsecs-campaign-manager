extends Control

const CampaignCreationManager = preload("res://src/core/campaign/CampaignCreationManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# UI Components
@onready var config_panel: Control = $"MarginContainer/VBoxContainer/StepPanels/ConfigPanel"
@onready var crew_panel: Control = $"MarginContainer/VBoxContainer/StepPanels/CrewPanel"
@onready var captain_panel: Control = $"MarginContainer/VBoxContainer/StepPanels/CaptainPanel"
@onready var resource_panel: Control = $"MarginContainer/VBoxContainer/StepPanels/ResourcePanel"
@onready var final_panel: Control = $"MarginContainer/VBoxContainer/StepPanels/FinalPanel"

@onready var step_label: Label = $"MarginContainer/VBoxContainer/Header/StepLabel"
@onready var next_button: Button = $"MarginContainer/VBoxContainer/Navigation/NextButton"
@onready var back_button: Button = $"MarginContainer/VBoxContainer/Navigation/BackButton"
@onready var finish_button: Button = $"MarginContainer/VBoxContainer/Navigation/FinishButton"

var creation_manager: CampaignCreationManager
var current_panel: Control
var current_step: int = 0
var max_steps: int = 5

func _ready() -> void:
	print("CampaignCreationUI: Starting initialization...")
	
	# Validate required nodes first
	if not _validate_required_nodes():
		push_error("CampaignCreationUI: Required nodes are missing")
		return
	
	# Setup UI first
	_setup_navigation()
	_setup_panels()
	
	# Initialize creation manager
	creation_manager = CampaignCreationManager.new()
	add_child(creation_manager)
	
	# Connect signals if methods exist
	if creation_manager.has_signal("creation_step_changed"):
		creation_manager.creation_step_changed.connect(_on_creation_step_changed)
	if creation_manager.has_signal("campaign_creation_completed"):
		creation_manager.campaign_creation_completed.connect(_on_campaign_creation_completed)
	
	# Start with first step
	_show_step(0)
	print("CampaignCreationUI: Initialization complete!")

func _validate_required_nodes() -> bool:
	"""Validate that all required UI nodes exist"""
	var required_nodes = [
		config_panel, crew_panel, captain_panel, resource_panel, final_panel,
		step_label, next_button, back_button, finish_button
	]
	
	for node in required_nodes:
		if not node:
			return false
	return true

func _setup_navigation() -> void:
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	finish_button.pressed.connect(_on_finish_pressed)
	
	# Initial state
	back_button.hide()
	finish_button.hide()
	next_button.disabled = false

func _setup_panels() -> void:
	# Hide all panels initially
	var step_panels = $"MarginContainer/VBoxContainer/StepPanels"
	for panel in step_panels.get_children():
		panel.hide()
	
	# Connect panel signals if they exist
	if config_panel and config_panel.has_signal("config_updated"):
		config_panel.config_updated.connect(_on_config_updated)
	if crew_panel and crew_panel.has_signal("crew_updated"):
		crew_panel.crew_updated.connect(_on_crew_updated)
	if resource_panel and resource_panel.has_signal("resources_updated"):
		resource_panel.resources_updated.connect(_on_resources_updated)

func _show_step(step: int) -> void:
	"""Show a specific creation step"""
	if current_panel:
		current_panel.hide()
	
	# Update step label
	var step_names = [
		"Step 1: Campaign Configuration",
		"Step 2: Crew Creation",
		"Step 3: Captain Setup",
		"Step 4: Resources & Equipment",
		"Step 5: Final Review"
	]
	
	if step < step_names.size():
		step_label.text = step_names[step]
	
	# Show appropriate panel
	match step:
		0: # Campaign Config
			current_panel = config_panel
			back_button.hide()
			next_button.show()
			finish_button.hide()
		1: # Crew Creation
			current_panel = crew_panel
			back_button.show()
			next_button.show()
			finish_button.hide()
		2: # Captain Setup
			current_panel = captain_panel
			back_button.show()
			next_button.show()
			finish_button.hide()
		3: # Resource Setup
			current_panel = resource_panel
			back_button.show()
			next_button.show()
			finish_button.hide()
		4: # Finalization
			current_panel = final_panel
			back_button.show()
			next_button.hide()
			finish_button.show()
	
	if current_panel:
		current_panel.show()
	_update_navigation()

func _on_creation_step_changed(step: int) -> void:
	"""Handle creation step change from creation manager"""
	_show_step(step)

func _validate_current_step() -> bool:
	"""Validate the current step can be advanced"""
	match current_step:
		0: # Campaign Config
			return config_panel != null
		1: # Crew Creation
			return crew_panel != null
		2: # Captain Setup
			return captain_panel != null
		3: # Resource Setup
			return resource_panel != null
		4: # Final Review
			return final_panel != null
		_:
			return false

func _on_next_pressed() -> void:
	"""Handle next button press"""
	print("CampaignCreationUI: Next pressed, current step: ", current_step)
	
	# Validate current step before proceeding
	if not _validate_current_step():
		print("CampaignCreationUI: Current step validation failed")
		return
	
	# Advance to next step
	if current_step < max_steps - 1:
		current_step += 1
		_show_step(current_step)
		
		# Use creation manager if available
		if creation_manager and creation_manager.has_method("advance_step"):
			creation_manager.advance_step()

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("CampaignCreationUI: Back pressed, current step: ", current_step)
	
	# Go to previous step
	if current_step > 0:
		current_step -= 1
		_show_step(current_step)
		
		# Use creation manager if available
		if creation_manager and creation_manager.has_method("go_back_step"):
			creation_manager.go_back_step()

func _on_finish_pressed() -> void:
	"""Handle finish button press"""
	print("CampaignCreationUI: Finish pressed - creating campaign")
	
	# Finalize campaign creation
	var _campaign_data = _gather_campaign_data()
	
	if creation_manager and creation_manager.has_method("finalize_campaign_creation"):
		var campaign = creation_manager.finalize_campaign_creation()
		_start_campaign(campaign)
	else:
		# Fallback - transition to main game
		print("CampaignCreationUI: No creation manager, transitioning to main game")
		_transition_to_main_game()

func _gather_campaign_data() -> Dictionary:
	"""Gather all campaign data from panels"""
	return {
		"config": _get_config_data(),
		"crew": _get_crew_data(),
		"captain": _get_captain_data(),
		"resources": _get_resource_data()
	}

func _get_config_data() -> Dictionary:
	return {} # TODO: Get from config panel

func _get_crew_data() -> Array:
	return [] # TODO: Get from crew panel

func _get_captain_data() -> Dictionary:
	return {} # TODO: Get from captain panel

func _get_resource_data() -> Dictionary:
	return {} # TODO: Get from resource panel

func _start_campaign(campaign) -> void:
	"""Start the campaign with given data"""
	print("CampaignCreationUI: Starting campaign")
	# TODO: Connect to game state manager
	_transition_to_main_game()

func _transition_to_main_game() -> void:
	"""Transition to the main game scene"""
	print("CampaignCreationUI: Transitioning to main game")
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router.has_method("enter_main_game"):
		scene_router.enter_main_game()
	else:
		push_warning("SceneRouter not found or method unavailable")

func _update_navigation() -> void:
	"""Update navigation button states"""
	back_button.disabled = (current_step == 0)
	next_button.disabled = (current_step == max_steps - 1) or not _validate_current_step()
	finish_button.disabled = (current_step != max_steps - 1) or not _validate_current_step()

# Panel update handlers

func _on_config_updated(config: Dictionary) -> void:
	_update_navigation()

func _on_crew_updated(crew: Array) -> void:
	_update_navigation()

func _on_resources_updated(resources: Dictionary) -> void:
	_update_navigation()

func _on_campaign_creation_completed(campaign) -> void:
	"""Handle campaign creation completion"""
	print("CampaignCreationUI: Campaign creation completed")
	_start_campaign(campaign)