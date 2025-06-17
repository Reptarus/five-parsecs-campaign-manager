extends GdUnitTestSuite

# Test BattleEventsSystem using Universal Mock Strategy patterns
class_name Test_BattleEventsSystem

# Type-safe script references
const BattleEventsSystem: GDScript = preload("res://src/core/battle/BattleEventsSystem.gd")

var battle_events_system: Resource
var mock_game_state: Resource

func before_test():
	# Create fresh system for each test - proven pattern
	battle_events_system = BattleEventsSystem.new()
	mock_game_state = Resource.new()

func after_test():
	# Cleanup happens automatically with track_resource()
	pass

# Test system initialization
func test_battle_events_initialization():
	# Then battle events should be initialized with expected values
	assert_that(battle_events_system.is_system_active).is_false()
	assert_that(battle_events_system.current_round).is_equal(0)
	assert_that(battle_events_system.events_triggered).is_empty()
	assert_that(battle_events_system.active_hazards).is_empty()
	assert_that(battle_events_system.battle_in_progress).is_false()

# Test battle initialization
func test_battle_initialization():
	# When initializing battle
	battle_events_system.initialize_battle()
	
	# Then system should be active and ready
	assert_that(battle_events_system.is_system_active).is_true()
	assert_that(battle_events_system.battle_in_progress).is_true()
	assert_that(battle_events_system.current_round).is_equal(0)
	assert_that(battle_events_system.events_triggered).is_empty()

# Test round advancement
func test_round_advancement():
	# Given initialized battle
	battle_events_system.initialize_battle()
	monitor_signals(battle_events_system)
	
	# When advancing round
	battle_events_system.advance_round()
	
	# Then round should advance and signal emitted
	assert_that(battle_events_system.current_round).is_equal(1)
	assert_signal(battle_events_system).is_emitted("round_event_check", [1])

# Test event triggering on round 2
func test_event_triggering_round_2():
	# Given battle in round 1
	battle_events_system.initialize_battle()
	battle_events_system.advance_round() # Round 1
	monitor_signals(battle_events_system)
	
	# When advancing to round 2
	battle_events_system.advance_round() # Round 2
	
	# Then event should be triggered (Core Rules: end of round 2)
	assert_that(battle_events_system.current_round).is_equal(2)
	assert_signal(battle_events_system).is_emitted("battle_event_triggered")

# Test event triggering on round 4
func test_event_triggering_round_4():
	# Given battle advanced to round 3
	battle_events_system.initialize_battle()
	for i in range(3):
		battle_events_system.advance_round()
	monitor_signals(battle_events_system)
	
	# When advancing to round 4
	battle_events_system.advance_round() # Round 4
	
	# Then event should be triggered (Core Rules: end of round 4)
	assert_that(battle_events_system.current_round).is_equal(4)
	assert_signal(battle_events_system).is_emitted("battle_event_triggered")

# Test no events on other rounds
func test_no_events_other_rounds():
	# Given battle system
	battle_events_system.initialize_battle()
	monitor_signals(battle_events_system)
	
	# When advancing to round 1, 3, 5
	for round_num in [1, 3, 5]:
		battle_events_system.advance_round()
		
		# Then no battle events should trigger (only rounds 2 and 4)
		if round_num != 2 and round_num != 4:
			assert_signal(battle_events_system).is_not_emitted("battle_event_triggered")

# Test event registry initialization
func test_event_registry_initialization():
	# Then event registry should contain Core Rules events
	var registry = battle_events_system.event_registry
	assert_that(registry).is_not_empty()
	assert_that(registry.has("RENEWED_EFFORTS")).is_true()
	assert_that(registry.has("ENEMY_REINFORCEMENTS")).is_true()
	assert_that(registry.has("SEIZED_MOMENT")).is_true()
	assert_that(registry.has("ENVIRONMENTAL_HAZARD")).is_true()

# Test specific event creation
func test_battle_event_creation():
	# Given event registry
	var registry = battle_events_system.event_registry
	var event = registry["RENEWED_EFFORTS"]
	
	# Then event should have proper structure
	assert_that(event).is_not_null()
	assert_that(event.event_id).is_equal("RENEWED_EFFORTS")
	assert_that(event.title).is_equal("Renewed Efforts")
	assert_that(event.roll_range).is_equal([1, 5])
	assert_that(event.target_type).is_equal("enemy")

# Test event roll matching
func test_event_roll_matching():
	# When getting event for roll within range
	var event = battle_events_system._get_event_for_roll(3) # Should match RENEWED_EFFORTS [1,5]
	
	# Then correct event should be returned
	assert_that(event).is_not_null()
	assert_that(event.event_id).is_equal("RENEWED_EFFORTS")

# Test environmental hazard creation
func test_environmental_hazard_creation():
	# Given environmental event
	var env_event = battle_events_system.event_registry["ENVIRONMENTAL_HAZARD"]
	monitor_signals(battle_events_system)
	
	# When applying environmental event
	battle_events_system._apply_environmental_event(env_event)
	
	# Then hazard should be created and signal emitted
	assert_that(battle_events_system.active_hazards).is_not_empty()
	assert_signal(battle_events_system).is_emitted("environmental_hazard_activated")

# Test environmental damage checking
func test_environmental_damage_checking():
	# Given active environmental hazard
	var hazard = BattleEventsSystem.EnvironmentalHazard.new()
	hazard.hazard_id = "TEST_HAZARD"
	hazard.save_difficulty = 5
	hazard.damage_bonus = 1
	hazard.affects_radius = 2
	battle_events_system.active_hazards.append(hazard)
	
	# When checking damage for character in range
	var damage_results = battle_events_system.check_environmental_damage(Vector2(1, 1), 3)
	
	# Then damage results should be calculated
	assert_that(damage_results).is_not_empty()
	assert_that(damage_results.has("TEST_HAZARD")).is_true()

