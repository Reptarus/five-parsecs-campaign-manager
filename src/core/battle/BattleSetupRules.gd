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

const PatronJobEffects = preload("res://src/core/patrons/PatronJobEffects.gd")

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
		# An ABSOLUTE ceiling on the deployment, not a modifier: "Small Squad —
		# You cannot deploy more than 4 crew" (Core Rules p.84) caps at 4 whether
		# the campaign crew size is 4, 5 or 6. 0 = no ceiling. Kept distinct from
		# crew_cap_delta so the two compose instead of one overwriting the other.
		"crew_cap_max": 0,
		"can_seize_initiative": true,
		"panic_range_delta": 0,
		"hold_rounds": 0,
		"no_win_condition": false,
		"early_leave_is_casualty": false,
		"flee_before_round": 0,
		# {"from": [ai codes], "to": code} when an objective overrides enemy AI
		# (Core Rules p.90 Defend). Empty when nothing overrides it.
		"force_enemy_ai": {},
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
	_apply_objective(b, mission_data)
	_apply_deployment_condition(b, mission_data, enemy_count, crew_count)
	_apply_patron_conditions(b, mission_data)
	_apply_expanded_quest_step(b, mission_data)
	return b


## Expanded Quest Progression (Compendium p.79) setup effects.
##
## Two rows change the battle rather than the campaign turn:
##   21-28 "reduce their Panic range by -1" for this one fight;
##   93-100 "All future battles that are part of the Quest reduce the enemy Panic
##          range by -1" for the rest of the Quest.
## ExpandedQuestProgression.mission_stamp() has already summed both into
## `quest_panic_reduction` as a positive magnitude, so the sign convention of
## this bundle (negative = enemies hold on longer, same as p.84 Veteran
## Opposition above) is applied here and nowhere else.
##
## Row 66-80 also changes the opposition's behaviour: "Set up a Protect mission.
## The enemy AI is changed to Aggressive." Unlike p.90 Defend, which only raises
## reluctant AI, this row says "changed to" without qualification, so every AI
## code is on the from-list.
static func _apply_expanded_quest_step(b: Dictionary, mission_data: Dictionary) -> void:
	var reduction: int = int(mission_data.get("quest_panic_reduction", 0))
	if reduction > 0:
		b["panic_range_delta"] -= reduction
		b["setup_notes"].append(
			"Quest step: enemy Panic range -%d (Compendium p.79)." % reduction)
		b["sources"].append("expanded_quest:panic")

	var forced_ai: String = str(mission_data.get("quest_force_enemy_ai", "")).strip_edges()
	if forced_ai.to_lower() == "aggressive":
		b["force_enemy_ai"] = {"from": ["C", "D", "T", "R", "B", "G"], "to": "A"}
		b["setup_notes"].append(
			"Quest step: the enemy AI is changed to Aggressive (Compendium p.79).")
		b["sources"].append("expanded_quest:aggressive_ai")


## Patron job Hazards and Conditions that change the SETUP (Core Rules pp.83-84).
##
## Both were rolled, attached to the job and rendered in the battle screen's
## PATRON CONDITIONS block, and neither reached the setup: a "Small Squad" job
## still let a crew of six deploy six, and "Veteran Opposition" enemies bailed on
## exactly the same roll as anyone else.
##
## Direction note on Bail: p.84 says "Enemy is -1 to Bail Range", and a LOWER
## Bail Range means they hold on longer. That is the opposite sign convention to
## p.88's "Enemy Morale +1", which the Compendium p.49 Leadership table settles
## as ALSO meaning the panic range goes down. Both are enemy buffs; only the
## wording differs, so both are negative deltas here.
static func _apply_patron_conditions(b: Dictionary, mission_data: Dictionary) -> void:
	var cap: int = PatronJobEffects.max_deploy_crew(mission_data)
	if cap > 0:
		b["crew_cap_max"] = cap
		b["setup_notes"].append(
			"Small Squad: deploy no more than %d crew (p.84)." % cap)
		b["sources"].append("patron_condition:small_squad")

	var bail: int = PatronJobEffects.enemy_bail_modifier(mission_data)
	if bail != 0:
		b["panic_range_delta"] += bail
		b["setup_notes"].append(
			"Veteran Opposition: enemy Bail Range %d (p.84)." % bail)
		b["sources"].append("patron_hazard:veteran_opposition")

	if PatronJobEffects.has_vip_enemy(mission_data):
		b["setup_notes"].append(
			"VIP: one random enemy has +%d Toughness and Combat Skill %+d (p.84)."
			% [PatronJobEffects.vip_toughness_bonus(mission_data),
				PatronJobEffects.vip_combat_skill_final(mission_data)])
		b["sources"].append("patron_hazard:vip")


## Objectives that modify the SETUP rather than the win condition.
##
## Only one of the eleven does: Defend (Core Rules p.90). It is a Quest
## objective (p.89, D10 5-6, so a fifth of Quest missions) and its two setup
## clauses were unimplemented — the crew fought one fewer enemy than the rules
## require, against a force that kept its cautious AI. That is the difference
## between "drive off an assault" and "wait out a stand-off", which is the whole
## character of the objective.
static func _apply_objective(b: Dictionary, mission_data: Dictionary) -> void:
	var details: Dictionary = mission_data.get("objective_details", {})
	var obj_type: String = str(details.get("type",
		mission_data.get("objective_type", ""))).strip_edges().to_upper()
	if obj_type != "DEFEND":
		return

	# "Add +1 when determining the enemy numbers."
	b["enemy_delta"] += 1
	# "If the opposing AI is normally Cautious, Defensive, or Tactical, change
	# it to Aggressive." Rampaging, Beast and Guardian are NOT on the book's
	# list and are left alone — the rule raises reluctant AI to Aggressive, it
	# does not lower anything.
	b["force_enemy_ai"] = {"from": ["C", "D", "T"], "to": "A"}
	b["sources"].append("Objective: Defend (Core Rules p.90)")
	b["setup_notes"].append(
		"Defend: add 1 enemy, and any Cautious/Defensive/Tactical AI becomes Aggressive (p.90).")


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
