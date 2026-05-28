extends RefCounted

## No-Minis Combat auto-resolver (Compendium pp.66-73; ruleset in
## data/compendium/no_minis_combat.json). The standalone "play it out for me"
## engine: it drives the book-faithful No-Minis round STRUCTURE while delegating
## every per-shot dice roll to BattleCalculations (the same math the standard
## resolver uses). It is the bridge between the two faithful halves the codebase
## already had — CompendiumNoMinisCombat (structure, text-only) and
## BattleResolver (automated math, non-canonical structure). See
## docs/sop/decision-log.md (2026-05) and docs/COMBAT_SIMULATION_MODES_RESEARCH.md.
##
## NO class_name on purpose: callers preload by path
## (const NoMinisResolverClass = preload("res://src/core/battle/NoMinisResolver.gd"))
## which sidesteps the .uid/class_name runtime trap for editor-external files.
##
## ── Scope of the first cut (recorded in decision-log so it is NOT a silent cut) ──
## FAITHFUL (outcome-determining):
##   • Round phases: (Battle Flow Events, optional/off) → Initiative → Firefight → Morale (Compendium p.66)
##   • Initiative: roll (crew_size − 1) dice; Captain + (die ≤ Reactions) get one Initiative Action (Compendium p.67)
##   • Firefight: select 3 enemies (4 if 7+ alive); random crew target; longer-range fires first + return fire;
##     melee-only/mixed Brawl; both in Cover; max range; max Shots; fire once/round; Area & Terrifying ignored (Compendium pp.69-70)
##   • Morale: at round end, roll 1D6 per enemy COMBAT casualty this round; each die ≤ Bail Range → one enemy Bails;
##     regulars removed before specialists; Fearless never bail (Core Rules p.114; Compendium p.72)
## ABSTRACTED (player-decision tiers with no auto-resolve analog — already exist in the companion engine):
##   • The positional Initiative Actions (Scout / Move Up / Carry Out Task / Support / Take Cover / Keep Distance)
##     and Locations/objectives. The auto-resolver performs only the OFFENSIVE actions (Optimal Shot / Charge),
##     chosen by loadout — it does NOT invent a tactical AI for positioning.
##   • Voluntary crew Retreat (Compendium p.72) — the mechanic exists (_attempt_crew_retreat) but is opt-in via
##     options; auto-resolve fights to a conclusion by default, which is rules-legal (retreat is "you MAY").
##   • Optional Battle Flow Events D100 table — off by default (it is an "additional optional rule").
##
## Returns the SAME result Dictionary shape as BattleResolver.resolve_battle(), so it is a drop-in
## for the combat_mode == "no_minis" routing in BattlePhase / TacticalBattleUI.

const BattleResolverRef = preload("res://src/core/battle/BattleResolver.gd")

# Safety cap — No-Minis battles end on elimination/bail; this only guards runaway loops.
const SAFETY_MAX_ROUNDS := 50

# Firefight enemy selection (Compendium p.69)
const FIREFIGHT_BASE_SELECT := 3
const FIREFIGHT_HIGH_SELECT := 4
const FIREFIGHT_HIGH_THRESHOLD := 7  # 4 enemies engage if 7+ are on the field

# Battlefield Test target numbers (2D6 ≥ N) for the offensive actions (Compendium p.68)
const OPTIMAL_SHOT_TARGET := 7  # -1 to the roll if firing a Heavy weapon
const CHARGE_TARGET := 6        # +1 if Speed 5"+
const SPEED_BONUS_THRESHOLD := 5

# No-Minis fixed engagement ranges (Compendium p.70)
const MELEE_DEFENSE_RANGE := 6.0  # melee-only opponent is shot at 6" first, counting as Cover
const DEFAULT_RANGED_RANGE := 24  # fallback weapon range when a unit carries no structured weapon dict
const MELEE_RANGE_MAX := 2        # a weapon at/under this range is treated as melee
const MAX_SHOTS_CAP := 4          # guard against malformed "shots" data

