#!/usr/bin/env python3
"""Static preflight checker for astrodynamics benchmark submissions.

This script intentionally does not perform full CR3BP physics validation.
It checks the result-file shape, event ordering, basic timing/fuel gates, and
extracts the landed payload score. Use it as Tier 0 only.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path


MU_E = 398600.0
MU_M = 4903.0
LU_KM = 384400.0
TU_DAY = math.sqrt(LU_KM**3 / (MU_E + MU_M)) / 86400.0

EVENTS = {-1, 0, 1, 2, 3, 4, 5}
TOL = 1e-7


def load_rows(path: Path) -> list[list[float]]:
    rows: list[list[float]] = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 10:
            raise ValueError(f"line {lineno}: expected 10 columns, got {len(parts)}")
        try:
            row = [float(x) for x in parts]
        except ValueError as exc:
            raise ValueError(f"line {lineno}: non-numeric value") from exc
        event_float = row[0]
        event = int(event_float)
        if abs(event_float - event) > TOL:
            raise ValueError(f"line {lineno}: event must be an integer")
        if event not in EVENTS:
            raise ValueError(f"line {lineno}: unknown event {event}")
        row[0] = float(event)
        rows.append(row)
    if not rows:
        raise ValueError("empty results file")
    return rows


def first_index(rows: list[list[float]], event: int) -> int | None:
    for i, row in enumerate(rows):
        if int(row[0]) == event:
            return i
    return None


def check(rows: list[list[float]]) -> dict[str, object]:
    errors: list[str] = []
    warnings: list[str] = []

    events = [int(r[0]) for r in rows]
    times = [r[1] for r in rows]
    fuels = [r[8] for r in rows]
    carries = [r[9] for r in rows]

    for required in (1, 2, 3, 4):
        if required not in events:
            errors.append(f"missing required event {required}")

    if events[-1] != 4:
        errors.append("last row must be event 4")

    for i in range(1, len(times)):
        if times[i] + TOL < times[i - 1]:
            errors.append(f"time decreases between rows {i} and {i + 1}")
            break

    for i, fuel in enumerate(fuels, 1):
        if fuel < -1e-5:
            errors.append(f"negative fuel on row {i}: {fuel}")
            break

    idx_depart = first_index(rows, 1)
    idx_arrive = first_index(rows, 2)
    idx_leave = first_index(rows, 3)
    idx_return = first_index(rows, 4)

    payload = None
    mission_days = None
    stay_days = None
    final_fuel = fuels[-1]

    if idx_arrive is not None:
        before_arrival = rows[:idx_arrive]
        if before_arrival:
            payload = max(r[9] for r in before_arrival)
        for j, carry in enumerate(carries[idx_arrive:], idx_arrive + 1):
            if abs(carry) > 1e-3:
                errors.append(f"payload should be zero after event 2; row {j} has {carry}")
                break

    if idx_arrive is not None and idx_leave is not None:
        if idx_leave != idx_arrive + 1:
            errors.append("event 2 and event 3 must be consecutive rows")
        stay_days = (times[idx_leave] - times[idx_arrive]) * TU_DAY
        if stay_days < 3.0 - 1e-6 or stay_days > 10.0 + 1e-6:
            errors.append(f"moon stay {stay_days:.6f} days outside [3, 10]")

    if idx_depart is not None and idx_return is not None:
        mission_days = (times[idx_return] - times[idx_depart]) * TU_DAY
        if mission_days > 100.0 + 1e-6:
            errors.append(f"mission time {mission_days:.6f} days exceeds 100")

    if final_fuel > 100.0 + 1e-6:
        errors.append(f"final fuel {final_fuel:.6f} kg exceeds 100")

    if payload is None:
        errors.append("could not extract payload before event 2")
    elif payload < -1e-6:
        errors.append(f"negative payload score {payload}")

    burn_rows = [i for i, event in enumerate(events) if event == -1]
    if len(burn_rows) % 2 != 0:
        warnings.append("odd number of event -1 rows; burn pairing may be malformed")

    dock_rows = [i for i, event in enumerate(events) if event == 5]
    if dock_rows and len(dock_rows) not in (1, 2):
        warnings.append("event 5 usually appears once or twice at a docking instant")

    return {
        "valid_preflight": not errors,
        "payload_kg": payload,
        "final_fuel_kg": final_fuel,
        "mission_days": mission_days,
        "moon_stay_days": stay_days,
        "rows": len(rows),
        "errors": errors,
        "warnings": warnings,
        "note": "Tier 0 only: this is not full CR3BP physics validation.",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path)
    parser.add_argument("--json", action="store_true", help="print JSON only")
    args = parser.parse_args()

    try:
        rows = load_rows(args.results)
        report = check(rows)
    except Exception as exc:  # noqa: BLE001 - CLI should print user-facing error
        report = {
            "valid_preflight": False,
            "payload_kg": None,
            "final_fuel_kg": None,
            "mission_days": None,
            "moon_stay_days": None,
            "rows": 0,
            "errors": [str(exc)],
            "warnings": [],
            "note": "Tier 0 only: this is not full CR3BP physics validation.",
        }

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        status = "PASS" if report["valid_preflight"] else "FAIL"
        print(f"Preflight: {status}")
        print(f"Payload kg: {report['payload_kg']}")
        print(f"Final fuel kg: {report['final_fuel_kg']}")
        print(f"Mission days: {report['mission_days']}")
        print(f"Moon stay days: {report['moon_stay_days']}")
        print(f"Rows: {report['rows']}")
        for error in report["errors"]:
            print(f"ERROR: {error}")
        for warning in report["warnings"]:
            print(f"WARNING: {warning}")
        print(report["note"])

    return 0 if report["valid_preflight"] else 1


if __name__ == "__main__":
    sys.exit(main())

