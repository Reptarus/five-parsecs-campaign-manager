class_name TacticsOperationalRules
extends RefCounted

## Tactics Operational System — the RULES half. Source: Tactics **pp.95-99**.
##
## Every number here is read from `data/tactics/tactics_campaign_config.json`, which
## carries its own page cites. Nothing is hardcoded in this file: the constants that
## used to live at TacticsOperationalMap.gd:34-36 and were re-hardcoded a second time
## at TacticsCreationCoordinator.gd:230-232 now have one home, which is the project's
## standing "one value, one home" rule.
##
## ⚠ CITE: the source text marks the RAW page in `=== PAGE N ===` and prints the FOLIO
## on the next line — offset raw-2, confirmed at raw PAGE 94 -> printed 92
## "THE OPERATIONAL SYSTEM". Applying another book's offset here lands 63 pages out, in
## the Lifeforms bestiary, which is exactly how this chapter came to be miscited in four
## separate files.
##
## ⭐ The outcome table and the dice TALLY are deliberately split from the ROLLING, so a
## test can assert the book's table directly without fighting an RNG:
##   classify_combat_outcome(player_rolls, enemy_rolls)  <- pure, no randomness
##   resolve_operational_combat(...)                     <- rolls, then calls the above
##
## Usage:
##   var pbp := TacticsOperationalRules.award_battle_points(2, 1, 0)
##   var dice := TacticsOperationalRules.combat_dice(my_as, their_as, pbp_spent, false)
##   var res  := TacticsOperationalRules.classify_combat_outcome([6, 6, 3], [5, 2])

const _CONFIG_PATH := "res://data/tactics/tactics_campaign_config.json"

static var _data: Dictionary = {}
static var _data_loaded: bool = false

# MARK: - Data Loading

