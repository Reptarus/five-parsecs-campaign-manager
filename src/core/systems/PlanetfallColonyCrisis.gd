class_name PlanetfallColonyCrisis
extends RefCounted

## Planetfall Step 9 (Injuries, p.66), Step 11 (Colony Morale) and Step 16 (Colony
## Integrity): the Injury and grunt casualty rolls, the Morale Incident table, the
## Crisis check and Crisis Outcome table (pp.68, 89-90), and the Integrity Failure
## table with Emergency Repairs (pp.87-88).
##
## PURE: it reads a snapshot (`ctx`) and returns a receipt {lines, ops}. It never
## touches a campaign. PlanetfallPhaseManager applies the ops, the same split as
## BugHuntPostBattleResolver and BugHuntPhaseManager. Every die goes through
## DiceManager, so each table can be armed from the QA seam:
##   "Planetfall Morale Incident" (D100), "Planetfall Crisis Check" (2D6),
##   "Planetfall Crisis Outcome" (2D6), "Planetfall Integrity Failure" (3D6),
##   "Planetfall Sabotage" (D6), "Planetfall Psionic Cohesion" (D6),
##   "Planetfall Colonist Demands" (D6), "Planetfall Injury" (D100),
##   "Planetfall Grunt Casualty" (D6).
##
## Until 2026-10-27 Step 16 rolled a D6 per point of negative Integrity and lost grunts
## on a 5-6, a table in neither book, and Step 11 printed "roll on the Morale Incident
## table" without rolling it, so Political Upheaval and the Crisis did not exist.
##
## Ops (applied in order):
##   {op: "morale_adjust", amount}      {op: "morale_set", value}
##   {op: "story_point"}                {op: "upheaval", amount}
##   {op: "upheaval_set", value}        {op: "crisis", active}
##   {op: "campaign_failure"}           {op: "colony_damage", amount, mitigable}
##   {op: "income_penalty", turn, bp, rp}
##   {op: "injury", character_id, turns}  {op: "slain", character_id}
##   {op: "xp", character_id, amount}   {op: "loyalty_loss", character_id}
##   {op: "protest"}                    {op: "colonist_demands", active}
##   {op: "bot_broken"}                 {op: "grunt_lost"}

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")

const INTEGRITY_PATH := "res://data/planetfall/integrity_failure.json"
const MORALE_PATH := "res://data/planetfall/morale_incidents.json"

var _dice: PlanetfallEventResolverScript
var _integrity: Dictionary = {}
var _morale: Dictionary = {}


func _init() -> void:
	_dice = PlanetfallEventResolverScript.new()
	_integrity = _load(INTEGRITY_PATH)
	_morale = _load(MORALE_PATH)


func is_loaded() -> bool:
	return not _integrity.is_empty() and not _morale.is_empty()


func incident_threshold() -> int:
	return int(_morale.get("incident_threshold", -10))


func integrity_threshold() -> int:
	return int(_integrity.get("threshold", -3))


## ============================================================================
## STEP 11 — COLONY MORALE ADJUSTMENTS (pp.68, 89-90)
## ============================================================================

## p.68: "drops 1 point during this step ... an additional point for every battle
## casualty. If you were playing a Rescue Mission, you do NOT suffer Morale loss due
## to casualties, except for the colonists in the mission". Colony Damage is NOT
## charged here: p.87 and p.89 charge it when it is taken
## (PlanetfallCampaignCore.take_colony_damage). Shared with the preview.
static func morale_change(casualties: int, mission_id: String, colonists_lost: int = 0) -> int:
	if mission_id == "rescue":
		return -1 - maxi(colonists_lost, 0)
	return -1 - maxi(casualties, 0)


