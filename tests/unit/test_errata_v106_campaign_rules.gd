extends GdUnitTestSuite
## Errata v1.06 and the designer FAQ — the rulings the printed pages contradict.
## Sep 2026 page walk.
##
## Source: docs/gameplay/rules/5P_errata_and_tweaks106.pdf (pages 3 and 4; page 5
## is labelled "not official" in the document itself and stays excluded) plus the
## designer FAQ at modiphius.net/en-us/pages/five-parsecs-faq, items 13, 14 and
## 17.
##
## THE DEFECT CLASS THIS PINS. Every row below was implemented CORRECTLY against
## the printed rulebook, and the designer has since changed the rule. That is
## invisible to a code audit, a flag census and a producer/consumer census alike:
## the code matches its cited page. Only diffing against the errata finds it. Five
## rulings were being played the old way:
##
##   Lay Low          no producer of `battle_skipped` existed anywhere, so the
##                    app demanded a battle every single campaign turn while the
##                    orchestrator had had a consumer for the flag all along.
##   Creation Patrons offers come only from `patron_offers_owed` (a successful
##                    Find a Patron roll) or the p.84 Busy follow-up. Neither
##                    fires on turn 1, so a crew that rolled a Patron at creation
##                    opened its first World Phase with an empty job board.
##   Quest 7+         the Rumor pool carried over, so every Rumor spent finishing
##                    one Quest kept adding +1 to the next one's rolls forever.
##   Bio-upgrade      the sub-type applied its 2-credit PENALTY and not its
##                    compensating Implant.
##   Recruits         p.78's "basic profile, no background rolls" was implemented
##                    exactly; the errata replaces it with a full table roll.
##   Multi-job        accepting one Patron job consumed it and left the others to
##                    lapse; the errata lets the crew accept all of them.
##   Mods/sights      "single-shot" was never tested at all, so a Sight could be
##                    fitted to a grenade.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const WeaponModService = preload("res://src/core/equipment/WeaponModService.gd")
const LootResolver = preload("res://src/core/equipment/LootTableResolver.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const FinalizationService = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")

const CTC_SRC := "res://src/ui/screens/campaign/CampaignTurnController.gd"
const WPC_SRC := "res://src/ui/screens/world/WorldPhaseController.gd"
const WPC_TSCN := "res://src/ui/screens/world/WorldPhaseController.tscn"
const PBP_SRC := "res://src/core/campaign/phases/PostBattlePhase.gd"
const JOB_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const CREW_TASK_SRC := "res://src/ui/screens/world/components/CrewTaskComponent.gd"
const RESOLVER_SRC := "res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd"

## Core Rules p.133 Implants Subtable, all eleven rows.
const IMPLANT_NAMES := [
	"AI Companion", "Body Wire", "Boosted Arm", "Boosted Leg", "Cyber Hand",
	"Genetic Defenses", "Health Boost", "Nerve Adjuster",
	"Neural Optimization", "Night Sight", "Pain Suppressor",
]


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# ── 1. Lay Low (errata p.3 Update, FAQ 17) ────────────────────────────────

func test_the_world_phase_offers_a_lay_low_button() -> void:
	# The .tscn is the authority on what is actually instantiated, so the button
	# is asserted there rather than in the script.
	var scene: String = _read(WPC_TSCN)
	assert_str(scene).override_failure_message(
		"no Lay Low button exists in the World Phase footer"
	).contains('[node name="LayLowButton" type="Button"')
	assert_str(scene).override_failure_message(
		"the button must be a scene-unique node or %LayLowButton cannot resolve"
	).contains("unique_name_in_owner = true")


func test_the_button_signal_has_a_listener() -> void:
	# A signal declared and never connected is the commonest dead wire in this
	# project (67 of them were burned down in the Jul 2026 sweep). Both halves.
	assert_str(_read(WPC_SRC)).contains("signal lay_low_requested")
	assert_str(_read(CTC_SRC)).override_failure_message(
		"lay_low_requested has no listener, so the button does nothing"
	).contains("world_phase_controller.lay_low_requested.connect(_on_lay_low_requested)")


