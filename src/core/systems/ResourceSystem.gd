extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal resource_changed(type: int, amount: int)
signal resource_depleted(type: int)
signal resource_added(type: int, amount: int)
signal resource_removed(type: int, amount: int)

var _resources: Dictionary = {}
var _resource_limits: Dictionary = {}

func _init() -> void:
    _initialize_resources()

func _initialize_resources() -> void:
    for type in GameEnums.ResourceType.values():
        _resources[type] = 0
        _resource_limits[type] = -1 # -1 means no limit

func has_resource(type: int) -> bool:
    return _resources.has(type)

func get_resource_amount(type: int) -> int:
    return _resources.get(type, 0)

func add_resource(type: int, amount: int) -> void:
    if amount <= 0:
        return
        
    var current = get_resource_amount(type)
    var limit = _resource_limits[type]
    
    if limit >= 0:
        amount = min(amount, limit - current)
        
    if amount > 0:
        _resources[type] = current + amount
        resource_added.emit(type, amount)
        resource_changed.emit(type, _resources[type])

func remove_resource(type: int, amount: int) -> bool:
    if amount <= 0:
        return true
        
    var current = get_resource_amount(type)
    if current < amount:
        return false
        
    _resources[type] = current - amount
    resource_removed.emit(type, amount)
    resource_changed.emit(type, _resources[type])
    
    if _resources[type] == 0:
        resource_depleted.emit(type)
        
    return true

func set_resource_limit(type: int, limit: int) -> void:
    _resource_limits[type] = limit
    if limit >= 0:
        var current = get_resource_amount(type)
        if current > limit:
            remove_resource(type, current - limit)

func get_resource_limit(type: int) -> int:
    return _resource_limits.get(type, -1)

func clear_resources() -> void:
    for type in _resources.keys():
        _resources[type] = 0
        resource_changed.emit(type, 0)
        resource_depleted.emit(type)

func serialize() -> Dictionary:
    return {
        "resources": _resources.duplicate(),
        "limits": _resource_limits.duplicate()
    }

func deserialize(data: Dictionary) -> void:
    if data.has("resources"):
        _resources = data["resources"].duplicate()
    if data.has("limits"):
        _resource_limits = data["limits"].duplicate()