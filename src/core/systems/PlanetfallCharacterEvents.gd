extends RefCounted

## Planetfall Step 17, the Character Event table (pp.70-71).
##
## PURE, like PlanetfallColonyCrisis: it reads a snapshot (`ctx`) and returns a receipt
## {lines, ops, choice}. PlanetfallPhaseManager.apply_character_event_ops() applies the
## ops. Until 2026-10-27 the Step 17 dialog applied six of the table's twenty rows (XP,
## Sick Bay, Morale, Story Points) and printed the rest: no Loyalty ever moved, no Enemy
## Information was gained, R&R, Dispute, Making friends and Accident did nothing, and the
## next-mission modifiers were never recorded.
##
## Dice (all forceable from the QA seam): "Planetfall Step 17 Event" (D100, rolled by
## the dialog), "Planetfall R&R Return" (D6), "Planetfall Friendship" (D6) and
## "Planetfall Injury" (D100, the p.66 table, through PlanetfallColonyCrisis).
##
## ctx: roster (Array of character dicts), sick_bay ({id: turns}), campaign_turn,
##      tactical_enemy_count, last_mission_won (true / false / null when none recorded),
##      away (Array of ids off world, who "cannot be the target of events").
##
## Ops beyond PlanetfallColonyCrisis's (xp, injury, slain, loyalty_loss):
##   {op: "loyalty_gain", character_id}           {op: "enemy_info", enemy_index, amount}
##   {op: "sick_bay_extend", character_id, turns}  {op: "reduce_recovery", character_id, turns}
##   {op: "recover_fully", character_id}          {op: "departed", character_id}
##   {op: "away", character_id, until_turn}       {op: "dispute", a, b, turn}
##   {op: "note", character_id, key, value}       {op: "story_point_gain", amount}
##   {op: "morale_adjust", amount}

const EventResolverScript := preload("res://src/core/systems/PlanetfallEventResolver.gd")
const ColonyCrisisScript := preload("res://src/core/systems/PlanetfallColonyCrisis.gd")

## p.71 Accident: 'If you roll "Dead", it instead counts as 5 turns of recovery.'
const ACCIDENT_DEATH_RECOVERY := 5
## p.70 R&R: "gone for 2 campaign turns".
const RR_TURNS := 2
## p.70 Change of assignment: "they immediately earn 5 XP".
const TRANSFER_XP := 5

var _dice: EventResolverScript


func _init() -> void:
	_dice = EventResolverScript.new()


