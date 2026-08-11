extends GdUnitTestSuite
## The Campaign Editor's Compendium-progress seed fields.
##
## WHY THEY EXIST. Red Zone licensing, Red Zone turns completed and Salvage units
## are the only campaign state gating the deepest Compendium content, and none of
## them was reachable from the editor. A campaign created or corrected there could
## never reach a Black Job (Core Rules p.150: "you have played at least 10
## campaign turns in a Red Zone", and a licence) or the Scrapper (Compendium
## p.147 needs banked Salvage). They are also legitimate onboarding state — a
## tabletop crew joining mid-campaign may already hold both.
##
## WHAT THIS SUITE ACTUALLY PINS, and it is not the UI. The three fields have TWO
## DIFFERENT OWNERS:
##   - red_zone_licensed / red_zone_turns_completed are top-level fields on
##     FiveParsecsCampaignCore with no setter; the live game writes them directly
##     (RedZoneSystem.gd:120, WorldPhaseController.gd:1550).
##   - Salvage units live on progress_data and SalvageLedger is their declared
##     owner.
## The obvious uniform implementation — write all three directly — would be a raw
## progress_data write, exactly what the editor's own header bans and what
## scripts/lint_data_ownership.py exists to stop. And because the owner API takes
## a DELTA while a SpinBox reports an ABSOLUTE, the naive call add_units(n) is
## wrong in a way that only shows when a value is lowered.

const EDITOR_PATH := "res://src/ui/screens/campaign/CampaignEditorScreen.gd"

