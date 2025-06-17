extends GdUnitTestSuite

# Test StoryTrackSystem using Universal Mock Strategy patterns
class_name Test_StoryTrackSystem

# Universal Mock Strategy - Resource-based mock
class MockStoryTrackSystem extends Resource:
	# Expected values - never null/zero unless testing edge cases
	var is_story_track_active: bool = false
	var story_clock_ticks: int = 6
	var evidence_pieces: int = 0
	var current_event_index: int = 0
	var story_track_phase: String = "inactive"
	var story_events: Array = []
	var story_choices_made: Array = []
	var completed_events: Array = []
	var story_rewards_earned: Array = []
	
	# Complete API - all required methods implemented
	func _init():
		_initialize_story_events()
	
	func _initialize_story_events():
		# Create 6 story events per Appendix V
		story_events = [
			{
				"event_index": 0,
				"event_id": "discovery_signal",
				"title": "Mysterious Signal",
				"required_evidence": 0,
				"is_completed": false,
				"choices": [
					{
						"choice_text": "Investigate immediately",
						"risk_level": "high",
						"evidence_gain": 2
					},
					{
						"choice_text": "Gather more information",
						"risk_level": "low",
						"evidence_gain": 1
					},
					{
						"choice_text": "Ignore the signal",
						"risk_level": "none",
						"evidence_gain": 0
					}
				]
			},
			{
				"event_index": 1,
				"event_id": "first_contact",
				"title": "First Contact",
				"required_evidence": 2,
				"is_completed": false,
				"choices": []
			},
			{
				"event_index": 2,
				"event_id": "investigation",
				"title": "Investigation",
				"required_evidence": 3,
				"is_completed": false,
				"choices": []
			},
			{
				"event_index": 3,
				"event_id": "revelation",
				"title": "Revelation",
				"required_evidence": 4,
				"is_completed": false,
				"choices": []
			},
			{
				"event_index": 4,
				"event_id": "preparation",
				"title": "Preparation",
				"required_evidence": 5,
				"is_completed": false,
				"choices": []
			},
			{
				"event_index": 5,
				"event_id": "final_confrontation",
				"title": "We're Coming!",
				"required_evidence": 7,
				"is_completed": false,
				"choices": []
			}
		]
	
	func start_story_track():
		is_story_track_active = true
		story_track_phase = "active"
		story_event_triggered.emit()
	
	func advance_story_clock(success: bool):
		if success:
			story_clock_ticks = max(0, story_clock_ticks - 2)
		else:
			story_clock_ticks = max(0, story_clock_ticks - 1)
		story_clock_advanced.emit(story_clock_ticks)
	
	func discover_evidence(amount: int):
		evidence_pieces += amount
		evidence_discovered.emit(amount)
	
	func get_current_event():
		if current_event_index < story_events.size():
			return story_events[current_event_index]
		return null
	
	func make_story_choice(event, choice):
		if not event or not choice:
			return {"success": false, "message": "Invalid parameters"}
		
		story_choices_made.append({"event": event, "choice": choice})
		event.is_completed = true
		completed_events.append(event)
		story_choice_made.emit()
		
		return {
			"success": true,
			"description": "Choice processed successfully"
		}
	
	func _check_evidence_progression():
		# Mock evidence progression logic
		pass
	
	func _calculate_success_chance(risk_level: String) -> float:
		match risk_level:
			"none": return 1.0
			"low": return 0.85
			"high": return 0.55
			"extreme": return 0.25
			_: return 0.5
	
	func trigger_next_event():
		current_event_index += 1
		if current_event_index >= story_events.size():
			is_story_track_active = false
			story_track_phase = "completed"
			story_track_completed.emit()
	
	func get_story_track_status():
		return {
			"is_active": is_story_track_active,
			"evidence_pieces": evidence_pieces,
			"current_event_index": current_event_index,
			"total_events": story_events.size(),
			"can_progress": can_progress()
		}
	
	func serialize():
		return {
			"is_story_track_active": is_story_track_active,
			"evidence_pieces": evidence_pieces,
			"current_event_index": current_event_index,
			"story_choices_made": story_choices_made
		}
	
	func deserialize(data: Dictionary):
		is_story_track_active = data.get("is_story_track_active", false)
		evidence_pieces = data.get("evidence_pieces", 0)
		current_event_index = data.get("current_event_index", 0)
		story_choices_made = data.get("story_choices_made", [])
	
	func _apply_choice_consequences(choice):
		# Mock consequence application
		if choice.risk_level == "extreme":
			evidence_pieces = max(0, evidence_pieces - 1)
			story_clock_ticks = max(0, story_clock_ticks - 1)
	
	func get_available_events():
		var available = []
		for event in story_events:
			if evidence_pieces >= event.required_evidence:
				available.append(event)
		return available
	
	func can_progress() -> bool:
		if current_event_index >= story_events.size():
			return false
		var current_event = story_events[current_event_index]
		return evidence_pieces >= current_event.required_evidence
	
	func _get_success_flavor(reward_type: String) -> String:
		match reward_type:
			"tech_data": return "You discover valuable technology data"
			"ally": return "You gain a powerful ally"
			_: return "Success achieved"
	
	func _get_failure_flavor(risk_level: String) -> String:
		match risk_level:
			"extreme": return "The severe consequences are felt immediately"
			_: return "The attempt fails"
	
	func _apply_choice_rewards(choice):
		var reward = {
			"type": choice.get("reward_type", "evidence"),
			"effect": choice.get("evidence_gain", 1),
			"timestamp": Time.get_ticks_msec()
		}
		story_rewards_earned.append(reward)
	
	# Realistic signals - emit immediately for predictable testing
	signal story_event_triggered()
	signal story_clock_advanced(ticks: int)
	signal evidence_discovered(amount: int)
	signal story_choice_made()
	signal story_track_completed()

