extends GdUnitTestSuite
## Enemy weapons — Core Rules p.104, plus the AI Blade rule as corrected by the
## official errata v1.06.
##
## THE GAP THESE PIN: an enemy's WEAPONS entry is "<number> <letter>" — the book
## says outright that these are "a weapon code and a Specialist code (a number
## and a letter respectively)". Both halves were read backwards. The number was
## treated as "how many weapons to roll" and the LETTER was mapped onto the basic
## weapon columns, so:
##   - a "2 A" enemy got TWO weapons off the WEAPON 1 column
##   - which basic column got rolled was decided by the Specialist code
##   - the 18-entry Specialist table was unreachable — Specialists carried the
##     same gun as the mooks they lead
##   - the AI Blade rule was never applied anywhere, though enemy_types.json
##     ships its text under weapon_tables.ai_weapon_rules
##
## Every column value below is quoted from the p.104 tables, so a regression in
## the column mapping fails here rather than silently arming the wrong enemies.

const GEN = preload("res://src/core/systems/EnemyGenerator.gd")

const TRIALS := 200

func _gen() -> Object:
	return auto_free(GEN.new())

# The p.104 WEAPON columns, verbatim. A roll on column N can only ever produce
# one of these six (or the two halves of its "+" entry).
const WEAPON_1 := ["Scrap Pistol", "Handgun", "Colony Rifle", "Military Rifle",
	"Shotgun", "Blade"]  # row 5 is "Scrap Pistol + Blade"
const WEAPON_2 := ["Colony Rifle", "Military Rifle", "Hand Laser",
	"Infantry Laser"]
const WEAPON_3 := ["Hand Laser", "Infantry Laser", "Blast Rifle"]

# The p.104 SPECIALIST columns, verbatim.
const SPEC_A := ["Power Claw", "Shotgun", "Auto Rifle", "Clingfire Pistol",
	"Hunting Rifle", "Handgun", "Ripper Sword"]  # row 6 is "Handgun + Ripper Sword"
const SPEC_B := ["Marksman's Rifle", "Auto Rifle", "Shell Gun", "Hand Flamer",
	"Rattle Gun"]
const SPEC_C := ["Marksman's Rifle", "Shell Gun", "Fury Rifle", "Plasma Rifle",
	"Hyper Blaster"]

# ── The number selects the basic weapon COLUMN ────────────────────────────

func _basic_names(code: String) -> Dictionary:
	var g = _gen()
	var seen := {}
	for _i in range(TRIALS):
		for w in g._resolve_weapon_code(code):
			seen[str(w)] = true
	return seen

func test_code_number_one_rolls_only_the_weapon_1_column() -> void:
	# The letter must NOT influence which basic column is rolled — "1 A" and
	# "1 B" are the same rank-and-file column, differing only in Specialist.
	for name in _basic_names("1 B").keys():
		assert_bool(name in WEAPON_1).override_failure_message(
			"'%s' is not on the p.104 WEAPON 1 column" % name).is_true()

func test_code_number_two_rolls_only_the_weapon_2_column() -> void:
	for name in _basic_names("2 A").keys():
		assert_bool(name in WEAPON_2).override_failure_message(
			"'%s' is not on the p.104 WEAPON 2 column" % name).is_true()

func test_code_number_three_rolls_only_the_weapon_3_column() -> void:
	for name in _basic_names("3 C").keys():
		assert_bool(name in WEAPON_3).override_failure_message(
			"'%s' is not on the p.104 WEAPON 3 column" % name).is_true()

func test_basic_enemies_roll_once_not_once_per_code_number() -> void:
	# p.104: "To determine the weapon carried by the basic opponents ... roll
	# ONCE below." A "3 C" enemy previously received three weapons.
	var g = _gen()
	for _i in range(TRIALS):
		# Only row 5 of WEAPON 1 ("Scrap Pistol + Blade") yields two entries,
		# and only column 1 has such a row — so 2 and 3 are always exactly one.
		assert_int(g._resolve_weapon_code("3 C").size()).is_equal(1)
		assert_int(g._resolve_weapon_code("2 B").size()).is_equal(1)

