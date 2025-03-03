@tool
extends EditorScript

## Utility script to fix missing class method references
## When class_name is removed, direct static method calls like ClassName.method() need to be fixed

# Configuration
const TARGET_FILES = ["res://src/core/managers/CampaignManager.gd"]
const REPLACEMENTS = {
	"StoryQuestData.create_mission": {
		"preload": "const StoryQuestDataScript = preload(\"res://src/core/mission/StoryQuestData.gd\")",
		"replacement": "StoryQuestDataScript.create_mission"
	}
}

func _run():
	print("Starting to fix missing class method references...")
	
	for file_path in TARGET_FILES:
		fix_references_in_file(file_path)
	
	print("Finished fixing references")

func fix_references_in_file(file_path):
	print("Processing file: " + file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error opening file: " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	var has_changes = false
	var added_preloads = {}
	
	# Check for each problematic reference
	for reference in REPLACEMENTS:
		var replacement_info = REPLACEMENTS[reference]
		var preload_statement = replacement_info.preload
		var new_reference = replacement_info.replacement
		
		var reference_pattern = RegEx.new()
		reference_pattern.compile("\\b" + reference.replace(".", "\\.") + "\\b")
		
		var matches = reference_pattern.search_all(content)
		if matches.size() > 0:
			content = reference_pattern.sub(content, new_reference, true)
			has_changes = true
			
			# Add preload statement if not already added
			if not added_preloads.has(preload_statement):
				added_preloads[preload_statement] = true
	
	if has_changes:
		# Add the necessary preload statements at the top of the file
		var preload_position = find_preload_position(content)
		var preload_insertion = ""
		
		for preload_statement in added_preloads:
			preload_insertion += preload_statement + "\n"
		
		var lines = content.split("\n")
		lines.insert(preload_position, preload_insertion)
		content = lines.join("\n")
		
		# Write the changes back to the file
		var output = FileAccess.open(file_path, FileAccess.WRITE)
		if not output:
			print("Error opening file for writing: " + file_path)
			return
		
		output.store_string(content)
		output.close()
		
		print("Fixed references in " + file_path)
	else:
		print("No changes needed in " + file_path)

func find_preload_position(content):
	var lines = content.split("\n")
	var extends_line = -1
	var const_line = -1
	var class_name_line = -1
	var tool_line = -1
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		if line.begins_with("@tool"):
			tool_line = i
		elif line.begins_with("class_name"):
			class_name_line = i
		elif line.begins_with("extends"):
			extends_line = i
		elif line.begins_with("const "):
			const_line = i
			# We only care about the first const line
			if const_line != -1:
				break
	
	# Choose the appropriate position for the preload statement
	if const_line != -1:
		return const_line + 1
	elif extends_line != -1:
		return extends_line + 1
	elif class_name_line != -1:
		return class_name_line + 1
	elif tool_line != -1:
		return tool_line + 1
	else:
		return 0 # Beginning of file