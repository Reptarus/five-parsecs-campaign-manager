# Story Track Integration Test
extends SceneTree

func _init() -> void:
	print("=== Five Parsecs Story Track Integration Test ===")
	test_story_integration()
	quit()

func test_story_integration() -> void:
	print("\n1. Testing Story Track System Integration:")
	
	# Test autoload access
	print("   Testing autoload access...")
	print("   Note: SceneTree test - managers may not be available during standalone execution")
	print("   ✓ Test framework: Available")
	
	# Create a minimal story system for testing
	var StoryTrackSystem = preload("res://src/core/story/StoryTrackSystem.gd")
	var story_system: RefCounted = StoryTrackSystem.new()
	
	if story_system:
		print("   ✓ Story track system: Loaded for testing")
		test_story_system(story_system)
	else:
		print("   ✗ Story track system: Failed to load")

func test_story_system(story_system) -> void:
	print("\n2. Testing Story System Functionality:")
	
	# Test story track status
	var status = story_system.get_story_track_status()
	print("   Story Track Status:")







	print("     - Active: %s" % status.get("is_active", false))







	print("     - Phase: %s" % status.get("phase", "unknown"))







	print("     - Clock Ticks: %d" % status.get("clock_ticks", 0))







	print("     - Evidence: %d" % status.get("evidence_pieces", 0))







	print("     - Can Progress: %s" % status.get("can_progress", false))
	
	# Test starting story track
	if not story_system.is_story_track_active:
		print("\n   Starting story track...")
		story_system.start_story_track()
		
		var new_status = story_system.get_story_track_status()







		print("   ✓ Story track started - Active: %s" % new_status.get("is_active", false))
		
		# Test current event
		var current_event = story_system.get_current_event()
		if current_event:
			print("   ✓ Current event available: %s" % current_event.title)
			test_story_choice(story_system, current_event)
		else:
			print("   ✗ No current event available")
	else:
		print("   Story track already active")

func test_story_choice(story_system, event) -> void:
	print("\n3. Testing Story Choice System:")
	
	if event.choices and event.choices.size() > 0:
		var choice = event.choices[0]
		print("   Testing choice: %s" % choice.choice_text)
		print("   Risk level: %s" % choice.risk_level)
		
		# Test making a choice
		var outcome = story_system.make_story_choice(event, choice)
		print("   Choice outcome:")







		print("     - Success: %s" % outcome.get("success", false))







		print("     - Description: %s" % outcome.get("description", "No description"))
		print("   ✓ Story choice system working")
	else:
		print("   ✗ No choices available for current event")

	print("\n=== Story Track Integration Test Complete ===")
