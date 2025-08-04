class_name ResponsiveDesignManager
extends RefCounted

## Five Parsecs Campaign Manager - Responsive Design Manager
## Refactored for Godot 4.x best practices compliance
## 
## Architecture: Adaptive UI system for cross-platform compatibility
## Performance: Optimized viewport monitoring and scaling calculations
## Patterns: Signal-based updates, efficient resource management

# ============================================================================
# CONSTANTS & ENUMS
# ============================================================================

## Device type classification for adaptive UI
enum DeviceType {
	MOBILE,		## Small screens: phones, small tablets
	TABLET,		## Medium screens: large tablets, small laptops
	DESKTOP,	## Large screens: desktops, large laptops
	WIDESCREEN	## Extra wide screens: ultrawide monitors
}

## UI scaling modes
enum ScalingMode {
	PIXEL_PERFECT,	## Fixed pixel sizes (desktop)
	SCALED,			## Scaled UI elements (tablets)
	ADAPTIVE		## Fully adaptive layouts (mobile)
}

# Breakpoint constants (in pixels)
const BREAKPOINT_MOBILE: float = 768.0
const BREAKPOINT_TABLET: float = 1024.0
const BREAKPOINT_DESKTOP: float = 1920.0

# Margin constants (percentage of screen width)
const MARGIN_MOBILE_PERCENT: float = 0.02		# 2%
const MARGIN_TABLET_PERCENT: float = 0.03		# 3%
const MARGIN_DESKTOP_PERCENT: float = 0.05		# 5%

# Margin limits (absolute pixels)
const MARGIN_MIN_PIXELS: float = 16.0
const MARGIN_MAX_PIXELS: float = 60.0

# Button size constants
const BUTTON_SIZE_MOBILE: float = 120.0
const BUTTON_SIZE_TABLET: float = 140.0
const BUTTON_SIZE_DESKTOP: float = 160.0

# Font scaling constants
const FONT_SCALE_MIN: float = 0.75		# 75%
const FONT_SCALE_MAX: float = 1.5		# 150%
const FONT_SCALE_MOBILE: float = 0.9	# 90%
const FONT_SCALE_TABLET: float = 1.0	# 100%
const FONT_SCALE_DESKTOP: float = 1.1	# 110%

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when device type changes
signal device_type_changed(old_type: DeviceType, new_type: DeviceType)

## Emitted when viewport size changes
signal viewport_size_changed(new_size: Vector2)

## Emitted when responsive values are updated
signal responsive_values_updated(margins: float, button_size: float, font_scale: float)

## Emitted when scaling mode changes
signal scaling_mode_changed(new_mode: ScalingMode)

# ============================================================================
# PROPERTIES
# ============================================================================

## Current device type
var current_device_type: DeviceType = DeviceType.DESKTOP

## Current scaling mode
var current_scaling_mode: ScalingMode = ScalingMode.SCALED

## Current viewport size
var current_viewport_size: Vector2 = Vector2.ZERO

## Current responsive values
var current_margins: float = 40.0
var current_button_size: float = 160.0
var current_font_scale: float = 1.0

## Viewport reference
var viewport: Viewport

## Update throttling
var last_update_time: float = 0.0
var update_throttle_ms: float = 100.0	# Only update every 100ms max

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(target_viewport: Viewport = null) -> void:
	"""Initialize the responsive design manager"""
	if target_viewport:
		viewport = target_viewport
	else:
		# Try to get main viewport
		if Engine.get_main_loop() and Engine.get_main_loop().has_method("get_viewport"):
			viewport = Engine.get_main_loop().get_viewport()
	
	if viewport:
		_setup_viewport_monitoring()
		_calculate_initial_values()
	else:
		push_error("ResponsiveDesignManager: No viewport available for monitoring")

func _setup_viewport_monitoring() -> void:
	"""Setup viewport size change monitoring"""
	if not viewport:
		return
	
	# Connect to viewport size changes
	if viewport.has_signal("size_changed"):
		viewport.size_changed.connect(_on_viewport_size_changed)
	
	# Get initial size
	current_viewport_size = viewport.get_visible_rect().size
	print("ResponsiveDesignManager: Monitoring viewport - Initial size: %s" % current_viewport_size)