# Traits ignored entirely in No-Minis combat (Compendium p.70)
const IGNORED_TRAITS := ["area", "terrifying"]


## Main entry point. Signature mirrors BattleResolver.resolve_battle() plus an
## optional `options` dict ({"battle_flow_events": bool, "auto_retreat": bool}).
static func resolve_battle(
	crew_deployed: Array,
	enemies_deployed: Array,
	battlefield_data: Dictionary,
	deployment_condition: Dictionary,
	dice_roller: Callable,
	options: Dictionary = {}
) -> Dictionary:
	# Reuse BattleResolver's unit initialization (Character→dict, effective stats,
	# armor/screen extraction, deployment condition effects). This keeps the unit
	# contract identical to the standard path and preserves input ordering so
	# BattlePhase's index-based is_alive mapping stays valid.
	var battle_state: Dictionary = BattleResolverRef.initialize_battle(
		crew_deployed, enemies_deployed, deployment_condition)
	var crew_units: Array = battle_state["crew_units"]
	var enemy_units: Array = battle_state["enemy_units"]
	_mark_captain(crew_units)
	for enemy in enemy_units:
		enemy["_is_enemy_unit"] = true  # so kill/morale bookkeeping can tell the sides apart

	var consumed_items: Array = []
	var total_crew_casualties := 0
	var total_enemy_kills := 0  # combat kills only — Bailed enemies are NOT kills (Core Rules p.114)
	var total_enemies_bailed := 0
	var round_number := 1

	while round_number <= SAFETY_MAX_ROUNDS:
		var round_result: Dictionary = _execute_round(
			round_number, crew_units, enemy_units, battlefield_data, dice_roller, options)
		total_crew_casualties += round_result["crew_killed"]
		total_enemy_kills += round_result["enemy_killed"]
		consumed_items.append_array(round_result["consumed_items"])

		# Morale (end of round): only enemies test, only if they lost figures this round.
		var bailed: int = resolve_enemy_morale(
			enemy_units, round_result["enemy_killed"], dice_roller)
		total_enemies_bailed += bailed

		# Optional voluntary crew retreat (off by default — see scope notes).
		if options.get("auto_retreat", false):
			_attempt_crew_retreat(crew_units, dice_roller)

		_clear_round_status(crew_units)
		_clear_round_status(enemy_units)

		if _count_alive(crew_units) == 0 or _count_alive(enemy_units) == 0:
			break
		round_number += 1

	# Outcome (Core Rules p.114): all enemies slain OR bailed → Held the Field.
	var crew_alive := _count_alive(crew_units)
	var enemies_alive := _count_alive(enemy_units)
	var success: bool
	var held_field: bool
	if enemies_alive == 0:
		success = true
		held_field = true
	elif crew_alive == 0:
		success = false
		held_field = false
	else:
		# Hit the safety cap with both sides standing — fall back to the shared
		# casualty-ratio outcome so behavior matches the standard resolver.
		var partial: Dictionary = BattleResolverRef.calculate_battle_outcome(
			total_crew_casualties, total_enemy_kills, crew_deployed, enemies_deployed)
		success = partial["success"]
		held_field = partial["held_field"]

	var loot_rolls: int = BattleCalculations.calculate_loot_rolls(
		success, total_enemy_kills, held_field)

	return {
		# Core outcome (identical keys to BattleResolver.resolve_battle)
		"success": success,
		"rounds_fought": round_number,
		"crew_casualties": total_crew_casualties,
		"enemies_defeated": total_enemy_kills,
		"held_field": held_field,
		"loot_opportunities": loot_rolls,
		"battlefield_finds": randi_range(
			BattleResolverRef.BATTLEFIELD_FINDS_MIN,
			BattleResolverRef.BATTLEFIELD_FINDS_MAX) if held_field else 0,
		"consumed_items": consumed_items,
		"crew_units_final": crew_units,
		"enemy_units_final": enemy_units,
		"deployment_effects": battle_state["condition_effects"],
		# No-Minis additive fields (non-breaking; consumers that don't read them are unaffected)
		"combat_mode": "no_minis",
		"enemies_bailed": total_enemies_bailed,
	}


