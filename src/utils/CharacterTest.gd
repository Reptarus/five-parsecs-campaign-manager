extends Node

## Simple test script to verify the consolidated Character class works

const Character = preload("res://src/core/character/Character.gd")

func _ready() -> void:
	print("=== Character Class Test ===")
	_test_character_creation()
	_test_character_properties()
	_test_character_methods()
	print("=== Character Test Complete ===")

func _test_character_creation() -> void:
	print("\n--- Testing Character Creation ---")
	
	var character = Character.new()
	if character:
		print("✅ Character creation successful")
		print("  - Character ID: ", character.character_id)
		print("  - Character Name: ", character.character_name)
		print("  - Character Class: ", character.character_class)
	else:
		print("❌ Character creation failed")

func _test_character_properties() -> void:
	print("\n--- Testing Character Properties ---")
	
	var character = Character.new()
	if not character:
		print("❌ Cannot test properties - character creation failed")
		return
	
	# Test basic properties
	character.character_name = "Test Character"
	character.character_class = 1 # SOLDIER
	character.background = 1 # MILITARY
	character.motivation = 1 # SURVIVAL
	character.origin = 1 # HUMAN
	
	# Test stats
	character.reaction = 3
	character.combat = 2
	character.toughness = 4
	character.speed = 6
	character.savvy = 1
	character.luck = 0
	
	# Test health
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	print("✅ Character properties set successfully")
	print("  - Name: ", character.character_name)
	print("  - Class: ", character.character_class)
	print("  - Health: ", character.health, "/", character.max_health)
	print("  - Stats: R=", character.reaction, " C=", character.combat, " T=", character.toughness, " S=", character.speed, " Sv=", character.savvy)

func _test_character_methods() -> void:
	print("\n--- Testing Character Methods ---")
	
	var character = Character.new()
	if not character:
		print("❌ Cannot test methods - character creation failed")
		return
	
	# Test trait system
	character.add_trait("Military Training")
	character.add_trait("Combat Experience")
	
	print("✅ Traits added successfully")
	print("  - Traits: ", character.traits)
	print("  - Has Military Training: ", character.has_trait("Military Training"))
	
	# Test stat check
	var check_result = character.roll_stat_check("combat", 4)
	print("✅ Stat check completed")
	print("  - Combat check vs 4: ", check_result)
	
	# Test character description
	var description = character.get_character_description()
	print("✅ Character description generated")
	print("  - Description: ", description)
	
	# Test character summary
	var summary = character.get_character_summary()
	print("✅ Character summary generated")
	print("  - Summary keys: ", summary.keys())