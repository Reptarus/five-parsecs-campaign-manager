extends RefCounted

## Bespoke AUTO-RESOLVE resolver for Salvage Jobs (Compendium pp.139-148).
##
## A salvage job is a SINGLE scenario with internal rounds (not a campaign-level
## multi-battle), so one resolve_battle() models it. Its core loop is roll-based
## (Tension track, Contact spawning, POI investigation) and therefore auto-
## resolvable; only placement / movement / extraction-positioning are positional,
## which auto-resolve abstracts by design ("play it out for me").
##
## Canonical mechanics modelled (all from CompendiumSalvageJobs / SalvageJobGenerator
## data tables — no invented values):
##   • Tension: starts at ceil(crew/2), max 12 (get_initial_tension). Each round
##     (>1) roll D6 vs Tension (roll_tension): D6 > Tension → Tension rises; else a
##     Contact spawns and Tension drops.
##   • Contacts (resolve_contact, D6): 3-5 = Hostiles → spawn the book's per-encounter
##     force COUNT (enemy_forces_by_encounter: 2 / 2+spec / 2+lt) as clones of the
##     deployed force. The D100 hostile-TYPE variety (free_for_all/toughs/rival_team/
##     infestation) is a setup/manual concern (abstracted — same precedent as the
##     Stealth resolver's reinforcement clones; avoids fabricating per-type stat blocks).
##   • POIs (4 markers, Compendium p.141): each investigated POI rolls roll_poi_reveal
##     (D100, 23 types) → _apply_poi_effect applies the type's canonical effect
##     (tension shift + salvage / credits / quest-rumor / story-point / loot / Savvy
##     test / combat spawn). Positional-only hazards reduce to their tension effect.
##   • Post-mission completion reward (salvage_value_rules): for each POI investigated,
##     D6 → 5 = +1 salvage, 6 = Discovery D100 (loot / +1 salvage / quest-rumor / credits).
##
## Extraction (end-condition): all 4 POIs investigated AND the crew survives. The
## result matches BattleResolver's shape (drop-in for the auto-resolve handoff),
## tagged combat_mode = "salvage", and carries salvage_units / credits_found /
## quest_rumors / story_points_earned for the narrative wrap + post-battle pipeline.
##
## Runs its OWN round loop, reusing BattleResolver's STATIC helpers so the shared
## loop (every other battle) is untouched. NO class_name: preloaded by path.

const BattleResolverRef = preload("res://src/core/battle/BattleResolver.gd")
const CompendiumSalvageJobsRef = preload("res://src/data/compendium_salvage_jobs.gd")
const SalvageJobGeneratorRef = preload("res://src/core/mission/SalvageJobGenerator.gd")

const _SAFETY_MAX_ROUNDS := 100
const POI_COUNT := 4          # Compendium p.141: 4 POI markers (one per quarter)
const MAX_TENSION := 12
const SAVVY_TEST_TARGET := 5  # 1D6 + Savvy >= 5 succeeds (POI Savvy checks)


