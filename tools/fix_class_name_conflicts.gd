@tool
extends EditorScript

## This script helps identify and fix class_name conflicts in the project
## Run this script from the Godot editor to analyze and suggest fixes

# Configuration
const SCAN_DIRECTORIES = ["res://src", "res://tests"]
const EXCLUDE_DIRECTORIES = ["res://src/addons"]
const OUTPUT_FILE = "res://class_name_conflicts_report.md"

# Class name registry - maps class_name to files that declare it
var class_registry = {}

# Files with issues
var conflicting_files = []
var missing_reference_files = []

func _run():
	print("Starting class_name conflict analysis...")
	
	# Clear previous results
	class_registry.clear()
	conflicting_files.clear()
	missing_reference_files.clear()
	
	# Scan project files
	for directory in SCAN_DIRECTORIES:
		scan_directory(directory)
	
	# Generate report
	generate_report()
	
	print("Analysis complete. Results saved to " + OUTPUT_FILE)

func scan_directory(path):
	print("Scanning directory: " + path)
	
	var dir = DirAccess.open(path)
	if not dir:
		print("Error opening directory: " + path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		# Skip excluded directories
		var should_skip = false
		for exclude in EXCLUDE_DIRECTORIES:
			if full_path.begins_with(exclude):
				should_skip = true
				break
		
		if should_skip:
			file_name = dir.get_next()
			continue
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			if not file_name in [".", ".."]:
				scan_directory(full_path)
		elif file_name.ends_with(".gd"):
			# Analyze GDScript file
			analyze_script(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func analyze_script(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error opening file: " + file_path)
		return
	
	var content = file.get_as_text()
	var lines = content.split("\n")
	var class_name_pattern = RegEx.new()
	class_name_pattern.compile("class_name\\s+([A-Za-z0-9_]+)")
	
	for line in lines:
		var result = class_name_pattern.search(line)
		if result:
			var class_found = result.get_string(1)
			if not class_registry.has(class_found):
				class_registry[class_found] = []
			
			class_registry[class_found].append(file_path)
			
			# Check for conflicts
			if class_registry[class_found].size() > 1:
				if not conflicting_files.has(file_path):
					conflicting_files.append(file_path)
				
				# Also add the original file that declared this class
				var original_file = class_registry[class_found][0]
				if not conflicting_files.has(original_file):
					conflicting_files.append(original_file)

func generate_report():
	var report = "# Class Name Conflicts Report\n\n"
	report += "This report identifies scripts with class_name conflicts.\n\n"
	report += "## Conflicting Class Names\n\n"
	report += "The following classes are defined in multiple files:\n\n"
	
	# Add conflicts section
	var has_conflicts = false
	for class_name_key in class_registry.keys():
		if class_registry[class_name_key].size() > 1:
			has_conflicts = true
			report += "### Class: `" + class_name_key + "`\n\n"
			report += "Declared in:\n"
			
			for file_path in class_registry[class_name_key]:
				report += "- `" + file_path + "`\n"
			
			report += "\n**Recommendation**: Keep class_name in authoritative file and remove from others. Add comments in non-authoritative files.\n\n"
	
	if not has_conflicts:
		report += "No class_name conflicts found.\n\n"
	
	report += "## How to Fix\n\n"
	report += "For each conflicting class:\n\n"
	report += "1. Decide which file is the \"authoritative\" version that should keep the class_name\n"
	report += "2. For all other files:\n"
	report += "   - Remove the class_name declaration\n"
	report += "   - Add a comment explaining where the authoritative version is\n"
	report += "   - Update code to use preload/load instead of direct reference\n"
	report += "3. Add an entry to the class name registry at `docs/class_name_registry.md`\n\n"
	report += "### Example Fix:\n\n"
	report += "```gdscript\n"
	report += "# BEFORE:\n"
	report += "class_name ConflictingClass\n"
	report += "extends Node\n\n"
	report += "# AFTER:\n"
	report += "# REMOVED: class_name ConflictingClass\n"
	report += "# The authoritative ConflictingClass is located at res://path/to/authoritative/file.gd\n"
	report += "# Use explicit preloads to reference this class: preload(\"res://path/to/this/script.gd\")\n"
	report += "extends Node\n\n"
	report += "# Update any inner classes that were referenced externally\n"
	report += "# Consider adding factory methods for inner classes\n"
	report += "```\n"
	
	# Write report to file
	var file = FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	if not file:
		print("Error writing report to " + OUTPUT_FILE)
		return
	
	file.store_string(report)
	file.close()