## ── One No-Minis battle round ───────────────────────────────────────────────
## Phases: Battle Flow Events (optional) → Initiative → Firefight.
## Returns {"crew_killed": int, "enemy_killed": int, "consumed_items": Array}.
static func _execute_round(
	_round_number: int,
	crew_units: Array,
	enemy_units: Array,
	_battlefield_data: Dictionary,
	dice_roller: Callable,
	_options: Dictionary
) -> Dictionary:
	var result := {"crew_killed": 0, "enemy_killed": 0, "consumed_items": []}

	# Phase 1 — Battle Flow Events: optional rule, intentionally off for the first
	# cut (Compendium p.71). The phase exists; the D100 table is a future opt-in.

	# Phase 2 — Initiative + crew Initiative Actions (Compendium p.67).
	# Normal initiative = one D6 per crew member (Core Rules p.117); No-Minis uses
	# one die fewer. The Captain always acts; each other living crew member rolls a
	# die and acts if it is ≤ their Reactions. We perform only the OFFENSIVE actions.
	var living_crew: Array = _alive(crew_units)
	for crew in living_crew:
		var acts := false
		if crew.get("_is_captain", false):
			acts = true  # Captain always gets an Initiative Action
		else:
			# (crew_size − 1) dice for (crew_size − 1) non-captain crew → one die each.
			var die: int = dice_roller.call()
			acts = die <= int(crew.get("reactions", 1))
		if acts:
			_perform_offensive_action(crew, enemy_units, dice_roller, result)
			if _count_alive(enemy_units) == 0:
				return result

	# Phase 3 — Firefight (Compendium pp.69-70).
	# Pool excludes enemies that already fired during a crew Optimal Shot this round.
	var pool: Array = []
	for enemy in enemy_units:
		if enemy.get("is_alive", false) and not enemy.get("_fired_optimal_defense", false):
			pool.append(enemy)
	if pool.is_empty():
		return result

	var alive_enemy_count := _count_alive(enemy_units)
	var select_count: int = FIREFIGHT_HIGH_SELECT if alive_enemy_count >= FIREFIGHT_HIGH_THRESHOLD else FIREFIGHT_BASE_SELECT
	var selected: Array = _pick_random(pool, select_count)

	for enemy in selected:
		if not enemy.get("is_alive", false):
			continue
		var target: Dictionary = _random_alive(crew_units)
		if target.is_empty():
			break  # no crew left to target
		_resolve_engagement(enemy, target, dice_roller, result)

	return result


## ── Crew offensive Initiative Action (Optimal Shot / Charge), chosen by loadout ──
static func _perform_offensive_action(
	crew: Dictionary,
	enemy_units: Array,
	dice_roller: Callable,
	result: Dictionary
) -> void:
	var enemy: Dictionary = _random_alive(enemy_units)
	if enemy.is_empty():
		return

	if is_melee_only(crew):
		# Charge (Compendium p.68): 2D6 ≥ 6 (+1 if Speed 5"+).
		var bonus := 1 if int(crew.get("speed", 4)) >= SPEED_BONUS_THRESHOLD else 0
		if _battlefield_test(dice_roller, CHARGE_TARGET, bonus):
			# 1D6 > Speed → the enemy fires first at 6" (charger counts as Cover).
			var pre: int = dice_roller.call()
			if pre > int(crew.get("speed", 4)) and not is_melee_only(enemy):
				_resolve_one_shot(enemy, crew, MELEE_DEFENSE_RANGE, true, dice_roller, result, false)
			if crew.get("is_alive", false) and enemy.get("is_alive", false):
				_resolve_brawl_engagement(crew, enemy, dice_roller, result)
		return

	# Optimal Shot (Compendium p.68): 2D6 ≥ 7, −1 to the roll if Heavy. Crew fires
	# first at max range (both in Cover); a surviving enemy returns fire and is then
	# barred from the Firefight step this round.
	var weapon: Dictionary = _ranged_weapon(crew)
	var heavy_penalty := -1 if _weapon_has_trait(weapon, "heavy") else 0
	if _battlefield_test(dice_roller, OPTIMAL_SHOT_TARGET, heavy_penalty):
		var rng: float = float(_weapon_range(weapon))
		_resolve_one_shot(crew, enemy, rng, true, dice_roller, result, true)
		if enemy.get("is_alive", false) and not is_melee_only(enemy) and not enemy.get("_fired_this_round", false):
			# Enemy returns fire, then cannot be selected as a Firefight attacker.
			_resolve_one_shot(enemy, crew, float(_weapon_range(_ranged_weapon(enemy))), true, dice_roller, result, true)
			enemy["_fired_optimal_defense"] = true


