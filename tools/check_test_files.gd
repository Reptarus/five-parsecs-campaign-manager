@tool
extends EditorScript

## Test File Verification Script
## 
## This script checks for GDScript files in test directories that don't follow
## standard GUT test naming conventions. It helps identify files that won't be
## picked up by GUT's test collector.
##
## Run this from the Editor -> Tools menu

func _run():
	print("\n=== FIVE PARSECS TEST VERIFICATION ===")
	print("Checking for test files that might be missed by GUT...")
	
	var test_dirs = [
		"res://tests/unit/",
		"res://tests/integration/",
		"res://tests/battle/",
		"res://tests/performance/",
		"res://tests/mobile/",
		"res://tests/diagnostic/"
	]
	
	var issues_found = 0
	
	# Check each test directory
	for test_dir in test_dirs:
		issues_found += check_directory(test_dir)
		
	if issues_found == 0:
		print("\n✅ All test files follow naming conventions!")
	else:
		print("\n❌ Found " + str(issues_found) + " test files with issues!")
		print("   These files may not be run by GUT.")
		print("   Consider renaming them to follow the pattern: test_*.gd")
		
	print("\n=== VERIFICATION COMPLETE ===")

func check_directory(path: String, recurse: bool = true) -> int:
	var issues = 0
	var dir = DirAccess.open(path)
	
	if not dir:
		print("ERROR: Could not open directory " + path)
		return 0
		
	print("\nScanning directory: " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != ".." and recurse:
			var subdir = path + file_name + "/"
			issues += check_directory(subdir)
		elif file_name.ends_with(".gd"):
			var full_path = path + file_name
			
			# Check if this is a potential test file that doesn't follow naming convention
			if not file_name.begins_with("test_"):
				# Check file content to see if it might be a test
				var content = load_file_content(full_path)
				if content != null and is_likely_test_file(content):
					print("⚠️ Potential test file with wrong naming: " + full_path)
					issues += 1
			else:
				# This is a test file, check if it has @tool annotation
				var content = load_file_content(full_path)
				if content != null and not content.begins_with("@tool"):
					print("⚠️ Test file missing @tool annotation: " + full_path)
					issues += 1
		
		file_name = dir.get_next()
	
	return issues
	
func load_file_content(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
		
	return file.get_as_text()

func is_likely_test_file(content: String) -> bool:
	# Check for common indicators that a file might be a test
	var indicators = [
		"extends \"res://tests/",
		"extends GutTest",
		"extends \"res://addons/gut/test.gd\"",
		"func test_",
		"assert_",
		"get_tree().quit()",
		"func before_each",
		"func after_each",
		"func before_all",
		"func after_all"
	]
	
	for indicator in indicators:
		if content.find(indicator) != -1:
			return true
			
	return false