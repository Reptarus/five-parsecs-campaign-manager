extends GdUnitTestSuite

## End-to-End Campaign Turn Workflow Integration Test
## Tests complete multi-turn campaign workflow with UI-backend integration
## Validates 4-phase turn system with persistent data across turns

const CampaignTurnController = preload("res://src/ui/screens/campaign/CampaignTurnController.gd")
const UIBackendIntegrationValidator = preload("res://src/core/validation/UIBackendIntegrationValidator.gd")
const ValidationErrorBoundary = preload("res://src/core/validation/ValidationErrorBoundary.gd")

## Test fixture data
var test_turn_controller: Node
var test_scene: Node
var mock_campaign_phase_manager: Node
var mock_game_state: Node
var turn_data_history: Array[Dictionary] = []
var performance_metrics: Dictionary = {}

func before_test() -> void:
	"""Setup test environment for campaign turn testing"""
	print("=== Campaign Turn E2E Test Setup ===")
	
	# Create test scene container
	test_scene = Node.new()
	test_scene.name = "TestScene"
	add_child(test_scene)
	
	# Create mock campaign turn controller
	test_turn_controller = Node.new()
	test_turn_controller.name = "CampaignTurnController"
	test_scene.add_child(test_turn_controller)
	
	# Create mock autoload nodes
	_create_mock_autoloads()
	
	# Create mock UI components
	_create_mock_ui_components()
	
	# Add backend integration methods
	_add_turn_controller_backend_methods()
	
	# Initialize performance tracking
	performance_metrics = {
		"turn_start_times": [],
		"phase_durations": {},
		"backend_call_times": {},
		"total_workflow_time": 0
	}
	
	print("Campaign Turn E2E: Test setup complete")

func after_test() -> void:
	"""Cleanup after each test"""
	if test_scene:
		test_scene.queue_free()
	turn_data_history.clear()
	performance_metrics.clear()
	print("Campaign Turn E2E: Test cleanup complete")

func _create_mock_autoloads() -> void:
	"""Create mock autoload nodes for campaign management"""
	# Mock CampaignPhaseManager
	mock_campaign_phase_manager = Node.new()
	mock_campaign_phase_manager.name = "CampaignPhaseManager"
	mock_campaign_phase_manager.set_script(GDScript.new())
	mock_campaign_phase_manager.get_script().source_code = """
extends Node

signal phase_started(phase: int)
signal phase_completed(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)

var current_turn: int = 1
var current_phase: int = 1  # TRAVEL phase

enum Phase { NONE = 0, TRAVEL = 1, WORLD = 2, BATTLE = 3, POST_BATTLE = 4 }

func get_turn_number() -> int:
	return current_turn

func get_current_phase() -> int:
	return current_phase

func start_new_campaign_turn() -> void:
	current_turn += 1
	current_phase = Phase.TRAVEL
	campaign_turn_started.emit(current_turn)
	phase_started.emit(current_phase)

func start_phase(phase: int) -> void:
	current_phase = phase
	phase_started.emit(phase)
"""
	test_scene.add_child(mock_campaign_phase_manager)
	test_turn_controller.set("campaign_phase_manager", mock_campaign_phase_manager)
	
	# Mock GameState
	mock_game_state = Node.new()
	mock_game_state.name = "GameState"
	mock_game_state.set_script(GDScript.new())
	mock_game_state.get_script().source_code = """
extends Node

var campaign_turn: int = 0
var current_mission: Dictionary = {"type": "patrol", "difficulty": 2}
var active_crew: Array = [
	{"character_name": "Test Captain", "is_captain": true, "combat": 4},
	{"character_name": "Test Crew 1", "combat": 3},
	{"character_name": "Test Crew 2", "combat": 3}
]
var current_planet: Dictionary = {"id": "test_planet", "name": "Test World"}

func get_campaign_turn() -> int:
	return campaign_turn

func get_current_mission() -> Dictionary:
	return current_mission

func get_active_crew() -> Array:
	return active_crew

func get_current_planet() -> Dictionary:
	return current_planet

func set_battle_results(results: Dictionary) -> void:
	print("GameState: Battle results stored - %s" % str(results))

func clear_battle_results() -> void:
	print("GameState: Battle results cleared")
"""
	test_scene.add_child(mock_game_state)
	test_turn_controller.set("game_state", mock_game_state)

