class_name PlanetfallResearchSystem
extends RefCounted

## Manages Planetfall research: theories, applications, prerequisites.
## Loads research_tree.json and provides queries + state mutation.
## Theory cost = RP to unlock theory. Application cost = RP per application.
## Applications are randomly selected from unlocked theory's pool.
## Source: Planetfall pp.91-96

## p.93: "randomly select from the Applications you have not yet discovered ... Use any
## appropriate die type." PlanetfallMap.pick_index is that die (smallest that covers the
## count, high rolls rerolled), forceable under this context.
const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const EventResolverScript := preload("res://src/core/systems/PlanetfallEventResolver.gd")
const APPLICATION_DIE := "Planetfall Research Application"
const BIO_ANALYSIS_PATH := "res://data/planetfall/bio_analysis.json"
const BIO_ANALYSIS_DIE := "Planetfall Bio-Analysis"

var _theories: Array = []
var _loaded: bool = false
var _bio: Dictionary = {}


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var path := "res://data/planetfall/research_tree.json"
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallResearchSystem: JSON not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if json.data is Dictionary:
		_theories = json.data.get("theories", [])
	_loaded = not _theories.is_empty()


## ============================================================================
## QUERIES
## ============================================================================

func get_all_theories() -> Array:
	return _theories.duplicate(true)


func get_theory(theory_id: String) -> Dictionary:
	for theory in _theories:
		if theory is Dictionary and theory.get("id", "") == theory_id:
			return theory.duplicate(true)
	return {}


func is_theory_available(campaign: Resource, theory_id: String) -> bool:
	## A theory is available if all its prerequisites are fully researched.
	var theory: Dictionary = get_theory(theory_id)
	if theory.is_empty():
		return false
	var prereqs: Array = theory.get("prerequisites", [])
	for prereq_id in prereqs:
		if not is_theory_researched(campaign, str(prereq_id)):
			return false
	return true


func is_theory_researched(campaign: Resource, theory_id: String) -> bool:
	## A theory is fully researched if its full RP cost has been paid.
	var rd: Dictionary = _get_research_data(campaign)
	var completed: Array = rd.get("completed_theories", [])
	return completed.has(theory_id)


func is_application_unlocked(
		campaign: Resource, application_id: String) -> bool:
	var rd: Dictionary = _get_research_data(campaign)
	var unlocked: Array = rd.get("unlocked_applications", [])
	return unlocked.has(application_id)


func get_theory_progress(campaign: Resource, theory_id: String) -> int:
	## Returns RP invested so far toward this theory.
	var rd: Dictionary = _get_research_data(campaign)
	var progress: Dictionary = rd.get("theory_progress", {})
	return progress.get(theory_id, 0)


func get_available_applications(
		campaign: Resource, theory_id: String) -> Array:
	## Returns applications from a completed theory that haven't been unlocked.
	if not is_theory_researched(campaign, theory_id):
		return []
	var theory: Dictionary = get_theory(theory_id)
	var apps: Array = theory.get("applications", [])
	var result: Array = []
	for app in apps:
		if app is Dictionary:
			var aid: String = app.get("id", "")
			if not is_application_unlocked(campaign, aid):
				result.append(app.duplicate(true))
	return result


## The Application that unlocks `building_id` (p.93 "(Building)"), with its Theory's
## name added as `theory_name`; {} when no Application does.
## An Application by its id, with the Theory it sits under. Empty when unknown.
func get_application(app_id: String) -> Dictionary:
	if app_id == "":
		return {}
	for theory in _theories:
		if theory is not Dictionary:
			continue
		for app in theory.get("applications", []):
			if app is Dictionary and str(app.get("id", "")) == app_id:
				var found: Dictionary = (app as Dictionary).duplicate(true)
				found["theory_id"] = str(theory.get("id", ""))
				found["theory_name"] = str(theory.get("name", ""))
				return found
	return {}


func application_for_building(building_id: String) -> Dictionary:
	if building_id == "":
		return {}
	for theory in _theories:
		if theory is not Dictionary:
			continue
		for app in theory.get("applications", []):
			if app is Dictionary and str(app.get("unlocks_building", "")) == building_id:
				var found: Dictionary = (app as Dictionary).duplicate(true)
				found["theory_id"] = str(theory.get("id", ""))
				found["theory_name"] = str(theory.get("name", ""))
				return found
	return {}


func get_current_rp(campaign: Resource) -> int:
	var rd: Dictionary = _get_research_data(campaign)
	return rd.get("current_rp", 0)


## ============================================================================
## MUTATION
## ============================================================================

