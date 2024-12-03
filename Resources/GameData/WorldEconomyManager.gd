extends Resource

signal economy_updated(world_data: Dictionary)

var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func calculate_upkeep() -> int:
    var base_upkeep = 100
    var crew_size_modifier = game_state.crew.size() * 25
    var ship_modifier = game_state.ship.maintenance_cost
    
    return base_upkeep + crew_size_modifier + ship_modifier

func pay_upkeep(crew) -> bool:
    var upkeep_cost = calculate_upkeep()
    if game_state.credits >= upkeep_cost:
        game_state.credits -= upkeep_cost
        return true
    return false

func update_market_prices() -> void:
    var market_data = _generate_market_data()
    game_state.current_location.update_market(market_data)
    economy_updated.emit(market_data)

func _generate_market_data() -> Dictionary:
    var base_prices = _get_base_prices()
    var modifiers = _calculate_price_modifiers()
    
    var market_data = {}
    for item in base_prices:
        market_data[item] = base_prices[item] * modifiers[item]
    
    return market_data

func _get_base_prices() -> Dictionary:
    return {
        "fuel": 50,
        "supplies": 75,
        "medical": 100,
        "ammo": 80,
        "spare_parts": 120
    }

func _calculate_price_modifiers() -> Dictionary:
    var modifiers = {}
    var location = game_state.current_location
    
    for item in _get_base_prices():
        var modifier = 1.0
        
        # Apply location type modifiers
        if location.is_trade_hub():
            modifier *= 0.8
        elif location.is_frontier():
            modifier *= 1.2
            
        # Apply supply/demand modifiers
        var supply = location.get_resource_supply(item)
        var demand = location.get_resource_demand(item)
        modifier *= (demand / supply) if supply > 0 else 2.0
        
        modifiers[item] = modifier
    
    return modifiers 