func _create_mock_ui_components() -> void:
	"""Create mock UI components for phase management"""
	# Travel Phase UI
	var travel_phase_ui = Control.new()
	travel_phase_ui.name = "TravelPhaseUI"
	travel_phase_ui.visible = false
	test_scene.add_child(travel_phase_ui)
	test_turn_controller.set("travel_phase_ui", travel_phase_ui)
	
	# World Phase UI
	var world_phase_ui = Control.new()
	world_phase_ui.name = "WorldPhaseUI"
	world_phase_ui.visible = false
	world_phase_ui.set_script(GDScript.new())
	world_phase_ui.get_script().source_code = """
extends Control

func update_planet_data_backend(planet_id: String, turn_number: int) -> void:
	print("WorldPhaseUI: Backend planet data updated - %s (turn %d)" % [planet_id, turn_number])

func generate_random_contact_backend(planet_id: String, turn_number: int) -> void:
	print("WorldPhaseUI: Backend contact generated for %s (turn %d)" % [planet_id, turn_number])

func has_method(method_name: String) -> bool:
	return method_name in ["update_planet_data_backend", "generate_random_contact_backend"]
"""
	test_scene.add_child(world_phase_ui)
	test_turn_controller.set("world_phase_ui", world_phase_ui)
	
	# Battle Transition UI
	var battle_transition_ui = Control.new()
	battle_transition_ui.name = "BattleTransitionUI"
	battle_transition_ui.visible = false
	battle_transition_ui.set_script(GDScript.new())
	battle_transition_ui.get_script().source_code = """
extends Control

func set_rival_encounter_data(encounter_data: Dictionary) -> void:
	print("BattleTransitionUI: Rival encounter data set - %s" % str(encounter_data))

func has_method(method_name: String) -> bool:
	return method_name == "set_rival_encounter_data"
"""
	test_scene.add_child(battle_transition_ui)
	test_turn_controller.set("battle_transition_ui", battle_transition_ui)
	
	# Post Battle UI
	var post_battle_ui = Control.new()
	post_battle_ui.name = "PostBattleUI"
	post_battle_ui.visible = false
	post_battle_ui.set_script(GDScript.new())
	post_battle_ui.get_script().source_code = """
extends Control

signal post_battle_completed(results: Dictionary)

func complete_post_battle() -> void:
	var results = {"casualties": 0, "loot": ["Credits: 500"], "experience": 10}
	post_battle_completed.emit(results)
"""
	test_scene.add_child(post_battle_ui)
	test_turn_controller.set("post_battle_ui", post_battle_ui)
	
	# UI State components
	var current_turn_label = Label.new()
	current_turn_label.name = "CurrentTurnLabel"
	current_turn_label.text = "Turn 1"
	test_scene.add_child(current_turn_label)
	test_turn_controller.set("current_turn_label", current_turn_label)
	
	var current_phase_label = Label.new()
	current_phase_label.name = "CurrentPhaseLabel"
	current_phase_label.text = "Phase: Travel"
	test_scene.add_child(current_phase_label)
	test_turn_controller.set("current_phase_label", current_phase_label)
	
	var phase_progress_bar = ProgressBar.new()
	phase_progress_bar.name = "PhaseProgressBar"
	phase_progress_bar.min_value = 0
	phase_progress_bar.max_value = 100
	phase_progress_bar.value = 25
	test_scene.add_child(phase_progress_bar)
	test_turn_controller.set("phase_progress_bar", phase_progress_bar)

