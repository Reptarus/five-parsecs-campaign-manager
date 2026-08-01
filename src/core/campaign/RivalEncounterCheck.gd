extends RefCounted
## Core Rules p.85, World Step 6 "Check for Rivals" — the gate that decides
## whether a Rival forces the battle this campaign turn, and WHICH Rival it is.
##
## THE GAP THIS FILLS. The check was written but could never run:
##   - CampaignTurnController asked `rival_generator.has_method("check_rival_encounter")`
##     and RivalBattleGenerator defines no such method (zero definitions repo-wide),
##     so the guard was permanently false.
##   - The fallback read `progress_data["rival_count"]`, a key nothing writes, so it
##     was always 0 and returned before rolling.
## Rivals therefore never tracked the crew down, and the Decoy crew task's entire
## effect ("+1 to the roll when checking if Rivals track you down, per crew sent
## as Decoy", data/crew_tasks.json p.78) modified a roll that never happened.
##
## The book (p.85): "Tally up the number of Rivals you have, and roll a D6. If the
## roll is equal to or lower than the number of Rivals, one of them has tracked you
## down, and you will have to fight them. [...] Select the exact Rival at random
## from those on your list."
##
## That last sentence is why this returns an id and not just a bool: post-battle
## Step 1 (p.119) needs to know WHICH Rival was fought in order to remove them from
## the list on a 4+. Without it the removal roll can never fire and beating a Rival
## can only ever ADD Rivals, never shake one off.
##
## No `class_name` — same reason as BattleResultNormalizer: the global class cache
## is stale until the editor reopens. Preload by path.

## The canonical rival list (`FiveParsecsCampaignCore.rivals`) is a MIXED array of
## Strings and Dictionaries — CharacterGeneration appends names, CrewTaskComponent
## and CharacterTransferService append dicts. Both shapes must resolve to an id.
static func rival_id_of(rival: Variant) -> String:
	if rival is Dictionary:
		var d: Dictionary = rival
		return str(d.get("id", d.get("rival_id", d.get("name", ""))))
	return str(rival)


static func rival_name_of(rival: Variant) -> String:
	if rival is Dictionary:
		var d: Dictionary = rival
		return str(d.get("name", d.get("id", "Rival")))
	return str(rival)


## Count the crew sent as Decoy this campaign turn from the resolved crew-task
## results. data/crew_tasks.json "decoy": "+1 to the roll when checking if Rivals
## track you down, per crew sent as Decoy" (Core Rules p.78).
static func decoy_count_from_tasks(task_results: Array) -> int:
	var n: int = 0
	for entry in task_results:
		if entry is Dictionary and str((entry as Dictionary).get("task_id", "")) == "decoy":
			n += 1
	return n


## Rival ids successfully located by the Track crew task this turn.
## data/crew_tasks.json "track": "6+ locates a Rival of your choice" (p.78).
## Read post-battle as the p.119 "+1 if you Tracked them down" removal modifier.
static func tracked_rival_ids_from_tasks(task_results: Array) -> Array:
	var out: Array = []
	for entry in task_results:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		if str(d.get("task_id", "")) != "track":
			continue
		if not bool(d.get("success", false)):
			continue
		var rid: String = str(d.get("rival_id", ""))
		if rid != "" and rid not in out:
			out.append(rid)
	return out


## The p.85 check itself.
##
## `rng` may be null (a fresh randomized RandomNumberGenerator is used); pass one
## for deterministic tests. Returns a dict shaped for battle_results/mission_data:
##   has_encounter, rival_id, rival_name, roll, rival_count, decoy_bonus, reason
static func check(
	rivals: Array, decoy_count: int = 0, rng: RandomNumberGenerator = null
) -> Dictionary:
	var result: Dictionary = {
		"has_encounter": false,
		"rival_id": "",
		"rival_name": "",
		"roll": 0,
		"rival_count": rivals.size(),
		"decoy_bonus": maxi(0, decoy_count),
		"reason": "",
	}
	if rivals.is_empty():
		result["reason"] = "No Rivals to check (Core Rules p.85)."
		return result

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	# "roll a D6" — Decoys add to the roll, making it HARDER for the roll to land
	# at or below the Rival count. Matches MissionTableManager.check_rival_tracking.
	var roll: int = gen.randi_range(1, 6) + result["decoy_bonus"]
	result["roll"] = roll
	if roll > rivals.size():
		result["reason"] = "Rolled %d against %d Rival(s) — evaded (Core Rules p.85)." % [
			roll, rivals.size()]
		return result

	# "Select the exact Rival at random from those on your list."
	var picked: Variant = rivals[gen.randi_range(0, rivals.size() - 1)]
	result["has_encounter"] = true
	result["rival_id"] = rival_id_of(picked)
	result["rival_name"] = rival_name_of(picked)
	result["reason"] = "Rolled %d against %d Rival(s) — %s tracked you down (Core Rules p.85)." % [
		roll, rivals.size(), result["rival_name"]]
	return result
