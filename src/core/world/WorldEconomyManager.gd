@tool
extends Node

## Economy in Five Parsecs from Home
## - Trade activities are conducted via missions
## - For item prices, main rules state "normal price per item"

signal economy_updated
signal transaction_completed(amount: int, type: String)

var _current_credits: int = 0
var _transaction_history: Array = []
func _init() -> void:
	_current_credits = 0 # Set by campaign creation (Core Rules p.28: 1 credit per crew member)

func get_credits() -> int:
	return _current_credits

func add_credits(amount: int) -> void:
	if amount > 0:
		_current_credits += amount
		_record_transaction(amount, "credit")
		economy_updated.emit()

func remove_credits(amount: int) -> bool:
	if amount > 0 and _current_credits >= amount:
		_current_credits -= amount
		_record_transaction(- amount, "debit")
		economy_updated.emit()
		return true
	return false

func _record_transaction(amount: int, type: String) -> void:
	var transaction = {
		"amount": amount,
		"type": type,
		"timestamp": Time.get_unix_time_from_system()
	}
	_transaction_history.append(transaction)
	transaction_completed.emit(amount, type)

func get_transaction_history() -> Array:
	return _transaction_history

func clear_history() -> void:
	_transaction_history.clear()

## Serialization for campaign save/load persistence
func serialize() -> Dictionary:
	return {
		"current_credits": _current_credits,
		"transaction_history": _transaction_history.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	_current_credits = data.get("current_credits", 0)
	_transaction_history = data.get("transaction_history", [])

# Market functions
# (calculate_price_adjustment deleted Sprint B Phase B.3 (2026-05-24) —
# fabricated per-location price modifiers not in Core Rules. 5PFH trade is
# flat 1cr per item sold per Core Rules p.125. Zero callers verified.)