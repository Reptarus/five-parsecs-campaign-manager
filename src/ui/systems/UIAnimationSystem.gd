class_name UIAnimationSystem
extends RefCounted

## UI Animation System for Five Parsecs Campaign Manager
## Provides consistent, reusable animations throughout the UI

# Animation presets
enum AnimationType {
	FADE_IN,
	FADE_OUT,
	SLIDE_IN_LEFT,
	SLIDE_IN_RIGHT,
	SLIDE_IN_UP,
	SLIDE_IN_DOWN,
	SLIDE_OUT_LEFT,
	SLIDE_OUT_RIGHT,
	SLIDE_OUT_UP,
	SLIDE_OUT_DOWN,
	SCALE_IN,
	SCALE_OUT,
	BOUNCE_IN,
	BOUNCE_OUT,
	PULSE,
	SHAKE,
	HIGHLIGHT_FLASH,
	BUTTON_PRESS,
	CARD_FLIP,
	EXPAND_COLLAPSE
}

# Animation durations
const ANIMATION_DURATIONS = {
	AnimationType.FADE_IN: 0.3,
	AnimationType.FADE_OUT: 0.25,
	AnimationType.SLIDE_IN_LEFT: 0.4,
	AnimationType.SLIDE_IN_RIGHT: 0.4,
	AnimationType.SLIDE_IN_UP: 0.4,
	AnimationType.SLIDE_IN_DOWN: 0.4,
	AnimationType.SLIDE_OUT_LEFT: 0.3,
	AnimationType.SLIDE_OUT_RIGHT: 0.3,
	AnimationType.SLIDE_OUT_UP: 0.3,
	AnimationType.SLIDE_OUT_DOWN: 0.3,
	AnimationType.SCALE_IN: 0.3,
	AnimationType.SCALE_OUT: 0.25,
	AnimationType.BOUNCE_IN: 0.5,
	AnimationType.BOUNCE_OUT: 0.4,
	AnimationType.PULSE: 1.0,
	AnimationType.SHAKE: 0.5,
	AnimationType.HIGHLIGHT_FLASH: 0.6,
	AnimationType.BUTTON_PRESS: 0.1,
	AnimationType.CARD_FLIP: 0.8,
	AnimationType.EXPAND_COLLAPSE: 0.4
}

# Easing presets for different animation types
const EASING_PRESETS = {
	AnimationType.FADE_IN: Tween.EASE_OUT,
	AnimationType.FADE_OUT: Tween.EASE_IN,
	AnimationType.SLIDE_IN_LEFT: Tween.EASE_OUT,
	AnimationType.SLIDE_IN_RIGHT: Tween.EASE_OUT,
	AnimationType.SLIDE_IN_UP: Tween.EASE_OUT,
	AnimationType.SLIDE_IN_DOWN: Tween.EASE_OUT,
	AnimationType.SCALE_IN: Tween.EASE_OUT,
	AnimationType.SCALE_OUT: Tween.EASE_IN,
	AnimationType.BOUNCE_IN: Tween.EASE_OUT,
	AnimationType.PULSE: Tween.EASE_IN_OUT
}

## ===== MAIN ANIMATION METHODS =====

