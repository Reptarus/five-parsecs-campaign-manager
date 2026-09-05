extends GdUnitTestSuite
## Core Rules p.13 — the four crew-creation methods.
##
## The audit ledger recorded these as "OPEN by choice", i.e. a product decision. Reading
## the page settled it as a rules gap instead: the Miniatures Method explicitly allows
## "any combination of Primary Aliens, Bots, or Humans", so the wizard's free species
## choice was always a BOOK method — what was missing was the choice itself and the
## constraints the other three impose.
##
## Both directions are asserted throughout. A validator that only ever rejects is as
## wrong as one that only ever accepts, and the Tactics p.134 defect fixed the same day
## was exactly that shape: limits borrowed from a different organisation, rejecting legal
## armies as well as accepting illegal ones.

const CCM := preload("res://src/core/character/CrewCreationMethods.gd")

## The six Primary Aliens of the p.14 subtable, and a Strange Character from its own.
const ALIEN_A := "kerin"
const ALIEN_B := "engineer"
const ALIEN_C := "swift"


func _crew(species: Array) -> Array:
	var out: Array = []
	for s in species:
		out.append({"species_id": s, "name": "Crew %s" % s})
	return out


# ── Category resolution ─────────────────────────────────────────────────────

func test_species_resolve_to_their_p14_categories() -> void:
	assert_str(CCM.category_for_species("human")).is_equal(CCM.CAT_HUMAN)
	assert_str(CCM.category_for_species("bot")).is_equal(CCM.CAT_BOT)
	for alien in [ALIEN_A, ALIEN_B, ALIEN_C, "soulless", "precursor", "feral"]:
		assert_str(CCM.category_for_species(alien)).override_failure_message(
			"%s is on the p.14 primary_alien subtable" % alien
		).is_equal(CCM.CAT_PRIMARY_ALIEN)


func test_an_empty_species_is_human_not_a_crash() -> void:
	# A crew dictionary with no species_id is the shape a pre-species save has.
	assert_str(CCM.category_for_species("")).is_equal(CCM.CAT_HUMAN)


func test_an_unknown_species_is_not_silently_treated_as_human() -> void:
	# Falling back to Human would let an unrecognised id slip past the Standard caps
	# unnoticed. It resolves to the one category no pick-based method admits, so the
	# validator reports it instead of swallowing it.
	assert_str(CCM.category_for_species("not_a_real_species")).is_equal(CCM.CAT_STRANGE)


# ── First-timer: "a crew of 6 Human characters" ──────────────────────────────

func test_first_timer_requires_an_all_human_crew() -> void:
	var all_human := _crew(["human", "human", "human", "human", "human", "human"])
	assert_array(CCM.validate(all_human, CCM.Method.FIRST_TIMER)).is_empty()
	var one_alien := _crew(["human", "human", "human", "human", "human", ALIEN_A])
	assert_array(CCM.validate(one_alien, CCM.Method.FIRST_TIMER)).is_not_empty()
	assert_str(str(CCM.validate(one_alien, CCM.Method.FIRST_TIMER))).contains("Human")


# ── Standard: 3 Human / 2 may be alien / 1 may be bot ───────────────────────

func test_standard_accepts_the_books_own_maximum_mix() -> void:
	# "3 are always Human. 2 may be Human or a Primary Alien. 1 may be a Human or Bot."
	var maxed := _crew(["human", "human", "human", ALIEN_A, ALIEN_B, "bot"])
	assert_array(CCM.validate(maxed, CCM.Method.STANDARD)).override_failure_message(
		"2 aliens + 1 bot + 3 humans is the maximum the book allows, and must PASS"
	).is_empty()


func test_standard_rejects_a_third_alien_and_a_second_bot() -> void:
	var three_aliens := _crew(["human", "human", ALIEN_A, ALIEN_B, ALIEN_C, "bot"])
	assert_str(str(CCM.validate(three_aliens, CCM.Method.STANDARD))).contains(
		"at most 2 Primary Aliens")
	var two_bots := _crew(["human", "human", "human", "human", "bot", "bot"])
	assert_str(str(CCM.validate(two_bots, CCM.Method.STANDARD))).contains("at most 1 Bot")


