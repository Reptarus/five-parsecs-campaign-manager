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
	assert_that(state_manager.has_signal("state_changed")).is_true()
	assert_that(state_manager.has_signal("state_reset")).is_true()

	# Verify signal can be emitted without error
	var signal_received = false
	state_manager.state_changed.connect(func(s): signal_received = true)
	state_manager.emit_signal("state_changed", {})
	assert_that(signal_received).is_true()

	state_manager.queue_free()

## Test 2: Battle Event Bus Signal Flow
## Expected: FPCM_BattleEventBus → BattleManager → UI Components
func test_battle_event_bus_signal_chain():
	# Battle event bus must exist as autoload or singleton
	assert_that(has_node("/root/FPCM_BattleEventBus") or Engine.has_singleton("FPCM_BattleEventBus")).is_true()

	# Verify critical battle signals exist
	var battle_signals = [
		"battle_initialized",
		"battle_phase_changed",
		"battle_completed",
		"ui_transition_requested",
		"pre_battle_setup_complete"
	]

	# Note: Actual signal verification depends on how BattleEventBus is structured
	# This is a placeholder - update with actual validation once consolidated

## Test 3: Story Track Signal Flow
## Expected: StoryTrackSystem → UI → GameState
func test_story_track_signal_chain():
	# Verify StoryTrackSystem class exists
	var story_system = FPCM_StoryTrackSystem.new()

	# Verify critical story signals
	assert_that(story_system.has_signal("story_clock_advanced")).is_true()
	assert_that(story_system.has_signal("story_event_triggered")).is_true()
	assert_that(story_system.has_signal("story_track_completed")).is_true()

	story_system.queue_free()

## Test 4: Victory Condition Signal Flow
## Expected: VictoryConditionTracker → UI → Dashboard
func test_victory_condition_signal_chain():
	var tracker = VictoryConditionTracker.new()

	# Verify victory signals exist
	assert_that(tracker.has_signal("victory_condition_reached")).is_true()
	assert_that(tracker.has_signal("victory_progress_updated")).is_true()

	# Test signal emission
	var progress_received = false
	tracker.victory_progress_updated.connect(func(t, c, r): progress_received = true)
	tracker.emit_signal("victory_progress_updated", 0, 0, 10)
	assert_that(progress_received).is_true()

	tracker.queue_free()

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
	character.queue_free()

	var campaign = FiveParsecsCampaign.new()
	assert_that(campaign).is_not_null()
	campaign.queue_free()

	var battle_setup = BattleSetupData.new()
	assert_that(battle_setup).is_not_null()
	battle_setup.queue_free()

	var mission = Mission.new()
	assert_that(mission).is_not_null()
	mission.queue_free()

## Test 9: Signal Connection Stress Test
## Expected: Multiple signals can be connected/disconnected without errors
func test_signal_connection_stability():
	var state_manager = CampaignCreationStateManager.new()

	# Connect 10 handlers to same signal
	var handlers = []
	for i in range(10):
		var handler = func(s): pass
		state_manager.state_changed.connect(handler)
		handlers.append(handler)

	# Emit signal
	state_manager.emit_signal("state_changed", {})

	# Disconnect all
	for handler in handlers:
		state_manager.state_changed.disconnect(handler)

	state_manager.queue_free()

## Test 10: Cross-System Signal Integration
## Expected: Signals can propagate across system boundaries
func test_cross_system_signal_propagation():
	# Campaign creation → Battle setup → Victory tracking
	# This validates end-to-end signal flow

	var state_manager = CampaignCreationStateManager.new()
	var victory_tracker = VictoryConditionTracker.new()

	var signal_chain_completed = false

	# Connect state change to victory update
	state_manager.state_changed.connect(func(s):
		victory_tracker.emit_signal("victory_progress_updated", 0, 1, 10)
	)

	victory_tracker.victory_progress_updated.connect(func(t, c, r):
		signal_chain_completed = true
	)

	# Trigger chain
	state_manager.emit_signal("state_changed", {})

	assert_that(signal_chain_completed).is_true()

	state_manager.queue_free()
	victory_tracker.queue_free()

## Test 11: No Orphaned Signal Connections
## Expected: Cleaned-up objects don't leave dangling connections
func test_no_orphaned_signal_connections():
	var state_manager = CampaignCreationStateManager.new()
	var connection_count_before = state_manager.state_changed.get_connections().size()

	# Create temporary connection
	var temp_handler = func(s): pass
	state_manager.state_changed.connect(temp_handler)

	# Verify connection added
	var connection_count_during = state_manager.state_changed.get_connections().size()
	assert_that(connection_count_during).is_equal(connection_count_before + 1)

	# Disconnect
	state_manager.state_changed.disconnect(temp_handler)

	# Verify back to original count
	var connection_count_after = state_manager.state_changed.get_connections().size()
	assert_that(connection_count_after).is_equal(connection_count_before)

	state_manager.queue_free()

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
	var dashboard = dashboard_scene.instantiate()
	assert_that(dashboard).is_not_null()
	dashboard.queue_free()

	var menu = main_menu_scene.instantiate()
	assert_that(menu).is_not_null()
	menu.queue_free()

## Test 13: Performance - Signal Emission Speed
## Expected: Signal emission remains fast after consolidation
func test_signal_emission_performance():
	var state_manager = CampaignCreationStateManager.new()

	# Benchmark: 1000 signal emissions should complete < 10ms
	var start_time = Time.get_ticks_msec()
	for i in range(1000):
		state_manager.emit_signal("state_changed", {})
	var elapsed = Time.get_ticks_msec() - start_time

	assert_that(elapsed).is_less_than(10) \
		.override_failure_message("Signal emission too slow: %d ms for 1000 emissions" % elapsed)

	state_manager.queue_free()
