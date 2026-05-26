#!/usr/bin/env python3
"""Run the official Windows validator with macOS-friendly fallbacks.

The executable's exact CLI contract is not documented in this repository, so
the wrapper tries several safe invocation patterns and records all output.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


PASS_KEYWORDS = [
    "pass",
    "passed",
    "success",
    "valid",
    "correct",
    "通过",
    "成功",
    "正确",
]

FAIL_KEYWORDS = [
    "fail",
    "failed",
    "error",
    "invalid",
    "incorrect",
    "violation",
    "不通过",
    "失败",
    "错误",
    "不满足",
    "非法",
]


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def find_exe(explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit).expanduser().resolve()
    else:
        path = repo_root() / "error_checking_program.exe"
    if not path.exists():
        raise FileNotFoundError(f"validator executable not found: {path}")
    return path


def split_cmd(value: str) -> list[str]:
    return [part for part in value.split(" ") if part]


def find_runner() -> tuple[list[str] | None, str]:
    system = platform.system().lower()
    if system == "windows":
        return [], "windows-native"

    for env_name in ("VALIDATOR_WINE", "WINE_CMD", "CROSSOVER_WINE"):
        value = os.environ.get(env_name)
        if value:
            return split_cmd(value), env_name

    for name in ("wine64", "wine"):
        path = shutil.which(name)
        if path:
            return [path], name

    crossover_candidates = [
        "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine",
        str(Path.home() / "CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"),
    ]
    for candidate in crossover_candidates:
        if Path(candidate).exists():
            return [candidate], "crossover"

    return None, "unavailable"


def run_one(
    cmd: list[str],
    cwd: Path,
    timeout_s: int,
    stdin_text: str | None = None,
) -> dict[str, object]:
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            input=stdin_text,
            text=True,
            capture_output=True,
            timeout=timeout_s,
        )
        return {
            "cmd": cmd,
            "returncode": proc.returncode,
            "stdout": proc.stdout,
            "stderr": proc.stderr,
            "timeout": False,
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "cmd": cmd,
            "returncode": None,
            "stdout": exc.stdout or "",
            "stderr": exc.stderr or "",
            "timeout": True,
        }


def classify(attempt: dict[str, object]) -> tuple[bool, str]:
    output = f"{attempt.get('stdout', '')}\n{attempt.get('stderr', '')}".lower()
    returncode = attempt.get("returncode")
    has_fail = any(word.lower() in output for word in FAIL_KEYWORDS)
    has_pass = any(word.lower() in output for word in PASS_KEYWORDS)

    if returncode == 0 and not has_fail:
        if has_pass or output.strip():
            return True, "exit 0 without failure keywords"
        return True, "exit 0 with no output"
    return False, "nonzero exit, timeout, or failure keyword"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path, help="path to results.txt")
    parser.add_argument("--exe", help="path to error_checking_program.exe")
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()

    results = args.results.expanduser().resolve()
    if not results.exists():
        print(f"ERROR: results file not found: {results}", file=sys.stderr)
        return 2

    exe = find_exe(args.exe)
    runner, runner_name = find_runner()
    if runner is None:
        report = {
            "official_available": False,
            "official_pass": False,
            "runner": runner_name,
            "error": "No Wine/CrossOver runner found. Install wine-stable, set WINE_CMD, or run in Windows.",
            "attempts": [],
        }
        print(json.dumps(report, indent=2, ensure_ascii=False))
        if args.json_out:
            args.json_out.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        return 86

    with tempfile.TemporaryDirectory(prefix="astro-validator-") as tmp:
        cwd = Path(tmp)
        local_exe = cwd / "error_checking_program.exe"
        local_results = cwd / "results.txt"
        shutil.copy2(exe, local_exe)
        shutil.copy2(results, local_results)

        exe_cmd = [str(local_exe)] if runner_name == "windows-native" else runner + [str(local_exe)]
        attempts = [
            run_one(exe_cmd + [str(local_results)], cwd, args.timeout),
            run_one(exe_cmd, cwd, args.timeout),
            run_one(exe_cmd, cwd, args.timeout, stdin_text=f"{local_results}\n"),
            run_one(exe_cmd + ["results.txt"], cwd, args.timeout),
        ]

    official_pass = False
    reason = "no attempt passed"
    for attempt in attempts:
        ok, why = classify(attempt)
        attempt["classified_pass"] = ok
        attempt["classification_reason"] = why
        if ok and not official_pass:
            official_pass = True
            reason = why

    report = {
        "official_available": True,
        "official_pass": official_pass,
        "runner": runner_name,
        "exe": str(exe),
        "results": str(results),
        "reason": reason,
        "attempts": attempts,
    }

    text = json.dumps(report, indent=2, ensure_ascii=False)
    print(text)
    if args.json_out:
        args.json_out.write_text(text, encoding="utf-8")
    return 0 if official_pass else 1


if __name__ == "__main__":
    sys.exit(main())