## ── A single Firefight engagement: one selected enemy vs a random crew member ──
## Implements the three weapon-type cases from Compendium p.70.
static func _resolve_engagement(
	enemy: Dictionary,
	crew: Dictionary,
	dice_roller: Callable,
	result: Dictionary
) -> void:
	var enemy_melee := is_melee_only(enemy)
	var crew_melee := is_melee_only(crew)

	if enemy_melee or crew_melee:
		# Melee-only present: the opponent (the ranged one) may shoot first at 6",
		# target in Cover, no Heavy/Area; survivor then Brawls.
		if enemy_melee and not crew_melee:
			# Crew has guns → crew shoots first (if it hasn't already fired this round).
			if not crew.get("_fired_this_round", false):
				_resolve_one_shot(crew, enemy, MELEE_DEFENSE_RANGE, true, dice_roller, result, true)
		elif crew_melee and not enemy_melee:
			# Enemy has guns → enemy always fires if able.
			if not enemy.get("_fired_this_round", false):
				_resolve_one_shot(enemy, crew, MELEE_DEFENSE_RANGE, true, dice_roller, result, true)
		# Both alive → Brawl.
		if enemy.get("is_alive", false) and crew.get("is_alive", false):
			_resolve_brawl_engagement(enemy, crew, dice_roller, result)
		return

	# Both ranged: the longer weapon range fires first; tie → crew first.
	# Both stationary, both in Cover, each fires at max range and max Shots.
	var crew_range: int = _weapon_range(_ranged_weapon(crew))
	var enemy_range: int = _weapon_range(_ranged_weapon(enemy))
	var crew_fires_first := crew_range >= enemy_range  # tie favors crew (p.70)

	if crew_fires_first:
		_ranged_exchange(crew, enemy, dice_roller, result)
	else:
		_ranged_exchange(enemy, crew, dice_roller, result)


## A full ranged exchange: `first` fires (max range, max shots, both in Cover);
## if `second` survives and can fire, it returns fire.
static func _ranged_exchange(
	first: Dictionary,
	second: Dictionary,
	dice_roller: Callable,
	result: Dictionary
) -> void:
	# `first` fires if able and hasn't already fired this round (enemies always fire if able).
	if not first.get("_fired_this_round", false):
		_resolve_one_shot(first, second, float(_weapon_range(_ranged_weapon(first))), true, dice_roller, result, true)
	# Return fire from a surviving `second`.
	if second.get("is_alive", false) and not second.get("_fired_this_round", false):
		_resolve_one_shot(second, first, float(_weapon_range(_ranged_weapon(second))), true, dice_roller, result, true)


## ── One shot resolution (may be multiple Shots per the weapon) ───────────────
## Delegates each Shot's to-hit/damage/saves to BattleCalculations.resolve_ranged_attack.
## `mark_fired` records that the shooter fired this round (a character fires only once/round).
static func _resolve_one_shot(
	shooter: Dictionary,
	target: Dictionary,
	range_inches: float,
	target_in_cover: bool,
	dice_roller: Callable,
	result: Dictionary,
	mark_fired: bool
) -> void:
	if not shooter.get("is_alive", false) or not target.get("is_alive", false):
		return
	var weapon: Dictionary = _ranged_weapon(shooter)
	weapon = _strip_ignored_traits(weapon)
	shooter["range_to_target"] = range_inches
	target["in_cover"] = target_in_cover

	var shots: int = clampi(int(weapon.get("shots", 1)), 1, MAX_SHOTS_CAP)
	var shot := 0
	while shot < shots:
		if not target.get("is_alive", false):
			break
		var attack: Dictionary = BattleCalculations.resolve_ranged_attack(
			shooter, target, weapon, dice_roller)
		_apply_damage(shooter, target, attack, result)
		shot += 1

	if mark_fired:
		shooter["_fired_this_round"] = true


