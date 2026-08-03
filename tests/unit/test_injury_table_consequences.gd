extends GdUnitTestSuite
## Core Rules p.122 Injury Table — the consequences beyond Sick Bay turns.
##
## THE DEFECT THIS PINS. InjuryProcessor computed `equipment_lost` and
## `all_equipment` for every injury and stored them in the result dict, and no
## consumer anywhere in the repo ever acted on either. Three rows of the organic
## table (1-5 Gruesome fate, 16 Miraculous escape, 17-30 Equipment loss = 20 of
## 100 results) and two of the Bot table (1-5, 16-30 = another 20) left every
## item pristine.
##
## The knock-on was larger than the rows. p.122 opens with "If a result on these
## tables indicates damaged equipment, such equipment cannot be used until it has
## been Repaired (see p.78)", and Repair Your Kit is one of only six crew tasks —
## so with no producer the single most common source of damaged gear in the book
## never fired, and the repair task had nothing to repair in any campaign outside
## the rare Character-Event item damage.
##
## data/injury_results.json separately carried `surgery_cost_roll: "1d6"` and the
## whole `stat_reduction` block for roll 31-45 Crippling wound. Neither had an
## accessor, so the worst survivable result on the table was mechanically
## identical to the Serious injury one row below it.
##
## THE MARKER SHAPE IS THE CONTRACT, and there are two of them because the two
## containers are different shapes:
##   carried gear — a status_effects entry {type: "item_damaged", damaged_item:
##                  <name>} on the OWNER
##   stash items  — `damaged: true` on the item dict
## Both are read by CrewTaskComponent._first_damaged_target() (p.78 Repair Your
## Kit). Writing the wrong one produces gear that is unusable per p.122 and that
## no task can ever restore, so the shapes are asserted here directly.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryProcessorClass = preload(
	"res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")
const InjuryConstants = preload("res://src/core/systems/InjurySystemConstants.gd")


func _campaign(members: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "inj_t", "crew": {"members": members}})
	return c


func _ctx(members: Array) -> Variant:
	var ctx = PostBattleContextClass.new()
	ctx.campaign = _campaign(members)
	ctx.battle_result = {"turn": 3}
	return ctx


func _armed(id: String, gear: Array) -> Dictionary:
	return {
		"character_id": id, "character_name": "Kaya", "experience": 0,
		"speed": 5, "toughness": 3, "luck": 0,
		"equipment": gear, "status_effects": [],
	}


func _damage_markers(member: Variant) -> Array:
	var out: Array = []
	for eff in member.get("status_effects", []):
		if eff is Dictionary and str(eff.get("type", "")) == "item_damaged":
			out.append(eff)
	return out


# --- The marker shape Repair Your Kit reads -----------------------------------

func test_damage_writes_the_shape_the_repair_task_reads() -> void:
	# CrewTaskComponent._first_damaged_target() scans status_effects for
	# type == "item_damaged" and pulls damaged_item. Any other shape is unfixable
	# gear: the item stops working (p.122) and no task can ever restore it.
	var ctx = _ctx([_armed("c1", ["Colony Rifle"])])
	var hit: String = ctx.damage_random_equipment_for("c1", "unit test")

	assert_str(hit).is_equal("Colony Rifle")
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	var markers: Array = _damage_markers(member)
	assert_int(markers.size()).override_failure_message(
		"no item_damaged marker was written — Repair Your Kit (p.78) can never "
		+ "find this item. status_effects: %s" % str(member.get("status_effects", []))
	).is_equal(1)
	assert_str(str(markers[0].get("damaged_item", ""))).is_equal("Colony Rifle")


func test_the_same_item_is_not_damaged_twice() -> void:
	# A second Equipment Loss result must cost a DIFFERENT item, or the row is
	# free whenever the crew member already has one broken thing.
	var ctx = _ctx([_armed("c1", ["Colony Rifle"])])
	assert_str(ctx.damage_random_equipment_for("c1", "first")).is_equal("Colony Rifle")
	assert_str(ctx.damage_random_equipment_for("c1", "second")).override_failure_message(
		"the already-damaged rifle was 'damaged' again, so the second result cost nothing"
	).is_empty()

	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int(_damage_markers(member).size()).is_equal(1)


