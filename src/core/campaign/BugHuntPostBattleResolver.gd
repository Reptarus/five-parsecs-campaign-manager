extends RefCounted
## Bug Hunt post-battle sequence — Compendium pp.201-206.
##
## PURE. It takes a snapshot Dictionary and never touches the campaign core, so
## every rule below is testable without a save, a screen or a SceneTree. The ONE
## mutator is `BugHuntPhaseManager._apply_post_battle_results`, which applies the
## receipt this returns; the panel renders it and collects the choices.
##
## Mirrors the 5PFH post_battle/ subsystem contract: RefCounted, returns data,
## emits nothing, mutates nothing.
##
## ⚠ Rolls go through `roll_d6` / `roll_d100` / `roll_2d6` ONLY. Those four are
## the methods that consume `DiceManager.queue_forced_result` via `_take_forced`;
## `roll_custom` (DiceManager.gd:217) does NOT, so a roll made through it cannot
## be forced by QA. 1D3 is therefore `ceil(1D6 / 2)` — a uniform D3 that stays
## reachable through the D6 seam.

# ── Page cites, carried on every effect so a receipt line can show its source ──
const CITE_COURT_MARTIAL := "Compendium p.201"
const CITE_CASUALTIES := "Compendium p.202"
const CITE_TALLY := "Compendium p.203"
const CITE_MUSTER := "Compendium p.203"
const CITE_REPUTATION := "Compendium p.203"
const CITE_XP := "Compendium p.204"
const CITE_OP_PROGRESS := "Compendium p.205"
const CITE_MILITARY_LIFE := "Compendium p.206"
const CITE_RR := "Compendium p.206"

## The XP `condition` strings are DATA KEYS, not prose we author. They select
## which row of `experience.awards` supplies the value, so every XP number stays
## in the JSON and this file holds none of them.
const XP_COND_CASUALTY := "Became a casualty or lost marine"
const XP_COND_LOW_OBJECTIVES := "Not a casualty, 0-1 Objectives"
const XP_COND_HIGH_OBJECTIVES := "Not a casualty, 2+ Objectives"
const XP_COND_PRIORITY := "Mission Priority was 4+"
const XP_COND_MVP := "MVP"

## p.204 award row "Mission Priority was 4+" — the threshold is in the row's own
## name, so it is named here rather than invented.
const PRIORITY_XP_THRESHOLD := 4

const POST_BATTLE_PATH := "res://data/bug_hunt/bug_hunt_post_battle.json"
const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"

static var _cached_post_battle: Dictionary = {}
static var _cached_missions: Dictionary = {}

var _dice: Node = null
var _rolls: Array = []


func _init() -> void:
	# A RefCounted cannot use a bare get_node_or_null("/root/X") — that ERRORS
	# and aborts the enclosing function rather than returning null.
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root: Node = (loop as SceneTree).root
		if root != null:
			_dice = root.get_node_or_null("/root/DiceManager")


# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

## Resolve the whole p.201-206 sequence against `snapshot`.
##
## snapshot keys (all optional; every one has a safe empty shape):
##   characters                     Array[Dictionary] — main characters
##   reputation                     int
##   operational_progress_modifier  int
##   missions_in_current_operation  int
##   sick_bay                       Dictionary {character_id: turns_remaining}
##   battle_result                  Dictionary — BugHuntBattleResultNormalizer output
##   data                           Dictionary — {post_battle, missions} test override
##
## Returns {steps, effects, choices_needed, rolls}. `effects` is the flattened,
## ORDERED list the mutator applies; `steps` is the same content grouped for the
## receipt the panel renders.
func resolve(snapshot: Dictionary) -> Dictionary:
	_rolls = []
	var data: Dictionary = snapshot.get("data", {})
	var pb: Dictionary = data.get("post_battle", _load_post_battle())
	var missions: Dictionary = data.get("missions", _load_missions())

	var characters: Array = _as_array(snapshot.get("characters", []))
	var battle: Dictionary = snapshot.get("battle_result", {})
	var sick_bay: Dictionary = snapshot.get("sick_bay", {})

	var participants: Array = _as_string_array(battle.get("participant_ids", []))
	var casualties: Array = _as_string_array(battle.get("casualty_ids", []))
	var lost_marines: Array = _as_string_array(battle.get("lost_marine_ids", []))
	var objectives: int = int(battle.get("objectives_completed", 0))
	var priority: int = int(battle.get("priority", 0))

	var ctx := {
		"pb": pb,
		"missions": missions,
		"characters": characters,
		"by_id": _index_by_id(characters),
		"battle": battle,
		"sick_bay": sick_bay,
		"participants": participants,
		"casualties": casualties,
		"lost_marines": lost_marines,
		"objectives": objectives,
		"priority": priority,
		"reputation": int(snapshot.get("reputation", 0)),
		"op_modifier": int(snapshot.get("operational_progress_modifier", 0)),
		"missions_in_operation": int(snapshot.get("missions_in_current_operation", 0)),
		# Filled by step 1 and read by steps 2-5.
		# Step 6 can trigger R&R (p.205); step 8 is the ONE place that decides and
		# applies it, so a row that triggers it sets this flag instead of emitting a
		# second, differently-shaped R&R effect.
		"rr_triggered": false,
		"killed": [],
		"sick_bay_after": {},
		"tallied": {},
	}

	var steps: Array = []
	steps.append(_step_court_martial(ctx))
	steps.append(_step_casualties(ctx))
	steps.append(_step_tally(ctx))
	steps.append(_step_muster_out(ctx))
	steps.append(_step_reputation(ctx))
	steps.append(_step_experience(ctx))
	steps.append(_step_operational_progress(ctx))
	steps.append(_step_military_life(ctx))
	var rr := _step_rest_and_recuperation(ctx)
	# "Make an additional roll on the Military Life table" (p.206) — the extra
	# rolls owed by an earned R&R this turn, plus any banked by a paid early R&R
	# on a previous turn, are rolled here so they land in the same receipt.
	var banked: int = int(snapshot.get("pending_military_life_rolls", 0))
	var extra: int = banked + (1 if _step_earned_rr(rr) else 0)
	for i in range(extra):
		steps.append(_step_military_life(ctx, i + 1))
	# Clear only what was BANKED — the R&R-earned roll was never owed, so
	# clearing it too would drive the counter negative.
	if banked > 0:
		steps.append(_clear_owed_step(banked))
	steps.append(rr)

	var effects: Array = []
	var choices: Array = []
	var kept: Array = []
	for step in steps:
		if not (step is Dictionary):
			continue
		if step.get("skipped", false) and step.get("lines", []).is_empty():
			continue
		kept.append(step)
		for e in step.get("effects", []):
			effects.append(e)
		for c in step.get("choices", []):
			choices.append(c)

	return {
		"steps": kept,
		"effects": effects,
		"choices_needed": choices,
		"rolls": _rolls.duplicate(true),
	}


