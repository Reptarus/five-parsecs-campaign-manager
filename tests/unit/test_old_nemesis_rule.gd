extends GdUnitTestSuite
## T11-25 / T11-35 — the two Campaign Events that create a Rival with riders.
##
## Core Rules p.126, rolls 21-23, verbatim:
##   "An old nemesis has tracked you down. Select a prior Rival, or roll up a new
##    one. They will follow you from planet to planet until resolved and receive +1
##    when rolling for the number of enemies in a battle."
##
## Core Rules p.128, rolls 89-91, verbatim:
##   "You got noticed by someone you'd rather avoid. Add a Rival. If you currently
##    are on a Quest, the next campaign turn is automatically a battle against the
##    new Rival, and they will add +1 to the number of enemies."
##
## WHAT WAS WRONG. Old Nemesis called ctx.add_rival("Old nemesis (persistent, +1
## enemies)") — the EFFECT STRING as the Rival's NAME, which is what the device walk
## found printed on the World Record Sheet — and applied neither rider anywhere. The
## "select a prior Rival" half of the rule was not modelled at all. Got Noticed
## likewise named both of its riders in a returned string and applied neither.
##
## ⚠ SCOPE OF THE p.128 CONDITIONAL. The "If you currently are on a Quest" clause
## governs the WHOLE second sentence, so the forced battle AND the +1 enemies are
## both Quest-only. The shipped table agrees (campaign_events.json encodes them as
## `quest_forced_battle` and `enemy_bonus_if_quest`). Off-Quest it is a plain
## "Add a Rival". Asserted in both directions below, because a rider that fires
## unconditionally is as wrong as one that never fires.

const EffectsScript = preload(
	"res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")
const ContextScript = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CampaignCoreScript = preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")
const NewWorldArrivalScript = preload("res://src/core/campaign/NewWorldArrival.gd")
const RivalCheckScript = preload("res://src/core/campaign/RivalEncounterCheck.gd")
const EnemyGeneratorScript = preload("res://src/core/systems/EnemyGenerator.gd")


## Minimal stand-in for the GameState autoload: process_campaign_event only asks it
## one question, and driving the real singleton would make this suite depend on
## whatever campaign another suite left loaded.
class QuestStateStub:
	extends RefCounted
	var on_quest: bool = false
	var current_campaign: Variant = null
	func has_active_quest() -> bool:
		return on_quest


func _ctx(rivals: Array = [], on_quest: bool = false) -> Variant:
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "nemesis_t"})
	campaign.rivals = rivals
	var ctx = ContextScript.new()
	ctx.campaign = campaign
	var stub := QuestStateStub.new()
	stub.on_quest = on_quest
	stub.current_campaign = campaign
	ctx.game_state = stub
	ctx.battle_result = {"turn": 4, "planet_id": "planet_x"}
	return ctx


func _rivals_of(ctx) -> Array:
	return ctx.campaign.rivals


# ---------------------------------------------------------------------------
# p.126 — Old Nemesis
# ---------------------------------------------------------------------------

func test_with_no_prior_rivals_it_rolls_one_up_with_both_riders() -> void:
	var ctx = _ctx([])
	var effects = EffectsScript.new()
	var text: String = effects.apply_effect("Old Nemesis", ctx)

	var rivals: Array = _rivals_of(ctx)
	assert_int(rivals.size()).override_failure_message(
		"Expected exactly one Rival to be rolled up. Got %d." % rivals.size()
	).is_equal(1)
	var r: Dictionary = rivals[0]
	assert_bool(bool(r.get("persistent", false))).override_failure_message(
		"p.126: 'They will follow you from planet to planet until resolved.'"
	).is_true()
	assert_int(int(r.get("enemy_count_bonus", 0))).override_failure_message(
		"p.126: '+1 when rolling for the number of enemies in a battle.'"
	).is_equal(1)
	assert_bool(effects.pending_nemesis_choice.is_empty()).override_failure_message(
		"There was nothing to select FROM, so no chooser should be pending."
	).is_true()
	assert_str(text).is_not_empty()


## The NAME must be a name. This is the finding as it was seen on the sheet.
func test_the_rival_is_not_named_after_its_own_effects() -> void:
	var ctx = _ctx([])
	EffectsScript.new().apply_effect("Old Nemesis", ctx)
	var name: String = str(_rivals_of(ctx)[0].get("name", ""))
	assert_str(name).override_failure_message(
		"The Rival was named '%s' — an effect string leaked into the name field, "
		% name + "which is what the World Record Sheet printed."
	).not_contains("+1")
	assert_str(name).not_contains("persistent")


