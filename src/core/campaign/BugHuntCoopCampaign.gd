extends RefCounted
## Bug Hunt CO-OP CAMPAIGN -- Compendium Appendices, "Co-op campaigns", printed pp.209-211.
##
## One device tracks the shared campaign: the sector map, the common pool of Support
## points and the Enemy Moves rolled at the end of every operational turn. Each player
## brings their own squad; this module knows nothing about squads.
##
## PURE AND STATIC. Every function works on the co-op Dictionary it is HANDED (the campaign
## stores it as `BugHuntCampaignCore.coop`), mutates only that, and returns a receipt
## {ok, lines, rolls, ...}. Nothing here touches a campaign core, a save or a screen. The
## core's wrappers -- start_coop_campaign(), record_coop_battle(),
## end_coop_operational_turn() -- are the callers and own the campaign-level consequences
## (modified time, the won campaign). No class_name: callers preload this file by path.
##
## The co-op Dictionary (normalize() is the one shape):
##   enabled             bool   -- absent or false means this is not a co-op campaign
##   players             Array[String]
##   sectors             Array[Dictionary]
##       {id, name, priority, factors: Array[String], stash, cleared,
##        conditions: Array[String], adjacent: Array[String]}
##   support_pool        int    -- p.211 "a common pool which any player may draw on"
##   op_turn             int    -- the operational turn in progress, from 1
##   support_penalty     int    -- p.211 Enemy sabotage!, applied to THIS operational turn
##   attacked_this_turn  Array[String] -- players who have fought this operational turn
##
## `factors` is a list, not one id: the setup table gives each sector one Factor (p.210),
## and three Enemy Moves rows then say an enemy sector "becomes" an Ambush zone,
## Obstructed or an Infiltration point (p.211). A sector keeps what it had and gains the
## new one -- see _book_notes.enemy_move_stacking in the data file.
##
## DICE. Every die goes through the DiceManager autoload with its own "Bug Hunt Co-op ..."
## context, so a QA tester can force it. Each context is a LITERAL on its roll line, which
## is what test_bug_hunt_dice_routing.gd's census looks for once the QA rows exist. No
## context is a substring of another, and none contains an existing Bug Hunt key (the
## priority dice say "Co-op Priority", never "Bug Hunt Priority").

const DATA_PATH := "res://data/bug_hunt/bug_hunt_coop_campaign.json"
## The p.187 Priority limits and the p.201 success threshold live here, not in the co-op
## file: p.210 and p.211 both point back at them ("as normal (see p.187)", "2+ Objectives").
const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"

const CITE_MAP := "Compendium p.210"
const CITE_BATTLES := "Compendium p.211"
const CITE_PRIORITY_LIMITS := "Compendium p.187"

const TARGET_ENEMY := "enemy"
const TARGET_CLEARED := "cleared"

## A rerolled duplicate Factor is the book's "one of each factor before you can duplicate
## any" (p.210). The cap only exists so a broken dice source that returns one value forever
## cannot spin the loop; seven distinct rows make it unreachable from a real die.
const MAX_FACTOR_REROLLS := 200

static var _cached_rules: Dictionary = {}
static var _cached_missions: Dictionary = {}


# ──────────────────────────────────────────────────────────────────────────────
# Data
# ──────────────────────────────────────────────────────────────────────────────

static func rules() -> Dictionary:
	if _cached_rules.is_empty():
		_cached_rules = _load_json(DATA_PATH)
	return _cached_rules


static func is_enabled(coop: Variant) -> bool:
	return coop is Dictionary and bool((coop as Dictionary).get("enabled", false))


static func factor_for_roll(roll: int) -> Dictionary:
	return _row_for(_entries(rules().get("sector_factors", {})), roll)


static func enemy_move_for_roll(roll: int) -> Dictionary:
	return _row_for(_entries(rules().get("enemy_moves", {})), roll)


static func factor_row(factor_id: String) -> Dictionary:
	for row in _entries(rules().get("sector_factors", {})):
		if str(row.get("id", "")) == factor_id:
			return row
	return {}