static func animate(target: Node, animation_type: AnimationType, duration: float = -1.0, callback: Callable = Callable()) -> Tween:
	"""Main animation method - animates target with specified type"""
	if not is_instance_valid(target):
		return null
	var tween = target.create_tween()

	var anim_duration = duration if duration > 0 else ANIMATION_DURATIONS.get(animation_type, 0.3)

	var easing = EASING_PRESETS.get(animation_type, Tween.EASE_OUT)

	match animation_type:
		AnimationType.FADE_IN:
			_animate_fade_in(target, tween, anim_duration, easing)
		AnimationType.FADE_OUT:
			_animate_fade_out(target, tween, anim_duration, easing)
		AnimationType.SLIDE_IN_LEFT:
			_animate_slide_in_left(target, tween, anim_duration, easing)
		AnimationType.SLIDE_IN_RIGHT:
			_animate_slide_in_right(target, tween, anim_duration, easing)
		AnimationType.SLIDE_IN_UP:
			_animate_slide_in_up(target, tween, anim_duration, easing)
		AnimationType.SLIDE_IN_DOWN:
			_animate_slide_in_down(target, tween, anim_duration, easing)
		AnimationType.SLIDE_OUT_LEFT:
			_animate_slide_out_left(target, tween, anim_duration, easing)
		AnimationType.SLIDE_OUT_RIGHT:
			_animate_slide_out_right(target, tween, anim_duration, easing)
		AnimationType.SLIDE_OUT_UP:
			_animate_slide_out_up(target, tween, anim_duration, easing)
		AnimationType.SLIDE_OUT_DOWN:
			_animate_slide_out_down(target, tween, anim_duration, easing)
		AnimationType.SCALE_IN:
			_animate_scale_in(target, tween, anim_duration, easing)
		AnimationType.SCALE_OUT:
			_animate_scale_out(target, tween, anim_duration, easing)
		AnimationType.BOUNCE_IN:
			_animate_bounce_in(target, tween, anim_duration)
		AnimationType.BOUNCE_OUT:
			_animate_bounce_out(target, tween, anim_duration)
		AnimationType.PULSE:
			_animate_pulse(target, tween, anim_duration)
		AnimationType.SHAKE:
			_animate_shake(target, tween, anim_duration)
		AnimationType.HIGHLIGHT_FLASH:
			_animate_highlight_flash(target, tween, anim_duration)
		AnimationType.BUTTON_PRESS:
			_animate_button_press(target, tween, anim_duration)
		AnimationType.CARD_FLIP:
			_animate_card_flip(target, tween, anim_duration)
		AnimationType.EXPAND_COLLAPSE:
			_animate_expand_collapse(target, tween, anim_duration)

	if callback.is_valid():
		tween.tween_callback(callback)

	return tween

## ===== ANIMATION IMPLEMENTATIONS =====

static func _animate_fade_in(target: Node, tween: Tween, duration: float, easing: int):
	target.modulate.a = 0.0
	tween.tween_property(target, "modulate:a", 1.0, duration).set_ease(easing)

static func _animate_fade_out(target: Node, tween: Tween, duration: float, easing: int):
	tween.tween_property(target, "modulate:a", 0.0, duration).set_ease(easing)

static func _animate_slide_in_left(target: Node, tween: Tween, duration: float, easing: int):
	var original_pos = target.position
	target.position.x -= 200
	target.modulate.a = 0.0

	tween.parallel().tween_property(target, "position:x", original_pos.x, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.7).set_ease(easing)

static func _animate_slide_in_right(target: Node, tween: Tween, duration: float, easing: int):
	var original_pos = target.position
	target.position.x += 200
	target.modulate.a = 0.0

	tween.parallel().tween_property(target, "position:x", original_pos.x, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.7).set_ease(easing)

static func _animate_slide_in_up(target: Node, tween: Tween, duration: float, easing: int):
	var original_pos = target.position
	target.position.y += 150
	target.modulate.a = 0.0

	tween.parallel().tween_property(target, "position:y", original_pos.y, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.7).set_ease(easing)

static func _animate_slide_in_down(target: Node, tween: Tween, duration: float, easing: int):
	var original_pos = target.position
	target.position.y -= 150
	target.modulate.a = 0.0

	tween.parallel().tween_property(target, "position:y", original_pos.y, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.7).set_ease(easing)

static func _animate_slide_out_left(target: Node, tween: Tween, duration: float, easing: int):
	var target_pos = target.position
	target_pos.x -= 200

	tween.parallel().tween_property(target, "position:x", target_pos.x, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.8).set_ease(easing)

static func _animate_slide_out_right(target: Node, tween: Tween, duration: float, easing: int):
	var target_pos = target.position
	target_pos.x += 200

	tween.parallel().tween_property(target, "position:x", target_pos.x, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.8).set_ease(easing)

