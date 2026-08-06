extends GdUnitTestSuite
## Red / Black Zone job opposition — Core Rules Appendix III pp.149-151.
##
## THE GAP THESE PIN: both zone types were rolled by the World Phase, written
## into mission_data as is_red_zone / is_black_zone, and PRINTED to the player by
## MissionPrepComponent — and the enemy generator never read either flag. A Red
## Job therefore fielded an ordinary randomly-sized force instead of the book's
## fixed 7-figure one, and a Black Job could draw any encounter category at all
## rather than the Roving Threats subtable the book mandates.

const GEN = preload("res://src/core/systems/EnemyGenerator.gd")

const TRIALS := 40

func _gen() -> Object:
	return auto_free(GEN.new())

func _count_roles(squad: Array) -> Dictionary:
	var out := {"standard": 0, "specialist": 0, "lieutenant": 0, "unique": 0}
	for e in squad:
		var role: String = str(e.get("role", "standard"))
		if out.has(role):
			out[role] += 1
	return out

func _numbers_mod(squad: Array) -> int:
	# Every figure carries the type's Numbers entry, so read it off figure 0.
	if squad.is_empty():
		return 0
	var raw: String = str(squad[0].get("numbers", "+0")).strip_edges()
	if raw.is_empty():
		return 0
	if raw.begins_with("+"):
		raw = raw.substr(1)
	return int(raw) if raw.is_valid_int() else 0

# ── Red Job: Increased Opposition (p.150) ─────────────────────────────────

func test_red_job_uses_the_fixed_base_of_seven_plus_the_numbers_modifier() -> void:
	# p.150 verbatim: "Do not roll for opposing numbers. Instead, you will
	# encounter a base of 7 figures + any modifier from the enemy type
	# encountered. No other modifiers are applied up or down."
	var g = _gen()
	for _i in range(TRIALS):
		var squad: Array = g.generate_enemies_as_dicts(
			{"is_red_zone": true, "mission_source": "patron"}, 6)
		# Unique Individuals are "always in addition" (p.94), so exclude them
		# from the count the Increased Opposition rule governs.
		var roles: Dictionary = _count_roles(squad)
		var counted: int = squad.size() - roles["unique"]
		var expected: int = maxi(1, 7 + _numbers_mod(squad))
		assert_int(counted).override_failure_message(
			"Red Job fielded %d figures; the book fixes it at 7 + Numbers (%d)"
			% [counted, expected]).is_equal(expected)

func test_the_red_job_count_ignores_campaign_crew_size() -> void:
	# "No other modifiers are applied up or down" — the p.63 crew-size dice
	# formula, which normally drives the count, is discarded entirely.
	var g = _gen()
	for crew_size in [4, 5, 6]:
		var squad: Array = g.generate_enemies_as_dicts(
			{"is_red_zone": true, "mission_source": "patron"}, crew_size)
		var roles: Dictionary = _count_roles(squad)
		var counted: int = squad.size() - roles["unique"]
		assert_int(counted).override_failure_message(
			"Crew size %d changed the Red Job count to %d" % [crew_size, counted]) \
			.is_equal(maxi(1, 7 + _numbers_mod(squad)))

func test_red_job_fields_three_special_figures_one_being_the_lieutenant() -> void:
	# p.150: "Opposing figures will include 3 Specialists, one of which is a
	# Lieutenant." Three special figures TOTAL — so two Specialists stand
	# alongside the Lieutenant, not three.
	var g = _gen()
	var checked: int = 0
	for _i in range(TRIALS):
		var squad: Array = g.generate_enemies_as_dicts(
			{"is_red_zone": true, "mission_source": "patron"}, 6)
		# Animal forces take no Specialists at all (errata v1.06), so they are
		# not governed by this clause.
		var has_specialist_capable: bool = false
		for e in squad:
			if str(e.get("role", "")) == "specialist":
				has_specialist_capable = true
		if not has_specialist_capable:
			continue
		checked += 1
		var roles: Dictionary = _count_roles(squad)
		assert_int(roles["lieutenant"]).is_equal(1)
		assert_int(roles["specialist"] + roles["lieutenant"]) \
			.override_failure_message(
				"Red Job had %d Specialists + %d Lieutenant; the book says 3 total"
				% [roles["specialist"], roles["lieutenant"]]).is_equal(3)
	assert_int(checked).override_failure_message(
		"No weapon-using Red Job force appeared in %d rolls" % TRIALS).is_greater(0)

func test_a_normal_job_is_not_given_red_job_opposition() -> void:
	# The override must be gated on the flag, not applied to every mission.
	var g = _gen()
	var saw_non_seven: bool = false
	for _i in range(TRIALS):
		var squad: Array = g.generate_enemies_as_dicts({"mission_source": "patron"}, 6)
		var roles: Dictionary = _count_roles(squad)
		var counted: int = squad.size() - roles["unique"]
		if counted != maxi(1, 7 + _numbers_mod(squad)):
			saw_non_seven = true
			break
	assert_bool(saw_non_seven).override_failure_message(
		"Every ordinary job produced the Red Job count — the flag is not gating") \
		.is_true()

# ── Black Job: the opponent is fixed (p.150) ──────────────────────────────

func test_black_job_always_draws_from_roving_threats() -> void:
	# p.150 verbatim: "You will always be facing an opponent from the Roving
	# Threats Subtable."
	var g = _gen()
	for _i in range(TRIALS):
		var squad: Array = g.generate_enemies_as_dicts(
			{"is_black_zone": true, "mission_source": "patron"}, 6)
		assert_array(squad).is_not_empty()
		assert_str(str(squad[0].get("category", ""))).override_failure_message(
			"Black Job drew from '%s'; the book mandates roving_threats"
			% str(squad[0].get("category", ""))).is_equal("roving_threats")

func test_a_preset_enemy_type_still_wins_over_the_black_job_default() -> void:
	# A Rival or scripted encounter names its opponent explicitly; the zone
	# default is only for the "roll for it" path.
	var g = _gen()
	var squad: Array = g.generate_enemies_as_dicts(
		{"is_black_zone": true, "enemy_type": "Gangers"}, 6)
	assert_array(squad).is_not_empty()
	assert_str(str(squad[0].get("type", ""))).is_equal("Gangers")

# ── The two zones stack ───────────────────────────────────────────────────

func test_a_black_job_in_a_red_zone_gets_both_rules() -> void:
	# Black Jobs are only available after 10 Red Zone campaign turns, so a
	# mission can legitimately carry both flags.
	var g = _gen()
	var squad: Array = g.generate_enemies_as_dicts(
		{"is_red_zone": true, "is_black_zone": true, "mission_source": "patron"}, 6)
	assert_array(squad).is_not_empty()
	assert_str(str(squad[0].get("category", ""))).is_equal("roving_threats")
	var roles: Dictionary = _count_roles(squad)
	var counted: int = squad.size() - roles["unique"]
	assert_int(counted).is_equal(maxi(1, 7 + _numbers_mod(squad)))