# ──────────────────────────────────────────────────────────────────────────────
# Setup -- The Map, p.210
# ──────────────────────────────────────────────────────────────────────────────

## p.210: "As a guideline, try 3 sectors per player for a shorter campaign, up to 5 for a
## longer campaign." Then, for each sector: "1. Roll 2D6 and pick the lower of the dice to
## establish a Priority Rating for the sector. 2. Roll D100 on the table below ... You must
## place one of each factor before you can duplicate any. 3. If the D100 roll ends in a 5
## or 0 (25, 40, 85, etc.), the sector is also home to a resource stash of 1D6 Support
## points."
##
## Returns {ok, coop, lines, rolls} or {ok: false, error}.
static func new_campaign(players: Array, sectors_per_player: int) -> Dictionary:
	var receipt := _receipt()
	var data := rules()

	var names: Array = []
	for p in players:
		var player_name := str(p).strip_edges()
		if not player_name.is_empty() and not names.has(player_name):
			names.append(player_name)
	if names.is_empty():
		return _refuse(receipt, "A co-op campaign needs at least one player (%s)." % CITE_BATTLES)

	var per_player: Dictionary = _as_dict(data.get("sectors_per_player", {}))
	var fewest: int = int(per_player.get("shorter", 0))
	var most: int = int(per_player.get("longer", 0))
	if fewest <= 0 or sectors_per_player < fewest or sectors_per_player > most:
		return _refuse(receipt, ("Pick %d-%d sectors per player: %d for a shorter campaign, "
			+ "up to %d for a longer one (%s).") % [fewest, most, fewest, most, CITE_MAP])

	var factor_rows: Array = _entries(data.get("sector_factors", {}))
	var unique_first: bool = bool(data.get("unique_factors_before_duplicates", true))
	var sectors: Array = grid_sectors(names.size() * sectors_per_player)
	var placed: Array = []
	for sector: Dictionary in sectors:
		sector["priority"] = _roll_sector_priority(data, receipt.rolls)
		var pick: Dictionary = _roll_factor(factor_rows, placed, unique_first, receipt.rolls)
		var row: Dictionary = pick.get("row", {})
		var factor_id: String = str(row.get("id", ""))
		sector["factors"] = [factor_id]
		placed.append(factor_id)
		sector["stash"] = _roll_stash(data, int(pick.get("roll", 0)), receipt.rolls)
		receipt.lines.append("%s: Priority %d, %s%s." % [
			sector.name, sector.priority, str(row.get("name", factor_id)),
			"" if int(sector.stash) == 0 else ", resource stash of %d Support points" % sector.stash])

	receipt["coop"] = {
		"enabled": true,
		"players": names,
		"sectors": sectors,
		"support_pool": 0,
		"op_turn": 1,
		"support_penalty": 0,
		"attacked_this_turn": [],
	}
	receipt["ok"] = true
	return receipt


## p.210: "a grid map will have a nice military look". The book leaves the map's shape to
## the players, so this is a LAYOUT, not a rule: a near-square grid with orthogonal
## neighbours, recorded as explicit `adjacent` ids so a map the players draw differently
## can replace it without touching any rule below. Adjacency is what Infiltration point
## and Sheltered read.
static func grid_columns(count: int) -> int:
	return maxi(1, ceili(sqrt(float(maxi(count, 1)))))


static func grid_sectors(count: int) -> Array:
	var columns: int = grid_columns(count)
	var sectors: Array = []
	for i in range(count):
		sectors.append({
			"id": "S%d" % (i + 1),
			"name": "Sector %d" % (i + 1),
			"priority": 0,
			"factors": [],
			"stash": 0,
			"cleared": false,
			"conditions": [],
			"adjacent": [],
		})
	for i in range(count):
		var row: int = floori(float(i) / float(columns))
		var col: int = i % columns
		var neighbours: Array = []
		if row > 0:
			neighbours.append(i - columns)
		if i + columns < count:
			neighbours.append(i + columns)
		if col > 0:
			neighbours.append(i - 1)
		if col + 1 < columns and i + 1 < count:
			neighbours.append(i + 1)
		neighbours.sort()
		for n: int in neighbours:
			(sectors[i]["adjacent"] as Array).append("S%d" % (n + 1))
	return sectors


