class_name TacticsCreationCoordinator
extends Node

## Orchestrates Tactics campaign creation — 5-step wizard.
## Follows the same coordinator pattern as BugHuntCreationCoordinator
## and PlanetfallCreationCoordinator.
##
## Steps:
##   0: Configuration (name, points, org type, play mode)
##   1: Species Selection (primary + optional secondary)
##   2: Army Roster (unit selection, upgrades, composition validation)
##   3: Vehicles (optional — auto-completes if species has no vehicles)
##   4: Final Review

signal navigation_updated(can_back: bool, can_forward: bool, can_finish: bool)
signal step_changed(step: int, total_steps: int)

const STEP_NAMES := [
	"Configuration",
	"Species",
	"Army Roster",
	"Vehicles",
	"Review",
]

var current_step: int = 0
var total_steps: int = 5

## Accumulated creation state
var config_data: Dictionary = {}
var species_id: String = ""
var secondary_species_id: String = ""
var roster_entries: Array = []  # Array of TacticsRosterEntry.to_dict()
var vehicle_entries: Array = []

## Loaded species book (cached after species selection)
var _species_book: TacticsSpeciesBook = null

## Step completion flags
var _step_complete: Array[bool] = [false, false, false, false, false]


func _ready() -> void:
	pass


func go_to_step(step: int) -> void:
	if step < 0 or step >= total_steps:
		return

	# Auto-skip vehicles step if species has no vehicles
	if step == 3 and _species_book and _species_book.vehicles.is_empty():
		_step_complete[3] = true
		# Skip directly to Review (step 4) instead of showing Vehicles
		current_step = 4
		step_changed.emit(current_step, total_steps)
		_update_navigation()
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
	var target: int = current_step - 1
	# Skip vehicles step going backward if species has no vehicles
	if target == 3 and _species_book and _species_book.vehicles.is_empty():
		target = 2
	go_to_step(target)


func get_step_name(step: int = -1) -> String:
	if step < 0:
		step = current_step
	if step >= 0 and step < STEP_NAMES.size():
		return STEP_NAMES[step]
	return "Unknown"


func _update_navigation() -> void:
	var can_back := current_step > 0
	var can_forward := current_step < total_steps - 1 and _step_complete[current_step]
	var can_finish := current_step == total_steps - 1 and _can_finish()
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
		_species_book = TacticsSpeciesBookLoader.load_species_book(species_id)

	_step_complete[1] = not species_id.is_empty()

	# Reset downstream steps when species changes
	roster_entries.clear()
	vehicle_entries.clear()
	_step_complete[2] = false
	_step_complete[3] = false
	_step_complete[4] = false

	_update_navigation()


func update_roster(entries: Array) -> void:
	roster_entries = entries.duplicate(true)

	# Validate via composition validator
	var valid := not roster_entries.is_empty()
	if valid and _species_book:
		var roster := _build_temp_roster()
		var errors: Array[String] = TacticsCompositionValidator.validate(roster)
		valid = errors.is_empty()

	_step_complete[2] = valid
	_update_navigation()


func update_vehicles(entries: Array) -> void:
	vehicle_entries = entries.duplicate(true)
	_step_complete[3] = true  # Vehicles are always optional
	_update_navigation()


func get_species_book() -> TacticsSpeciesBook:
	return _species_book


func get_validation_errors() -> Array[String]:
	if _species_book:
		var roster := _build_temp_roster()
		return TacticsCompositionValidator.validate(roster)
	return ["No species selected"]


## ============================================================================
## FINALIZE — Create campaign and navigate to dashboard
## ============================================================================

func finalize() -> void:
	if not _can_finish():
		push_warning("[TacticsCreationCoordinator] Cannot finalize — validation failed")
		return

	# Create campaign core
	var campaign := TacticsCampaignCore.create_new_campaign(
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
	})

	# Initialize roster
	campaign.initialize_roster(roster_entries)

	# Create campaign units from roster entries
	var campaign_units: Array = []
	for entry_dict in roster_entries:
		var unit_dict: Dictionary = {
			"unit_id": TacticsCampaignUnit.generate_id(),
			"custom_name": entry_dict.get("display_name", ""),
			"base_unit_id": entry_dict.get("unit_id", ""),
			"species_id": species_id,
			"campaign_points": 0,
			"campaign_points_spent": 0,
			"battles_fought": 0,
			"battles_won": 0,
			"objectives_completed": 0,
			"models_lost_total": 0,
			"current_models": entry_dict.get("model_count", 5),
			"is_destroyed": false,
			"selected_upgrades": entry_dict.get("selected_upgrades", []),
		}
		campaign_units.append(unit_dict)
	campaign.initialize_campaign_units(campaign_units)

	# Initialize empty operational map
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

	# Register with GameState and save
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") \
		if Engine.get_main_loop() else null
	if gs and gs.has_method("set_current_campaign"):
		gs.set_current_campaign(campaign)

	# Save to disk
	var save_dir := "user://saves/"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path := save_dir + campaign.get_campaign_id() + ".save"
	campaign.save_to_file(save_path)

	# Navigate to dashboard
	var router = Engine.get_main_loop().root.get_node_or_null("/root/SceneRouter") \
		if Engine.get_main_loop() else null
	if router and router.has_method("navigate_to"):
		router.navigate_to("tactics_dashboard")


## ============================================================================
## PRIVATE
## ============================================================================

func _build_temp_roster() -> TacticsRoster:
	var roster := TacticsRoster.new()
	roster.points_limit = config_data.get("points_limit", 500)

	var org_str: String = config_data.get("org_type", "platoon")
	roster.org_type = TacticsRoster.OrgType.COMPANY if org_str == "company" \
		else TacticsRoster.OrgType.PLATOON
	roster.platoon_count = config_data.get("platoon_count", 1)
	roster.species_book = _species_book

	# Build entries from stored dicts
	for entry_dict in roster_entries:
		var entry := TacticsRosterEntry.new()
		entry.entry_id = entry_dict.get("entry_id", "")
		entry.platoon_index = entry_dict.get("platoon_index", 0)
		entry.model_count = entry_dict.get("model_count", 0)
		entry.display_name = entry_dict.get("display_name", "")

		# Resolve base profile from species book
		var unit_id: String = entry_dict.get("unit_id", "")
		if _species_book and not unit_id.is_empty():
			entry.base_profile = _species_book.get_unit_profile(unit_id)

		roster.entries.append(entry)

	return roster
