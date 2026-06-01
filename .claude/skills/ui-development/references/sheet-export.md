# Sheet / PDF Export Reference

The Five Parsecs sheet export system renders official Modiphius sheet
PNGs with overlaid player data, exportable to PNG (universal) and PDF
(via GodotHaru on Steam Win/Linux, GodotPDF universal fallback, or no
output when neither addon is installed).

Sprint 1 + 2 shipped May 23 2026. Sprint 3 (PDF-native text overlay)
is researched and documented here, deferred until alpha feedback
confirms tester demand.

For the institutional SOP (adding new sheets, calibrating field
coordinates, plugin evaluation, cross-platform gotchas), read
`docs/sop/sheet-export.md`. This reference focuses on the architectural
internals and the Sprint 3 design.

## Architecture (six layers)

```
PrintSheetScreen (src/ui/screens/print/, tab bar + right rail)
  └─ SheetRenderer (src/ui/components/sheet/SheetRenderer.gd)
       ├─ Background TextureRect — official PNG, KEEP_ASPECT
       ├─ Field Label nodes — positioned per data/sheets/<book>/<id>_fields.json
       └─ Debug overlay — _draw() red rects for calibration

       export_to_png(path):
         SubViewport.set_size_2d_override(2764, 1843)
         + await RenderingServer.frame_post_draw
         + get_texture().get_image().save_png(path)

       export_to_pdf(path):
         → PdfExportRouter.export_viewport_as_pdf(texture, ...)
            → "godotharu" (ClassDB.class_exists(&"PDF_DOC"))
            → "godotpdf"  (ResourceLoader.exists "res://addons/godotpdf/PDF.gd")
            → ""          (returns ERR_UNAVAILABLE)
```

## Critical files

| File | Role |
|------|------|
| `src/ui/screens/print/PrintSheetScreen.gd` + `.tscn` | Top-level screen, tab bar + right rail |
| `src/ui/components/sheet/SheetRenderer.gd` | Manifest loader, label overlay, SubViewport export |
| `src/core/export/PdfExportRouter.gd` | Plugin detection + per-backend dispatch (`_export_via_godotpdf` / `_export_via_godotharu`) |
| `data/sheets/core/*_fields.json` | Per-sheet field manifests (rect, type, source dot-path, font) |
| `assets/sheets/core/*.png` | Source sheet PNGs (2764×1843, Core Rulebook) |
| `addons/godotpdf/PDF.gd` | Pure-GDScript PDF addon (universal fallback) |
| `addons/godotharu/` | GDExtension PDF addon (Steam Win/Linux preferred) |

Navigation entry points:

- `src/ui/screens/SceneRouter.gd` — `"print_sheet"` route
- `src/ui/screens/campaign/CampaignDashboard.gd` — `_add_sheets_button()` programmatically inserts next to Export
- `src/ui/screens/character/CharacterDetailsScreen.gd` — `_setup_print_sheet_button()` (HeroCard bottom-right)

## Field manifest schema

```json
{
  "sheet_id": "crew_log",
  "book": "core",
  "source_png": "res://assets/sheets/core/crew_log.png",
  "source_size": [2764, 1843],
  "fields": [
    {
      "id": "captain_name",
      "type": "text",          // text | number | multiline_text | checkbox | checkbox_grid
      "rect": [320, 145, 540, 60],  // [x, y, w, h] in source-PNG pixels
      "font_size": 36,
      "align": "left",         // left | center | right
      "source": "campaign.captain.character_name"
    }
  ]
}
```

`source` is dot-notation traversed by `SheetRenderer._resolve_source()` against
the data context built in `PrintSheetScreen._build_data_context()`. Top-level
keys: `campaign.*` (FiveParsecsCampaignCore with `captain` shortcut + `crew[N]`),
`world.*` (PlanetDataManager), `journal.*` (CampaignJournal entries, e.g.
`journal.last_battle.location`).

## Plugin detection contract (`PdfExportRouter.best_available_backend()`)

