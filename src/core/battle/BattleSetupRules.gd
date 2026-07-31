class_name FPCM_BattleSetupRules
extends RefCounted

## The setup-time modifications a scenario makes before the first die is rolled
## — Rival attack types (Core Rules pp.91-92), Invasion battles (p.92) and
## deployment conditions (p.88).
##
## THE GAP THIS FILLS: all three were rolled, stored and DISPLAYED, and none of
## them changed anything.
##   - `rival_attack_type` was written to mission_data and read by exactly one
##     label. Ambush never removed a crew slot or blocked the Seize roll; Brought
##     Friends and Assault never added their enemy; Raid and Assault never cost
##     anything on a loss.
##   - `DeploymentConditionsSystem.apply_condition()` had ZERO callers. Only
##     Small Encounter's enemy reduction was hand-applied at the campaign layer;
##     its crew-sit-out half was not, so the deployment cap was always full size.
##   - Invasion had only the Notable-Sight skip: no extra enemy, no 6-round hold.
##
## Shape: pure static functions over Dictionaries. No tree, no autoloads, no
## RNG at compute time (dice are rolled by the caller and passed in), so the
## whole rules surface is unit-testable and every value traces to a page.
##
## The single setup-time caller is CampaignTurnController._initiate_battle_
## sequence; the loss penalties are consumed post-battle from the same bundle.

## Rival attack types, Core Rules p.91 D10 table:
##   1 Ambush / 2-3 Brought friends / 4-7 Showdown / 8 Assault / 9-10 Raid
const RIVAL_AMBUSH := "AMBUSH"
const RIVAL_BROUGHT_FRIENDS := "BROUGHT_FRIENDS"
const RIVAL_SHOWDOWN := "SHOWDOWN"
const RIVAL_ASSAULT := "ASSAULT"
const RIVAL_RAID := "RAID"

## p.91: "If you flee from the battle before 4 rounds are up, a random crew
## member will lose a random item of equipment carried in your flight."
const RIVAL_FLEE_ROUND_THRESHOLD := 4

## p.92: "You must hold out for 6 rounds... Any figure that leaves the table
## before Round 6 becomes a casualty."
const INVASION_HOLD_ROUNDS := 6


static func _empty_bundle() -> Dictionary:
	return {
		"enemy_delta": 0,
		"crew_cap_delta": 0,
		"can_seize_initiative": true,
		"panic_range_delta": 0,
		"hold_rounds": 0,
		"no_win_condition": false,
		"early_leave_is_casualty": false,
		"flee_before_round": 0,
		"setup_notes": [],
		"loss_penalties": [],
		"round_one": {},
		"sources": [],
	}


## Compute every setup modification this scenario imposes.
##
## mission_data keys read: "rival_attack_type", "mission_source"/"is_invasion",
## "deployment_condition" ({"condition_id": ...}).
## enemy_count / crew_count are the already-rolled values; they only affect
## Small Encounter, which removes 2 enemies when you are outnumbered.
static func compute(
	mission_data: Dictionary, enemy_count: int, crew_count: int
) -> Dictionary:
	var b: Dictionary = _empty_bundle()
	_apply_rival_attack(b, mission_data)
	_apply_invasion(b, mission_data)
	_apply_deployment_condition(b, mission_data, enemy_count, crew_count)
	return b


static func is_invasion(mission_data: Dictionary) -> bool:
	if bool(mission_data.get("is_invasion", false)):
		return true
	return str(mission_data.get("mission_source", "")).to_lower() == "invasion"


static func _apply_rival_attack(b: Dictionary, mission_data: Dictionary) -> void:
	var attack: String = str(
		mission_data.get("rival_attack_type", "")).strip_edges().to_upper()
	if attack.is_empty():
		return

	# p.91: "There is no Win condition against Rivals, but if you Hold the Field,
	# you have an increased chance of permanently chasing them off."
	b["no_win_condition"] = true
	b["flee_before_round"] = RIVAL_FLEE_ROUND_THRESHOLD
	b["sources"].append("Rival attack: %s (Core Rules p.91)" % attack.capitalize())
	b["setup_notes"].append(
		"Fleeing before round %d costs a random crew member a random carried item (p.91)."
			% RIVAL_FLEE_ROUND_THRESHOLD)

	match attack:
		RIVAL_AMBUSH:
			# "You can deploy one crew member less than standard (5 in a typical
			# campaign) for this fight, and cannot roll to Seize the Initiative."
			b["crew_cap_delta"] -= 1
			b["can_seize_initiative"] = false
			b["setup_notes"].append(
				"Ambush: deploy one crew member fewer, and you cannot roll to Seize the Initiative (p.91).")
		RIVAL_BROUGHT_FRIENDS:
			# "Add 1 additional enemy."
			b["enemy_delta"] += 1
			b["setup_notes"].append("Brought Friends: add 1 additional enemy (p.91).")
		RIVAL_SHOWDOWN:
			# "A straight-up fight. No modifications."
			b["setup_notes"].append("Showdown: a straight-up fight, no modifications (p.91).")
		RIVAL_ASSAULT:
			# "Add one additional enemy figure. Your crew must all set up in or
			# adjacent to a building. If you fail to Hold the Field, you will
			# lose 1D3 credits."
			b["enemy_delta"] += 1
			b["setup_notes"].append(
				"Assault: add 1 enemy, and set your whole crew up in or adjacent to a building (p.92).")
			b["loss_penalties"].append({
				"type": "credits",
				"dice": "1D3",
				"reason": "Assault — failed to Hold the Field (Core Rules p.92)",
			})
		RIVAL_RAID:
			# "If you fail to Hold the Field, your ship will take 1D6+1 points of
			# Hull Point damage."
			b["setup_notes"].append(
				"Raid: if you fail to Hold the Field your ship takes 1D6+1 Hull Point damage. Place your ship model on the table (p.92).")
			b["loss_penalties"].append({
				"type": "hull",
				"dice": "1D6+1",
				"reason": "Raid — failed to Hold the Field (Core Rules p.92)",
			})


