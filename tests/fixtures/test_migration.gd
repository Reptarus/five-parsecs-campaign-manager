@tool
extends EditorScript

## Test Migration Tool - GUT to gdUnit4
##
## This tool helps identify and migrate test files from GUT to gdUnit4.
## It analyzes test files for common migration patterns and provides guidance.

const TEST_DIR: String = "res://tests/"
const UNIT_TEST_DIR: String = "res://tests/unit/"
const INTEGRATION_TEST_DIR: String = "res://tests/integration/"
const PERFORMANCE_TEST_DIR: String = "res://tests/performance/"
const MOBILE_TEST_DIR: String = "res://tests/mobile/"

const DOMAIN_TO_BASE_CLASS: Dictionary = {
	"unit/ui": "GdUnitGameTest",
	"unit/battle": "GdUnitGameTest",
	"unit/campaign": "GdUnitGameTest",
	"unit/enemy": "GdUnitGameTest",
	"mobile": "GdUnitGameTest",
	"unit": "GdUnitGameTest",
	"integration": "GdUnitGameTest",
	"performance": "GdUnitGameTest"
}

enum IssueType {
	WRONG_EXTENSION,
	MISSING_SUPER_CALLS,
	OLD_ASSERTION_PATTERN,
	OLD_SIGNAL_PATTERN,
	OLD_LIFECYCLE_METHODS
}

var _issues: Dictionary = {}
var _stats: Dictionary = {
	"total_files": 0,
	"files_with_issues": 0,
	"issues_by_type": {}
}

func _run() -> void:
	print("\n=== GUT to gdUnit4 Migration Tool ===\n")
	
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
	var expected_base: String = DOMAIN_TO_BASE_CLASS.get(domain, "GdUnitGameTest")
	
	if not correct_extension_pattern(content, expected_base):
		file_issues.append({
			"type": IssueType.WRONG_EXTENSION,
			"description": "Should extend %s for gdUnit4" % expected_base,
			"expected": "extends %s" % expected_base
		})
		_stats.issues_by_type[IssueType.WRONG_EXTENSION] += 1
	
	# Check super calls - gdUnit4 uses before()/after() instead of before_each()/after_each()
	if not has_correct_gdunit4_lifecycle(content):
		file_issues.append({
			"type": IssueType.MISSING_SUPER_CALLS,
			"description": "Missing proper gdUnit4 lifecycle methods (before/after instead of before_each/after_each)",
			"expected": "Use before(), after(), before_test(), after_test() methods"
		})
		_stats.issues_by_type[IssueType.MISSING_SUPER_CALLS] += 1
	
	# Check assertion patterns - gdUnit4 uses assert_that() instead of assert_eq()
	if has_old_assertion_patterns(content):
		file_issues.append({
			"type": IssueType.OLD_ASSERTION_PATTERN,
			"description": "Using old GUT assertion patterns",
			"expected": "Replace assert_eq() with assert_that().is_equal(), etc."
		})
		_stats.issues_by_type[IssueType.OLD_ASSERTION_PATTERN] += 1
	
	# Check signal patterns - gdUnit4 uses different signal testing
	if has_old_signal_patterns(content):
		file_issues.append({
			"type": IssueType.OLD_SIGNAL_PATTERN,
			"description": "Using old GUT signal testing patterns",
			"expected": "Replace watch_signals() with monitor_signals(), assert_signal_emitted() with assert_signal().is_emitted()"
		})
		_stats.issues_by_type[IssueType.OLD_SIGNAL_PATTERN] += 1
	
	# Check lifecycle methods
	if has_old_lifecycle_methods(content):
		file_issues.append({
			"type": IssueType.OLD_LIFECYCLE_METHODS,
			"description": "Using old GUT lifecycle methods",
			"expected": "Replace before_each()/after_each() with before_test()/after_test()"
		})
		_stats.issues_by_type[IssueType.OLD_LIFECYCLE_METHODS] += 1
	
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

func has_correct_gdunit4_lifecycle(content: String) -> bool:
	var has_before: bool = content.find("func before") != -1
	var has_after: bool = content.find("func after") != -1
	
	var has_before_test: bool = content.find("func before_test") != -1
	var has_after_test: bool = content.find("func after_test") != -1
	
	# If these methods exist, they should call their super equivalents
	if has_before and not has_before_test:
		return false
	
	if has_after and not has_after_test:
		return false
	
	return true

