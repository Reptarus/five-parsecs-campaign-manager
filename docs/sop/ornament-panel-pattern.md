# Ornament Panel Pattern

How we build rulebook-faithful panel chrome in the Five Parsecs UI.

**Read this when**: writing new panels that should match the Modiphius rulebook's
sci-fi tech aesthetic (corner brackets + colored stroke + optional title banner),
OR before tweaking `OrnamentPanel.gd` / the bracket-atlas generator.

## What the rulebook actually does (confirmed via 11-page visual analysis)

Every content panel in the Modiphius rulebook uses the same recipe:

1. **Rounded rectangle** (corner radius ~12px)
2. **Colored stroke** (~2px, chapter accent color)
3. **Small angular brackets at all 4 corners** — these are the "sci-fi tech panel
   access" detail. Important properties:
   - **Same shape mirrored 4 ways**: the rulebook uses ONE bracket art piece,
     flipped horizontally + vertically to fill all 4 corners. Not 4 unique pieces.
   - **Fixed pixel size** regardless of panel size: a tiny page-number badge has
     the same bracket size as a giant section panel. This is what rules out
     stretching textures (single-image scaling won't preserve corner size at
     different panel scales).
4. **Optional title banner** (rounded sub-panel at top-center) OR inline title
   in the upper-left inside the border (Elite Ranks p.65 style)
5. **Body content** with comfortable padding

6 semantic colors mirror BaseCampaignPanel and cover the chapter accents
observed in the rulebook: cyan (PRIMARY, default), red (DANGER — Character
Creation), gold/amber (WARNING — Campaign Preparation / Battles), green
(SUCCESS — Post-Battle), purple (PURPLE — Appendices / GM tools), neutral
white (NEUTRAL — no semantic emphasis). All use the SAME bracket art, just
`modulate`d to the chapter color.

## Architecture

```text
OrnamentPanel (Control, PRESET_FULL_RECT)
  ├── BackgroundPanel (PanelContainer, StyleBoxFlat: rounded + colored stroke)
  │     └── VBoxContainer
  │           ├── BannerRow (HBoxContainer, centers banner) — visible only when title_text non-empty
  │           │     └── TitleBanner (PanelContainer with smaller StyleBoxFlat)
  │           │           └── Label (uppercase, accent color)
  │           └── ContentSlot (MarginContainer — consumer adds children here)
  └── OrnamentLayer (NinePatchRect — 9-slice atlas, modulate = accent_color)
```

Why `extends Control` (not `PanelContainer`): the OrnamentLayer needs to render
OVER the panel at the panel's actual rendered corners, not inside the panel's
stylebox content_margin where a PanelContainer's children get laid out. The
composition pattern matches `BookFrame.gd` and `NarrativeScreen.gd`.

## 9-slice atlas system

- **Two atlases** at `assets/ui/borders/`:
  - `ornament_atlas_9slice.png` (256×256, 64px corner cells) — for panels ≥256px
  - `ornament_atlas_compact.png` (128×128, 32px corner cells) — for badges/stat cards <256px
- **Each atlas**: brackets at the 4 corner cells, transparent edges + center
  (transparent edges = no edge-stretching artifacts; transparent center = the
  underlying StyleBoxFlat bg renders through unchanged)
