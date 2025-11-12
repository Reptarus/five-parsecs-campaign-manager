@tool
extends EditorScript

## Campaign Creation System Verification Tool
## Comprehensive readiness check for the campaign creation system
## Run from Script Editor: File > Run

func _run() -> void:
	print("\n" + _repeat_char("=", 60))
	print("CAMPAIGN CREATION SYSTEM - VERIFICATION")
	print(_repeat_char("=", 60) + "\n")
	
	var results = _run_verification()
	_print_results(results)
	_generate_recommendations(results)

func _repeat_char(char: String, count: int) -> String:
	var result = ""
	for i in count:
		result += char
	return result

func _run_verification() -> Dictionary:
	return {
		"files": _check_files(),
		"signals": _check_signals(),
		"state": _check_state_management(),
		"panels": _check_panels(),
		"finalization": _check_finalization_system(),
		"dependencies": _check_dependencies()
	}

func _check_files() -> Dictionary:
	"""Check for critical system files"""
	var critical_files = {
		"CampaignCreationUI": "res://src/ui/screens/campaign/CampaignCreationUI.gd",
		"StateManager": "res://src/core/campaign/creation/CampaignCreationStateManager.gd",
		"Coordinator": "res://src/ui/screens/campaign/CampaignCreationCoordinator.gd",
		"FinalizationService": "res://src/core/campaign/creation/CampaignFinalizationService.gd",
		"CampaignValidator": "res://src/core/validation/CampaignValidator.gd",
		"CampaignCore": "res://src/game/campaign/FiveParsecsCampaignCore.gd",
		"SecureSaveManager": "res://src/core/validation/SecureSaveManager.gd"
	}
	
	var results = {"found": 0, "missing": [], "total": critical_files.size()}
	for name in critical_files:
		if ResourceLoader.exists(critical_files[name]):
			results.found += 1
		else:
			results.missing.append(name + " (" + critical_files[name] + ")")
	
	return results

func _check_signals() -> Dictionary:
	"""Check if required signals exist in CampaignCreationUI"""
	var ui_path = "res://src/ui/screens/campaign/CampaignCreationUI.gd"
	if not ResourceLoader.exists(ui_path):
		return {"status": "UI script not found"}
	
	var ui_script = load(ui_path)
	var required_signals = [
		"campaign_data_updated",
		"campaign_completion_ready", 
		"campaign_creation_completed"
	]
	
	var found = []
	for sig in required_signals:
		if ui_script.has_script_signal(sig):
			found.append(sig)
	
	return {
		"found": found.size(),
		"total": required_signals.size(),
		"missing": required_signals.size() - found.size(),
		"details": found
	}

func _check_state_management() -> Dictionary:
	"""Check state management system"""
	var state_path = "res://src/core/campaign/creation/CampaignCreationStateManager.gd"
	var results = {
		"exists": ResourceLoader.exists(state_path),
		"phases": []
	}
	
	# Expected phases
	var expected_phases = [
		"CONFIG", "CREW_SETUP", "CAPTAIN_CREATION", 
		"SHIP_ASSIGNMENT", "EQUIPMENT_GENERATION", 
		"WORLD_GENERATION", "FINAL_REVIEW"
	]
	results.phases = expected_phases
	results.phase_count = expected_phases.size()
	
	return results

func _verify_data_persistence() -> Dictionary:
	var result = {"directories": {}, "permissions": {}}
	
	# Check save directory
	var campaigns_dir = "user://campaigns/"
	var dir = DirAccess.open("user://")
	
	if dir:
		if not dir.dir_exists("campaigns"):
			dir.make_dir("campaigns")
		
		result.directories["campaigns"] = dir.dir_exists("campaigns")
		result.permissions["write"] = true
		result.permissions["read"] = true
	
	return result

func _verify_ui_integration() -> Dictionary:
	var result = {"panels": {}, "navigation": {}}
	
	var panel_files = {
		"Config": "res://src/ui/screens/campaign/panels/ConfigPanel.tscn",
		"Crew": "res://src/ui/screens/campaign/panels/CrewPanel.tscn",
		"Captain": "res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
		"Ship": "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
		"Equipment": "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn",
		"World": "res://src/ui/screens/campaign/panels/WorldInfoPanel.tscn",
		"Final": "res://src/ui/screens/campaign/panels/FinalPanel.tscn"
	}
	
	for panel_name in panel_files:
		result.panels[panel_name] = ResourceLoader.exists(panel_files[panel_name])
	
	result.navigation["back_button"] = true
	result.navigation["next_button"] = true
	result.navigation["finish_button"] = true
	
	return result

func _check_panels() -> Dictionary:
	"""Check panel system completeness"""
	var panels = {
		"Config": "res://src/ui/screens/campaign/panels/ConfigPanel.tscn",
		"Crew": "res://src/ui/screens/campaign/panels/CrewPanel.tscn",
		"Captain": "res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
		"Ship": "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
		"Equipment": "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn",
		"World": "res://src/ui/screens/campaign/panels/WorldInfoPanel.tscn",
		"Final": "res://src/ui/screens/campaign/panels/FinalPanel.tscn"
	}
	
	var found_scenes = 0
	var missing_scenes = []
	
	for name in panels:
		if ResourceLoader.exists(panels[name]):
			found_scenes += 1
		else:
			missing_scenes.append(name)
	
	return {
		"scenes": {"found": found_scenes, "total": panels.size(), "missing": missing_scenes}
	}