func test_a_second_result_reaches_the_undamaged_item() -> void:
	var ctx = _ctx([_armed("c1", ["Colony Rifle", "Frag Vest"])])
	var first: String = ctx.damage_random_equipment_for("c1", "first")
	var second: String = ctx.damage_random_equipment_for("c1", "second")
	assert_str(second).is_not_empty()
	assert_str(second).is_not_equal(first)


# --- 1-5 Gruesome fate: ALL equipment DAMAGED (not lost) ----------------------

func test_gruesome_fate_damages_every_item_and_keeps_them() -> void:
	# p.122: "Dead, and all carried equipment is damaged." Damaged, therefore
	# still present and repairable — it does not leave the game.
	var ctx = _ctx([_armed("c1", ["Colony Rifle", "Frag Vest", "Blade"])])
	var damaged: Array = ctx.damage_all_equipment_for("c1", "unit test")

	assert_int(damaged.size()).is_equal(3)
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int(_damage_markers(member).size()).is_equal(3)
	assert_int((member.get("equipment", []) as Array).size()).override_failure_message(
		"Gruesome fate DESTROYED the equipment; p.122 says it is damaged, not lost"
	).is_equal(3)


# --- 16 Miraculous escape: ALL items PERMANENTLY LOST -------------------------

func test_miraculous_escape_removes_the_items_entirely() -> void:
	# p.122 roll 16: "...but all items carried are permanently lost." This is a
	# DIFFERENT outcome from Gruesome fate, and the two shared a flag before the
	# fix, so roll 16 was being treated as ordinary repairable damage.
	var ctx = _ctx([_armed("c1", ["Colony Rifle", "Frag Vest"])])
	var lost: Array = ctx.lose_all_equipment_for("c1")

	assert_int(lost.size()).is_equal(2)
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int((member.get("equipment", []) as Array).size()).override_failure_message(
		"items were meant to be permanently lost and are still on the sheet"
	).is_equal(0)
	assert_int(_damage_markers(member).size()).override_failure_message(
		"lost items left a repair marker behind — Repair Your Kit would offer to "
		+ "fix an item that no longer exists"
	).is_equal(0)


func test_losing_everything_clears_a_pre_existing_damage_marker() -> void:
	var ctx = _ctx([_armed("c1", ["Colony Rifle", "Frag Vest"])])
	ctx.damage_random_equipment_for("c1", "earlier injury")
	ctx.lose_all_equipment_for("c1")
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int(_damage_markers(member).size()).is_equal(0)


# --- The table rows carry the right flags -------------------------------------

func test_the_two_all_equipment_rows_are_not_the_same_outcome() -> void:
	var IT = InjuryConstants.InjuryType
	assert_bool(InjuryConstants.causes_all_equipment_damage(IT.GRUESOME_FATE)) \
		.override_failure_message("p.122 1-5 damages all carried equipment").is_true()
	assert_bool(InjuryConstants.equipment_is_permanently_lost(IT.GRUESOME_FATE)) \
		.override_failure_message("1-5 is damage, NOT permanent loss").is_false()

	assert_bool(InjuryConstants.equipment_is_permanently_lost(IT.MIRACULOUS_ESCAPE)) \
		.override_failure_message("p.122 roll 16 loses all items permanently").is_true()
	assert_bool(InjuryConstants.causes_all_equipment_damage(IT.MIRACULOUS_ESCAPE)) \
		.override_failure_message(
			"roll 16 must not ALSO route through the damage branch, or the items "
			+ "get repair markers on their way out of the game"
		).is_false()

	assert_bool(InjuryConstants.causes_equipment_loss(IT.EQUIPMENT_LOSS)).is_true()
	assert_bool(InjuryConstants.causes_all_equipment_damage(IT.EQUIPMENT_LOSS)) \
		.override_failure_message("p.122 17-30 damages ONE random item").is_false()

	# Rows the book gives no equipment consequence.
	for benign in [IT.SERIOUS_INJURY, IT.MINOR_INJURY, IT.KNOCKED_OUT, IT.HARD_KNOCKS]:
		assert_bool(InjuryConstants.causes_equipment_loss(benign)).is_false()
		assert_bool(InjuryConstants.causes_all_equipment_damage(benign)).is_false()