# ── The letter selects the SPECIALIST column ──────────────────────────────

func _specialist_names(code: String) -> Dictionary:
	var g = _gen()
	var seen := {}
	for _i in range(TRIALS):
		for w in g.resolve_specialist_weapon(code):
			seen[str(w)] = true
	return seen

func test_letter_a_rolls_the_specialist_a_column() -> void:
	for name in _specialist_names("1 A").keys():
		assert_bool(name in SPEC_A).override_failure_message(
			"'%s' is not on the p.104 SPECIALIST A column" % name).is_true()

func test_letter_b_rolls_the_specialist_b_column() -> void:
	for name in _specialist_names("1 B").keys():
		assert_bool(name in SPEC_B).override_failure_message(
			"'%s' is not on the p.104 SPECIALIST B column" % name).is_true()

func test_letter_c_rolls_the_specialist_c_column() -> void:
	for name in _specialist_names("2 C").keys():
		assert_bool(name in SPEC_C).override_failure_message(
			"'%s' is not on the p.104 SPECIALIST C column" % name).is_true()

func test_specialist_weapons_are_actually_distinct_from_basic() -> void:
	# The regression that motivated this suite: Specialists used to receive the
	# rank-and-file loadout. Nothing on SPECIALIST C appears on WEAPON 2, so a
	# "2 C" force must produce two disjoint pools.
	var basic := _basic_names("2 C")
	var spec := _specialist_names("2 C")
	assert_int(spec.size()).is_greater(0)
	for name in spec.keys():
		assert_bool(name in basic).override_failure_message(
			"Specialist weapon '%s' leaked from the basic column" % name).is_false()

# ── Combo entries are two weapons ─────────────────────────────────────────

func test_combo_entries_split_into_two_weapons() -> void:
	# "Scrap Pistol + Blade" (WEAPON 1 row 5) is a pistol AND a blade. The old
	# code left it as one fused string under a comment claiming it handled it.
	var g = _gen()
	var saw_split: bool = false
	for _i in range(TRIALS):
		var w: Array = g._resolve_weapon_code("1 A")
		for name in w:
			assert_bool("+" in str(name)).override_failure_message(
				"Combo entry '%s' was never split" % name).is_false()
		if w.size() == 2 and "Scrap Pistol" in w and "Blade" in w:
			saw_split = true
	assert_bool(saw_split).override_failure_message(
		"WEAPON 1 row 5 never produced its two-weapon result").is_true()

# ── Literal loadouts are never rolled for ─────────────────────────────────

func test_named_loadouts_are_carried_verbatim() -> void:
	# p.104: "Some enemies have a specific weapon listed, and always carries
	# that. No roll is made." These entries are real rows in enemy_types.json.
	var g = _gen()
	assert_array(g._resolve_weapon_code("Hand Cannon, Blade")) \
		.contains_exactly(["Hand Cannon", "Blade"])
	assert_array(g._resolve_weapon_code("Fangs (Damage +1)")) \
		.contains_exactly(["Fangs (Damage +1)"])
	# A named-loadout enemy has no Specialist column, so its Specialist just
	# carries the listed weapons.
	assert_array(g.resolve_specialist_weapon("Hand Cannon, Blade")) \
		.contains_exactly(["Hand Cannon", "Blade"])

func test_parse_distinguishes_a_table_code_from_a_weapon_name() -> void:
	var g = _gen()
	assert_bool(g.parse_weapon_code("2 A").get("is_table_code")).is_true()
	assert_bool(g.parse_weapon_code("Rattle Gun").get("is_table_code")).is_false()
	# "Fangs (Damage +0)" starts with no digit but must not be mistaken for one.
	assert_bool(g.parse_weapon_code("Fangs (Damage +0)").get("is_table_code")).is_false()

# ── AI Blade rule (p.104 + errata v1.06) ──────────────────────────────────

