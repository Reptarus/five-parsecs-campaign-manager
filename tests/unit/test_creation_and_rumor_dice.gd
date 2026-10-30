extends GdUnitTestSuite
## Sprint 7b 5P-2/5P-4: the creation, Rumor and post-battle credit dice go through DiceManager.
##
## Each of these rolled engine RNG, so the QA "Force the next roll" seam could not reach
## them: the p.31 Ship Table and its 1D6 debt, the p.32 Crew Table, the p.28 high-tech
## swap, the p.85 Rumors -> Quest check, the p.121 Debris 1D3 (in BOTH the backend and
## the post-battle screen) and the p.134 Loot credit dice. Each case forces the key a
## tester would pick and
## asserts the row the book table gives for that value.

const ShipPanelScene := preload("res://src/ui/screens/campaign/panels/ShipPanel.tscn")
const EquipmentPanelScene := preload("res://src/ui/screens/campaign/panels/EquipmentPanel.tscn")
const ResolveRumorsScene := preload(
	"res://src/ui/screens/world/components/ResolveRumorsComponent.tscn")
const CampaignCoreClass := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleScene := preload("res://src/ui/screens/postbattle/PostBattleSequence.tscn")
const PaymentProcessorClass := preload(
	"res://src/core/campaign/phases/post_battle/PaymentProcessor.gd")
const ContextClass := preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

var _dm: Node
var _prior_campaign: Resource = null


func before_test() -> void:
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	assert_object(_dm).override_failure_message("premise: DiceManager").is_not_null()
	_dm.clear_forced_results()
	_prior_campaign = GameState.current_campaign
	# A raw roll can land on the asserted row by chance (15% for Glare Sword, 33% for a
	# D3). A fixed seed makes a reverted route fail the same way on every run. Its first
	# draws are D3 = 2 and D6 = 5 (measured), so no case forces either value.
	seed(20261030)


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	GameState.current_campaign = _prior_campaign


## p.31: 96-100 is the Retired Military Patrol Ship, debt 1D6+35.
func test_the_ship_table_and_its_debt_can_be_forced() -> void:
	var panel: Control = auto_free(ShipPanelScene.instantiate())
	add_child(panel)
	await get_tree().process_frame
	_dm.queue_forced_result("Ship Table", 100)
	_dm.queue_forced_result("Ship Debt", 4)
	panel._generate_ship()
	assert_str(str(panel.ship_data.type)).is_equal("Retired Military Patrol Ship")
	assert_int(int(panel.ship_data.debt)).override_failure_message(
		"p.31: debt base 35 plus the forced 4").is_equal(39)


## p.32 Crew Table: 1-10 "Hired by a random member of the group".
func test_the_crew_table_can_be_forced() -> void:
	var panel: Control = auto_free(ShipPanelScene.instantiate())
	add_child(panel)
	await get_tree().process_frame
	_dm.queue_forced_result("Crew Flavor", 1)
	panel._on_reroll_met_pressed()
	assert_str(str(panel.flavor_data.we_met_through)).is_equal(
		"Hired by a random member of the group")


## p.28: a Savvy swap rolls the High-tech Weapon table; 86-100 is the Glare Sword.
func test_the_high_tech_swap_can_be_forced() -> void:
	var panel: Control = auto_free(EquipmentPanelScene.instantiate())
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(panel.dice_manager).override_failure_message(
		"premise: the panel resolved DiceManager").is_not_null()
	var kit: Array[Dictionary] = [{"name": "Military Rifle", "condition": "standard"}]
	panel.generated_equipment = kit
	panel._savvy_subs_available = 1
	panel._savvy_subs_used = 0
	_dm.queue_forced_result("High-Tech Weapon", 100)
	panel._on_savvy_swap_pressed(0)
	assert_str(str(panel.generated_equipment[0].name)).is_equal("Glare Sword")


## Rumors: at or under the Rumor count starts a Quest. A forced 6 against 5 Rumors fails.
func test_the_rumors_quest_check_can_be_forced() -> void:
	GameState.current_campaign = CampaignCoreClass.new()
	GameState.current_campaign.quest_rumors = 5
	var c: Node = auto_free(ResolveRumorsScene.instantiate())
	add_child(c)
	await get_tree().process_frame
	# The World Phase controller hands the step its Rumors through this entry point.
	c.initialize_rumors_phase(["r1", "r2", "r3", "r4", "r5"], {})
	assert_bool((c.rumors as Array).is_empty()).override_failure_message(
		"premise: the component loaded the campaign's Rumors").is_false()
	_dm.queue_forced_result("Rumors Quest Check", 6)
	c._on_roll_pressed()
	assert_int(int(c.last_roll)).is_equal(6)


## p.121, 61-75: "Debris: 1D3 credits' worth on the scrap market." The backend rolls it
## while the post-battle orchestrator runs.
func test_the_backend_debris_find_can_be_forced() -> void:
	var ctx = ContextClass.new()
	ctx.dice_manager = _dm
	ctx.battle_result = {"held_field": true}
	_dm.queue_forced_result("Battlefield Find", 61)
	_dm.queue_forced_result("Debris Credits", 3)
	var finds: Array = PaymentProcessorClass.new().process_battlefield_finds(ctx)
	assert_int(finds.size()).override_failure_message("premise: one find").is_equal(1)
	assert_str(str(finds[0].get("type", ""))).is_equal("DEBRIS")
	assert_int(int(finds[0].get("amount", 0))).is_equal(3)


## The screen rolls the same row when the backend did not resolve the step.
func test_the_screens_debris_and_loot_credits_can_be_forced() -> void:
	var ui: Control = auto_free(PostBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	_dm.queue_forced_result("Debris Credits", 3)
	assert_int(int(ui._resolve_battlefield_find(61).get("credits", 0))).is_equal(3)
	_dm.queue_forced_result("Loot Credits", 1)
	assert_int(ui._roll_credits_dice("1d6")).is_equal(1)
