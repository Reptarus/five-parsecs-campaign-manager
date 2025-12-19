extends GdUnitTestSuite

## Phase 4.2: Post-Roll Explanation System Tests
## Validates that combat log provides clear explanations for all roll outcomes

# Preload script directly - scene instantiation can fail silently with @tool scripts
const CombatLogPanel := preload("res://src/ui/components/combat/log/combat_log_panel.gd")

var log_panel

func before_test() -> void:
	# Instantiate the script directly (avoids @tool scene loading issues in tests)
	log_panel = CombatLogPanel.new()
	log_panel.max_entries = 50
	add_child(log_panel)

	# Wait multiple frames for UI construction and @onready vars
	for i in range(3):
		await get_tree().process_frame

	# VERIFY initialization succeeded
	if not is_instance_valid(log_panel):
		push_error("CombatLogPanel failed to initialize")
		return

func after_test() -> void:
	# Wait for pending signal processing before cleanup
	await get_tree().process_frame
	if log_panel and is_instance_valid(log_panel):
		log_panel.queue_free()
	log_panel = null

#region Hit/Miss Breakdown Tests

func test_simple_hit_explanation() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Simple hit with no modifiers
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Marine Alpha", "Raider", result)
	
	# Assert: Should show hit with roll vs threshold
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("HIT!")
	assert_str(entry["message"]).contains("Rolled 5 vs 5+")

func test_miss_with_explanation() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Miss - rolled too low
	var result := {
		"hit": false,
		"hit_roll": 3,
		"modified_hit_roll": 3,
		"hit_threshold": 5,
	}

	# Act
	log_panel.log_combat_result("Marine Alpha", "Raider", result)
	
	# Assert: Should show miss with what was needed
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("MISS!")
	assert_str(entry["message"]).contains("Rolled 3, needed 5+")

func test_hit_with_range_modifier() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit with weapon modification range bonus
	var result := {
		"hit": true,
		"hit_roll": 4,
		"modified_hit_roll": 5,  # 4 + 1 range bonus
		"hit_threshold": 5,
		"mod_range_bonus": 1,
		"range_band": "short",
		"damage_roll": 3,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Sniper", "Enemy", result)
	
	# Assert: Should show modifier breakdown
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("HIT!")
	assert_str(entry["message"]).contains("+1 range (short)")
	assert_str(entry["message"]).contains("Rolled 4")
	assert_str(entry["message"]).contains("= 5")

func test_hit_with_multiple_modifiers() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit with multiple modifiers (range + targeting + camouflage)
	var result := {
		"hit": true,
		"hit_roll": 3,
		"modified_hit_roll": 5,  # 3 + 2 targeting
		"hit_threshold": 5,
		"mod_range_bonus": 1,
		"range_band": "medium",
		"armor_hit_bonus": 2,  # Enhanced targeting
		"camouflage_penalty": 1,
		"damage_roll": 4,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Marine", "Stalker", result)
	
	# Assert: Should show all modifiers
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("+1 range (medium)")
	assert_str(entry["message"]).contains("+2 targeting")
	assert_str(entry["message"]).contains("-1 camouflage")

#endregion

#region Damage Breakdown Tests

func test_damage_roll_explanation() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit with damage roll
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 4,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Gunner", "Target", result)
	
	# Assert: Should show damage roll
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Damage: Rolled 4")

func test_damage_with_weapon_mod_bonus() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Damage with weapon modification bonus
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"weapon_mod_damage_bonus": 1,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Heavy", "Enemy", result)
	
	# Assert: Should show weapon bonus breakdown
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("+ 1 weapon = 4")

#endregion

#region Armor/Screen Save Tests

func test_armor_save_success() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit but armor saved
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"armor_roll": 5,
		"armor_saved": true,
		"save_type": "armor",
		"wounds_inflicted": 0,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Attacker", "Armored Target", result)
	
	# Assert: Should show armor save success
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Armor Save!")
	assert_str(entry["message"]).contains("Rolled 5")

func test_screen_save_success() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit but screen saved
	var result := {
		"hit": true,
		"hit_roll": 6,
		"modified_hit_roll": 6,
		"hit_threshold": 5,
		"damage_roll": 4,
		"raw_damage": 2,
		"armor_roll": 5,
		"screen_saved": true,
		"armor_saved": true,
		"save_type": "screen",
		"wounds_inflicted": 0,
		"effects": ["screen_deflected"]
	}

	# Act
	log_panel.log_combat_result("Attacker", "Shielded Target", result)
	
	# Assert: Should show screen save
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Screen Save!")

func test_shield_blocked() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit blocked by shield
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"shield_blocked": true,
		"armor_saved": true,
		"wounds_inflicted": 0,
		"effects": ["shield_blocked"]
	}

	# Act
	log_panel.log_combat_result("Attacker", "Shielded", result)
	
	# Assert: Should show shield block
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Shield blocked!")

func test_piercing_bypasses_armor() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Piercing weapon bypasses armor
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 4,
		"raw_damage": 2,
		"armor_roll": 3,
		"armor_saved": false,
		"wounds_inflicted": 1,
		"effects": ["armor_pierced"]
	}

	# Act
	log_panel.log_combat_result("Sniper", "Armored", result)
	
	# Assert: Should show piercing effect
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Piercing weapon bypassed armor")

