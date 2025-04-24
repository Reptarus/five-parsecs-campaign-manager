@tool
extends SceneTree

## Cleans up all UID files
##
## Godot stores .uid files alongside script files to help with caching, but these can
## sometimes cause issues with GUT tests.

const DIRECTORIES_TO_CLEAN = [
	"res://addons/gut",
	"res://tests"
]

func _init():
	print("Starting .uid file cleanup...")
	
	var total_removed = 0
	
	for directory in DIRECTORIES_TO_CLEAN:
		total_removed += clean_directory(directory)
	
	print("Removed %d .uid files" % total_removed)
	
	# Also fix empty script path
	ensure_temp_dir_exists()
	
	quit()

func clean_directory(directory_path: String) -> int:
	var removed_count = 0
	
	var dir = DirAccess.open(directory_path)
	if not dir:
		print("Failed to open directory: %s" % directory_path)
		return 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var current_path = directory_path + "/" + file_name
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			# Process subdirectory
			removed_count += clean_directory(current_path)
		elif not dir.current_is_dir() and file_name.ends_with(".uid"):
			# Remove .uid file
			if dir.remove(file_name) == OK:
				removed_count += 1
				print("Removed %s" % current_path)
		
		file_name = dir.get_next()
	
	return removed_count

func ensure_temp_dir_exists():
	var temp_dir = "res://addons/gut/temp"
	var empty_script_path = temp_dir + "/__empty.gd"
	
	# Create directory if needed
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)
		print("Created temp directory: %s" % temp_dir)
	
	# Create empty script if needed
	if not FileAccess.file_exists(empty_script_path):
		var file = FileAccess.open(empty_script_path, FileAccess.WRITE)
		if file:
			file.store_string("extends GDScript\n\n# This is an empty script file used by the compatibility layer\n# to replace GDScript.new() functionality in Godot 4.4")
			file.close()
			print("Created empty script at %s" % empty_script_path)
	else:
		print("Empty script already exists at %s" % empty_script_path)