static func resolve_battle(
		crew_deployed: Array,
		enemies_deployed: Array,
		battlefield_data: Dictionary,
		deployment_condition: Dictionary,
		dice_roller: Callable
) -> Dictionary:
	var field: Dictionary = battlefield_data.duplicate(true)

	# Dramatic Combat (Compendium p.87) parity with BattleResolver.
	var dc_thresholds: Dictionary = _dramatic_thresholds()
	if not dc_thresholds.is_empty():
		field["dramatic_combat"] = true
		field["adjusted_shooting_thresholds"] = dc_thresholds

	var battle_state: Dictionary = BattleResolverRef.initialize_battle(
		crew_deployed, enemies_deployed, deployment_condition)

	# Contact-spawn template: clone the mission's own enemy type (no invented stats).
	var enemy_template: Dictionary = {}
	if not battle_state["enemy_units"].is_empty():
		enemy_template = (battle_state["enemy_units"][0] as Dictionary).duplicate(true)

	var best_savvy: int = _best_savvy(crew_deployed)
	var crew_size: int = maxi(crew_deployed.size(), 1)

	# Accumulators (carried out to the result for the post-battle pipeline + narrative).
	var state := {
		"tension": clampi(CompendiumSalvageJobsRef.get_initial_tension(crew_size), 0, MAX_TENSION),
		"salvage_units": 0,
		"credits_found": 0,
		"quest_rumors": 0,
		"story_points": 0,
		"loot_opportunities": 0,
		"spawned": 0,   # reinforcement/contact clones added (for the loss-ratio denominator)
		"encounter": 0, # hostile-encounter counter (sizes the spawned force)
	}

	var pois_investigated := 0
	var round_number := 1
	var all_consumed_items: Array = []

	while round_number <= _SAFETY_MAX_ROUNDS:
		# 1. Tension / Contact (only while exploring; round > 1 per the book).
		if round_number > 1 and pois_investigated < POI_COUNT:
			var t: Dictionary = CompendiumSalvageJobsRef.roll_tension(int(state["tension"]))
			state["tension"] = clampi(int(t.get("new_tension", state["tension"])), 0, MAX_TENSION)
			if bool(t.get("contact_spawned", false)):
				_resolve_contact(state, battle_state, enemy_template)

		# 2. Investigate one POI per round until all four are done.
		if pois_investigated < POI_COUNT:
			var poi: Dictionary = SalvageJobGeneratorRef.roll_point_of_interest()
			_apply_poi_effect(poi, state, battle_state, enemy_template, best_savvy)
			pois_investigated += 1

		# 3. Combat round (only if a force is present on the board).
		if _count_alive(battle_state["enemy_units"]) > 0:
			var round_result: Dictionary = BattleResolverRef.execute_combat_round(
				round_number,
				battle_state["crew_units"],
				battle_state["enemy_units"],
				field,
				battle_state["condition_effects"],
				dice_roller)
			battle_state["crew_casualties"] += round_result["crew_casualties"]
			battle_state["enemy_casualties"] += round_result["enemy_casualties"]
			all_consumed_items.append_array(round_result.get("consumed_items", []))

		# 4. End checks: crew wiped = failure; all POIs done + board clear = extracted.
		if _count_alive(battle_state["crew_units"]) == 0:
			break
		if pois_investigated >= POI_COUNT and _count_alive(battle_state["enemy_units"]) == 0:
			break
		round_number += 1

	# Post-mission completion reward (salvage_value_rules): per POI investigated, D6.
	for i in pois_investigated:
		var d6: int = randi_range(1, 6)
		if d6 == 5:
			state["salvage_units"] = int(state["salvage_units"]) + 1
		elif d6 == 6:
			_apply_discovery(state)

	# Outcome: effective enemy count = initial + every spawned clone (correct ratio).
	var effective_enemies: Array = enemies_deployed.duplicate()
	for i in int(state["spawned"]):
		effective_enemies.append(enemy_template.duplicate(true))

	var outcome: Dictionary = BattleResolverRef.calculate_battle_outcome(
		battle_state["crew_casualties"],
		battle_state["enemy_casualties"],
		crew_deployed,
		effective_enemies)

	# Extraction success: survived AND investigated all POIs (Compendium p.141).
	var extracted: bool = _count_alive(battle_state["crew_units"]) > 0 and pois_investigated >= POI_COUNT
	var success: bool = bool(outcome["success"]) and extracted

	var loot_rolls := BattleCalculations.calculate_loot_rolls(
		success, battle_state["enemy_casualties"], outcome["held_field"])

	return {
		"success": success,
		"rounds_fought": round_number,
		"crew_casualties": battle_state["crew_casualties"],
		"enemies_defeated": battle_state["enemy_casualties"],
		"held_field": outcome["held_field"],
		"loot_opportunities": loot_rolls,
		"battlefield_finds": randi_range(
			BattleResolverRef.BATTLEFIELD_FINDS_MIN,
			BattleResolverRef.BATTLEFIELD_FINDS_MAX) if outcome["held_field"] else 0,
		"consumed_items": all_consumed_items,
		"crew_units_final": battle_state["crew_units"],
		"enemy_units_final": battle_state["enemy_units"],
		"deployment_effects": battle_state["condition_effects"],
		# Salvage-specific (additive — covered by the narrative contract version).
		"combat_mode": "salvage",
		"salvage_units": int(state["salvage_units"]),
		"credits_found": int(state["credits_found"]),
		"quest_rumors": int(state["quest_rumors"]),
		"story_points_earned": int(state["story_points"]),
		"salvage_loot_rolls": int(state["loot_opportunities"]),
		"pois_investigated": pois_investigated,
		"tension_final": int(state["tension"]),
	}


## Apply a Contact that resolved to Hostiles: spawn the book's per-encounter force
## COUNT (enemy_forces_by_encounter) as clones of the deployed force.
static func _resolve_contact(state: Dictionary, battle_state: Dictionary, template: Dictionary) -> void:
	var contact: Dictionary = SalvageJobGeneratorRef.resolve_contact()
	if str(contact.get("id", "")) != "hostiles":
		return  # nothing / bad_feeling / movement → no combat force
	state["encounter"] = int(state["encounter"]) + 1
	var forces: Dictionary = CompendiumSalvageJobsRef.get_enemy_forces(int(state["encounter"]))
	var count: int = int(forces.get("basic", 0)) + int(forces.get("specialist", 0)) + int(forces.get("lieutenant", 0))
	_spawn_clones(state, battle_state, template, count)


