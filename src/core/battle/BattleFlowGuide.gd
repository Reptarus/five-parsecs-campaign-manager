class_name FPCM_BattleFlowGuide
extends RefCounted

## Battle-journey guidance derivations — the fluid golden path's text source.
##
## Pure static lookups consumed by the EXISTING guidance surfaces
## (TacticalBattleUI's phase banner, phase-content cards, and the pre-battle
## Battle Card). Deliberately NOT a new tracking system and NOT a wizard:
## it derives short, page-cited instructions from state the battle UI
## already holds. All rule text is condensed transcription from the Core
## Rules PDF (extracted + verified 2026-07-02); nothing invented.

## Enemy setup spacing by AI type (Core Rules p.110, verbatim-condensed).
static func ai_setup_text(ai_type: String) -> String:
	match ai_type.to_upper():
		"A", "R":
			return "one cluster, 1\" between figures"
		"T", "D":
			return "3 teams, 8\" apart; team members 1-2\" apart"
		"C":
			return "2 groups, 6\" apart; members 1.5-2\" apart"
		"B":
			return "pairs — one per table third, 2\" between figures; " \
				+ "any odd figure sets up on its own"
		"G":
			return "attached to the figure it guards " \
				+ "(Lieutenant if present, else a random non-Specialist)"
		_:
			return "on the opposite battlefield edge"

## The p.110 deployment procedure as three player steps, with the active
## deployment condition's crew modifiers folded into step 3 (p.88).
static func deployment_steps(condition_id: String,
		enemy_ai: String) -> Array:
	var crew_note: String = ""
	match condition_id.to_upper():
		"DELAYED":
			crew_note = " Note: 2 random crew start off-table — at each " \
				+ "round's end, roll 1D6; they arrive at your edge if the " \
				+ "roll is at or below the round number (p.88)."
		"SMALL_ENCOUNTER":
			crew_note = " Note: 1 random crew member sits this battle " \
				+ "out (p.88)."
		"CAUGHT_OFF_GUARD":
			crew_note = " Note: your whole squad acts in the Slow " \
				+ "Actions phase in Round 1 (p.88)."
		"SURPRISE_ENCOUNTER":
			crew_note = " Note: the enemy cannot act in the first " \
				+ "round (p.88)."
	return [
		{
			"text": "Battlefield edges: randomly pick your entry edge — "
				+ "the enemy is always assigned the opposite edge.",
			"page_cite": "Core Rules p.110",
		},
		{
			"text": "Set up the enemy FIRST: %s." % ai_setup_text(enemy_ai),
			"page_cite": "Core Rules p.110",
		},
		{
			"text": "Set up your crew on your edge — no figures from "
				+ "opposing forces within 18\" of each other." + crew_note,
			"page_cite": "Core Rules p.110",
		},
	]

## Deployment-condition effects that must be resolved at the END of each
## round (Core Rules p.88) — the rolls players forget most. Conditions
## without a per-round effect return an empty Array.
static func build_round_end_prompts(condition_id: String) -> Array:
	match condition_id.to_upper():
		"BRIEF_ENGAGEMENT":
			return [{
				"id": "brief_engagement",
				"text": "Brief engagement: roll 2D6 — if the roll is at "
					+ "or below the round number, the game ends "
					+ "inconclusively.",
				"roll": "2D6",
				"page_cite": "Core Rules p.88",
			}]
		"DELAYED":
			return [{
				"id": "delayed",
				"text": "Delayed: roll 1D6 for the off-table crew — if "
					+ "the roll is at or below the round number, place "
					+ "them at any point of your own battlefield edge.",
				"roll": "1D6",
				"page_cite": "Core Rules p.88",
			}]
		"POOR_VISIBILITY":
			return [{
				"id": "poor_visibility",
				"text": "Poor visibility: reroll the visibility limit — "
					+ "1D6+8\".",
				"roll": "1D6",
				"page_cite": "Core Rules p.88",
			}]
		_:
			return []

## Red Job Time Constraint (Core Rules p.149), verbatim: "All Red Jobs are fought
## under a time constraint. AT THE END OF ROUND 6, roll 1D6 on the table below."
##
## THE GAP THIS FILLS: `RedZoneSystem.roll_time_constraint()` was written, correct,
## and had ZERO callers — a Red Zone battle simply ran to its natural end. The only
## `roll_time_constraint()` with a caller is a DIFFERENT function on
## `compendium_missions_expanded.gd`, for Expanded Missions, reached from
## JobOfferComponent. Grepping the NAME finds a live call and proves nothing; the
## two are unrelated tables on unrelated classes.
##
## Unlike the Threat Condition this cannot be stamped at mission acceptance — the
## book fixes it to a ROUND — so it needs this round-aware hook.
##
## `state` carries what has already happened this battle:
##   rolled       bool  the round-6 D6 has been made
##   effect       String the `effect` key off the p.149 row
##   countdown_at int   current Count Down threshold (1 on the first check, then
##                      2, 3 ... as "the Battle ends on a 1-2, then 1-3")
const RED_JOB_CONSTRAINT_ROUND := 6

