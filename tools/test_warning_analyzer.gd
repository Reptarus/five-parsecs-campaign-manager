@tool
extends EditorScript

const WARNING_PATTERNS = {
	"UNSAFE_CAST": {
		"patterns": [
			"\\bas\\b",
			"\\:=\\s*[^:]+\\s+as\\s+",
			"\\bget_node\\([^)]+\\)",
			"\\bget_node_or_null\\([^)]+\\)"
		],
		"priority": 1
	},
	"UNSAFE_METHOD_CALL": {
		"patterns": [
			"\\.\\w+\\s*\\([^)]*\\)",
			"\\bcall\\([^)]+\\)",
			"\\bcallv\\([^)]+\\)"
		],
		"priority": 2
	},
	"UNSAFE_PROPERTY_ACCESS": {
		"patterns": [
			"\\.\\w+\\s*=",
			"\\.\\w+\\s*\\+=",
			"\\.\\w+\\s*-="
		],
		"priority": 3
	},
	"UNTYPED_DECLARATION": {
		"patterns": [
			"\\bvar\\s+\\w+\\s*(?!:)",
			"\\bvar\\s+\\w+\\s*=\\s*\\[\\]",
			"\\bvar\\s+\\w+\\s*=\\s*\\{\\}"
		],
		"priority": 4
	}
}

# Create a warning info Dictionary factory instead of a class
func create_warning_info(p_path: String, p_line: int, p_type: String, p_code: String, p_fix: String = "") -> Dictionary:
	return {
		"file_path": p_path,
		"line_number": p_line,
		"warning_type": p_type,
		"code_line": p_code,
		"suggested_fix": p_fix
	}

func _run() -> void:
	print("Analyzing test files for warnings...")
	var warnings = analyze_test_files()
	generate_report(warnings)
	print("Analysis complete. Check 'res://tools/test_warnings_report.md' for results.")

func analyze_test_files() -> Array:
	var warnings = []
	var test_files = find_test_files("res://tests")
	
	for file_path in test_files:
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
			
		var line_number = 1
		while not file.eof_reached():
			var line = file.get_line()
			var found_warnings = analyze_line(file_path, line_number, line)
			warnings.append_array(found_warnings)
			line_number += 1
	
	return warnings

func find_test_files(path: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if not dir:
		return files
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			files.append_array(find_test_files(full_path))
		elif file_name.ends_with(".gd") and (file_name.begins_with("test_") or path.contains("/test/")):
			files.append(full_path)
		file_name = dir.get_next()
	
	return files

func analyze_line(file_path: String, line_number: int, line: String) -> Array:
	var warnings = []
	
	for warning_type in WARNING_PATTERNS:
		var patterns = WARNING_PATTERNS[warning_type]["patterns"]
		for pattern in patterns:
			if RegEx.create_from_string(pattern).search(line):
				var suggested_fix = suggest_fix(warning_type, line)
				warnings.append(create_warning_info(
					file_path,
					line_number,
					warning_type,
					line.strip_edges(),
					suggested_fix
				))
				break
	
	return warnings

func suggest_fix(warning_type: String, line: String) -> String:
	match warning_type:
		"UNSAFE_CAST":
			return suggest_safe_cast_fix(line)
		"UNSAFE_METHOD_CALL":
			return suggest_method_call_fix(line)
		"UNSAFE_PROPERTY_ACCESS":
			return suggest_property_access_fix(line)
		"UNTYPED_DECLARATION":
			return suggest_type_annotation_fix(line)
	return ""

func suggest_safe_cast_fix(line: String) -> String:
	# Extract type from 'as' expression
	var as_match = RegEx.create_from_string("as\\s+(\\w+)").search(line)
	if as_match:
		var type_name = as_match.get_string(1)
		return line.replace(
			" as " + type_name,
			": " + type_name + " = _safe_cast_to_" + type_name.to_lower() + "(" + line.split(" as ")[0].strip_edges() + ", \"" + type_name + "\")"
		)
	return line

func suggest_method_call_fix(line: String) -> String:
	var method_match = RegEx.create_from_string("\\.(\\w+)\\s*\\(").search(line)
	if method_match:
		var method_name = method_match.get_string(1)
		var obj_name = line.split(".")[0].strip_edges()
		return "if " + obj_name + " and " + obj_name + ".has_method(\"" + method_name + "\"):\\n\\t" + line
	return line

func suggest_property_access_fix(line: String) -> String:
	var prop_match = RegEx.create_from_string("\\.(\\w+)\\s*=").search(line)
	if prop_match:
		var prop_name = prop_match.get_string(1)
		var obj_name = line.split(".")[0].strip_edges()
		return "if " + obj_name + " and \"" + prop_name + "\" in " + obj_name + ":\\n\\t" + line
	return line

func suggest_type_annotation_fix(line: String) -> String:
	var var_match = RegEx.create_from_string("var\\s+(\\w+)").search(line)
	if var_match:
		var var_name = var_match.get_string(1)
		if line.contains("[]"):
			return line.replace("[]", ": Array = []")
		elif line.contains("{}"):
			return line.replace("{}", ": Dictionary = {}")
		else:
			return line.replace(var_name, var_name + ": Variant")
	return line

func generate_report(warnings: Array) -> void:
	var report = FileAccess.open("res://tools/test_warnings_report.md", FileAccess.WRITE)
	if not report:
		return
		
	report.store_string("# Test Warnings Analysis Report\n\n")
	
	var warnings_by_type = {}
	for warning in warnings:
		if not warnings_by_type.has(warning["warning_type"]):
			warnings_by_type[warning["warning_type"]] = []
		warnings_by_type[warning["warning_type"]].append(warning)
	
	for warning_type in warnings_by_type:
		var type_warnings = warnings_by_type[warning_type]
		report.store_string("## " + warning_type + " (" + str(type_warnings.size()) + " occurrences)\n\n")
		
		for warning in type_warnings:
			report.store_string("### " + warning["file_path"] + ":" + str(warning["line_number"]) + "\n")
			report.store_string("```gdscript\n" + warning["code_line"] + "\n```\n")
			if warning["suggested_fix"]:
				report.store_string("Suggested fix:\n```gdscript\n" + warning["suggested_fix"] + "\n```\n")
			report.store_string("\n")
