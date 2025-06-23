extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal global_event_triggered(event: int)
signal economy_updated
signal market_updated(prices: Dictionary)
signal trade_completed
signal transaction_failed(reason: String)

const BASE_ITEM_MARKUP: float = 1.2
const BASE_ITEM_MARKDOWN: float = 0.8
const GLOBAL_EVENT_CHANCE: float = 0.1
const ECONOMY_NORMALIZATION_RATE: float = 0.1
const MAX_PRICE_FLUCTUATION: float = 0.3
const MIN_PRICE_MULTIPLIER: float = 0.5
const MAX_PRICE_MULTIPLIER: float = 2.0

var location_price_modifiers: Dictionary = {} # location_name: float
var global_economic_modifier: float = 1.0
var trade_restricted_items: Array[String] = []
var scarce_resources: Array = []
var new_tech_items: Array = []
var current_market_state: int = 0  # Will be set to NORMAL in _init()
var market_prices: Dictionary = {}
var supply_demand: Dictionary = {}

func _init() -> void:
    randomize()
    
    # Initialize enum values
    if GameEnums and "MarketState" in GameEnums and "NORMAL" in GameEnums.MarketState:
        current_market_state = GameEnums.MarketState.NORMAL
    
    _initialize_market()
func _initialize_market() -> void:
    market_prices.clear()
    supply_demand.clear()
    
    # Initialize base prices for all item types
    if not GameEnums or not "ItemType" in GameEnums:
        push_error("CRASH PREVENTION: EconomyManager cannot initialize market - GameEnums.ItemType not available")
        return
    
    for item_type in GameEnums.ItemType.values():
        if "NONE" in GameEnums.ItemType and item_type == GameEnums.ItemType.NONE:
            continue
        market_prices[item_type] = 1.0
        supply_demand[item_type] = {
            "supply": randf_range(0.5, 1.5),
            "demand": randf_range(0.5, 1.5)
        }
func update_market() -> void:
    _update_market_state()
    _update_supply_demand()
    _update_prices()
    _check_for_global_events()
    market_updated.emit(market_prices) # warning: return value discarded (intentional)

func _update_market_state() -> void:
    var state_change_roll := randf()
    
    match current_market_state:
        GameEnums.MarketState.NORMAL:
            if state_change_roll < 0.1:
                current_market_state = GameEnums.MarketState.BOOM if randf() < 0.6 else GameEnums.MarketState.RESTRICTED
        GameEnums.MarketState.BOOM:
            if state_change_roll < 0.2:
                current_market_state = GameEnums.MarketState.NORMAL
            elif state_change_roll < 0.25:
                current_market_state = GameEnums.MarketState.CRISIS
        GameEnums.MarketState.RESTRICTED:
            if state_change_roll < 0.15:
                current_market_state = GameEnums.MarketState.NORMAL
            elif state_change_roll < 0.2:
                current_market_state = GameEnums.MarketState.CRISIS
        GameEnums.MarketState.CRISIS:
            if state_change_roll < 0.1:
                current_market_state = GameEnums.MarketState.NORMAL
func _update_supply_demand() -> void:
    for item_type in supply_demand.keys():
        var data: Dictionary = supply_demand[item_type]
        
        # Natural supply/demand fluctuation
        data.supply += randf_range(-0.1, 0.1)
        data.demand += randf_range(-0.1, 0.1)
        
        # Clamp values
        data.supply = clampf(data.supply, 0.1, 2.0)
        data.demand = clampf(data.demand, 0.1, 2.0)
        
        # Apply market state effects
        match current_market_state:
            GameEnums.MarketState.BOOM:
                data.demand *= 1.2
            GameEnums.MarketState.RESTRICTED:
                data.demand *= 0.8
            GameEnums.MarketState.CRISIS:
                data.supply *= 0.7
                data.demand *= 0.6
func _update_prices() -> void:
    for item_type in market_prices.keys():
        var base_modifier := 1.0
        
        # Apply supply/demand effects
        var supply_demand_ratio: Dictionary = supply_demand[item_type]
        base_modifier *= supply_demand_ratio.demand / supply_demand_ratio.supply
        
        # Apply market state effects
        match current_market_state:
            GameEnums.MarketState.BOOM:
                base_modifier *= 1.3
            GameEnums.MarketState.RESTRICTED:
                base_modifier *= 0.7
            GameEnums.MarketState.CRISIS:
                base_modifier *= 0.5
        
        # Apply random fluctuation
        base_modifier *= (1.0 + randf_range(-MAX_PRICE_FLUCTUATION, MAX_PRICE_FLUCTUATION))
        
        # Apply global modifier
        base_modifier *= global_economic_modifier
        
        # Clamp final modifier
        base_modifier = clampf(base_modifier, MIN_PRICE_MULTIPLIER, MAX_PRICE_MULTIPLIER)
        
        # Update price
        market_prices[item_type] = base_modifier
