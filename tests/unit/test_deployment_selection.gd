extends GdUnitTestSuite
## T11-48 — the crew the player SELECTS is the crew that fights.
##
## THE GAP THESE PIN. Three book rules shrink the deployment, and all three are
## computed by BattleSetupRules.compute():
##   - Core Rules p.91, Rival Ambush: "you can deploy one crew member less than
##     standard"                                        -> crew_cap_delta -1
##   - Core Rules p.88, Small Encounter: "a random crew member sits out"
##                                                      -> crew_cap_delta -1
##   - Core Rules p.84, Small Squad: "You cannot deploy more than 4 crew"
##                                                      -> crew_cap_max 4
## CampaignTurnController._launch_pre_battle_directly() folded them into a
## deploy_limit and handed it to PreBattleUI, which pre-selected up to the cap and
## refused every toggle past it. Then _on_deployment_confirmed() rebuilt the battle
## crew from _deployable(get_active_crew()) and PreBattleUI.get_selected_crew() had
## ZERO callers repo-wide, so the cap was computed, displayed in the briefing, and
## discarded. Measured on the tablet (deploy #23): 6/6 deployed in an Ambush whose
## crew_cap_delta was -1, and any crew the player DESELECTED still fought.
##
## ⚠ The fallback cases matter as much as the filtering ones. An empty selection
## means the selector never ran, NOT that the player chose to field nobody, so the
## rule returns the roster untouched. A "fix" that fielded an empty force off a
## matching failure would be worse than the defect.

const RULES = preload("res://src/core/battle/BattleSetupRules.gd")
const PRE_BATTLE_SCENE := "res://src/ui/screens/battle/PreBattle.tscn"

## Crew members as the campaign stores them: Dictionaries carrying BOTH key
## spellings, which is the shape to_dictionary() emits and the shape
## BattleCheckpoint.member_key() is written against.
func _member(idx: int) -> Dictionary:
	return {
		"character_id": "char_%d" % idx,
		"id": "char_%d" % idx,
		"character_name": "Crew %d" % idx,
		"name": "Crew %d" % idx,
	}

