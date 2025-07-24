import json
import re
from pathlib import Path

def analyze_errors():
    """
    Analyzes all error calls in the Five Parsecs Campaign Manager codebase
    to create a comprehensive classification and prioritization system for
    production error handling implementation.
    """
    src_path = Path("/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src")
    files_with_errors = list(src_path.glob("**/*.gd"))

    error_calls = []
    for file_path in files_with_errors:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                for line_num, line in enumerate(f, 1):
                    if any(pattern in line for pattern in ["push_error", "push_warning", "printerr", "assert"]):
                        error_calls.append({
                            "file": str(file_path),
                            "line_num": line_num,
                            "line": line.strip()
                        })
        except Exception as e:
            print(f"Could not read file {file_path}: {e}")

    severity_breakdown = {
        "CRITICAL": 0,
        "HIGH": 0,
        "MEDIUM": 0,
        "LOW": 0
    }
    system_breakdown = {
        "UI": {"total": 0, "CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0},
        "Core": {"total": 0, "CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0},
        "Game": {"total": 0, "CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0},
        "Data": {"total": 0, "CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0},
        "Battle": {"total": 0, "CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0},
        "Other": {"total": 0, "CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
    }
    critical_error_priorities = {
        "immediate_action_required": [],
        "high_priority": [],
        "system_totals": {},
        "recovery_strategy_distribution": {}
    }

    for error in error_calls:
        severity = _classify_severity(error["line"])
        system = _classify_system(error["file"])

        severity_breakdown[severity] += 1
        system_breakdown[system]["total"] += 1
        system_breakdown[system][severity] += 1

        if severity == "CRITICAL":
            critical_error_priorities["immediate_action_required"].append(_format_critical_error(error, severity, system))
        elif severity == "HIGH":
            critical_error_priorities["high_priority"].append(_format_critical_error(error, severity, system))

    # Generate ERROR_AUDIT_REPORT.md
    _generate_markdown_report(len(error_calls), len(files_with_errors), severity_breakdown, system_breakdown, critical_error_priorities)

    # Generate CRITICAL_ERROR_PRIORITIES.json
    _generate_json_report(critical_error_priorities, system_breakdown)

def _classify_severity(line):
    line_lower = line.lower()
    if any(keyword in line_lower for keyword in ["critical", "fatal", "corrupt", "crash", "data loss"]):
        return "CRITICAL"
    if any(keyword in line_lower for keyword in ["fail", "exception", "invalid state"]):
        return "HIGH"
    if any(keyword in line_lower for keyword in ["warning", "timeout", "invalid", "missing"]):
        return "MEDIUM"
    return "LOW"

def _classify_system(file_path):
    if "/ui/" in file_path:
        return "UI"
    if "/core/" in file_path:
        return "Core"
    if "/game/" in file_path:
        return "Game"
    if any(keyword in file_path for keyword in ["data", "manager", "save"]):
        return "Data"
    if any(keyword in file_path for keyword in ["battle", "combat", "enemy"]):
        return "Battle"
    return "Other"

def _format_critical_error(error, severity, system):
    return {
        "file": error["file"],
        "line": error["line_num"],
        "error_message": error["line"],
        "severity": severity,
        "system": system,
        "impact": "Potential data corruption or crash",
        "recommended_recovery": "EMERGENCY_SAVE" if severity == "CRITICAL" else "FALLBACK",
        "priority_score": 100 if severity == "CRITICAL" else 80
    }

def _generate_markdown_report(total_errors, files_analyzed, severity_breakdown, system_breakdown, critical_errors):
    report = "# Five Parsecs Campaign Manager - Error Audit Report\n\n"
    report += "## Executive Summary\n"
    report += f"- Total Error Calls: {total_errors}\n"
    report += f"- Files Analyzed: {files_analyzed}\n"
    report += f"- Critical Issues: {severity_breakdown['CRITICAL']}\n"
    report += f"- Immediate Action Required: {len(critical_errors['immediate_action_required'])}\n\n"

    report += "## Severity Breakdown\n"
    report += "| Severity | Count | Percentage | Systems Affected |\n"
    report += "|----------|-------|------------|------------------|\n"
    for severity, count in severity_breakdown.items():
        percentage = (count / total_errors) * 100 if total_errors > 0 else 0
        systems_affected = [sys for sys, data in system_breakdown.items() if data[severity] > 0]
        report += f"| {severity} | {count} | {percentage:.1f}% | {', '.join(systems_affected)} |\n"

    report += "\n## System Breakdown\n"
    report += "| System | Total Errors | Critical | High | Medium | Low |\n"
    report += "|--------|--------------|----------|------|--------|-----|\n"
    for system, data in system_breakdown.items():
        report += f"| {system} | {data['total']} | {data['CRITICAL']} | {data['HIGH']} | {data['MEDIUM']} | {data['LOW']} |\n"

    report += "\n## Top 20 Critical Error Paths\n"
    top_20 = (critical_errors["immediate_action_required"] + critical_errors["high_priority"])[:20]
    for i, error in enumerate(top_20, 1):
        report += f"{i}. [{error['file']}:{error['line']}] - `{error['error_message']}` - {error['severity']} - {error['recommended_recovery']}\n"

    report += "\n## Recommended Recovery Strategies\n"
    report += "### For CRITICAL errors:\n- Emergency save and graceful shutdown\n- Data backup before operations\n- User notification of data risk\n"
    report += "### For HIGH errors:\n- Component restart capabilities\n- Fallback to basic functionality\n- User notification of feature unavailability\n"
    report += "### For MEDIUM errors:\n- Automatic retry with backoff\n- Graceful degradation\n- Background error logging\n"
    report += "### For LOW errors:\n- Silent error logging\n- Continue normal operation\n- Optional user notification\n"

    with open("ERROR_AUDIT_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)

def _generate_json_report(critical_errors, system_breakdown):
    system_totals = {}
    for system, data in system_breakdown.items():
        system_totals[f"{system.lower()}_system"] = {
            "total": data["total"],
            "critical": data["CRITICAL"],
            "high": data["HIGH"]
        }
    
    recovery_strategy_distribution = {
        "RETRY": 0,
        "FALLBACK": 0,
        "EMERGENCY_SAVE": 0,
        "GRACEFUL_DEGRADE": 0
    }
    all_errors = critical_errors["immediate_action_required"] + critical_errors["high_priority"]
    for error in all_errors:
        strategy = error["recommended_recovery"]
        if strategy in recovery_strategy_distribution:
            recovery_strategy_distribution[strategy] += 1

    json_data = {
        "immediate_action_required": critical_errors["immediate_action_required"],
        "high_priority": critical_errors["high_priority"],
        "system_totals": system_totals,
        "recovery_strategy_distribution": recovery_strategy_distribution
    }

    with open("CRITICAL_ERROR_PRIORITIES.json", "w", encoding="utf-8") as f:
        json.dump(json_data, f, indent=2)

if __name__ == "__main__":
    analyze_errors()
