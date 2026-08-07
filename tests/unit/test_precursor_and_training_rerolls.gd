extends GdUnitTestSuite
## Two p.125/p.126 rules that were implemented and never reached the table.
##
## 1. PRECURSOR CHARACTER EVENT (Core Rules p.17 + p.126). Three failures in
##    series, so fixing any one of them alone would have proved nothing:
##      a. the roll-twice branch compared an origin resolved by handing a crew_id
##         STRING to get_character_origin(), which takes a CHARACTER — it fell
##         through both branches and returned "Human" for everyone, so the
##         comparison was permanently false;
##      b. the orchestrator had no consumer for the choice envelope, which
##         carries no "type" key, so it fell through the has("type") guard and
##         the Character Event was DROPPED entirely;
##      c. the whole pipeline — signal, public API, dialog — was attached to the
##         step-12 CAMPAIGN Event instead, where the book has no such rule, and
##         the UI auto-picked event 1 anyway (statistically identical to not
##         rolling twice at all).
##
## 2. ADVANCED TRAINING REROLLS (Core Rules p.125). Medical school costs 20 XP
##    and Bot technician 10 XP, and neither did anything: no reroll existed at
##    either Injury Table roll site.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CharacterEventEffectsClass = preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
const CampaignEventEffectsClass = preload(
	"res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")
const InjuryProcessorClass = preload(
	"res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")
const CharacterClass = preload("res://src/core/character/Character.gd")


func _member(id: String, origin: String = "human", extra: Dictionary = {}) -> Dictionary:
	var m := {
		"character_id": id, "character_name": id.capitalize(),
		"combat": 1, "speed": 4, "toughness": 3, "luck": 0,
		"experience": 0, "equipment": [], "status_effects": [],
		"origin": origin, "species_id": origin,
		"acquired_training": [],
	}
	for k in extra:
		m[k] = extra[k]
	return m


func _ctx(members: Array, story_points: int = 0) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "pcr", "crew": {"members": members}})
	if "story_points" in c:
		c.story_points = story_points
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 3}
	return ctx


# ── 1. Precursor: the rule is on step 13, never step 12 ────────────────────

## p.125 step 12 is one line: "Roll D100 on the Campaign Event Table. Apply the
## result immediately." There is no Precursor clause anywhere on it. A whole-book
## sweep for "Precursor" finds the roll-twice rule only at p.17 and p.126, and
## both name the CHARACTER Event.
func test_campaign_event_never_offers_a_precursor_choice() -> void:
	var ctx = _ctx([_member("c1", "precursor"), _member("c2", "precursor")])
	var effects = CampaignEventEffectsClass.new()
	for i in 25:
		var event: Dictionary = effects.process_campaign_event(ctx)
		assert_bool(event.get("precursor_choice", false)).override_failure_message(
			"step 12 offered a Precursor double-roll the book does not grant"
		).is_false()
		assert_bool(event.has("type")).override_failure_message(
			"a campaign event with no 'type' key falls through the orchestrator's"
			+ " finalize guard and is silently dropped").is_true()


## The step-12 rewrite also gave the journal a real roll — finalize_event()
## logs event.get("roll", 0) and nothing had ever written the key.
func test_campaign_event_carries_its_roll() -> void:
	var ctx = _ctx([_member("c1")])
	var effects = CampaignEventEffectsClass.new()
	var event: Dictionary = effects.process_campaign_event(ctx)
	assert_int(int(event.get("roll", 0))).is_between(1, 100)


## The trap underneath all of it: get_character_origin() takes a CHARACTER, and
## `"origin" in "crew_1"` is a SUBSTRING test, not a property test, so a bare
## crew_id fell through every branch and answered "Human" for everyone. Both
## spellings are in the tree, so ids now resolve at the door.
func test_origin_resolves_from_a_crew_id_as_well_as_a_member() -> void:
	var ctx = _ctx([_member("c1", "precursor")])
	assert_str(str(ctx.get_character_origin("c1")).to_lower()).override_failure_message(
		"a crew_id resolved to the wrong origin — the Precursor branch, the"
		+ " p.126 Bot filter and every species check read through this"
	).is_equal("precursor")
	var member = ctx.get_crew_member("c1")
	assert_str(str(ctx.get_character_origin(member)).to_lower()).is_equal("precursor")
	assert_str(ctx.get_character_origin("no_such_id")).is_equal("Human")


