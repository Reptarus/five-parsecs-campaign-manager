"""
Five Parsecs Complexity Analyzer
Shows the REAL state of your project
"""

import os
import json
from pathlib import Path

def analyze_project(src_dir):
    stats = {
        'total_files': 0,
        'total_lines': 0,
        'files_by_size': {'small': 0, 'medium': 0, 'large': 0, 'huge': 0},
        'managers': [],
        'enhanced': [],
        'duplicate_functionality': {},
        'test_coverage': 0,
        'ci_readiness': 0
    }
    
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file.endswith('.gd'):
                filepath = os.path.join(root, file)
                stats['total_files'] += 1
                
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    line_count = len(lines)
                    stats['total_lines'] += line_count
                    
                    # Categorize by size
                    if line_count < 100:
                        stats['files_by_size']['small'] += 1
                    elif line_count < 500:
                        stats['files_by_size']['medium'] += 1
                    elif line_count < 1000:
                        stats['files_by_size']['large'] += 1
                    else:
                        stats['files_by_size']['huge'] += 1
                    
                    # Find violations
                    content = ''.join(lines)
                    if 'Manager' in file or 'manager' in content.lower():
                        stats['managers'].append(file)
                    if 'Enhanced' in file or 'enhanced' in content.lower():
                        stats['enhanced'].append(file)
                    if 'func test_' in content:
                        stats['test_coverage'] += 1
    
    # Calculate CI readiness score (0-100)
    ci_score = 0
    if stats['test_coverage'] > 0: ci_score += 20
    if stats['total_files'] < 200: ci_score += 20
    if len(stats['managers']) < 10: ci_score += 20
    if stats['files_by_size']['huge'] < 5: ci_score += 20
    if stats['total_lines'] < 50000: ci_score += 20
    stats['ci_readiness'] = ci_score
    
    return stats

def print_report(stats):
    print("\n" + "="*60)
    print("FIVE PARSECS PROJECT REALITY CHECK")
    print("="*60)
    
    print(f"\nFILE METRICS:")
    print(f"  Total Files: {stats['total_files']} (Framework Bible wants: 20)")
    print(f"  Total Lines: {stats['total_lines']:,}")
    print(f"  Small files (<100 lines): {stats['files_by_size']['small']}")
    print(f"  Medium files (100-500): {stats['files_by_size']['medium']}")
    print(f"  Large files (500-1000): {stats['files_by_size']['large']}")
    print(f"  HUGE files (>1000): {stats['files_by_size']['huge']}")
    
    print(f"\nVIOLATIONS:")
    print(f"  Manager Pattern Files: {len(stats['managers'])}")
    print(f"  Enhanced Pattern Files: {len(stats['enhanced'])}")
    
    print(f"\nTEST COVERAGE:")
    print(f"  Files with tests: {stats['test_coverage']}")
    print(f"  Test percentage: {(stats['test_coverage']/stats['total_files']*100):.1f}%")
    
    print(f"\nCI/CD READINESS SCORE: {stats['ci_readiness']}/100")
    if stats['ci_readiness'] < 40:
        print("  Status: NOT READY - 3-6 months of work needed")
    elif stats['ci_readiness'] < 70:
        print("  Status: PARTIALLY READY - 1-2 months of work needed")
    else:
        print("  Status: NEARLY READY - 2-4 weeks of work needed")
    
    print("\nRECOMMENDED NEXT STEPS:")
    if stats['test_coverage'] == 0:
        print("  1. CREATE YOUR FIRST TEST - You have ZERO tests!")
    if stats['total_files'] > 300:
        print("  2. CONSOLIDATE - Merge related functionality")
    if len(stats['managers']) > 20:
        print("  3. ELIMINATE MANAGERS - Direct implementation instead")
    if stats['files_by_size']['huge'] > 10:
        print("  4. REFACTOR HUGE FILES - Break down monoliths")
    
    print("\nREALISTIC TIMELINE TO CI/CD:")
    weeks_needed = max(1, (stats['total_files'] - 100) // 50 + (100 - stats['ci_readiness']) // 10)
    print(f"  Estimated: {weeks_needed} weeks minimum")
    print("="*60)

if __name__ == "__main__":
    src_dir = r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\src"
    stats = analyze_project(src_dir)
    print_report(stats)
