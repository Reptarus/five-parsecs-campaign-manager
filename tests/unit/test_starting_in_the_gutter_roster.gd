extends GdUnitTestSuite
## "Starting in the Gutter" — Compendium p.34, second bullet. Sep 2026 page walk.
##
## The book, verbatim: "In a campaign with a standard crew size of 6, begin with
## only 3 crew."
##
## THE DEFECT THIS PINS. Three of the option's four clauses were live (no free
## Military/Hi-Tech rolls, no 1 credit per crew member, no starting ship) and
## this one was recorded as a KNOWN PARTIAL in DLCContentCatalog, because the
## wizard carried ONE crew-size number and this clause needs two:
##
##   campaign_crew_size    the STANDARD size (Core Rules p.63). Drives the
##                         enemy-count dice, the deployment cap, the p.78
##                         Recruit gate and the p.124 stealth sentry count.
##                         Must stay 6.
##   starting_roster_size  how many characters to create now. 3 under this
##                         toggle, equal to the standard size otherwise.
##
## Shrinking `campaign_crew_size` to 3 would have been the easy fix and the wrong
## one: a Gutter campaign would then roll a crew-of-3 enemy count for the rest of
## its life, making the hardest option in the book EASIER than Normal.
##
## gdUnit4 v6.0.3 compatible.

const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")

const COORDINATOR_SRC := "res://src/ui/screens/campaign/CampaignCreationCoordinator.gd"
const CREW_PANEL_SRC := "res://src/ui/screens/campaign/panels/CrewPanel.gd"
const CREATION_UI_SRC := "res://src/ui/screens/campaign/CampaignCreationUI.gd"
const FINAL_PANEL_SRC := "res://src/ui/screens/campaign/panels/FinalPanel.gd"
const CATALOG_SRC := "res://src/ui/screens/store/DLCContentCatalog.gd"

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"))


func after_test() -> void:
	Toggles.clear_creation_toggles()
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


## Turn the option pack on and select `ids` through the creation override — the
## same path the wizard uses, and the only deterministic one before a campaign
## exists.
func _activate(ids: Array) -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"), true)
	Toggles.set_creation_toggles(ids)
	return Toggles.is_toggle_active("starting_gutter")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# ── The rule ──────────────────────────────────────────────────────────────

func test_a_crew_of_six_starts_with_three() -> void:
	if not _activate(["starting_gutter"]):
		return
	assert_int(Toggles.starting_roster_size(6)).override_failure_message(
		"Compendium p.34: a standard crew size of 6 begins with only 3 crew"
	).is_equal(3)


func test_the_standard_size_is_untouched() -> void:
	# The clause shrinks the ROSTER. Shrinking the standard size would change the
	# p.63 enemy-count dice for the whole campaign, making the book's hardest
	# option easier than Normal — the opposite of its purpose.
	if not _activate(["starting_gutter"]):
		return
	var src: String = _read(COORDINATOR_SRC)
	assert_str(src).override_failure_message(
		"the coordinator must publish a SECOND number, not overwrite the size"
	).contains('unified_campaign_state.campaign_config["starting_roster_size"] = roster')
	assert_bool(src.contains("campaign_crew_size = 3")).override_failure_message(
		"campaign_crew_size must never be rewritten to 3 — it drives the p.63"
		+ " enemy-count dice and the deployment cap"
	).is_false()


func test_crews_of_four_and_five_are_unchanged() -> void:
	# p.34 names only the crew of 6; a player who chose 4 or 5 already starts
	# short-handed, and the book does not shrink them further.
	if not _activate(["starting_gutter"]):
		return
	assert_int(Toggles.starting_roster_size(5)).is_equal(5)
	assert_int(Toggles.starting_roster_size(4)).is_equal(4)


func test_the_roster_equals_the_size_without_the_toggle() -> void:
	if not _activate(["reduced_lethality"]):
		return
	assert_int(Toggles.starting_roster_size(6)).override_failure_message(
		"without Starting in the Gutter the roster IS the standard size"
	).is_equal(6)


func test_the_roster_equals_the_size_with_the_pack_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"), false)
	Toggles.clear_creation_toggles()
	assert_int(Toggles.starting_roster_size(6)).is_equal(6)


# ── The wiring ────────────────────────────────────────────────────────────

func test_the_crew_panel_takes_both_numbers() -> void:
	# One argument was the whole reason this clause could not be implemented.
	assert_str(_read(CREW_PANEL_SRC)).override_failure_message(
		"CrewPanel.apply_campaign_crew_size must take the roster as well as the"
		+ " standard size, or the panel has only one number to work from"
	).contains("func apply_campaign_crew_size(size: int, roster_size: int = 0)")


func test_the_creation_ui_hands_the_panel_the_roster() -> void:
	# A producer with no caller is the commonest dead shape in this project, so
	# anchor on the exact call rather than on the key name.
	assert_str(_read(CREATION_UI_SRC)).override_failure_message(
		"nothing passes starting_roster_size to the crew step"
	).contains("panel.apply_campaign_crew_size(configured, roster)")


func test_the_review_step_completes_at_the_roster() -> void:
	# FinalPanel's CREW check compared against campaign_crew_size, so a legal
	# Gutter campaign would sit three crew short forever and never review.
	assert_str(_read(FINAL_PANEL_SRC)).override_failure_message(
		"the review step still requires the STANDARD size, so a Gutter campaign"
		+ " can never complete its crew step"
	).contains('cfg.get(\n\t\t"starting_roster_size", cfg.get("campaign_crew_size", 6))')


func test_the_partial_note_is_gone() -> void:
	# docs/COMPENDIUM_CHAPTER_TRACE and DLCContentCatalog both recorded this as
	# incomplete. The note shrinking IS the progress bar, so it must not outlive
	# the fix.
	assert_bool(_read(CATALOG_SRC).contains("KNOWN PARTIAL")).override_failure_message(
		"DLCContentCatalog still records Starting in the Gutter as partial"
	).is_false()


func test_the_size_dropdown_is_locked_while_the_roster_differs() -> void:
	# The dropdown shows the STANDARD size, which this panel no longer owns under
	# the toggle — leaving it editable would offer the player a control that
	# silently fights the option they chose.
	assert_str(_read(CREW_PANEL_SRC)).contains("crew_size_option.disabled = _gutter_roster")
