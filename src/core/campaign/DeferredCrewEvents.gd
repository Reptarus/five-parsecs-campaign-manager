extends RefCounted
## The Trade and Explore results that pay off later (Core Rules pp.79-81), held in
## campaign.progress_data["pending_events"] and spent at the hook each one names.
##
## Before 2026-10-29 twelve rows were cached there and nothing read them back, except a
## turn-start popup that ran on the first turn of a session only, applied an effect whose
## numbers were all 0, and then DELETED the event. A crew member who found Basic
## supplies, Insider information or a Military fuel cell got nothing for it.
##
## Where each one is spent:
##   Local maps                 ResolveRumorsComponent, when a Quest is received
##   Luxury trinket             CrewTaskComponent, a Recruit roll (+2)
##   Basic supplies             UpkeepPhaseComponent, the Upkeep bill
##   Trade goods                UpkeepPhaseComponent, each world arrival (offered)
##   Military fuel cell         UpkeepPhaseComponent, the cost of a jump
##   Insider information        CrewTaskComponent, a Find a Patron roll
##   Package delivered          UpkeepPhaseComponent, the next world arrival
##   Promising lead             PaymentProcessor, an Opportunity mission's pay step
##   You make a useful contact  CrewTaskComponent, a Recruit, Patron or Track roll (+1)
##
## Each row's window comes from its printed wording, counted in completed turns
## (progress_data.turns_played, one behind the turn in progress):
##   "this campaign turn"           live only during the turn it was found
##   "next campaign turn"           live only during the following turn
##   "this or the following world"  live until the second arrival after it
##   no wording                     live until spent
## Crew tasks resolve in one pass, so a "next campaign turn" row found by an Explore task
## must not be spent by a Find a Patron roll later in that same pass. Hence a window,
## not just an expiry.

const KEY := "pending_events"

## [first turn live, last turn live] as offsets from the turn the row was found; a last
## turn of -1 means it stays until spent.
const WINDOWS := {
	"Promising lead": [0, 0],
	"Offered a small job": [0, 0],
	"Offered a reward": [0, 0],
	"Insider information": [1, 1],
	"You make a useful contact": [1, 1],
	# Upkeep is paid before crew tasks in the World Phase, so the turn the supplies
	# were found has already paid its bill.
	"Basic supplies": [1, -1],
}

## Arrivals a row survives after the world it was found on.
const WORLDS := {"Local maps": 1}


## Write the row's window onto a freshly cached event.
static func stamp(event: Dictionary, turns_played: int) -> void:
	var event_name: String = str(event.get("event_name", ""))
	var window: Array = WINDOWS.get(event_name, [0, -1])
	event["found_after_turn"] = turns_played
	event["live_from"] = turns_played + int(window[0])
	event["live_until"] = turns_played + int(window[1]) if int(window[1]) >= 0 else -1
	if WORLDS.has(event_name):
		event["arrivals_left"] = int(WORLDS[event_name])


static func is_live(event: Dictionary, turns_played: int) -> bool:
	if bool(event.get("consumed", false)):
		return false
	if not event.has("live_from"):
		# Cached before windows existed. A row bound to a turn has had its turn.
		var window: Array = WINDOWS.get(str(event.get("event_name", "")), [0, -1])
		return int(window[1]) < 0
	var until: int = int(event.get("live_until", -1))
	return turns_played >= int(event.get("live_from", 0)) \
		and (until < 0 or turns_played <= until)


## Every live event of that name, oldest first. Read-only.
static func live(pd: Dictionary, event_name: String, turns_played: int) -> Array:
	var out: Array = []
	for e: Variant in pd.get(KEY, []):
		if e is Dictionary and str(e.get("event_name", "")) == event_name \
				and is_live(e, turns_played):
			out.append(e)
	return out


