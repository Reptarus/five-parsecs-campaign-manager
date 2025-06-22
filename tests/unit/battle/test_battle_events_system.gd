@warning_ignore("return_value_discarded")
	extends GdUnitTestSuite

# Test BattleEventsSystem using Universal Mock Strategy patterns
class_name Test_BattleEventsSystem

# Type-safe script references
const BattleEventsSystem: GDScript = preload("res://src/core/battle/BattleEventsSystem.gd")

var battle_events_system: Resource
var mock_game_state: Resource

func before_test() -> void:
	# Create fresh system for each test - proven pattern
	battle_events_system = BattleEventsSystem.new()
	mock_game_state = Resource.new()

func after_test() -> void:
	# Cleanup happens automatically with @warning_ignore("return_value_discarded")
	track_resource()
	pass

# Test system initialization
@warning_ignore("unsafe_method_access")
func test_battle_events_initialization() -> void:
	# Then battle events should be initialized with expected values
	assert_that(battle_events_system.is_system_active).is_false()
	assert_that(battle_events_system.current_round).is_equal(0)
	assert_that(battle_events_system.events_triggered).is_empty()
	assert_that(battle_events_system.active_hazards).is_empty()
	assert_that(battle_events_system.battle_in_progress).is_false()

# Test battle initialization
@warning_ignore("unsafe_method_access")
func test_battle_initialization() -> void:
	# When initializing battle
	battle_events_system.initialize_battle()
	
	# Then system should be active and ready
	assert_that(battle_events_system.is_system_active).is_true()
	assert_that(battle_events_system.battle_in_progress).is_true()
	assert_that(battle_events_system.current_round).is_equal(0)
	assert_that(battle_events_system.events_triggered).is_empty()

# Test round advancement
@warning_ignore("unsafe_method_access")
func test_round_advancement() -> void:
	# Given initialized battle
	battle_events_system.initialize_battle()
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When advancing round
	battle_events_system.advance_round()
	
	# Then round should advance and signal emitted
	assert_that(battle_events_system.current_round).is_equal(1)
	assert_signal(battle_events_system).is_emitted("round_event_check", [1])

# Test event triggering on round 2
@warning_ignore("unsafe_method_access")
func test_event_triggering_round_2() -> void:
	# Given battle in round 1
	battle_events_system.initialize_battle()
	battle_events_system.advance_round() # Round 1
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When advancing to round 2
	battle_events_system.advance_round() # Round 2
	
	# Then event should be triggered (Core Rules: end of round 2)
	assert_that(battle_events_system.current_round).is_equal(2)
	assert_signal(battle_events_system).is_emitted("battle_event_triggered")

# Test event triggering on round 4
@warning_ignore("unsafe_method_access")
func test_event_triggering_round_4() -> void:
	# Given battle advanced to round 3
	battle_events_system.initialize_battle()
	for i: int in range(3):
		battle_events_system.advance_round()
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When advancing to round 4
	battle_events_system.advance_round() # Round 4
	
	# Then event should be triggered (Core Rules: end of round 4)
	assert_that(battle_events_system.current_round).is_equal(4)
	assert_signal(battle_events_system).is_emitted("battle_event_triggered")

# Test no events on other rounds
@warning_ignore("unsafe_method_access")
func test_no_events_other_rounds() -> void:
	# Given battle system
	battle_events_system.initialize_battle()
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When advancing to round 1, 3, 5
	for round_num in [1, 3, 5]:
		battle_events_system.advance_round()
		
		# Then no battle events should trigger (only rounds 2 and 4)
		if round_num != 2 and round_num != 4:
			assert_signal(battle_events_system).is_not_emitted("battle_event_triggered")

