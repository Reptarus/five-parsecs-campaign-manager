class_name TacticsOperationalTurn
extends RefCounted

## Tactics Operational System, the TURN: the opening map (pp.93-95) and Steps 3-7 of
## the operational turn (pp.97-99). The dice tables and caps live in
## `TacticsOperationalRules`; this class runs them in the order the book prints.
##
## ⭐ Before 2026-10-27 every rule here existed and none of it ran. The outcome table,
## the Orders table and Army Strength generation had zero callers, no code path ever
## created a Zone (creation seeded `zones: []`), so the Strategic phase could only
## ever show an empty map and a Commando Raid button with nothing to raid.
##
## Shape: every method works on the operational-map DICTIONARY the campaign stores
## (`TacticsCampaignCore.operational_map`), mutates the copy it is handed, and returns
## a receipt. The Strategic panel passes its WORKING COPY; `TacticsPhaseManager` is
## the only thing that writes the result back to the campaign, and the only thing that
## turns `regions_lost` into Cohesion (Step 9). Nothing here touches Cohesion.
##
## The map Dictionary:
##   player_cohesion, enemy_cohesion, player_battle_points, operational_turn
##   focus_zone_id    the p.94 Operational Focus
##   player_zone_id   where the player's army is committed (Step 1 / Step 8)
##   regions  [{id, name, owner: "player" | "enemy" | "neutral"}]
##   zones    [{id, region_id, name, attacker, player_army_strength,
##              enemy_army_strength, player_adjacent, enemy_adjacent, opened_turn}]
##   orders_history   the operational log, one entry per opening / Strategic phase
##   next_zone_seq    id counter, so a ceased Zone's id is never reused
##
## `*_adjacent` is whether that side's territory touches the Zone. The app has no map
## geography — the player draws the map (p.93) — so the opening and new Zones set it by
## rule and the panel lets the player correct it against their paper map. It feeds the
## p.97 "+1 Combat Die if the enemy is not adjacent to their own territory".
##
## Dice: every roll goes through DiceManager with a "Tactics ..." context, so a QA
## tester can force one. A test passes `scripted_rolls` instead.

const RulesRef = preload("res://src/core/campaign/TacticsOperationalRules.gd")

const PLAYER := "player"
const ENEMY := "enemy"
const NEUTRAL := "neutral"
const FACTIONS: Array[String] = [PLAYER, ENEMY]

## A refight loop always ends — every refight row costs someone Army Strength — but a
## cap keeps a corrupt save (negative strengths, say) from spinning forever.
const MAX_REFIGHTS := 24

var _dice: Node = null
var _scripted: Array = []
var _scripted_mode: bool = false
## Every die rolled, in order: {die, value, context}. Tests read it; so can a receipt.
var rolls: Array = []


func _init(scripted_rolls: Array = []) -> void:
	_scripted = scripted_rolls.duplicate()
	_scripted_mode = not scripted_rolls.is_empty()
	# A RefCounted cannot use a bare get_node_or_null("/root/X"): it ERRORS and
	# aborts the enclosing function rather than returning null.
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		_dice = (loop as SceneTree).root.get_node_or_null("/root/DiceManager")


# MARK: - Opening (pp.93-95)

## True for a campaign that has never had its map opened — a new one, or a save made
## before 2026-10-27, when creation seeded an empty map. Guard on the CONTENT of two
## fields, not on the dictionary: an empty dictionary is a different defect.
static func needs_opening(map: Dictionary) -> bool:
	return _array(map, "regions").is_empty() and _array(map, "zones").is_empty()


