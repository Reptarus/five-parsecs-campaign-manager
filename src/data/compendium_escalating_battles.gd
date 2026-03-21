class_name CompendiumEscalatingBattles
extends RefCounted
## Escalating Battles — Compendium pp.46-47
##
## At end of each round, if any enemy removed, objective reached, or
## outnumbered by 3+ at end of Round 1, perform an Escalation check.
## Max 3 escalation rolls per battle. D100 by AI type.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.ESCALATING_BATTLES.


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.ESCALATING_BATTLES)


## ============================================================================
## ESCALATION TRIGGER RULES
## ============================================================================

const TRIGGER_RULES: String = (
	"ESCALATION CHECK: Perform at end of each round if ANY of:\n" +
	"  - Any enemy figures were removed from play\n" +
	"  - A crew member reached an objective\n" +
	"  - End of Round 1, if enemy outnumbered by 3+\n" +
	"Max 3 escalation rolls per battle. Roll D100 by enemy AI type."
)


## ============================================================================
## ESCALATION EFFECTS (Compendium p.47)
## ============================================================================

const ESCALATION_EFFECTS: Array[Dictionary] = [
	{"id": "morale_increase", "name": "Morale Increase",
	 "instruction": "ESCALATION: Morale Increase. Enemy Panic range reduced by -1 (1-3→1-2, 1-2→1, 1→Fearless) for rest of battle. If already Fearless, treat as Fighting Intensifies."},
	{"id": "fighting_intensifies", "name": "Fighting Intensifies",
	 "instruction": "ESCALATION: Fighting Intensifies. Random enemy: +1 Combat Skill, +1 Toughness (max 5) for rest of battle."},
	{"id": "reinforcements", "name": "Reinforcements!",
	 "instruction": "ESCALATION: Reinforcements! 2 basic enemies arrive from random edge (D6: 1-2 left, 3-4 right, 5-6 enemy edge) at center. If enemy base Combat +0, 3 arrive instead (1 is specialist)."},
	{"id": "regroup", "name": "Regroup",
	 "instruction": "ESCALATION: Regroup. Each enemy makes bonus move to most distant position in Cover with LoS and in weapon range. If outnumbered, +1 basic enemy adjacent to random enemy."},
	{"id": "sniper", "name": "Sniper!",
	 "instruction": "ESCALATION: Sniper! Place new enemy on tallest terrain. Armed with Marksman's Rifle, +1 Combat Skill (max +2)."},
	{"id": "ambush", "name": "Ambush!",
	 "instruction": "ESCALATION: Ambush! Select crew furthest to left or right. Place 2 new basic enemies halfway between that side edge and the selected crew figure."},
	{"id": "covering_fire", "name": "Covering Fire",
	 "instruction": "ESCALATION: Covering Fire. Enemy closest to your edge moves up to 3\" (stay in Cover), then throws Frakk grenade (if within 6\") or fires weapon. 1-Shot weapons get +1 to Hit."},
	{"id": "unconventional_tactics", "name": "Unconventional Tactics",
	 "instruction": "ESCALATION: Unconventional Tactics. Next round, all crew members count as Reaction score 1."},
	{"id": "rush_attack", "name": "Rush Attack",
	 "instruction": "ESCALATION: Rush Attack. All enemies make full move immediately, entering Brawl if possible. If outnumbered, +2 basic enemies adjacent to enemy closest to enemy edge."},
]

## D100 ranges by AI type. Values = [effect_index, roll_min, roll_max]
## Effect indices match ESCALATION_EFFECTS array order
const ESCALATION_TABLES: Dictionary = {
	"aggressive": [
		[0, 1, 15], [1, 16, 30], [2, 31, 45], [5, 46, 60],
		[6, 61, 70], [7, 71, 80], [8, 81, 100]],
	"cautious": [
		[0, 1, 10], [1, 11, 15], [2, 16, 40], [3, 41, 55],
		[4, 56, 70], [6, 71, 80], [7, 81, 100]],
	"defensive": [
		[0, 1, 20], [1, 21, 40], [2, 41, 50], [3, 51, 65],
		[4, 66, 75], [6, 76, 90], [7, 91, 100]],
	"rampage": [
		[0, 1, 10], [1, 11, 20], [2, 21, 45], [5, 46, 60],
		[7, 61, 65], [8, 66, 100]],
	"tactical": [
		[0, 1, 10], [1, 11, 25], [2, 26, 30], [3, 31, 45],
		[4, 46, 60], [6, 61, 85], [7, 86, 100]],
	"beast": [
		[0, 1, 10], [1, 11, 15], [2, 16, 35], [5, 36, 80],
		[8, 81, 100]],
}


## ============================================================================
## QUERY METHODS
## ============================================================================

## Check if escalation should trigger this round.
static func should_escalate(enemies_removed: bool, objective_reached: bool,
		round_number: int, enemy_count: int, crew_count: int,
		escalations_so_far: int) -> bool:
	if not _is_enabled():
		return false
	if escalations_so_far >= 3:
		return false
	if enemies_removed or objective_reached:
		return true
	if round_number == 1 and crew_count >= enemy_count + 3:
		return true
	return false


## Roll escalation effect for a given AI type. Returns effect dict.
static func roll_escalation(ai_type: String) -> Dictionary:
	if not _is_enabled():
		return {}

	var ai_key := ai_type.to_lower()
	if not ESCALATION_TABLES.has(ai_key):
		return ESCALATION_EFFECTS[0]

	var roll := randi_range(1, 100)
	var table: Array = ESCALATION_TABLES[ai_key]
	for entry in table:
		var effect_idx: int = entry[0]
		var r_min: int = entry[1]
		var r_max: int = entry[2]
		if roll >= r_min and roll <= r_max:
			var result: Dictionary = ESCALATION_EFFECTS[effect_idx].duplicate()
			result["roll"] = roll
			result["ai_type"] = ai_key
			return result

	return ESCALATION_EFFECTS[0]


## Get escalation effect by ID.
static func get_escalation_effect(effect_id: String) -> Dictionary:
	for effect in ESCALATION_EFFECTS:
		if effect.id == effect_id:
			return effect
	return {}


## Optional variation rule: if same result rolled twice, ignore it
## (doesn't count toward the 3-roll limit).
static func check_variation_duplicate(effect_id: String, prior_effects: Array) -> bool:
	return effect_id in prior_effects
