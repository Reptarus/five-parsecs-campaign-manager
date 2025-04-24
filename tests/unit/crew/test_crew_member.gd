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

# Safe method helpers to avoid dependency on Compatibility
func _has_method(obj, method_name: String) -> bool:
	if not obj:
		return false
	return obj.has_method(method_name)

func _safe_call_method(obj, method_name: String, args: Array = [], default_value = null):
	if not obj or not method_name:
		return default_value
	
	if not obj.has_method(method_name):
		push_warning("Method '%s' not found on object" % method_name)
		return default_value
		
	if args.is_empty():
		return obj.call(method_name)
	else:
		return obj.callv(method_name, args)

# Helper to set resource path safely
func _ensure_resource_path(resource, name_base: String = "test_resource") -> Resource:
	if not resource:
		return resource
		
	if _has_method(resource, "set_resource_path"):
		var timestamp = Time.get_unix_time_from_system()
		resource.set_resource_path("res://tests/generated/%s_%d.tres" % [name_base, timestamp])
	
	return resource

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
	_crew_member = _ensure_resource_path(_crew_member, "test_crew_member")
	
	track_test_resource(_crew_member)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_crew_member = null
	await super.after_each()

func test_crew_member_initialization() -> void:
	assert_not_null(_crew_member, "Crew member should be initialized")
	
	# Test basic properties
	var name = _safe_call_method(_crew_member, "get_name", [], "")
	var level = _safe_call_method(_crew_member, "get_level", [], 0)
	var health = _safe_call_method(_crew_member, "get_health", [], 0)
	
	assert_ne(name, "", "Crew member should have a name")
	assert_ge(level, 1, "Crew member should have at least level 1")
	assert_gt(health, 0, "Crew member should have positive health")

func test_crew_member_experience_gain():
	# Given
	watch_signals(_crew_member)
	
	# When - use safe method call instead of direct method call
	# Check if the method exists first
	if _has_method(_crew_member, "add_experience"):
		_safe_call_method(_crew_member, "add_experience", [100])
	else:
		# Fallback: try to add experience through a setter
		_safe_call_method(_crew_member, "set_experience", [100])
		push_warning("Using fallback method for adding experience")
	
	# Then
	var experience = _safe_call_method(_crew_member, "get_experience", [], 0)
	assert_eq(experience, 100, "Experience should be 100 after adding 100")
	
	# Verify level increase signal
	verify_signal_emitted(_crew_member, "level_changed")
	
	var level = _safe_call_method(_crew_member, "get_level", [], 0)
	assert_gt(level, 1, "Level should increase after gaining experience")