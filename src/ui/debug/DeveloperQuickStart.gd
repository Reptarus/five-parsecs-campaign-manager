@tool
extends Control
class_name DeveloperQuickStart

## Developer Quick Start Panel for Efficient Playtesting
## Provides instant access to test campaigns and scenarios

# Safe imports  
# const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd") # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd") # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd") # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

signal test_campaign_requested(campaign_data: Dictionary)
signal direct_phase_requested(phase_name: String)
signal test_scenario_requested(scenario_name: String)

# Campaign presets for quick testing
const CAMPAIGN_PRESETS = {
	"fresh_start": {
		"name": "Fresh Start",
		"description": "Turn 1, basic crew, starting resources",
		"turn_number": 1,
		"crew_size": 4,
		"credits": 1000,
		"supplies": 5,
		"phase": "world",
		"rivals": 0,
		"quests": 0,
		"equipment_level": "basic"
	},
	"developing": {
		"name": "Developing Campaign", 
		"description": "Turn 10, growing crew, some experience",
		"turn_number": 10,
		"crew_size": 5,
		"credits": 3000,
		"supplies": 12,
		"phase": "world",
		"rivals": 1,
		"quests": 1,
		"equipment_level": "improved"
	},
	"experienced": {
		"name": "Experienced Campaign",
		"description": "Turn 25, veteran crew, advanced equipment",
		"turn_number": 25,
		"crew_size": 6,
		"credits": 8000,
		"supplies": 20,
		"phase": "world",
		"rivals": 2,
		"quests": 2,
		"equipment_level": "advanced"
	},
	"endgame": {
		"name": "End Game Campaign",
		"description": "Turn 45, elite crew, approaching victory",
		"turn_number": 45,
		"crew_size": 6,
		"credits": 15000,
		"supplies": 35,
		"phase": "world", 
		"rivals": 3,
		"quests": 3,
		"equipment_level": "elite"
	}
}

# Test scenarios for specific situations
const TEST_SCENARIOS = {
	"rival_attack": {
		"name": "Rival Attack",
		"description": "Multiple rivals attacking, high tension",
		"setup": {"force_rival_attack": true, "rival_count": 2}
	},
	"resource_crisis": {
		"name": "Resource Crisis", 
		"description": "Low credits and supplies, upkeep pressure",
		"setup": {"credits": 100, "supplies": 1, "crew_size": 6}
	},
	"quest_chain": {
		"name": "Active Quest Chain",
		"description": "Multiple quests active, story progression",
		"setup": {"active_quests": 3, "quest_rumors": 5}
	},
	"equipment_showcase": {
		"name": "Equipment Showcase",
		"description": "All equipment types available for testing", 
		"setup": {"credits": 50000, "all_equipment": true}
	},
	"combat_ready": {
		"name": "Combat Ready",
		"description": "Pre-battle setup with various enemy types",
		"setup": {"phase": "battle", "enemy_variety": true}
	}
}

# Available phases for direct jumping
const PHASE_OPTIONS = {
	"travel": "Travel Phase",
	"world": "World Phase", 
	"battle": "Battle Phase",
	"post_battle": "Post-Battle Phase"
}

# Dependencies
var GameStateManager = null
var CampaignPhaseManager = null
var SceneRouter = null

# UI Components
@onready var preset_container: VBoxContainer = get_node("%PresetContainer")
@onready var phase_container: VBoxContainer = get_node("%PhaseContainer")
@onready var scenario_container: VBoxContainer = get_node("%ScenarioContainer")
@onready var save_state_container: VBoxContainer = get_node("%SaveStateContainer")
@onready var developer_info: Label = get_node("%DeveloperInfo")

func _ready() -> void:
	print("DeveloperQuickStart: Initializing developer panel...")

	# Only enable in debug builds
	if not OS.is_debug_build():
		visible = false
		return

	# Load dependencies
	_load_dependencies()

	# Setup UI
	_setup_preset_buttons()
	_setup_phase_buttons()
	_setup_scenario_buttons()
	_setup_save_state_buttons()
	_update_developer_info()

	print("DeveloperQuickStart: Ready for efficient playtesting!")

