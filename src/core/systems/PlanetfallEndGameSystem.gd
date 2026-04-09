class_name PlanetfallEndGameSystem
extends RefCounted

## Manages the End Game sequence: Summit, Colony Security check,
## Final Milestone construction, and path resolution.
## 4 paths: Independence, Ascension, Loyalty, Isolation.
## Source: Planetfall pp.160-164

var _endgame_data: Dictionary = {}
var _summit_entries: Array = []
var _security_requirements: Dictionary = {}
var _final_milestones: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	_endgame_data = _load_json("res://data/planetfall/endgame.json")

	var summit: Dictionary = _endgame_data.get("summit", {})
	_summit_entries = summit.get("entries", [])

	var security: Dictionary = _endgame_data.get("colony_security", {})
	_security_requirements = security.get("requirements", {})

	_final_milestones = _endgame_data.get("final_milestones", {})

	_loaded = not _summit_entries.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallEndGameSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallEndGameSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## SUMMIT
## ============================================================================

func run_summit(campaign: Resource) -> Dictionary:
	## Roll D6 per roster character (not bots/grunts) plus 1 for population.
	## Returns {votes: Array, available_paths: Array}.
	var votes: Dictionary = {
		"independence": 0, "ascension": 0,
		"loyalty": 0, "isolation": 0, "no_opinion": 0
	}
	var individual_votes: Array = []

	if not campaign or not "roster" in campaign:
		return {"votes": votes, "available_paths": [], "individual_votes": []}

	# Roll for each roster character (exclude bots)
	for char_dict in campaign.roster:
		if char_dict is not Dictionary:
			continue
		var cclass: String = char_dict.get("class", "")
		if cclass == "bot":
			continue
		var roll: int = randi_range(1, 6)
		var vote: Dictionary = _resolve_summit_vote(roll)
		var vote_id: String = vote.get("id", "no_opinion")
		votes[vote_id] = votes.get(vote_id, 0) + 1
		individual_votes.append({
			"character": char_dict.get("name", "Unknown"),
			"roll": roll,
			"vote": vote_id,
			"vote_name": vote.get("name", "No opinion")
		})

	# Population vote
	var pop_roll: int = randi_range(1, 6)
	var pop_vote: Dictionary = _resolve_summit_vote(pop_roll)
	var pop_id: String = pop_vote.get("id", "no_opinion")
	votes[pop_id] = votes.get(pop_id, 0) + 1
	individual_votes.append({
		"character": "General Population",
		"roll": pop_roll,
		"vote": pop_id,
		"vote_name": pop_vote.get("name", "No opinion")
	})

	# Determine available paths (any with at least 1 supporter)
	var available: Array = []
	for path_id in ["independence", "ascension", "loyalty", "isolation"]:
		if votes.get(path_id, 0) > 0:
			available.append(path_id)

	return {
		"votes": votes,
		"available_paths": available,
		"individual_votes": individual_votes
	}


## ============================================================================
## COLONY SECURITY
## ============================================================================

func check_colony_security(campaign: Resource, path_id: String) -> bool:
	## Check if colony security requirement is met for the chosen path.
	var req: Dictionary = _security_requirements.get(path_id, {})
	var strongpoints_needed: int = req.get("strongpoints_destroyed", 0)

	if strongpoints_needed <= 0:
		return true

	# Count destroyed strongpoints (defeated tactical enemies)
	var destroyed: int = 0
	if campaign and "defeated_enemies" in campaign:
		destroyed = campaign.defeated_enemies.size()

	return destroyed >= strongpoints_needed


func get_security_requirement(path_id: String) -> int:
	var req: Dictionary = _security_requirements.get(path_id, {})
	return req.get("strongpoints_destroyed", 0)


## ============================================================================
## FINAL MILESTONE
## ============================================================================

func get_final_milestone_cost(path_id: String) -> Dictionary:
	## Returns {bp: int, rp: int} for the chosen path.
	var path_data: Dictionary = _final_milestones.get(path_id, {})
	return {
		"bp": path_data.get("cost_bp", 0),
		"rp": path_data.get("cost_rp", 0)
	}


func get_final_milestone_cost_with_reductions(path_id: String,
		final_breakthrough_id: String) -> Dictionary:
	## Apply any cost reductions from the Final Breakthrough.
	var base: Dictionary = get_final_milestone_cost(path_id)

	# Loyalty has specific cost reductions
	if path_id == "loyalty":
		var path_data: Dictionary = _final_milestones.get("loyalty", {})
		var reductions: Dictionary = path_data.get("cost_reductions", {})
		if reductions.has(final_breakthrough_id):
			var red: Dictionary = reductions[final_breakthrough_id]
			if red.has("bp"):
				base["bp"] = red["bp"]
			if red.has("rp"):
				base["rp"] = red["rp"]

	return base