- **Size selection**: `OrnamentPanel._resolve_atlas_variant()` picks based on
  `custom_minimum_size` shorter axis vs `COMPACT_THRESHOLD = 256`. Done once
  at `_ready()` (corner size is fixed; doesn't change with subsequent resize)

## Bracket generation — procedural, NOT extracted

**Important**: the Modiphius `.ai` border delivery contains PAGE-CHROME elements
only (chapter title brackets, vertical edge accents, page-corner ornaments at
PAGE corners). It does NOT contain the small panel-corner brackets the rulebook
uses on its content panels. Verified by:

- Extracting at `merge_distance=15` (37 fragments) — all sub-pieces of
  page-chrome composites, none are panel-corner brackets
- Searching the entire `5PFH Art\` delivery for callout/bracket/panel/corner
  filenames — only the page-chrome `Borders/` folder exists

The panel-corner brackets are typography-decoration drawn in InDesign during
typesetting, not delivered as discrete Illustrator assets. To work around this,
we GENERATE the brackets procedurally with PIL via
`scripts/generate_corner_bracket_atlas.py`.

### Why procedural beats extraction here

- **Tunable**: bracket shape is controlled by constants (`LEG_LENGTH_FRAC`,
  `STROKE_THICKNESS_FRAC`, notch positions, stepped-tip dimensions). Adjust
  numbers, re-run, refresh atlases.
- **Sharp at any size**: pure pixel rasterization, no SVG-to-PNG aliasing
- **Independent of source delivery**: not blocked on Modiphius shipping new art
- **Matches rulebook visual intent**: angular L + multiple notches per leg +
  stepped tips reproduces the "machined sci-fi panel access" feel observed in
  rulebook page-11 (NORMS OF THE GAME), page-12 (CHARACTER CREATION), etc.

### Sci-fi vs fantasy: what the constants actually do

Pure geometric shapes (clean L with one tick) read as "fantasy RPG corner
ornament". Controlled irregularity reads as "sci-fi tech panel":

- **Multiple notches per leg** (`NOTCH_NEAR_OFFSET_FRAC`, `NOTCH_FAR_OFFSET_FRAC`):
  two ticks per leg, not one. Suggests panel access points / circuit details.
- **Stepped tips** (`TIP_GAP_FRAC`, `TIP_LENGTH_FRAC`, `TIP_THICKNESS_FRAC`):
  the leg has a small gap then a slightly thicker endcap. Suggests
  hardware terminators, not decorative scrollwork.
- **Slightly thick stroke** (`STROKE_THICKNESS_FRAC = 0.16`): too thin reads as
  decorative pinstripe; too thick reads as cartoonish. 0.14–0.18 of cell size
  is the sci-fi sweet spot.

If you're tweaking and the bracket starts reading as "fantasy," ADD detail
(more notches, asymmetry, irregular spacing). If it reads as "messy," REMOVE
detail or align it better.

## Decision matrix — which component to use

| Use case | Component | Why |
| --- | --- | --- |
| Section card on a dashboard / dialog content panel / mission card | **OrnamentPanel** | Rounded chrome + corner brackets matches the rulebook callout-panel recipe |
| Sharp-cornered emphasis box (Elite Ranks p.65 style — title inline in upper-left, sharp corners, narrow border) | **CalloutCard** | Existing component, matches that specific rulebook variant |
| Full-screen chapter intro / narrative window with chapter-title bracket + page-corner ornaments | **BookFrame** (refine the existing) | PAGE-CHROME, uses the actual Modiphius .ai art at native size |
| Quick stat badge (CREW/TURN/CREDITS) | **OrnamentPanel** with `custom_minimum_size < 256` (auto-uses compact atlas) | Small bracket variant exists for this exact case |
| Data table | Standard `PanelContainer` with custom StyleBoxFlat | Rulebook data tables use striped rows, not bracketed chrome |

## Key files

| File | Role |
| --- | --- |
| `src/ui/components/common/OrnamentPanel.gd` | The component itself |
| `scripts/generate_corner_bracket_atlas.py` | Generator for the bracket PNGs (run after tuning) |
| `scripts/build_ornament_9slice_atlas.py` | Edge-strip variant for future PageChrome use (NOT used by OrnamentPanel currently) |
| `assets/ui/borders/ornament_atlas_9slice.png` | Standard atlas, 64px corners |
| `assets/ui/borders/ornament_atlas_compact.png` | Compact atlas, 32px corners |
| `tests/manual/test_ornament_panel.tscn` | Visual test scene (F6 to render in editor; MCP to verify) |
| `assets/ui/borders/ornaments/ornament_*.svg` | RESERVED — the Modiphius page-chrome extracts. NOT used by OrnamentPanel. Reserved for future PageChrome / chapter-intro use. |

## When OrnamentPanel is the WRONG choice

- The rulebook page uses page-chrome (chapter title bracket + page-corner ornaments
  at page corners + edge markers + page number badge) — this is `BookFrame`
  territory, not `OrnamentPanel`
- The content is a data table — use a plain styled `PanelContainer` with striped row colors
- You want sharp corners with the title baked into the border (Elite Ranks style) — use `CalloutCard`
- You're making a button or input — use the project's existing `BaseCampaignPanel` button styles

## Iterating the bracket aesthetic

If a future design review wants different bracket character (more ornate, more
minimal, different color logic), the iteration loop is:

1. Edit `*_FRAC` constants in `scripts/generate_corner_bracket_atlas.py`
2. `py scripts/generate_corner_bracket_atlas.py` (regenerates both atlases)
3. `Godot --headless --import --quit --path <project>` (refreshes `.import` files
   for the new PNGs — REQUIRED, see [visual-runtime-verification.md](./visual-runtime-verification.md))
4. F6 on `tests/manual/test_ornament_panel.tscn` or MCP run with `scene` param
5. Visually verify all 6 semantic colors + 3 size variants render correctly

Test scene shows 3 sizes × 6 colors + 3 banner-variants = 21 panels. If any
look wrong, the bracket FRAC constants are the only tuning surface (besides
the atlas size).

## Lessons captured during the build (post-mortem)

This pattern took 3+ failed iterations before settling. The mistakes that
got us off-track:

1. **Tried to repurpose page-chrome ornaments at panel scale.** The `.ai`
   delivery only has page-corner brackets (170×231 chapter-title composites).
   Cramming those into 64×64 corner cells produced "compressed noise," not
   clean brackets. Lesson: when source art doesn't match the use case, don't
   try to force-fit. Either find the right source or generate it procedurally.
2. **Initial visual analysis was wrong** — at 80 DPI renders, the small
   panel-corner brackets were invisible. I incorrectly concluded the rulebook
   has "no per-panel corner ornaments." User pushback + 2.5x scale renders
   corrected this. Lesson: when doing visual design analysis on PDFs,
   render at >=2x scale or the small details disappear.
3. **Tried to be selective with edges before realizing edges aren't the
   problem** — selective `--include-edges=False` was a partial fix but didn't
   address the corner-shape problem (which was the bigger issue). Lesson:
   diagnose the WHY of a visual problem before iterating the WHAT.

Reference: `C:\Users\admin\.claude\plans\modular-forging-narwhal.md` for the
full iteration history.