## Spend the oldest live event of that name and return it; {} when there is none.
static func take(pd: Dictionary, event_name: String, turns_played: int) -> Dictionary:
	var events: Array = pd.get(KEY, [])
	for i in events.size():
		var e: Variant = events[i]
		if e is Dictionary and str(e.get("event_name", "")) == event_name \
				and is_live(e, turns_played):
			events.remove_at(i)
			pd[KEY] = events
			return e
	return {}


## Spend every live event of that name; oldest first.
static func take_all(pd: Dictionary, event_name: String, turns_played: int) -> Array:
	var taken: Array = []
	var kept: Array = []
	for e: Variant in pd.get(KEY, []):
		if e is Dictionary and str(e.get("event_name", "")) == event_name \
				and is_live(e, turns_played):
			taken.append(e)
		else:
			kept.append(e)
	if not taken.is_empty():
		pd[KEY] = kept
	return taken


## A world arrival ages the "this or the following world" rows.
static func on_arrival(pd: Dictionary) -> void:
	if not pd.has(KEY):
		return
	var kept: Array = []
	for e: Variant in pd.get(KEY, []):
		if e is Dictionary and e.has("arrivals_left"):
			var left: int = int(e["arrivals_left"]) - 1
			if left < 0:
				continue
			e["arrivals_left"] = left
		kept.append(e)
	pd[KEY] = kept


## Drop the rows whose window has closed, so the save does not keep dead events.
static func prune(pd: Dictionary, turns_played: int) -> void:
	if not pd.has(KEY):
		return
	var kept: Array = []
	for e: Variant in pd.get(KEY, []):
		if not (e is Dictionary):
			continue
		var until: int = int(e.get("live_until", -1))
		var closed: bool = bool(e.get("consumed", false)) \
			or (e.has("live_from") and until >= 0 and turns_played > until) \
			or (not e.has("live_from") and not is_live(e, turns_played))
		if not closed:
			kept.append(e)
	pd[KEY] = kept


## Which held bonuses to spend on a crew-task roll, and the roll they make.
##
## `thresholds` are the results that change what the roll gives (Find a Patron: 5 for one
## job, 6 for two; Recruit and Track: 6). A bonus is spent only when it reaches a
## threshold the roll would otherwise miss, and the cheapest combination that gets there
## is chosen, so a +1 is never burned on a roll that succeeds without it or fails with it.
## Insider information is "a Patron, automatically", so on a Find a Patron roll it counts
## as reaching the first threshold and is spent only when the dice do not get there.
static func plan_roll_bonus(task_id: String, roll: int, thresholds: Array,
		contact: bool, trinket: bool, insider: bool) -> Dictionary:
	var plan := {"contact": false, "trinket": false, "insider": false, "roll": roll}
	if thresholds.is_empty():
		return plan
	var insider_usable: bool = insider and task_id == "find_patron"
	var trinket_usable: bool = trinket and task_id == "recruit"
	var floor_tier: int = 1 if insider_usable else 0
	var current: int = maxi(_tier(roll, thresholds), floor_tier)
	# Cheapest first: [bonus, spends the contact, spends the trinket].
	var options: Array = []
	if contact:
		options.append([1, true, false])
	if trinket_usable:
		options.append([2, false, true])
	if contact and trinket_usable:
		options.append([3, true, true])
	var best: int = current
	for o: Array in options:
		best = maxi(best, _tier(roll + int(o[0]), thresholds))
	if best > current:
		for o: Array in options:
			if _tier(roll + int(o[0]), thresholds) == best:
				plan["roll"] = roll + int(o[0])
				plan["contact"] = bool(o[1])
				plan["trinket"] = bool(o[2])
				break
	if insider_usable and int(plan["roll"]) < int(thresholds.min()):
		plan["roll"] = int(thresholds.min())
		plan["insider"] = true
	return plan


static func _tier(roll: int, thresholds: Array) -> int:
	var n: int = 0
	for t: Variant in thresholds:
		if roll >= int(t):
			n += 1
	return n