# ──────────────────────────────────────────────────────────────────────────────
# Step 0 — Court Martial (p.201)
# ──────────────────────────────────────────────────────────────────────────────

## p.201: "If you failed to complete any Objectives, select the mission leader
## and roll D6. On a 1, they are removed from campaign." Printed on p.201, i.e.
## before the p.202 sequence, so it is resolved first.
func _step_court_martial(ctx: Dictionary) -> Dictionary:
	var step := _new_step(0, "Court Martial", CITE_COURT_MARTIAL)
	var rules: Dictionary = ctx.missions.get("court_martial", {})
	if rules.is_empty():
		step.skipped = true
		return step
	if int(ctx.objectives) > 0:
		step.skipped = true
		step.lines.append("No Court Martial — the team completed %d Objective(s)." % ctx.objectives)
		return step

	var leader: Dictionary = _mission_leader(ctx)
	if leader.is_empty():
		step.skipped = true
		step.lines.append("No Court Martial — no mission leader took the field.")
		return step

	var leader_id: String = _char_id(leader)
	var roll: int = _roll_d6("Bug Hunt Court Martial: %s" % _char_name(leader))
	step.rolls.append({"die": "1D6", "value": roll, "subject": leader_id})
	var failure: int = int(rules.get("failure_value", 1))
	if roll > failure:
		step.lines.append("%s faced a Court Martial and was cleared (rolled %d)." % [_char_name(leader), roll])
		return step

	var cost: int = int(rules.get("avoid_reputation_cost", 0))
	step.lines.append("%s rolled %d and is removed from the campaign." % [_char_name(leader), roll])
	# Conditional: the buyout CANCELS this effect rather than adding another, so
	# the mutator never has to undo a removal it already applied.
	step.effects.append({
		"op": "remove_character", "target": leader_id, "cite": CITE_COURT_MARTIAL,
		"cancel_choice": "court_martial_buyout",
	})
	if cost > 0 and int(ctx.reputation) >= cost:
		step.choices.append({
			"id": "court_martial_buyout", "kind": "court_martial_buyout",
			"target": leader_id, "target_name": _char_name(leader),
			"cost": cost, "cite": CITE_COURT_MARTIAL,
			"prompt": "Pay %d Reputation to save %s from the Court Martial?" % [cost, _char_name(leader)],
		})
	return step


# ──────────────────────────────────────────────────────────────────────────────
# Step 1 — Casualties and Lost Marines (p.202)
# ──────────────────────────────────────────────────────────────────────────────

func _step_casualties(ctx: Dictionary) -> Dictionary:
	var step := _new_step(1, "Determine Casualties and Lost Marines", CITE_CASUALTIES)
	var table: Dictionary = ctx.pb.get("casualty_table", {})
	var entries: Array = _as_array(table.get("entries", []))
	if entries.is_empty():
		step.skipped = true
		return step
	if ctx.casualties.is_empty():
		step.skipped = true
		step.lines.append("No casualties — nobody was taken off the field.")
		return step

	for cid in ctx.casualties:
		var member: Dictionary = ctx.by_id.get(cid, {})
		if member.is_empty():
			continue
		var is_lost: bool = cid in ctx.lost_marines
		var range_key: String = "lost_marine_d100_range" if is_lost else "casualty_d100_range"
		var label: String = "Lost Marine" if is_lost else "Casualty"
		var roll: int = _roll_d100("Bug Hunt Casualty: %s" % _char_name(member))
		step.rolls.append({"die": "1D100", "value": roll, "subject": cid, "column": label})
		var row: Dictionary = _find_row(entries, range_key, roll)
		if row.is_empty():
			step.lines.append("%s (%s, rolled %d) — no table row matched." % [_char_name(member), label, roll])
			continue

		step.lines.append("%s (%s, rolled %d): %s — %s" % [
			_char_name(member), label, roll, row.get("name", ""), row.get("effect", "")])

		if bool(row.get("is_dead", false)):
			ctx.killed.append(cid)
			step.effects.append({"op": "kill", "target": cid, "cite": CITE_CASUALTIES,
				"reason": str(row.get("name", ""))})
			# p.203: "If a main character leaves for any reason, a new character
			# is rolled up as a replacement."
			step.effects.append({"op": "replace_character", "target": cid, "cite": CITE_MUSTER})
			continue

		var bonus_xp: int = int(row.get("bonus_xp", 0))
		if bonus_xp != 0:
			step.effects.append({"op": "add_xp", "target": cid, "amount": bonus_xp,
				"cite": CITE_CASUALTIES, "reason": str(row.get("name", ""))})

		var turns: int = _sick_bay_turns(row, _char_name(member))
		if turns > 0:
			ctx.sick_bay_after[cid] = turns
			step.effects.append({"op": "set_sick_bay", "target": cid, "amount": turns,
				"cite": CITE_CASUALTIES})
			# p.202: "Spend 1 Reputation to reduce Sick Bay time by 1 campaign
			# turn. Once per character per turn."
			if not str(table.get("advanced_care", "")).is_empty() and int(ctx.reputation) > 0:
				step.choices.append({
					"id": "advanced_care:%s" % cid, "kind": "advanced_care",
					"target": cid, "target_name": _char_name(member),
					"cost": 1, "max_reduction": 1, "sick_bay_turns": turns,
					"cite": CITE_CASUALTIES,
					"prompt": "Spend 1 Reputation to cut %s's Sick Bay time to %d turn(s)?" % [
						_char_name(member), maxi(turns - 1, 0)],
				})
	return step


