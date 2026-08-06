class_name ExpandedQuestProgression
extends RefCounted
## Expanded Quest Progression — Compendium pp.78-80.
##
## WHAT WAS THERE BEFORE. The data has always been complete and correct:
## `data/compendium/missions_expanded.json` carries all nine D100 rows spanning
## 01-100 contiguously, plus the Conclusion. Three reader functions existed on
## `src/data/compendium_missions_expanded.gd` — `roll_quest_progression()`,
## `get_quest_conclusion()` — correctly gated on the EXPANDED_QUESTS flag.
##
## All three had ZERO callers. The chapter was a table nobody rolled on.
##
## Nothing was broken; the wire was simply absent. That makes this a different
## animal from Fringe World Strife (five broken guards over a missing engine) —
## here the missing piece is the STATE. A Quest step is not an event, it is a
## standing obligation: "until this has been paid / done / completed, you cannot
## progress the Quest." A roll with nowhere to persist its result cannot express
## that, which is why the readers were never wired in the first place.
##
## THE BOOK, verbatim.
##
## The gate (p.78):
##   "In Post-Battle Sequence Step 3. 'Determine Quest Progress', the system
##    below is used in place of the core rulebook system. Roll 1D6, adding the
##    number of Quest Rumors you have acquired so far. On a modified score of 6
##    or lower, roll on the Quest Progression table below to determine your next
##    step. On a modified score of 7 or higher, you have reached the Quest
##    Conclusion."
##
## "In place of" is doing real work: this REPLACES the core p.120 mapping (1-3
## dead end / 4-6 a step closer / 7+ finale) and its follow-up p.119 travel roll,
## because the travel roll is part of the system being replaced. The Expanded
## Database +1 (Compendium p.28) is kept — a ship component that modifies a Quest
## progress roll is orthogonal to which table the roll consults. The core -2 for
## a lost battle is NOT kept: the p.78 formula names 1D6 and Quest Rumors only.
##
## The Conclusion (p.80):
##   "This final battle is always a Straight Up Fight with no special conditions.
##    You must add +1 to the number of enemies encountered (plus any modifications
##    from the Quest Progression table above), and the enemy is always accompanied
##    by a Unique Individual. They will not test Morale during this battle."
##
## The two permanent rows (p.79):
##   81-92 "All future battles that are part of the Quest must add +1 to the
##         number of enemies encountered (entry 54-65 above is unaffected)."
##   93-100 "All future battles that are part of the Quest reduce the enemy Panic
##          range by -1."
## Both stack with the Conclusion's own +1 — "plus any modifications from the
## Quest Progression table above" says so explicitly.
##
## STATE lives at `campaign.progress_data["expanded_quest"]`, which is already
## serialized, so it persists for free and dies with the campaign. It is keyed to
## nothing: a campaign has at most one active Quest (`GameState.get_active_quest`
## holds a single Dictionary), and `clear()` runs when that Quest ends.

const FLAG := "EXPANDED_QUESTS"
const STATE_KEY := "expanded_quest"

## p.78: "On a modified score of 7 or higher, you have reached the Quest
## Conclusion."
const CONCLUSION_THRESHOLD := 7

const MissionsExpandedRef = preload("res://src/data/compendium_missions_expanded.gd")


## ============================================================================
## GATING
## ============================================================================

static func _dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


## Whether the player enabled the chapter. Everything else in this file is a
## pure state accessor and stays honest when the answer is false — a campaign
## that turns the flag off mid-run keeps its pending step in progress_data but
## stops consulting it, and turning it back on resumes where it left off.
static func is_enabled() -> bool:
	var dlc := _dlc_manager()
	if not dlc:
		return false
	var flag_value: int = dlc.ContentFlag.get(FLAG, -1)
	if flag_value < 0:
		return false
	return dlc.is_feature_enabled(flag_value)


## ============================================================================
## STATE
## ============================================================================

static func _blank_state() -> Dictionary:
	return {
		# The standing obligation. {} when the Quest is free to progress.
		"step": {},
		# p.79 rows 81-92 and 93-100. Permanent for the rest of THIS Quest.
		"enemy_bonus": 0,
		"panic_reduction": 0,
		# Step ids in the order they were rolled, for the journal and the UI.
		"history": [],
	}


