extends GdUnitTestSuite
## Ship debt has ONE owner: campaign.ship_debt.
##
## THE BUG THIS EXISTS TO PREVENT
## Debt lived in two unreconciled places:
##   campaign.ship_debt  - what the RULES code reads/writes (Black Zone loan payoff
##                         PaymentProcessor.gd:205-209, Planetfall independence
##                         prepayment, ShiplessSystem's interest ladder + p.76 seizure)
##   ship_data["debt"]   - what CREATION and every DISPLAY use (ShipPanel:921,
##                         ShipManager:269/315, TradePhasePanel:780)
##
## The bridge meant to join them (CampaignFinalizationService.gd:347-351) called
## set_ship_debt(ship_data.get("debt", 0)), and set_ship_debt did
## `c.ship_data["debt"] = amount` — it read the nested field and wrote the SAME
## nested field back. A self-copy. campaign.ship_debt was never touched.
##
## Measured across all 15 real 5PFH saves on disk: ship_debt = 0 in every one while
## ship.debt ranged 12-36.
##
## SCOPE UPDATE (Aug 2 2026). This file used to say the interest ladder and the
## seizure roll "cannot run today", so a permanently-zero owner was only a latent
## trap. That is no longer true: CampaignPhaseManager._process_ship_debt() now
## calls ShiplessSystem.process_debt_interest() at every turn rollover, so the
## owner field is read by the live p.76 mechanics and the ownership fix above is
## what keeps the loan from silently reading 0. The interest ladder itself is
## pinned by the tests at the bottom of this file.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const Shipless = preload("res://src/core/ship/ShiplessSystem.gd")


func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


var _previous = null
var _swapped := false


func after_test() -> void:
	## Restore in a lifecycle hook — GameState is a live autoload.
	if not _swapped:
		return
	var gs := _gs()
	if gs:
		gs.current_campaign = _previous
	_previous = null
	_swapped = false


func _install(campaign) -> void:
	var gs := _gs()
	if gs == null:
		return
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = campaign


# --- the load-time migration --------------------------------------------------

func test_a_legacy_save_seeds_the_owner_from_the_nested_field() -> void:
	# Exactly the shape of all 15 real saves: no top-level ship_debt, a real loan
	# sitting in ship.debt.
	var campaign = CampaignCore.new()
	campaign.from_dictionary({
		"campaign_id": "legacy_debt",
		"ship": {"name": "Void Runner", "debt": 24},
	})
	assert_int(int(campaign.ship_debt)).override_failure_message(
		"the starting loan stayed invisible to the rules code after load"
	).is_equal(24)


func test_the_migration_does_not_clobber_a_real_owner_value() -> void:
	# Idempotence: once the owner holds a value it wins, including a paid-down one.
	var campaign = CampaignCore.new()
	campaign.from_dictionary({
		"campaign_id": "paid_down",
		"ship_debt": 9,
		"ship": {"debt": 24},
	})
	assert_int(int(campaign.ship_debt)).is_equal(9)


func test_no_debt_anywhere_stays_zero() -> void:
	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "debt_free", "ship": {"name": "Free"}})
	assert_int(int(campaign.ship_debt)).is_equal(0)


# --- the accessors ------------------------------------------------------------

func test_the_setter_writes_the_owner_not_just_the_mirror() -> void:
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "debt": 24})
	_install(campaign)

	gsm.set_ship_debt(17)

	assert_int(int(campaign.ship_debt)).override_failure_message(
		"set_ship_debt still only touched the nested field — the self-copy bug"
	).is_equal(17)


func test_the_setter_keeps_the_display_mirror_in_sync() -> void:
	# ShipPanel / ShipManager / TradePhasePanel all render the nested field, so it
	# must follow the owner or the screens would show a stale loan.
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "debt": 24})
	_install(campaign)

	gsm.set_ship_debt(17)

	assert_int(int(campaign.ship_data.get("debt", -1))).is_equal(17)


func test_the_getter_falls_back_when_only_the_nested_field_is_set() -> void:
	# Creation and the ship screen still write ship_data["debt"] directly, so a
	# getter that read only the owner would report a debt-free ship.
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "debt": 24})
	campaign.ship_debt = 0
	_install(campaign)

	assert_int(int(gsm.get_ship_debt())).is_equal(24)


func test_the_black_zone_payoff_now_reduces_a_real_debt() -> void:
	# The one LIVE consequence: PaymentProcessor did
	# `campaign.ship_debt = maxi(0, campaign.ship_debt - payoff)` against a field
	# that was always 0, then logged "Ship loan reduced by 5".
	var campaign = CampaignCore.new()
	campaign.from_dictionary({"campaign_id": "bz", "ship": {"debt": 24}})
	campaign.ship_debt = maxi(0, campaign.ship_debt - 5)   # the real reward line
	assert_int(int(campaign.ship_debt)).override_failure_message(
		"the Black Zone payoff still decremented nothing while claiming it did"
	).is_equal(19)


# --- the p.76 interest ladder, now that it actually runs ----------------------

## Core Rules p.76: "the amount is now increased by 1 credit (2 credits if you
## owe 31 credits or more)". The boundary is what matters: 30 pays 1, 31 pays 2.
func test_interest_ladder_matches_the_book_at_the_boundary() -> void:
	for pair: Array in [[1, 1], [30, 1], [31, 2], [50, 2]]:
		var campaign = CampaignCore.new()
		campaign.ship_debt = pair[0]
		campaign.has_ship = true
		var result: Dictionary = Shipless.process_debt_interest(campaign)
		assert_int(int(result.get("interest", 0))).override_failure_message(
			"a debt of %d should accrue %d credits of interest" % [pair[0], pair[1]]
		).is_equal(pair[1])
		assert_int(int(campaign.ship_debt)).is_equal(pair[0] + pair[1])


## p.76: "If this brings the total to 75 credits or more, roll 2D6." The check is
## made AFTER the interest is added, so a debt of 74 crosses on the same turn.
func test_seizure_risk_arms_only_at_75_after_interest() -> void:
	var below = CampaignCore.new()
	below.ship_debt = 60
	below.has_ship = true
	assert_bool(bool(Shipless.process_debt_interest(below).get("seizure_risk", true))
		).override_failure_message("60 credits must not arm seizure").is_false()

	var crossing = CampaignCore.new()
	crossing.ship_debt = 73   # +2 at 31+, so 75 exactly
	crossing.has_ship = true
	assert_bool(bool(Shipless.process_debt_interest(crossing).get("seizure_risk", false))
		).override_failure_message(
			"the threshold is checked AFTER interest, so 73 must arm it"
		).is_true()


## A debt-free crew must never be charged.
func test_no_debt_accrues_no_interest() -> void:
	var campaign = CampaignCore.new()
	campaign.ship_debt = 0
	campaign.has_ship = true
	assert_int(int(Shipless.process_debt_interest(campaign).get("interest", -1))).is_equal(0)
	assert_int(int(campaign.ship_debt)).is_equal(0)
