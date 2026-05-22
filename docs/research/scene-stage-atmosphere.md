# Scene Stage Atmosphere — Research & Design

**Status**: Research / design proposal — not yet built.
**Date**: 2026-05-21
**Owner**: `src/ui/screens/narrative/` (when implemented)
**Replaces nothing**; complements `SceneStage.gd` (current static-stack composer).

## Problem

The extracted PSD layer scenes (BG / Actor / FX / Prop) render as a static
painting. We want **atmospheric motion that responds to game state** — a
"frozen" planet sees falling snow; a "haze" planet sees a soft fog overlay;
a battlefield aftermath shows smoke columns; an interior shows dust motes
in shafts of light.

Two constraints from the production target:

1. **Data-driven**: world traits already exist in `data/world_traits.json`
   and are applied at battle setup via
   `BattlefieldGenerator._apply_world_trait_modifications()`. The
   atmosphere pipeline should consume the same trait IDs — adding a new
   trait shouldn't require a separate "atmosphere catalog" edit.
2. **Reusable across PSDs**: ~50 PSDs in the delivery pipeline. Per-PSD
   atmospheric authoring doesn't scale. One particle effect (e.g.
   `snow`) should apply to any scene shown on a frozen world without
   per-scene config.

## Why GPUParticles2D, not CPUParticles2D

`GPUParticles2D` runs the entire emission/simulation loop in a compute
shader on the GPU. For ambient atmospheric overlays (continuous
emission, hundreds of long-lived particles, no per-particle game logic),
this is essentially free at runtime — the bottleneck is overdraw, not
emission cost.

`CPUParticles2D` runs on the CPU. Use when:
- Compatibility renderer (mobile / web export) is required — no GPU
  particle support there
- You need `emit_particle()` to spawn individual particles in response
  to game events (e.g. a one-shot ember burst at a specific position)
- You need to inspect particle state per-frame from GDScript (e.g.
  collision callbacks)

For Five Parsecs companion-app use: GPUParticles2D for ambient,
CPUParticles2D for event-triggered effects. Both can coexist in the same
scene.

### Critical properties for atmosphere

| Property | Default | Atmospheric value | Why |
|---|---|---|---|
| `amount` | 8 | 50-500 | Scene-wide overlays need density |
| `lifetime` | 1.0 | 4.0-15.0 | Slow-falling snow / drifting dust / rising smoke |
| `preprocess` | 0.0 | 2.0-5.0 | **Critical** — without this, scene starts with an empty sky and fills up over `lifetime` seconds. Set to ≥lifetime so the first frame already shows steady-state particle distribution |
| `emitting` | true | toggled per trait | Off when trait inactive |
| `one_shot` | false | false (ambient) / true (event) | One-shot for explosions/sparks; false for continuous |
| `local_coords` | false | false | Particles persist in world space — important when the scene scrolls or transitions |
| `fixed_fps` | 30 | 30 | Decouples particle motion from variable frame rate; 30 is fine for atmospheric |
| `visibility_aabb` (3D) / `visibility_rect` (2D CPU) | small | scene-wide | Must cover the full canvas or particles disappear when emitter is off-screen |

**`preprocess` warning**: "Can be very expensive if set to a high number"
— runs the particle shader at `fixed_fps` * `preprocess` iterations on
the first frame. Cap at 5-10 seconds; if you need more, your `lifetime`
is too long for the effect.

## Atmospheric effect catalog (proposed initial set)

Five effects cover ~80% of the visual space we'd want. Each is one
GPUParticles2D + one ParticleProcessMaterial config. Authored once,
applied many times.

| Effect | World traits that trigger | Particle config | Z-order |
|---|---|---|---|
| `snow` | `frozen`, `arctic_storm` (Compendium addition if needed) | Top-down emission, gravity (0, 80), spread 5°, scale_curve falloff, white-blue color ramp, lifetime 8s | Above FX layer, below UI |
| `dust_motes` | (default for any interior scene with no overriding trait) | Box emission shape covering canvas, near-zero gravity, slow drift, white color, very low alpha, lifetime 12s | Above BG, below actors |
| `fog_haze` | `haze`, `fog`, `gloom` | Box emission across bottom 60% of canvas, very slow upward drift, gray-white tint, high alpha-curve falloff, lifetime 6s | Above FX layer |
| `embers` | (event-triggered after battle, or scenes with fire props) | Point/area emission, gravity (0, -40) for rising, orange-red color ramp, additive blend mode, lifetime 3s | Above FX layer |
| `smoke_columns` | (event-triggered for burning ships/wreckage scenes) | Multi-point emission (per-prop wreckage), rising gravity, gray-brown ramp, large scale_curve, lifetime 5s | Above FX layer |