static func get_state(campaign: Variant) -> Dictionary:
	if campaign == null or not ("progress_data" in campaign):
		return _blank_state()
	var raw: Variant = campaign.progress_data.get(STATE_KEY, null)
	if raw is Dictionary:
		var state: Dictionary = _blank_state()
		state.merge(raw, true)
		return state
	return _blank_state()


static func _write_state(campaign: Variant, state: Dictionary) -> void:
	if campaign == null or not ("progress_data" in campaign):
		return
	campaign.progress_data[STATE_KEY] = state


## Called when a Quest ends. The permanent modifiers are per-Quest ("all future
## battles that are part of THE Quest"), so a new Quest must not inherit them.
static func clear(campaign: Variant) -> void:
	if campaign == null or not ("progress_data" in campaign):
		return
	campaign.progress_data.erase(STATE_KEY)


## ============================================================================
## THE PENDING STEP
## ============================================================================

static func get_pending_step(campaign: Variant) -> Dictionary:
	var step: Variant = get_state(campaign).get("step", {})
	return step if step is Dictionary else {}


## "Until this has been [paid/done/completed], you cannot progress the Quest."
## Seven of the nine rows carry that clause; the two that do not resolve on the
## spot and never become pending.
static func blocks_progress(campaign: Variant) -> bool:
	var step: Dictionary = get_pending_step(campaign)
	return not step.is_empty() and bool(step.get("blocks_progress", false))


## Whether the pending step is one the crew discharges by fighting. Used by the
## job offer screen: a Quest whose next step is a purchase or a research effort
## has no battle to offer, and a Quest whose next step IS a battle must offer
## that battle rather than a generic Quest mission.
static func pending_step_is_battle(campaign: Variant) -> bool:
	var step: Dictionary = get_pending_step(campaign)
	if step.is_empty():
		return false
	var completion: String = str(step.get("completion", ""))
	return completion == "hold_the_field" or completion == "mission"


static func _table() -> Array:
	return MissionsExpandedRef.QUEST_PROGRESSION


## D100 lookup. Public so tests and the UI can address a row without rolling.
static func step_for_roll(roll: int) -> Dictionary:
	for row: Variant in _table():
		if not (row is Dictionary):
			continue
		if roll >= int(row.get("roll_min", 0)) and roll <= int(row.get("roll_max", 0)):
			return (row as Dictionary).duplicate(true)
	return {}


static func step_by_id(step_id: String) -> Dictionary:
	for row: Variant in _table():
		if row is Dictionary and str(row.get("id", "")) == step_id:
			return (row as Dictionary).duplicate(true)
	return {}


## ============================================================================
## THE p.78 GATE
## ============================================================================