## ctx: morale, casualties, mission_id, mission_played, mission_won, upheaval,
## in_crisis, story_points, story_points_blocked, turn, roster, psionic_cohesion,
## colonist_demands, supervisors, personal_appeals, crisis_reroll.
func resolve_morale_step(ctx: Dictionary) -> Dictionary:
	var r := {"lines": [], "ops": []}
	var st := {
		"upheaval": int(ctx.get("upheaval", 0)),
		"in_crisis": bool(ctx.get("in_crisis", false)),
		"story_points": int(ctx.get("story_points", 0)),
	}
	_resolve_colonist_demands(ctx, r)
	if st.in_crisis:
		# p.90: "Colony Morale is fixed at 0 and cannot be changed for any reason. All
		# modifiers are ignored." p.68: "If a Crisis is ongoing, a test is now made".
		_line(r, "A Crisis is ongoing: Colony Morale is fixed at 0 and this step's "
				+ "adjustments are ignored (p.90).")
		_resolve_crisis_outcome(ctx, st, r)
		return r

	var casualties: int = int(ctx.get("casualties", 0))
	var rescue: bool = str(ctx.get("mission_id", "")) == "rescue"
	var change: int = morale_change(casualties, str(ctx.get("mission_id", "")),
			int(ctx.get("colonists_lost", 0)))
	_line(r, "Automatic: -1 (p.68).")
	if rescue and casualties > 0:
		# p.68 / p.89 Rescue Missions: squad casualties cost no Morale; colonists lost
		# are charged by the mission's own post-battle step.
		_line(r, "Rescue Mission: %d squad casualt%s cost no Morale (p.89)."
				% [casualties, "y" if casualties == 1 else "ies"])
	elif casualties > 0:
		_line(r, "Battle casualties: -%d (p.68)." % casualties)
	_op(r, {"op": "morale_adjust", "amount": change})
	var before: int = int(ctx.get("morale", 0))
	var after: int = before + change
	_line(r, "Colony Morale: %d -> %d." % [before, after])
	if after <= incident_threshold():
		_resolve_incident(ctx, st, r)
	return r


func _resolve_incident(ctx: Dictionary, st: Dictionary, r: Dictionary) -> void:
	_line(r, "Morale is %d or worse: a Morale Incident occurs (p.89)." % incident_threshold())
	if bool(ctx.get("personal_appeals", false)) and _can_spend_story_point(ctx, st):
		# p.89 Personal Appeals: the test counts as "nothing happens", and nothing was
		# rolled on the table, so no Political Upheaval is added for it.
		_spend_story_point(st, r)
		_line(r, "Personal Appeals: 1 Story Point spent. The incident counts as "
				+ "\"nothing happens\" (p.89).")
		_op(r, {"op": "morale_set", "value": 0})
		_line(r, "Colony Morale is set back to 0.")
		return

	var roll: int = _dice.roll_d100("Planetfall Morale Incident")
	var entry: Dictionary = _range_entry(_morale.get("incidents", []), roll)
	_line(r, "D100 %d: %s. %s" % [roll, entry.get("name", "?"), entry.get("description", "")])
	match str(entry.get("id", "")):
		"protests":
			_op(r, {"op": "protest"})
		"colonist_demands":
			_op(r, {"op": "colonist_demands", "active": true})
	for effect in entry.get("effects", []):
		if effect is Dictionary:
			_apply_effect(effect, ctx, st, r)
	_op(r, {"op": "morale_set", "value": 0})
	_line(r, "Colony Morale is set back to 0 (p.89).")
	st.upheaval += 1
	_op(r, {"op": "upheaval", "amount": 1})
	_line(r, "Political Upheaval +1, now %d (p.89)." % st.upheaval)
	if not st.in_crisis:
		_crisis_check(st, r)


## p.89: "Roll 2D6. If the roll is equal to or below the amount of Political Upheaval,
## the colony suffers a collapse of government and enters a Crisis."
func _crisis_check(st: Dictionary, r: Dictionary) -> void:
	var roll: int = _dice.roll_2d6("Planetfall Crisis Check")
	if roll <= int(st.upheaval):
		st.in_crisis = true
		_op(r, {"op": "crisis", "active": true})
		_line(r, "Crisis check: 2D6 %d is at or below Political Upheaval %d. The government "
				% [roll, st.upheaval] + "collapses and the colony enters a Crisis (p.89).")
	else:
		_line(r, "Crisis check: 2D6 %d is above Political Upheaval %d. No Crisis."
				% [roll, st.upheaval])


