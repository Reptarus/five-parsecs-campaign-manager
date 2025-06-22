#!/usr/bin/env python3
"""
GDScript Indentation and Spacing Fixer
Fixes mixed tab/space indentation and removes return null from void functions.
Usage: python fix_indentation.py
"""

import re
import os
from pathlib import Path

# Target files to fix
TARGET_FILES = [
    "src/ui/components/character/CharacterSheet.gd",
    "src/ui/components/combat/TerrainOverlay.gd", 
    "src/ui/components/ErrorDisplay.gd",
    "src/ui/components/gesture/GestureManager.gd",
    "src/ui/components/grid/GridOverlay.gd",
    "src/ui/components/logbook/logbook.gd",
    "src/ui/components/mission/EnemyInfoPanel.gd",
    "src/ui/components/mission/MissionInfoPanel.gd",
    "src/ui/components/mission/MissionSummaryPanel.gd",
    "src/ui/components/options/AppOptions.gd",
    "src/ui/components/rewards/RewardsPanel.gd",
    "src/ui/components/tooltip/TooltipManager.gd",
    "src/ui/components/tutorial/TutorialOverlay.gd",
    "src/ui/components/tutorial/TutorialUI.gd",
    "src/ui/screens/battle/PreBattleUI.gd",
    "src/ui/screens/campaign/CampaignLoadDialog.gd",
    "src/ui/screens/campaign/CampaignManager.gd",
    "src/ui/screens/campaign/CampaignSetupScreen.gd",
    "src/ui/screens/campaign/CampaignSummaryPanel.gd",
    "src/ui/screens/campaign/phases/EndPhasePanel.gd",
    "src/ui/screens/campaign/QuickStartDialog.gd",
    "src/ui/screens/campaign/UpkeepPhaseUI.gd",
    "src/ui/screens/crew/InitialCrewCreation.gd",
    "src/ui/screens/GameOverScreen.gd",
    "src/ui/screens/gameplay_options_menu.gd"
]

class IndentationFixer:
    def __init__(self):
        self.spaces_per_tab = 4
        
    def fix_file(self, file_path):
        """Fix indentation and spacing issues in a single file."""
        try:
            if not os.path.exists(file_path):
                print(f"[SKIP] File not found: {file_path}")
                return False
                
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Fix indentation issues
            content = self._fix_indentation(content)
            
            # Remove return null from void functions
            content = self._remove_void_returns(content)
            
            # Fix unterminated strings
            content = self._fix_unterminated_strings(content)
            
            # Fix syntax errors
            content = self._fix_syntax_errors(content)
            
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"[FIXED] {file_path}")
                return True
            else:
                print(f"[OK] {file_path}")
                return True
                
        except Exception as e:
            print(f"[ERROR] {file_path}: {e}")
            return False
    
    def _fix_indentation(self, content):
        """Convert tabs to spaces and fix mixed indentation."""
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            # Convert tabs to spaces
            fixed_line = line.expandtabs(self.spaces_per_tab)
            fixed_lines.append(fixed_line)
        
        return '\n'.join(fixed_lines)
    
    def _remove_void_returns(self, content):
        """Remove return null statements from void functions."""
        # Pattern to match standalone return null lines
        patterns = [
            r'^\s*return\s+null\s*$',
            r'^\s*return\s+null\s*#.*$',
            r'^\s*\treturn\s+null\s*$',
        ]
        
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            skip_line = False
            for pattern in patterns:
                if re.match(pattern, line, re.MULTILINE):
                    skip_line = True
                    break
            
            if not skip_line:
                fixed_lines.append(line)
        
        return '\n'.join(fixed_lines)
    
    def _fix_unterminated_strings(self, content):
        """Fix common unterminated string issues."""
        # Fix node paths missing closing quotes
        content = re.sub(r'\$"([^"]*?)$', r'$"\1"', content, flags=re.MULTILINE)
        
        return content
    
    def _fix_syntax_errors(self, content):
        """Fix common syntax errors."""
        # Remove duplicate quotes at end of lines
        content = re.sub(r'([^"])""\s*$', r'\1"', content, flags=re.MULTILINE)
        
        # Fix malformed string endings
        content = re.sub(r'([^"])"$\s*return\s+null', r'\1"', content, flags=re.MULTILINE)
        
        # Remove orphaned return null lines before closing braces/keywords
        content = re.sub(r'\treturn\s+null\s*\n(\s*[})])', r'\n\1', content)
        
        return content

def main():
    print("=== GDScript Indentation and Spacing Fixer ===")
    print("=" * 50)
    
    fixer = IndentationFixer()
    total_files = len(TARGET_FILES)
    successful = 0
    failed = 0
    
    print(f"Processing {total_files} files...")
    print("=" * 50)
    
    for i, file_path in enumerate(TARGET_FILES, 1):
        print(f"[{i}/{total_files}] {file_path}")
        if fixer.fix_file(file_path):
            successful += 1
        else:
            failed += 1
    
    print("=" * 50)
    print("Final Results:")
    print(f"   Successful: {successful}")
    print(f"   Failed: {failed}")
    print(f"   Total: {total_files}")
    
    if failed == 0:
        print("All files processed successfully!")
        return 0
    else:
        print(f"{failed} files had errors. Check the output above.")
        return 1

if __name__ == "__main__":
    exit(main()) 