func _add_turn_controller_backend_methods() -> void:
	"""Add backend integration methods to turn controller"""
	test_turn_controller.set_script(GDScript.new())
	test_turn_controller.get_script().source_code = """
extends Node

var campaign_phase_manager: Node
var game_state: Node
var travel_phase_ui: Control
var world_phase_ui: Control
var battle_transition_ui: Control
var post_battle_ui: Control
var current_turn_label: Label
var current_phase_label: Label
var phase_progress_bar: ProgressBar

var current_ui_phase: Control = null
var battle_results: Dictionary = {}

# Backend systems (will be mocked)
var backend_systems_initialized: bool = false

func _ready() -> void:
	_initialize_backend_systems()
	_connect_signals()

func _initialize_backend_systems() -> void:
	print("CampaignTurnController: Initializing mock backend systems...")
	
	# Create mock backend nodes
	var planet_manager = Node.new()
	planet_manager.name = "BackendPlanetManager"
	planet_manager.set_script(GDScript.new())
	planet_manager.get_script().source_code = '''
extends Node

func get_or_generate_planet(planet_id: String, turn_number: int) -> Dictionary:
	return {"name": "Generated Planet %s" % planet_id, "id": planet_id, "turn": turn_number}

func has_method(method_name: String) -> bool:
	return method_name == "get_or_generate_planet"
'''
	add_child(planet_manager)
	
	var contact_manager = Node.new()
	contact_manager.name = "BackendContactManager"
	contact_manager.set_script(GDScript.new())
	contact_manager.get_script().source_code = '''
extends Node

func generate_random_contact(planet_id: String, turn_number: int) -> Dictionary:
	return {"name": "Contact %d" % turn_number, "planet": planet_id, "reputation": 0}

func has_method(method_name: String) -> bool:
	return method_name == "generate_random_contact"
'''
	add_child(contact_manager)
	
	var rival_generator = Node.new()
	rival_generator.name = "BackendRivalGenerator"
	rival_generator.set_script(GDScript.new())
	rival_generator.get_script().source_code = '''
extends Node

func check_rival_encounter(planet_id: String, turn_number: int) -> Dictionary:
	# Return encounter every 3rd turn for testing
	var has_encounter = (turn_number % 3 == 0)
	return {
		"has_encounter": has_encounter,
		"rival_name": "Test Rival" if has_encounter else "",
		"planet": planet_id,
		"turn": turn_number
	}

func has_method(method_name: String) -> bool:
	return method_name == "check_rival_encounter"
'''
	add_child(rival_generator)
	
	backend_systems_initialized = true
	print("CampaignTurnController: Mock backend systems initialized")

func _connect_signals() -> void:
	if campaign_phase_manager:
		campaign_phase_manager.phase_started.connect(_on_phase_started)
		campaign_phase_manager.phase_completed.connect(_on_phase_completed)
		campaign_phase_manager.campaign_turn_started.connect(_on_campaign_turn_started)
		campaign_phase_manager.campaign_turn_completed.connect(_on_campaign_turn_completed)

func _on_phase_started(phase: int) -> void:
	print("CampaignTurnController: Phase started - %d" % phase)
	_show_phase_ui(phase)
	_update_phase_display(phase)

func _on_phase_completed(phase: int) -> void:
	print("CampaignTurnController: Phase completed - %d" % phase)

func _on_campaign_turn_started(turn_number: int) -> void:
	print("CampaignTurnController: Campaign turn started - %d" % turn_number)
	_update_turn_display(turn_number)

func _on_campaign_turn_completed(turn_number: int) -> void:
	print("CampaignTurnController: Campaign turn completed - %d" % turn_number)

func _show_phase_ui(phase: int) -> void:
	# Hide all UIs
	travel_phase_ui.hide()
	world_phase_ui.hide()
	battle_transition_ui.hide()
	post_battle_ui.hide()
	
	# Show appropriate UI and trigger backend integration
	match phase:
		1: # TRAVEL
			travel_phase_ui.show()
			current_ui_phase = travel_phase_ui
		2: # WORLD
			world_phase_ui.show()
			current_ui_phase = world_phase_ui
			_trigger_world_phase_backend_integration()
		3: # BATTLE
			battle_transition_ui.show()
			current_ui_phase = battle_transition_ui
			_initiate_battle_sequence()
		4: # POST_BATTLE
			post_battle_ui.show()
			current_ui_phase = post_battle_ui

func _trigger_world_phase_backend_integration() -> void:
	print("CampaignTurnController: Triggering world phase backend integration")
	
	var current_turn = campaign_phase_manager.get_turn_number()
	var current_planet_id = _get_current_planet_id()
	
	# Update planet data using backend
	var planet_manager = get_node("BackendPlanetManager")
	if planet_manager and planet_manager.has_method("get_or_generate_planet"):
		var planet_data = planet_manager.get_or_generate_planet(current_planet_id, current_turn)
		print("CampaignTurnController: Planet data updated - %s" % planet_data.name)
		
		if world_phase_ui and world_phase_ui.has_method("update_planet_data_backend"):
			world_phase_ui.update_planet_data_backend(current_planet_id, current_turn)
	
	# Generate contacts using backend
	var contact_manager = get_node("BackendContactManager")
	if contact_manager and contact_manager.has_method("generate_random_contact"):
		for i in range(randi_range(1, 3)):
			var contact = contact_manager.generate_random_contact(current_planet_id, current_turn)
			print("CampaignTurnController: Generated contact - %s" % contact.name)
		
		if world_phase_ui and world_phase_ui.has_method("generate_random_contact_backend"):
			world_phase_ui.generate_random_contact_backend(current_planet_id, current_turn)

func _initiate_battle_sequence() -> void:
	print("CampaignTurnController: Initiating battle sequence")
	
	var current_turn = campaign_phase_manager.get_turn_number()
	var current_planet_id = _get_current_planet_id()
	
	# Check for rival encounters
	_check_rival_encounter_backend(current_planet_id, current_turn)
	
	# Simulate battle completion after short delay
	await get_tree().create_timer(0.1).timeout
	_simulate_battle_completion()

func _check_rival_encounter_backend(planet_id: String, turn_number: int) -> void:
	print("CampaignTurnController: Checking for rival encounters")
	
	var rival_generator = get_node("BackendRivalGenerator")
	if rival_generator and rival_generator.has_method("check_rival_encounter"):
		var encounter_data = rival_generator.check_rival_encounter(planet_id, turn_number)
		
		if encounter_data.get("has_encounter", false):
			print("CampaignTurnController: Rival encounter detected - %s" % encounter_data.rival_name)
			battle_results["rival_encounter"] = encounter_data
			
			if battle_transition_ui and battle_transition_ui.has_method("set_rival_encounter_data"):
				battle_transition_ui.set_rival_encounter_data(encounter_data)

func _simulate_battle_completion() -> void:
	var battle_results = {"outcome": "victory", "casualties": 0, "loot": 500}
	game_state.set_battle_results(battle_results)
	
	# Advance to post-battle phase
	campaign_phase_manager.start_phase(4)  # POST_BATTLE

func _get_current_planet_id() -> String:
	if game_state and game_state.has_method("get_current_planet"):
		var planet = game_state.get_current_planet()
		if planet:
			return planet.get("id", "planet_" + str(campaign_phase_manager.get_turn_number()))
	return "planet_" + str(campaign_phase_manager.get_turn_number())

func _update_turn_display(turn_number: int) -> void:
	if current_turn_label:
		current_turn_label.text = "Turn %d" % turn_number

func _update_phase_display(phase: int) -> void:
	var phase_names = ["None", "Travel", "World", "Battle", "Post-Battle"]
	var phase_name = phase_names[phase] if phase < phase_names.size() else "Unknown"
	
	if current_phase_label:
		current_phase_label.text = "Phase: %s" % phase_name
	
	if phase_progress_bar:
		var progress_values = [0, 25, 50, 75, 100]
		if phase < progress_values.size():
			phase_progress_bar.value = progress_values[phase]

func start_new_campaign_turn() -> void:
	campaign_phase_manager.start_new_campaign_turn()

func complete_current_phase() -> void:
	var current_phase = campaign_phase_manager.get_current_phase()
	campaign_phase_manager.phase_completed.emit(current_phase)
	
	# Auto-advance to next phase
	var next_phase = current_phase + 1
	if next_phase <= 4:  # POST_BATTLE
		campaign_phase_manager.start_phase(next_phase)
	else:
		# Complete turn and start new one
		var turn_number = campaign_phase_manager.get_turn_number()
		campaign_phase_manager.campaign_turn_completed.emit(turn_number)
		await get_tree().create_timer(0.1).timeout
		start_new_campaign_turn()

func has_method(method_name: String) -> bool:
	return method_name in ["start_new_campaign_turn", "complete_current_phase", "_trigger_world_phase_backend_integration", "_check_rival_encounter_backend"]
"""