## Roll Post-Battle Step 3 under the expanded system.
##
## d6 / d100 / cost_d6 / research_d6 are injectable so the caller can route them
## through DiceManager (journal + dice feed) and so tests are deterministic; -1
## means "roll here".
##
## crew_savvy_total is only read by the Analyze Data row, which generates
## research points "equal to the combined Savvy scores of your crew members,
## +1D6" the moment the step is assigned.
##
## Returns:
##   {ran, blocked, step, roll, rumors, total, conclusion, rumor_awarded, message}
static func roll_progress(
	campaign: Variant,
	quest_rumors: int,
	crew_savvy_total: int = 0,
	turn_number: int = 0,
	bonus: int = 0,
	d6: int = -1,
	d100: int = -1,
	cost_d6: int = -1,
	research_d6: int = -1
) -> Dictionary:
	var result: Dictionary = {
		"ran": false, "blocked": false, "step": {}, "roll": 0,
		"rumors": quest_rumors, "total": 0, "conclusion": false,
		"rumor_awarded": false, "message": "",
	}
	if not is_enabled() or campaign == null:
		return result

	var state: Dictionary = get_state(campaign)

	# The standing obligation outranks the roll. "Until this has been done, you
	# cannot progress the Quest" — and progressing the Quest is exactly what this
	# step does, so a pending blocker means Step 3 produces no roll at all.
	var pending: Dictionary = state.get("step", {})
	if pending is Dictionary and not pending.is_empty() \
			and bool(pending.get("blocks_progress", false)):
		result["blocked"] = true
		result["step"] = pending
		result["message"] = str(pending.get("instruction", ""))
		return result

	result["ran"] = true
	var base: int = d6 if d6 > 0 else randi_range(1, 6)
	var total: int = base + maxi(0, quest_rumors) + bonus
	result["roll"] = base
	result["total"] = total

	if total >= CONCLUSION_THRESHOLD:
		result["conclusion"] = true
		result["message"] = str(MissionsExpandedRef.QUEST_CONCLUSION.get("instruction", ""))
		return result

	var table_roll: int = d100 if d100 > 0 else randi_range(1, 100)
	var step: Dictionary = step_for_roll(table_roll)
	if step.is_empty():
		return result

	step["roll"] = table_roll
	step["assigned_turn"] = turn_number
	step["progress"] = 0
	result["step"] = step
	result["message"] = str(step.get("instruction", ""))

	var history: Array = state.get("history", [])
	history.append(str(step.get("id", "")))
	state["history"] = history

	# The two rows that resolve on the spot: "Add 1 Quest Rumor" with no
	# obligation attached, plus a modifier that lasts the rest of the Quest.
	if bool(step.get("immediate_rumor", false)):
		result["rumor_awarded"] = true
		state["enemy_bonus"] = int(state.get("enemy_bonus", 0)) \
			+ int(step.get("permanent_enemy_bonus", 0))
		state["panic_reduction"] = int(state.get("panic_reduction", 0)) \
			+ int(step.get("permanent_panic_reduction", 0))
		state["step"] = {}
		_write_state(campaign, state)
		return result

	# "It costs 1D6 Credits" — rolled once, when the step is assigned, so the
	# player is told the price instead of re-rolling it every time they look.
	if str(step.get("completion", "")) == "pay_credits":
		step["cost"] = cost_d6 if cost_d6 > 0 else randi_range(1, 6)

	# "You generate research points equal to the combined Savvy scores of your
	# crew members, +1D6." The first tranche lands at assignment; every campaign
	# turn after that adds another via add_research_points().
	if str(step.get("completion", "")) == "research_points":
		var first: int = maxi(0, crew_savvy_total) \
			+ (research_d6 if research_d6 > 0 else randi_range(1, 6))
		step["progress"] = first
		if first >= int(step.get("research_target", 20)):
			# Solved before it ever became an obligation.
			result["rumor_awarded"] = true
			state["step"] = {}
			state["history"] = history
			_write_state(campaign, state)
			result["step"] = step
			return result

	state["step"] = step
	_write_state(campaign, state)
	result["step"] = step
	return result


## ============================================================================
## DISCHARGING THE PENDING STEP
## ============================================================================

## Shared tail: clear the obligation and report the Rumor every row pays.
## Every completion clause in the table ends "receive 1 Quest Rumor" / "Claim 1
## Quest Rumor" / "Add 1 Quest Rumor", so the reward is not per-row data.
static func _complete(campaign: Variant, state: Dictionary, step: Dictionary) -> Dictionary:
	state["step"] = {}
	_write_state(campaign, state)
	return {
		"completed": true, "rumor_awarded": true, "step_id": str(step.get("id", "")),
		"message": "Quest step complete: +1 Quest Rumor.",
	}


static func _incomplete(step: Dictionary, message: String) -> Dictionary:
	return {
		"completed": false, "rumor_awarded": false,
		"step_id": str(step.get("id", "")), "message": message,
	}


## "It costs 1D6 Credits. Until this has been paid, you cannot progress the
## Quest. Once it is paid, receive 1 Quest Rumor."
##
## Returns {completed, rumor_awarded, cost, paid, message}. The caller owns the
## credits — this never mutates them, it only reports whether the price is met,
## because credits have a single canonical owner (GameStateManager.set_credits).
static func pay_step_cost(campaign: Variant, credits_available: int) -> Dictionary:
	var state: Dictionary = get_state(campaign)
	var step: Dictionary = state.get("step", {})
	if not (step is Dictionary) or step.is_empty() \
			or str(step.get("completion", "")) != "pay_credits":
		return {"completed": false, "rumor_awarded": false, "cost": 0, "paid": 0,
			"message": "No purchase is pending on this Quest."}
	var cost: int = int(step.get("cost", 0))
	if credits_available < cost:
		var short: Dictionary = _incomplete(step,
			"The information costs %d credits; you have %d." % [cost, credits_available])
		short["cost"] = cost
		short["paid"] = 0
		return short
	var done: Dictionary = _complete(campaign, state, step)
	done["cost"] = cost
	done["paid"] = cost
	done["message"] = "Paid %d credits for the information: +1 Quest Rumor." % cost
	return done


