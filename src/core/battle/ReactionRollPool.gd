class_name FPCM_ReactionRollPool
extends RefCounted

## The Reaction Roll as the book actually describes it (Core Rules p.113).
##
## THE GAP THIS FILLS, in three parts:
##
## 1. IT IS A POOL, NOT A PER-FIGURE ROLL. p.113: "Roll a number of D6 equal to
##    the number of your characters. ASSIGN EACH OF THE DICE RESULTS to one of
##    your characters." Which die goes to whom is the player's decision and the
##    round's main tactical choice. The app rolled one die per figure and pinned
##    it there, removing the decision entirely.
##
## 2. THE APP ROLLED TWICE, AND THE TWO ROLLS DISAGREED.
##    _assign_crew_reaction_slots() rolled and set react_slot (which drives the
##    Quick/Slow rails). _on_roll_reactions_pressed() — the button the player
##    actually presses — rolled AGAIN, wrote initiative_roll, logged that second
##    result, and never touched react_slot. So the numbers the player was shown
##    were not the numbers the app acted on.
##
## 3. THE FERAL RULE WAS MISSING. p.113 "Feral Impetuous Actions": "If your crew
##    has a Feral character, and you roll exactly a single 1 on your Initiative
##    dice, it must be assigned to a Feral character. This rule does not apply if
##    you roll multiple 1s." Nothing anywhere implemented it. (SeizeInitiative's
##    has_feral flag is a DIFFERENT rule, p.112.)
##
## Pure and RefCounted: no tree, no autoloads, dice injected. Every rule here is
## unit-testable without standing up a battle.

## A figure eligible for a die. `reactions` is its Reaction score; `is_feral`
## drives the p.113 Impetuous Actions constraint.
## Shape: {"id": String, "name": String, "reactions": int, "is_feral": bool}

const SLOT_QUICK := 1
const SLOT_SLOW := 2


static func roll_pool(figure_count: int, dice_roller: Callable = Callable()) -> Array[int]:
	## p.113: "Roll a number of D6 equal to the number of your characters."
	var out: Array[int] = []
	for _i in range(maxi(0, figure_count)):
		if dice_roller.is_valid():
			out.append(clampi(int(dice_roller.call()), 1, 6))
		else:
			out.append(randi_range(1, 6))
	return out


## Who gets a Reaction die, as each book counts it.
##   Core Rules p.113: one die per character.
##   Bug Hunt p.173 and p.198: one die per main character and one per combat team, "and
##     every figure in a given combat team acts in the same phase".
##   Planetfall pp.29-30: one die per character and one per grunt fireteam, plus one more
##     die for each scientist ("Quick Thinking"). Those extra dice give no one a second
##     action: "After assigning one die to each character, any excess dice are discarded."
##
## members: [{"id", "name", "reactions", "is_feral", "team" (0 = not in a team),
##   "is_scientist"}], one per figure on the screen.
## stand_ins: [{"id", "name", "reactions", "size"}] for figures the screen does not hold
##   (Planetfall's fireteams are not tracked as units).
## Returns {"figures": Array (pass to auto_assign), "dice": int,
##   "figure_of": {member_id: figure_id}}. A team takes its first member's Reactions:
##   every grunt shares one profile.
static func build_figures(members: Array, stand_ins: Array = []) -> Dictionary:
	var figures: Array = []
	var figure_of: Dictionary = {}
	var team_index: Dictionary = {}
	var extra_dice: int = 0
	for m: Variant in members:
		if not (m is Dictionary):
			continue
		var mid: String = str(m.get("id", ""))
		var team: int = int(m.get("team", 0))
		if team > 0:
			var fid: String = "team_%d" % team
			if not team_index.has(fid):
				team_index[fid] = figures.size()
				figures.append({"id": fid, "name": "Combat Team %d" % team,
					"reactions": int(m.get("reactions", 1)), "is_feral": false, "team": team,
					"size": 0})
			figures[int(team_index[fid])]["size"] += 1
			figure_of[mid] = fid
		else:
			figures.append({"id": mid, "name": str(m.get("name", "")),
				"reactions": int(m.get("reactions", 1)),
				"is_feral": bool(m.get("is_feral", false))})
			figure_of[mid] = mid
		if bool(m.get("is_scientist", false)):
			extra_dice += 1
	for s: Variant in stand_ins:
		if s is Dictionary:
			var fig: Dictionary = (s as Dictionary).duplicate()
			fig["is_feral"] = false
			figures.append(fig)
	return {"figures": figures, "dice": figures.size() + extra_dice, "figure_of": figure_of}


