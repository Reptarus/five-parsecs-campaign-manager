"""Generate the four Android launcher-icon layers from assets/iconnew.png.

Why this script exists
----------------------
All four `launcher_icons/*` slots in export_presets.cfg were empty, so every build
shipped the default Godot robot. The source art (assets/iconnew.png) is 432x432 RGB
with NO alpha channel, which cannot be used directly as an adaptive foreground:
Android masks adaptive icons to a circle/squircle and crops roughly the outer third,
so a full-bleed square loses its edges and the logo gets clipped.

What Android actually wants (developer.android.com/develop/ui/views/launch/icon_design_adaptive):
  main_192x192                  legacy square icon, pre-Android-8 launchers
  adaptive_foreground_432x432   the logo, WITH alpha, sized inside the 264px safe zone
  adaptive_background_432x432   an opaque fill behind it
  adaptive_monochrome_432x432   single-colour silhouette for themed icons (Android 13+)

Run:  py scripts/make_launcher_icons.py
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "iconnew.png"
OUT = ROOT / "assets" / "launcher"

# Deep Space theme COLOR_BASE — matches the app's own background so the icon reads
# as part of the product rather than a pasted-on square.
BACKGROUND = (26, 26, 46, 255)  # #1A1A2E

CANVAS = 432
# Android guarantees only the centre 264x264 of a 432x432 adaptive layer is visible;
# everything outside can be masked away by the launcher's shape.
SAFE_ZONE = 264


def main() -> int:
    if not SRC.exists():
        print(f"ERROR: source art not found: {SRC}")
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    print(f"source: {src.size[0]}x{src.size[1]} {src.mode}")

    # --- legacy square icon -------------------------------------------------
    legacy = src.resize((192, 192), Image.LANCZOS)
    legacy.save(OUT / "icon_192.png")

    # --- adaptive background: the art, FULL BLEED ---------------------------
    # The source is a photographic scene, not a logo on transparency. Shrinking it
    # into the safe zone and floating it on a flat colour reads as a picture pasted
    # onto a card. Full-bleed on the background layer is what the adaptive system is
    # designed for: the launcher masks it to that device's shape (circle, squircle,
    # rounded square) and the art reaches the edge in every one of them.
    background = src.resize((CANVAS, CANVAS), Image.LANCZOS).convert("RGB")
    # Flatten onto the theme colour so there is never a transparent pixel behind the
    # mask, whatever the source art carries.
    flat = Image.new("RGB", (CANVAS, CANVAS), BACKGROUND[:3])
    flat.paste(background, (0, 0))
    flat.save(OUT / "adaptive_background_432.png")

    # --- adaptive foreground: intentionally empty ---------------------------
    # Everything visible lives in the background layer above. A transparent
    # foreground is a supported configuration and avoids double-printing the art.
    foreground = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    foreground.save(OUT / "adaptive_foreground_432.png")

    # --- monochrome: luminance -> alpha silhouette --------------------------
    # Android tints this layer itself, so colour is discarded and only coverage
    # matters. Luminance is the honest source of coverage for photographic art.
    logo = src.resize((SAFE_ZONE, SAFE_ZONE), Image.LANCZOS)
    offset = (CANVAS - SAFE_ZONE) // 2
    mono = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    silhouette = Image.new("RGBA", (SAFE_ZONE, SAFE_ZONE), (255, 255, 255, 0))
    silhouette.putalpha(logo.convert("L"))
    mono.paste(silhouette, (offset, offset), silhouette)
    mono.save(OUT / "adaptive_monochrome_432.png")

    for f in sorted(OUT.glob("*.png")):
        img = Image.open(f)
        print(f"  {f.relative_to(ROOT)}  {img.size[0]}x{img.size[1]} {img.mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
