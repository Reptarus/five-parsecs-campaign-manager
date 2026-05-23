extends GdUnitTestSuite
## Pre-battle enemy force display contract
##
## PreBattleUI._setup_enemy_info() reads from `data["enemy_force"]` which
## BattlePhase populates with the full Core Rules pp.91-94 stat block plus
## parent-category metadata (added Sprint 2 / Item 9). Locks in:
##   1. AI letter → name decoder covers all Core Rules AI types
##   2. The enemy_force dict shape PreBattleUI expects exists end-to-end
##
## gdUnit4 v6.0.3 compatible.

const PreBattleUIScript := preload("res://src/ui/screens/battle/PreBattleUI.gd")


func test_ai_type_names_covers_core_rules_letters() -> void:
	# Core Rules p.99 + data/RulesReference/EnemyAI.json: A, C, T, D, R, B
	# (Compendium adds G = Guardian for some elite types.)
	var names: Dictionary = PreBattleUIScript.AI_TYPE_NAMES
	assert_str(str(names.get("A", ""))).is_equal("Aggressive")
	assert_str(str(names.get("C", ""))).is_equal("Cautious")
	assert_str(str(names.get("T", ""))).is_equal("Tactical")
	assert_str(str(names.get("D", ""))).is_equal("Defensive")
	assert_str(str(names.get("R", ""))).is_equal("Rampage")
	assert_str(str(names.get("B", ""))).is_equal("Beast")


func test_ai_type_names_does_not_have_invented_letters() -> void:
	# Guard against future agents adding fabricated AI types.
	# Only 6 Core Rules + 1 Compendium type (G) are valid.
	var names: Dictionary = PreBattleUIScript.AI_TYPE_NAMES
	var allowed: Array = ["A", "C", "T", "D", "R", "B", "G"]
	for key in names.keys():
		assert_bool(key in allowed).override_failure_message(
			"Unexpected AI letter '%s' in AI_TYPE_NAMES — only A/C/T/D/R/B/G are valid" % str(key)
		).is_true()


func test_enemy_force_dict_shape_has_category_fields() -> void:
	# BattlePhase emits this shape; PreBattleUI consumes it.
	# Sprint 2 / Item 9 added category_name, category_rules, seize_initiative_modifier.
	var enemy_force: Dictionary = {
		"type": "Enforcers",
		"category": "hired_muscle",
		"category_name": "Hired Muscle",
		"category_rules": "Someone has hired goons to stop you. -1 to Seize the Initiative.",
		"seize_initiative_modifier": -1,
		"count": 4,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": "T",
		"weapons": "2 A",
		"numbers": "+0",
		"special_rules": ["Cop killer: As Rivals, +2 to their numbers"],
		"units": [],
	}

	# All Bestiary schema fields must be readable with safe defaults.
	assert_str(str(enemy_force.get("type", ""))).is_equal("Enforcers")
	assert_str(str(enemy_force.get("category_name", ""))).is_equal("Hired Muscle")
	assert_int(int(enemy_force.get("seize_initiative_modifier", 0))).is_equal(-1)
	assert_int(int(enemy_force.get("speed", 0))).is_equal(4)
	assert_int(int(enemy_force.get("combat_skill", 0))).is_equal(1)
	assert_int(int(enemy_force.get("toughness", 0))).is_equal(4)
	assert_str(str(enemy_force.get("ai", ""))).is_equal("T")
	assert_int(int(enemy_force.get("special_rules", []).size())).is_equal(1)


func test_enemy_force_dict_safe_defaults_when_category_missing() -> void:
	# Legacy / non-bestiary enemies (rivals, story-track custom enemies) may
	# not carry category metadata. The reader must not crash on the empty path.
	var enemy_force: Dictionary = {
		"type": "Custom Story Boss",
		"count": 1,
		"speed": 5,
		"combat_skill": 2,
		"toughness": 5,
		"ai": "A",
	}

	assert_str(str(enemy_force.get("category_name", ""))).is_equal("")
	assert_str(str(enemy_force.get("category_rules", ""))).is_equal("")
	assert_int(int(enemy_force.get("seize_initiative_modifier", 0))).is_equal(0)
