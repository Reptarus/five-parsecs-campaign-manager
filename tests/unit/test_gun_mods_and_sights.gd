extends GdUnitTestSuite
## Gun Mods and Gun Sights — Core Rules p.53 (audit row 99).
##
## All 13 attachments shipped in `data/equipment_database.json` with byte-accurate
## p.53 effects, and all 13 are rollable off the p.131 Loot Table (`gun_mods`
## 1-20 and `gun_sights` 21-40 of the Gear subtable — a fifth of all gear loot).
## NOTHING could fit one to a weapon, so every one of them was an inventory line
## with no effect.
##
## The sharpest instance: `BattleCalculations.calculate_hit_modifier()` has
## implemented the Bipod clause verbatim since it was written, gated on
## `modifiers.has_bipod` — and a repo-wide search for a producer of that key
## returned NOTHING. A correct rule, a correct reader, a permanently-false input.
## Worse, the ONE live caller (`CharacterQuickRollPanel`) passed `modifiers = {}`,
## so Heavy's -1 and Snap Shot's +1 (both plain p.51 weapon traits) were dead too.
##
## gdUnit4 v6.0.3 compatible.

const ModsRef := preload("res://src/core/equipment/WeaponModService.gd")
const CalcRef := preload("res://src/core/battle/BattleCalculations.gd")

const MODS_SRC := "res://src/core/equipment/WeaponModService.gd"
const PANEL_SRC := "res://src/ui/components/battle/CharacterQuickRollPanel.gd"
const ASSIGN_SRC := "res://src/ui/screens/world/components/AssignEquipmentComponent.gd"


func _rifle() -> Dictionary:
	return {"id": "auto_rifle", "name": "Auto Rifle", "type": "Slug",
		"damage": 0, "range": 24, "shots": 2, "traits": []}


func _pistol() -> Dictionary:
	return {"id": "hand_cannon", "name": "Hand Cannon", "type": "Slug",
		"damage": 2, "range": 8, "shots": 1, "traits": ["Pistol"]}