static func _roll_sector_priority(data: Dictionary, rolls: Array) -> int:
	var rule: Dictionary = _as_dict(data.get("sector_priority", {}))
	if str(rule.get("dice", "")) != "2D6" or str(rule.get("keep", "")) != "lower":
		push_error("BugHuntCoopCampaign: p.210 Priority is 2D6 keep the LOWER; the data says %s"
			% str(rule))
	var die1: int = _roll_d6("Bug Hunt Co-op Priority: die 1", rolls)
	var die2: int = _roll_d6("Bug Hunt Co-op Priority: die 2", rolls)
	return mini(die1, die2)


static func _roll_factor(rows: Array, placed: Array, unique_first: bool, rolls: Array) -> Dictionary:
	var unplaced: Array = []
	for row in rows:
		var row_id: String = str(row.get("id", ""))
		if not placed.has(row_id):
			unplaced.append(row_id)
	for _attempt in range(MAX_FACTOR_REROLLS):
		var roll: int = _roll_d100("Bug Hunt Co-op Sector Factor", rolls)
		var row: Dictionary = _row_for(rows, roll)
		if row.is_empty():
			continue
		if not unique_first or unplaced.is_empty() or unplaced.has(str(row.get("id", ""))):
			return {"row": row, "roll": roll}
	push_warning("BugHuntCoopCampaign: %d Factor rolls never found an unplaced Factor -- "
		% MAX_FACTOR_REROLLS + "the dice source is stuck. Placing the first unplaced one.")
	var fallback: String = str(unplaced[0]) if not unplaced.is_empty() else ""
	return {"row": factor_row(fallback), "roll": 0}


## Step 3 is tested on the D100 that was KEPT for step 2 -- a duplicate rerolled away under
## the one-of-each rule placed nothing, so its digits place no stash either.
static func _roll_stash(data: Dictionary, factor_roll: int, rolls: Array) -> int:
	if factor_roll < 1:
		return 0
	var stash: Dictionary = _as_dict(data.get("stash", {}))
	var hit := false
	# JSON numbers are floats: compare through int(), never Array.has() on an int.
	for digit in _as_array(stash.get("d100_ends_in", [])):
		if factor_roll % 10 == int(digit):
			hit = true
	if not hit:
		return 0
	if str(stash.get("support_points", "")) != "1D6":
		push_error("BugHuntCoopCampaign: p.210 says the stash is 1D6 Support points; the data says %s"
			% str(stash.get("support_points", "")))
	return _roll_d6("Bug Hunt Co-op Resource Stash", rolls)


# ──────────────────────────────────────────────────────────────────────────────
# The Battles -- p.211
# ──────────────────────────────────────────────────────────────────────────────

## p.211: "Each player may attack one sector of their choice. As the troops are air-mobile,
## you may normally attack any sector on the map." p.210 Sheltered: "The sector cannot be
## attacked until at least one adjacent sector has been cleared."
static func can_attack(coop: Dictionary, sector_id: String, player: String = "") -> Dictionary:
	if not is_enabled(coop):
		return {"ok": false, "reason": "This is not a co-op campaign."}
	var sector: Dictionary = _sector(coop, sector_id)
	if sector.is_empty():
		return {"ok": false, "reason": "There is no sector %s on the map." % sector_id}
	if bool(sector.get("cleared", false)):
		return {"ok": false, "reason": "%s is already cleared." % str(sector.get("name", sector_id))}
	if not player.is_empty():
		if not _as_array(coop.get("players", [])).has(player):
			return {"ok": false, "reason": "%s is not a player in this campaign." % player}
		if _as_array(coop.get("attacked_this_turn", [])).has(player):
			return {"ok": false, "reason": ("%s has already attacked this operational turn -- each "
				+ "player may attack one sector (%s).") % [player, CITE_BATTLES]}
	for factor_id in _as_array(sector.get("factors", [])):
		var row: Dictionary = factor_row(str(factor_id))
		if bool(row.get("requires_adjacent_cleared", false)) and not _any_adjacent_cleared(coop, sector):
			return {"ok": false, "reason": ("%s is %s: it cannot be attacked until at least one "
				+ "adjacent sector has been cleared (%s).") % [
					str(sector.get("name", sector_id)), str(row.get("name", factor_id)), CITE_MAP]}
	return {"ok": true, "reason": ""}


