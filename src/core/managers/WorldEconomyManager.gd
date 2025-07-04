class_name WorldEconomyManagerClass
extends Node

## Simple world economy manager for Five Parsecs
##
## Handles planetary economy, trade routes, and market conditions

signal economy_updated(planet: String, new_status: int)
signal trade_route_established(from_planet: String, to_planet: String)
signal market_fluctuation(planet: String, resource_type: int, change: float)

enum EconomyStatus {
	DEPRESSION,
	RECESSION,
	STABLE,
	GROWTH,
	BOOM
}

var planetary_economies: Dictionary = {}
var trade_routes: Array[Dictionary] = []
var market_conditions: Dictionary = {}

func _init() -> void:
	_initialize_default_economies()

func _initialize_default_economies() -> void:
	# Initialize some default planetary economies
	planetary_economies = {
		"New Dublin": EconomyStatus.STABLE,
		"Fringe World Alpha": EconomyStatus.RECESSION,
		"Trade Hub Beta": EconomyStatus.GROWTH,
		"Industrial Gamma": EconomyStatus.STABLE
	}

## Get economy status for a planet

func get_economy_status(planet_name: String) -> EconomyStatus:
	return planetary_economies.get(planet_name, EconomyStatus.STABLE)

## Set economy status for a planet
func set_economy_status(planet_name: String, status: EconomyStatus) -> void:
	planetary_economies[planet_name] = status
	economy_updated.emit(planet_name, status) # warning: return value discarded (intentional)

## Update economy based on events
func update_economy(planet_name: String, change: int) -> void:
	var current_status = get_economy_status(planet_name)
	var new_status = clamp(current_status + change, EconomyStatus.DEPRESSION, EconomyStatus.BOOM)
	set_economy_status(planet_name, new_status)

## Get trade modifier for economy status

func get_trade_modifier(planet_name: String) -> float:
	var status = get_economy_status(planet_name)
	match status:
		EconomyStatus.DEPRESSION: return 0.5
		EconomyStatus.RECESSION: return 0.75
		EconomyStatus.STABLE: return 1.0
		EconomyStatus.GROWTH: return 1.25
		EconomyStatus.BOOM: return 1.5
		_: return 1.0

## Establish trade route between planets
func establish_trade_route(from_planet: String, to_planet: String) -> void:
	var route = {
		"from": from_planet,
		"to": to_planet,
		"established": Time.get_unix_time_from_system()
	}
	trade_routes.append(route) # warning: return value discarded (intentional)
	trade_route_established.emit(from_planet, to_planet) # warning: return value discarded (intentional)

## Check if trade route exists
func has_trade_route(from_planet: String, to_planet: String) -> bool:
	for route in trade_routes:
		if route.from == from_planet and route.to == to_planet:
			return true
		if route.from == to_planet and route.to == from_planet:
			return true
	return false

## Get all trade routes for a _planet
func get_trade_routes(planet_name: String) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for route in trade_routes:
		if route.from == planet_name or route.to == planet_name:
			routes.append(route) # warning: return value discarded (intentional)
	return routes

## Process economic fluctuations
func process_economic_fluctuations() -> void:
	for planet in planetary_economies.keys():
		# Random chance for economic change
		if randf() < 0.1: # 10% chance per cycle
			var change = randi_range(-1, 1)
			if change != 0:
				update_economy(planet, change)

## Get economy status name

func get_economy_status_name(status: EconomyStatus) -> String:
	match status:
		EconomyStatus.DEPRESSION: return "Depression"
		EconomyStatus.RECESSION: return "Recession"
		EconomyStatus.STABLE: return "Stable"
		EconomyStatus.GROWTH: return "Growth"
		EconomyStatus.BOOM: return "Boom"
		_: return "Unknown"

## Serialize economy data
func serialize() -> Dictionary:
	return {
		"planetary_economies": planetary_economies,
		"trade_routes": trade_routes,
		"market_conditions": market_conditions
	}

## Deserialize economy data
func deserialize(data: Dictionary) -> void:
	planetary_economies = data.get("planetary_economies", {})
	trade_routes = data.get("trade_routes", [])
	market_conditions = data.get("market_conditions", {})
