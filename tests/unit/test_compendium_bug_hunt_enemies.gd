extends GdUnitTestSuite

## The Compendium reference screen shows a Bug Hunt enemy in the Bug Hunt table's own
## columns, Compendium p.194 (BP-12).
##
## ⚠ Before 2026-10-27 `bug_hunt_enemies` shared the 5PFH enemy builder: every Bug Hunt
## enemy read "Panic: —", "AI: —" and "Weapons: —" (fields it does not have) while its
## Damage column and its special rule were never shown. The row below is read from the
## shipped data file, so the case fails if the data and the screen drift apart.

const ViewScript = preload("res://src/ui/screens/compendium/CompendiumCategoryView.gd")
const ENEMIES_PATH := "res://data/bug_hunt/bug_hunt_enemies.json"


func _first_enemy() -> Dictionary:
	var f := FileAccess.open(ENEMIES_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	return (data.get("enemy_table", []) as Array)[0]


func test_a_bug_hunt_enemy_shows_its_own_columns_and_special_rule() -> void:
	var row := _first_enemy()
	assert_str(str(row.get("special_rule", ""))).override_failure_message(
		"premise: the first shipped row carries a special rule").is_not_empty()
	var view = auto_free(ViewScript.new())
	view._category = {"id": "bug_hunt_enemies"}
	var body: String = view._build_detail_body(row)
	assert_str(body).contains("Damage:[/color] %d" % int(row.damage))
	assert_str(body).contains(str(row.special_rule))
	assert_str(body).contains("Enemy table D100: 01-08")
	for absent in ["Panic", "AI:", "Weapons"]:
		assert_str(body).override_failure_message(
			"a Bug Hunt enemy has no %s column" % absent).not_contains(absent)
