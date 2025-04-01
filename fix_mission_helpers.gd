@tool
extends EditorScript

func _run():
	# Get all mission helper files
	var dir = DirAccess.open("res://tests/temp/")
	if not dir:
		push_error("Failed to access temp directory")
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("mission_helper_") and file_name.ends_with(".gd"):
			_fix_file("res://tests/temp/" + file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Mission helper files fixed!")

func _fix_file(path: String):
	if not FileAccess.file_exists(path):
		push_error("File not found: %s" % path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: %s" % path)
		return
		
	var content = file.get_as_text()
	file.close()
	
	# Replace has() with in operator
	var new_content = content.replace('has("_completed")', '"_completed" in self')
	new_content = new_content.replace('has("', '"')
	new_content = new_content.replace('")', '" in self')
	
	# Write back to file
	file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: %s" % path)
		return
		
	file.store_string(new_content)
	file.close()
	
	print("Fixed file: %s" % path)