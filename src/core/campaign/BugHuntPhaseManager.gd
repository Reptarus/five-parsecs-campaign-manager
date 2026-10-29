class_name BugHuntPhaseManager
extends Node

const BattleResultNormalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")
const PostBattleResolver = preload("res://src/core/campaign/BugHuntPostBattleResolver.gd")

## Manages the Bug Hunt 3-stage campaign turn:
##   SPECIAL_ASSIGNMENTS → MISSION → POST_BATTLE
## Each stage must complete before the next begins.
## After POST_BATTLE, the turn is complete and a new turn can start.

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
signal navigation_updated(can_back: bool, can_forward: bool)

enum Phase {
	NONE = -1,
	SPECIAL_ASSIGNMENTS = 0,
	MISSION = 1,
	POST_BATTLE = 2
}

const PHASE_NAMES := {
	Phase.SPECIAL_ASSIGNMENTS: "Special Assignments",
	Phase.MISSION: "Mission",
	Phase.POST_BATTLE: "Post-Battle"
}

const PHASE_COUNT := 3

var campaign: Resource  # BugHuntCampaignCore

## Who went Out of Action in this turn's battle, carried from MISSION completion to
## the post-battle step that rolls the p.202 Casualty table for them.
var _pending_casualty_ids: Array = []
var current_phase: int = Phase.NONE
var previous_phase: int = Phase.NONE
var turn_number: int = 0

var _phase_complete: Dictionary = {
	Phase.SPECIAL_ASSIGNMENTS: false,
	Phase.MISSION: false,
	Phase.POST_BATTLE: false
}


func setup(campaign_resource: Resource) -> void:
	campaign = campaign_resource
	if campaign and "campaign_turn" in campaign:
		turn_number = campaign.campaign_turn


func start_new_turn() -> void:
	turn_number += 1
	if campaign and campaign.has_method("advance_turn"):
		campaign.advance_turn()

	_reset_phase_completion()
	campaign_turn_started.emit(turn_number)
	_journal_log_turn_start(turn_number)
	_go_to_phase(Phase.SPECIAL_ASSIGNMENTS)


func get_phase_name(phase: int = -99) -> String:
	if phase == -99:
		phase = current_phase
	return PHASE_NAMES.get(phase, "Unknown")


func complete_current_phase(result_data: Dictionary = {}) -> void:
	## Mark the current phase as done and auto-advance to next.
	if current_phase == Phase.NONE:
		return

	_phase_complete[current_phase] = true
	phase_completed.emit(current_phase)
	_journal_log_phase_complete(current_phase, result_data)

	# Apply phase results to campaign
	_apply_phase_results(current_phase, result_data)

	# Advance or end turn
	if current_phase < Phase.POST_BATTLE:
		_go_to_phase(current_phase + 1)
	else:
		_complete_turn()


func is_phase_complete(phase: int) -> bool:
	return _phase_complete.get(phase, false)


func can_advance() -> bool:
	return _phase_complete.get(current_phase, false)


func go_to_phase(phase: int) -> void:
	## Public API for external callers (e.g. TurnController resuming after battle).
	_go_to_phase(phase)


func _go_to_phase(phase: int) -> void:
	previous_phase = current_phase
	current_phase = phase
	_persist_phase()
	phase_changed.emit(previous_phase, current_phase)
	_update_navigation()


func _persist_phase() -> void:
	## Write current_phase through to the campaign so a reload resumes here.
	##
	## Called from EVERY transition, not only at turn end. 5PFH persists at two call
	## sites for exactly this reason (CampaignPhaseManager._complete_turn :1077 and
	## start_phase :1324): persist only at turn end and a mid-turn Save stores a stale
	## phase, so reopening the save skips the rest of the turn.
	if campaign and "current_turn_phase" in campaign:
		campaign.current_turn_phase = current_phase