## p.126, verbatim: "Select a random non-Bot, non-Soulless character." The
## eligibility filter passes crew_id STRINGS to is_character_bot_or_soulless(),
## so before the id resolution above it excluded nobody and Bots were eligible
## for Character Events the book forbids them.
func test_bot_and_soulless_are_excluded_from_character_events() -> void:
	var ctx = _ctx([_member("b1", "bot"), _member("s1", "soulless")])
	assert_bool(ctx.is_character_bot_or_soulless("b1")).is_true()
	assert_bool(ctx.is_character_bot_or_soulless("s1")).is_true()
	assert_bool(ctx.is_character_bot_or_soulless("c1")).is_false()

	# An all-Bot/Soulless crew leaves nobody eligible, so the step must produce
	# no event rather than rolling one for a figure that cannot have one.
	var effects = CharacterEventEffectsClass.new()
	var event: Dictionary = effects.process_character_event(ctx)
	assert_str(str(event.get("type", ""))).override_failure_message(
		"a Bot/Soulless-only crew was still handed a Character Event"
	).is_equal("none")


## An all-Precursor crew must ALWAYS reach the choice (the selected character is
## necessarily a Precursor), and the envelope must carry both rolls.
func test_precursor_character_event_offers_two_rolls() -> void:
	var ctx = _ctx([_member("c1", "precursor")])
	var effects = CharacterEventEffectsClass.new()
	var event: Dictionary = effects.process_character_event(ctx)
	assert_bool(event.get("precursor_choice", false)).override_failure_message(
		"the selected character is a Precursor and got no double-roll"
	).is_true()
	assert_bool(event.has("event1") and event.has("event2")).is_true()
	assert_bool(effects.waiting_for_precursor_choice).is_true()


## A crew with no Precursor must NOT get the choice — this is the half that
## proves the test above is not passing vacuously.
func test_non_precursor_crew_gets_an_ordinary_event() -> void:
	var ctx = _ctx([_member("c1", "human")])
	var effects = CharacterEventEffectsClass.new()
	for i in 15:
		var event: Dictionary = effects.process_character_event(ctx)
		assert_bool(event.get("precursor_choice", false)).override_failure_message(
			"a Human crew was offered the Precursor double-roll").is_false()


func test_precursor_choice_returns_the_selected_roll() -> void:
	var ctx = _ctx([_member("c1", "precursor")])
	var effects = CharacterEventEffectsClass.new()
	var envelope: Dictionary = effects.process_character_event(ctx)
	var second: Dictionary = envelope["event2"]
	var chosen: Dictionary = effects.select_precursor_event(2, ctx)
	assert_int(int(chosen.get("roll", -1))).is_equal(int(second.get("roll", -2)))
	assert_bool(effects.waiting_for_precursor_choice).is_false()


## p.17, the fuller statement of the rule: "If you would prefer avoiding the
## event altogether, you may do so by spending 1 story point after rolling
## twice." p.126 omits this third option entirely.
func test_precursor_can_avoid_the_event_for_one_story_point() -> void:
	var ctx = _ctx([_member("c1", "precursor")], 2)
	var effects = CharacterEventEffectsClass.new()
	effects.process_character_event(ctx)
	var chosen: Dictionary = effects.select_precursor_event(3, ctx)
	assert_str(str(chosen.get("type", ""))).override_failure_message(
		"an avoided event must be type 'none' so the orchestrator does not"
		+ " finalize it — that is what the story point bought").is_equal("none")
	assert_bool(chosen.get("precursor_avoided", false)).is_true()
	assert_int(int(ctx.campaign.story_points)).override_failure_message(
		"the story point was not spent").is_equal(1)


