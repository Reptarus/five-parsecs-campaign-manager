# Simple integration test to verify our changes work
extends SceneTree

func _init() -> void:
	print("=== Five Parsecs Campaign Manager Integration Test ===")
	test_autoloads()
	test_scene_files()
	quit()

func test_autoloads() -> void:
	print("\n1. Testing Autoload Configuration:")
	
	# Test if autoloads are configured
	var autoloads = ["AlphaGameManager", "CampaignManager", "DiceManager"]
	for autoload_name in autoloads:
		if has_meta(autoload_name) or Engine.has_singleton(autoload_name):
			print("  ✓ %s: Found in autoloads" % autoload_name)
		else:
			print("  ✗ %s: NOT found in autoloads" % autoload_name)

func test_scene_files() -> void:
	print("\n2. Testing Scene File Existence:")
	
	var required_scenes = [
		"res://src/scenes/main/MainGameScene.tscn",
		"res://src/ui/screens/campaign/CampaignDashboard.tscn",
		"res://src/ui/screens/world/WorldPhaseUI.tscn",
		"res://src/ui/screens/battle/BattleResolutionUI.tscn"
	]
	
	for scene_path in required_scenes:
		if ResourceLoader.exists(scene_path):
			print("  ✓ %s: EXISTS" % scene_path.get_file())
		else:
			print("  ✗ %s: MISSING" % scene_path.get_file())

	print("\n3. Testing Script Files:")
	var script_files = [
		"res://src/core/managers/AlphaGameManager.gd",
		"res://src/core/managers/CampaignManager.gd",
		"res://src/core/managers/DiceManager.gd",
		"res://src/core/systems/DiceSystem.gd"
	]
	
	for script_path in script_files:
		if ResourceLoader.exists(script_path):
			print("  ✓ %s: EXISTS" % script_path.get_file())
		else:
			print("  ✗ %s: MISSING" % script_path.get_file())

	print("\n=== Integration Test Complete ===")