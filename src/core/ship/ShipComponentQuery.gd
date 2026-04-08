class_name ShipComponentQuery
extends RefCounted

## Ship Component Query Helper — Core Rules pp.60-62, Compendium p.28
##
## Lightweight static helper to check installed ship components from any system.
## Uses GameStateManager.get_ship_data() → ship_data["components"] (Array of String IDs).
##
## Usage:
##   if ShipComponentQuery.has_component("medical_bay"):
##       # Apply Medical Bay effect
##   var count: int = ShipComponentQuery.get_component_count()
##   var ids: Array = ShipComponentQuery.get_installed_ids()

# MARK: - Component Queries

## Check if a specific component is installed on the campaign ship.
static func has_component(component_id: String) -> bool:
	var components: Array = get_installed_ids()
	return component_id in components


## Get all installed component IDs as an Array of Strings.
static func get_installed_ids() -> Array:
	var ship: Dictionary = _get_ship_data()
	if ship.is_empty():
		return []
	var components: Variant = ship.get("components", [])
	return components if components is Array else []


## Get the number of installed components.
static func get_component_count() -> int:
	return get_installed_ids().size()


## Check if a component has the Miniaturized mod applied (Compendium p.28).
## Miniaturized components are not counted towards increased fuel costs.
static func is_miniaturized(component_id: String) -> bool:
	var ship: Dictionary = _get_ship_data()
	if ship.is_empty():
		return false
	var miniaturized: Array = ship.get("miniaturized_components", [])
	return component_id in miniaturized


## Get the number of components that count towards fuel cost (+1 per 3).
## Excludes components with the Miniaturized mod (Compendium p.28).
static func get_billable_component_count() -> int:
	var ids: Array = get_installed_ids()
	var count: int = 0
	for comp_id in ids:
		if not is_miniaturized(comp_id):
			count += 1
	return count


# MARK: - Internal

## Get ship data Dictionary from GameStateManager autoload.
## Returns empty Dictionary if unavailable.
static func _get_ship_data() -> Dictionary:
	var gsm: Variant = Engine.get_main_loop().root.get_node_or_null(
		"/root/GameStateManager") if Engine.get_main_loop() else null
	if gsm and gsm.has_method("get_ship_data"):
		var data: Variant = gsm.get_ship_data()
		return data if data is Dictionary else {}
	return {}