## The cost is not optional, so a player who cannot pay does not get the option.
## The two rolls have already happened and cannot be un-rolled, so the honest
## fallback is the first roll — never a free avoid.
func test_avoid_without_a_story_point_keeps_the_first_roll() -> void:
	var ctx = _ctx([_member("c1", "precursor")], 0)
	var effects = CharacterEventEffectsClass.new()
	var envelope: Dictionary = effects.process_character_event(ctx)
	var first: Dictionary = envelope["event1"]
	var chosen: Dictionary = effects.select_precursor_event(3, ctx)
	assert_bool(chosen.get("precursor_avoided", false)).override_failure_message(
		"the event was avoided without paying for it").is_false()
	assert_int(int(chosen.get("roll", -1))).is_equal(int(first.get("roll", -2)))
	assert_int(int(ctx.campaign.story_points)).is_equal(0)


# ── 2. p.125 Advanced Training rerolls ─────────────────────────────────────

## The legacy spelling. TrainingSelectionDialog granted `bot_tech` while
## CharacterDetailsScreen granted `bot_technician` (the SSOT id), so a campaign
## can hold either and a single-spelling check sees only half of them.
func test_has_training_accepts_the_legacy_bot_tech_spelling() -> void:
	var ch = CharacterClass.new()
	ch.add_training("bot_tech")
	assert_bool(ch.has_training("bot_technician")).override_failure_message(
		"a Bot technician trained through the post-battle dialog is invisible to"
		+ " a check that uses the data-file id").is_true()
	var canonical = CharacterClass.new()
	canonical.add_training("bot_technician")
	assert_bool(canonical.has_training("bot_technician")).is_true()
	assert_bool(canonical.has_training("medical")).is_false()


## "picking the better result" needs an ordering, and every term of it is a
## consequence the book itself attaches to the row — nothing is invented.
## Roll 1-15 is dead; roll 46+ is a plain Sick Bay stay.
func test_better_roll_prefers_survival() -> void:
	var proc = InjuryProcessorClass.new()
	assert_int(proc._better_roll(5, 60, false)).override_failure_message(
		"a fatal result was kept over a survivable one").is_equal(60)
	assert_int(proc._better_roll(60, 5, false)).is_equal(60)


## A tie keeps the FIRST roll, so a reroll can never make an outcome worse.
func test_better_roll_ties_keep_the_first_roll() -> void:
	var proc = InjuryProcessorClass.new()
	assert_int(proc._better_roll(60, 61, false)).is_equal(60)
	assert_int(proc._better_roll(61, 60, false)).is_equal(61)


## Determinism: the comparison must never consult a fresh dice roll, or the same
## pair could rank differently on two evaluations.
func test_better_roll_is_deterministic() -> void:
	var proc = InjuryProcessorClass.new()
	for pair in [[3, 88], [17, 42], [99, 1], [55, 55]]:
		var first: int = proc._better_roll(pair[0], pair[1], false)
		for i in 20:
			assert_int(proc._better_roll(pair[0], pair[1], false)).is_equal(first)


func test_bot_better_roll_prefers_survival() -> void:
	var proc = InjuryProcessorClass.new()
	# Bot table p.122: 1-5 Obliterated (destroyed). 61+ is a light result.
	assert_int(proc._better_roll(3, 70, true)).is_equal(70)
	assert_int(proc._better_roll(70, 3, true)).is_equal(70)


## Medical school: "you may nominate A casualty" — one figure, once per battle.
func test_medical_school_nominates_one_casualty() -> void:
	var medic := _member("medic", "human", {"acquired_training": ["medical"]})
	var hurt_a := _member("hurt_a")
	var hurt_b := _member("hurt_b")
	var ctx = _ctx([medic, hurt_a, hurt_b])
	ctx.crew_participants = ["medic", "hurt_a", "hurt_b"]
	ctx.injuries_sustained = [{"crew_id": "hurt_a"}, {"crew_id": "hurt_b"}]
	ctx.battle_result["medical_school_nominee_crew_id"] = "hurt_b"

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_str(proc._medical_nominee_id).override_failure_message(
		"the player's nomination was ignored").is_equal("hurt_b")