func invest_in_theory(
		campaign: Resource, theory_id: String, rp_amount: int) -> Dictionary:
	## Invest RP toward a theory. Returns {success, remaining_cost, completed}.
	var theory: Dictionary = get_theory(theory_id)
	if theory.is_empty():
		return {"success": false, "error": "Unknown theory"}
	if not is_theory_available(campaign, theory_id):
		return {"success": false, "error": "Prerequisites not met"}
	if is_theory_researched(campaign, theory_id):
		return {"success": false, "error": "Already completed"}

	var current_rp: int = get_current_rp(campaign)
	if current_rp < rp_amount:
		return {"success": false, "error": "Not enough RP"}

	var rd: Dictionary = _get_research_data(campaign)
	var progress: int = get_theory_progress(campaign, theory_id)
	# p.136: a Theory STARTED while a translation discount is pending takes it.
	if progress == 0 and _take_discount(rd):
		var discounted: Array = rd.get("discounted_theories", [])
		discounted.append(theory_id)
		rd["discounted_theories"] = discounted
	var theory_cost: int = theory_cost_for(campaign, theory_id)
	var invest: int = mini(rp_amount, theory_cost - progress)

	# Deduct RP
	rd["current_rp"] = current_rp - invest

	# Add progress
	if not rd.has("theory_progress"):
		rd["theory_progress"] = {}
	rd["theory_progress"][theory_id] = progress + invest

	# Check completion
	var completed: bool = (progress + invest) >= theory_cost
	if completed:
		if not rd.has("completed_theories"):
			rd["completed_theories"] = []
		rd["completed_theories"].append(theory_id)

	_set_research_data(campaign, rd)
	return {
		"success": true,
		"invested": invest,
		"remaining_cost": max(0, theory_cost - progress - invest),
		"completed": completed
	}


func research_application(
		campaign: Resource, theory_id: String) -> Dictionary:
	## Pay application cost and randomly unlock one application.
	## Returns {success, application, error}.
	var theory: Dictionary = get_theory(theory_id)
	if theory.is_empty():
		return {"success": false, "error": "Unknown theory"}
	if not is_theory_researched(campaign, theory_id):
		return {"success": false, "error": "Theory not yet completed"}

	var available: Array = get_available_applications(campaign, theory_id)
	if available.is_empty():
		return {"success": false, "error": "All applications already unlocked"}

	var app_cost: int = application_cost_for(campaign, theory_id)
	var current_rp: int = get_current_rp(campaign)
	if current_rp < app_cost:
		return {"success": false, "error": "Not enough RP (%d needed)" % app_cost}

	# Deduct RP
	var rd: Dictionary = _get_research_data(campaign)
	rd["current_rp"] = current_rp - app_cost
	if app_cost < int(theory.get("application_cost", 0)):
		_take_discount(rd)

	# p.93: randomly select from the undiscovered Applications. It was a raw randi_range,
	# which no QA seam could force.
	var app: Dictionary = available[MapScript.pick_index(available.size(), APPLICATION_DIE)]
	var aid: String = app.get("id", "")

	if not rd.has("unlocked_applications"):
		rd["unlocked_applications"] = []
	rd["unlocked_applications"].append(aid)

	# Apply immediate bonus effects
	var effect: Dictionary = app.get("effect", {})
	_apply_application_effect(campaign, effect)

	_set_research_data(campaign, rd)
	return {"success": true, "application": app}


## ============================================================================
## RESEARCH COSTS (p.136 Alien translation guide)
## ============================================================================

## A Theory's full cost, halved (rounded up) when it was started under a discount.
func theory_cost_for(campaign: Resource, theory_id: String) -> int:
	var cost: int = int(get_theory(theory_id).get("theory_cost", 0))
	var rd: Dictionary = _get_research_data(campaign)
	return _halved(cost) if theory_id in rd.get("discounted_theories", []) else cost


## What finishing this Theory costs if RP is invested now: a Theory not yet started takes
## a pending discount with its first investment (invest_in_theory).
func theory_cost_now(campaign: Resource, theory_id: String) -> int:
	var cost: int = theory_cost_for(campaign, theory_id)
	var started: bool = get_theory_progress(campaign, theory_id) > 0 \
			or theory_id in _get_research_data(campaign).get("discounted_theories", [])
	return _halved(cost) if not started and discounts_left(campaign) > 0 else cost


## What the next Application of this Theory costs right now.
func application_cost_for(campaign: Resource, theory_id: String) -> int:
	var cost: int = int(get_theory(theory_id).get("application_cost", 0))
	return _halved(cost) if discounts_left(campaign) > 0 else cost


## p.136: "The next two research topics have their Research Point cost halved, rounded up."
func discounts_left(campaign: Resource) -> int:
	return int(_get_research_data(campaign).get("cost_halved_remaining", 0))