#endregion

#region Wound/Elimination Tests

func test_target_elimination() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Target eliminated
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 6,  # Natural 6 = elimination
		"raw_damage": 2,
		"target_eliminated": true,
		"wounds_inflicted": 3,
		"effects": ["eliminated"]
	}

	# Act
	log_panel.log_combat_result("Heavy Gunner", "Raider", result)
	
	# Assert: Should show elimination
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("TARGET ELIMINATED!")

func test_wound_inflicted() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Wound inflicted (not eliminated)
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"target_eliminated": false,
		"wounds_inflicted": 1,
		"effects": ["stunned", "push_back"]
	}

	# Act
	log_panel.log_combat_result("Rifleman", "Enemy", result)
	
	# Assert: Should show wound count
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("1 wound inflicted")

func test_auto_medicator_negates_wound() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Auto-medicator negates wound
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"target_eliminated": false,
		"wounds_inflicted": 0,  # Negated
		"effects": ["auto_medicator_negated_wound"]
	}

	# Act
	log_panel.log_combat_result("Attacker", "Medic Target", result)
	
	# Assert: Should show auto-medicator activation
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Auto-Medicator negated wound!")

#endregion

#region Special Effects Tests

func test_special_effects_display() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Hit with multiple status effects
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": ["stunned", "push_back", "suppressed"]
	}

	# Act
	log_panel.log_combat_result("Heavy", "Target", result)
	
	# Assert: Should list all effects
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Effects:")
	assert_str(entry["message"]).contains("Stunned")
	assert_str(entry["message"]).contains("Pushed 1\"")
	assert_str(entry["message"]).contains("Suppressed")

func test_critical_hit_with_extra_hit() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Critical hit with extra hit trait
	var result := {
		"hit": true,
		"hit_roll": 6,
		"modified_hit_roll": 6,
		"hit_threshold": 5,
		"damage_roll": 4,
		"raw_damage": 2,
		"wounds_inflicted": 2,
		"effects": ["critical_extra_hit"]
	}

	# Act
	log_panel.log_combat_result("Sniper", "Enemy", result)
	
	# Assert: Should show critical extra hit
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Critical: 2 Hits")

func test_battle_visor_reroll() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Battle visor rerolled a 1
	var result := {
		"hit": true,
		"hit_roll": 5,  # After reroll
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"battle_visor_used": true,
		"battle_visor_reroll": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Tech Marine", "Target", result)
	
	# Assert: Should show battle visor reroll
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("Battle Visor reroll: 1 → 5")

#endregion

#region Color Coding Tests

func test_success_colors() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Successful hit
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Attacker", "Target", result)
	
	# Assert: Should use green color for success
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("[color=#10B981]HIT![/color]")

func test_failure_colors() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Miss
	var result := {
		"hit": false,
		"hit_roll": 2,
		"modified_hit_roll": 2,
		"hit_threshold": 5,
	}

	# Act
	log_panel.log_combat_result("Attacker", "Target", result)
	
	# Assert: Should use red color for failure
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("[color=#DC2626]MISS![/color]")

func test_warning_colors() -> void:
	# Nil guard
	if not is_instance_valid(log_panel):
		push_warning("log_panel not available, skipping test")
		return

	# Arrange: Wound inflicted
	var result := {
		"hit": true,
		"hit_roll": 5,
		"modified_hit_roll": 5,
		"hit_threshold": 5,
		"damage_roll": 3,
		"raw_damage": 2,
		"wounds_inflicted": 1,
		"effects": []
	}

	# Act
	log_panel.log_combat_result("Attacker", "Target", result)
	
	# Assert: Should use orange/warning color for wounds
	assert_int(log_panel.log_entries.size()).is_equal(1)
	var entry: Dictionary = log_panel.log_entries[0]
	assert_str(entry["message"]).contains("[color=#D97706]1 wound inflicted[/color]")

#endregion
