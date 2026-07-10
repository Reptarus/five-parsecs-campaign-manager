"""
Phase 3.3: Grep-based lint rule for data ownership violations.

Scans GDScript files for patterns that bypass the canonical data owners:
  - Direct writes to campaign.credits (must use GameStateManager.set_credits)
  - Direct writes to campaign.supplies/reputation/story_points
  - Direct appends to character.equipment (must use EquipmentTransferService)
  - progress_data["credits"] mirrors (must not exist post-Phase 2.1)

Run: py scripts/lint_data_ownership.py
Exit code: 0 = clean, 1 = violations found.
"""

import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(PROJECT_ROOT, "src")

# Files that are ALLOWED to write directly (the canonical owners + service)
ALLOWED_FILES = {
    "GameStateManager.gd",
    "FiveParsecsCampaignCore.gd",
    "EquipmentTransferService.gd",
    "EquipmentManager.gd",
}

# Patterns to flag (regex, description)
RULES = [
    # Only flag writes to campaign-level resources. The pattern requires
    # "campaign" or "current_campaign" before ".credits" to avoid matching
    # patron.credits, equipment.credits, merged.credits, etc.
    (
        r'(campaign|current_campaign)\.credits\s*=\s*',
        "Direct campaign.credits write — use GameStateManager.set_credits()",
    ),
    (
        r'(campaign|current_campaign)\.supplies\s*=\s*',
        "Direct campaign.supplies write — use GameStateManager.set_supplies()",
    ),
    (
        r'(campaign|current_campaign)\.reputation\s*=\s*',
        "Direct campaign.reputation write — use GameStateManager.set_reputation()",
    ),
    (
        r'(campaign|current_campaign)\.story_points\s*=\s*',
        "Direct campaign.story_points write — use GameStateManager.set_story_progress()",
    ),
    (
        r'progress_data\["(credits|supplies|reputation|story_points)"\]',
        "Legacy progress_data mirror — removed in Phase 2.1",
    ),
    (
        r'\.equipment\.append\(',
        "Direct .equipment.append() — use EquipmentTransferService",
    ),
]


def scan_file(filepath):
    violations = []
    basename = os.path.basename(filepath)
    if basename in ALLOWED_FILES:
        return violations
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError:
        return violations
    for lineno, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        # Allow explicit lint suppression via "# lint:ignore" comment
        if "# lint:ignore" in stripped:
            continue
        for pattern, message in RULES:
            if re.search(pattern, stripped):
                violations.append((filepath, lineno, stripped.strip(), message))
    return violations


def main():
    all_violations = []
    for dirpath, _, filenames in os.walk(SRC_DIR):
        for fn in filenames:
            if not fn.endswith(".gd"):
                continue
            full_path = os.path.join(dirpath, fn)
            all_violations.extend(scan_file(full_path))

    if not all_violations:
        print("lint_data_ownership: CLEAN (0 violations)")
        return 0

    print(f"lint_data_ownership: {len(all_violations)} violation(s) found\n")
    for filepath, lineno, code, message in all_violations:
        rel = os.path.relpath(filepath, PROJECT_ROOT)
        print(f"  {rel}:{lineno}: {message}")
        print(f"    {code}\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