static func _load_data() -> void:
	if _data_loaded:
		return
	var file := FileAccess.open(_CONFIG_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			_data = json.data
	_data_loaded = true


static func _get_data() -> Dictionary:
	if not _data_loaded:
		_load_data()
	return _data


## The `operational_system` block. Empty if the config is missing — every caller below
## falls back to the book value it would have read, so a missing file degrades to the
## printed rule rather than to zero.
static func _system() -> Dictionary:
	var d := _get_data()
	var s: Variant = d.get("operational_system", {})
	return s if s is Dictionary else {}


static func _section(name: String) -> Dictionary:
	var s: Variant = _system().get(name, {})
	return s if s is Dictionary else {}


# MARK: - Starting values (p.93)

## "If in doubt, begin Cohesion at 5 for each side." Cohesion is a pacing control, so a
## campaign may legitimately start elsewhere; this is the default, not a constraint.
static func starting_values() -> Dictionary:
	var d := _get_data()
	var sv: Variant = d.get("starting_values", {})
	if not (sv is Dictionary):
		return {"player_cohesion": 5, "enemy_cohesion": 5, "player_battle_points": 0}
	var out: Dictionary = (sv as Dictionary).duplicate(true)
	out.erase("_source_note")
	return out


# MARK: - Step 2 — Player Battle Points (p.96)

## Award PBP for one Zone's tabletop battles this operational turn.
##
## The book, verbatim in effect: 1 PBP per victory, 0 for a draw or an inconclusive
## battle, both sides' points cancel 1-for-1 in the same Zone, an army cannot GAIN more
## than 2 in a turn, cannot HOLD more than 3, and excess is discarded with no effect.
##
## ⚠ Both caps are real book values and neither existed anywhere in the code before
## 2026-09-07 — `add_battle_point()` incremented without limit and nothing called it.
## Returns {"awarded", "total", "discarded"} so a caller can report what was lost.
static func award_battle_points(
		player_wins: int, enemy_wins: int, saved_pbp: int = 0) -> Dictionary:
	var cfg := _section("player_battle_points")
	var per_win: int = int(cfg.get("award_per_victory", 1))
	var max_turn: int = int(cfg.get("max_gain_per_operational_turn", 2))
	var max_saved: int = int(cfg.get("max_saved_total", 3))

	# Cancel 1-for-1 in the same Zone before any cap is applied.
	var net_wins: int = maxi(player_wins - enemy_wins, 0)
	var gross: int = net_wins * per_win
	var awarded: int = mini(gross, max_turn)
	var total: int = mini(saved_pbp + awarded, max_saved)
	return {
		"awarded": awarded,
		"total": total,
		"discarded": (gross - awarded) + maxi(saved_pbp + awarded - max_saved, 0),
	}


## The two p.96 caps, exposed separately because they bind in different places: the
## per-turn cap belongs to the awarding step (which sees every battle in the turn), the
## saved cap belongs to the field that holds the points.
static func max_battle_points_per_turn() -> int:
	return int(_section("player_battle_points").get(
		"max_gain_per_operational_turn", 2))


static func max_saved_battle_points() -> int:
	return int(_section("player_battle_points").get("max_saved_total", 3))


# MARK: - Step 3 — Operational Combat (p.97)

## Tally Combat Dice for one side. Each faction begins with 1; +1 if the enemy is not
## adjacent to their own territory; +1 if this side's Army Strength is 2+ higher; +1 per
## PBP spent. `extra` carries the book's open-ended "various factors ... the GM may also
## add dice as desired", including the p.98 same-Zone +1 when two sides attack at once.
static func combat_dice(
		own_army_strength: int,
		enemy_army_strength: int,
		pbp_spent: int = 0,
		enemy_not_adjacent_to_own_territory: bool = false,
		extra: int = 0) -> int:
	var cfg := _section("operational_combat")
	var dice: int = int(cfg.get("base_combat_dice", 1))
	if enemy_not_adjacent_to_own_territory:
		dice += int(cfg.get("bonus_enemy_not_adjacent_to_own_territory", 1))
	var threshold: int = int(cfg.get("army_strength_advantage_threshold", 2))
	if own_army_strength - enemy_army_strength >= threshold:
		dice += int(cfg.get("bonus_for_army_strength_advantage", 1))
	dice += maxi(pbp_spent, 0) * int(cfg.get("combat_dice_per_pbp_spent", 1))
	return maxi(dice + extra, 1)


## Classify one exchange from two already-rolled dice pools. PURE — no randomness.
##
## ⚠ The rows are consulted IN ORDER and only the FIRST match is used; the book says so
## explicitly, and a roll routinely satisfies several. Encoding this as an if/elif chain
## in the printed order is the whole point — a `match` on some derived key would lose it.
##
## Returns {"id", "outcome", "player_delta", "enemy_delta", "refight", "dice_adjust"}.
static func classify_combat_outcome(
		player_rolls: Array, enemy_rolls: Array) -> Dictionary:
	var p_six: int = _count_sixes(player_rolls)
	var e_six: int = _count_sixes(enemy_rolls)
	var p_max: int = _highest(player_rolls)
	var e_max: int = _highest(enemy_rolls)

	# Row 1 — both sides rolled two or more 6s.
	if p_six >= 2 and e_six >= 2:
		return _outcome("both_multiple_sixes", "A devastating major battle",
			-1, -1, true, -1)

	# Row 2 — only one side rolled two or more 6s.
	if p_six >= 2 or e_six >= 2:
		var player_won: bool = p_six >= 2
		# "fight again immediately" only if the winner now has the higher Army Strength,
		# which the caller knows and this pure function does not — so it reports the
		# conditional and lets resolve_operational_combat() decide.
		return _outcome("one_multiple_sixes", "A grand tactical success",
			1 if player_won else -1, -1 if player_won else 1, true, -1)

	# Row 3 — one side's highest single die beats every die the opponent rolled.
	if p_max != e_max:
		var p_ahead: bool = p_max > e_max
		return _outcome("single_high_die", "One side gains the upper hand",
			0 if p_ahead else -1, -1 if p_ahead else 0, false, 0)

	# Row 4 — tied highest die, and it is a 5 or a 6.
	if p_max >= 5:
		return _outcome("tie_high", "Brutal attrition fighting", -1, -1, false, 0)

	# Row 5 — tied highest die of 1-4.
	return _outcome("tie_low", "Inconclusive fighting", 0, 0, false, 0)


static func _outcome(id: String, text: String, p_delta: int, e_delta: int,
		refight: bool, dice_adjust: int) -> Dictionary:
	return {
		"id": id,
		"outcome": text,
		"player_delta": p_delta,
		"enemy_delta": e_delta,
		"refight": refight,
		"dice_adjust": dice_adjust,
	}


static func _count_sixes(rolls: Array) -> int:
	var n: int = 0
	for r in rolls:
		if int(r) == 6:
			n += 1
	return n


static func _highest(rolls: Array) -> int:
	var best: int = 0
	for r in rolls:
		best = maxi(best, int(r))
	return best


## Roll both pools and classify. `rng` is required so a test can seed it — every random
## call in this file takes one rather than touching a global.
static func resolve_operational_combat(
		player_dice: int, enemy_dice: int, rng: RandomNumberGenerator) -> Dictionary:
	var p_rolls: Array = _roll_pool(player_dice, rng)
	var e_rolls: Array = _roll_pool(enemy_dice, rng)
	var result: Dictionary = classify_combat_outcome(p_rolls, e_rolls)
	result["player_rolls"] = p_rolls
	result["enemy_rolls"] = e_rolls
	return result


static func _roll_pool(count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for _i in range(maxi(count, 1)):
		out.append(rng.randi_range(1, 6))
	return out


## p.98 Assault Option — an army 1 point stronger may add a die, but loses 1 Army
## Strength on top of the combat result if it does not win.
static func assault_option_penalty(won: bool) -> int:
	if won:
		return 0
	var cfg: Variant = _section("operational_combat").get("assault_option", {})
	var d: Dictionary = cfg if cfg is Dictionary else {}
	return -int(d.get("army_strength_penalty_if_not_won", 1))


# MARK: - Step 4 — Operational Orders (p.98)

static func operational_orders_table() -> Array:
	var cfg := _section("operational_orders")
	var t: Variant = cfg.get("table", [])
	return t if t is Array else []


## Roll 1D6 on the Operational Orders table. Returns the matching row, or {} if the
## table could not be read — never a fabricated order.
static func roll_operational_order(rng: RandomNumberGenerator) -> Dictionary:
	var roll: int = rng.randi_range(1, 6)
	return operational_order_for(roll)


static func operational_order_for(roll: int) -> Dictionary:
	for row in operational_orders_table():
		if row is Dictionary and int((row as Dictionary).get("roll", -1)) == roll:
			var out: Dictionary = (row as Dictionary).duplicate(true)
			out["rolled"] = roll
			return out
	return {}


# MARK: - Step 5 — Commando Raids (p.99)

## Commit PBP against a region: roll 1D6 per point. Any 1-2 loses ALL committed points
## for that region; every 6 costs the target 1 Army Strength, and that damage lands even
## when the points are lost. Anything else does nothing.
##
## Returns {"rolls", "pbp_lost", "army_strength_damage"}.
static func resolve_commando_raid(
		pbp_committed: int, rng: RandomNumberGenerator) -> Dictionary:
	var cfg := _section("commando_raids")
	var loss_range: Variant = cfg.get("all_committed_pbp_lost_on_any_roll_in", [1, 2])
	var losing: Array = loss_range if loss_range is Array else [1, 2]
	var damage_on: int = int(cfg.get("army_strength_damage_per_roll_of", 6))
	var damage_each: int = int(cfg.get("army_strength_damage_amount", 1))

	var rolls: Array = []
	var lost: bool = false
	var damage: int = 0
	for _i in range(maxi(pbp_committed, 0)):
		var r: int = rng.randi_range(1, 6)
		rolls.append(r)
		if _in_range(r, losing):
			lost = true
		if r == damage_on:
			damage += damage_each
	return {
		"rolls": rolls,
		"pbp_lost": pbp_committed if lost else 0,
		"army_strength_damage": damage,
	}


static func _in_range(value: int, bounds: Array) -> bool:
	if bounds.size() == 2:
		return value >= int(bounds[0]) and value <= int(bounds[1])
	return bounds.has(value)


# MARK: - Army Strength (p.95) and new Zones (p.99)

## "If the Zone is in or adjacent to friendly territory, roll two D6s and pick the
## highest die. If the Zone is not connected directly to friendly territory, roll one."
static func generate_army_strength(
		connected_to_friendly_territory: bool, rng: RandomNumberGenerator) -> int:
	if connected_to_friendly_territory:
		return maxi(rng.randi_range(1, 6), rng.randi_range(1, 6))
	return rng.randi_range(1, 6)


# MARK: - Step 9 — Cohesion (p.99)

## ⚠ Step 9 is ABSENT from the book's own 8-step summary list on p.96 and present as a
## section on p.99. It is the campaign's end condition, so a turn loop built from that
## summary list alone can never finish — which is what happened here.
static func cohesion_after_region_loss(current_cohesion: int, regions_lost: int = 1) -> int:
	var cfg := _section("cohesion")
	var per: int = int(cfg.get("loss_per_region_lost", 1))
	return maxi(current_cohesion - (per * maxi(regions_lost, 0)), 0)


static func is_faction_defeated(cohesion: int) -> bool:
	var cfg := _section("cohesion")
	return cohesion <= int(cfg.get("defeated_at", 0))


## The campaign is won when only one faction remains; if every remaining faction hits 0
## together the war is inconclusive, "with both sides completely exhausted".
## Returns "player", "enemy", "inconclusive", or "" while the war continues.
static func campaign_result(player_cohesion: int, enemy_cohesion: int) -> String:
	var p_out: bool = is_faction_defeated(player_cohesion)
	var e_out: bool = is_faction_defeated(enemy_cohesion)
	if p_out and e_out:
		return "inconclusive"
	if e_out:
		return "player"
	if p_out:
		return "enemy"
	return ""


# MARK: - The nine steps, for any surface that lists them

## ⚠ Read this rather than retyping the list. The panel used to hardcode eight steps
## whose wording drifted from the book's own section headings, and omitted Step 9.
static func turn_steps() -> Array:
	var d := _get_data()
	var s: Variant = d.get("operational_turn_steps", [])
	return s if s is Array else []
