class_name FPCM_BattlefieldIO

## Handles the import and export of .5pbf (Five Parsecs Battlefield) files.
## This allows users to share procedurally generated battlefields.

# --- Public API ---

## Exports the context needed to regenerate a battlefield to a JSON string.
## @param context: A dictionary containing `mission_resource` and `generation_seed`.
## @param grid_snapshot: An optional snapshot of the final grid for perfect 1:1 loading.
## @return: A JSON-formatted string representing the battlefield blueprint.
static func export_battlefield(context: Dictionary, grid_snapshot: Array = []) -> String:
	var mission_resource = context.get("mission_resource")
	if not mission_resource:
		push_error("Cannot export battlefield: Mission resource is missing from context.")
		return ""

	var blueprint = {
		"version": "1.0",
		"source_mission_path": mission_resource.resource_path,
		"generation_seed": context.get("generation_seed", 0),
		"notes": "Exported from Five Parsecs Campaign Manager",
		# The grid snapshot is optional but ensures perfect replication
		"generated_grid_snapshot": grid_snapshot 
	}
	
	return JSON.stringify(blueprint, "\t") # Use tabs for readability

## Imports a battlefield blueprint from a JSON string.
## @param file_content: The JSON string from a .5pbf file.
## @return: A Dictionary containing the loaded context, or an empty dictionary on failure.
static func import_battlefield(file_content: String) -> Dictionary:
	var data = JSON.parse_string(file_content)

	if not data or typeof(data) != TYPE_DICTIONARY:
		push_error("Failed to parse battlefield blueprint. Invalid JSON.")
		return {}

	# Validate the imported data
	if not data.has("source_mission_path") or not data.has("generation_seed"):
		push_error("Invalid battlefield blueprint: missing required fields.")
		return {}

	var mission_path = data.get("source_mission_path")
	if not ResourceLoader.exists(mission_path):
		push_error("Cannot load battlefield: Mission resource not found at path: %s" % mission_path)
		return {}

	# Load the mission resource
	var mission_resource = load(mission_path)

	# Return a context dictionary ready for the generator
	var context = {
		"mission_resource": mission_resource,
		"generation_seed": data.get("generation_seed"),
		"imported_grid_snapshot": data.get("generated_grid_snapshot", [])
	}

	return context
