extends Control

const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalNodeValidator = preload("res://src/utils/UniversalNodeValidator.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

# Use the new core system setup
var core_systems: Node = null
var creation_manager: Node = null

# UI Components
@onready var config_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/ConfigPanel", "CampaignCreationUI")
@onready var crew_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/CrewPanel", "CampaignCreationUI")
@onready var captain_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/CaptainPanel", "CampaignCreationUI")
@onready var ship_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/ShipPanel", "CampaignCreationUI")
@onready var equipment_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/EquipmentPanel", "CampaignCreationUI")
@onready var resource_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/ResourcePanel", "CampaignCreationUI")
@onready var final_panel: Control = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/StepPanels/FinalPanel", "CampaignCreationUI")

@onready var step_label: Label = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/Header/StepLabel", "CampaignCreationUI")
@onready var next_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/Navigation/NextButton", "CampaignCreationUI")
@onready var back_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/Navigation/BackButton", "CampaignCreationUI")
@onready var finish_button: Button = UniversalNodeAccess.get_node_safe(self, "MarginContainer/VBoxContainer/Navigation/FinishButton", "CampaignCreationUI")

# State
var current_step: int = 0
var step_panels: Array[Control] = []

func _ready() -> void:
	print("CampaignCreationUI: Initializing...")
	
	# Define ALL nodes this component uses (matching actual scene structure)
	var required_nodes: Array[String] = [
		"MarginContainer/VBoxContainer/StepPanels/ConfigPanel",
		"MarginContainer/VBoxContainer/StepPanels/CrewPanel",
		"MarginContainer/VBoxContainer/StepPanels/CaptainPanel",
		"MarginContainer/VBoxContainer/StepPanels/ShipPanel",
		"MarginContainer/VBoxContainer/StepPanels/EquipmentPanel",
		"MarginContainer/VBoxContainer/StepPanels/ResourcePanel",
		"MarginContainer/VBoxContainer/StepPanels/FinalPanel",
		"MarginContainer/VBoxContainer/Header/StepLabel",
		"MarginContainer/VBoxContainer/Navigation/NextButton",
		"MarginContainer/VBoxContainer/Navigation/BackButton",
		"MarginContainer/VBoxContainer/Navigation/FinishButton"
	]
	
	# Define ALL signal connections this component needs
	var signal_connections = [
		{"node_path": "MarginContainer/VBoxContainer/Navigation/NextButton", "signal": "pressed", "method": "_on_next_button_pressed"},
		{"node_path": "MarginContainer/VBoxContainer/Navigation/BackButton", "signal": "pressed", "method": "_on_back_button_pressed"},
		{"node_path": "MarginContainer/VBoxContainer/Navigation/FinishButton", "signal": "pressed", "method": "_on_finish_button_pressed"}
	]
	
	# Universal setup
	var setup_result = UniversalNodeValidator.setup_ui_component(
		self,
		required_nodes,
		signal_connections,
		"CampaignCreationUI"
	)
	
	# Store validated references
	_store_node_references(setup_result.nodes)
	
	# Initialize only if setup succeeded
	if setup_result.success:
		_initialize_component()
	else:
		_setup_fallback_mode(setup_result.errors)

# Add this method to store node references
func _store_node_references(nodes: Dictionary) -> void:
	config_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/ConfigPanel")
	crew_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/CrewPanel")
	captain_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/CaptainPanel")
	ship_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/ShipPanel")
	equipment_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/EquipmentPanel")
	resource_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/ResourcePanel")
	final_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/FinalPanel")
	step_label = nodes.get("MarginContainer/VBoxContainer/Header/StepLabel")
	next_button = nodes.get("MarginContainer/VBoxContainer/Navigation/NextButton")
	back_button = nodes.get("MarginContainer/VBoxContainer/Navigation/BackButton")
	finish_button = nodes.get("MarginContainer/VBoxContainer/Navigation/FinishButton")

# Add this method for successful initialization
func _initialize_component() -> void:
	_setup_ui()
	_initialize_core_systems()

# Add this method for graceful degradation
func _setup_fallback_mode(errors: Array) -> void:
	print("CampaignCreationUI running in degraded mode: ", errors)
	# Show a simple error message
	if step_label:
		step_label.text = "Campaign Creation - Some features unavailable"
	# Initialize with whatever panels are available
	_setup_ui()

func _initialize_core_systems() -> void:
	"""Initialize core systems for campaign creation"""
	core_systems = UniversalNodeAccess.get_node_safe(self, "/root/CoreSystemSetup", "CampaignCreationUI")
	if core_systems:
		if core_systems.has_method("get_campaign_creation_manager"):
			creation_manager = core_systems.get_campaign_creation_manager()
			if creation_manager:
				print("CampaignCreationUI: CampaignCreationManager connected")
				_connect_creation_manager_signals()
			else:
				push_warning("CampaignCreationUI: CampaignCreationManager not available")
		else:
			push_warning("CampaignCreationUI: CoreSystemSetup doesn't have get_campaign_creation_manager method")
	else:
		push_error("CampaignCreationUI: CoreSystemSetup autoload not found")
		# Create fallback UI
		call_deferred("_create_fallback_ui")

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
	# Collect step panels safely
	step_panels = []
	var panel_list = [config_panel, crew_panel, captain_panel, ship_panel, equipment_panel, resource_panel, final_panel]
	for panel in panel_list:
		if panel:
			step_panels.append(panel)
	
	if step_panels.is_empty():
		push_error("CampaignCreationUI: No step panels found - cannot proceed")
		return
	
	# Connect button signals with proper validation
	_connect_button_signals()
	
	# Connect panel signals for data flow
	_connect_panel_signals()
	
	# Show first step
	_update_ui_for_step(0)

func _connect_button_signals() -> void:
	"""Connect button signals with proper validation"""
	# Button signal connections are handled by UniversalNodeValidator.setup_ui_component
	# This method is kept for compatibility but actual connections are done universally
	pass

func _connect_panel_signals() -> void:
	"""Connect to panel signals for data flow"""
	# Connect to config panel
	if config_panel and config_panel.has_signal("config_updated"):
		config_panel.config_updated.connect(_on_config_updated)
	
	# Connect to crew panel
	if crew_panel and crew_panel.has_signal("crew_updated"):
		crew_panel.crew_updated.connect(_on_crew_updated)
	
	# Connect to captain panel
	if captain_panel and captain_panel.has_signal("captain_updated"):
		captain_panel.captain_updated.connect(_on_captain_updated)
	
	# Connect to ship panel
	if ship_panel and ship_panel.has_signal("ship_updated"):
		ship_panel.ship_updated.connect(_on_ship_updated)
	
	# Connect to equipment panel
	if equipment_panel and equipment_panel.has_signal("equipment_generated"):
		equipment_panel.equipment_generated.connect(_on_equipment_generated)
	
	# Connect to resource panel if it has signals
	if resource_panel and resource_panel.has_signal("resources_updated"):
		resource_panel.resources_updated.connect(_on_resources_updated)

# Add signal handlers for panel data updates
func _on_config_updated(config: Dictionary) -> void:
	"""Handle config panel updates"""
	print("CampaignCreationUI: Config updated: ", config)
	# Validate and enable/disable next button based on config validity
	if config_panel and config_panel.has_method("is_valid"):
		if next_button:
			next_button.disabled = not config_panel.is_valid()

func _on_crew_updated(crew: Array) -> void:
	"""Handle crew panel updates"""
	print("CampaignCreationUI: Crew updated, size: ", crew.size())
	
	# Update equipment panel with crew size for proper generation
	if equipment_panel and equipment_panel.has_method("set_crew_size"):
		equipment_panel.set_crew_size(crew.size())
	
	# Update resource panel with crew data for bonus calculation
	if resource_panel and resource_panel.has_method("set_crew_data"):
		resource_panel.set_crew_data(crew)

func _on_captain_updated(captain) -> void:
	"""Handle captain panel updates"""
	print("CampaignCreationUI: Captain updated")
	# Captain is included in crew for resource calculations

func _on_ship_updated(ship_data: Dictionary) -> void:
	"""Handle ship panel updates"""
	print("CampaignCreationUI: Ship updated: ", ship_data.get("name", "Unknown"))
	# Ship data will be included in final campaign creation

func _on_equipment_generated(equipment: Array) -> void:
	"""Handle equipment generation updates"""
	print("CampaignCreationUI: Equipment generated, count: ", equipment.size())
	# Equipment will be included in final campaign creation

func _on_resources_updated(resources: Dictionary) -> void:
	"""Handle resource panel updates"""
	print("CampaignCreationUI: Resources updated: ", resources)

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
		var step_names = ["Configuration", "Crew Setup", "Captain Creation", "Ship Assignment", "Equipment Generation", "Resources", "Final Review"]
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
	# Validate current step before advancing
	var validation_errors = _validate_current_step()
	if not validation_errors.is_empty():
		_show_error_dialog("Validation Error", "Please fix the following issues:\n\n" + "\n".join(validation_errors))
		return
	
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

func _on_finish_button_pressed() -> void:
	"""Handle finish button press - explicitly start campaign creation"""
	print("CampaignCreationUI: Finish button pressed")
	_finalize_campaign_creation()

func _validate_current_step() -> Array[String]:
	"""Validate the current step and return array of error messages"""
	var errors: Array[String] = []
	
	if current_step >= step_panels.size():
		errors.append("Invalid step index")
		return errors
	
	var current_panel = step_panels[current_step]
	if not current_panel:
		errors.append("Current panel is missing")
		return errors
	
	# Call panel-specific validation if available
	if current_panel.has_method("validate"):
		var panel_errors = current_panel.validate()
		if panel_errors is Array:
			errors.append_array(panel_errors)
		elif panel_errors is String and not panel_errors.is_empty():
			errors.append(panel_errors)
	elif current_panel.has_method("is_valid"):
		if not current_panel.is_valid():
			var panel_name = current_panel.name if current_panel.name else "Unknown Panel"
			errors.append("%s is not properly configured" % panel_name)
	
	return errors

func _show_error_dialog(title: String, message: String) -> void:
	"""Show an error dialog to the user"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.dialog_autowrap = true
	add_child(dialog)
	dialog.popup_centered()
	
	# Auto-remove dialog after user closes it
	dialog.confirmed.connect(func(): dialog.queue_free())

func _finalize_campaign_creation() -> void:
	"""Finalize campaign creation with data from UI panels"""
	print("CampaignCreationUI: Finalizing campaign creation...")
	
	# Final validation before creating campaign
	var all_errors: Array[String] = []
	for step in range(step_panels.size()):
		current_step = step
		var step_errors = _validate_current_step()
		all_errors.append_array(step_errors)
	
	if not all_errors.is_empty():
		_show_error_dialog("Campaign Creation Failed", "Please fix all issues before creating the campaign:\n\n" + "\n".join(all_errors))
		return
	
	# Collect data from UI panels
	var campaign_config = _collect_campaign_config()
	
	if creation_manager and creation_manager.has_method("finalize_campaign_creation"):
		# Set the config data first
		creation_manager.set_config_data(campaign_config)
		
		# Set crew data if available
		if campaign_config.has("crew") and creation_manager.has_method("set_crew_data"):
			creation_manager.set_crew_data(campaign_config.crew)
		
		# Set captain data if available
		if campaign_config.has("captain") and creation_manager.has_method("set_captain_data"):
			if campaign_config.captain is Character:
				# Convert Character object to dictionary format
				var captain_dict = {
					"character_object": campaign_config.captain,
					"name": campaign_config.captain.character_name if campaign_config.captain.has("character_name") else "Captain"
				}
				creation_manager.set_captain_data(captain_dict)
			elif campaign_config.captain is Dictionary:
				creation_manager.set_captain_data(campaign_config.captain)
		
		# Set resource data if available
		if campaign_config.has("resources") and creation_manager.has_method("set_resource_data"):
			creation_manager.set_resource_data(campaign_config.resources)
		
		# Finalize and create the campaign
		var campaign = creation_manager.finalize_campaign_creation()
		if campaign:
			print("CampaignCreationUI: Campaign created successfully")
			_start_campaign(campaign)
		else:
			push_error("CampaignCreationUI: Failed to create campaign")
	else:
		# Fallback: just start a basic campaign
		print("CampaignCreationUI: Creating fallback campaign")
		_start_fallback_campaign(campaign_config)

func _collect_campaign_config() -> Dictionary:
	"""Collect campaign configuration from UI panels"""
	var config = {}
	
	# Get data from ConfigPanel
	if config_panel and config_panel.has_method("get_config_data"):
		config = config_panel.get_config_data()
	else:
		# Fallback: create basic config from visible UI
		config = {
			"name": "New Campaign",
			"difficulty": 1,
			"description": "A Five Parsecs from Home campaign"
		}
	
	# Collect data from other panels if they exist
	if crew_panel and crew_panel.has_method("get_crew_data"):
		config.crew = crew_panel.get_crew_data()
	
	if captain_panel and captain_panel.has_method("get_captain_data"):
		config.captain = captain_panel.get_captain_data()
	
	if ship_panel and ship_panel.has_method("get_ship_data"):
		config.ship = ship_panel.get_ship_data()
	
	if equipment_panel and equipment_panel.has_method("get_equipment"):
		config.equipment = equipment_panel.get_equipment()
	
	if resource_panel and resource_panel.has_method("get_resources"):
		config.resources = resource_panel.get_resources()
	
	# Ensure minimum required fields
	if not config.has("name") or config.name.is_empty():
		config.name = "New Campaign"
	if not config.has("difficulty"):
		config.difficulty = 1
	
	print("CampaignCreationUI: Collected complete config: ", config)
	return config

func _start_campaign(campaign) -> void:
	"""Start the created campaign"""
	print("CampaignCreationUI: Starting campaign...")
	
	# Try to start the campaign through core systems
	if core_systems and core_systems.has_method("start_new_campaign"):
		var config = {"campaign": campaign}
		if core_systems.start_new_campaign(config):
			print("CampaignCreationUI: Campaign started successfully")
			_navigate_to_main_game()
		else:
			push_error("CampaignCreationUI: Failed to start campaign")
	else:
		push_warning("CampaignCreationUI: Core systems not available, navigating to main game")
		_navigate_to_main_game()

func _start_fallback_campaign(config: Dictionary) -> void:
	"""Start a basic fallback campaign"""
	print("CampaignCreationUI: Starting fallback campaign with config: ", config)
	
	if core_systems and core_systems.has_method("start_new_campaign"):
		core_systems.start_new_campaign(config)
	
	_navigate_to_main_game()

func _navigate_to_main_game() -> void:
	"""Navigate to the main game scene"""
	print("CampaignCreationUI: Navigating to main game...")
	
	var scene_router = UniversalNodeAccess.get_node_safe(self, "/root/SceneRouter", "CampaignCreationUI")
	if scene_router and scene_router.has_method("navigate_to_main_game"):
		print("CampaignCreationUI: Using SceneRouter to navigate")
		scene_router.navigate_to_main_game()
	elif scene_router and scene_router.has_method("change_scene"):
		print("CampaignCreationUI: Using SceneRouter change_scene method")
		scene_router.change_scene("res://src/scenes/main/MainGameScene.tscn")
	else:
		# Fallback navigation
		print("CampaignCreationUI: Using fallback navigation to main game")
		get_tree().call_deferred("change_scene_to_file", "res://src/scenes/main/MainGameScene.tscn")

func _return_to_main_menu() -> void:
	"""Return to the main menu"""
	print("CampaignCreationUI: Returning to main menu...")
	
	var scene_router = UniversalNodeAccess.get_node_safe(self, "/root/SceneRouter", "CampaignCreationUI")
	if scene_router and scene_router.has_method("return_to_main_menu"):
		print("CampaignCreationUI: Using SceneRouter to return to main menu")
		scene_router.return_to_main_menu()
	elif scene_router and scene_router.has_method("change_scene"):
		print("CampaignCreationUI: Using SceneRouter change_scene for main menu")
		scene_router.change_scene("res://src/ui/screens/mainmenu/MainMenu.tscn")
	else:
		# Fallback navigation
		print("CampaignCreationUI: Using fallback navigation to main menu")
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
	_show_error_dialog("Campaign Creation Error", "Please fix the following issues:\n\n" + "\n".join(errors))
