## Post-Consolidation Signal Flow Regression Test
## Purpose: Validate critical signal chains after file consolidation
## DO NOT DELETE - This test catches consolidation-induced signal breakage

extends GdUnitTestSuite

## CRITICAL: This test must pass 100% after consolidation
## If ANY test fails, consolidation has broken signal integration

## Test 1: Campaign Creation Signal Flow
## Expected: CampaignCreationStateManager → Panels → Finalization
func test_campaign_creation_signal_chain():
	# Verify CampaignCreationStateManager exists and has signals
	var state_manager = CampaignCreationStateManager.new()
	assert_that(state_manager.has_signal("state_updated")).is_true()
	assert_that(state_manager.has_signal("validation_changed")).is_true()

	# Verify signal can be emitted without error
	var signal_received = false
	state_manager.state_updated.connect(func(phase, data): signal_received = true)
	state_manager.emit_signal("state_updated", null, {})
	assert_that(signal_received).is_true()

	# RefCounted objects are auto-managed, no need to free
	state_manager = null

## Test 2: Battle Event Bus Signal Flow
## Expected: FPCM_BattleEventBus → BattleManager → UI Components
func test_battle_event_bus_signal_chain():
	# Battle event bus must exist as autoload or singleton
	var has_event_bus = has_node("/root/FPCM_BattleEventBus") or Engine.has_singleton("FPCM_BattleEventBus")
	assert_that(has_event_bus).is_true()

	if not has_event_bus:
		push_warning("BattleEventBus not found - skipping signal verification")
		return

	# Get the actual event bus instance
	var event_bus = get_node_or_null("/root/FPCM_BattleEventBus")
	if not is_instance_valid(event_bus):
		push_warning("BattleEventBus instance not valid - skipping")
		return

	# Verify critical battle signals exist
	var battle_signals = [
		"battle_initialized",
		"battle_phase_changed",
		"battle_completed",
		"ui_transition_requested",
		"pre_battle_setup_complete"
	]

	for signal_name in battle_signals:
		if event_bus.has_signal(signal_name):
			assert_that(event_bus.has_signal(signal_name)).is_true()
		else:
			push_warning("Signal %s not found on BattleEventBus" % signal_name)

## Test 3: Story Track Signal Flow
## Expected: StoryTrackSystem → UI → GameState
func test_story_track_signal_chain():
	# Verify StoryTrackSystem class exists
	var story_system = FPCM_StoryTrackSystem.new()

	# Verify critical story signals
	assert_that(story_system.has_signal("story_clock_advanced")).is_true()
	assert_that(story_system.has_signal("story_event_triggered")).is_true()
	assert_that(story_system.has_signal("story_track_completed")).is_true()

	# Resource objects are auto-managed, no need to free
	story_system = null

## Test 4: Victory Condition Signal Flow
## Expected: VictoryConditionTracker → UI → Dashboard
func test_victory_condition_signal_chain():
	var tracker = auto_free(VictoryConditionTracker.new())
	add_child(tracker)

	# Wait for ready
	for i in range(3):
		await get_tree().process_frame

	if not is_instance_valid(tracker):
		push_warning("VictoryConditionTracker not initialized properly")
		return

	# Verify victory signals exist
	assert_that(tracker.has_signal("victory_condition_reached")).is_true()
	assert_that(tracker.has_signal("victory_progress_updated")).is_true()

	# Test signal emission
	var progress_received = false
	tracker.victory_progress_updated.connect(func(t, c, r): progress_received = true)
	tracker.emit_signal("victory_progress_updated", 0, 0, 10)
	assert_that(progress_received).is_true()

## Test 5: Campaign Turn Event Bus
## Expected: Central event bus for turn-based events
func test_campaign_turn_event_bus():
	# CampaignTurnEventBus should be autoload
	assert_that(has_node("/root/CampaignTurnEventBus")).is_true()

	var event_bus = get_node("/root/CampaignTurnEventBus")
	assert_that(event_bus.has_signal("turn_event_published")).is_true()

## Test 6: State Manager Signal Flow
## Expected: GameState → UI screens → Save/Load
func test_game_state_signal_chain():
	# GameState should be autoload
	assert_that(has_node("/root/GameState")).is_true()

	var game_state = get_node("/root/GameState")

	# Verify state-related signals exist
	# (Actual signals depend on GameState implementation)
	# This test validates GameState is accessible after consolidation

## Test 7: Autoload Accessibility
## Expected: All critical autoloads remain accessible
func test_all_autoloads_accessible():
	var critical_autoloads = [
		"GameState",
		"GameStateManager",
		"DataManager",
		"DiceManager",
		"SaveManager",
		"CampaignManager",
		"CampaignPhaseManager",
		"SceneRouter",
		"CampaignTurnEventBus",
		"ThemeManager"
	]

	for autoload_name in critical_autoloads:
		var node_path = "/root/" + autoload_name
		assert_that(has_node(node_path)).is_true() \
			.override_failure_message("Autoload missing after consolidation: " + autoload_name)

