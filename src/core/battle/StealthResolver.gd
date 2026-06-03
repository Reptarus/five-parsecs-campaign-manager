extends RefCounted

## Bespoke AUTO-RESOLVE resolver for Stealth Missions (Compendium pp.117-124).
##
## Stealth missions are explicitly "NOT compatible with No-minis Combat Resolution"
## and "require conventional miniatures rules" (Compendium p.117). The stealth phase
## — crew creep toward an objective while enemies scan in facing arcs, with a 2D6
## SPOTTING roll compared against MEASURED table distance (p.120) — is inherently
## positional and CANNOT be auto-resolved without inventing a distance. So this
## resolver does NOT simulate detection: that stays player-driven via the panel.
## (Fabricating a detection probability would violate the Data-Integrity rule.)
##
## What it DOES resolve canonically is the post-alarm engagement — conventional
## combat PLUS the one stealth-specific, non-positional, rollable combat mechanic:
## REINFORCEMENTS (Compendium p.120). At the start of each battle round, roll 2D6;
## each die showing a 6 brings 1 basic enemy onto the board. Auto-resolving a
## stealth mission therefore models "the infiltration went loud": the conventional
## firefight escalates as reinforcements stream in.
##
## It runs its OWN round loop, reusing BattleResolver's STATIC helpers
## (initialize_battle / execute_combat_round / calculate_battle_outcome /
## _count_alive_units) instead of modifying BattleResolver's shared loop — so the
## reinforcement behaviour is fully contained and cannot affect Standard / Bug Hunt
## / Planetfall / Tactics / Street-Fight battles. The result matches BattleResolver's
## shape (drop-in for the auto-resolve handoff), is tagged combat_mode = "stealth",
## and carries the canonical stealth objective + a reinforcements_arrived count for
## the narrative wrap.
##
## NO class_name: preloaded by path, matching the other resolvers.

const BattleResolverRef = preload("res://src/core/battle/BattleResolver.gd")
const CompendiumStealthMissionsRef = preload("res://src/data/compendium_stealth_missions.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")

const _SAFETY_MAX_ROUNDS := 100


static func resolve_battle(
		crew_deployed: Array,
		enemies_deployed: Array,
		battlefield_data: Dictionary,
		deployment_condition: Dictionary,
		dice_roller: Callable
) -> Dictionary:
	# Copy so we never mutate the caller's battlefield_data.
	var field: Dictionary = battlefield_data.duplicate(true)

	# Dramatic Combat (Compendium p.87) — query once, mirroring BattleResolver, so
	# per-shot resolution can pick it up. Empty when the DLC flag is off (no-op).
	var dc_thresholds: Dictionary = CompendiumDifficultyTogglesRef.get_adjusted_shooting_thresholds()
	if not dc_thresholds.is_empty():
		field["dramatic_combat"] = true
		field["adjusted_shooting_thresholds"] = dc_thresholds

	var battle_state: Dictionary = BattleResolverRef.initialize_battle(
		crew_deployed, enemies_deployed, deployment_condition)

	# Reinforcement template: clone the mission's own enemy type (avoids inventing
	# a stat block — "basic enemy" reinforcements match the force already present).
	# Snapshot a freshly-initialized enemy unit's shape before combat begins.
	var reinforcement_template: Dictionary = {}
	if not battle_state["enemy_units"].is_empty():
		reinforcement_template = (battle_state["enemy_units"][0] as Dictionary).duplicate(true)

	var reinforcements_arrived := 0
	var round_number := 1
	var all_consumed_items: Array = []

	while round_number <= _SAFETY_MAX_ROUNDS:
		# Reinforcements (Compendium p.120): at the start of each battle round, roll
		# 2D6; each die showing a 6 adds 1 basic enemy. Skipped if no template
		# (degenerate empty-enemy input).
		if not reinforcement_template.is_empty():
			# 2D6: each die showing a 6 adds one reinforcement (Compendium p.120).
			var arriving := 0
			if int(dice_roller.call()) == 6:
				arriving += 1
			if int(dice_roller.call()) == 6:
				arriving += 1
			for i in arriving:
				var fresh: Dictionary = reinforcement_template.duplicate(true)
				fresh["is_alive"] = true
				fresh["hp_current"] = 1
				fresh["_reinforcement"] = true
				battle_state["enemy_units"].append(fresh)
			reinforcements_arrived += arriving

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

		var crew_alive: int = _count_alive(battle_state["crew_units"])
		var enemies_alive: int = _count_alive(battle_state["enemy_units"])
		if crew_alive == 0 or enemies_alive == 0:
			break
		round_number += 1

	# Effective enemy count for the outcome ratio = initial + reinforcements, so the
	# loss-ratio denominator (calculate_battle_outcome uses enemies_deployed.size())
	# accounts for every enemy that actually fought. Pad with real template clones.
	var effective_enemies: Array = enemies_deployed.duplicate()
	for i in reinforcements_arrived:
		effective_enemies.append(reinforcement_template.duplicate(true))

	var outcome: Dictionary = BattleResolverRef.calculate_battle_outcome(
		battle_state["crew_casualties"],
		battle_state["enemy_casualties"],
		crew_deployed,
		effective_enemies)

	# Inferred type (matches BattleResolver): calculate_loot_rolls returns a count.
	var loot_rolls := BattleCalculations.calculate_loot_rolls(
		outcome["success"],
		battle_state["enemy_casualties"],
		outcome["held_field"])

	# Canonical stealth objective (Compendium p.118 D100 table). Returns {} in
	# contexts where the STEALTH_MISSIONS DLC isn't enabled (e.g. headless tests).
	var stealth_objective: Dictionary = CompendiumStealthMissionsRef.roll_objective()

	return {
		"success": outcome["success"],
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
		# Stealth-specific (additive — covered by the narrative contract version).
		"combat_mode": "stealth",
		"stealth_objective": stealth_objective,
		"reinforcements_arrived": reinforcements_arrived,
	}


## Count units still standing. Local copy of BattleResolver's helper so this
## resolver doesn't reach into another class's private method.
static func _count_alive(units: Array) -> int:
	var count := 0
	for unit in units:
		if unit.get("is_alive", false):
			count += 1
	return count