static func has_feral(figures: Array) -> bool:
	for f in figures:
		if f is Dictionary and bool((f as Dictionary).get("is_feral", false)):
			return true
	return false


static func feral_die_required(dice: Array, figures: Array) -> bool:
	## True when p.113's Impetuous Actions constraint is live: the crew includes a
	## Feral AND the pool contains EXACTLY ONE 1. "This rule does not apply if you
	## roll multiple 1s" — so two 1s releases the constraint entirely.
	if not has_feral(figures):
		return false
	var ones: int = 0
	for d in dice:
		if int(d) == 1:
			ones += 1
	return ones == 1


static func auto_assign(dice: Array, figures: Array) -> Dictionary:
	## A sensible default the player can then change: put as many figures as
	## possible into Quick Actions.
	##
	## Greedy, and provably optimal for this problem. Sort figures by Reactions
	## ASCENDING and dice ASCENDING, then give each figure the smallest die that
	## still clears its score. A figure with Reactions 1 can only ever use a 1, so
	## serving the pickiest first never costs a later figure a die it could have
	## used.
	##
	## Returns {figure_id: die_value}.
	var assignment: Dictionary = {}
	if figures.is_empty():
		return assignment

	var pool: Array[int] = []
	for d in dice:
		pool.append(int(d))
	pool.sort()

	var order: Array = figures.duplicate()
	order.sort_custom(func(a, b):
		return int(a.get("reactions", 1)) < int(b.get("reactions", 1)))

	# p.113 Feral: the lone 1 is spoken for before anything else can claim it.
	var feral_locked: bool = false
	if feral_die_required(dice, figures):
		for f in order:
			if bool(f.get("is_feral", false)):
				assignment[str(f.get("id", ""))] = 1
				pool.erase(1)
				feral_locked = true
				break

	for f in order:
		var fid: String = str(f.get("id", ""))
		if assignment.has(fid):
			continue
		if pool.is_empty():
			break
		var reactions: int = int(f.get("reactions", 1))
		var chosen: int = -1
		for d in pool:
			if d <= reactions:
				chosen = d
				break
		# Nothing clears this figure's score, so it is going Slow regardless —
		# give it the LARGEST die and leave the small ones for figures that can
		# still use them.
		if chosen < 0:
			chosen = pool[pool.size() - 1]
		assignment[fid] = chosen
		pool.erase(chosen)

	if feral_locked:
		pass  # already recorded above
	return assignment


static func slot_for(die_value: int, reactions: int) -> int:
	## p.113: "Any character assigned a die result equal or below their Reaction
	## score will act in the Quick Actions phase... Characters that were assigned
	## a die result higher than their Reaction score will act in the Slow Actions
	## phase."
	return SLOT_QUICK if int(die_value) <= int(reactions) else SLOT_SLOW


static func validate(assignment: Dictionary, dice: Array, figures: Array) -> Dictionary:
	## Check a player-edited assignment against the book. Returns
	## {"valid": bool, "error": String}.
	##
	## Two things can go wrong: the assignment stops being a permutation of the
	## rolled pool (a die invented or used twice), or it breaks the Feral rule.
	var used: Array[int] = []
	for fid in assignment.keys():
		used.append(int(assignment[fid]))
	var pool: Array[int] = []
	for d in dice:
		pool.append(int(d))
	used.sort()
	pool.sort()

	if used.size() > pool.size():
		return {"valid": false, "error": "More dice assigned than were rolled."}
	var remaining: Array[int] = pool.duplicate()
	for u in used:
		if not remaining.has(u):
			return {"valid": false,
				"error": "A die value was assigned that is not in the rolled pool."}
		remaining.erase(u)

	if feral_die_required(dice, figures):
		var feral_has_one: bool = false
		for f in figures:
			if not bool(f.get("is_feral", false)):
				continue
			if int(assignment.get(str(f.get("id", "")), -1)) == 1:
				feral_has_one = true
				break
		if not feral_has_one:
			return {"valid": false,
				"error": "Core Rules p.113: a single rolled 1 must go to a Feral character."}

	return {"valid": true, "error": ""}