## p.211: "If the mission is a victory (2+ Objectives completed), clear the sector from the
## map, and claim 1 Support point worth of resources (in addition to the +5 if a Resource
## stash was present). If the mission failed, the sector remains under enemy control."
##
## `battle_result` is BugHuntBattleResultNormalizer's output; only `objectives_completed`
## (the weighted count) is read. The stash pays its ROLLED 1D6 -- see _book_notes.
static func apply_battle_result(coop: Dictionary, player: String, sector_id: String,
		battle_result: Dictionary) -> Dictionary:
	var receipt := _receipt()
	receipt.merge({"victory": false, "support_awarded": 0, "stash_paid": 0,
		"campaign_won": false, "sector_id": sector_id})
	if player.is_empty():
		return _refuse(receipt, "Name the player whose squad fought (%s)." % CITE_BATTLES)
	var check: Dictionary = can_attack(coop, sector_id, player)
	if not bool(check.get("ok", false)):
		return _refuse(receipt, str(check.get("reason", "")))

	var sector: Dictionary = _sector(coop, sector_id)
	var objectives: int = int(battle_result.get("objectives_completed", 0))
	var victory: bool = objectives >= _success_threshold()
	var attacked: Array = _as_array(coop.get("attacked_this_turn", [])).duplicate()
	attacked.append(player)
	coop["attacked_this_turn"] = attacked
	receipt["victory"] = victory

	if not victory:
		receipt.lines.append("%s: %d Objective(s) -- the mission failed and the sector remains under enemy control (%s)."
			% [str(sector.get("name", sector_id)), objectives, CITE_BATTLES])
	else:
		var award: int = int(rules().get("victory_support_points", 0))
		var stash: int = int(sector.get("stash", 0))
		sector["cleared"] = true
		sector["stash"] = 0
		# The forces that held it are gone. Its Factors describe the ground and stay with
		# it, in case an Enemy assault takes it back.
		sector["conditions"] = []
		coop["support_pool"] = int(coop.get("support_pool", 0)) + award + stash
		receipt["support_awarded"] = award
		receipt["stash_paid"] = stash
		receipt.lines.append("%s cleared with %d Objective(s): +%d Support point%s%s to the common pool (%s)."
			% [str(sector.get("name", sector_id)), objectives, award, "" if award == 1 else "s",
				"" if stash == 0 else ", plus the resource stash of %d" % stash, CITE_BATTLES])

	receipt["campaign_won"] = is_campaign_won(coop)
	if bool(receipt.campaign_won):
		receipt.lines.append("Every sector is cleared -- the co-op campaign is won (%s)." % CITE_MAP)
	receipt["ok"] = true
	return receipt


## p.211: "Simply add any desired points to the Support that would normally be available
## ... Points remain until they are used." Returns how many were actually drawn.
static func draw_support(coop: Dictionary, amount: int) -> int:
	if not is_enabled(coop) or amount <= 0:
		return 0
	var pool: int = int(coop.get("support_pool", 0))
	var drawn: int = mini(amount, pool)
	coop["support_pool"] = pool - drawn
	return drawn


