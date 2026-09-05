class_name CrewCreationMethods
extends RefCounted

## The four crew-creation methods — Core Rules p.13, "CREW COMPOSITION / Selecting Your
## Crew". Static SSOT: the caps live here and nowhere else, so the wizard's dropdowns,
## its validation gate and any future randomiser cannot drift from each other.
##
## Book text, verbatim (PDF index 12 -> printed p.13; the Core Rules offset is index
## PLUS one, verified at four independent points):
##
##   First-timer Method  "start with a crew of 6 Human characters, or use the example
##                        crew at the end of this chapter."
##   Standard Method     "You receive 6 crew figures: 3 are always Human. 2 may be Human
##                        or a Primary Alien, according to your choice. 1 may be a Human
##                        or Bot, according to your choice. If you have opted for a
##                        reduced crew size (see page 63), you may still select up to
##                        1 Bot and 2 Primary Aliens."
##   Miniatures Method   "Select 6 miniatures you would like to play with from your
##                        collection... This option allows you to have any combination of
##                        Primary Aliens, Bots, or Humans that matches your selected
##                        miniature figures."
##   Random Method       "You receive 6 crew figures. Roll on the Crew Type Tables below
##                        for each position."
##
## ⚠ THE MINIATURES METHOD IS WHY FREE SPECIES CHOICE NEEDS NO HOUSE-RULE LABEL. Before
## this file the wizard let a player pick any species for any slot, and the audit row
## (RULES_WIRING_AUDIT_2026-08.md) recorded the p.13 methods as "OPEN by choice" — a
## product decision. Reading the page settles it instead: "any combination of Primary
## Aliens, Bots, or Humans" IS a book method. What was actually missing was the CHOICE,
## and the constraints the other three methods impose.
##
## ⚠ STANDARD IS EXPRESSED AS CAPS, NOT SLOTS, and that is deliberate. Written as slots
## ("3 are always Human") the reduced-crew clause on the same page becomes a special
## case; written as caps (<=2 Primary Aliens, <=1 Bot, no Strange Characters) the SAME
## rule covers both, because at the full 6 figures "3 are always Human" is exactly what
## 6 - 2 - 1 leaves. The book states the reduced case in those very terms: "you may still
## select up to 1 Bot and 2 Primary Aliens."
##
## ⚠ STRANGE CHARACTERS ARE REACHABLE ONLY BY THE RANDOM METHOD, by rolling 91-100 on the
## p.14 Crew Type Table. No other method lists them. That is the book's own scarcity
## control, and it is why a flat randi() pick over all species was a defect (see
## CLAUDE.md, the p.14 Crew Type Tables fix: randomised crews came out ~69% Strange
## against a book value of 10%).

enum Method {
	FIRST_TIMER,
	STANDARD,
	MINIATURES,
	RANDOM,
}

## Category ids exactly as the p.14 Crew Type Tables produce them
## (data/character_species.json -> crew_type_tables.crew_type[].category).
const CAT_HUMAN := "baseline_human"
const CAT_PRIMARY_ALIEN := "primary_alien"
const CAT_BOT := "bot"
const CAT_STRANGE := "strange_character"

## Standard Method caps (p.13). Anything that is not an alien or a bot is Human.
const STANDARD_MAX_PRIMARY_ALIENS := 2
const STANDARD_MAX_BOTS := 1

const _METHOD_IDS := {
	Method.FIRST_TIMER: "first_timer",
	Method.STANDARD: "standard",
	Method.MINIATURES: "miniatures",
	Method.RANDOM: "random",
}

const _METHOD_NAMES := {
	Method.FIRST_TIMER: "First-timer",
	Method.STANDARD: "Standard",
	Method.MINIATURES: "Miniatures",
	Method.RANDOM: "Random",
}

const _METHOD_BLURBS := {
	Method.FIRST_TIMER: "A crew of all Humans. Fewest rules to track while you learn.",
	Method.STANDARD: "Up to 2 Primary Aliens and 1 Bot; the rest Human.",
	Method.MINIATURES: "Any mix of Humans, Primary Aliens and Bots - build to match the miniatures you own.",
	Method.RANDOM: "Roll every crew member on the Crew Type Table. The only method that can produce a Strange Character.",
}


static func all_methods() -> Array:
	return [Method.FIRST_TIMER, Method.STANDARD, Method.MINIATURES, Method.RANDOM]


static func method_id(method: int) -> String:
	return String(_METHOD_IDS.get(method, "miniatures"))


static func method_name(method: int) -> String:
	return String(_METHOD_NAMES.get(method, "Miniatures"))


static func method_blurb(method: int) -> String:
	return String(_METHOD_BLURBS.get(method, ""))


## Round-trip an id from the saved campaign config back to the enum.
##
## An unknown id falls to MINIATURES - the least restrictive BOOK method - so a config
## written by a newer build can never make an existing crew retroactively illegal.
static func method_from_id(id: String) -> int:
	for m in _METHOD_IDS:
		if String(_METHOD_IDS[m]) == id:
			return int(m)
	return Method.MINIATURES


## Categories a player may PICK for a crew member under `method`.
## RANDOM returns an empty array: nothing is picked there, every position is rolled.
static func selectable_categories(method: int) -> Array:
	match method:
		Method.FIRST_TIMER:
			return [CAT_HUMAN]
		Method.STANDARD, Method.MINIATURES:
			return [CAT_HUMAN, CAT_PRIMARY_ALIEN, CAT_BOT]
		_:
			return []


