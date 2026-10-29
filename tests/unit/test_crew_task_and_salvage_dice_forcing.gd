extends GdUnitTestSuite
## World Phase crew-task dice and Compendium Salvage Job dice can be forced.
##
## Find a Patron / Recruit / Track / Repair (Core Rules pp.77-78), the loot
## subtables (pp.131, 134), the Military Weapon Table (p.28) and every Salvage
## Job table (Compendium pp.137-146) rolled with a raw randi(), so
## DiceManager.queue_forced_result() could not reach them, and the "Force the next
## roll" rows in QAScenarioDialog would have queued values nothing consumed.
## Each case forces two values that land in DIFFERENT rows, so an unrouted random
## roll passes only by matching both by chance.

const CrewTaskScene = preload("res://src/ui/screens/world/components/CrewTaskComponent.tscn")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SalvageJobs = preload("res://src/data/compendium_salvage_jobs.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _dm: Node
var _snap: Dictionary = {}
var _prev_campaign = null
var _dlc_owned: Dictionary = {}
var _dlc_flags: Dictionary = {}


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_dm = get_node("/root/DiceManager")
	_dm.clear_forced_results()
	_prev_campaign = get_node("/root/GameState").current_campaign
	var dlc := get_node("/root/DLCManager")
	_dlc_owned = dlc._owned_dlcs.duplicate()
	_dlc_flags = dlc._enabled_flags.duplicate()


func after_test() -> void:
	_dm.clear_forced_results()
	get_node("/root/GameState").current_campaign = _prev_campaign
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs = _dlc_owned
	dlc._enabled_flags = _dlc_flags
	SaveDirGuard.restore(_snap)


func _force(key: String, value: int) -> void:
	_dm.queue_forced_result(key, value)


## A full crew: below 6, Recruit is automatic (Core Rules p.78) and nothing rolls.
func _crew_task() -> Node:
	var crew: Array = []
	for i in 6:
		crew.append({"character_name": "Crew %d" % i, "species_id": "human",
			"character_class": "soldier", "savvy": 0})
	var c = CampaignCore.new()
	c.crew_data = {"members": crew}
	get_node("/root/GameState").current_campaign = c
	var tasks: Node = auto_free(CrewTaskScene.instantiate())
	add_child(tasks)
	return tasks


func _task(tasks: Node, task_id: String) -> Dictionary:
	for t: Dictionary in tasks.available_crew_tasks:
		if t["id"] == task_id:
			return t
	return {}


func _result() -> Dictionary:
	return {"details": "", "roll": 0, "modified_roll": 0, "success": false, "reward": ""}


func _member() -> Dictionary:
	return {"character_name": "Ana", "species_id": "human", "character_class": "soldier",
		"savvy": 0}


func test_the_three_dice_tasks_can_be_forced() -> void:
	var tasks := _crew_task()
	for task_id: String in ["find_patron", "recruit", "track"]:
		var task := _task(tasks, task_id)
		# Premise: the real task dict, so its name builds the real roll context.
		assert_bool(task.is_empty()).is_false()
		var key: String = "Crew Task: %s" % str(task["name"])
		for value: int in [1, 6]:
			_force(key, value)
			var r: Dictionary = tasks._resolve_dice_task(_result(), task, task_id, _member())
			assert_int(int(r["roll"])).override_failure_message(
				"%s forced %d" % [key, value]).is_equal(value)


func test_repair_can_be_forced() -> void:
	var tasks := _crew_task()
	var task := _task(tasks, "repair_kit")
	assert_bool(task.is_empty()).is_false()
	for value: int in [1, 6]:
		_force("Crew Task: Repair", value)
		var r: Dictionary = tasks._resolve_repair_task(_result(), task, _member())
		assert_int(int(r["roll"])).is_equal(value)


func test_the_loot_rewards_subtable_can_be_forced() -> void:
	var tasks := _crew_task()
	var sub: Array = [{"roll_range": [1, 50], "id": "low"}, {"roll_range": [51, 100], "id": "high"}]
	_force("Loot Rewards Subtable", 10)
	assert_str(str(tasks._roll_on_reward_subtable(sub).get("id"))).is_equal("low")
	_force("Loot Rewards Subtable", 90)
	assert_str(str(tasks._roll_on_reward_subtable(sub).get("id"))).is_equal("high")


func test_the_military_weapon_table_can_be_forced() -> void:
	# p.28. The expected rows come from the same table, so this pins the ROUTING.
	var tasks := _crew_task()
	var table: Array = tasks._get_military_weapon_table()
	assert_int(table.size()).is_greater(1)
	var first: String = str(table[0].get("name", ""))
	var last: String = str(table[table.size() - 1].get("name", ""))
	assert_str(first).is_not_equal(last)
	_force("Military Weapon Table", 1)
	assert_str(tasks._roll_on_military_weapons_table()).is_equal(first)
	_force("Military Weapon Table", 100)
	assert_str(tasks._roll_on_military_weapons_table()).is_equal(last)


func test_the_salvage_tables_can_be_forced() -> void:
	# Compendium p.140: Contact 1 nothing, 6 movement everywhere.
	_force("Salvage Contact", 1)
	assert_str(str(SalvageJobs.roll_contact_result().get("id"))).is_equal("nothing")
	_force("Salvage Contact", 6)
	assert_str(str(SalvageJobs.roll_contact_result().get("id"))).is_equal("movement_everywhere")
	# pp.140-141: Hostiles 01-25 Free-for-all, 66-00 Infestation.
	_force("Salvage Hostiles", 10)
	assert_str(str(SalvageJobs.roll_hostiles_type().get("id"))).is_equal("free_for_all")
	_force("Salvage Hostiles", 70)
	assert_str(str(SalvageJobs.roll_hostiles_type().get("id"))).is_equal("infestation")
	# pp.142-145: Point of Interest 01-05 Obstacle, 100 Doomsday protocol.
	_force("Salvage Point of Interest", 3)
	assert_str(str(SalvageJobs.roll_poi_reveal().get("id"))).is_equal("obstacle")
	_force("Salvage Point of Interest", 100)
	assert_str(str(SalvageJobs.roll_poi_reveal().get("id"))).is_equal("doomsday_protocol")
	# These two split a D6 roughly in half, so a single forced pair would pass an
	# unrouted random die about one time in four. Six pairs make that ~1 in 4,000.
	for _i in 6:
		# p.139 Tension: above the score raises it, at or under spawns a Contact.
		_force("Salvage Tension", 6)
		assert_bool(bool(SalvageJobs.roll_tension(3).get("contact_spawned"))).is_false()
		_force("Salvage Tension", 1)
		assert_bool(bool(SalvageJobs.roll_tension(3).get("contact_spawned"))).is_true()
		# p.138: after an illegal job, 5-6 the authorities are on your trail.
		_force("Salvage Authorities", 2)
		assert_bool(bool(SalvageJobGenerator.roll_authorities_check(1).get("caught"))).is_false()
		_force("Salvage Authorities", 6)
		assert_bool(bool(SalvageJobGenerator.roll_authorities_check(1).get("caught"))).is_true()


func test_the_salvage_job_generator_wrappers_never_re_roll() -> void:
	# The four wrappers used to carry a raw re-roll "fallback" for an empty result.
	# It never ran (each roller returns a row), and if it ever did it would replace a
	# forced die. The wrapper must hand back exactly what the forced roller rolled.
	_force("Salvage Hostiles", 70)
	assert_str(str(SalvageJobGenerator.roll_hostile_type().get("id"))).is_equal("infestation")
	_force("Salvage Point of Interest", 100)
	assert_str(str(SalvageJobGenerator.roll_point_of_interest().get("id"))).is_equal("doomsday_protocol")
	_force("Salvage Contact", 6)
	assert_str(str(SalvageJobGenerator.resolve_contact().get("id"))).is_equal("movement_everywhere")
	# And no raw random call survives in the generator's CODE (comments excluded).
	var src := FileAccess.get_file_as_string("res://src/core/mission/SalvageJobGenerator.gd")
	assert_int(src.length()).is_greater(500)
	var raw_calls: Array[String] = []
	for line: String in src.split("
"):
		var code := line.split("#")[0]
		for token: String in ["randi(", "randi_range(", "randf(", "randf_range("]:
			if token in code:
				raw_calls.append(line.strip_edges())
	assert_array(raw_calls).is_empty()


func test_salvage_availability_can_be_forced() -> void:
	# p.137: 1 no job, 6 illegal job. The table is behind the Salvage Jobs flag,
	# set in memory only (set_dlc_owned() would write user://dlc_ownership.cfg).
	var dlc := get_node("/root/DLCManager")
	for id: Variant in dlc.DLC_IDS:
		dlc._owned_dlcs[id] = true
	dlc._enabled_flags[dlc.ContentFlag.SALVAGE_JOBS] = true
	_force("Salvage Availability", 1)
	assert_str(str(SalvageJobs.roll_salvage_availability().get("id"))).is_equal("no_job")
	_force("Salvage Availability", 6)
	assert_str(str(SalvageJobs.roll_salvage_availability().get("id"))).is_equal("illegal_job")
