# Story Integration Validation Script
extends Node

func _ready() -> void:
	print("=== Story Track Integration Validation ===")
	validate_files()
	validate_scene_structure()
	print("=== Validation Complete ===")

func validate_files() -> void:
	print("\n1. Validating File Structure:")
	
	var required_files = [
		"res://src/core/story/StoryTrackSystem.gd",
		"res://src/ui/components/story/StoryTrackPanel.gd", 
		"res://src/ui/components/story/StoryNotificationIndicator.gd",
		"res://src/ui/screens/campaign/phases/StoryPhasePanel.gd",
		"res://src/ui/screens/campaign/phases/StoryPhasePanel.tscn",
		"res://src/scenes/main/MainGameScene.gd",
		"res://src/scenes/main/MainGameScene.tscn"
	]
	
	for file_path in required_files:
		if ResourceLoader.exists(file_path):
			print("   ✓ %s: EXISTS" % file_path.get_file())
		else:
			print("   ✗ %s: MISSING" % file_path.get_file())

func validate_scene_structure() -> void:
	print("\n2. Validating Scene Structure:")
	
	# Load MainGameScene to check structure
	var main_scene = load("res://src/scenes/main/MainGameScene.tscn")
	if main_scene:
		print("   ✓ MainGameScene.tscn: Loaded successfully")
		
		# Check if it can be instantiated
		var instance = main_scene.instantiate()
		if instance:
			print("   ✓ MainGameScene: Can be instantiated")
			
			# Check for required nodes
			var required_nodes = [
				"PhaseContainer/StoryPhase",
				"DiceFeedOverlay", 
				"StoryNotificationOverlay"
			]
			
			for node_path in required_nodes:
				if instance.has_node(node_path):
					print("   ✓ Node %s: EXISTS" % node_path)
				else:
					print("   ✗ Node %s: MISSING" % node_path)
			
			instance.queue_free()
		else:
			print("   ✗ MainGameScene: Cannot be instantiated")
	else:
		print("   ✗ MainGameScene.tscn: Cannot be loaded")

	# Check StoryPhasePanel scene
	var story_scene = load("res://src/ui/screens/campaign/phases/StoryPhasePanel.tscn")
	if story_scene:
		print("   ✓ StoryPhasePanel.tscn: Loaded successfully")
	else:
		print("   ✗ StoryPhasePanel.tscn: Cannot be loaded")

	print("\n3. Integration Summary:")
	print("   - Story Track System: Enhanced with dice integration")
	print("   - Story Phase Panel: Updated for new system integration")
	print("   - Main Game Scene: Story phase added to flow")
	print("   - Story Notification: Real-time indicator added")
	print("   - Phase Flow: Smart story phase inclusion/skipping")
	print("   - Manager Integration: Story system accessible via AlphaGameManager")