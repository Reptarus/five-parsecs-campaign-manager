extends GdUnitTestSuite
## Compendium Casualty Tables (pp.99-100) and Detailed Post-Battle Injuries (p.102).
##
## THE DEFECT THIS PINS. Both features had a correct flag gate, a correct call
## site, and book-exact data — and neither had ever produced a single result,
## because each READER disagreed with its own data file:
##
##   roll_casualty()        read `casualty_table`, whose value in
##                          difficulty_toggles.json is the empty array []. The
##                          real pp.99-100 data is in `casualty_tables` — three
##                          tables (humanoid / cybernetic / beast) with regular
##                          and boss COLUMNS, not a flat `roll` field. Iterating
##                          the empty array returned {} on every call.
##
##   roll_detailed_injury() rolled 2D6 — a 2..12 range — against a D100 table,
##                          and then matched `entry.roll`, a key those rows do
##                          not have (they carry roll_min / roll_max). Either
##                          fault alone guaranteed {}.
##
## Neither is findable by tracing call sites, which is how both survived a
## chapter-level audit that checked exactly that. The tests below assert the
## VALUES, not the calls.
##
## Also pinned: item_damaged markers must NOT carry a `duration` key. Both
## turn-rollover loops decrement any effect that has one and delete it at <= 0,
## so the literal `"duration": 0` this used to carry meant damaged gear repaired
## itself at the next rollover and Repair Your Kit (p.78) never had a job.
##
## gdUnit4 v6.0.3 compatible.

const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryProcessorClass = preload(
	"res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")

const FLAGS := ["CASUALTY_TABLES", "DETAILED_INJURIES"]

var _saved_flags: Dictionary = {}
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


## DLCManager is an AUTOLOAD — a flag left flipped here leaks into every suite
## that runs after this one in the same process.
func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flags.clear()
	for flag_name in FLAGS:
		_saved_flags[flag_name] = dlc.is_feature_enabled(dlc.ContentFlag.get(flag_name))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	for flag_name in _saved_flags:
		dlc.set_feature_enabled(dlc.ContentFlag.get(flag_name), bool(_saved_flags[flag_name]))
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _enable() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	for flag_name in FLAGS:
		dlc.set_feature_enabled(dlc.ContentFlag.get(flag_name), true)
	return true


func _member(id: String, name: String, extra: Dictionary = {}) -> Dictionary:
	var m := {
		"character_id": id, "character_name": name,
		"combat": 1, "speed": 4, "toughness": 3, "luck": 0,
		"experience": 0, "equipment": [], "status_effects": [], "injuries": [],
		"origin": "human", "species_id": "human", "is_captain": false,
	}
	for k in extra:
		m[k] = extra[k]
	return m


func _ctx(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "cinj", "crew": {"members": members}})
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 3}
	return ctx


# --- Casualty Tables pp.99-100 ------------------------------------------------

func test_casualty_roll_returns_a_row_for_every_book_table() -> void:
	if not _enable():
		return
	for category in ["humanoid", "cybernetic", "beast"]:
		var seen := {}
		for _i in range(60):
			var row: Dictionary = Toggles.roll_casualty(category, false)
			assert_bool(row.is_empty()).override_failure_message(
				"roll_casualty('%s') returned {} — the reader is looking at the "
				% category + "empty `casualty_table` key again").is_false()
			seen[str(row.get("outcome", ""))] = true
		# Every one of the three book tables has exactly three outcome bands.
		assert_int(seen.size()).override_failure_message(
			"table '%s' produced outcomes %s; the book gives each table three"
			% [category, str(seen.keys())]).is_equal(3)


func test_the_boss_column_is_harder_to_kill_than_the_regular_column() -> void:
	# p.100 humanoid: Regular 5-6 is Goner, Boss only on a 6. A roll of 5 must
	# therefore be Goner on the regular column and Wounded on the boss column —
	# the single clearest proof the column is actually being read.
	if not _enable():
		return
	var regular_goners := 0
	var boss_goners := 0
	for _i in range(400):
		if str(Toggles.roll_casualty("humanoid", false).get("outcome", "")) == "Goner":
			regular_goners += 1
		if str(Toggles.roll_casualty("humanoid", true).get("outcome", "")) == "Goner":
			boss_goners += 1
	assert_int(regular_goners).override_failure_message(
		"regular column should be Goner on 2 of 6 results, boss on 1 of 6 — got "
		+ "%d vs %d over 400 rolls each" % [regular_goners, boss_goners]
	).is_greater(boss_goners)