func _load_dependencies() -> void:
	"""Load required game systems"""
	GameStateManager = load("res://src/core/managers/GameStateManager.gd")
	CampaignPhaseManager = load("res://src/core/campaign/CampaignPhaseManager.gd")

	# Try to get SceneRouter
	SceneRouter = get_node_or_null("/root/SceneRouter")
	if not SceneRouter:
		print("DeveloperQuickStart: SceneRouter not available")

func _setup_preset_buttons() -> void:
	"""Create buttons for campaign presets"""
	if not preset_container:
		return

	for preset_key in CAMPAIGN_PRESETS:
		var preset = CAMPAIGN_PRESETS[preset_key]
		var button: Button = Button.new()
		button.text = preset.name
		button.tooltip_text = preset.description

		button.pressed.connect(_on_preset_selected.bind(preset_key))

		preset_container.add_child(button)

func _setup_phase_buttons() -> void:
	"""Create buttons for direct phase access"""
	if not phase_container:
		return

	for phase_key in PHASE_OPTIONS:
		var phase_name = PHASE_OPTIONS[phase_key]
		var button: Button = Button.new()
		button.text = "Jump to " + str(phase_name)
		button.pressed.connect(_on_phase_selected.bind(phase_key))

		phase_container.add_child(button)

func _setup_scenario_buttons() -> void:
	"""Create buttons for test scenarios"""
	if not scenario_container:
		return

	for scenario_key in TEST_SCENARIOS:
		var scenario = TEST_SCENARIOS[scenario_key]
		var button: Button = Button.new()
		button.text = scenario.name
		button.tooltip_text = scenario.description

		button.pressed.connect(_on_scenario_selected.bind(scenario_key))

		scenario_container.add_child(button)

func _setup_save_state_buttons() -> void:
	"""Create buttons for save state management"""
	if not save_state_container:
		return

	# Quick save button
	var quick_save_btn = Button.new()
	quick_save_btn.text = "Quick Save Test State"
	quick_save_btn.pressed.connect(_on_quick_save_pressed)
	save_state_container.add_child(quick_save_btn)

	# Quick load button
	var quick_load_btn = Button.new()
	quick_load_btn.text = "Quick Load Test State"
	quick_load_btn.pressed.connect(_on_quick_load_pressed)
	save_state_container.add_child(quick_load_btn)

	# Reset button  
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Clean State"
	reset_btn.pressed.connect(_on_reset_pressed)
	save_state_container.add_child(reset_btn)

func _update_developer_info() -> void:
	"""Update developer information display"""
	if not developer_info:
		return

	var info_text: String = "DEVELOPER MODE ACTIVE\n"
	info_text += "Build: " + ("Debug" if OS.is_debug_build() else "Release") + "\n"
	info_text += "Version: Five Parsecs Campaign Manager v1.0\n"
	info_text += "Quick Access Panel - Bypass main menu flow for efficient testing"

	developer_info.text = info_text

## Button Handlers

func _on_preset_selected(preset_key: String) -> void:
	"""Handle campaign preset selection"""
	print("DeveloperQuickStart: Creating test campaign - ", preset_key)

	var preset = CAMPAIGN_PRESETS[preset_key]
	var campaign_data = preset.duplicate()
	campaign_data["preset_name"] = preset_key

	# Create and configure test campaign
	_create_test_campaign(campaign_data)

func _on_phase_selected(phase_key: String) -> void:
	"""Handle direct phase navigation"""
	print("DeveloperQuickStart: Jumping to phase - ", phase_key)

	# Emit signal for phase change
	direct_phase_requested.emit(phase_key)

	# Try direct navigation if SceneRouter available
	if SceneRouter and SceneRouter.has_method("navigate_to_campaign_phase"):
		SceneRouter.navigate_to_campaign_phase(phase_key)

