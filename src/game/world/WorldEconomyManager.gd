@tool
extends Node

## Economy in Five Parsecs from Home
## - Trade activities are conducted via missions
## - For item prices, main rules state "normal price per item

signal economy_updated
signal transaction_completed(amount: int, type: String)

var _current_credits: int = 0
var _transaction_history: Array = []

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")
# GameState reference - loaded at runtime to avoid circular dependencies
var GameState: Variant = null

# Market State Types
enum MarketState {
	NORMAL,
	CRISIS,
	BOOM,
	RESTRICTED
}

func _init() -> void:
	_current_credits = 1000 # Starting credits

func _ready() -> void:
	# Load GameState dependency at runtime to avoid circular dependencies
	GameState = load("res://src/core/state/GameState.gd")

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
		_record_transaction(-amount, "debit")
		economy_updated.emit() # warning: return value discarded (intentional)
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

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null