## Everything a co-op mission's setup needs from the map, for the mission panel to apply:
## the sector's Priority ("Set up the mission as normal, using the Priority level from the
## sector map", p.211), this turn's Sabotage penalty, and the battle-side values of every
## Factor and Enemy Moves condition on the sector, merged into one `battle` Dictionary.
static func battle_modifiers(coop: Dictionary, sector_id: String) -> Dictionary:
	var sector: Dictionary = _sector(coop, sector_id)
	if sector.is_empty():
		return {}
	var battle: Dictionary = {}
	var factors: Array = []
	for factor_id in _as_array(sector.get("factors", [])):
		var row: Dictionary = factor_row(str(factor_id))
		factors.append({"id": str(factor_id), "name": str(row.get("name", factor_id)),
			"effect": str(row.get("effect", ""))})
		battle.merge(_whole_numbers(_as_dict(row.get("battle", {}))), true)
	var conditions: Array = []
	for condition_id in _as_array(sector.get("conditions", [])):
		var move: Dictionary = _move_for_condition(str(condition_id))
		conditions.append({"id": str(condition_id), "name": str(move.get("condition_name", condition_id)),
			"effect": str(move.get("effect", ""))})
		battle.merge(_whole_numbers(_as_dict(move.get("battle", {}))), true)
	return {
		"sector_id": str(sector.get("id", "")),
		"sector_name": str(sector.get("name", "")),
		"priority": int(sector.get("priority", 0)),
		"support_penalty": int(coop.get("support_penalty", 0)),
		"support_pool": int(coop.get("support_pool", 0)),
		"factors": factors,
		"conditions": conditions,
		"battle": battle,
		"cite": CITE_BATTLES,
	}


## p.210: "Operational turns continue until all sectors have been cleared of enemies and all
## Lairs have been destroyed." No page defines a Lair (see _book_notes.lairs_undefined).
static func is_campaign_won(coop: Variant) -> bool:
	if not is_enabled(coop):
		return false
	var sectors: Array = _as_array((coop as Dictionary).get("sectors", []))
	if sectors.is_empty():
		return false
	for sector in sectors:
		if not (sector is Dictionary) or not bool(sector.get("cleared", false)):
			return false
	return true


# ──────────────────────────────────────────────────────────────────────────────
# The end of an operational turn -- Infiltration points (p.210), Enemy Moves (p.211)
# ──────────────────────────────────────────────────────────────────────────────

## p.210: "During an operational turn, each player will carry out a mission, followed by a
## roll for Enemy Moves. Note that the normal Operational Progress table is not used."
## p.211: "At the end of each operational turn, the enemy will carry out their actions. Each
## player rolls on the table and applies the results to the map."
##
## Order inside the end phase (the book gives none): a campaign already won rolls nothing;
## Sabotage from the PREVIOUS end phase expires; existing Infiltration points act; then one
## Enemy Moves roll per player. A point created by this end phase first acts at the next.
static func end_operational_turn(coop: Dictionary) -> Dictionary:
	var receipt := _receipt()
	receipt.merge({"moves": [], "infiltrations": [], "campaign_won": false, "op_turn": 0})
	if not is_enabled(coop):
		return _refuse(receipt, "This is not a co-op campaign.")
	var turn: int = int(coop.get("op_turn", 1))
	receipt["op_turn"] = turn

	if is_campaign_won(coop):
		receipt["campaign_won"] = true
		receipt["ok"] = true
		receipt.lines.append("Every sector is cleared -- the co-op campaign is won (%s). No Enemy Moves are rolled."
			% CITE_MAP)
		return receipt

	# "During the next operational turn" -- the penalty rolled one end phase ago has now
	# been fought through. This end phase's Sabotage results add to the fresh count.
	coop["support_penalty"] = 0
	_resolve_infiltration(coop, receipt)
	for player in _as_array(coop.get("players", [])):
		var roll: int = _roll_d100("Bug Hunt Co-op Enemy Move: %s" % str(player), receipt.rolls)
		_apply_enemy_move(coop, str(player), roll, receipt)

	coop["attacked_this_turn"] = []
	coop["op_turn"] = turn + 1
	receipt["op_turn"] = turn + 1
	receipt["campaign_won"] = is_campaign_won(coop)
	receipt["ok"] = true
	return receipt


