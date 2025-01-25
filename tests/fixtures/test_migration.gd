@tool
extends EditorScript

const MIGRATION_PATTERNS := {
	# Old patterns to new patterns
	"await get_tree().create_timer(\\d+\\.\\d+).timeout": "await stabilize_engine()",
	"assert_true\\(\\s*is_instance_valid\\(([^)]+)\\)\\s*\\)": "assert_valid_game_state($1)",
	"await\\s+([^.]+)\\.([^\\s]+)": "await wait_for_signal($1, \"$2\")",
	"add_child\\(([^)]+)\\)": "add_child_autofree($1)",
	"var\\s+([^\\s]+)\\s*=\\s*([^\\s]+)\\.new\\(\\)": "var $1 = create_resource_autofree($2.new())"
}

const FILE_HEADER := """@tool
extends "res://tests/fixtures/game_test.gd"

"""

const LIFECYCLE_TEMPLATE := """
func before_each() -> void:
	await super.before_each()
	
	# Initialize test environment
	_game_state = create_test_game_state()
	add_child(_game_state)
	track_test_node(_game_state)
	
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
"""

func _run() -> void:
	print("Starting test migration...")
	
	# Get all test files
	var test_files = _find_test_files("res://tests")
	print("Found %d test files to migrate" % test_files.size())
	
	# Process each file
	for file_path in test_files:
		_migrate_test_file(file_path)
	
	print("Migration complete!")

func _find_test_files(path: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_find_test_files(path.path_join(file_name)))
			elif file_name.ends_with(".gd") and file_name.begins_with("test_"):
				files.append(path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func _migrate_test_file(file_path: String) -> void:
	print("Migrating: " + file_path)
	
	# Read file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open file: " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Skip if already migrated
	if content.begins_with(FILE_HEADER):
		print("File already migrated: " + file_path)
		return
	
	# Apply migrations
	var new_content = _apply_migrations(content)
	
	# Write back
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("Failed to write file: " + file_path)
		return
	
	file.store_string(new_content)
	file.close()
	
	print("Successfully migrated: " + file_path)

func _apply_migrations(content: String) -> String:
	# Add header
	if not content.begins_with("@tool"):
		content = FILE_HEADER + content
	
	# Update extends
	content = content.replace(
		'extends "res://addons/gut/test.gd"',
		'extends "res://tests/fixtures/game_test.gd"'
	)
	
	# Add lifecycle methods if missing
	if not "before_each" in content:
		var insert_pos = content.find("\n\n", content.find("class_name")) + 2
		content = content.insert(insert_pos, LIFECYCLE_TEMPLATE)
	
	# Apply pattern replacements
	for pattern in MIGRATION_PATTERNS:
		var regex = RegEx.new()
		regex.compile(pattern)
		
		var position = 0
		while position < content.length():
			var result = regex.search(content, position)
			if not result:
				break
			
			var replacement = MIGRATION_PATTERNS[pattern]
			for i in range(1, result.get_group_count() + 1):
				replacement = replacement.replace("$" + str(i), result.get_string(i))
			
			content = content.substr(0, result.get_start()) + \
					 replacement + \
					 content.substr(result.get_end())
			
			position = result.get_start() + replacement.length()
	
	return content

func _extract_class_name(content: String) -> String:
	var regex = RegEx.new()
	regex.compile("class_name\\s+([^\\s]+)")
	var result = regex.search(content)
	return result.get_string(1) if result else ""

func _backup_file(file_path: String) -> void:
	var backup_path = file_path + ".bak"
	var dir = DirAccess.open("res://")
	if dir:
		dir.copy(file_path, backup_path)

func _restore_backup(file_path: String) -> void:
	var backup_path = file_path + ".bak"
	var dir = DirAccess.open("res://")
	if dir and dir.file_exists(backup_path):
		dir.copy(backup_path, file_path)
		dir.remove(backup_path)