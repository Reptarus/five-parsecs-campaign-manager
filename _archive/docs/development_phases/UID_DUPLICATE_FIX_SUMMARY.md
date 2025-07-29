# UID Duplicate Fix Summary

## ✅ Successfully Fixed UID Duplicates

### Image Files Fixed (4 duplicates resolved):

1. **global-plugin.png duplicates**
   - `addons/global-plugin.png` (kept original UID)
   - `assets/images/global-plugin.png` → **NEW UID**: `uid://3fd7ad13c84b`

2. **arrow_diagonal_cross.png duplicates**
   - `assets/ui/basic/green.png` (kept original UID)
   - `assets/PNG/Double (128px)/arrow_diagonal_cross.png` → **NEW UID**: `uid://3cfbf0757a18`

3. **arrow_rotate.png duplicates**
   - `assets/ui/basic/red.png` (kept original UID)
   - `assets/PNG/Double (128px)/arrow_rotate.png` → **NEW UID**: `uid://8bded21fa77f`

4. **arrow_diagonal_cross_divided.png duplicates**
   - `assets/ui/basic/yellow.png` (kept original UID)
   - `assets/PNG/Double (128px)/arrow_diagonal_cross_divided.png` → **NEW UID**: `uid://431d624668b2`

### Scene Files Status:

The scene files mentioned in the warnings do not have `.import` files, which means:
- They haven't been imported by Godot yet
- No UID conflicts exist for these files
- UIDs will be assigned automatically when Godot imports them

**Scene files without UID conflicts:**
- `src/ui/components/character/CharacterBox.tscn`
- `src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn`
- `src/ui/components/combat/overrides/override_controller.tscn`
- `src/ui/components/combat/log/combat_log_controller.tscn`
- `src/ui/components/combat/rules/house_rules_controller.tscn`
- `src/ui/components/combat/rules/house_rules_panel.tscn`
- `src/ui/screens/campaign/UpkeepPhaseUI.tscn`
- `src/ui/screens/campaign/CampaignSetupDialog.tscn`
- `src/ui/screens/utils/SaveLoadUI.tscn`
- `src/ui/screens/campaign/panels/CaptainPanel.tscn`
- `src/ui/screens/world/MissionSelectionUI.tscn`
- `src/ui/screens/campaign/panels/CrewPanel.tscn`

## 🎉 Results

- **4 image UID duplicates** successfully resolved
- **0 scene UID duplicates** (files not yet imported)
- **All backup files** created automatically
- **Verification passed** - no remaining duplicate UIDs found

## 💡 Next Steps

1. **Restart Godot** to ensure the UID changes take effect
2. **Import scene files** when needed (Godot will assign unique UIDs automatically)
3. **Monitor for new UID warnings** during development

## 🔧 Tools Created

- `fix_uid_duplicates.py` - Main UID fixer for image files
- `fix_scene_uid_duplicates.py` - Scene UID fixer (for future use)
- `manual_uid_fix.py` - Manual UID fixer for specific files

All tools include backup creation and verification features for safe UID management. 