func test_bot_table_rows_carry_the_right_flags() -> void:
	var BT = InjuryConstants.BotInjuryType
	assert_bool(InjuryConstants.bot_causes_all_equipment_damage(BT.OBLITERATED)) \
		.override_failure_message("Bot 1-5: 'Destroyed, and all carried equipment is damaged'") \
		.is_true()
	assert_bool(InjuryConstants.bot_causes_equipment_loss(BT.EQUIPMENT_LOSS)).is_true()
	assert_bool(InjuryConstants.bot_causes_all_equipment_damage(BT.EQUIPMENT_LOSS)).is_false()
	assert_bool(InjuryConstants.bot_causes_equipment_loss(BT.SEVERE_DAMAGE)).is_false()
	assert_bool(InjuryConstants.bot_causes_equipment_loss(BT.JUST_A_FEW_DENTS)).is_false()


# --- 31-45 Crippling wound ----------------------------------------------------

func test_crippling_wound_carries_a_stat_reduction_and_a_surgery_cost() -> void:
	var IT = InjuryConstants.InjuryType
	var spec: Dictionary = InjuryConstants.get_stat_reduction(IT.CRIPPLING_WOUND)
	assert_bool(spec.is_empty()).override_failure_message(
		"data/injury_results.json carries stat_reduction for 31-45 and nothing read it"
	).is_false()
	assert_array(spec.get("stats", [])).contains_exactly_in_any_order(["speed", "toughness"])
	# Godot's JSON parser returns every number as a FLOAT, so -1.0 != -1 unless
	# the accessor normalises. This assertion is the guard on that.
	assert_int(int(spec.get("amount", 0))).is_equal(-1)
	assert_str(str(spec.get("pick", ""))).is_equal("highest")

	for _i in range(20):
		var cost: int = InjuryConstants.roll_surgery_cost_for(IT.CRIPPLING_WOUND)
		assert_int(cost).is_between(1, 6)

	assert_int(InjuryConstants.roll_surgery_cost_for(IT.MINOR_INJURY)) \
		.override_failure_message("only 31-45 has a surgery clause").is_equal(0)


func test_the_reduction_hits_the_HIGHEST_of_speed_or_toughness() -> void:
	# p.122: "-1 permanent reduction to highest of Speed or Toughness."
	var ctx = _ctx([{
		"character_id": "c1", "character_name": "Kaya",
		"speed": 5, "toughness": 3, "equipment": [], "status_effects": [],
	}])
	var got: Dictionary = ctx.apply_permanent_stat_reduction("c1", ["speed", "toughness"], -1)

	assert_str(str(got.get("stat", ""))).override_failure_message(
		"reduced the wrong stat — Speed 5 is higher than Toughness 3"
	).is_equal("speed")
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int(int(member.get("speed", 0))).is_equal(4)
	assert_int(int(member.get("toughness", 0))).override_failure_message(
		"the lower stat must be untouched"
	).is_equal(3)


func test_the_reduction_picks_toughness_when_toughness_is_higher() -> void:
	var ctx = _ctx([{
		"character_id": "c1", "character_name": "Rho",
		"speed": 4, "toughness": 6, "equipment": [], "status_effects": [],
	}])
	var got: Dictionary = ctx.apply_permanent_stat_reduction("c1", ["speed", "toughness"], -1)
	assert_str(str(got.get("stat", ""))).is_equal("toughness")
	assert_int(int(ctx.campaign.get_crew_member_by_id("c1").get("toughness", 0))).is_equal(5)


func test_the_reduction_never_goes_below_zero() -> void:
	var ctx = _ctx([{
		"character_id": "c1", "character_name": "Zed",
		"speed": 0, "toughness": 0, "equipment": [], "status_effects": [],
	}])
	assert_bool(ctx.apply_permanent_stat_reduction("c1", ["speed", "toughness"], -1).is_empty()) \
		.override_failure_message("a 0 stat cannot be reduced; the offer must report nothing") \
		.is_true()
	assert_int(int(ctx.campaign.get_crew_member_by_id("c1").get("speed", 0))).is_equal(0)


# --- The live processor path reaches all of it --------------------------------

