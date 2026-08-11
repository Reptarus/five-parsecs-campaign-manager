extends GdUnitTestSuite
## W2-02 — does generating a Quest from Rumors actually PERSIST? (tablet QA, Aug 8 2026)
##
## On device, Turn 1 rolled "2 <= 5 rumors - QUEST GENERATED! New Quest: Mysterious
## Data", and the end-of-turn save contained NO `active_quest` key and
## `resources.quest_rumors = 6` — i.e. the Quest was never stored and p.85's "remove
## all Rumors from your roster" never happened. With no active Quest the p.85 gate
## ("If you are NOT currently on a Quest, roll a D6") re-opens every turn and the
## rumor pool costs nothing, forever.
##
## Two causes were possible and the ledger deliberately refused to guess:
##   (a) the persistence block in _generate_quest_from_rumors() never executed, or
##   (b) the Quest was legitimately cleared later by the p.120 post-battle step.
##
## This suite settles it by exercising ONLY the generation step against a real
## campaign, with no battle and no rollover in the way. If these pass, the loss is
## downstream and (b) is where to look; if they fail, it is (a).
##
## Note on (b): clear_active_quest() assigns `{}`, it does not erase the key — so a
## save that is MISSING the key entirely cannot have come from that path. That
## asymmetry is worth preserving, and is asserted below.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const CampaignCoreClass = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const ResolveRumorsScene = preload(
	"res://src/ui/screens/world/components/ResolveRumorsComponent.tscn")

var _prior_campaign: Resource = null


func before_test() -> void:
	_prior_campaign = GameState.current_campaign
	GameState.current_campaign = CampaignCoreClass.new()
	GameState.current_campaign.quest_rumors = 5


func after_test() -> void:
	GameState.current_campaign = _prior_campaign


func _component() -> Node:
	var c: Node = auto_free(ResolveRumorsScene.instantiate())
	add_child(c)
	return c


func test_generating_a_quest_writes_it_to_the_campaign() -> void:
	# The whole point of a Quest is that the p.85 gate sees it next turn.
	var c := _component()
	c.rumors = ["r1", "r2", "r3", "r4", "r5"]

	c._generate_quest_from_rumors()

	assert_bool(GameState.has_active_quest()).is_true()
	assert_str(str(GameState.get_active_quest().get("name", ""))).is_not_empty()


func test_generating_a_quest_spends_the_rumors() -> void:
	# Core Rules p.85: "remove all Rumors from your roster." The device save showed 6
	# survivors, which is what makes the Quest free and repeatable.
	var c := _component()
	c.rumors = ["r1", "r2", "r3", "r4", "r5"]

	c._generate_quest_from_rumors()

	assert_int(int(GameState.current_campaign.quest_rumors)).is_equal(0)


func test_the_stored_quest_survives_a_serialize_reload_round_trip() -> void:
	# The device evidence was a SAVE FILE, not a screen, so the assertion has to run
	# through serialization — an in-memory write that does not survive `progress` is
	# indistinguishable on screen from one that does.
	var c := _component()
	c.rumors = ["r1", "r2", "r3", "r4", "r5"]
	c._generate_quest_from_rumors()

	# to_dictionary()/from_dictionary(), NOT serialize()/deserialize() — those do not
	# exist on this Resource and the invalid call shows up as a gdUnit ERROR rather
	# than a failure. An error row is a harness fault until proven otherwise.
	var blob: Dictionary = GameState.current_campaign.to_dictionary()
	var restored = CampaignCoreClass.new()
	restored.from_dictionary(blob)

	assert_bool(restored.progress_data.has("active_quest")).is_true()
	assert_bool((restored.progress_data["active_quest"] as Dictionary).is_empty()).is_false()
	assert_int(int(restored.quest_rumors)).is_equal(0)


func test_clearing_a_quest_leaves_the_key_present_but_empty() -> void:
	# The discriminator between the two candidate causes, and the reason the missing
	# key on device ruled out the post-battle path. Do not "tidy" clear_active_quest()
	# into an erase() — that would destroy this evidence for the next investigation.
	GameState.set_active_quest({"id": "q1", "name": "Test"})
	assert_bool(GameState.has_active_quest()).is_true()

	GameState.clear_active_quest()

	assert_bool(GameState.current_campaign.progress_data.has("active_quest")).is_true()
	assert_bool(GameState.has_active_quest()).is_false()