## Build the opening map. Cohesion defaults to p.93's "If in doubt, begin Cohesion at
## 5 for each side" (read from the config); each faction holds as many regions as its
## Cohesion (p.94); the neutral count follows the p.93 example (see RulesRef).
##
## p.94: each faction attacks one region adjacent to its territory, the side with the
## initiative (picked at random) attacks a third, and one of the three becomes the
## Operational Focus. The book calls these "typically neutral regions between the
## warring factions", so an opening Zone counts as touching both sides' territory.
##
## Returns {"map", "receipt"}. Existing keys on `into` (cohesion, PBP, turn) are kept.
func build_opening_map(into: Dictionary = {}) -> Dictionary:
	var sv: Dictionary = RulesRef.starting_values()
	var map: Dictionary = into.duplicate(true)
	var pc: int = int(map.get("player_cohesion", sv.get("player_cohesion", 5)))
	var ec: int = int(map.get("enemy_cohesion", sv.get("enemy_cohesion", 5)))
	map["player_cohesion"] = pc
	map["enemy_cohesion"] = ec
	map["player_battle_points"] = int(map.get(
		"player_battle_points", sv.get("player_battle_points", 0)))
	map["operational_turn"] = int(map.get("operational_turn", 0))
	map["focus_zone_id"] = ""
	map["player_zone_id"] = ""
	map["zones"] = []
	map["next_zone_seq"] = 1
	if not (map.get("orders_history") is Array):
		map["orders_history"] = []

	var regions: Array = []
	for i in range(pc):
		regions.append({"id": "pr%d" % (i + 1), "name": "Your Region %d" % (i + 1),
			"owner": PLAYER})
	for i in range(ec):
		regions.append({"id": "er%d" % (i + 1), "name": "Enemy Region %d" % (i + 1),
			"owner": ENEMY})
	for i in range(RulesRef.opening_neutral_regions(pc, ec)):
		regions.append({"id": "nr%d" % (i + 1), "name": "Neutral Region %d" % (i + 1),
			"owner": NEUTRAL})
	map["regions"] = regions

	var receipt: Dictionary = _receipt("Opening the campaign (Tactics pp.93-95)")
	receipt.lines.append("Cohesion: you %d, enemy %d. Regions: %d yours, %d enemy, %d neutral."
		% [pc, ec, pc, ec, regions.size() - pc - ec])

	var bounds: Variant = RulesRef.opening_rules().get("initiative_player_on", [1, 3])
	var b: Array = bounds if bounds is Array and (bounds as Array).size() == 2 else [1, 3]
	var init_roll: int = _d6("Tactics Opening Initiative")
	var initiative: String = PLAYER \
		if init_roll >= int(b[0]) and init_roll <= int(b[1]) else ENEMY
	receipt.lines.append("Initiative (D6 %d): %s attack a third region." % [
		init_roll, "you" if initiative == PLAYER else "the enemy"])

	for attacker: String in [PLAYER, ENEMY, initiative]:
		var zone: Dictionary = _open_zone(map, attacker, true, "", false, false)
		if zone.is_empty():
			receipt.lines.append("%s had no region left to attack." % _who(attacker))
			continue
		receipt.lines.append(_zone_opened_line(zone))

	var zones: Array = _array(map, "zones")
	if not zones.is_empty():
		var focus: Dictionary = zones[_pick(zones.size(), "Tactics Opening Focus")]
		map["focus_zone_id"] = str(focus.get("id", ""))
		map["player_zone_id"] = map["focus_zone_id"]
		receipt.lines.append("Operational Focus: %s. Your army is committed there."
			% str(focus.get("name", "")))
	_log(map, receipt)
	return {"map": map, "receipt": receipt}


# MARK: - Step 3 — Resolve Battles (p.97)

## "A battle takes place in every Operational Zone." `pbp_spent` buys Combat Dice in
## the Zone the player's army is committed to, and is used up whatever happens —
## the caller deducts it (the panel's running `pbp_spent`).
## `assault_zone_ids` are the Zones where the player opts into the p.98 Assault Option.
## ⚠ The AI never assaults: the book gives it no rule for when to opt in, and an AI
## that always took the extra die would be an invented behaviour.
func resolve_zone_battles(map: Dictionary, pbp_spent: int = 0,
		assault_zone_ids: Array = []) -> Dictionary:
	var receipt: Dictionary = _receipt("Step 3 — Operational Combat in every Zone (p.97)")
	var player_zone: String = str(map.get("player_zone_id", ""))
	for zone: Dictionary in _array(map, "zones").duplicate():
		var zid: String = str(zone.get("id", ""))
		var spend: int = pbp_spent if zid == player_zone else 0
		_fight(zone, receipt, 0, spend, assault_zone_ids.has(zid))
	_settle_destruction(map, receipt)
	if _array(map, "zones").is_empty() and receipt.lines.is_empty():
		receipt.lines.append("No Operational Zones are open.")
	return receipt


