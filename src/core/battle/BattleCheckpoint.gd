class_name FPCM_BattleCheckpoint
extends RefCounted

## In-progress battle checkpoint — survives quit, crash and process death.
##
## ── WHY THIS EXISTS ─────────────────────────────────────────────────────────
## A Five Parsecs battle is thirty to sixty minutes at a physical table, and the
## app held every bit of it in RAM. Nothing about a fight in progress was written
## anywhere: not the round, not the phase, not which figures were down, Stunned or
## activated, not the Seize the Initiative outcome, not the objective's progress.
##
## The consequence was worse than losing the notes. On relaunch the campaign
## resumes at the World Phase checkpoint, and `CampaignTurnController
## ._initiate_battle_sequence()` runs again from the top with
## `seed_rng.randomize()` — generating DIFFERENT enemies, a DIFFERENT objective and
## a DIFFERENT battlefield. The player is sitting in front of a table they built
## from the old one. The terrain layout alone was persisted (`active_battlefield`),
## and nothing read it back on re-entry.
##
## ── SHAPE ───────────────────────────────────────────────────────────────────
## Stored at `campaign.progress_data["active_battle"]`, mirroring how
## `GameState.set_battlefield_data()` write-throughs `active_battlefield`. Keyed by
## the campaign turn so a checkpoint can never be applied to a later battle.
##
## Units are matched by a STABLE identity, never by array index: the crew list is
## rebuilt from the campaign on resume and its order is not guaranteed. Crew match
## on `character_id`; enemies have no persistent id of their own, so they match on
## their generated index, which IS stable because the enemy list is restored from
## the same persisted mission data rather than re-rolled.

const SCHEMA_VERSION: int = 1


## Build the checkpoint dictionary from live battle state.
##
## `units` entries are the caller's TacticalUnit objects; only the fields that a
## player would have to re-derive by hand are stored. Anything recomputable from
## the mission (stats, weapons, AI) is deliberately left out — it comes back from
## the persisted mission data, and duplicating it would create a second source of
## truth that could disagree.
static func build(turn: int, tier: int, round_number: int, phase: int,
		crew_units: Array, enemy_units: Array, extras: Dictionary = {}
	) -> Dictionary:
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"turn": turn,
		"tier": tier,
		"round": round_number,
		"phase": phase,
		"crew": [],
		"enemies": [],
	}
	for unit in crew_units:
		data["crew"].append(_unit_state(unit, _crew_key(unit)))
	for i in range(enemy_units.size()):
		data["enemies"].append(_unit_state(enemy_units[i], str(i)))
	for k in extras:
		data[k] = extras[k]
	return data


## Apply a checkpoint back onto freshly built units. Returns a receipt rather than
## a bool: a restore that silently matched half the figures is worse than none, so
## the caller can log exactly what came back and what did not.
static func apply(data: Dictionary, crew_units: Array,
		enemy_units: Array) -> Dictionary:
	var receipt: Dictionary = {
		"crew_restored": 0, "enemies_restored": 0, "unmatched": [],
	}
	if not is_valid(data):
		receipt["unmatched"].append("checkpoint invalid or wrong schema")
		return receipt

	var by_key: Dictionary = {}
	for entry in data.get("crew", []):
		if entry is Dictionary:
			by_key[str(entry.get("key", ""))] = entry
	for unit in crew_units:
		var key: String = _crew_key(unit)
		if by_key.has(key):
			_restore_unit(unit, by_key[key])
			receipt["crew_restored"] = int(receipt["crew_restored"]) + 1
		else:
			receipt["unmatched"].append("crew %s" % key)

	var enemies: Array = data.get("enemies", [])
	for i in range(enemy_units.size()):
		if i < enemies.size() and enemies[i] is Dictionary:
			_restore_unit(enemy_units[i], enemies[i])
			receipt["enemies_restored"] = int(receipt["enemies_restored"]) + 1
		else:
			receipt["unmatched"].append("enemy %d" % i)
	return receipt


## True when `data` is a checkpoint this build understands AND it belongs to
## `turn`. The turn gate is what stops a stale checkpoint being applied to the
## NEXT battle — the failure mode that would silently start a fresh fight with the
## previous one's casualties already marked down.
static func is_valid(data: Variant, turn: int = -1) -> bool:
	if not (data is Dictionary) or data.is_empty():
		return false
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	if turn >= 0 and int(data.get("turn", -1)) != turn:
		return false
	return true


## The crew identities stored in `data`, for callers that must rebuild the
## deployed roster before applying the checkpoint.
static func crew_keys(data: Dictionary) -> Array:
	var out: Array = []
	for entry in data.get("crew", []):
		if entry is Dictionary:
			out.append(str(entry.get("key", "")))
	return out


## Key for a raw campaign crew member (Dictionary or Character Resource), so a
## caller can filter a roster against crew_keys() using the SAME identity rule
## the checkpoint was written with. Two implementations of that rule would drift.
static func member_key(member) -> String:
	if member is Dictionary:
		var cid: Variant = member.get("character_id", member.get("id", ""))
		if str(cid) != "":
			return str(cid)
		return str(member.get("character_name", member.get("name", "")))
	if member:
		var cid2: Variant = member.get("character_id")
		if cid2 != null and str(cid2) != "":
			return str(cid2)
		var nm: Variant = member.get("character_name")
		if nm != null:
			return str(nm)
	return ""


static func _crew_key(unit) -> String:
	## Crew identity comes from the campaign character, not the display name:
	## two crew can share a name, and the roster order is not stable across a load.
	var oc = unit.original_character if "original_character" in unit else null
	if oc is Dictionary:
		var cid: Variant = oc.get("character_id", oc.get("id", ""))
		if str(cid) != "":
			return str(cid)
	elif oc:
		var cid2: Variant = oc.get("character_id")
		if cid2 != null and str(cid2) != "":
			return str(cid2)
	return str(unit.node_name) if "node_name" in unit else ""


static func _unit_state(unit, key: String) -> Dictionary:
	return {
		"key": key,
		"is_dead": bool(unit.is_dead),
		"is_knocked_out": bool(unit.is_knocked_out),
		"stun_markers": int(unit.stun_markers),
		"is_activated": bool(unit.is_activated),
		"react_slot": int(unit.react_slot),
		"initiative_roll": int(unit.initiative_roll),
		"luck_remaining": int(unit.luck_remaining),
		"killed_by": str(unit.killed_by),
		"health": int(unit.health),
	}


static func _restore_unit(unit, entry: Dictionary) -> void:
	unit.is_dead = bool(entry.get("is_dead", false))
	unit.is_knocked_out = bool(entry.get("is_knocked_out", false))
	unit.stun_markers = int(entry.get("stun_markers", 0))
	unit.is_activated = bool(entry.get("is_activated", false))
	unit.react_slot = int(entry.get("react_slot", 0))
	unit.initiative_roll = int(entry.get("initiative_roll", 0))
	unit.luck_remaining = int(entry.get("luck_remaining", unit.luck_remaining))
	unit.killed_by = str(entry.get("killed_by", ""))
	# health follows is_dead rather than being trusted from the file: it is an
	# internal liveness flag now (Core Rules p.46 has no hit points), and a stored
	# value that disagreed with is_dead would produce a figure that is neither.
	unit.health = 0 if unit.is_dead else maxi(int(entry.get("health", 1)), 1)