func test_standard_keeps_its_caps_at_a_reduced_crew_size() -> void:
	# p.13: "If you have opted for a reduced crew size (see page 63), you may still
	# select up to 1 Bot and 2 Primary Aliens." Expressing Standard as CAPS rather than
	# slots is what makes this the same rule rather than a special case — a 4-person crew
	# of 1 human + 2 aliens + 1 bot has NO "3 always Human" to satisfy and is still legal.
	var reduced := _crew(["human", ALIEN_A, ALIEN_B, "bot"])
	assert_array(CCM.validate(reduced, CCM.Method.STANDARD, 4)).override_failure_message(
		"a reduced crew may still take 2 Primary Aliens and 1 Bot"
	).is_empty()
	var reduced_over := _crew(["human", ALIEN_A, ALIEN_B, ALIEN_C])
	assert_array(CCM.validate(reduced_over, CCM.Method.STANDARD, 4)).is_not_empty()


# ── Miniatures: any combination of Humans, Primary Aliens and Bots ──────────

func test_miniatures_allows_any_mix_of_the_three_listed_types() -> void:
	# This is the case that makes free species choice a BOOK method rather than a house
	# rule, and it is why no house-rule label was added.
	var wild := _crew([ALIEN_A, ALIEN_B, ALIEN_C, "bot", "bot", "bot"])
	assert_array(CCM.validate(wild, CCM.Method.MINIATURES)).override_failure_message(
		"the Miniatures Method allows ANY combination of Primary Aliens, Bots or Humans"
	).is_empty()


# ── Strange Characters are Random-only ─────────────────────────────────────

func test_strange_characters_are_reachable_only_by_the_random_method() -> void:
	# p.14 puts them at 91-100 on the Crew Type Table and no other method lists them.
	# That is the book's own scarcity control (~10%), and ignoring it is what made
	# randomised crews ~69% Strange before the Crew Type Tables fix.
	var strange := _crew(["human", "human", "human", "human", "human", "hulker"])
	if CCM.category_for_species("hulker") != CCM.CAT_STRANGE:
		return  # species data does not list this one; the rule is asserted below anyway
	assert_array(CCM.validate(strange, CCM.Method.STANDARD)).is_not_empty()
	assert_array(CCM.validate(strange, CCM.Method.MINIATURES)).is_not_empty()
	assert_array(CCM.validate(strange, CCM.Method.RANDOM)).override_failure_message(
		"the Random Method rolls every position, so nothing it produces is a violation"
	).is_empty()


# ── Selectable categories drive the wizard's dropdowns ─────────────────────

func test_selectable_categories_match_each_methods_freedom() -> void:
	assert_array(CCM.selectable_categories(CCM.Method.FIRST_TIMER)).is_equal(
		[CCM.CAT_HUMAN])
	assert_array(CCM.selectable_categories(CCM.Method.STANDARD)).contains(
		[CCM.CAT_PRIMARY_ALIEN, CCM.CAT_BOT])
	assert_array(CCM.selectable_categories(CCM.Method.MINIATURES)).contains(
		[CCM.CAT_PRIMARY_ALIEN, CCM.CAT_BOT])
	# Nothing is PICKED under Random — every position is rolled.
	assert_array(CCM.selectable_categories(CCM.Method.RANDOM)).is_empty()


# ── Persistence round-trip ─────────────────────────────────────────────────

func test_method_ids_round_trip_and_an_unknown_id_falls_to_a_book_method() -> void:
	for m in CCM.all_methods():
		assert_int(CCM.method_from_id(CCM.method_id(m))).override_failure_message(
			"%s must survive a save/load round trip" % CCM.method_name(m)).is_equal(m)
	# A config written by a newer build must not make an existing crew retroactively
	# illegal, so the fallback is the least restrictive BOOK method.
	assert_int(CCM.method_from_id("something_new")).is_equal(CCM.Method.MINIATURES)