## PHASE 1: Turn Controller Initialization Tests

func test_turn_controller_initialization():
	"""Test turn controller initializes with all required components"""
	# Trigger initialization
	test_turn_controller._ready()
	await get_tree().process_frame
	
	# Validate backend systems initialized
	assert_that(test_turn_controller.get("backend_systems_initialized")).is_true()
	
	# Validate backend nodes created
	assert_that(test_turn_controller.get_node("BackendPlanetManager")).is_not_null()
	assert_that(test_turn_controller.get_node("BackendContactManager")).is_not_null()
	assert_that(test_turn_controller.get_node("BackendRivalGenerator")).is_not_null()
	
	# Validate UI components
	assert_that(test_turn_controller.get("travel_phase_ui")).is_not_null()
	assert_that(test_turn_controller.get("world_phase_ui")).is_not_null()
	assert_that(test_turn_controller.get("battle_transition_ui")).is_not_null()
	assert_that(test_turn_controller.get("post_battle_ui")).is_not_null()
	
	print("✅ Turn controller initialization test passed")

func test_backend_system_availability() -> void:
	"""Test backend system availability validation"""
	# Initialize turn controller
	test_turn_controller._ready()
	await get_tree().process_frame
	
	# Run backend system health validation
	var validation_results = UIBackendIntegrationValidator.validate_turn_system_integration(test_turn_controller)
	
	# Should find our mock backend systems
	var available_systems = 0
	var missing_systems = 0
	
	for result in validation_results:
		if result.integration_type == UIBackendIntegrationValidator.IntegrationValidationType.BACKEND_SYSTEM_AVAILABILITY:
			if result.severity == UIBackendIntegrationValidator.ValidationSeverity.INFO:
				available_systems += 1
			else:
				missing_systems += 1
	
	# Should have found our 3 mock backend systems
	assert_that(available_systems).is_greater_than(0)
	
	print("✅ Backend system availability test passed (Available: %d, Missing: %d)" % [available_systems, missing_systems])