func test_the_live_injury_path_produces_damaged_gear() -> void:
	# process_single_injury() rolls its own D100, so this asserts the INVARIANT
	# (over many rolls the wiring fires) rather than a seeded value — a seed
	# fixes the RNG stream, not the roll, and any unrelated change that draws a
	# different number of dice would shift it.
	#
	# p(equipment consequence) = 20/100 per roll, so over 200 fresh characters a
	# zero result is ~4e-20 and means the wiring is dead, not unlucky.
	var proc = InjuryProcessorClass.new()
	var saw_damage: bool = false
	var saw_loss: bool = false

	for i in range(200):
		var ctx = _ctx([_armed("c%d" % i, ["Colony Rifle", "Frag Vest"])])
		var out: Dictionary = proc.process_single_injury(ctx, {"crew_id": "c%d" % i})
		if not (out.get("items_damaged", []) as Array).is_empty():
			saw_damage = true
			# The marker must be on the member, not just in the report dict.
			var m: Dictionary = ctx.campaign.get_crew_member_by_id("c%d" % i)
			assert_int(_damage_markers(m).size()).override_failure_message(
				"the injury REPORTED damaged items and wrote no marker, so the "
				+ "player is told about a break the repair task cannot see"
			).is_greater(0)
		if not (out.get("items_lost", []) as Array).is_empty():
			saw_loss = true

	assert_bool(saw_damage).override_failure_message(
		"200 injuries and not one damaged an item — p.122's equipment rows are dead"
	).is_true()
	assert_bool(saw_loss).override_failure_message(
		"200 injuries and roll 16 never took anyone's kit"
	).is_true()


func test_the_live_injury_path_applies_the_crippling_wound() -> void:
	# p(31-45) = 15/100; over 200 rolls a zero result is ~7.6e-15.
	var proc = InjuryProcessorClass.new()
	var saw_reduction: bool = false

	for i in range(200):
		var cid: String = "c%d" % i
		var ctx = _ctx([_armed(cid, [])])
		var out: Dictionary = proc.process_single_injury(ctx, {"crew_id": cid})
		if str(out.get("type", "")) != "CRIPPLING_WOUND":
			continue
		saw_reduction = true
		assert_str(str(out.get("stat_reduced", ""))).override_failure_message(
			"a Crippling wound landed and reduced nothing — the row is identical "
			+ "to a Serious injury, which is the bug. Result: %s" % str(out)
		).is_equal("speed")  # _armed() is speed 5 / toughness 3
		assert_int(int(ctx.campaign.get_crew_member_by_id(cid).get("speed", 0))) \
			.override_failure_message("the reduction never reached the sheet").is_equal(4)
		assert_int(int(out.get("surgery_cost", 0))).override_failure_message(
			"no surgery buy-out was offered, so the player never gets the choice "
			+ "p.122 gives them"
		).is_between(1, 6)
		assert_bool(out.get("surgery_offer_available", false)).is_true()

	assert_bool(saw_reduction).override_failure_message(
		"200 injuries and not one Crippling wound in 15% of the table"
	).is_true()


func test_every_injury_reports_the_crew_member_by_name() -> void:
	# The wizard prints injury.get("crew_name", "Unknown") and nothing wrote the
	# key, so every injury line in every campaign read "Unknown: <severity>".
	var proc = InjuryProcessorClass.new()
	var ctx = _ctx([_armed("c1", [])])
	var out: Dictionary = proc.process_single_injury(ctx, {"crew_id": "c1"})
	assert_str(str(out.get("crew_name", ""))).override_failure_message(
		"injury result carries no crew_name; the post-battle wizard falls back to "
		+ "'Unknown' for every line"
	).is_equal("Kaya")


# --- Campaign Event 45-48 targets the STASH, and Repair can reach it ----------

const CrewTasks = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")


func _campaign_with_stash(items: Array) -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({
		"campaign_id": "stash_t",
		"crew": {"members": [_armed("c1", [])]},
		"equipment": {"equipment": items},
	})
	return c


func test_equipment_malfunction_damages_a_stash_item_not_carried_gear() -> void:
	# p.127 45-48, verbatim: "If there are any items in your Stash, a random item
	# is damaged and must be Repaired." The Stash — the event's own result string
	# already said so while the code reached for crew `weapons`/`items`.
	var ctx = PostBattleContextClass.new()
	ctx.campaign = _campaign_with_stash([
		{"id": "i1", "name": "Colony Rifle"},
		{"id": "i2", "name": "Frag Vest"},
	])
	var hit: String = ctx.damage_random_equipment()
	assert_str(hit).is_not_empty()

	var stash: Array = ctx.get_stash_items()
	var damaged_count: int = 0
	for item in stash:
		if bool(item.get("damaged", false)):
			damaged_count += 1
	assert_int(damaged_count).override_failure_message(
		"Equipment Malfunction damaged no stash item. Stash: %s" % str(stash)
	).is_equal(1)

	# The carried-gear path must NOT be touched by this event.
	var member: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int(_damage_markers(member).size()).is_equal(0)