func test_species_of_reads_both_shapes_and_survives_a_numeric_origin() -> void:
	assert_str(CCM.species_of({"species_id": "KErin".to_lower()})).is_equal("kerin")
	# Legacy saves store origin as a NUMBER (int far more often than float). A string
	# operation on a float ABORTS the enclosing function in Godot, so the accessor must
	# str()-wrap rather than assume text.
	#
	# The assertion is on the CATEGORY, not the string: str(7) and str(7.0) format
	# differently and that formatting is not a contract anyone depends on. What matters
	# is that a numeric origin resolves to a species nobody can pick, so the Standard
	# caps cannot be bypassed by a legacy save - and that reading it does not abort.
	assert_str(CCM.species_of({"origin": 7})).is_not_empty()
	assert_str(CCM.species_of({"origin": 7.0})).is_not_empty()
	for numeric in [{"origin": 7}, {"origin": 7.0}, {"origin": 0}]:
		assert_str(CCM.category_for_species(CCM.species_of(numeric)))			.override_failure_message(
				"a numeric legacy origin must not silently pass as Human"
			).is_equal(CCM.CAT_STRANGE)


# ── Crew-level coercion after a roll ───────────────────────────────────────

func test_coercion_leaves_random_and_miniatures_untouched() -> void:
	# Random rolls every position by the book, and Miniatures allows any combination of
	# the three listed types, so neither has anything to correct.
	var rolled := [ALIEN_A, ALIEN_B, ALIEN_C, "bot", "bot", "human"]
	assert_array(CCM.coerce_to_method(rolled, CCM.Method.RANDOM)).is_equal(rolled)
	assert_array(CCM.coerce_to_method(rolled, CCM.Method.MINIATURES)).is_equal(rolled)


func test_coercion_makes_a_first_timer_crew_all_human() -> void:
	var rolled := [ALIEN_A, "bot", "human", ALIEN_B]
	var out: Array = CCM.coerce_to_method(rolled, CCM.Method.FIRST_TIMER)
	assert_int(out.size()).is_equal(rolled.size())
	for s in out:
		assert_str(str(s)).is_equal("human")


func test_coercion_keeps_the_earliest_standard_picks_and_humanises_the_excess() -> void:
	# The caps are CREW-level while species are rolled one character at a time, so a
	# single roll can never know it is the third alien. Keeping the EARLIEST picks means
	# a player who deliberately placed an alien first does not lose it to a later roll.
	var rolled := [ALIEN_A, ALIEN_B, ALIEN_C, "bot", "bot", "human"]
	var out: Array = CCM.coerce_to_method(rolled, CCM.Method.STANDARD)
	assert_array(out).is_equal([ALIEN_A, ALIEN_B, "human", "bot", "human", "human"])
	# And the result is legal by the validator, which is the point of coercing at all.
	var as_crew: Array = []
	for s in out:
		as_crew.append({"species_id": s})
	assert_array(CCM.validate(as_crew, CCM.Method.STANDARD)).is_empty()


func test_coercion_removes_strange_characters_under_standard() -> void:
	var rolled := ["human", "hulker", "human", "human"]
	if CCM.category_for_species("hulker") != CCM.CAT_STRANGE:
		return
	var out: Array = CCM.coerce_to_method(rolled, CCM.Method.STANDARD)
	assert_str(str(out[1])).override_failure_message(
		"Strange Characters are Random-only (p.13-14), so under Standard that slot is "
		+ "a Human one").is_equal("human")


func test_coercion_never_changes_the_crew_size() -> void:
	# A coercion that dropped a member would silently shrink the crew below the size the
	# player chose, which the wizard's own over-size gate would never catch.
	for m in CCM.all_methods():
		var rolled := [ALIEN_A, ALIEN_B, ALIEN_C, "bot", "bot", "human"]
		assert_int(CCM.coerce_to_method(rolled, int(m)).size()).override_failure_message(
			"%s changed the crew size" % CCM.method_name(int(m))).is_equal(rolled.size())