func _complete_turn() -> void:
	## Order is load-bearing: phase -> persist -> save -> emit.
	##
	## The phase must be NONE BEFORE the save, or the file records a finished turn as
	## still sitting in POST_BATTLE and reopening it replays that turn. The emit must be
	## LAST, because campaign_turn_completed is what redraws the footer into its
	## "Start Next Turn" state and it must not fire against an unsaved campaign.
	##
	## Set current_phase DIRECTLY rather than routing through _go_to_phase(NONE): that
	## emits phase_changed, which hides the panel, renders the phase label "UNKNOWN"
	## (PHASE_NAMES has no NONE entry) and resets the footer to a disabled
	## "Complete Phase" -- undoing the turn-complete footer this function then asks for.
	## Mirrors CampaignPhaseManager._complete_turn (CampaignPhaseManager.gd:1077).
	##
	## Leaving current_phase at POST_BATTLE is what made a Bug Hunt turn unable to end:
	## BugHuntTurnController's NONE branch (:310-314) was unreachable, so Advance fell
	## through to panels[POST_BATTLE].complete() and re-applied the finished turn's XP,
	## tally, Reputation, Operational Progress and Sick Bay tick, then saved again.
	previous_phase = current_phase
	current_phase = Phase.NONE
	_persist_phase()

	if campaign and campaign.has_method("persist"):
		campaign.persist()

	campaign_turn_completed.emit(turn_number)
	_journal_log_turn_complete(turn_number)


func _reset_phase_completion() -> void:
	for phase_key in _phase_complete:
		_phase_complete[phase_key] = false


func _update_navigation() -> void:
	var can_back := false  # Never go back in Bug Hunt turn phases
	var can_forward := _phase_complete.get(current_phase, false)
	navigation_updated.emit(can_back, can_forward)


func _apply_phase_results(phase: int, data: Dictionary) -> void:
	if not campaign:
		return

	match phase:
		Phase.SPECIAL_ASSIGNMENTS:
			# Apply assignment results (training, support requests)
			if data.has("completed_assignments") and campaign.has_method("apply_assignments"):
				campaign.apply_assignments(data.completed_assignments)

		Phase.MISSION:
			# Battle results (casualties, objectives, priority changes)
			if data.has("battle_result"):
				_apply_battle_results(data.battle_result)

		Phase.POST_BATTLE:
			# Post-battle processing (injuries, XP, mustering out, operational progress)
			if data.has("post_battle_result"):
				_apply_post_battle_results(data.post_battle_result)


func _apply_battle_results(result: Dictionary) -> void:
	## Reads ONLY keys BugHuntBattleResultNormalizer produces.
	##
	## It used to read three keys nothing wrote. `casualties` is TacticalBattleUI's
	## key and holds Dictionaries, not ids, so `add_to_sick_bay(str(dict), ...)`
	## would have keyed Sick Bay by a stringified Dictionary -- and it never fired,
	## because nothing normalized the result. `injury_turns` and
	## `extra_contact_bonus` had ZERO producers repo-wide, so the objective branch
	## added 0 markers whenever it ran: `.get(key, default)` on a missing key is a
	## silent default, never a fault.
	if not campaign:
		return
	## Sick Bay from the battle is NOT applied here. p.202 Step 1 is a D100 roll on
	## the Casualty table, which decides both the outcome and the number of turns,
	## and that roll happens in the post-battle step -- applying a flat turn here
	## would put the same character in Sick Bay twice for two different reasons.
	var casualty_ids: Array = result.get("casualty_ids", []) \
		if result.get("casualty_ids", []) is Array else []
	if not casualty_ids.is_empty():
		_pending_casualty_ids = casualty_ids.duplicate()