func test_laying_low_checks_for_rivals_before_charging() -> void:
	# Errata: "check for Rival attacks NORMALLY. If you are not attacked, you can
	# pay..." — the order is the rule. Charging first would take credits for a
	# stay the crew does not get (Core Rules p.85: a Rival that tracks you down
	# "will prevent you from doing whatever you had wanted to do this campaign
	# turn").
	var src: String = _read(CTC_SRC)
	var start: int = src.find("func _on_lay_low_requested()")
	assert_int(start).override_failure_message("no Lay Low handler").is_greater(-1)
	var after: int = src.find("\nfunc ", start + 10)
	var body: String = src.substr(start, after - start)
	var check_at: int = body.find("_check_rival_encounter_backend(")
	var charge_at: int = body.find("remove_credits(")
	assert_int(check_at).override_failure_message(
		"the Rival check is missing from the Lay Low path").is_greater(-1)
	assert_int(charge_at).override_failure_message(
		"nothing charges the 1D6+1 credits").is_greater(-1)
	assert_bool(check_at < charge_at).override_failure_message(
		"the crew is charged BEFORE the Rival check, so an ambushed crew pays for"
		+ " a stay it never gets"
	).is_true()


func test_the_rival_check_is_not_rolled_twice_in_one_turn() -> void:
	# Lay Low rolls it, and _initiate_battle_sequence() rolls it again on the
	# battle path. Without a per-turn stamp an ambushed crew could be told it was
	# clear and then ambushed anyway, or vice versa.
	assert_str(_read(CTC_SRC)).override_failure_message(
		"the p.85 Rival check has no per-turn guard, so Lay Low would roll it a"
		+ " second time"
	).contains('battle_results["rival_check_turn"] = _turn_number')


func test_a_skipped_battle_still_runs_the_turns_bookkeeping() -> void:
	# Errata: "skip the battle sequence and ALL REWARD SECTIONS (loot, pay,
	# injuries, XP)" — steps 4-10. A Campaign Event and a Character Event happen
	# because a TURN passed, so they stand. The old skip branch jumped straight to
	# completion and dropped 12-14 as well; nothing noticed because nothing could
	# produce the flag.
	var src: String = _read(PBP_SRC)
	var start: int = src.find('if battle_data.get("battle_skipped", false):')
	assert_int(start).is_greater(-1)
	var body: String = src.substr(start, 900)
	assert_str(body).override_failure_message(
		"a rest turn no longer rolls its Campaign Event"
	).contains("process_campaign_event")
	assert_str(body).override_failure_message(
		"a rest turn must still run steps 13-14 through the shared tail"
	).contains("_process_character_event_step()")


func test_a_skipped_battle_writes_no_battle_record() -> void:
	# There was no fight, so a battle journal entry, lifetime battle stats, a
	# Notable Sight reward or the p.67 "Bitter Day" story point would all invent
	# one — and Bitter Day pays for "held the field", which nobody did.
	var src: String = _read(PBP_SRC)
	var start: int = src.find("func _complete_post_battle_phase()")
	assert_int(start).is_greater(-1)
	var body: String = src.substr(start, 1200)
	assert_str(body).override_failure_message(
		"completion does not branch on battle_skipped, so a rest turn records a"
		+ " battle that never happened"
	).contains('battle_result.get("battle_skipped", false)')


func test_a_rest_turn_is_neither_a_win_nor_a_loss() -> void:
	# `victory` is absent on a skipped turn, so the else-branch counted a LOSS —
	# and battles_won/lost are rules-bearing (VictoryChecker reads the p.64
	# "Win N tabletop battles" conditions off them).
	assert_str(_read(CTC_SRC)).override_failure_message(
		"a rest turn still moves the W/L counters"
	).contains("if gsm and not was_skipped:")


# ── 2. Creation Patrons owe a turn-1 offer (errata p.3, FAQ 14) ───────────

func test_creation_patrons_are_banked_as_turn_one_offers() -> void:
	# Errata: "Patrons received during character creation will automatically grant
	# you a job offer in the FIRST CAMPAIGN TURN."
	var campaign := CampaignCore.new()
	var patrons: Array = [
		{"id": "starting_patron_1", "name": "Vasquez Holdings", "type": "Corporate"},
		{"name": "The Quiet Men", "type": "Criminal"},
	]
	FinalizationService._bank_creation_patron_offers(campaign, patrons)
	var owed: Array = campaign.progress_data.get("patron_followup_offers", [])
	assert_int(owed.size()).override_failure_message(
		"both creation patrons must owe an offer; got %s" % str(owed)
	).is_equal(2)
	# Identity must match JobOfferComponent._patron_identity: id, else patron_id,
	# else the name. That consumer DROPS ids it cannot match, so a mismatch here
	# would leave the offer unclaimed forever.
	assert_bool("starting_patron_1" in owed).is_true()
	assert_bool("The Quiet Men" in owed).override_failure_message(
		"a patron with no id must be banked under its NAME, which is what"
		+ " _patron_identity() falls back to"
	).is_true()


