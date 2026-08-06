class_name StoryTrackProcessor
extends RefCounted

## Story Track post-battle progression — Core Rules Appendix V (pp.153-160).
##
## RESTORES the drive shaft deleted in e4373e137 (Apr 8 2026, the PostBattlePhase
## decomposition). That commit removed `_advance_story_track()`, which was the ONLY
## caller of StoryTrackSystem.advance_clock_end_of_turn() and .apply_post_battle().
## None of the 10 replacement post_battle/* subsystems reimplemented it, so the
## Story Clock had not ticked in any campaign since — no Story Event could ever fire.
##
## TWO DIFFERENCES FROM THE DELETED CODE, both deliberate:
##
## 1. The deleted `_log_story_effects()` only wrote a journal line. The events'
##    `post_battle_effects` — Event 4's 1D6+10 Hull damage, Event 7's rewards —
##    had therefore NEVER been applied, even before the regression. This file
##    applies them.
## 2. Suppression/bonus effects (no payment, no loot, extra Finds rolls) cannot be
##    applied at step 14 because steps 4-7 have already run by then. They are
##    stamped onto `battle_result` by `apply_pre_reward_gates()`, called BEFORE
##    step 4, in exactly the same shape as the existing `is_invasion` gates
##    (PaymentProcessor:200/291-294, LootProcessor:22).
##
## Pattern note: RefCounted, returns data, ZERO `.emit()` — the orchestrator owns
## all signals. Same contract as the other post_battle/* subsystems.

const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")


# ══════════════════════════════════════════════════════════════════════════════
# STEP 0 — Pre-reward gates (must run BEFORE step 4 "Get Paid")
# ══════════════════════════════════════════════════════════════════════════════

func apply_pre_reward_gates(ctx: PostBattleContextClass) -> Dictionary:
	## Stamp the current Story Event's reward suppressions and bonuses onto
	## `battle_result` so the payment/finds/loot processors honour them.
	##
	## Safe to call on every battle: returns immediately unless this turn is a
	## Story Event turn. The outcome branch is already known here — the battle has
	## been fought and `ctx.mission_successful` is set by start_post_battle_phase().
	var gates: Dictionary = {}
	var event: Variant = _current_event(ctx)
	if event == null:
		return gates

	var merged: Dictionary = _merge_outcome_branches(event, ctx)
	if merged.is_empty():
		return gates

	# p.157 (Event 5): "You do not get paid after this mission, and obtain no Loot"
	if bool(merged.get("no_payment", false)):
		ctx.battle_result["story_no_payment"] = true
		gates["no_payment"] = true
	if bool(merged.get("no_loot", false)):
		ctx.battle_result["story_no_loot"] = true
		gates["no_loot"] = true

	# p.157 (Event 5): "You may make a Battlefield Finds roll as normal" — an
	# explicit re-grant, because the same paragraph denies pay and Loot.
	if bool(merged.get("battlefield_finds_roll", false)):
		ctx.battle_result["story_force_battlefield_finds"] = true
		gates["force_finds"] = true

	# p.156 (Event 4 hold field) and p.160 (Event 7 win): "roll twice on the
	# Battlefield Finds Table".
	var finds_rolls: int = int(merged.get("battlefield_finds_rolls", 0))
	if finds_rolls > 0:
		ctx.battle_result["story_battlefield_finds_rolls"] = finds_rolls
		gates["battlefield_finds_rolls"] = finds_rolls

	# p.155 (Event 3 win): "an additional Loot roll from snooping around the site".
	# p.160 (Event 7 win): "3 rolls on the Loot Table".
	var bonus_loot: int = int(merged.get("bonus_loot_roll", 0))
	var loot_rolls: int = int(merged.get("loot_rolls", 0))
	if loot_rolls > 0:
		ctx.battle_result["story_loot_rolls"] = loot_rolls
		gates["loot_rolls"] = loot_rolls
	elif bonus_loot > 0:
		ctx.battle_result["story_bonus_loot_rolls"] = bonus_loot
		gates["bonus_loot_rolls"] = bonus_loot

	# p.153 (Event 1): "provided you killed at least one opponent".
	if bool(merged.get("loot_roll_if_killed_one", false)):
		if ctx.enemies_defeated <= 0:
			ctx.battle_result["story_no_loot"] = true
			gates["no_loot"] = true
			gates["no_loot_reason"] = "killed no opponents"

	# p.153 (Event 1) / p.156 (Event 4): "Do not check for new Rivals after this
	# battle." RivalPatronResolver reads this at step 1.
	if bool(merged.get("no_new_rival_check", false)) \
			or str(merged.get("rival_check", "")) == "none":
		ctx.battle_result["story_no_new_rival_check"] = true
		gates["no_new_rival_check"] = true

	return gates