const SalvageLedger = preload("res://src/core/campaign/SalvageLedger.gd")
const BlackZoneSystem = preload("res://src/core/mission/BlackZoneSystem.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


## Comment stripping is mandatory: the seed handlers are documented at their site
## with the very identifiers a wiring scan looks for, so an unstripped scan would
## pass on the comment that explains the code rather than on the code.
func _code_only(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var out: PackedStringArray = []
	for line in f.get_as_text().split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	f.close()
	return "\n".join(out)


func _campaign() -> Resource:
	var c: Resource = CampaignCore.new()
	c.progress_data = {}
	return c


## The REAL screen, not a mirror of it.
##
## .new() without adding to the tree means _ready() never fires, so none of the
## screen's autoload/chrome wiring runs. That is safe here precisely because all
## three seed handlers are tree-independent by construction — they touch only
## _campaign and SalvageLedger, never get_node_or_null — so the actual shipped
## implementation is what gets exercised below. A mirrored copy of the conversion
## would pass forever while the screen drifted away from it.
func _editor() -> Object:
	var scr: GDScript = load(EDITOR_PATH)
	assert_that(scr).is_not_null()
	return auto_free(scr.new())


# ============================================================================
# The screen still loads, and the three setters exist
# ============================================================================

## --headless --quit only validates startup scripts, and this screen is not one,
## so a parse error here would survive the project's usual compile check. A
## preload is the cheapest thing that actually reads the file.
func test_the_editor_script_loads_and_exposes_the_three_seed_setters() -> void:
	var scr: GDScript = load(EDITOR_PATH)
	assert_that(scr).is_not_null()

	var names: Array = []
	for m in scr.get_script_method_list():
		names.append(str(m.get("name", "")))

	assert_array(names).contains([
		"_on_rz_licensed_toggled",
		"_set_red_zone_turns",
		"_set_salvage_units",
	])


# ============================================================================
# Ownership — the reason this needed writing rather than three lambdas
# ============================================================================

## Anchored on the exact enabling FORM, not a bare mention. A contains() on
## "SalvageLedgerRef.add_units(" survives `if false and SalvageLedgerRef.add_units(`
## — that shape defeated three assertions during the Aug 2026 audit before anyone
## noticed, so the assertion carries its own indentation and the not_contains
## companion that makes a disabled variant fail.
func test_salvage_seeding_goes_through_the_owner_api_never_a_raw_key_write() -> void:
	var src := _code_only(EDITOR_PATH)

	assert_str(src).contains(
		"\tvar delta: int = maxi(0, n) - SalvageLedgerRef.get_units(_campaign)")
	assert_str(src).contains("\t\tSalvageLedgerRef.add_units(_campaign, delta)")

	# The write it must never be. progress_data is SalvageLedger's to touch.
	assert_str(src).not_contains("progress_data[\"salvage_units\"]")
	assert_str(src).not_contains("progress_data[SalvageLedgerRef.UNITS_KEY]")
	assert_str(src).not_contains("and SalvageLedgerRef.add_units(")


## The two Red Zone fields are the OPPOSITE case — no setter exists, so a direct
## write is correct here and routing them through a service would be inventing an
## owner the codebase does not have.
func test_red_zone_seeding_writes_the_core_fields_directly() -> void:
	var src := _code_only(EDITOR_PATH)
	assert_str(src).contains("\t\t_campaign.red_zone_licensed = on")
	assert_str(src).contains("\t\t_campaign.red_zone_turns_completed = maxi(0, n)")


# ============================================================================
# The arithmetic — the only place a naive implementation actually breaks
# ============================================================================

## add_units() takes a delta. A SpinBox reports an absolute. Writing
## add_units(campaign, n) would accumulate instead of set, and every assertion
## below except the first would fail — which is exactly why the first alone would
## not have caught it.
func test_seeding_an_absolute_salvage_total_round_trips_up_and_down() -> void:
	var ed := _editor()
	var c := _campaign()
	ed._campaign = c
	assert_int(SalvageLedger.get_units(c)).is_equal(0)

	ed._set_salvage_units(12)
	assert_int(SalvageLedger.get_units(c)).is_equal(12)

	# The discriminating case: lowering the value. A naive add_units(n) yields 17.
	ed._set_salvage_units(5)
	assert_int(SalvageLedger.get_units(c)).is_equal(5)

	# A no-op set must not drift.
	ed._set_salvage_units(5)
	assert_int(SalvageLedger.get_units(c)).is_equal(5)

	ed._set_salvage_units(0)
	assert_int(SalvageLedger.get_units(c)).is_equal(0)


## The three handlers must also be no-ops with no campaign loaded — the editor
## builds its UI before _load_from_campaign(), and a Control can be constructed
## with _campaign still null.
func test_the_seed_handlers_are_safe_with_no_campaign_loaded() -> void:
	var ed := _editor()
	ed._campaign = null
	ed._set_salvage_units(5)
	ed._set_red_zone_turns(5)
	ed._on_rz_licensed_toggled(true)
	# Reaching here without an error IS the assertion; make it explicit.
	assert_that(ed._campaign).is_null()


## The Red Zone pair, through the real handlers. Negative input is clamped rather
## than stored — red_zone_turns_completed feeds a ">= 10" comparison, and a
## negative would be a silently impossible state.
func test_red_zone_handlers_set_and_clamp_the_core_fields() -> void:
	var ed := _editor()
	var c := _campaign()
	ed._campaign = c

	ed._on_rz_licensed_toggled(true)
	assert_bool(bool(c.red_zone_licensed)).is_true()
	ed._on_rz_licensed_toggled(false)
	assert_bool(bool(c.red_zone_licensed)).is_false()

	ed._set_red_zone_turns(14)
	assert_int(int(c.red_zone_turns_completed)).is_equal(14)
	ed._set_red_zone_turns(-3)
	assert_int(int(c.red_zone_turns_completed)).is_equal(0)


## An empty progress_data is a LEGAL state for a brand-new campaign, and guarding
## on its emptiness is the bug SalvageLedger._has_store() was split out to avoid.
## Seeding must work on the emptiest legal campaign or the editor is useless for
## the case it most needs to serve.
func test_seeding_works_on_a_campaign_whose_progress_data_is_empty() -> void:
	var ed := _editor()
	var c := _campaign()
	ed._campaign = c
	assert_bool(c.progress_data.is_empty()).is_true()
	ed._set_salvage_units(7)
	assert_int(SalvageLedger.get_units(c)).is_equal(7)


# ============================================================================
# What the seeding is FOR — the p.150 gate it unlocks
# ============================================================================

## Core Rules p.150, verified verbatim in the PDF: "for this unless you have
## played at least 10 campaign turns in a Red Zone." Ten is a pass, nine is not,
## and the licence is required on top. This is the gate the seed fields exist to
## reach, so it is pinned here rather than assumed.
func test_the_ten_turn_black_zone_gate_is_what_the_seed_fields_unlock() -> void:
	var c := _campaign()

	# Fresh campaign: no licence, no turns.
	var fresh: Dictionary = BlackZoneSystem.can_accept_mission(c)
	assert_bool(bool(fresh.get("can_accept", true))).is_false()

	# Licensed but one turn short — the licence alone is not enough.
	c.red_zone_licensed = true
	c.red_zone_turns_completed = 9
	var short: Dictionary = BlackZoneSystem.can_accept_mission(c)
	assert_bool(bool(short.get("can_accept", true))).is_false()

	# Exactly ten. "at least 10" is inclusive.
	c.red_zone_turns_completed = 10
	var ok: Dictionary = BlackZoneSystem.can_accept_mission(c)
	assert_bool(bool(ok.get("can_accept", false))).is_true()

	# Turns without the licence must still fail — both halves are required.
	c.red_zone_licensed = false
	var unlicensed: Dictionary = BlackZoneSystem.can_accept_mission(c)
	assert_bool(bool(unlicensed.get("can_accept", true))).is_false()


# ============================================================================
# Persistence — seeded state that does not survive a save is not seeded
# ============================================================================

## The editor's Apply & Save calls GameState.save_campaign(), which serializes
## through to_dictionary(). If any of the three fields dropped out there the whole
## feature would appear to work and silently reset on the next load — the exact
## silent-loss shape the Aug 2026 audit spent itself on.
func test_seeded_compendium_progress_survives_a_save_load_round_trip() -> void:
	var ed := _editor()
	var c := _campaign()
	ed._campaign = c
	ed._on_rz_licensed_toggled(true)
	ed._set_red_zone_turns(14)
	ed._set_salvage_units(23)

	var data: Dictionary = c.to_dictionary()

	var restored: Resource = CampaignCore.new()
	restored.from_dictionary(data)

	assert_bool(bool(restored.red_zone_licensed)).is_true()
	assert_int(int(restored.red_zone_turns_completed)).is_equal(14)
	assert_int(SalvageLedger.get_units(restored)).is_equal(23)

	# And the restored campaign really does clear the gate it was seeded past.
	var gate: Dictionary = BlackZoneSystem.can_accept_mission(restored)
	assert_bool(bool(gate.get("can_accept", false))).is_true()