static func _resolve_infiltration(coop: Dictionary, receipt: Dictionary) -> void:
	for sector in _as_array(coop.get("sectors", [])):
		if not (sector is Dictionary) or bool(sector.get("cleared", false)):
			continue
		var increase: int = 0
		for factor_id in _as_array(sector.get("factors", [])):
			increase += int(factor_row(str(factor_id)).get("adjacent_priority_increase", 0))
		if increase <= 0:
			continue
		var adjacent: Array = []
		for adjacent_id in _as_array(sector.get("adjacent", [])):
			var neighbour: Dictionary = _sector(coop, str(adjacent_id))
			if not neighbour.is_empty():
				adjacent.append(neighbour)
		if adjacent.is_empty():
			receipt.lines.append("%s is an Infiltration point with no adjacent sector -- no effect."
				% str(sector.get("name", "")))
			continue
		var target: Dictionary = adjacent[0]
		if adjacent.size() > 1:
			var pick_roll: int = _roll_d100("Bug Hunt Co-op Infiltration", receipt.rolls)
			target = adjacent[(pick_roll - 1) % adjacent.size()]
		var before: int = int(target.get("priority", 0))
		target["priority"] = _clamp_priority(before + increase)
		(receipt.infiltrations as Array).append({"from": str(sector.get("id", "")),
			"sector_id": str(target.get("id", "")), "before": before, "after": int(target.priority)})
		receipt.lines.append("Infiltration point %s: %s Priority %d -> %d (%s)." % [
			str(sector.get("name", "")), str(target.get("name", "")), before,
			int(target.priority), CITE_MAP])


static func _apply_enemy_move(coop: Dictionary, player: String, roll: int, receipt: Dictionary) -> void:
	var row: Dictionary = enemy_move_for_roll(roll)
	var move := {"player": player, "roll": roll, "id": str(row.get("id", "")),
		"name": str(row.get("name", "")), "sector_id": "", "applied": false}
	(receipt.moves as Array).append(move)
	if row.is_empty():
		receipt.lines.append("%s rolled %d on Enemy Moves -- no table row matched." % [player, roll])
		return

	var target: String = str(row.get("target", ""))
	var sector: Dictionary = {}
	if target == TARGET_ENEMY or target == TARGET_CLEARED:
		var pool: Array = _sectors_where(coop, target == TARGET_CLEARED)
		if pool.is_empty():
			receipt.lines.append("%s rolled %d: %s -- there is no %s sector, so it has no effect (%s)."
				% [player, roll, move.name, "cleared" if target == TARGET_CLEARED else "enemy",
					CITE_BATTLES])
			return
		sector = pool[0]
		if pool.size() > 1:
			var pick_roll: int = _roll_d100("Bug Hunt Co-op Target Sector", receipt.rolls)
			sector = pool[(pick_roll - 1) % pool.size()]
		move["sector_id"] = str(sector.get("id", ""))

	var detail: String = ""
	if row.has("set_priority"):
		# Enemy assault: "A cleared sector falls to the enemy. Priority level 3."
		sector["cleared"] = false
		sector["priority"] = _clamp_priority(int(row.get("set_priority", 0)))
		detail = "%s falls to the enemy at Priority %d" % [str(sector.get("name", "")), int(sector.priority)]
	if row.has("add_factor"):
		var factor_id: String = str(row.get("add_factor", ""))
		var factors: Array = _as_array(sector.get("factors", []))
		var added: bool = not factors.has(factor_id)
		if added:
			factors.append(factor_id)
			sector["factors"] = factors
		detail = "%s %s %s" % [str(sector.get("name", "")),
			"becomes" if added else "is already", str(factor_row(factor_id).get("name", factor_id))]
	if row.has("add_condition"):
		var condition_id: String = str(row.get("add_condition", ""))
		var conditions: Array = _as_array(sector.get("conditions", []))
		var gained: bool = not conditions.has(condition_id)
		if gained:
			conditions.append(condition_id)
			sector["conditions"] = conditions
		detail = "%s: %s%s" % [str(sector.get("name", "")), str(row.get("condition_name", condition_id)),
			"" if gained else " (already)"]
	if row.has("priority_increase"):
		var before: int = int(sector.get("priority", 0))
		sector["priority"] = _clamp_priority(before + int(row.get("priority_increase", 0)))
		detail = "%s Priority %d -> %d" % [str(sector.get("name", "")), before, int(sector.priority)]
	if row.has("next_turn_support_penalty"):
		var penalty: int = int(row.get("next_turn_support_penalty", 0))
		coop["support_penalty"] = int(coop.get("support_penalty", 0)) + penalty
		detail = "every battle next operational turn has -%d Support point" % int(coop.support_penalty)
	if row.has("support_reserve_loss"):
		if str(row.get("support_reserve_loss", "")) != "1D3":
			push_error("BugHuntCoopCampaign: p.211 Wastage is -1D3; the data says %s"
				% str(row.get("support_reserve_loss", "")))
		var loss: int = _roll_d3("Bug Hunt Co-op Wastage", receipt.rolls)
		var pool_before: int = int(coop.get("support_pool", 0))
		# A pool of points cannot hold fewer than none.
		coop["support_pool"] = maxi(pool_before - loss, 0)
		detail = "rolled %d: the common pool falls %d -> %d" % [loss, pool_before, int(coop.support_pool)]

	move["applied"] = true
	receipt.lines.append("%s rolled %d: %s -- %s (%s)." % [player, roll, move.name, detail, CITE_BATTLES])


