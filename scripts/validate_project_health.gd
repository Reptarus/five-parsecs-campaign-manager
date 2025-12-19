@tool
extends SceneTree

## Project Health Validation Script
## Run with: godot --headless --script scripts/validate_project_health.gd --quit

var health_report = {
	"critical_issues": [],
	"warnings": [],
	"passed_checks": [],
	"overall_status": "UNKNOWN"
}

func _init():
	print("=== Five Parsecs Campaign Manager - Health Check ===")
	run_health_checks()
	generate_report()
	quit()

func run_health_checks():
	print("\n🔍 Running comprehensive health checks...")
	
	# Critical Checks
	check_duplicate_declarations()
	check_campaign_creation_flow()
	check_autoload_consistency()
	check_signal_connections()
	
	# Warning Checks  
	check_todo_comments()
	check_resource_files()
	check_backup_files()
	
	# Performance Checks
	check_scene_loading_performance()

func check_duplicate_declarations():
	print("\n1. Checking for duplicate declarations...")
	var campaign_ui_path = "res://src/ui/screens/campaign/CampaignCreationUI.gd"
	
	if not ResourceLoader.exists(campaign_ui_path):
		health_report.critical_issues.append("CampaignCreationUI.gd not found at expected path")
		return
	
	var file = FileAccess.open(campaign_ui_path, FileAccess.READ)
	if not file:
		health_report.critical_issues.append("Cannot read CampaignCreationUI.gd")
		return
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var variable_declarations = {}
	var function_declarations = {}
	var line_num = 0
	
	for line in lines:
		line_num += 1
		var trimmed = line.strip_edges()
		
		# Check for variable declarations
		if trimmed.begins_with("var "):
			var var_name = trimmed.split(" ")[1].split(":")[0].split("=")[0]
			if variable_declarations.has(var_name):
				health_report.critical_issues.append("Duplicate variable '%s' at line %d (first at %d)" % [var_name, line_num, variable_declarations[var_name]])
			else:
				variable_declarations[var_name] = line_num
		
		# Check for function declarations
		if trimmed.begins_with("func "):
			var func_name = trimmed.split("(")[0].replace("func ", "")
			if function_declarations.has(func_name):
				health_report.critical_issues.append("Duplicate function '%s' at line %d (first at %d)" % [func_name, line_num, function_declarations[func_name]])
			else:
				function_declarations[func_name] = line_num
	
	if health_report.critical_issues.is_empty():
		health_report.passed_checks.append("✅ No duplicate declarations found")

