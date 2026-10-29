class_name ShipComponentQuery
extends RefCounted

## Ship Component Query Helper — Core Rules pp.60-62, Compendium p.27
##
## Lightweight static helper to check installed ship components from any system.
## Uses GameStateManager.get_ship_data() → ship_data["components"] (Array of String IDs).
##
## Usage:
##   if ShipComponentQuery.has_component("medical_bay"):
##       # Apply Medical Bay effect
##   var count: int = ShipComponentQuery.get_component_count()
##   var ids: Array = ShipComponentQuery.get_installed_ids()
##
## Core Rules p.60: "Only one Component can be added each turn. When purchased, the
## Component is fully functional at the beginning of the next campaign turn." So a
## component bought this turn is OWNED but not yet FUNCTIONAL, and every query below
## answers for functional components only. The turn each one went in is stamped on
## the ship under INSTALL_TURNS_KEY, keyed by progress_data["turns_played"] (the
## completed-turn count). That count is saved and holds still for the whole turn,
## unlike CampaignPhaseManager.turn_number, which restarts at 0 on every load.
## A component with no stamp (every ship saved before this rule) is functional.

const INSTALL_TURNS_KEY := "component_install_turns"

# MARK: - Component Queries

## Check if a specific component is installed on the campaign ship.
static func has_component(component_id: String) -> bool:
	var components: Array = get_installed_ids()
	return component_id in components


## Get the IDs of every FUNCTIONAL component (p.60: one bought this turn works
## from the next turn).
static func get_installed_ids() -> Array:
	var ship: Dictionary = _get_ship_data()
	if ship.is_empty():
		return []
	var components: Variant = ship.get("components", [])
	if not (components is Array):
		return []
	var turn: int = current_turn()
	var functional: Array = []
	for comp_id in components:
		if not is_pending_on(ship, str(comp_id), turn):
			functional.append(comp_id)
	return functional


## True while a component installed on `turn` is still waiting for the next one.
static func is_pending_on(ship: Dictionary, component_id: String, turn: int) -> bool:
	var stamps: Variant = ship.get(INSTALL_TURNS_KEY, {})
	return stamps is Dictionary and (stamps as Dictionary).has(component_id) \
		and int(stamps[component_id]) >= turn


## How many components went in on `turn` (p.60 allows one).
static func installs_on_turn(ship: Dictionary, turn: int) -> int:
	var stamps: Variant = ship.get(INSTALL_TURNS_KEY, {})
	if not (stamps is Dictionary):
		return 0
	var count: int = 0
	for comp_id in stamps:
		if int(stamps[comp_id]) == turn:
			count += 1
	return count


## The campaign turn in progress, as its completed-turn count.
static func current_turn() -> int:
	var loop: Variant = Engine.get_main_loop()
	var gs: Variant = loop.root.get_node_or_null("/root/GameState") if loop else null
	var campaign: Variant = gs.current_campaign \
		if gs and "current_campaign" in gs else null
	if campaign == null or not ("progress_data" in campaign) \
			or not (campaign.progress_data is Dictionary):
		return 0
	return int(campaign.progress_data.get("turns_played", 0))


## Get the number of installed components.
static func get_component_count() -> int:
	return get_installed_ids().size()


## Check if a component has the Miniaturized mod applied (Compendium p.27).
## Miniaturized components are not counted towards increased fuel costs.
static func is_miniaturized(component_id: String) -> bool:
	var ship: Dictionary = _get_ship_data()
	if ship.is_empty():
		return false
	var miniaturized: Array = ship.get("miniaturized_components", [])
	return component_id in miniaturized


## Get the number of components that count towards fuel cost (+1 per 3).
## Excludes components with the Miniaturized mod (Compendium p.27).
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