# ══════════════════════════════════════════════════════════════════════════════
# STEP 14c — Clock / event advancement + consequence effects
# ══════════════════════════════════════════════════════════════════════════════

func process_story_track(ctx: PostBattleContextClass) -> Dictionary:
	## Advance the Story Track at the end of a campaign turn's battle.
	var result: Dictionary = {"active": false}
	var st: Variant = _story_track(ctx)
	if st == null or not st.is_story_track_active:
		return result

	result["active"] = true
	var won: bool = _mission_won(ctx)
	result["won"] = won

	# Event 5 Evidence (Core Rules p.157). Banked BEFORE apply_post_battle(),
	# because that call flips the track into the evidence-search phase and the
	# very next turn's roll is "1D6 + evidence pieces found" — the pieces have to
	# already be on the sheet. StoryMarkerPanel produced them during the battle;
	# add_evidence() had zero callers before that panel existed.
	var found: int = int(ctx.battle_result.get("story_evidence_found", 0))
	if found > 0 and st.has_method("add_evidence"):
		st.add_evidence(found)
		result["evidence_added"] = found

	# Core Rules p.153. This MUST be if/else, never both:
	# apply_post_battle() clears `is_story_event_turn` internally (StoryTrackSystem
	# :212), so calling advance_clock_end_of_turn() after it would tick the clock on
	# a Story Event turn — and the book is explicit that "The Clock does NOT count
	# down during a campaign turn where a Story Event takes place."
	if st.is_story_event_turn:
		# Capture the event's outcome prose BEFORE apply_post_battle(), which
		# advances current_event_index and makes get_current_event() point at the
		# NEXT event. Every event authors completion_win / completion_lose and
		# StoryEvent parses them into narrative_win / narrative_lose — and until
		# now nothing anywhere rendered either one, so the player fought a Story
		# Event and was never told how the story moved.
		var event_now: Variant = st.get_current_event()
		if event_now != null:
			result["event_title"] = str(event_now.title)
			result["event_number"] = int(event_now.event_number)
			result["outcome_text"] = str(
				event_now.narrative_win if won else event_now.narrative_lose)

		# Battle facts the system cannot see for itself, so Event 3's
		# captured-mercenary bonus and Event 7's rescued-companion roll can fire.
		var outcome: Dictionary = {
			"held_field": bool(ctx.battle_result.get("held_field", won)),
			"mercenary_captured": bool(
				ctx.battle_result.get("mercenary_captured", false)),
			"captive_survived": bool(
				ctx.battle_result.get("captive_survived", true)),
		}
		var effects: Dictionary = st.apply_post_battle(won, outcome)
		result["effects"] = effects
		result["applied"] = apply_event_effects(effects, ctx, won)
		_journal_outcome_prose(ctx, result)
	else:
		result["clock"] = st.advance_clock_end_of_turn(won)

	var pm: Variant = ctx.campaign_phase_manager
	if pm != null and pm.has_method("save_story_track_state"):
		pm.save_story_track_state()

	return result


# ══════════════════════════════════════════════════════════════════════════════
# Effect application
# ══════════════════════════════════════════════════════════════════════════════

