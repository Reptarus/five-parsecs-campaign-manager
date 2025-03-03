@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")

signal cache_updated

const CACHE_FILE = "user://planet_cache.json"
const MAX_CACHED_PLANETS = 50

var cached_planets: Dictionary = {} # planet_id: Planet
var cache_timestamps: Dictionary = {} # planet_id: timestamp
var dirty: bool = false

func _init() -> void:
    load_cache()

func add_planet(planet: GamePlanet) -> void:
    var planet_id = _generate_planet_id(planet)
    cached_planets[planet_id] = planet
    cache_timestamps[planet_id] = Time.get_unix_time_from_system()
    dirty = true
    _cleanup_old_cache()
    save_cache()
    cache_updated.emit()

func get_planet(sector: String, coordinates: Vector2) -> GamePlanet:
    var planet_id = _generate_id(sector, coordinates)
    return cached_planets.get(planet_id)

func update_planet(planet: GamePlanet) -> void:
    var planet_id = _generate_planet_id(planet)
    if cached_planets.has(planet_id):
        cached_planets[planet_id] = planet
        cache_timestamps[planet_id] = Time.get_unix_time_from_system()
        dirty = true
        save_cache()
        cache_updated.emit()

func _generate_planet_id(planet: GamePlanet) -> String:
    return _generate_id(planet.sector, planet.coordinates)

func _generate_id(sector: String, coordinates: Vector2) -> String:
    return "%s_%d_%d" % [sector, coordinates.x, coordinates.y]

func _cleanup_old_cache() -> void:
    if cached_planets.size() <= MAX_CACHED_PLANETS:
        return
    
    var timestamps = cache_timestamps.values()
    timestamps.sort()
    var cutoff_time = timestamps[timestamps.size() - MAX_CACHED_PLANETS]
    
    var to_remove = []
    for planet_id in cache_timestamps:
        if cache_timestamps[planet_id] < cutoff_time:
            to_remove.append(planet_id)
    
    for planet_id in to_remove:
        cached_planets.erase(planet_id)
        cache_timestamps.erase(planet_id)

func save_cache() -> void:
    if not dirty:
        return
    
    var cache_data = {
        "planets": {},
        "timestamps": cache_timestamps
    }
    
    for planet_id in cached_planets:
        cache_data.planets[planet_id] = cached_planets[planet_id].serialize()
    
    var file = FileAccess.open(CACHE_FILE, FileAccess.WRITE)
    file.store_string(JSON.stringify(cache_data))
    file.close()
    
    dirty = false

func load_cache() -> void:
    if not FileAccess.file_exists(CACHE_FILE):
        return
    
    var file = FileAccess.open(CACHE_FILE, FileAccess.READ)
    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    file.close()
    
    if error == OK:
        var cache_data = json.data
        cache_timestamps = cache_data.timestamps
        
        for planet_id in cache_data.planets:
            cached_planets[planet_id] = GamePlanet.deserialize(cache_data.planets[planet_id])