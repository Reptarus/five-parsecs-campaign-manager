#!/usr/bin/env python3
"""
Comprehensive Void Return Fixer for GDScript Files
Removes 'return null' statements from void functions
"""

import os
import re
import sys
from pathlib import Path

class VoidReturnFixer:
    def __init__(self):
        self.patterns = [
            # Pattern to match standalone return null
            (re.compile(r'^\s*return null\s*$', re.MULTILINE), ''),
            # Pattern to match return null followed by newlines  
            (re.compile(r'\n\s*return null\s*\n', re.MULTILINE), '\n'),
            # Pattern to match comment followed by return null
            (re.compile(r'(\n\s*#[^\n]*\n)\s*return null\s*\n', re.MULTILINE), r'\1'),
            # Pattern to match return null at end of function
            (re.compile(r'\n\s*return null\s*\nfunc ', re.MULTILINE), '\nfunc '),
        ]
    
    def fix_content(self, content: str) -> tuple[str, int]:
        """Fix void return issues in content"""
        original_content = content
        fixes_count = 0
        
        for pattern, replacement in self.patterns:
            new_content = pattern.sub(replacement, content)
            if new_content != content:
                fixes_count += len(pattern.findall(content))
                content = new_content
        
        return content, fixes_count
    
    def fix_file(self, file_path: str) -> bool:
        """Fix a single file"""
        try:
            # Read the file
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Apply fixes
            fixed_content, fixes_count = self.fix_content(content)
            
            if fixes_count > 0:
                # Write back the fixed content
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(fixed_content)
                print(f"   [SUCCESS] Fixed {fixes_count} issues in {os.path.basename(file_path)}")
                return True
            else:
                print(f"   [SKIP] No issues found in {os.path.basename(file_path)}")
                return True
                
        except Exception as e:
            print(f"   [ERROR] Failed to process {file_path}: {e}")
            return False

def main():
    # List of files to fix
    files_to_fix = [
        "src/core/managers/CampaignManager.gd",
        "src/core/managers/EventManager.gd", 
        "src/core/state/GameState.gd",
        "src/core/story/UnifiedStorySystem.gd",
        "src/core/systems/items/GameWeapon.gd",
        "src/game/campaign/crew/FiveParsecsCrewExporter.gd",
        "src/game/campaign/crew/FiveParsecsCrewMember.gd",
        "src/game/campaign/FiveParsecsPreBattleLoop.gd",
        "src/game/character/CharacterDataManager.gd",
        "src/game/character/CharacterManager.gd",
        "src/game/combat/EnemyTacticalAI.gd",
        "src/game/ships/FiveParsecsShipRoles.gd",
        "src/scenes/campaign/CampaignUI.gd",
        "src/scenes/campaign/components/ResourcePanel.gd",
        "src/scenes/campaign/world_phase/JobOffersPanel.gd",
        "src/scenes/character/CharacterUI.gd",
        "src/ui/components/combat/overrides/manual_override_panel.gd",
        "src/ui/components/combat/rules/house_rules_controller.gd",
        "src/ui/components/combat/rules/validation_panel.gd",
        "src/ui/components/combat/TerrainTooltip.gd",
        "src/ui/components/dice/DiceDisplay.gd",
        "src/ui/components/difficulty/DifficultyOption.gd",
        "src/ui/components/rewards/RewardsPanel.gd",
        "src/ui/components/tutorial/TutorialUI.gd",
        "src/ui/screens/ships/ShipManager.gd",
        "src/ui/dialogs/SettingsDialog.gd",
        "src/ui/screens/battle/BattlefieldMain.gd",
        "src/ui/screens/campaign/CampaignCreationUI.gd",
        "src/ui/screens/campaign/CampaignDashboard.gd",
        "src/ui/screens/campaign/panels/CaptainPanel.gd",
        "src/ui/screens/campaign/panels/CrewPanel.gd",
        "src/ui/screens/campaign/phases/AdvancementPhasePanel.gd",
        "src/ui/screens/campaign/phases/BattleResolutionPhasePanel.gd",
        "src/ui/screens/campaign/phases/BattleSetupPhasePanel.gd",
        "src/ui/screens/campaign/phases/CampaignPhasePanel.gd",
        "src/ui/screens/campaign/phases/StoryPhasePanel.gd",
        "src/ui/screens/campaign/phases/TradePhasePanel.gd",
        "src/ui/screens/campaign/phases/UpkeepPhasePanel.gd",
        "src/ui/screens/campaign/VictoryProgressPanel.gd",
        "src/ui/screens/character/AdvancementManager.gd",
        "src/ui/screens/dice/DiceTestScene.gd",
        "src/ui/screens/events/CampaignEventsManager.gd",
        "src/ui/screens/postbattle/PostBattleSequence.gd",
        "src/ui/screens/rules/RulesReference.gd",
        "src/ui/screens/SceneRouter.gd",
        "src/ui/screens/world/WorldPhaseUI.gd",
        "src/utils/helpers/PathFinder.gd",
        "src/utils/helpers/stat_distribution.gd"
    ]
    
    print("=== Comprehensive Void Return Fixer ===")
    print("=" * 50)
    
    fixer = VoidReturnFixer()
    successful = 0
    failed = 0
    
    print(f"[INFO] Found {len(files_to_fix)} files to process")
    print(f"[INFO] Processing {len(files_to_fix)} files...")
    print("=" * 50)
    
    for i, file_path in enumerate(files_to_fix, 1):
        print(f"[{i}/{len(files_to_fix)}] {file_path}")
        
        if not os.path.exists(file_path):
            print(f"   [SKIP] File not found: {file_path}")
            continue
            
        if fixer.fix_file(file_path):
            successful += 1
        else:
            failed += 1
    
    print("=" * 50)
    print(f"[RESULTS] Final Results:")
    print(f"   [SUCCESS] Successful: {successful}")
    print(f"   [ERROR] Errors: {failed}")
    print(f"   [TOTAL] Total: {len(files_to_fix)}")
    
    if failed == 0:
        print("[COMPLETE] All files processed successfully!")
    else:
        print(f"[WARNING] {failed} files had errors. Check the output above.")
    
    print("[NOTE] Remember to test your code to ensure everything works correctly.")

if __name__ == "__main__":
    main() 