```
1. ClassDB.class_exists(&"PDF_DOC")             → "godotharu"
2. ResourceLoader.exists("res://addons/godotpdf/PDF.gd") → "godotpdf"
3. otherwise                                    → ""
```

Cached in a static var after first call. `reset_cache()` for tests.

`is_pdf_available()` returns `best_available_backend() != ""`. UI uses this
to grey out Save PDF when no backend is present (see
`PrintSheetScreen` Save PDF button setup).

## Sprint 2.5 SHIPPED (May 24 2026) — Automated calibration via CV

The previous deferred-research recommendation ("user fills the PNG manually,
assistant eyeball-extracts coords") was superseded by an even better
approach realized via Opus 4.8: the sheets are designed with uniform
cyan borders around every field rect (RGB ~190, 220, 231) which makes
fully automated extraction trivially viable.

**The pipeline**: `tools/extract_sheet_fields.py` (Pillow + NumPy + optional
Pytesseract) reads the blank sheet PNG, builds a cyan border mask, dilates
by 3px to bridge sub-pixel border gaps, flood-fills from the page exterior,
labels connected interior regions, computes bounding boxes, filters by
size + edge-margin, then optionally OCRs the top-left of each rect for a
label hint. Output: `<sheet>_fields_extracted.json` with ~89 candidate
rects for Crew Log (vs the previous 14-field starter).

**Then per-sheet ID assignment** maps the detected rects to semantic
field IDs + source dot-paths. For Crew Log this is automated via
`tools/assign_crew_log_ids.py` which:
- Drops title-letter noise (rects in the top region matching title-text
  shape: small, low-y, roughly square)
- Drops sub-pixel artifacts
- Drops parent character-card outlines (1219×242 redundant with detected
  sub-fields)
- Algorithmically splits compound rects: the 401×62 stat row splits into
  5 equal cells (Reactions/Speed/Combat/Toughness/Savvy); Luck is detected
  separately as a 6th cell
- Generates 16 fields per character card × 8 card slots (1 captain + 7
  crew positions) using card-relative offsets
- Plus 16 hand-mapped header fields = 144 total fields

**Verification**: MCP runtime + debug overlay shows red rects align cleanly
to the printed cyan field outlines across the entire sheet. gdUnit4
schema tests (all field IDs unique, rects in bounds, sources non-empty)
pass on the 144-field manifest.

**Effort**: ~3 hours of script writing + tuning + ID-assignment vs the
~10-12h manual measurement the previous SOP estimated. Reusable for
Encounter Log + World Record Sheet + future expansion-book sheets.

**Critical fix shipped alongside**: the SheetRenderer's debug overlay was
invisible because `_draw()` runs on the parent Control which renders
BEFORE child nodes. Fixed by setting `_background.show_behind_parent = true`
on the TextureRect so the parent's `_draw()` (which paints debug rects)
renders ON TOP. Without this, the cyan PNG completely covers the red
debug rects.

**Source attribute paths discovered during ID assignment** (not what they
seem from data-context dot-notation):
- Character: `character_name` (not `name`), `species_id` (not `species`),
  `reaction` (not `reactions`), `experience` (not `xp`)
- Weapons: `weapons[0].name`, `.range`, `.shots`, `.damage`, `.traits`
- Captain accessor: `campaign.captain.<attr>` (special accessor on
  FiveParsecsCampaignCore — works directly, doesn't go through crew_data)
- Crew at index N: `campaign.crew[N].<attr>` (N = 0..N-1, where N is the
  fixed campaign crew size 4/5/6)

**Remaining work for follow-up sprint** (not Sprint 2.5):
- Encounter Log + World Record Sheet ID assignment helpers (write
  `tools/assign_encounter_log_ids.py` and `tools/assign_world_record_ids.py`
  in same pattern as `assign_crew_log_ids.py`)
- `.size()` or `count_of:` resolver extension if patron/rival count fields
  need numeric rendering (currently the dot-path returns the array;
  workaround is to derive `patrons_count` in `_build_data_context()`)
- Sprint 3 (PDF-native text overlay) remains independently deferred

## Calibration reference availability (do NOT hunt for more)

User confirmed May 23 2026: the **only filled sheet example in the
Core Rules PDF is the Crew Log "Example Crew"** (Flint Jameson + 5
crew members). Encounter Log and World Record Sheet ship with no
filled examples. Future expansion books (Compendium / Planetfall /
Tactics) are unknown — worth asking Modiphius on the next partnership
sync.

Practical implications:

- **Crew Log calibration**: comparison-mode (~1-1.5h). Render in debug
  overlay, visually align rects against the filled example.
- **Encounter Log / World Record Sheet calibration**: measurement-mode
  (~3-4h each). Use the printed labels on the blank PNG as positional
  anchors — the artwork itself shows where each field belongs.
- **Don't waste time** searching for more filled examples in the Core
  Rules PDF. They don't exist there.
- **Field count expectation**: a fully-populated Crew Log has ~110
  fields (3 header + 4 stash + 7 ship + 16 captain + 16 × 5 crew).
  Sprint 1 starter manifest had only 14 — significant expansion needed.

## Backend gotchas

- **PDF_DOC + PDF_PAGE are RefCounted**, NOT Object-derived, despite `free()`
  appearing in their ClassDB method lists (inherited from Object). Calling
  `pdf.free()` throws `"Can't free a RefCounted object."` Auto-free via scope
  is the ONLY valid cleanup. Verified May 23 2026 by runtime introspection +
  hitting the debugger.
- **GodotPDF page size is hardcoded `Vector2i(612, 792)`** (US letter
  portrait). NOT configurable via the API. Our 3:2 landscape sheets letterbox
  into the portrait page. GodotHaru DOES support arbitrary page sizes.
- **GodotPDF `newImage()` requires `FORMAT_RGB8` or `FORMAT_RGBA8`** (per
  PDF.gd line 103). Defensive `img.convert(Image.FORMAT_RGBA8)` in the
  router covers HDR / transparent-bg edge cases.
- **GodotPDF instantiation does not require autoload registration** —
  `var pdf = load("res://addons/godotpdf/PDF.gd").new()` gives a per-export
  Control instance. The `_enable_plugin()` autoload pattern is for the
  game-level `PDF.newPDF()` singleton style we don't use.
- **GodotHaru's GDExtension auto-loads regardless of `[editor_plugins]`
  enablement** — that's the GDExtension manager path, separate from
  EditorPlugin autoloads.

---

## Sprint 3 — PDF-native text overlay (researched, deferred)

### Why this is the next step

Sprint 1+2 ships sheet PDFs that are **single rasterized images** — the
SheetRenderer's full visual output (background PNG + Label overlays) goes
through a SubViewport and lands in the PDF as one big image. Output is
functional but:

- Text is **rasterized pixels**, not selectable / searchable / copy-paste-able
- Text quality is **capped at SubViewport DPI** (~250 dpi for 2764×1843 at
  11×8.5") — fine for print but soft when zoomed in a viewer
- File size is **larger** (raster pixels > PDF text streams)
- The PDF "feels like a screenshot" rather than a native document — weaker
  T4 demo artifact for partnership conversations

Sprint 3 emits the sheet PNG **background only** as the image layer, then
overlays **native PDF text elements** per field. Output: selectable,
searchable, infinitely zoomable, smaller files, professional appearance.

### Both backends support text overlay (confirmed via introspection)

**GodotHaru** (PDF_PAGE methods, from `ClassDB.class_get_method_list`):

```
begin_text() / end_text()
set_font_and_size(font: PDF_FONT, size: float)
text_out(x: float, y: float, text: String)         — single-line at point
text_rect(rect, text, alignment)                   — bounded box with wrap
show_text(text: String) / show_text_next_line(text)
move_text_pos(x, y) / move_text_pos_2(x, y)
text_width(text) -> float / measure_text(...)
set_text_leading / set_text_rise / set_char_space / set_word_space
set_text_rendering_mode / set_text_matrix
```

Plus on PDF_DOC: `get_font(name)` for built-in PDF 14 fonts (Helvetica /
Times / Courier × 4 styles + Symbol + ZapfDingbats), and
`load_tt_font_from_file(path)` / `load_tt_font_from_file_2(...)` for custom
TTFs.

**GodotPDF** (`addons/godotpdf/PDF.gd` source):

```gdscript
pdf.newLabel(pageNum: int, position: Vector2i, text: String,
             size: int = 12, font: String = "Helvetica") -> bool
pdf.newFont(fontName: String, fontPath: String) -> bool
```

Single-line only. Helvetica is the only built-in. Custom fonts need
`importer="keep"` on the TTF's `.import` sidecar to survive PCK export
(per plugin.cfg point 8 — currently `Amplify.ttf.import` is `font_data_dynamic`,
which would break in exported builds).

### Per-backend dispatch matrix

| Capability | GodotHaru | GodotPDF |
|---|---|---|
| Emit text at point | `page.text_out(x, y, text)` | `pdf.newLabel(1, Vector2i(x, y), text, size, font)` |
| Set font + size | `page.set_font_and_size(font, size)` | passed inline to `newLabel` |
| Built-in fonts | 14 PDF standard (via `pdf.get_font(name)`) | "Helvetica" only |
| Custom TTF | `pdf.load_tt_font_from_file(path)` | `pdf.newFont(name, path)` (needs importer=keep) |
| Measure text width | `page.text_width(text) -> float` | NOT exposed — would need fork |
| Right-align text | `text_out(x - text_width(text), y, text)` | Approximate via char-width estimate, or left-align only |
| Center-align text | `text_out(x - text_width(text)/2, y, text)` | Same caveat as right-align |
| Multi-line / wrap | `page.text_rect(rect, text, align)` | NOT exposed — manual line-split + multiple `newLabel` calls |
| Coordinate origin | Bottom-left (PDF native) — caller flips Y | Top-left (PDF.gd flips internally at line 81) |

The asymmetry in coordinate origin is annoying. Sprint 3 should normalize
on top-left at the SheetRenderer/router boundary, and have each backend
helper do the appropriate flip.

### PDF text string escape rules (CRITICAL)

PDF text strings are wrapped in parentheses: `(Hello World) Tj`. Three
characters MUST be escaped or the PDF stream is corrupt:

- `(` → `\(`
- `)` → `\)`
- `\` → `\\`

**GodotPDF does NOT escape these** — `PDF.gd:389` literally concatenates:
`contentStream += "(" + i.text + ") Tj\n"`. A character named `Mc(Carthy)`
would break the file. Sprint 3 MUST pre-escape strings before passing to
`newLabel()`, OR fork the addon and patch the export function.

**GodotHaru's `text_out()` is libharu-backed and handles escaping internally**
(libharu's HPDF_Page_TextOut encodes the string). Verified by reading
libharu source. Safe to pass raw strings.

Sprint 3 should pre-escape at the SheetRenderer layer (above the router)
for consistency, so both backends receive already-safe strings:

```gdscript
static func _escape_pdf_text(s: String) -> String:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
```

### Font handling decision (open)

Three viable strategies:

**Option A — Helvetica everywhere (zero font shipping)**

- Use PDF's built-in Helvetica via `pdf.get_font("Helvetica")` (GodotHaru)
  and the default `"Helvetica"` string (GodotPDF)
- Zero file shipping, zero export-build caveats
- Output looks PROFESSIONAL but DIFFERENT from on-screen (which uses
  Montserrat per `sci_fi_theme.tres`)
- Latin-1 only — fine for current English-only build, breaks at localization

**Option B — Ship Montserrat as TTF for both backends**

- GodotHaru: `pdf.load_tt_font_from_file("res://assets/fonts/Montserrat-Regular.ttf")`
- GodotPDF: `pdf.newFont("Montserrat", "res://addons/godotpdf/Montserrat-Regular.ttf")`
  — must place TTF inside `addons/godotpdf/` OR change `.import` to `importer="keep"`
  on the project-level TTF. The plugin reads with `FileAccess.get_file_as_bytes()`
  which returns the imported `.fontdata` (not the original TTF) for default-imported
  fonts.
- Output matches on-screen visually
- Unicode coverage (full Latin-Extended, etc.)
- Adds ~600KB per font weight to PCK size

**Option C — Helvetica for body, Montserrat for headers only**

- Headers (titles in CAPS) use Montserrat; everything else uses Helvetica
- Visual brand consistency where it matters most, minimal TTF shipping
- More complex per-field font lookup

**Recommendation**: Option A for Sprint 3 MVP (ship-or-don't decision is
isolated). Revisit to Option B if tester feedback flags visual drift as
distracting.

### Coordinate transform math

Field rects are stored in **source-PNG pixels** (e.g., 2764×1843). PDF
pages are in **libharu points** (e.g., 612×792 portrait for GodotPDF,
792×612 landscape for GodotHaru on US letter).

```gdscript
# Compute scale at SheetRenderer.export_to_pdf:
var scale_x: float = page_width_pt / float(source_size.x)
var scale_y: float = page_height_pt / float(source_size.y)

# Per field:
var pdf_x: float = field.rect.position.x * scale_x
var pdf_y_top_left: float = field.rect.position.y * scale_y  # top-left coord
var pdf_font_size: float = field.font_size * scale_x  # uniform scale for fonts

# Y-flip for GodotHaru (PDF native bottom-left):
var pdf_y_bottom_left: float = page_height_pt - pdf_y_top_left - pdf_font_size
```

For GodotPDF the y-flip happens inside `PDF.gd:81` (`_pageSize.y - labelPosition.y`).
So pass top-left coordinates and let the addon flip.

### `multiline_text` field handling

The current SheetRenderer renders `multiline_text` via RichTextLabel with
word wrap inside the field rect. For PDF:

- **GodotHaru**: `page.text_rect(rect, text, alignment)` does auto-wrap
  within the bounded rect — direct mapping
- **GodotPDF**: no native wrap. Either (a) split the string at character
  boundaries based on field width / estimated char width, emit one
  `newLabel()` per line, OR (b) fork to add wrap support

Sprint 3 MVP: support `multiline_text` on GodotHaru, fall back to
single-line truncation on GodotPDF (degraded but non-crashing).

### `checkbox` and `checkbox_grid` fields

Current SheetRenderer uses a Label with `"X"` glyph (for `checkbox`) or
iterates pip rectangles (for `checkbox_grid`). For PDF:

- **GodotHaru**: `page.rectangle(x, y, w, h); page.fill();` for filled
  pips, or use `text_out` with `"X"` for the simple checkbox case
- **GodotPDF**: `pdf.newBox(pageNum, position, size, fill, border)` — already
  exposed, supports fill + border colors

These should look the same visually since both PDFs and the current
on-screen render bake a glyph or filled rect.

### SheetRenderer refactor: background-only render mode

The PDF text-overlay path needs the SheetRenderer to produce a **sheet PNG
with NO field labels baked in** — the labels become PDF text elements
separately. Currently `set_blank_mode(true)` hides the Label nodes but
doesn't directly drive the export path.

Two options:

**Option 1 — Reuse `set_blank_mode`**:

```gdscript
func export_to_pdf(output_path: String) -> Error:
    set_blank_mode(true)
    var sub_viewport = await _render_offscreen()
    var bg_img = sub_viewport.get_texture().get_image()
    sub_viewport.queue_free()
    set_blank_mode(false)  # restore for screen display
    # ... emit text overlays from _manifest ...
```

Risk: user-visible flash of blank-mode while exporting (if the export is
synchronous on the visible scene). Mitigated by export running on a clone
in the SubViewport, which is already what `_render_offscreen()` does.

**Option 2 — Add explicit `_render_background_only_offscreen()`**:

Duplicates most of `_render_offscreen()` but constructs the clone without
field nodes. Cleaner separation but ~30 lines of near-duplicate code.

**Recommendation**: Option 1 with the clone pattern from `_render_offscreen()`.
The existing offscreen clone bypasses the visible scene entirely, so
toggling `_blank_mode` on the clone doesn't flash the user's view.

### PdfExportRouter API additions

```gdscript
# NEW — added alongside existing export_viewport_as_pdf, not replacing
static func export_image_with_text_overlay(
    background: Image,                  # sheet PNG (no labels baked)
    text_overlays: Array[Dictionary],   # [{pos, size, text, font, align, type}]
    page_size_inches: Vector2,
    output_path: String
) -> Error
```

Both helper functions (`_export_via_godotharu`, `_export_via_godotpdf`) gain
a new signature OR a flag parameter. Cleanest is a new pair of helpers:

```gdscript
static func _export_with_text_via_godotharu(bg, overlays, size, path) -> Error
static func _export_with_text_via_godotpdf(bg, overlays, size, path) -> Error
```

The original single-image helpers stay for backward compatibility (PNG-fallback
exports, or any caller that explicitly wants the rasterized version).

### Test coverage additions

```
tests/unit/test_pdf_export_router.gd:
  + test_escape_pdf_text_handles_parens_and_backslashes
  + test_export_with_text_overlay_routes_to_backend
  + test_export_with_text_overlay_returns_unavailable_when_no_backend

tests/unit/test_sheet_renderer.gd:
  + test_export_to_pdf_with_text_mode_emits_no_baked_labels
  + test_export_to_pdf_scales_field_coordinates_to_page_size
```

The end-to-end "produces a valid PDF with selectable text" verification is
MCP-only — read the PDF back via a PyPDF2 script and assert `extract_text()`
returns the expected field values.

### Open decisions for Sprint 3 kickoff

1. **Font strategy** — Helvetica-only (Option A), Montserrat everywhere
   (Option B), or hybrid (Option C)? See decision matrix above.
2. **Multi-line on GodotPDF** — fall back to truncation (MVP) or fork the
   addon to add word-wrap?
3. **GodotPDF `newLabel` escape patching** — pre-escape at the SheetRenderer
   layer (clean), or fork the addon's `_addPageContent()` to escape there?
   Pre-escape is recommended (no maintained fork).
4. **Page-size unification** — keep the asymmetry (GodotPDF portrait
   612×792, GodotHaru landscape 792×612) or normalize? Normalizing requires
   forking GodotPDF to expose `set_page_size()`.
5. **Backward-compatible PNG-bake mode** — keep `export_viewport_as_pdf` as
   the legacy single-image path for the no-text-overlay case (e.g., user
   preference for "looks exactly like the screen"), or remove? Keeping it
   adds zero maintenance cost since it's already shipping.

### Estimated effort

~1-1.5 dev days. Breakdown:

- SheetRenderer background-only export pass + text-overlay emission (3h)
- PdfExportRouter new helpers + escape function + text dispatch (3h)
- Font setup (Helvetica if Option A, +2h if Option B with TTF shipping) (1-3h)
- Test additions (2h)
- MCP runtime verification incl. PyPDF2 text-extract validation (1.5h)
- SOP doc update (30min)

Total: 11-13h focused work. Acceptable as one sprint.

### Sprint 3 acceptance criteria

- All 3 Core Rulebook sheet PDFs contain SELECTABLE text (copy-paste
  works in Adobe / Edge / Chrome PDF viewers)
- File sizes are SMALLER than Sprint 2 output (text streams << image
  pixels) — verify via byte count comparison
- PyPDF2 `extract_text()` returns the field values when run on each
  exported PDF
- Both backends produce valid PDFs with text overlay (priority order
  still GodotHaru > GodotPDF)
- Existing 28 unit tests still pass + new tests added per coverage plan
- No regression in the Save PNG path (still produces single rasterized image)
- SOP doc updated with Sprint 3 patterns