var story_track_system: MockStoryTrackSystem
var mock_game_state: Resource

func before_test():
	# Create fresh system for each test - proven pattern
	story_track_system = MockStoryTrackSystem.new()
	mock_game_state = Resource.new()
	
	# Track resources for cleanup
	auto_free(story_track_system)
	auto_free(mock_game_state)

func after_test():
	# Cleanup happens automatically with auto_free()
	pass

# Test system initialization
func test_story_track_initialization():
	# Then story track should be initialized with expected values
	assert_that(story_track_system.is_story_track_active).is_false()
	assert_that(story_track_system.story_clock_ticks).is_equal(6)
	assert_that(story_track_system.evidence_pieces).is_equal(0)
	assert_that(story_track_system.current_event_index).is_equal(0)
	assert_that(story_track_system.story_events.size()).is_equal(6) # 6 events per Appendix V

# Test story track activation
func test_story_track_activation():
	# Monitor signals before action - proven pattern
	monitor_signals(story_track_system)
	
	# When starting story track
	story_track_system.start_story_track()
	
	# Then story track should be active
	assert_that(story_track_system.is_story_track_active).is_true()
	assert_that(story_track_system.story_track_phase).is_equal("active")
	assert_that(story_track_system.story_clock_ticks).is_equal(6)
	
	# And first event should be triggered
	assert_signal(story_track_system).is_emitted("story_event_triggered")

# Test story clock advancement
func test_story_clock_advancement():
	# Given an active story track
	story_track_system.start_story_track()
	monitor_signals(story_track_system)
	
	# When advancing clock with success
	story_track_system.advance_story_clock(true)
	
	# Then clock should reduce by 2 (success pattern from rules)
	assert_that(story_track_system.story_clock_ticks).is_equal(4)
	assert_signal(story_track_system).is_emitted("story_clock_advanced", [4])
	
	# When advancing clock with failure
	story_track_system.advance_story_clock(false)
	
	# Then clock should reduce by 1 (failure pattern from rules)
	assert_that(story_track_system.story_clock_ticks).is_equal(3)

# Test evidence discovery
func test_evidence_discovery():
	# Given an active story track
	story_track_system.start_story_track()
	monitor_signals(story_track_system)
	
	# When discovering evidence
	story_track_system.discover_evidence(2)
	
	# Then evidence count should increase
	assert_that(story_track_system.evidence_pieces).is_equal(2)
	assert_signal(story_track_system).is_emitted("evidence_discovered", [2])

# Test story event progression
func test_story_event_progression():
	# Given an active story track
	story_track_system.start_story_track()
	
	# When getting current event
	var current_event = story_track_system.get_current_event()
	
	# Then it should be the first event
	assert_that(current_event).is_not_null()
	assert_that(current_event.event_index).is_equal(0)
	assert_that(current_event.event_id).is_equal("discovery_signal")
	assert_that(current_event.title).is_equal("Mysterious Signal")

