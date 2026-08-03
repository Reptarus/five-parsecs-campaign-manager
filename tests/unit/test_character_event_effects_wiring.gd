extends GdUnitTestSuite
## Character Events that described an outcome and produced none (Core Rules pp.128-130).
##
## Post-battle step 13 rolls D100 on this table every single battle, so a row
## that only returns a sentence is a rule the player is TOLD happened and never
## sees. Seven were in that state:
##
##   11-12 Time to Move On   the 1D6-vs-recovery-turns roll never happened, so
##                           nobody ever left the crew from Sick Bay
##   20-23 Scrap             the Feeler and K'Erin special cases were wired and
##                           the FIGHT was not — no one ever went to Sick Bay
##   24-26 Good Food         paid +1 XP unconditionally, so a character in Sick
##                           Bay got XP they are not owed AND kept the recovery
##                           turn they should have lost; Engineers got a benefit
##                           the book denies them
##   42-45 Heart to Heart    "BOTH earn +1 XP" paid only one of the two
##   52-55 Scars             +2 XP unconditionally — the largest free XP source
##                           on the table, gated on an injury nobody checked
##   67-68 True Love         the +1 story point landed, the Motivation-specific
##                           +1D6 XP did not
##   72-75 Gift              "Roll once on the Loot Table" rolled nothing
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CharacterEventEffectsClass = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")


func _ctx(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "cev", "crew": {"members": members}})
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 5}
	return ctx


func _member(id: String, name: String, extra: Dictionary = {}) -> Dictionary:
	var m := {
		"character_id": id, "character_name": name,
		"combat": 1, "speed": 4, "toughness": 3, "luck": 0,
		"experience": 0, "equipment": [], "status_effects": [],
		"origin": "human", "species_id": "human",
	}
	for k in extra:
		m[k] = extra[k]
	return m


func _sick(id: String, name: String, turns: int) -> Dictionary:
	return _member(id, name, {
		"injuries": [{"type": "MINOR_INJURY", "recovery_turns": turns,
			"turn_sustained": 5}],
		"in_sick_bay": true, "recovery_turns": turns, "status": "injured",
	})


# --- 11-12 Time to Move On ----------------------------------------------------

func test_time_to_move_on_does_nothing_outside_sick_bay() -> void:
	# p.128 conditions the whole row on "IF the character is currently in Sick Bay".
	var ctx = _ctx([_member("c1", "Kaya")])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Time to Move On", m, ctx)
	assert_str(str(m.get("status", ""))).is_not_equal("departed")


func test_time_to_move_on_can_actually_remove_a_crew_member() -> void:
	# 6 turns of recovery left means a D6 can never exceed it, so the departure
	# is certain — the roll is real, the outcome here is not luck.
	var ctx = _ctx([_sick("c1", "Kaya", 6), _member("c2", "Rho")])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	var msg: String = fx.apply_effect("Time to Move On", m, ctx)
	assert_str(str(m.get("status", ""))).override_failure_message(
		"6 turns left: every D6 result is <= 6, so they must leave. Msg: %s" % msg
	).is_equal("departed")


# --- 20-23 Scrap with Crewmate ------------------------------------------------

func test_the_scrap_actually_sends_someone_to_sick_bay() -> void:
	# p.129: "roll 1D6+Combat Skill for each. The lower score must spend one
	# campaign turn in Sick Bay. On a draw, both go."
	var ctx = _ctx([_member("c1", "Kaya"), _member("c2", "Rho")])
	var fx = CharacterEventEffectsClass.new()
	var a: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Scrap with Crewmate", a, ctx)

	var b: Dictionary = ctx.campaign.get_crew_member_by_id("c2")
	var hurt: int = 0
	for m in [a, b]:
		if ctx.get_member_recovery_turns(m) > 0:
			hurt += 1
	assert_int(hurt).override_failure_message(
		"a brawl with equal Combat Skill must put at least one of them in Sick "
		+ "Bay (both on a draw) — nobody was hurt"
	).is_greater(0)


func test_a_lone_crew_member_has_nobody_to_scrap_with() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Scrap with Crewmate", m, ctx)
	assert_int(ctx.get_member_recovery_turns(m)).override_failure_message(
		"there was no one to fight, so nobody should be injured").is_equal(0)