## Called AFTER the app has resolved the roll, so the prompt reports the outcome
## and the table instruction rather than asking for a roll the app already made.
## That is the house pattern: DiceManager rolls, the companion tells the player
## what to do with their figures.
static func build_red_job_round_prompts(
	round_number: int, is_red_zone: bool, state: Dictionary
) -> Array:
	if not is_red_zone:
		return []
	var out: Array = []

	# Before Round 6, warn that the clock is coming — the whole point of a time
	# constraint is that the player plans around it.
	if not bool(state.get("rolled", false)):
		if round_number > 0 and round_number < RED_JOB_CONSTRAINT_ROUND:
			out.append({
				"id": "red_job_time_constraint_pending",
				"text": "RED JOB: a Time Constraint is rolled at the end of Round"
					+ " %d (%d round(s) away)."
					% [RED_JOB_CONSTRAINT_ROUND,
						RED_JOB_CONSTRAINT_ROUND - round_number],
				"page_cite": "Core Rules p.149",
			})
		return out

	# The rolled result, restated every round afterwards: a reinforcement wave the
	# player is meant to place is not a one-time notice.
	var name: String = str(state.get("name", ""))
	var desc: String = str(state.get("description", ""))
	if not name.is_empty():
		out.append({
			"id": "red_job_time_constraint",
			"text": "RED JOB TIME CONSTRAINT (rolled %d) — %s: %s"
				% [int(state.get("roll", 0)), name, desc],
			"page_cite": "Core Rules p.149",
		})

	# Count Down is the only row with a per-round clock, and it escalates.
	if str(state.get("effect", "")) == "countdown":
		var threshold: int = maxi(1, int(state.get("countdown_at", 1)))
		var range_text: String = "1" if threshold <= 1 else "1-%d" % threshold
		out.append({
			"id": "red_job_countdown",
			"text": "COUNT DOWN: the battle ends on a %s at the end of this round."
				% range_text,
			"roll": "1D6",
			"page_cite": "Core Rules p.149",
		})

	return out


## Black Job reinforcement + Active/Passive clock (Core Rules p.151).
##
## THE GAP THIS FILLS: `BlackZoneSystem.get_opposition_rules()`,
## `get_active_passive_rules()` and `get_ending_rules()` were all written, all
## byte-faithful to the book, and all had ZERO callers. The whole reason a Black
## Job plays differently from any other battle — a fresh 4-figure team walking on
## every single round, and Passive teams waking up — reached the player nowhere.
## `MissionPrepComponent` printed a hardcoded "4 teams of 4" string once, before
## deployment, and that was the entire delivery.
##
## Every clause below is quoted from p.151. This is a per-ROUND rule, so like the
## Red Job Time Constraint it cannot be stamped at mission acceptance.
##
## `won` drives the p.151 ending clause: "If you have Won, you will be evac'ed out
## at the end of the following round. Hang in there!" — which is a round the
## player must actually survive, not a formality.
static func build_black_job_round_prompts(
	round_number: int, is_black_zone: bool, won: bool = false
) -> Array:
	if not is_black_zone or round_number <= 0:
		return []
	var out: Array = []

	# "At the end of each round, another team arrives. Randomly select a neutral
	# battlefield edge, then place an entrance point 2D6" down that battlefield
	# edge, measuring from the opponent's edge. Place the figures 1D6" on to the
	# battlefield from the side. These teams enter the battlefield Passive."
	out.append({
		"id": "black_job_reinforcements",
		"text": "BLACK JOB: another 4-figure team arrives. Pick a random neutral "
			+ "edge, mark an entrance 2D6\" down it measuring from the opponent's "
			+ "edge, and place the figures 1D6\" onto the table from the side. "
			+ "They enter PASSIVE.",
		"roll": "2D6",
		"page_cite": "Core Rules p.151",
	})

	# "At the end of each round, assign a number to each Passive team on the
	# battlefield (just count from left to right). Roll 1D6. If the roll is a team
	# already on the board, it becomes Active. Otherwise nothing happens."
	out.append({
		"id": "black_job_passive_activation",
		"text": "Number the Passive teams left to right, then roll 1D6 — if the "
			+ "roll matches a team on the board, that team becomes ACTIVE. Passive "
			+ "teams also wake if fired upon, or if a crew figure comes within 8\".",
		"roll": "1D6",
		"page_cite": "Core Rules p.151",
	})

	if won:
		out.append({
			"id": "black_job_evac",
			"text": "OBJECTIVE COMPLETE — the evac lifts you out at the end of the "
				+ "FOLLOWING round. Hang in there: reinforcements keep arriving.",
			"page_cite": "Core Rules p.151",
		})

	return out


## Win-condition summary per objective type (Core Rules p.90,
## verbatim-condensed) — shown on the Battle Card so the player knows what
## "winning" means before building the table.
static func objective_win_text(objective: String) -> String:
	# Accept the display name as well as the snake_case id: callers reach this
	# from both a tracker id ("fight_off") and a human label ("Fight Off"), and
	# an unmatched key silently returns "" — a Battle Card row with no win
	# condition on it, which is exactly what a runtime walk found.
	match objective.to_lower().strip_edges().replace(" ", "_"):
		"access":
			return "Reach the console at the exact center and access it: " \
				+ "1D6+Savvy, 6+ (a Combat Action; up to two attempts per " \
				+ "round). Win once accessed."
		"acquire":
			return "Move into contact with the item at the center, take " \
				+ "a Combat Action to pick it up, then move off the table."
		"deliver":
			return "Carry the package to the exact center of the table — " \
				+ "placing it safely takes a Combat Action."
		"defend":
			return "Drive off the enemy — you Win by Holding the Field."
		"eliminate":
			return "Kill the marked target figure to Win."
		"fight_off":
			return "Drive off the enemy — you Win by Holding the Field."
		"move_through":
			return "Move at least 2 crew members off the opposing " \
				+ "battlefield edge."
		"patrol":
			return "End a move within 2\" of each of the 3 marked " \
				+ "terrain features."
		"protect":
			return "Your VIP must spend a full round within 3\" of the " \
				+ "table center (+2 credits if done within 4 rounds)."
		"secure":
			return "End 2 consecutive rounds with crew within 2\" of the " \
				+ "center — a crew member with an enemy within 6\" does " \
				+ "not count."
		"search":
			return "Search each marked feature (contact + a Combat " \
				+ "Action, 5+ finds it). Win when found."
		_:
			return ""