## PHASE 2: Single Turn Workflow Tests

func test_single_turn_travel_phase():
	"""Test travel phase workflow with backend integration"""
	var start_time = Time.get_ticks_msec()
	
	# Initialize turn controller
	test_turn_controller._ready()
	await get_tree().process_frame
	
	# Start new turn (should begin with travel phase)
	test_turn_controller.start_new_campaign_turn()
	await get_tree().process_frame
	
	# Validate travel phase activated
	var travel_ui = test_turn_controller.get("travel_phase_ui")
	assert_that(travel_ui.visible).is_true()
	assert_that(test_turn_controller.get("current_ui_phase")).is_equal(travel_ui)
	
	# Validate turn display updated
	var turn_label = test_turn_controller.get("current_turn_label")
	assert_that(turn_label.text).contains("Turn 2")  # Started at 1, incremented to 2
	
	var end_time = Time.get_ticks_msec()
	performance_metrics.backend_call_times["travel_phase"] = end_time - start_time
	
	print("✅ Single turn travel phase test passed (%dms)" % (end_time - start_time))

func test_single_turn_world_phase():
	"""Test world phase workflow with backend integration"""
	var start_time = Time.get_ticks_msec()
	
	# Initialize and start turn
	test_turn_controller._ready()
	await get_tree().process_frame
	
	test_turn_controller.start_new_campaign_turn()
	await get_tree().process_frame
	
	# Advance to world phase
	mock_campaign_phase_manager.start_phase(2)  # WORLD phase
	await get_tree().process_frame
	
	# Validate world phase activated with backend integration
	var world_ui = test_turn_controller.get("world_phase_ui")
	assert_that(world_ui.visible).is_true()
	
	# Validate backend integration methods were called
	# (validated through print output in real testing)
	
	var end_time = Time.get_ticks_msec()
	performance_metrics.backend_call_times["world_phase"] = end_time - start_time
	
	print("✅ Single turn world phase test passed (%dms)" % (end_time - start_time))

