extends GdUnitTestSuite

## Species rule gates + book-exact combat modifier sources (2026-07-02).
##
## Guards the fabricated-species purge: the dead "Species Combat Abilities"
## region (synthoid/avian/psyker/... + Human "Adaptable") was deleted from
## BattleCalculations; the LIVE _apply_species_bonuses was made book-exact
## (Soulless/Bot armor 5 -> 6+ per Core Rules p.15/p.17; fabricated K'Erin
## +1 brawl, Hulker +2 melee, Stalker ambush +2, Swift defense_vs_ranged,
## and the felinoid/reptilian/insectoid species removed); and the
## De-converted / Assault Bot "Savvy can never be improved" rule
## (p.19/p.21) gained mechanical gates in Character.spend_xp_on_stat and
## CharacterAdvancementService.can_advance_stat.

const CharacterScript = preload("res://src/core/character/Character.gd")


func _make_character(species: String, xp: int = 5):
	var c = CharacterScript.new()
	c.species_id = species
	c.origin = species
	c.experience = xp
	return c


func _species_stats(c) -> Array:
	var mods: Dictionary = c.get_combat_modifiers()
	var stats: Array = []
	for src in mods.get("sources", []):
		if src.get("type", "") == "species":
			stats.append(str(src.get("stat", "")))
	return stats


# ── Savvy-frozen gates (Core Rules p.19 De-converted, p.21 Assault Bot) ──

func test_de_converted_cannot_improve_savvy():
	var c = _make_character("de_converted")
	var savvy_before: int = c.savvy
	assert_bool(c.spend_xp_on_stat("savvy")).is_false()
	assert_int(c.savvy).is_equal(savvy_before)
	assert_int(c.experience).is_equal(5)  # XP must not be consumed


func test_assault_bot_cannot_improve_savvy():
	var c = _make_character("assault_bot")
	assert_bool(c.spend_xp_on_stat("savvy")).is_false()


func test_de_converted_can_still_improve_other_stats():
	var c = _make_character("de_converted")
	var combat_before: int = c.combat
	assert_bool(c.spend_xp_on_stat("combat")).is_true()
	assert_int(c.combat).is_equal(combat_before + 1)


func test_human_can_improve_savvy():
	var c = _make_character("human")
	var before: int = c.savvy
	assert_bool(c.spend_xp_on_stat("savvy")).is_true()
	assert_int(c.savvy).is_equal(before + 1)


func test_advancement_service_blocks_frozen_savvy():
	var result: Dictionary = CharacterAdvancementService.can_advance_stat(
		{"species_id": "de_converted", "experience": 10, "savvy": 0}, "savvy")
	assert_bool(result.get("can_advance", true)).is_false()
	assert_str(str(result.get("reason", ""))).contains("Savvy")


func test_advancement_service_legacy_float_origin_no_crash():
	# Legacy saves store origin as a numeric enum float — the gate must
	# str()-wrap it, not crash, and not block non-frozen species.
	var result: Dictionary = CharacterAdvancementService.can_advance_stat(
		{"origin": 7.0, "experience": 10, "savvy": 0}, "savvy")
	assert_bool(result.get("can_advance", false)).is_true()


# ── Book-exact species modifier sources ──────────────────────────────────

func test_soulless_natural_armor_is_6():
	var mods: Dictionary = _make_character("soulless").get_combat_modifiers()
	var armor_value := -1
	for src in mods.get("sources", []):
		if src.get("stat", "") == "natural_armor":
			armor_value = int(src.get("value", -1))
	assert_int(armor_value).is_equal(6)  # Core Rules p.17 (was wrongly 5)


func test_hulker_book_flags_no_melee_bonus():
	var stats := _species_stats(_make_character("hulker"))
	assert_array(stats).contains([
		"shooting_skill_zero", "no_shooting_bonuses", "ignore_clumsy_heavy"])
	assert_bool("melee_damage_bonus" in stats).is_false()


func test_kerin_reroll_flag_no_flat_bonus():
	var stats := _species_stats(_make_character("kerin"))
	assert_array(stats).contains(["brawl_reroll"])
	assert_bool("brawl_bonus" in stats).is_false()


func test_traveler_retreat_speed_bonus():
	var stats := _species_stats(_make_character("traveler"))
	assert_array(stats).contains(["retreat_speed_bonus"])


func test_primitive_gun_sight_ban_and_limits():
	var stats := _species_stats(_make_character("primitive"))
	assert_array(stats).contains([
		"no_gun_sights", "max_range_8", "melee_elegant"])


func test_stalker_teleport_replaces_fabricated_ambush():
	var stats := _species_stats(_make_character("stalker"))
	assert_array(stats).contains(["teleport_1d6"])  # Core Rules p.20
	assert_bool("ambush_hit_bonus" in stats).is_false()


func test_fabricated_species_have_no_entries():
	# felinoid / reptilian / insectoid are not Five Parsecs species — their
	# invented modifier entries were removed.
	for fake in ["felinoid", "reptilian", "insectoid"]:
		assert_array(_species_stats(_make_character(fake))).is_empty()