func calculate_item_price(item: Resource, is_buying: bool) -> int:
    if not item:
        push_error("Item is required for price calculation")
        return 0
        
    var base_price: int = item._value

    var location_modifier: float = location_price_modifiers.get(
        get_node("/root/GameStateManager").game_state.current_location.name,
        1.0
    )

    var market_modifier: float = market_prices.get(item.type, 1.0)
    
    if is_buying:
        base_price = int(base_price * BASE_ITEM_MARKUP * location_modifier * market_modifier)
    else:
        base_price = int(base_price * BASE_ITEM_MARKDOWN * location_modifier * market_modifier)
    
    return max(1, base_price)

func can_trade_item(item: Resource) -> bool:
    if not item:
        return false
        
    if item.name in trade_restricted_items:
        return false
        
    if item.type in scarce_resources and current_market_state == GameEnums.MarketState.CRISIS:
        return false
        
    return true

func process_transaction(item: Resource, is_buying: bool, quantity: int = 1) -> bool:
    if not can_trade_item(item):
        transaction_failed.emit("This item cannot be traded at this time") # warning: return value discarded (intentional)
        return false
        
    var price := calculate_item_price(item, is_buying) * quantity
    var game_state = get_node("/root/GameStateManager").game_state
    
    if is_buying:
        if game_state.credits < price:
            transaction_failed.emit("Insufficient credits") # warning: return value discarded (intentional)
            return false
            
        game_state.spend_credits(price)
        game_state.add_item(item, quantity)
    else:
        if not game_state.has_item(item, quantity):
            transaction_failed.emit("Insufficient items") # warning: return value discarded (intentional)
            return false
            
        game_state.remove_item(item, quantity)
        game_state.add_credits(price)
    
    # Update supply/demand
    var sd_data: Dictionary = supply_demand[item.type]
    if is_buying:
        sd_data.supply = maxf(0.1, sd_data.supply - 0.1 * quantity)
        sd_data.demand = minf(2.0, sd_data.demand + 0.05 * quantity)
    else:
        sd_data.supply = minf(2.0, sd_data.supply + 0.1 * quantity)
        sd_data.demand = maxf(0.1, sd_data.demand - 0.05 * quantity)
    
    trade_completed.emit() # warning: return value discarded (intentional)
    return true

func _check_for_global_events() -> void:
    if randf() < GLOBAL_EVENT_CHANCE:
        var event := _generate_global_event()
        _apply_global_event(event)
        global_event_triggered.emit(event) # warning: return value discarded (intentional)

func _generate_global_event() -> int:
    if not GameEnums or not "GlobalEvent" in GameEnums:
        push_error("CRASH PREVENTION: EconomyManager cannot generate global event - GameEnums.GlobalEvent not available")
        return 0
    
    var events := GameEnums.GlobalEvent.values()
    return events[randi() % events.size()]

func _apply_global_event(_event: int) -> void:
    if not GameEnums or not "GlobalEvent" in GameEnums:
        push_error("CRASH PREVENTION: EconomyManager cannot apply global event - GameEnums.GlobalEvent not available")
        return
    
    match _event:
        GameEnums.GlobalEvent.TRADE_DISRUPTION if "TRADE_DISRUPTION" in GameEnums.GlobalEvent:
            global_economic_modifier *= 0.8
        GameEnums.GlobalEvent.ECONOMIC_BOOM if "ECONOMIC_BOOM" in GameEnums.GlobalEvent:
            global_economic_modifier *= 1.2
        GameEnums.GlobalEvent.RESOURCE_SHORTAGE if "RESOURCE_SHORTAGE" in GameEnums.GlobalEvent:
            if "ItemType" in GameEnums:
                var resource_types := GameEnums.ItemType.values()
                if resource_types.size() > 0:
                    var new_resource: int = resource_types[randi() % resource_types.size()]
                    if "NONE" in GameEnums.ItemType and new_resource != GameEnums.ItemType.NONE and not new_resource in scarce_resources:
                        scarce_resources.append(new_resource) # warning: return value discarded (intentional)
        GameEnums.GlobalEvent.NEW_TECHNOLOGY if "NEW_TECHNOLOGY" in GameEnums.GlobalEvent:
            if "ItemType" in GameEnums:
                var tech_items := GameEnums.ItemType.values()
                if tech_items.size() > 0:
                    var new_tech: int = tech_items[randi() % tech_items.size()]
                    if "NONE" in GameEnums.ItemType and new_tech != GameEnums.ItemType.NONE and not new_tech in new_tech_items:
                        new_tech_items.append(new_tech) # warning: return value discarded (intentional)
    
    # Normalize global modifier over time
    global_economic_modifier = lerpf(global_economic_modifier, 1.0, ECONOMY_NORMALIZATION_RATE)