Authoring scope per effect: ~50 lines of GDScript (ParticleProcessMaterial
config) + 1 texture (32-64px white circle for snow, soft blob for
smoke, etc.). Estimated 1-2 hours per effect at quality bar.

## World-trait → atmosphere mapping

Read `data/world_traits.json` once at app start. For each trait, look up
`atmosphere_effect` in a parallel mapping file (new):

```json
// data/atmosphere/world_trait_atmosphere.json
{
  "_source": "Design doc docs/research/scene-stage-atmosphere.md",
  "trait_to_effect": {
    "frozen":          { "effect": "snow", "intensity": 1.0 },
    "haze":            { "effect": "fog_haze", "intensity": 0.5 },
    "fog":             { "effect": "fog_haze", "intensity": 1.0 },
    "gloom":           { "effect": "fog_haze", "intensity": 0.7 },
    "reflective_dust": { "effect": "dust_motes", "intensity": 1.5 },
    "warzone":         { "effect": "smoke_columns", "intensity": 0.3 }
  },
  "default_interior_effect": { "effect": "dust_motes", "intensity": 0.4 }
}
```

`intensity` scales `amount_ratio` on the GPUParticles2D node — same
particle config, dialable density per trait. A `null_zone` trait could
override to `{ "effect": "none" }` to suppress the default dust_motes.

**Why a parallel file, not adding fields to `world_traits.json`**:
`world_traits.json` is canonical rules data (Core Rules pp.72-75) and
should not gain visual-only fields. The atmosphere mapping is a UI
concern; the trait IDs are the integration contract between them.

## Code architecture

```
src/ui/screens/narrative/
├── SceneStage.gd                 # (existing — unchanged for v1 of atmosphere)
├── SceneAtmosphereLayer.gd       # NEW — Control wrapper around atmosphere particles
├── AtmosphereCatalog.gd          # NEW — RefCounted static loader (JSON → effect configs)
└── particles/                    # NEW — one .gd per effect type
    ├── SnowParticles.gd          # builds GPUParticles2D + ParticleProcessMaterial for snow
    ├── DustMotesParticles.gd
    ├── FogHazeParticles.gd
    ├── EmbersParticles.gd
    └── SmokeColumnsParticles.gd
```

### `SceneAtmosphereLayer.gd` public API

```gdscript
extends Control

func set_atmosphere(effect_id: String, intensity: float = 1.0) -> void
func set_atmosphere_for_world_traits(traits: Array) -> void  # picks first matching
func clear_atmosphere() -> void
func add_event_effect(effect_id: String, position: Vector2) -> void  # one-shot
```

### Integration sketch in NarrativeScreen

```gdscript
@onready var stage: Control = $SceneStage
@onready var atmosphere: Control = $SceneAtmosphereLayer

func _show_scene(scene_id: String, world_traits: Array) -> void:
    stage.set_scene(scene_id)
    atmosphere.set_atmosphere_for_world_traits(world_traits)
```

The atmosphere layer is a sibling of SceneStage (z-ordered above it via
scene tree position) — keeps the two concerns independent. SceneStage
doesn't need to know about atmosphere; atmosphere doesn't need to know
about layer composition.

### Single-source-of-truth path-loaded pattern

Same convention as `ModeInfoCatalog`, `PlanetfallPresetCrew`, etc.:
- `AtmosphereCatalog.gd` is `extends RefCounted`, no `class_name`
- Consumers preload via `const AtmosphereCatalog = preload(...)`
- Static `_cache` + `_ensure_loaded()` pattern
- Returns `{effect: String, intensity: float}` Dictionary

(Documented as the SSOT pattern in `docs/sop/component-patterns.md`.)

## Performance budget

Order-of-magnitude estimate, no measurements yet:

