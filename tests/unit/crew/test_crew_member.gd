@tool
# Use explicit file paths instead of class names
extends "res://tests/fixtures/base/game_test.gd"
# Tests the basic functionality of a crew member
# Properties, skills, health points, etc.

# Test suite for BaseCrewMember class
# Tests initialization, experience gain, and level progression

# Use explicit preloads instead of global class names
const CrewMemberScript = preload("res://src/base/campaign/crew/BaseCrewMember.gd")
const GameEnumsScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test variables with type safety comments
var _crew_member = null # BaseCrewMember instance

func before_each():
	await super.before_each()
	
	# Create instance of crew member
	_crew_member = CrewMemberScript.new()
	add_child_autofree(_crew_member)
	
	await stabilize_engine()

func after_each():
	_crew_member = null
	await super.after_each()

func test_crew_member_initialization():
	# Then
	assert_not_null(_crew_member, "Crew member should be initialized")
	
	# Use direct method calls
	var name = _crew_member.get_name()
	assert_eq(name, "", "Default name should be empty")
	
	var level = _crew_member.get_level()
	assert_eq(level, 1, "Default level should be 1")
	
	var experience = _crew_member.get_experience()
	assert_eq(experience, 0, "Default experience should be 0")

func test_crew_member_experience_gain():
	# Given
	watch_signals(_crew_member)
	
	# When - use direct method call
	_crew_member.add_experience(100)
	
	# Then
	var experience = _crew_member.get_experience()
	assert_eq(experience, 100, "Experience should be 100 after adding 100")
	
	# Verify level increase signal
	verify_signal_emitted(_crew_member, "level_changed")
	
	var level = _crew_member.get_level()
	assert_gt(level, 1, "Level should increase after gaining experience")