## Simple test runner script for Godot console execution
extends SceneTree

const HybridDataArchitectureTester = preload("res://data_architecture_test.gd")

func _init():
	print("🧪 STARTING FIVE PARSECS HYBRID DATA ARCHITECTURE TESTING")
	print("======================================================================")
	
	# Execute the comprehensive testing protocol
	var results = HybridDataArchitectureTester.execute_testing_protocol()
	
	print("\n🏁 TESTING COMPLETE")
	print("======================================================================")
	
	# Exit Godot
	quit()