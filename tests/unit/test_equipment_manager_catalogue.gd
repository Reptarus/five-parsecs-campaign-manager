extends GdUnitTestSuite
## The equipment screen that creation step 4's "Manual Select" opens.
##
## Its catalogue was a five-item literal in neither book's form: a Military Rifle at
## Damage 1 (Core Rules p.50 prints 0), a "Combat Armor" with a "Heavy" trait, a
## "Medkit". With no crew handed over it showed four invented crew ("Captain
## Reynolds", "Dr. Chen"). And its details pane could only print zeros: it read the
## copy DataValidator.validate_equipment() returns, which keeps a fixed key set and
## drops range, shots, damage and traits. The catalogue is data/equipment_database.json
## now, the pane reads the item itself, and the crew is only what the panel hands over.

const SCENE := "res://src/ui/screens/equipment/EquipmentManager.tscn"
const DB := "res://data/equipment_database.json"


func _screen() -> Node:
	var screen: Node = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(screen)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func _db_names() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DB))
	var out: Array = []
	for section: String in ["weapons", "armor", "gear"]:
		for e: Dictionary in data[section]:
			out.append(str(e["name"]))
	return out


func test_the_catalogue_is_the_equipment_database() -> void:
	var screen := await _screen()
	var names: Array = screen.equipment_database.map(
		func(i: Dictionary) -> String: return str(i.get("name", "")))
	assert_array(names).contains_exactly_in_any_order(_db_names())
	assert_array(names).not_contains(["Medkit"])
	# No invented crew before the creation panel hands its crew over.
	assert_array(screen.crew_roster).is_empty()


## Through the grid buttons, as a player taps them: the binding is part of the fix.
func _press(screen: Node, item_name: String) -> void:
	for b: Node in screen.equipment_grid.get_children():
		if b is Button and (b as Button).text == item_name:
			(b as Button).pressed.emit()
			await await_idle_frame()
			return
	fail("no grid button for %s" % item_name)


func test_the_details_pane_shows_the_items_real_profile() -> void:
	var screen := await _screen()
	await _press(screen, "Military Rifle")
	var label: Label = screen.details_container.find_child("ProfileLabel", true, false)
	assert_object(label).is_not_null()
	# Core Rules p.50: Military rifle 24", 1 shot, damage 0.
	assert_str(label.text).is_equal("24\" · 1 shot · Dmg +0")
	await _press(screen, "Blade")
	label = screen.details_container.find_child("ProfileLabel", true, false)
	# p.50 prints a melee weapon's range as "Brawl".
	assert_str(label.text).is_equal("Brawl · Dmg +0")
