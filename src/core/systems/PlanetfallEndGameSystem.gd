class_name PlanetfallEndGameSystem
extends RefCounted

## Manages the End Game sequence: Summit, Colony Security check,
## Final Milestone construction, and path resolution.
## 4 paths: Independence, Ascension, Loyalty, Isolation.
## Source: Planetfall pp.160-164
##
## Every die goes through DiceManager (contexts "Planetfall Summit", "Planetfall Unity
## Response", "Planetfall War Colony" / "War Unity", "Planetfall Ascension", "Planetfall Fate of Ascension",
## "Planetfall Colony Future", "Planetfall Administrator Role", "Planetfall Nomad
## Struggles", "Planetfall End Game Character"), so QA can force an ending. They were raw
## randi_range() until 2026-10-27.
##
## resolve_path() mutates the campaign only through its owner's methods: a character the
## book kills leaves the roster (slay_character), and a colonist the War arrests is
## marked "arrested" so p.164's "characters that escaped captivity" is a real filter.

var _endgame_data: Dictionary = {}
var _summit_entries: Array = []
var _security_requirements: Dictionary = {}
var _final_milestones: Dictionary = {}
var _loaded: bool = false

## pp.161-162: the Unity Response rolls again on 8-10; a die loop that never settles is
## a defect, so the loops are bounded (no table here can repeat this often in practice).
const MAX_REROLLS := 50


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
	## p.160: "Roll a D6 on the table below for each character (not counting any bots or
	## grunts), plus an additional die to represent the general population."
	## Returns {votes, available_paths, individual_votes}.
	var votes: Dictionary = {
		"independence": 0, "ascension": 0,
		"loyalty": 0, "isolation": 0, "no_opinion": 0
	}
	var individual_votes: Array = []

	if not campaign or not "roster" in campaign:
		return {"votes": votes, "available_paths": [], "individual_votes": []}

	for char_dict in campaign.roster:
		if char_dict is not Dictionary:
			continue
		if str(char_dict.get("class", "")) == "bot":
			continue
		var roll: int = _d6("Planetfall Summit")
		var vote: Dictionary = _resolve_summit_vote(roll)
		var vote_id: String = vote.get("id", "no_opinion")
		votes[vote_id] = votes.get(vote_id, 0) + 1
		individual_votes.append({
			"character": char_dict.get("name", "Unknown"),
			"roll": roll,
			"vote": vote_id,
			"vote_name": vote.get("name", "No opinion")
		})

	var pop_roll: int = _d6("Planetfall Summit")
	var pop_vote: Dictionary = _resolve_summit_vote(pop_roll)
	var pop_id: String = pop_vote.get("id", "no_opinion")
	votes[pop_id] = votes.get(pop_id, 0) + 1
	individual_votes.append({
		"character": "General Population",
		"roll": pop_roll,
		"vote": pop_id,
		"vote_name": pop_vote.get("name", "No opinion")
	})

	# "Any opinion that does not have support from any character or the general
	# population cannot be selected." No opinion (5-6) supports nothing.
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
	## pp.160-161: Strongpoints destroyed. "If you have previously achieved this, you
	## already meet the requirement", so every defeat in the campaign counts.
	var needed: int = get_security_requirement(path_id)
	if needed <= 0:
		return true
	return get_strongpoints_destroyed(campaign) >= needed


func get_security_requirement(path_id: String) -> int:
	var req: Dictionary = _security_requirements.get(path_id, {})
	return int(req.get("strongpoints_destroyed", 0))


func get_strongpoints_destroyed(campaign: Resource) -> int:
	if campaign and "defeated_enemies" in campaign:
		return campaign.defeated_enemies.size()
	return 0


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
	## p.162 Loyalty: Ancient Factory → 5 BP; Terraforming → 0 RP; Ancient Colony →
	## 6 BP and 2 RP.
	var base: Dictionary = get_final_milestone_cost(path_id)

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


