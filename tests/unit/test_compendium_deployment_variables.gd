extends GdUnitTestSuite
## Enemy Deployment Variables — Compendium pp.44-45.
##
## THE DEFECT THIS PINS. data/compendium/deployment_variables.json has held the
## nine deployment types and all six AI-type D100 columns, byte-correct against
## the p.44 table, since it was written — and had ZERO loaders anywhere in the
## repository. A player who owned the Freelancer's Handbook and switched the
## option on got standard deployment in every battle of every campaign.
##
## p.44: "Set up both sides normally and roll to Seize the Initiative. If you
## fail, roll D100 on the table below, using the AI type to calculate which
## deployment type the enemy will use. If you successfully Seize the Initiative,
## the enemy will always use the Line (i.e. standard) deployment option."
##
## gdUnit4 v6.0.3 compatible.

const DeployVars = preload("res://src/data/compendium_deployment_variables.gd")

const BATTLE_UI_SRC := "res://src/ui/screens/battle/TacticalBattleUI.gd"

## The p.44 table, transcribed from the book. A dash in the book means that AI
## type never produces that deployment, so the id is simply absent here.
const BOOK_TABLE := {
	"aggressive": {"line": [1, 20], "half_flank": [21, 35], "forward_positions": [36, 50],
		"bolstered_line": [51, 60], "infiltration": [61, 80], "bolstered_flank": [81, 90],
		"concealed": [91, 100]},
	"cautious": {"line": [1, 30], "half_flank": [31, 40], "improved_positions": [41, 50],
		"bolstered_line": [51, 70], "reinforced": [71, 90], "concealed": [91, 100]},
	"defensive": {"line": [1, 25], "improved_positions": [26, 40], "forward_positions": [41, 45],
		"bolstered_line": [46, 60], "infiltration": [61, 70], "reinforced": [71, 85],
		"bolstered_flank": [86, 90], "concealed": [91, 100]},
	"rampage": {"line": [1, 20], "half_flank": [21, 25], "forward_positions": [26, 45],
		"bolstered_line": [46, 65], "infiltration": [66, 75], "reinforced": [76, 80],
		"bolstered_flank": [81, 90], "concealed": [91, 100]},
	"tactical": {"line": [1, 20], "half_flank": [21, 30], "improved_positions": [31, 40],
		"forward_positions": [41, 50], "bolstered_line": [51, 60], "infiltration": [61, 70],
		"reinforced": [71, 80], "bolstered_flank": [81, 90], "concealed": [91, 100]},
	"beast": {"half_flank": [1, 15], "improved_positions": [16, 20],
		"forward_positions": [21, 35], "bolstered_line": [36, 45], "infiltration": [46, 65],
		"reinforced": [66, 70], "bolstered_flank": [71, 80], "concealed": [81, 100]},
}

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("DEPLOYMENT_VARIABLES"))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(
		dlc.ContentFlag.get("DEPLOYMENT_VARIABLES"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _enable() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("DEPLOYMENT_VARIABLES"), true)
	return true


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# --- The data matches the printed table ---------------------------------------

func test_every_column_matches_the_book_span_for_span() -> void:
	var types: Array = DeployVars.DEPLOYMENT_TYPES
	assert_int(types.size()).override_failure_message(
		"p.44 lists nine deployment types").is_equal(9)
	var ids: Array = []
	for entry in types:
		ids.append(str(entry.get("id", "")))

	var tables: Dictionary = DeployVars.DEPLOYMENT_TABLES
	for ai_type in BOOK_TABLE:
		var rows: Array = tables.get(ai_type, [])
		assert_int(rows.size()).override_failure_message(
			"%s column missing from the data file" % ai_type
		).is_equal(BOOK_TABLE[ai_type].size())
		var got := {}
		for row in rows:
			got[str(ids[int(row[0])])] = [int(row[1]), int(row[2])]
		for deploy_id in BOOK_TABLE[ai_type]:
			assert_array(got.get(deploy_id, [])).override_failure_message(
				"%s / %s: book says %s, data says %s" % [ai_type, deploy_id,
					str(BOOK_TABLE[ai_type][deploy_id]), str(got.get(deploy_id, []))]
			).is_equal(BOOK_TABLE[ai_type][deploy_id])


func test_each_column_covers_1_to_100_without_a_gap() -> void:
	# A gap would silently return {} and read as "the option did nothing".
	for ai_type in DeployVars.TABLE_AI_TYPES:
		var rows: Array = DeployVars.DEPLOYMENT_TABLES.get(ai_type, [])
		var spans: Array = []
		for row in rows:
			spans.append([int(row[1]), int(row[2])])
		spans.sort_custom(func(a, b): return a[0] < b[0])
		var previous: int = 0
		for span in spans:
			assert_int(span[0]).override_failure_message(
				"%s column has a gap or overlap at %d" % [ai_type, span[0]]
			).is_equal(previous + 1)
			previous = span[1]
		assert_int(previous).override_failure_message(
			"%s column stops at %d, not 100" % [ai_type, previous]).is_equal(100)


# --- The rule -----------------------------------------------------------------

func test_seizing_the_initiative_always_gives_line() -> void:
	if not _enable():
		return
	for ai_type in DeployVars.TABLE_AI_TYPES:
		for _i in range(10):
			var out: Dictionary = DeployVars.roll_deployment(ai_type, true)
			assert_str(str(out.get("id", ""))).override_failure_message(
				"p.44: 'If you successfully Seize the Initiative, the enemy will "
				+ "always use the Line (i.e. standard) deployment option.'"
			).is_equal("line")


func test_failing_to_seize_rolls_on_the_ai_column() -> void:
	if not _enable():
		return
	for ai_type in DeployVars.TABLE_AI_TYPES:
		var seen := {}
		for _i in range(300):
			var out: Dictionary = DeployVars.roll_deployment(ai_type, false)
			assert_bool(out.is_empty()).override_failure_message(
				"%s produced no deployment — the loader is not reading the table"
				% ai_type).is_false()
			var roll: int = int(out.get("roll", 0))
			assert_int(roll).is_between(1, 100)
			# The result must be one the BOOK allows for this AI type.
			assert_bool(BOOK_TABLE[ai_type].has(str(out.get("id", "")))) \
				.override_failure_message(
					"%s rolled %s, which the book marks '-' for that column"
					% [ai_type, str(out.get("id", ""))]).is_true()
			seen[str(out.get("id", ""))] = true
		assert_int(seen.size()).override_failure_message(
			"%s only ever produced %s over 300 rolls" % [ai_type, str(seen.keys())]
		).is_greater(1)


func test_a_beast_force_can_never_deploy_in_line() -> void:
	# The book prints "-" for Beast / Line. It is the one column with no Line row,
	# so it proves the column is being read rather than a shared default.
	if not _enable():
		return
	for _i in range(300):
		assert_str(str(DeployVars.roll_deployment("beast", false).get("id", ""))) \
			.is_not_equal("line")


func test_single_letter_ai_codes_resolve() -> void:
	# enemy_types.json stores AI as A/C/D/R/T/B, which is what the battle context
	# actually carries.
	assert_str(DeployVars.normalize_ai_type("A")).is_equal("aggressive")
	assert_str(DeployVars.normalize_ai_type("b")).is_equal("beast")
	assert_str(DeployVars.normalize_ai_type("Tactical")).is_equal("tactical")


func test_guardian_gets_no_variable_deployment_rather_than_a_guess() -> void:
	# p.44 prints six columns and Guardian is not one of them.
	if not _enable():
		return
	assert_str(DeployVars.normalize_ai_type("guardian")).is_equal("")
	assert_bool(DeployVars.roll_deployment("guardian", false).is_empty()).is_true()


func test_the_option_is_silent_when_switched_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DEPLOYMENT_VARIABLES"), false)
	assert_bool(DeployVars.roll_deployment("aggressive", false).is_empty()).is_true()
	assert_bool(DeployVars.roll_deployment("aggressive", true).is_empty()).is_true()


# --- The wiring ---------------------------------------------------------------

func test_the_battle_ui_rolls_it_off_the_initiative_result() -> void:
	# Wiring, not behaviour: p.44 keys the roll to the Seize the Initiative
	# outcome, so the call must hang off that handler and nowhere else.
	var src: String = _src(BATTLE_UI_SRC)
	assert_str(src).override_failure_message(
		"TacticalBattleUI no longer resolves the enemy deployment variable"
	).contains("_apply_enemy_deployment_variable(seized)")
	assert_str(src).contains("CompendiumDeploymentVariablesRef.roll_deployment(")