static func _animate_slide_out_up(target: Node, tween: Tween, duration: float, easing: int):
	var target_pos = target.position
	target_pos.y -= 150

	tween.parallel().tween_property(target, "position:y", target_pos.y, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.8).set_ease(easing)

static func _animate_slide_out_down(target: Node, tween: Tween, duration: float, easing: int):
	var target_pos = target.position
	target_pos.y += 150

	tween.parallel().tween_property(target, "position:y", target_pos.y, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.8).set_ease(easing)

static func _animate_scale_in(target: Node, tween: Tween, duration: float, easing: int):
	target.scale = Vector2.ZERO
	target.modulate.a = 0.7

	tween.parallel().tween_property(target, "scale", Vector2.ONE, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.6).set_ease(easing)

static func _animate_scale_out(target: Node, tween: Tween, duration: float, easing: int):
	tween.parallel().tween_property(target, "scale", Vector2.ZERO, duration).set_ease(easing)
	tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.8).set_ease(easing)

static func _animate_bounce_in(target: Node, tween: Tween, duration: float):
	target.scale = Vector2.ZERO
	target.modulate.a = 0.8

	# Bounce effect with multiple keyframes
	tween.parallel().tween_property(target, "scale", Vector2(1.2, 1.2), duration * 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(target, "scale", Vector2.ONE, duration * 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.3)

static func _animate_bounce_out(target: Node, tween: Tween, duration: float):
	tween.tween_property(target, "scale", Vector2(1.1, 1.1), duration * 0.3).set_trans(Tween.TRANS_ELASTIC)
	tween.chain().tween_property(target, "scale", Vector2.ZERO, duration * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.5)

static func _animate_pulse(target: Node, tween: Tween, duration: float):
	var original_scale = target.scale
	var pulse_scale = Vector2(1.1, 1.1)

	tween.tween_property(target, "scale", pulse_scale, duration * 0.5).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(target, "scale", original_scale, duration * 0.5).set_trans(Tween.TRANS_SINE)

static func _animate_shake(target: Node, tween: Tween, duration: float):
	var original_pos = target.position
	var shake_strength: int = 5
	var shake_count: int = 8

	for i in shake_count:
		var shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		var shake_duration = duration / shake_count
		tween.tween_property(target, "position", original_pos + shake_offset, shake_duration)
		tween.chain()

	tween.tween_property(target, "position", original_pos, duration / shake_count)

static func _animate_highlight_flash(target: Node, tween: Tween, duration: float):
	var original_modulate = target.modulate
	var highlight_color = Color(1.4, 1.4, 1.0, 1.0) # Bright yellow tint

	tween.tween_property(target, "modulate", highlight_color, duration * 0.2)
	tween.chain().tween_property(target, "modulate", original_modulate, duration * 0.8)

static func _animate_button_press(target: Node, tween: Tween, duration: float):
	var original_scale = target.scale
	var pressed_scale = Vector2(0.95, 0.95)

	tween.tween_property(target, "scale", pressed_scale, duration * 0.5).set_trans(Tween.TRANS_QUART)
	tween.chain().tween_property(target, "scale", original_scale, duration * 0.5).set_trans(Tween.TRANS_ELASTIC)

static func _animate_card_flip(target: Node, tween: Tween, duration: float):
	var original_scale = target.scale

	# Flip horizontally
	tween.tween_property(target, "scale:x", 0.0, duration * 0.5).set_trans(Tween.TRANS_QUART)
	tween.chain().tween_property(target, "scale:x", original_scale.x, duration * 0.5).set_trans(Tween.TRANS_QUART)

static func _animate_expand_collapse(target: Node, tween: Tween, duration: float):
	var is_expanded = target.get_meta("is_expanded", false)

	if is_expanded:
		# Collapse
		tween.tween_property(target, "scale:y", 0.0, duration).set_trans(Tween.TRANS_QUART)
		tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.8)
		target.set_meta("is_expanded", false)
	else:
		# Expand
		target.scale.y = 0.0
		target.modulate.a = 0.0
		tween.tween_property(target, "scale:y", 1.0, duration).set_trans(Tween.TRANS_QUART)
		tween.parallel().tween_property(target, "modulate:a", 1.0, duration * 0.6)
		target.set_meta("is_expanded", true)

