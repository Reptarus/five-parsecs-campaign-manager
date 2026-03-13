# TweenFX Animation Guide

## Addon Info
- **Path**: `addons/TweenFX/TweenFX.gd`
- **Autoloaded as**: `TweenFX`
- **Version**: v1.2 (EvilBunnyMan)
- **70 animations** available

## CRITICAL: pivot_offset Requirement

TweenFX NEVER sets `pivot_offset`. You MUST call:
```gdscript
node.pivot_offset = node.size / 2
```
BEFORE any scale/rotation animation.

### Needs pivot_offset
`press`, `pop_in`, `pulsate`, `punch_in`, `breathe`, `tada`, `critical_hit`, `upgrade`, `attract`, `headshake`

### Safe WITHOUT pivot_offset
`fade_in`, `fade_out`, `blink`, `spotlight`, `alarm`, `shake`, `flash`, `flicker`, `ghost`

## Looping Animations (Must Stop Explicitly)

These loop forever until stopped:
- `alarm`
- `breathe`
- `attract`
- `glow_pulse`

**Cleanup pattern**:
```gdscript
# Stop specific animation
TweenFX.stop(node, TweenFX.Animations.BREATHE)

# Stop all animations on node
TweenFX.stop_all(node)
```

Always stop looping animations in `_exit_tree()`, panel hide code, or cleanup functions.

## Signature Gotcha

**TweenFX.tada()** takes only 2 arguments:
```gdscript
TweenFX.tada(node, duration)  # CORRECT — no scale parameter
TweenFX.tada(node, duration, scale)  # WRONG — will error
```

## Accessibility

Check before adding animations:
```gdscript
if UIColors.should_animate():
    node.pivot_offset = node.size / 2
    TweenFX.breathe(node, 1.5)
```

`UIColors.should_animate()` checks `ThemeManager._reduced_animation` flag.

## Common Animation Patterns

### Button Press Feedback
```gdscript
func _on_button_pressed():
    button.pivot_offset = button.size / 2
    TweenFX.press(button, 0.15)
```

### Card Entry Animation
```gdscript
func _show_card(card: Control):
    TweenFX.fade_in(card, 0.3)  # No pivot needed
```

### Attention Pulse (Looping)
```gdscript
func _highlight_action():
    if UIColors.should_animate():
        button.pivot_offset = button.size / 2
        TweenFX.breathe(button, 1.5)

func _stop_highlight():
    TweenFX.stop(button, TweenFX.Animations.BREATHE)
```

### Stagger Reveal
```gdscript
for i in cards.size():
    await get_tree().create_timer(0.1 * i).timeout
    TweenFX.fade_in(cards[i], 0.2)
```