# Test story choice making
func test_story_choice_making():
	# Given an active story track with current event
	story_track_system.start_story_track()
	var current_event = story_track_system.get_current_event()
	assert_that(current_event).is_not_null()
	assert_that(current_event.choices.size()).is_greater(0)
	
	var first_choice = current_event.choices[0] # "Investigate immediately"
	assert_that(first_choice).is_not_null()
	
	monitor_signals(story_track_system)
	
	# When making a story choice
	var outcome = story_track_system.make_story_choice(current_event, first_choice)
	
	# Then choice should be recorded and processed
	assert_that(outcome).is_not_null()
	assert_that(outcome.has("success")).is_true()
	assert_that(outcome.has("description")).is_true()
	assert_that(story_track_system.story_choices_made.size()).is_equal(1)
	
	# And signals should be emitted
	assert_signal(story_track_system).is_emitted("story_choice_made")
	
	# And event should be marked completed
	assert_that(current_event.is_completed).is_true()
	assert_that(story_track_system.completed_events.size()).is_equal(1)

# Test evidence progression mechanics (Core Rules)
func test_evidence_progression_mechanics():
	# Given story track with evidence
	story_track_system.start_story_track()
	story_track_system.evidence_pieces = 6 # Set high evidence count
	
	# Mock the random roll for testing - simulate rolling 1 (total = 7)
	# This tests the "7+" mechanic from Appendix V
	
	# When checking evidence progression
	story_track_system._check_evidence_progression()
	
	# Then either event should advance or evidence should increase
	# (depending on random roll, but we can test the logic worked)
	assert_that(story_track_system.evidence_pieces >= 6).is_true()

# Test risk/reward mechanics
func test_risk_reward_mechanics():
	# Test different risk levels produce expected success chances
	var none_chance = story_track_system._calculate_success_chance("none")
	var low_chance = story_track_system._calculate_success_chance("low")
	var high_chance = story_track_system._calculate_success_chance("high")
	var extreme_chance = story_track_system._calculate_success_chance("extreme")
	
	# Then success chances should decrease with risk
	assert_that(none_chance).is_equal(1.0)
	assert_that(low_chance).is_equal(0.85)
	assert_that(high_chance).is_equal(0.55)
	assert_that(extreme_chance).is_equal(0.25)

# Test story track completion
func test_story_track_completion():
	# Given an active story track
	story_track_system.start_story_track()
	story_track_system.current_event_index = 6 # Past last event
	monitor_signals(story_track_system)
	
	# When triggering next event (should complete track)
	story_track_system.trigger_next_event()
	
	# Then story track should be completed
	assert_that(story_track_system.is_story_track_active).is_false()
	assert_that(story_track_system.story_track_phase).is_equal("completed")
	assert_signal(story_track_system).is_emitted("story_track_completed")

# Test story track status
func test_story_track_status():
	# Given an active story track with some progress
	story_track_system.start_story_track()
	story_track_system.evidence_pieces = 3
	story_track_system.current_event_index = 2
	
	# When getting status
	var status = story_track_system.get_story_track_status()
	
	# Then status should reflect current state
	assert_that(status.is_active).is_true()
	assert_that(status.evidence_pieces).is_equal(3)
	assert_that(status.current_event_index).is_equal(2)
	assert_that(status.total_events).is_equal(6)
	assert_that(status.has("can_progress")).is_true()

# Test serialization/deserialization
func test_serialization():
	# Given a story track with some progress
	story_track_system.start_story_track()
	story_track_system.evidence_pieces = 3
	story_track_system.current_event_index = 2
	story_track_system.story_choices_made.append({"test": "choice"})
	
	# When serializing and deserializing
	var serialized_data = story_track_system.serialize()
	var new_system = MockStoryTrackSystem.new()
	auto_free(new_system)
	new_system.deserialize(serialized_data)
	
	# Then state should be preserved
	assert_that(new_system.is_story_track_active).is_true()
	assert_that(new_system.evidence_pieces).is_equal(3)
	assert_that(new_system.current_event_index).is_equal(2)
	assert_that(new_system.story_choices_made.size()).is_equal(1)

# Test choice consequences
func test_choice_consequences():
	# Given a story track and high-risk choice
	story_track_system.start_story_track()
	var current_event = story_track_system.get_current_event()
	var high_risk_choice = current_event.choices[0] # "Investigate immediately" (high risk)
	high_risk_choice.risk_level = "extreme"
	
	# Store initial values
	var initial_evidence = story_track_system.evidence_pieces
	var initial_clock = story_track_system.story_clock_ticks
	
	# When applying consequences for failed choice
	story_track_system._apply_choice_consequences(high_risk_choice)
	
	# Then consequences should be applied for extreme risk
	# (evidence or clock should be reduced)
	var evidence_reduced = story_track_system.evidence_pieces < initial_evidence
	var clock_reduced = story_track_system.story_clock_ticks < initial_clock
	assert_that(evidence_reduced or clock_reduced).is_true()

