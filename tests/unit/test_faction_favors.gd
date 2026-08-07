extends GdUnitTestSuite
## The Benefits of Loyalty — calling in a Faction favor (Compendium p.112).
##
## The last genuinely open item in docs/RULES_WIRING_AUDIT_2026-08.md, recorded in
## the doc's narrative rather than the ledger table.
##
## `FactionSystem.attempt_faction_favor()` was correct and complete — D6 <=
## Loyalty, reduce Loyalty BY THE DIE ROLL, return the six book favors — and had
## ZERO callers, because p.112 requires a crew task ("and can only be done by
## your captain") that did not exist. Every Loyalty point the crew earned was
## unspendable and all six favors were unreachable.

const FavorService = preload("res://src/core/systems/FactionFavorService.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const CREW_TASK_PATH := "res://src/ui/screens/world/components/CrewTaskComponent.gd"
const CTC_PATH := "res://src/ui/screens/campaign/CampaignTurnController.gd"


func _code_only(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var out: PackedStringArray = []
	for line in f.get_as_text().split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	f.close()
	return "\n".join(out)


func _campaign() -> Resource:
	var c: Resource = CampaignCore.new()
	c.progress_data = {}
	c.rivals = []
	c.patrons = []
	return c


# ============================================================================
# The crew task the book requires
# ============================================================================

func test_the_crew_task_exists_and_is_captain_only() -> void:
	## p.112: "This REQUIRES A CREW TASK, and can only be done by your CAPTAIN."
	var f := FileAccess.open("res://data/crew_tasks.json", FileAccess.READ)
	assert_that(f).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).is_equal(OK)
	f.close()

	var found: Dictionary = {}
	for t: Variant in (json.data as Dictionary).get("tasks", []):
		if str((t as Dictionary).get("id", "")) == "call_in_a_favor":
			found = t
	assert_dict(found).is_not_empty()
	assert_bool(bool(found.get("captain_only", false))).is_true()
	assert_bool(bool(found.get("once_per_campaign_turn", false))).is_true()
	assert_str(str(found.get("resolution_type", ""))).is_equal("faction_favor")
	# One crew member: it is the captain's call, not a group effort.
	assert_int(int(found.get("max_crew", 0))).is_equal(1)


func test_the_task_reaches_attempt_faction_favor() -> void:
	## The whole row was "a correct function with no caller". A task that resolves
	## to something other than FactionSystem would leave it exactly as dead.
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("\"faction_favor\":")
	assert_str(src).contains("_resolve_faction_favor_task(result, crew_member)")
	assert_str(src).contains("fs.attempt_faction_favor(faction_id)")


func test_the_captain_gate_is_enforced_at_the_resolver_not_only_the_widget() -> void:
	## A gate that lives only in the assignment UI is one rebuild away from being
	## bypassed, so the rule sits in the resolver and the UI check is the courtesy.
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("if not bool(_member_get(crew_member, \"is_captain\", false)):")
	assert_str(src).contains("if bool(task.get(\"captain_only\", false)) \\")


func test_the_favor_is_chosen_after_the_roll() -> void:
	## p.112, verbatim: "You can choose the favor AFTER ROLLING." Offering the
	## picker first would let a player pick Monetary help and then discover the
	## die that sets its payout.
	var src: String = _code_only(CREW_TASK_PATH)
	var roll_at: int = src.find("fs.attempt_faction_favor(faction_id)")
	var pick_at: int = src.find("_offer_faction_favor(faction_id, result.roll)")
	assert_int(roll_at).is_greater(0)
	assert_int(pick_at).is_greater(roll_at)


# ============================================================================
# The once-per-campaign-turn gate
# ============================================================================

func test_a_favor_is_once_per_campaign_turn() -> void:
	var c := _campaign()
	assert_bool(FavorService.favor_used_this_turn(c, 4)).is_false()
	FavorService.mark_favor_used(c, 4)
	assert_bool(FavorService.favor_used_this_turn(c, 4)).is_true()
	assert_bool(FavorService.favor_used_this_turn(c, 5)).is_false()


func test_an_empty_progress_data_is_not_read_as_already_used() -> void:
	## The empty-container trap: guarding on `pd.is_empty()` would report "already
	## used" for a crew that has never played a turn.
	var c := _campaign()
	assert_dict(c.progress_data).is_empty()
	assert_bool(FavorService.favor_used_this_turn(c, 0)).is_false()
	FavorService.mark_favor_used(c, 0)
	assert_bool(FavorService.favor_used_this_turn(c, 0)).is_true()


# ============================================================================
# The six favors
# ============================================================================

func test_all_six_book_favors_are_offered() -> void:
	## p.112 lists six. Contact network is SPLIT into two rows because the book
	## gives it an either/or the player must make ("You may EITHER roll up a Patron
	## that offers a job OR opt to take a Salvage job"), so seven picker rows.
	var options: Array = FavorService.favor_options(4, 3)
	var ids: Array = []
	for o: Dictionary in options:
		ids.append(str(o["id"]))
	assert_array(ids).contains([
		FavorService.FAVOR_PULLING_STRINGS,
		FavorService.FAVOR_MONETARY_HELP,
		FavorService.FAVOR_CONTACT_PATRON,
		FavorService.FAVOR_CONTACT_SALVAGE,
		FavorService.FAVOR_ARRANGE_MEETING,
		FavorService.FAVOR_PROVIDE_COVER,
		FavorService.FAVOR_ACCESS_INFORMATION,
	])
	# The payout must be visible BEFORE the choice — Monetary help's value IS the
	# die that was already rolled.
	assert_str(str(options[1]["label"])).contains("4 credits")


func test_pulling_strings_removes_an_eligible_rival() -> void:
	## p.112: "remove an Enforcer, Vigilante, or Bounty Hunter Rival."
	var c := _campaign()
	c.rivals = [
		{"id": "r1", "name": "Roving Gang", "type": "Gangers"},
		{"id": "r2", "name": "Local Enforcers", "type": "Enforcers"},
	]
	var out: Dictionary = FavorService.apply_favor(
		c, FavorService.FAVOR_PULLING_STRINGS, 3, 2)

	assert_bool(bool(out["applied"])).is_true()
	assert_int(c.rivals.size()).is_equal(1)
	assert_str(str(c.rivals[0]["name"])).is_equal("Roving Gang")


func test_pulling_strings_banks_the_loan_cancel_when_no_rival_qualifies() -> void:
	## The favor is an either/or where only one branch may be available. Spending
	## it for nothing would be the worst reading of a limited resource.
	var c := _campaign()
	c.rivals = [{"id": "r1", "name": "Roving Gang", "type": "Gangers"}]
	var out: Dictionary = FavorService.apply_favor(
		c, FavorService.FAVOR_PULLING_STRINGS, 3, 2)

	assert_bool(bool(out["applied"])).is_true()
	assert_int(c.rivals.size()).is_equal(1)
	assert_bool(bool(c.progress_data[FavorService.CANCEL_ENFORCEMENT_KEY])).is_true()


func test_monetary_help_pays_the_die_and_adds_one_against_debt() -> void:
	## p.112: "Gain Credits equal to the die roll. Add +1 to the score if the sum
	## is used directly to pay off debts or medical expenses."
	var no_debt := _campaign()
	no_debt.ship_debt = 0
	var plain: Dictionary = FavorService.apply_favor(
		no_debt, FavorService.FAVOR_MONETARY_HELP, 5, 2)
	assert_int(int(plain["credits"])).is_equal(5)

	var indebted := _campaign()
	indebted.ship_debt = 20
	var paid: Dictionary = FavorService.apply_favor(
		indebted, FavorService.FAVOR_MONETARY_HELP, 5, 2)
	# +1 applies because the sum went straight to the debt.
	assert_int(indebted.ship_debt).is_equal(14)
	assert_int(int(paid.get("credits", 0))).is_equal(0)


func test_monetary_help_cannot_overpay_a_small_debt() -> void:
	var c := _campaign()
	c.ship_debt = 2
	FavorService.apply_favor(c, FavorService.FAVOR_MONETARY_HELP, 6, 2)
	assert_int(c.ship_debt).is_equal(0)


func test_contact_network_banks_an_entitlement_not_a_second_generator() -> void:
	## Both branches route through machinery this codebase already owns: the p.77
	## `patron_offers_owed` counter and the Compendium p.137 salvage generator.
	## A favor that grew its own copy of a job table is how two tables drift.
	var c := _campaign()
	FavorService.apply_favor(c, FavorService.FAVOR_CONTACT_PATRON, 3, 2)
	assert_int(int(c.progress_data["patron_offers_owed"])).is_equal(1)

	var s := _campaign()
	FavorService.apply_favor(s, FavorService.FAVOR_CONTACT_SALVAGE, 3, 2)
	assert_bool(bool(s.progress_data["faction_favor_salvage_job"])).is_true()


func test_provide_cover_suppresses_the_p85_rival_check() -> void:
	## p.112: "Provide cover — You cannot be attacked by any Rivals this turn."
	## Fourth clause on the ONE suppression chokepoint — four rules suppress this
	## roll and there is one place that decides it.
	var c := _campaign()
	c.progress_data["turns_played"] = 7
	FavorService.apply_favor(c, FavorService.FAVOR_PROVIDE_COVER, 3, 2)

	assert_bool(FavorService.provide_cover_active(c, 7)).is_true()
	assert_bool(FavorService.provide_cover_active(c, 8)).is_false()

	# Anchored on the EXACT enabling form, not on containment. A containment
	# assert survives `if false and FactionFavorServiceRef.provide_cover_active(`
	# — proven empirically, and the third time in this audit that a `contains()`
	# check passed on a disabled call.
	var src: String = _code_only(CTC_PATH)
	assert_str(src).contains("\t\tif FactionFavorServiceRef.provide_cover_active(")
	assert_str(src).not_contains("and FactionFavorServiceRef.provide_cover_active(")
	var suppress_at: int = src.find("func _story_rival_suppression_reason()")
	var call_at: int = src.find("if FactionFavorServiceRef.provide_cover_active(")
	assert_int(suppress_at).is_greater(0)
	assert_int(call_at).is_greater(suppress_at)


func test_access_to_information_scales_with_influence() -> void:
	## p.112: "Gain Quest Clues equal to Influence this turn." The Core Rules call
	## the same token a Quest RUMOR and this codebase has exactly one of them —
	## inventing a second currency named "clue" would be the unfaithful reading.
	var c := _campaign()
	assert_int(int(FavorService.apply_favor(
		c, FavorService.FAVOR_ACCESS_INFORMATION, 3, 4)["rumors"])).is_equal(4)
	# Influence 0 pays nothing rather than erroring or paying 1.
	assert_int(int(FavorService.apply_favor(
		c, FavorService.FAVOR_ACCESS_INFORMATION, 3, 0)["rumors"])).is_equal(0)


func test_arrange_a_meeting_spawns_a_character() -> void:
	## p.112: "Roll up a new crew member using the start-of-campaign process."
	var c := _campaign()
	var out: Dictionary = FavorService.apply_favor(
		c, FavorService.FAVOR_ARRANGE_MEETING, 3, 2)
	assert_bool(bool(out["spawn_temp_crew"])).is_true()
	# ...and the caller must act on it, or the favor is a message with no effect.
	assert_str(_code_only(CREW_TASK_PATH)).contains(
		"if bool(outcome.get(\"spawn_temp_crew\", false)):")


func test_an_unknown_favor_id_does_nothing() -> void:
	var c := _campaign()
	var out: Dictionary = FavorService.apply_favor(c, "bribe_the_governor", 3, 2)
	assert_bool(bool(out["applied"])).is_false()
