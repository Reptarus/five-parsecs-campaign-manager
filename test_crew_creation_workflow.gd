extends SceneTree

## Emergency Fix Crew Creation Workflow Test
## Tests that crew creation now works without FiveParsecsCharacterGeneration errors

func _init():
	print("=== Emergency Crew Creation Workflow Test ===")
	
	# Test 1: Test multiple character generation (simulating crew creation)
	print("\n1. Testing multiple character generation...")
	var crew_members = []
	for i in range(4):  # Generate 4 crew members
		var character = Character.generate_character_enhanced({"creation_mode": "standard"})
		if character and character.is_valid():
			crew_members.append(character)
			print("✅ Crew member %d generated: %s (%s)" % [i+1, character.name, character.background])
		else:
			print("❌ Failed to generate crew member %d" % [i+1])
			quit(1)
	
	# Test 2: Test captain promotion
	print("\n2. Testing captain promotion...")
	if crew_members.size() > 0:
		var captain = Character.create_captain_from_crew(crew_members[0])
		if captain.is_captain:
			print("✅ Captain promotion successful: %s" % captain.name)
		else:
			print("❌ Captain promotion failed")
			quit(1)
	
	# Test 3: Test crew generation using static method
	print("\n3. Testing crew generation using Character.generate_crew_members()...")
	var generated_crew = Character.generate_crew_members(6)  # Generate 6 crew members
	if generated_crew.size() == 6:
		print("✅ Crew generation successful: %d members generated" % generated_crew.size())
		for i in range(generated_crew.size()):
			var member = generated_crew[i]
			if not member.is_valid():
				print("❌ Invalid crew member generated at index %d" % i)
				quit(1)
		print("✅ All crew members are valid")
	else:
		print("❌ Crew generation failed: expected 6, got %d" % generated_crew.size())
		quit(1)
	
	# Test 4: Test character enhancement methods
	print("\n4. Testing character enhancement methods...")
	var test_character = Character.new()
	test_character.name = "Test Character"
	test_character.background = "Military"
	test_character.combat = 2
	test_character.toughness = 2
	
	# Apply bonuses
	Character.apply_background_bonuses(test_character)
	Character.apply_class_bonuses(test_character)
	Character.set_character_flags(test_character)
	
	# Validate
	var validation = Character.validate_character(test_character)
	if validation.valid:
		print("✅ Character enhancement and validation successful")
	else:
		print("❌ Character enhancement failed: %s" % validation.errors)
		quit(1)
	
	# Test 5: Test equipment generation
	print("\n5. Testing equipment generation...")
	var equipment = Character.generate_starting_equipment_enhanced(test_character)
	if equipment is Dictionary:
		print("✅ Equipment generation successful: %d items" % equipment.size())
	else:
		print("❌ Equipment generation failed")
		quit(1)
	
	# Test 6: Test patron/rival generation (stub methods)
	print("\n6. Testing patron/rival generation...")
	var patrons = Character.generate_patrons(test_character)
	var rivals = Character.generate_rivals(test_character)
	if patrons is Array and rivals is Array:
		print("✅ Patron/rival generation successful (stub methods working)")
	else:
		print("❌ Patron/rival generation failed")
		quit(1)
	
	# Test 7: Test comprehensive character validation
	print("\n7. Testing comprehensive character validation...")
	var validation_count = 0
	for member in crew_members:
		var result = Character.validate_character(member)
		if result.valid:
			validation_count += 1
	
	if validation_count == crew_members.size():
		print("✅ All %d crew members pass validation" % validation_count)
	else:
		print("❌ Validation failed: %d/%d members valid" % [validation_count, crew_members.size()])
		quit(1)
	
	print("\n=== ALL CREW CREATION TESTS PASSED! ===")
	print("Crew creation workflow is working correctly!")
	print("Emergency character generation fix successfully eliminates FiveParsecsCharacterGeneration errors!")
	quit(0)