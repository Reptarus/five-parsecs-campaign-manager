extends Node

## Base class for all economy manager implementations
##
## Provides core functionality for managing in-game economies, currencies, and transactions

# Core signals
signal economy_updated
signal transaction_completed(amount: float, transaction_type: String, description: String)
signal balance_changed(new_balance: float)

# Base properties
var balance: float = 0.0
var transaction_history: Array = []

# --- Core functionality ---

## Initialize the economy with a starting balance
func initialize(starting_balance: float = 0.0) -> void:
	balance = starting_balance
	balance_changed.emit(balance)

## Get the current balance
func get_balance() -> float:
	return balance

## Add funds to the balance
func add_funds(amount: float, description: String = "") -> bool:
	if amount <= 0:
		return false
		
	balance += amount
	_record_transaction(amount, "credit", description)
	balance_changed.emit(balance)
	economy_updated.emit()
	return true

## Remove funds from the balance
func remove_funds(amount: float, description: String = "") -> bool:
	if amount <= 0 or balance < amount:
		return false
		
	balance -= amount
	_record_transaction(- amount, "debit", description)
	balance_changed.emit(balance)
	economy_updated.emit()
	return true

## Check if there are sufficient funds
func has_sufficient_funds(amount: float) -> bool:
	return balance >= amount

## Transfer funds between two economy managers
func transfer_funds_to(target_economy, amount: float, description: String = "") -> bool:
	if not has_sufficient_funds(amount):
		return false
		
	if remove_funds(amount, "Transfer to: " + description):
		target_economy.add_funds(amount, "Transfer from: " + description)
		return true
	return false

## Get the transaction history
func get_transaction_history() -> Array:
	return transaction_history.duplicate()

## Clear the transaction history
func clear_transaction_history() -> void:
	transaction_history.clear()
	
## Record a transaction in the history
func _record_transaction(amount: float, transaction_type: String, description: String = "") -> void:
	var transaction = {
		"amount": amount,
		"type": transaction_type,
		"description": description,
		"timestamp": Time.get_unix_time_from_system()
	}
	transaction_history.append(transaction)
	transaction_completed.emit(amount, transaction_type, description)