# ──────────────────────────────────────────────────────────────────────────────
# Persistence shape
# ──────────────────────────────────────────────────────────────────────────────

## The ONE shape of a co-op Dictionary, rebuilt from whatever was loaded. A save carries
## every number back as a JSON float, and a float Priority prints "3.0" (T11-33), so every
## count is coerced here rather than at each reader. Anything not a Dictionary -- and the
## absent key of every save written before co-op existed -- is {}: not a co-op campaign.
static func normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var source: Dictionary = raw
	var sectors: Array = []
	for s in _as_array(source.get("sectors", [])):
		if not (s is Dictionary):
			continue
		sectors.append({
			"id": str(s.get("id", "")),
			"name": str(s.get("name", "")),
			"priority": int(s.get("priority", 0)),
			"factors": _strings(s.get("factors", [])),
			"stash": int(s.get("stash", 0)),
			"cleared": bool(s.get("cleared", false)),
			"conditions": _strings(s.get("conditions", [])),
			"adjacent": _strings(s.get("adjacent", [])),
		})
	return {
		"enabled": bool(source.get("enabled", false)),
		"players": _strings(source.get("players", [])),
		"sectors": sectors,
		"support_pool": int(source.get("support_pool", 0)),
		"op_turn": int(source.get("op_turn", 1)),
		"support_penalty": int(source.get("support_penalty", 0)),
		"attacked_this_turn": _strings(source.get("attacked_this_turn", [])),
	}


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

static func _sector(coop: Dictionary, sector_id: String) -> Dictionary:
	for sector in _as_array(coop.get("sectors", [])):
		if sector is Dictionary and str(sector.get("id", "")) == sector_id:
			return sector
	return {}


static func _sectors_where(coop: Dictionary, cleared: bool) -> Array:
	var out: Array = []
	for sector in _as_array(coop.get("sectors", [])):
		if sector is Dictionary and bool(sector.get("cleared", false)) == cleared:
			out.append(sector)
	return out


static func _any_adjacent_cleared(coop: Dictionary, sector: Dictionary) -> bool:
	for adjacent_id in _as_array(sector.get("adjacent", [])):
		if bool(_sector(coop, str(adjacent_id)).get("cleared", false)):
			return true
	return false


