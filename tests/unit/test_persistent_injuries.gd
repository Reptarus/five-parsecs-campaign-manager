extends GdUnitTestSuite
## The four Compendium p.102 injuries that OUTLIVE Sick Bay, plus the knock-out
## rule they modify. Sep 2026 page walk.
##
## THE DEFECT THIS PINS. `InjuryProcessor._process_detailed_injury` handled five
## of the twelve p.102 rows and let injured_arm / injured_leg / injured_torso /
## lingering_injury fall through with nothing but a Sick Bay count. Both
## turn-rollover countdowns then DELETE an injury entry the moment its recovery
## reaches 0 — so all four evaporated a turn or three after the battle, and a
## penalty the book says lasts "until 3 Credits of medical treatment" lasted
## exactly as long as the character was in the med bay.
##
## Extensive injury was worse than absent: it wrote skip_tasks +
## skip_next_battle effects with NO `duration`, which the turn-rollover expiry
## can never clear, and its `treatment_cost` had no consumer anywhere in the
## codebase. A permanent benching with no way to pay.
##
## And Core Rules p.40 — "If a character ever has 3 or more Stun markers at the
## same time, they are knocked out and removed from play" — was not implemented
## on the played path at all, which is why Injured torso ("knocked out after two
## Stun markers, instead of the customary three") had nothing to modify.
##
## gdUnit4 v6.0.3 compatible.

const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryProcessorClass = preload(
	"res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")
const PhaseManagerClass = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const LingeringRef = preload("res://src/core/campaign/LingeringInjuryCheck.gd")
const BattleCalc = preload("res://src/core/battle/BattleCalculations.gd")

const INJURY_PROC_SRC := "res://src/core/campaign/phases/post_battle/InjuryProcessor.gd"
const GSM_SRC := "res://src/core/managers/GameStateManager.gd"
const CTC_SRC := "res://src/ui/screens/campaign/CampaignTurnController.gd"
const UNTREATED_SOURCE := "Detailed Injury: Extensive injury"

const FLAGS := ["CASUALTY_TABLES", "DETAILED_INJURIES"]
const PERSISTENT_ROWS := ["injured_arm", "injured_leg", "injured_torso"]

var _saved_flags: Dictionary = {}
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


## DLCManager is an AUTOLOAD — a flag left flipped leaks into every later suite.
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


func _member(id: String, cname: String, extra: Dictionary = {}) -> Dictionary:
	var m := {
		"character_id": id, "character_name": cname,
		"combat": 1, "speed": 4, "toughness": 3, "luck": 0,
		"experience": 0, "equipment": [], "status_effects": [], "injuries": [],
		"origin": "human", "species_id": "human", "is_captain": false,
	}
	for k in extra:
		m[k] = extra[k]
	return m


func _ctx(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "pinj", "crew": {"members": members}})
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 3}
	return ctx


func _row(row_id: String) -> Dictionary:
	for entry in Toggles.DETAILED_INJURY_TABLE:
		if entry is Dictionary and str(entry.get("id", "")) == row_id:
			return entry
	return {}


## Drive the REAL processor for one named row, so the flags under test are the
## ones production writes rather than a hand-built fixture the app cannot make.
func _process_row(row_id: String) -> Dictionary:
	var row: Dictionary = _row(row_id)
	assert_dict(row).override_failure_message(
		"row '%s' is missing from detailed_injury_table" % row_id).is_not_empty()
	var member: Dictionary = _member("c1", "Patient")
	var ctx = _ctx([member])
	var proc = InjuryProcessorClass.new()
	var processed: Dictionary = proc._process_detailed_injury(ctx, row, "c1")
	return {"processed": processed, "member": ctx.campaign.crew_data["members"][0]}


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# ── The flags ─────────────────────────────────────────────────────────────

