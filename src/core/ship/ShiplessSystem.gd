class_name ShiplessSystem
extends RefCounted

## Being Without a Ship — Core Rules p.59
##
## Handles the game state when the crew's ship is destroyed during travel.
## Provides mechanics for commercial passage, stash limits, and ship acquisition.
##
## Usage:
##   ShiplessSystem.apply_ship_destruction(campaign)
##   var cost = ShiplessSystem.get_commercial_passage_cost(crew_size)
##   var offer = ShiplessSystem.roll_ship_offer()

# MARK: - Constants

## Maximum items in stash when shipless (Core Rules p.59)
const SHIPLESS_STASH_LIMIT := 5

## Maximum items per crew member to keep after ship destruction
const ITEMS_PER_CREW_ON_DESTRUCTION := 2

## Commercial passage cost per crew member
const COMMERCIAL_PASSAGE_COST_PER_CREW := 1

## Maximum amount that can be financed for a new ship
const MAX_SHIP_FINANCING := 70

## Ship debt interest thresholds
const LOW_DEBT_THRESHOLD := 30
const LOW_DEBT_INTEREST := 1
const HIGH_DEBT_INTEREST := 2

## Ship seizure threshold and risk
const SEIZURE_DEBT_THRESHOLD := 75
const SEIZURE_ROLL_MAX := 6  # Roll 2D6, on 2-6 ship seized

# MARK: - Ship Destruction

## Apply ship destruction consequences (Core Rules p.59).
## Loses all credits, keeps only 2 items per crew member.
## Returns Dictionary describing what was lost.
static func apply_ship_destruction(campaign: Resource) -> Dictionary:
	var lost_items: Array = []
	var lost_credits: int = 0

	# Lose all credits — route through GameStateManager for single-source-of-truth
	if "credits" in campaign:
		lost_credits = campaign.credits
		var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() else null
		if gsm and gsm.has_method("set_credits"):
			gsm.set_credits(0)
		else:
			campaign.credits = 0  # lint:ignore — fallback when GSM unavailable (static method)

	# Mark ship as destroyed
	if "has_ship" in campaign:
		campaign.has_ship = false

	# Clear ship debt (ship is gone, debt remains — Core Rules doesn't
	# explicitly state debt is cleared, but ship is destroyed)
	# Note: If debt was to a financier, this could be a plot hook

	# Stash limit enforcement — keep only 2 items per crew member
	var crew_size: int = 0
	if campaign.has_method("get_crew_members"):
		crew_size = campaign.get_crew_members().size()
	elif "crew_data" in campaign:
		crew_size = campaign.crew_data.get("members", []).size()

	var max_items: int = crew_size * ITEMS_PER_CREW_ON_DESTRUCTION
	# The actual item removal would be done by the UI (player chooses)
	# We just report the limit

	return {
		"ship_destroyed": true,
		"credits_lost": lost_credits,
		"max_items_allowed": max_items,
		"stash_limit": SHIPLESS_STASH_LIMIT,
		"description": "Ship destroyed! Lost %d credits. Keep only %d items (%d per crew member). Stash limited to %d items." % [
			lost_credits, max_items, ITEMS_PER_CREW_ON_DESTRUCTION, SHIPLESS_STASH_LIMIT
		]
	}

# MARK: - Commercial Passage

## Get cost of commercial passage (1 credit per crew member).
## Cannot carry packages or deliverable cargo.
static func get_commercial_passage_cost(crew_size: int) -> int:
	return crew_size * COMMERCIAL_PASSAGE_COST_PER_CREW

## Check if crew can afford commercial passage.
static func can_afford_passage(credits: int, crew_size: int) -> bool:
	return credits >= get_commercial_passage_cost(crew_size)

# MARK: - Ship Acquisition

