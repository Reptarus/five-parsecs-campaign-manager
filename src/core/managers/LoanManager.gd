extends Resource

signal loan_taken(amount: int, interest_rate: float)
signal loan_repaid(amount: int)
signal payment_missed(penalty: int)

const BASE_INTEREST_RATE := 0.1
const LATE_PAYMENT_PENALTY := 0.2
const MAX_LOAN_AMOUNT := 50000

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const EconomySystem = preload("res://src/core/systems/EconomySystem.gd")

var game_state: GameState
var active_loans: Array[Dictionary] = []
var credit_rating: float = 1.0

func _init(_game_state: GameState) -> void:
	if not _game_state:
		push_error("GameState is required for LoanManager")
		return
	game_state = _game_state

func take_loan(amount: int) -> bool:
	if amount <= 0 or amount > MAX_LOAN_AMOUNT:
		push_error("Invalid loan amount")
		return false

	if not can_take_loan(amount):
		push_error("Cannot take loan: credit limit exceeded")
		return false

	var interest_rate := calculate_interest_rate()
	var loan := {
		"amount": amount,
		"interest_rate": interest_rate,
		"remaining": amount,
		"payments_missed": 0
	}

	active_loans.append(loan)
	game_state.credits += amount
	loan_taken.emit(amount, interest_rate)
	return true

func make_payment(loan_index: int, amount: int) -> bool:
	if loan_index < 0 or loan_index >= (safe_call_method(active_loans, "size") as int):
		push_error("Invalid loan _index")
		return false

	var loan := active_loans[loan_index]
	if amount > loan.remaining:
		amount = loan.remaining

	if game_state.credits < amount:
		push_error("Insufficient credits for loan payment")
		return false

	loan.remaining -= amount
	game_state.credits -= amount

	if loan.remaining <= 0:
		active_loans.remove_at(loan_index)
		loan_repaid.emit(amount)
	return true

func calculate_interest_rate() -> float:
	return BASE_INTEREST_RATE * (2.0 - credit_rating)

func can_take_loan(amount: int) -> bool:
	var total_debt := 0
	for loan in active_loans:
		total_debt += loan.remaining
	return total_debt + amount <= MAX_LOAN_AMOUNT * credit_rating

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null