# Test event registry initialization
@warning_ignore("unsafe_method_access")
func test_event_registry_initialization() -> void:
	# Then event registry should contain Core Rules events
	var registry = battle_events_system.event_registry
	assert_that(registry).is_not_empty()
	assert_that(@warning_ignore("unsafe_call_argument")
	registry.has("RENEWED_EFFORTS")).is_true()
	assert_that(@warning_ignore("unsafe_call_argument")
	registry.has("ENEMY_REINFORCEMENTS")).is_true()
	assert_that(@warning_ignore("unsafe_call_argument")
	registry.has("SEIZED_MOMENT")).is_true()
	assert_that(@warning_ignore("unsafe_call_argument")
	registry.has("ENVIRONMENTAL_HAZARD")).is_true()

# Test specific event creation
@warning_ignore("unsafe_method_access")
func test_battle_event_creation() -> void:
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
@warning_ignore("unsafe_method_access")
func test_event_roll_matching() -> void:
	# When getting event for roll within range
	var event = battle_events_system._get_event_for_roll(3) # Should match RENEWED_EFFORTS [1,5]
	
	# Then correct event should be returned
	assert_that(event).is_not_null()
	assert_that(event.event_id).is_equal("RENEWED_EFFORTS")

# Test environmental hazard creation
@warning_ignore("unsafe_method_access")
func test_environmental_hazard_creation() -> void:
	# Given environmental event
	var env_event = battle_events_system.event_registry["ENVIRONMENTAL_HAZARD"]
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When applying environmental event
	battle_events_system._apply_environmental_event(env_event)
	
	# Then hazard should be created and signal emitted
	assert_that(battle_events_system.active_hazards).is_not_empty()
	assert_signal(battle_events_system).is_emitted("environmental_hazard_activated")

# Test environmental damage checking
@warning_ignore("unsafe_method_access")
func test_environmental_damage_checking() -> void:
	# Given active environmental hazard
	var hazard: Resource = Resource.new()
	hazard.set_meta("hazard_id", "TEST_HAZARD")
	hazard.set_meta("save_difficulty", 5)
	hazard.set_meta("damage_bonus", 1)
	hazard.set_meta("affects_radius", 2)
	battle_events_system.@warning_ignore("return_value_discarded")
	active_hazards.append(hazard)
	
	# When checking damage for character in range
	var damage_results = battle_events_system.check_environmental_damage(Vector2(1, 1), 3)
	
	# Then damage results should be calculated
	assert_that(damage_results).is_not_empty()
	assert_that(@warning_ignore("unsafe_call_argument")
	damage_results.has("TEST_HAZARD")).is_true()

# Test crew event effects
@warning_ignore("unsafe_method_access")
func test_crew_event_effects() -> void:
	# Given crew event
	var crew_event = battle_events_system.event_registry["SEIZED_MOMENT"]
	
	# When applying crew event
	battle_events_system._apply_crew_event(crew_event)
	
	# Then crew effects should be applied
	assert_that(crew_event.@warning_ignore("unsafe_call_argument")
	effects.has("selected_crew")).is_true()
	assert_that(crew_event.@warning_ignore("unsafe_call_argument")
	effects.has("bonus_actions")).is_true()

# Test enemy event effects
@warning_ignore("unsafe_method_access")
func test_enemy_event_effects() -> void:
	# Given enemy event
	var enemy_event = battle_events_system.event_registry["ENEMY_REINFORCEMENTS"]
	
	# When applying enemy event
	battle_events_system._apply_enemy_event(enemy_event)
	
	# Then enemy effects should be applied
	assert_that(enemy_event.@warning_ignore("unsafe_call_argument")
	effects.has("spawn_enemies")).is_true()
	assert_that(enemy_event.@warning_ignore("unsafe_call_argument")
	effects.has("specialist_count")).is_true()

# Test battlefield event effects
@warning_ignore("unsafe_method_access")
func test_battlefield_event_effects() -> void:
	# Given battlefield event
	var battlefield_event = battle_events_system.event_registry["FOG_CLOUD"]
	
	# When applying battlefield event
	battle_events_system._apply_battlefield_event(battlefield_event)
	
	# Then battlefield effects should be applied
	assert_that(battlefield_event.@warning_ignore("unsafe_call_argument")
	effects.has("fog_radius")).is_true()
	assert_that(battlefield_event.@warning_ignore("unsafe_call_argument")
	effects.has("fog_vision")).is_true()

