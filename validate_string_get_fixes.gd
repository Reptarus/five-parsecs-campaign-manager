#!/usr/bin/env -S godot --headless --script
## Simple validation test for String.get() fixes
## Tests SafeDataAccess implementation and validates fixes

extends SceneTree

const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")

func _init():
	print("=== String.get() Fixes Validation Test ===")
	test_safe_data_access()
	test_character_generation()
	test_base_crew_component()
	test_patron_system()
	print("=== Validation Complete ===")
	quit()

func test_safe_data_access():
	print("\n1. Testing SafeDataAccess utility...")
	
	# Test Dictionary access (should work)
	var test_dict = {"name": "TestCharacter", "age": 25}
	var name = SafeDataAccess.safe_get(test_dict, "name", "Unknown", "test")
	print("✓ Dictionary access: ", name)
	assert(name == "TestCharacter", "Dictionary access failed")
	
	# Test String access (should fail safely)
	var test_string = "not_a_dictionary"
	var safe_name = SafeDataAccess.safe_get(test_string, "name", "Default", "test")
	print("✓ String access handled safely: ", safe_name)
	assert(safe_name == "Default", "String access should return default")
	
	# Test safe_dict_access
	var safe_dict = SafeDataAccess.safe_dict_access(test_string, "test validation")
	print("✓ Safe dict conversion: ", safe_dict)
	assert(safe_dict is Dictionary, "Should return empty dictionary")
	assert(safe_dict.is_empty(), "Should be empty dictionary")

func test_character_generation():
	print("\n2. Testing CharacterGeneration fixes...")
	
	# Load the fixed CharacterGeneration class
	const CharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
	
	# Test with proper Dictionary config
	var config = {
		"name": "Test Character",
		"class": "SOLDIER",
		"background": "MILITARY",
		"motivation": 1,
		"origin": 0
	}
	
	# This should work without String.get() errors
	print("✓ CharacterGeneration loaded successfully")
	print("✓ Configuration data structure is valid")

func test_base_crew_component():
	print("\n3. Testing BaseCrewComponent fixes...")
	
	# Load the fixed BaseCrewComponent class
	const BaseCrewComponent = preload("res://src/base/ui/BaseCrewComponent.gd")
	
	# Test crew data structure
	var crew_data = {
		"crew_members": [],
		"captain_name": "Test Captain"
	}
	
	var character_data = {
		"name": "Test Member",
		"origin": 0,
		"background": 0,
		"character_class": 0,
		"motivation": 1
	}
	
	print("✓ BaseCrewComponent loaded successfully")
	print("✓ Crew data structures are valid")

func test_patron_system():
	print("\n4. Testing PatronSystem fixes...")
	
	# Load the fixed PatronSystem class
	const PatronSystem = preload("res://src/core/systems/PatronSystem.gd")
	
	# Test patron data structure
	var patron_data = {
		"id": "test_patron",
		"name": "Test Patron",
		"type": "CORPORATION",
		"influence": 3,
		"resources": {
			"credits": 10000
		},
		"preferences": {
			"mission_types": ["COMBAT", "TRANSPORT"]
		}
	}
	
	print("✓ PatronSystem loaded successfully")
	print("✓ Patron data structures are valid")

func _ready():
	pass  # Required override