func test_the_three_treatable_injuries_are_marked_persistent() -> void:
	if not _enable():
		return
	for row_id in PERSISTENT_ROWS:
		var processed: Dictionary = _process_row(row_id)["processed"]
		assert_bool(bool(processed.get("persistent", false))).override_failure_message(
			"'%s' is not marked persistent, so the recovery tick deletes it"
			% row_id).is_true()
		# p.102: "It takes 3 Credits of medical treatment to remove this penalty."
		assert_int(int(processed.get("treatment_cost", 0))).override_failure_message(
			"'%s' must cost 3 credits to treat (Compendium p.102)" % row_id
		).is_equal(3)


func test_a_lingering_injury_is_marked_but_not_treatable() -> void:
	# p.102 clears a Lingering Injury on a natural 6 before a mission, NOT by
	# paying — so it is persistent with no treatment cost.
	if not _enable():
		return
	var processed: Dictionary = _process_row("lingering_injury")["processed"]
	assert_bool(bool(processed.get("persistent", false))).is_true()
	assert_bool(bool(processed.get("lingering", false))).is_true()
	assert_int(int(processed.get("treatment_cost", 0))).override_failure_message(
		"a Lingering Injury is cleared by a die roll, not by credits"
	).is_equal(0)


func test_the_persistence_flags_survive_the_record_chokepoint() -> void:
	# `PostBattleContext.apply_crew_injury` builds each injuries[] entry from a
	# FIXED key literal, so anything not named there is DELETED — the same shape
	# as CampaignJournal.create_entry. Asserting on the processed dict alone
	# would prove nothing about what the crew member actually carries.
	if not _enable():
		return
	var member: Dictionary = _process_row("injured_leg")["member"]
	var injuries: Array = member.get("injuries", [])
	assert_array(injuries).is_not_empty()
	var found := false
	for entry in injuries:
		if entry is Dictionary and bool(entry.get("persistent", false)):
			found = true
			assert_int(int(entry.get("treatment_cost", 0))).is_equal(3)
	assert_bool(found).override_failure_message(
		"the injuries[] entry lost its `persistent` flag at apply_crew_injury —"
		+ " that literal is a fixed key set and drops anything unnamed"
	).is_true()


# ── Both recovery countdowns ──────────────────────────────────────────────

func test_the_turn_rollover_keeps_a_persistent_injury_but_ends_sick_bay() -> void:
	# The whole point: the Sick Bay stay ends on schedule, the PENALTY does not.
	var member: Dictionary = _member("c1", "Limper")
	member["injuries"] = [
		{"type": "injured_leg", "recovery_turns": 1, "persistent": true,
			"treatment_cost": 3},
	]
	member["in_sick_bay"] = true
	member["recovery_turns"] = 1
	member["status"] = "injured"
	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "tick", "crew": {"members": [member]}})
	var pm = auto_free(PhaseManagerClass.new())
	add_child(pm)

	pm._process_sick_bay_recovery(campaign)

	var after: Dictionary = campaign.crew_data["members"][0]
	assert_int((after.get("injuries", []) as Array).size()).override_failure_message(
		"the countdown deleted the persistent injury, so the p.102 penalty is gone"
	).is_equal(1)
	assert_bool(bool(after.get("in_sick_bay", true))).override_failure_message(
		"a persistent injury must not keep the character in Sick Bay forever"
	).is_false()


func test_the_resource_path_countdown_also_keeps_it() -> void:
	# A fresh campaign holds Character Resources, which tick through
	# Character.process_recovery_turn() instead. Both paths or neither.
	var c: Character = Character.new()
	c.character_name = "Resource Limper"
	c.injuries.append({"type": "injured_arm", "recovery_turns": 1,
		"persistent": true, "treatment_cost": 3})
	c.injuries.append({"type": "minor_injury", "recovery_turns": 1})
	c.process_recovery_turn()
	assert_int(c.injuries.size()).override_failure_message(
		"the Resource countdown removed the persistent injury alongside the"
		+ " ordinary one; only the ordinary one should go"
	).is_equal(1)
	assert_str(str(c.injuries[0].get("type", ""))).is_equal("injured_arm")