## The Sick Bay column is `null` (dead), a String formula ("1D3", "1D3+1") or an
## int. Typing it as any one of those aborts the function on the other two.
func _sick_bay_turns(row: Dictionary, subject: String) -> int:
	var raw: Variant = row.get("sick_bay_turns", null)
	if raw == null:
		return 0
	if raw is String:
		return _roll_formula(raw, "Bug Hunt Recovery Time: %s" % subject)
	return int(raw)


# ──────────────────────────────────────────────────────────────────────────────
# Step 2 — Update Completed Missions (p.203)
# ──────────────────────────────────────────────────────────────────────────────

## p.203: "+1 for each character that took the field. Characters in Sick Bay do
## not update." A character who BECAME a casualty this mission did take the
## field, so they tally; a character who started the turn in Sick Bay did not.
func _step_tally(ctx: Dictionary) -> Dictionary:
	var step := _new_step(2, "Update Completed Missions", CITE_TALLY)
	if ctx.participants.is_empty():
		step.skipped = true
		step.lines.append("No tally — nobody took the field.")
		return step

	for cid in ctx.participants:
		var member: Dictionary = ctx.by_id.get(cid, {})
		if member.is_empty():
			continue
		if int(ctx.sick_bay.get(cid, 0)) > 0:
			step.lines.append("%s was in Sick Bay and does not update." % _char_name(member))
			continue
		var before: int = int(member.get("completed_missions_count", 0))
		ctx.tallied[cid] = before + 1
		step.effects.append({"op": "tally", "target": cid, "amount": 1, "cite": CITE_TALLY})
		step.lines.append("%s: %d → %d completed missions." % [_char_name(member), before, before + 1])

	# The turn's own mission count, which R&R (p.206) reads.
	step.effects.append({"op": "total_missions_played", "amount": 1, "cite": CITE_TALLY})
	return step


# ──────────────────────────────────────────────────────────────────────────────
# Step 3 — Check for Mustering Out (p.203)
# ──────────────────────────────────────────────────────────────────────────────

## p.203: only characters whose Completed Missions ROSE this mission check, and
## they check at their NEW count. Roll 2D6 >= the Muster number to leave.
func _step_muster_out(ctx: Dictionary) -> Dictionary:
	var step := _new_step(3, "Check for Mustering Out", CITE_MUSTER)
	var table: Array = _as_array(ctx.pb.get("mustering_out", {}).get("table", []))
	if table.is_empty() or ctx.tallied.is_empty():
		step.skipped = true
		return step

	for cid in ctx.tallied:
		if cid in ctx.killed:
			continue
		var member: Dictionary = ctx.by_id.get(cid, {})
		if member.is_empty():
			continue
		var count: int = int(ctx.tallied[cid])
		var row: Dictionary = _find_muster_row(table, count)
		if row.is_empty():
			continue

		if bool(row.get("automatic", false)):
			step.lines.append("%s has %d completed missions and leaves automatically." % [
				_char_name(member), count])
			step.effects.append({"op": "muster_out", "target": cid, "amount": count,
				"cite": CITE_MUSTER, "reason": "automatic"})
			step.effects.append({"op": "replace_character", "target": cid, "cite": CITE_MUSTER})
			continue

		var target: Variant = row.get("muster_target", null)
		if target == null:
			continue
		# The 5-7 row: "Only if the character was a casualty or lost marine."
		if bool(row.get("requires_casualty", false)) and not (cid in ctx.casualties):
			continue

		var roll: int = _roll_2d6("Bug Hunt Muster Out: %s" % _char_name(member))
		step.rolls.append({"die": "2D6", "value": roll, "subject": cid, "target": int(target)})
		if roll >= int(target):
			step.lines.append("%s rolled %d against %d at %d missions — they muster out." % [
				_char_name(member), roll, int(target), count])
			step.effects.append({"op": "muster_out", "target": cid, "amount": count,
				"cite": CITE_MUSTER, "reason": "rolled %d vs %d" % [roll, int(target)]})
			step.effects.append({"op": "replace_character", "target": cid, "cite": CITE_MUSTER})
		else:
			step.lines.append("%s rolled %d against %d at %d missions — they stay." % [
				_char_name(member), roll, int(target), count])
	return step


## Rows mix `completed_missions_range` (Array) with `completed_missions`
## (scalar). A count past the last declared bound falls to the final row, which
## p.203 marks automatic — without this, a career character falls through
## forever and can never leave.
func _find_muster_row(table: Array, count: int) -> Dictionary:
	var highest: int = 0
	var last: Dictionary = {}
	for entry in table:
		if not (entry is Dictionary):
			continue
		last = entry
		if entry.has("completed_missions_range"):
			var r: Variant = entry["completed_missions_range"]
			if r is Array and r.size() >= 2:
				highest = maxi(highest, int(r[1]))
				if count >= int(r[0]) and count <= int(r[1]):
					return entry
		elif entry.has("completed_missions"):
			var n: int = int(entry["completed_missions"])
			highest = maxi(highest, n)
			if count == n:
				return entry
	if count > highest and not last.is_empty():
		return last
	return {}


# ──────────────────────────────────────────────────────────────────────────────
# Step 4 — Determine Reputation (p.203)
# ──────────────────────────────────────────────────────────────────────────────

