class_name EconomyManager
extends Node

signal global_event_triggered(event: GlobalEnums.GlobalEvent)
signal economy_updated

const BASE_ITEM_MARKUP: float = 1.2
const BASE_ITEM_MARKDOWN: float = 0.8
const GLOBAL_EVENT_CHANCE: float = 0.1
const ECONOMY_NORMALIZATION_RATE: float = 0.1

var location_price_modifiers: Dictionary = {}  # location_name: float
var global_economic_modifier: float = 1.0
var trade_restricted_items: Array[String] = []
var scarce_resources: Array[String] = []
var new_tech_items: Array[String] = []

func calculate_item_price(item: Equipment, is_buying: bool) -> int:
    if not item:
        push_error("Item is required for price calculation")
        return 0
        
    var base_price: int = item.value
    var location_modifier: float = location_price_modifiers.get(
        GameStateManager.get_instance().game_state.current_location.name,
        1.0
    )
    
    if is_buying:
        base_price = int(base_price * BASE_ITEM_MARKUP * location_modifier * global_economic_modifier)
    else:
        base_price = int(base_price * BASE_ITEM_MARKDOWN * location_modifier * global_economic_modifier)
    
    return max(1, base_price)