func test_equipment_malfunction_on_an_empty_stash_is_a_no_op() -> void:
	# "IF there are any items in your Stash" — no items, no effect, no crash.
	var ctx = PostBattleContextClass.new()
	ctx.campaign = _campaign_with_stash([])
	assert_str(ctx.damage_random_equipment()).is_empty()


func test_equipment_malfunction_never_re_damages_the_same_item() -> void:
	var ctx = PostBattleContextClass.new()
	ctx.campaign = _campaign_with_stash([{"id": "i1", "name": "Colony Rifle"}])
	assert_str(ctx.damage_random_equipment()).is_equal("Colony Rifle")
	assert_str(ctx.damage_random_equipment()).override_failure_message(
		"the only stash item was already damaged and was 'damaged' again"
	).is_empty()


func test_repair_your_kit_finds_a_damaged_stash_item() -> void:
	# p.78 draws no line between carried gear and the Stash: "If you have had
	# items destroyed, you can attempt to Repair them." Before this the task
	# scanned only the acting character's status_effects, so a stash item damaged
	# by p.127 was permanently unusable — Assign Equipment shows it "[DAMAGED]"
	# and Purchase Items refuses to sell it, with no way back.
	var stash: Array = [
		{"id": "i1", "name": "Colony Rifle"},
		{"id": "i2", "name": "Frag Vest", "damaged": true},
	]
	var found: Dictionary = CrewTasks._first_damaged_in_stash(stash)
	assert_str(str(found.get("name", ""))).is_equal("Frag Vest")
	assert_str(str(found.get("source", ""))).is_equal("stash")
	assert_int(int(found.get("index", -1))).is_equal(1)


func test_a_successful_stash_repair_clears_the_flag_and_keeps_the_item() -> void:
	var stash: Array = [{"id": "i2", "name": "Frag Vest", "damaged": true,
		"damage_source": "Campaign Event"}]
	CrewTasks._resolve_damaged_stash_item(
		stash, {"name": "Frag Vest", "source": "stash", "index": 0}, true)
	assert_int(stash.size()).is_equal(1)
	assert_bool(bool(stash[0].get("damaged", true))).is_false()
	assert_bool(stash[0].has("damage_source")).is_false()


func test_a_natural_one_removes_the_stash_item_entirely() -> void:
	# p.78: "A natural 1 always fails this roll. A failed roll means the item is
	# beyond fixing."
	var stash: Array = [
		{"id": "i1", "name": "Colony Rifle"},
		{"id": "i2", "name": "Frag Vest", "damaged": true},
	]
	CrewTasks._resolve_damaged_stash_item(
		stash, {"name": "Frag Vest", "source": "stash", "index": 1}, false)
	assert_int(stash.size()).is_equal(1)
	assert_str(str(stash[0].get("name", ""))).is_equal("Colony Rifle")


func test_a_stale_index_still_resolves_the_right_item() -> void:
	# The index is captured before the D6 is rolled. If anything mutated the
	# stash in between, trusting it would repair or DELETE an unrelated item.
	var stash: Array = [
		{"id": "i2", "name": "Frag Vest", "damaged": true},
		{"id": "i1", "name": "Colony Rifle"},
	]
	CrewTasks._resolve_damaged_stash_item(
		stash, {"name": "Frag Vest", "source": "stash", "index": 1}, false)
	assert_int(stash.size()).is_equal(1)
	assert_str(str(stash[0].get("name", ""))).override_failure_message(
		"a stale index deleted the wrong item"
	).is_equal("Colony Rifle")


# --- Sick Bay recovery reductions reach the countdown -------------------------
#
# The three reducers all wrote ONLY `injury_recovery_turns`, which the turn
# rollover does not read: it decrements `injuries[]` and ends the stay when that
# array is empty. So Friendly Doc (p.126), the p.84 Health Insurance benefit and
# the Character Event that gives a turn back all reported success and left the
# crew member in Sick Bay for the full original duration.