func _resolve_crisis_outcome(ctx: Dictionary, st: Dictionary, r: Dictionary) -> void:
	var roll: int = _dice.roll_2d6("Planetfall Crisis Outcome")
	if bool(ctx.get("crisis_reroll", false)) and _can_spend_story_point(ctx, st):
		var second: int = _dice.roll_2d6("Planetfall Crisis Outcome")
		_spend_story_point(st, r)
		_line(r, "1 Story Point spent to roll twice: %d and %d, keeping %d (p.90)."
				% [roll, second, maxi(roll, second)])
		roll = maxi(roll, second)
	var entry: Dictionary = _range_entry(_morale.get("crisis_outcomes", []), roll)
	_line(r, "Crisis Outcome 2D6 %d: %s. %s"
			% [roll, entry.get("name", "?"), entry.get("description", "")])
	match str(entry.get("id", "")):
		"high_tensions":
			var check: int = _dice.roll_2d6("Planetfall Crisis Check")
			if check <= int(st.upheaval):
				_op(r, {"op": "campaign_failure"})
				_line(r, "Crisis check: 2D6 %d is at or below Political Upheaval %d. The "
						% [check, st.upheaval] + "colony collapses into open rebellion. "
						+ "Unity forces move in and the campaign ends (p.90).")
			else:
				st.upheaval += 1
				_op(r, {"op": "upheaval", "amount": 1})
				_line(r, "Crisis check: 2D6 %d is above Political Upheaval. Political "
						% check + "Upheaval +1, now %d." % st.upheaval)
		"deteriorating_conditions":
			if not bool(ctx.get("mission_played", false)):
				_line(r, "No mission result was recorded this turn, so nothing changes.")
			elif bool(ctx.get("mission_won", false)):
				_line(r, "This turn's mission succeeded: no change.")
			else:
				st.upheaval += 1
				_op(r, {"op": "upheaval", "amount": 1})
				_line(r, "This turn's mission failed: Political Upheaval +1, now %d."
						% st.upheaval)
		"building_bridges":
			st.upheaval -= 1
			if st.upheaval <= 0:
				_line(r, "Political Upheaval falls to 0: treated as Agreements reached.")
				_end_crisis(st, r)
			else:
				_op(r, {"op": "upheaval", "amount": -1})
				_line(r, "Political Upheaval -1, now %d." % st.upheaval)
		"agreements_reached":
			_end_crisis(st, r)


func _end_crisis(st: Dictionary, r: Dictionary) -> void:
	st.in_crisis = false
	st.upheaval = 0
	_op(r, {"op": "crisis", "active": false})
	_op(r, {"op": "upheaval_set", "value": 0})
	_op(r, {"op": "morale_set", "value": 0})
	_line(r, "The Crisis ends. Political Upheaval and Colony Morale are set to 0 (p.90).")


## p.90 Colonist demands: "For each character, roll 1D6+Savvy with a 5+ indicating the
## demands have been satisfied." Supervisors are chosen by the player in this step.
func _resolve_colonist_demands(ctx: Dictionary, r: Dictionary) -> void:
	if not bool(ctx.get("colonist_demands", false)):
		return
	var supervisors: Array = ctx.get("supervisors", [])
	if supervisors.is_empty():
		_line(r, "Colonist demands continue: no scouts or troopers supervised security (p.90).")
		return
	var by_id: Dictionary = {}
	for c in ctx.get("roster", []):
		if c is Dictionary:
			by_id[str(c.get("id", ""))] = c
	for cid in supervisors:
		var c: Dictionary = by_id.get(str(cid), {})
		var savvy: int = int(c.get("savvy", 0))
		var roll: int = _dice.roll_d6("Planetfall Colonist Demands")
		var total: int = roll + savvy
		var ok: bool = total >= 5
		_line(r, "%s supervises security: 1D6 %d %+d Savvy = %d%s." % [
				c.get("name", str(cid)), roll, savvy, total,
				" (5+: satisfied)" if ok else ""])
		if ok:
			_op(r, {"op": "colonist_demands", "active": false})
			_line(r, "The colonists' demands have been satisfied (p.90).")
			return
	_line(r, "The colonists' demands continue.")


## ============================================================================
## STEP 16 — COLONY INTEGRITY (pp.87-88)
## ============================================================================

