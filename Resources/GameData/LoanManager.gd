class_name LoanManager
extends Node

const MIN_LOAN_AMOUNT: int = 10
const MAX_LOAN_AMOUNT: int = 30
const MIN_INTEREST_RATE: float = 0.05
const MAX_INTEREST_RATE: float = 0.15
const MIN_REPAYMENT_PERIOD: int = 5
const MAX_REPAYMENT_PERIOD: int = 10

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_loan_offer() -> Dictionary:
	var loan_amount: int = randi_range(MIN_LOAN_AMOUNT, MAX_LOAN_AMOUNT)
	var interest_rate: float = randf_range(MIN_INTEREST_RATE, MAX_INTEREST_RATE)
	var repayment_period: int = randi_range(MIN_REPAYMENT_PERIOD, MAX_REPAYMENT_PERIOD)
	var loan_type: GlobalEnums.LoanType = _determine_loan_type()

	return {
		"amount": loan_amount,
		"interest_rate": interest_rate,
		"repayment_period": repayment_period,
		"total_repayment": calculate_total_repayment(loan_amount, interest_rate, repayment_period),
		"type": loan_type
	}

func _determine_loan_type() -> GlobalEnums.LoanType:
	var roll: int = randi() % 100 + 1
	if roll <= 60:
		return GlobalEnums.LoanType.STANDARD
	elif roll <= 90:
		return GlobalEnums.LoanType.PREDATORY
	else:
		return GlobalEnums.LoanType.BLACK_MARKET

func calculate_total_repayment(amount: int, rate: float, period: int) -> int:
	return int(amount * (1 + rate * period))

func accept_loan(loan: Dictionary) -> void:
	assert(loan.has_all(["amount", "interest_rate", "repayment_period", "total_repayment", "type"]), "Invalid loan data")
	game_state.credits += loan.amount
	game_state.current_crew.active_loans.append(loan)
	
	match loan.type:
		GlobalEnums.LoanType.PREDATORY:
			game_state.reputation -= 1
		GlobalEnums.LoanType.BLACK_MARKET:
			game_state.reputation -= 2

func update_loans() -> void:
	var loans_to_remove: Array[Dictionary] = []
	for loan in game_state.current_crew.active_loans:
		loan.repayment_period -= 1
		if loan.repayment_period <= 0:
			collect_loan(loan)
			loans_to_remove.append(loan)
	
	for loan in loans_to_remove:
		game_state.current_crew.active_loans.erase(loan)

func collect_loan(loan: Dictionary) -> void:
	var repayment_amount: int = loan.total_repayment
	if game_state.credits >= repayment_amount:
		game_state.credits -= repayment_amount
	else:
		handle_loan_default(loan)

func handle_loan_default(loan: Dictionary) -> void:
	game_state.reputation -= 5
	var penalty: int = int(loan.total_repayment * 0.5)
	force_asset_sale(penalty)
	
	match loan.type:
		GlobalEnums.LoanType.PREDATORY:
			game_state.reputation -= 2
			_trigger_predatory_consequences()
		GlobalEnums.LoanType.BLACK_MARKET:
			game_state.reputation -= 5
			_trigger_black_market_consequences()

func _trigger_black_market_consequences() -> void:
	var roll = randi() % 100 + 1
	
	if roll <= 30:
		# Add a new Rival
		var new_rival = {
			"name": "Black Market Enforcer",
			"type": GlobalEnums.Faction.CRIMINAL,
			"description": "A ruthless debt collector sent to recover the defaulted loan."
		}
		game_state.current_crew.rivals.append(new_rival)
		
	elif roll <= 60:
		# Trigger a bounty hunter encounter
		game_state.add_story_event({
			"type": GlobalEnums.StrifeType.RESOURCE_CONFLICT,
			"description": "A bounty hunter has been dispatched to track down your crew!"
		})
		
	elif roll <= 80:
		# Reputation hit with criminal factions
		game_state.faction_standings[GlobalEnums.Faction.CRIMINAL] -= 10
		
	else:
		# Asset seizure
		var seizure_amount = int(get_total_debt() * 0.2)
		force_asset_sale(seizure_amount)