# --- 24-26 Good Food ----------------------------------------------------------

func test_good_food_shortens_a_sick_bay_stay_instead_of_paying_xp() -> void:
	var ctx = _ctx([_sick("c1", "Kaya", 3)])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Good Food", m, ctx)

	assert_int(ctx.get_member_recovery_turns(m)).override_failure_message(
		"p.129: in Sick Bay the reward is a turn off, not XP").is_equal(2)
	assert_int(int(m.get("experience", 0))).override_failure_message(
		"a character in Sick Bay must NOT also collect the +1 XP").is_equal(0)


func test_good_food_pays_xp_when_healthy() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Good Food", m, ctx)
	assert_int(int(m.get("experience", 0))).is_equal(1)


func test_engineers_receive_no_benefit_from_the_local_food() -> void:
	# p.129, verbatim: "Engineers receive no benefit from this."
	var ctx = _ctx([_member("c1", "Cog", {"origin": "engineer", "species_id": "engineer"})])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Good Food", m, ctx)
	assert_int(int(m.get("experience", 0))).is_equal(0)


# --- 42-45 Heart to Heart -----------------------------------------------------

func test_heart_to_heart_pays_both_characters() -> void:
	# p.129: "Select a random crew member. BOTH earn +1 XP."
	var ctx = _ctx([_member("c1", "Kaya"), _member("c2", "Rho")])
	var fx = CharacterEventEffectsClass.new()
	var a: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Heart to Heart", a, ctx)
	var b: Dictionary = ctx.campaign.get_crew_member_by_id("c2")
	assert_int(int(a.get("experience", 0))).is_equal(1)
	assert_int(int(b.get("experience", 0))).override_failure_message(
		"the crewmate the rule exists to include earned nothing").is_equal(1)


# --- 52-55 Scars Tell the Story -----------------------------------------------

func test_scars_pay_nothing_without_a_recent_injury() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Scars Tell the Story", m, ctx)
	assert_int(int(m.get("experience", 0))).override_failure_message(
		"p.129 gates this on being injured last or this turn; an unhurt "
		+ "character collected 2 free XP"
	).is_equal(0)


func test_scars_pay_two_xp_when_recently_injured() -> void:
	var ctx = _ctx([_sick("c1", "Kaya", 2)])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Scars Tell the Story", m, ctx)
	assert_int(int(m.get("experience", 0))).is_equal(2)


func test_a_zero_turn_injury_still_counts_as_a_scar() -> void:
	# Knocked out / Equipment loss leave no recovery time but ARE injuries
	# "in any way", so the turn stamp is what carries them.
	var ctx = _ctx([_member("c1", "Kaya", {
		"injuries": [{"type": "KNOCKED_OUT", "recovery_turns": 0, "turn_sustained": 5}],
	})])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Scars Tell the Story", m, ctx)
	assert_int(int(m.get("experience", 0))).is_equal(2)


# --- 67-68 Found True Love ----------------------------------------------------

func test_true_love_pays_the_motivation_bonus() -> void:
	# p.129: "If the character's motivation was True Love, they earn +1D6 XP.
	# Regardless, get +1 story point."
	var ctx = _ctx([_member("c1", "Kaya", {"motivation": "true love"})])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Found True Love", m, ctx)
	assert_int(int(m.get("experience", 0))).override_failure_message(
		"the one row that rewards a specific Motivation rewarded nothing"
	).is_between(1, 6)


func test_true_love_pays_no_xp_to_other_motivations() -> void:
	var ctx = _ctx([_member("c1", "Kaya", {"motivation": "wealth"})])
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Found True Love", m, ctx)
	assert_int(int(m.get("experience", 0))).is_equal(0)


# --- 72-75 Gift ---------------------------------------------------------------

func test_the_gift_reaches_the_stash() -> void:
	# p.129: "Someone has sent you a gift. Roll once on the Loot Table (p.131)."
	var ctx = _ctx([_member("c1", "Kaya")])
	ctx.campaign.equipment_data = {"equipment": []}
	var fx = CharacterEventEffectsClass.new()
	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	fx.apply_effect("Gift", m, ctx)
	assert_int(ctx.get_stash_items().size()).override_failure_message(
		"the gift never reached the ship stash — the loot roll produced nothing"
	).is_greater(0)