func _hurt(id: String, turns: int) -> Dictionary:
	return {
		"character_id": id, "character_name": "Kaya",
		"speed": 4, "toughness": 4, "equipment": [],
		"status_effects": [{"type": "injury", "duration": turns}],
		"injuries": [{"type": "MINOR_INJURY", "recovery_turns": turns}],
		"in_sick_bay": true, "recovery_turns": turns,
		"injury_recovery_turns": turns, "status": "injured",
	}


func test_friendly_doc_shortens_the_stay_the_countdown_actually_reads() -> void:
	# p.126 1-3: "Select up to two crew members in Sick Bay and reduce their
	# Recovery time by one campaign turn each."
	var ctx = _ctx([_hurt("c1", 3), _hurt("c2", 2), _hurt("c3", 4)])
	ctx.reduce_recovery_time(2)

	var m1: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	var injuries: Array = m1.get("injuries", [])
	assert_int(int(injuries[0].get("recovery_turns", 0))).override_failure_message(
		"the injuries[] entry is what the turn rollover decrements; leaving it "
		+ "untouched means the Sick Bay stay is unchanged"
	).is_equal(2)
	assert_int(int(m1.get("recovery_turns", 0))).is_equal(2)

	# "up to two" — the third is untouched.
	assert_int(int(ctx.campaign.get_crew_member_by_id("c3").get("recovery_turns", 0))) \
		.override_failure_message("Friendly Doc treated more than two crew").is_equal(4)


func test_recovering_fully_clears_the_sick_bay_gates() -> void:
	# p.126: "If they recover, they can act normally next campaign turn." The
	# gates are in_sick_bay and status, not the counter.
	var ctx = _ctx([_hurt("c1", 1)])
	ctx.reduce_recovery_time(1)

	var m: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int((m.get("injuries", []) as Array).size()).is_equal(0)
	assert_bool(bool(m.get("in_sick_bay", true))).override_failure_message(
		"still flagged in Sick Bay after recovering — CrewTaskComponent and "
		+ "UpkeepPhaseComponent both gate on this"
	).is_false()
	assert_str(str(m.get("status", ""))).is_equal("ACTIVE")
	assert_int(int(m.get("recovery_turns", -1))).is_equal(0)


func test_a_healthy_crew_member_is_not_counted_as_treated() -> void:
	var healthy: Dictionary = _armed("c1", [])
	var ctx = _ctx([healthy, _hurt("c2", 2)])
	ctx.reduce_recovery_time(1)
	# The one treatment must land on the crew member who needed it.
	assert_int(int(ctx.campaign.get_crew_member_by_id("c2").get("recovery_turns", 0))) \
		.override_failure_message("the treatment was spent on a healthy crew member") \
		.is_equal(1)


func test_the_longest_outstanding_injury_is_what_gates_the_stay() -> void:
	# The countdown decrements EVERY entry each turn, so time-to-clear is the max.
	var m: Dictionary = _hurt("c1", 2)
	m["injuries"].append({"type": "SERIOUS_INJURY", "recovery_turns": 4})
	var ctx = _ctx([m])
	assert_int(ctx.get_member_recovery_turns(
		ctx.campaign.get_crew_member_by_id("c1"))).is_equal(4)

	ctx.reduce_member_recovery(ctx.campaign.get_crew_member_by_id("c1"), 2)
	var after: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	assert_int((after.get("injuries", []) as Array).size()).override_failure_message(
		"the 2-turn injury should have cleared and the 4-turn one survived"
	).is_equal(1)
	assert_int(ctx.get_member_recovery_turns(after)).is_equal(2)
	assert_bool(bool(after.get("in_sick_bay", false))).override_failure_message(
		"released from Sick Bay while an injury is still outstanding"
	).is_true()


func test_heal_crew_in_sickbay_clears_one_member_completely() -> void:
	var ctx = _ctx([_hurt("c1", 3), _hurt("c2", 3)])
	ctx.heal_crew_in_sickbay()
	var m1: Dictionary = ctx.campaign.get_crew_member_by_id("c1")
	var m2: Dictionary = ctx.campaign.get_crew_member_by_id("c2")
	assert_int(ctx.get_member_recovery_turns(m1)).is_equal(0)
	assert_bool(bool(m1.get("in_sick_bay", true))).is_false()
	assert_int(ctx.get_member_recovery_turns(m2)).override_failure_message(
		"only ONE crew member is healed"
	).is_equal(3)