func _step_reputation(ctx: Dictionary) -> Dictionary:
	var step := _new_step(4, "Determine Reputation", CITE_REPUTATION)
	var rules: Dictionary = ctx.pb.get("reputation", {})
	if rules.is_empty():
		step.skipped = true
		return step

	var gained: int = 0
	var threshold: int = int(rules.get("auto_award_threshold", 2))
	if int(ctx.objectives) >= threshold:
		gained += int(rules.get("auto_award_amount", 1))
		step.lines.append("%d Objectives completed (%d+): +%d Reputation." % [
			ctx.objectives, threshold, int(rules.get("auto_award_amount", 1))])

	var per: Dictionary = rules.get("per_objective_roll", {})
	if not per.is_empty():
		var success: Array = _as_array(per.get("success_range", []))
		var low: int = int(success[0]) if success.size() >= 1 else 5
		var high: int = int(success[1]) if success.size() >= 2 else 6
		var award: int = int(per.get("award", 1))
		for i in range(int(ctx.objectives)):
			var roll: int = _roll_d6("Bug Hunt Reputation: objective %d" % (i + 1))
			step.rolls.append({"die": "1D6", "value": roll, "subject": "objective %d" % (i + 1)})
			if roll >= low and roll <= high:
				gained += award
				step.lines.append("Objective %d rolled %d: +%d Reputation." % [i + 1, roll, award])
			else:
				step.lines.append("Objective %d rolled %d: nothing." % [i + 1, roll])

	if gained != 0:
		step.effects.append({"op": "reputation", "amount": gained, "cite": CITE_REPUTATION})
	elif step.lines.is_empty():
		step.lines.append("No Reputation earned this mission.")
	return step


# ──────────────────────────────────────────────────────────────────────────────
# Step 5 — Experience and Leveling (p.204)
# ──────────────────────────────────────────────────────────────────────────────

func _step_experience(ctx: Dictionary) -> Dictionary:
	var step := _new_step(5, "Experience and Leveling", CITE_XP)
	var exp: Dictionary = ctx.pb.get("experience", {})
	var awards: Array = _as_array(exp.get("awards", []))
	if awards.is_empty() or ctx.participants.is_empty():
		step.skipped = true
		return step

	var xp_casualty: int = _award_value(awards, XP_COND_CASUALTY)
	var xp_low: int = _award_value(awards, XP_COND_LOW_OBJECTIVES)
	var xp_high: int = _award_value(awards, XP_COND_HIGH_OBJECTIVES)
	var xp_priority: int = _award_value(awards, XP_COND_PRIORITY)
	var xp_mvp: int = _award_value(awards, XP_COND_MVP)
	var high_threshold: int = int(ctx.pb.get("reputation", {}).get("auto_award_threshold", 2))

	var totals: Dictionary = {}
	for cid in ctx.participants:
		var member: Dictionary = ctx.by_id.get(cid, {})
		if member.is_empty() or cid in ctx.killed:
			continue
		var amount: int = 0
		if cid in ctx.casualties:
			amount += xp_casualty
		elif int(ctx.objectives) >= high_threshold:
			amount += xp_high
		else:
			amount += xp_low
		if int(ctx.priority) >= PRIORITY_XP_THRESHOLD:
			amount += xp_priority
		totals[cid] = amount

	# p.204 MVP: "Awarded to one character of choice." A stamped mvp_id is the
	# player's pick already made on the debrief card; otherwise it is a choice.
	var mvp: String = str(ctx.battle.get("mvp_id", ""))
	if xp_mvp != 0:
		if not mvp.is_empty() and totals.has(mvp):
			totals[mvp] = int(totals[mvp]) + xp_mvp
			step.lines.append("MVP %s: +%d XP." % [_char_name(ctx.by_id.get(mvp, {})), xp_mvp])
		elif not totals.is_empty():
			var options: Array = []
			for cid in totals:
				options.append({"id": cid, "name": _char_name(ctx.by_id.get(cid, {}))})
			step.choices.append({
				"id": "mvp", "kind": "mvp", "amount": xp_mvp, "options": options,
				"cite": CITE_XP, "prompt": "Award the MVP bonus (+%d XP) to one character." % xp_mvp,
			})

	for cid in totals:
		var amount: int = int(totals[cid])
		if amount == 0:
			continue
		step.effects.append({"op": "add_xp", "target": cid, "amount": amount, "cite": CITE_XP})
		step.lines.append("%s: +%d XP." % [_char_name(ctx.by_id.get(cid, {})), amount])

	# p.204 advancement. Affordability is offered per purchase and RE-CHECKED by
	# the consumer, because two purchases from one pool can each look affordable.
	var costs: Array = _as_array(exp.get("advancement_costs", []))
	if not costs.is_empty():
		for cid in totals:
			var member: Dictionary = ctx.by_id.get(cid, {})
			if member.is_empty():
				continue
			var pool: int = int(member.get("xp", 0)) + int(totals[cid])
			var options: Array = []
			for c in costs:
				if not (c is Dictionary):
					continue
				var stat: String = str(c.get("stat", ""))
				var cost: int = int(c.get("xp_cost", 0))
				var cap: int = int(c.get("max_value", 0))
				if stat.is_empty() or cost <= 0 or cost > pool:
					continue
				if int(member.get(stat, 0)) >= cap:
					continue
				options.append({"stat": stat, "xp_cost": cost, "max_value": cap})
			if options.is_empty():
				continue
			step.choices.append({
				"id": "advancement:%s" % cid, "kind": "advancement",
				"target": cid, "target_name": _char_name(member),
				"xp_available": pool, "options": options, "cite": CITE_XP,
				"prompt": "Spend %s's experience?" % _char_name(member),
			})
	return step


