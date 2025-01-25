extends Control

const CampaignCreationManager = preload("res://src/core/campaign/CampaignCreationManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# UI Components
@onready var config_panel = $StepPanels/ConfigPanel
@onready var crew_panel = $StepPanels/CrewPanel
@onready var resource_panel = $StepPanels/ResourcePanel
@onready var final_panel = $StepPanels/FinalPanel

@onready var next_button = $Navigation/NextButton
@onready var back_button = $Navigation/BackButton
@onready var finish_button = $Navigation/FinishButton

var creation_manager: CampaignCreationManager
var current_panel: Control

func _ready() -> void:
	creation_manager = CampaignCreationManager.new()
	add_child(creation_manager)
	
	# Connect signals
	creation_manager.creation_step_changed.connect(_on_creation_step_changed)
	creation_manager.campaign_creation_completed.connect(_on_campaign_creation_completed)
	
	# Setup UI
	_setup_navigation()
	_setup_panels()
	
	# Start creation flow
	creation_manager.start_campaign_creation()

func _setup_navigation() -> void:
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	finish_button.pressed.connect(_on_finish_pressed)
	
	# Initial state
	back_button.hide()
	finish_button.hide()
	next_button.disabled = true

func _setup_panels() -> void:
	# Hide all panels initially
	for panel in $StepPanels.get_children():
		panel.hide()
	
	# Connect panel signals
	config_panel.config_updated.connect(_on_config_updated)
	crew_panel.crew_updated.connect(_on_crew_updated)
	resource_panel.resources_updated.connect(_on_resources_updated)

func _on_creation_step_changed(step: int) -> void:
	if current_panel:
		current_panel.hide()
	
	match step:
		CampaignCreationManager.CreationStep.CAMPAIGN_CONFIG:
			current_panel = config_panel
			back_button.hide()
			next_button.show()
			finish_button.hide()
		
		CampaignCreationManager.CreationStep.CREW_CREATION:
			current_panel = crew_panel
			back_button.show()
			next_button.show()
			finish_button.hide()
		
		CampaignCreationManager.CreationStep.RESOURCE_SETUP:
			current_panel = resource_panel
			back_button.show()
			next_button.show()
			finish_button.hide()
		
		CampaignCreationManager.CreationStep.FINALIZATION:
			current_panel = final_panel
			back_button.show()
			next_button.hide()
			finish_button.show()
	
	current_panel.show()
	_update_navigation()

func _update_navigation() -> void:
	next_button.disabled = not creation_manager.can_advance_to_next_step()
	finish_button.disabled = not creation_manager.can_advance_to_next_step()

func _on_next_pressed() -> void:
	match creation_manager.current_step:
		CampaignCreationManager.CreationStep.CAMPAIGN_CONFIG:
			creation_manager.submit_campaign_config(config_panel.get_config())
		
		CampaignCreationManager.CreationStep.CREW_CREATION:
			creation_manager.submit_crew_data(crew_panel.get_crew_data())
		
		CampaignCreationManager.CreationStep.RESOURCE_SETUP:
			creation_manager.initialize_resources(config_panel.get_config().difficulty)

func _on_back_pressed() -> void:
	# Implementation depends on how we want to handle going back
	# For now, we'll just restart the process
	creation_manager.start_campaign_creation()

func _on_finish_pressed() -> void:
	var campaign = creation_manager.finalize_campaign_creation()
	# Emit signal or call method to start the campaign
	get_tree().get_root().get_node("/root/GameManager").start_campaign(campaign)

# Panel update handlers
func _on_config_updated(config: Dictionary) -> void:
	_update_navigation()

func _on_crew_updated(crew: Array) -> void:
	_update_navigation()

func _on_resources_updated(resources: Dictionary) -> void:
	_update_navigation()

func _on_campaign_creation_completed(campaign) -> void:
	# Handle campaign creation completion
	# This might involve transitioning to the main campaign screen
	pass