## A Rival IS an enemy type (p.119). The old code picked from an invented list
## ["Criminal", "Corporate", "Personal", "Gang"] that is in neither rulebook.
func test_the_rolled_type_is_a_real_enemy_type() -> void:
	for _i in range(12):
		var ctx = _ctx([])
		EffectsScript.new().apply_effect("Old Nemesis", ctx)
		var rtype: String = str(_rivals_of(ctx)[0].get("type", ""))
		assert_bool(EnemyGeneratorScript.is_known_enemy_type(rtype)) \
			.override_failure_message(
				"Rival type '%s' is not one of the 60 enemy names in " % rtype
				+ "data/enemy_types.json. p.94's Unknown Rival column is the only "
				+ "non-invented source for an event-created Rival's type."
			).is_true()


## p.101: "Enemies from this list never become Rivals" — and accordingly the p.94
## Unknown Rival column has no Roving Threats band at all.
func test_a_rolled_rival_is_never_a_roving_threat() -> void:
	var roving: Dictionary = {}
	var file := FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	for category in (parsed as Dictionary).get("enemy_categories", []):
		if str(category.get("id", "")) != "roving_threats":
			continue
		for enemy in category.get("enemies", []):
			roving[str(enemy.get("name", ""))] = true
	assert_int(roving.size()).override_failure_message(
		"No Roving Threats found in the data file; this case proves nothing."
	).is_greater(0)

	for _i in range(25):
		var ctx = _ctx([])
		EffectsScript.new().apply_effect("Old Nemesis", ctx)
		var rtype: String = str(_rivals_of(ctx)[0].get("type", ""))
		assert_bool(roving.has(rtype)).override_failure_message(
			"Rolled a Roving Threat ('%s') as a Rival, which p.101 forbids." % rtype
		).is_false()


## An existing Rival list means the player owes a CHOICE, and nothing may be
## created until they make it — creating one now and letting them pick as well
## would hand out two Rivals for a one-Rival event.
func test_with_prior_rivals_it_offers_a_choice_and_creates_nothing() -> void:
	var priors: Array = [
		{"id": "r1", "name": "Gangers Vendetta", "type": "Gangers"},
		{"id": "r2", "name": "Enforcers Vendetta", "type": "Enforcers"},
	]
	var ctx = _ctx(priors.duplicate(true))
	var effects = EffectsScript.new()
	effects.apply_effect("Old Nemesis", ctx)

	assert_int(_rivals_of(ctx).size()).override_failure_message(
		"A Rival was created before the player chose."
	).is_equal(2)

	var choice: Dictionary = effects.pending_nemesis_choice
	assert_bool(choice.is_empty()).is_false()
	var ids: Array = []
	for opt in choice.get("options", []):
		ids.append(str(opt.get("id", "")))
	assert_array(ids).override_failure_message(
		"The chooser must list every prior Rival plus the roll-new branch. Got %s."
		% [ids]
	).contains(["r1", "r2", "roll_new"])


func test_choosing_a_prior_rival_applies_the_riders_to_that_rival() -> void:
	var ctx = _ctx([
		{"id": "r1", "name": "Gangers Vendetta", "type": "Gangers"},
		{"id": "r2", "name": "Enforcers Vendetta", "type": "Enforcers"},
	])
	var effects = EffectsScript.new()
	effects.apply_effect("Old Nemesis", ctx)
	var result: Dictionary = effects.resolve_nemesis_choice("r2", ctx)

	assert_bool(bool(result.get("applied", false))).is_true()
	assert_int(_rivals_of(ctx).size()).override_failure_message(
		"Choosing a PRIOR Rival must not also create a new one."
	).is_equal(2)

	var chosen: Dictionary = {}
	var untouched: Dictionary = {}
	for r in _rivals_of(ctx):
		if str(r.get("id", "")) == "r2":
			chosen = r
		else:
			untouched = r
	assert_bool(bool(chosen.get("persistent", false))).is_true()
	assert_int(int(chosen.get("enemy_count_bonus", 0))).is_equal(1)
	assert_bool(untouched.has("persistent")).override_failure_message(
		"The riders landed on a Rival the player did not select."
	).is_false()


func test_choosing_roll_new_creates_exactly_one_rival() -> void:
	var ctx = _ctx([{"id": "r1", "name": "Gangers Vendetta", "type": "Gangers"}])
	var effects = EffectsScript.new()
	effects.apply_effect("Old Nemesis", ctx)
	effects.resolve_nemesis_choice("roll_new", ctx)

	assert_int(_rivals_of(ctx).size()).is_equal(2)
	var fresh: Dictionary = _rivals_of(ctx)[1]
	assert_bool(bool(fresh.get("persistent", false))).is_true()
	assert_int(int(fresh.get("enemy_count_bonus", 0))).is_equal(1)


