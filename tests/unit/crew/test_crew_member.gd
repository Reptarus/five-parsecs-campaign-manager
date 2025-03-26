@tool
# Use explicit file paths instead of class names
extends "res://tests/fixtures/base/game_test.gd"
# Tests the basic functionality of a crew member
# Properties, skills, health points, etc.

# Test suite for BaseCrewMember class
# Tests initialization, experience gain, and level progression

# Use explicit preloads instead of global class names
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var CrewMemberScript = load("res://src/core/crew/CrewMember.gd") if ResourceLoader.exists("res://src/core/crew/CrewMember.gd") else null

# Test variables with type safety comments
var _crew_member: Resource = null

func before_each() -> void:
	await super.before_each()
	
	if not CrewMemberScript:
		push_error("CrewMember script is null")
		return
		
	_crew_member = CrewMemberScript.new()
	if not _crew_member:
		push_error("Failed to create crew member")
		return
	
	# Ensure resource has a valid path for Godot 4.4
	_crew_member = Compatibility.ensure_resource_path(_crew_member, "test_crew_member")
	
	track_test_resource(_crew_member)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_crew_member = null
	await super.after_each()

func test_crew_member_initialization() -> void:
	assert_not_null(_crew_member, "Crew member should be initialized")
	
	# Test basic properties
	var name = Compatibility.safe_call_method(_crew_member, "get_name", [], "")
	var level = Compatibility.safe_call_method(_crew_member, "get_level", [], 0)
	var health = Compatibility.safe_call_method(_crew_member, "get_health", [], 0)
	
	assert_ne(name, "", "Crew member should have a name")
	assert_ge(level, 1, "Crew member should have at least level 1")
	assert_gt(health, 0, "Crew member should have positive health")

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