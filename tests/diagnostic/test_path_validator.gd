@tool
extends "res://addons/gut/test.gd"

# Import GutCompatibility helper for type-safe method calls
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

func test_can_resolve_campaign_test_script():
	var script_path = "res://tests/fixtures/specialized/campaign_test.gd"
	var script = load(script_path)
	assert_not_null(script, "Should be able to load campaign_test.gd")
	if script:
		print("Successfully loaded: ", script_path)

func test_can_instantiate_campaign_test_script():
	var script_path = "res://tests/fixtures/specialized/campaign_test.gd"
	var script = load(script_path)
	if script:
		var instance = script.new()
		assert_not_null(instance, "Should be able to instantiate campaign_test.gd")
		if instance:
			print("Successfully instantiated: ", script_path)
			instance.free() # Clean up

func test_resolve_test_campaign_manager():
	var script_path = "res://tests/integration/campaign/test_campaign_manager.gd"
	var script = load(script_path)
	assert_not_null(script, "Should be able to load test_campaign_manager.gd")
	if script:
		print("Successfully loaded: ", script_path)

func test_can_load_game_enums():
	var script_path = "res://src/core/systems/GlobalEnums.gd"
	var script = load(script_path)
	assert_not_null(script, "Should be able to load GlobalEnums.gd")
	if script:
		print("Successfully loaded: ", script_path)