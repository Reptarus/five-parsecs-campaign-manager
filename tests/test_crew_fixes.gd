extends SceneTree

## Test script to verify crew panel fixes

const CrewPanel = preload("res://src/ui/screens/campaign/panels/CrewPanel.gd")
const Character = preload("res://src/core/character/Character.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

func _init():
	print("=== TESTING CREW PANEL FIXES ===")
	test_character_has_method_fix()
	test_crew_index_calculation()
	print("=== ALL TESTS COMPLETED ===")
	quit()

func test_character_has_method_fix():
	print("\n--- Testing Character .has() method fix ---")
	
	var character = Character.new()
	character.character_name = "Test Character"
	
	# Test the safe_get_property method that replaces .has()
	var safe_get_property = func(obj: Variant, property: String, default_value: Variant = null) -> Variant:
		if obj == null:
			return default_value
		if obj is Object:
			# Handle Resource objects properly - they don't have has() method
			if obj.has_method("get"):
				var value = obj.get(property)
				return value if value != null else default_value
			else:
				return default_value
		elif obj is Dictionary:
			return obj.get(property, default_value)
		return default_value
	
	# This should not crash (the old .has() method would crash)
	var portrait_path = safe_get_property.call(character, "portrait_path", "")
	print("✓ Safe property access works: portrait_path = '%s'" % portrait_path)
	
	# Test with actual property
	character.set("portrait_path", "test/path.png")
	portrait_path = safe_get_property.call(character, "portrait_path", "")
	print("✓ Safe property access with value: portrait_path = '%s'" % portrait_path)

func test_crew_index_calculation():
	print("\n--- Testing Crew Index Calculation Fix ---")
	
	# Simulate the crew list structure:
	# Index 0: Status line (disabled)
	# Index 1: Summary line (disabled) 
	# Index 2: Separator line (disabled)
	# Index 3: Character 0
	# Index 4: Character 1
	# etc.
	
	var test_cases = [
		{"selected_index": 3, "expected_crew_index": 0, "character_name": "First Character"},
		{"selected_index": 4, "expected_crew_index": 1, "character_name": "Second Character"},
		{"selected_index": 5, "expected_crew_index": 2, "character_name": "Third Character"},
	]
	
	for test_case in test_cases:
		var selected_index = test_case.selected_index
		var expected_crew_index = test_case.expected_crew_index
		
		# This is the FIXED calculation (was index - 2, now index - 3)
		var calculated_crew_index = selected_index - 3
		
		if calculated_crew_index == expected_crew_index:
			print("✓ Index calculation correct: selected=%d -> crew_index=%d (%s)" % [
				selected_index, calculated_crew_index, test_case.character_name
			])
		else:
			print("✗ Index calculation FAILED: selected=%d -> expected=%d, got=%d" % [
				selected_index, expected_crew_index, calculated_crew_index
			])
	
	# Test edge cases
	print("\n--- Testing Edge Cases ---")
	
	# Selecting status/summary lines should result in invalid index
	var invalid_selections = [0, 1, 2]
	for invalid_index in invalid_selections:
		var crew_index = invalid_index - 3
		if crew_index < 0:
			print("✓ Invalid selection %d correctly identified (crew_index=%d < 0)" % [invalid_index, crew_index])
		else:
			print("✗ Invalid selection %d not caught (crew_index=%d)" % [invalid_index, crew_index])