## The cost this campaign pays: the one place the Breakthrough is read, so the price
## shown, the price checked and the price charged cannot disagree.
func final_cost_for(campaign: Resource, path_id: String) -> Dictionary:
	return get_final_milestone_cost_with_reductions(path_id, _final_breakthrough(campaign))


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


## Pay the final milestone, or refuse. Returns false (and charges nothing) when the
## colony cannot afford it.
func pay_final_milestone(campaign: Resource, path_id: String) -> bool:
	var bt: String = _final_breakthrough(campaign)
	if not can_afford_final_milestone(campaign, path_id, bt):
		return false
	var cost: Dictionary = get_final_milestone_cost_with_reductions(path_id, bt)
	campaign.buildings_data["current_bp"] = int(campaign.buildings_data.get("current_bp", 0)) \
			- int(cost.get("bp", 0))
	campaign.research_data["current_rp"] = int(campaign.research_data.get("current_rp", 0)) \
			- int(cost.get("rp", 0))
	return true


## ============================================================================
## PATH RESOLUTION
## ============================================================================

func get_path_data(path_id: String) -> Dictionary:
	## Returns the full final milestone data for a path.
	return _final_milestones.get(path_id, {}).duplicate(true)


## True when the book lets this path end as a narrated victory without dice
## (p.161 Independence, p.162 Ascension: "You may end the campaign as a victory here").
func can_narrate_victory(path_id: String) -> bool:
	return path_id == "independence" or path_id == "ascension"


## p.162 Loyalty: "Roll 2D6 and pick either result". The two dice are rolled once and
## the player picks; resolve_path() takes the picked value as choices.loyalty_future.
func roll_colony_future_dice() -> Array:
	return [_d6("Planetfall Colony Future"), _d6("Planetfall Colony Future")]


func resolve_path(campaign: Resource, path_id: String,
		choices: Dictionary = {}) -> Dictionary:
	## Resolve the chosen path and complete the campaign. Returns
	## {path, path_name, outcome, ending_id, lines: Array[String], ...per path}.
	## choices: {narrated: bool, loyalty_future: int (1-6),
	##           moved_in_time_character: String (a roster id)}.
	var path_data: Dictionary = _final_milestones.get(path_id, {})
	if path_data.is_empty():
		return {"error": "Unknown path: %s" % path_id}

	var result: Dictionary = {
		"path": path_id,
		"path_name": path_data.get("name", ""),
		"outcome": "",
		"ending_id": path_id,
		"lines": []
	}

	if bool(choices.get("narrated", false)) and can_narrate_victory(path_id):
		result["outcome"] = "Victory. Narrate how it all ends and what it really meant."
		result["lines"].append(result["outcome"])
		if path_id == "independence":
			result["ending_id"] = "independence_won"
	else:
		match path_id:
			"independence":
				_resolve_independence(campaign, result)
			"ascension":
				_resolve_ascension(campaign, choices, result)
			"loyalty":
				_resolve_loyalty(campaign, choices, result)
			"isolation":
				_resolve_isolation(campaign, result)

	if campaign and "game_phase" in campaign:
		campaign.game_phase = "completed"
	if campaign and "endgame_path" in campaign:
		campaign.endgame_path = path_id
	# The campaign records its own ending: get_planetfall_ending() and the muster-out
	# read it, and a resolution must not depend on which screen called this.
	if campaign and "endgame_state" in campaign:
		campaign.endgame_state["result"] = result.duplicate(true)

	return result


## ============================================================================
## PRIVATE — RESOLUTION
## ============================================================================

