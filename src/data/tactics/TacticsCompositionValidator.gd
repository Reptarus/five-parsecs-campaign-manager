class_name TacticsCompositionValidator
extends RefCounted

## TacticsCompositionValidator - Validates Tactics army roster composition
## Platoon org (1-2 leaders, 2-4 troops, 0-3 supports, 0-1 specialists per 2 troops),
## company org (2-4 platoons, leaders = platoon count).
## ⚠ THIS SUMMARY WAS STALE UNTIL 2026-09-06: it still recited the pre-fix numbers
## ("2-5 troops, 0-4 supports, 0-2 specialists") directly above the constants that had
## already been corrected on 2026-09-04. Whoever fixed the constants updated the block
## that JUSTIFIES them and not the one-line summary above it — so the file argued with
## itself, and the wrong half is the half a reader skims first. If you change a limit,
## change it here too.
## Source: Five Parsecs: Tactics **pp.134-135** — "Infantry Platoon Organization"
## and "Company Organization" in the Army Builder chapter (p.132; ToC p.5, index
## "Army Builder 61, 132").
## ⚠ CITE CORRECTED 2026-09-04 from "pp.81-88", which is the **Scenario Types**
## chapter (objectives + D100 tables).
##
## ⚠ ERRATA CHECKED 2026-09-04 — there is NONE for this rule. The repo errata
## (docs/gameplay/rules/5P_errata_and_tweaks106.pdf, v1.06) is CORE RULES only:
## zero occurrences of "Tactics", "platoon", "troops", "Support", "Army Builder"
## or "Campaign Point" across all 5 pages. The official Modiphius FAQ
## (modiphius.net/en-us/pages/five-parsecs-faq) covers only the core skirmish
## game. The designer's own Tactics post (nordicweasel.posthaven.com) changes
## combat only — activation, suppression, close combat, morale, Stun — not
## composition. The p.134 text was re-verified against the SOURCE PDF
## (docs/rules/Five Parsecs From Home - Tactics.pdf, index 135 = printed p.134;
## the Tactics PDF offset is index MINUS one) and matches the text extraction
## word for word. So the book stands and the constants below are simply wrong —
## most likely Age of Fantasy values carried over by the "complete rewrite of
## AoF rules" this file describes, never re-checked against Five Parsecs.
##
## ✅ FIXED 2026-09-04 against p.134, verbatim from docs/rules/tactics_source.txt
## (raw marker 136 -> printed 134; the Tactics extract offset is marker MINUS two,
## confirmed here by the "=== PAGE 137 ===" marker immediately preceding printed 135):
##
##   "Leaders (1-2)"   - "A platoon must have one character, and may include a second."
##   "Troops (2-4)"    - "A platoon must have 2 squads, and may take a total of 4."
##   "Supports (0-3; must be fewer than number of Troops)"
##   "Specialists (0-1 per 2 Troops)"
##
## ⚠ WHERE THE OLD NUMBERS CAME FROM. They were not arbitrary: Leader 1, Troops 2-5 and
## Supports 0-4 are exactly the **Armored Platoon** optional rule on p.135 -
## "Leader (1): One vehicle. Troops (2-5): Each troop is a vehicle... Supports (0-4, must
## be fewer in number than troops)". One organisation's limits had been applied to a
## different one. The armored platoon is NOT modelled here (TacticsRoster.OrgType has
## PLATOON and COMPANY only), and it should not be bolted onto the infantry limits: the
## book gives it different units ("There are no weapon teams or specialists in an armored
## platoon"), a same-type constraint on its first 3 vehicles, and mandatory transports for
## its supports. Adding it is a roster-model change, recorded here rather than improvised.
##
## ⚠ ONE CLAIM IN THE OLD NOTE WAS WRONG and is corrected rather than deleted: it said the
## "must be fewer than Troops" clause was "stated in the comment but never enforced - the
## check is a flat compare". There are TWO checks, and the relational one was always live
## (`support_count >= troop_count`, below). Only the flat cap was wrong.
##
## ⚠ ERRATA CHECKED 2026-09-04 - there is NONE for this rule. The repo errata
## (docs/gameplay/rules/5P_errata_and_tweaks106.pdf, v1.06) is CORE RULES only: zero
## occurrences of "Tactics", "platoon", "troops", "Support" or "Army Builder" across all
## 5 pages. The official Modiphius FAQ covers only the core skirmish game, and the
## designer's Tactics post changes combat only, not composition.