## ===== CONVENIENCE METHODS =====

static func fade_in(target: Node, duration: float = 0.3, callback: Callable = Callable()) -> Tween:
	"""Convenience method for fade in animation"""
	return animate(target, AnimationType.FADE_IN, duration, callback)

static func fade_out(target: Node, duration: float = 0.25, callback: Callable = Callable()) -> Tween:
	"""Convenience method for fade out animation"""
	return animate(target, AnimationType.FADE_OUT, duration, callback)

static func slide_in_from_left(target: Node, duration: float = 0.4, callback: Callable = Callable()) -> Tween:
	"""Convenience method for slide in from left"""
	return animate(target, AnimationType.SLIDE_IN_LEFT, duration, callback)

static func slide_in_from_right(target: Node, duration: float = 0.4, callback: Callable = Callable()) -> Tween:
	"""Convenience method for slide in from right"""
	return animate(target, AnimationType.SLIDE_IN_RIGHT, duration, callback)

static func scale_in(target: Node, duration: float = 0.3, callback: Callable = Callable()) -> Tween:
	"""Convenience method for scale in animation"""
	return animate(target, AnimationType.SCALE_IN, duration, callback)

static func bounce_in(target: Node, duration: float = 0.5, callback: Callable = Callable()) -> Tween:
	"""Convenience method for bounce in animation"""
	return animate(target, AnimationType.BOUNCE_IN, duration, callback)

static func pulse(target: Node, duration: float = 1.0, callback: Callable = Callable()) -> Tween:
	"""Convenience method for pulse animation"""
	return animate(target, AnimationType.PULSE, duration, callback)

static func shake(target: Node, duration: float = 0.5, callback: Callable = Callable()) -> Tween:
	"""Convenience method for shake animation"""
	return animate(target, AnimationType.SHAKE, duration, callback)

static func highlight_flash(target: Node, duration: float = 0.6, callback: Callable = Callable()) -> Tween:
	"""Convenience method for highlight flash"""
	return animate(target, AnimationType.HIGHLIGHT_FLASH, duration, callback)

static func button_press_animation(target: Node, duration: float = 0.1, callback: Callable = Callable()) -> Tween:
	"""Convenience method for button press animation"""
	return animate(target, AnimationType.BUTTON_PRESS, duration, callback)

## ===== COMPLEX ANIMATION SEQUENCES =====

static func sequence_fade_in_elements(elements: Array[Node], stagger_delay: float = 0.1) -> Array[Tween]:
	"""Animate multiple elements fading in with staggered timing"""
	var tweens: Array[Tween] = []

	for i: int in range(elements.size()):
		var element = elements[i]
		if is_instance_valid(element):
			var delay = i * stagger_delay
			var tween = element.create_tween()

			element.modulate.a = 0.0
			tween.tween_delay(delay)
			tween.tween_property(element, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

			tweens.append(tween)

	return tweens

static func sequence_slide_in_elements(elements: Array[Node], direction: AnimationType = AnimationType.SLIDE_IN_LEFT, stagger_delay: float = 0.1) -> Array[Tween]:
	"""Animate multiple elements sliding in with staggered timing"""
	var tweens: Array[Tween] = []

	for i: int in range(elements.size()):
		var element = elements[i]
		if is_instance_valid(element):
			var delay = i * stagger_delay
			var tween = element.create_tween()

			tween.tween_delay(delay)
			var anim_tween = animate(element, direction)

			tweens.append(anim_tween)

	return tweens

static func create_loading_animation(target: Node) -> Tween:
	"""Create a continuous loading animation"""
	var tween = target.create_tween()
	tween.set_loops()

	tween.tween_property(target, "rotation", TAU, 1.0).set_trans(Tween.TRANS_LINEAR)

	return tween

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null