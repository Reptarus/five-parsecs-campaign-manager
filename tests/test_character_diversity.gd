extends SceneTree

# Test script to verify character generation diversity
# Run with: godot --script test_character_diversity.gd --quit

func _init():
	print("=== CHARACTER DIVERSITY TEST ===")

	# Load GameStateManager class directly
	var GameStateManagerClass = load("res://src/core/managers/GameStateManager.gd")
	var gsm = GameStateManagerClass.new()

	# Initialize it
	gsm._ready()

	print("GameStateManager loaded and initialized")

	print("\n1. Generating test campaign...")

	# Generate 4 test characters
	var test_characters = []
	for i in range(4):
		var char_name = ["Alex", "Jordan", "Casey", "Riley"][i]
		var char_data = gsm._generate_character_with_modifiers(char_name)
		test_characters.append(char_data)

		print("\nGenerated character %d:" % (i + 1))
		print("  Name: %s" % char_data.get("character_name", "Unknown"))
		print("  Background: %s" % char_data.get("background", "UNKNOWN"))
		print("  Motivation: %s" % char_data.get("motivation", "UNKNOWN"))
		print("  Class: %s" % char_data.get("class", "UNKNOWN"))
		print("  Stats: Combat=%d, Toughness=%d, Savvy=%d" % [
			char_data.get("combat", 0),
			char_data.get("toughness", 0),
			char_data.get("savvy", 0)
		])

	print("\n2. Creating Character Resource objects...")

	# Load Character class
	var Character = load("res://src/core/character/Character.gd")
	if not Character:
		push_error("Failed to load Character.gd")
		quit(1)
		return

	var character_resources = []
	for char_data in test_characters:
		var character = Character.deserialize(char_data)
		if character:
			character_resources.append(character)
			print("\nDeserialized character:")
			print("  Name: %s" % character.name)
			print("  Background: %s" % character.background)
			print("  Motivation: %s" % character.motivation)
			print("  Class: %s" % character.character_class)
		else:
			push_error("Failed to deserialize character: %s" % char_data.get("character_name", "Unknown"))

	print("\n3. Testing to_dictionary() output...")

	for character in character_resources:
		var dict = character.to_dictionary()
		print("\nCharacter %s as dictionary:" % character.name)
		print("  background: %s" % dict.get("background", "MISSING"))
		print("  motivation: %s" % dict.get("motivation", "MISSING"))
		print("  character_class: %s" % dict.get("character_class", "MISSING"))

	print("\n=== TEST COMPLETE ===")
	print("\nExpected: Diverse backgrounds, motivations, and classes")
	print("Result: %s" % ("PASS" if _check_diversity(character_resources) else "FAIL"))

	quit(0)

func _check_diversity(characters: Array) -> bool:
	"""Check if characters have diverse backgrounds/motivations/classes"""
	var backgrounds = []
	var motivations = []
	var classes = []

	for char in characters:
		backgrounds.append(char.background)
		motivations.append(char.motivation)
		classes.append(char.character_class)

	# Check if we have at least 2 different values in each category
	var unique_backgrounds = {}
	var unique_motivations = {}
	var unique_classes = {}

	for bg in backgrounds:
		unique_backgrounds[bg] = true
	for mot in motivations:
		unique_motivations[mot] = true
	for cls in classes:
		unique_classes[cls] = true

	var diversity_ok = (
		unique_backgrounds.size() >= 2 and
		unique_motivations.size() >= 2 and
		unique_classes.size() >= 2
	)

	print("\nDiversity check:")
	print("  Unique backgrounds: %d (%s)" % [unique_backgrounds.size(), str(unique_backgrounds.keys())])
	print("  Unique motivations: %d (%s)" % [unique_motivations.size(), str(unique_motivations.keys())])
	print("  Unique classes: %d (%s)" % [unique_classes.size(), str(unique_classes.keys())])

	return diversity_ok