## p.161 Independence: 2D6 Unity Response, +1 with Defense Network "unless the dice show
## a double"; 8-10 rolls again, where "any result of an 8 is counted as War while any
## roll of 10 is counted as Recognized status".
func _resolve_independence(campaign: Resource, result: Dictionary) -> void:
	var lines: Array = result["lines"]
	var bonus: bool = _has_breakthrough(campaign, "defense_network")
	var response: String = ""
	var negotiating: bool = false
	var rolls: Array = []
	for _i in range(MAX_REROLLS):
		var a: int = _d6("Planetfall Unity Response")
		var b: int = _d6("Planetfall Unity Response")
		var total: int = a + b + (1 if bonus and a != b else 0)
		rolls.append(total)
		lines.append("Unity Response: %d + %d%s = %d" % [a, b,
				" +1 (Defense Network)" if bonus and a != b else "", total])
		if negotiating and total == 8:
			response = "war"
		elif negotiating and total == 10:
			response = "recognized"
		elif total <= 2:
			response = "total_war"
		elif total <= 7:
			response = "war"
		elif total <= 10:
			negotiating = true
			lines.append("Negotiations drag on. Roll again.")
			continue
		else:
			response = "recognized"
		break
	result["unity_response_rolls"] = rolls

	if response == "total_war":
		if _has_breakthrough(campaign, "artificial_construction"):
			lines.append("Total war, but the Artificial Construction Breakthrough means "
					+ "the colony must go to War instead (p.161).")
			response = "war"
		else:
			result["outcome"] = "Total war. Unity makes an example of you: the colony is " \
					+ "obliterated."
			result["ending_id"] = "independence_lost"
			lines.append(result["outcome"])
			for c in _roster_ids(campaign):
				campaign.slay_character(c)
			return

	if response == "recognized":
		result["outcome"] = "Recognized status. Your colony will go on to become an " \
				+ "independent, Unity-Allied world."
		result["ending_id"] = "independence_won"
		lines.append(result["outcome"])
		return

	_resolve_war(campaign, result)


## p.161 War: each round 1D6 colony vs 1D6 Unity; the lower side takes 1 War Fatigue. A
## draw kills one random character and rolls again (Warzone: Unity also takes 1). Three
## Fatigue surrenders. A surrendering colony's characters each escape on 5+.
func _resolve_war(campaign: Resource, result: Dictionary) -> void:
	var lines: Array = result["lines"]
	lines.append("War. Unity responds with military force.")
	var warzone: bool = _has_breakthrough(campaign, "warzone")
	var colony_fatigue: int = 0
	var unity_fatigue: int = 0
	var rounds: Array = []
	for i in range(MAX_REROLLS * 4):
		if colony_fatigue >= 3 or unity_fatigue >= 3:
			break
		var c: int = _d6("Planetfall War Colony")
		var u: int = _d6("Planetfall War Unity")
		var note: String = ""
		if c < u:
			colony_fatigue += 1
			note = "the colony takes War Fatigue"
		elif u < c:
			unity_fatigue += 1
			note = "Unity takes War Fatigue"
		else:
			var killed: String = _kill_random(campaign)
			note = "a draw: %s is killed in the fighting" % (killed if killed != "" else "no one")
			if warzone:
				unity_fatigue += 1
				note += "; Unity takes War Fatigue (Warzone)"
		rounds.append({"round": i + 1, "colony": c, "unity": u})
		lines.append("Round %d: colony %d, Unity %d: %s (Fatigue %d / %d)." % [
				i + 1, c, u, note, colony_fatigue, unity_fatigue])
	result["war_rounds"] = rounds

	if unity_fatigue >= 3:
		result["outcome"] = "Unity surrenders. You are now independent!"
		result["ending_id"] = "independence_won"
		lines.append(result["outcome"])
		return

	result["outcome"] = "The colony surrenders and is incorporated into Unity forcefully."
	result["ending_id"] = "independence_lost"
	lines.append(result["outcome"])
	for cid in _roster_ids(campaign):
		var who: Variant = campaign.get_roster_character_by_id(cid)
		var roll: int = _d6("Planetfall End Game Character")
		var escaped: bool = roll >= 5
		if who is Dictionary:
			who["arrested"] = not escaped
		lines.append("  %s rolls %d: %s." % [_name_of(campaign, cid), roll,
				"escapes" if escaped else "is arrested"])


