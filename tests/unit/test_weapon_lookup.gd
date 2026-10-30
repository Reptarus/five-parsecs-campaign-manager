extends GdUnitTestSuite
## A weapon is a name in the equipment database (Core Rules pp.49-51), found by one
## normalised key, the same everywhere it is looked up.
##
## Before 2026-10-29 the battle cards matched the exact lowercase name, so the "Handgun" a
## recruit is handed (recruitment_opportunities.json) found no profile, while the printable
## sheet stripped spaces and found "Hand Gun". The crew-task dialogs decided what a weapon
## was by keyword, missing Hyper Blaster and both grenades and counting Concealed Blade.

const BotUpgradeEffectsRef = preload("res://src/core/character/BotUpgradeEffects.gd")
const CrewTaskComponentScript = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")
const EQUIPMENT := "res://data/equipment_database.json"
const RECRUITS := "res://data/campaign_tables/crew_tasks/recruitment_opportunities.json"


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _database_weapon_names() -> Array:
	var names: Array = []
	for w: Variant in (_json(EQUIPMENT) as Dictionary).get("weapons", []):
		names.append(str((w as Dictionary).get("name", "")))
	return names


func test_a_recruits_handgun_finds_the_books_hand_gun() -> void:
	# Premise: a live producer really writes the one-word spelling.
	assert_str(FileAccess.get_file_as_string(RECRUITS)).contains("\"Handgun\"")
	assert_str(str(BotUpgradeEffectsRef.weapon_profile("Handgun").get("name", ""))) \
		.is_equal("Hand Gun")
	assert_str(str(BotUpgradeEffectsRef.weapon_profile("marksmans rifle").get("name", ""))) \
		.is_equal("Marksman's Rifle")
	assert_dict(BotUpgradeEffectsRef.weapon_profile("Concealed Blade")).is_empty()


func test_no_two_database_weapons_share_a_key() -> void:
	var seen: Dictionary = {}
	for n: String in _database_weapon_names():
		var key: String = BotUpgradeEffectsRef.weapon_key(n)
		assert_bool(seen.has(key)).override_failure_message(
			"%s and %s share the key %s" % [n, seen.get(key, ""), key]).is_false()
		seen[key] = n
	assert_int(seen.size()).is_equal(36)


func test_the_crew_task_dialog_knows_every_database_weapon_and_no_gear() -> void:
	var c = auto_free(CrewTaskComponentScript.new())
	for n: String in _database_weapon_names():
		assert_bool(c._is_weapon(n)).override_failure_message(
			"%s is a database weapon" % n).is_true()
	for gear: String in ["Concealed Blade", "Grapple Launcher", "Communicator"]:
		assert_bool(c._is_weapon(gear)).override_failure_message(
			"%s is gear, not a weapon" % gear).is_false()