## The choice is one-shot: a duplicate resolve must not grant a second Rival.
func test_the_choice_cannot_be_resolved_twice() -> void:
	var ctx = _ctx([{"id": "r1", "name": "Gangers Vendetta", "type": "Gangers"}])
	var effects = EffectsScript.new()
	effects.apply_effect("Old Nemesis", ctx)
	effects.resolve_nemesis_choice("roll_new", ctx)
	var second: Dictionary = effects.resolve_nemesis_choice("roll_new", ctx)

	assert_bool(bool(second.get("applied", false))).is_false()
	assert_int(_rivals_of(ctx).size()).override_failure_message(
		"Resolving twice created a second Rival."
	).is_equal(2)


# ---------------------------------------------------------------------------
# The label -> type rule
# ---------------------------------------------------------------------------

## "Enforcers" MUST stay Enforcers: the p.96 Cop-killer rule ("If you ever fight
## Enforcers as Rivals, add +2 to their numbers") keys on that exact name.
func test_a_label_that_already_names_an_enemy_type_is_kept() -> void:
	var ctx = _ctx([])
	ctx.add_rival("Enforcers")
	assert_str(str(_rivals_of(ctx)[0].get("type", ""))).is_equal("Enforcers")


# ---------------------------------------------------------------------------
# Consumer 1 — p.126 "follow you from planet to planet"
# ---------------------------------------------------------------------------

## A persistent Rival follows unconditionally, an ordinary one does not.
##
## Both arms run the SAME 40 seeds and differ in exactly one key, so the ordinary
## Rival being left behind at least once is the control that proves the seeds are
## actually producing failing rolls — without it, "persistent always survived"
## could just mean every seed rolled 5+.
func test_persistent_follows_where_an_ordinary_rival_is_left_behind() -> void:
	var persistent_kept: int = 0
	var ordinary_kept: int = 0
	for s: int in range(40):
		var c1 = CampaignCoreScript.new()
		c1.from_dictionary({"campaign_id": "follow_p"})
		c1.rivals = [{"id": "r1", "name": "Old nemesis", "type": "Gangers",
			"persistent": true}]
		var rng1 := RandomNumberGenerator.new()
		rng1.seed = s
		NewWorldArrivalScript.apply(c1, rng1)
		persistent_kept += c1.rivals.size()

		var c2 = CampaignCoreScript.new()
		c2.from_dictionary({"campaign_id": "follow_o"})
		c2.rivals = [{"id": "r1", "name": "Ordinary Vendetta", "type": "Gangers"}]
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = s
		NewWorldArrivalScript.apply(c2, rng2)
		ordinary_kept += c2.rivals.size()

	assert_int(persistent_kept).override_failure_message(
		"A persistent Rival was left behind. p.126 says it follows 'until "
		+ "resolved', which is not a better roll - it is no roll."
	).is_equal(40)
	assert_int(ordinary_kept).override_failure_message(
		"The ordinary Rival followed on all 40 seeds, so none of them produced a "
		+ "failing p.72 roll and the persistent arm proves nothing."
	).is_less(40)


func test_a_persistent_rival_survives_every_seed() -> void:
	for s: int in range(40):
		var campaign = CampaignCoreScript.new()
		campaign.from_dictionary({"campaign_id": "follow_t"})
		campaign.rivals = [{"id": "r1", "name": "Old nemesis",
			"type": "Gangers", "persistent": true}]
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		NewWorldArrivalScript.apply(campaign, rng)
		assert_int(campaign.rivals.size()).override_failure_message(
			"Persistent Rival was left behind on seed %d." % s
		).is_equal(1)


# ---------------------------------------------------------------------------
# Consumer 2 — p.126/p.128 "+1 to the number of enemies"
# ---------------------------------------------------------------------------

func test_the_encounter_check_carries_the_bonus_off_the_rival() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var result: Dictionary = RivalCheckScript.check(
		[{"id": "r1", "name": "Old nemesis", "type": "Gangers",
			"persistent": true, "enemy_count_bonus": 1}], 0, rng)
	# One Rival and a D6: 1 is the only roll at or below the count, so retry until
	# the encounter happens rather than asserting on a particular seed's stream.
	var tries: int = 0
	while not bool(result.get("has_encounter", false)) and tries < 200:
		result = RivalCheckScript.check(
			[{"id": "r1", "name": "Old nemesis", "type": "Gangers",
				"persistent": true, "enemy_count_bonus": 1}], 0, null)
		tries += 1
	assert_bool(bool(result.get("has_encounter", false))).override_failure_message(
		"No encounter in 200 attempts; the case cannot assert anything."
	).is_true()
	assert_int(int(result.get("rival_enemy_count_bonus", 0))).override_failure_message(
		"The +1 was not carried onto the encounter result, so the battle can "
		+ "never see it."
	).is_equal(1)


