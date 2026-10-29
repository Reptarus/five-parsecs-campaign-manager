extends GdUnitTestSuite
## UX-6: one post-battle receipt renderer for Bug Hunt, Tactics and Planetfall.
##
## Every case asserts a step's RESULT line on screen, never only its heading: a heading
## renders for a step the rule skipped (the Bug Hunt Phase 7 Court Martial detector, which
## returned the same answer in both arms). Breaking ReceiptCard's line renderer turns all
## three mode cases red at once, which is what makes it the one renderer.

const ReceiptCard = preload("res://src/ui/components/common/ReceiptCard.gd")
const BugHuntPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
const TacticsPanel = preload(
	"res://src/ui/screens/tactics/panels/TacticsOperationalMapPanel.gd")
const PlanetfallPanel = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const TacticsCore = preload("res://src/game/campaign/TacticsCampaignCore.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()


func after_test() -> void:
	SaveDirGuard.restore(_user_state)
	_user_state = {}


func _text(root: Node) -> String:
	var out: Array = []
	for n in root.find_children("*", "", true, false):
		if n is Label:
			out.append((n as Label).text)
		elif n is RichTextLabel:
			out.append((n as RichTextLabel).get_parsed_text())
	return "\n".join(out)


func _step() -> Dictionary:
	return {"step": 2, "title": "Injuries", "cite": "p.202",
		"rolls": [{"die": "D100", "value": 40, "modifier": 5, "total": 45,
			"subject": "c1", "column": "Grunt"}],
		"lines": ["Ash is out for 2 missions."]}


func test_a_receipt_step_prints_its_dice_and_its_result() -> void:
	var body: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(body)
	ReceiptCard.fill(body, _step(), func(id: String) -> String:
		return "Ash" if id == "c1" else id)
	assert_str(ReceiptCard.heading(_step())).is_equal("Step 2: Injuries")
	assert_str(_text(body)).contains("p.202") \
		.contains("D100 -> 40 +5 = 45  (Ash) [Grunt]") \
		.contains("Ash is out for 2 missions.")
	# A skipped step with nothing to say is announced, not left as a bare heading.
	var skipped: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(skipped)
	ReceiptCard.fill(skipped, {"title": "Court Martial", "skipped": true})
	assert_str(_text(skipped)).contains("Not applicable this turn.")


func test_bug_hunt_prints_a_step_result_through_the_shared_card() -> void:
	var panel: Control = auto_free(BugHuntPanel.new())
	add_child(panel)
	await get_tree().process_frame
	var box := VBoxContainer.new()
	panel.add_child(box)
	panel._content_container = box
	panel._receipt = {"steps": [_step()]}
	panel._render_receipt()
	assert_str(_text(box)).contains("Step 2: Injuries") \
		.contains("D100 -> 40 +5 = 45").contains("Ash is out for 2 missions.")


func test_tactics_prints_a_step_result_through_the_shared_card() -> void:
	var campaign = TacticsCore.new()
	campaign.operational_map = {
		"player_cohesion": 5, "enemy_cohesion": 5, "player_battle_points": 0,
		"operational_turn": 0, "focus_zone_id": "z1",
		"regions": [{"id": "r1", "name": "North", "zones": ["z1"], "is_focus": true}],
		"zones": [{"id": "z1", "region_id": "r1", "name": "North Pass", "status": 0,
			"player_army_strength": 4, "enemy_army_strength": 4}],
		"orders_history": [],
	}
	var panel: Control = auto_free(TacticsPanel.new())
	add_child(panel)
	await get_tree().process_frame
	panel.setup(null, campaign)
	panel.show_phase(7)
	panel._take({"title": "Step 3 — Resolve Focus Battle (p.96)",
		"lines": ["Player wins North Pass."]})
	panel._advance_to(panel._stage)
	await get_tree().process_frame
	assert_str(_text(panel._content)).contains("Step 3 — Resolve Focus Battle (p.96)") \
		.contains("Player wins North Pass.")


func test_planetfall_prints_a_step_result_through_the_shared_card() -> void:
	var panel: Control = auto_free(PlanetfallPanel.new())
	add_child(panel)
	await get_tree().process_frame
	var box := VBoxContainer.new()
	panel.add_child(box)
	panel._result_container = box
	panel._receipt_lines = []
	panel._add_result_bbcode("Colony Morale +1 (p.68).")
	assert_str(_text(box)).contains("Colony Morale +1 (p.68).")
	assert_array(panel._receipt_lines).contains(["Colony Morale +1 (p.68)."])
