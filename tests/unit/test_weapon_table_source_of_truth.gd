extends GdUnitTestSuite
## Weapon Ratings are single-sourced from data/equipment_database.json.
##
## THE GAP THIS PINS. WeaponTableSystem carried a hardcoded fallback table that
## was wrong in ~30 profiles against Core Rules p.50, and it fed two
## player-facing surfaces: WeaponTableDisplay (an in-app rules reference) and
## EnemyGenerationWizard (which arms enemies). The fallback fired silently
## whenever the JSON failed to load, so wrong data would reach the table with
## only a push_warning.
##
## Its Suppression Maul entry (Brawl, 2 damage, Melee+Stun) matched the
## COMPENDIUM Game Options alternative weapon table rather than the Core Rules
## (Brawl, 1 damage, Melee+Impact) — the sourcing trap recorded in
## docs/RULES_WIRING_AUDIT_2026-08.md. The Compendium table is an opt-in variant,
## NOT errata, so Core Rules values govern.

const WeaponTableSystem := preload("res://src/core/battle/WeaponTableSystem.gd")
const EquipmentDatabase := "res://data/equipment_database.json"

## Core Rules p.50 spot-values. Melee weapons print "Brawl" for range.
const BOOK := {
	"hand gun": {"range": 12, "shots": 1, "damage": 0},
	"colony rifle": {"range": 18, "shots": 1, "damage": 0},
	"military rifle": {"range": 24, "shots": 1, "damage": 0},
	"auto rifle": {"range": 24, "shots": 2, "damage": 0},
	"shotgun": {"range": 12, "shots": 2, "damage": 1},
	"hunting rifle": {"range": 30, "shots": 1, "damage": 1},
	"machine pistol": {"range": 8, "shots": 2, "damage": 0},
	"blast pistol": {"range": 8, "shots": 1, "damage": 1},
	"infantry laser": {"range": 30, "shots": 1, "damage": 0},
	"plasma rifle": {"range": 20, "shots": 2, "damage": 1},
	"flak gun": {"range": 8, "shots": 2, "damage": 1},
	"fury rifle": {"range": 24, "shots": 1, "damage": 2},
	"hyper blaster": {"range": 24, "shots": 3, "damage": 1},
	"rattle gun": {"range": 24, "shots": 3, "damage": 0},
	"shell gun": {"range": 30, "shots": 2, "damage": 0},
	"cling fire pistol": {"range": 12, "shots": 2, "damage": 1},
	"hand flamer": {"range": 12, "shots": 2, "damage": 1},
	"needle rifle": {"range": 18, "shots": 2, "damage": 0},
	"marksman's rifle": {"range": 36, "shots": 1, "damage": 0},
	"scrap pistol": {"range": 9, "shots": 1, "damage": 0},
}


func _json_weapons() -> Dictionary:
	var f := FileAccess.open(EquipmentDatabase, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_bool(parsed is Dictionary).is_true()
	var by_name: Dictionary = {}
	for entry in (parsed as Dictionary).get("weapons", []):
		if entry is Dictionary:
			by_name[str(entry.get("name", "")).to_lower()] = entry
	return by_name


func test_equipment_database_matches_core_rules_p50() -> void:
	# int() every parsed value: Godot's JSON parser returns EVERY number as a
	# float, so a raw compare against an int literal fails on correct data.
	var weapons := _json_weapons()
	for name: String in BOOK:
		assert_bool(weapons.has(name)).override_failure_message(
			"'%s' is missing from equipment_database.json" % name
		).is_true()
		var w: Dictionary = weapons[name]
		var want: Dictionary = BOOK[name]
		for field: String in want:
			assert_int(int(w.get(field, -999))).override_failure_message(
				"%s %s drifted from Core Rules p.50" % [name, field]
			).is_equal(int(want[field]))


func test_suppression_maul_uses_core_rules_not_the_compendium_option() -> void:
	# Core Rules p.50: Brawl, 1 damage, Melee + Impact.
	# Compendium Game Options: Brawl, 2 damage, Melee + Stun. That table is an
	# opt-in alternative and must never be the default.
	var weapons := _json_weapons()
	if not weapons.has("suppression maul"):
		return
	var w: Dictionary = weapons["suppression maul"]
	assert_int(int(w.get("damage", -1))).override_failure_message(
		"Suppression maul is 1 damage in the Core Rules; 2 is the Compendium option"
	).is_equal(1)
	var traits: Array = w.get("traits", [])
	var lowered: Array = []
	for t in traits:
		lowered.append(str(t).to_lower())
	assert_bool("impact" in lowered).override_failure_message(
		"Suppression maul has the Impact trait (p.50), not Stun"
	).is_true()
	assert_bool("stun" in lowered).override_failure_message(
		"'Stun' on the Suppression maul is the Compendium Game Options value"
	).is_false()


func test_weapon_system_has_no_hardcoded_fallback_table() -> void:
	# The fabricated fallback was deleted 2026-08-02. A silent fallback is worse
	# than a hard failure here, because this data reaches the player as a rules
	# reference and arms enemies.
	var src := FileAccess.open("res://src/core/battle/WeaponTableSystem.gd", FileAccess.READ)
	assert_object(src).is_not_null()
	var text := src.get_as_text()
	src.close()
	assert_bool(text.contains("_add_weapon(")).override_failure_message(
		"a hardcoded weapon table has been reintroduced — equipment_database.json is the SSOT"
	).is_false()
	assert_bool(text.contains("_initialize_weapon_registry")).override_failure_message(
		"the fabricated fallback registry has been reintroduced"
	).is_false()


func test_loaded_registry_agrees_with_the_json_it_came_from() -> void:
	var system: Variant = WeaponTableSystem.new()
	var weapons := _json_weapons()
	assert_int(system.get_all_weapons().size()).override_failure_message(
		"WeaponTableSystem loaded no weapons — equipment_database.json unreadable?"
	).is_greater(0)
	for name: String in ["shotgun", "plasma rifle", "hand gun"]:
		if not weapons.has(name):
			continue
		var entry: Dictionary = weapons[name]
		var loaded: Variant = system.get_weapon(str(entry.get("id", "")))
		assert_object(loaded).override_failure_message(
			"'%s' did not survive the load into WeaponTableSystem" % name
		).is_not_null()
		assert_int(loaded.range_inches).is_equal(int(entry.get("range", 0)))
		assert_int(loaded.shots).is_equal(int(entry.get("shots", 0)))
		assert_int(loaded.damage_bonus).is_equal(int(entry.get("damage", 0)))
