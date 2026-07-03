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

## Win-condition summary per objective type (Core Rules p.90,
## verbatim-condensed) — shown on the Battle Card so the player knows what
## "winning" means before building the table.
static func objective_win_text(objective: String) -> String:
	match objective.to_lower().strip_edges():
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
