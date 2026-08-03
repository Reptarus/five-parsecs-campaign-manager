extends GdUnitTestSuite
## Compendium "Loans: Who Do You Owe?" pp.152-156, Step 2 — The Loan Amount.
##
## THE DEFECT THIS PINS. Steps 1 (origin), 3 (interest rate) and 4 (enforcement
## thresholds) all rolled correctly and fed a loan whose PRINCIPAL was the literal
## `var loan_amount: int = 20`, carrying a comment that called it the "Compendium
## standard starting loan". No such rule exists. The book says:
##
##   "The base value of the loan will be the cost of the ship in question, as
##    indicated on p.31 of the core rules. [...]
##    - Unity Program loans must add +5 Credits due to fees and paperwork.
##    - Free Trader or Suspicious Character loans must add +1D6 Credits due to
##      personal whims."
##
## So the one place the chapter's five lenders differ in COST rather than flavour
## had no implementation: a Unity Program loan and a Suspicious Character loan
## were financially identical. world_options.json has carried a `fee_adjustment`
## string on every origin row the whole time, read by nothing.
##
## gdUnit4 v6.0.3 compatible.

const WorldOptions = preload("res://src/data/compendium_world_options.gd")

const TRADE_PANEL_SRC := "res://src/ui/screens/campaign/phases/TradePhasePanel.gd"

## Core Rules p.31 Ship Table, DEBT column: every hull is "1D6 + base".
const P31_DEBT_BASE := {
	"Worn Freighter": 20,
	"Retired Troop Transport": 30,
	"Strange Alien Vessel": 15,
	"Upgraded Shuttle": 10,
	"Retired Scout Ship": 20,
	"Repurposed Science Vessel": 10,
	"Battered Mining Ship": 20,
	"Unreliable Merchant Cruiser": 20,
	"Former Diplomatic Vessel": 15,
	"Ancient Low-tech Craft": 20,
	"Built from Salvaged Wrecks": 20,
	"Worn Colony Ship": 20,
	"Retired Military Patrol Ship": 35,
}


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# --- The surcharge itself -----------------------------------------------------

func test_unity_program_adds_exactly_five() -> void:
	for _i in range(20):
		assert_int(WorldOptions.loan_origin_surcharge("unity_program")) \
			.override_failure_message(
				"p.152: 'Unity Program loans must add +5 Credits'").is_equal(5)


func test_free_trader_and_suspicious_character_add_1d6() -> void:
	for origin_id in ["free_trader", "suspicious_character"]:
		var seen := {}
		for _i in range(200):
			var v: int = WorldOptions.loan_origin_surcharge(origin_id)
			assert_int(v).override_failure_message(
				"p.152: '+1D6 Credits due to personal whims' — %s gave %d"
				% [origin_id, v]).is_between(1, 6)
			seen[v] = true
		# A fixed value masquerading as a roll is the exact bug this file exists
		# for, so require the surcharge to actually vary.
		assert_int(seen.size()).override_failure_message(
			"%s returned a constant, not 1D6" % origin_id).is_greater(3)


func test_the_two_plain_origins_add_nothing() -> void:
	# p.152 lists adjustments for Unity, Free Trader and Suspicious Character
	# only. Sector Government and Corporate get the base cost.
	for origin_id in ["sector_government", "corporate"]:
		assert_int(WorldOptions.loan_origin_surcharge(origin_id)).is_equal(0)


func test_an_unknown_origin_adds_nothing_rather_than_guessing() -> void:
	assert_int(WorldOptions.loan_origin_surcharge("")).is_equal(0)
	assert_int(WorldOptions.loan_origin_surcharge("bank_of_unity")).is_equal(0)


# --- Every origin the table can roll is handled -------------------------------

func test_every_loan_origin_id_in_the_data_file_is_covered() -> void:
	# A new row added to world_options.json with an id the surcharge does not
	# know would silently price at +0 — the same class of bug, one row at a time.
	var known := ["unity_program", "sector_government", "corporate",
		"free_trader", "suspicious_character"]
	var ids := []
	for origin in WorldOptions.LOAN_ORIGINS:
		ids.append(str(origin.get("id", "")))
	assert_array(ids).override_failure_message(
		"world_options.json loan_origins ids drifted from the surcharge match: %s"
		% str(ids)).contains_exactly_in_any_order(known)


func test_the_data_files_fee_adjustment_text_agrees_with_the_surcharge() -> void:
	# The JSON prose and the code must not disagree — the prose is what the
	# player is shown, and it was the only place this rule existed for months.
	for origin in WorldOptions.LOAN_ORIGINS:
		var origin_id: String = str(origin.get("id", ""))
		var note: String = str(origin.get("fee_adjustment", "")).to_lower()
		var surcharge: int = WorldOptions.loan_origin_surcharge(origin_id)
		if note.begins_with("none"):
			assert_int(surcharge).override_failure_message(
				"%s says '%s' but charges %d" % [origin_id, note, surcharge]
			).is_equal(0)
		else:
			assert_int(surcharge).override_failure_message(
				"%s says '%s' but charges nothing" % [origin_id, note]
			).is_greater(0)


# --- The principal is the ship's p.31 cost ------------------------------------

func test_ships_json_debt_bases_match_the_core_rules_p31_table() -> void:
	var f := FileAccess.open("res://data/ships.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	var ok: bool = json.parse(f.get_as_text()) == OK
	f.close()
	assert_bool(ok).is_true()

	var found := 0
	for entry in json.data.get("ship_types", []):
		var ship_name: String = str(entry.get("name", ""))
		if not P31_DEBT_BASE.has(ship_name):
			continue
		found += 1
		assert_int(int(entry.get("debt_base", -1))).override_failure_message(
			"%s debt_base disagrees with Core Rules p.31" % ship_name
		).is_equal(int(P31_DEBT_BASE[ship_name]))
	assert_int(found).override_failure_message(
		"only matched %d of the 13 p.31 hulls by name — the loan principal "
		% found + "resolves the ship by name, so a rename silently reverts it "
		+ "to the fallback").is_equal(13)


func test_the_flat_twenty_credit_principal_is_gone() -> void:
	# Wiring, not behaviour: the principal is computed inside a UI handler, so
	# the source is the honest instrument for "is this still connected".
	var src: String = _src(TRADE_PANEL_SRC)
	assert_str(src).override_failure_message(
		"TradePhasePanel no longer derives the principal from the ship's p.31 cost"
	).contains("_ship_cost_from_core_rules_p31()")
	assert_str(src).override_failure_message(
		"the origin surcharge is not being applied to the principal"
	).contains("loan_origin_surcharge(origin_id)")