func resolve(ctx: Dictionary, character_id: String, roll: int) -> Dictionary:
	var r: Dictionary = {"lines": [], "ops": [], "choice": {}}
	var c: Dictionary = _character(ctx, character_id)
	var event: Dictionary = _dice.resolve_character_event(roll)
	r["event"] = event
	if c.is_empty():
		_line(r, "That character is no longer on the roster.")
		return r
	var cid: String = str(c.get("id", ""))
	var cname: String = str(c.get("name", cid))
	var turn: int = int(ctx.get("campaign_turn", 0))
	var effect: Dictionary = event.get("effect", {})

	match str(event.get("id", "")):
		"minor_promotion":
			if str(c.get("loyalty", "committed")).to_lower() == "loyal":
				_op(r, {"op": "xp", "character_id": cid, "amount": 2})
				_line(r, "%s is already Loyal: +2 XP." % cname)
			else:
				_op(r, {"op": "loyalty_gain", "character_id": cid})
				_op(r, {"op": "xp", "character_id": cid, "amount": 1})
				_line(r, "%s gains a level of Loyalty and +1 XP." % cname)
		"personal_investigation":
			var enemies: int = int(ctx.get("tactical_enemy_count", 0))
			if enemies <= 0:
				_line(r, "No Tactical Enemy has been encountered yet, so there is nothing to learn.")
			else:
				var idx: int = _dice.pick_index(enemies, "Planetfall Investigation Enemy")
				_op(r, {"op": "enemy_info", "enemy_index": idx, "amount": 1})
				_line(r, "+1 Enemy Information on Tactical Enemy %d." % (idx + 1))
		"something_in_the_water":
			if _in_sick_bay(ctx, cid):
				_op(r, {"op": "sick_bay_extend", "character_id": cid, "turns": 1})
				_line(r, "%s's recovery takes 1 turn longer." % cname)
			else:
				_line(r, "%s gets a tummy ache but is otherwise fine." % cname)
		"r_and_r":
			_resolve_r_and_r(ctx, c, turn, r)
		"change_of_assignment":
			r["choice"] = {"kind": "change_of_assignment", "character_id": cid}
			_line(r, "Decide whether %s accepts: +%d XP and a transfer to another Five "
					% [cname, TRANSFER_XP] + "Parsecs game, or decline and gain a level of Loyalty.")
		"disputes_with_leadership":
			_op(r, {"op": "loyalty_loss", "character_id": cid})
		"commitment_to_cause":
			_op(r, {"op": "loyalty_gain", "character_id": cid})
		"dispute":
			var other: Dictionary = _second_character(ctx, cid)
			if other.is_empty():
				_line(r, "There is no one for %s to fall out with." % cname)
			else:
				_op(r, {"op": "dispute", "a": cid, "b": str(other.get("id", "")), "turn": turn + 1})
				_line(r, "%s and %s cannot both be assigned to next turn's mission unless "
						% [cname, str(other.get("name", "?"))] + "it is a Pitched Battle.")
		"personal_calibrations":
			_op(r, {"op": "note", "character_id": cid, "key": "calibrated", "value": true})
			_line(r, "On %s's next mission, one weapon they carry gets +1 to hit." % cname)
		"making_friends":
			var friend: Dictionary = _second_character(ctx, cid)
			if friend.is_empty():
				_line(r, "There is no one else on the roster to befriend.")
			else:
				for who in [c, friend]:
					var wid: String = str(who.get("id", ""))
					_op(r, {"op": "xp", "character_id": wid, "amount": 1})
					var d6: int = _dice.roll_d6("Planetfall Friendship")
					if d6 >= int(effect.get("loyalty_roll_threshold", 5)):
						_op(r, {"op": "loyalty_gain", "character_id": wid})
					_line(r, "%s: +1 XP, D6 %d%s." % [str(who.get("name", wid)), d6,
							", a level of Loyalty" if d6 >= int(effect.get("loyalty_roll_threshold", 5))
							else ""])
		"excellent_health":
			if _in_sick_bay(ctx, cid):
				_op(r, {"op": "reduce_recovery", "character_id": cid, "turns": 2})
				_line(r, "%s's recovery time is reduced by 2 turns." % cname)
			else:
				_op(r, {"op": "note", "character_id": cid, "key": "saved_health", "value": true})
				_line(r, "%s is not injured: the effect is saved for their next injury." % cname)
		"accident":
			var injury: Dictionary = ColonyCrisisScript.new().injury_roll_receipt(
					c, ACCIDENT_DEATH_RECOVERY)
			for line in injury.get("lines", []):
				_line(r, str(line))
			for op in injury.get("ops", []):
				_op(r, op)
		"personal_reflection":
			_op(r, {"op": "note", "character_id": cid, "key": "double_xp", "value": true})
			_line(r, "%s earns double XP on their next mission." % cname)
		"personal_conviction":
			_by_last_mission(ctx, r, cid, cname, true)
		"losing_faith":
			_by_last_mission(ctx, r, cid, cname, false)
		"personal_tragedy":
			_op(r, {"op": "note", "character_id": cid, "key": "xp_forfeit_turn", "value": turn + 1})
			_line(r, "Next campaign turn %s forfeits all XP. You may keep them out of the "
					% cname + "mission rather than lose it.")
		_:
			_apply_simple(effect, cid, cname, r)
	return r