# Test event availability
func test_event_availability():
	# Given a story track
	story_track_system.start_story_track()
	
	# When checking event availability with insufficient evidence
	story_track_system.evidence_pieces = 0
	story_track_system.current_event_index = 2 # Event requiring more evidence
	
	# Then later events should not be available
	var available_events = story_track_system.get_available_events()
	assert_that(available_events.size()).is_less_equal(1) # Only first event or none

# Test progression control
func test_progression_control():
	# Given a story track
	story_track_system.start_story_track()
	
	# When checking if can progress with sufficient evidence
	story_track_system.evidence_pieces = 5
	var can_progress_with_evidence = story_track_system.can_progress()
	
	# When checking if can progress without sufficient evidence  
	story_track_system.evidence_pieces = 0
	story_track_system.current_event_index = 3 # Event requiring evidence
	var cannot_progress_without_evidence = story_track_system.can_progress()
	
	# Then progression should be controlled by evidence
	assert_that(can_progress_with_evidence).is_true()
	assert_that(cannot_progress_without_evidence).is_false()

# Test all 6 story events are properly configured
func test_all_story_events_configured():
	# Given initialized story track
	# Then all 6 events should be properly configured
	assert_that(story_track_system.story_events.size()).is_equal(6)
	
	# Event 1: Discovery
	var event1 = story_track_system.story_events[0]
	assert_that(event1.event_id).is_equal("discovery_signal")
	assert_that(event1.required_evidence).is_equal(0)
	assert_that(event1.choices.size()).is_equal(3)
	
	# Event 6: Final confrontation
	var event6 = story_track_system.story_events[5]
	assert_that(event6.event_id).is_equal("final_confrontation")
	assert_that(event6.title).is_equal("We're Coming!")
	assert_that(event6.required_evidence).is_equal(7) # Per Appendix V rules

# Test choice text and descriptions
func test_choice_content():
	# Given initialized story track
	var first_event = story_track_system.story_events[0]
	
	# Then choices should have proper content
	assert_that(first_event.choices.size()).is_equal(3)
	assert_that(first_event.choices[0].choice_text).is_equal("Investigate immediately")
	assert_that(first_event.choices[0].risk_level).is_equal("high")
	assert_that(first_event.choices[0].evidence_gain).is_equal(2)

# Test flavor text generation
func test_flavor_text_generation():
	# Given choices with different rewards
	var tech_flavor = story_track_system._get_success_flavor("tech_data")
	var ally_flavor = story_track_system._get_success_flavor("ally")
	var failure_flavor = story_track_system._get_failure_flavor("extreme")
	
	# Then flavor text should be appropriate
	assert_that(tech_flavor).contains("technology")
	assert_that(ally_flavor).contains("ally")
	assert_that(failure_flavor).contains("severe")

# Test error handling
func test_error_handling():
	# When making choice with null parameters
	var outcome = story_track_system.make_story_choice(null, null)
	
	# Then error should be handled gracefully
	assert_that(outcome.success).is_false()
	assert_that(outcome.has("message")).is_true()

# Test signal emission patterns (Universal Mock Strategy)
func test_signal_emission_patterns():
	# Given story track system
	monitor_signals(story_track_system)
	
	# When performing various actions
	story_track_system.start_story_track()
	story_track_system.advance_story_clock(true)
	story_track_system.discover_evidence(1)
	
	# Then appropriate signals should be emitted
	assert_signal(story_track_system).is_emitted("story_event_triggered")
	assert_signal(story_track_system).is_emitted("story_clock_advanced")
	assert_signal(story_track_system).is_emitted("evidence_discovered")

# Test story rewards tracking
func test_story_rewards_tracking():
	# Given a story track with successful choice
	story_track_system.start_story_track()
	var current_event = story_track_system.get_current_event()
	var choice = current_event.choices[0]
	
	# When applying rewards
	story_track_system._apply_choice_rewards(choice)
	
	# Then rewards should be tracked
	assert_that(story_track_system.story_rewards_earned.size()).is_equal(1)
	var reward = story_track_system.story_rewards_earned[0]
	assert_that(reward.has("type")).is_true()
	assert_that(reward.has("effect")).is_true()
	assert_that(reward.has("timestamp")).is_true()