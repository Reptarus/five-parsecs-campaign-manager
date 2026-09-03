class_name LingeringInjuryCheck
extends RefCounted
## Lingering Injury — Compendium p.102, roll 31-40 on the Detailed Injury table.
##
## The book, verbatim:
##   "Note down that the character has a Lingering Injury once they recover.
##    Before every mission, roll 1D6: On a 1, their old injury is acting up and
##    they cannot participate in the battle. On a 2-5, they are fine. On a 6,
##    they are finally over it and are fully recovered. A character could
##    potentially have multiple lingering injuries and would roll for each in
##    turn."
##
## WHAT WAS THERE BEFORE: nothing. `_process_detailed_injury` had no case for the
## row, so a Lingering Injury was a 1D6+1 Sick Bay stay and then — because both
## turn-rollover countdowns delete an injury entry the moment its recovery
## reaches 0 — the note itself was deleted. The condition the book says to write
## down was erased by the recovery tick a turn or two later.
##
## Three details the wording settles:
##   * "once they recover" — the roll starts AFTER Sick Bay, so an entry still
##     serving its recovery turns is skipped here.
##   * "roll for each in turn" — per ENTRY, not per character, and a 1 on any of
##     them benches the figure.
##   * "fully recovered" on a 6 removes THAT injury, not every lingering one.

const FLAG := "DETAILED_INJURIES"

## p.102: "On a 1, their old injury is acting up and they cannot participate."
const ACTING_UP := 1
## p.102: "On a 6, they are finally over it and are fully recovered."
const RECOVERED := 6


static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func is_enabled() -> bool:
	var dlc := _get_dlc_manager()
	if not dlc:
		return false
	var flag_value: int = dlc.ContentFlag.get(FLAG, -1)
	if flag_value < 0:
		return false
	return dlc.is_feature_enabled(flag_value)


## The lingering entries on this crew member that are past their Sick Bay time.
static func pending_for(member) -> Array:
	var out: Array = []
	var injuries: Variant = _injuries_of(member)
	if not (injuries is Array):
		return out
	for entry in injuries:
		if not (entry is Dictionary):
			continue
		if not bool(entry.get("lingering", false)):
			continue
		# "once they recover" — still in Sick Bay means no roll yet.
		if int(entry.get("recovery_turns", 0)) > 0:
			continue
		out.append(entry)
	return out


## Roll for every pending Lingering Injury on one crew member.
##
## Returns {rolled, benched, cleared, rolls} — `benched` is true when any die
## came up 1, `cleared` names the injuries a 6 removed. A benched character is
## given a one-battle `skip_next_battle` status effect, which
## `GameStateManager.filter_deployable()` already excludes from deployment, so
## no new gate is needed anywhere.
static func roll_for(member, roller: Callable = Callable()) -> Dictionary:
	var result: Dictionary = {
		"rolled": false, "benched": false, "cleared": [], "rolls": [],
	}
	if not is_enabled() or member == null:
		return result
	var pending: Array = pending_for(member)
	if pending.is_empty():
		return result

	var injuries: Array = _injuries_of(member)
	var recovered: Array = []
	for entry in pending:
		var roll: int = int(roller.call()) if roller.is_valid() else randi_range(1, 6)
		(result["rolls"] as Array).append(roll)
		result["rolled"] = true
		if roll <= ACTING_UP:
			result["benched"] = true
		elif roll >= RECOVERED:
			recovered.append(entry)
			(result["cleared"] as Array).append(
				str(entry.get("table_name", "Lingering Injury")))

	# Removed after the loop: mutating the array while iterating it would skip
	# the next entry, and "roll for each in turn" means every one gets its die.
	for entry in recovered:
		var idx: int = injuries.find(entry)
		if idx != -1:
			injuries.remove_at(idx)

	if bool(result["benched"]):
		_bench_for_one_battle(member)
	return result


## Roll for every crew member with a pending Lingering Injury. Returns one
## result dict per character that actually rolled, for the caller to journal.
static func roll_for_crew(crew: Array, roller: Callable = Callable()) -> Array:
	var out: Array = []
	if not is_enabled():
		return out
	for member in crew:
		var res: Dictionary = roll_for(member, roller)
		if bool(res.get("rolled", false)):
			res["character_name"] = _name_of(member)
			out.append(res)
	return out


static func _bench_for_one_battle(member) -> void:
	# `duration 1` so CampaignPhaseManager._process_character_event_effects
	# expires it at the next turn rollover — the book benches them for THIS
	# mission, not permanently.
	var effect: Dictionary = {
		"type": "skip_next_battle",
		"name": "Lingering Injury acting up",
		"description": ("An old injury is acting up: they cannot participate in"
			+ " this battle (Compendium p.102)."),
		"duration": 1,
		"source_event": "Lingering Injury (Compendium p.102)",
	}
	if member is Dictionary:
		if not member.has("status_effects") or not (member["status_effects"] is Array):
			member["status_effects"] = []
		member["status_effects"].append(effect)
		return
	if member is Object:
		if member.has_method("add_status_effect"):
			member.add_status_effect(effect)
		elif "status_effects" in member and member.status_effects is Array:
			member.status_effects.append(effect)


static func _injuries_of(member) -> Variant:
	if member is Dictionary:
		if not member.has("injuries") or not (member["injuries"] is Array):
			member["injuries"] = []
		return member["injuries"]
	if member is Object and "injuries" in member:
		return member.injuries
	return []


static func _name_of(member) -> String:
	if member is Dictionary:
		return str(member.get("character_name", member.get("name", "Crew")))
	if member is Object and "character_name" in member:
		return str(member.character_name)
	return "Crew"