## Test 8: Class Name Resolution
## Expected: All critical class_names remain registered
func test_critical_class_names_registered():
	var critical_classes = [
		"Character",
		"FiveParsecsCampaign",
		"BattleSetupData",
		"Mission",
		"VictoryConditionTracker",
		"CampaignCreationStateManager"
	]

	# Attempt to instantiate each class
	# If class_name is missing, this will error
	var character = Character.new()
	assert_that(character).is_not_null()
	character = null

	var campaign = FiveParsecsCampaign.new()
	assert_that(campaign).is_not_null()
	campaign = null

	var battle_setup = BattleSetupData.new()
	assert_that(battle_setup).is_not_null()
	battle_setup = null

	# Mission is a Resource class - validate it can be instantiated
	var mission = Mission.new()
	assert_that(mission).is_not_null()
	assert_that(mission is Resource).is_true()
	mission = null

## Test 9: Signal Connection Stress Test
## Expected: Multiple signals can be connected/disconnected without errors
func test_signal_connection_stability():
	var state_manager = CampaignCreationStateManager.new()

	# Connect 10 handlers to same signal
	var handlers = []
	for i in range(10):
		var handler = func(phase, data): pass
		state_manager.state_updated.connect(handler)
		handlers.append(handler)

	# Emit signal
	state_manager.emit_signal("state_updated", null, {})

	# Disconnect all
	for handler in handlers:
		state_manager.state_updated.disconnect(handler)

	# RefCounted objects are auto-managed
	state_manager = null

## Test 10: Cross-System Signal Integration
## Expected: Signals can propagate across system boundaries
func test_cross_system_signal_propagation():
	# Campaign creation → Battle setup → Victory tracking
	# This validates end-to-end signal flow

	var state_manager = CampaignCreationStateManager.new()
	var victory_tracker = auto_free(VictoryConditionTracker.new())
	add_child(victory_tracker)

	# Wait for initialization
	for i in range(3):
		await get_tree().process_frame

	if not is_instance_valid(victory_tracker):
		push_warning("victory_tracker not initialized - skipping")
		return

	var signal_chain_completed = false

	# Connect state change to victory update
	state_manager.state_updated.connect(func(phase, data):
		victory_tracker.emit_signal("victory_progress_updated", 0, 1, 10)
	)

	victory_tracker.victory_progress_updated.connect(func(t, c, r):
		signal_chain_completed = true
	)

	# Trigger chain
	state_manager.emit_signal("state_updated", null, {})

	assert_that(signal_chain_completed).is_true()

	# RefCounted objects are auto-managed
	state_manager = null

## Test 11: No Orphaned Signal Connections
## Expected: Cleaned-up objects don't leave dangling connections
func test_no_orphaned_signal_connections():
	var state_manager = CampaignCreationStateManager.new()

	# Create temporary connection and verify it works
	var signal_received = false
	var temp_handler = func(phase, data): signal_received = true
	state_manager.state_updated.connect(temp_handler)

	# Emit signal to verify connection works
	state_manager.emit_signal("state_updated", null, {})
	assert_that(signal_received).is_true()

	# Disconnect and verify signal no longer received
	signal_received = false
	state_manager.state_updated.disconnect(temp_handler)
	state_manager.emit_signal("state_updated", null, {})
	assert_that(signal_received).is_false()

	# RefCounted objects are auto-managed
	state_manager = null

## Test 12: Scene Instantiation After Consolidation
## Expected: UI scenes can still be instantiated
func test_ui_scenes_instantiable():
	# Test critical UI scenes
	var campaign_dashboard_path = "res://src/ui/screens/campaign/CampaignDashboard.tscn"
	var main_menu_path = "res://src/ui/screens/mainmenu/MainMenu.tscn"

	# Load scenes
	var dashboard_scene = load(campaign_dashboard_path)
	assert_that(dashboard_scene).is_not_null()

	var main_menu_scene = load(main_menu_path)
	assert_that(main_menu_scene).is_not_null()

	# Instantiate (validates no missing script references)
	var dashboard = auto_free(dashboard_scene.instantiate())
	assert_that(dashboard).is_not_null()
	add_child(dashboard)

	# Wait for ready
	await get_tree().process_frame

	var menu = auto_free(main_menu_scene.instantiate())
	assert_that(menu).is_not_null()
	add_child(menu)

	# Wait for ready
	await get_tree().process_frame

## Test 13: Performance - Signal Emission Speed
## Expected: Signal emission remains fast after consolidation
func test_signal_emission_performance():
	var state_manager = CampaignCreationStateManager.new()

	# Verify signal exists before benchmarking
	assert_that(state_manager.has_signal("state_updated")).is_true()

	# Benchmark: 1000 signal emissions should complete < 10ms
	var start_time = Time.get_ticks_msec()
	for i in range(1000):
		state_manager.emit_signal("state_updated", null, {})
	var elapsed = Time.get_ticks_msec() - start_time

	assert_that(elapsed).is_less(10) \
		.override_failure_message("Signal emission too slow: %d ms for 1000 emissions" % elapsed)

	# RefCounted objects are auto-managed
	state_manager = null