## Apply a POI reveal's canonical effect (Compendium poi_reveals, 23 types). The
## tension_adjust field is applied for every type; per-type extras add salvage /
## credits / quest-rumors / story-points / loot / Savvy tests / combat spawns.
## Positional-only hazards reduce to their tension effect (area overlap can't be
## auto-resolved — documented abstraction).
static func _apply_poi_effect(
		poi: Dictionary, state: Dictionary, battle_state: Dictionary,
		template: Dictionary, best_savvy: int) -> void:
	if poi.is_empty():
		return
	# Base tension shift (data-driven, every POI carries it).
	state["tension"] = clampi(int(state["tension"]) + int(poi.get("tension_adjust", 0)), 0, MAX_TENSION)

	match str(poi.get("id", "")):
		"hot_find":
			var units: int = randi_range(1, 3)
			state["salvage_units"] = int(state["salvage_units"]) + units
			state["tension"] = clampi(int(state["tension"]) + units, 0, MAX_TENSION)  # +1 per salvage
		"cache":
			state["salvage_units"] = int(state["salvage_units"]) + randi_range(1, 3)
		"lure":
			# D6: 1-3 spawn that many Contacts; 4-6 receive that many Salvage units.
			var roll: int = randi_range(1, 6)
			if roll <= 3:
				_spawn_clones(state, battle_state, template, roll)
			else:
				state["salvage_units"] = int(state["salvage_units"]) + roll
		"valuable_find":
			state["credits_found"] = int(state["credits_found"]) + randi_range(1, 3) + 1
		"survivors":
			# 1D3 Hardened Colonist allies; +1 Story Point if any survive/exit. In an
			# abstract resolve the allies are assumed to make it out.
			state["story_points"] = int(state["story_points"]) + 1
		"secure_device":
			if randi_range(1, 6) + best_savvy >= SAVVY_TEST_TARGET:
				state["loot_opportunities"] = int(state["loot_opportunities"]) + 1  # lockbox opened
			else:
				state["tension"] = clampi(int(state["tension"]) + 1, 0, MAX_TENSION)
		"dead_spacer", "interesting_find":
			state["loot_opportunities"] = int(state["loot_opportunities"]) + 1
		"information_station":
			# Reduce Tension by the modified Savvy die (1D6 + Savvy).
			var reduce: int = randi_range(1, 6) + best_savvy
			state["tension"] = clampi(int(state["tension"]) - reduce, 0, MAX_TENSION)
		"incursion", "rival_trap":
			# 6-figure force arrives (4 basic / 1 specialist / 1 lieutenant).
			_spawn_clones(state, battle_state, template, 6)
		"hornets_nest":
			_spawn_clones(state, battle_state, template, 1)
		"security_bot":
			# 1D6+Savvy: 6+ shut down (nothing). Failure: a hostile bot joins the fight.
			if randi_range(1, 6) + best_savvy < 6:
				_spawn_clones(state, battle_state, template, 1)
		"creature":
			# 1D6+Savvy 5+ it fights for you; otherwise it's hostile.
			if randi_range(1, 6) + best_savvy < SAVVY_TEST_TARGET:
				_spawn_clones(state, battle_state, template, 1)
		"we_need_to_hurry":
			# +1 Tension for each remaining POI (this one is already being investigated).
			var remaining: int = POI_COUNT - 1
			state["tension"] = clampi(int(state["tension"]) + remaining, 0, MAX_TENSION)
		_:
			# obstacle / environmental_threat / thick_air / dead_end / all_clear /
			# map_readouts / evac_time / doomsday_protocol: tension-only (already
			# applied) or positional hazards abstracted to their tension effect.
			pass


## Discovery D100 (salvage_value_rules): 01-40 Loot, 41-70 +1 Salvage, 71-85 Quest
## Rumor, 86-100 +1D3 Credits.
static func _apply_discovery(state: Dictionary) -> void:
	var roll: int = randi_range(1, 100)
	if roll <= 40:
		state["loot_opportunities"] = int(state["loot_opportunities"]) + 1
	elif roll <= 70:
		state["salvage_units"] = int(state["salvage_units"]) + 1
	elif roll <= 85:
		state["quest_rumors"] = int(state["quest_rumors"]) + 1
	else:
		state["credits_found"] = int(state["credits_found"]) + randi_range(1, 3)


## Spawn `count` clones of the deployed enemy template into the live enemy force.
## No template (degenerate empty-enemy input) → nothing spawns.
static func _spawn_clones(state: Dictionary, battle_state: Dictionary, template: Dictionary, count: int) -> void:
	if template.is_empty() or count <= 0:
		return
	for i in count:
		var fresh: Dictionary = template.duplicate(true)
		fresh["is_alive"] = true
		fresh["hp_current"] = 1
		fresh["_spawned"] = true
		battle_state["enemy_units"].append(fresh)
	state["spawned"] = int(state["spawned"]) + count


static func _best_savvy(crew: Array) -> int:
	var best := 0
	for member in crew:
		if member is Dictionary:
			best = maxi(best, int(member.get("savvy", 0)))
		elif member is Object and member.has_method("get"):
			best = maxi(best, int(member.get("savvy")))
	return best


## Dramatic-combat thresholds, null-safe (empty when the DLC flag is off).
static func _dramatic_thresholds() -> Dictionary:
	var toggles = load("res://src/data/compendium_difficulty_toggles.gd")
	if toggles and toggles.has_method("get_adjusted_shooting_thresholds"):
		return toggles.get_adjusted_shooting_thresholds()
	return {}


## Count units still standing. Local copy of BattleResolver's helper so this
## resolver doesn't reach into another class's private method.
static func _count_alive(units: Array) -> int:
	var count := 0
	for unit in units:
		if unit.get("is_alive", false):
			count += 1
	return count