func apply_event_effects(
	effects: Dictionary, ctx: PostBattleContextClass, won: bool
) -> Array[String]:
	## Apply the consequence half of a Story Event's post_battle_effects.
	##
	## PUBLIC because there is a second entry point: letting the Event 7 delay
	## window lapse (Core Rules p.159, "the chance is missed") completes the track
	## as a loss at TURN START, with no battle and therefore no post-battle
	## pipeline. PostBattlePhase.apply_story_completion_effects() routes that case
	## back through here so "Losing the Story" pays out identically either way.
	## Suppressions and bonus reward rolls are NOT handled here — they were already
	## stamped by apply_pre_reward_gates() before the reward steps ran.
	var applied: Array[String] = []
	if effects.is_empty():
		return applied

	var merged: Dictionary = _merge_branches_from_effects(effects, ctx, won)
	if merged.is_empty():
		return applied

	var is_final: bool = bool(effects.get("story_track_complete", false))

	# ── Story points ──────────────────────────────────────────────────────
	# Event 7's +3 win / +1 loss (p.160) are ALREADY awarded by
	# CampaignPhaseManager._award_story_completion_points(), which fires off the
	# story_track_completed signal. Applying them here too would double-pay.
	var sp: int = int(merged.get("story_points", 0))
	if sp > 0 and not is_final:
		ctx.add_story_points(sp)
		applied.append("+%d story point(s)" % sp)

	# ── XP ────────────────────────────────────────────────────────────────
	# p.156 (Event 4): "every character still on field". p.160 (Event 7): "every
	# crew member". The scope string decides which.
	var xp: int = int(merged.get("xp_bonus", 0))
	if xp > 0:
		var scope: String = str(
			merged.get("xp_bonus_scope", merged.get("xp_scope", "")))
		if scope.contains("still on field"):
			var survivors: Array = _survivors_on_field(ctx)
			for member in survivors:
				ctx.add_character_xp(member, xp)
			applied.append("+%d XP to %d survivor(s)" % [xp, survivors.size()])
		else:
			ctx.award_xp_to_all_crew(xp)
			applied.append("+%d XP to all crew" % xp)

	# ── Credits (p.160, Event 7 win: "1D6+2 credits") ─────────────────────
	var credits_expr: String = str(merged.get("credits", ""))
	if not credits_expr.is_empty():
		var amount: int = _roll_expression(credits_expr, ctx, "Story Track credits")
		if amount > 0 and ctx.game_state_manager \
				and ctx.game_state_manager.has_method("add_credits"):
			ctx.game_state_manager.add_credits(amount)
			applied.append("+%d credits" % amount)

	# ── Ship damage (p.156, Event 4 flee/wipe: "1D6+10 Hull Points") ──────
	var ship_expr: String = str(merged.get("ship_damage", ""))
	if not ship_expr.is_empty():
		var dmg: int = _roll_expression(ship_expr, ctx, "Story Track hull damage")
		var dealt: int = _damage_ship(ctx, dmg)
		if dealt > 0:
			applied.append("ship took %d Hull damage" % dealt)

	# ── Rivals ────────────────────────────────────────────────────────────
	var add_rival: int = int(merged.get("add_rival", 0))
	for _i in range(add_rival):
		ctx.add_rival("Corporate Hitmen")
		applied.append("gained a Rival")

	var remove_rival: int = int(merged.get("remove_rival", 0))
	if remove_rival > 0:
		var removed: int = _remove_rivals(ctx, remove_rival)
		if removed > 0:
			applied.append("removed %d Rival(s)" % removed)
		elif merged.has("remove_rival_deferred"):
			# p.160: "or remove the next one obtained, if you have none currently"
			_set_campaign_flag(ctx, "story_pending_rival_removals",
				_get_campaign_flag(ctx, "story_pending_rival_removals", 0)
				+ remove_rival)
			applied.append("Rival removal banked for the next one gained")

	# p.160 losing: "On each of the next three worlds you visit, you will
	# automatically acquire a new Rival."
	var auto_rivals: int = int(merged.get("auto_rival_next_worlds", 0))
	if auto_rivals > 0:
		_set_campaign_flag(ctx, "story_auto_rival_worlds", auto_rivals)
		applied.append("nemesis will seed a Rival on the next %d worlds"
			% auto_rivals)

	# ── Upkeep relief (p.157, Event 5) ────────────────────────────────────
	if bool(merged.get("upkeep_covered_next_turn", false)):
		_set_campaign_flag(ctx, "upkeep_covered_next_turn", true)
		applied.append("locals cover next turn's Upkeep")

	# ── Companion (pp.158-160, Events 6 and 7) ────────────────────────────
	if bool(merged.get("companion_joins_for_final_battle", false)):
		_set_campaign_flag(ctx, "story_companion_rescued", true)
		applied.append("companion joins for the final battle")
	if bool(merged.get("companion_flown_off", false)):
		_set_campaign_flag(ctx, "story_companion_joins_after_event_7", true)
		applied.append("companion flown off — will join after Event 7")
	if bool(merged.get("companion_joins", false)):
		_set_campaign_flag(ctx, "story_companion_joins_permanently", true)
		# p.160: "They do NOT count towards your Upkeep costs."
		_set_campaign_flag(ctx, "story_companion_free_upkeep",
			not bool(merged.get("companion_upkeep", true)))
		applied.append("companion joins permanently")

	# p.160 losing: "If your old companion was rescued and has not died, roll 1D6:
	# On a 4+, they opt to join you ... but WILL count for Upkeep going forward."
	var join_roll: Dictionary = merged.get("companion_join_roll", {})
	if not join_roll.is_empty() and _companion_rescued(ctx):
		var threshold: int = int(join_roll.get("threshold", 4))
		var roll: int = ctx.roll_d6("Companion joins after Story Track loss")
		if roll >= threshold:
			_set_campaign_flag(ctx, "story_companion_joins_permanently", true)
			_set_campaign_flag(ctx, "story_companion_free_upkeep", false)
			applied.append("companion joins (rolled %d) — counts for Upkeep" % roll)
		else:
			applied.append("companion declines to join (rolled %d)" % roll)

	# ── Event 2 narrative state (p.154) ───────────────────────────────────
	if bool(merged.get("contact_made", false)):
		_set_campaign_flag(ctx, "story_contact_made", true)

	_journal_effects(ctx, effects, applied)
	return applied


