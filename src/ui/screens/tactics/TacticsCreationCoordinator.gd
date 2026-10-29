class_name TacticsCreationCoordinator
extends Node

## Runtime loads for Tactics data classes (avoid class_name parse-order issues)
var _SpeciesBookLoader: GDScript
var _CompositionValidator: GDScript
var _CampaignCore: GDScript
var _CampaignUnit: GDScript
var _Roster: GDScript
var _RosterEntry: GDScript

## Orchestrates Tactics campaign creation — 4-step wizard.
## Follows the same coordinator pattern as BugHuntCreationCoordinator
## and PlanetfallCreationCoordinator.
##
## Steps:
##   0: Configuration (name, points, org type, play mode)
##   1: Species Selection (primary + optional secondary)
##   2: Army Roster (unit selection, upgrades, vehicles, composition validation)
##   3: Final Review
## ⚠ A separate "Vehicles" step (3) was removed 2026-10-27. Its setter had zero callers
## and the UI showed the roster panel in its place; it skipped itself only while a
## species had no vehicles, and since p.141 gives every army all 19 that skip stopped
## firing. Vehicles are Army Builder units (p.134 Supports; p.135 armored platoons) and
## are bought on the roster step with everything else.

signal navigation_updated(can_back: bool, can_forward: bool, can_finish: bool)
signal step_changed(step: int, total_steps: int)

const STEP_NAMES := [
	"Configuration",
	"Species",
	"Army Roster",
	"Review",
]

var current_step: int = 0
var total_steps: int = 4

## Accumulated creation state
var config_data: Dictionary = {}
var species_id: String = ""
var secondary_species_id: String = ""
var roster_entries: Array = []  # Array of _RosterEntry.to_dict()

## Loaded species book (cached after species selection)
var _species_book = null  # TacticsSpeciesBook

## Step completion flags
var _step_complete: Array[bool] = [false, false, false, false]


func _ready() -> void:
	_SpeciesBookLoader = load("res://src/data/tactics/TacticsSpeciesBookLoader.gd")
	_CompositionValidator = load("res://src/data/tactics/TacticsCompositionValidator.gd")
	_CampaignCore = load("res://src/game/campaign/TacticsCampaignCore.gd")
	_CampaignUnit = load("res://src/data/tactics/TacticsCampaignUnit.gd")
	_Roster = load("res://src/data/tactics/TacticsRoster.gd")
	_RosterEntry = load("res://src/data/tactics/TacticsRosterEntry.gd")


func go_to_step(step: int) -> void:
	if step < 0 or step >= total_steps:
		return

	current_step = step
	step_changed.emit(current_step, total_steps)
	_update_navigation()


func next_step() -> void:
	if current_step < total_steps - 1:
		go_to_step(current_step + 1)


func previous_step() -> void:
	if current_step <= 0:
		return
	go_to_step(current_step - 1)


func get_step_name(step: int = -1) -> String:
	if step < 0:
		step = current_step
	if step >= 0 and step < STEP_NAMES.size():
		return STEP_NAMES[step]
	return "Unknown"


func _update_navigation() -> void:
	var can_back = current_step > 0
	var can_forward = current_step < total_steps - 1 and _step_complete[current_step]
	var can_finish = current_step == total_steps - 1 and _can_finish()
	navigation_updated.emit(can_back, can_forward, can_finish)


func _can_finish() -> bool:
	return _step_complete[0] and _step_complete[1] and _step_complete[2]


## ============================================================================
## STATE UPDATE METHODS (called by panels via signals)
## ============================================================================

func update_config(data: Dictionary) -> void:
	config_data.merge(data, true)
	_step_complete[0] = (
		not config_data.get("campaign_name", "").is_empty()
		and config_data.has("points_limit")
	)
	_update_navigation()


func update_species(data: Dictionary) -> void:
	species_id = data.get("species_id", "")
	secondary_species_id = data.get("secondary_species_id", "")

	# Load the species book for roster building
	if not species_id.is_empty():
		_species_book = _SpeciesBookLoader.load_species_book(species_id)

	_step_complete[1] = not species_id.is_empty()

	# Reset downstream steps when species changes
	roster_entries.clear()
	_step_complete[2] = false
	_step_complete[3] = false

	_update_navigation()


func update_roster(entries: Array) -> void:
	roster_entries = entries.duplicate(true)

	# Validate via composition validator
	var valid = not roster_entries.is_empty()
	if valid and _species_book:
		var roster = _build_temp_roster()
		var errors: Array[String] = _CompositionValidator.validate(roster)
		valid = errors.is_empty()

	_step_complete[2] = valid
	_update_navigation()


func get_species_book():  # -> TacticsSpeciesBook
	return _species_book


