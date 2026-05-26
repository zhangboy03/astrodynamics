#!/usr/bin/env python3
"""Run the official Windows validator with macOS-friendly fallbacks.

The official executable is a MATLAB Runtime console app. It expects a file
named ``results.txt`` in its working directory and should be launched without
positional arguments.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import signal
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
    "未通过",
    "有误",
    "缺少",
    "未检验通过",
    "scriptnotafunction",
]

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


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
            return split_cmd(value), "crossover" if env_name == "CROSSOVER_WINE" else env_name

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


def runner_env(runner_name: str) -> dict[str, str]:
    env = os.environ.copy()
    bottle = (
        os.environ.get("VALIDATOR_CROSSOVER_BOTTLE")
        or os.environ.get("CROSSOVER_BOTTLE")
        or "astrodynamics-validator"
    )
    if runner_name == "crossover":
        env.setdefault("CX_BOTTLE", bottle)
    return env


def cleanup_runner(runner_name: str, env: dict[str, str]) -> None:
    if runner_name != "crossover":
        return
    wineserver = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wineserver"
    if Path(wineserver).exists():
        subprocess.run(
            [wineserver, "-k"],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
            check=False,
        )


def clean_output(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        text = value.decode("utf-8", errors="replace")
    else:
        text = value
    return ANSI_RE.sub("", text).replace("\r", "\n")


def run_one(
    cmd: list[str],
    cwd: Path,
    timeout_s: int,
    env: dict[str, str],
    runner_name: str,
    stdin_text: str | None = None,
) -> dict[str, object]:
    proc: subprocess.Popen[str] | None = None
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        stdout, stderr = proc.communicate(stdin_text, timeout=timeout_s)
        return {
            "cmd": cmd,
            "returncode": proc.returncode,
            "stdout": clean_output(stdout),
            "stderr": clean_output(stderr),
            "timeout": False,
        }
    except subprocess.TimeoutExpired as exc:
        if proc and proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
                proc.wait(timeout=5)
            except Exception:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except Exception:
                    pass
        cleanup_runner(runner_name, env)
        return {
            "cmd": cmd,
            "returncode": None,
            "stdout": clean_output(exc.stdout),
            "stderr": clean_output(exc.stderr),
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

        env = runner_env(runner_name)
        exe_cmd = [str(local_exe)] if runner_name == "windows-native" else runner + [str(local_exe)]
        attempts = [run_one(exe_cmd, cwd, args.timeout, env=env, runner_name=runner_name)]

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