## p.162 Ascension: 1D6 per character (Moved in Time and Space: one chosen character
## counts as a 6). 1 perishes, 2-4 ascends, 5-6 earns 1 ascension energy. Then 1D6
## against the energy (+2 with Signs of Genetic Modification): above it (or no energy)
## the colonists become a sub-species; otherwise the same die reads the Fate table.
func _resolve_ascension(campaign: Resource, choices: Dictionary, result: Dictionary) -> void:
	var lines: Array = result["lines"]
	var chosen: String = str(choices.get("moved_in_time_character", "")) \
			if _has_breakthrough(campaign, "moved_in_time_or_space") else ""
	var energy: int = 0
	var character_results: Array = []
	for cid in _roster_ids(campaign):
		var name: String = _name_of(campaign, cid)
		var roll: int = 6 if cid == chosen else _d6("Planetfall Ascension")
		var outcome: String = "ascend"
		if roll <= 1:
			outcome = "perish"
		elif roll >= 5:
			outcome = "energy"
			energy += 1
		character_results.append({"character": name, "roll": roll, "outcome": outcome})
		lines.append("  %s rolls %d%s: %s." % [name, roll,
				" (Moved in Time and Space)" if cid == chosen else "",
				{"perish": "perishes as body or mind rejects ascension",
				"ascend": "undergoes ascension and joins the new species",
				"energy": "ascends and earns 1 ascension energy"}[outcome]])
		if outcome == "perish":
			campaign.slay_character(cid)
	result["character_results"] = character_results

	if _has_breakthrough(campaign, "signs_of_genetic_modification"):
		energy += 2
		lines.append("Signs of Genetic Modification: +2 ascension energy.")
	var fate_roll: int = _d6("Planetfall Fate of Ascension")
	result["ascension_energy"] = energy
	result["fate_roll"] = fate_roll
	lines.append("Ascension energy %d; fate roll %d." % [energy, fate_roll])
	if energy <= 0 or fate_roll > energy:
		result["outcome"] = "Your surviving colonists are now a distinct sub-species of " \
				+ "Humanity, perfectly adapted to exist on this world."
	else:
		result["outcome"] = _ascension_fate(fate_roll)
	lines.append(result["outcome"])


func _ascension_fate(roll: int) -> String:
	var table: Array = _final_milestones.get("ascension", {}).get("resolution", {}) \
			.get("fate_table", [])
	for entry in table:
		if entry is Dictionary and int(entry.get("value", 0)) == roll:
			return str(entry.get("description", ""))
	return ""


## p.162 Loyalty: the player picks one of the two Colony Future dice, then 1D6 per
## character on the Administrator Role table ("if you like": always rolled here, it is
## read-only flavour). Nobody dies.
func _resolve_loyalty(campaign: Resource, choices: Dictionary, result: Dictionary) -> void:
	var lines: Array = result["lines"]
	var resolution: Dictionary = _final_milestones.get("loyalty", {}).get("resolution", {})
	var pick: int = clampi(int(choices.get("loyalty_future", 0)), 0, 6)
	if pick <= 0:
		pick = _d6("Planetfall Colony Future")
	result["colony_future_roll"] = pick
	result["outcome"] = "The colony becomes: %s." % _value_name(
			resolution.get("colony_future_entries", []), pick)
	lines.append(result["outcome"])
	var futures: Array = []
	for cid in _roster_ids(campaign):
		var roll: int = _d6("Planetfall Administrator Role")
		var role: String = _value_name(resolution.get("character_future_entries", []), roll)
		futures.append({"character": _name_of(campaign, cid), "roll": roll, "outcome": role})
		lines.append("  %s rolls %d: %s." % [_name_of(campaign, cid), roll, role])
	result["character_results"] = futures


