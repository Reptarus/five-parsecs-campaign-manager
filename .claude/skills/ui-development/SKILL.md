---
name: ui-development
description: "Use this skill when working with UI panels, components, the Deep Space theme, responsive layout, TweenFX animations, or scene routing. Covers BaseCampaignPanel (FiveParsecsCampaignPanel), SceneRouter, TweenFX addon, and all general UI components and screens."
---

# UI Development

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/deep-space-theme.md` | Complete color palette, 8px spacing grid, typography scale, BBCode colors, all constants |
| `references/panel-patterns.md` | BaseCampaignPanel factory methods, signal-up/call-down, responsive layout, glass card styles |
| `references/tweenfx-guide.md` | 70 animations, pivot_offset requirement list, looping cleanup, accessibility, .tada() signature |
| `references/scene-router.md` | SceneRouter 70+ routes, navigation methods, history, caching, category helpers |

## Quick Decision Tree

- **Styling/colors/spacing** → Read `deep-space-theme.md`
- **Creating new panels** → Read `panel-patterns.md`
- **Adding animations** → Read `tweenfx-guide.md`
- **Scene navigation** → Read `scene-router.md`
- **Responsive layout** → Read `panel-patterns.md` (responsive section)
- **Button styling** → Read `panel-patterns.md` (_style_button section)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/ui/screens/campaign/panels/BaseCampaignPanel.gd` | `FiveParsecsCampaignPanel` | Base panel with theme + factory methods |
| `src/ui/screens/SceneRouter.gd` | Autoload | Scene navigation (70+ routes) |
| `addons/TweenFX/TweenFX.gd` | Autoload | 70 animation types |
| `src/ui/components/` | 125+ files | Reusable UI components |

## Critical Gotchas

1. **TweenFX pivot_offset** — MUST set `node.pivot_offset = node.size / 2` before scale/rotation animations
2. **TweenFX looping** — `alarm`, `breathe`, `attract`, `glow_pulse` must be explicitly stopped
3. **TweenFX.tada()** — Only takes 2 args `(node, duration)`, no scale parameter
4. **UIColors.should_animate()** — Check before adding animations (accessibility/reduced motion)
5. **Never hardcode colors** — always use theme constants from BaseCampaignPanel
