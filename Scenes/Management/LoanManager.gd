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

	return {
		"amount": loan_amount,
		"interest_rate": interest_rate,
		"repayment_period": repayment_period,
		"total_repayment": calculate_total_repayment(loan_amount, interest_rate, repayment_period)
	}

func calculate_total_repayment(amount: int, rate: float, period: int) -> int:
	return int(amount * (1 + rate * period))

func accept_loan(loan: Dictionary) -> void:
	assert(loan.has_all(["amount", "interest_rate", "repayment_period", "total_repayment"]), "Invalid loan data")
	game_state.credits += loan.amount
	game_state.current_crew.active_loans.append(loan)

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
