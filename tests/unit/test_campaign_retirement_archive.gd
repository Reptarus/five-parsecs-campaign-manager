extends GdUnitTestSuite
## Core Rules p.8 — a campaign may simply end when the players decide it has:
## "Others decide on a set number of campaign turns, or just play until they feel
## their crew is either forced to disband, or has MADE IT BIG AND CAN RETIRE."
##
## `EndPhasePanel._try_archive_campaign()` has always gated on
## `progress_data["crew_retired"]` and NOTHING in the codebase ever wrote it — a
## consumer with no producer, so a crew that retired was silently dropped instead
## of entering the Hall of Fame. The gate is now reachable from a real control.
##
## Reading that function to add the writer surfaced a SECOND defect in it: the
## archive had no idempotence guard, while `setup_phase()` re-enables the Save
## button every turn and the turn gate stays open forever once turns >= 20. A
## campaign taken to turn 30 filed eleven copies of itself into the same list that
## `get_best_campaign()` and `get_legacy_bonus()` read.
##
## gdUnit4 v6.0.3 compatible.

const PANEL_SRC := "res://src/ui/screens/campaign/phases/EndPhasePanel.gd"
const PANEL_TSCN := "res://src/ui/screens/campaign/phases/EndPhasePanel.tscn"
const LEGACY_SRC := "res://src/core/campaign/LegacySystem.gd"
const DASHBOARD_SRC := "res://src/ui/screens/campaign/CampaignDashboard.gd"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comment-stripped source — a scan that forbids a string must ignore the comment
## that explains why it is forbidden.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _legacy() -> Node:
	return get_node_or_null("/root/LegacySystem")


# ── 1. The writer exists and reaches the campaign ──────────────────────────

func test_crew_retired_has_a_producer_not_only_a_consumer() -> void:
	var src: String = _code_only(PANEL_SRC)
	assert_bool(src.contains("progress_data[\"crew_retired\"] = true")) \
		.override_failure_message(
			"nothing writes progress_data[\"crew_retired\"] again — the archival"
			+ " gate at _try_archive_campaign() is unreachable by retirement, so a"
			+ " Core Rules p.8 crew retirement drops the campaign silently"
		).is_true()


func test_the_retire_control_exists_in_the_scene_and_is_connected() -> void:
	var scene: String = _src(PANEL_TSCN)
	assert_bool(scene.contains("[node name=\"RetireButton\" type=\"Button\"")) \
		.override_failure_message(
			"RetireButton is gone from EndPhasePanel.tscn; the @onready var would"
			+ " resolve null and the writer becomes unreachable").is_true()
	var src: String = _code_only(PANEL_SRC)
	assert_bool(src.contains("retire_button.pressed.connect")) \
		.override_failure_message(
			"the Retire button is built but never connected — a control that looks"
			+ " like it works and does not").is_true()


func test_retirement_is_confirmed_before_it_happens() -> void:
	# It is irreversible, so it must not be a single mis-tap.
	var src: String = _code_only(PANEL_SRC)
	assert_bool(src.contains("ConfirmationDialog.new()")).override_failure_message(
		"retirement no longer asks for confirmation").is_true()
	assert_bool(src.contains("dialog.confirmed.connect(_retire_crew)")) \
		.override_failure_message(
			"_retire_crew is not wired to the dialog's confirmed signal, so either"
			+ " it never runs or it runs without asking").is_true()


func test_retirement_archives_and_journals() -> void:
	var src: String = _code_only(PANEL_SRC)
	var body: String = src.substr(src.find("func _retire_crew"))
	body = body.substr(0, body.find("func _try_archive_campaign"))
	assert_bool(body.contains("_try_archive_campaign()")).override_failure_message(
		"retiring sets the flag but never calls the archival step, so the crew"
		+ " still never reaches the Hall of Fame").is_true()
	assert_bool(body.contains("auto_create_milestone_entry")).override_failure_message(
		"the campaign's own ending is not written to its journal").is_true()
	assert_bool(body.contains("campaign_retired.emit()")).override_failure_message(
		"nothing is told the campaign ended, so a host screen keeps offering a"
		+ " next turn that cannot happen").is_true()


# ── 2. The archive fires exactly once ──────────────────────────────────────

func test_the_archive_is_guarded_against_re_archiving() -> void:
	var src: String = _code_only(PANEL_SRC)
	assert_bool(src.contains("campaign_archived")).override_failure_message(
		"the once-per-campaign guard is gone. _try_archive_campaign() runs on"
		+ " every Save press and the turns >= 20 gate never closes, so a long"
		+ " campaign appends a duplicate Hall of Fame entry every single turn"
	).is_true()