func _code_only(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	var out: PackedStringArray = []
	for line in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# ── Data ────────────────────────────────────────────────────────────────────

func test_all_thirteen_attachments_load_with_the_right_split() -> void:
	## p.53 is 8 Gun Mods and 5 Gun Sights.
	var mods: Array = []
	var sights: Array = []
	for entry in ModsRef.all():
		if str(entry.get("type", "")) == "Gun Mod":
			mods.append(str(entry.get("id", "")))
		elif str(entry.get("type", "")) == "Gun Sight":
			sights.append(str(entry.get("id", "")))
	assert_int(mods.size()).is_equal(8)
	assert_int(sights.size()).is_equal(5)
	for m in ["assault_blade", "beam_light", "bipod", "hot_shot_pack",
			"nano_sludge", "stabilizer_mod", "shock_attachment", "upgrade_kit"]:
		assert_bool(m in mods).override_failure_message("missing Gun Mod %s" % m).is_true()
	for s in ["laser_sight", "quality_sight", "seeker_sight", "tracker_sight",
			"unity_battle_sight"]:
		assert_bool(s in sights).override_failure_message("missing Gun Sight %s" % s).is_true()


func test_normalize_id_resolves_loot_table_display_names() -> void:
	## These are the exact strings `data/loot_tables.json` rolls. If they did not
	## resolve, a looted attachment could never be recognised as one.
	assert_str(ModsRef.normalize_id("Assault Blade")).is_equal("assault_blade")
	assert_str(ModsRef.normalize_id("Hot Shot Pack")).is_equal("hot_shot_pack")
	assert_str(ModsRef.normalize_id("Cyber-configurable Nano-Sludge")) \
		.is_equal("nano_sludge")
	assert_str(ModsRef.normalize_id("Stabilizer")).is_equal("stabilizer_mod")
	assert_str(ModsRef.normalize_id("Unity Battle Sight")).is_equal("unity_battle_sight")
	assert_str(ModsRef.normalize_id("Blast Rifle")).is_equal("")


# ── Fitting restrictions (p.53) ─────────────────────────────────────────────

func test_non_pistol_only_mods_refuse_a_pistol() -> void:
	## "Assault blade ... Non-Pistol only." / "Bipod ... Non-Pistol only."
	for mod_id in ["assault_blade", "bipod"]:
		assert_bool(bool(ModsRef.can_fit(_pistol(), mod_id).get("ok", true))) \
			.override_failure_message("%s fitted to a Pistol" % mod_id).is_false()
		assert_bool(bool(ModsRef.can_fit(_rifle(), mod_id).get("ok", false))).is_true()


func test_laser_sight_is_pistol_only() -> void:
	## "Laser sight ... Pistol only."
	assert_bool(bool(ModsRef.can_fit(_pistol(), "laser_sight").get("ok", false))).is_true()
	assert_bool(bool(ModsRef.can_fit(_rifle(), "laser_sight").get("ok", true))).is_false()


func test_hot_shot_pack_fits_only_its_four_named_weapons() -> void:
	## "If fitted to a Blast Pistol, Blast Rifle, Hand Laser, or Infantry Laser"
	var blast := {"name": "Blast Rifle", "range": 16, "traits": []}
	assert_bool(bool(ModsRef.can_fit(blast, "hot_shot_pack").get("ok", false))).is_true()
	assert_bool(bool(ModsRef.can_fit(_rifle(), "hot_shot_pack").get("ok", true))).is_false()


func test_only_one_mod_per_weapon_and_mods_cannot_be_removed() -> void:
	## "A weapon can have only one mod." + "cannot be removed or reversed."
	var w := _rifle()
	assert_bool(bool(ModsRef.fit(w, "upgrade_kit").get("ok", false))).is_true()
	assert_str(ModsRef.fitted_mod(w)).is_equal("upgrade_kit")
	var second: Dictionary = ModsRef.fit(w, "bipod")
	assert_bool(bool(second.get("ok", true))) \
		.override_failure_message("fitted a SECOND Gun Mod").is_false()
	assert_str(ModsRef.fitted_mod(w)).is_equal("upgrade_kit")
	# There is deliberately no remove_mod() — adding one would invent a rule.
	# Scanned rather than probed: has_method() cannot be called on a class
	# reference (only on an instance), and this service is entirely static.
	assert_bool(_code_only(MODS_SRC).contains("func remove_mod")) \
		.override_failure_message(
			"remove_mod() exists, but p.53 says mods cannot be removed or reversed") \
		.is_false()
	assert_bool(_code_only(MODS_SRC).contains("func remove_sight")) \
		.override_failure_message("remove_sight() is required — Sights ARE movable") \
		.is_true()


func test_a_sight_may_be_replaced_and_the_old_one_comes_back() -> void:
	## "Sights can be fitted to a weapon or moved to a new one when equipment is
	## being assigned during the campaign turn." A displaced Sight is a physical
	## item and must not evaporate — one item, one home.
	var w := _rifle()
	assert_bool(bool(ModsRef.fit(w, "seeker_sight").get("ok", false))).is_true()
	var swap: Dictionary = ModsRef.fit(w, "unity_battle_sight")
	assert_bool(bool(swap.get("ok", false))).is_true()
	assert_str(str(swap.get("replaced", ""))).is_equal("seeker_sight")
	assert_str(ModsRef.fitted_sight(w)).is_equal("unity_battle_sight")
	assert_str(ModsRef.remove_sight(w)).is_equal("unity_battle_sight")
	assert_str(ModsRef.fitted_sight(w)).is_equal("")


# ── Derived weapon profile ──────────────────────────────────────────────────

func test_upgrade_kit_and_quality_sight_each_add_two_inches() -> void:
	var w := _rifle()
	ModsRef.fit(w, "upgrade_kit")
	assert_int(int(ModsRef.effective_weapon(w).get("range", 0))).is_equal(26)
	ModsRef.fit(w, "quality_sight")
	assert_int(int(ModsRef.effective_weapon(w).get("range", 0))).is_equal(28)


func test_effective_weapon_never_compounds() -> void:
	## Returns a COPY on purpose: applying it to the stored weapon would let a
	## second render add another +2", so a rifle would grow every time it was drawn.
	var w := _rifle()
	ModsRef.fit(w, "upgrade_kit")
	for _i in range(5):
		assert_int(int(ModsRef.effective_weapon(w).get("range", 0))).is_equal(26)
	assert_int(int(w.get("range", 0))).is_equal(24)


func test_assault_blade_grants_melee_and_damage() -> void:
	## "The weapon gains the Melee trait. Damage +1, and wins combat on a Draw."
	var w := _rifle()
	ModsRef.fit(w, "assault_blade")
	var eff: Dictionary = ModsRef.effective_weapon(w)
	assert_int(int(eff.get("damage", -99))).is_equal(1)
	var traits: Array = eff.get("traits", [])
	var lowered: Array = []
	for t in traits:
		lowered.append(str(t).to_lower())
	assert_bool("melee" in lowered).is_true()


func test_stabilizer_removes_the_heavy_trait() -> void:
	## "Weapon may ignore Heavy trait." Removing it from the profile is also what
	## removes the p.51 -1 for moving, since that penalty keys off the trait.
	var w := _rifle()
	w["traits"] = ["Heavy"]
	ModsRef.fit(w, "stabilizer_mod")
	var traits: Array = ModsRef.effective_weapon(w).get("traits", [])
	for t in traits:
		assert_str(str(t).to_lower()).is_not_equal("heavy")
	# And the penalty is gone at the maths layer, which is the point.
	assert_int(CalcRef.calculate_hit_modifier(0, 12.0, traits, true)).is_equal(0)
	assert_int(CalcRef.calculate_hit_modifier(0, 12.0, ["Heavy"], true)).is_equal(-1)


func test_shock_attachment_and_laser_sight_grant_their_traits() -> void:
	var w := _rifle()
	ModsRef.fit(w, "shock_attachment")
	var traits: Array = ModsRef.effective_weapon(w).get("traits", [])
	var lowered: Array = []
	for t in traits:
		lowered.append(str(t).to_lower())
	assert_bool("stun" in lowered).is_true()

	var p := _pistol()
	ModsRef.fit(p, "laser_sight")
	var ptraits: Array = ModsRef.effective_weapon(p).get("traits", [])
	var plower: Array = []
	for t in ptraits:
		plower.append(str(t).to_lower())
	assert_bool("snap shot" in plower).is_true()


func test_a_damaged_sight_grants_nothing() -> void:
	## "If the weapon is damaged, any Sight attached also becomes damaged." (p.53)
	var w := _rifle()
	ModsRef.fit(w, "quality_sight")
	assert_int(int(ModsRef.effective_weapon(w).get("range", 0))).is_equal(26)
	ModsRef.propagate_damage_to_sight(w)
	assert_bool(ModsRef.sight_is_damaged(w)).is_true()
	assert_int(int(ModsRef.effective_weapon(w).get("range", 0))) \
		.override_failure_message("a damaged Sight still granted its bonus").is_equal(24)
	assert_int(int(ModsRef.hit_inputs(w).get("flat_hit_bonus", -1))).is_equal(0)


func test_damage_does_not_flag_a_sight_that_is_not_there() -> void:
	var w := _rifle()
	ModsRef.propagate_damage_to_sight(w)
	assert_bool(ModsRef.sight_is_damaged(w)).is_false()


# ── Battle inputs: the key nothing produced ─────────────────────────────────

func test_bipod_finally_produces_the_key_the_maths_reads() -> void:
	## `has_bipod` has been read by BattleCalculations since it was written and
	## had ZERO producers repo-wide. This is that producer.
	var w := _rifle()
	assert_bool(bool(ModsRef.hit_inputs(w).get("has_bipod", true))).is_false()
	ModsRef.fit(w, "bipod")
	assert_bool(bool(ModsRef.hit_inputs(w).get("has_bipod", false))).is_true()


func test_bipod_bonus_applies_only_over_eight_inches_when_aiming_or_in_cover() -> void:
	## "+1 to Hit at ranges over 8" when Aiming or when firing from Cover."
	## Each clause asserted separately, so a fix that drops one is caught.
	assert_int(CalcRef.calculate_hit_modifier(0, 12.0, [], false, true, true, false)) \
		.is_equal(1)
	assert_int(CalcRef.calculate_hit_modifier(0, 12.0, [], false, true, false, true)) \
		.is_equal(1)
	# Not aiming, not in cover.
	assert_int(CalcRef.calculate_hit_modifier(0, 12.0, [], false, true, false, false)) \
		.is_equal(0)
	# 8" is not "over 8".
	assert_int(CalcRef.calculate_hit_modifier(0, 8.0, [], false, true, true, false)) \
		.is_equal(0)
	# Pistol excluded.
	assert_int(CalcRef.calculate_hit_modifier(
		0, 12.0, ["Pistol"], false, true, true, false)).is_equal(0)


func test_flat_hit_bonuses_from_nano_sludge_and_unity_sight() -> void:
	## Nano-sludge "permanent +1 Hit bonus"; Unity Battle Sight "+1 to all Hit rolls".
	var w := _rifle()
	ModsRef.fit(w, "nano_sludge")
	assert_int(int(ModsRef.hit_inputs(w).get("flat_hit_bonus", 0))).is_equal(1)
	ModsRef.fit(w, "unity_battle_sight")
	assert_int(int(ModsRef.hit_inputs(w).get("flat_hit_bonus", 0))) \
		.override_failure_message("a Mod and a Sight bonus must both count").is_equal(2)
	# And the maths layer actually applies them.
	assert_int(CalcRef.calculate_hit_modifier(0, 12.0, [], false, false, false, false, 2)) \
		.is_equal(2)


func test_conditional_sights_are_reported_as_conditions_not_bonuses() -> void:
	## Seeker ("if the shooter did not Move this round") and Tracker ("if you
	## fired at the same target during your previous round") depend on battle
	## state the app cannot know, so the service must hand back a FLAG for the
	## caller to answer — silently granting them would be inventing the condition.
	var w := _rifle()
	ModsRef.fit(w, "seeker_sight")
	var seeker: Dictionary = ModsRef.hit_inputs(w)
	assert_bool(bool(seeker.get("seeker_sight", false))).is_true()
	assert_int(int(seeker.get("flat_hit_bonus", -1))).is_equal(0)

	ModsRef.fit(w, "tracker_sight")
	var tracker: Dictionary = ModsRef.hit_inputs(w)
	assert_bool(bool(tracker.get("tracker_sight", false))).is_true()
	assert_int(int(tracker.get("flat_hit_bonus", -1))).is_equal(0)


func test_hot_shot_pack_reports_its_overheat() -> void:
	## "Any natural 6 on the shooting dice causes an overheat, rendering the
	## weapon inoperable for the rest of the fight."
	var w := {"name": "Blast Rifle", "range": 16, "damage": 1, "traits": []}
	ModsRef.fit(w, "hot_shot_pack")
	assert_bool(bool(ModsRef.hit_inputs(w).get("overheats_on_natural_6", false))).is_true()
	assert_int(int(ModsRef.effective_weapon(w).get("damage", 0))).is_equal(2)


# ── Delivery: the wires exist on the live paths ─────────────────────────────

func test_quick_roll_panel_no_longer_passes_an_empty_modifiers_dict() -> void:
	## The regression this whole row is about. `var modifiers := {}` at the only
	## live caller made Heavy, Snap Shot AND Bipod unreachable at once.
	var src: String = _code_only(PANEL_SRC)
	assert_bool(src.contains("var modifiers := {}")) \
		.override_failure_message(
			"CharacterQuickRollPanel is passing an EMPTY modifiers dict again —"
			+ " Heavy, Snap Shot and Bipod all stop applying").is_false()
	for key in ["\"weapon_traits\":", "\"firer_moved\":", "\"has_bipod\":",
			"\"is_aiming\":", "\"firer_in_cover\":", "\"mod_bonus\":"]:
		assert_bool(src.contains(key)) \
			.override_failure_message("modifiers bag is missing %s" % key).is_true()


func test_assign_equipment_can_fit_an_attachment() -> void:
	## p.53 puts the fitting step on this exact screen: Sights are moved "when
	## equipment is being assigned during the campaign turn".
	var src: String = _code_only(ASSIGN_SRC)
	assert_bool(src.contains("WeaponModServiceRef.fit(")).is_true()
	assert_bool(src.contains("WeaponModServiceRef.can_fit(")).is_true()
	assert_bool(src.contains("WeaponModServiceRef.summary_tag(")).is_true()