## p.98: "An army with Army Strength 1 point higher than the opposing side may opt to
## launch an assault when conducting Operational Combat."
static func can_assault(zone: Dictionary, faction: String) -> bool:
	return _as(zone, faction) >= _as(zone, _opp(faction)) + 1


# MARK: - Step 4 — Operational Orders (p.98)

func roll_orders() -> Dictionary:
	var out: Dictionary = {}
	for f: String in FACTIONS:
		var r: int = _d6("Tactics Operational Orders: %s" % _who(f))
		var row: Dictionary = RulesRef.operational_order_for(r)
		row["faction"] = f
		out[f] = row
	return out


## The Zones an order may be aimed at, for a picker. Empty for orders that need no
## Zone (New Offensive picks a region; Bolster Positions is "the weakest army").
static func order_target_zones(map: Dictionary, faction: String, roll: int) -> Array:
	var out: Array = []
	for zone: Dictionary in _array(map, "zones"):
		var own: int = _as(zone, faction)
		var opp: int = _as(zone, _opp(faction))
		var ok: bool = false
		match roll:
			1, 4:
				ok = true
			2:
				ok = own >= opp   # "where it has equal or higher Army Strength"
			5:
				ok = opp > own    # "If the enemy has a higher Army Strength"
		if ok:
			out.append(str(zone.get("id", "")))
	return out


## Carry out both factions' orders in the book's order (p.98): "First, carry out any
## changes in Army Strengths and Operational Zones. Next, carry out any Operational
## Combats that occur. If two sides attack the same Zone, add +1 Combat Die to each
## side in the first Operational Combat that is resolved".
##
## `player_target_zone_id` is the player's choice where the order needs a Zone; "A
## player may select the target if they are fighting for a particular army". Absent
## or ineligible, the Zone is chosen at random, as for an AI faction.
func carry_out_orders(map: Dictionary, rolled: Dictionary,
		player_target_zone_id: String = "") -> Dictionary:
	var receipt: Dictionary = _receipt("Step 4 — Operational Orders (p.98)")
	var combats: Array = []
	for f: String in FACTIONS:
		var row: Variant = rolled.get(f, {})
		if not (row is Dictionary) or (row as Dictionary).is_empty():
			continue
		var roll: int = int((row as Dictionary).get("roll", 0))
		receipt.lines.append("%s rolled %d: %s." % [
			_who(f), roll, str((row as Dictionary).get("name", "?"))])
		var target: String = player_target_zone_id if f == PLAYER else ""
		match roll:
			1:
				# The optional terrain types (p.100) are not modelled, so the book's
				# own fallback applies: "increase Army Strength by +1 instead".
				var z1: Dictionary = _order_zone(map, f, roll, target)
				if not z1.is_empty():
					_set_as(z1, f, _as(z1, f) + 1)
					receipt.lines.append("  +1 Army Strength in %s (now %d)." % [
						z1.get("name", ""), _as(z1, f)])
			2:
				var z2: Dictionary = _order_zone(map, f, roll, target)
				if z2.is_empty():
					receipt.lines.append("  No Zone where they are at least as strong.")
				else:
					combats.append({"faction": f, "zone_id": str(z2.get("id", ""))})
			3:
				var z3: Dictionary = _open_zone(map, f, false, "", true, false)
				if z3.is_empty():
					receipt.lines.append("  No region left to attack.")
				else:
					receipt.lines.append("  " + _zone_opened_line(z3))
					combats.append({"faction": f, "zone_id": str(z3.get("id", ""))})
			4:
				var z4: Dictionary = _order_zone(map, f, roll, target)
				if not z4.is_empty():
					_set_as(z4, f, _as(z4, f) + 1)
					receipt.lines.append("  +1 Army Strength in %s (now %d)." % [
						z4.get("name", ""), _as(z4, f)])
					combats.append({"faction": f, "zone_id": str(z4.get("id", ""))})
			5:
				var z5: Dictionary = _order_zone(map, f, roll, target)
				if z5.is_empty():
					receipt.lines.append("  The other side is nowhere stronger.")
				else:
					var opp: String = _opp(f)
					_set_as(z5, opp, maxi(_as(z5, opp) - 1, 0))
					receipt.lines.append("  %s loses 1 Army Strength in %s (now %d)." % [
						_who(opp), z5.get("name", ""), _as(z5, opp)])
			6:
				var weakest: Dictionary = _weakest_army(map, f)
				if not weakest.is_empty():
					_set_as(weakest, f, _as(weakest, f) + 1)
					receipt.lines.append("  Weakest army, in %s, +1 Army Strength (now %d)."
						% [weakest.get("name", ""), _as(weakest, f)])
	_settle_destruction(map, receipt)

	var attackers: Dictionary = {}
	for c: Dictionary in combats:
		var zid: String = str(c.zone_id)
		var seen: Array = attackers.get(zid, [])
		if not seen.has(c.faction):
			seen.append(c.faction)
		attackers[zid] = seen
	var reserves_used: Dictionary = {}
	for c: Dictionary in combats:
		var zone: Dictionary = _zone(map, str(c.zone_id))
		if zone.is_empty():
			receipt.lines.append("  The Zone %s attacked has already ceased." % _who(c.faction))
			continue
		var extra: int = 0
		var zid: String = str(c.zone_id)
		if (attackers[zid] as Array).size() >= 2 and not reserves_used.has(zid):
			reserves_used[zid] = true
			extra = 1
			receipt.lines.append("  Both sides attack %s: +1 Combat Die each (p.98)."
				% zone.get("name", ""))
		_fight(zone, receipt, extra, 0)
		_settle_destruction(map, receipt)
	return receipt