func test_casualty_category_follows_the_creature_type() -> void:
	assert_str(Toggles.casualty_category_for(true, false)).is_equal("cybernetic")
	assert_str(Toggles.casualty_category_for(false, true)).is_equal("beast")
	assert_str(Toggles.casualty_category_for(false, false)).is_equal("humanoid")


func test_casualty_returns_nothing_for_an_unknown_category() -> void:
	if not _enable():
		return
	assert_bool(Toggles.roll_casualty("dragon", false).is_empty()).is_true()


func test_casualty_is_silent_when_the_option_is_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("CASUALTY_TABLES"), false)
	assert_bool(Toggles.roll_casualty("humanoid", false).is_empty()).is_true()


# --- Detailed Post-Battle Injuries p.102 --------------------------------------

func test_detailed_injury_covers_the_whole_d100_span() -> void:
	# The 2D6 bug could only ever reach 2..12, which lands inside the first four
	# rows (0-10, 11-15, 16-20, 21-30). Seeing any row at 31+ proves a D100.
	if not _enable():
		return
	var ids := {}
	for _i in range(600):
		var row: Dictionary = Toggles.roll_detailed_injury()
		assert_bool(row.is_empty()).override_failure_message(
			"roll_detailed_injury() returned {} — the reader is matching "
			+ "`entry.roll` again, a key these rows do not have").is_false()
		var roll: int = int(row.get("roll", 0))
		assert_int(roll).is_between(1, 100)
		assert_int(roll).is_between(
			int(row.get("roll_min", -1)), int(row.get("roll_max", -1)))
		ids[str(row.get("id", ""))] = true
	# 12 rows; over 600 rolls the narrowest band (11-15, 5%) is all but certain.
	assert_int(ids.size()).override_failure_message(
		"only reached %d of the 12 rows: %s" % [ids.size(), str(ids.keys())]
	).is_greater(9)
	assert_bool(ids.has("knocked_out")).override_failure_message(
		"never reached the 81-95 band — a 2D6 roll cannot get there").is_true()


func test_detailed_injury_is_silent_when_the_option_is_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DETAILED_INJURIES"), false)
	assert_bool(Toggles.roll_detailed_injury().is_empty()).is_true()


# --- The table reaching the played post-battle path ---------------------------

func _process_row(ctx: Variant, row_id: String, crew_id: String) -> Dictionary:
	var row: Dictionary = {}
	for entry in Toggles.DETAILED_INJURY_TABLE:
		if str(entry.get("id", "")) == row_id:
			row = entry.duplicate(true)
			row["roll"] = int(entry.get("roll_min", 1))
			break
	assert_bool(row.is_empty()).override_failure_message(
		"no row with id '%s' in the table" % row_id).is_false()
	var proc = InjuryProcessorClass.new()
	return proc._process_detailed_injury(ctx, row, crew_id)


func test_death_slays_and_damages_a_carried_item() -> void:
	var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Hand Laser"]})])
	var out: Dictionary = _process_row(ctx, "death", "c1")
	assert_bool(bool(out.get("is_fatal", false))).is_true()
	assert_str(str(out.get("damaged_item", ""))).override_failure_message(
		"p.102 Death: 'A random item they carried is damaged.'"
	).is_equal("Hand Laser")


func test_luck_saves_a_character_from_the_death_row() -> void:
	# Core Rules p.121 travels with the table that replaces it.
	var ctx = _ctx([_member("c1", "Kaya", {"luck": 2})])
	var out: Dictionary = _process_row(ctx, "death", "c1")
	assert_bool(bool(out.get("is_fatal", true))).override_failure_message(
		"a character holding Luck must survive a slaying roll").is_false()
	assert_bool(bool(out.get("luck_death_save", false))).is_true()


func test_critical_strike_spares_an_armored_character_and_wrecks_the_armor() -> void:
	var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Combat Armor"]})])
	var out: Dictionary = _process_row(ctx, "critical_strike", "c1")
	assert_bool(bool(out.get("is_fatal", true))).override_failure_message(
		"p.102: wearing Armor, 'they survive, but the armor is damaged'").is_false()
	assert_str(str(out.get("damaged_item", ""))).is_equal("Combat Armor")


func test_critical_strike_slays_an_unarmored_character() -> void:
	var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Hand Laser"]})])
	var out: Dictionary = _process_row(ctx, "critical_strike", "c1")
	assert_bool(bool(out.get("is_fatal", false))).override_failure_message(
		"p.102: no Armor means 'Otherwise, they are slain.'").is_true()


