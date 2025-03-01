@tool
extends EditorScript

## Test Migration Tool
##
## This tool helps identify and fix inconsistencies in test files.
## It analyzes test files for common issues and provides guidance on fixing them.

const TEST_DIR: String = "res://tests/"
const UNIT_TEST_DIR: String = "res://tests/unit/"
const INTEGRATION_TEST_DIR: String = "res://tests/integration/"
const PERFORMANCE_TEST_DIR: String = "res://tests/performance/"
const MOBILE_TEST_DIR: String = "res://tests/mobile/"

const DOMAIN_TO_BASE_CLASS: Dictionary = {
	"unit/ui": "UITest",
	"unit/battle": "BattleTest",
	"unit/campaign": "CampaignTest",
	"unit/enemy": "EnemyTest",
	"mobile": "MobileTest",
	"unit": "GameTest",
	"integration": "GameTest",
	"performance": "GameTest"
}

enum IssueType {
	WRONG_EXTENSION,
	MISSING_SUPER_CALLS,
	MISSING_TYPE_SAFETY,
	INCONSISTENT_RESOURCE_MANAGEMENT,
	DIRECT_METHOD_CALLS
}

var _issues: Dictionary = {}
var _stats: Dictionary = {
	"total_files": 0,
	"files_with_issues": 0,
	"issues_by_type": {}
}

func _run() -> void:
	print("\n=== Test Migration Tool ===\n")
	
	# Initialize stats
	for issue: int in IssueType.values():
		_stats.issues_by_type[issue] = 0
	
	# Scan directories
	scan_directory(UNIT_TEST_DIR)
	scan_directory(INTEGRATION_TEST_DIR)
	scan_directory(PERFORMANCE_TEST_DIR)
	scan_directory(MOBILE_TEST_DIR)
	
	# Print results
	print_results()
	
	# Generate migration report
	generate_migration_report()