static func _move_for_condition(condition_id: String) -> Dictionary:
	for row in _entries(rules().get("enemy_moves", {})):
		if str(row.get("add_condition", "")) == condition_id:
			return row
	return {}


## p.187: "Regardless of points spent or modifiers, Priority cannot be reduced below 1 or
## raised above 6." p.210's Infiltration point repeats the cap ("to a maximum of 6").
static func _clamp_priority(value: int) -> int:
	var limits: Dictionary = _as_dict(_missions().get("priority", {}))
	if not limits.has("min") or not limits.has("max"):
		push_error("BugHuntCoopCampaign: bug_hunt_missions.json priority has no min/max (%s)"
			% CITE_PRIORITY_LIMITS)
		return value
	return clampi(value, int(limits.get("min", 1)), int(limits.get("max", 6)))


## p.211 "2+ Objectives completed" is the p.201 success threshold.
static func _success_threshold() -> int:
	var scoring: Dictionary = _as_dict(_as_dict(_missions().get("objectives", {})).get("scoring", {}))
	if not scoring.has("success_threshold"):
		push_error("BugHuntCoopCampaign: bug_hunt_missions.json objectives.scoring has no success_threshold")
	return int(scoring.get("success_threshold", 2))


static func _row_for(rows: Array, roll: int) -> Dictionary:
	for row in rows:
		var bounds: Variant = row.get("d100_range", [])
		if bounds is Array and (bounds as Array).size() >= 2 \
				and roll >= int(bounds[0]) and roll <= int(bounds[1]):
			return row
	return {}


static func _entries(section: Variant) -> Array:
	var out: Array = []
	for row in _as_array(_as_dict(section).get("entries", [])):
		if row is Dictionary:
			out.append(row)
	return out


## JSON hands back 8.0 for 8; a battle value that is a whole number is an int.
static func _whole_numbers(values: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in values:
		var v: Variant = values[key]
		out[key] = int(v) if v is float and is_equal_approx(v, roundf(v)) else v
	return out


static func _receipt() -> Dictionary:
	return {"ok": false, "error": "", "lines": [], "rolls": []}


static func _refuse(receipt: Dictionary, reason: String) -> Dictionary:
	receipt["ok"] = false
	receipt["error"] = reason
	return receipt


static func _as_array(value: Variant) -> Array:
	return value if value is Array else []


static func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _strings(value: Variant) -> Array:
	var out: Array = []
	for v in _as_array(value):
		out.append(str(v))
	return out


static func _missions() -> Dictionary:
	if _cached_missions.is_empty():
		_cached_missions = _load_json(MISSIONS_PATH)
	return _cached_missions


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("BugHuntCoopCampaign: missing data file %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


# ── Dice: the DiceManager autoload when one is reachable, so QA can force any table.
# This module is static and never in the tree, so the autoload is reached through the main
# loop; a bare get_node_or_null("/root/...") would ERROR here rather than return null.

static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null("/root/DiceManager")
	return null


static func _roll_d3(context: String, rolls: Array) -> int:
	var dm: Node = _dice()
	var value: int = int(dm.roll_d3(context)) if dm != null and dm.has_method("roll_d3") \
		else randi_range(1, 3)
	rolls.append({"die": "1D3", "value": value, "context": context})
	return value


static func _roll_d6(context: String, rolls: Array) -> int:
	var dm: Node = _dice()
	var value: int = int(dm.roll_d6(context)) if dm != null and dm.has_method("roll_d6") \
		else randi_range(1, 6)
	rolls.append({"die": "1D6", "value": value, "context": context})
	return value


static func _roll_d100(context: String, rolls: Array) -> int:
	var dm: Node = _dice()
	var value: int = int(dm.roll_d100(context)) if dm != null and dm.has_method("roll_d100") \
		else randi_range(1, 100)
	rolls.append({"die": "1D100", "value": value, "context": context})
	return value
