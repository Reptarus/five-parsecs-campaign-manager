extends SceneTree

## Emergency Fix Character Generation End-to-End Test
## Tests that all fixed character generation references work correctly

func _init():
	print("=== Emergency Character Generation Fix End-to-End Test ===")
	
	# Test 1: Basic Character generation
	print("\n1. Testing Character.generate_character()...")
	var character1 = Character.generate_character()
	if character1 and character1.is_valid():
		print("✅ Basic character generation successful: %s" % character1.name)
	else:
		print("❌ Basic character generation failed")
		quit(1)
	
	# Test 2: Enhanced Character generation
	print("\n2. Testing Character.generate_character_enhanced()...")
	var character2 = Character.generate_character_enhanced({"creation_mode": "veteran"})
	if character2 and character2.is_valid():
		print("✅ Enhanced character generation successful: %s (veteran)" % character2.name)
	else:
		print("❌ Enhanced character generation failed")
		quit(1)
	
	# Test 3: Compatibility methods
	print("\n3. Testing compatibility methods...")
	var character3 = Character.generate_complete_character({})
	if character3 and character3.is_valid():
		print("✅ Compatibility method generate_complete_character() works: %s" % character3.name)
	else:
		print("❌ Compatibility method generate_complete_character() failed")
		quit(1)
	
	# Test 4: Character attributes generation
	print("\n4. Testing Character.generate_character_attributes()...")
	var character4 = Character.new()
	character4.name = "Test Character"
	Character.generate_character_attributes(character4)
	if character4.combat > 0 and character4.reactions > 0:
		print("✅ Character attributes generation successful: Combat=%d, Reactions=%d" % [character4.combat, character4.reactions])
	else:
		print("❌ Character attributes generation failed")
		quit(1)
	
	# Test 5: Background bonuses
	print("\n5. Testing Character.apply_background_bonuses()...")
	var character5 = Character.new()
	character5.name = "Military Character"
	character5.background = "Military"
	character5.combat = 1
	character5.toughness = 1
	Character.apply_background_bonuses(character5)
	if character5.combat > 1 or character5.toughness > 1:
		print("✅ Background bonuses applied successfully")
	else:
		print("❌ Background bonuses failed")
		quit(1)
	
	# Test 6: Character validation
	print("\n6. Testing Character.validate_character()...")
	var validation_result = Character.validate_character(character1)
	if validation_result.has("valid") and validation_result.valid:
		print("✅ Character validation successful")
	else:
		print("❌ Character validation failed: %s" % validation_result.get("errors", []))
		quit(1)
	
	# Test 7: Random character generation
	print("\n7. Testing Character.generate_random_character()...")
	var character7 = Character.generate_random_character()
	if character7 and character7.is_valid():
		print("✅ Random character generation successful: %s" % character7.name)
	else:
		print("❌ Random character generation failed")
		quit(1)
	
	print("\n=== ALL TESTS PASSED! ===")
	print("Emergency character generation fix is working correctly!")
	quit(0)