extends GdUnitTestSuite
## Weapons reach the auto-resolver at all, and Dramatic Weapons overrides them.
##
## THE DEFECT THIS PINS. BattleResolver reads `attacker["weapon"]` in exactly two
## places and NOTHING anywhere wrote it:
##
##   - initialize_battle() pulled armor and screens out of `equipment` and never
##     a weapon.
##   - Character.to_dictionary() emits `equipment` (an Array of item NAMES) and
##     has no `weapon` key at all.
##   - Enemies carry `weapons` — plural, an Array of names. The attack loop reads
##     `weapon`, singular. Nothing bridged the two.
##
## So `attacker.get("weapon", {})` was {} in every auto-resolved battle ever
## played and every attack used the defaults: range 12", 1 shot, 1 damage, no
## traits, logged as "Unknown Weapon". A Hand Cannon (damage 2, range 8") and a
## Hand Gun (damage 0, range 12") were mechanically identical; a Machine Pistol
## fired one shot instead of two; and every weapon trait in the game — Focused,
## Piercing, Critical, Snap Shot, Heavy, Burn, Hot — was inert, because the trait
## list was always empty. The Overheat and Focused code in BattleResolver is
## written correctly and simply had no data to act on.
##
## It is also why the Compendium pp.88-89 Dramatic Weapons table had no consumer:
## there was no weapon profile in the unit to override.
##
## gdUnit4 v6.0.3 compatible.

const BattleResolverClass = preload("res://src/core/battle/BattleResolver.gd")
const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("DRAMATIC_COMBAT"))
	# Default OFF so the baseline tests measure equipment_database, not the
	# Compendium overlay. A flag left on here would leak into sibling suites.
	dlc.set_feature_enabled(dlc.ContentFlag.get("DRAMATIC_COMBAT"), false)


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DRAMATIC_COMBAT"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _crew(name: String, equipment: Array) -> Dictionary:
	return {
		"character_id": "c_" + name, "character_name": name,
		"combat": 1, "combat_skill": 1, "toughness": 3, "speed": 4,
		"reactions": 1, "savvy": 0, "luck": 0,
		"equipment": equipment, "status_effects": [], "injuries": [],
	}


func _unit_weapon(crew_list: Array, enemy_list: Array, index: int,
		is_enemy: bool = false) -> Dictionary:
	var state: Dictionary = BattleResolverClass.initialize_battle(
		crew_list, enemy_list, {})
	var units: Array = state["enemy_units"] if is_enemy else state["crew_units"]
	assert_int(units.size()).is_greater(index)
	var w: Variant = units[index].get("weapon", null)
	return w if w is Dictionary else {}


# --- The crew's weapon reaches the resolver -----------------------------------

func test_a_crew_members_carried_weapon_becomes_their_battle_profile() -> void:
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Hand Cannon"])], [], 0)
	assert_bool(w.is_empty()).override_failure_message(
		"unit['weapon'] is still empty — the attack loop will fall back to the "
		+ "generic 12\"/1 shot/1 damage default for every crew member"
	).is_false()
	# equipment_database.json Hand Cannon: damage 2, range 8, 1 shot, Pistol.
	assert_int(int(w.get("damage", -1))).is_equal(2)
	assert_int(int(w.get("range", -1))).is_equal(8)


func test_two_different_guns_are_not_mechanically_identical() -> void:
	# The headline symptom: before the fix both of these resolved to {} and were
	# indistinguishable in play.
	var cannon: Dictionary = _unit_weapon([_crew("A", ["Hand Cannon"])], [], 0)
	var handgun: Dictionary = _unit_weapon([_crew("B", ["Hand Gun"])], [], 0)
	assert_int(int(cannon.get("damage", 0))).override_failure_message(
		"Hand Cannon and Hand Gun deal the same damage — weapons do not matter"
	).is_not_equal(int(handgun.get("damage", 0)))


func test_a_multishot_weapon_keeps_its_shots() -> void:
	# Machine Pistol is 2 shots; the default is 1, so this is the shot-count proof.
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Machine Pistol"])], [], 0)
	assert_int(int(w.get("shots", 1))).override_failure_message(
		"a 2-shot weapon fired once — BattleResolver's per-shot loop had no "
		+ "profile to read").is_equal(2)


func test_weapon_traits_arrive_so_the_trait_code_has_data() -> void:
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Machine Pistol"])], [], 0)
	var traits: Array = w.get("traits", [])
	assert_int(traits.size()).override_failure_message(
		"traits were empty, so Focused/Overheat/Piercing/Critical handling could "
		+ "never fire for any weapon in the game").is_greater(0)


func test_armor_in_the_pack_is_not_mistaken_for_a_weapon() -> void:
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Combat Armor", "Blade"])], [], 0)
	assert_str(str(w.get("name", ""))).override_failure_message(
		"the first ITEM is not the first WEAPON — armor must be skipped"
	).is_equal("Blade")


func test_a_crew_member_carrying_no_weapon_gets_no_invented_gun() -> void:
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Combat Armor"])], [], 0)
	assert_bool(w.is_empty()).override_failure_message(
		"an unarmed figure must not be handed a weapon the player never bought"
	).is_true()


# --- Enemies too --------------------------------------------------------------

func test_enemy_weapons_plural_bridge_to_the_singular_key() -> void:
	var enemy := {
		"name": "Raider", "combat_skill": 1, "toughness": 3, "speed": 4,
		"weapons": ["Colony Rifle", "Blade"],
	}
	var w: Dictionary = _unit_weapon([], [enemy], 0, true)
	assert_bool(w.is_empty()).override_failure_message(
		"enemies carry `weapons` and the attack loop reads `weapon` — nothing "
		+ "bridged the two, so enemy profiles were inert as well").is_false()
	assert_str(str(w.get("name", ""))).is_equal("Colony Rifle")


# --- Dramatic Weapons pp.88-89 now has something to override -------------------

func test_dramatic_combat_replaces_the_printed_profile() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	var baseline: Dictionary = _unit_weapon([_crew("Kaya", ["Hand Cannon"])], [], 0)

	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("DRAMATIC_COMBAT"), true)
	var dramatic: Dictionary = _unit_weapon([_crew("Kaya", ["Hand Cannon"])], [], 0)

	assert_bool(bool(dramatic.get("dramatic_profile", false))).override_failure_message(
		"the pp.88-89 table did not overlay — get_dramatic_weapon_stats() still "
		+ "has no consumer").is_true()
	# p.88 Hand cannon: 6" 1 shot 2 damage Pistol. Baseline is 8".
	assert_int(int(dramatic.get("range", -1))).override_failure_message(
		"p.88 prints Hand cannon at 6\"; got %s (baseline was %s)"
		% [str(dramatic.get("range")), str(baseline.get("range"))]).is_equal(6)


func test_dramatic_combat_off_leaves_the_baseline_untouched() -> void:
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Hand Cannon"])], [], 0)
	assert_bool(w.has("dramatic_profile")).override_failure_message(
		"the overlay fired with the option switched off").is_false()
	assert_int(int(w.get("range", -1))).is_equal(8)


func test_a_weapon_absent_from_the_dramatic_table_keeps_its_profile() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("DRAMATIC_COMBAT"), true)
	# The pp.88-89 table lists 37 weapons; equipment_database has 36 entries but
	# not every id matches. Whatever is missing must pass through unchanged
	# rather than being blanked to zeros.
	var w: Dictionary = _unit_weapon([_crew("Kaya", ["Hand Gun"])], [], 0)
	assert_bool(w.is_empty()).is_false()
	assert_int(int(w.get("range", 0))).is_greater(0)