# MARK: - Step 5 — Commando Raids (p.99)

## Commit `points` PBP against a Zone's enemy army. Returns {} when the raid cannot be
## attempted at all — which is different from a raid that rolled badly.
func commando_raid(map: Dictionary, zone_id: String, points: int) -> Dictionary:
	var held: int = int(map.get("player_battle_points", 0))
	var zone: Dictionary = _zone(map, zone_id)
	if points <= 0 or points > held or zone.is_empty():
		return {}
	var dice: Array = []
	for _i in range(points):
		dice.append(_d6("Tactics Commando Raid: %s" % zone.get("name", "")))
	var res: Dictionary = RulesRef.classify_commando_raid(dice)
	map["player_battle_points"] = held - points
	var dmg: int = int(res.get("army_strength_damage", 0))
	if dmg > 0:
		_set_as(zone, ENEMY, maxi(_as(zone, ENEMY) - dmg, 0))
	var receipt: Dictionary = _receipt("Step 5 — Commando Raid (p.99)")
	receipt.lines.append("Raid on %s with %d PBP: rolled %s. %s%s" % [
		zone.get("name", ""), points, str(dice),
		("Enemy -%d Army Strength (now %d)." % [dmg, _as(zone, ENEMY)])
			if dmg > 0 else "No damage.",
		" Every committed point is lost." if int(res.get("pbp_lost", 0)) > 0 else ""])
	receipt["spent"] = points
	receipt["raid"] = res
	_settle_destruction(map, receipt)
	return receipt


# MARK: - Step 6 — Redeploy Forces (p.99)

## Armies of `faction` that can give up a point without being destroyed.
static func redeploy_sources(map: Dictionary, faction: String) -> Array:
	var out: Array = []
	for zone: Dictionary in _array(map, "zones"):
		if _as(zone, faction) >= 2:
			out.append(str(zone.get("id", "")))
	return out


## "Each faction may redeploy 1 point of Army Strength provided both armies are
## connected through a series of friendly territories." The connection is on the
## player's paper map, so the panel states the condition and the player confirms it.
func redeploy(map: Dictionary, faction: String, from_id: String, to_id: String) -> Dictionary:
	var receipt: Dictionary = _receipt("Step 6 — Redeploy Forces (p.99)")
	var src: Dictionary = _zone(map, from_id)
	var dst: Dictionary = _zone(map, to_id)
	if src.is_empty() or dst.is_empty() or from_id == to_id or _as(src, faction) < 2:
		return receipt
	_set_as(src, faction, _as(src, faction) - 1)
	_set_as(dst, faction, _as(dst, faction) + 1)
	receipt.lines.append("%s moved 1 Army Strength from %s (now %d) to %s (now %d)." % [
		_who(faction), src.get("name", ""), _as(src, faction),
		dst.get("name", ""), _as(dst, faction)])
	return receipt