func test_banking_is_idempotent() -> void:
	# Finalization runs once, but a re-entry must not double the offers.
	var campaign := CampaignCore.new()
	var patrons: Array = [{"id": "p1", "name": "Once"}]
	FinalizationService._bank_creation_patron_offers(campaign, patrons)
	FinalizationService._bank_creation_patron_offers(campaign, patrons)
	assert_int((campaign.progress_data.get("patron_followup_offers", []) as Array).size()) \
		.is_equal(1)


# ── 3. Quest 7+ discards the Rumor pool (errata p.3, FAQ 13) ─────────────

func test_reaching_the_conclusion_discards_every_rumor() -> void:
	# Errata + FAQ 13: "Once the roll on this table is a 7 or greater, DISCARD ALL
	# RUMORS you have accumulated." The core rulebook is silent, which is why the
	# pool used to carry over.
	var campaign := CampaignCore.new()
	campaign.quest_rumors = 5
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.battle_result = {"turn": 4}
	var discarded: int = int(ctx.discard_all_quest_rumors())
	assert_int(discarded).is_equal(5)
	assert_int(campaign.quest_rumors).override_failure_message(
		"the Rumor pool survived the Quest conclusion, so the next Quest starts"
		+ " five rolls ahead"
	).is_equal(0)


func test_both_quest_systems_discard_at_the_conclusion() -> void:
	# The core p.120 branch and the Compendium p.78 expanded conclusion are
	# different code paths; the ruling is about the POOL, so it governs both.
	var src: String = _read(RESOLVER_SRC)
	var count: int = src.count("_discard_rumors_at_conclusion(ctx)")
	assert_int(count).override_failure_message(
		"expected the discard on BOTH conclusion branches, found %d" % count
	).is_equal(2)


# ── 4. Bio-upgrade starts with an Implant (errata p.4, update 1.03) ───────

func test_the_implant_subtable_is_rollable_on_its_own() -> void:
	# A creation rule has no loot roll to ride on, so the p.133 subtable has to be
	# addressable directly — through the same _roll_d100 the loot path uses, not a
	# second copy of the spans.
	var seen := {}
	for _i in range(400):
		var name_rolled: String = LootResolver.roll_implant_name()
		assert_str(name_rolled).override_failure_message(
			"roll_implant_name() returned nothing — the implants category is"
			+ " missing from odds_and_ends_subtable"
		).is_not_empty()
		seen[name_rolled] = true
	for wanted in IMPLANT_NAMES:
		assert_bool(seen.has(wanted)).override_failure_message(
			"'%s' never came up in 400 rolls; the p.133 spans are wrong" % wanted
		).is_true()
	assert_int(seen.size()).override_failure_message(
		"the p.133 Implants Subtable has exactly 11 rows, got %s" % str(seen.keys())
	).is_equal(11)


func test_the_bio_upgrade_grant_is_wired_to_the_creator() -> void:
	# Anchored on the exact enabling call. The rule was absent, not broken, so a
	# looser scan for the word "implant" would have passed before the fix.
	var src: String = _read("res://src/core/character/Generation/CharacterCreator.gd")
	assert_str(src).override_failure_message(
		"nothing grants the Bio-upgrade its errata Implant"
	).contains("_grant_bio_upgrade_implant(character)")
	assert_str(src).contains("func _grant_bio_upgrade_implant(")


# ── 5. Recruits roll the creation tables (errata p.3 Update) ─────────────

func test_the_recruit_path_rolls_the_creation_tables() -> void:
	# p.78 says a recruit does "not roll on any of the random background tables".
	# The errata replaces that: "roll on the normal character creation tables as
	# you would when starting a new game but IGNORE ALL CREDITS".
	var src: String = _read(CREW_TASK_SRC)
	assert_str(src).override_failure_message(
		"the recruit still arrives with p.78's basic profile"
	).contains("_apply_recruit_creation_tables(rolled)")
	assert_str(src).contains("roll_character_tables()")
	assert_bool(src.contains("func _strip_to_recruit_loadout(")).override_failure_message(
		"the superseded p.78 loadout function is still present"
	).is_false()


func test_the_recruit_gets_no_credits_from_the_tables() -> void:
	# The single reward the errata withholds, and the easiest one to leak.
	var src: String = _read(CREW_TASK_SRC)
	var start: int = src.find("func _apply_recruit_creation_tables(")
	assert_int(start).is_greater(-1)
	var after: int = src.find("\nfunc ", start + 10)
	var body: String = src.substr(start, after - start)
	assert_str(body).override_failure_message(
		"a recruit must be banked with zero bonus credits"
	).contains('"bonus_credits": 0')