func _on_scenario_selected(scenario_key: String) -> void:
	"""Handle test scenario setup"""
	print("DeveloperQuickStart: Setting up scenario - ", scenario_key)

	var scenario = TEST_SCENARIOS[scenario_key]
	test_scenario_requested.emit(scenario_key)

	# Apply scenario setup
	_apply_scenario_setup(scenario.setup)

func _on_quick_save_pressed() -> void:
	"""Handle quick save of current test state"""
	print("DeveloperQuickStart: Quick saving test state...")

	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("save_current_state"):
		var success = gsm.save_current_state()
		if success:
			_show_notification("Test state saved successfully!")
		else:
			_show_notification("Failed to save test state.")
	else:
		_show_notification("Save system not available.")

func _on_quick_load_pressed() -> void:
	"""Handle quick load of test state"""
	print("DeveloperQuickStart: Quick loading test state...")

	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("load_saved_state"):
		var success = gsm.load_saved_state()
		if success:
			_show_notification("Test state loaded successfully!")
		else:
			_show_notification("Failed to load test state.")
	else:
		_show_notification("Load system not available.")

func _on_reset_pressed() -> void:
	"""Handle reset to clean state"""
	print("DeveloperQuickStart: Resetting to clean state...")

	# Reset to fresh campaign state
	_create_test_campaign(CAMPAIGN_PRESETS["fresh_start"])
	_show_notification("Reset to clean state completed!")

## Implementation Methods

func _create_test_campaign(campaign_data: Dictionary) -> void:
	"""Create a test campaign with specified parameters"""

	# Try to get or create GameStateManager
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		_show_notification("GameStateManager not available - cannot create test campaign")
		return

	# Initialize new campaign
	if gsm.has_method("start_new_campaign"):
		gsm.start_new_campaign(campaign_data)

	# Apply campaign parameters
	if gsm.has_method("set_credits"):
		gsm.set_credits(campaign_data.get("credits", 1000))

	if gsm.has_method("set_supplies"):
		gsm.set_supplies(campaign_data.get("supplies", 5))

	# Navigate to target phase or main game
	var target_phase = campaign_data.get("phase", "world")
	if SceneRouter:
		if target_phase == "world":
			SceneRouter.navigate_to("main_game")
		else:
			SceneRouter.navigate_to_campaign_phase(target_phase)

	# Emit signal for external handling
	test_campaign_requested.emit(campaign_data)

	_show_notification("Test campaign created: " + campaign_data.get("name", "Unknown"))

func _apply_scenario_setup(setup: Dictionary) -> void:
	"""Apply scenario-specific setup"""

	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		return

	# Apply credits if specified
	if setup.has("credits") and gsm.has_method("set_credits"):
		gsm.set_credits(setup.credits)

	# Apply supplies if specified
	if setup.has("supplies") and gsm.has_method("set_supplies"):
		gsm.set_supplies(setup.supplies)

	# Handle special scenario flags
	if setup.get("force_rival_attack", false):
		# This would need integration with rival system
		print("DeveloperQuickStart: Rival attack scenario setup requested")

	if setup.get("all_equipment", false):
		# This would need integration with equipment system
		print("DeveloperQuickStart: All equipment unlock requested")

func _show_notification(message: String) -> void:
	"""Show a notification message to the developer"""
	print("DeveloperQuickStart: " + message)

	# Create a simple notification popup
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

	# Auto-close after 2 seconds
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(dialog):
		dialog.queue_free()

## Public API for external integration

func get_available_presets() -> Array[String]:
	"""Get list of available campaign presets"""
	var presets: Array[String] = []
	for key in CAMPAIGN_PRESETS:
		presets.append(key)
	return presets

func get_available_scenarios() -> Array[String]:
	"""Get list of available test scenarios"""
	var scenarios: Array[String] = []
	for key in TEST_SCENARIOS:
		scenarios.append(key)
	return scenarios

func create_custom_test_campaign(custom_data: Dictionary) -> void:
	"""Create a test campaign with custom parameters"""
	_create_test_campaign(custom_data)

func is_developer_mode_active() -> bool:
	"""Check if developer mode is active"""
	return OS.is_debug_build() and visible
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