func _apply_post_battle_results(result: Dictionary) -> void:
	## THE ONLY MUTATOR for the Compendium p.202 post-battle sequence.
	##
	## `result` carries what the panel COLLECTED, never what it decided:
	##   receipt -- BugHuntPostBattleResolver.resolve()'s output (steps/effects/rolls)
	##   answers -- choice id -> the player's selection
	##
	## The resolver is pure (it takes a snapshot, never the core) and the panel is
	## presentation-only, so every write to the campaign happens below. That is the
	## 5PFH PostBattlePhase shape: RefCounted processors return data, one orchestrator
	## applies it -- and it is what stops the tally being raised in three places, as
	## HEAD did (here, in the panel, and again inside the muster lookup).
	if not campaign:
		return

	var receipt: Dictionary = result.get("receipt", {})
	if receipt.is_empty():
		return
	var answers: Dictionary = result.get("answers", {})
	var chosen: Dictionary = PostBattleResolver.apply_choices(receipt, answers)
	var cancelled: Array = chosen.get("cancelled", [])

	## Sick Bay ticks BEFORE this turn's wounds go in.
	##
	## HEAD ticked it LAST, so a Casualty row that put a marine in Sick Bay for one
	## turn was decremented straight back to zero in the same breath and they were
	## never out of action at all. p.202 hands out turns the marine is meant to SERVE.
	if campaign.has_method("tick_sick_bay"):
		campaign.tick_sick_bay()

	## Compendium p.210, Co-op campaigns: "Note that the normal Operational Progress table
	## is not used." The resolver skips step 6 when its snapshot carries `coop_enabled`;
	## this is the backstop where the damage would land, so a receipt resolved without that
	## flag still cannot move the p.205 modifier, award its Reputation, or declare the
	## Parade victory on a co-op campaign the sector map has not won.
	var coop_campaign: bool = campaign.has_method("is_coop") and bool(campaign.is_coop())

	## Receipt effects first, in the order the book resolves them, skipping any the
	## player's choice cancelled. The Court Martial buyout is the only canceller
	## today, and it CANCELS the removal rather than undoing it, so no write is ever
	## made that has to be reversed.
	for e in receipt.get("effects", []):
		if not (e is Dictionary):
			continue
		if coop_campaign and str(e.get("cite", "")) == PostBattleResolver.CITE_OP_PROGRESS:
			continue
		# One key, or several: a Lost Marine's roll can be cancelled by Movie Magic
		# "Escape" (every lost marine) OR "Survived" (that one character), p.181.
		var cancel_keys: Variant = e.get("cancel_choice", "")
		if cancel_keys is Array:
			if (cancel_keys as Array).any(func(k: Variant) -> bool: return cancelled.has(str(k))):
				continue
		elif not str(cancel_keys).is_empty() and cancelled.has(str(cancel_keys)):
			continue
		_apply_post_battle_effect(e)

	## Then the effects the answers produced -- purchases, MVP, advanced care.
	## Pressing a button in the panel applies nothing on its own; it becomes an
	## effect here or it does not happen.
	for e in chosen.get("effects", []):
		if e is Dictionary:
			_apply_post_battle_effect(e)

	## ONE save for the whole sequence.
	if campaign.has_method("persist"):
		campaign.persist()


