extends Node

## Scene-Script Consistency Validation Script
## Run this to validate that all critical scenes load correctly

func validate_scene_script_consistency():
	print("=== Five Parsecs Campaign Manager Scene Validation ===")
	
	var scenes_to_check = [
		"res://src/ui/screens/character/CharacterCreator.tscn",
		"res://src/ui/screens/campaign/panels/CrewPanel.tscn", 
		"res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
		"res://src/ui/screens/campaign/panels/FinalPanel.tscn",
		"res://src/ui/screens/campaign/CampaignCreationUI.tscn",
		"res://src/ui/components/character/CharacterSheet.tscn",
		"res://src/ui/components/dialogs/QuickStartDialog.tscn"
	]
	
	var success_count = 0
	var failure_count = 0
	
	for scene_path in scenes_to_check:
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path)
			if scene:
				var instance = scene.instantiate()
				if instance:
					print("✅ Scene loads successfully: ", scene_path)
					instance.queue_free()
					success_count += 1
				else:
					print("❌ Failed to instantiate scene: ", scene_path)
					failure_count += 1
			else:
				print("❌ Failed to load scene: ", scene_path)
				failure_count += 1
		else:
			print("❌ Scene file not found: ", scene_path)
			failure_count += 1
	
	print("\n=== VALIDATION RESULTS ===")
	print("✅ Successful: ", success_count)
	print("❌ Failed: ", failure_count)
	
	if failure_count == 0:
		print("🎉 ALL SCENES VALIDATED SUCCESSFULLY!")
		return true
	else:
		print("⚠️  SOME SCENES FAILED VALIDATION")
		return false

func _ready():
	validate_scene_script_consistency()