## "The AI will always try to reinforce an army reduced to 1-2 Army Strength, drawing
## the strength from the strongest army present."
func ai_redeploy(map: Dictionary, faction: String) -> Dictionary:
	var receipt: Dictionary = _receipt("Step 6 — Redeploy Forces (p.99)")
	var target: Dictionary = {}
	for zone: Dictionary in _array(map, "zones"):
		var s: int = _as(zone, faction)
		if s >= 1 and s <= 2 and (target.is_empty() or s < _as(target, faction)):
			target = zone
	if target.is_empty():
		receipt.lines.append("%s: no army at 1-2 Army Strength to reinforce." % _who(faction))
		return receipt
	var source: Dictionary = {}
	for zone: Dictionary in _array(map, "zones"):
		if zone == target or _as(zone, faction) < 2:
			continue
		if source.is_empty() or _as(zone, faction) > _as(source, faction):
			source = zone
	if source.is_empty():
		receipt.lines.append("%s: no other army can spare a point for %s." % [
			_who(faction), target.get("name", "")])
		return receipt
	var moved: Dictionary = redeploy(map, faction, str(source.get("id", "")),
		str(target.get("id", "")))
	receipt.lines.append_array(moved.lines)
	return receipt


# MARK: - Step 7 — Open new Zones; select new Focus (p.99)

## The regions `faction` could attack, in the AI's order of preference: "The AI picks
## at random from adjacent opposing regions, and then from neutral regions if no enemy
## territory is adjacent." Regions already fought over are excluded.
static func attack_targets(map: Dictionary, faction: String) -> Array:
	var contested: Dictionary = {}
	for zone: Dictionary in _array(map, "zones"):
		contested[str(zone.get("region_id", ""))] = true
	var opposing: Array = []
	var neutral: Array = []
	for region: Dictionary in _array(map, "regions"):
		var rid: String = str(region.get("id", ""))
		if contested.has(rid):
			continue
		var owner: String = str(region.get("owner", NEUTRAL))
		if owner == _opp(faction):
			opposing.append(rid)
		elif owner == NEUTRAL:
			neutral.append(rid)
	return opposing + neutral


## "Each faction that won an Operational Zone attacks a region adjacent to its
## territory ... The attacking army receives an Army Strength of the highest result
## from two D6s. The defending army is generated with 1D6 Army Strength." Then a new
## Focus is selected.
func open_new_zones(map: Dictionary, zones_won: Dictionary,
		player_target_region_id: String = "") -> Dictionary:
	var receipt: Dictionary = _receipt("Step 7 — Open new Zones; select new Focus (p.99)")
	for f: String in FACTIONS:
		if int(zones_won.get(f, 0)) <= 0:
			continue
		var target: String = player_target_region_id if f == PLAYER else ""
		var zone: Dictionary = _open_zone(map, f, false, target, true, true)
		if zone.is_empty():
			receipt.lines.append("%s won a Zone but has no region left to attack." % _who(f))
		else:
			receipt.lines.append(_zone_opened_line(zone))
	if not receipt.lines.size():
		receipt.lines.append("No faction won a Zone this turn, so no new Zone opens.")
	var zones: Array = _array(map, "zones")
	if zones.is_empty():
		map["focus_zone_id"] = ""
		receipt.lines.append("No Zone is open, so there is no Operational Focus.")
	else:
		var focus: Dictionary = zones[_pick(zones.size(), "Tactics New Focus")]
		map["focus_zone_id"] = str(focus.get("id", ""))
		receipt.lines.append("New Operational Focus: %s." % focus.get("name", ""))
		if _zone(map, str(map.get("player_zone_id", ""))).is_empty():
			map["player_zone_id"] = map["focus_zone_id"]
			receipt.lines.append("Your army's Zone has ceased; it moves to the Focus.")
	return receipt


