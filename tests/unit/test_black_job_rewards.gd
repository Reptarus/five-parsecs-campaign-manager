extends GdUnitTestSuite
## Core Rules Appendix III pp.150-151 — Black Job advantages and victory rewards.
##
## `BlackZoneSystem.calculate_rewards()` returned the full p.151 payout and
## PaymentProcessor applied only PART of it: the credits, the ship-loan payoff,
## the Rival clear and the 2 Patrons landed, while `loot_rolls: 3` and
## `xp_bonus_all_crew: 1` were computed and read by NOBODY.
##
## `get_turn_advantages()` — the p.150 side — had ZERO callers, so the three free
## Weapon Table rolls and the Rival-interference immunity never existed at all.
##
## gdUnit4 v6.0.3 compatible.

const BlackZoneSystemClass = preload("res://src/core/mission/BlackZoneSystem.gd")
const StartingEquipmentGeneratorClass = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")


# ── p.151 victory rewards ───────────────────────────────────────────────────

## Verbatim, all five bullets: "Clear all Rivals. / Add 2 Patrons... Persistent
## across worlds. / Claim 5 bonus credits. If you owe money on a ship, Unity
## additionally pays off 5 credits of your loan. / Claim 3 rolls on the Loot
## Table. / Claim 1 bonus XP for every crew member you have, even if they did
## not participate in the battle."
func test_victory_rewards_match_the_book() -> void:
	var r: Dictionary = BlackZoneSystemClass.calculate_rewards({"success": true})
	assert_bool(r.get("is_victory", false)).is_true()
	assert_bool(r.get("clear_all_rivals", false)).is_true()
	assert_int(int(r.get("add_patrons", 0))).is_equal(2)
	assert_str(str(r.get("patron_type", ""))).is_equal("persistent")
	assert_int(int(r.get("bonus_credits", 0))).is_equal(5)
	assert_int(int(r.get("ship_loan_payoff", 0))).is_equal(5)
	assert_int(int(r.get("loot_rolls", 0))).override_failure_message(
		"p.151: 'Claim 3 rolls on the Loot Table'").is_equal(3)
	assert_int(int(r.get("xp_bonus_all_crew", 0))).override_failure_message(
		"p.151: '1 bonus XP for every crew member'").is_equal(1)


## "You get the normal post-battle rewards for a failed mission, and Unity pays
## 1 credit for every crew member who became a casualty."
func test_failure_pays_one_credit_per_casualty() -> void:
	var none: Dictionary = BlackZoneSystemClass.calculate_rewards({"success": false})
	assert_bool(none.get("is_victory", true)).is_false()
	assert_int(int(none.get("unity_casualty_pay", -1))).is_equal(0)

	var two: Dictionary = BlackZoneSystemClass.calculate_rewards({
		"success": false,
		"casualties": [{"crew_id": "a"}, {"crew_id": "b"}],
	})
	assert_int(int(two.get("unity_casualty_pay", -1))).override_failure_message(
		"1 credit per casualty; the old code read a `casualties_count` key no"
		+ " producer writes, so this always paid 0").is_equal(2)


# ── p.150 advantages ────────────────────────────────────────────────────────

## "Black Jobs are never subject to interference from Rivals." / "During a
## campaign turn where you will accept a Black Job, you do not have to pay any
## Upkeep, any ship loan does not increase, and your ship cannot be seized." /
## "You may roll three times on the Weapon Table."
func test_turn_advantages_match_the_book() -> void:
	var a: Dictionary = BlackZoneSystemClass.get_turn_advantages()
	assert_bool(a.get("no_rival_interference", false)).is_true()
	assert_bool(a.get("no_upkeep_payment", false)).is_true()
	assert_bool(a.get("ship_loan_no_increase", false)).is_true()
	assert_bool(a.get("ship_cannot_be_seized", false)).is_true()
	assert_int(int(a.get("free_weapon_rolls", 0))).override_failure_message(
		"p.150: 'You may roll THREE times on the Weapon Table'").is_equal(3)


## The three rolls have to land on real gear, or the advantage is three blanks.
## Also the shared door this now uses: gear_database.json is the SSOT, and the
## alternative was a third hand-rolled copy of the Military Weapon Table.
func test_the_weapon_table_roll_returns_real_gear() -> void:
	var seen := {}
	for attempt in 40:
		var name: String = StartingEquipmentGeneratorClass.roll_on_weapon_table(
			"military_weapon", null)
		assert_str(name).override_failure_message(
			"a Black Job weapon roll produced nothing").is_not_empty()
		seen[name] = true
	assert_int(seen.size()).override_failure_message(
		"40 D100 rolls produced only %d distinct weapons — the table is not"
		% seen.size() + " being rolled").is_greater(3)


## The D10 'Your Day in Hell' table (p.150-151) — five rows, and every roll must
## land on exactly one.
func test_your_day_in_hell_covers_every_roll() -> void:
	var seen := {}
	for attempt in 80:
		var m: Dictionary = BlackZoneSystemClass.roll_mission_type()
		assert_bool(m.is_empty()).override_failure_message(
			"roll_mission_type() returned nothing").is_false()
		seen[str(m.get("name", m.get("type", "?")))] = true
	assert_int(seen.size()).override_failure_message(
		"the D10 table produced only %s over 80 rolls" % str(seen.keys())
	).is_equal(5)
