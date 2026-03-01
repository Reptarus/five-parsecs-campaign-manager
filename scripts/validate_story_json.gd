@tool
extends EditorScript

## Standalone JSON validation script
## Run via: Editor -> Run Script

func _run() -> void:
	print("=== Story Mission JSON Validation ===\n")

	var mission_files = [
		"res://data/story_track_missions/mission_01_discovery.json",
		"res://data/story_track_missions/mission_02_contact.json",
		"res://data/story_track_missions/mission_03_conspiracy.json",
		"res://data/story_track_missions/mission_04_personal.json",
		"res://data/story_track_missions/mission_05_hunt.json",
		"res://data/story_track_missions/mission_06_confrontation.json"
	]

	var passed = 0
	var failed = 0
	var errors = []

	for path in mission_files:
		var result = validate_mission_file(path)
		if result.is_empty():
			print("✅ %s PASSED" % path.get_file())
			passed += 1
		else:
			print("❌ %s FAILED:" % path.get_file())
			for error in result:
				print("  - %s" % error)
			failed += 1
			errors.append({"file": path, "errors": result})

	print("\n=== Results ===")
	print("Passed: %d/%d" % [passed, mission_files.size()])
	print("Failed: %d/%d" % [failed, mission_files.size()])

	if not errors.is_empty():
		print("\n=== Failed Missions Details ===")
		for error_info in errors:
			print("\nFile: %s" % error_info["file"])
			for error in error_info["errors"]:
				print("  - %s" % error)

func validate_mission_file(file_path: String) -> Array[String]:
	var validation_errors: Array[String] = []

	if not FileAccess.file_exists(file_path):
		validation_errors.append("File not found")
		return validation_errors

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		validation_errors.append("Could not open file")
		return validation_errors

	var content = file.get_as_text()
	file.close()

	if content.is_empty():
		validation_errors.append("Empty file")
		return validation_errors

	var json = JSON.new()
	var parse_result = json.parse(content)

	if parse_result != OK:
		validation_errors.append("JSON parse error: %s" % json.get_error_message())
		return validation_errors

	var data = json.get_data()
	if not data is Dictionary:
		validation_errors.append("Root is not a Dictionary")
		return validation_errors

	# Validate required top-level fields
	var required_fields = ["mission_id", "story_event_id", "title", "mission_number", "battlefield", "enemies", "objectives"]
	for field in required_fields:
		if not data.has(field):
			validation_errors.append("Missing required field: %s" % field)

	# Validate battlefield structure
	if data.has("battlefield"):
		var bf = data["battlefield"]
		if not bf is Dictionary:
			validation_errors.append("Battlefield is not a Dictionary")
		else:
			if not bf.has("size") or not bf.has("deployment_zones"):
				validation_errors.append("Battlefield missing size or deployment_zones")
			if bf.has("size"):
				var size = bf["size"]
				if not size is Dictionary:
					validation_errors.append("Battlefield size is not a Dictionary")
				elif not size.has("x") or not size.has("y"):
					validation_errors.append("Battlefield size missing x or y")

	# Validate enemies structure
	if data.has("enemies"):
		var enemies = data["enemies"]
		if not enemies is Dictionary:
			validation_errors.append("Enemies is not a Dictionary")
		elif not enemies.has("composition") or not enemies.has("fixed_count"):
			validation_errors.append("Enemies missing composition or fixed_count")

	# Validate objectives structure
	if data.has("objectives"):
		var objectives = data["objectives"]
		if not objectives is Dictionary:
			validation_errors.append("Objectives is not a Dictionary")
		elif not objectives.has("primary"):
			validation_errors.append("Objectives missing primary objective")

	# Validate mission number
	if data.has("mission_number"):
		var num = data["mission_number"]
		if not num is int and not num is float:
			validation_errors.append("Mission number is not a number")
		elif num < 1 or num > 6:
			validation_errors.append("Mission number must be 1-6, got: %s" % num)

	# Validate difficulty rating (if present)
	if data.has("difficulty_rating"):
		var diff = data["difficulty_rating"]
		if not diff is int and not diff is float:
			validation_errors.append("Difficulty rating is not a number")
		elif diff < 1 or diff > 5:
			validation_errors.append("Difficulty rating must be 1-5, got: %s" % diff)

	return validation_errors