## Roll for a new ship offer (Core Rules p.59).
## Cost = (2D6+3) * 10 credits. Can finance up to 70.
## Returns Dictionary with ship details and financing options.
static func roll_ship_offer() -> Dictionary:
	var roll: int = randi_range(1, 6) + randi_range(1, 6) + 3
	var cost: int = roll * 10

	var can_finance: bool = true
	var max_financed: int = mini(cost, MAX_SHIP_FINANCING)
	var min_down_payment: int = cost - max_financed

	return {
		"roll": roll,
		"cost": cost,
		"can_finance": can_finance,
		"max_financed": max_financed,
		"min_down_payment": min_down_payment,
		"description": "Ship available for %d credits (roll %d × 10). Finance up to %d, min down payment %d." % [
			cost, roll, max_financed, min_down_payment
		]
	}

## Purchase a new ship. Returns true on success.
## down_payment: credits paid upfront.
## financed: amount added to ship_debt.
static func purchase_ship(
	campaign: Resource, down_payment: int, financed: int
) -> Dictionary:
	var total: int = down_payment + financed

	if financed > MAX_SHIP_FINANCING:
		return {"success": false, "reason": "Cannot finance more than %d credits" % MAX_SHIP_FINANCING}

	if "credits" in campaign and campaign.credits < down_payment:
		return {"success": false, "reason": "Insufficient credits for down payment"}

	# Deduct down payment
	if "credits" in campaign:
		campaign.credits -= down_payment

	# Set debt
	if "ship_debt" in campaign:
		campaign.ship_debt = financed

	# Mark as having ship
	if "has_ship" in campaign:
		campaign.has_ship = true

	return {
		"success": true,
		"cost": total,
		"down_payment": down_payment,
		"financed": financed,
		"description": "Ship purchased for %d credits (%d down, %d financed)." % [
			total, down_payment, financed
		]
	}

# MARK: - Debt Management (Per Campaign Turn)

## Process ship debt interest for the current campaign turn.
## Returns Dictionary with interest applied and seizure risk.
static func process_debt_interest(campaign: Resource) -> Dictionary:
	if not ("ship_debt" in campaign) or campaign.ship_debt <= 0:
		return {"interest": 0, "seizure_risk": false}

	# Calculate interest (Core Rules p.59)
	var interest: int
	if campaign.ship_debt <= LOW_DEBT_THRESHOLD:
		interest = LOW_DEBT_INTEREST  # +1 per turn if <= 30
	else:
		interest = HIGH_DEBT_INTEREST  # +2 per turn if > 30

	campaign.ship_debt += interest

	# Check for seizure risk
	# Core Rules p.76: "75 credits or more" triggers seizure risk
	var seizure_risk: bool = campaign.ship_debt >= SEIZURE_DEBT_THRESHOLD
	var ship_seized: bool = false

	if seizure_risk:
		# Roll 2D6. On 2-6, ship is seized and lost.
		var seizure_roll: int = randi_range(1, 6) + randi_range(1, 6)
		if seizure_roll <= SEIZURE_ROLL_MAX:
			ship_seized = true
			campaign.has_ship = false
			campaign.ship_debt = 0

	return {
		"interest": interest,
		"new_debt": campaign.ship_debt,
		"seizure_risk": seizure_risk,
		"ship_seized": ship_seized,
		"description": "Debt interest +%d (total: %d).%s" % [
			interest, campaign.ship_debt,
			" SHIP SEIZED!" if ship_seized else (
				" WARNING: Seizure risk!" if seizure_risk else ""
			)
		]
	}

# MARK: - State Queries

## Check if crew currently has a ship.
static func crew_has_ship(campaign: Resource) -> bool:
	if "has_ship" in campaign:
		return campaign.has_ship
	return true  # Default: assume crew has ship

## Get current stash limit based on ship status.
static func get_stash_limit(campaign: Resource) -> int:
	if crew_has_ship(campaign):
		return 999  # Unlimited with ship
	return SHIPLESS_STASH_LIMIT

## Get a summary for UI display.
static func get_status_summary(campaign: Resource) -> String:
	if crew_has_ship(campaign):
		var debt: int = campaign.ship_debt if "ship_debt" in campaign else 0
		if debt > 0:
			return "Ship: Active (Debt: %d cr)" % debt
		return "Ship: Active"
	return "NO SHIP — Stash limited to %d items, travel by commercial passage only" % SHIPLESS_STASH_LIMIT