## The p.14 category for a species id, resolved from the shipped species data so this
## file never carries a second copy of the species list.
static func category_for_species(species_id: String) -> String:
	var id := species_id.strip_edges().to_lower()
	if id.is_empty() or id == "human":
		return CAT_HUMAN
	if id == "bot":
		return CAT_BOT
	for row in _subtable("primary_alien"):
		if String((row as Dictionary).get("species_id", "")) == id:
			return CAT_PRIMARY_ALIEN
	for row in _subtable("strange_character"):
		if String((row as Dictionary).get("species_id", "")) == id:
			return CAT_STRANGE
	# An unrecognised id is NOT silently treated as Human: that would let an unknown
	# species slip past the Standard caps. Report it as Strange, the one category no
	# pick-based method admits, so the validator surfaces it instead of swallowing it.
	return CAT_STRANGE


## Book violations for a finished crew. An empty array means legal.
##
## `members` may hold Character resources or the crew dictionaries a campaign stores;
## both are read through the same species accessor, because the wizard hands over
## Characters while a loaded save hands over dictionaries.
static func validate(members: Array, method: int,
		campaign_crew_size: int = 6) -> Array:
	var errors: Array = []
	var counts := {CAT_HUMAN: 0, CAT_PRIMARY_ALIEN: 0, CAT_BOT: 0, CAT_STRANGE: 0}
	for m in members:
		var cat := category_for_species(species_of(m))
		counts[cat] = int(counts[cat]) + 1

	match method:
		Method.FIRST_TIMER:
			var non_human: int = members.size() - int(counts[CAT_HUMAN])
			if non_human > 0:
				errors.append("First-timer Method: every crew member must be Human "
					+ "(p.13) - %d of %d are not" % [non_human, campaign_crew_size])
		Method.STANDARD:
			if int(counts[CAT_PRIMARY_ALIEN]) > STANDARD_MAX_PRIMARY_ALIENS:
				errors.append("Standard Method: at most %d Primary Aliens (p.13) - have %d"
					% [STANDARD_MAX_PRIMARY_ALIENS, int(counts[CAT_PRIMARY_ALIEN])])
			if int(counts[CAT_BOT]) > STANDARD_MAX_BOTS:
				errors.append("Standard Method: at most %d Bot (p.13) - have %d"
					% [STANDARD_MAX_BOTS, int(counts[CAT_BOT])])
			if int(counts[CAT_STRANGE]) > 0:
				errors.append("Standard Method: Strange Characters are reachable only by "
					+ "the Random Method (p.13-14) - have %d" % int(counts[CAT_STRANGE]))
		Method.MINIATURES:
			if int(counts[CAT_STRANGE]) > 0:
				errors.append("Miniatures Method: any mix of Humans, Primary Aliens and "
					+ "Bots (p.13); Strange Characters are Random-only - have %d"
					% int(counts[CAT_STRANGE]))
		Method.RANDOM:
			pass  # Every position was rolled; there is nothing for a player to get wrong.
	return errors


## Correct a rolled crew so it satisfies , returning the species ids to use.
##
## Needed because the caps are CREW-level while species are rolled ONE character at a
## time: a single roll cannot know it is the third Primary Alien. CharacterCreator rolls
## each member on the p.14 table, then the panel passes the whole crew through here.
##
## Excess picks become Human, which is what the book itself does with the slots it does
## not spend: Standard is "3 are always Human" plus at most 2 aliens and 1 bot, so a
## fourth alien has no slot to occupy other than a Human one. Order is preserved and the
## EARLIEST picks are kept, so a player who deliberately placed an alien first does not
## lose it to a later roll.
##
## RANDOM and MINIATURES return the input untouched - the first because every position is
## rolled by the book, the second because it allows any combination of the three types.
static func coerce_to_method(species_ids: Array, method: int) -> Array:
	var out: Array = []
	if method == Method.RANDOM or method == Method.MINIATURES:
		for s in species_ids:
			out.append(str(s))
		return out
	if method == Method.FIRST_TIMER:
		for _s in species_ids:
			out.append("human")
		return out
	# STANDARD
	var aliens := 0
	var bots := 0
	for s in species_ids:
		var id := str(s)
		match category_for_species(id):
			CAT_PRIMARY_ALIEN:
				aliens += 1
				out.append(id if aliens <= STANDARD_MAX_PRIMARY_ALIENS else "human")
			CAT_BOT:
				bots += 1
				out.append(id if bots <= STANDARD_MAX_BOTS else "human")
			CAT_HUMAN:
				out.append(id)
			_:
				# Strange Characters are Random-only (p.13-14); under Standard the slot
				# is a Human one.
				out.append("human")
	return out


## Species id from either a Character resource or a crew dictionary.
##
## ⚠ `str()`-wrapped on purpose: legacy saves store `origin` as a NUMBER (int far more
## often than float - 69 of 132 values across 21 real saves), and any string operation on
## a float hard-errors and ABORTS the enclosing function. Prefer species_id, which is
## always a String where it is present.
static func species_of(member: Variant) -> String:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("species_id", d.get("origin", ""))).to_lower()
	if member is Object:
		var o: Object = member
		if o != null:
			if "species_id" in o and str(o.get("species_id")) != "":
				return str(o.get("species_id")).to_lower()
			if "origin" in o:
				return str(o.get("origin")).to_lower()
	return ""


static func _subtable(name: String) -> Array:
	var f := FileAccess.open("res://data/character_species.json", FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return []
	var tables: Variant = (parsed as Dictionary).get("crew_type_tables", {})
	if not (tables is Dictionary):
		return []
	var rows: Variant = (tables as Dictionary).get(name, [])
	return rows if rows is Array else []