static func _apply_invasion(b: Dictionary, mission_data: Dictionary) -> void:
	if not is_invasion(mission_data):
		return
	# p.92: "Invasion opponents always have one additional enemy. You must hold
	# out for 6 rounds, then you can flee or fight until you Hold the Field.
	# There is no Win condition. Any figure that leaves the table before Round 6
	# becomes a casualty."
	b["enemy_delta"] += 1
	b["hold_rounds"] = INVASION_HOLD_ROUNDS
	b["no_win_condition"] = true
	b["early_leave_is_casualty"] = true
	b["sources"].append("Invasion battle (Core Rules p.92)")
	b["setup_notes"].append(
		"Invasion: 1 additional enemy. Hold out for %d rounds, then flee or fight until you Hold the Field. There is no Win condition." % INVASION_HOLD_ROUNDS)
	b["setup_notes"].append(
		"Invasion: any figure leaving the table before round %d becomes a casualty (p.92)."
			% INVASION_HOLD_ROUNDS)


static func _apply_deployment_condition(
	b: Dictionary, mission_data: Dictionary, enemy_count: int, crew_count: int
) -> void:
	var cond: Dictionary = mission_data.get("deployment_condition", {})
	var cid: String = str(cond.get("condition_id",
		cond.get("id", ""))).strip_edges().to_upper()
	if cid.is_empty() or cid == "NO_CONDITION":
		return
	b["sources"].append("Deployment condition: %s (Core Rules p.88)" % cid.capitalize())

	match cid:
		"SMALL_ENCOUNTER":
			# p.88: a random crew member sits out, and the opposition is reduced
			# (by 2 if they outnumber you, otherwise by 1). Only the enemy half
			# was ever applied.
			b["crew_cap_delta"] -= 1
			b["enemy_delta"] -= (2 if enemy_count > crew_count else 1)
			b["setup_notes"].append(
				"Small Encounter: one random crew member sits this fight out (p.88).")
		"SURPRISE_ENCOUNTER":
			b["round_one"]["enemy_skips"] = true
			b["setup_notes"].append(
				"Surprise Encounter: the enemy cannot act in round 1 (p.88).")
		"CAUGHT_OFF_GUARD":
			b["round_one"]["crew_all_slow"] = true
			b["setup_notes"].append(
				"Caught Off Guard: your entire crew acts as Slow in round 1 (p.88).")
		"DELAYED":
			b["round_one"]["delayed_crew"] = 2
			b["setup_notes"].append(
				"Delayed: 2 random crew start off-table. At the end of each round roll 1D6 per absent figure; they arrive on a roll at or under the round number (p.88).")
		"BITTER_STRUGGLE":
			# p.88 says only "Enemy Morale is +1", which is ambiguous in a system
			# where enemy morale IS the Panic range. Compendium p.49 settles the
			# vocabulary: it prints a Leadership table headed "enemy Morale is
			# IMPROVED according to the table below" whose every row moves the
			# Panic range DOWN (1-3 -> 1-2, 1-2 -> 1), and adds that a range of 0
			# means Fearless "unless another modifier RAISES the Panic range".
			# So improved Morale = reduced Panic range: Bitter Struggle makes the
			# enemy HARDER to break, matching the Boss rule "Bosses reduce Bail
			# Range by 1". Lieutenant-grade reductions floor at 1 on that table;
			# only Captain-grade reaches 0, so this floors at 1.
			b["panic_range_delta"] -= 1
			b["setup_notes"].append(
				"Bitter Struggle: enemy Morale is improved — their Panic range drops by 1 (p.88; direction per Compendium p.49).")
		"POOR_VISIBILITY", "GLOOMY", "SLIPPERY_GROUND", "TOXIC_ENVIRONMENT", \
		"BRIEF_ENGAGEMENT":
			# Persistent in-battle effects, already surfaced as banner/prompt
			# text by the round spine. Recorded here so the bundle is a complete
			# picture of the scenario, but they impose no setup-time change.
			pass


## Apply the computed enemy delta to an already-rolled enemy roster.
## Additions duplicate the last figure and mark it, matching how the quest-finale
## +1 has always been done; removals pop from the back but never empty the force.
static func apply_enemy_delta(
	enemies: Array, delta: int, label: String = "Reinforcement"
) -> Array:
	if delta == 0 or enemies.is_empty():
		return enemies
	var out: Array = enemies.duplicate()
	if delta > 0:
		for _i in range(delta):
			var extra: Dictionary = (out[-1] as Dictionary).duplicate(true)
			extra["name"] = "%s (%s)" % [extra.get("name", "Enemy"), label]
			# A duplicated figure must not clone a unique role — the book adds a
			# rank-and-file body, not a second Lieutenant or Unique Individual.
			extra["role"] = "standard"
			extra["is_leader"] = false
			extra["is_unique_individual"] = false
			out.append(extra)
	else:
		for _i in range(mini(-delta, out.size() - 1)):
			out.pop_back()
	return out
