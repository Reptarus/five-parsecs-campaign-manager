@tool
extends EditorScript

## Script to register test class names to make them available to GUT
##
## This script should be run from the Godot editor to register
## test classes and make them available for inheritance

func _run():
	print("Registering test classes...")
	
	# Register the base classes
	if ClassDB.class_exists("BaseTest"):
		print("BaseTest already registered")
	else:
		print("BaseTest is being registered")
	
	# Register specialized classes
	var specialized_classes = ["UITest", "BattleTest", "CampaignTest", "MobileTest", "EnemyTest"]
	
	for class_item in specialized_classes:
		if ClassDB.class_exists(class_item):
			print("%s already registered" % class_item)
		else:
			print("%s is being registered" % class_item)

	print("Done registering test classes. Please restart Godot to apply changes.")