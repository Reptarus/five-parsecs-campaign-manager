extends RefCounted

## Bespoke AUTO-RESOLVE resolver for Street Fights (Compendium pp.125-138).
##
## Street Fights are a positional, player-driven tabletop mission — Suspect / City
## markers, Evasion, pistol Shootouts — that the book runs by hand. This resolver
## does NOT simulate those positional mechanics: auto-resolve ("play it out for
## me") abstracts them by design, the same way it abstracts every played-out
## battle. What it DOES do, canonically, is run the Standard combat resolution
## under the two Street-Fight battle-rule modifiers that map cleanly onto an
## abstract clash:
##
##   • Morale is NOT checked (Compendium pp.125-138). The Standard resolver has
##     no Morale/Bail step (only NoMinisResolver does, Compendium p.72), so this
##     is satisfied by delegating to BattleResolver — documented here so a future
##     change to BattleResolver doesn't silently violate it.
##   • Visibility is limited to 9" and cannot be increased. Injected as
##     battlefield_data["max_visibility_inches"] = 9.0, which caps
##     BattleResolver._estimate_range so every engagement resolves at <= 9" — the
##     defining feel of a street fight (pistols and blades at close quarters; no
##     long-range duels; every weapon is always in range).
##
## The result is tagged combat_mode = "street_fight" so the narrative wrap can
## colour the beats as a back-alley brawl rather than a generic firefight. The
## mission's objective / reward stays in the campaign post-battle flow; this
## resolver owns COMBAT resolution only, and emits the exact BattleResolver
## result shape so it is a drop-in for the auto-resolve handoff.
##
## NO class_name: preloaded by path, matching NoMinisResolver / BattleResolverRouter
## (sidesteps the .uid/class_name runtime trap for editor-external files).

const BattleResolverRef = preload("res://src/core/battle/BattleResolver.gd")

## Compendium pp.125-138: street-fight visibility is limited to 9" and cannot be
## increased. A hard ceiling (not a min() with any prior value) — a street fight
## is always fought at <= 9".
const STREET_FIGHT_VISIBILITY_INCHES := 9.0


static func resolve_battle(
		crew_deployed: Array,
		enemies_deployed: Array,
		battlefield_data: Dictionary,
		deployment_condition: Dictionary,
		dice_roller: Callable
) -> Dictionary:
	# Copy so we never mutate the caller's battlefield_data (it may be reused).
	var sf_field: Dictionary = battlefield_data.duplicate(true)
	sf_field["max_visibility_inches"] = STREET_FIGHT_VISIBILITY_INCHES

	var result: Dictionary = BattleResolverRef.resolve_battle(
		crew_deployed, enemies_deployed, sf_field, deployment_condition, dice_roller)
	result["combat_mode"] = "street_fight"
	return result