# ── Paying for treatment ──────────────────────────────────────────────────

func test_paying_for_treatment_removes_the_injury_and_charges_credits() -> void:
	# p.102: "It takes 3 Credits of medical treatment to remove this penalty."
	# `treatment_cost` had NO consumer before this — the number was written and
	# read by nothing, so there was no way to end any of the three penalties.
	var gsm := _gsm()
	var gs := _gs()
	if gsm == null or gs == null:
		return
	var saved = gs.current_campaign
	var member: Dictionary = _member("c1", "Payer")
	member["injuries"] = [
		{"type": "injured_leg", "recovery_turns": 0, "persistent": true,
			"treatment_cost": 3, "table_name": "Injured Leg"},
	]
	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "pay", "crew": {"members": [member]}})
	campaign.credits = 10
	gs.current_campaign = campaign

	var res: Dictionary = gsm.pay_medical_treatment("c1", 0)
	assert_bool(bool(res.get("ok", false))).override_failure_message(
		"payment failed: %s" % str(res.get("reason", ""))).is_true()
	assert_int(int(res.get("cost", 0))).is_equal(3)
	assert_int(gsm.get_credits()).override_failure_message(
		"treatment must be CHARGED, not merely checked").is_equal(7)
	assert_array(campaign.crew_data["members"][0].get("injuries", [])) \
		.override_failure_message("the treated injury is still on the character") \
		.is_empty()

	gs.current_campaign = saved


func test_treatment_is_refused_when_the_crew_cannot_pay() -> void:
	# One site checks AND charges (GameStateManager.remove_credits), because a
	# separate check and charge is how the p.53 licensing bug let a crew add what
	# it could not pay for.
	var gsm := _gsm()
	var gs := _gs()
	if gsm == null or gs == null:
		return
	var saved = gs.current_campaign
	var member: Dictionary = _member("c1", "Broke")
	member["injuries"] = [
		{"type": "injured_arm", "recovery_turns": 0, "persistent": true,
			"treatment_cost": 3},
	]
	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "broke", "crew": {"members": [member]}})
	campaign.credits = 2
	gs.current_campaign = campaign

	var res: Dictionary = gsm.pay_medical_treatment("c1", 0)
	assert_bool(bool(res.get("ok", true))).is_false()
	assert_int(gsm.get_credits()).override_failure_message(
		"a refused treatment must not spend anything").is_equal(2)
	assert_array(campaign.crew_data["members"][0].get("injuries", [])) \
		.override_failure_message("a refused treatment must not cure anyone") \
		.is_not_empty()

	gs.current_campaign = saved


func test_paying_an_extensive_injury_starts_recovery_and_frees_the_crew() -> void:
	# p.102, verbatim: "Until the cost has been paid, the character cannot take
	# crew tasks or fight. The Sick Bay recovery time begins ONCE THEY HAVE
	# RECEIVED TREATMENT." The two status effects were written with no duration,
	# so nothing could ever expire them — paying is the only exit and it did not
	# exist.
	var gsm := _gsm()
	var gs := _gs()
	if gsm == null or gs == null:
		return
	var saved = gs.current_campaign
	var member: Dictionary = _member("c1", "Extensive")
	member["injuries"] = [
		{"type": "extensive_injury", "recovery_turns": 4, "persistent": false,
			"treatment_cost": 4, "treatment_pending": true},
	]
	member["status_effects"] = [
		{"type": "skip_tasks", "name": "Untreated Injury (4cr)",
			"source_event": UNTREATED_SOURCE},
		{"type": "skip_next_battle", "name": "Untreated Injury (4cr)",
			"source_event": UNTREATED_SOURCE},
	]
	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "ext", "crew": {"members": [member]}})
	campaign.credits = 9
	gs.current_campaign = campaign

	var res: Dictionary = gsm.pay_medical_treatment("c1", 0)
	assert_bool(bool(res.get("ok", false))).is_true()
	assert_int(int(res.get("recovery_turns", 0))).override_failure_message(
		"Sick Bay must BEGIN at payment, not run while untreated").is_equal(4)
	var after: Dictionary = campaign.crew_data["members"][0]
	assert_array(after.get("status_effects", [])).override_failure_message(
		"the untreated-injury lockout effects survived payment, so the crew"
		+ " member is still benched with nothing left to pay"
	).is_empty()
	assert_bool(bool(after.get("in_sick_bay", false))).is_true()

	gs.current_campaign = saved


