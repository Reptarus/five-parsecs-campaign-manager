extends GdUnitTestSuite
## Compendium p.102 injuries end the way the book ends them, on records the real
## producer writes.
##
## GameStateManager.pay_medical_treatment() charged and cleared a treatable injury
## and nothing outside its tests called it, so no screen could pay: Injured arm /
## leg / torso ("It takes 3 Credits of medical treatment to remove this penalty")
## were permanent. An Extensive injury was worse. Its record stored the deferred
## Sick Bay time as recovery_turns, so Sick Bay started at once and the turn-rollover
## countdown deleted the record at 0, and the record chokepoint dropped
## treatment_pending, so even a payment would not have cleared the two bench
## effects. The character never fought again.
##
## The existing Extensive case (test_persistent_injuries.gd) hand-builds the record
## with treatment_pending set, a shape production could not write, which is why it
## stayed green. Every record here comes from InjuryProcessor through
## PostBattleContext.apply_crew_injury().
##
## Flags are flipped in memory only (set_dlc_owned() persists). Forced dice are
## cleared after each case.

const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryProcessorClass = preload(
	"res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")
const PhaseManagerClass = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const LingeringRef = preload("res://src/core/campaign/LingeringInjuryCheck.gd")
const UpkeepScript = preload("res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
const UPKEEP_SCENE := "res://src/ui/screens/world/components/UpkeepPhaseComponent.tscn"
const QuickRollScript = preload("res://src/ui/components/battle/CharacterQuickRollPanel.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

const UNTREATED_SOURCE := "Detailed Injury: Extensive injury"

var _owned: Dictionary = {}
var _flags: Dictionary = {}
var _snap: Dictionary = {}
var _prev_campaign = null


func before_test() -> void:
	var dlc := get_node("/root/DLCManager")
	_owned = dlc._owned_dlcs.duplicate()
	_flags = dlc._enabled_flags.duplicate()
	_snap = SaveDirGuard.snapshot()
	_prev_campaign = get_node("/root/GameState").current_campaign


func after_test() -> void:
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs = _owned
	dlc._enabled_flags = _flags
	get_node("/root/DiceManager").clear_forced_results()
	get_node("/root/GameState").current_campaign = _prev_campaign
	SaveDirGuard.restore(_snap)


func _detailed(on: bool) -> void:
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs["freelancers_handbook"] = true
	dlc._enabled_flags[dlc.ContentFlag.DETAILED_INJURIES] = on


func _force(key: String, value: int) -> void:
	assert_bool(get_node("/root/DiceManager").queue_forced_result(key, value)).is_true()


## A die that bypasses DiceManager leaves its queued value behind, whatever face
## the random roll shows, so this is deterministic where a row check is not.
func _consumed(key: String) -> void:
	assert_dict(get_node("/root/DiceManager").get_forced_results()).override_failure_message(
		"the forced '%s' value was never consumed: that roll bypasses DiceManager" % key
	).is_empty()


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
	c.from_dictionary({"campaign_id": "treat", "crew": {"members": members}})
	var ctx = PostBattleContextClass.new()
	ctx.campaign = c
	ctx.battle_result = {"turn": 3}
	return ctx


func _row(row_id: String) -> Dictionary:
	for entry in Toggles.DETAILED_INJURY_TABLE:
		if entry is Dictionary and str(entry.get("id", "")) == row_id:
			return entry
	return {}


## One p.102 row through the real processor; returns the context.
func _injure(row_id: String, member: Dictionary) -> Variant:
	var ctx = _ctx([member])
	var proc = InjuryProcessorClass.new()
	proc._process_detailed_injury(ctx, _row(row_id), str(member["character_id"]))
	return ctx


func _upkeep() -> Node:
	var comp: Node = auto_free((load(UPKEEP_SCENE) as PackedScene).instantiate())
	add_child(comp)
	return comp


func _button(root: Node, text: String) -> Button:
	for child in root.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child
	return null


func test_upkeep_charges_and_ends_an_injured_arm() -> void:
	var ctx = _injure("injured_arm", _member("c1", "Ana"))
	var campaign = ctx.campaign
	campaign.credits = 5
	get_node("/root/GameState").current_campaign = campaign
	var comp := _upkeep()
	var box: VBoxContainer = auto_free(VBoxContainer.new())
	comp._build_injury_treatment_entry(box)
	var btn := _button(box, "Treat (3 cr)")
	assert_object(btn).override_failure_message(
		"p.102 'It takes 3 Credits of medical treatment' - the step offers no button"
	).is_not_null()
	btn.pressed.emit()
	var after: Dictionary = campaign.crew_data["members"][0]
	assert_array(after.get("injuries", [])).is_empty()
	assert_int(int(campaign.credits)).is_equal(2)


func test_the_upkeep_step_itself_builds_the_treatment_row() -> void:
	# The helper alone is not the fix: the step has to call it. Build the real
	# component with an injured crew loaded and look for the button in its tree.
	var ctx = _injure("injured_torso", _member("c1", "Ana"))
	ctx.campaign.credits = 5
	get_node("/root/GameState").current_campaign = ctx.campaign
	var comp := _upkeep()
	for _i in range(4):
		await get_tree().process_frame
	assert_object(_button(comp, "Treat (3 cr)")).override_failure_message(
		"the Upkeep step never builds the p.102 treatment row").is_not_null()


func test_treatment_is_offered_but_disabled_when_unaffordable() -> void:
	var ctx = _injure("injured_leg", _member("c1", "Ana"))
	ctx.campaign.credits = 2
	get_node("/root/GameState").current_campaign = ctx.campaign
	var comp := _upkeep()
	var box: VBoxContainer = auto_free(VBoxContainer.new())
	comp._build_injury_treatment_entry(box)
	var btn := _button(box, "Treat (3 cr)")
	assert_object(btn).is_not_null()
	assert_bool(btn.disabled).is_true()


func test_an_unpaid_extensive_injury_keeps_its_record_and_its_bench() -> void:
	# p.102: "The Sick Bay recovery time begins once they have received treatment."
	var ctx = _injure("extensive_injury", _member("c1", "Kaya"))
	var campaign = ctx.campaign
	var member: Dictionary = campaign.crew_data["members"][0]
	assert_bool(bool(member.get("in_sick_bay", false))).override_failure_message(
		"Sick Bay started before treatment was paid").is_false()
	var pm = auto_free(PhaseManagerClass.new())
	add_child(pm)
	for _i in range(10):
		pm._process_sick_bay_recovery(campaign)
	var after: Dictionary = campaign.crew_data["members"][0]
	var rows: Array = UpkeepScript.treatable_injuries(campaign.crew_data["members"])
	assert_int(rows.size()).override_failure_message(
		"the countdown deleted the unpaid Extensive injury, leaving its bench"
		+ " effects with nothing to pay for").is_equal(1)
	var sources: Array = []
	for eff in after.get("status_effects", []):
		sources.append(str(eff.get("source_event", "")))
	assert_array(sources).contains([UNTREATED_SOURCE])


func test_paying_a_produced_extensive_injury_frees_the_crew() -> void:
	_force("Extensive Injury Cost", 4)
	var ctx = _injure("extensive_injury", _member("c1", "Kaya"))
	var campaign = ctx.campaign
	campaign.credits = 9
	get_node("/root/GameState").current_campaign = campaign
	var res: Dictionary = get_node("/root/GameStateManager").pay_medical_treatment("c1", 0)
	assert_bool(bool(res.get("ok", false))).is_true()
	assert_int(int(res.get("recovery_turns", 0))).override_failure_message(
		"Sick Bay must begin at payment for the deferred 1D6+1 turns").is_equal(5)
	var after: Dictionary = campaign.crew_data["members"][0]
	for eff in after.get("status_effects", []):
		assert_str(str(eff.get("source_event", ""))).override_failure_message(
			"a PAID Extensive injury left its bench effect in place").is_not_equal(
				UNTREATED_SOURCE)
	assert_bool(bool(after.get("in_sick_bay", false))).is_true()


func test_the_resource_countdown_keeps_an_unpaid_extensive_injury() -> void:
	var ctx = _injure("extensive_injury", _member("c1", "Kaya"))
	var record: Dictionary = (ctx.campaign.crew_data["members"][0]["injuries"][0]
		as Dictionary).duplicate(true)
	var c: Character = Character.new()
	c.injuries.append(record)
	for _i in range(10):
		c.process_recovery_turn()
	assert_int(c.injuries.size()).is_equal(1)


func test_treatable_injuries_reads_both_crew_shapes() -> void:
	var arm: Dictionary = _injure("injured_arm", _member("c1", "Ana")).campaign.crew_data[
		"members"][0]
	var lingering: Dictionary = _injure("lingering_injury", _member("c2", "Bo")).campaign.crew_data[
		"members"][0]
	var res: Character = Character.new()
	res.character_id = "c3"
	res.character_name = "Cy"
	res.injuries.append({"type": "INJURED_TORSO", "treatment_cost": 3,
		"table_name": "Injured torso", "persistent": true})
	var rows: Array = UpkeepScript.treatable_injuries([arm, lingering, res])
	var names: Array = []
	for r: Dictionary in rows:
		names.append(str(r["name"]))
	# A Lingering injury ends on a natural 6, not by payment.
	assert_array(names).contains_exactly(["Ana", "Cy"])


func test_the_arm_penalty_stops_at_minus_one() -> void:
	# p.102: "Count the character's Combat Skill as 1 point lower (to a minimum of -1)".
	var panel = auto_free(QuickRollScript.new())
	panel._selected_character = {"injuries": [{"type": "INJURED_ARM"}]}
	assert_int(panel._injured_arm_penalty(false, 0)).is_equal(-1)
	assert_int(panel._injured_arm_penalty(false, 2)).is_equal(-1)
	assert_int(panel._injured_arm_penalty(false, -1)).is_equal(0)
	assert_int(panel._injured_arm_penalty(true, 2)).is_equal(0)


func test_the_injury_dice_can_be_forced() -> void:
	# Core Rules p.122 Injury Table: 1-5 Gruesome fate.
	_detailed(false)
	_force("Post-Battle Injury", 1)
	var ctx = _ctx([_member("c1", "Ana")])
	var proc = InjuryProcessorClass.new()
	var core: Dictionary = proc.process_single_injury(ctx, {"crew_id": "c1"})
	assert_bool(bool(core.get("is_fatal", false))).override_failure_message(
		"a forced 1 did not reach the Core Rules injury roll").is_true()
	_consumed("Post-Battle Injury")

	# Core Rules p.122 Bot Injury Table: 1-5 Obliterated.
	_force("Bot Injury", 1)
	var bot_ctx = _ctx([_member("b1", "Unit", {"is_bot": true})])
	var bot: Dictionary = InjuryProcessorClass.new().process_single_injury(
		bot_ctx, {"crew_id": "b1"})
	assert_bool(bool(bot.get("is_fatal", false))).override_failure_message(
		"a forced 1 did not reach the Bot Injury roll").is_true()
	_consumed("Bot Injury")

	# Compendium p.102: 41-50 Injured arm.
	_detailed(true)
	_force("Detailed Injury Table", 41)
	assert_str(str(Toggles.roll_detailed_injury().get("id", ""))).is_equal("injured_arm")
	_consumed("Detailed Injury Table")

	# Extensive injury 1D6+1.
	_force("Extensive Injury Cost", 6)
	var ext = _injure("extensive_injury", _member("c2", "Kaya"))
	var rec: Dictionary = ext.campaign.crew_data["members"][0]["injuries"][0]
	assert_int(int(rec.get("treatment_cost", 0))).is_equal(7)
	_consumed("Extensive Injury Cost")

	# Item hit: 5-6 destroyed.
	_force("Injury Item Hit", 5)
	var hit_proc = InjuryProcessorClass.new()
	var hit_ctx = _ctx([_member("c3", "Ivo", {"equipment": ["Hand Laser"]})])
	var hit: Dictionary = hit_proc._process_detailed_injury(hit_ctx, _row("item_hit"), "c3")
	assert_str(str(hit.get("destroyed_item", ""))).is_not_empty()
	_consumed("Injury Item Hit")

	# Lingering injury: a 1 sits this battle out.
	_force("Lingering Injury", 1)
	var lingering: Dictionary = _member("c4", "Lo")
	lingering["injuries"] = [{"type": "LINGERING_INJURY", "lingering": true,
		"persistent": true, "recovery_turns": 0}]
	var res: Dictionary = LingeringRef.roll_for(lingering)
	assert_bool(bool(res.get("benched", false))).is_true()
	_consumed("Lingering Injury")
