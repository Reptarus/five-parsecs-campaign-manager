@tool
extends Control
class_name DeveloperQuickStart

## Developer Quick Start Panel for Efficient Playtesting
## Provides instant access to test campaigns and scenarios

# Safe imports  
# Removed legacy Universal framework references to reduce architectural debt
# Modern Godot 4.4 provides sufficient built-in utilities for our use cases

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
	},
	"pre_battle": {
		"name": "Pre-Battle Ready",
		"description": "Turn 10, mission selected, ready for battle transition",
		"turn_number": 10,
		"crew_size": 4,
		"credits": 2000,
		"supplies": 10,
		"phase": "world",
		"rivals": 1,
		"quests": 1,
		"equipment_level": "improved",
		"mission_ready": true
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
@onready var setup_mode_button: Button = get_node("%SetupModeButton")
@onready var play_mode_button: Button = get_node("%PlayModeButton")
@onready var health_check_container: VBoxContainer = get_node("%HealthCheckContainer")
@onready var preset_container: VBoxContainer = get_node("%PresetContainer")
@onready var phase_container: VBoxContainer = get_node("%PhaseContainer")
@onready var scenario_container: VBoxContainer = get_node("%ScenarioContainer")
@onready var quick_actions_container: VBoxContainer = get_node("%QuickActionsContainer")
@onready var save_state_container: VBoxContainer = get_node("%SaveStateContainer")
@onready var developer_info: Label = get_node("%DeveloperInfo")

# Mode state
enum InterfaceMode { SETUP, PLAY }
var current_mode: InterfaceMode = InterfaceMode.SETUP

func _ready() -> void:
	print("DeveloperQuickStart: Initializing developer panel...")

	# Only enable in debug builds
	if not OS.is_debug_build():
		visible = false
		return

	# Load dependencies
	_load_dependencies()

	# Setup UI
	_setup_health_check()
	_setup_preset_buttons()
	_setup_phase_buttons()
	_setup_scenario_buttons()
	_setup_quick_actions()
	_setup_save_state_buttons()
	_update_developer_info()
	_apply_interface_mode()  # Apply initial Setup mode styling

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

	var mode_text := "Setup Mode (Dense)" if current_mode == InterfaceMode.SETUP else "Play Mode (Streamlined)"
	var info_text: String = "DEVELOPER MODE ACTIVE - " + mode_text + "\n"
	info_text += "Build: " + ("Debug" if OS.is_debug_build() else "Release") + "\n"
	info_text += "Version: Five Parsecs Campaign Manager v1.0\n"
	info_text += "Quick Access Panel - Bypass main menu flow for efficient testing"

	developer_info.text = info_text

func _setup_health_check() -> void:
	"""Setup health check status indicators"""
	if not health_check_container:
		return

	_perform_health_check()

func _setup_quick_actions() -> void:
	"""Setup contextual quick action buttons"""
	if not quick_actions_container:
		return

	# Roll Injury button
	var roll_injury_btn = Button.new()
	roll_injury_btn.text = "🩹 Roll Random Injury"
	roll_injury_btn.tooltip_text = "Test injury system with random D100 roll"
	roll_injury_btn.pressed.connect(_on_roll_injury_pressed)
	quick_actions_container.add_child(roll_injury_btn)

	# Advance Character button
	var advance_stat_btn = Button.new()
	advance_stat_btn.text = "⬆️ Advance Character Stats"
	advance_stat_btn.tooltip_text = "Test character advancement with auto-spending XP"
	advance_stat_btn.pressed.connect(_on_advance_stat_pressed)
	quick_actions_container.add_child(advance_stat_btn)

	# Validate Campaign button
	var validate_campaign_btn = Button.new()
	validate_campaign_btn.text = "✓ Validate Campaign State"
	validate_campaign_btn.tooltip_text = "Run full campaign state validation"
	validate_campaign_btn.pressed.connect(_on_validate_campaign_pressed)
	quick_actions_container.add_child(validate_campaign_btn)

	# Generate Mission button
	var generate_mission_btn = Button.new()
	generate_mission_btn.text = "🎯 Generate Test Mission"
	generate_mission_btn.tooltip_text = "Create random mission for testing"
	generate_mission_btn.pressed.connect(_on_generate_mission_pressed)
	quick_actions_container.add_child(generate_mission_btn)

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

	# Use create_test_campaign() instead of start_new_campaign() to properly generate crew
	if gsm.has_method("create_test_campaign"):
		print("DeveloperQuickStart: Creating test campaign with crew generation")
		gsm.create_test_campaign(campaign_data)
	else:
		push_error("DeveloperQuickStart: create_test_campaign() not available on GameStateManager")
		return

	# Check if this is a pre-battle ready campaign
	var mission_ready = campaign_data.get("mission_ready", false)

	if mission_ready:
		# Generate mission context for battle transition
		var mission_context = _generate_test_mission_context(campaign_data)

		# Store mission in game state
		if gsm.has_method("set_current_mission"):
			gsm.set_current_mission(mission_context)

		# Navigate directly to BattleTransition
		if SceneRouter and SceneRouter.has_method("navigate_to"):
			print("DeveloperQuickStart: Navigating to BattleTransition with pre-generated mission")
			SceneRouter.navigate_to("battle_transition", {"mission_context": mission_context})
		else:
			push_warning("DeveloperQuickStart: SceneRouter not available - navigating to dashboard instead")
			if SceneRouter and SceneRouter.has_method("navigate_to"):
				SceneRouter.navigate_to("campaign_dashboard")

		_show_notification("Pre-Battle campaign created - Mission: " + mission_context.get("mission_type", "OPPORTUNITY"))
	else:
		# Navigate to Campaign Dashboard to show generated crew and campaign state
		if SceneRouter and SceneRouter.has_method("navigate_to"):
			print("DeveloperQuickStart: Navigating to Campaign Dashboard to show generated campaign")
			SceneRouter.navigate_to("campaign_dashboard")
		else:
			push_warning("DeveloperQuickStart: SceneRouter not available for navigation")

		_show_notification("Test campaign created: " + campaign_data.get("name", "Unknown") + " - Check Campaign Dashboard")

	# Emit signal for external handling
	test_campaign_requested.emit(campaign_data)

func _generate_test_mission_context(campaign_data: Dictionary) -> Dictionary:
	"""Generate a test mission context for pre-battle testing"""
	var HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	var helper = HelperClass.new()

	var mock_battle = helper.create_mock_battle_phase_data()

	return {
		"mission_type": mock_battle.get("mission_type", "OPPORTUNITY"),
		"enemy_count": mock_battle.get("enemy_count", 5),
		"enemy_type": mock_battle.get("enemy_type", "RAIDERS"),
		"deployment_zones": ["north", "south"],
		"terrain_type": "urban",
		"objective": "eliminate_hostiles",
		"reward_credits": 100 + (randi() % 200),
		"difficulty": campaign_data.get("equipment_level", "basic"),
		"turn_number": campaign_data.get("turn_number", 1)
	}

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

	# Create a simple notification popup (only if in scene tree)
	if not is_inside_tree():
		return

	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

	# Auto-close after 2 seconds
	var tree = get_tree()
	if tree:
		await tree.create_timer(2.0).timeout
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

## Mode switching handlers

func _on_setup_mode_pressed() -> void:
	"""Switch to Setup Mode (dense information display)"""
	current_mode = InterfaceMode.SETUP
	play_mode_button.button_pressed = false
	_apply_interface_mode()
	_update_developer_info()
	_show_notification("Switched to Setup Mode - Dense information for planning")

func _on_play_mode_pressed() -> void:
	"""Switch to Play Mode (streamlined quick actions)"""
	current_mode = InterfaceMode.PLAY
	setup_mode_button.button_pressed = false
	_apply_interface_mode()
	_update_developer_info()
	_show_notification("Switched to Play Mode - Streamlined for physical gameplay")

func _apply_interface_mode() -> void:
	"""Apply visual styling based on current mode"""
	match current_mode:
		InterfaceMode.SETUP:
			# Setup mode: Show everything (dense)
			if preset_container: preset_container.visible = true
			if phase_container: phase_container.visible = true
			if scenario_container: scenario_container.visible = true
			if health_check_container: health_check_container.visible = true
			if quick_actions_container: quick_actions_container.visible = true
			if save_state_container: save_state_container.visible = true

		InterfaceMode.PLAY:
			# Play mode: Hide planning tools, show quick actions only
			if preset_container: preset_container.visible = false
			if phase_container: phase_container.visible = false
			if scenario_container: scenario_container.visible = false
			if health_check_container: health_check_container.visible = false
			if quick_actions_container: quick_actions_container.visible = true
			if save_state_container: save_state_container.visible = true

func _on_refresh_health_pressed() -> void:
	"""Refresh health check status"""
	_perform_health_check()
	_show_notification("Health check refreshed")

## Quick action handlers

func _on_roll_injury_pressed() -> void:
	"""Test injury system with random roll"""
	const InjurySystemService = preload("res://src/core/services/InjurySystemService.gd")

	var injury_result := InjurySystemService.roll_injury()

	var message := "Injury Roll: D100 = %d\n" % injury_result.roll
	message += "Result: %s\n" % injury_result.type_name
	message += "Description: %s\n" % injury_result.description

	if injury_result.recovery_turns > 0:
		message += "Recovery: %d turns" % injury_result.recovery_turns

	print("DeveloperQuickStart: " + message)
	_show_notification(message)

func _on_advance_stat_pressed() -> void:
	"""Test character advancement"""
	const CharacterAdvancementService = preload("res://src/core/services/CharacterAdvancementService.gd")

	# Create test character with 50 XP
	var test_character := {
		"name": "Test Character",
		"experience": 50,
		"reactions": 1,
		"combat_skill": 0,
		"speed": 4,
		"savvy": 0,
		"toughness": 3,
		"luck": 0
	}

	var result := CharacterAdvancementService.auto_advance_character(test_character, 3)

	var message := "Advanced %d stats:\n" % result.advancements_applied
	for advancement in result.advancements:
		message += "• %s: %d → %d\n" % [advancement.stat, advancement.old_value, advancement.new_value]
	message += "XP remaining: %d" % result.xp_remaining

	print("DeveloperQuickStart: " + message)
	_show_notification(message)

func _on_validate_campaign_pressed() -> void:
	"""Validate current campaign state"""
	const CampaignStateValidator = preload("res://src/core/services/CampaignStateValidator.gd")

	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		_show_notification("GameStateManager not available for validation")
		return

	# Build campaign data from game state
	var campaign_data := {
		"campaign_name": "Test Campaign",
		"current_turn": gsm.get("turn_number") if gsm.has_method("get") else 1,
		"current_phase": 0,
		"crew": [],
		"credits": gsm.get("credits") if gsm.has_method("get") else 1000
	}

	var validation_result := CampaignStateValidator.validate_campaign_state(campaign_data)

	var message := ""
	if validation_result.valid:
		message = "✓ Campaign state is VALID\n"
	else:
		message = "✗ Campaign state has ERRORS:\n"
		for error in validation_result.errors:
			message += "• " + error + "\n"

	if validation_result.warnings.size() > 0:
		message += "\nWarnings:\n"
		for warning in validation_result.warnings:
			message += "• " + warning + "\n"

	print("DeveloperQuickStart: " + message)
	_show_notification(message)

func _on_generate_mission_pressed() -> void:
	"""Generate random test mission"""
	var mission_types: Array[String] = ["Patrol", "Defense", "Opportunity", "Rival Attack"]
	var mission_type: String = mission_types[randi() % mission_types.size()]

	var message := "Generated Mission:\n"
	message += "Type: %s\n" % mission_type
	message += "Enemy Count: %d\n" % (randi() % 6 + 3)
	message += "Reward: %d credits" % (randi() % 500 + 100)

	print("DeveloperQuickStart: " + message)
	_show_notification(message)

## Health check implementation

func _perform_health_check() -> void:
	"""Perform system health check with traffic light indicators"""
	if not health_check_container:
		return

	# Clear existing status indicators
	for child in health_check_container.get_children():
		child.queue_free()

	# Check critical systems
	var systems_to_check := [
		{"name": "GameStateManager", "path": "/root/GameStateManager"},
		{"name": "DataManager", "path": "/root/DataManager"},
		{"name": "DiceManager", "path": "/root/DiceManager"},
		{"name": "CampaignManager", "path": "/root/CampaignManager"},
		{"name": "SceneRouter", "path": "/root/SceneRouter"}
	]

	for system in systems_to_check:
		var status_label = Label.new()
		var node_check = get_node_or_null(system.path)

		if node_check:
			status_label.text = "✅ " + system.name + " - ONLINE"
			status_label.modulate = Color(0.5, 1.0, 0.5)  # Green
		else:
			status_label.text = "❌ " + system.name + " - OFFLINE"
			status_label.modulate = Color(1.0, 0.5, 0.5)  # Red

		health_check_container.add_child(status_label)

	# Add service layer status
	var service_status = Label.new()
	service_status.text = "ℹ️ Service Layer: InjurySystemService, CharacterAdvancementService, CampaignStateValidator"
	service_status.modulate = Color(0.7, 0.7, 1.0)  # Blue
	health_check_container.add_child(service_status)

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