func _calculate_initial_values() -> void:
	"""Calculate initial responsive values based on current viewport"""
	if current_viewport_size == Vector2.ZERO:
		return
	
	_update_device_type()
	_update_scaling_mode()
	_update_responsive_values()
	
	print("ResponsiveDesignManager: Initial values calculated - Device: %s, Margins: %.1f, Button: %.1f, Font: %.2f" % [
		DeviceType.keys()[current_device_type], current_margins, current_button_size, current_font_scale
	])

# ============================================================================
# VIEWPORT MONITORING
# ============================================================================

func _on_viewport_size_changed() -> void:
	"""Handle viewport size changes with throttling"""
	var current_time = Time.get_ticks_msec()
	
	# Throttle updates to prevent performance issues
	if current_time - last_update_time < update_throttle_ms:
		return
	
	last_update_time = current_time
	
	var new_size = viewport.get_visible_rect().size
	if new_size != current_viewport_size:
		var old_size = current_viewport_size
		current_viewport_size = new_size
		
		# Update all responsive values
		_update_device_type()
		_update_scaling_mode()
		_update_responsive_values()
		
		# Emit signals
		viewport_size_changed.emit(new_size)
		
		print("ResponsiveDesignManager: Viewport changed %s -> %s" % [old_size, new_size])

# ============================================================================
# DEVICE TYPE CLASSIFICATION
# ============================================================================

func _update_device_type() -> void:
	"""Update device type based on current viewport size"""
	var old_type = current_device_type
	var width = current_viewport_size.x
	
	if width < BREAKPOINT_MOBILE:
		current_device_type = DeviceType.MOBILE
	elif width < BREAKPOINT_TABLET:
		current_device_type = DeviceType.TABLET
	elif width < BREAKPOINT_DESKTOP:
		current_device_type = DeviceType.DESKTOP
	else:
		current_device_type = DeviceType.WIDESCREEN
	
	if old_type != current_device_type:
		device_type_changed.emit(old_type, current_device_type)
		print("ResponsiveDesignManager: Device type changed: %s -> %s" % [
			DeviceType.keys()[old_type], DeviceType.keys()[current_device_type]
		])

func _update_scaling_mode() -> void:
	"""Update scaling mode based on device type"""
	var old_mode = current_scaling_mode
	
	match current_device_type:
		DeviceType.MOBILE:
			current_scaling_mode = ScalingMode.ADAPTIVE
		DeviceType.TABLET:
			current_scaling_mode = ScalingMode.SCALED
		DeviceType.DESKTOP, DeviceType.WIDESCREEN:
			current_scaling_mode = ScalingMode.SCALED
	
	if old_mode != current_scaling_mode:
		scaling_mode_changed.emit(current_scaling_mode)

# ============================================================================
# RESPONSIVE VALUE CALCULATIONS
# ============================================================================

func _update_responsive_values() -> void:
	"""Update all responsive values based on current device type"""
	var old_margins = current_margins
	var old_button_size = current_button_size
	var old_font_scale = current_font_scale
	
	# Calculate new values
	current_margins = _calculate_responsive_margins()
	current_button_size = _calculate_responsive_button_size()
	current_font_scale = _calculate_responsive_font_scale()
	
	# Emit update signal if values changed
	if old_margins != current_margins or old_button_size != current_button_size or old_font_scale != current_font_scale:
		responsive_values_updated.emit(current_margins, current_button_size, current_font_scale)

func _calculate_responsive_margins() -> float:
	"""Calculate responsive margins based on viewport size"""
	var width = current_viewport_size.x
	var percentage: float
	
	match current_device_type:
		DeviceType.MOBILE:
			percentage = MARGIN_MOBILE_PERCENT
		DeviceType.TABLET:
			percentage = MARGIN_TABLET_PERCENT
		DeviceType.DESKTOP, DeviceType.WIDESCREEN:
			percentage = MARGIN_DESKTOP_PERCENT
	
	var calculated_margin = width * percentage
	return clamp(calculated_margin, MARGIN_MIN_PIXELS, MARGIN_MAX_PIXELS)

func _calculate_responsive_button_size() -> float:
	"""Calculate responsive button size based on device type"""
	match current_device_type:
		DeviceType.MOBILE:
			return BUTTON_SIZE_MOBILE
		DeviceType.TABLET:
			return BUTTON_SIZE_TABLET
		DeviceType.DESKTOP, DeviceType.WIDESCREEN:
			return BUTTON_SIZE_DESKTOP
	
	return BUTTON_SIZE_DESKTOP  # Fallback

