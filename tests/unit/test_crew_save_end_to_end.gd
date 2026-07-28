extends GdUnitTestSuite
## END-TO-END: a crew member created in the wizard must reach the SAVE FILE ON DISK
## with its species and rule-bearing fields intact.
##
## WHY THIS EXISTS SEPARATELY FROM test_crew_serialization_fidelity.gd
## That suite proves _character_to_dict() returns a wide dict. It does NOT prove the
## dict survives the rest of the chain:
##
##   CrewPanel (Character Resources)
##     -> CampaignCreationCoordinator._character_to_dict()
##        -> CampaignFinalizationService._transform_crew_data_for_turn_system()
##           -> FiveParsecsCampaignCore.crew_data["members"]
##              -> save_to_file() -> JSON on disk
##
## Any link could narrow the dict again. The original bug was exactly a narrowing in
## the middle of a chain that looked fine at both ends, so "the converter is correct"
## is not the same claim as "the save file is correct". This asserts the bytes.
##
## gdUnit4 v6.0.3 compatible.

const Coordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const FinalizationService = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")

const TEST_DIR := "user://test_crew_e2e/"

var _paths: Array[String] = []


func before_test() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_test() -> void:
	for p in _paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(p + suffix):
				DirAccess.remove_absolute(p + suffix)
	_paths.clear()


func _path(name: String) -> String:
	var p := TEST_DIR + name
	_paths.append(p)
	return p


func _make_character(cname: String, species: String, is_captain: bool) -> Resource:
	var ch = CharacterScript.new()
	ch.character_name = cname
	ch.species_id = species
	ch.is_captain = is_captain
	ch.combat = 2
	ch.toughness = 4
	return ch


func _save_a_crew_and_read_it_back() -> Array:
	## Runs the real chain and returns the crew members as parsed from the FILE.
	var coordinator = Coordinator.new()
	add_child(coordinator)
	auto_free(coordinator)

	# 1. The wizard holds Character RESOURCES (CrewPanel.gd:143/153).
	var roster := [
		_make_character("Captain Reyes", "human", true),
		_make_character("Vex Kalder", "krag", false),
		_make_character("Nine", "bot", false),
	]

	# 2. Coordinator normalisation — where the ~38 fields used to be dropped.
	var members := []
	for r in roster:
		members.append(coordinator._character_to_dict(r))

	# 3. Finalization transform.
	var svc = FinalizationService.new()
	if svc is Node:
		add_child(svc)
		auto_free(svc)
	var transformed: Dictionary = svc._transform_crew_data_for_turn_system(
		{"members": members})

	# 4. Into the campaign and out to disk.
	var campaign = CampaignCore.new()
	campaign.campaign_id = "crew_e2e"
	campaign.campaign_name = "Crew E2E"
	campaign.crew_data = transformed
	var path := _path("crew_e2e.save")
	campaign.save_to_file(path)

	# 5. Read the FILE, not the object.
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return []
	var crew = (parsed as Dictionary).get("crew", {})
	if not (crew is Dictionary):
		return []
	var out = (crew as Dictionary).get("members", [])
	return out if out is Array else []


func test_every_crew_member_reaches_disk_with_its_species() -> void:
	var members := _save_a_crew_and_read_it_back()
	assert_int(members.size()).override_failure_message(
		"the crew did not survive the chain to disk at all"
	).is_equal(3)

	var speciesless: Array[String] = []
	for m in members:
		if not (m is Dictionary):
			continue
		var d: Dictionary = m
		if str(d.get("species_id", "")).is_empty():
			speciesless.append(str(d.get("character_name", d.get("name", "?"))))

	assert_array(speciesless).override_failure_message(
		"reached the save file WITHOUT species_id: %s — every Strange Character rule "
		% str(speciesless) + "is inert for them"
	).is_empty()


func test_non_captains_are_not_narrower_than_the_captain_on_disk() -> void:
	# The original bug in one assertion: the captain kept 27 keys and everyone else
	# got 18, because only the captain's path merged to_dictionary().
	var members := _save_a_crew_and_read_it_back()
	var captain_keys := 0
	var worst_crew_keys := 9999
	var worst_name := ""
	for m in members:
		if not (m is Dictionary):
			continue
		var d: Dictionary = m
		if bool(d.get("is_captain", false)):
			captain_keys = d.size()
		elif d.size() < worst_crew_keys:
			worst_crew_keys = d.size()
			worst_name = str(d.get("character_name", "?"))

	assert_int(captain_keys).is_greater(0)
	assert_bool(worst_crew_keys >= captain_keys).override_failure_message(
		"on disk the captain has %d keys but '%s' has only %d — the projection is back"
		% [captain_keys, worst_name, worst_crew_keys]
	).is_true()


func test_bot_flag_reaches_disk() -> void:
	# is_bot absent meant Bots were handed XP, which Core Rules p.98 forbids.
	var members := _save_a_crew_and_read_it_back()
	var found := false
	for m in members:
		if m is Dictionary and str((m as Dictionary).get("character_name", "")) == "Nine":
			found = (m as Dictionary).has("is_bot")
	assert_bool(found).override_failure_message(
		"is_bot never reached the save file — the p.98 no-XP rule cannot be enforced"
	).is_true()