func test_the_untreated_source_string_matches_on_both_sides() -> void:
	# The writer (InjuryProcessor) and the clearer (GameStateManager) must agree
	# on `source_event` exactly, or paying would leave the effects in place. They
	# live in different files, so a test is the only thing holding them together.
	assert_str(_read(INJURY_PROC_SRC)).contains(UNTREATED_SOURCE)
	assert_str(_read(GSM_SRC)).override_failure_message(
		"GameStateManager's UNTREATED_INJURY_SOURCE no longer matches the string"
		+ " InjuryProcessor stamps, so paying cannot clear the lockout effects"
	).contains(UNTREATED_SOURCE)


# ── Lingering Injury, the pre-mission 1D6 ─────────────────────────────────

func test_a_lingering_injury_is_skipped_while_still_in_sick_bay() -> void:
	# p.102: "Note down that the character has a Lingering Injury ONCE THEY
	# RECOVER." An entry still serving its recovery turns gets no roll yet.
	if not _enable():
		return
	var member: Dictionary = _member("c1", "Healing")
	member["injuries"] = [
		{"type": "lingering_injury", "recovery_turns": 2, "persistent": true,
			"lingering": true},
	]
	assert_array(LingeringRef.pending_for(member)).is_empty()
	var res: Dictionary = LingeringRef.roll_for(member, func(): return 1)
	assert_bool(bool(res.get("rolled", true))).is_false()


func test_a_one_benches_the_character_for_this_battle_only() -> void:
	# p.102: "On a 1, their old injury is acting up and they cannot participate
	# in the battle." Benched through the skip_next_battle effect, which
	# GameStateManager.filter_deployable() already excludes — one gate, not two.
	if not _enable():
		return
	var member: Dictionary = _member("c1", "Aching")
	member["injuries"] = [
		{"type": "lingering_injury", "recovery_turns": 0, "persistent": true,
			"lingering": true},
	]
	var res: Dictionary = LingeringRef.roll_for(member, func(): return 1)
	assert_bool(bool(res.get("benched", false))).is_true()
	var effects: Array = member.get("status_effects", [])
	assert_array(effects).is_not_empty()
	assert_str(str(effects[0].get("type", ""))).is_equal("skip_next_battle")
	# duration 1 so the turn rollover expires it — the book benches them for THIS
	# mission, not permanently.
	assert_int(int(effects[0].get("duration", 0))).is_equal(1)
	# The injury itself is NOT cleared by a 1.
	assert_array(member.get("injuries", [])).is_not_empty()

	var gsm := _gsm()
	if gsm == null:
		return
	assert_array(gsm.filter_deployable([member])).override_failure_message(
		"a benched character must not be deployable (Compendium p.102)"
	).is_empty()


func test_a_six_clears_the_lingering_injury_for_good() -> void:
	# p.102: "On a 6, they are finally over it and are fully recovered."
	if not _enable():
		return
	var member: Dictionary = _member("c1", "Recovered")
	member["injuries"] = [
		{"type": "lingering_injury", "recovery_turns": 0, "persistent": true,
			"lingering": true, "table_name": "Lingering Injury"},
	]
	var res: Dictionary = LingeringRef.roll_for(member, func(): return 6)
	assert_bool(bool(res.get("benched", true))).is_false()
	assert_array(res.get("cleared", [])).is_not_empty()
	assert_array(member.get("injuries", [])).override_failure_message(
		"a natural 6 must remove the Lingering Injury entirely"
	).is_empty()


