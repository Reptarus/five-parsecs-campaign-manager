#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Warning Elimination Suite
Systematically eliminates 10k+ Godot warnings through automated transformations.
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Set
from dataclasses import dataclass

@dataclass
class WarningFix:
    file_path: str
    line_number: int
    original_line: str
    fixed_line: str
    warning_type: str
    confidence: str  # "high", "medium", "low"

class WarningEliminator:
    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root)
        self.fixes_applied: List[WarningFix] = []
        self.backup_dir = self.project_root / "backups" / "warning_fixes"
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        # Signal patterns for modern Godot 4
        self.signal_patterns = [
            # emit_signal with parameters
            (
                r'emit_signal\("([^"]+)"\s*,\s*([^)]+)\)',
                r'\1.emit(\2)'
            ),
            # emit_signal without parameters
            (
                r'emit_signal\("([^"]+)"\)',
                r'\1.emit()'
            ),
            # Remove warning ignore comments for signals
            (
                r'\s*#\s*warning:\s*return\s*value\s*discarded\s*\(intentional\)',
                ''
            )
        ]
        
        # Type annotation patterns
        self.type_patterns = [
            # Common untyped variable patterns
            (r'var\s+(\w+):\s*$', self._infer_variable_type),
            (r'var\s+(\w+):\s*=\s*\[\]', r'var \1: Array = []'),
            (r'var\s+(\w+):\s*=\s*\{\}', r'var \1: Dictionary = {}'),
            (r'var\s+(\w+):\s*=\s*""', r'var \1: String = ""'),
            (r'var\s+(\w+):\s*=\s*0', r'var \1: int = 0'),
            (r'var\s+(\w+):\s*=\s*0\.0', r'var \1: float = 0.0'),
            (r'var\s+(\w+):\s*=\s*false', r'var \1: bool = false'),
            (r'var\s+(\w+):\s*=\s*true', r'var \1: bool = true'),
            (r'var\s+(\w+):\s*=\s*null', r'var \1: Variant = null'),
        ]
        
        # Common type mappings based on variable names
        self.name_type_mappings = {
            # Data structures
            'data': 'Dictionary',
            'result': 'Dictionary', 
            'config': 'Dictionary',
            'settings': 'Dictionary',
            'options': 'Dictionary',
            'battle_data': 'Dictionary',
            'campaign_data': 'Dictionary',
            'mission_data': 'Dictionary',
            'crew_data': 'Dictionary',
            
            # Arrays
            'enemies': 'Array[Dictionary]',
            'weapons': 'Array[Dictionary]',
            'items': 'Array[Dictionary]',
            'missions': 'Array[Dictionary]',
            'characters': 'Array[Dictionary]',
            'crew_members': 'Array[Dictionary]',
            'patrons': 'Array[Dictionary]',
            'rivals': 'Array[Dictionary]',
            
            # Strings
            'name': 'String',
            'title': 'String',
            'description': 'String',
            'file_path': 'String',
            'save_path': 'String',
            'character_name': 'String',
            'mission_name': 'String',
            'campaign_name': 'String',
            
            # Numbers
            'count': 'int',
            'index': 'int',
            'level': 'int',
            'damage': 'int',
            'health': 'int',
            'credits': 'int',
            'reputation': 'int',
            'experience': 'int',
            'turn': 'int',
            'round': 'int',
            
            # Floats
            'percentage': 'float',
            'multiplier': 'float',
            'weight': 'float',
            'scale': 'float',
            'duration': 'float',
            
            # Managers/Systems
            'manager': 'Node',
            'system': 'Node',
            'controller': 'Node',
            'campaign_manager': 'CampaignManager',
            'battle_manager': 'BattleManager',
            'character_manager': 'CharacterManager',
        }

    def _infer_variable_type(self, match) -> str:
        """Infer variable type based on name patterns"""
        var_name = match.group(1).lower()
        
        # Check direct mappings first
        if var_name in self.name_type_mappings:
            return f'var {match.group(1)}: {self.name_type_mappings[var_name]}'
        
        # Pattern-based inference
        if var_name.endswith('_manager'):
            return f'var {match.group(1)}: Node'
        elif var_name.endswith('_system'):
            return f'var {match.group(1)}: Node'
        elif var_name.endswith('_data'):
            return f'var {match.group(1)}: Dictionary'
        elif var_name.endswith('_list') or var_name.endswith('s'):
            return f'var {match.group(1)}: Array'
        elif var_name.endswith('_name') or var_name.endswith('_path'):
            return f'var {match.group(1)}: String'
        elif var_name.endswith('_count') or var_name.endswith('_id'):
            return f'var {match.group(1)}: int'
        else:
            # Default to Variant for unknown patterns
            return f'var {match.group(1)}: Variant'

    def backup_file(self, file_path: Path) -> Path:
        """Create backup of file before modification"""
        relative_path = file_path.relative_to(self.project_root)
        backup_path = self.backup_dir / relative_path
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        
        import shutil
        shutil.copy2(file_path, backup_path)
        return backup_path

    def find_gdscript_files(self) -> List[Path]:
        """Find all .gd files in the project"""
        gd_files = []
        
        # Priority directories (process these first)
        priority_dirs = [
            "src/core/managers",
            "src/core/systems", 
            "src/game/campaign",
            "src/ui/screens",
            "src/core/battle",
            "src/core/story"
        ]
        
        # Process priority directories first
        for priority_dir in priority_dirs:
            dir_path = self.project_root / priority_dir
            if dir_path.exists():
                gd_files.extend(dir_path.rglob("*.gd"))
        
        # Then process remaining directories
        for gd_file in self.project_root.rglob("*.gd"):
            if gd_file not in gd_files:
                # Skip test files for now (lower priority)
                if "tests/" not in str(gd_file):
                    gd_files.append(gd_file)
        
        return gd_files

    def fix_signals_in_file(self, file_path: Path) -> List[WarningFix]:
        """Fix signal-related warnings in a single file"""
        fixes = []
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            modified = False
            new_lines = []
            
            for line_num, line in enumerate(lines, 1):
                original_line = line
                current_line = line
                
                # Apply signal transformation patterns
                for pattern, replacement in self.signal_patterns:
                    if callable(replacement):
                        match = re.search(pattern, current_line)
                        if match:
                            current_line = replacement(match)
                    else:
                        new_line = re.sub(pattern, replacement, current_line)
                        if new_line != current_line:
                            current_line = new_line
                
                if current_line != original_line:
                    fixes.append(WarningFix(
                        file_path=str(file_path),
                        line_number=line_num,
                        original_line=original_line.strip(),
                        fixed_line=current_line.strip(),
                        warning_type="signal_modernization",
                        confidence="high"
                    ))
                    modified = True
                
                new_lines.append(current_line)
            
            # Write back modified content
            if modified:
                self.backup_file(file_path)
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
        
        return fixes

    def fix_types_in_file(self, file_path: Path) -> List[WarningFix]:
        """Fix type annotation warnings in a single file"""
        fixes = []
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            modified = False
            new_lines = []
            
            for line_num, line in enumerate(lines, 1):
                original_line = line
                current_line = line
                
                # Apply type annotation patterns
                for pattern, replacement in self.type_patterns:
                    if callable(replacement):
                        match = re.search(pattern, current_line)
                        if match:
                            current_line = replacement(match) + '\n'
                    else:
                        new_line = re.sub(pattern, replacement, current_line)
                        if new_line != current_line:
                            current_line = new_line
                
                if current_line != original_line:
                    fixes.append(WarningFix(
                        file_path=str(file_path),
                        line_number=line_num,
                        original_line=original_line.strip(),
                        fixed_line=current_line.strip(),
                        warning_type="type_annotation",
                        confidence="high"
                    ))
                    modified = True
                
                new_lines.append(current_line)
            
            # Write back modified content
            if modified:
                self.backup_file(file_path)
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
        
        return fixes

    def process_file(self, file_path: Path, fix_signals: bool = True, fix_types: bool = True) -> List[WarningFix]:
        """Process a single file for all warning types"""
        all_fixes = []
        
        print(f"Processing: {file_path.relative_to(self.project_root)}")
        
        if fix_signals:
            signal_fixes = self.fix_signals_in_file(file_path)
            all_fixes.extend(signal_fixes)
            
        if fix_types:
            type_fixes = self.fix_types_in_file(file_path)
            all_fixes.extend(type_fixes)
        
        return all_fixes

    def process_all_files(self, fix_signals: bool = True, fix_types: bool = True) -> Dict[str, int]:
        """Process all .gd files in the project"""
        gd_files = self.find_gdscript_files()
        
        print(f"Found {len(gd_files)} .gd files to process")
        print("=" * 60)
        
        stats = {
            "files_processed": 0,
            "signal_fixes": 0,
            "type_fixes": 0,
            "total_fixes": 0,
            "errors": 0
        }
        
        for file_path in gd_files:
            try:
                fixes = self.process_file(file_path, fix_signals, fix_types)
                self.fixes_applied.extend(fixes)
                
                signal_fixes = len([f for f in fixes if f.warning_type == "signal_modernization"])
                type_fixes = len([f for f in fixes if f.warning_type == "type_annotation"])
                
                if fixes:
                    print(f"  ✓ Fixed {len(fixes)} warnings ({signal_fixes} signals, {type_fixes} types)")
                
                stats["files_processed"] += 1
                stats["signal_fixes"] += signal_fixes
                stats["type_fixes"] += type_fixes
                stats["total_fixes"] += len(fixes)
                
            except Exception as e:
                print(f"  ✗ Error: {e}")
                stats["errors"] += 1
        
        return stats

    def generate_report(self, stats: Dict[str, int]) -> str:
        """Generate a comprehensive report of all fixes applied"""
        report = f"""
# Five Parsecs Campaign Manager - Warning Elimination Report

## Summary
- **Files Processed**: {stats['files_processed']}
- **Total Fixes Applied**: {stats['total_fixes']}
- **Signal Modernization Fixes**: {stats['signal_fixes']}
- **Type Annotation Fixes**: {stats['type_fixes']}
- **Errors Encountered**: {stats['errors']}

## Detailed Changes
"""
        
        # Group fixes by file
        fixes_by_file = {}
        for fix in self.fixes_applied:
            if fix.file_path not in fixes_by_file:
                fixes_by_file[fix.file_path] = []
            fixes_by_file[fix.file_path].append(fix)
        
        for file_path, fixes in fixes_by_file.items():
            relative_path = Path(file_path).relative_to(self.project_root)
            report += f"\n### {relative_path}\n"
            report += f"**{len(fixes)} fixes applied**\n\n"
            
            for fix in fixes[:10]:  # Show first 10 fixes per file
                report += f"- Line {fix.line_number} ({fix.warning_type}):\n"
                report += f"  - Before: `{fix.original_line}`\n"
                report += f"  - After: `{fix.fixed_line}`\n\n"
            
            if len(fixes) > 10:
                report += f"  ... and {len(fixes) - 10} more fixes\n\n"
        
        return report

