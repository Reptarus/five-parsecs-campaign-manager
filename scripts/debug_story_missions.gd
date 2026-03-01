extends SceneTree

## Debug script to manually validate story mission JSON files
## Run via: godot --script scripts/debug_story_missions.gd

func _init() -> void:
	print("=== Story Mission JSON Validation Debug ===\n")

	var loader = FPCM_StoryMissionLoader.new()
	var event_ids = ["discovery_signal", "first_contact", "conspiracy_revealed",
	                 "personal_connection", "hunt_begins", "final_confrontation"]

	var passed = 0
	var failed = 0

	for event_id in event_ids:
		print("Testing: %s" % event_id)
		var mission = loader.load_story_mission(event_id)

		if mission.is_empty():
			print("  ❌ FAILED to load")
			failed += 1
		else:
			print("  ✅ PASSED - mission_id: %s, title: %s" % [mission.get("mission_id"), mission.get("title")])
			passed += 1
		print("")

	print("\n=== Results ===")
	print("Passed: %d/%d" % [passed, event_ids.size()])
	print("Failed: %d/%d" % [failed, event_ids.size()])

	quit()