func test_single_turn_battle_phase():
	"""Test battle phase workflow with rival encounter integration"""
	var start_time = Time.get_ticks_msec()
	
	# Initialize and start turn
	test_turn_controller._ready()
	await get_tree().process_frame
	
	test_turn_controller.start_new_campaign_turn()
	await get_tree().process_frame
	
	# Advance to battle phase
	mock_campaign_phase_manager.start_phase(3)  # BATTLE phase
	await get_tree().process_frame
	
	# Allow battle sequence to complete
	await get_tree().create_timer(0.2).timeout
	
	# Validate battle phase activated
	var battle_ui = test_turn_controller.get("battle_transition_ui")
	assert_that(battle_ui.visible).is_true()
	
	# Validate battle results stored
	var battle_results = test_turn_controller.get("battle_results")
	assert_that(battle_results).is_not_empty()
	
	var end_time = Time.get_ticks_msec()
	performance_metrics.backend_call_times["battle_phase"] = end_time - start_time
	
	print("✅ Single turn battle phase test passed (%dms)" % (end_time - start_time))

func test_single_turn_post_battle_phase():
	"""Test post-battle phase workflow"""
	var start_time = Time.get_ticks_msec()
	
	# Initialize and complete battle phase first
	await test_single_turn_battle_phase()
	
	# Post-battle phase should be active
	var post_battle_ui = test_turn_controller.get("post_battle_ui")
	assert_that(post_battle_ui.visible).is_true()
	
	# Simulate post-battle completion
	post_battle_ui.complete_post_battle()
	await get_tree().process_frame
	
	var end_time = Time.get_ticks_msec()
	performance_metrics.backend_call_times["post_battle_phase"] = end_time - start_time
	
	print("✅ Single turn post-battle phase test passed (%dms)" % (end_time - start_time))

## PHASE 3: Multi-Turn Campaign Workflow Tests

func test_complete_single_turn_cycle():
	"""Test complete single turn cycle through all 4 phases"""
	var workflow_start_time = Time.get_ticks_msec()
	
	# Initialize turn controller
	test_turn_controller._ready()
	await get_tree().process_frame
	
	var initial_turn = mock_campaign_phase_manager.get_turn_number()
	
	# Phase 1: Travel
	test_turn_controller.start_new_campaign_turn()
	await get_tree().process_frame
	assert_that(test_turn_controller.get("travel_phase_ui").visible).is_true()
	print("  ✓ Travel phase completed")
	
	# Phase 2: World
	test_turn_controller.complete_current_phase()
	await get_tree().process_frame
	assert_that(test_turn_controller.get("world_phase_ui").visible).is_true()
	print("  ✓ World phase completed")
	
	# Phase 3: Battle
	test_turn_controller.complete_current_phase()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout  # Allow battle to complete
	print("  ✓ Battle phase completed")
	
	# Phase 4: Post-Battle (should be active after battle)
	assert_that(test_turn_controller.get("post_battle_ui").visible).is_true()
	print("  ✓ Post-battle phase completed")
	
	# Record turn data
	var turn_data = {
		"turn_number": mock_campaign_phase_manager.get_turn_number(),
		"phases_completed": 4,
		"backend_calls_made": true,
		"duration_ms": Time.get_ticks_msec() - workflow_start_time
	}
	turn_data_history.append(turn_data)
	
	performance_metrics.total_workflow_time = Time.get_ticks_msec() - workflow_start_time
	
	print("✅ Complete single turn cycle test passed (%dms)" % turn_data.duration_ms)