def main():
    """Main execution function"""
    if len(sys.argv) > 1:
        project_root = sys.argv[1]
    else:
        project_root = "."
    
    eliminator = WarningEliminator(project_root)
    
    print("🚀 Five Parsecs Campaign Manager - Warning Elimination Suite")
    print("=" * 60)
    print(f"Project Root: {Path(project_root).absolute()}")
    print()
    
    # Process all files
    stats = eliminator.process_all_files(fix_signals=True, fix_types=True)
    
    print("\n" + "=" * 60)
    print("🎉 PROCESSING COMPLETE!")
    print(f"✅ {stats['total_fixes']} warnings eliminated across {stats['files_processed']} files")
    print(f"📊 Signal fixes: {stats['signal_fixes']}, Type fixes: {stats['type_fixes']}")
    
    if stats['errors'] > 0:
        print(f"⚠️  {stats['errors']} files had errors - check manually")
    
    # Generate and save report
    report = eliminator.generate_report(stats)
    report_path = Path(project_root) / "tools" / "warning_elimination_report.md"
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(f"📋 Detailed report saved to: {report_path}")
    print(f"💾 File backups saved to: {eliminator.backup_dir}")
    
    return stats['total_fixes']

if __name__ == "__main__":
    fixes_applied = main()
    sys.exit(0 if fixes_applied > 0 else 1) 