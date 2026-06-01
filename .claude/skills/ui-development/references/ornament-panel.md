# OrnamentPanel — Rulebook-Faithful Callout Chrome

Full SOP: `docs/sop/ornament-panel-pattern.md`. This file is the
operationally-focused skill reference (the patterns + the API + the
gotchas you need at the keyboard).

## When to use this component

YES:

- New section card on a dashboard / dialog content panel / mission card
- Stat badge with rulebook-styled rounded chrome
- Any callout that should match Modiphius's panel-corner-bracket recipe
  (NORMS OF THE GAME p.11, CHARACTER CREATION p.12, COVER EXAMPLES p.39,
  READYING FOR BATTLE p.87 — all use this style)

NO:

- Full-screen chapter intro chrome with chapter-title bracket → use `BookFrame`
- Sharp-cornered emphasis box with title inline upper-left (Elite Ranks p.65) → use `CalloutCard`
- Data tables → standard `PanelContainer` with striped row colors
- Plain UI panels with no semantic decoration → standard PanelContainer

## API

```gdscript
const OrnamentPanelScript := preload(
    "res://src/ui/components/common/OrnamentPanel.gd")

var panel: Control = OrnamentPanelScript.new()
panel.custom_minimum_size = Vector2(400, 280)  # determines compact vs standard atlas
panel.accent_color = OrnamentPanelScript.COLOR_PRIMARY  # cyan
panel.title_text = "CREW MANIFEST"  # optional; empty hides banner
panel.add_content_child(my_content_node)
add_child(panel)

# Or one-liner:
panel.setup("CREW MANIFEST", my_vbox, OrnamentPanelScript.COLOR_PRIMARY)
```

6 semantic colors mirror BaseCampaignPanel:
`COLOR_NEUTRAL` / `COLOR_PRIMARY` (cyan default) / `COLOR_SUCCESS` (green) /
`COLOR_WARNING` (gold/amber) / `COLOR_DANGER` (red) / `COLOR_PURPLE`.

## Architecture (one-line)

`extends Control` → inner `PanelContainer` with `StyleBoxFlat` (rounded
+ stroke + bg) + sibling `NinePatchRect` overlay painting the 4 corner
brackets from a procedurally-generated 9-slice atlas. `modulate` on the
NinePatchRect carries the accent color; bg stays constant dark glass.

## Atlas system

Two atlases at `assets/ui/borders/`:

- `ornament_atlas_9slice.png` — 256×256, 64px corner cells. Used for panels with shorter axis ≥256px.
- `ornament_atlas_compact.png` — 128×128, 32px corner cells. Used for badges/stat cards.

Auto-selected by `_resolve_atlas_variant()` based on `custom_minimum_size`
at `_ready()`. Set `custom_minimum_size` BEFORE adding to tree, or the
component picks the wrong atlas.

Both atlases are **procedurally generated** by
`scripts/generate_corner_bracket_atlas.py`. They are NOT extracted from
the Modiphius .ai delivery — that delivery only contains page-chrome
elements (chapter brackets, edge accents, page-corner ornaments at
PAGE corners). The small panel-corner brackets the rulebook uses on
its content panels are typography decoration drawn in InDesign during
typesetting, not delivered as discrete Illustrator assets.

## Critical Gotchas

1. **`custom_minimum_size` must be set BEFORE first `_ready()`** —
   atlas variant is picked once based on declared min size. If you set
   it after `add_child()`, the wrong atlas may load. Use `panel.custom_minimum_size = ...`
   before `add_child(panel)`.

2. **Modulate the NinePatchRect, NOT the OrnamentPanel root** — the
   component already does this internally via `_apply_accent_color()`.
   Setting `modulate` on the root would tint body content too. Use
   `accent_color` setter exclusively for color changes.

3. **Procedural bracket atlas, NOT a Modiphius extract** — if someone
   asks "why aren't we using the Modiphius border art?" the answer is
   the .ai delivery doesn't contain the small panel-corner brackets at
   panel scale. We verified this by extracting at merge_distance=15
   (37 sub-fragments, all page-chrome) and by filesystem-searching the
   delivery. The brackets are procedurally drawn instead.

