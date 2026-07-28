extends GdUnitTestSuite
## Cross-mode transfers must carry XP across the key boundary, and every leg must
## attach the lossless snapshot.
##
## THE BUGS THESE EXIST TO PREVENT
##
## 1. XP KEY CROSSING. The two sides of a transfer name the field differently and
##    both are correct in their own mode:
##      5PFH       -> "experience"  (Character.to_dictionary():1306 / from_dictionary():1404;
##                    CharacterAdvancementService:62/152 spends against it;
##                    CampaignPhaseManager:500 and PostBattleContext:435 award into it)
##      Bug Hunt   -> "xp"          (BugHuntPhaseManager:177)
##      Planetfall -> "xp"
##    Every conversion read and wrote "xp" unconditionally, so:
##      - muster-out wrote the retained XP to a key 5PFH never reads, and
##      - the Planetfall import read "xp" off a 5PFH source that only has "experience".
##    Compendium p.213 says mustering out "Retain profile and unused XP" — the
##    docblock on _convert_to_standard() states the rule the code was breaking.
##
## 2. MISSING SNAPSHOT ON THE ENLISTMENT LEG. attempt_enlistment() called
##    _convert_to_bug_hunt() directly instead of going through import_from_canonical(),
##    making it the only one of four legs with no `snapshot`. Without it,
##    export_to_canonical() falls through to _convert_to_standard(), which rebuilds
##    from the Bug Hunt shape and cannot recover species, class, traits or implants —
##    a veteran came home as a stat-only husk.
##
## Both were invisible to the 24 pre-existing transfer tests, which passed throughout.
##
## gdUnit4 v6.0.3 compatible.

const TransferService = preload("res://src/core/character/CharacterTransferService.gd")


func _svc():
	return TransferService.new()


func _five_parsecs_veteran() -> Dictionary:
	## A 5PFH character as Character.to_dictionary() actually emits it: XP under
	## "experience", identity fields under both alias spellings.
	return {
		"id": "vet_01",
		"character_id": "vet_01",
		"name": "Sgt. Rell",
		"character_name": "Sgt. Rell",
		"experience": 17,
		"origin": "k_erin",
		"species_id": "k_erin",
		"character_class": "SOLDIER",
		# Combat 5 makes enlistment deterministic: the roll is 2D6 + Combat vs 7
		# (Compendium p.212), and 2D6 has a floor of 2, so 5 can never fail. Without
		# this the two enlistment cases below silently skipped ~17% of runs on a bad
		# roll and passed vacuously.
		"combat_skill": 5,
		"combat": 5,
		"reactions": 3,
		"speed": 4,
		"toughness": 4,
		"savvy": 1,
		"luck": 1,
		"traits": ["Brawler"],
	}


# --- XP across the key boundary -----------------------------------------------

func test_muster_out_retains_xp_under_the_key_5pfh_reads() -> void:
	# Compendium p.213: "Retain profile and unused XP".
	var svc = _svc()
	var bug_hunter := {
		"id": "bh_01",
		"name": "Trooper Vex",
		"game_mode": "bug_hunt",
		"xp": 12,
		"combat_skill": 2,
		"completed_missions_count": 4,
	}
	var canonical: Dictionary = svc.export_to_canonical(bug_hunter, "bug_hunt")

	assert_int(int(canonical.get("experience", -1))).override_failure_message(
		"mustered-out XP is still written only under \"xp\", which no 5PFH system reads"
	).is_equal(12)


func test_planetfall_import_reads_xp_from_a_5pfh_source() -> void:
	# The source here stores "experience"; the old code read get("xp", 0) and got 0.
	var svc = _svc()
	var pf: Dictionary = svc.convert_to_planetfall(_five_parsecs_veteran(), "5pfh")

	assert_int(int(pf.get("xp", -1))).override_failure_message(
		"the veteran arrived in the colony with 0 XP — the read still uses the wrong key"
	).is_equal(17)


func test_returning_colonist_carries_xp_back_into_5pfh() -> void:
	var svc = _svc()
	var colonist := {"id": "col_01", "name": "Mira", "xp": 8, "combat_skill": 1}
	var back: Dictionary = svc.convert_from_planetfall(colonist, "")

	assert_int(int(back.get("experience", -1))).is_equal(8)


func test_both_xp_keys_agree_on_a_5pfh_bound_dict() -> void:
	# Mixed-vintage consumers read either spelling, so they must not disagree.
	var svc = _svc()
	var back: Dictionary = svc.convert_from_planetfall(
		{"id": "c", "name": "N", "xp": 5}, "")
	assert_int(int(back.get("experience", -1))).is_equal(int(back.get("xp", -2)))


# --- the snapshot on every leg -------------------------------------------------

func test_enlistment_attaches_a_snapshot() -> void:
	var svc = _svc()
	var result: Dictionary = svc.attempt_enlistment(_five_parsecs_veteran())
	assert_bool(result.get("success", false)).override_failure_message(
		"enlistment should be deterministic at Combat 5 — see the fixture note"
	).is_true()
	var transferred: Dictionary = result.get("transferred_character", {})

	assert_bool(transferred.has("snapshot")).override_failure_message(
		"the enlistment leg still bypasses import_from_canonical, so nothing can be restored on muster-out"
	).is_true()


func test_enlist_then_muster_out_restores_species_and_class() -> void:
	# The husk symptom: identity fields the Bug Hunt shape does not carry.
	var svc = _svc()
	var original := _five_parsecs_veteran()
	var result: Dictionary = svc.attempt_enlistment(original)
	assert_bool(result.get("success", false)).is_true()

	var in_bug_hunt: Dictionary = result.get("transferred_character", {})
	var home: Dictionary = svc.export_to_canonical(in_bug_hunt, "bug_hunt")

	assert_str(str(home.get("species_id", ""))).override_failure_message(
		"species was lost across the round trip"
	).is_equal("k_erin")
	assert_str(str(home.get("character_class", ""))).is_equal("SOLDIER")
	assert_int(int(home.get("experience", -1))).override_failure_message(
		"the snapshot restored identity but XP still came back wrong"
	).is_equal(17)


func test_every_target_mode_gets_a_snapshot() -> void:
	# import_from_canonical is the single chokepoint; no leg may skip it.
	var svc = _svc()
	var canonical := _five_parsecs_veteran()
	for mode in ["bug_hunt", "planetfall", "tactics"]:
		var down: Dictionary = svc.import_from_canonical(canonical, mode)
		assert_bool(down.has("snapshot")).override_failure_message(
			"target mode '%s' produced a character with no return ticket" % mode
		).is_true()
