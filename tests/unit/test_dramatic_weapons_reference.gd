extends GdUnitTestSuite
## The Compendium pp.88-89 Dramatic Weapons table reaches the player.
##
## With Dramatic Combat on, BattleResolver applies the pp.88-89 profiles to every
## weapon in an auto-resolved battle, but a battle the player PLAYS showed the table
## nowhere: the setup tab prints the p.87 rules only, and the cheat sheet had no
## section. Meanwhile get_dramatic_effect() had no caller and returned a per-weapon-
## TYPE paraphrase ("Blades and melee weapons score +1 Damage") that is in neither
## book. These cases render the cheat-sheet section from the SAME rows the resolver
## applies, with the printed names and the p.89 trait notes.
##
## Flags are flipped in memory only (set_dlc_owned() persists).

const Sections = preload("res://src/ui/components/battle/CheatSheetSections.gd")
const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")
const PanelScript = preload("res://src/ui/components/battle/CheatSheetPanel.gd")
const DATA_PATH := "res://data/compendium/difficulty_toggles.json"

var _owned: Dictionary = {}
var _flags: Dictionary = {}


func before_test() -> void:
	var dlc := get_node("/root/DLCManager")
	_owned = dlc._owned_dlcs.duplicate()
	_flags = dlc._enabled_flags.duplicate()


func after_test() -> void:
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs = _owned
	dlc._enabled_flags = _flags


func _set_dramatic(on: bool) -> void:
	var dlc := get_node("/root/DLCManager")
	dlc._owned_dlcs["freelancers_handbook"] = true
	dlc._enabled_flags[dlc.ContentFlag.DRAMATIC_COMBAT] = on


func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func test_the_section_prints_every_row_the_resolver_applies() -> void:
	_set_dramatic(true)
	var text := Sections.dramatic_weapons()
	var table: Dictionary = _data()["dramatic_weapons_stats"]
	var rows := 0
	for key: String in table:
		if key.begins_with("_"):
			continue
		rows += 1
		assert_str(text).contains("[b]%s[/b]" % str(table[key]["name"]))
	assert_int(rows).is_equal(36)
	# Two rows read straight off the page (p.89, p.88).
	assert_str(text).contains("[b]Hunting rifle[/b]  30\"  1  1  Heavy, Critical")
	assert_str(text).contains("[b]Blade[/b]  Brawl  -  1  Melee")
	assert_str(text).contains("Adjusted Shooting hit numbers (p.87)")


func test_the_section_carries_the_p89_trait_notes() -> void:
	_set_dramatic(true)
	var text := Sections.dramatic_weapons()
	assert_str(text).contains("Trait notes (p.89)")
	assert_str(text).contains("All shots hit on a 5+ regardless of hit modifiers, skill or Cover.")
	assert_str(text).contains("+1 to Brawling rolls. +1 to hit within 6\".")
	assert_int((_data()["dramatic_trait_notes"]["notes"] as Array).size()).is_equal(16)


func test_the_panel_shows_the_section_only_with_dramatic_combat_on() -> void:
	_set_dramatic(true)
	var on_panel: Node = auto_free(PanelScript.new())
	add_child(on_panel)
	assert_bool(_titles(on_panel).has("Dramatic Weapons [Compendium pp.88-89]")).is_true()
	_set_dramatic(false)
	assert_str(Sections.dramatic_weapons()).is_empty()
	var off_panel: Node = auto_free(PanelScript.new())
	add_child(off_panel)
	assert_bool(_titles(off_panel).has("Dramatic Weapons [Compendium pp.88-89]")).is_false()


func test_the_per_type_paraphrase_is_gone() -> void:
	# "dramatic_effects" held a sentence per weapon TYPE that neither book prints.
	assert_bool(_data().has("dramatic_effects")).is_false()


func _titles(panel: Node) -> Array:
	var out: Array = []
	for s: Dictionary in panel._sections:
		out.append(str(s.get("title", "")))
	return out