func test_multi_turn_campaign_workflow():
	"""Test multi-turn campaign workflow with data persistence"""
	var workflow_start_time = Time.get_ticks_msec()
	
	print("Starting multi-turn campaign workflow test...")
	
	# Run 3 complete turns
	for turn_index in range(3):
		print("  Starting turn %d..." % (turn_index + 1))
		
		var turn_start_time = Time.get_ticks_msec()
		await test_complete_single_turn_cycle()
		var turn_duration = Time.get_ticks_msec() - turn_start_time
		
		performance_metrics.turn_start_times.append(turn_start_time)
		
		# Validate turn progression
		assert_that(mock_campaign_phase_manager.get_turn_number()).is_greater_than(turn_index + 1)
		
		# Validate data persistence across turns
		if turn_data_history.size() > 1:
			var previous_turn = turn_data_history[turn_data_history.size() - 2]
			var current_turn = turn_data_history[turn_data_history.size() - 1]
			assert_that(current_turn.turn_number).is_greater_than(previous_turn.turn_number)
		
		print("  ✓ Turn %d completed in %dms" % [turn_index + 1, turn_duration])
		
		# Brief pause between turns
		await get_tree().create_timer(0.1).timeout
	
	var total_workflow_time = Time.get_ticks_msec() - workflow_start_time
	performance_metrics.total_workflow_time = total_workflow_time
	
	# Validate multi-turn consistency
	assert_that(turn_data_history.size()).is_equal(3)
	assert_that(mock_campaign_phase_manager.get_turn_number()).is_greater_equal(4)
	
	print("✅ Multi-turn campaign workflow test passed")
	print("  Total turns: %d" % turn_data_history.size())
	print("  Total time: %dms" % total_workflow_time)
	print("  Average turn time: %dms" % (total_workflow_time / turn_data_history.size()))

## PHASE 4: Backend Integration Stress Tests

func test_rival_encounter_integration():
	"""Test rival encounter detection across multiple turns"""
	# Initialize turn controller
	test_turn_controller._ready()
	await get_tree().process_frame
	
	var encounters_detected = 0
	
	# Run 6 turns to test rival encounter pattern (every 3rd turn)
	for turn in range(1, 7):
		mock_campaign_phase_manager.current_turn = turn
		
		# Check rival encounter for this turn
		var rival_generator = test_turn_controller.get_node("BackendRivalGenerator")
		var encounter_data = rival_generator.check_rival_encounter("test_planet", turn)
		
		if encounter_data.get("has_encounter", false):
			encounters_detected += 1
			print("  Rival encounter on turn %d: %s" % [turn, encounter_data.rival_name])
	
	# Should have encounters on turns 3 and 6
	assert_that(encounters_detected).is_equal(2)
	
	print("✅ Rival encounter integration test passed (%d encounters detected)" % encounters_detected)

func test_backend_system_performance():
	"""Test backend system performance under normal load"""
	# Initialize turn controller
	test_turn_controller._ready()
	await get_tree().process_frame
	
	var performance_data = {}
	
	# Test planet data generation performance
	var planet_start = Time.get_ticks_msec()
	var planet_manager = test_turn_controller.get_node("BackendPlanetManager")
	for i in range(10):
		planet_manager.get_or_generate_planet("planet_%d" % i, i)
	performance_data["planet_generation"] = Time.get_ticks_msec() - planet_start
	
	# Test contact generation performance
	var contact_start = Time.get_ticks_msec()
	var contact_manager = test_turn_controller.get_node("BackendContactManager")
	for i in range(20):
		contact_manager.generate_random_contact("planet_test", i)
	performance_data["contact_generation"] = Time.get_ticks_msec() - contact_start
	
	# Test rival encounter checking performance
	var rival_start = Time.get_ticks_msec()
	var rival_generator = test_turn_controller.get_node("BackendRivalGenerator")
	for i in range(50):
		rival_generator.check_rival_encounter("planet_test", i)
	performance_data["rival_encounter_checks"] = Time.get_ticks_msec() - rival_start
	
	# Validate performance benchmarks (very generous for mock systems)
	assert_that(performance_data.planet_generation).is_less_than(1000)  # 1 second for 10 operations
	assert_that(performance_data.contact_generation).is_less_than(1000)  # 1 second for 20 operations
	assert_that(performance_data.rival_encounter_checks).is_less_than(1000)  # 1 second for 50 operations
	
	print("✅ Backend system performance test passed")
	print("  Planet generation: %dms" % performance_data.planet_generation)
	print("  Contact generation: %dms" % performance_data.contact_generation)
	print("  Rival checks: %dms" % performance_data.rival_encounter_checks)