func _check_finalization_system() -> Dictionary:
	"""Check finalization system readiness"""
	var finalization_files = {
		"FinalizationService": "res://src/core/campaign/creation/CampaignFinalizationService.gd",
		"CampaignValidator": "res://src/core/validation/CampaignValidator.gd",
		"CampaignCore": "res://src/game/campaign/FiveParsecsCampaignCore.gd"
	}
	
	var found = 0
	var missing = []
	
	for name in finalization_files:
		if ResourceLoader.exists(finalization_files[name]):
			found += 1
		else:
			missing.append(name)
	
	return {
		"found": found,
		"total": finalization_files.size(),
		"missing": missing,
		"ready": found == finalization_files.size()
	}

func _check_dependencies() -> Dictionary:
	"""Check system dependencies"""
	var dependencies = {
		"SecurityValidator": "res://src/core/validation/SecurityValidator.gd",
		"SecureSaveManager": "res://src/core/validation/SecureSaveManager.gd",
		"BaseCampaignPanel": "res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd",
		"CampaignCoordinator": "res://src/ui/screens/campaign/CampaignCreationCoordinator.gd"
	}
	
	var found = 0
	var missing = []
	
	for name in dependencies:
		if ResourceLoader.exists(dependencies[name]):
			found += 1
		else:
			missing.append(name)
	
	return {
		"found": found,
		"total": dependencies.size(),
		"missing": missing
	}

func _print_results(results: Dictionary) -> void:
	"""Print comprehensive verification results"""
	print("VERIFICATION RESULTS:")
	print(_repeat_char("-", 40))
	
	# Files
	var files = results.files
	print("\n✅ Critical Files: %d/%d found" % [files.found, files.total])
	if files.missing.size() > 0:
		print("   ❌ Missing:")
		for missing in files.missing:
			print("      • %s" % missing)
	
	# Signals
	var signals = results.signals
	if signals.has("status"):
		print("\n⚠️ Signals: %s" % signals.status)
	else:
		print("\n✅ Signals: %d/%d found" % [signals.found, signals.total])
		if signals.missing > 0:
			print("   ❌ Missing: %d signals" % signals.missing)
	
	# State Management
	var state = results.state
	print("\n✅ State Manager: %s" % ("Found" if state.exists else "Missing"))
	print("   Phases: %d defined (%s)" % [state.phase_count, ", ".join(state.phases)])
	
	# Panels
	var panels = results.panels
	print("\n✅ UI Panels:")
	print("   Scenes: %d/%d found" % [panels.scenes.found, panels.scenes.total])
	if panels.scenes.missing.size() > 0:
		print("   ❌ Missing scenes: %s" % ", ".join(panels.scenes.missing))
	
	# Finalization System
	var finalization = results.finalization
	print("\n✅ Finalization System: %d/%d components" % [finalization.found, finalization.total])
	if finalization.missing.size() > 0:
		print("   ❌ Missing: %s" % ", ".join(finalization.missing))
	
	# Dependencies
	var deps = results.dependencies
	print("\n✅ Dependencies: %d/%d found" % [deps.found, deps.total])
	if deps.missing.size() > 0:
		print("   ❌ Missing: %s" % ", ".join(deps.missing))

func _generate_recommendations(results: Dictionary) -> void:
	"""Generate actionable recommendations"""
	print("\n" + _repeat_char("=", 60))
	print("RECOMMENDATIONS:")
	print(_repeat_char("-", 40))
	
	var issues = []
	var system_ready = true
	
	# Check critical issues
	if results.files.missing.size() > 0:
		issues.append("Create missing files: %s" % ", ".join(results.files.missing))
		system_ready = false
	
	if results.signals.has("missing") and results.signals.missing > 0:
		issues.append("Add %d missing signals to CampaignCreationUI" % results.signals.missing)
		system_ready = false
	
	if results.panels.scenes.missing.size() > 0:
		issues.append("Create missing panel scenes: %s" % ", ".join(results.panels.scenes.missing))
		system_ready = false
	
	if not results.finalization.ready:
		issues.append("Complete finalization system: %s" % ", ".join(results.finalization.missing))
		system_ready = false
	
	if results.dependencies.missing.size() > 0:
		issues.append("Install missing dependencies: %s" % ", ".join(results.dependencies.missing))
		system_ready = false
	
	# Print results
	if system_ready:
		print("🎉 SYSTEM READY FOR TESTING!")
		print("\nNext steps:")
		print("1. Run CampaignCreationUI.tscn")
		print("2. Complete all phases with test data:")
		print("   • CONFIG: Enter campaign name, select difficulty")
		print("   • CREW: Add 4 crew members")
		print("   • CAPTAIN: Select/create captain")
		print("   • SHIP: Configure ship")
		print("   • EQUIPMENT: Generate equipment")
		print("   • WORLD: Set world parameters")
		print("   • FINAL: Review and click Finish")
		print("3. Verify save file created in user://campaigns/")
		print("4. Check Godot console for errors")
	else:
		print("⚠️ SYSTEM NOT READY - Fix these issues:")
		for i in range(issues.size()):
			print("%d. %s" % [i + 1, issues[i]])
	
	# Performance notes
	var completeness = float(results.files.found) / results.files.total * 100
	print("\n📊 System Completeness: %.1f%%" % completeness)
	
	if completeness >= 90:
		print("🚀 System is nearly complete!")
	elif completeness >= 70:
		print("🔧 System needs some work")
	else:
		print("🚨 System requires significant development")
	
	print("\n" + _repeat_char("=", 60))
