extends GdUnitTestSuite
## Injury Table rows whose upside was never paid (Core Rules p.122).
##
## THE GAP THESE PIN. data/injury_results.json has always carried the right
## values for both rows; nothing read them.
##
##   16 "Miraculous escape — The character survives and receives +1 Luck, but
##      all items carried are permanently lost." The JSON row carries
##      luck_bonus: 1. INJURY_PROPERTIES never exposed it and there was no
##      accessor, so the single best non-fatal outcome in the game did
##      literally nothing — no Luck, and every item kept.
##
##   96-100 "School of hard knocks — Earn 1 XP". InjuryProcessor computed
##      bonus_xp and stored it in the result dict, and the only consumer of that
##      key anywhere is Planetfall's panel. On the 5PFH path the book's
##      consolation prize for being downed was silently withheld every time.

const InjuryConstants = preload("res://src/core/systems/InjurySystemConstants.gd")


## The 96-100 row must expose its XP.
func test_school_of_hard_knocks_exposes_its_xp() -> void:
	assert_int(InjuryConstants.get_bonus_xp(
		InjuryConstants.InjuryType.HARD_KNOCKS)
	).override_failure_message(
		"p.122 96-100 pays 1 XP"
	).is_equal(1)


## The 16 row must expose its Luck.
func test_miraculous_escape_exposes_its_luck() -> void:
	assert_int(InjuryConstants.get_luck_bonus(
		InjuryConstants.InjuryType.MIRACULOUS_ESCAPE)
	).override_failure_message(
		"p.122 roll 16 grants +1 Luck; the JSON carries it and nothing read it"
	).is_equal(1)


## "...but all items carried are permanently lost" — the row is not pure upside.
func test_miraculous_escape_still_costs_every_item() -> void:
	assert_bool(InjuryConstants.causes_equipment_loss(
		InjuryConstants.InjuryType.MIRACULOUS_ESCAPE)
	).override_failure_message(
		"p.122 roll 16 loses all carried items"
	).is_true()


## Rows with no bonus must not accidentally gain one.
func test_ordinary_injuries_pay_nothing() -> void:
	for injury: int in [
		InjuryConstants.InjuryType.MINOR_INJURY,
		InjuryConstants.InjuryType.EQUIPMENT_LOSS,
	]:
		assert_int(InjuryConstants.get_luck_bonus(injury)).is_equal(0)
		assert_int(InjuryConstants.get_bonus_xp(injury)).is_equal(0)


## Fatal rows carry no consolation bonus.
func test_fatal_rows_pay_nothing() -> void:
	for injury: int in [
		InjuryConstants.InjuryType.GRUESOME_FATE,
		InjuryConstants.InjuryType.FATAL,
	]:
		assert_int(InjuryConstants.get_luck_bonus(injury)).is_equal(0)
		assert_int(InjuryConstants.get_bonus_xp(injury)).is_equal(0)