## The guard must be claimed only when the archive is really about to be written.
## Setting it above the LegacySystem null-check would consume the one chance and
## lose the campaign permanently on a missing autoload.
func test_the_guard_is_claimed_after_the_autoload_check() -> void:
	var src: String = _code_only(PANEL_SRC)
	var fn: String = src.substr(src.find("func _try_archive_campaign"))
	var legacy_at: int = fn.find("get_node_or_null(\"/root/LegacySystem\")")
	var claim_at: int = fn.find("campaign.progress_data[\"campaign_archived\"] = true")
	assert_int(legacy_at).override_failure_message(
		"LegacySystem lookup not found in _try_archive_campaign").is_greater(-1)
	assert_int(claim_at).override_failure_message(
		"the campaign_archived claim is not written in _try_archive_campaign"
	).is_greater(-1)
	assert_bool(claim_at > legacy_at).override_failure_message(
		"campaign_archived is claimed BEFORE the LegacySystem guard — a null"
		+ " autoload would burn the one archive attempt and lose the campaign"
	).is_true()


## Behavioural half of the same rule, against the live autoload.
func test_archiving_twice_files_one_entry_not_two() -> void:
	var legacy: Node = _legacy()
	if legacy == null or not legacy.has_method("archive_campaign"):
		return
	var before: int = (legacy.get_hall_of_fame() as Array).size()
	legacy.archive_campaign("unit-test-retire-a", {"turns_survived": 21})
	legacy.archive_campaign("unit-test-retire-b", {"turns_survived": 22})
	var after: int = (legacy.get_hall_of_fame() as Array).size()
	# LegacySystem itself is an append-only store by design; the once-per-campaign
	# decision belongs to the caller. This pins that appending really does append,
	# so the guard above is doing real work rather than covering for a no-op.
	assert_int(after - before).override_failure_message(
		"LegacySystem.archive_campaign stopped appending; the caller-side guard"
		+ " would then be masking a silent failure instead of preventing"
		+ " duplicates").is_equal(2)


# ── 3. The ending is recorded honestly ─────────────────────────────────────

func test_the_archive_carries_how_the_campaign_ended() -> void:
	assert_bool(_code_only(LEGACY_SRC).contains("\"ended_by\"")).override_failure_message(
		"archive_campaign() builds a WHITELIST dict — a key it does not name is"
		+ " dropped, so ended_by must be listed there or it never survives"
	).is_true()
	assert_bool(_code_only(PANEL_SRC).contains("\"ended_by\": ended_by")) \
		.override_failure_message("the panel stopped passing ended_by").is_true()


func test_ended_by_defaults_and_round_trips() -> void:
	var legacy: Node = _legacy()
	if legacy == null or not legacy.has_method("archive_campaign"):
		return
	legacy.archive_campaign("unit-test-ended-by", {
		"turns_survived": 12, "ended_by": "retired",
	})
	var hof: Array = legacy.get_hall_of_fame()
	var found := {}
	for a: Variant in hof:
		if (a as Dictionary).get("campaign_id", "") == "unit-test-ended-by":
			found = a
	assert_bool(found.is_empty()).override_failure_message(
		"the archive was not stored").is_false()
	assert_str(str(found.get("ended_by", ""))).override_failure_message(
		"ended_by did not survive the whitelist").is_equal("retired")

	# And an ordinary archive must not silently claim retirement.
	legacy.archive_campaign("unit-test-ended-default", {"turns_survived": 20})
	for a: Variant in legacy.get_hall_of_fame():
		if (a as Dictionary).get("campaign_id", "") == "unit-test-ended-default":
			assert_str(str((a as Dictionary).get("ended_by", ""))) \
				.override_failure_message(
					"an unlabelled archive defaults to something other than"
					+ " 'ended'").is_equal("ended")


## Victory outranks retirement: a crew that retires ON the turn it completes its
## Victory Condition still earned the p.65 Elite Rank, and the card must say so.
func test_victory_outranks_retirement_in_the_label() -> void:
	var src: String = _code_only(PANEL_SRC)
	var v_at: int = src.find("ended_by = \"victory\"")
	var r_at: int = src.find("ended_by = \"retired\"")
	assert_int(v_at).is_greater(-1)
	assert_int(r_at).is_greater(-1)
	assert_bool(v_at < r_at).override_failure_message(
		"the retired branch is tested before the victory branch, so a crew that"
		+ " retires on its winning turn loses the VICTORY label").is_true()


func test_the_hall_of_fame_card_shows_retirement() -> void:
	assert_bool(_code_only(DASHBOARD_SRC).contains("\"retired\"")) \
		.override_failure_message(
			"the Hall of Fame card no longer distinguishes a retired campaign from"
			+ " one that merely ran long — ended_by becomes a producer with no"
			+ " consumer, which is the defect shape this audit exists to remove"
		).is_true()
