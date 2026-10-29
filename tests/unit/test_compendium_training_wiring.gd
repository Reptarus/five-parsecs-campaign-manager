extends GdUnitTestSuite
## Compendium p.25 New Training and the Core Rules p.125 Broker, where they act.
##
## p.25: "Any of the following training courses may be taken using the rules in
## post-battle step 10. Invest in Advanced Training. They are acquired using the
## same rules as any other Advanced Training." They were sold in the Advancement
## phase for credits alone, with no application roll, and stored as traits nothing
## read. Now they are offered by the step-10 dialog, and two of them act:
## - Instructor: "you do not have to pay the 1 Credit application fee or roll for
##   availability";
## - Fixer: "When taking a Find a Patron, Recruit, or Track crew action, add +1".
## Broker (p.125): "When rolling to obtain licenses, Advanced Training applications,
## or searching for Patrons, add +1". The patron search was the unwired third.

const DialogScene = preload("res://src/ui/components/postbattle/TrainingSelectionDialog.tscn")
const CrewTaskScene = preload("res://src/ui/screens/world/components/CrewTaskComponent.tscn")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CompendiumEquipment = preload("res://src/data/compendium_equipment.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _snap: Dictionary = {}
var _prev_campaign = null
var _dlc_owned: Dictionary = {}
var _dlc_flags: Dictionary = {}


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_prev_campaign = get_node("/root/GameState").current_campaign
	var dlc := get_node("/root/DLCManager")
	_dlc_owned = dlc._owned_dlcs.duplicate()
	_dlc_flags = dlc._enabled_flags.duplicate()


func after_test() -> void:
	get_node("/root/GameState").current_campaign = _prev_campaign
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs = _dlc_owned
	dlc._enabled_flags = _dlc_flags
	get_node("/root/DiceManager").clear_forced_results()
	SaveDirGuard.restore(_snap)


## In memory only: set_dlc_owned() would write user://dlc_ownership.cfg.
func _new_training(on: bool) -> void:
	var dlc := get_node("/root/DLCManager")
	for id: Variant in dlc.DLC_IDS:
		dlc._owned_dlcs[id] = true
	dlc._enabled_flags[dlc.ContentFlag.NEW_TRAINING] = on


func _campaign(credits: int, crew: Array) -> void:
	var c = CampaignCore.new()
	c.credits = credits
	c.crew_data = {"members": crew}
	get_node("/root/GameState").current_campaign = c


func _member(name: String, training: Array = [], xp: int = 0) -> Dictionary:
	return {"character_name": name, "experience": xp, "acquired_training": training,
		"is_bot": false, "species_id": "human", "character_class": "soldier"}


func _dialog() -> Node:
	var d: Node = auto_free(DialogScene.instantiate())
	add_child(d)
	return d


func _crew_task() -> Node:
	var c: Node = auto_free(CrewTaskScene.instantiate())
	add_child(c)
	return c


func _result() -> Dictionary:
	return {"details": "", "roll": 0, "modified_roll": 0, "success": false, "reward": ""}


## The task as the component loads it from data/crew_tasks.json, the shape
## _resolve_single_task() hands over. A hand-built {"id": ...} lacks dice_target,
## and the resolver aborts on it.
func _task(tasks: Node, task_id: String) -> Dictionary:
	for t: Dictionary in tasks.available_crew_tasks:
		if t["id"] == task_id:
			return t
	return {}


# --- the step-10 dialog --------------------------------------------------------

func test_the_compendium_courses_are_offered_beside_the_core_ones() -> void:
	_new_training(true)
	var dlg := _dialog()
	var on: Dictionary = dlg._courses()
	assert_int(on.size()).is_equal(7 + CompendiumEquipment.get_advanced_training().size())
	assert_bool(on.has("instructor") and on.has("fixer") and on.has("pilot")).is_true()
	_new_training(false)
	assert_int(dlg._courses().size()).is_equal(7)


func test_an_instructor_waives_the_application_fee() -> void:
	_new_training(true)
	var dlg := _dialog()
	dlg.setup([_member("Ana")], 10)
	assert_int(dlg._enrollment_fee()).is_greater(0)
	dlg.setup([_member("Ana"), _member("Ivo", ["instructor"])], 10)
	assert_int(dlg._enrollment_fee()).is_equal(0)


func test_an_instructor_skips_the_approval_roll() -> void:
	# Two forced 1s total 2, which no Advanced Training application passes. With an
	# Instructor in the crew there is no roll to fail.
	_new_training(true)
	var applicant := _member("Ana", [], 30)
	var crew := [applicant, _member("Ivo", ["instructor"])]
	_campaign(20, crew)
	var dice := get_node("/root/DiceManager")
	dice.queue_forced_result("Training Approval", 1)
	dice.queue_forced_result("Training Approval", 1)
	var dlg := _dialog()
	dlg.setup(crew, 20)
	dlg.selected_character = dlg.available_crew[0]
	dlg.selected_training_type = "pilot"
	dlg._on_roll_pressed()
	assert_array(applicant["acquired_training"]).contains(["pilot"])


# --- the World Phase crew tasks ------------------------------------------------

func test_a_fixer_adds_one_to_patron_and_recruit_rolls() -> void:
	# A full crew: below 6, Recruit is automatic (Core Rules p.78) and nothing rolls.
	var crew: Array = []
	for i in 6:
		crew.append(_member("Crew %d" % i))
	_campaign(0, crew)
	var tasks := _crew_task()
	for task_id: String in ["find_patron", "recruit"]:
		assert_bool(_task(tasks, task_id).is_empty()).is_false()
		var with: Dictionary = tasks._resolve_dice_task(
			_result(), _task(tasks, task_id), task_id, _member("Ana", ["fixer"]))
		assert_str(str(with["details"])).contains("+1 Fixer")
		var without: Dictionary = tasks._resolve_dice_task(
			_result(), _task(tasks, task_id), task_id, _member("Ana"))
		assert_str(str(without["details"])).not_contains("+1 Fixer")


func test_a_broker_in_the_crew_adds_one_to_find_a_patron() -> void:
	_campaign(0, [_member("Ivo", ["broker"])])
	var tasks := _crew_task()
	var patron: Dictionary = tasks._resolve_dice_task(
		_result(), _task(tasks, "find_patron"), "find_patron", _member("Ana"))
	assert_str(str(patron["details"])).contains("+1 Broker")
	var recruit: Dictionary = tasks._resolve_dice_task(
		_result(), _task(tasks, "recruit"), "recruit", _member("Ana"))
	assert_str(str(recruit["details"])).not_contains("+1 Broker")