## ── One Brawl engagement ─────────────────────────────────────────────────────
static func _resolve_brawl_engagement(
	a: Dictionary,
	b: Dictionary,
	dice_roller: Callable,
	result: Dictionary
) -> void:
	if not a.get("is_alive", false) or not b.get("is_alive", false):
		return
	# Stunned characters cannot enter Brawling combat (Compendium p.70).
	if a.get("is_stunned", false) or b.get("is_stunned", false):
		return
	var brawl: Dictionary = BattleCalculations.resolve_brawl(a, b, dice_roller)
	if brawl.get("damage_to_defender", 0) > 0:
		_apply_wounds(a, b, int(brawl["damage_to_defender"]), result)
	if brawl.get("damage_to_attacker", 0) > 0:
		_apply_wounds(b, a, int(brawl["damage_to_attacker"]), result)


## ── Damage application (mirrors BattleResolver's unsaved-hit handling) ───────
static func _apply_damage(
	attacker: Dictionary,
	target: Dictionary,
	attack: Dictionary,
	result: Dictionary
) -> void:
	if not attack.get("hit", false):
		return
	var saved: bool = attack.get("armor_saved", false) or attack.get("screen_saved", false)
	if saved:
		# Stun still applies on a saved hit (Core Rules p.51).
		if "stun" in attack.get("effects", []):
			target["is_stunned"] = true
		return
	# An unsaved hit always causes at least 1 wound (Five Parsecs: failed save = casualty).
	var wounds: int = maxi(1, int(attack.get("wounds_inflicted", 1)))
	_apply_wounds(attacker, target, wounds, result)
	if target.get("is_alive", false) and "stun" in attack.get("effects", []):
		target["is_stunned"] = true


## Apply raw wounds to a target, handling stim-pack save and kill bookkeeping.
static func _apply_wounds(
	attacker: Dictionary,
	target: Dictionary,
	wounds: int,
	result: Dictionary
) -> void:
	if not target.get("hp_current"):
		target["hp_current"] = target.get("toughness", BattleResolverRef.DEFAULT_TOUGHNESS)
	target["hp_current"] -= wounds
	if target["hp_current"] > 0:
		return
	# Stim-pack prevents elimination once (Core Rules p.54).
	if target.get("has_stim_pack", false):
		target["has_stim_pack"] = false
		target["hp_current"] = 1
		target["is_stunned"] = true
		result["consumed_items"].append({
			"character_name": target.get("character_name", target.get("name", "")),
			"character_id": str(target.get("character_id", target.get("id", ""))),
			"weapon_name": "Stim-pack",
			"weapon_id": "stim_pack",
		})
		return
	target["is_alive"] = false
	attacker["kills"] = attacker.get("kills", 0) + 1
	if target.get("_is_enemy_unit", false):
		result["enemy_killed"] += 1
	else:
		result["crew_killed"] += 1


## ── Morale: enemy Bail check at end of round (Core Rules p.114; Compendium p.72) ──
## Roll 1D6 per enemy COMBAT casualty this round; each die ≤ Bail Range removes one
## enemy (it Bails — fled, not killed). Regulars bail before Specialists; Fearless never bail.
## Returns the number of enemies that bailed.
static func resolve_enemy_morale(
	enemy_units: Array,
	enemy_killed_this_round: int,
	dice_roller: Callable
) -> int:
	if enemy_killed_this_round <= 0:
		return 0
	var bailed := 0
	var checks := 0
	while checks < enemy_killed_this_round:
		checks += 1
		var die: int = dice_roller.call()
		# Find a living, non-Fearless enemy to apply this die to (regulars first).
		var victim: Dictionary = _next_bail_candidate(enemy_units)
		if victim.is_empty():
			break  # nobody left who can bail
		var bail_max: int = bail_range_max(victim)
		if bail_max > 0 and die <= bail_max:
			victim["is_alive"] = false
			victim["_bailed"] = true  # removed from play, but NOT a combat kill
			bailed += 1
	return bailed


