extends Node
class_name PanelDiagnostics

## Panel Diagnostics Tool for Five Parsecs Campaign Manager
## Validates signal connections and panel replacement architecture

static func run_diagnostics(campaign_ui: Node) -> Dictionary:
	## Run comprehensive diagnostics on panel system
	var results = {
		"coordinator_type": "",
		"panel_clearing": [],
		"signal_connections": [],
		"content_container": "",
		"overlay_detection": [],
		"errors": []
	}
	
	# Check coordinator type
	if campaign_ui.has_method("get_coordinator"):
		var coordinator = campaign_ui.get("coordinator")
		if coordinator:
			results.coordinator_type = coordinator.get_class()
			if not coordinator is Node:
				results.errors.append("CRITICAL: Coordinator is not a Node type!")
		else:
			results.errors.append("Coordinator is null")
	
	# Verify panel clearing mechanism
	if campaign_ui.has_method("_clear_current_panel"):
		results.panel_clearing.append("_clear_current_panel method exists")
		
		# Check for parentheses in function calls
		var script_source = campaign_ui.get_script().source_code if campaign_ui.get_script() else ""
		var missing_parens = []
		var lines = script_source.split("\n")
		for i in range(lines.size()):
			var line = lines[i]
			if "_clear_current_panel" in line and not "_clear_current_panel()" in line and not "func _clear_current_panel" in line:
				missing_parens.append("Line %d: Missing parentheses on _clear_current_panel" % [i + 1])
		
		if missing_parens.size() > 0:
			results.errors.append_array(missing_parens)
		else:
			results.panel_clearing.append("All _clear_current_panel calls have parentheses")
	
	# Check content container
	if campaign_ui.has_node("ContentArea/RightPanel"):
		results.content_container = "ContentArea/RightPanel exists"
		var container = campaign_ui.get_node("ContentArea/RightPanel")
		var child_count = container.get_child_count()
		if child_count > 1:
			results.overlay_detection.append("WARNING: Multiple panels detected (%d children)" % child_count)
			for child in container.get_children():
				results.overlay_detection.append("  - %s (visible: %s)" % [child.name, child.visible])
	else:
		results.errors.append("Content container not found")
	
	# Check signal connections
	if campaign_ui.has_signal("phase_transition_started"):
		var connections = campaign_ui.get_signal_connection_list("phase_transition_started")
		results.signal_connections.append("phase_transition_started has %d connections" % connections.size())
	
	# Verify panel scenes dictionary
	if campaign_ui.has_method("get_panel_scenes"):
		var panel_scenes = campaign_ui.get("panel_scenes")
		if panel_scenes:
			for phase in panel_scenes:
				var scene_path = panel_scenes[phase]
				if not ResourceLoader.exists(scene_path):
					results.errors.append("Missing panel scene: %s" % scene_path)
	
	return results

static func print_diagnostic_report(results: Dictionary) -> void:
	## Print formatted diagnostic report
	print("\n========== PANEL SYSTEM DIAGNOSTICS ==========")
	
	print("\n[COORDINATOR STATUS]")
	print("  Type: %s" % results.coordinator_type)
	if results.coordinator_type == "Node":
		print("  ✓ Coordinator type is correct")
	else:
		print("  ✗ CRITICAL: Coordinator should extend Node!")
	
	print("\n[PANEL CLEARING]")
	for item in results.panel_clearing:
		print("  %s" % item)
	
	print("\n[SIGNAL CONNECTIONS]")
	for item in results.signal_connections:
		print("  %s" % item)
	
	print("\n[CONTENT CONTAINER]")
	print("  %s" % results.content_container)
	
	if results.overlay_detection.size() > 0:
		print("\n[OVERLAY DETECTION]")
		for item in results.overlay_detection:
			print("  %s" % item)
	
	if results.errors.size() > 0:
		print("\n[ERRORS FOUND]")
		for error in results.errors:
			print("  ✗ %s" % error)
	else:
		print("\n[STATUS]")
		print("  ✓ No critical errors detected")
	
	print("\n==============================================\n")