## "You may continue accumulating research points every campaign turn until you
## reach the total." Called at turn rollover with the crew's combined Savvy; the
## +1D6 is injectable for the same reasons as above.
static func add_research_points(
	campaign: Variant, crew_savvy_total: int, research_d6: int = -1
) -> Dictionary:
	var state: Dictionary = get_state(campaign)
	var step: Dictionary = state.get("step", {})
	if not (step is Dictionary) or step.is_empty() \
			or str(step.get("completion", "")) != "research_points":
		return {"completed": false, "rumor_awarded": false, "points": 0, "total": 0,
			"message": ""}
	var gained: int = maxi(0, crew_savvy_total) \
		+ (research_d6 if research_d6 > 0 else randi_range(1, 6))
	var total: int = int(step.get("progress", 0)) + gained
	var target: int = int(step.get("research_target", 20))
	step["progress"] = total
	if total >= target:
		var done: Dictionary = _complete(campaign, state, step)
		done["points"] = gained
		done["total"] = total
		done["message"] = "Research complete (%d/%d): +1 Quest Rumor." % [total, target]
		return done
	state["step"] = step
	_write_state(campaign, state)
	var partial: Dictionary = _incomplete(step,
		"Research continues: %d/%d points." % [total, target])
	partial["points"] = gained
	partial["total"] = total
	return partial


## "A special Work on the Quest crew task becomes available... Once a total of 6
## such tasks have been performed by your crew, receive 1 Quest Rumor."
static func record_quest_task(campaign: Variant) -> Dictionary:
	var state: Dictionary = get_state(campaign)
	var step: Dictionary = state.get("step", {})
	if not (step is Dictionary) or step.is_empty() \
			or str(step.get("completion", "")) != "crew_tasks":
		return {"completed": false, "rumor_awarded": false, "tasks": 0, "target": 0,
			"message": ""}
	var target: int = int(step.get("task_target", 6))
	var done_count: int = int(step.get("progress", 0)) + 1
	step["progress"] = done_count
	if done_count >= target:
		var done: Dictionary = _complete(campaign, state, step)
		done["tasks"] = done_count
		done["target"] = target
		done["message"] = "The work is finished (%d/%d): +1 Quest Rumor." % [done_count, target]
		return done
	state["step"] = step
	_write_state(campaign, state)
	var partial: Dictionary = _incomplete(step,
		"Work on the Quest: %d/%d tasks." % [done_count, target])
	partial["tasks"] = done_count
	partial["target"] = target
	return partial


## Whether the "Work on the Quest" crew task should appear this turn. It is not a
## standing option — it exists only while row 29-38 is the pending step.
static func quest_task_available(campaign: Variant) -> bool:
	var step: Dictionary = get_pending_step(campaign)
	return not step.is_empty() and str(step.get("completion", "")) == "crew_tasks"


## The three battle-discharged rows, resolved from a post-battle result.
##
## `tough_fight` pays on Hold the Field specifically ("If you Hold the Field,
## receive 1 Quest Rumor") — losing the field means the obligation stands and the
## fight can be taken again, which is what "you may take on this battle at any
## time" allows.
##
## The two data-cache rows and the business contact pay on "when the mission is
## completed". For 54-65 that completion is its own in-battle clock ("Once the
## score reaches 28, you can end the mission"), reported as
## `quest_survival_reached`.
static func record_battle(campaign: Variant, battle_result: Dictionary) -> Dictionary:
	var state: Dictionary = get_state(campaign)
	var step: Dictionary = state.get("step", {})
	if not (step is Dictionary) or step.is_empty():
		return {"completed": false, "rumor_awarded": false, "step_id": "", "message": ""}

	# The battle has to be THIS step's battle. Without the stamp a Patron job
	# fought while a Quest obligation was open would discharge the obligation.
	var fought_id: String = str(battle_result.get("quest_step_id", ""))
	if fought_id != str(step.get("id", "")):
		return {"completed": false, "rumor_awarded": false,
			"step_id": str(step.get("id", "")), "message": ""}

	match str(step.get("completion", "")):
		"hold_the_field":
			if bool(battle_result.get("held_field", false)):
				return _complete(campaign, state, step)
			return _incomplete(step,
				"You did not hold the field. The Quest step still stands.")
		"mission":
			if str(step.get("id", "")) == "data_cache_dangerous":
				if bool(battle_result.get("quest_survival_reached", false)):
					return _complete(campaign, state, step)
				return _incomplete(step,
					"You pulled out before the score reached %d. The step still stands."
					% int(step.get("survival_target", 28)))
			# "success" is the canonical key: PostBattlePhase reads exactly
			# `battle_data.get("success", false)` into ctx.mission_successful, and
			# the results form emits it under that name. The other two spellings
			# are tolerated for the auto-resolve paths, not relied on.
			if bool(battle_result.get("success",
					battle_result.get("mission_successful",
						battle_result.get("victory", false)))):
				return _complete(campaign, state, step)
			return _incomplete(step, "The mission was not completed. The step still stands.")
		_:
			return {"completed": false, "rumor_awarded": false,
				"step_id": str(step.get("id", "")), "message": ""}