## Step 9 Injuries (p.66). ctx: roster, battle_result (normalized by
## PlanetfallBattleResultNormalizer, which has already split the casualties by class).
## "Injury rolls are made for any scientist, scout, trooper, or crew"; civvies "do not
## roll"; a bot "is marked 'Broken' ... until repaired"; each grunt rolls 1D6 and is
## lost on 1-2. Uses the same _injury_roll as the Integrity Failure table, so there is
## one copy of the p.66 roller.
func resolve_injury_step(ctx: Dictionary) -> Dictionary:
	var r := {"lines": [], "ops": []}
	var br: Dictionary = ctx.get("battle_result", {}) if ctx.get("battle_result") is Dictionary \
			else {}
	var roster: Array = ctx.get("roster", []) if ctx.get("roster") is Array else []
	var by_id: Dictionary = {}
	for c in roster:
		if c is Dictionary:
			by_id[str(c.get("id", ""))] = c
	var rolled: int = 0
	for cid in br.get("injury_roll_ids", []):
		var who: Dictionary = by_id.get(str(cid), {})
		if who.is_empty():
			_line(r, "%s is no longer on the roster; no injury roll." % str(cid))
			continue
		_injury_roll(who, 0, r)
		rolled += 1
	for cid in br.get("broken_bot_ids", []):
		_op(r, {"op": "bot_broken"})
		_line(r, "%s is a bot: no injury roll. It is marked Broken until repaired (p.66)."
				% by_id.get(str(cid), {}).get("name", str(cid)))
	for cid in br.get("civvy_casualty_ids", []):
		_line(r, "%s is a civvy: civvies do not roll on the Injury table (p.66)."
				% by_id.get(str(cid), {}).get("name", str(cid)))
	var grunts: int = int(br.get("grunt_casualties", 0))
	for i in range(maxi(grunts, 0)):
		var roll: int = _dice.roll_d6("Planetfall Grunt Casualty")
		var res: Dictionary = _dice.resolve_grunt_casualty(roll)
		if bool(res.get("permanent", false)):
			_op(r, {"op": "grunt_lost"})
			_line(r, "Grunt %d, D6 %d: lost to the colony (p.66)." % [i + 1, roll])
		else:
			_line(r, "Grunt %d, D6 %d: okay, recovers for the next mission." % [i + 1, roll])
	if rolled == 0 and grunts <= 0 and (br.get("broken_bot_ids", []) as Array).is_empty() \
			and (br.get("civvy_casualty_ids", []) as Array).is_empty():
		_line(r, "No casualties this battle.")
	return r


## ctx: integrity, in_crisis, story_points, story_points_blocked, turn, roster,
## emergency_repairs.
func resolve_integrity_step(ctx: Dictionary) -> Dictionary:
	var r := {"lines": [], "ops": []}
	var st := {
		"upheaval": 0,
		"in_crisis": bool(ctx.get("in_crisis", false)),
		"story_points": int(ctx.get("story_points", 0)),
	}
	var integrity: int = int(ctx.get("integrity", 0))
	_line(r, "Colony Integrity: %d." % integrity)
	if integrity > integrity_threshold():
		_line(r, "Integrity is above %d: no Integrity Failure test (p.87)."
				% integrity_threshold())
		return r
	if bool(ctx.get("emergency_repairs", false)) and _can_spend_story_point(ctx, st):
		_spend_story_point(st, r)
		_line(r, "Emergency Repairs: 1 Story Point spent to avoid the Integrity Failure "
				+ "roll. Integrity is unchanged (p.88).")
		return r
	var target: int = -integrity
	var roll: int = _dice.roll_3d6("Planetfall Integrity Failure")
	if roll > target:
		_line(r, "3D6 %d is above %d: no Integrity Failure (p.87)." % [roll, target])
		return r
	var entry: Dictionary = {}
	for e in _integrity.get("entries", []):
		if e is Dictionary and int(e.get("roll", 0)) == roll:
			entry = e
	_line(r, "3D6 %d is %d or less: Integrity Failure. %s"
			% [roll, target, entry.get("text", "")])
	for effect in entry.get("effects", []):
		if effect is Dictionary:
			_apply_effect(effect, ctx, st, r)
	return r


## ============================================================================
## SHARED EFFECTS
## ============================================================================