# Platoon constraints (per-platoon) - Tactics p.134, "Infantry Platoon Organization"
const MIN_TROOPS_PER_PLATOON := 2       # "must have 2 squads"
const MAX_TROOPS_PER_PLATOON := 4       # "may take a total of 4"
const MAX_SUPPORTS_PER_PLATOON := 3     # "Supports (0-3 ...)" - AND fewer than Troops
const MIN_PLATOON_LEADERS := 1          # "must have one character"
const MAX_PLATOON_LEADERS := 2          # "and may include a second"
## "Specialists (0-1 per 2 Troops)" - a RATIO, not a flat cap. The old flat 2 was right
## only at the maximum troop count and let a 2-troop platoon take two specialists where
## the book allows one.
const TROOPS_PER_SPECIALIST := 2


## Book cap on specialists for a platoon of `troop_count` squads (p.134).
static func max_specialists_for(troop_count: int) -> int:
	return maxi(0, troop_count) / TROOPS_PER_SPECIALIST

# Company constraints
const MIN_PLATOONS := 2
const MAX_PLATOONS := 4
const MAX_COMPANY_LEADERS := 4  # Max = platoon count
const MAX_COMPANY_SUPPORTS := 4  # Max = platoon count

# Points tiers
const POINTS_SMALL := 500
const POINTS_STANDARD := 750
const POINTS_LARGE := 1000

# Mixed army rule
const MAX_SPECIES_PICKUP := 2  # Pick-up games: max 2 species


## Validate a complete roster. Returns empty array if valid.
static func validate(roster: TacticsRoster) -> Array[String]:
	var errors: Array[String] = []

	if not roster.species_book:
		errors.append("No species book selected")
		return errors

	# Points check
	var total: int = roster.get_total_points()
	if total > roster.points_limit:
		errors.append("Over points limit: %d / %d" % [total, roster.points_limit])

	# Must have at least one entry
	if roster.entries.is_empty():
		errors.append("Roster is empty")
		return errors

	# Validate per org type
	match roster.org_type:
		TacticsRoster.OrgType.PLATOON:
			errors.append_array(_validate_platoon(roster, 0))
		TacticsRoster.OrgType.COMPANY:
			errors.append_array(_validate_company(roster))

	# Validate individual entries
	for i in range(roster.entries.size()):
		var entry: TacticsRosterEntry = roster.entries[i] as TacticsRosterEntry
		if entry:
			var entry_errors: Array[String] = entry.validate()
			for err in entry_errors:
				errors.append("Entry %d (%s): %s" % [i + 1, entry.get_display_name(), err])

	return errors


## Validate a single platoon within the roster
static func _validate_platoon(roster: TacticsRoster, platoon_idx: int) -> Array[String]:
	var errors: Array[String] = []

	var troop_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.TROOP, platoon_idx)
	var support_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.SUPPORT, platoon_idx)
	var specialist_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT, platoon_idx)
	var leader_count: int = roster.count_slot_in_platoon(
		TacticsUnitProfile.OrgSlot.LEADER, platoon_idx)

	var label: String = "Platoon %d" % (platoon_idx + 1)

	# Troops: 2-4 (p.134)
	if troop_count < MIN_TROOPS_PER_PLATOON:
		errors.append("%s: Need at least %d troop units (have %d)" % [
			label, MIN_TROOPS_PER_PLATOON, troop_count])
	if troop_count > MAX_TROOPS_PER_PLATOON:
		errors.append("%s: Max %d troop units (have %d)" % [
			label, MAX_TROOPS_PER_PLATOON, troop_count])

	# Supports: 0-3 AND strictly fewer than troops (p.134). Both clauses are
	# real and neither implies the other: 3 supports with 3 troops passes the
	# cap and fails the ratio; 4 supports with 5 troops does the reverse.
	if support_count > MAX_SUPPORTS_PER_PLATOON:
		errors.append("%s: Max %d support units (have %d)" % [
			label, MAX_SUPPORTS_PER_PLATOON, support_count])
	if support_count >= troop_count and troop_count > 0:
		errors.append("%s: Support count (%d) must be fewer than troop count (%d)" % [
			label, support_count, troop_count])

	# Specialists: 0-1 per 2 Troops (p.134). That RATIO is the whole rule.
	var specialist_cap: int = max_specialists_for(troop_count)
	if specialist_count > specialist_cap:
		errors.append("%s: Max %d specialist units for %d troops (have %d) - the book "
			% [label, specialist_cap, troop_count, specialist_count]
			+ "allows 1 specialist per 2 troops")

	## ⚠ DO NOT RE-ADD A DUPLICATE-SPECIALIST CHECK (deleted 2026-09-06).
	## A check here rejected two specialists sharing a `unit_id`, commented "one of each
	## type". It has NO textual basis and rejected legal armies. p.134 says only:
	##   "Specialists (0-1 per 2 Troops)" / "A platoon may have 1 specialist unit per
	##    2 troops selected."
	## The book states type-composition rules plainly when it has one, and the only two
	## places it does so near here both CONTRADICT the deleted check:
	##   p.134 Troops    - "The platoon does not have to consist of all the same type."
	##                     (an explicit permission to MIX, i.e. the opposite restriction)
	##   p.135 Armored   - "The first 3 vehicles selected for this section must be the
	##                     same type" (a same-type REQUIREMENT, and inverted at that)
	## ⭐ WHERE IT CAME FROM: `TacticsRoster.gd` records that this rewrite "Drops AoF
	## hero-per-375, 35% cap, **duplicate limit**, combined units" - so Age of Fantasy
	## had a duplicate limit, Tactics has none, and the "complete rewrite of AoF rules"
	## this file describes dropped it from the ROSTER and left it standing HERE. A rule
	## deleted in one file and kept in its sibling is the shape to watch for: the old
	## wrong constants had the same story (lifted from the p.135 Armored Platoon, see
	## the header), so this validator has now been contaminated by its AoF ancestry and
	## by the wrong page of its own book, once each.
	## Verified against docs/rules/tactics_source.txt raw 9138-9150 and 9206-9208
	## (Tactics offset = raw marker MINUS two, re-confirmed at marker 138 -> folio 136);
	## a repo-wide search of the book text for a duplicate/one-of-each restriction on
	## specialists returns ZERO hits.

	# Leaders: 1-2 per platoon (p.134)
	if leader_count < MIN_PLATOON_LEADERS:
		errors.append("%s: Needs a platoon leader" % label)
	if leader_count > MAX_PLATOON_LEADERS:
		errors.append("%s: Max %d leaders (have %d)" % [
			label, MAX_PLATOON_LEADERS, leader_count])

	return errors