func _roster(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(_member(i))
	return out

func _ids(crew: Array) -> Array:
	var out: Array = []
	for m in crew:
		out.append(str(m.get("character_id", "")))
	return out

## Mirrors CampaignTurnController._launch_pre_battle_directly() :1837-1847 — the
## deltas first, then the p.84 absolute ceiling, so a scenario that already shrank
## the squad cannot push it back up. ⚠ If that arithmetic moves, this moves with it;
## it is duplicated here on purpose so the cap SOURCES below are asserted against a
## single stated formula rather than three hand-written numbers.
func _deploy_limit(bundle: Dictionary, crew_size: int) -> int:
	var limit: int = maxi(1, crew_size + int(bundle.get("crew_cap_delta", 0)))
	var hard: int = int(bundle.get("crew_cap_max", 0))
	if hard > 0:
		limit = mini(limit, hard)
	return limit


# ── the rule itself ──────────────────────────────────────────────────────────

func test_a_selection_of_five_fields_exactly_those_five() -> void:
	var roster: Array = _roster(6)
	var chosen: Array = roster.slice(0, 5)
	var fielded: Array = RULES.apply_crew_selection(roster, chosen)
	assert_int(fielded.size()).is_equal(5)
	assert_array(_ids(fielded)).is_equal(
		["char_0", "char_1", "char_2", "char_3", "char_4"])

func test_a_deselected_member_does_not_fight() -> void:
	var roster: Array = _roster(6)
	var chosen: Array = []
	for m in roster:
		if str(m["character_id"]) != "char_2":
			chosen.append(m)
	var fielded: Array = RULES.apply_crew_selection(roster, chosen)
	assert_int(fielded.size()).is_equal(5)
	assert_bool(_ids(fielded).has("char_2")).is_false()

func test_order_comes_from_the_roster_not_the_selection() -> void:
	# However the player clicked, the fielded list keeps campaign crew order.
	var roster: Array = _roster(4)
	var chosen: Array = [roster[3], roster[0], roster[2]]
	var fielded: Array = RULES.apply_crew_selection(roster, chosen)
	assert_array(_ids(fielded)).is_equal(["char_0", "char_2", "char_3"])

func test_matching_is_by_identity_key_not_object_equality() -> void:
	# The confirm handler re-reads get_active_crew(), so the selection may hold
	# DIFFERENT Dictionary instances describing the same crew. Identity must come
	# from character_id, exactly as BattleCheckpoint.member_key() does it.
	var roster: Array = _roster(5)
	var chosen: Array = [_member(1), _member(3)]  # fresh objects, same ids
	var fielded: Array = RULES.apply_crew_selection(roster, chosen)
	assert_array(_ids(fielded)).is_equal(["char_1", "char_3"])


# ── the fallbacks, each of which must return the roster UNTOUCHED ────────────

func test_an_empty_selection_falls_back_to_the_whole_roster() -> void:
	# setup_crew_selection() never ran (its caller guards on a non-empty roster).
	# That is not a decision to field nobody.
	var roster: Array = _roster(6)
	assert_int(RULES.apply_crew_selection(roster, []).size()).is_equal(6)

func test_a_selection_matching_nobody_falls_back_to_the_roster() -> void:
	var roster: Array = _roster(6)
	var strangers: Array = [{"character_id": "ghost_1", "character_name": "Ghost"}]
	assert_int(RULES.apply_crew_selection(roster, strangers).size()).is_equal(6)

func test_a_selection_with_no_usable_key_falls_back_to_the_roster() -> void:
	var roster: Array = _roster(6)
	assert_int(RULES.apply_crew_selection(roster, [{}, {}]).size()).is_equal(6)

func test_an_empty_roster_is_returned_unchanged() -> void:
	assert_int(RULES.apply_crew_selection([], _roster(3)).size()).is_equal(0)


# ── the three cap SOURCES, each to its page ──────────────────────────────────

func test_p91_rival_ambush_takes_one_crew_slot() -> void:
	var bundle: Dictionary = RULES.compute(
		{"rival_attack_type": "AMBUSH"}, 5, 6)
	assert_int(int(bundle["crew_cap_delta"])).is_equal(-1)
	assert_int(_deploy_limit(bundle, 6)).is_equal(5)

func test_p88_small_encounter_takes_one_crew_slot() -> void:
	var bundle: Dictionary = RULES.compute(
		{"deployment_condition": {"condition_id": "SMALL_ENCOUNTER"}}, 5, 6)
	assert_int(int(bundle["crew_cap_delta"])).is_equal(-1)
	assert_int(_deploy_limit(bundle, 6)).is_equal(5)

## ⚠ The Small Squad fixture names the CONDITION, not the effect. PatronJobEffects
## .max_deploy_crew() reads `effects.max_deploy_crew` off the entries hanging on the
## job's benefits / hazards / conditions arrays, and _resolve() accepts a bare id
## string — so `{"conditions": ["small_squad"]}` is the shape a real Patron job
## carries and the 4 comes out of the shipped data/patron_generation.json rather
## than being retyped here. The first version of this test put max_deploy_crew at
## the TOP level of mission_data; it read 0 and failed, which is the fixture-shape
## trap this project keeps hitting: a hand-built fixture the app never produces.
func test_p84_small_squad_is_an_absolute_ceiling() -> void:
	var bundle: Dictionary = RULES.compute({"conditions": ["small_squad"]}, 5, 6)
	assert_int(int(bundle["crew_cap_max"])).is_equal(4)
	assert_int(_deploy_limit(bundle, 6)).is_equal(4)

func test_the_ceiling_is_applied_after_the_deltas_and_never_widens_them() -> void:
	# p.84 is a ceiling, not a target. With a crew of 6 the Ambush takes one (5) and
	# the ceiling then bites (4); with a crew of 4 the Ambush takes one (3) and the
	# ceiling must NOT push it back up to its own 4.
	var six: Dictionary = RULES.compute(
		{"rival_attack_type": "AMBUSH", "conditions": ["small_squad"]}, 5, 6)
	assert_int(_deploy_limit(six, 6)).is_equal(4)
	var four: Dictionary = RULES.compute(
		{"rival_attack_type": "AMBUSH", "conditions": ["small_squad"]}, 5, 4)
	assert_int(_deploy_limit(four, 4)).is_equal(3)


# ── end to end through a REAL PreBattleUI ────────────────────────────────────
#
# The unit cases above prove the rule and the caps in isolation; these prove the
# WIRING, which is where T11-48 actually lived. Testing the callee alone is what
# let a correct cap sit beside a consumer that ignored it.

func _pre_battle() -> Node:
	var packed: PackedScene = load(PRE_BATTLE_SCENE)
	var inst: Node = packed.instantiate()
	add_child(inst)
	auto_free(inst)
	return inst

func test_the_widget_preselects_up_to_the_cap_and_the_rule_fields_exactly_those() -> void:
	var roster: Array = _roster(6)
	var ui: Node = _pre_battle()
	ui.setup_crew_selection(roster, 5)          # p.91 Ambush limit
	var chosen: Array = ui.get_selected_crew()
	assert_int(chosen.size()).is_equal(5)
	var fielded: Array = RULES.apply_crew_selection(roster, chosen)
	assert_int(fielded.size()).is_equal(5)

func test_a_full_cap_still_fields_everyone() -> void:
	var roster: Array = _roster(6)
	var ui: Node = _pre_battle()
	ui.setup_crew_selection(roster, 6)
	var fielded: Array = RULES.apply_crew_selection(roster, ui.get_selected_crew())
	assert_int(fielded.size()).is_equal(6)

func test_setup_crew_selection_is_idempotent() -> void:
	# T11-48's second half. This used to clear neither the selection nor the panel,
	# so a re-entry inherited the old picks (the pre-select loop only fills up to
	# _max_deploy) and stacked a duplicate button list. Harmless while nothing
	# consumed the selection; the wrong crew on the table once something does.
	var roster: Array = _roster(6)
	var ui: Node = _pre_battle()
	ui.setup_crew_selection(roster, 6)
	assert_int(ui.get_selected_crew().size()).is_equal(6)
	ui.setup_crew_selection(roster, 5)
	assert_int(ui.get_selected_crew().size()).is_equal(5)
	var fielded: Array = RULES.apply_crew_selection(roster, ui.get_selected_crew())
	assert_int(fielded.size()).is_equal(5)


# -- the WIRING, pinned at the call site --------------------------------------
#
# Every case above would STILL PASS with _on_deployment_confirmed() ignoring the
# selection again, because they call the rule themselves. That is exactly what
# T11-48 was: a correct callee sitting beside a consumer that never called it. So
# the call site itself is asserted, and anchored on the ENABLING FORM rather than a
# loose mention of the name.

const CTC_PATH := "res://src/ui/screens/campaign/CampaignTurnController.gd"

func test_the_confirm_handler_actually_consumes_the_selection() -> void:
	var f := FileAccess.open(CTC_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var src: String = f.get_as_text()
	f.close()
	var head: int = src.find("func _on_deployment_confirmed")
	assert_int(head).is_greater(-1)
	var body: String = src.substr(head, 2400)
	assert_str(body).contains("get_selected_crew")
	assert_str(body).contains("crew_data = BattleSetupRulesClass.apply_crew_selection")

func test_the_controller_and_the_rule_both_compile() -> void:
	# The other half of the scan above. A source scan proves the right words are
	# present, NEVER that the file compiles - CheatSheetPanel stayed green in a
	# 14-case suite while the engine could not load it. A plain load() null-check
	# detects nothing either: it serves the resource cache and a parse-broken
	# GDScript still returns a non-null object. can_instantiate() is the check that
	# actually distinguishes them.
	var ctc: Resource = load(CTC_PATH)
	assert_object(ctc).is_not_null()
	assert_bool((ctc as GDScript).can_instantiate()).is_true()
	# The RULE needs no separate compile check: the twelve cases above call
	# apply_crew_selection() directly, so a broken BattleSetupRules fails them all.
	# ⚠ An earlier draft asserted RULES.can_instantiate() here and that is a PARSE
	# ERROR - RULES is a const preload of a class_name script, so GDScript resolves
	# it as the type and refuses a non-static call on it. It cost nothing to find
	# only because the failure was loud; gdUnit4 reports a parse error as "No test
	# cases found" and EXITS 0, so read the case count, never the exit code.
