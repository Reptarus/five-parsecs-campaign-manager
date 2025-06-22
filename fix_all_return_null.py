#!/usr/bin/env python3
"""
Batch Remove Return Null Statements
Removes 'return null' statements from specific GDScript files.
Usage: python fix_all_return_null.py [--auto]
"""

import subprocess
import sys
from pathlib import Path

# All the files you specified
TARGET_FILES = [
    "src/core/managers/CampaignManager.gd",
    "src/core/story/StoryQuestData.gd",
    "src/core/story/UnifiedStorySystem.gd",
    "src/core/systems/BattlefieldGenerator.gd",
    "src/core/systems/ResourceSystem.gd",
    "src/core/terrain/TerrainEffects.gd",
    "src/core/terrain/TerrainSystem.gd",
    "src/game/campaign/crew/FiveParsecsCrew.gd",
    "src/core/systems/TableProcessor.gd",
    "src/game/campaign/crew/FiveParsecsCrewExporter.gd",
    "src/game/campaign/crew/FiveParsecsStrangeCharacters.gd",
    "src/game/campaign/FiveParsecsCampaign.gd",
    "src/game/campaign/crew/FiveParsecsCrewMember.gd",
    "src/game/campaign/FiveParsecsCampaignManager.gd",
    "src/game/campaign/FiveParsecsMissionGenerator.gd",
    "src/game/character/CharacterDataManager.gd",
    "src/game/character/CharacterStats.gd",
    "src/game/character/generation/CharacterCreator.gd",
    "src/game/combat/BattleCharacter.gd",
    "src/game/combat/FiveParsecsBattleData.gd",
    "src/game/mission/five_parsecs_mission.gd",
    "src/game/story/StoryEventData.gd",
    "src/game/story/StoryQuestData.gd",
    "src/ui/screens/campaign/CampaignDashboard.gd",
    "src/ui/screens/campaign/JobSystem.gd",
    "src/ui/screens/campaign/StatusEffects.gd",
    "src/ui/screens/campaign/TravelPhase.gd",
    "src/ui/screens/mainscene/MainGameScene.gd",
    "src/ui/screens/SaveLoadUI.gd",
    "src/ui/screens/ships/ShipInventory.gd",
    "src/ui/themes/ThemeManager.gd",
    "src/utils/helpers/PathFinder.gd"
]

def main():
    auto_mode = "--auto" in sys.argv
    
    print("=== Batch Return Null Remover ===")
    print("=" * 50)
    
    # Check if fix_void_returns.py exists
    fixer_script = Path("fix_void_returns.py")
    if not fixer_script.exists():
        print("[ERROR] fix_void_returns.py not found in current directory!")
        print("   Make sure you run this from the same directory as fix_void_returns.py")
        return 1
    
    existing_files = []
    missing_files = []
    
    # Check which files exist
    for file_path in TARGET_FILES:
        if Path(file_path).exists():
            existing_files.append(file_path)
        else:
            missing_files.append(file_path)
    
    print(f"[INFO] Found {len(existing_files)} files to process")
    if missing_files:
        print(f"[WARNING] {len(missing_files)} files not found:")
        for missing in missing_files[:5]:  # Show first 5
            print(f"   - {missing}")
        if len(missing_files) > 5:
            print(f"   ... and {len(missing_files) - 5} more")
    
    if not existing_files:
        print("[ERROR] No files found to process!")
        return 1
    
    if not auto_mode:
        response = input(f"\n[PROMPT] Process {len(existing_files)} files? (y/n): ")
        if response.lower() != 'y':
            print("[CANCELLED] User declined.")
            return 0
    
    print(f"\n[INFO] Processing {len(existing_files)} files...")
    print("=" * 50)
    
    success_count = 0
    error_count = 0
    
    for i, file_path in enumerate(existing_files, 1):
        print(f"\n[{i}/{len(existing_files)}] {file_path}")
        
        # Run the fixer script on this file
        try:
            cmd = ["python", "fix_void_returns.py", file_path]
            if auto_mode:
                cmd.append("--auto")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                # Parse the output to see what was done
                output = result.stdout
                if "No 'return null' statements found" in output:
                    print("   [OK] No issues found")
                elif "Fixed" in output:
                    # Extract the number of fixes
                    lines = output.split('\n')
                    fix_line = next((line for line in lines if "Fixed" in line), "")
                    print(f"   [SUCCESS] {fix_line}")
                else:
                    print("   [OK] Processed successfully")
                success_count += 1
            else:
                print(f"   [ERROR] {result.stderr.strip()}")
                error_count += 1
                
        except subprocess.TimeoutExpired:
            print("   [ERROR] Timeout")
            error_count += 1
        except Exception as e:
            print(f"   [ERROR] Exception: {e}")
            error_count += 1
    
    print("\n" + "=" * 50)
    print("[RESULTS] Final Results:")
    print(f"   [SUCCESS] Successful: {success_count}")
    print(f"   [ERROR] Errors: {error_count}")
    print(f"   [TOTAL] Total: {len(existing_files)}")
    
    if error_count == 0:
        print("\n[COMPLETE] All files processed successfully!")
        print("[NOTE] Remember to test your code to ensure everything works correctly.")
    else:
        print(f"\n[WARNING] {error_count} files had errors. Check the output above.")
    
    return 0 if error_count == 0 else 1

if __name__ == "__main__":
    sys.exit(main()) 