## The rows that need no context: XP, a stay in Sick Bay, Story Points and Morale.
func _apply_simple(effect: Dictionary, cid: String, cname: String, r: Dictionary) -> void:
	if effect.has("xp"):
		_op(r, {"op": "xp", "character_id": cid, "amount": int(effect.xp)})
		_line(r, "+%d XP for %s." % [int(effect.xp), cname])
	if effect.has("sick_bay_turns"):
		_op(r, {"op": "injury", "character_id": cid, "turns": int(effect.sick_bay_turns)})
		_line(r, "%s spends %d campaign turns recovering." % [cname, int(effect.sick_bay_turns)])
	if effect.has("story_points"):
		_op(r, {"op": "story_point_gain", "amount": int(effect.story_points)})
		_line(r, "+%d Story Point." % int(effect.story_points))
	if effect.has("colony_morale"):
		_op(r, {"op": "morale_adjust", "amount": int(effect.colony_morale)})
		_line(r, "Colony Morale %+d." % int(effect.colony_morale))


## p.70 R&R: gone for 2 turns, recovers completely; a Disloyal character rolls 1D6:
## 1-2 they do not return, 3-5 remain Disloyal, 6 become Committed.
func _resolve_r_and_r(ctx: Dictionary, c: Dictionary, turn: int, r: Dictionary) -> void:
	var cid: String = str(c.get("id", ""))
	var cname: String = str(c.get("name", cid))
	if _in_sick_bay(ctx, cid):
		_op(r, {"op": "recover_fully", "character_id": cid})
		_line(r, "%s recovers completely from their injuries." % cname)
	if str(c.get("loyalty", "committed")).to_lower() == "disloyal":
		var d6: int = _dice.roll_d6("Planetfall R&R Return")
		if d6 <= 2:
			_op(r, {"op": "departed", "character_id": cid})
			_line(r, "%s is Disloyal, D6 %d: they do not return." % [cname, d6])
			return
		if d6 == 6:
			_op(r, {"op": "loyalty_gain", "character_id": cid})
			_line(r, "%s is Disloyal, D6 6: they come back Committed." % cname)
		else:
			_line(r, "%s is Disloyal, D6 %d: they remain Disloyal." % [cname, d6])
	_op(r, {"op": "away", "character_id": cid, "until_turn": turn + RR_TURNS})
	_line(r, "%s is off world for %d campaign turns and cannot be the target of events."
			% [cname, RR_TURNS])


func _by_last_mission(ctx: Dictionary, r: Dictionary, cid: String, cname: String,
		on_success: bool) -> void:
	var won: Variant = ctx.get("last_mission_won", null)
	if won == null:
		_line(r, "No mission result is recorded this turn, so nothing changes.")
		return
	if bool(won) == on_success:
		_op(r, {"op": "loyalty_gain" if on_success else "loyalty_loss", "character_id": cid})
	else:
		_line(r, "The last mission was a %s, so %s's Loyalty does not change."
				% ["failure" if on_success else "success", cname])


func _character(ctx: Dictionary, cid: String) -> Dictionary:
	for c in ctx.get("roster", []):
		if c is Dictionary and str(c.get("id", "")) == cid:
			return c
	return {}


## A random character other than `cid` who is not off world (p.70 R&R).
func _second_character(ctx: Dictionary, cid: String) -> Dictionary:
	var pool: Array = []
	var away: Array = ctx.get("away", [])
	for c in ctx.get("roster", []):
		if c is Dictionary and str(c.get("id", "")) != cid and not away.has(str(c.get("id", ""))):
			pool.append(c)
	if pool.is_empty():
		return {}
	return pool[_dice.pick_index(pool.size(), "Planetfall Second Character")]


func _in_sick_bay(ctx: Dictionary, cid: String) -> bool:
	return int((ctx.get("sick_bay", {}) as Dictionary).get(cid, 0)) > 0


func _line(r: Dictionary, text: String) -> void:
	(r["lines"] as Array).append(text)


func _op(r: Dictionary, op: Dictionary) -> void:
	(r["ops"] as Array).append(op)
