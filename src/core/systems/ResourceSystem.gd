@tool
extends RefCounted
class_name GameResourceSystem

## Simple resource management system for Five Parsecs
##
## Handles credits, supplies, and other campaign resources

signal resource_changed(type: int, amount: int)
signal transaction_recorded(transaction: ResourceTransaction)
signal validation_failed(type: int, amount: int, reason: String)

class ResourceTransaction:
	var type: int
	var amount: int
	var timestamp: int
	var transaction_type: String
	var description: String
	
	func _init(res_type: int, res_amount: int, trans_type: String, desc: String = ""):
		type = res_type
		amount = res_amount
		transaction_type = trans_type
		description = desc
		timestamp = Time.get_unix_time_from_system()

enum ResourceType {
	CREDITS,
	SUPPLIES,
	FUEL,
	TECHNOLOGY,
	WEAPONS,
	LUXURY_GOODS,
	MINERALS,
	RARE_MATERIALS,
	MEDICAL_SUPPLIES
}

var resources: Dictionary = {}
var transaction_history: Array[ResourceTransaction] = []

func _init() -> void:
	_initialize_resources()

func _initialize_resources() -> void:
	for resource_type in ResourceType.values():
		resources[resource_type] = 0

## Add resources

func add_resource(type: ResourceType, amount: int, description: String = "") -> void:
	if amount <= 0:
		validation_failed.emit(type, amount, "Amount must be positive") # warning: return value discarded (intentional)
		return
	
	resources[type] += amount
	var transaction = ResourceTransaction.new(type, amount, "ADD", description)
	transaction_history.append(transaction) # warning: return value discarded (intentional)
	
	resource_changed.emit(type, resources[type]) # warning: return value discarded (intentional)
	transaction_recorded.emit(transaction) # warning: return value discarded (intentional)

## Remove resources
func remove_resource(type: ResourceType, amount: int, description: String = "") -> bool:
	if amount <= 0:
		validation_failed.emit(type, amount, "Amount must be positive") # warning: return value discarded (intentional)
		return false
	
	if resources[type] < amount:
		validation_failed.emit(type, amount, "Insufficient resources") # warning: return value discarded (intentional)
		return false
	
	resources[type] -= amount
	var transaction = ResourceTransaction.new(type, -amount, "REMOVE", description)
	transaction_history.append(transaction) # warning: return value discarded (intentional)
	
	resource_changed.emit(type, resources[type]) # warning: return value discarded (intentional)
	transaction_recorded.emit(transaction) # warning: return value discarded (intentional)
	return true

## Get resource amount
func get_resource(type: ResourceType) -> int:
	return resources.get(type, 0)

## Check if has enough resources
func has_enough(type: ResourceType, amount: int) -> bool:
	return get_resource(type) >= amount

## Get all resources
func get_all_resources() -> Dictionary:
	return resources.duplicate()

## Get transaction history
func get_transaction_history() -> Array[ResourceTransaction]:
	return transaction_history.duplicate()

## Clear transaction history
func clear_transaction_history() -> void:
	transaction_history.clear()

## Serialize resource data

func serialize() -> Dictionary:
	var transactions_data: Array = []
	for transaction in transaction_history:
		transactions_data.append({ # warning: return value discarded (intentional)
			"type": transaction.type,
			"amount": transaction.amount,
			"timestamp": transaction.timestamp,
			"transaction_type": transaction.transaction_type,
			"description": transaction.description
		})
	
	return {
		"resources": resources,
		"transaction_history": transactions_data
	}

## Deserialize resource data
func deserialize(data: Dictionary) -> void:
	resources = data.get("resources", {})
	transaction_history.clear()
	
	var transactions_data = data.get("transaction_history", [])
	for transaction_data in transactions_data:
		var transaction = ResourceTransaction.new(
			transaction_data.type,
			transaction_data.amount,
			transaction_data.transaction_type,
			transaction_data.get("description", "")
		)
		transaction.timestamp = transaction_data.timestamp
		transaction_history.append(transaction) # warning: return value discarded (intentional)