func _take_discount(rd: Dictionary) -> bool:
	var left: int = int(rd.get("cost_halved_remaining", 0))
	if left <= 0:
		return false
	rd["cost_halved_remaining"] = left - 1
	return true


static func _halved(cost: int) -> int:
	return ceili(cost / 2.0)


## ============================================================================
## BIO-ANALYSIS (p.92)
## ============================================================================

## p.92: "You may research any Lifeform on your campaign encounter chart ... You must
## collect a sample from the Lifeform in question by successfully completing a Hunt
## mission. Once a sample has been collected, you may conduct Bio-Analysis by spending 3
## Research Points. Roll 1D6 on the table below". One benefit per form of the creature:
## a profile change clears both the sample and the benefit (PlanetfallLifeformGenerator).
func bio_analysis_cost(campaign: Resource) -> int:
	var cost: int = int(_bio_data().get("cost_rp", 3))
	return _halved(cost) if discounts_left(campaign) > 0 else cost


## The encounter entries a player can see at the Research step: sampled ones, and any
## already analyzed. [{slot, name, analysis}].
func bio_analysis_candidates(campaign: Resource) -> Array:
	var out: Array = []
	if not campaign or not "lifeform_table" in campaign:
		return out
	for i in range(campaign.lifeform_table.size()):
		var e: Variant = campaign.lifeform_table[i]
		if e is Dictionary and (bool(e.get("sampled", false)) or e.has("bio_analysis")):
			out.append({"slot": i, "name": str(e.get("name", "Encounter entry %d" % (i + 1))),
				"analysis": e.get("bio_analysis", {})})
	return out


## Returns {success, roll, entry, cost} or {success: false, error}.
func conduct_bio_analysis(campaign: Resource, slot: int) -> Dictionary:
	if not campaign or not "lifeform_table" in campaign \
			or slot < 0 or slot >= campaign.lifeform_table.size() \
			or not campaign.lifeform_table[slot] is Dictionary:
		return {"success": false, "error": "No such Lifeform"}
	var entry: Dictionary = campaign.lifeform_table[slot]
	if not bool(entry.get("sampled", false)):
		return {"success": false, "error": "No sample collected: complete a Hunt (p.121)"}
	if entry.has("bio_analysis"):
		return {"success": false, "error": "Already analyzed in this form (p.92)"}
	var cost: int = bio_analysis_cost(campaign)
	var rd: Dictionary = _get_research_data(campaign)
	var current_rp: int = get_current_rp(campaign)
	if current_rp < cost:
		return {"success": false, "error": "Not enough RP (%d needed)" % cost}
	rd["current_rp"] = current_rp - cost
	if cost < int(_bio_data().get("cost_rp", 3)):
		_take_discount(rd)
	var roll: int = EventResolverScript.new().roll_d6(BIO_ANALYSIS_DIE)
	var found: Dictionary = {}
	for e in _bio_data().get("entries", []):
		if e is Dictionary and int(e.get("roll", 0)) == roll:
			found = e
	entry["bio_analysis"] = {"id": str(found.get("id", "")), "name": str(found.get("name", "")),
		"description": str(found.get("description", ""))}
	_set_research_data(campaign, rd)
	return {"success": true, "roll": roll, "entry": entry["bio_analysis"], "cost": cost}


func _bio_data() -> Dictionary:
	if _bio.is_empty() and FileAccess.file_exists(BIO_ANALYSIS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIO_ANALYSIS_PATH))
		_bio = parsed if parsed is Dictionary else {}
	return _bio


## ============================================================================
## PRIVATE
## ============================================================================

func _get_research_data(campaign: Resource) -> Dictionary:
	if not campaign or not "research_data" in campaign:
		return {}
	return campaign.research_data


func _set_research_data(campaign: Resource, data: Dictionary) -> void:
	if campaign and "research_data" in campaign:
		campaign.research_data = data


func _apply_application_effect(
		campaign: Resource, effect: Dictionary) -> void:
	if effect.is_empty() or not campaign:
		return
	if effect.has("colony_morale") and campaign.has_method("adjust_morale"):
		campaign.adjust_morale(effect.get("colony_morale", 0))
	# p.87: an Integrity BONUS raises the maximum with the current score.
	if effect.has("colony_integrity") and campaign.has_method("raise_integrity"):
		campaign.raise_integrity(effect.get("colony_integrity", 0))
	if effect.has("augmentation_points") and "augmentation_points" in campaign:
		campaign.augmentation_points += effect.get("augmentation_points", 0)
	if effect.has("research_points_per_turn") and "research_points_per_turn" in campaign:
		campaign.research_points_per_turn += effect.get("research_points_per_turn", 0)


func is_loaded() -> bool:
	return _loaded