func test_recruit_contacts_are_granted_only_to_the_hired_candidate() -> void:
	# p.74 Adventurous population rolls up EXTRA candidates to choose between, and
	# the tables run on all of them. Granting the errata Rivals and Patrons at
	# roll time would hand out the contacts of people who were never hired — up to
	# two extra Rivals from a single Recruit task.
	var src: String = _read(CREW_TASK_SRC)
	var start: int = src.find("func _hire_recruit(")
	assert_int(start).is_greater(-1)
	var after: int = src.find("\nfunc ", start + 10)
	var body: String = src.substr(start, after - start)
	assert_str(body).override_failure_message(
		"contacts are not granted at the hire site, so rejected candidates would"
		+ " still saddle the crew with their Rivals"
	).contains("_grant_recruit_contacts(")

	var roll_start: int = src.find("func _apply_recruit_creation_tables(")
	var roll_after: int = src.find("\nfunc ", roll_start + 10)
	var roll_body: String = src.substr(roll_start, roll_after - roll_start)
	assert_bool(roll_body.contains("_grant_recruit_contacts(")).override_failure_message(
		"contacts must NOT be granted while merely rolling up a candidate"
	).is_false()


# ── 6. Several Patron jobs at once (errata p.3 Update) ───────────────────

func test_accepting_a_job_banks_it_as_an_outstanding_commitment() -> void:
	# Errata: "you can accept all of them but pay attention to the time-frames."
	var src: String = _read(JOB_SRC)
	assert_str(src).override_failure_message(
		"accepting a job does not record an outstanding commitment"
	).contains("_bank_accepted_commitment(job)")
	assert_str(src).contains("func _expire_stale_commitments(")


func test_a_lapsed_commitment_counts_as_a_failure() -> void:
	# Errata: "Failure to finish a job in the allotted time COUNTS AS A FAILURE."
	# Routed through the same _fail_expired_job() a lapsed OFFER takes, which is
	# what applies the errata Correction p.119 removal and the p.84 Vengeful check.
	var src: String = _read(JOB_SRC)
	var start: int = src.find("func _expire_stale_commitments(")
	assert_int(start).is_greater(-1)
	var after: int = src.find("\nfunc ", start + 10)
	var body: String = src.substr(start, after - start)
	assert_str(body).override_failure_message(
		"a lapsed commitment is dropped silently instead of failing"
	).contains("_fail_expired_job(job, current_turn)")


func test_the_fought_job_is_discharged_at_the_handoff() -> void:
	# Without a caller, discharge_commitment() would be a zero-caller producer —
	# and the job the crew actually ran would later lapse as a false failure.
	assert_str(_read(WPC_SRC)).override_failure_message(
		"nothing discharges the commitment for the job actually fought"
	).contains("job_offer_component.discharge_commitment(")


func test_commitments_survive_the_world_phase_checkpoint() -> void:
	# T9-50 was three fixes deep because the accepted job lived only in memory.
	# The commitments ride the same serializer pair, and the restore is guarded in
	# the CALLEE so it cannot matter which of initialize_job_offers() three
	# callers ran first.
	var src: String = _read(JOB_SRC)
	assert_str(src).contains('"pending_commitments": _pending_commitments().duplicate(true)')
	assert_str(src).override_failure_message(
		"the restore must not overwrite a live campaign value"
	).contains("if _pending_commitments().is_empty():")


# ── 7. Mods and sights vs disposable weapons (errata p.4) ────────────────

func test_a_grenade_cannot_take_a_sight() -> void:
	# Errata: "The book says Mods and sights cannot be assigned to single-shot
	# weapons. This means grenades and other limited use weapons, not weapons
	# with only 1 Shot per round on their profile."
	var grenade: Dictionary = {
		"name": "Frakk Grenade", "range": 6, "shots": 2,
		"traits": ["Heavy", "Area", "Single use"],
	}
	var check: Dictionary = WeaponModService.can_fit(grenade, "quality_sight")
	assert_bool(bool(check.get("ok", true))).override_failure_message(
		"a Sight was fitted to a grenade: %s" % str(check.get("reason", ""))
	).is_false()
	assert_str(str(check.get("reason", ""))).contains("single-use")


func test_a_one_shot_rifle_can_still_take_a_sight() -> void:
	# The ruling exists BECAUSE the naive reading is the opposite: a Military
	# Rifle has Shots 1, and fitting a Sight to a rifle is what the p.53 list is
	# for. Testing the shot count instead of the trait would break the common case.
	var rifle: Dictionary = {
		"name": "Military Rifle", "range": 24, "shots": 1, "traits": [],
	}
	var check: Dictionary = WeaponModService.can_fit(rifle, "quality_sight")
	assert_bool(bool(check.get("ok", false))).override_failure_message(
		"a single-SHOT rifle was refused a Sight, which the errata explicitly"
		+ " allows: %s" % str(check.get("reason", ""))
	).is_true()