func _apply_post_battle_effect(e: Dictionary) -> void:
	## Apply one resolver effect through the core's own mutators.
	##
	## Every op below is emitted by BugHuntPostBattleResolver and by nothing else.
	## `test_bug_hunt_post_battle_resolver.gd` asserts the two vocabularies match, so
	## an op added to the resolver without a writer here fails loudly instead of
	## silently doing nothing -- the consumer-reads-a-key-no-producer-writes defect
	## with the producer and consumer swapped.
	var op: String = str(e.get("op", ""))
	var target: String = str(e.get("target", ""))
	var amount: int = int(e.get("amount", 0))

	match op:
		"add_xp":
			var mc: Variant = campaign.get_main_character_by_id(target)
			if mc is Dictionary:
				# XP is spent as well as earned (advancements, Military Life
				# purchases), so a negative amount is legitimate -- never below 0.
				mc["xp"] = maxi(int(mc.get("xp", 0)) + amount, 0)

		"stat_increase":
			var stat_mc: Variant = campaign.get_main_character_by_id(target)
			if stat_mc is Dictionary:
				var stat: String = str(e.get("stat", ""))
				if not stat.is_empty():
					var value: int = int(stat_mc.get(stat, 0)) + amount
					var cap: int = int(e.get("max_value", 0))
					if cap > 0:
						value = mini(value, cap)
					stat_mc[stat] = value

		"weapon_range_bonus":
			# p.206 "Weapon specialist": +1" range with one weapon type, for good.
			# It lands on the character dict, which to_dictionary() duplicates
			# wholesale, so it persists with no schema change.
			var wep_mc: Variant = campaign.get_main_character_by_id(target)
			if wep_mc is Dictionary:
				var weapon: String = str(e.get("weapon", ""))
				var bonuses: Dictionary = wep_mc.get("weapon_range_bonuses", {})
				bonuses[weapon] = int(bonuses.get(weapon, 0)) + amount
				wep_mc["weapon_range_bonuses"] = bonuses

		"tally":
			# p.203. The ONE site that raises a marine's completed-mission count.
			# HEAD raised it here AND in the panel AND again inside the muster
			# lookup, so a marine who played every mission was checked at 2, 4 ...
			# 16 and never landed on the p.203 rows that let them leave.
			var tally_mc: Variant = campaign.get_main_character_by_id(target)
			if tally_mc is Dictionary:
				tally_mc["completed_missions_count"] = \
					int(tally_mc.get("completed_missions_count", 0)) + amount

		"set_sick_bay":
			# ABSOLUTE, not additive -- the resolver has already read the current
			# value and decided the result, and add_to_sick_bay() overwrites.
			if amount > 0:
				campaign.add_to_sick_bay(target, amount)
			elif "sick_bay" in campaign:
				campaign.sick_bay.erase(target)

		"kill", "remove_character":
			if not target.is_empty() and campaign.has_method("remove_main_character"):
				campaign.remove_main_character(target)

		"muster_out":
			_muster_out_main_character(target)

		"replace_character":
			_replace_main_character()

		"use_movie_magic":
			if campaign.has_method("use_movie_magic"):
				campaign.use_movie_magic(str(e.get("ability", "")))

		"reputation":
			# Through the core's OWN mutators, not a direct write -- Reputation is a
			# canonical-owner field and lint_data_ownership enforces that. A cost is
			# spent, never subtracted, and a cost larger than the balance takes what
			# is there: spend_reputation() REFUSES an unaffordable amount outright,
			# which would silently leave a book-mandated penalty unpaid.
			if amount > 0 and campaign.has_method("add_reputation"):
				campaign.add_reputation(amount)
			elif amount < 0 and campaign.has_method("spend_reputation"):
				campaign.spend_reputation(mini(-amount, int(campaign.reputation)))

		"op_modifier":
			if "operational_progress_modifier" in campaign:
				campaign.operational_progress_modifier += amount

		"op_reset":
			if "operational_progress_modifier" in campaign:
				campaign.operational_progress_modifier = 0

		"extra_contact_markers":
			if "extra_contact_markers" in campaign:
				campaign.extra_contact_markers = maxi(
					int(campaign.extra_contact_markers) + amount, 0)

		"extra_support_rolls":
			if "extra_support_rolls" in campaign:
				campaign.extra_support_rolls = maxi(
					int(campaign.extra_support_rolls) + amount, 0)

		"missions_in_operation":
			if "missions_in_current_operation" in campaign:
				campaign.missions_in_current_operation = maxi(
					int(campaign.missions_in_current_operation) + amount, 0)

		"total_missions_played":
			if "total_missions_played" in campaign:
				campaign.total_missions_played += amount

		"military_life_flag":
			_set_military_life_flag(target, str(e.get("flag", "")), amount)

		"military_life_roll_owed":
			# Banked by a paid early R&R, spent by the next turn's step 7.
			if "military_life_modifiers" in campaign:
				var mods: Dictionary = campaign.military_life_modifiers
				mods["pending_rolls"] = maxi(int(mods.get("pending_rolls", 0)) + amount, 0)

		"rest_and_recuperation":
			_apply_rest_and_recuperation()

		"campaign_victory":
			# p.205, the `above_100` Parade row -- the only way a Bug Hunt campaign
			# is WON, and unreachable on HEAD because no played mission ever scored
			# an objective. It lands in the existing game_phase vocabulary
			# ("creation" / "active" / "completed", core :33) rather than a new
			# field nothing else reads.
			if "game_phase" in campaign:
				campaign.game_phase = "completed"

		_:
			push_warning("BugHuntPhaseManager: unhandled post-battle effect op '%s'" % op)


func _apply_rest_and_recuperation() -> void:
	## p.206 R&R, as ONE op because it is one rule: "cross off one additional
	## campaign turn in Sick Bay for all characters", and the operation restarts.
	##
	## The additional Military Life roll the same rule grants is ROLLED INSIDE the
	## receipt (resolve() appends an extra step for it) rather than banked here --
	## banking it as well would hand the player the roll twice.
	if "sick_bay" in campaign:
		var recovered: Array = []
		for cid in campaign.sick_bay:
			campaign.sick_bay[cid] = int(campaign.sick_bay[cid]) - 1
			if int(campaign.sick_bay[cid]) <= 0:
				recovered.append(cid)
		for cid in recovered:
			campaign.sick_bay.erase(cid)
	if "missions_in_current_operation" in campaign:
		campaign.missions_in_current_operation = 0


func _set_military_life_flag(character_id: String, flag: String, amount: int) -> void:
	## Persist a p.206 Military Life effect so the systems that must honour it can
	## read it next turn: the Special Assignments bonus/skip, the Priority modifier,
	## and "miss the next mission".
	##
	## `military_life_modifiers` has been a serialized field with NO producer since
	## Bug Hunt shipped -- declared, saved and permanently empty, which reads exactly
	## like a wired feature. Shape: {pending_rolls: int, characters: {cid: {flag: int}}}.
	if flag.is_empty() or character_id.is_empty():
		return
	if not ("military_life_modifiers" in campaign):
		return
	var mods: Dictionary = campaign.military_life_modifiers
	var by_char: Dictionary = mods.get("characters", {})
	var flags: Dictionary = by_char.get(character_id, {})
	flags[flag] = int(flags.get(flag, 0)) + amount
	by_char[character_id] = flags
	mods["characters"] = by_char


