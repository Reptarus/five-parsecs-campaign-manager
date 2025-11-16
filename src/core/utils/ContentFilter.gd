class_name ContentFilter
extends RefCounted

## ContentFilter
##
## Utility class for filtering game content based on DLC ownership.
## Used by various systems to ensure only owned content is available.
##
## Usage:
##   var filter := ContentFilter.new()
##   var available_species := filter.filter_by_ownership(all_species, "species")
##   var mission_enemies := filter.filter_enemies_by_dlc(enemies, current_mission.dlc_required)

## Reference to ExpansionManager (set on initialization)
var expansion_manager: Node = null

func _init() -> void:
	# Get ExpansionManager autoload
	if Engine.has_singleton("ExpansionManager"):
		expansion_manager = Engine.get_singleton("ExpansionManager")
	elif has_node("/root/ExpansionManager"):
		expansion_manager = get_node("/root/ExpansionManager")
	else:
		push_warning("ContentFilter: ExpansionManager not found. All DLC content will be filtered out.")

## Filter an array of content items based on DLC ownership
## Returns only items that are either core content or from owned DLC
func filter_by_ownership(content_array: Array, content_type: String = "") -> Array:
	if not expansion_manager:
		return _filter_core_only(content_array)

	var filtered := []
	for item in content_array:
		if _is_item_available(item):
			filtered.append(item)
	return filtered

## Check if a single content item is available based on DLC ownership
func is_content_available(item: Variant) -> bool:
	if not expansion_manager:
		return _is_core_content(item)
	return _is_item_available(item)

## Filter species list based on DLC ownership
func filter_species(species_array: Array) -> Array:
	return filter_by_ownership(species_array, "species")

## Filter equipment list based on DLC ownership
func filter_equipment(equipment_array: Array) -> Array:
	return filter_by_ownership(equipment_array, "equipment")

## Filter enemy types based on DLC ownership
func filter_enemies(enemy_array: Array) -> Array:
	return filter_by_ownership(enemy_array, "enemies")

## Filter mission templates based on DLC ownership
func filter_missions(mission_array: Array) -> Array:
	return filter_by_ownership(mission_array, "missions")

## Filter backgrounds based on DLC ownership
func filter_backgrounds(background_array: Array) -> Array:
	return filter_by_ownership(background_array, "backgrounds")

## Filter classes based on DLC ownership
func filter_classes(class_array: Array) -> Array:
	return filter_by_ownership(class_array, "classes")

## Filter psionic powers based on DLC ownership (Trailblazer's Toolkit)
func filter_psionic_powers(power_array: Array) -> Array:
	if not expansion_manager or not expansion_manager.is_expansion_available("trailblazers_toolkit"):
		return [] # No psionic powers without Trailblazer's Toolkit
	return filter_by_ownership(power_array, "psionic_powers")

## Get DLC requirement from content item
## Returns empty string if core content, or DLC ID if expansion content
func get_dlc_requirement(item: Variant) -> String:
	if item is Dictionary:
		if item.has("dlc_required") and item.dlc_required != null:
			return str(item.dlc_required)
		if item.has("source") and item.source != "core":
			return str(item.source)
	elif item is Resource:
		if item.get("dlc_required"):
			return str(item.get("dlc_required"))
		if item.get("source") and item.get("source") != "core":
			return str(item.get("source"))

	return "" # Core content

## Filter content by specific DLC
## Use when you want content from a specific DLC only
func filter_by_dlc(content_array: Array, dlc_id: String) -> Array:
	var filtered := []
	for item in content_array:
		var required_dlc := get_dlc_requirement(item)
		if required_dlc == dlc_id:
			filtered.append(item)
	return filtered

## Get only core content (no DLC)
func filter_core_only(content_array: Array) -> Array:
	return _filter_core_only(content_array)

## Combine multiple DLC content arrays with core content
## Useful for building complete content lists
func combine_content(core_content: Array, dlc_contents: Dictionary) -> Array:
	var combined := []

	# Always add core content first
	combined.append_array(core_content)

	# Add DLC content if owned
	for dlc_id in dlc_contents.keys():
		if expansion_manager and expansion_manager.is_expansion_available(dlc_id):
			combined.append_array(dlc_contents[dlc_id])

	return combined

## Check if specific DLC content type is available
## Example: is_content_type_available("psionic_powers") checks for Trailblazer's Toolkit
func is_content_type_available(content_type: String) -> bool:
	if not expansion_manager:
		return false

	match content_type:
		"psionic_powers":
			return expansion_manager.is_expansion_available("trailblazers_toolkit")
		"elite_enemies":
			return expansion_manager.is_expansion_available("freelancers_handbook")
		"difficulty_modifiers":
			return expansion_manager.is_expansion_available("freelancers_handbook")
		"stealth_missions", "salvage_jobs", "street_fights":
			return expansion_manager.is_expansion_available("fixers_guidebook")
		"bug_hunt_enemies", "bug_hunt_missions":
			return expansion_manager.is_expansion_available("bug_hunt")
		_:
			return true # Core content types are always available

## Get list of missing DLC for content item
## Returns array of DLC IDs that would be needed to unlock this content
func get_missing_dlc_for_content(item: Variant) -> Array:
	var required_dlc := get_dlc_requirement(item)
	if required_dlc.is_empty():
		return [] # Core content, no DLC needed

	if expansion_manager and expansion_manager.is_expansion_available(required_dlc):
		return [] # DLC is owned

	return [required_dlc]

## Generate user-friendly message about why content is locked
func get_locked_content_message(item: Variant) -> String:
	var required_dlc := get_dlc_requirement(item)
	if required_dlc.is_empty():
		return "" # Not locked

	if expansion_manager and expansion_manager.is_expansion_available(required_dlc):
		return "" # Not locked

	var dlc_name := _get_dlc_display_name(required_dlc)
	return "Requires DLC: %s" % dlc_name

## Get statistics about content availability
## Returns dictionary with counts of available/locked content
func get_content_stats(content_array: Array) -> Dictionary:
	var stats := {
		"total": content_array.size(),
		"available": 0,
		"locked": 0,
		"by_dlc": {}
	}

	for item in content_array:
		var required_dlc := get_dlc_requirement(item)

		if required_dlc.is_empty() or (expansion_manager and expansion_manager.is_expansion_available(required_dlc)):
			stats.available += 1
		else:
			stats.locked += 1
			if not stats.by_dlc.has(required_dlc):
				stats.by_dlc[required_dlc] = 0
			stats.by_dlc[required_dlc] += 1

	return stats

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _is_item_available(item: Variant) -> bool:
	var required_dlc := get_dlc_requirement(item)

	# Core content is always available
	if required_dlc.is_empty():
		return true

	# Check DLC ownership
	return expansion_manager.is_expansion_available(required_dlc)

func _is_core_content(item: Variant) -> bool:
	return get_dlc_requirement(item).is_empty()

func _filter_core_only(content_array: Array) -> Array:
	var filtered := []
	for item in content_array:
		if _is_core_content(item):
			filtered.append(item)
	return filtered

func _get_dlc_display_name(dlc_id: String) -> String:
	match dlc_id:
		"trailblazers_toolkit":
			return "Trailblazer's Toolkit"
		"freelancers_handbook":
			return "Freelancer's Handbook"
		"fixers_guidebook":
			return "Fixer's Guidebook"
		"bug_hunt":
			return "Bug Hunt"
		"complete_compendium":
			return "Complete Compendium"
		_:
			return dlc_id.capitalize()