# ══════════════════════════════════════════════════════════════════════════════
# Outcome-branch selection
# ══════════════════════════════════════════════════════════════════════════════

func _merge_outcome_branches(
	event: Variant, ctx: PostBattleContextClass
) -> Dictionary:
	if event == null or not ("post_battle_effects" in event):
		return {}
	return _merge_branches_from_effects(
		event.post_battle_effects, ctx, _mission_won(ctx))


func _merge_branches_from_effects(
	effects: Dictionary, ctx: PostBattleContextClass, won: bool
) -> Dictionary:
	## The JSON keys post_battle_effects by outcome. `apply_post_battle()` hands
	## back the WHOLE dict (every branch), so the caller must pick. Branch names
	## vary per event — "hold_field"/"flee"/"win"/"flee_or_all_casualties"/
	## "win_captive_survived"/"winning_the_story"/"losing_the_story" — plus a
	## "common" branch that always applies.
	var merged: Dictionary = {}
	var held: bool = bool(ctx.battle_result.get("held_field", won))

	var order: Array[String] = ["common"]
	if won:
		order.append_array(["win", "winning_the_story", "win_captive_survived"])
	else:
		order.append_array(["losing_the_story"])
	if held:
		order.append("hold_field")
	else:
		order.append_array(["flee", "flee_or_all_casualties"])

	# Event 2 (p.154): the bonus only lands if the mercenary was actually taken
	# alive in a brawl. StoryTrackSystem tracks that on `mercenary_captured`.
	if bool(ctx.battle_result.get("mercenary_captured", false)):
		order.append("brawl_capture")

	for key: String in order:
		var branch: Variant = effects.get(key, null)
		if branch is Dictionary:
			for k: Variant in branch:
				merged[k] = branch[k]

	return merged


# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════

func _story_track(ctx: PostBattleContextClass) -> Variant:
	var pm: Variant = ctx.campaign_phase_manager
	if pm == null:
		return null
	if not ("story_track" in pm):
		return null
	return pm.story_track


func _current_event(ctx: PostBattleContextClass) -> Variant:
	var st: Variant = _story_track(ctx)
	if st == null or not st.is_story_track_active or not st.is_story_event_turn:
		return null
	if not st.has_method("get_current_event"):
		return null
	return st.get_current_event()


func _mission_won(ctx: PostBattleContextClass) -> bool:
	return bool(ctx.battle_result.get("success", ctx.mission_successful))


func _companion_rescued(ctx: PostBattleContextClass) -> bool:
	var st: Variant = _story_track(ctx)
	if st != null and "companion_rescued" in st:
		return bool(st.companion_rescued)
	return bool(_get_campaign_flag(ctx, "story_companion_rescued", false))


func _survivors_on_field(ctx: PostBattleContextClass) -> Array:
	## "every character still on field" (p.156) — participants who did not go down.
	var participants: Array = ctx.get_participating_crew()
	if participants.is_empty():
		participants = ctx.get_crew_members()
	var downed: Array = ctx.battle_result.get("units_downed", [])
	if downed.is_empty():
		return participants
	var survivors: Array = []
	for member: Variant in participants:
		if not _member_id(member) in downed:
			survivors.append(member)
	return survivors


func _member_id(member: Variant) -> String:
	if member is Dictionary:
		return str(member.get("character_id", member.get("id", "")))
	if member is Object:
		if "character_id" in member:
			return str(member.character_id)
		if "id" in member:
			return str(member.id)
	return ""


