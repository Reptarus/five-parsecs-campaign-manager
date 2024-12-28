class_name LoanManager
extends Resource

signal loan_taken(amount: int, interest_rate: float)
signal loan_repaid(amount: int)
signal payment_missed(penalty: int)

const BASE_INTEREST_RATE := 0.1
const LATE_PAYMENT_PENALTY := 0.2
const MAX_LOAN_AMOUNT := 50000

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const WorldEconomyManager = preload("res://src/core/managers/WorldEconomyManager.gd")

var game_state: FiveParsecsGameState
var active_loans: Array[Dictionary] = []
var credit_rating: float = 1.0

func _init(_game_state: FiveParsecsGameState) -> void:
	if not _game_state:
		push_error("FiveParsecsGameState is required for LoanManager")
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
	if loan_index < 0 or loan_index >= active_loans.size():
		push_error("Invalid loan index")
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