func test_a_two_to_five_leaves_everything_alone() -> void:
	if not _enable():
		return
	for face in [2, 3, 4, 5]:
		var member: Dictionary = _member("c1", "Fine")
		member["injuries"] = [
			{"type": "lingering_injury", "recovery_turns": 0, "persistent": true,
				"lingering": true},
		]
		var res: Dictionary = LingeringRef.roll_for(member, func(): return face)
		assert_bool(bool(res.get("benched", true))).override_failure_message(
			"a %d must not bench the character" % face).is_false()
		assert_array(member.get("injuries", [])).is_not_empty()
		assert_array(member.get("status_effects", [])).is_empty()


func test_multiple_lingering_injuries_each_get_their_own_die() -> void:
	# p.102: "A character could potentially have multiple lingering injuries and
	# would roll for EACH IN TURN." A 1 on any of them benches the figure, and a
	# 6 clears only that one.
	if not _enable():
		return
	var member: Dictionary = _member("c1", "Veteran")
	member["injuries"] = [
		{"type": "lingering_injury", "recovery_turns": 0, "persistent": true,
			"lingering": true, "table_name": "First"},
		{"type": "lingering_injury", "recovery_turns": 0, "persistent": true,
			"lingering": true, "table_name": "Second"},
	]
	var faces: Array = [6, 1]
	var res: Dictionary = LingeringRef.roll_for(member, func(): return faces.pop_front())
	assert_int((res.get("rolls", []) as Array).size()).override_failure_message(
		"two lingering injuries must produce two dice"
	).is_equal(2)
	assert_bool(bool(res.get("benched", false))).is_true()
	assert_int((member.get("injuries", []) as Array).size()).override_failure_message(
		"the 6 should have cleared exactly one of the two"
	).is_equal(1)


func test_the_check_is_off_without_the_detailed_injuries_option() -> void:
	# The table is a DLC option, so its follow-up roll must be too.
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DETAILED_INJURIES"), false)
	var member: Dictionary = _member("c1", "NoDLC")
	member["injuries"] = [
		{"type": "lingering_injury", "recovery_turns": 0, "persistent": true,
			"lingering": true},
	]
	var res: Dictionary = LingeringRef.roll_for(member, func(): return 1)
	assert_bool(bool(res.get("rolled", true))).is_false()
	assert_array(member.get("status_effects", [])).is_empty()


func test_the_battle_path_rolls_the_check_before_deployment() -> void:
	# Anchored on the exact enabling call: the roll has to happen before the crew
	# is filtered, or the benching it produces would not be seen this battle.
	assert_str(_read(CTC_SRC)).override_failure_message(
		"nothing rolls the p.102 Lingering Injury check before a mission"
	).contains("_roll_lingering_injuries(crew_data)")


# ── Core Rules p.40 knock-out, and the Injured torso threshold ────────────

func test_three_stun_markers_knock_a_figure_out() -> void:
	# Core Rules p.40, verbatim: "If a character ever has 3 or more Stun markers
	# at the same time, they are knocked out and removed from play."
	assert_bool(BattleCalc.is_knocked_out_by_stun(2)).is_false()
	assert_bool(BattleCalc.is_knocked_out_by_stun(3)).is_true()


func test_an_injured_torso_breaks_at_two_markers() -> void:
	# Compendium p.102: "The character is knocked out after TWO Stun markers,
	# instead of the customary three." The threshold was a hardcoded constant, so
	# this injury could not reach the resolver at all.
	assert_bool(BattleCalc.is_knocked_out_by_stun(2, 2)).override_failure_message(
		"an Injured torso must be knocked out on the second Stun marker"
	).is_true()
	assert_bool(BattleCalc.is_knocked_out_by_stun(1, 2)).is_false()