func _roll_expression(
	expr: String, ctx: PostBattleContextClass, context: String
) -> int:
	## Parse the book's dice notation as written in the JSON: "1D6+2",
	## "1D6+10 Hull Points", "2D6", or a bare integer.
	var cleaned: String = expr.strip_edges().to_upper()
	var total: int = 0
	var d_index: int = cleaned.find("D")
	if d_index <= 0:
		return int(cleaned) if cleaned.is_valid_int() else 0

	var count_text: String = cleaned.substr(0, d_index)
	var count: int = int(count_text) if count_text.is_valid_int() else 1

	var rest: String = cleaned.substr(d_index + 1)
	var sides_text: String = ""
	for ch: String in rest:
		if ch.is_valid_int():
			sides_text += ch
		else:
			break
	var sides: int = int(sides_text) if sides_text.is_valid_int() else 6

	for _i in range(count):
		if sides == 6:
			total += ctx.roll_d6(context)
		else:
			total += randi_range(1, sides)

	var plus_index: int = rest.find("+")
	if plus_index >= 0:
		var bonus_text: String = ""
		for ch: String in rest.substr(plus_index + 1):
			if ch.is_valid_int():
				bonus_text += ch
			else:
				break
		if bonus_text.is_valid_int():
			total += int(bonus_text)

	return total


func _damage_ship(ctx: PostBattleContextClass, amount: int) -> int:
	## apply_ship_damage() is the real API (GameStateManager:496) and returns the
	## damage actually dealt after ship traits. NOTE: `damage_hull()` has zero
	## definitions repo-wide — do not call it.
	if amount <= 0:
		return 0
	if ctx.game_state_manager \
			and ctx.game_state_manager.has_method("apply_ship_damage"):
		return int(ctx.game_state_manager.apply_ship_damage(amount))
	if ctx.campaign and "ship_data" in ctx.campaign:
		var ship: Dictionary = ctx.campaign.ship_data
		ship["hull_points"] = maxi(0, int(ship.get("hull_points", 0)) - amount)
		return amount
	return 0


func _remove_rivals(ctx: PostBattleContextClass, count: int) -> int:
	var campaign: Variant = ctx.campaign
	if campaign == null or not ("rivals" in campaign):
		return 0
	var rivals: Array = campaign.rivals
	var removed: int = 0
	while removed < count and rivals.size() > 0:
		rivals.remove_at(rivals.size() - 1)
		removed += 1
	return removed


func _get_campaign_flag(
	ctx: PostBattleContextClass, key: String, default_value: Variant
) -> Variant:
	var campaign: Variant = ctx.campaign
	if campaign == null or not ("progress_data" in campaign):
		return default_value
	return campaign.progress_data.get(key, default_value)


func _set_campaign_flag(
	ctx: PostBattleContextClass, key: String, value: Variant
) -> void:
	var campaign: Variant = ctx.campaign
	if campaign == null or not ("progress_data" in campaign):
		return
	campaign.progress_data[key] = value


func _journal_outcome_prose(
	ctx: PostBattleContextClass, result: Dictionary
) -> void:
	## Persist the event's own closing narration to the campaign journal, so the
	## story beat survives even if the player dismisses the on-screen card.
	var prose: String = str(result.get("outcome_text", ""))
	if prose.is_empty():
		return
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("create_entry"):
		return
	# Tags and mood must come from the canonical sets in JournalEntryTypes
	# (TAGS / MOOD_STRING_TO_ENUM). validate_entry() only push_warning()s on a
	# miss, so a made-up value ships as console noise plus an entry rendered in
	# the fallback colour — "outcome" and "grim" both did exactly that.
	var won: bool = bool(result.get("won", false))
	ctx.campaign_journal.create_entry({
		"type": "story",
		"auto_generated": true,
		"title": "Event %d: %s — %s" % [
			int(result.get("event_number", 0)),
			str(result.get("event_title", "Story Event")),
			"Victory" if won else "Setback",
		],
		"description": prose,
		"mood": "triumphant" if won else "somber",
		"turn_number": int(ctx.battle_result.get("turn", 0)),
		"tags": ["story_track", "post_battle", "victory" if won else "defeat"],
	})


func _journal_effects(
	ctx: PostBattleContextClass, effects: Dictionary, applied: Array[String]
) -> void:
	if applied.is_empty():
		return
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("create_entry"):
		return
	ctx.campaign_journal.create_entry({
		"type": "story",
		"auto_generated": true,
		"title": "Story Event resolved: %s" % str(effects.get("event_id", "")),
		"description": ", ".join(applied),
		"turn_number": int(ctx.battle_result.get("turn", 0)),
		"tags": ["story_track", "post_battle"],
	})
