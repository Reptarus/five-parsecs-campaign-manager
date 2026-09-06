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


## The ENEMY TYPE this Rival fights as (p.92: "Once a Rival has been established,
## they will always be the same type"). `_append_rival` records it as `type`.
##
## Returns "" for a bare-String Rival, which predates the dict shape and carries
## no type. "" is the right answer, not a guess: the generator treats an empty
## preset as "roll normally", so a legacy Rival keeps today's behaviour instead of
## being pinned to an invented type.
static func rival_type_of(rival: Variant) -> String:
	if rival is Dictionary:
		var d: Dictionary = rival
		return str(d.get("type", d.get("enemy_type", "")))
	return ""


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
##
## `forced_rival_id` (T11-35, Core Rules p.128 "Got Noticed"): when the previous
## turn's Campaign Event fired on a Quest, "the next campaign turn is
## automatically a battle against the new Rival" - so that Rival is returned
## WITHOUT rolling. Suppression still wins over it: a Story Event that forbids
## Rival attacks this turn is an absolute, and the caller leaves the flag set so
## the forced battle lands on the next eligible turn instead of being lost.
static func check(
	rivals: Array, decoy_count: int = 0, rng: RandomNumberGenerator = null,
	suppressed_reason: String = "", forced_rival_id: String = ""
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
	# Several Story Events call the check off for their turn outright — Event 1
	# "Do not roll for existing Rivals interfering this campaign turn", Event 4
	# "You cannot be attacked by Rivals this campaign turn", Event 5 "you manage
	# to slip away without any Rivals having a chance to attack", Event 6 "you
	# will manage to dodge any Rivals coming after you". Passing the reason keeps
	# the suppression visible in battle_results instead of looking like an evade.
	if not suppressed_reason.is_empty():
		result["suppressed"] = true
		result["reason"] = suppressed_reason
		return result
	if rivals.is_empty():
		result["reason"] = "No Rivals to check (Core Rules p.85)."
		return result

	# T11-35: the p.128 forced battle. No D6 - the book says the turn IS a battle
	# against that Rival. Placed after the suppression and empty-list guards so a
	# Story Event's prohibition still wins and a deleted Rival cannot force a
	# battle against nobody.
	if not forced_rival_id.is_empty():
		for candidate: Variant in rivals:
			if rival_id_of(candidate) != forced_rival_id:
				continue
			result["has_encounter"] = true
			result["forced"] = true
			_stamp_rival(result, candidate)
			result["reason"] = ("%s forces a battle this turn (Core Rules p.128 - "
				% result["rival_name"]
				+ "Got Noticed while on a Quest).")
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
	_stamp_rival(result, picked)
	result["reason"] = "Rolled %d against %d Rival(s) — %s tracked you down (Core Rules p.85)." % [
		roll, rivals.size(), result["rival_name"]]
	return result


## Copy everything the battle needs to know about the chosen Rival onto `result`.
##
## Factored out so the p.85 rolled encounter and the p.128 FORCED encounter cannot
## drift: a forced battle that quietly dropped is_elite or the enemy-count bonus
## would be a different fight from the same Rival tracking you down normally.
static func _stamp_rival(result: Dictionary, picked: Variant) -> void:
	result["rival_id"] = rival_id_of(picked)
	result["rival_name"] = rival_name_of(picked)
	# p.92, verbatim: "Once a Rival has been established, they will always be the
	# same type." The type is recorded on the Rival at birth
	# (RivalPatronResolver._append_rival writes `type`), and without carrying it
	# here the battle re-rolled the encounter table — so the Unity troops you made
	# an enemy of last month could turn up as Roving Threats.
	result["rival_type"] = rival_type_of(picked)
	result["is_elite"] = picked is Dictionary and bool(
		(picked as Dictionary).get("is_elite", false))
	# Compendium p.21: "Note on your record sheet that these Rivals are Psi-hunters
	# in addition to their normal type." The tag rides with the Rival exactly like
	# is_elite, because the three adjustments it carries (Seize the Initiative -2,
	# +1 Specialist, +1 to attack a Psionic) are applied at BATTLE time, turns after
	# the Rival was created.
	result["is_psi_hunter"] = picked is Dictionary and bool(
		(picked as Dictionary).get("is_psi_hunter", false))
	# T11-25 / T11-35 — Core Rules p.126 Old Nemesis: the Rival will "receive +1
	# when rolling for the number of enemies in a battle"; p.128 Got Noticed adds
	# the same +1 while on a Quest. Carried the same way is_psi_hunter is, because
	# EnemyGenerator must apply it at battle time and has no other way to know which
	# Rival it is fighting.
	result["rival_enemy_count_bonus"] = int(
		(picked as Dictionary).get("enemy_count_bonus", 0)) \
		if picked is Dictionary else 0