func test_rampaging_ai_always_gets_a_blade() -> void:
	# Book text says "Psycho AI"; the errata replaces that with Rampaging AI —
	# there is no Psycho AI type in the p.92 code table, and the Psychos entry
	# (p.95) uses R. Combat Skill is irrelevant for R.
	var g = _gen()
	assert_array(g.apply_ai_blade_rule(["Colony Rifle"], "R", 0)) \
		.contains(["Blade"])
	assert_array(g.apply_ai_blade_rule(["Colony Rifle"], "R", 2)) \
		.contains(["Blade"])

func test_aggressive_ai_gets_a_blade_only_above_combat_skill_zero() -> void:
	# p.104: "unless their Combat Skill is +0".
	var g = _gen()
	assert_array(g.apply_ai_blade_rule(["Handgun"], "A", 1)).contains(["Blade"])
	assert_array(g.apply_ai_blade_rule(["Handgun"], "A", 0)) \
		.contains_exactly(["Handgun"])

func test_other_ai_types_never_gain_a_blade() -> void:
	var g = _gen()
	for code in ["C", "D", "G", "T", "B"]:
		assert_array(g.apply_ai_blade_rule(["Handgun"], code, 2)) \
			.override_failure_message("AI '%s' should not gain a Blade" % code) \
			.contains_exactly(["Handgun"])

func test_blade_is_not_duplicated_when_already_carried() -> void:
	var g = _gen()
	var out: Array = g.apply_ai_blade_rule(["Scrap Pistol", "Blade"], "R", 1)
	assert_int(out.count("Blade")).is_equal(1)

# ── The rule reaches a generated squad, not just the helper ───────────────

func test_a_generated_rampaging_squad_carries_blades() -> void:
	# Psychos (p.95): AI R, Combat Skill +0, weapons "1 B". Under the old code
	# NO figure in this force carried a Blade.
	var g = _gen()
	var squad: Array = g.generate_enemies_as_dicts(
		{"enemy_type": "Psychos", "enemy_category": "criminal_elements"}, 6)
	var found_psychos: bool = false
	for e in squad:
		if str(e.get("type", "")) != "Psychos":
			continue
		found_psychos = true
		assert_bool("Blade" in e["weapons"]).override_failure_message(
			"Rampaging-AI figure '%s' has no Blade: %s" % [
				e.get("name", "?"), str(e["weapons"])]).is_true()
	# If the D100 didn't land on Psychos this run, the assertion above is vacuous
	# — exercise the helper contract directly so the case still means something.
	if not found_psychos:
		assert_array(g.apply_ai_blade_rule(["Colony Rifle"], "R", 0)) \
			.contains(["Blade"])

func test_a_generated_squad_gives_its_specialist_a_specialist_weapon() -> void:
	# Needs >= 3 enemies for a Specialist to exist (p.93). Drives the real squad
	# builder so the join from template -> role -> weapon column is covered.
	var g = _gen()
	for _i in range(30):
		var squad: Array = g.generate_enemies_as_dicts(
			{"enemy_category": "criminal_elements"}, 6)
		var template_code: String = ""
		var spec_weapons: Array = []
		var basic_weapons: Array = []
		for e in squad:
			match str(e.get("role", "")):
				"specialist": spec_weapons = e["weapons"]
				"standard": basic_weapons = e["weapons"]
		if spec_weapons.is_empty() or basic_weapons.is_empty():
			continue
		# A Specialist's weapon must come from a Specialist column. Union of all
		# three covers whichever letter this enemy type carries.
		var all_spec: Array = SPEC_A + SPEC_B + SPEC_C
		var from_spec_table: bool = false
		for w in spec_weapons:
			if str(w) in all_spec:
				from_spec_table = true
		assert_bool(from_spec_table).override_failure_message(
			"Specialist carried %s, none of which is on any p.104 Specialist column"
			% str(spec_weapons)).is_true()
		return
	# Fall through only if 30 squads produced no Specialist, which the p.93
	# thresholds make effectively impossible at crew size 6.
	assert_bool(false).override_failure_message(
		"No Specialist appeared in 30 generated squads").is_true()