# ── WIRING (T11-09) ─────────────────────────────────────────────────────────
#
# EVERY CASE ABOVE PASSED WHILE THIS FEATURE WAS COMPLETELY INERT ON THE DEVICE.
# That is not a criticism of them — they pin the book, and the book half was right.
# It is the reason this section exists.
#
# Found on tablet deploy #17: Standard Method + crew size 4, "Randomize All"
# produced TWO Bots against a p.13 cap of one, no warning appeared, and Next
# advanced. The rule was correct, the setter existed, and its has_method guard was
# live. The value died in CampaignCreationCoordinator.update_campaign_config_state(),
# a WHITELIST that did not name `crew_creation_method` — so the unified state never
# carried it, and both consumers read their "miniatures" default:
#
#   coercion   CampaignCreationUI._push_campaign_crew_size() -> CrewPanel
#   the gate   state_manager.campaign_data["config"] -> _validate_crew_with_warnings()
#
# ONE missing line, BOTH halves dead. It is the fourth feature that whitelist has
# eaten (Progressive Difficulty, narrative_wrap_override, difficulty_toggles,
# house_rules), which is why the propagation is now asserted and not just commented.

const COORDINATOR := preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const SM := preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")


## Built in the TREE on purpose: a detached .new() Node cannot resolve
## get_node_or_null("/root/X") — the call errors and aborts the enclosing function
## rather than returning null, so a detached coordinator would measure the trap.
func _coordinator() -> Node:
	var c: Node = COORDINATOR.new()
	add_child(c)
	auto_free(c)
	return c


func test_the_config_steps_method_choice_reaches_the_unified_state() -> void:
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "standard"})
	var cfg: Dictionary = c.get_unified_campaign_state().get("campaign_config", {})
	assert_str(str(cfg.get("crew_creation_method", "<DROPPED>"))).override_failure_message(
		"update_campaign_config_state() is a whitelist: a key it does not name is "
		+ "silently dropped, and nothing errors. This is T11-09 exactly."
	).is_equal("standard")


func test_the_method_also_reaches_the_validator_the_next_button_consults() -> void:
	# advance_to_next_phase() consults ONLY _validate_phase_with_warnings(); the
	# strict _validate_crew_phase() is not on the navigation path.
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "standard"})
	var cfg: Dictionary = c.state_manager.campaign_data.get("config", {})
	assert_str(str(cfg.get("crew_creation_method", "<DROPPED>"))).override_failure_message(
		"The gate reads campaign_data['config'], which the coordinator feeds from "
		+ "the same campaign_config the whitelist built."
	).is_equal("standard")


func test_an_illegal_standard_crew_is_reported_at_the_live_gate() -> void:
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "standard"})
	# The device's exact roster: two Bots at crew size 4.
	c.state_manager.set_phase_data(SM.Phase.CREW_SETUP, {
		"members": _crew(["bot", "bot", "human", "human"]),
		"size": 4, "has_captain": true, "backend_generated": true,
	})
	var res: Dictionary = c.state_manager._validate_phase_with_warnings(SM.Phase.CREW_SETUP)
	var joined := "\n".join(PackedStringArray(res.get("warnings", [])))
	assert_bool(joined.contains("at most 1 Bot")).override_failure_message(
		"Two Bots under the Standard Method must warn (p.13). Warnings were:\n%s" % joined
	).is_true()


func test_the_same_crew_is_legal_under_the_miniatures_method() -> void:
	# BOTH DIRECTIONS. Without this the case above passes for a validator that
	# warns about two Bots under every method — which is not the book, and would
	# hide the propagation failing by defaulting to something strict.
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "miniatures"})
	c.state_manager.set_phase_data(SM.Phase.CREW_SETUP, {
		"members": _crew(["bot", "bot", "human", "human"]),
		"size": 4, "has_captain": true, "backend_generated": true,
	})
	var res: Dictionary = c.state_manager._validate_phase_with_warnings(SM.Phase.CREW_SETUP)
	var joined := "\n".join(PackedStringArray(res.get("warnings", [])))
	assert_bool(joined.contains("at most 1 Bot")).override_failure_message(
		"Miniatures allows any combination of Humans, Primary Aliens and Bots (p.13)."
	).is_false()


