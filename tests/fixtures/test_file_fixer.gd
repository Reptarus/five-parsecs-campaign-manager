@tool
extends EditorScript

# Path mapping for extends statements
const PATH_MAPPING = {
	"GameTest": "res://tests/fixtures/base/game_test.gd",
	"BaseTest": "res://tests/fixtures/base/base_test.gd",
	"CampaignTest": "res://tests/fixtures/specialized/campaign_test.gd",
	"EnemyTest": "res://tests/fixtures/specialized/enemy_test.gd",
	"EnemyTestBase": "res://tests/fixtures/specialized/enemy_test_base.gd",
	"BattleTest": "res://tests/fixtures/specialized/battle_test.gd",
	"MobileTest": "res://tests/fixtures/specialized/mobile_test.gd",
	"UITest": "res://tests/fixtures/specialized/ui_test.gd",
	"MobileTestBase": "res://tests/fixtures/base/mobile_test_base.gd",
	"UITestBase": "res://tests/unit/ui/base/ui_test_base.gd",
	"ComponentTestBase": "res://tests/unit/ui/base/component_test_base.gd",
	"ControllerTestBase": "res://tests/unit/ui/base/controller_test_base.gd",
	"PanelTestBase": "res://tests/unit/ui/base/panel_test_base.gd",
	"PerfTestBase": "res://tests/performance/base/perf_test_base.gd"
}

# Files to check for circular references
const SELF_REFERENCE_PATHS = [
	"res://tests/fixtures/base/base_test.gd",
	"res://tests/fixtures/base/game_test.gd",
	"res://tests/fixtures/specialized/campaign_test.gd",
	"res://tests/fixtures/specialized/enemy_test.gd"
]

func _run() -> void:
	# Process all test files
	for path in _get_all_test_files():
		_process_file(path)
	
	print("Test file fixing complete!")

func _get_all_test_files() -> Array:
	var files := []
	var test_dirs := [
		"res://tests/unit",
		"res://tests/integration",
		"res://tests/performance",
		"res://tests/mobile",
		"res://tests/templates",
		"res://tests/fixtures"
	]
	
	for dir_path in test_dirs:
		files.append_array(_scan_directory(dir_path))
	
	return files

func _scan_directory(path: String) -> Array:
	var result := []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				var subdir := path.path_join(file_name)
				result.append_array(_scan_directory(subdir))
			elif file_name.ends_with(".gd"):
				result.append(path.path_join(file_name))
			
			file_name = dir.get_next()
	
	return result

func _process_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Could not open file: " + file_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	var modified := false
	
	# Check for class-based extends
	for class_name_key in PATH_MAPPING.keys():
		var class_extends_pattern: String = "extends " + class_name_key
		if content.contains(class_extends_pattern):
			var path_replacement: String = 'extends "' + PATH_MAPPING[class_name_key] + '"'
			content = content.replace(class_extends_pattern, path_replacement)
			modified = true
	
	# Check for circular references
	if file_path in SELF_REFERENCE_PATHS:
		var file_name := file_path.get_file()
		var self_ref_pattern: String = 'const ' + file_name.get_basename().capitalize() + 'Script = preload("' + file_path + '")'
		
		if content.contains(self_ref_pattern):
			var lines := content.split("\n")
			var filtered_lines := []
			
			for line in lines:
				if not (line.contains(self_ref_pattern) or (line.strip_edges().begins_with("# ") and line.contains(file_path))):
					filtered_lines.append(line)
			
			content = "\n".join(filtered_lines)
			modified = true
	
	# Save if modified
	if modified:
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			print("Fixed file: " + file_path)