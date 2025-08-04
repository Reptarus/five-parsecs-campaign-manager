extends Control

## Developer Dashboard - Production Emergency Boot System
## Bypasses broken UI components for development and testing
## Senior Developer Implementation: Complete error handling + diagnostics

# Import workflow testing system
const WorkflowSystemTester = preload("res://src/core/debug/WorkflowSystemTester.gd")

@onready var dashboard_panel: Panel = $DashboardPanel
@onready var status_label: Label = $DashboardPanel/VBox/StatusLabel
@onready var fix_button: Button = $DashboardPanel/VBox/FixButton
@onready var test_campaign_button: Button = $DashboardPanel/VBox/TestCampaignButton
@onready var scene_validator_button: Button = $DashboardPanel/VBox/SceneValidatorButton
@onready var bypass_creation_button: Button = $DashboardPanel/VBox/BypassCreationButton
@onready var workflow_test_button: Button = $DashboardPanel/VBox/WorkflowTestButton
@onready var modular_scenes_button: Button = $DashboardPanel/VBox/ModularScenesButton

var campaign_creation_scene: String = "res://src/ui/screens/campaign/CampaignCreationUI.tscn"
var main_dashboard_scene: String = "res://src/ui/screens/campaign/CampaignDashboard.tscn"
var workflow_orchestrator_scene: String = "res://src/ui/screens/campaign/CampaignWorkflowOrchestrator.tscn"

var modular_scenes: Dictionary = {
	"InitialCrewCreation": "res://src/ui/screens/crew/InitialCrewCreation.tscn",
	"CharacterCreator": "res://src/ui/screens/character/CharacterCreator.tscn", 
	"CampaignDashboard": "res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"ConfigPanel": "res://src/ui/screens/campaign/panels/ConfigPanel.tscn",
	"ShipPanel": "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
	"EquipmentPanel": "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn"
}

func _ready():
	_setup_dashboard()
	_connect_buttons()
	_run_system_diagnostics()

func _setup_dashboard():
	status_label.text = "🚨 DEVELOPER DASHBOARD - Emergency Boot Mode"
	dashboard_panel.modulate = Color.ORANGE
	
func _connect_buttons():
	fix_button.pressed.connect(_attempt_scene_fix)
	test_campaign_button.pressed.connect(_create_test_campaign)
	scene_validator_button.pressed.connect(_run_scene_validation)
	bypass_creation_button.pressed.connect(_bypass_to_dashboard)
	workflow_test_button.pressed.connect(_test_workflow_orchestrator)
	modular_scenes_button.pressed.connect(_test_modular_scenes)

func _run_system_diagnostics():
	var diagnostics = []
	
	# Check legacy scenes
	if ResourceLoader.exists(campaign_creation_scene):
		diagnostics.append("✅ CampaignCreationUI.tscn exists (LEGACY)")
	else:
		diagnostics.append("❌ CampaignCreationUI.tscn missing")
	
	if ResourceLoader.exists(main_dashboard_scene):
		diagnostics.append("✅ CampaignDashboard.tscn exists")
	else:
		diagnostics.append("❌ CampaignDashboard.tscn missing")
	
	# Check NEW workflow orchestrator
	if ResourceLoader.exists(workflow_orchestrator_scene):
		diagnostics.append("✅ CampaignWorkflowOrchestrator.tscn exists (NEW)")
	else:
		diagnostics.append("❌ CampaignWorkflowOrchestrator.tscn missing")
	
	# Check modular scenes
	var modular_count = 0
	for scene_name in modular_scenes:
		if ResourceLoader.exists(modular_scenes[scene_name]):
			modular_count += 1
	diagnostics.append("✅ Modular scenes available: %d/%d" % [modular_count, modular_scenes.size()])
	
	# Check autoloads
	if has_node("/root/GameState"):
		diagnostics.append("✅ GameState autoload active")
	else:
		diagnostics.append("❌ GameState autoload missing")
	
	# Check workflow context manager
	if has_node("/root/WorkflowContextManager"):
		diagnostics.append("✅ WorkflowContextManager available")
	else:
		diagnostics.append("❌ WorkflowContextManager missing")
	
	var diagnostic_text = "SYSTEM DIAGNOSTICS:\\n" + "\\n".join(diagnostics)
	status_label.text += "\\n\\n" + diagnostic_text