## One roster entry's points: the unit, its chosen options and its transport. The
## roster and review panels price through this, so the number a player reads is the
## number the validator checks against the points limit.
func entry_cost(entry_dict: Dictionary) -> int:
	return _RosterEntry.from_entry_dict(entry_dict, _species_book).get_total_cost()


func get_validation_errors() -> Array[String]:
	if _species_book:
		var roster = _build_temp_roster()
		return _CompositionValidator.validate(roster)
	return ["No species selected"]


## ============================================================================
## FINALIZE — Create campaign and navigate to dashboard
## ============================================================================

func finalize() -> void:
	if not _can_finish():
		push_warning("[TacticsCreationCoordinator] Cannot finalize — validation failed")
		return
	var campaign = build_campaign()

	# Register with GameState and save
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") \
		if Engine.get_main_loop() else null
	if gs and gs.has_method("set_current_campaign"):
		gs.set_current_campaign(campaign)

	# Save to disk
	var save_dir = "user://saves/"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path = save_dir + campaign.get_campaign_id() + ".save"
	campaign.save_to_file(save_path)

	# Navigate to dashboard
	var router = Engine.get_main_loop().root.get_node_or_null("/root/SceneRouter") \
		if Engine.get_main_loop() else null
	if router and router.has_method("navigate_to"):
		router.navigate_to("tactics_dashboard")


## The campaign the wizard's choices describe, built and started, and NOT registered,
## saved or navigated to. finalize() is the only product caller; the layout sweeps and
## the screen captures build their fixture through here so a swept Tactics screen shows a
## real army rather than a hand-written dict (the Planetfall coordinator's
## build_campaign() has the same split).
func build_campaign():  # -> TacticsCampaignCore
	var campaign = _CampaignCore.create_new_campaign(
		config_data.get("campaign_name", "Tactics Campaign"),
		species_id,
		config_data.get("points_limit", 500),
	)

	# Apply config
	campaign.set_config({
		"campaign_name": config_data.get("campaign_name", ""),
		"army_name": config_data.get("army_name", ""),
		"species_id": species_id,
		"secondary_species_id": secondary_species_id,
		"points_limit": config_data.get("points_limit", 500),
		"org_type": config_data.get("org_type", "platoon"),
		"platoon_count": config_data.get("platoon_count", 1),
		"play_mode": config_data.get("play_mode", "solo"),
		"armored_platoons": config_data.get("armored_platoons", []),
	})

	# Initialize roster
	campaign.initialize_roster(roster_entries)

	# Create campaign units from roster entries
	var campaign_units: Array = []
	for entry_dict in roster_entries:
		# ⚠ Built by TacticsCampaignUnit, not by a literal here. This used to be a
		# hand-written dictionary — a SECOND definition of the record shape beside
		# the one in TacticsCampaignUnit, which is how the two drifted apart and
		# how a fabricated-CP cleanup in that file left this creation path loading a
		# script that no longer parsed.
		campaign_units.append(_CampaignUnit.new_unit(
			str(entry_dict.get("unit_id", "")),
			species_id,
			str(entry_dict.get("display_name", "")),
			int(entry_dict.get("model_count", 5)),
			entry_dict.get("selected_upgrades", []),
			str(entry_dict.get("transport_vehicle_id", ""))))
	campaign.initialize_campaign_units(campaign_units)

	# Starting values only. The p.94 opening (regions, the three opening zones and the
	# Focus) is built ONCE, by TacticsPhaseManager._open_operational_map_if_needed()
	# when turn 1 starts — the same site that opens a legacy save's empty map, so the
	# rule has one grant site rather than two.
	campaign.initialize_operational_map({
		"player_cohesion": 5,
		"enemy_cohesion": 5,
		"player_battle_points": 0,
		"operational_turn": 0,
		"focus_zone_id": "",
		"regions": [],
		"zones": [],
		"orders_history": [],
	})

	# Start campaign
	campaign.start_campaign()
	return campaign


## ============================================================================
## PRIVATE
## ============================================================================

func _build_temp_roster() :
	var roster = _Roster.new()
	roster.points_limit = config_data.get("points_limit", 500)

	var org_str: String = config_data.get("org_type", "platoon")
	roster.org_type = _Roster.OrgType.COMPANY if org_str == "company" \
		else _Roster.OrgType.PLATOON
	roster.platoon_count = config_data.get("platoon_count", 1)
	roster.armored_platoons = config_data.get("armored_platoons", []).duplicate()
	roster.is_pickup = str(config_data.get("play_mode", "solo")) == "versus"
	roster.species_book = _species_book

	for entry_dict in roster_entries:
		roster.entries.append(_RosterEntry.from_entry_dict(entry_dict, _species_book))

	return roster