func _trigger_predatory_consequences() -> void:
	var roll = randi() % 100 + 1
	
	if roll <= 40:
		# Legal troubles
		game_state.faction_standings[GlobalEnums.Faction.CORPORATE] -= 5
	elif roll <= 70:
		# Credit rating hit
		game_state.credit_rating -= 1
	else:
		# Debt collectors
		game_state.add_story_event({
			"type": GlobalEnums.StrifeType.CORPORATE_WARFARE,
			"description": "Corporate debt collectors are pursuing your crew."
		})

func force_asset_sale(amount: int) -> void:
	var sold_amount: int = 0
	var equipment_to_sell: Array[Equipment] = []

	for equipment in game_state.current_crew.equipment:
		if sold_amount >= amount:
			break
		equipment_to_sell.append(equipment)
		sold_amount += equipment.value

	for equipment in equipment_to_sell:
		game_state.current_crew.equipment.erase(equipment)
		game_state.credits += equipment.value

	if sold_amount < amount:
		game_state.credits += sold_amount - amount
		print("Warning: Not enough assets to cover loan default. Remaining debt: %d" % (amount - sold_amount))

func get_active_loans() -> Array[Dictionary]:
	return game_state.current_crew.active_loans

func get_total_debt() -> int:
	return game_state.current_crew.active_loans.reduce(func(acc, loan): return acc + loan.total_repayment, 0)

func can_take_loan() -> bool:
	var current_debt: int = get_total_debt()
	var max_allowed_debt: int = game_state.current_crew.get_max_allowed_debt()
	return current_debt < max_allowed_debt

func get_loan_risk_factor() -> float:
	var current_debt: int = get_total_debt()
	var max_allowed_debt: int = game_state.current_crew.get_max_allowed_debt()
	return float(current_debt) / max_allowed_debt if max_allowed_debt > 0 else 1.0

func roll_for_loan_event() -> void:
	var roll: int = randi() % 100 + 1
	if roll <= 10:
		_trigger_loan_event()

func _trigger_loan_event() -> void:
	var roll = randi() % 100 + 1
	var risk_factor = get_loan_risk_factor()
	
	if roll <= 20:
		# Loan shark demands early repayment
		var demand_amount = int(get_total_debt() * 0.25)
		print("A loan shark demands early repayment of %d credits!" % demand_amount)
		if game_state.credits >= demand_amount:
			game_state.credits -= demand_amount
			print("You paid the demand from your available credits.")
		else:
			force_asset_sale(demand_amount)
			print("Assets were seized to cover the demand.")
	
	elif roll <= 40:
		# Unexpected fees
		var fee_amount = int(get_total_debt() * 0.1)
		print("Unexpected loan fees of %d credits have been added to your debt." % fee_amount)
		game_state.current_crew.active_loans[0].total_repayment += fee_amount
	
	elif roll <= 60:
		# Opportunity to reduce debt
		var reduction_amount = int(get_total_debt() * 0.15)
		print("An opportunity arises to reduce your debt by %d credits." % reduction_amount)
		if game_state.credits >= reduction_amount:
			game_state.credits -= reduction_amount
			game_state.current_crew.active_loans[0].total_repayment -= reduction_amount
			print("You took advantage of the opportunity and reduced your debt.")
		else:
			print("You couldn't afford to take advantage of this opportunity.")
	
	elif roll <= 80:
		# Rival interference
		print("A rival has interfered with your loan arrangements.")
		game_state.current_crew.active_loans[0].interest_rate += 0.05
		print("Your interest rate has increased by 5%.")
	
	else:
		# Loan forgiveness (rare event)
		if risk_factor > 0.8:  # Only if in severe debt
			var forgiven_amount = int(get_total_debt() * 0.2)
			print("Due to unforeseen circumstances, %d credits of your debt have been forgiven!" % forgiven_amount)
			game_state.current_crew.active_loans[0].total_repayment -= forgiven_amount
	
	# Add a story point for the dramatic event
	game_state.story_points += 1
