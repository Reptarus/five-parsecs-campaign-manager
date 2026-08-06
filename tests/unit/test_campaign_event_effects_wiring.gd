extends GdUnitTestSuite
## Campaign Events that described an outcome and produced none (Core Rules pp.126-128).
##
##   57-59 New Captain        rolled the D6 and discarded it. The is_captain flag
##                            never moved, the 3 XP were never paid, and the old
##                            captain never left — a whole leadership-change event
##                            was two return strings.
##   79-81 Renegotiate Debts  rolled the relief, ignored it, and paid the 2
##                            credits UNCONDITIONALLY, so a crew carrying ship
##                            debt got the consolation prize meant for the
##                            debt-free and their loan never moved.
##   82-84 Rumors of War      "+2 to all Invasion rolls while you remain on this
##                            planet" had no producer at all.
##   98-100 Great Story       paid the story point every time and the +1 Luck
##                            never — the branch the book puts FIRST did nothing.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CampaignEventEffectsClass = preload(
	"res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")


func _member(id: String, name: String, extra: Dictionary = {}) -> Dictionary:
	var m := {
		"character_id": id, "character_name": name,
		"combat": 1, "speed": 4, "toughness": 3, "luck": 0,
		"experience": 0, "equipment": [], "status_effects": [],
		"origin": "human", "species_id": "human", "is_captain": false,
	}
	for k in extra:
		m[k] = extra[k]
	return m


func _ctx(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "cev2", "crew": {"members": members}})
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 4}
	return ctx


# --- 57-59 New Captain --------------------------------------------------------

func test_the_captaincy_actually_changes_hands() -> void:
	var ctx = _ctx([
		_member("c1", "Old Boss", {"is_captain": true}),
		_member("c2", "Rho"),
	])
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("New Captain", ctx)

	var old_c: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	var new_c: Dictionary = ctx.campaign.get_crew_member_by_id("c2")
	assert_bool(bool(new_c.get("is_captain", false))).override_failure_message(
		"the successor was never flagged as captain").is_true()
	assert_bool(bool(old_c.get("is_captain", true))).override_failure_message(
		"the old captain still holds the rank — two captains at once"
	).is_false()
	assert_int(int(new_c.get("experience", 0))).override_failure_message(
		"p.127: the new captain 'immediately receives 3 XP'").is_equal(3)


func test_a_kerin_must_be_selected_when_present() -> void:
	# p.127: "If your crew has any K'Erin, one of them MUST be selected."
	var ctx = _ctx([
		_member("c1", "Old Boss", {"is_captain": true}),
		_member("c2", "Rho"),
		_member("c3", "Krath", {"species_id": "k'erin", "origin": "k'erin"}),
	])
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("New Captain", ctx)
	assert_bool(bool(ctx.campaign.get_crew_member_by_id("c3").get("is_captain", false))) \
		.override_failure_message("the K'Erin was passed over — the book forbids it") \
		.is_true()


func test_a_solo_captain_has_no_successor() -> void:
	var ctx = _ctx([_member("c1", "Old Boss", {"is_captain": true})])
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("New Captain", ctx)
	assert_bool(bool(ctx.campaign.get_crew_member_by_id("c1").get("is_captain", false))) \
		.override_failure_message("with nobody to promote the captain must keep the rank") \
		.is_true()


# --- 79-81 Renegotiate Debts --------------------------------------------------

func test_renegotiating_reduces_real_debt_and_pays_no_credits() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	ctx.campaign.ship_debt = 20
	ctx.campaign.credits = 5
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Renegotiate Debts", ctx)

	# 1D6+1 is 2..7 off a 20-credit loan.
	assert_int(int(ctx.campaign.ship_debt)).override_failure_message(
		"p.127 reduces the debt by 1D6+1; the loan did not move"
	).is_between(13, 18)
	assert_int(int(ctx.campaign.credits)).override_failure_message(
		"the +2 credits are for a DEBT-FREE crew only — a crew in debt was paid "
		+ "the consolation prize as well"
	).is_equal(5)


func test_a_debt_free_crew_earns_the_two_credits() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	ctx.campaign.ship_debt = 0
	var before: int = int(ctx.campaign.credits)
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Renegotiate Debts", ctx)
	assert_int(int(ctx.campaign.credits)).is_equal(before + 2)


func test_debt_never_goes_negative() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	ctx.campaign.ship_debt = 1
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Renegotiate Debts", ctx)
	assert_int(int(ctx.campaign.ship_debt)).is_equal(0)


# --- 98-100 Great Story -------------------------------------------------------

func test_a_casualty_earns_the_luck_not_a_story_point() -> void:
	# p.127: "Select a crew member who was a casualty last battle. They receive
	# +1 LUCK. If nobody got hurt, receive +1 story point INSTEAD."
	var ctx = _ctx([_member("c1", "Kaya"), _member("c2", "Rho")])
	ctx.battle_result = {"turn": 4, "casualties": [{"crew_id": "c1"}]}
	var sp_before: int = int(ctx.campaign.story_points)
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Great Story", ctx)

	assert_int(int(ctx.campaign.get_crew_member_by_id("c1").get("luck", 0))) \
		.override_failure_message("the casualty earned no Luck").is_equal(1)
	assert_int(int(ctx.campaign.story_points)).override_failure_message(
		"the story point is the ELSE branch — it must not pay out as well"
	).is_equal(sp_before)


func test_no_casualties_pays_the_story_point() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	ctx.battle_result = {"turn": 4, "casualties": []}
	var sp_before: int = int(ctx.campaign.story_points)
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Great Story", ctx)
	assert_int(int(ctx.campaign.story_points)).is_equal(sp_before + 1)
	assert_int(int(ctx.campaign.get_crew_member_by_id("c1").get("luck", 0))).is_equal(0)


func test_the_played_paths_downed_list_also_counts_as_a_casualty() -> void:
	# The played path routes downed crew to the Injury Table and leaves
	# `casualties` empty, so Great Story must read the other shapes too or it
	# silently falls to the story-point branch after a bloody fight.
	var ctx = _ctx([_member("c1", "Kaya")])
	ctx.battle_result = {"turn": 4, "casualties": [], "units_downed": ["c1"]}
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Great Story", ctx)
	assert_int(int(ctx.campaign.get_crew_member_by_id("c1").get("luck", 0))).is_equal(1)


# --- 82-84 Rumors of War ------------------------------------------------------

func test_rumors_of_war_records_a_planet_scoped_modifier() -> void:
	# p.127: "While you remain on THIS PLANET, any roll for Invasion is at +2."
	# Planet-scoped, not global — a global flag would follow the crew across the
	# sector forever.
	var ctx = _ctx([_member("c1", "Kaya")])
	var fx = CampaignEventEffectsClass.new()
	fx.apply_effect("Rumors of War", ctx)
	assert_bool(ctx.campaign.progress_data.has("rumors_of_war_planet")) \
		.override_failure_message(
			"the event recorded nothing, so the +2 has no producer"
		).is_true()
