class_name EscalatingBattlesManager
extends RefCounted
## Escalating Battles Manager - Compendium pp.46-48
##
## As battles progress, enemies fight back harder, bring reinforcements,
## or rush forward. All output is TEXT INSTRUCTIONS for the tabletop companion.
## Gated behind DLCManager.ContentFlag.ESCALATING_BATTLES.
##
## Trigger conditions (check at end of each round):
##   - Any enemy figures removed from play
##   - A crew member reached an objective
##   - End of Round 1 if enemies outnumbered by 3+
## Max 3 escalation rolls per battle.
##
## D100 table varies by enemy AI type (6 columns from CompendiumDifficultyToggles).
## 9 possible effects with detailed tabletop instructions.


## ============================================================================
## DLC GATING
## ============================================================================

## Check if Escalating Battles DLC feature is enabled.
static func is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.ESCALATING_BATTLES)


## ============================================================================
## ESCALATION D100 TABLE (Compendium p.47)
## Rows: 9 effects. Columns: 6 AI types.
## Each cell is [min, max] range or null if that effect doesn't apply.
## ============================================================================

const ESCALATION_EFFECTS: Array[Dictionary] = [
	{
		"id": "morale_increase",
		"name": "Morale Increase",
		"ranges": {
			"aggressive": [1, 15],
			"cautious": [1, 10],
			"defensive": [1, 20],
			"rampage": [1, 10],
			"tactical": [1, 10],
			"beast": [1, 10],
		},
		"instruction": "ESCALATION: Morale Increase. Panic range for remaining enemies reduced by -1 (1-3 becomes 1-2, 1-2 becomes 1, 1 becomes Fearless). Lasts rest of battle. If already Fearless, treat as 'Fighting intensifies'.",
	},
	{
		"id": "fighting_intensifies",
		"name": "Fighting Intensifies",
		"ranges": {
			"aggressive": [16, 30],
			"cautious": [11, 15],
			"defensive": [21, 40],
			"rampage": [11, 20],
			"tactical": [11, 25],
			"beast": [11, 15],
		},
		"instruction": "ESCALATION: Fighting Intensifies. Select a random enemy - their Combat Skill +1 and Toughness +1 (max 5). Lasts rest of battle.",
	},
	{
		"id": "reinforcements",
		"name": "Reinforcements!",
		"ranges": {
			"aggressive": [31, 45],
			"cautious": [16, 40],
			"defensive": [41, 50],
			"rampage": [21, 45],
			"tactical": [26, 30],
			"beast": [16, 35],
		},
		"instruction": "ESCALATION: Reinforcements! 2 basic enemies arrive from random edge (D6: 1-2 left, 3-4 right, 5-6 enemy edge). Place at center of that edge. If enemy base Combat +0, 3 arrive instead (1 specialist).",
	},
	{
		"id": "regroup",
		"name": "Regroup",
		"ranges": {
			"cautious": [41, 55],
			"defensive": [51, 65],
			"tactical": [31, 45],
		},
		"instruction": "ESCALATION: Regroup. Each enemy makes a bonus move to the most distant position in Cover with LoS to a crew member and in weapons range. If enemies outnumbered, place +1 basic enemy adjacent to a random enemy.",
	},
	{
		"id": "sniper",
		"name": "Sniper!",
		"ranges": {
			"cautious": [56, 70],
			"defensive": [66, 75],
			"tactical": [46, 60],
		},
		"instruction": "ESCALATION: Sniper! Place +1 enemy on tallest terrain feature. Armed with Marksman's Rifle, Combat Skill +1 (max +2).",
	},
	{
		"id": "ambush",
		"name": "Ambush!",
		"ranges": {
			"aggressive": [46, 60],
			"rampage": [46, 60],
			"beast": [36, 80],
		},
		"instruction": "ESCALATION: Ambush! Pick crew figure furthest left or right (random). Place 2 basic enemies halfway between that side edge and the crew figure.",
	},
	{
		"id": "covering_fire",
		"name": "Covering Fire",
		"ranges": {
			"aggressive": [61, 70],
			"cautious": [71, 80],
			"defensive": [76, 90],
			"tactical": [61, 85],
		},
		"instruction": "ESCALATION: Covering Fire. Enemy closest to your edge moves up to 3\" to best shot without leaving Cover, then throws Frakk grenade (if within 6\") or fires weapon. Single-shot weapons get +1 Hit.",
	},
	{
		"id": "unconventional_tactics",
		"name": "Unconventional Tactics",
		"ranges": {
			"aggressive": [71, 80],
			"cautious": [81, 100],
			"defensive": [91, 100],
			"rampage": [61, 65],
			"tactical": [86, 100],
		},
		"instruction": "ESCALATION: Unconventional Tactics. Next round, ALL crew members are counted as having Reaction score of 1.",
	},
	{
		"id": "rush_attack",
		"name": "Rush Attack",
		"ranges": {
			"aggressive": [81, 100],
			"rampage": [66, 100],
			"beast": [81, 100],
		},
		"instruction": "ESCALATION: Rush Attack! Each enemy moves full move immediately, entering brawling combat if possible. If enemies outnumbered, +2 basic enemies placed adjacent to enemy closest to enemy edge.",
	},
]