## pp.163 Isolation: 2D6 until 3 Wisdom or every character has died. 2 kills a random
## character (Psionic Manipulation: the first time also gives 1 Wisdom); 3-7 is a
## hardship, and a second hardship kills (Semi-Living Organism: ignore the first two);
## 8-12 is 1 Wisdom.
func _resolve_isolation(campaign: Resource, result: Dictionary) -> void:
	var lines: Array = result["lines"]
	var psionic: bool = _has_breakthrough(campaign, "psionic_manipulation")
	var semi_living: bool = _has_breakthrough(campaign, "semi_living_organism")
	var wisdom: int = 0
	var hardship: Dictionary = {}
	var ignored: int = 0
	var rounds: Array = []
	for i in range(MAX_REROLLS * 4):
		if wisdom >= 3 or _roster_ids(campaign).is_empty():
			break
		var total: int = _d6("Planetfall Nomad Struggles") + _d6("Planetfall Nomad Struggles")
		var note: String = ""
		if total <= 2:
			note = "%s falls, never to stand again" % _kill_random(campaign)
			if psionic:
				psionic = false
				wisdom += 1
				note += "; Psionic Manipulation: 1 Wisdom"
		elif total <= 7:
			if semi_living and ignored < 2:
				ignored += 1
				note = "a hardship, ignored (Semi-Living Organism)"
			else:
				var ids: Array = _roster_ids(campaign)
				var cid: String = ids[_pick(ids.size(), "Planetfall End Game Character")]
				if hardship.has(cid):
					note = "%s suffers a second hardship and dies" % _name_of(campaign, cid)
					campaign.slay_character(cid)
				else:
					hardship[cid] = true
					note = "%s suffers a hardship" % _name_of(campaign, cid)
		else:
			wisdom += 1
			note = "a vision: 1 Wisdom"
		rounds.append({"round": i + 1, "roll": total})
		lines.append("Roll %d: %d, %s (Wisdom %d)." % [i + 1, total, note, wisdom])
	result["nomad_results"] = rounds
	if wisdom >= 3:
		result["outcome"] = "Your colonists have founded a new tribe successfully."
	else:
		result["outcome"] = "Every character has perished on the march."
	lines.append(result["outcome"])


func _resolve_summit_vote(roll: int) -> Dictionary:
	for entry in _summit_entries:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {"id": "no_opinion", "name": "No opinion"}


## ============================================================================
## PRIVATE — HELPERS
## ============================================================================

func _final_breakthrough(campaign: Resource) -> String:
	return str(campaign.final_breakthrough) \
			if campaign and "final_breakthrough" in campaign else ""


func _has_breakthrough(campaign: Resource, id: String) -> bool:
	return _final_breakthrough(campaign) == id


func _roster_ids(campaign: Resource) -> Array:
	var ids: Array = []
	if campaign and "roster" in campaign:
		for c in campaign.roster:
			if c is Dictionary and str(c.get("id", "")) != "":
				ids.append(str(c.get("id", "")))
	return ids


func _name_of(campaign: Resource, cid: String) -> String:
	var who: Variant = campaign.get_roster_character_by_id(cid) \
			if campaign and campaign.has_method("get_roster_character_by_id") else null
	return str(who.get("name", cid)) if who is Dictionary else cid


## Kill one random roster character; returns their name, or "" when none are left.
func _kill_random(campaign: Resource) -> String:
	var ids: Array = _roster_ids(campaign)
	if ids.is_empty():
		return ""
	var cid: String = ids[_pick(ids.size(), "Planetfall End Game Character")]
	var name: String = _name_of(campaign, cid)
	campaign.slay_character(cid)
	return name


func _value_name(entries: Array, value: int) -> String:
	for entry in entries:
		if entry is Dictionary and int(entry.get("value", 0)) == value:
			return str(entry.get("name", ""))
	return ""


static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


func _d6(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d6(context)) if dm else randi_range(1, 6)


## A random index in [0, count); 0 when there is nothing to choose between. NOT forceable:
## DiceManager.roll_custom() ignores the QA queue, so a test that needs a known victim
## gives the roster one character.
func _pick(count: int, context: String) -> int:
	if count <= 1:
		return 0
	var dm := _dice()
	var roll: int = int(dm.roll_custom(1, count, 0, context)) if dm else randi_range(1, count)
	return clampi(roll - 1, 0, count - 1)


func is_loaded() -> bool:
	return _loaded