func test_the_battle_screen_derives_the_threshold_from_the_injury() -> void:
	# The played path reads the threshold off the crew member's injuries, on
	# either shape.
	var TacticalUI = load("res://src/ui/screens/battle/TacticalBattleUI.gd")
	var unit_class = TacticalUI.TacticalUnit
	var healthy: Dictionary = _member("c1", "Healthy")
	var torso: Dictionary = _member("c2", "Cracked")
	torso["injuries"] = [
		{"type": "injured_torso", "recovery_turns": 0, "persistent": true,
			"treatment_cost": 3},
	]
	assert_int(unit_class._stun_threshold_for(healthy)).is_equal(3)
	assert_int(unit_class._stun_threshold_for(torso)).override_failure_message(
		"the battle screen ignored the Injured torso, so the figure would take"
		+ " three markers like anyone else"
	).is_equal(2)


func test_a_knock_out_is_not_a_casualty() -> void:
	# Core Rules p.121: "If a character was merely knocked out (from suffering 3
	# Stun results simultaneously), NO ROLL IS REQUIRED" on the Injury Table, and
	# p.114 counts only figures "removed due to combat" for Morale. Routing a
	# knock-out through the casualty path would invent both a post-battle injury
	# roll and an enemy Morale die.
	var src: String = _read("res://src/ui/screens/battle/TacticalBattleUI.gd")
	assert_str(src).contains("func _mark_knocked_out(")
	var start: int = src.find("func _mark_knocked_out(")
	# Bound the window at the NEXT function, or the scan runs into the neighbour
	# and reports its calls as this one's.
	var after: int = src.find("
func ", start + 10)
	var whole: String = src.substr(start, (after - start) if after > start else 1400)
	# CODE ONLY. The first version of this case scanned the docblock too, which
	# says "does not call `_mark_casualty()`" — so the test failed on the very
	# comment explaining why it must not. A source scan has to strip comments or
	# it reads intent as implementation.
	var body: String = ""
	for raw_line in whole.split("
"):
		var trimmed: String = raw_line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		body += raw_line + "
"
	assert_bool(body.contains("_mark_casualty")).override_failure_message(
		"_mark_knocked_out() routes through _mark_casualty(), which would feed"
		+ " enemy Morale and add a post-battle injury roll the book denies"
	).is_false()
	assert_bool(body.contains("is_dead = true")).override_failure_message(
		"a knocked-out figure must not be marked dead"
	).is_false()


# ── Critical Hit, Compendium p.100 ────────────────────────────────────────
#
# THE GAP THIS PINS. p.100's "additional optional rule" — "If the Hit roll was a
# natural 6, roll one additional time on the Casualty table and use the highest
# result as normal" — was not implemented at all, and the natural 6 that felled a
# figure is known ONLY inside BattleResolver. So the producer half is a stamp on
# the unit dict (`casualty_hit_critical`) and the consumer half is the casualty
# roll in TacticalBattleUI; either alone does nothing.

const BATTLE_UI_SRC := "res://src/ui/screens/battle/TacticalBattleUI.gd"


func test_a_critical_hit_rolls_twice_and_keeps_the_higher() -> void:
	# "use the highest result as normal" is the whole rule, and the kept row must
	# BE the higher of the two rolls, not merely a second roll that replaces the
	# first, which is what a careless implementation produces.
	if not _enable():
		return
	var saw_two := false
	for _i in range(60):
		var row: Dictionary = Toggles.roll_casualty_with_critical(
			"humanoid", false, true, true)
		if row.is_empty():
			continue
		assert_bool(bool(row.get("critical_hit", false))).override_failure_message(
			"a critical casualty roll must be marked as one").is_true()
		var rolls: Array = row.get("critical_rolls", [])
		assert_int(rolls.size()).override_failure_message(
			"p.100 rolls ONE ADDITIONAL time, so there must be exactly two rolls"
		).is_equal(2)
		var highest: int = maxi(int(rolls[0]), int(rolls[1]))
		assert_int(int(row.get("roll", 0))).override_failure_message(
			"kept roll %s is not the highest of %s" % [str(row.get("roll")), str(rolls)]
		).is_equal(highest)
		if int(rolls[0]) != int(rolls[1]):
			saw_two = true
	assert_bool(saw_two).override_failure_message(
		"60 critical rolls never produced two different dice, so the second roll"
		+ " is probably not being made"
	).is_true()


func test_a_critical_skews_the_outcome_toward_the_worse_row() -> void:
	# The observable consequence of "keep the highest", and the one a player
	# feels: over many rolls a critical must produce more severe rows than an
	# ordinary hit. A second roll that REPLACED the first would pass the
	# structural check above and fail this one.
	if not _enable():
		return
	var plain := 0
	var crit := 0
	for _i in range(600):
		var a: Dictionary = Toggles.roll_casualty_with_critical(
			"humanoid", false, false, true)
		var b: Dictionary = Toggles.roll_casualty_with_critical(
			"humanoid", false, true, true)
		plain += int(a.get("roll", 0))
		crit += int(b.get("roll", 0))
	# The margin matters. Keeping the highest of two d6 has mean 4.47 against
	# 3.5, so 600 rolls separate by roughly 580 — while an implementation that
	# merely REPLACED the first roll would land within about 60 of zero and
	# clear a bare "is_greater" half the time by luck. 200 sits far outside that
	# noise and far inside the real signal, so this fails on a replace.
	assert_int(crit - plain).override_failure_message(
		"600 critical rolls summed %d against %d for ordinary ones, a margin of"
		% [crit, plain] + " %d. Keeping the highest of two dice must separate" % (crit - plain)
		+ " them by hundreds; this looks like a second roll REPLACING the first."
	).is_greater(200)


func test_a_non_critical_hit_rolls_once() -> void:
	if not _enable():
		return
	var row: Dictionary = Toggles.roll_casualty_with_critical(
		"humanoid", false, false, true)
	if row.is_empty():
		return
	assert_bool(row.has("critical_hit")).override_failure_message(
		"an ordinary casualty must not be marked critical"
	).is_false()


func test_the_critical_rule_is_off_unless_the_player_opts_in() -> void:
	# p.100 presents it as an "additional optional rule" ON TOP of the Casualty
	# Tables, so it needs its own switch. Turning on Casualty Tables must not
	# silently double every roll.
	if not _enable():
		return
	for _i in range(10):
		var row: Dictionary = Toggles.roll_casualty_with_critical(
			"humanoid", false, true, false)
		if row.is_empty():
			continue
		assert_bool(row.has("critical_hit")).override_failure_message(
			"the Critical Hit rule fired with its setting OFF"
		).is_false()


func test_the_screen_reads_the_setting_and_the_resolver_stamps_the_six() -> void:
	# Both halves outside the pure rule. The critical is known only at the
	# attack, and the setting is readable only from the tree, so the rule can be
	# perfect and still never fire if either end is missing.
	var resolver: String = _read("res://src/core/battle/BattleResolver.gd")
	assert_str(resolver).override_failure_message(
		"BattleResolver does not record whether the felling hit was a natural 6"
	).contains('target["casualty_hit_critical"]')
	assert_str(resolver).contains('attack_result.get("critical", false)')
	var ui: String = _read(BATTLE_UI_SRC)
	assert_str(ui).contains('get("casualty_hit_critical", false)')
	assert_str(ui).override_failure_message(
		"the battle screen must pass the player's setting into the rule"
	).contains("roll_casualty_with_critical(")
	assert_str(ui).contains("use_critical_hit()")
