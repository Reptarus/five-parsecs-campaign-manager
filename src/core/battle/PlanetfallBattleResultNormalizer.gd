extends RefCounted

## Planetfall battle-result normalizer -- the ONE chokepoint every Planetfall
## post-battle step reads through. A sibling of BugHuntBattleResultNormalizer, and
## for the same reason: the post-battle rules are the mode's own (Planetfall
## pp.66-68, 134), and the 5PFH normalizer is what the Alpha-1 build ships.
##
## No class_name on purpose -- the global class cache is stale until the editor is
## reopened, so consumers preload this by path.
##
## WHY IT EXISTS. Before 2026-10-27 the post-battle panel read twelve keys and the
## battle screen produced one of them (`won`). It read `casualties` as character ids
## while TacticalBattleUI writes the downed crew into `crew_injuries_data`, so no
## played battle ever rolled an Injury, and it read `mission_id` while the battle
## screen writes `mission_type`, so the p.68 Rescue exemption never applied.
##
## THE STAMP. The turn controller is rebuilt on the battle return, so what the
## mission was (its id, the opposition, which Tactical Enemy, how many grunts went
## in) is stamped onto the phase manager BEFORE the battle and persisted with the
## turn. This function is where the stamp and the battle's own facts meet.
##
## ADD-ONLY AND IDEMPOTENT for battle facts (Block A): written only when absent, so
## calling it twice changes nothing and an upstream producer always wins. The
## debrief (Block B) is the player's declaration of what only the table knows, so
## it overwrites -- but always intersected with what the battle recorded.

const _Shared = preload("res://src/core/battle/BattleResultNormalizer.gd")

## p.66: "Injury rolls are made for any scientist, scout, trooper, or crew".
## Civvies "do not roll on this table" and a bot is marked Broken instead.
const NO_INJURY_ROLL_CLASSES := ["civvy", "bot"]


static func normalize(
	results: Dictionary, stamp: Dictionary, roster: Array, debrief: Dictionary
) -> Dictionary:
	if results == null:
		results = {}
	if stamp == null:
		stamp = {}

	# --- Block A: what the stamp and the battle screen already know ----------
	var crew: Dictionary = _Shared.parse_crew_outcome(results)

	if not results.has("mission_id"):
		var stamped_id: String = str(stamp.get("id", ""))
		results["mission_id"] = stamped_id if stamped_id != "" \
			else str(results.get("mission_type", ""))
	for key in ["mission_name", "opposition_type", "enemy_type", "grunts_deployed", "sector"]:
		if not results.has(key) and stamp.has(key):
			results[key] = stamp[key]
	if not results.has("tactical_enemy_index"):
		results["tactical_enemy_index"] = int(stamp.get("tactical_enemy_index", -1))

	# p.67: "any character that was on the table for at least 1 round qualifies".
	# crew_participants is who the battle screen deployed; the stamp is the fallback
	# for a result that carries no figures at all.
	if not results.has("participants"):
		var ids: Array = _as_array(crew.get("participant_ids", [])).duplicate()
		if ids.is_empty():
			ids = _as_array(stamp.get("deployed_ids", [])).duplicate()
		results["participants"] = ids

	# p.66: the casualties are the figures removed from play. TacticalBattleUI
	# records every downed crew figure (Core p.122 routes them all to the injury
	# roll), and parse_crew_outcome reads both of its lists.
	if not results.has("casualties"):
		results["casualties"] = _as_array(crew.get("downed_ids", [])).duplicate()

	var participants: Array = _as_array(results["participants"])
	var casualties: Array = _as_array(results["casualties"])

	if not results.has("injury_roll_ids"):
		var roll_ids: Array = []
		var bot_ids: Array = []
		var civvy_ids: Array = []
		for cid in casualties:
			match class_of(roster, str(cid)):
				"bot":
					bot_ids.append(str(cid))
				"civvy":
					civvy_ids.append(str(cid))
				_:
					roll_ids.append(str(cid))
		results["injury_roll_ids"] = roll_ids
		results["broken_bot_ids"] = bot_ids
		results["civvy_casualty_ids"] = civvy_ids

	# p.134: a Find bonus "requires at least one [scientist or scout] must still be
	# on their feet at the end of the battle and not a casualty".
	var standing: Dictionary = {}
	for pid in participants:
		if str(pid) not in casualties:
			standing[class_of(roster, str(pid))] = true
	if not results.has("has_scientist_standing"):
		results["has_scientist_standing"] = standing.has("scientist")
	if not results.has("has_scout_standing"):
		results["has_scout_standing"] = standing.has("scout")

	results["planetfall_normalized"] = true

	# --- Block B: what only the table can tell us -----------------------------
	if debrief != null and not debrief.is_empty():
		# p.66 Grunt Casualties: grunts are a count on the stamp, not battle-screen
		# figures, so the player declares how many went down. Never more than went in.
		if debrief.has("grunt_casualties"):
			var cap: int = int(results.get("grunts_deployed", debrief["grunt_casualties"]))
			results["grunt_casualties"] = clampi(int(debrief["grunt_casualties"]), 0, maxi(cap, 0))

		# p.68: on a Rescue Mission "you do NOT suffer Morale loss due to casualties,
		# except for the colonists in the mission".
		if debrief.has("colonists_lost"):
			results["colonists_lost"] = maxi(int(debrief["colonists_lost"]), 0)

		# p.67 Cowardice: moved off a battlefield edge in the first two rounds. A
		# casualty is "awarded as normal", so a coward is a participant who was NOT
		# a casualty.
		if debrief.has("coward_ids"):
			var cowards: Array = []
			for cid in _as_array(debrief["coward_ids"]):
				var s: String = str(cid)
				if s in participants and s not in casualties and s not in cowards:
					cowards.append(s)
			results["coward_ids"] = cowards

		# p.67: "Directly killed an enemy Boss or Leader ... once per battle". Each
		# killer counts once however many Leaders they shot.
		if debrief.has("boss_killers"):
			var killers: Array = []
			for cid in _as_array(debrief["boss_killers"]):
				var s2: String = str(cid)
				if s2 in participants and s2 not in killers:
					killers.append(s2)
			results["boss_killers"] = killers

		# p.134: Find rolls come "after winning an encounter", in the number "each
		# mission will detail".
		if debrief.has("find_rolls"):
			results["find_rolls"] = maxi(int(debrief["find_rolls"]), 0) \
				if bool(results.get("won", false)) else 0

		# p.68 Step 12: "If you obtained any Mission Data, note it on your roster."
		if debrief.has("mission_data_gained"):
			results["mission_data_gained"] = maxi(int(debrief["mission_data_gained"]), 0)

		results["debrief_recorded"] = true

	# p.68 Step 11: "drop an additional point for every battle casualty". A figure
	# removed from play is a battle casualty whatever its injury roll later says
	# (p.66: "knocked out ... wounded ... died"), so this is fixed at the battle,
	# never after the roll. Written last so a debriefed grunt count is included.
	results["battle_casualty_count"] = casualties.size() \
		+ int(results.get("grunt_casualties", 0))
	return results


## The roster class of a character id, or "" when it is not on the roster.
static func class_of(roster: Array, character_id: String) -> String:
	for entry in roster:
		if entry is Dictionary and str(entry.get("id", "")) == character_id:
			return str(entry.get("class", ""))
	return ""


static func _as_array(value: Variant) -> Array:
	return value if value is Array else []
