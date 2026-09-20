extends RefCounted

## Bug Hunt battle-result normalizer -- the ONE chokepoint every Bug Hunt
## post-battle consumer reads through, mirroring what BattleResultNormalizer does
## for 5PFH. It is a SIBLING rather than a branch inside that file: Bug Hunt's
## casualty, tally and objective rules are its own (Compendium pp.201-203), and
## the 5PFH path is what the Alpha-1 build ships.
##
## No class_name on purpose -- the global class cache is stale until the editor
## is reopened, so consumers preload this by path.
##
## WHAT IT IS FOR. The battle screen cannot report a Bug Hunt objective: the
## objectives are dice results on a physical table (p.187), not something the app
## tracks. So the scenario is STAMPED before the battle by
## BugHuntMissionPanel._launch_mission, the player DECLARES what happened at the
## debrief, and this function is where the two meet. Everything downstream --
## scoring, Court Martial, Reputation, XP -- reads only what comes out of here.
##
## ADD-ONLY AND IDEMPOTENT. Every battle fact is written only when absent, so
## calling it twice cannot change an answer, and an upstream producer always wins.
## The debrief block is skipped entirely when no debrief was collected, which is
## what lets the same call run on the battle RETURN (facts only, no debrief yet)
## and again on debrief SUBMIT (the player's declaration).

const _Shared = preload("res://src/core/battle/BattleResultNormalizer.gd")


static func normalize(
	results: Dictionary, stamped_mission: Dictionary, debrief: Dictionary
) -> Dictionary:
	if results == null:
		results = {}

	# --- Block A: what the battle and the stamp already know -----------------
	var crew: Dictionary = _Shared.parse_crew_outcome(results)

	# The scenario's own identity, carried forward from the stamp. `priority` in
	# particular is read by the p.204 XP step ("Mission Priority 4+: +1 XP"), and
	# before the stamp existed it defaulted to 1 on every played mission.
	for key in ["priority", "spawn_rating", "escalation_step", "signals_total"]:
		if not results.has(key) and stamped_mission.has(key):
			results[key] = stamped_mission[key]
	if not results.has("mission_objectives"):
		results["mission_objectives"] = _as_array(stamped_mission.get("objectives", []))

	# Who took the field (p.203). The stamp is authoritative because it was taken
	# at deployment, before the battle could change the roster; crew_participants
	# from the battle screen is the fallback.
	if not results.has("participant_ids"):
		var stamped_ids: Array = _as_array(stamped_mission.get("participant_ids", []))
		results["participant_ids"] = stamped_ids if not stamped_ids.is_empty() \
			else crew.get("participant_ids", [])

	# Who rolls on the p.202 Casualty table: "For each character who became a
	# casualty during this campaign turn, roll D100". That is exactly the crew who
	# went Out of Action, which the battle screen does record -- so it is derived,
	# never asked of the player and never invented.
	if not results.has("casualty_ids"):
		results["casualty_ids"] = crew.get("downed_ids", [])

	results["bug_hunt_normalized"] = true

	# --- Block B: what only the player can tell us ---------------------------
	if debrief == null or debrief.is_empty():
		return results

	var scoring: Dictionary = _as_dict(stamped_mission.get("scoring", {}))

	# p.202: "If a character exited the table via a battlefield edge, rather than
	# through Evac, use the Lost Marine column instead." Only a casualty can be a
	# Lost Marine, so the declaration is intersected with who actually went down.
	if debrief.has("lost_marine_ids"):
		var declared: Array = _as_array(debrief["lost_marine_ids"])
		var casualty_ids: Array = _as_array(results.get("casualty_ids", []))
		var lost: Array = []
		for cid in declared:
			if str(cid) in casualty_ids and str(cid) not in lost:
				lost.append(str(cid))
		results["lost_marine_ids"] = lost

	if debrief.has("signals_investigated"):
		results["signals_investigated"] = maxi(int(debrief["signals_investigated"]), 0)

	if debrief.has("mvp_id"):
		results["mvp_id"] = str(debrief["mvp_id"])

	if debrief.has("completed_objective_indices"):
		var objectives: Array = _as_array(results.get("mission_objectives", []))
		var indices: Array = _as_array(debrief["completed_objective_indices"])
		var weighted: int = 0
		var counted: int = 0
		for raw_idx in indices:
			var idx: int = int(raw_idx)
			if idx < 0 or idx >= objectives.size():
				continue
			var obj: Dictionary = _as_dict(objectives[idx])
			# Compendium pp.185, 201: a Vital Objective counts as 2 and a Critical
			# as 3. The weight travels ON the objective, stamped from cited data at
			# generation, so the number scored here is the number briefed.
			weighted += maxi(int(obj.get("weight", 1)), 0)
			counted += 1
		results["objectives_completed_count"] = counted

		# p.201: "if the mission had 4 or more signals initially, you must have
		# investigated at least 2 before Evac. Failure to do so means your
		# Objective total is reduced by 1."
		var req: Dictionary = _as_dict(scoring.get("signals_requirement", {}))
		var at_least: int = int(req.get("signals_at_least", 4))
		var must: int = int(req.get("must_investigate", 2))
		var penalty: int = int(req.get("objective_penalty", 1))
		var total_signals: int = int(results.get("signals_total", 0))
		var investigated: int = int(results.get("signals_investigated", 0))
		var penalised: bool = total_signals >= at_least and investigated < must
		if penalised:
			weighted = maxi(weighted - penalty, 0)
		results["objectives_penalty_applied"] = penalised
		results["objectives_completed"] = weighted

	# Derived verdicts, written last so they see the final total. Both are
	# add-only like everything else, so an upstream producer still wins.
	var total: int = int(results.get("objectives_completed", 0))
	if not results.has("mission_success"):
		# p.201: "Two or more is considered a success for the purposes of awarding
		# Experience Points after the battle."
		results["mission_success"] = total >= int(scoring.get("success_threshold", 2))
	if not results.has("court_martial_required"):
		# p.201: "If you failed to complete any Objectives at all, you may face a
		# court martial." ANY, so the test is on zero -- not on falling short of
		# the success threshold.
		results["court_martial_required"] = total <= 0
	results["debrief_recorded"] = true
	return results


static func _as_array(value: Variant) -> Array:
	return value if value is Array else []


static func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
