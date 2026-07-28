extends GdUnitTestSuite
## END-TO-END: an auto-resolved battle must have real consequences for the crew.
##
## THE PIPELINE UNDER TEST
##   PreBattleUI "Play it out for me"
##     -> CampaignTurnController._on_auto_resolve_completed
##          _deployable(get_active_crew())            <- filter
##          BattleResolverRouter.resolve              <- counts + crew_units_final
##          _map_resolver_crew_outcome                <- counts -> per-character arrays
##     -> _normalize_battle_results
##          crew_injuries_data  -> injuries_sustained
##          crew_casualties_data -> casualties
##     -> PostBattlePhase -> InjuryProcessor -> ctx.apply_crew_injury
##          -> in_sick_bay / recovery_turns / injuries[] / status
##
## Every link was individually plausible and the pipeline as a whole did nothing:
## the resolver reports only COUNTS, the normalizer derives its arrays from keys the
## resolver never emits, and InjuryProcessor iterates the array that was therefore
## always empty. The post-battle wizard still announced "Casualty 1: Serious injury
## (2 turns recovery)" from the count, so it LOOKED like it worked.
##
## These cases assert the joins, not the individual links.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const Normalizer = preload("res://src/core/battle/BattleResultNormalizer.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryProcessorClass = preload(
	"res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")


func _campaign_with_crew() -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({
		"campaign_id": "auto_res_t",
		"crew": {"members": [
			{"character_id": "c1", "character_name": "Ana", "species_id": "human"},
			{"character_id": "c2", "character_name": "Bo", "species_id": "kerin"},
		]},
	})
	return c


func _resolver_shaped_result(downed_index: int, crew: Array) -> Dictionary:
	## What BattleResolver actually returns: counts + crew_units_final, and NONE of
	## the per-character arrays the normalizer needs.
	var finals: Array = []
	for i in range(crew.size()):
		finals.append({"is_alive": i != downed_index})
	return {
		"success": true, "victory": true, "won": true,
		"crew_casualties": 1,
		"enemies_defeated": 3,
		"crew_units_final": finals,
		"auto_resolved": true,
	}


# --- the join the resolver never made -----------------------------------------

func test_normalizer_produces_nothing_from_a_raw_resolver_result() -> void:
	# Documents WHY the mapping step is required: this is the exact shape that used
	# to be handed straight to post-battle.
	var raw := _resolver_shaped_result(0, [{}, {}])
	var out: Dictionary = Normalizer.normalize(raw, {}, 1)
	assert_array(out.get("injuries_sustained", [])).override_failure_message(
		"a raw resolver result should yield no injuries — if it does, the mapping step is redundant"
	).is_empty()


func test_mapped_result_yields_injuries_the_processor_can_consume() -> void:
	var campaign = _campaign_with_crew()
	var crew: Array = campaign.crew_data["members"]
	var resolved := _resolver_shaped_result(0, crew)

	# The mapping step CampaignTurnController now performs.
	var casualties: Array = []
	var injuries: Array = []
	var finals: Array = resolved["crew_units_final"]
	for i in range(crew.size()):
		if not bool(finals[i].get("is_alive", true)):
			injuries.append(crew[i])
	resolved["crew_injuries_data"] = injuries
	resolved["crew_participants"] = crew.duplicate()

	var out: Dictionary = Normalizer.normalize(resolved, {}, 1)
	var sustained: Array = out.get("injuries_sustained", [])
	assert_int(sustained.size()).override_failure_message(
		"the mapped result still produced no injuries_sustained"
	).is_equal(1)
	assert_str(str(sustained[0].get("crew_id", ""))).override_failure_message(
		"the crew id did not survive into injuries_sustained — apply_crew_injury cannot match it"
	).is_equal("c1")


# --- the join into the crew member --------------------------------------------

