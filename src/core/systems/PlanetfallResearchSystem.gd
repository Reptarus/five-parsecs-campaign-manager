class_name PlanetfallResearchSystem
extends RefCounted

## Manages Planetfall research: theories, applications, prerequisites.
## Loads research_tree.json and provides queries + state mutation.
## Theory cost = RP to unlock theory. Application cost = RP per application.
## Applications are randomly selected from unlocked theory's pool.
## Source: Planetfall pp.91-96

var _theories: Array = []
var _loaded: bool = false


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


func get_available_theories(campaign: Resource) -> Array:
	## Returns theories whose prerequisites are met and not yet completed.
	var result: Array = []
	for theory in _theories:
		if theory is not Dictionary:
			continue
		var tid: String = theory.get("id", "")
		if is_theory_available(campaign, tid) and not is_theory_researched(campaign, tid):
			result.append(theory.duplicate(true))
	return result


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
	var theory_cost: int = theory.get("theory_cost", 0)
	var progress: int = get_theory_progress(campaign, theory_id)
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

	var app_cost: int = theory.get("application_cost", 0)
	var current_rp: int = get_current_rp(campaign)
	if current_rp < app_cost:
		return {"success": false, "error": "Not enough RP (%d needed)" % app_cost}

	# Deduct RP
	var rd: Dictionary = _get_research_data(campaign)
	rd["current_rp"] = current_rp - app_cost

	# Randomly select application
	var app: Dictionary = available[randi_range(0, available.size() - 1)]
	var aid: String = app.get("id", "")

	if not rd.has("unlocked_applications"):
		rd["unlocked_applications"] = []
	rd["unlocked_applications"].append(aid)

	# Apply immediate bonus effects
	var effect: Dictionary = app.get("effect", {})
	_apply_application_effect(campaign, effect)

	_set_research_data(campaign, rd)
	return {"success": true, "application": app}


func add_research_points(campaign: Resource, amount: int) -> void:
	## Add RP to the campaign pool.
	var rd: Dictionary = _get_research_data(campaign)
	rd["current_rp"] = rd.get("current_rp", 0) + amount
	_set_research_data(campaign, rd)


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
	if effect.has("colony_integrity") and campaign.has_method("adjust_integrity"):
		campaign.adjust_integrity(effect.get("colony_integrity", 0))
	if effect.has("augmentation_points") and "augmentation_points" in campaign:
		campaign.augmentation_points += effect.get("augmentation_points", 0)
	if effect.has("research_points_per_turn") and "research_points_per_turn" in campaign:
		campaign.research_points_per_turn += effect.get("research_points_per_turn", 0)


func is_loaded() -> bool:
	return _loaded