## Append a finished Strategic phase to the operational log. `orders_history` was
## declared and serialized from the start and nothing ever wrote it.
static func log_strategic_phase(map: Dictionary, turn: int, receipts: Array) -> void:
	var steps: Array = []
	for r: Variant in receipts:
		if r is Dictionary and not (r as Dictionary).get("lines", []).is_empty():
			steps.append({"title": str(r.get("title", "")),
				"lines": (r.get("lines", []) as Array).duplicate()})
	if steps.is_empty():
		return
	if not (map.get("orders_history") is Array):
		map["orders_history"] = []
	(map["orders_history"] as Array).append({"turn": turn, "steps": steps})


# MARK: - Army destruction (p.98)

## "If an army is reduced to 0 Army Strength, they are no longer able to contest the
## region. The Operational Zone ceases to exist, and the area falls under control of
## the survivors. ... two armies may destroy each other. If so, the Operational Zone
## still ceases to exist and the region becomes neutral."
##
## A region that leaves a faction's hands is a region LOST (Step 9, p.99); a neutral
## region taken costs nobody anything. The winner of a Zone is recorded for Step 7.
func _settle_destruction(map: Dictionary, receipt: Dictionary) -> void:
	for zone: Dictionary in _array(map, "zones").duplicate():
		var p: int = _as(zone, PLAYER)
		var e: int = _as(zone, ENEMY)
		if p > 0 and e > 0:
			continue
		var region: Dictionary = _region(map, str(zone.get("region_id", "")))
		var before: String = str(region.get("owner", NEUTRAL))
		var after: String = NEUTRAL
		if p <= 0 and e <= 0:
			receipt.lines.append("Both armies in %s are destroyed: the Zone ceases and "
				% zone.get("name", "") + "the region becomes neutral.")
		else:
			after = ENEMY if p <= 0 else PLAYER
			receipt.zones_won[after] = int(receipt.zones_won.get(after, 0)) + 1
			if after == ENEMY:
				receipt.lines.append("Your army in %s is destroyed: the Zone ceases and "
					% zone.get("name", "") + "the enemy takes the region.")
			else:
				receipt.lines.append("The enemy army in %s is destroyed: the Zone ceases "
					% zone.get("name", "") + "and you take the region.")
		if not region.is_empty():
			region["owner"] = after
		if before != after and (before == PLAYER or before == ENEMY):
			receipt.regions_lost[before] = int(receipt.regions_lost.get(before, 0)) + 1
			receipt.lines.append("%s lost a region: Cohesion -1 (Step 9, p.99)." % _who(before))
		_array(map, "zones").erase(zone)
		var zid: String = str(zone.get("id", ""))
		if str(map.get("focus_zone_id", "")) == zid:
			map["focus_zone_id"] = ""


# MARK: - Combat

