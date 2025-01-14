@tool
class_name PositionValidator
extends Node

## Variables
var force_invalid_points: bool = false

## Constants
const MIN_DISTANCE_BETWEEN_POINTS := 3.0
const MIN_DISTANCE_FROM_EDGE := 2.0

## Get a valid point for cover placement
func get_valid_cover_point(existing_points: Array) -> Vector2:
	if force_invalid_points:
		return Vector2.ZERO
	
	var attempts := 0
	const MAX_ATTEMPTS := 50
	
	while attempts < MAX_ATTEMPTS:
		var point := _generate_random_point()
		if _is_valid_cover_point(point, existing_points):
			return point
		attempts += 1
	
	return Vector2.ZERO

## Get a valid point for hazard placement
func get_valid_hazard_point(existing_points: Array) -> Vector2:
	if force_invalid_points:
		return Vector2.ZERO
	
	var attempts := 0
	const MAX_ATTEMPTS := 50
	
	while attempts < MAX_ATTEMPTS:
		var point := _generate_random_point()
		if _is_valid_hazard_point(point, existing_points):
			return point
		attempts += 1
	
	return Vector2.ZERO

## Get a valid point for strategic point placement
func get_valid_strategic_point(existing_points: Array) -> Vector2:
	if force_invalid_points:
		return Vector2.ZERO
	
	var attempts := 0
	const MAX_ATTEMPTS := 50
	
	while attempts < MAX_ATTEMPTS:
		var point := _generate_random_point()
		if _is_valid_strategic_point(point, existing_points):
			return point
		attempts += 1
	
	return Vector2.ZERO

## Generate a random point within the battlefield bounds
func _generate_random_point() -> Vector2:
	var x := randf_range(MIN_DISTANCE_FROM_EDGE, 50.0 - MIN_DISTANCE_FROM_EDGE)
	var y := randf_range(MIN_DISTANCE_FROM_EDGE, 50.0 - MIN_DISTANCE_FROM_EDGE)
	return Vector2(x, y)

## Check if a point is valid for cover placement
func _is_valid_cover_point(point: Vector2, existing_points: Array) -> bool:
	# Check distance from other points
	for existing in existing_points:
		var existing_pos: Vector2 = existing["position"]
		if point.distance_to(existing_pos) < MIN_DISTANCE_BETWEEN_POINTS:
			return false
	
	return true

## Check if a point is valid for hazard placement
func _is_valid_hazard_point(point: Vector2, existing_points: Array) -> bool:
	# Hazards need more space between them
	for existing in existing_points:
		var existing_pos: Vector2 = existing["position"]
		var min_distance := MIN_DISTANCE_BETWEEN_POINTS * 2.0
		if point.distance_to(existing_pos) < min_distance:
			return false
	
	return true

## Check if a point is valid for strategic point placement
func _is_valid_strategic_point(point: Vector2, existing_points: Array) -> bool:
	# Strategic points need significant spacing
	for existing in existing_points:
		var existing_pos: Vector2 = existing["position"]
		var min_distance := MIN_DISTANCE_BETWEEN_POINTS * 3.0
		if point.distance_to(existing_pos) < min_distance:
			return false
	
	return true

## Set the battlefield size for point validation
func set_battlefield_size(size: Vector2) -> void:
	# Update the random point generation bounds
	_update_bounds(size)

## Update the bounds for random point generation
func _update_bounds(size: Vector2) -> void:
	# Implement bounds updating logic here
	pass

## Validate a specific position
func validate_position(position: Vector2, battlefield_size: Vector2) -> bool:
	if position.x < MIN_DISTANCE_FROM_EDGE or position.x > battlefield_size.x - MIN_DISTANCE_FROM_EDGE:
		return false
	if position.y < MIN_DISTANCE_FROM_EDGE or position.y > battlefield_size.y - MIN_DISTANCE_FROM_EDGE:
		return false
	return true