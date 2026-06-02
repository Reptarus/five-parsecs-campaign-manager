extends RefCounted

## Single chokepoint for AUTO-RESOLVE resolver selection. Both auto-resolve call
## sites — CampaignTurnController._on_auto_resolve_completed() and
## TacticalBattleUI._on_auto_resolve_battle() — route through here so the
## No-Minis / Standard / Salvage-fallback decision can never drift between them.
##
## Why this exists (Wave 1.2): the two sites had diverged. CampaignTurnController
## applied the Salvage fallback (Compendium p.116 — No-Minis "is not easily usable
## with the Salvage mission type"); TacticalBattleUI did NOT, so a Salvage mission
## auto-resolved from the battle screen wrongly ran NoMinisResolver. They also
## independently re-derived the "DLC on + standard battle_mode" check. Centralizing
## the decision fixes the inconsistency and gives one place to evolve combat-mode
## routing (e.g. the Wave 3 per-battle picker, the Wave 4 mission resolvers).
##
## NO class_name on purpose: callers preload by path (sidesteps the .uid/class_name
## runtime trap for editor-external files), matching NoMinisResolver's convention.
##
## Both resolvers emit the SAME result Dictionary shape, so the caller is agnostic
## to which one ran (NoMinisResolver adds purely-additive fields like enemies_bailed).

const BattleResolverRef = preload("res://src/core/battle/BattleResolver.gd")
const NoMinisResolverRef = preload("res://src/core/battle/NoMinisResolver.gd")


## Decide whether the No-Minis resolver applies (Compendium pp.66-73):
##   • the NO_MINIS_COMBAT DLC must be enabled, AND
##   • the battle must be standard 5PFH ("" / "standard" battle_mode — Bug Hunt /
##     Planetfall / Tactics keep the generic resolver), AND
##   • the mission must not be Salvage (Compendium p.116 fallback).
## dlc_manager is the /root/DLCManager autoload (or null in tests/headless).
static func use_no_minis(dlc_manager, battle_mode_id: String, mission_type: String) -> bool:
	if dlc_manager == null or not dlc_manager.has_method("is_feature_enabled"):
		return false
	if not dlc_manager.is_feature_enabled(dlc_manager.ContentFlag.NO_MINIS_COMBAT):
		return false
	if battle_mode_id != "" and battle_mode_id != "standard":
		return false
	if "salvage" in mission_type.to_lower():
		return false
	return true


## Resolve an auto-resolved battle, picking the resolver via use_no_minis().
## Returns the resolver result Dictionary (identical shape from either path).
## `options` is forwarded only to NoMinisResolver (BattleResolver takes no options).
static func resolve(
		crew_deployed: Array,
		enemies_deployed: Array,
		battlefield_data: Dictionary,
		deployment_condition: Dictionary,
		dice_roller: Callable,
		dlc_manager,
		battle_mode_id: String = "",
		mission_type: String = "",
		options: Dictionary = {}
) -> Dictionary:
	if use_no_minis(dlc_manager, battle_mode_id, mission_type):
		return NoMinisResolverRef.resolve_battle(
			crew_deployed, enemies_deployed, battlefield_data,
			deployment_condition, dice_roller, options)
	return BattleResolverRef.resolve_battle(
		crew_deployed, enemies_deployed, battlefield_data,
		deployment_condition, dice_roller)