4. **After tuning bracket shape, MUST re-run `--import`** — bracket
   constants (`*_FRAC` in the generator) → regenerate atlases →
   `Godot --headless --import --quit` → refresh `.import` files →
   THEN runtime test. Skipping the `--import` step leaves stale atlases.
   See [feedback_godot_import_after_asset_add.md].

5. **Visual reads as "fantasy" instead of "sci-fi"** — bracket shape
   too geometrically pure. Add irregularity: more notches per leg,
   stepped tips (gap + thicker endcap at outer end of each leg).
   See `LEG_LENGTH_FRAC`, `STROKE_THICKNESS_FRAC`, `NOTCH_*_FRAC`,
   `TIP_*_FRAC` in `scripts/generate_corner_bracket_atlas.py`. The
   default values produce the Modiphius sci-fi look.

## Tuning Workflow

When a design review wants different bracket character:

1. Edit `*_FRAC` constants in `scripts/generate_corner_bracket_atlas.py`
2. `py scripts/generate_corner_bracket_atlas.py` — regenerates both atlases
3. `Godot --headless --import --quit --path <project>` — required, else stale
4. F6 on `tests/manual/test_ornament_panel.tscn` OR MCP run with `scene` param
5. Visually verify all 6 semantic colors + 3 size variants render correctly

Test scene shows 3 sizes × 6 colors + 3 banner-variants. If any look wrong,
the bracket FRAC constants are the only tuning surface.

## Sci-fi vs fantasy reading

Pure symmetric L = "fantasy RPG corner ornament." What makes it read
"sci-fi machined panel":

- **Multiple notches per leg** (2, not 1) → "access panel detail"
- **Stepped tip** (gap + slightly thicker endcap at outer end of each
  leg) → "hardware terminator," not decoration
- **Slight stroke thickness** (~14-18% of cell size) → too thin is
  decorative, too thick is cartoonish

If the rendered brackets look ornamental rather than functional, ADD
detail. If messy, REMOVE detail or align it better.

## Decision matrix vs other chrome components

| Need | Component | Why |
|------|-----------|-----|
| Section cards, dialog content, mission cards | OrnamentPanel | Rounded + colored stroke + corner brackets matches rulebook callouts |
| Elite-Ranks-style (sharp, title inline upper-left, narrow border) | CalloutCard | Existing component for that specific rulebook variant |
| Chapter-intro / NarrativeScreen / chapter splash | BookFrame | Page-chrome, uses real Modiphius .ai art at native size |
| Stat badge (CREW/TURN/CREDITS) | OrnamentPanel with `custom_minimum_size < 256` | Compact atlas (32px corners) auto-selected |
| Data table | Standard `PanelContainer` | Rulebook tables use striped rows, not bracketed chrome |

## Lessons captured during the build

Took 3+ failed iterations before settling. Avoid the same mistakes:

1. **Don't try to repurpose page-chrome art at panel scale.** The .ai
   ornaments are 170×231 chapter-title composites — cramming them into
   64×64 cells reads as "compressed noise." Get the right source for
   the use case OR generate procedurally.
2. **Render PDFs at >=2x DPI for visual design analysis.** At 80 DPI,
   small panel-corner brackets are invisible — leads to wrong conclusions
   about what the source material actually does.
3. **Build a comparison table of element-usage-by-page-type BEFORE
   coding.** Compare 8-12 pages; surface the rules; THEN design the API.
   Saves multiple iterations.

## Files

| File | Role |
|------|------|
| `src/ui/components/common/OrnamentPanel.gd` | Component |
| `scripts/generate_corner_bracket_atlas.py` | PIL generator for bracket atlases |
| `scripts/build_ornament_9slice_atlas.py` | Inkscape-based edge-strip variant (reserved for future PageChrome) |
| `assets/ui/borders/ornament_atlas_9slice.png` | Standard atlas, 64px corners |
| `assets/ui/borders/ornament_atlas_compact.png` | Compact atlas, 32px corners |
| `tests/manual/test_ornament_panel.tscn` | Visual test scene |
| `assets/ui/borders/ornaments/ornament_*.svg` | RESERVED — Modiphius page-chrome extracts. NOT used by OrnamentPanel. Reserved for future BookFrame work. |