| Effect | Amount | Lifetime | Particles on screen | GPU cost |
|---|---|---|---|---|
| snow | 300 | 8s | ~300 simultaneous | Cheap — small textured quads |
| dust_motes | 100 | 12s | ~100 | Negligible |
| fog_haze | 200 | 6s | ~200 | Moderate — overdraw if alpha is high |
| embers (event burst) | 50 | 3s | ≤50 | Negligible (short-lived) |
| smoke_columns (event) | 100 per source | 5s | ~500 worst case | Moderate — alpha overdraw |

For a tabletop companion app at 60fps target on integrated GPUs, total
budget should stay under ~1500 simultaneous 2D particles to leave
headroom for the rest of the UI. The mapping above stays well under
that.

**Compatibility renderer note**: If we ever export to mobile/web with
the Compatibility renderer, GPUParticles2D won't work — need to swap to
CPUParticles2D. Defer this concern until export time; the per-effect
`.gd` files are the right swap point.

## Prototype roadmap

**Phase A (research validation, 1 day)**:
- Implement `SnowParticles.gd` only
- Drop a SceneAtmosphereLayer onto Meeting.psd's SceneStage via MCP
  injection (no production code modified)
- Visually verify snow renders on top of the layered scene at the right
  z-order
- Measure FPS impact

**Phase B (catalog buildout, ~1 week)**:
- Implement the other 4 effects (dust_motes, fog_haze, embers,
  smoke_columns)
- Write `AtmosphereCatalog.gd` + `data/atmosphere/world_trait_atmosphere.json`
- Wire `SceneAtmosphereLayer.set_atmosphere_for_world_traits()`

**Phase C (NarrativeScreen integration, depends on NarrativeScreen
existing)**:
- Add SceneAtmosphereLayer sibling to NarrativeScreen's SceneStage
- Plumb world-traits-array from campaign state through to the
  atmosphere call

**Out of scope for v1**:
- Per-PSD atmosphere overrides (a scene manifest could opt out / force
  a specific effect — defer until we hit a case)
- Wind direction from compass-rose data (snow falls vertically; angled
  snow can come later)
- Audio: ambient SFX (wind, rain) should pair with atmosphere effects
  but lives in a separate AudioManager track
- Particle collision with FX/Prop layers
- Skinned particle textures (real snowflake shape, real smoke billow)
  — start with simple white circles, upgrade textures later

## Resolved design decisions (May 21, 2026)

1. **Dust motes are default-on for every scene** unless a world trait
   explicitly overrides. `AtmosphereCatalog` returns
   `default_interior_effect` from the JSON when no trait matches. A
   future `suppress_atmosphere: true` flag on a SceneStage manifest can
   opt out per-PSD if a vacuum/underwater scene needs it; defer until
   we hit a case.
2. **MainMenu mode-showcase covers stay atmosphere-free.** Menus stay
   snappy. Atmosphere is gameplay-only. Revisit only if marketing
   screenshots demand it later — and even then, as a static-frame
   render, not a live particle system on the menu.
3. **`add_event_effect(id, position)` ships in v1.** Designing the API
   in v2 would require retrofitting; designing it now is cheap.
   Even with no narrative-event listener wired today, the hook is
   ready for `narrative_event_fired` consumers (punch lands → embers,
   ship destroyed → smoke columns). Implementation note: use
   `CPUParticles2D` for event-triggered one-shots (need `emit_particle()`
   and the `finished` signal); reserve `GPUParticles2D` for ambient.

## References

- `data/world_traits.json` — world trait definitions (Core Rules
  pp.72-75)
- `src/core/battle/BattlefieldGenerator.gd:418-510` —
  `_apply_world_trait_modifications()`, parallel consumer of the same
  trait IDs
- `src/ui/screens/narrative/SceneStage.gd` — existing layer-composer,
  unchanged by this design
- `addons/TweenFX/TweenFX.gd` — looping animation primitives (breathe,
  float_bob, etc.) — separately covers per-layer motion (Tier 0)
- Godot 4.6 docs:
  [GPUParticles2D](https://docs.godotengine.org/en/4.6/classes/class_gpuparticles2d.html),
  [ParticleProcessMaterial](https://docs.godotengine.org/en/4.6/classes/class_particleprocessmaterial.html),
  [CPUParticles2D](https://docs.godotengine.org/en/4.6/classes/class_cpuparticles2d.html)
