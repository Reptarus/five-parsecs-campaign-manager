@tool
extends SceneTree

## Fix Test Indentation Script
## Run in Godot using: godot -s tools/fix_test_indentation.gd
##
## This script goes through all test files and fixes common indentation issues
## that cause the "Unexpected Indent in class body" error

var tests_directory = "res://tests/"
var fixed_files = 0
var error_files = 0

func _init():
	print("Fixing test indentation issues...")
	
	# Process test files
	process_directory(tests_directory)
	
	print("Completed fixing indentation issues:")
	print("- Fixed files: ", fixed_files)
	print("- Error files: ", error_files)
	
	quit()

func process_directory(path):
	var dir = DirAccess.open(path)
	if dir == null:
		print("Failed to open directory: ", path)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var file_path = path + file_name
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			process_directory(file_path + "/")
		elif file_name.ends_with(".gd") and (file_name.begins_with("test_") or path.find("/fixtures/") >= 0):
			process_test_file(file_path)
			
		file_name = dir.get_next()
	
	dir.list_dir_end()

func process_test_file(file_path):
	print("Processing: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("  Failed to open file: ", file_path)
		error_files += 1
		return
		
	var content = file.get_as_text()
	file.close()
	
	# Check if file needs fixing
	var needs_fixing = false
	
	# Check for mixed tabs/spaces
	var mixed_indentation = has_mixed_indentation(content)
	
	# Check for trailing whitespace after pending() calls
	var has_pending_whitespace = content.find("pending(") >= 0 and content.find("pending(") < content.find("\t ")
	
	# Check for incorrect indentation after multi-line strings
	var has_multiline_issue = content.find('"""') >= 0 and check_multiline_indentation(content)
	
	if mixed_indentation or has_pending_whitespace or has_multiline_issue:
		print("  Needs fixing: ", file_path)
		needs_fixing = true
		
	if needs_fixing:
		# Fix the issues
		var fixed_content = fix_indentation_issues(content)
		
		# Write back the fixed content
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			print("  Failed to write fixed file: ", file_path)
			error_files += 1
			return
			
		file.store_string(fixed_content)
		file.close()
		fixed_files += 1
		print("  Fixed: ", file_path)

func has_mixed_indentation(content):
	var lines = content.split("\n")
	var uses_tabs = false
	var uses_spaces = false
	
	for line in lines:
		if line.begins_with("\t"):
			uses_tabs = true
		elif line.begins_with(" "):
			uses_spaces = true
			
	return uses_tabs and uses_spaces

func check_multiline_indentation(content):
	var lines = content.split("\n")
	var in_multiline = false
	
	for i in range(lines.size()):
		var line = lines[i]
		
		if line.find('"""') >= 0:
			in_multiline = !in_multiline
			
			# Check the line after closing multi-line string
			if !in_multiline and i < lines.size() - 1:
				var next_line = lines[i + 1]
				var current_indent = get_line_indent(line)
				var next_indent = get_line_indent(next_line)
				
				if next_indent != current_indent:
					return true
					
	return false

func get_line_indent(line):
	var indent = 0
	for c in line:
		if c == '\t':
			indent += 1
		elif c == ' ':
			indent += 1
		else:
			break
	return indent

func fix_indentation_issues(content):
	var lines = content.split("\n")
	var fixed_lines = []
	var dominant_indent = get_dominant_indent_style(lines)
	var in_multiline = false
	var multiline_indent = 0
	
	for i in range(lines.size()):
		var line = lines[i]
		var fixed_line = line
		
		# Track multiline strings
		if line.find('"""') >= 0:
			if !in_multiline:
				in_multiline = true
				multiline_indent = get_line_indent(line)
			else:
				in_multiline = false
		
		# Fix indentation style (use the dominant style)
		if !in_multiline and (line.begins_with("\t") or line.begins_with(" ")):
			var current_indent = get_line_indent(line)
			fixed_line = convert_indent_style(line, dominant_indent, current_indent)
		
		# Fix trailing whitespace after pending calls
		if line.find("pending(") >= 0:
			fixed_line = line.strip_edges(false, true)
		
		fixed_lines.append(fixed_line)
	
	return "\n".join(fixed_lines)

func get_dominant_indent_style(lines):
	var tab_count = 0
	var space_count = 0
	
	for line in lines:
		if line.begins_with("\t"):
			tab_count += 1
		elif line.begins_with(" "):
			space_count += 1
	
	return "\t" if tab_count >= space_count else "    "

func convert_indent_style(line, dominant_style, current_indent):
	var indent_text = ""
	var content = line.strip_edges(true, false)
	
	for i in range(current_indent):
		indent_text += dominant_style
		
	return indent_text + content