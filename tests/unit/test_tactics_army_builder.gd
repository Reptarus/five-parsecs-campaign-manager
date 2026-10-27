extends GdUnitTestSuite

## Tactics Army Builder (pp.133-139) and Lifeforms profiles (pp.153-167).
##
## Before Sprint 1 every species file hand-listed its own units, priced at the figures
## alone: a Human infantry squad cost 55 where the book's cost is 55 + the +27 Infantry
## package = 82, every character missed its +5 equipment package, and the single-figure
## "Civilian"/"Military" PROFILES were offered as units (5 Military figures for 10 points).
## Fourteen of fifteen species also carried wrong profile stats and nine carried invented
## traits. The units are now composed from data/tactics/army_builder.json and each
## species' book profiles by TacticsSpeciesBookLoader.compose_army_builder_units().

const Loader := preload("res://src/data/tactics/TacticsSpeciesBookLoader.gd")
const MASTER := "res://data/tactics/tactics_weapons_master.json"
const MANIFEST := "res://data/tactics/species_manifest.json"


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func _species_ids() -> Array:
	var out: Array = []
	for sid: Variant in _json(MANIFEST).get("species", []):
		if str(sid) != "creatures":
			out.append(str(sid))
	return out


func _unit(book: TacticsSpeciesBook, unit_id: String) -> TacticsUnitProfile:
	var p: TacticsUnitProfile = book.get_unit_profile(unit_id)
	assert_object(p).override_failure_message("no unit '%s'" % unit_id).is_not_null()
	return p


# --- Costs: profile(s) + element base cost (p.133 steps 2-4) ------------------------

func test_human_units_cost_what_the_book_prices_them_at() -> void:
	var book: TacticsSpeciesBook = Loader.load_species_book("human_colonists")
	# p.153: Military 10, Sergeant 15, Major 20, Epic 30.
	var expected := {
		"human_sergeant": 15 + 5,                  # Characters base cost +5 (p.136)
		"human_major": 20 + 5,
		"human_epic": 30 + 5,
		"human_infantry_squad": 4 * 10 + 15 + 27,  # p.137
		"human_recon_squad": 4 * 10 + 15 + 23,     # p.137
		"human_storm_squad": 4 * 10 + 15 + 28,     # p.138
		"human_weapon_team": 3 * 10 + 5 + 15,      # p.138: +5, infantry mortar 15
		"human_tech_specialist": 10 + 5,           # p.138
		"human_sharpshooter": 10 + 15,             # p.139
		"human_fire_section": 2 * 10 + 15,         # p.139: a two-figure squad
		"human_comms_specialist": 10 + 10,         # p.139
		"human_medic": 10 + 10,                    # p.139
	}
	for uid: String in expected:
		assert_int(_unit(book, uid).points_cost).override_failure_message(
			"%s should cost %d" % [uid, expected[uid]]).is_equal(expected[uid])


func test_a_soulless_squad_is_five_standard_figures() -> void:
	# p.158: "All figures, whether civilian, military, or individual characters use the
	# standard profile" (cost 20), so the sergeant is a standard figure too.
	var book: TacticsSpeciesBook = Loader.load_species_book("soulless")
	assert_int(_unit(book, "soulless_infantry_squad").points_cost).is_equal(5 * 20 + 27)
	assert_int(_unit(book, "soulless_weapon_team").points_cost).is_equal(3 * 20 + 5 + 15)
	assert_int(_unit(book, "soulless_epic").points_cost).is_equal(20 + 5)


func test_armor_is_priced_per_figure() -> void:
	# p.136: Powered Armor 2 points per figure, Breach Armor 4.
	var squad: TacticsUnitProfile = _unit(Loader.load_species_book("kerin"), "kerin_infantry_squad")
	var prices := {}
	for group: TacticsUpgradeGroup in squad.upgrade_groups:
		for opt: TacticsUpgradeOption in group.options:
			prices[opt.upgrade_name] = opt.points_cost
	assert_int(int(prices.get("Powered Armor", -1))).is_equal(2 * 5)
	assert_int(int(prices.get("Breach Armor", -1))).is_equal(4 * 5)


# --- What is offered ------------------------------------------------------------------

func test_profiles_are_not_offered_as_units() -> void:
	# A Lifeforms profile is a stat line, not an Army Builder element (p.133 step 1).
	var invented := ["feral_scout_specialist", "precursor_seer", "skulker_ambush_team",
		"horde_swarm_squad", "converted_assault_squad"]
	for sid: String in _species_ids():
		var book: TacticsSpeciesBook = Loader.load_species_book(sid)
		assert_object(book).override_failure_message("%s did not load" % sid).is_not_null()
		assert_int(book.unit_profiles.size()).override_failure_message(
			"%s should offer the 12 Army Builder elements" % sid).is_equal(12)
		for p: TacticsUnitProfile in book.unit_profiles:
			assert_bool(p.unit_id.ends_with("_civilian") or p.unit_id.ends_with("_military")
				or p.unit_id.ends_with("_worker") or p.unit_id.ends_with("_standard")) \
				.override_failure_message("%s offers a bare profile '%s'" % [sid, p.unit_id]) \
				.is_false()
			assert_bool(p.unit_id in invented).override_failure_message(
				"%s is not in the Tactics book" % p.unit_id).is_false()