func has_old_assertion_patterns(content: String) -> bool:
	var assert_eq_pattern: String = "assert_eq("
	var assert_that_pattern: String = "assert_that("
	
	var assert_eq_count: int = count_occurrences(content, assert_eq_pattern)
	var assert_that_count: int = count_occurrences(content, assert_that_pattern)
	
	if assert_eq_count > 0 and assert_that_count == 0:
		return true
	
	return false

func has_old_signal_patterns(content: String) -> bool:
	var watch_signals_pattern: String = "watch_signals("
	var monitor_signals_pattern: String = "monitor_signals("
	var assert_signal_emitted_pattern: String = "assert_signal_emitted("
	var assert_signal_pattern: String = "assert_signal("
	
	var watch_signals_count: int = count_occurrences(content, watch_signals_pattern)
	var monitor_signals_count: int = count_occurrences(content, monitor_signals_pattern)
	var assert_signal_emitted_count: int = count_occurrences(content, assert_signal_emitted_pattern)
	var assert_signal_count: int = count_occurrences(content, assert_signal_pattern)
	
	if watch_signals_count > 0 and monitor_signals_count == 0:
		return true
	
	if assert_signal_emitted_count > 0 and assert_signal_count == 0:
		return true
	
	return false

func has_old_lifecycle_methods(content: String) -> bool:
	var before_each_pattern: String = "before_each()"
	var after_each_pattern: String = "after_each()"
	var before_test_pattern: String = "before_test()"
	var after_test_pattern: String = "after_test()"
	
	var before_each_count: int = count_occurrences(content, before_each_pattern)
	var after_each_count: int = count_occurrences(content, after_each_pattern)
	var before_test_count: int = count_occurrences(content, before_test_pattern)
	var after_test_count: int = count_occurrences(content, after_test_pattern)
	
	if before_each_count > 0 and before_test_count == 0:
		return true
	
	if after_each_count > 0 and after_test_count == 0:
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
	var instructions: String = "## GUT to gdUnit4 Migration Instructions\n\n"
	
	instructions += "To migrate test files from GUT to gdUnit4, follow these steps:\n\n"
	instructions += "1. Update the extends statement to use gdUnit4 base classes:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # GUT:\n"
	instructions += "   extends \"res://addons/gut/test.gd\"\n"
	instructions += "   \n"
	instructions += "   # gdUnit4:\n"
	instructions += "   extends GdUnitGameTest  # or GdUnitTestSuite for basic tests\n"
	instructions += "   ```\n\n"
	
	instructions += "2. Update lifecycle methods to gdUnit4 patterns:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # GUT:\n"
	instructions += "   func before_each():\n"
	instructions += "       # setup code\n"
	instructions += "   \n"
	instructions += "   func after_each():\n"
	instructions += "       # cleanup code\n"
	instructions += "   \n"
	instructions += "   # gdUnit4:\n"
	instructions += "   func before_test():\n"
	instructions += "       super.before_test()\n"
	instructions += "       # setup code\n"
	instructions += "   \n"
	instructions += "   func after_test():\n"
	instructions += "       # cleanup code\n"
	instructions += "       super.after_test()\n"
	instructions += "   ```\n\n"
	
	instructions += "3. Replace GUT assertions with gdUnit4 fluent API:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # GUT:\n"
	instructions += "   assert_eq(actual, expected)\n"
	instructions += "   assert_ne(actual, expected)\n"
	instructions += "   assert_null(value)\n"
	instructions += "   assert_not_null(value)\n"
	instructions += "   \n"
	instructions += "   # gdUnit4:\n"
	instructions += "   assert_that(actual).is_equal(expected)\n"
	instructions += "   assert_that(actual).is_not_equal(expected)\n"
	instructions += "   assert_that(value).is_null()\n"
	instructions += "   assert_that(value).is_not_null()\n"
	instructions += "   ```\n\n"
	
	instructions += "4. Update signal testing patterns:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # GUT:\n"
	instructions += "   watch_signals(object)\n"
	instructions += "   assert_signal_emitted(object, \"signal_name\")\n"
	instructions += "   \n"
	instructions += "   # gdUnit4:\n"
	instructions += "   monitor_signals(object)\n"
	instructions += "   assert_signal(object).is_emitted(\"signal_name\")\n"
	instructions += "   ```\n\n"
	
	instructions += "5. Use gdUnit4 resource tracking:\n"
	instructions += "   ```gdscript\n"
	instructions += "   # gdUnit4:\n"
	instructions += "   var node = Node.new()\n"
	instructions += "   track_node(node)  # Automatic cleanup\n"
	instructions += "   \n"
	instructions += "   var resource = Resource.new()\n"
	instructions += "   track_resource(resource)  # Automatic cleanup\n"
	instructions += "   ```\n\n"
	
	return instructions