## Pick the next enemy a Morale die applies to: living, not Fearless, regulars before
## specialists. (No positional ordering in No-Minis, so "regulars first" replaces
## "closest to the battlefield edge" — Compendium p.72.)
static func _next_bail_candidate(enemy_units: Array) -> Dictionary:
	var specialist: Dictionary = {}
	for enemy in enemy_units:
		if not enemy.get("is_alive", false) or enemy.get("_bailed", false):
			continue
		if _is_fearless(enemy):
			continue
		if _is_specialist(enemy):
			if specialist.is_empty():
				specialist = enemy
			continue
		return enemy  # a regular — preferred
	return specialist  # only specialists left (or empty)


## ── Voluntary crew retreat (opt-in; Compendium p.72) ─────────────────────────
## Up to 2 crew may attempt to leave: 1D6 ≤ Speed escapes. Special-movement crew
## leave automatically and don't count toward the 2. Off by default — see scope notes.
static func _attempt_crew_retreat(crew_units: Array, dice_roller: Callable) -> void:
	# Only triggered when options.auto_retreat is set; left as a faithful mechanic
	# rather than auto-invoked, since when to retreat is a player decision.
	var attempts := 0
	for crew in crew_units:
		if attempts >= 2:
			break
		if not crew.get("is_alive", false):
			continue
		if crew.get("has_special_movement", false):
			crew["is_alive"] = false
			crew["_retreated"] = true
			continue  # does not count toward the 2-figure limit
		var die: int = dice_roller.call()
		if die <= int(crew.get("speed", 4)):
			crew["is_alive"] = false
			crew["_retreated"] = true
		attempts += 1


## ── Helpers ──────────────────────────────────────────────────────────────────

## Tag the captain (used so the Captain always gets an Initiative Action) and tag
## enemy units so kill/morale bookkeeping can tell the sides apart by reference.
static func _mark_captain(crew_units: Array) -> void:
	var found := false
	for crew in crew_units:
		crew["_is_enemy_unit"] = false
		if crew.get("is_captain", false) and not found:
			crew["_is_captain"] = true
			found = true
		else:
			crew["_is_captain"] = false
	if not found and not crew_units.is_empty():
		crew_units[0]["_is_captain"] = true


static func _battlefield_test(dice_roller: Callable, target: int, modifier: int) -> bool:
	# 2D6 + modifier ≥ target.
	var roll: int = int(dice_roller.call()) + int(dice_roller.call()) + modifier
	return roll >= target


static func _count_alive(units: Array) -> int:
	var n := 0
	for u in units:
		if u.get("is_alive", false):
			n += 1
	return n