# Test event conflict detection
@warning_ignore("unsafe_method_access")
func test_event_conflict_detection() -> void:
	# Given event with conflicts
	var event1: Resource = Resource.new()
	event1.set_meta("event_id", "EVENT_1")
	var conflicts: @warning_ignore("unsafe_call_argument")
	Array[String] = ["EVENT_2"]
	event1.set_meta("conflicts_with", conflicts)
	
	var event2: Resource = Resource.new()
	event2.set_meta("event_id", "EVENT_2")
	
	battle_events_system.@warning_ignore("return_value_discarded")
	events_triggered.append(event1)
	
	# When checking conflicts
	var conflict = battle_events_system._check_event_conflicts(event2)
	
	# Then conflict should be detected
	assert_that(conflict).is_not_null()
	assert_that(conflict.get_meta("event_id")).is_equal("EVENT_1")

# Test battle ending
@warning_ignore("unsafe_method_access")
func test_battle_ending() -> void:
	# Given active battle with events
	battle_events_system.initialize_battle()
	var test_event: Resource = Resource.new()
	test_event.set_meta("is_persistent", false)
	battle_events_system.@warning_ignore("return_value_discarded")
	events_triggered.append(test_event)
	
	# When ending battle
	battle_events_system.end_battle()
	
	# Then system should cleanup and stop
	assert_that(battle_events_system.battle_in_progress).is_false()

# Test event duration processing
@warning_ignore("unsafe_method_access")
func test_event_duration_processing() -> void:
	# Given event with duration
	var timed_event: Resource = Resource.new()
	timed_event.set_meta("event_id", "TIMED_EVENT")
	timed_event.set_meta("duration", 2)
	battle_events_system.@warning_ignore("return_value_discarded")
	events_triggered.append(timed_event)
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When processing events twice
	battle_events_system._process_active_events()
	battle_events_system._process_active_events()
	
	# Then event should be completed and removed
	assert_that(battle_events_system.events_triggered).is_empty()
	assert_signal(battle_events_system).is_emitted("event_resolved", ["TIMED_EVENT", {"completed": true}])

# Test system status checking
@warning_ignore("unsafe_method_access")
func test_system_status_checking() -> void:
	# Given inactive system
	assert_that(battle_events_system.is_active()).is_false()
	
	# When initializing battle
	battle_events_system.initialize_battle()
	
	# Then system should be active
	assert_that(battle_events_system.is_active()).is_true()
	assert_that(battle_events_system.get_current_round()).is_equal(0)

# Test serialization
@warning_ignore("unsafe_method_access")
func test_serialization() -> void:
	# Given system with state
	battle_events_system.initialize_battle()
	battle_events_system.advance_round()
	
	# When serializing
	var serialized = battle_events_system.serialize()
	
	# Then data should be preserved
	assert_that(serialized).is_not_empty()
	assert_that(@warning_ignore("unsafe_call_argument")
	serialized.has("is_system_active")).is_true()
	assert_that(@warning_ignore("unsafe_call_argument")
	serialized.has("current_round")).is_true()
	assert_that(@warning_ignore("unsafe_call_argument")
	serialized.has("battle_in_progress")).is_true()

# Test deserialization
@warning_ignore("unsafe_method_access")
func test_deserialization() -> void:
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
@warning_ignore("unsafe_method_access")
func test_signal_emission_patterns() -> void:
	# Given battle system
	battle_events_system.initialize_battle()
	@warning_ignore("unsafe_method_access")
	monitor_signals(battle_events_system)
	
	# When advancing to event round
	battle_events_system.advance_round() # Round 1
	battle_events_system.advance_round() # Round 2 - triggers event
	
	# Then proper signals should be emitted
	assert_signal(battle_events_system).is_emitted("round_event_check", [1])
	assert_signal(battle_events_system).is_emitted("round_event_check", [2])
	assert_signal(battle_events_system).is_emitted("battle_event_triggered")

# Test error handling
@warning_ignore("unsafe_method_access")
func test_error_handling() -> void:
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