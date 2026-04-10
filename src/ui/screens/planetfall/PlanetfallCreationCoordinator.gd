class_name PlanetfallCreationCoordinator
extends Node

## Orchestrates Planetfall campaign creation — 6-step wizard.
## Follows the same coordinator pattern as BugHuntCreationCoordinator.
##
## Steps:
##   0: Expedition Type (D100 roll)
##   1: Character Roster (class selection, sub-species, imports)
##   2: Backgrounds (Motivation + Prior Experience + Notable Event)
##   3: Map Generation (grid size, home sector, investigation sites)
##   4: Tutorial Missions (Beacons/Analysis/Perimeter — play or skip)
##   5: Final Review

signal navigation_updated(can_back: bool, can_forward: bool, can_finish: bool)
signal step_changed(step: int, total_steps: int)

var current_step: int = 0
var total_steps: int = 6

## Accumulated creation state
var config_data: Dictionary = {}
var roster_data: Array = []
var background_data: Dictionary = {}
var map_config: Dictionary = {}
var tutorial_results: Dictionary = {}

## Step completion flags
var _step_complete: Array[bool] = [false, false, false, false, false, false]


func _ready() -> void:
	pass


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
	if current_step > 0:
		go_to_step(current_step - 1)


func _update_navigation() -> void:
	var can_back := current_step > 0
	var can_forward := current_step < total_steps - 1 and _step_complete[current_step]
	var can_finish := current_step == total_steps - 1 and _can_finish()
	navigation_updated.emit(can_back, can_forward, can_finish)


func _can_finish() -> bool:
	# Must have expedition type, roster, and backgrounds at minimum
	return _step_complete[0] and _step_complete[1] and _step_complete[2]


## ============================================================================
## STATE UPDATE METHODS (called by panels via signals)
## ============================================================================

func update_expedition(data: Dictionary) -> void:
	config_data.merge(data, true)
	_step_complete[0] = data.has("expedition_type") and not data.expedition_type.is_empty()
	_update_navigation()


func update_roster(characters: Array) -> void:
	roster_data = characters.duplicate(true)
	# Validate: at least 3 characters, min 1 of each class
	var class_counts := {"scientist": 0, "scout": 0, "trooper": 0}
	for char_dict in roster_data:
		var cls: String = char_dict.get("class", "")
		if class_counts.has(cls):
			class_counts[cls] += 1
	var valid := roster_data.size() >= 3
	for cls in class_counts:
		if class_counts[cls] < 1:
			valid = false
	_step_complete[1] = valid
	_update_navigation()


func update_backgrounds(data: Dictionary) -> void:
	background_data = data.duplicate(true)
	# All characters must have motivation assigned
	var all_have_motivation := true
	for char_dict in roster_data:
		var cid: String = char_dict.get("id", "")
		if not background_data.has(cid) or not background_data[cid].has("motivation"):
			all_have_motivation = false
			break
	_step_complete[2] = all_have_motivation
	_update_navigation()


func update_map_config(data: Dictionary) -> void:
	map_config = data.duplicate(true)
	_step_complete[3] = data.has("grid_size")
	_update_navigation()


func update_tutorial_results(data: Dictionary) -> void:
	tutorial_results = data.duplicate(true)
	_step_complete[4] = true  # Tutorial is always optional — can skip
	_update_navigation()


func skip_tutorials() -> void:
	_step_complete[4] = true
	_update_navigation()


func mark_review_seen() -> void:
	_step_complete[5] = true
	_update_navigation()


## ============================================================================
## FINALIZATION
## ============================================================================