func test_a_screen_is_not_armor() -> void:
	# armor.json separates Armor ("provides Saving Throws") from Screen
	# ("energy-based or stealth"). p.102 asks specifically about Armor.
	var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Camo Cloak"]})])
	var out: Dictionary = _process_row(ctx, "critical_strike", "c1")
	assert_bool(bool(out.get("is_fatal", false))).override_failure_message(
		"a Camo Cloak is a Screen, not Armor — it must not save the character"
	).is_true()


func test_extensive_injury_blocks_tasks_and_battle_until_paid() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	var out: Dictionary = _process_row(ctx, "extensive_injury", "c1")
	var cost: int = int(out.get("treatment_cost", 0))
	assert_int(cost).override_failure_message(
		"p.102: 'Roll 1D6+1 to determine the cost in Credits.'").is_between(2, 7)

	var effects: Array = ctx.campaign.get_crew_member_by_id("c1").get("status_effects", [])
	var types := []
	for eff in effects:
		types.append(str(eff.get("type", "")))
	assert_array(types).override_failure_message(
		"'Until the cost has been paid, the character cannot take crew tasks or "
		+ "fight' — both gates must be set, got %s" % str(types)
	).contains(["skip_tasks", "skip_next_battle"])


func test_item_hit_either_damages_or_destroys_but_never_both() -> void:
	var destroyed := 0
	var damaged := 0
	for _i in range(40):
		var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Hand Laser"]})])
		var out: Dictionary = _process_row(ctx, "item_hit", "c1")
		var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
		if not str(out.get("destroyed_item", "")).is_empty():
			destroyed += 1
			assert_int(member.get("equipment", []).size()).override_failure_message(
				"a destroyed item must leave the sheet").is_equal(0)
		elif not str(out.get("damaged_item", "")).is_empty():
			damaged += 1
			assert_int(member.get("equipment", []).size()).override_failure_message(
				"a damaged item is repairable and must STAY on the sheet").is_equal(1)
	assert_int(destroyed + damaged).override_failure_message(
		"p.102 Item hit always resolves to one or the other").is_equal(40)


func test_school_of_hard_knocks_pays_the_xp() -> void:
	var ctx = _ctx([_member("c1", "Kaya")])
	var out: Dictionary = _process_row(ctx, "school_of_hard_knocks", "c1")
	assert_int(int(out.get("bonus_xp", 0))).is_equal(1)
	assert_int(int(ctx.campaign.get_crew_member_by_id("c1").get("experience", 0))).is_equal(1)


func test_sick_bay_times_match_the_books_column() -> void:
	# p.102: knocked out 0, minor 1, serious 1D3+1, injured leg 1D3.
	var ctx = _ctx([
		_member("c1", "A"), _member("c2", "B"), _member("c3", "C"), _member("c4", "D"),
	])
	assert_int(int(_process_row(ctx, "knocked_out", "c1").get("recovery_turns", -1))).is_equal(0)
	assert_int(int(_process_row(ctx, "minor_injury", "c2").get("recovery_turns", -1))).is_equal(1)
	assert_int(int(_process_row(ctx, "serious_injury", "c3").get("recovery_turns", 0))) \
		.is_between(2, 4)
	assert_int(int(_process_row(ctx, "injured_leg", "c4").get("recovery_turns", 0))) \
		.is_between(1, 3)


# --- The self-repairing gear regression ---------------------------------------

func test_a_damaged_item_marker_has_no_duration_so_it_cannot_expire() -> void:
	var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Hand Laser"]})])
	ctx.damage_random_equipment_for("c1", "test")
	var effects: Array = ctx.campaign.get_crew_member_by_id("c1").get("status_effects", [])
	assert_int(effects.size()).is_equal(1)
	assert_bool(effects[0].has("duration")).override_failure_message(
		"item_damaged must NOT carry `duration`: both turn-rollover loops "
		+ "decrement any effect that has one and delete it at <= 0, so a literal "
		+ "0 meant damaged gear repaired itself overnight"
	).is_false()


func test_destroying_an_item_clears_its_damaged_marker() -> void:
	var ctx = _ctx([_member("c1", "Kaya", {"equipment": ["Hand Laser"]})])
	ctx.damage_random_equipment_for("c1", "test")
	assert_str(ctx.destroy_random_equipment_for("c1")).is_equal("Hand Laser")
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int(member.get("equipment", []).size()).is_equal(0)
	assert_int(member.get("status_effects", []).size()).override_failure_message(
		"Repair Your Kit would offer to fix an item the character no longer owns"
	).is_equal(0)