func _calculate_responsive_font_scale() -> float:
	"""Calculate responsive font scaling based on device type and resolution"""
	var base_scale: float
	
	match current_device_type:
		DeviceType.MOBILE:
			base_scale = FONT_SCALE_MOBILE
		DeviceType.TABLET:
			base_scale = FONT_SCALE_TABLET
		DeviceType.DESKTOP, DeviceType.WIDESCREEN:
			base_scale = FONT_SCALE_DESKTOP
	
	# Adjust based on actual resolution vs expected resolution
	var width = current_viewport_size.x
	var height = current_viewport_size.y
	var resolution_factor = sqrt((width * height) / (1920.0 * 1080.0))  # Normalize to 1080p
	
	var adjusted_scale = base_scale * clamp(resolution_factor, 0.8, 1.3)
	return clamp(adjusted_scale, FONT_SCALE_MIN, FONT_SCALE_MAX)

# ============================================================================
# PUBLIC API
# ============================================================================

## Get current device type
func get_device_type() -> DeviceType:
	return current_device_type

## Get current scaling mode
func get_scaling_mode() -> ScalingMode:
	return current_scaling_mode

## Get current responsive margins
func get_responsive_margins() -> float:
	return current_margins

## Get current responsive button size
func get_responsive_button_size() -> float:
	return current_button_size

## Get current font scale
func get_responsive_font_scale() -> float:
	return current_font_scale

## Get all current responsive values as dictionary
func get_responsive_values() -> Dictionary:
	return {
		"device_type": current_device_type,
		"scaling_mode": current_scaling_mode,
		"margins": current_margins,
		"button_size": current_button_size,
		"font_scale": current_font_scale,
		"viewport_size": current_viewport_size
	}

## Force update of all responsive values
func force_update() -> void:
	"""Force immediate update of all responsive values"""
	if viewport:
		current_viewport_size = viewport.get_visible_rect().size
		_update_device_type()
		_update_scaling_mode()
		_update_responsive_values()

## Apply responsive margins to a MarginContainer
func apply_responsive_margins(margin_container: MarginContainer) -> void:
	"""Apply current responsive margins to a MarginContainer"""
	if not margin_container:
		return
	
	var margin_value = int(current_margins)
	margin_container.add_theme_constant_override("margin_left", margin_value)
	margin_container.add_theme_constant_override("margin_top", margin_value)
	margin_container.add_theme_constant_override("margin_right", margin_value)
	margin_container.add_theme_constant_override("margin_bottom", margin_value)

## Apply responsive button size to a Button
func apply_responsive_button_size(button: Button) -> void:
	"""Apply current responsive button size to a Button"""
	if not button:
		return
	
	var button_size = Vector2(current_button_size, current_button_size * 0.33)  # Maintain aspect ratio
	button.custom_minimum_size = button_size

## Apply responsive font scale to a Control
func apply_responsive_font_scale(control: Control, base_font_size: int = 16) -> void:
	"""Apply current responsive font scale to a Control"""
	if not control:
		return
	
	var scaled_size = int(base_font_size * current_font_scale)
	control.add_theme_font_size_override("font_size", scaled_size)

## Check if device is mobile
func is_mobile() -> bool:
	return current_device_type == DeviceType.MOBILE

## Check if device is tablet
func is_tablet() -> bool:
	return current_device_type == DeviceType.TABLET

## Check if device is desktop or larger
func is_desktop() -> bool:
	return current_device_type in [DeviceType.DESKTOP, DeviceType.WIDESCREEN]

## Get device type as string
func get_device_type_string() -> String:
	return DeviceType.keys()[current_device_type].to_lower()

## Set update throttling (in milliseconds)
func set_update_throttle(throttle_ms: float) -> void:
	update_throttle_ms = max(50.0, throttle_ms)  # Minimum 50ms throttling

## Enable/disable responsive updates
func set_responsive_updates_enabled(enabled: bool) -> void:
	"""Enable or disable responsive updates"""
	if not viewport:
		return
	
	if enabled and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	elif not enabled and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)