## Validate company organization
static func _validate_company(roster: TacticsRoster) -> Array[String]:
	var errors: Array[String] = []

	# Company must have 2-4 platoons
	if roster.platoon_count < MIN_PLATOONS:
		errors.append("Company needs at least %d platoons (have %d)" % [
			MIN_PLATOONS, roster.platoon_count])
	if roster.platoon_count > MAX_PLATOONS:
		errors.append("Company max %d platoons (have %d)" % [
			MAX_PLATOONS, roster.platoon_count])

	# Validate each platoon
	for i in range(roster.platoon_count):
		errors.append_array(_validate_platoon(roster, i))

	# Company-level leaders: max = platoon count
	var company_leaders: int = 0
	for entry in roster.entries:
		if entry is TacticsRosterEntry:
			if entry.get_org_slot() == TacticsUnitProfile.OrgSlot.LEADER:
				if entry.platoon_index < 0:  # Company-level (not assigned to platoon)
					company_leaders += 1
	if company_leaders > roster.platoon_count:
		errors.append("Too many company leaders: %d (max %d = platoon count)" % [
			company_leaders, roster.platoon_count])

	# Company-level supports: max = platoon count
	var company_supports: int = 0
	for entry in roster.entries:
		if entry is TacticsRosterEntry:
			if entry.get_org_slot() == TacticsUnitProfile.OrgSlot.COMPANY_SUPPORT:
				company_supports += 1
	if company_supports > roster.platoon_count:
		errors.append("Too many company supports: %d (max %d = platoon count)" % [
			company_supports, roster.platoon_count])

	return errors


## Get a human-readable summary of composition limits for a given org type
static func get_limits_summary(org_type: int, points: int) -> String:
	var lines: Array[String] = []
	lines.append("Points: %d" % points)
	if org_type == TacticsRoster.OrgType.PLATOON:
		# These strings are what a player reads while building. They MUST be rendered
		# from the same constants the validator enforces - a displayed limit that exists
		# nowhere else is exactly how the p.134 mismatch survived unnoticed.
		lines.append("%d-%d Platoon Leaders" % [MIN_PLATOON_LEADERS, MAX_PLATOON_LEADERS])
		lines.append("%d-%d Troop units" % [MIN_TROOPS_PER_PLATOON, MAX_TROOPS_PER_PLATOON])
		lines.append("0-%d Support units (fewer than troops)" % MAX_SUPPORTS_PER_PLATOON)
		lines.append("Specialists: 1 per %d troops" % TROOPS_PER_SPECIALIST)
	else:
		lines.append("%d-%d Platoons" % [MIN_PLATOONS, MAX_PLATOONS])
		lines.append("Per platoon: same as above")
		lines.append("Company leaders: max = platoon count")
		lines.append("Company supports: max = platoon count")
	return "\n".join(lines)