## ============================================================================
## QUERY METHODS
## ============================================================================

## Check if escalation should be triggered this round.
## Returns true if conditions met and escalation limit not reached.
static func should_check_escalation(
	enemies_removed: bool,
	objective_reached: bool,
	round_num: int,
	crew_outnumber_by: int,
	escalations_so_far: int,
) -> bool:
	if not is_enabled():
		return false
	if escalations_so_far >= 3:
		return false
	if enemies_removed or objective_reached:
		return true
	if round_num == 1 and crew_outnumber_by >= 3:
		return true
	return false


## Roll D100 on the escalation table for a given AI type.
## ai_type should match CompendiumDifficultyToggles AI_BEHAVIOR_TABLE ids:
##   "aggressive", "cautious", "defensive", "rampage", "tactical", "beast"
## Returns escalation dict with {id, name, instruction} or empty if disabled/no match.
static func roll_escalation(ai_type: String) -> Dictionary:
	if not is_enabled():
		return {}
	var roll := randi_range(1, 100)
	return resolve_escalation(roll, ai_type)


## Resolve a specific D100 roll against the escalation table for an AI type.
## Useful for testing or when roll is provided externally.
static func resolve_escalation(roll: int, ai_type: String) -> Dictionary:
	var type_key := ai_type.to_lower()
	for effect in ESCALATION_EFFECTS:
		var ranges: Dictionary = effect.get("ranges", {})
		if type_key in ranges:
			var range_arr: Array = ranges[type_key]
			if roll >= range_arr[0] and roll <= range_arr[1]:
				return {
					"id": effect.id,
					"name": effect.name,
					"instruction": effect.instruction,
					"roll": roll,
					"ai_type": type_key,
				}
	return {}


## Get all possible escalation effects for a given AI type (for reference display).
static func get_effects_for_ai_type(ai_type: String) -> Array[Dictionary]:
	if not is_enabled():
		return []
	var type_key := ai_type.to_lower()
	var results: Array[Dictionary] = []
	for effect in ESCALATION_EFFECTS:
		var ranges: Dictionary = effect.get("ranges", {})
		if type_key in ranges:
			var range_arr: Array = ranges[type_key]
			results.append({
				"id": effect.id,
				"name": effect.name,
				"range": "%02d-%02d" % [range_arr[0], range_arr[1]],
				"instruction": effect.instruction,
			})
	return results


## ============================================================================
## INSTRUCTION TEXT GENERATION
## ============================================================================

## Generate setup instructions explaining escalation rules for this battle.
static func generate_setup_text(ai_type: String) -> String:
	if not is_enabled():
		return ""
	var lines: Array[String] = [
		"[b]ESCALATING BATTLES[/b] (Compendium p.46)",
		"",
		"[b]AI Type:[/b] %s" % ai_type.capitalize(),
		"",
		"[b]Trigger (check end of each round):[/b]",
		"  - Any enemy removed from play",
		"  - A crew member reached an objective",
		"  - End of Round 1 if enemies outnumbered by 3+",
		"",
		"[b]Limit:[/b] Max 3 escalation rolls per battle.",
		"",
		"[b]Possible Effects:[/b]",
	]
	var effects := get_effects_for_ai_type(ai_type)
	for eff in effects:
		lines.append("  %s (%s): %s" % [eff.name, eff.range, eff.id])
	return "\n".join(lines)


## Generate round check text when escalation triggers.
static func generate_escalation_check_text(
	round_num: int,
	escalation_num: int,
	result: Dictionary,
) -> String:
	if result.is_empty():
		return ""
	var lines: Array[String] = [
		"[b]ESCALATION CHECK - Round %d (Roll #%d/3)[/b]" % [round_num, escalation_num],
		"D100 Roll: %d (AI: %s)" % [result.get("roll", 0), result.get("ai_type", "unknown")],
		"",
		result.get("instruction", ""),
	]
	return "\n".join(lines)


## Generate variation mode text when a duplicate result occurs.
static func generate_variation_text(effect_name: String) -> String:
	return "[b]VARIATION MODE:[/b] '%s' already occurred this battle. No effect, but does NOT count toward the 3-roll limit." % effect_name