func _fight(zone: Dictionary, receipt: Dictionary,
		extra_each: int, player_pbp: int, player_assault: bool = false) -> void:
	var name: String = str(zone.get("name", zone.get("id", "Zone")))
	var p_dice: int = RulesRef.combat_dice(_as(zone, PLAYER), _as(zone, ENEMY),
		player_pbp, not _adjacent(zone, ENEMY), extra_each)
	var e_dice: int = RulesRef.combat_dice(_as(zone, ENEMY), _as(zone, PLAYER),
		0, not _adjacent(zone, PLAYER), extra_each)
	if player_pbp > 0:
		receipt.lines.append("%s: you spend %d PBP for +%d Combat Dice." % [
			name, player_pbp, player_pbp])
	var assaulting: bool = player_assault and can_assault(zone, PLAYER)
	if assaulting:
		p_dice += 1
		receipt.lines.append("%s: you launch an assault, +1 Combat Die (p.98)." % name)
	var won_last: bool = false
	for _round in range(MAX_REFIGHTS):
		var pr: Array = _pool(p_dice, "Tactics Operational Combat: %s (you)" % name)
		var er: Array = _pool(e_dice, "Tactics Operational Combat: %s (enemy)" % name)
		var out: Dictionary = RulesRef.classify_combat_outcome(pr, er)
		won_last = int(out.get("enemy_delta", 0)) < 0 and int(out.get("player_delta", 0)) >= 0
		_set_as(zone, PLAYER, maxi(_as(zone, PLAYER) + int(out.get("player_delta", 0)), 0))
		_set_as(zone, ENEMY, maxi(_as(zone, ENEMY) + int(out.get("enemy_delta", 0)), 0))
		receipt.lines.append("%s: you %s, enemy %s — %s. Army Strength you %d, enemy %d."
			% [name, str(pr), str(er), str(out.get("outcome", "")),
			_as(zone, PLAYER), _as(zone, ENEMY)])
		if _as(zone, PLAYER) <= 0 or _as(zone, ENEMY) <= 0:
			break
		var again: bool = false
		match str(out.get("id", "")):
			"both_multiple_sixes":
				again = true
			"one_multiple_sixes":
				# "If the winner now has higher Army Strength, fight again immediately"
				var player_won: bool = int(out.get("player_delta", 0)) > 0
				again = _as(zone, PLAYER) > _as(zone, ENEMY) if player_won \
					else _as(zone, ENEMY) > _as(zone, PLAYER)
		if not again:
			break
		# "Adjust the number of Combat Dice for each side by -1 to a minimum of 1. PBP
		# spent are used up".
		p_dice = maxi(p_dice - 1, 1)
		e_dice = maxi(e_dice - 1, 1)
		receipt.lines.append("%s: they fight again immediately, -1 Combat Die each." % name)
	# p.98: "if the army fails to win, it loses 1 Army Strength in addition to any
	# outcomes from the combat." Judged on the round that ended the combat, since a
	# refight replaces the result before it.
	if assaulting and not won_last and _as(zone, PLAYER) > 0:
		_set_as(zone, PLAYER, maxi(_as(zone, PLAYER)
			+ RulesRef.assault_option_penalty(false), 0))
		receipt.lines.append("%s: the assault failed to win, -1 Army Strength (p.98). " % name
			+ "You now have %d." % _as(zone, PLAYER))


# MARK: - Zones and regions

## Open a Zone where `attacker` strikes. `prefer_opposing` is the Step 7 AI order
## (opposing regions before neutral); the opening picks from both at random ("Target
## regions can be neutral or enemy controlled", p.94). `fixed_step7` uses Step 7's
## 2D6-highest / 1D6 instead of generating each side "normally" (p.95).
func _open_zone(map: Dictionary, attacker: String, neutral_touches_defender: bool,
		target_region_id: String, prefer_opposing: bool, fixed_step7: bool) -> Dictionary:
	var candidates: Array = attack_targets(map, attacker)
	if candidates.is_empty():
		return {}
	var rid: String = ""
	if not target_region_id.is_empty() and candidates.has(target_region_id):
		rid = target_region_id
	else:
		var pool: Array = candidates
		if prefer_opposing:
			var opposing: Array = []
			for c: String in candidates:
				if str(_region(map, c).get("owner", NEUTRAL)) == _opp(attacker):
					opposing.append(c)
			if not opposing.is_empty():
				pool = opposing
		rid = str(pool[_pick(pool.size(), "Tactics Attack Target: %s" % _who(attacker))])
	var region: Dictionary = _region(map, rid)
	var defender: String = _opp(attacker)
	var defender_touches: bool = str(region.get("owner", NEUTRAL)) == defender \
		or (str(region.get("owner", NEUTRAL)) == NEUTRAL and neutral_touches_defender)
	var seq: int = int(map.get("next_zone_seq", _array(map, "zones").size() + 1))
	map["next_zone_seq"] = seq + 1
	var zone: Dictionary = {
		"id": "z%d" % seq,
		"region_id": rid,
		"name": str(region.get("name", rid)),
		"attacker": attacker,
		"player_adjacent": true if attacker == PLAYER else defender_touches,
		"enemy_adjacent": true if attacker == ENEMY else defender_touches,
		"opened_turn": int(map.get("operational_turn", 0)),
	}
	for f: String in FACTIONS:
		var dice: int
		if fixed_step7:
			dice = 2 if f == attacker else 1
		else:
			dice = RulesRef.army_strength_dice(bool(zone[f + "_adjacent"]))
		var best: int = 0
		for d: int in _pool(dice, "Tactics Army Strength: %s, %s" % [zone.name, _who(f)]):
			best = maxi(best, d)
		zone[f + "_army_strength"] = best
	_array(map, "zones").append(zone)
	return zone