func test_an_injury_actually_puts_the_crew_member_in_sick_bay() -> void:
	# The final link: InjuryProcessor -> apply_crew_injury -> canonical Sick Bay shape.
	var campaign = _campaign_with_crew()
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.injuries_sustained = [{"crew_id": "c1", "name": "Ana"}]

	var proc = InjuryProcessorClass.new()
	proc.process_injuries(ctx)

	# The D100 injury roll decides injured-vs-fatal, so assert the member was MUTATED
	# EITHER WAY. Before the fix the whole function aborted on a has_method() call
	# against a Dictionary and the member was left completely untouched.
	var member: Dictionary = campaign.get_crew_member_by_id("c1")
	assert_object(member).is_not_null()
	var in_bay: bool = bool(member.get("in_sick_bay", false)) \
		or int(member.get("recovery_turns", 0)) > 0 \
		or str(member.get("status", "")) == "injured"
	var dead: bool = str(member.get("status", "")) == "DEAD" \
		or bool(member.get("is_dead", false))
	# A recorded injury is the invariant, NOT Sick Bay specifically: the D100 table
	# includes zero-recovery results (KNOCKED OUT, "No long-term effect") which are
	# correctly logged on the sheet without benching anyone. Requiring in_sick_bay
	# would have failed on a legitimate roll.
	var recorded: bool = bool(member.get("is_wounded", false)) \
		or (member.get("injuries", []) is Array and (member.get("injuries") as Array).size() > 0)
	assert_bool(in_bay or dead or recorded).override_failure_message(
		"the injury left the crew member completely untouched — no injuries[], no "
		+ "is_wounded, not dead. Member: %s" % str(member)
	).is_true()


func test_a_fatal_injury_marks_the_member_dead() -> void:
	# status "DEAD" was READ by PostBattleCompletion:205 and filter_deployable, and
	# never WRITTEN by anything. Drive apply_crew_death directly so the assertion does
	# not depend on the D100 roll.
	var campaign = _campaign_with_crew()
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	assert_bool(ctx.apply_crew_death("c1")).is_true()

	var member: Dictionary = campaign.get_crew_member_by_id("c1")
	assert_str(str(member.get("status", ""))).override_failure_message(
		"a killed crew member is not marked DEAD, so they stay deployable and are "
		+ "journalled as having survived"
	).is_equal("DEAD")


func test_a_dead_crew_member_is_not_deployable() -> void:
	var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("filter_deployable"):
		return
	var deployable: Array = gsm.filter_deployable([
		{"character_id": "c1", "status": "DEAD", "is_dead": true},
		{"character_id": "c2"},
	])
	var ids: Array = []
	for m in deployable:
		ids.append(str(m.get("character_id", "")))
	assert_array(ids).override_failure_message(
		"a dead crew member is still deployable: %s" % str(ids)
	).is_equal(["c2"])


func test_an_uninjured_crew_member_is_not_touched() -> void:
	var campaign = _campaign_with_crew()
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.injuries_sustained = [{"crew_id": "c1", "name": "Ana"}]
	var proc = InjuryProcessorClass.new()
	proc.process_injuries(ctx)

	var other: Dictionary = campaign.get_crew_member_by_id("c2")
	assert_bool(bool(other.get("in_sick_bay", false))
		or str(other.get("status", "")) == "DEAD").override_failure_message(
		"an unrelated crew member was injured or killed"
	).is_false()


# --- the filter that keeps them out of the NEXT battle -------------------------

func test_a_sick_bay_member_is_excluded_from_the_next_deployment() -> void:
	# Closes the loop: the injury above must actually keep them out next turn. This is
	# the filter that was applied at 3 of 4 crew-to-battle sites, missing exactly on
	# the auto-resolve path.
	var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("filter_deployable"):
		return
	var crew: Array = [
		{"character_id": "c1", "character_name": "Ana", "in_sick_bay": true,
			"recovery_turns": 2},
		{"character_id": "c2", "character_name": "Bo"},
	]
	var deployable: Array = gsm.filter_deployable(crew)
	var ids: Array = []
	for m in deployable:
		ids.append(str(m.get("character_id", "")))
	assert_array(ids).override_failure_message(
		"a Sick Bay crew member is still deployable: %s" % str(ids)
	).is_equal(["c2"])