func _muster_out_main_character(character_id: String) -> void:
	## p.203. A marine whose term is up LEAVES THE ARMY -- they do not cease to
	## exist. HEAD called remove_main_character() alone, so a veteran the player had
	## fielded for up to fifteen missions was deleted with nothing written anywhere.
	##
	## Destination first, then drop the source, exactly as BugHuntDashboard's manual
	## muster-out does: interrupted between the two, the failure is a duplicate the
	## player can delete, never a veteran who exists nowhere.
	if character_id.is_empty():
		return
	var mc: Variant = campaign.get_main_character_by_id(character_id)
	if not (mc is Dictionary):
		return

	var svc := CharacterTransferService.new()
	var envelope: Dictionary = svc.transfer_character(
		(mc as Dictionary).duplicate(true), "bug_hunt", "five_parsecs")
	if campaign.has_method("get_campaign_id"):
		envelope["source_campaign_id"] = campaign.get_campaign_id()
	if "campaign_name" in campaign:
		envelope["source_campaign_name"] = str(campaign.campaign_name)

	if CharacterTransferService.write_pending_transfer(envelope).is_empty():
		push_error("BugHuntPhaseManager: the muster-out transfer for %s could not be "
			% character_id + "written -- keeping them in the squad rather than losing them")
		return
	if campaign.has_method("remove_main_character"):
		campaign.remove_main_character(character_id)


func _replace_main_character() -> void:
	## p.203: a marine who dies or musters out is replaced by a fresh recruit, so a
	## long campaign does not play itself down to an empty squad.
	if not campaign.has_method("add_main_character"):
		return
	var gen := BugHuntCharacterGeneration.new()
	var recruit: Dictionary = gen.generate_main_character()
	if recruit.is_empty():
		return
	campaign.add_main_character(recruit)



# ── Journal integration (cross-mode coverage) ────────────────────────

func _journal() -> Node:
	## Lookup the CampaignJournal autoload safely. Returns null if absent
	## (e.g. headless tests where the autoload isn't registered).
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/CampaignJournal")


func _journal_log_turn_start(turn: int) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	j.create_entry({
		"type": "milestone",
		"title": "Bug Hunt — Turn %d begins" % turn,
		"description": "Operational turn %d opens with Special Assignments." % turn,
		"turn_number": turn,
		"tags": ["bug_hunt", "milestone", "campaign_setup"],
		"mood": "neutral",
	})


func _journal_log_phase_complete(phase: int, result_data: Dictionary) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	var phase_name: String = PHASE_NAMES.get(phase, "Unknown")
	var desc: String = "Phase complete: %s." % phase_name
	# Enrich description with notable result data when available
	if phase == Phase.MISSION and result_data.has("battle_result"):
		var br: Dictionary = result_data.battle_result
		## Through the shared reader, never `as Array`: an `as` cast on a value that
		## is not an Array yields null, and `.size()` on null ABORTS the enclosing
		## function -- which here would silently drop the journal entry.
		var cas: int = BattleResultNormalizer.casualty_count(br)
		if br.get("casualty_ids", []) is Array:
			cas = (br["casualty_ids"] as Array).size()
		desc += " Casualties: %d." % cas
	elif phase == Phase.POST_BATTLE and result_data.has("post_battle_result"):
		var pbr: Dictionary = result_data.post_battle_result
		var raw_mo: Variant = pbr.get("mustered_out", [])
		var mo: int = (raw_mo as Array).size() if raw_mo is Array else 0
		if mo > 0:
			desc += " %d crew mustered out." % mo
	j.create_entry({
		"type": "milestone",
		"title": "Bug Hunt — %s" % phase_name,
		"description": desc,
		"turn_number": turn_number,
		"tags": ["bug_hunt", "milestone"],
		"mood": "neutral",
	})


func _journal_log_turn_complete(turn: int) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	j.create_entry({
		"type": "milestone",
		"title": "Bug Hunt — Turn %d completed" % turn,
		"description": "Operational turn %d finished." % turn,
		"turn_number": turn,
		"tags": ["bug_hunt", "milestone"],
		"mood": "neutral",
	})