func finalize() -> void:
	if not _can_finish():
		push_warning("PlanetfallCreationCoordinator: Cannot finalize — incomplete steps")
		return

	var campaign := PlanetfallCampaignCore.new()

	# Config
	var campaign_name: String = config_data.get("campaign_name", "New Colony")
	var colony_name: String = config_data.get("colony_name", campaign_name)
	campaign.set_config({
		"campaign_name": campaign_name,
		"colony_name": colony_name,
		"expedition_type": config_data.get("expedition_type", ""),
		"difficulty": config_data.get("difficulty", "normal")
	})

	# Apply expedition bonuses
	_apply_expedition_bonus(campaign)

	# Initialize roster with backgrounds applied
	var final_roster: Array = []
	for char_dict in roster_data:
		var enriched: Dictionary = char_dict.duplicate(true)
		var cid: String = char_dict.get("id", "")
		if background_data.has(cid):
			var bg: Dictionary = background_data[cid]
			enriched["motivation"] = bg.get("motivation", "")
			enriched["prior_experience"] = bg.get("prior_experience", "")
			enriched["notable_event"] = bg.get("notable_event", "")
			# Apply stat bonuses from prior experience
			if bg.has("bonus_stat"):
				var stat: String = bg.bonus_stat
				var bonus: int = bg.get("bonus_value", 0)
				enriched[stat] = enriched.get(stat, 0) + bonus
			if bg.has("bonus_xp"):
				enriched["xp"] = enriched.get("xp", 0) + bg.bonus_xp
			if bg.has("bonus_loyalty"):
				enriched["loyalty"] = bg.bonus_loyalty
			if bg.has("bonus_kp"):
				enriched["kp"] = enriched.get("kp", 0) + bg.bonus_kp
			if bg.has("bonus_story_point"):
				campaign.add_story_points(bg.bonus_story_point)
		final_roster.append(enriched)
	campaign.initialize_roster(final_roster)

	# Apply tutorial bonuses
	if tutorial_results.get("beacons_success", false):
		campaign.add_raw_materials(2)
	if tutorial_results.get("analysis_success", false):
		var rp_bonus: int = 3 if tutorial_results.get("analysis_all_six", false) else 2
		campaign.research_points_per_turn += 0  # RP bonus is one-time, not per-turn
		# Store as starting RP (will be handled by research system)
		campaign.research_data["starting_rp"] = rp_bonus
	if tutorial_results.get("perimeter_success", false):
		campaign.adjust_morale(3)
	campaign.tutorial_missions = tutorial_results.get("missions", {
		"beacons": false, "analysis": false, "perimeter": false
	})

	# Initialize map
	var grid_rows: int = map_config.get("grid_rows", 6)
	var grid_cols: int = map_config.get("grid_cols", 6)
	campaign.initialize_map({
		"grid_size": [grid_rows, grid_cols],
		"home_sector": map_config.get("home_sector", [0, 0]),
		"investigation_sites": map_config.get("investigation_sites", []),
		"sectors": {}
	})

	# Initialize default colony equipment pool (standard weapons by class)
	campaign.initialize_equipment_pool([])

	# Start campaign
	campaign.start_campaign()

	# Register with GameState
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_current_campaign"):
		game_state.set_current_campaign(campaign)

	# Save to disk
	var save_dir := "user://saves/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path := save_dir + campaign.get_campaign_id() + ".save"
	campaign.save_to_file(save_path)

	# Navigate to dashboard
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("planetfall_dashboard")


func _apply_expedition_bonus(campaign: PlanetfallCampaignCore) -> void:
	var exp_type: String = config_data.get("expedition_type", "")
	# Load from JSON
	var json_path := "res://data/planetfall/expedition_types.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Dictionary = json.data
	for entry in data.get("entries", []):
		if entry.get("type", "") == exp_type:
			var bonus: Dictionary = entry.get("bonus", {})
			if bonus.has("research_points"):
				campaign.research_data["starting_rp"] = campaign.research_data.get("starting_rp", 0) + bonus.research_points
			if bonus.has("raw_materials"):
				campaign.add_raw_materials(bonus.raw_materials)
			if bonus.has("story_points"):
				campaign.add_story_points(bonus.story_points)
			if bonus.has("grunts"):
				campaign.gain_grunts(bonus.grunts)
			if bonus.has("colony_morale"):
				campaign.adjust_morale(bonus.colony_morale)
			if bonus.has("extra_investigation_sites"):
				map_config["extra_investigation_sites"] = bonus.extra_investigation_sites
			break


## ============================================================================
## DATA ACCESS (for review panel)
## ============================================================================

func get_all_data() -> Dictionary:
	return {
		"config": config_data.duplicate(true),
		"roster": roster_data.duplicate(true),
		"backgrounds": background_data.duplicate(true),
		"map_config": map_config.duplicate(true),
		"tutorial_results": tutorial_results.duplicate(true)
	}