## "This crew member must have been in the battle and must not have become a
## casualty." A medic who is themselves a casualty cannot apply their skill.
func test_medic_who_is_a_casualty_grants_nothing() -> void:
	var medic := _member("medic", "human", {"acquired_training": ["medical"]})
	var ctx = _ctx([medic, _member("hurt_a")])
	ctx.crew_participants = ["medic", "hurt_a"]
	ctx.injuries_sustained = [{"crew_id": "medic"}, {"crew_id": "hurt_a"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_str(proc._medical_nominee_id).is_equal("")


## A medic who sat the battle out grants nothing WITHOUT a Shuttle...
func test_medic_who_sat_out_grants_nothing_without_a_shuttle() -> void:
	var medic := _member("medic", "human", {"acquired_training": ["medical"]})
	var ctx = _ctx([medic, _member("hurt_a")])
	ctx.crew_participants = ["hurt_a"]
	ctx.injuries_sustained = [{"crew_id": "hurt_a"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_str(proc._medical_nominee_id).is_equal("")


## ...and DOES with one: "If your ship has a Shuttle, you can evac fast enough
## that this crew member can apply their skill even if they did not participate."
func test_shuttle_waives_the_participation_requirement() -> void:
	var medic := _member("medic", "human", {"acquired_training": ["medical"]})
	var ctx = _ctx([medic, _member("hurt_a")])
	ctx.crew_participants = ["hurt_a"]
	ctx.injuries_sustained = [{"crew_id": "hurt_a"}]
	ctx.campaign.ship_data = {"components": [{"name": "Shuttle Bay"}]}

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_str(proc._medical_nominee_id).override_failure_message(
		"p.125: a Shuttle lets the medic apply their skill remotely"
	).is_equal("hurt_a")


## A crew with nobody trained gets neither reroll — the half that proves the
## rows above are not passing for free.
func test_untrained_crew_gets_no_rerolls() -> void:
	var ctx = _ctx([_member("a"), _member("b")])
	ctx.crew_participants = ["a", "b"]
	ctx.injuries_sustained = [{"crew_id": "a"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_str(proc._medical_nominee_id).is_equal("")
	assert_bool(proc._bot_technician_active).is_false()


## Bot technician has no participation clause and no per-battle limit, so simply
## having one on the roster arms every Bot/Soulless injury roll.
func test_bot_technician_arms_from_the_roster() -> void:
	var tech := _member("tech", "human", {"acquired_training": ["bot_technician"]})
	var ctx = _ctx([tech, _member("bot_a", "bot")])
	ctx.crew_participants = ["bot_a"]
	ctx.injuries_sustained = [{"crew_id": "bot_a"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_bool(proc._bot_technician_active).is_true()


## And it arms from the legacy spelling too, so an existing save is not punished.
func test_bot_technician_arms_from_the_legacy_spelling() -> void:
	var tech := _member("tech", "human", {"acquired_training": ["bot_tech"]})
	var ctx = _ctx([tech, _member("bot_a", "bot")])
	ctx.injuries_sustained = [{"crew_id": "bot_a"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_bool(proc._bot_technician_active).is_true()


## Medical school names "the Injury Table"; Bots roll on the Bot Injury Table,
## so a Bot is never the medic's nominee.
func test_medical_school_skips_bot_casualties() -> void:
	var medic := _member("medic", "human", {"acquired_training": ["medical"]})
	var ctx = _ctx([medic, _member("bot_a", "bot")])
	ctx.crew_participants = ["medic", "bot_a"]
	ctx.injuries_sustained = [{"crew_id": "bot_a"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "")
	assert_str(proc._medical_nominee_id).is_equal("")


## The Reduced Lethality exemption skips the roll entirely, so there is no roll
## for the medic to improve — the two options must not both target one figure.
func test_medical_school_skips_the_reduced_lethality_exemptee() -> void:
	var medic := _member("medic", "human", {"acquired_training": ["medical"]})
	var ctx = _ctx([medic, _member("hurt_a"), _member("hurt_b")])
	ctx.crew_participants = ["medic", "hurt_a", "hurt_b"]
	ctx.injuries_sustained = [{"crew_id": "hurt_a"}, {"crew_id": "hurt_b"}]

	var proc = InjuryProcessorClass.new()
	proc._resolve_training_rerolls(ctx, "hurt_a")
	assert_str(proc._medical_nominee_id).is_equal("hurt_b")