## The generator must actually field the extra figure. Compares MEANS over many
## draws — the shape test_crew_size_enemy_calc.gd already uses for this generator,
## because the base count is dice-driven. The two arms differ in ONE key.
func test_the_generator_fields_one_more_figure_with_the_bonus() -> void:
	var gen = EnemyGeneratorScript.new()
	var iterations: int = 200
	var sum_plain: int = 0
	var sum_bonus: int = 0
	for _i in range(iterations):
		# Converted Infiltrators is a Roving Threat, which p.93 excludes from the
		# Unique Individual roll — so neither arm can gain figures for a second,
		# unrelated reason. Same isolation the difficulty case uses.
		var plain: Array = gen.generate_enemies_as_dicts({
			"mission_source": "opportunity",
			"enemy_type": "Converted Infiltrators",
			"danger_level": 2,
		}, 5)
		var bonus: Array = gen.generate_enemies_as_dicts({
			"mission_source": "opportunity",
			"enemy_type": "Converted Infiltrators",
			"danger_level": 2,
			"rival_enemy_count_bonus": 1,
		}, 5)
		sum_plain += plain.size()
		sum_bonus += bonus.size()

	assert_float(float(sum_bonus) / iterations).override_failure_message(
		"With the +1 the mean force was %.2f against %.2f without it — the "
		% [float(sum_bonus) / iterations, float(sum_plain) / iterations]
		+ "modifier is not reaching the enemy-count assembly."
	).is_greater(float(sum_plain) / iterations + 0.5)


# ---------------------------------------------------------------------------
# p.128 — Got Noticed (T11-35)
# ---------------------------------------------------------------------------

func test_off_quest_got_noticed_is_a_plain_add_a_rival() -> void:
	var ctx = _ctx([], false)
	EffectsScript.new().apply_effect("Got Noticed", ctx)

	assert_int(_rivals_of(ctx).size()).is_equal(1)
	var r: Dictionary = _rivals_of(ctx)[0]
	assert_bool(r.has("enemy_count_bonus")).override_failure_message(
		"The +1 fired off-Quest. p.128 puts both riders inside the 'If you "
		+ "currently are on a Quest' conditional."
	).is_false()
	assert_bool(ctx.campaign.progress_data.has("forced_rival_battle")) \
		.override_failure_message(
			"A forced battle was scheduled while not on a Quest."
		).is_false()


func test_on_quest_got_noticed_forces_a_battle_and_adds_an_enemy() -> void:
	var ctx = _ctx([], true)
	EffectsScript.new().apply_effect("Got Noticed", ctx)

	assert_int(_rivals_of(ctx).size()).is_equal(1)
	var r: Dictionary = _rivals_of(ctx)[0]
	assert_int(int(r.get("enemy_count_bonus", 0))).is_equal(1)
	assert_str(str(ctx.campaign.progress_data.get("forced_rival_battle", ""))) \
		.override_failure_message(
			"p.128: 'the next campaign turn is automatically a battle against the "
			+ "new Rival' — the flag must name that Rival."
		).is_equal(str(r.get("id", "")))


## The forced battle happens WITHOUT a roll, and against that Rival specifically.
func test_a_forced_id_produces_that_encounter_without_rolling() -> void:
	var rivals: Array = [
		{"id": "r1", "name": "Gangers Vendetta", "type": "Gangers"},
		{"id": "r2", "name": "Unwanted attention", "type": "Punks",
			"enemy_count_bonus": 1},
	]
	# Every seed must give the same answer — that is what "no roll" means.
	for s: int in range(25):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var result: Dictionary = RivalCheckScript.check(rivals, 0, rng, "", "r2")
		assert_bool(bool(result.get("has_encounter", false))).is_true()
		assert_str(str(result.get("rival_id", ""))).override_failure_message(
			"Seed %d produced a different Rival, so the battle is still being "
			% s + "rolled for rather than forced."
		).is_equal("r2")
		assert_int(int(result.get("rival_enemy_count_bonus", 0))).is_equal(1)


## A Story Event that forbids Rival attacks this turn is an absolute; the forced
## battle must lose to it (and the caller then leaves the flag set, so it lands on
## the next eligible turn rather than being silently spent).
func test_story_suppression_beats_a_forced_battle() -> void:
	var result: Dictionary = RivalCheckScript.check(
		[{"id": "r2", "name": "Unwanted attention", "type": "Punks"}],
		0, null, "Story Event 4: you cannot be attacked by Rivals", "r2")
	assert_bool(bool(result.get("has_encounter", false))).is_false()
	assert_bool(bool(result.get("suppressed", false))).is_true()


## A flag naming a Rival that has since been removed must not force a battle
## against nobody.
func test_a_stale_forced_id_falls_through_to_the_normal_roll() -> void:
	var result: Dictionary = RivalCheckScript.check(
		[{"id": "r1", "name": "Gangers Vendetta", "type": "Gangers"}],
		0, null, "", "deleted_rival")
	assert_bool(bool(result.get("forced", false))).is_false()