func can_afford_final_milestone(campaign: Resource, path_id: String,
		final_breakthrough_id: String) -> bool:
	## Check if campaign has enough BP and RP to construct final milestone.
	var cost: Dictionary = get_final_milestone_cost_with_reductions(
		path_id, final_breakthrough_id)
	if not campaign:
		return false

	var current_bp: int = 0
	var current_rp: int = 0
	if "buildings_data" in campaign:
		current_bp = campaign.buildings_data.get("current_bp", 0)
	if "research_data" in campaign:
		current_rp = campaign.research_data.get("current_rp", 0)

	return current_bp >= cost.get("bp", 0) and current_rp >= cost.get("rp", 0)


## ============================================================================
## PATH RESOLUTION
## ============================================================================

func get_path_data(path_id: String) -> Dictionary:
	## Returns the full final milestone data for a path.
	return _final_milestones.get(path_id, {}).duplicate(true)


func resolve_path(campaign: Resource, path_id: String,
		rolls: Dictionary) -> Dictionary:
	## Process final path resolution. Returns outcome summary.
	## rolls: Dictionary of pre-rolled dice values for deterministic resolution.
	var path_data: Dictionary = _final_milestones.get(path_id, {})
	if path_data.is_empty():
		return {"error": "Unknown path: %s" % path_id}

	var resolution: Dictionary = path_data.get("resolution", {})
	var result: Dictionary = {
		"path": path_id,
		"path_name": path_data.get("name", ""),
		"outcome": ""
	}

	match path_id:
		"independence":
			var unity_roll: int = rolls.get("unity_response", 0)
			if unity_roll <= 0:
				unity_roll = randi_range(1, 6) + randi_range(1, 6)
			result["unity_response_roll"] = unity_roll
			result["outcome"] = _resolve_independence(unity_roll, resolution)

		"ascension":
			result["character_results"] = _resolve_ascension(campaign, rolls, resolution)

		"loyalty":
			var colony_roll: int = rolls.get("colony_future", 0)
			if colony_roll <= 0:
				colony_roll = randi_range(1, 6) + randi_range(1, 6)
			result["colony_future_roll"] = colony_roll
			result["outcome"] = _resolve_loyalty(colony_roll, resolution)

		"isolation":
			result["nomad_results"] = _resolve_isolation(campaign, rolls, resolution)

	# Mark campaign as completed
	if campaign and "game_phase" in campaign:
		campaign.game_phase = "completed"
	if campaign and "endgame_path" in campaign:
		campaign.endgame_path = path_id

	return result


## ============================================================================
## PRIVATE — RESOLUTION HELPERS
## ============================================================================

func _resolve_independence(roll: int, resolution: Dictionary) -> String:
	var entries: Array = resolution.get("entries", [])
	for entry in entries:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return "%s: %s" % [entry.get("name", ""), entry.get("description", "")]
	return "Unknown outcome (roll: %d)" % roll


func _resolve_ascension(campaign: Resource, rolls: Dictionary,
		resolution: Dictionary) -> Array:
	var results: Array = []
	var per_char: Array = resolution.get("per_character", [])

	if campaign and "roster" in campaign:
		for i in range(campaign.roster.size()):
			var char_dict: Variant = campaign.roster[i]
			if char_dict is not Dictionary:
				continue
			if char_dict.get("class", "") == "bot":
				continue

			var roll: int = rolls.get("char_%d" % i, randi_range(1, 6))
			var outcome: String = "unknown"
			for entry in per_char:
				if entry is Dictionary:
					if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
						outcome = entry.get("result", "unknown")
						break

			results.append({
				"character": char_dict.get("name", "Unknown"),
				"roll": roll,
				"outcome": outcome
			})

	return results


func _resolve_loyalty(roll: int, resolution: Dictionary) -> String:
	var entries: Array = resolution.get("colony_future_entries", [])
	# Pick either die from 2D6
	var pick: int = randi_range(1, 6) if roll == 0 else roll
	for entry in entries:
		if entry is Dictionary and entry.get("value", 0) == pick:
			return entry.get("name", "Unknown future")
	return "Unknown colony future"


func _resolve_isolation(campaign: Resource, rolls: Dictionary,
		resolution: Dictionary) -> Array:
	var results: Array = []
	var entries: Array = resolution.get("entries", [])
	var wisdom: int = 0
	var round_num: int = 0

	# Simulate nomad march rounds
	while wisdom < 3 and round_num < 20:
		round_num += 1
		var roll: int = rolls.get("round_%d" % round_num,
			randi_range(1, 6) + randi_range(1, 6))

		var outcome: String = ""
		for entry in entries:
			if entry is Dictionary:
				if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
					outcome = entry.get("id", "")
					break

		match outcome:
			"death":
				results.append({"round": round_num, "roll": roll, "outcome": "death"})
			"hardship":
				results.append({"round": round_num, "roll": roll, "outcome": "hardship"})
			"wisdom":
				wisdom += 1
				results.append({"round": round_num, "roll": roll, "outcome": "wisdom", "total_wisdom": wisdom})

		if wisdom >= 3:
			break

	return results


func _resolve_summit_vote(roll: int) -> Dictionary:
	for entry in _summit_entries:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {"id": "no_opinion", "name": "No opinion"}


func is_loaded() -> bool:
	return _loaded