func _award_value(awards: Array, condition: String) -> int:
	for row in awards:
		if row is Dictionary and str(row.get("condition", "")) == condition:
			return int(row.get("xp", 0))
	return 0


# ──────────────────────────────────────────────────────────────────────────────
# Step 6 — Operational Progress (p.205)
# ──────────────────────────────────────────────────────────────────────────────

## The roll is D100 plus the cumulative modifier, and it is DELIBERATELY not
## clamped: `below_1` (Operation is a disaster) and `above_100` (Time to hold a
## parade — the campaign win) are real rows that only a modified roll can reach.
func _step_operational_progress(ctx: Dictionary) -> Dictionary:
	var step := _new_step(6, "Roll for Operational Progress", CITE_OP_PROGRESS)
	var entries: Array = _as_array(ctx.pb.get("operational_progress", {}).get("entries", []))
	if entries.is_empty():
		step.skipped = true
		return step

	var raw: int = _roll_d100("Bug Hunt Operational Progress")
	var modifier: int = int(ctx.op_modifier)
	var total: int = raw + modifier
	step.rolls.append({"die": "1D100", "value": raw, "modifier": modifier, "total": total})

	var row: Dictionary = _find_op_row(entries, total)
	if row.is_empty():
		step.lines.append("Rolled %d%s — no table row matched." % [raw, _signed(modifier)])
		return step
	step.lines.append("Rolled %d%s = %d: %s — %s" % [
		raw, _signed(modifier), total, row.get("name", ""), row.get("effect", "")])

	# The ±5 adjustments. Two rows are conditional on last mission's Objectives,
	# which is why `modifier_condition` exists rather than a flat number.
	if row.has("modifier"):
		var applies: bool = true
		var cond: String = str(row.get("modifier_condition", ""))
		if cond == "objectives_below_2":
			applies = int(ctx.objectives) < 2
		elif cond == "objectives_at_least_2":
			applies = int(ctx.objectives) >= 2
		var delta: int = int(row["modifier"])
		if applies and delta != 0:
			step.effects.append({"op": "op_modifier", "amount": delta, "cite": CITE_OP_PROGRESS})
			step.lines.append("Future rolls on this table: %s." % _signed(delta))
		elif not cond.is_empty() and not applies:
			step.lines.append("Condition not met — no adjustment.")

	if row.has("extra_contact_markers"):
		step.effects.append({"op": "extra_contact_markers", "amount": int(row["extra_contact_markers"]),
			"cite": CITE_OP_PROGRESS})
	if row.has("final_mission_extra_contact_markers"):
		step.effects.append({"op": "extra_contact_markers",
			"amount": int(row["final_mission_extra_contact_markers"]), "cite": CITE_OP_PROGRESS})
	if row.has("extra_support_rolls"):
		step.effects.append({"op": "extra_support_rolls", "amount": int(row["extra_support_rolls"]),
			"cite": CITE_OP_PROGRESS})
	if row.has("reputation"):
		step.effects.append({"op": "reputation", "amount": int(row["reputation"]),
			"cite": CITE_OP_PROGRESS})

	if row.has("xp_per_objective_random_participant") and int(ctx.objectives) > 0:
		var pick: Dictionary = _random_participant(ctx, "Bug Hunt Subject Pick: vital operation")
		if not pick.is_empty():
			var amount: int = int(row["xp_per_objective_random_participant"]) * int(ctx.objectives)
			step.effects.append({"op": "add_xp", "target": _char_id(pick), "amount": amount,
				"cite": CITE_OP_PROGRESS})
			step.lines.append("%s: +%d XP for the vital operation." % [_char_name(pick), amount])

	if bool(row.get("campaign_victory", false)):
		step.effects.append({"op": "campaign_victory", "cite": CITE_OP_PROGRESS})
	if bool(row.get("triggers_r_and_r", false)):
		ctx["rr_triggered"] = true
		step.lines.append("The operation grants R&R — resolved at step 8.")
	# Reset LAST, so a row that both awards and resets leaves the board clean.
	if bool(row.get("reset_progress", false)):
		step.effects.append({"op": "op_reset", "cite": CITE_OP_PROGRESS})
	return step


