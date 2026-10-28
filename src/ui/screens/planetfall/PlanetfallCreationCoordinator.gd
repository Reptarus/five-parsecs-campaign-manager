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

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const RosterRulesScript := preload("res://src/core/systems/PlanetfallRosterRules.gd")
const BackgroundsScript := preload("res://src/core/systems/PlanetfallBackgrounds.gd")

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


func is_step_complete(step: int) -> bool:
	return step >= 0 and step < _step_complete.size() and _step_complete[step]


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


## The roster step is done when RosterRules finds nothing wrong (pp.14-20): the screen
## lists the same problems, so the Next button and the warnings cannot disagree. Until
## 2026-10-28 any roster of 3 or more passed, against the book's eight, and sub-species
## limits were not checked. Backgrounds rolled for a character no longer on the roster
## are dropped, so a changed roster never carries a stale result.
func update_roster(characters: Array) -> void:
	roster_data = characters.duplicate(true)
	_step_complete[1] = RosterRulesScript.roster_problems(roster_data).is_empty()
	var ids: Dictionary = {}
	for c in roster_data:
		ids[str(c.get("id", ""))] = true
	for cid in background_data.keys():
		if not ids.has(cid):
			background_data.erase(cid)
	_step_complete[2] = BackgroundsScript.backgrounds_complete(roster_data, background_data)
	_update_navigation()


## Done when every character has a Motivation and exactly four, chosen by the player,
## also have Prior Experience and a Notable Event (p.21).
func update_backgrounds(data: Dictionary) -> void:
	background_data = data.duplicate(true)
	_step_complete[2] = BackgroundsScript.backgrounds_complete(roster_data, background_data)
	_update_navigation()


func update_map_config(data: Dictionary) -> void:
	map_config = data.duplicate(true)
	# p.53: the map step is done once the grid and the home sector are chosen.
	_step_complete[3] = data.has("grid_size") and data.has("home_sector")
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

	var campaign: PlanetfallCampaignCore = build_campaign()

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


## The colony the wizard's choices describe, built and started but not saved, registered
## or navigated to. finalize() is the app's caller; the screen-capture harness and the
## tests build their colony here too, so there is one way to found one.
func build_campaign() -> PlanetfallCampaignCore:
	var campaign := PlanetfallCampaignCore.new()

	# Config
	campaign.set_config({
		"campaign_name": campaign_name(),
		"colony_name": colony_name(),
		"expedition_type": config_data.get("expedition_type", ""),
		"difficulty": config_data.get("difficulty", "normal")
	})

	# Apply expedition bonuses
	_apply_expedition_bonus(campaign)

	# Initialize roster with backgrounds applied
	var final_roster: Array = []
	for char_dict in roster_data:
		var bg: Dictionary = background_data.get(str(char_dict.get("id", "")), {})
		final_roster.append(BackgroundsScript.apply_to(char_dict, bg))
		if bg.has("bonus_story_point"):
			campaign.add_story_points(int(bg.bonus_story_point))
	campaign.initialize_roster(final_roster)

	# Apply tutorial bonuses
	if tutorial_results.get("beacons_success", false):
		campaign.add_raw_materials(2)
	if tutorial_results.get("analysis_success", false):
		var rp_bonus: int = 3 if tutorial_results.get("analysis_all_six", false) else 2
		# Award into current_rp, the pool the colony actually spends.
		#
		# This used to write research_data["starting_rp"] with the comment "will be
		# handled by research system" — that handling was never built.
		# `starting_rp` has ZERO readers anywhere in src/; every consumer reads
		# current_rp (PlanetfallResearchSystem.get_current_rp:116,
		# PlanetfallPostMissionSystem:86/114, PlanetfallMissionDataSystem:180,
		# PlanetfallEndGameSystem:185). The key round-tripped through the save
		# perfectly, so the loss looked like it had persisted correctly while the
		# player never received the points.
		campaign.research_data["current_rp"] = \
			int(campaign.research_data.get("current_rp", 0)) + rp_bonus
	if tutorial_results.get("perimeter_success", false):
		campaign.adjust_morale(3)
	campaign.tutorial_missions = tutorial_results.get("missions", {
		"beacons": false, "analysis": false, "perimeter": false
	})

	# The map (pp.52-53): the grid and home sector the player chose, and the Investigation
	# Sites rolled once, here, through DiceManager: 10, plus the expedition's own (p.52
	# Corporate Funded "2 additional"), which PlanetfallMap.site_count_for reads.
	var home: Array = []
	if map_config.get("home_sector") is Array:
		home = map_config.home_sector
	MapScript.generate(campaign, int(map_config.get("grid_rows", MapScript.DEFAULT_SIZE)),
			int(map_config.get("grid_cols", MapScript.DEFAULT_SIZE)), home,
			MapScript.site_count_for(str(campaign.expedition_type)))

	# Start campaign
	campaign.start_campaign()
	return campaign


func _apply_expedition_bonus(campaign: PlanetfallCampaignCore) -> void:
	var entry: Dictionary = expedition_entry()
	if not entry.is_empty():
		var bonus: Dictionary = entry.get("bonus", {})
		if bonus.has("research_points"):
			# current_rp, not starting_rp — see the tutorial award above. This is
			# the "Scientific Mission" expedition's 3 RP
			# (data/planetfall/expedition_types.json), one of six player-selectable
			# options at creation, and it was landing in a key nothing reads while
			# every sibling bonus below used a real mutator.
			campaign.research_data["current_rp"] = \
				int(campaign.research_data.get("current_rp", 0)) + int(bonus.research_points)
		if bonus.has("raw_materials"):
			campaign.add_raw_materials(bonus.raw_materials)
		if bonus.has("story_points"):
			campaign.add_story_points(bonus.story_points)
		if bonus.has("grunts"):
			campaign.gain_grunts(bonus.grunts)
		if bonus.has("colony_morale"):
			campaign.adjust_morale(bonus.colony_morale)
		# extra_investigation_sites (Corporate Funded) is read by the map itself,
		# PlanetfallMap.site_count_for(); it was copied into map_config here, where
		# nothing read it, so the two sites were never placed.


## ============================================================================
## DATA ACCESS (for review panel)
## ============================================================================

const DEFAULT_CAMPAIGN_NAME := "New Colony"


## The name the colony will be founded under: what the player typed, or the default
## when the box is empty. A cleared box stores "" under the key, so .get(key, default)
## alone returned the empty string and founded a nameless colony.
func campaign_name() -> String:
	var typed: String = str(config_data.get("campaign_name", "")).strip_edges()
	return typed if typed != "" else DEFAULT_CAMPAIGN_NAME


## "Name your colony (or leave blank for campaign name)" (the step 1 hint).
func colony_name() -> String:
	var typed: String = str(config_data.get("colony_name", "")).strip_edges()
	return typed if typed != "" else campaign_name()


## The p.52 Expedition Type row the player rolled, or {} before the roll.
func expedition_entry() -> Dictionary:
	var exp_type: String = str(config_data.get("expedition_type", ""))
	if exp_type == "":
		return {}
	var file := FileAccess.open("res://data/planetfall/expedition_types.json", FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("entries", []):
			if entry is Dictionary and str(entry.get("type", "")) == exp_type:
				return entry
	return {}

func get_all_data() -> Dictionary:
	return {
		"config": config_data.duplicate(true),
		"roster": roster_data.duplicate(true),
		"backgrounds": background_data.duplicate(true),
		"map_config": map_config.duplicate(true),
		"tutorial_results": tutorial_results.duplicate(true)
	}
