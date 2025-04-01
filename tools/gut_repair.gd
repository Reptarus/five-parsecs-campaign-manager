@tool
extends EditorScript

## GUT Repair Tool
##
## Run this script via the Godot editor's Script menu to fix 
## common GUT breakage issues.

const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

const GUT_SCENES_TO_CHECK = [
	"res://addons/gut/gui/OutputText.tscn",
	"res://addons/gut/gui/RunResults.tscn",
	"res://addons/gut/gui/GutBottomPanel.tscn"
]

func _run():
	print("")
	print("=============================================")
	print("  FIVE PARSECS GUT REPAIR TOOL")
	print("=============================================")
	print("")
	
	# 1. Check for corrupted scene files
	print("Checking for corrupted GUT scene files...")
	var corrupted_scenes = []
	
	for scene_path in GUT_SCENES_TO_CHECK:
		if GutCompatibility.check_scene_corruption(scene_path):
			corrupted_scenes.append(scene_path)
	
	if not corrupted_scenes.is_empty():
		print("WARNING: The following scene files appear to be corrupted:")
		for scene in corrupted_scenes:
			print("  - " + scene)
		print("RECOMMENDATION: Delete these files and let Godot rebuild them")
	else:
		print("No corrupted scene files detected.")
	
	print("")
	
	# 2. Create necessary directories
	print("Ensuring necessary directories exist...")
	var test_dirs = [
		"res://tests/fixtures/helpers",
		"res://tests/generated",
		"res://tests/unit",
		"res://tests/integration"
	]
	
	for dir in test_dirs:
		if GutCompatibility.ensure_directory_exists(dir):
			print("  - Verified directory: " + dir)
	
	print("")
	
	# 3. Fix missing function references in test files
	print("Scanning for script issues...")
	var script_files = []
	GutCompatibility.find_scripts(script_files, "res://tests")
	
	var fixed_count = 0
	for script_path in script_files:
		if GutCompatibility.fix_type_safe_references(script_path):
			fixed_count += 1
	
	if fixed_count > 0:
		print("Fixed issues in %d scripts" % fixed_count)
	else:
		print("No script issues detected")
	
	print("")
	
	# 4. Fix dictionary usage in GUT addon files
	print("Checking GUT addon files for dictionary usage issues...")
	var gut_scripts = []
	GutCompatibility.find_scripts(gut_scripts, "res://addons/gut")
	
	fixed_count = 0
	for script_path in gut_scripts:
		var file = FileAccess.open(script_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			# Look for dictionary.has() usage
			var has_issues = false
			if content.contains(".has(") and not content.contains("has_method(") and not content.contains("has_signal("):
				# Replace dictionary access
				content = content.replace(".has(", " in ")
				has_issues = true
			
			if has_issues:
				file = FileAccess.open(script_path, FileAccess.WRITE)
				if file:
					file.store_string(content)
					file.close()
					fixed_count += 1
					print("  - Fixed dictionary usage in: " + script_path)
	
	if fixed_count > 0:
		print("Fixed issues in %d GUT files" % fixed_count)
	else:
		print("No dictionary usage issues detected in GUT files")
	
	print("")
	
	# 5. Check for UID conflicts
	print("Checking for UID conflicts...")
	var uid_files = []
	find_uid_files(uid_files, "res://addons/gut")
	
	if uid_files.size() > 50: # Arbitrary threshold based on your error logs
		print("WARNING: Found %d .uid files which may cause conflicts" % uid_files.size())
		print("RECOMMENDATION: Consider clearing these files if GUT is still breaking")
		print("  Run this command in your project root: find addons/gut -name \"*.uid\" -delete")
	else:
		print("No excessive UID files detected")
	
	print("")
	print("=============================================")
	print("  GUT REPAIR COMPLETE")
	print("=============================================")
	print("")
	print("If GUT continues to break after this repair:")
	print("1. Delete all .uid files in the addons/gut directory")
	print("2. Delete corrupted scene files and let Godot rebuild them")
	print("3. Make sure all test files use absolute paths in extends statements")
	print("4. Check that all resources have valid resource paths")
	print("")

func find_uid_files(result: Array, path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				find_uid_files(result, path.path_join(file_name))
			elif file_name.ends_with(".uid"):
				result.append(path.path_join(file_name))
			file_name = dir.get_next()
