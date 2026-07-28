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
## SCOPE, honestly stated. An earlier audit refuted this on the grounds that
## ShiplessSystem (the interest ladder and seizure roll) has ZERO callers — and that
## is correct, those mechanics cannot run today, so "the ship can never be seized"
## is NOT a live consequence. What IS live is the Black Zone victory: it decrements
## a field that is always 0 and then writes a journal milestone reading "Ship loan
## reduced by 5" (PaymentProcessor.gd:222-225). The player is told it happened and
## the displayed debt never moves. The rest is a latent trap: whoever wires up
## interest or seizure would read a field that is permanently 0.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


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