func check_campaign_creation_flow():
	print("\n2. Testing campaign creation workflow...")
	
	# Test coordinator initialization
	var CampaignCoordinator = load("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
	if not CampaignCoordinator:
		health_report.critical_issues.append("Cannot load CampaignCreationCoordinator")
		return
	
	var coordinator = CampaignCoordinator.new()
	if not coordinator:
		health_report.critical_issues.append("Cannot instantiate CampaignCreationCoordinator")
		return
	
	# Test data flow
	var test_data = {
		"campaign_name": "Health Check Campaign",
		"victory_conditions": {"is_complete": true}
	}
	
	coordinator.update_campaign_config_state(test_data)
	var state = coordinator.get_unified_campaign_state()
	
	if state.campaign_config.campaign_name != "Health Check Campaign":
		health_report.critical_issues.append("Campaign data flow broken - config data not stored properly")
	else:
		health_report.passed_checks.append("✅ Campaign creation data flow working")
	
	coordinator.queue_free()

func check_autoload_consistency():
	print("\n3. Checking autoload consistency...")
	
	# Expected autoloads from project.godot
	var expected_autoloads = [
		"GlobalEnums",
		"GameState", 
		"GameStateManagerAutoload",
		"DataManagerAutoload",
		"DiceManager",
		"SaveManager",
		"CampaignManager",
		"CampaignStateService",
		"SceneRouter",
		"CampaignPhaseManager",
		"BattleResultsManager"
	]
	
	var missing_autoloads = []
	for autoload_name in expected_autoloads:
		var autoload_node = get_root().get_node_or_null(autoload_name)
		if not autoload_node:
			missing_autoloads.append(autoload_name)
	
	if not missing_autoloads.is_empty():
		health_report.critical_issues.append("Missing autoloads: " + str(missing_autoloads))
	else:
		health_report.passed_checks.append("✅ All expected autoloads available")

func check_signal_connections():
	print("\n4. Checking signal connection health...")
	
	# Test CampaignCreationUI signal setup
	var CampaignCreationUI = load("res://src/ui/screens/campaign/CampaignCreationUI.gd")
	if not CampaignCreationUI:
		health_report.warnings.append("Cannot load CampaignCreationUI for signal test")
		return
	
	var ui = CampaignCreationUI.new()
	if ui.has_method("_initialize_coordinator"):
		ui._initialize_coordinator()
		
		if ui.coordinator:
			health_report.passed_checks.append("✅ CampaignCreationUI coordinator initialization working")
		else:
			health_report.warnings.append("CampaignCreationUI coordinator not initialized properly")
	else:
		health_report.warnings.append("CampaignCreationUI missing _initialize_coordinator method")
	
	ui.queue_free()

func check_todo_comments():
	print("\n5. Scanning for TODO/FIXME comments...")
	
	var todo_files = []
	_scan_directory_for_todos("res://src/", todo_files)
	
	if todo_files.size() > 20:
		health_report.warnings.append("High number of TODO/FIXME comments: %d files affected" % todo_files.size())
	elif todo_files.size() > 0:
		health_report.warnings.append("TODO/FIXME comments found in %d files" % todo_files.size())
	else:
		health_report.passed_checks.append("✅ No TODO/FIXME comments found")

func _scan_directory_for_todos(dir_path: String, result_files: Array):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory_for_todos(full_path, result_files)
		elif file_name.ends_with(".gd"):
			if _file_contains_todos(full_path):
				result_files.append(full_path)
		
		file_name = dir.get_next()

func _file_contains_todos(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text().to_upper()
	file.close()
	
	return content.contains("TODO") or content.contains("FIXME") or content.contains("HACK")

func check_resource_files():
	print("\n6. Checking resource file status...")
	
	var expected_resources = [
		"res://data/resources/equipment/armor.tres",
		"res://data/resources/equipment/weapons.tres",
		"res://data/resources/enemies/enemy_types.tres",
		"res://data/resources/world/crew_task_modifiers.tres"
	]
	
	var missing_resources = []
	for resource_path in expected_resources:
		if not ResourceLoader.exists(resource_path):
			missing_resources.append(resource_path)
	
	if not missing_resources.is_empty():
		health_report.warnings.append("Missing .tres resource files: " + str(missing_resources))
	else:
		health_report.passed_checks.append("✅ All expected .tres resource files exist")

func check_backup_files():
	print("\n7. Checking for cleanup-needed backup files...")
	
	var backup_patterns = [".backup", ".disabled", "_backup", "_old"]
	var cleanup_files = []
	
	_scan_directory_for_backups("res://src/", backup_patterns, cleanup_files)
	
	if cleanup_files.size() > 5:
		health_report.warnings.append("Many backup files found (%d) - consider cleanup" % cleanup_files.size())
	elif cleanup_files.size() > 0:
		health_report.warnings.append("Backup files found: %d files" % cleanup_files.size())
	else:
		health_report.passed_checks.append("✅ No excessive backup files")

func _scan_directory_for_backups(dir_path: String, patterns: Array, result_files: Array):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory_for_backups(full_path, patterns, result_files)
		else:
			for pattern in patterns:
				if file_name.contains(pattern):
					result_files.append(full_path)
					break
		
		file_name = dir.get_next()

func check_scene_loading_performance():
	print("\n8. Testing scene loading performance...")
	
	var start_time = Time.get_ticks_msec()
	var main_scene = load("res://src/ui/screens/mainmenu/MainMenu.tscn")
	var load_time = Time.get_ticks_msec() - start_time
	
	if load_time > 1000:
		health_report.warnings.append("Slow scene loading: %d ms (target: <500ms)" % load_time)
	else:
		health_report.passed_checks.append("✅ Scene loading performance good: %d ms" % load_time)

func generate_report():
	print("\n" + "=".repeat(60))
	print("🏥 PROJECT HEALTH REPORT")
	print("=".repeat(60))
	
	# Determine overall status
	if health_report.critical_issues.size() > 0:
		health_report.overall_status = "🔴 CRITICAL ISSUES FOUND"
	elif health_report.warnings.size() > 5:
		health_report.overall_status = "🟡 MULTIPLE WARNINGS"
	elif health_report.warnings.size() > 0:
		health_report.overall_status = "🟡 MINOR ISSUES"
	else:
		health_report.overall_status = "🟢 HEALTHY"
	
	print("\n📊 OVERALL STATUS: " + health_report.overall_status)
	
	# Critical Issues
	if health_report.critical_issues.size() > 0:
		print("\n🔴 CRITICAL ISSUES (%d):" % health_report.critical_issues.size())
		for issue in health_report.critical_issues:
			print("  • " + issue)
	
	# Warnings
	if health_report.warnings.size() > 0:
		print("\n🟡 WARNINGS (%d):" % health_report.warnings.size())
		for warning in health_report.warnings:
			print("  • " + warning)
	
	# Passed Checks
	if health_report.passed_checks.size() > 0:
		print("\n✅ PASSED CHECKS (%d):" % health_report.passed_checks.size())
		for check in health_report.passed_checks:
			print("  " + check)
	
	# Summary
	print("\n📈 SUMMARY:")
	print("  Critical Issues: %d" % health_report.critical_issues.size())
	print("  Warnings: %d" % health_report.warnings.size())
	print("  Passed Checks: %d" % health_report.passed_checks.size())
	
	if health_report.critical_issues.size() == 0:
		print("\n🎉 Project is ready for development!")
	else:
		print("\n⚠️  Address critical issues before proceeding.")
	
	print("\n📋 Next Steps:")
	if health_report.critical_issues.size() > 0:
		print("  1. Fix critical issues (see CLEANUP_AND_VERIFICATION_GUIDE.md)")
	if health_report.warnings.size() > 0:
		print("  2. Address warnings for optimal performance")
	print("  3. Run integration tests: godot --headless --script test_final_campaign_creation.gd")
	print("  4. Update documentation if needed")
	
	print("\n" + "=".repeat(60))