# ---------------------------------------------------------------------------
# T11-13 — THE WARNING HAS TO REACH THE PLAYER (deploy #19 device walk, Sep 5 2026)
#
# The four cases above prove the gate DETECTS an illegal Standard crew. On the tablet
# it did exactly that and the player saw nothing: advance_to_next_phase() sent the
# warnings to push_warning() and advanced. The device log carried
#
#     Advancing with warnings: [... "Standard Method: at most 1 Bot (p.13) - have 2"]
#
# with the right rule and the right page cite, while the screen showed a clean Next.
# A rule that is checked and never shown is indistinguishable from one that is not
# checked — the "default that is also a legal value" shape, again.
#
# Blocking is NOT the fix and must not become one: a half-finished crew passes through
# illegal-looking intermediate states as species are assigned slot by slot, which is
# why the composition check is a warning and the over-size check is not. See the
# comment on that check in CampaignCreationStateManager.
# ---------------------------------------------------------------------------

func _capture_warnings(sm: Object, out: Array) -> void:
	sm.phase_warnings.connect(func(_phase, warnings): out.append(warnings))


func test_the_gate_hands_its_warnings_to_a_listener_not_only_to_the_log() -> void:
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "standard"})
	c.state_manager.set_phase_data(SM.Phase.CREW_SETUP, {
		"members": _crew(["bot", "bot", "human", "human"]),
		"size": 4, "has_captain": true, "backend_generated": true,
	})
	c.state_manager.current_phase = SM.Phase.CREW_SETUP

	var seen: Array = []
	_capture_warnings(c.state_manager, seen)
	c.state_manager.advance_to_next_phase()

	assert_int(seen.size()).override_failure_message(
		"advance_to_next_phase() must emit phase_warnings so a screen can show them. "
		+ "Before T11-13 the only consumer was push_warning()."
	).is_equal(1)
	var joined := "\n".join(PackedStringArray(seen[0]))
	assert_bool(joined.contains("at most 1 Bot")).override_failure_message(
		"The emitted payload must carry the rule text the player needs, cite and all. "
		+ "Got:\n%s" % joined
	).is_true()


func test_a_clean_phase_emits_an_empty_list_so_a_stale_notice_clears() -> void:
	# BOTH DIRECTIONS. Without this, a listener that only ever appends would leave a
	# fixed crew still accused on the next step — and the case above could not tell
	# the difference between "emitted when dirty" and "emitted always, non-empty".
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "miniatures"})
	c.state_manager.set_phase_data(SM.Phase.CREW_SETUP, {
		"members": _crew(["bot", "bot", "human", "human"]),
		"size": 4, "has_captain": true, "backend_generated": true,
	})
	c.state_manager.current_phase = SM.Phase.CREW_SETUP

	var seen: Array = []
	_capture_warnings(c.state_manager, seen)
	c.state_manager.advance_to_next_phase()

	assert_int(seen.size()).override_failure_message(
		"phase_warnings must fire on EVERY advance, not only a dirty one — a listener "
		+ "has no other way to know the previous notice no longer applies."
	).is_equal(1)
	assert_array(seen[0]).override_failure_message(
		"Two Bots are legal under Miniatures (p.13), so this advance must report nothing."
	).is_empty()


func test_the_coordinator_relays_the_warnings_to_its_own_signal() -> void:
	# The screen listens to the coordinator, not to the state manager. This is the
	# link that makes the fix reachable from CampaignCreationUI; without it both
	# cases above pass while the player still sees nothing.
	var c := _coordinator()
	c.update_campaign_config_state({"crew_creation_method": "standard"})
	c.state_manager.set_phase_data(SM.Phase.CREW_SETUP, {
		"members": _crew(["bot", "bot", "human", "human"]),
		"size": 4, "has_captain": true, "backend_generated": true,
	})
	c.state_manager.current_phase = SM.Phase.CREW_SETUP

	var relayed: Array = []
	c.phase_warnings.connect(func(_phase, warnings): relayed.append(warnings))
	c.state_manager.advance_to_next_phase()

	assert_int(relayed.size()).override_failure_message(
		"CampaignCreationCoordinator must re-emit phase_warnings."
	).is_equal(1)
	var joined := "\n".join(PackedStringArray(relayed[0]))
	assert_bool(joined.contains("at most 1 Bot")).is_true()