## ============================================================================
## BATTLE MODIFIERS
## ============================================================================

## +1 per p.79 row 81-92, permanently, plus +2 while row 21-28 is the pending
## fight. The Conclusion's own +1 is NOT included here — CampaignTurnController
## already adds the finale reinforcement off `is_quest_finale`, and p.80 says the
## Conclusion adds its +1 "plus any modifications from the Quest Progression
## table", so the two compose by staying separate.
##
## `step_id` names the battle being generated so the book's one carve-out can
## apply: "(entry 54-65 above is unaffected)".
static func enemy_count_bonus(campaign: Variant, step_id: String = "") -> int:
	if not is_enabled():
		return 0
	var state: Dictionary = get_state(campaign)
	var step: Dictionary = state.get("step", {}) if state.get("step", {}) is Dictionary else {}
	var fighting: String = step_id if not step_id.is_empty() else str(step.get("id", ""))

	var bonus: int = 0
	var exempt: bool = false
	if not fighting.is_empty():
		var row: Dictionary = step_by_id(fighting)
		exempt = bool(row.get("exempt_from_permanent_enemy_bonus", false))
		if fighting == str(step.get("id", "")):
			bonus += int(step.get("battle_enemy_bonus", 0))
	if not exempt:
		bonus += int(state.get("enemy_bonus", 0))
	return bonus


## -1 per p.79 row 93-100, permanently, plus -1 while row 21-28 is the pending
## fight. Returned as a POSITIVE reduction; the caller applies the sign its own
## convention wants (BattleSetupRules uses a negative `panic_range_delta`).
static func panic_reduction(campaign: Variant, step_id: String = "") -> int:
	if not is_enabled():
		return 0
	var state: Dictionary = get_state(campaign)
	var step: Dictionary = state.get("step", {}) if state.get("step", {}) is Dictionary else {}
	var fighting: String = step_id if not step_id.is_empty() else str(step.get("id", ""))
	var reduction: int = int(state.get("panic_reduction", 0))
	if not fighting.is_empty() and fighting == str(step.get("id", "")):
		reduction += int(step.get("battle_panic_reduction", 0))
	return reduction


## Everything a Quest battle needs stamped onto its mission_data, in one call, so
## the "the mission carries its own identity" rule holds for this chapter too.
## Empty when the chapter is off, so the caller can merge unconditionally.
static func mission_stamp(campaign: Variant) -> Dictionary:
	if not is_enabled():
		return {}
	var step: Dictionary = get_pending_step(campaign)
	var step_id: String = str(step.get("id", ""))
	var stamp: Dictionary = {
		"quest_enemy_bonus": enemy_count_bonus(campaign, step_id),
		"quest_panic_reduction": panic_reduction(campaign, step_id),
	}
	if step_id.is_empty():
		return stamp
	stamp["quest_step_id"] = step_id
	stamp["quest_step_instruction"] = str(step.get("instruction", ""))
	if step.has("mission_objective"):
		stamp["quest_step_objective"] = str(step["mission_objective"])
	if step.has("enemy_ai"):
		stamp["quest_force_enemy_ai"] = str(step["enemy_ai"])
	if step.has("enemy_table"):
		stamp["quest_enemy_table"] = str(step["enemy_table"])
	if step.has("survival_target"):
		stamp["quest_survival_target"] = int(step["survival_target"])
	return stamp


## The Conclusion's own battle rules (p.80), for the finale stamp.
static func conclusion_rules() -> Dictionary:
	var c: Dictionary = MissionsExpandedRef.QUEST_CONCLUSION
	return c.duplicate(true) if c is Dictionary else {}