## Rows mix the String sentinels "below_1" / "above_100" with Array ranges.
func _find_op_row(entries: Array, total: int) -> Dictionary:
	var below: Dictionary = {}
	var above: Dictionary = {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var r: Variant = entry.get("d100_range", null)
		if r is String:
			if r == "below_1":
				below = entry
			elif r == "above_100":
				above = entry
			continue
		if r is Array and r.size() >= 2 and total >= int(r[0]) and total <= int(r[1]):
			return entry
	if total < 1:
		return below
	if total > 100:
		return above
	return {}


# ──────────────────────────────────────────────────────────────────────────────
# Step 7 — Military Life (p.206)
# ──────────────────────────────────────────────────────────────────────────────

## p.206: rolled once per campaign turn for a random main character.
func _step_military_life(ctx: Dictionary, index: int = 0) -> Dictionary:
	var step := _new_step(7, "Roll for Military Life", CITE_MILITARY_LIFE)
	var entries: Array = _as_array(ctx.pb.get("military_life", {}).get("entries", []))
	if entries.is_empty():
		step.skipped = true
		return step
	var member: Dictionary = _random_main_character(ctx, "Bug Hunt Subject Pick: Military Life")
	if member.is_empty():
		step.skipped = true
		step.lines.append("No main character available for Military Life.")
		return step

	var cid: String = _char_id(member)
	var suffix: String = "" if index == 0 else " (extra roll %d)" % index
	var roll: int = _roll_d100("Bug Hunt Military Life%s" % suffix)
	step.rolls.append({"die": "1D100", "value": roll, "subject": cid})
	var row: Dictionary = _find_row(entries, "d100_range", roll)
	if row.is_empty():
		step.lines.append("Rolled %d — no table row matched." % roll)
		return step

	step.lines.append("%s rolled %d: %s — %s" % [
		_char_name(member), roll, row.get("name", ""), row.get("effect", "")])
	_apply_military_life_row(ctx, step, member, row)
	return step


func _apply_military_life_row(ctx: Dictionary, step: Dictionary, member: Dictionary, row: Dictionary) -> void:
	var cid: String = _char_id(member)
	var name: String = _char_name(member)

	# 1-5 "Got in a fight": Roll 1D6+Combat Skill. Below 5, Sick Bay next turn.
	if row.has("failure_below"):
		var stat: String = str(row.get("roll_add_stat", ""))
		var bonus: int = int(member.get(stat, 0)) if not stat.is_empty() else 0
		var roll: int = _roll_d6("Bug Hunt Brawl: %s" % name)
		var total: int = roll + bonus
		step.rolls.append({"die": "1D6", "value": roll, "modifier": bonus, "total": total, "subject": cid})
		if total < int(row["failure_below"]):
			var turns: int = int(row.get("failure_sick_bay_turns", 1))
			step.effects.append({"op": "set_sick_bay", "target": cid, "amount": turns,
				"cite": CITE_MILITARY_LIFE})
			step.lines.append("%s rolled %d+%d = %d and spends %d turn(s) in Sick Bay." % [
				name, roll, bonus, total, turns])
		else:
			step.lines.append("%s rolled %d+%d = %d and walked away." % [name, roll, bonus, total])

	if row.has("reputation"):
		step.effects.append({"op": "reputation", "amount": int(row["reputation"]),
			"cite": CITE_MILITARY_LIFE})

	if row.has("xp"):
		step.effects.append({"op": "add_xp", "target": cid, "amount": int(row["xp"]),
			"cite": CITE_MILITARY_LIFE})

	# 46-50 "Feeling pretty fit": reduce Sick Bay by 1, or +1 XP if not in it.
	if row.has("sick_bay_reduction"):
		var current: int = int(ctx.sick_bay_after.get(cid, ctx.sick_bay.get(cid, 0)))
		if current > 0:
			var after: int = maxi(current - int(row["sick_bay_reduction"]), 0)
			step.effects.append({"op": "set_sick_bay", "target": cid, "amount": after,
				"cite": CITE_MILITARY_LIFE})
			step.lines.append("%s's Sick Bay time drops to %d turn(s)." % [name, after])
		elif row.has("xp_if_not_in_sick_bay"):
			step.effects.append({"op": "add_xp", "target": cid,
				"amount": int(row["xp_if_not_in_sick_bay"]), "cite": CITE_MILITARY_LIFE})

	if row.has("sick_bay_turns"):
		step.effects.append({"op": "set_sick_bay", "target": cid, "amount": int(row["sick_bay_turns"]),
			"cite": CITE_MILITARY_LIFE})

	for flag in ["miss_next_mission", "special_assignment_blocked"]:
		if bool(row.get(flag, false)):
			step.effects.append({"op": "military_life_flag", "target": cid, "flag": flag,
				"amount": 1, "cite": CITE_MILITARY_LIFE})
	for flag in ["special_assignment_bonus", "extra_special_assignment_rolls"]:
		if row.has(flag):
			step.effects.append({"op": "military_life_flag", "target": cid, "flag": flag,
				"amount": int(row[flag]), "cite": CITE_MILITARY_LIFE})

	# Choices: the book asks the player, so the resolver never picks.
	if row.has("priority_modifier_choice"):
		step.choices.append({
			"id": "military_life_priority:%s" % cid, "kind": "military_life_priority",
			"target": cid, "target_name": name,
			"options": _as_array(row["priority_modifier_choice"]), "cite": CITE_MILITARY_LIFE,
			"prompt": "Modify the Priority of the next mission.",
		})
	if row.has("weapon_range_bonus_inches"):
		step.choices.append({
			"id": "military_life_weapon:%s" % cid, "kind": "military_life_weapon",
			"target": cid, "target_name": name,
			"amount": int(row["weapon_range_bonus_inches"]), "cite": CITE_MILITARY_LIFE,
			"prompt": "Select one of %s's personal weapons to gain +%d\" range." % [
				name, int(row["weapon_range_bonus_inches"])],
		})
	if row.has("purchase"):
		var p: Dictionary = row["purchase"]
		step.choices.append({
			"id": "military_life_purchase:%s" % cid, "kind": "military_life_purchase",
			"target": cid, "target_name": name, "stat": str(p.get("stat", "")),
			"stat_amount": int(p.get("amount", 1)), "xp_cost": int(p.get("xp_cost", 0)),
			"xp_available": int(member.get("xp", 0)), "cite": CITE_MILITARY_LIFE,
			"prompt": "Raise %s's %s by +%d for %d XP?" % [
				name, str(p.get("stat", "")), int(p.get("amount", 1)), int(p.get("xp_cost", 0))],
		})
	if row.has("reputation_spend_max"):
		step.choices.append({
			"id": "military_life_favor:%s" % cid, "kind": "military_life_favor",
			"target": cid, "target_name": name,
			"max_spend": mini(int(row["reputation_spend_max"]), int(ctx.reputation)),
			"xp_per_reputation": int(row.get("xp_per_reputation", 0)),
			"bonus_per_reputation": int(row.get("special_assignment_bonus_per_reputation", 0)),
			"cite": CITE_MILITARY_LIFE,
			"prompt": "Cash in a favor: spend up to %d Reputation." % mini(
				int(row["reputation_spend_max"]), int(ctx.reputation)),
		})


# ──────────────────────────────────────────────────────────────────────────────
# Step 8 — R&R (p.206)
# ──────────────────────────────────────────────────────────────────────────────

func _step_rest_and_recuperation(ctx: Dictionary) -> Dictionary:
	var step := _new_step(8, "Check Entitlement to R&R", CITE_RR)
	var rules: Dictionary = ctx.pb.get("r_and_r", {})
	if rules.is_empty():
		step.skipped = true
		return step

	var required: int = int(rules.get("missions_required", 4))
	var after: int = int(ctx.missions_in_operation) + 1
	step.effects.append({"op": "missions_in_operation", "amount": 1, "cite": CITE_RR})
	step.lines.append("Missions in the current operation: %d of %d." % [after, required])

	# Either the fourth mission of the operation, or a p.205 Operational Progress
	# row that grants R&R outright. Both end in the same place, so they share one
	# effect rather than two shapes the mutator would have to keep in step.
	if after >= required or bool(ctx.get("rr_triggered", false)):
		step.lines.append("R&R earned: %s" % ", ".join(_as_string_array(rules.get("effects", []))))
		# ONE compound op. It crosses off an extra Sick Bay turn for everyone and
		# restarts the operation counter; the mutator owns both, so the two halves
		# cannot drift apart or be applied twice from two emission sites.
		step.effects.append({"op": "rest_and_recuperation", "cite": CITE_RR})
	else:
		var cost: int = int(rules.get("reputation_cost_for_early", 0))
		if cost > 0 and int(ctx.reputation) >= cost:
			step.choices.append({
				"id": "early_rr", "kind": "early_rr", "cost": cost, "cite": CITE_RR,
				"grants_military_life_roll": true,
				"prompt": "Pay %d Reputation to take R&R now?" % cost,
			})
	return step


func _step_earned_rr(step: Dictionary) -> bool:
	for e in step.get("effects", []):
		if e is Dictionary and str(e.get("op", "")) == "rest_and_recuperation":
			return true
	return false


## Banked rolls are cleared by the SAME receipt that spends them, so a crash
## between rolling and clearing cannot hand the player the roll twice.
func _clear_owed_step(count: int) -> Dictionary:
	var step := _new_step(7, "Extra Military Life rolls", CITE_RR)
	step.lines.append("%d extra Military Life roll(s) resolved." % count)
	step.effects.append({"op": "military_life_roll_owed", "amount": -count, "cite": CITE_RR})
	return step


# ──────────────────────────────────────────────────────────────────────────────
# Choice resolution — appended effects, applied by the SAME mutator
# ──────────────────────────────────────────────────────────────────────────────

## Turn the player's answers into effects. `answers` maps a choice id to the
## player's selection; a choice the player declined is simply absent.
##
## Returns {effects, cancelled}: `cancelled` holds the ids of choices whose
## presence CANCELS an already-emitted effect (the Court Martial buyout is the
## only one today), so the mutator skips any effect carrying that cancel_choice.
static func apply_choices(receipt: Dictionary, answers: Dictionary) -> Dictionary:
	var effects: Array = []
	var cancelled: Array = []
	var by_id: Dictionary = {}
	for c in receipt.get("choices_needed", []):
		if c is Dictionary:
			by_id[str(c.get("id", ""))] = c

	for cid in answers:
		var key: String = str(cid)
		var choice: Dictionary = by_id.get(key, {})
		if choice.is_empty():
			continue
		var answer: Variant = answers[key]
		var kind: String = str(choice.get("kind", ""))
		var target: String = str(choice.get("target", ""))
		var cite: String = str(choice.get("cite", ""))

		match kind:
			"court_martial_buyout":
				if bool(answer):
					cancelled.append(key)
					effects.append({"op": "reputation", "amount": -int(choice.get("cost", 0)),
						"cite": cite})
			"advanced_care":
				if bool(answer):
					var turns: int = maxi(int(choice.get("sick_bay_turns", 0))
						- int(choice.get("max_reduction", 1)), 0)
					effects.append({"op": "reputation", "amount": -int(choice.get("cost", 1)), "cite": cite})
					effects.append({"op": "set_sick_bay", "target": target, "amount": turns, "cite": cite})
			"mvp":
				var picked: String = str(answer)
				if not picked.is_empty():
					effects.append({"op": "add_xp", "target": picked,
						"amount": int(choice.get("amount", 0)), "cite": cite})
			"advancement":
				for stat in _answer_list(answer):
					for opt in choice.get("options", []):
						if opt is Dictionary and str(opt.get("stat", "")) == str(stat):
							effects.append({"op": "add_xp", "target": target,
								"amount": -int(opt.get("xp_cost", 0)), "cite": cite})
							effects.append({"op": "stat_increase", "target": target,
								"stat": str(stat), "amount": 1,
								"max_value": int(opt.get("max_value", 0)), "cite": cite})
							break
			"military_life_priority":
				effects.append({"op": "military_life_flag", "target": target,
					"flag": "priority_modifier", "amount": int(answer), "cite": cite})
			"military_life_weapon":
				effects.append({"op": "weapon_range_bonus", "target": target,
					"weapon": str(answer), "amount": int(choice.get("amount", 1)), "cite": cite})
			"military_life_purchase":
				if bool(answer):
					effects.append({"op": "add_xp", "target": target,
						"amount": -int(choice.get("xp_cost", 0)), "cite": cite})
					effects.append({"op": "stat_increase", "target": target,
						"stat": str(choice.get("stat", "")),
						"amount": int(choice.get("stat_amount", 1)), "cite": cite})
			"military_life_favor":
				var spend: int = clampi(int(answer), 0, int(choice.get("max_spend", 0)))
				if spend > 0:
					effects.append({"op": "reputation", "amount": -spend, "cite": cite})
					var per_xp: int = int(choice.get("xp_per_reputation", 0))
					if per_xp != 0:
						effects.append({"op": "add_xp", "target": target,
							"amount": spend * per_xp, "cite": cite})
					var per_bonus: int = int(choice.get("bonus_per_reputation", 0))
					if per_bonus != 0:
						effects.append({"op": "military_life_flag", "target": target,
							"flag": "special_assignment_bonus", "amount": spend * per_bonus,
							"cite": cite})
			"early_rr":
				if bool(answer):
					effects.append({"op": "reputation", "amount": -int(choice.get("cost", 1)), "cite": cite})
					effects.append({"op": "rest_and_recuperation", "cite": cite})
					if bool(choice.get("grants_military_life_roll", false)):
						# The extra Military Life roll cannot be rolled here — this is a
						# static function with no dice. It is BANKED, and step 7 of the
						# next resolve consumes it, which is what `pending_rolls` is for.
						effects.append({"op": "military_life_roll_owed", "amount": 1, "cite": cite})

	return {"effects": effects, "cancelled": cancelled}


static func _answer_list(answer: Variant) -> Array:
	if answer is Array:
		return answer
	if answer == null:
		return []
	return [answer]


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

func _new_step(index: int, title: String, cite: String) -> Dictionary:
	return {"step": index, "title": title, "cite": cite,
		"rolls": [], "lines": [], "effects": [], "choices": [], "skipped": false}


## Match `roll` against a row's range column. The column is `null` on six of the
## nine casualty rows (only Gruesome fate, Knocked out and School of hard knocks
## have a Lost Marine range), and `entry.has(key)` is TRUE for those — typing the
## value as Array is a class-(b) abort, not a miss.
func _find_row(entries: Array, range_key: String, roll: int) -> Dictionary:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var r: Variant = entry.get(range_key, null)
		if not (r is Array) or r.size() < 2:
			continue
		if roll >= int(r[0]) and roll <= int(r[1]):
			return entry
	return {}


func _mission_leader(ctx: Dictionary) -> Dictionary:
	var declared: String = str(ctx.battle.get("mission_leader_id", ""))
	if not declared.is_empty() and ctx.by_id.has(declared):
		return ctx.by_id[declared]
	# p.201 says "select the mission leader"; with none declared, the first
	# character who took the field stands in, and the receipt names them.
	for cid in ctx.participants:
		if ctx.by_id.has(cid):
			return ctx.by_id[cid]
	return {}


func _random_participant(ctx: Dictionary, context: String) -> Dictionary:
	var pool: Array = []
	for cid in ctx.participants:
		if ctx.by_id.has(cid) and not (cid in ctx.killed):
			pool.append(ctx.by_id[cid])
	return _pick(pool, context)


func _random_main_character(ctx: Dictionary, context: String) -> Dictionary:
	var pool: Array = []
	for member in ctx.characters:
		if member is Dictionary and not (_char_id(member) in ctx.killed):
			pool.append(member)
	return _pick(pool, context)


## Picked through the D100 seam rather than randi(), so QA can force WHICH
## character a per-character table lands on, not only the row.
func _pick(pool: Array, context: String) -> Dictionary:
	if pool.is_empty():
		return {}
	if pool.size() == 1:
		return pool[0]
	var roll: int = _roll_d100(context)
	return pool[(roll - 1) % pool.size()]


func _roll_d6(context: String) -> int:
	var value: int = _dice.roll_d6(context) if _dice != null and _dice.has_method("roll_d6") \
		else randi_range(1, 6)
	_rolls.append({"die": "1D6", "value": value, "context": context})
	return value


func _roll_2d6(context: String) -> int:
	var value: int = _dice.roll_2d6(context) if _dice != null and _dice.has_method("roll_2d6") \
		else randi_range(1, 6) + randi_range(1, 6)
	_rolls.append({"die": "2D6", "value": value, "context": context})
	return value


func _roll_d100(context: String) -> int:
	var value: int = _dice.roll_d100(context) if _dice != null and _dice.has_method("roll_d100") \
		else randi_range(1, 100)
	_rolls.append({"die": "1D100", "value": value, "context": context})
	return value


## "1D3", "1D3+1", "2D6", "3" — the Sick Bay column's whole vocabulary. A D3 is
## rolled as ceil(1D6 / 2) so it passes through the forceable D6 seam.
func _roll_formula(formula: String, context: String) -> int:
	var text: String = formula.strip_edges().to_upper()
	if text.is_valid_int():
		return int(text)
	var bonus: int = 0
	if text.contains("+"):
		var halves: PackedStringArray = text.split("+")
		text = halves[0]
		bonus = int(halves[1]) if halves.size() > 1 else 0
	var parts: PackedStringArray = text.split("D")
	if parts.size() != 2:
		return bonus
	var count: int = int(parts[0]) if not parts[0].is_empty() else 1
	var sides: int = int(parts[1])
	var total: int = bonus
	for i in range(count):
		if sides == 3:
			total += int(ceil(_roll_d6(context) / 2.0))
		elif sides == 6:
			total += _roll_d6(context)
		elif sides == 100:
			total += _roll_d100(context)
		else:
			total += randi_range(1, maxi(sides, 1))
	return total


func _index_by_id(characters: Array) -> Dictionary:
	var out: Dictionary = {}
	for member in characters:
		if member is Dictionary:
			var cid: String = _char_id(member)
			if not cid.is_empty():
				out[cid] = member
	return out


func _char_id(member: Dictionary) -> String:
	return str(member.get("id", member.get("character_id", "")))


func _char_name(member: Dictionary) -> String:
	if member.is_empty():
		return "Unknown"
	return str(member.get("name", member.get("character_name", "Unknown")))


func _signed(value: int) -> String:
	return "+%d" % value if value >= 0 else str(value)


static func _as_array(value: Variant) -> Array:
	return value if value is Array else []


static func _as_string_array(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for v in value:
			out.append(str(v))
	return out


static func _load_post_battle() -> Dictionary:
	if _cached_post_battle.is_empty():
		_cached_post_battle = _load_json(POST_BATTLE_PATH)
	return _cached_post_battle


static func _load_missions() -> Dictionary:
	if _cached_missions.is_empty():
		_cached_missions = _load_json(MISSIONS_PATH)
	return _cached_missions


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("BugHuntPostBattleResolver: missing data file %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
