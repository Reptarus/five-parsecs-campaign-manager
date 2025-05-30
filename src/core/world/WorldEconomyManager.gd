@tool
extends Node

## Economy in Five Parsecs from Home
## - Trade activities are conducted via missions
## - For item prices, main rules state "normal price per item"

signal economy_updated
signal transaction_completed(amount: int, type: String)

var _current_credits: int = 0
var _transaction_history: Array = []

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

func _init() -> void:
	_current_credits = 1000 # Starting credits

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

# Market functions
func calculate_price_adjustment(location_type: String) -> float:
	var base_adjustment := 1.0
	
	match location_type:
		"trade_hub": return base_adjustment * 0.9 # 10% discount
		"black_market": return base_adjustment * 1.2 # 20% premium
		"frontier_outpost": return base_adjustment * 1.1 # 10% premium
		"civilian_settlement": return base_adjustment * 1.0 # Standard price
		"military_base": return base_adjustment * 1.15 # 15% premium
		_: return base_adjustment
	
	return base_adjustment