func scan_directory(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			var full_path: String = dir_path + file_name
			
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				scan_directory(full_path + "/")
			elif file_name.ends_with(".gd") and file_name.begins_with("test_"):
				analyze_test_file(full_path)
			
			file_name = dir.get_next()

func analyze_test_file(file_path: String) -> void:
	_stats.total_files += 1
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	
	var content: String = file.get_as_text()
	var file_issues: Array = []
	
	# Check extends statement
	var domain: String = get_domain_for_file(file_path)
	var expected_base: String = DOMAIN_TO_BASE_CLASS.get(domain, "GameTest")
	
	if not correct_extension_pattern(content, expected_base):
		file_issues.append({
			"type": IssueType.WRONG_EXTENSION,
			"description": "Should extend " + expected_base + " directly using class_name",
			"expected": "extends " + expected_base
		})
		_stats.issues_by_type[IssueType.WRONG_EXTENSION] += 1
	
	# Check super calls
	if not has_correct_super_calls(content):
		file_issues.append({
			"type": IssueType.MISSING_SUPER_CALLS,
			"description": "Missing proper super.before_each() or super.after_each() calls",
			"expected": "await super.before_each() and await super.after_each()"
		})
		_stats.issues_by_type[IssueType.MISSING_SUPER_CALLS] += 1
	
	# Check type safety
	if has_missing_type_safety(content):
		file_issues.append({
			"type": IssueType.MISSING_TYPE_SAFETY,
			"description": "Missing type-safe method calls",
			"expected": "Replace direct method calls with TypeSafeMixin.*_call_node_method_* variants"
		})
		_stats.issues_by_type[IssueType.MISSING_TYPE_SAFETY] += 1
	
	# Check resource management
	if has_inconsistent_resource_management(content):
		file_issues.append({
			"type": IssueType.INCONSISTENT_RESOURCE_MANAGEMENT,
			"description": "Inconsistent resource management",
			"expected": "Use add_child_autofree() and track_test_resource() consistently"
		})
		_stats.issues_by_type[IssueType.INCONSISTENT_RESOURCE_MANAGEMENT] += 1
	
	# Check direct method calls
	if has_direct_method_calls(content):
		file_issues.append({
			"type": IssueType.DIRECT_METHOD_CALLS,
			"description": "Contains direct method calls without type safety",
			"expected": "Replace obj.method() with _call_node_method*(obj, 'method', [])"
		})
		_stats.issues_by_type[IssueType.DIRECT_METHOD_CALLS] += 1
	
	if file_issues.size() > 0:
		_issues[file_path] = file_issues
		_stats.files_with_issues += 1

func get_domain_for_file(file_path: String) -> String:
	var relative_path: String = file_path.replace(TEST_DIR, "")
	var parts: PackedStringArray = relative_path.split("/")
	
	if parts.size() >= 2:
		return parts[0] + "/" + parts[1]
	
	return parts[0]

func correct_extension_pattern(content: String, expected_base: String) -> bool:
	# Check for direct extension of the base class
	if content.find("extends " + expected_base) != -1:
		return true
	
	# Check for preload-based extension
	var preload_pattern: String = "extends \"res://tests/fixtures"
	return content.find(preload_pattern) == -1

func has_correct_super_calls(content: String) -> bool:
	var has_before_each: bool = content.find("func before_each") != -1
	var has_after_each: bool = content.find("func after_each") != -1
	
	var has_super_before: bool = content.find("super.before_each()") != -1
	var has_super_after: bool = content.find("super.after_each()") != -1
	
	# If these methods exist, they should call their super equivalents
	if has_before_each and not has_super_before:
		return false
	
	if has_after_each and not has_super_after:
		return false
	
	return true

func has_missing_type_safety(content: String) -> bool:
	var safe_pattern: String = "TypeSafeMixin._"
	var safe_calls_count: int = count_occurrences(content, safe_pattern)
	
	var unsafe_patterns: Array = [
		".get_node(",
		".get_parent(",
		".find_node(",
		".has_node("
	]
	
	var total_calls_count: int = safe_calls_count
	for pattern in unsafe_patterns:
		total_calls_count += count_occurrences(content, pattern)
	
	if total_calls_count > 0 and (float(safe_calls_count) / total_calls_count) < 0.7:
		return true
	
	return false

func count_occurrences(text: String, pattern: String) -> int:
	var count: int = 0
	var position: int = 0
	
	position = text.find(pattern, position)
	while position != -1:
		count += 1
		position = text.find(pattern, position + 1)
	
	return count

func has_direct_method_calls(content: String) -> bool:
	var safe_call_patterns: Array = [
		"_call_node_method(",
		"_call_node_method_bool(",
		"_call_node_method_int(",
		"_call_node_method_float(",
		"_call_node_method_string(",
		"_call_node_method_dict(",
		"_call_node_method_array("
	]
	
	var safe_calls_count: int = 0
	for pattern in safe_call_patterns:
		safe_calls_count += count_occurrences(content, pattern)
	
	var method_call_pattern: String = ".call("
	var direct_dot_calls: int = count_occurrences(content, method_call_pattern)
	var total_calls_count: int = safe_calls_count + direct_dot_calls
	
	if total_calls_count > 0 and (float(safe_calls_count) / total_calls_count) < 0.7:
		return true
	
	return false

func has_inconsistent_resource_management(content: String) -> bool:
	var has_add_child: bool = content.find("add_child(") != -1
	var has_add_child_autofree: bool = content.find("add_child_autofree(") != -1
	var has_track_test_node: bool = content.find("track_test_node(") != -1
	
	# If using add_child without tracking
	if has_add_child and not has_track_test_node and not has_add_child_autofree:
		return true
	
	return false

func print_results() -> void:
	print("Analyzed %d test files" % _stats.total_files)
	print("Found issues in %d files" % _stats.files_with_issues)
	print("\nIssues by type:")
	
	for issue: int in IssueType.values():
		var count: int = _stats.issues_by_type.get(issue, 0)
		print("- %s: %d files" % [IssueType.keys()[issue], count])
	
	print("\nTop files with most issues:")
	var sorted_files: Array = []
	
	for file_path in _issues:
		sorted_files.append({
			"path": file_path,
			"count": _issues[file_path].size()
		})
	
	sorted_files.sort_custom(func(a, b): return a.count > b.count)
	
	for i in range(min(5, sorted_files.size())):
		var file_info: Dictionary = sorted_files[i]
		print("- %s: %d issues" % [file_info.path, file_info.count])

func generate_migration_report() -> void:
	var report: String = "# Test Migration Report\n\n"
	report += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	
	report += "## Summary\n"
	report += "- Total test files: %d\n" % _stats.total_files
	report += "- Files with issues: %d\n" % _stats.files_with_issues
	report += "- Migration completion: %.1f%%\n\n" % (((_stats.total_files - _stats.files_with_issues) / float(_stats.total_files)) * 100)
	
	report += "## Issues by Type\n"
	for issue: int in IssueType.values():
		var count: int = _stats.issues_by_type.get(issue, 0)
		report += "- %s: %d files\n" % [IssueType.keys()[issue], count]
	
	report += "\n## Files Requiring Migration\n\n"
	
	for file_path in _issues:
		report += "### %s\n" % file_path
		
		for issue in _issues[file_path]:
			report += "- **%s**: %s\n" % [IssueType.keys()[issue.type], issue.description]
			report += "  - Expected: `%s`\n" % issue.expected
		
		report += "\n"
	
	# Write migration instructions
	var file: FileAccess = FileAccess.open("res://tests/migration_report.md", FileAccess.WRITE)
	if file:
		file.store_string(report)
		print("Migration report generated: 'res://tests/migration_report.md'")
	else:
		push_error("Failed to create migration report file")

func generate_migration_instructions() -> String:
	var instructions: String = "## Migration Instructions\n\n"
	
	instructions += "To standardize test files, follow these steps for each file:\n\n"
	instructions += "1. Update the extends statement to use the proper class_name:\n"
	instructions += "   ```gdscript\n"
	instructions += "   @tool\n"
	instructions += "   extends UITest  # Instead of extends \"res://tests/fixtures/specialized/ui_test.gd\"\n"
	instructions += "   ```\n\n"
	
	instructions += "2. Ensure proper super calls in lifecycle methods:\n"
	instructions += "   ```gdscript\n"
	instructions += "   func before_each() -> void:\n"
	instructions += "       await super.before_each()\n"
	instructions += "       # Setup code\n"
	instructions += "   \n"
	instructions += "   func after_each() -> void:\n"
	instructions += "       # Cleanup code\n"
	instructions += "       await super.after_each()\n"
	instructions += "   ```\n\n"
	
	instructions += "3. Replace direct method calls with type-safe alternatives:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # Instead of:\n"
	instructions += "   var result = node.method(param1, param2)\n"
	instructions += "   \n"
	instructions += "   # Use:\n"
	instructions += "   var result = _call_node_method_type(node, \"method\", [param1, param2], default_value)\n"
	instructions += "   ```\n\n"
	
	instructions += "4. Use proper resource management:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # Instead of:\n"
	instructions += "   add_child(node)\n"
	instructions += "   \n"
	instructions += "   # Use:\n"
	instructions += "   add_child_autofree(node)  # For nodes\n"
	instructions += "   track_test_resource(resource)  # For resources\n"
	instructions += "   ```\n\n"
	
	return instructions