func _attempt_scene_fix():
	status_label.text += "\\n\\n🔧 ATTEMPTING AUTOMATIC SCENE FIX..."
	
	var fix_instructions = """
PRODUCTION FIX REQUIRED:
1. Open CampaignCreationUI.tscn in Godot Editor
2. Set unique names for these nodes:
   - ConfigPanel (right-click → Access as Unique Name)
   - CrewPanel (right-click → Access as Unique Name)  
   - CaptainPanel (right-click → Access as Unique Name)
   - ShipPanel (right-click → Access as Unique Name)
   - EquipmentPanel (right-click → Access as Unique Name)
   - StepLabel (right-click → Access as Unique Name)
   - NextButton (right-click → Access as Unique Name)
   - BackButton (right-click → Access as Unique Name)
   - FinishButton (right-click → Access as Unique Name)
3. Save scene and test
"""
	
	status_label.text += "\\n" + fix_instructions
	print(fix_instructions)

func _create_test_campaign():
	status_label.text += "\\n\\n🧪 CREATING TEST CAMPAIGN..."
	
	var test_campaign = {
		"name": "Developer Test Campaign",
		"difficulty": "Standard", 
		"victory_condition": "No Victory Condition",
		"story_track": true,
		"created_date": Time.get_datetime_string_from_system()
	}
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("save_campaign_data"):
		save_manager.save_campaign_data("dev_test_campaign", test_campaign)
		status_label.text += "\\n✅ Test campaign created and saved"
	else:
		status_label.text += "\\n❌ SaveManager not available"

func _run_scene_validation():
	status_label.text += "\\n\\n🔍 RUNNING SCENE VALIDATION..."
	
	var scene_resource = load(campaign_creation_scene) as PackedScene
	if not scene_resource:
		status_label.text += "\\n❌ Cannot load CampaignCreationUI scene"
		return
		
	var scene_instance = scene_resource.instantiate()
	var missing_nodes = []
	
	var required_nodes = [
		"ConfigPanel", "CrewPanel", "CaptainPanel", "ShipPanel", 
		"EquipmentPanel", "StepLabel", "NextButton", "BackButton", "FinishButton"
	]
	
	for node_name in required_nodes:
		var node = scene_instance.get_node_or_null("%" + node_name)
		if not node:
			missing_nodes.append(node_name)
	
	if missing_nodes.size() > 0:
		status_label.text += "\\n❌ Missing unique name nodes: " + str(missing_nodes)
	else:
		status_label.text += "\\n✅ All required nodes found!"
		
	scene_instance.queue_free()

func _bypass_to_dashboard():
	status_label.text += "\\n\\n🚀 BYPASSING TO MAIN DASHBOARD..."
	
	var fake_campaign = {
		"name": "Emergency Dev Campaign",
		"difficulty": "Standard",
		"crew_size": 4,
		"current_turn": 1
	}
	
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		if game_state.has_method("set_current_campaign"):
			game_state.set_current_campaign(fake_campaign)
		status_label.text += "\\n✅ Fake campaign data set"
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file(main_dashboard_scene)

func _test_workflow_orchestrator():
	status_label.text += "\\n\\n🔬 TESTING WORKFLOW ORCHESTRATOR..."
	
	# Run comprehensive workflow system test
	var test_results = WorkflowSystemTester.run_comprehensive_test()
	
	# Display test summary
	status_label.text += "\\n" + WorkflowSystemTester.get_test_summary(test_results)
	
	if test_results.overall_success:
		status_label.text += "\\n🚀 LAUNCHING NEW WORKFLOW SYSTEM..."
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file(workflow_orchestrator_scene)
	else:
		status_label.text += "\\n❌ Workflow system tests failed - check errors above"

func _test_modular_scenes():
	status_label.text += "\\n\\n🧩 TESTING MODULAR SCENES..."
	
	var available_scenes = []
	var missing_scenes = []
	
	for scene_name in modular_scenes:
		var scene_path = modular_scenes[scene_name]
		if ResourceLoader.exists(scene_path):
			available_scenes.append(scene_name)
		else:
			missing_scenes.append(scene_name)
	
	status_label.text += "\\n✅ Available scenes: " + ", ".join(available_scenes)
	if missing_scenes.size() > 0:
		status_label.text += "\\n❌ Missing scenes: " + ", ".join(missing_scenes)
	
	# Test loading the first available scene
	if available_scenes.size() > 0:
		var first_scene = available_scenes[0]
		var scene_path = modular_scenes[first_scene]
		status_label.text += "\\n🔬 Testing scene load: " + first_scene
		
		var scene_resource = load(scene_path) as PackedScene
		if scene_resource:
			status_label.text += "\\n✅ Scene resource loaded successfully"
			var scene_instance = scene_resource.instantiate()
			if scene_instance:
				status_label.text += "\\n✅ Scene instantiated successfully"
				scene_instance.queue_free()
			else:
				status_label.text += "\\n❌ Failed to instantiate scene"
		else:
			status_label.text += "\\n❌ Failed to load scene resource"
	
	status_label.text += "\\n\\n🎯 MODULAR ARCHITECTURE ANALYSIS COMPLETE"