static func _alive(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u.get("is_alive", false):
			out.append(u)
	return out


static func _random_alive(units: Array) -> Dictionary:
	var living: Array = _alive(units)
	if living.is_empty():
		return {}
	return living[randi() % living.size()]


## Pick up to `count` distinct entries at random from `pool` (no reordering of backing array).
static func _pick_random(pool: Array, count: int) -> Array:
	var copy: Array = pool.duplicate()
	copy.shuffle()
	var n: int = mini(count, copy.size())
	return copy.slice(0, n)


## Gather every structured weapon dict a unit carries (handles "weapon" dict and
## "weapons" array-of-dicts; ignores the string "weapons" shape used by some
## enemy generators — those fall through to BattleCalculations defaults).
static func _collect_weapons(unit: Dictionary) -> Array:
	var out: Array = []
	var w: Variant = unit.get("weapon", null)
	if w is Dictionary and not (w as Dictionary).is_empty():
		out.append(w)
	var ws: Variant = unit.get("weapons", null)
	if ws is Array:
		for it: Variant in ws:
			if it is Dictionary:
				out.append(it)
	return out


static func _weapon_is_melee(weapon: Dictionary) -> bool:
	var traits: Array = weapon.get("traits", [])
	for t: Variant in traits:
		var ts := str(t).to_lower()
		if ts == "melee" or ts == "blade":
			return true
	if weapon.has("range") and int(weapon.get("range", DEFAULT_RANGED_RANGE)) <= MELEE_RANGE_MAX:
		return true
	var name := str(weapon.get("name", "")).to_lower()
	return "blade" in name or "sword" in name or "claw" in name or "fang" in name or "knife" in name


## A unit is melee-only if it carries structured weapons AND none of them are ranged.
## Units with no structured weapon dict are assumed ranged-capable (the common case).
static func is_melee_only(unit: Dictionary) -> bool:
	var weapons: Array = _collect_weapons(unit)
	if weapons.is_empty():
		return false
	for weapon: Dictionary in weapons:
		if not _weapon_is_melee(weapon):
			return false  # has at least one ranged weapon
	return true


## Best ranged weapon (falls back to a default rifle profile so combat still resolves).
static func _ranged_weapon(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for weapon: Dictionary in _collect_weapons(unit):
		if not _weapon_is_melee(weapon):
			if best.is_empty() or _weapon_range(weapon) > _weapon_range(best):
				best = weapon
	if best.is_empty():
		return {"range": DEFAULT_RANGED_RANGE, "shots": 1, "damage": 1, "traits": []}
	return best


static func _weapon_range(weapon: Dictionary) -> int:
	return int(weapon.get("range", DEFAULT_RANGED_RANGE))


static func _weapon_has_trait(weapon: Dictionary, trait_name: String) -> bool:
	for t: Variant in weapon.get("traits", []):
		if str(t).to_lower() == trait_name.to_lower():
			return true
	return false


## Return a copy of the weapon with No-Minis-ignored traits (Area, Terrifying) removed.
static func _strip_ignored_traits(weapon: Dictionary) -> Dictionary:
	var traits: Array = weapon.get("traits", [])
	if traits.is_empty():
		return weapon
	var needs_strip := false
	for t: Variant in traits:
		if str(t).to_lower() in IGNORED_TRAITS:
			needs_strip = true
			break
	if not needs_strip:
		return weapon
	var clean: Dictionary = weapon.duplicate(true)
	var kept: Array = []
	for t: Variant in traits:
		if not (str(t).to_lower() in IGNORED_TRAITS):
			kept.append(t)
	clean["traits"] = kept
	return clean


## Parse the enemy "panic" / Bail Range string ("1-2", "1", "0") → its maximum.
## A die ≤ this value (and ≥ 1) causes a Bail. "0" means fight-to-the-death.
static func bail_range_max(enemy: Dictionary) -> int:
	var raw: String = str(enemy.get("panic", enemy.get("bail_range", "1-2"))).strip_edges()
	if raw.is_empty():
		return 0
	if "-" in raw:
		var parts: PackedStringArray = raw.split("-")
		if parts.size() >= 2 and parts[1].is_valid_int():
			return int(parts[1])
		return 0
	return int(raw) if raw.is_valid_int() else 0


static func _is_fearless(enemy: Dictionary) -> bool:
	if enemy.get("fearless", false):
		return true
	for rule: Variant in enemy.get("special_rules", []):
		if "fearless" in str(rule).to_lower():
			return true
	return false


static func _is_specialist(enemy: Dictionary) -> bool:
	if enemy.get("is_specialist", false) or enemy.get("specialist", false):
		return true
	var role := str(enemy.get("role", enemy.get("enemy_class", ""))).to_lower()
	return "specialist" in role or "lieutenant" in role


## Reset per-round transient flags + clear Stun (Compendium p.70: Stun clears at round end).
static func _clear_round_status(units: Array) -> void:
	for u in units:
		u["is_stunned"] = false
		u["_fired_this_round"] = false
		u["_fired_optimal_defense"] = false