func test_every_weapon_a_unit_names_resolves() -> void:
	# A weapon id the palette cannot resolve is dropped SILENTLY by from_dict(), so a
	# unit would field fewer weapons than its entry lists with no error anywhere.
	var weapons: Dictionary = _json(MASTER).get("weapons", {})
	for sid: String in _species_ids():
		var data := _json("res://data/tactics/species/%s.json" % sid)
		for u: Dictionary in Loader.compose_army_builder_units(data):
			for wid: Variant in u.get("weapons", []):
				assert_bool(weapons.has(str(wid))).override_failure_message(
					"%s names unknown weapon '%s'" % [u["id"], wid]).is_true()
			for g: Dictionary in u.get("upgrade_groups", []):
				for o: Dictionary in g.get("options", []):
					for key: String in ["grants_weapon", "replaces"]:
						if o.has(key):
							assert_bool(weapons.has(str(o[key]))).override_failure_message(
								"%s option '%s' names unknown weapon '%s'" % [u["id"], o["name"], o[key]]).is_true()
		var book: TacticsSpeciesBook = Loader.load_species_book(sid)
		var squad: TacticsUnitProfile = book.get_unit_profile(data["unit_id_prefix"] + "_infantry_squad")
		assert_int(squad.weapons.size()).override_failure_message(
			"%s infantry squad lost weapons in the palette" % sid).is_equal(3)


# --- Profiles and rules, against the page ---------------------------------------------

func test_profiles_match_the_lifeforms_pages() -> void:
	var cases := [
		# [species, tier, field, value, page]
		["soulless", "military", "combat_skill", 2, "p.158"],
		["soulless", "military", "kp", 2, "p.158"],
		["soulless", "military", "savvy", 2, "p.158"],
		["ferals", "military", "toughness", 4, "p.154"],
		["ferals", "military", "speed", 4, "p.154"],
		["hulkers", "military", "speed", 5, "p.155"],
		["hulkers", "military", "kp", 2, "p.155"],
		["precursors", "military", "reactions", 3, "p.156"],
		["kerin", "military", "toughness", 4, "p.157"],
		["ystrik", "military", "toughness", 1, "p.166"],
		["skulkers", "military", "speed", 6, "p.163"],
		["serian", "military", "savvy", 2, "p.161"],
	]
	for c: Array in cases:
		var prof: Dictionary = _json("res://data/tactics/species/%s.json" % c[0]).get("profiles", {}).get(c[1], {})
		assert_int(int(prof.get(c[2], -99))).override_failure_message(
			"%s %s %s should be %d (%s)" % c).is_equal(c[3])


func test_species_rules_are_the_books_text() -> void:
	var expect := {
		# p.153: the +1 is for persuasion/negotiation, NOT for calling in Support
		"human_colonists": ["Widely Skilled", "NOT calling in Support"],
		# p.158: Machine Learning is about veterans, not a to-hit bonus
		"soulless": ["Machine Learning", "cannot be veterans"],
		"clones": ["One Mind", "+2 Savvy and +2 Training"],
		"skulkers": ["Agile", "Difficult terrain"],
		"ystrik": ["Rapid Analysis", "natural 1 as a 6"],
		"krag": ["Rivalry", "+1 to all attack rolls"],
		"hakshan": ["Determined", "objective"],
	}
	for sid: String in expect:
		var found := false
		for t: Dictionary in _json("res://data/tactics/species/%s.json" % sid)["species"]["traits"]:
			if t.get("name") == expect[sid][0]:
				found = str(t.get("description", "")).contains(expect[sid][1])
		assert_bool(found).override_failure_message(
			"%s: rule '%s' should read '...%s...'" % [sid, expect[sid][0], expect[sid][1]]).is_true()


func test_no_fabrication_tag_survives_in_the_tactics_data() -> void:
	for path: String in ["res://data/tactics/army_builder.json", MASTER]:
		assert_bool(FileAccess.get_file_as_string(path).contains("GAME_BALANCE_ESTIMATE")).is_false()
	for sid: String in _species_ids():
		assert_bool(FileAccess.get_file_as_string("res://data/tactics/species/%s.json" % sid)
			.contains("GAME_BALANCE_ESTIMATE")).override_failure_message(sid).is_false()