func _order_zone(map: Dictionary, faction: String, roll: int, target: String) -> Dictionary:
	var ids: Array = order_target_zones(map, faction, roll)
	if ids.is_empty():
		return {}
	if not target.is_empty() and ids.has(target):
		return _zone(map, target)
	return _zone(map, str(ids[_pick(ids.size(), "Tactics Order Target: %s" % _who(faction))]))


func _weakest_army(map: Dictionary, faction: String) -> Dictionary:
	var lowest: Array = []
	var low: int = 1 << 30
	for zone: Dictionary in _array(map, "zones"):
		var s: int = _as(zone, faction)
		if s < low:
			low = s
			lowest = [zone]
		elif s == low:
			lowest.append(zone)
	if lowest.is_empty():
		return {}
	return lowest[_pick(lowest.size(), "Tactics Weakest Army: %s" % _who(faction))]


func _zone_opened_line(zone: Dictionary) -> String:
	return "%s attack %s: Army Strength you %d, enemy %d." % [
		_who(str(zone.get("attacker", ""))), zone.get("name", ""),
		_as(zone, PLAYER), _as(zone, ENEMY)]


static func _array(map: Dictionary, key: String) -> Array:
	if not (map.get(key) is Array):
		map[key] = []
	return map[key]


static func _zone(map: Dictionary, zone_id: String) -> Dictionary:
	for zone: Variant in _array(map, "zones"):
		if zone is Dictionary and str((zone as Dictionary).get("id", "")) == zone_id:
			return zone
	return {}


static func _region(map: Dictionary, region_id: String) -> Dictionary:
	for region: Variant in _array(map, "regions"):
		if region is Dictionary and str((region as Dictionary).get("id", "")) == region_id:
			return region
	return {}


static func _as(zone: Dictionary, faction: String) -> int:
	return int(zone.get(faction + "_army_strength", 0))


static func _set_as(zone: Dictionary, faction: String, value: int) -> void:
	zone[faction + "_army_strength"] = value


## A Zone saved before adjacency was tracked counts as a border Zone for both sides.
static func _adjacent(zone: Dictionary, faction: String) -> bool:
	return bool(zone.get(faction + "_adjacent", true))


static func _opp(faction: String) -> String:
	return ENEMY if faction == PLAYER else PLAYER


static func _who(faction: String) -> String:
	return "You" if faction == PLAYER else "The enemy"


static func _receipt(title: String) -> Dictionary:
	return {"title": title, "lines": [],
		"regions_lost": {PLAYER: 0, ENEMY: 0}, "zones_won": {PLAYER: 0, ENEMY: 0}}


func _log(map: Dictionary, receipt: Dictionary) -> void:
	log_strategic_phase(map, int(map.get("operational_turn", 0)), [receipt])


# MARK: - Dice

func _d6(context: String) -> int:
	var v: int = 0
	if _scripted_mode:
		v = clampi(int(_scripted.pop_front()), 1, 6) if not _scripted.is_empty() else 1
	elif _dice != null and _dice.has_method("roll_d6"):
		v = _dice.roll_d6(context)
	else:
		v = randi_range(1, 6)
	rolls.append({"die": "1D6", "value": v, "context": context})
	return v


func _pool(count: int, context: String) -> Array:
	var out: Array = []
	for i in range(maxi(count, 1)):
		out.append(_d6("%s (%d/%d)" % [context, i + 1, maxi(count, 1)]))
	return out


## A uniform random index into `n` choices, rolled on D6s (re-rolling the faces above
## the largest multiple of n) so it passes through the forceable D6 seam.
func _pick(n: int, context: String) -> int:
	if n <= 1:
		return 0
	if n <= 6:
		for _i in range(50):
			var r: int = _d6(context)
			if r <= n:
				return r - 1
		return 0
	# More than six choices: combine two D6 as a base-6 number (0-35).
	var limit: int = 36 - (36 % n)
	for _i in range(50):
		var v: int = (_d6(context) - 1) * 6 + (_d6(context) - 1)
		if v < limit:
			return v % n
	return 0
