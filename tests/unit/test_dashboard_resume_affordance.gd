extends GdUnitTestSuite
## T11-16 — the dashboard must not offer a NEW turn when a battle is saved mid-fight.
##
## THE FINDING (device, deploy #19). After force-stopping during a battle and
## reopening the campaign, the dashboard read "Turn 9 — Story" with a primary button
## labelled "Begin Turn 9". Pressing it correctly RESUMED the saved battle from turn
## 8 — the checkpoint was intact and the resume worked. Only the affordance lied, and
## it lied in the direction that invites a player to believe their battle was lost
## and start over.
##
## ⚠ CORRECTION TO THE FINDING AS ORIGINALLY WRITTEN. It claimed `game_phase` was
## absent from the save. It is not: it is `meta.game_phase` ("active"), written by
## FiveParsecsCampaignCore. The original note read the TOP level of the save. That
## field is a LIFECYCLE marker anyway and would not distinguish these two states —
## the battle CHECKPOINT does, and that is what the fix reads.
##
## The dashboard is driven through its real .tscn: `phase_label` and `action_button`
## are @onready unique-name lookups, so a bare .new() would leave both null and the
## case would pass without asserting anything.

const DASHBOARD := "res://src/ui/screens/campaign/CampaignDashboard.tscn"
const CampaignCoreScript := preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")
const BattleCheckpoint := preload("res://src/core/battle/BattleCheckpoint.gd")

var _prior: Resource = null


func before_test() -> void:
	_prior = GameState.current_campaign


func after_test() -> void:
	GameState.current_campaign = _prior


func _campaign(with_checkpoint: bool) -> Resource:
	var c = CampaignCoreScript.new()
	c.from_dictionary({"campaign_id": "t1116"})
	c.progress_data["turns_played"] = 8
	if with_checkpoint:
		# Shaped so BattleCheckpoint.is_valid() accepts it: the schema version it
		# declares, and a `turn` matching turns_played (the COMPLETED count, which
		# is what the checkpoint stamps).
		c.progress_data["active_battle"] = {
			"schema_version": BattleCheckpoint.SCHEMA_VERSION,
			"turn": 8,
			"crew": [],
		}
	return c


func _dashboard(with_checkpoint: bool) -> Node:
	GameState.current_campaign = _campaign(with_checkpoint)
	var packed: PackedScene = load(DASHBOARD)
	assert_object(packed).is_not_null()
	var dash: Node = auto_free(packed.instantiate())
	add_child(dash)
	await await_idle_frame()
	return dash


func test_a_saved_battle_offers_to_resume_it() -> void:
	var dash := await _dashboard(true)
	assert_object(dash.action_button).override_failure_message(
		"action_button is null — the scene did not build, so this proves nothing."
	).is_not_null()
	dash._update_phase_ui(0)

	assert_str(dash.action_button.text).override_failure_message(
		"With a valid battle checkpoint the button read '%s'. Offering a new turn "
		% dash.action_button.text + "here reads as 'your battle is gone'."
	).contains("Resume Battle")
	assert_str(dash.phase_label.text).contains("Battle in progress")


func test_with_no_checkpoint_it_still_begins_the_turn() -> void:
	var dash := await _dashboard(false)
	dash._update_phase_ui(0)

	assert_str(dash.action_button.text).override_failure_message(
		"Without a checkpoint the button must still start the next turn."
	).contains("Begin Turn")
	assert_str(dash.phase_label.text).not_contains("Battle in progress")


## A checkpoint from a DIFFERENT turn is stale — is_valid() rejects it on the turn
## mismatch — and must not offer a resume that would restore the wrong fight.
func test_a_stale_checkpoint_does_not_offer_a_resume() -> void:
	GameState.current_campaign = _campaign(true)
	GameState.current_campaign.progress_data["active_battle"]["turn"] = 3
	var packed: PackedScene = load(DASHBOARD)
	var dash: Node = auto_free(packed.instantiate())
	add_child(dash)
	await await_idle_frame()
	dash._update_phase_ui(0)

	assert_str(dash.action_button.text).contains("Begin Turn")


## Both labels must agree on the turn number: a header saying one turn and a button
## saying another is the confusion this row is about.
func test_the_header_and_the_button_agree_on_the_turn() -> void:
	var dash := await _dashboard(true)
	dash._update_phase_ui(0)
	assert_str(dash.action_button.text).contains("9")
	assert_str(dash.phase_label.text).contains("Turn 9")