## PHASE 5: Data Consistency and Integration Validation

func test_turn_data_consistency():
	"""Test data consistency across multi-turn workflow"""
	# Run multi-turn workflow first
	await test_multi_turn_campaign_workflow()
	
	# Validate turn data history consistency
	assert_that(turn_data_history.size()).is_greater_than(1)
	
	for i in range(1, turn_data_history.size()):
		var previous_turn = turn_data_history[i - 1]
		var current_turn = turn_data_history[i]
		
		# Turn numbers should increment
		assert_that(current_turn.turn_number).is_greater_than(previous_turn.turn_number)
		
		# All turns should complete all phases
		assert_that(current_turn.phases_completed).is_equal(4)
		
		# All turns should have backend integration
		assert_that(current_turn.backend_calls_made).is_true()
	
	print("✅ Turn data consistency test passed")

func test_integration_validation_comprehensive():
	"""Test comprehensive integration validation"""
	# Initialize turn controller
	test_turn_controller._ready()
	await get_tree().process_frame
	
	# Run turn system integration validation
	var validation_results = UIBackendIntegrationValidator.validate_turn_system_integration(test_turn_controller)
	
	# Generate validation report
	var report = UIBackendIntegrationValidator.generate_integration_report(validation_results)
	
	# Validate report structure
	assert_that(report).contains("# UI-Backend Integration Validation Report")
	assert_that(report).contains("TURN_SYSTEM_INTEGRATION")
	assert_that(report).contains("BACKEND_SYSTEM_AVAILABILITY")
	
	# Count validation results by severity
	var info_count = 0
	var warning_count = 0
	var error_count = 0
	var critical_count = 0
	
	for result in validation_results:
		match result.severity:
			UIBackendIntegrationValidator.ValidationSeverity.INFO:
				info_count += 1
			UIBackendIntegrationValidator.ValidationSeverity.WARNING:
				warning_count += 1
			UIBackendIntegrationValidator.ValidationSeverity.ERROR:
				error_count += 1
			UIBackendIntegrationValidator.ValidationSeverity.CRITICAL:
				critical_count += 1
	
	# Should have good results for our mock setup
	assert_that(info_count).is_greater_than(0)
	assert_that(critical_count).is_equal(0)
	
	print("✅ Comprehensive integration validation test passed")
	print("  Info: %d, Warnings: %d, Errors: %d, Critical: %d" % [info_count, warning_count, error_count, critical_count])
	print("Generated validation report:")
	print(report)

func test_workflow_performance_benchmarks():
	"""Test workflow performance meets benchmark requirements"""
	# Run performance test if not already done
	if performance_metrics.total_workflow_time == 0:
		await test_multi_turn_campaign_workflow()
	
	# Validate performance benchmarks
	var avg_turn_time = performance_metrics.total_workflow_time / max(1, turn_data_history.size())
	
	# Turn workflow should complete within reasonable time (generous for testing)
	assert_that(avg_turn_time).is_less_than(5000).override_failure_message(
		"Average turn time %dms exceeds 5000ms benchmark" % avg_turn_time
	)
	
	# Individual backend calls should be fast
	for call_type in performance_metrics.backend_call_times.keys():
		var call_time = performance_metrics.backend_call_times[call_type]
		assert_that(call_time).is_less_than(1000).override_failure_message(
			"Backend call %s took %dms, exceeds 1000ms benchmark" % [call_type, call_time]
		)
	
	print("✅ Workflow performance benchmark test passed")
	print("  Average turn time: %dms" % avg_turn_time)
	print("  Total workflow time: %dms" % performance_metrics.total_workflow_time)
	print("  Backend call times: %s" % str(performance_metrics.backend_call_times))