func _apply_effect(effect: Dictionary, ctx: Dictionary, st: Dictionary, r: Dictionary) -> void:
	match str(effect.get("op", "")):
		"morale":
			_op(r, {"op": "morale_adjust", "amount": int(effect.get("amount", 0))})
			if st.in_crisis:
				_line(r, "(Crisis: Colony Morale is fixed at 0, so this has no effect.)")
		"colony_damage":
			var amount: int = int(effect.get("amount", 0))
			if str(effect.get("dice", "")) == "1D6":
				amount = _dice.roll_d6("Planetfall Sabotage")
				_line(r, "Sabotage: 1D6 = %d Colony Damage." % amount)
			_op(r, {"op": "colony_damage", "amount": amount,
					"mitigable": bool(effect.get("mitigable", true))})
		"income_penalty":
			var turn: int = int(ctx.get("turn", 0)) + int(effect.get("turn_offset", 0))
			_op(r, {"op": "income_penalty", "turn": turn,
					"bp": int(effect.get("bp", 0)), "rp": int(effect.get("rp", 0))})
		"crisis_check":
			if st.in_crisis:
				_line(r, "The colony is already in Crisis.")
			else:
				_crisis_check(st, r)
		"loyalty_loss":
			var c: Dictionary = _random_character(ctx, r)
			if c.is_empty():
				return
			if bool(ctx.get("psionic_cohesion", false)):
				var save: int = _dice.roll_d6("Planetfall Psionic Cohesion")
				if save >= 5:
					_line(r, "%s keeps their Loyalty: Psionic Cohesion 1D6 %d (p.105)."
							% [c.get("name", "?"), save])
					return
				_line(r, "Psionic Cohesion 1D6 %d: no save." % save)
			_op(r, {"op": "loyalty_loss", "character_id": str(c.get("id", ""))})
		"injury_roll":
			var c: Dictionary = _random_character(ctx, r)
			if c.is_empty():
				return
			_injury_roll(c, int(effect.get("death_as_recovery_turns", 0)), r)
		"slain":
			var c: Dictionary = _random_character(ctx, r)
			if c.is_empty():
				return
			_op(r, {"op": "slain", "character_id": str(c.get("id", ""))})
			_line(r, "%s is slain." % c.get("name", "?"))


## p.66 injury roll for an Integrity Failure victim. `death_as_recovery` > 0 is the
## row 10 clause: "treat 'Death' as 5 turns of recovery instead".
## One p.66 injury roll as its own receipt, for a table outside this file that sends a
## character to it (p.71 Accident, "Dead ... counts as 5 turns of recovery").
func injury_roll_receipt(c: Dictionary, death_as_recovery: int = 0) -> Dictionary:
	var r: Dictionary = {"lines": [], "ops": []}
	_injury_roll(c, death_as_recovery, r)
	return r


func _injury_roll(c: Dictionary, death_as_recovery: int, r: Dictionary) -> void:
	var cid: String = str(c.get("id", ""))
	var cname: String = str(c.get("name", cid))
	var roll: int = _dice.roll_d100("Planetfall Injury")
	var result: Dictionary = _dice.resolve_injury(roll)
	var turns: int = int(result.get("sick_bay_turns", 0))
	if bool(result.get("permanent", false)):
		if death_as_recovery > 0:
			_op(r, {"op": "injury", "character_id": cid, "turns": death_as_recovery})
			_line(r, "%s's injury roll, D100 %d: %s, treated as %d turns of recovery."
					% [cname, roll, result.get("name", "?"), death_as_recovery])
		else:
			_op(r, {"op": "slain", "character_id": cid})
			_line(r, "%s's injury roll, D100 %d: %s." % [cname, roll, result.get("name", "?")])
		return
	if turns > 0:
		_op(r, {"op": "injury", "character_id": cid, "turns": turns})
	var xp: int = int(result.get("bonus_xp", 0))
	if xp > 0:
		_op(r, {"op": "xp", "character_id": cid, "amount": xp})
	_line(r, "%s's injury roll, D100 %d: %s." % [cname, roll, result.get("name", "?")])


func _random_character(ctx: Dictionary, r: Dictionary) -> Dictionary:
	var roster: Array = []
	for c in ctx.get("roster", []):
		if c is Dictionary:
			roster.append(c)
	if roster.is_empty():
		_line(r, "There is no character on the roster to affect.")
		return {}
	var c: Dictionary = roster[_dice.pick_index(roster.size())]
	_line(r, "Random character: %s." % c.get("name", "?"))
	return c


func _can_spend_story_point(ctx: Dictionary, st: Dictionary) -> bool:
	return int(st.story_points) > 0 and not bool(ctx.get("story_points_blocked", false))


func _spend_story_point(st: Dictionary, r: Dictionary) -> void:
	st.story_points -= 1
	_op(r, {"op": "story_point"})


func _range_entry(table: Array, roll: int) -> Dictionary:
	for e in table:
		if e is Dictionary and roll >= int(e.get("min", 0)) and roll <= int(e.get("max", 0)):
			return e
	return {}


func _line(r: Dictionary, text: String) -> void:
	(r.lines as Array).append(text)


func _op(r: Dictionary, op: Dictionary) -> void:
	(r.ops as Array).append(op)


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("PlanetfallColonyCrisis: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
