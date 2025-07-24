@tool
extends EditorScript

## Simple syntax verification for JobSelectionUI integration

func _run() -> void:
	print("=== JobSelectionUI Syntax Verification ===")
	
	# Try to load the class
	var job_selection_script = load("res://src/ui/screens/world/JobSelectionUI.gd")
	if job_selection_script:
		print("✓ JobSelectionUI.gd loads successfully")
		
		# Try to instantiate
		var instance = job_selection_script.new()
		if instance:
			print("✓ JobSelectionUI instantiates successfully")
			
			# Check key properties exist
			if instance.has_method("set_world_phase"):
				print("✓ set_world_phase method exists")
			if instance.has_method("enable_world_phase_integration"):
				print("✓ enable_world_phase_integration method exists")
			if instance.has_method("_generate_jobs_from_world_phase"):
				print("✓ _generate_jobs_from_world_phase method exists")
			
			# Check properties
			if "world_phase" in instance:
				print("✓ world_phase property exists")
			if "use_world_phase_jobs" in instance:
				print("✓ use_world_phase_jobs property exists")
			
			instance.queue_free()
		else:
			print("✗ Failed to instantiate JobSelectionUI")
	else:
		print("✗ Failed to load JobSelectionUI.gd")
	
	# Check JobDataAdapter
	var adapter_script = load("res://src/core/world_phase/JobDataAdapter.gd")
	if adapter_script:
		print("✓ JobDataAdapter.gd loads successfully")
	else:
		print("✗ Failed to load JobDataAdapter.gd")
	
	# Check WorldPhase
	var world_phase_script = load("res://src/core/campaign/phases/WorldPhase.gd")
	if world_phase_script:
		print("✓ WorldPhase.gd loads successfully")
	else:
		print("✗ Failed to load WorldPhase.gd")
	
	print("=== Verification Complete ===")