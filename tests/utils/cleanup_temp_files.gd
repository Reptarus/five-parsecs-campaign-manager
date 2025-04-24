@tool
extends SceneTree

## Utility script to clean up temporary test files
## Run this script using: godot --script tests/utils/cleanup_temp_files.gd

const TEMP_DIRS = [
	"res://tests/temp/",
	"res://addons/gut/temp/"
]
const FILE_PATTERNS = [
	"*.gd",
	"*.gd.uid",
	"*.tmp"
]

func _init():
	print("Starting test file cleanup...")
	
	var total_removed = 0
	
	# Process each temp directory
	for dir_path in TEMP_DIRS:
		var dir = DirAccess.open(dir_path)
		if not dir:
			print("  Could not open directory: ", dir_path)
			continue
			
		print("Cleaning directory: ", dir_path)
		
		# Process each file pattern
		for pattern in FILE_PATTERNS:
			var files_removed = remove_matching_files(dir, pattern)
			if files_removed > 0:
				print("  Removed ", files_removed, " files matching pattern: ", pattern)
			total_removed += files_removed
	
	print("Cleanup complete. Total files removed: ", total_removed)
	quit()

func remove_matching_files(dir: DirAccess, pattern: String) -> int:
	var count = 0
	
	# First list all files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.match(pattern):
			var full_path = dir.get_current_dir() + "/" + file_name
			var err = dir.remove(file_name)
			if err == OK:
				count += 1
			else:
				print("    Failed to remove file: ", full_path, " (Error: ", err, ")")
		file_name = dir.get_next()
	
	return count