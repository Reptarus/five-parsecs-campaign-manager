# Chapter 15: Settings and Accessibility

> **Quick Start** (for tabletop veterans)
> - Access Settings from Main Menu > Options
> - Theme options: dark (default Deep Space) / light
> - Reduced animation: disables TweenFX effects for motion sensitivity
> - Text size: adjustable for readability
> - Touch targets: minimum 48px, comfortable mode at 56px

## Overview

The Settings screen lets you customize the app's appearance and behavior. Accessibility features ensure the app is usable by players with different needs, including those sensitive to animation, those who prefer larger text, or those using touch interfaces.

## Accessing Settings

Open Settings from:
- **Main Menu** > **Options** button
- In-game via the settings icon (where available)

## Visual Theme

### Deep Space Theme (Default)

The app uses a dark navy theme designed for comfortable extended play:

- Dark backgrounds reduce eye strain in low-light environments
- Cyan highlights for interactive elements
- Green/orange/red color coding for status information

### Theme Options

- **Dark mode** (default) — Deep Space navy palette
- **Light mode** — Lighter backgrounds for bright environments
- **High contrast** — Enhanced color contrast for visibility

## Text Size

Adjust text size across the entire app:

- **Small** (11-14px) — Compact, more information on screen
- **Medium** (14-16px) — Default, balanced readability
- **Large** (16-20px) — Easier to read, especially on small screens
- **Extra Large** (20-24px) — Maximum readability

Text size affects all UI elements: buttons, labels, descriptions, battle log, and help content.

## Animation Settings

### Reduced Animation

Toggle to disable decorative animations throughout the app:

When **enabled** (reduced animation ON):
- Fade transitions between screens are shortened or removed
- Button press animations are disabled
- Pulsing/breathing effects on UI elements are removed
- Battle companion animations are simplified

When **disabled** (reduced animation OFF, default):
- Full TweenFX animations play (70+ animation types)
- Smooth transitions between screens
- Interactive feedback animations on buttons and panels

This setting is respected by all screens via the `UIColors.should_animate()` check.

### Why Reduce Animation?

- **Motion sensitivity** — Some people experience discomfort from screen animations
- **Performance** — Older devices may run smoother with animations disabled
- **Preference** — Some players simply prefer a static interface

## Touch and Input

### Touch Targets

The app is designed for both mouse/keyboard and touch interfaces:

- **Minimum touch target**: 48px — All interactive elements meet this minimum
- **Comfortable touch target**: 56px — Input fields and primary buttons use this larger size

### Mobile Layout

On smaller screens (phones and tablets), the app automatically adapts:

- Single-column layouts replace multi-column on narrow screens
- Sidebars collapse into dropdown menus
- Touch targets increase to comfortable size
- Font sizes adjust for readability

The responsive system uses three breakpoints:
- **Mobile** (< 480px) — Single column, large touch targets
- **Tablet** (480-768px) — Two columns, standard touch targets
- **Desktop** (> 768px) — Full multi-column layout

## Dice System Settings

Configure how dice rolling works:

- **Auto-Roll** (default) — The app rolls dice digitally
- **Manual Input** — The app prompts you to enter physical dice results
- **Hybrid** — Auto-roll by default, with option to override specific rolls

See the dice system details in {{chapter:06}}.

## Data and Privacy

- All campaign data is stored locally on your device
- No data is sent to external servers
- DLC purchases are handled through platform stores (Steam/Google Play/App Store)
- Review prompts appear after 5+ turns and respect a 30-day cooldown

## Accessibility Checklist

If you have specific accessibility needs:

| Need | Setting |
|------|---------|
| Sensitive to motion | Enable **Reduced Animation** |
| Difficulty reading small text | Increase **Text Size** to Large or Extra Large |
| Using a touch device | App automatically applies touch-friendly sizes |
| Color vision differences | Use **High Contrast** theme |
| Bright environments | Switch to **Light** theme |
| Low-light environments | Use default **Dark** theme (Deep Space) |

## What's Next?

- Return to the beginning: {{chapter:01}} — Getting Started
- For the full Table of Contents: {{chapter:00}}