# Test crew event effects
func test_crew_event_effects():
	# Given crew event
	var crew_event = battle_events_system.event_registry["SEIZED_MOMENT"]
	
	# When applying crew event
	battle_events_system._apply_crew_event(crew_event)
	
	# Then crew effects should be applied
	assert_that(crew_event.effects.has("selected_crew")).is_true()
	assert_that(crew_event.effects.has("bonus_actions")).is_true()

# Test enemy event effects
func test_enemy_event_effects():
	# Given enemy event
	var enemy_event = battle_events_system.event_registry["ENEMY_REINFORCEMENTS"]
	
	# When applying enemy event
	battle_events_system._apply_enemy_event(enemy_event)
	
	# Then enemy effects should be applied
	assert_that(enemy_event.effects.has("spawn_enemies")).is_true()
	assert_that(enemy_event.effects.has("specialist_count")).is_true()

# Test battlefield event effects
func test_battlefield_event_effects():
	# Given battlefield event
	var battlefield_event = battle_events_system.event_registry["FOG_CLOUD"]
	
	# When applying battlefield event
	battle_events_system._apply_battlefield_event(battlefield_event)
	
	# Then battlefield effects should be applied
	assert_that(battlefield_event.effects.has("fog_radius")).is_true()
	assert_that(battlefield_event.effects.has("fog_vision")).is_true()

# Test event conflict detection
func test_event_conflict_detection():
	# Given event with conflicts
	var event1 = BattleEventsSystem.BattleEvent.new()
	event1.event_id = "EVENT_1"
	var conflicts: Array[String] = ["EVENT_2"]
	event1.conflicts_with = conflicts
	
	var event2 = BattleEventsSystem.BattleEvent.new()
	event2.event_id = "EVENT_2"
	
	battle_events_system.events_triggered.append(event1)
	
	# When checking conflicts
	var conflict = battle_events_system._check_event_conflicts(event2)
	
	# Then conflict should be detected
	assert_that(conflict).is_not_null()
	assert_that(conflict.event_id).is_equal("EVENT_1")

# Test battle ending
func test_battle_ending():
	# Given active battle with events
	battle_events_system.initialize_battle()
	var test_event = BattleEventsSystem.BattleEvent.new()
	test_event.is_persistent = false
	battle_events_system.events_triggered.append(test_event)
	
	# When ending battle
	battle_events_system.end_battle()
	
	# Then system should cleanup and stop
	assert_that(battle_events_system.battle_in_progress).is_false()

# Test event duration processing
func test_event_duration_processing():
	# Given event with duration
	var timed_event = BattleEventsSystem.BattleEvent.new()
	timed_event.event_id = "TIMED_EVENT"
	timed_event.duration = 2
	battle_events_system.events_triggered.append(timed_event)
	monitor_signals(battle_events_system)
	
	# When processing events twice
	battle_events_system._process_active_events()
	battle_events_system._process_active_events()
	
	# Then event should be completed and removed
	assert_that(battle_events_system.events_triggered).is_empty()
	assert_signal(battle_events_system).is_emitted("event_resolved", ["TIMED_EVENT", {"completed": true}])

# Test system status checking
func test_system_status_checking():
	# Given inactive system
	assert_that(battle_events_system.is_active()).is_false()
	
	# When initializing battle
	battle_events_system.initialize_battle()
	
	# Then system should be active
	assert_that(battle_events_system.is_active()).is_true()
	assert_that(battle_events_system.get_current_round()).is_equal(0)

# Test serialization
func test_serialization():
	# Given system with state
	battle_events_system.initialize_battle()
	battle_events_system.advance_round()
	
	# When serializing
	var serialized = battle_events_system.serialize()
	
	# Then data should be preserved
	assert_that(serialized).is_not_empty()
	assert_that(serialized.has("is_system_active")).is_true()
	assert_that(serialized.has("current_round")).is_true()
	assert_that(serialized.has("battle_in_progress")).is_true()

# Test deserialization
func test_deserialization():
	# Given serialized data
	var test_data = {
		"is_system_active": true,
		"current_round": 3,
		"battle_in_progress": true,
		"events_triggered": [],
		"active_hazards": []
	}
	
	# When deserializing
	battle_events_system.deserialize(test_data)
	
	# Then state should be restored
	assert_that(battle_events_system.is_system_active).is_true()
	assert_that(battle_events_system.current_round).is_equal(3)
	assert_that(battle_events_system.battle_in_progress).is_true()

# Test signal emission patterns
func test_signal_emission_patterns():
	# Given battle system
	battle_events_system.initialize_battle()
	monitor_signals(battle_events_system)
	
	# When advancing to event round
	battle_events_system.advance_round() # Round 1
	battle_events_system.advance_round() # Round 2 - triggers event
	
	# Then proper signals should be emitted
	assert_signal(battle_events_system).is_emitted("round_event_check", [1])
	assert_signal(battle_events_system).is_emitted("round_event_check", [2])
	assert_signal(battle_events_system).is_emitted("battle_event_triggered")

# Test error handling
func test_error_handling():
	# Given inactive system
	assert_that(battle_events_system.is_system_active).is_false()
	
	# When trying to advance round
	battle_events_system.advance_round()
	
	# Then round should not advance
	assert_that(battle_events_system.current_round).is_equal(0)
	
	# When trying to trigger event
	battle_events_system.trigger_battle_event()
	
	# Then no events should be triggered
	assert_that(battle_events_system.events_triggered).is_empty()