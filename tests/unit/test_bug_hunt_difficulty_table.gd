extends GdUnitTestSuite

## Compendium p.186 difficulty table, carrying the p.194 Numbers adjustment.
##
## p.194: "on the I'm too pretty to die difficulty setting, the number is reduced by 1.
## On the Mega-violence and Living Nightmare difficulty settings, the number is increased
## by 1." That rule used to live in bug_hunt_enemies.json:difficulty_modifiers, keyed by
## four ids of which "standard" matched no setting, so the app's default (mess_me_up)
## found no row. It is now a column of the one table every setting has a row in.

const MISSIONS := "res://data/bug_hunt/bug_hunt_missions.json"


func _rows() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS))
	var out := {}
	for row: Variant in (data as Dictionary).get("difficulty_settings", []):
		out[str(row.get("id", ""))] = row
	return out


func test_every_setting_carries_the_p194_numbers_adjustment() -> void:
	var expected := {"im_too_pretty_to_die": -1, "hey_not_too_crazy": 0, "mess_me_up": 0,
		"mega_violence": 1, "living_nightmare": 1}
	var rows := _rows()
	assert_int(rows.size()).is_equal(5)
	for id: String in expected:
		assert_bool(rows.has(id)).override_failure_message("p.186 setting '%s' missing" % id).is_true()
		assert_int(int(rows[id].get("numbers_modifier", 99))).override_failure_message(
			"%s numbers_modifier (p.194)" % id).is_equal(expected[id])


func test_the_default_difficulty_has_a_row() -> void:
	# BugHuntCampaignCore defaults to mess_me_up; the old block had no row for it.
	var core := BugHuntCampaignCore.new()
	assert_bool(_rows().has(core.difficulty)).override_failure_message(
		"default difficulty '%s' has no p.186 row" % core.difficulty).is_true()


func test_living_nightmare_places_a_contact_for_each_six() -> void:
	# p.193: "On the Living Nightmare difficulty setting, place a Contact marker for each
	# 6 rolled instead."
	var rows := _rows()
	assert_bool(bool(rows["living_nightmare"].get("reinforcement_contact_per_six", false))).is_true()
	for id: String in ["im_too_pretty_to_die", "hey_not_too_crazy", "mess_me_up", "mega_violence"]:
		assert_bool(bool(rows[id].get("reinforcement_contact_per_six", false))).is_false()
