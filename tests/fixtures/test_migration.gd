@tool
extends EditorScript

# Type-safe constants for migration patterns
const MIGRATION_PATTERNS := {
	# Core patterns
	"await get_tree().create_timer(\\d+\\.\\d+).timeout": "await stabilize_engine()",
	"assert_true\\(\\s*is_instance_valid\\(([^)]+)\\)\\s*\\)": "assert_valid_game_state($1)",
	"await\\s+([^.]+)\\.([^\\s]+)": "await wait_for_signal($1, \"$2\")",
	"add_child\\(([^)]+)\\)": "add_child_autofree($1)",
	"var\\s+([^\\s]+)\\s*=\\s*([^\\s]+)\\.new\\(\\)": "var $1 = create_resource_autofree($2.new())",
	
	# Enhanced type safety patterns
	"var\\s+([^\\s:]+)\\s*:=\\s*([^\\s]+)": "var $1: $2 = $2",
	"func\\s+([^(]+)\\(([^)]*)\\)": "func $1($2) -> void",
	"Array\\[\\]": "Array[Variant]",
	"Dictionary\\[\\]": "Dictionary[Variant, Variant]",
	
	# Signal patterns
	"connect\\(([^,]+),\\s*([^)]+)\\)": "connect($1.bind($2))",
	"emit_signal\\(([^)]+)\\)": "emit($1)",
	
	# Resource patterns
	"load\\(([^)]+)\\)": "preload($1)",
	"instance\\(\\)": "instantiate()",
	
	# Node patterns
	"get_node\\(([^)]+)\\)": "_get_node_safe($1)",
	"has_node\\(([^)]+)\\)": "is_valid_node($1)",
	
	# Property patterns
	"set\\(([^,]+),\\s*([^)]+)\\)": "_set_property_safe($1, $2)",
	"get\\(([^)]+)\\)": "_get_property_safe($1)"
}

# Type-safe file templates
const FILE_HEADER := """@tool
extends "res://tests/fixtures/game_test.gd"

# This test file was automatically migrated to the new test framework.
# Please review the changes and update as needed.

"""

const LIFECYCLE_TEMPLATE := """
# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize test environment
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create test game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	await stabilize_engine()

func after_each() -> void:
	# Cleanup test environment
	if _game_state:
		_game_state.queue_free()
		_game_state = null
	
	await super.after_each()
"""

# Type-safe instance variables
var _logger: Node = null
var _migration_stats: Dictionary = {
	"total_files": 0 as int,
	"migrated_files": 0 as int,
	"skipped_files": 0 as int,
	"errors": 0 as int,
	"start_time": 0.0 as float,
	"end_time": 0.0 as float
} as Dictionary

func _run() -> void:
	print("Starting test migration...")
	_migration_stats.start_time = Time.get_ticks_msec()
	
	# Get all test files
	var test_files: Array[String] = _find_test_files("res://tests")
	_migration_stats.total_files = test_files.size()
	print("Found %d test files to migrate" % test_files.size())
	
	# Process each file
	for file_path in test_files:
		_migrate_test_file(file_path)
	
	_migration_stats.end_time = Time.get_ticks_msec()
	_print_migration_stats()

func _find_test_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
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
	
	# Create backup
	_backup_file(file_path)
	
	# Read file
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open file: " + file_path)
		_migration_stats.errors += 1
		return
	
	var content := file.get_as_text()
	file.close()
	
	# Skip if already migrated
	if content.begins_with(FILE_HEADER):
		print("File already migrated: " + file_path)
		_migration_stats.skipped_files += 1
		return
	
	# Apply migrations
	var new_content := _apply_migrations(content)
	
	# Write back
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("Failed to write file: " + file_path)
		_migration_stats.errors += 1
		return
	
	file.store_string(new_content)
	file.close()
	
	_migration_stats.migrated_files += 1
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
		var insert_pos := content.find("\n\n", content.find("class_name")) + 2
		content = content.insert(insert_pos, LIFECYCLE_TEMPLATE)
	
	# Apply pattern replacements
	for pattern in MIGRATION_PATTERNS:
		var regex := RegEx.new()
		if regex.compile(pattern) != OK:
			push_error("Failed to compile regex pattern: %s" % pattern)
			continue
		
		var position := 0
		while position < content.length():
			var result := regex.search(content, position)
			if not result:
				break
			
			var replacement := MIGRATION_PATTERNS[pattern] as String
			for i in range(1, result.get_group_count() + 1):
				replacement = replacement.replace("$" + str(i), result.get_string(i))
			
			content = content.substr(0, result.get_start()) + \
					 replacement + \
					 content.substr(result.get_end())
			
			position = result.get_start() + replacement.length()
	
	return content

func _extract_class_name(content: String) -> String:
	var regex := RegEx.new()
	if regex.compile("class_name\\s+([^\\s]+)") != OK:
		push_error("Failed to compile class name regex")
		return ""
	var result := regex.search(content)
	return result.get_string(1) if result else ""

func _backup_file(file_path: String) -> void:
	var backup_path := file_path + ".bak"
	var dir := DirAccess.open("res://")
	if dir:
		if dir.copy(file_path, backup_path) != OK:
			push_error("Failed to create backup file: %s" % backup_path)

func _restore_backup(file_path: String) -> void:
	var backup_path := file_path + ".bak"
	var dir := DirAccess.open("res://")
	if dir and dir.file_exists(backup_path):
		if dir.copy(backup_path, file_path) != OK:
			push_error("Failed to restore from backup: %s" % backup_path)
			return
		if dir.remove(backup_path) != OK:
			push_error("Failed to remove backup file: %s" % backup_path)

func _print_migration_stats() -> void:
	var duration: float = (_migration_stats.end_time - _migration_stats.start_time) / 1000.0
	
	print("\n=== Migration Statistics ===")
	print("Duration: %.2f seconds" % duration)
	print("Total Files: %d" % _migration_stats.total_files)
	print("Migrated Files: %d" % _migration_stats.migrated_files)
	print("Skipped Files: %d" % _migration_stats.skipped_files)
	print("Errors: %d" % _migration_stats.errors)
	print("Success Rate: %.1f%%" % (float(_migration_stats.migrated_files) / _migration_stats.total_files * 100 if _migration_stats.total_files > 0 else 0.0))

# Enhanced validation methods
func _validate_migration_patterns() -> void:
	for pattern in MIGRATION_PATTERNS:
		var regex := RegEx.new()
		if regex.compile(pattern) != OK:
			push_error("Invalid migration pattern: %s" % pattern)

func _validate_file_path(path: String) -> bool:
	if not path.ends_with(".gd"):
		push_error("Invalid file extension: %s" % path)
		return false
	if not path.begins_with("res://tests/"):
		push_error("File must be in tests directory: %s" % path)
		return false
	return true