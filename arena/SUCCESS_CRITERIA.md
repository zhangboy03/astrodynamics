# Success Criteria

The arena uses hard validity gates. Payload matters only after a submission is valid.

## Required Final Artifacts

The final submission must contain:

```text
submission/
  results.txt
  README.md
  run.log
  src/ or matlab/ or scripts/
```

`submission/README.md` must include:

- Reproduction commands.
- Trajectory architecture summary.
- Final payload.
- Final fuel.
- Mission time from departure to Earth return.
- Validation commands and outcomes.

## Gate 0: Format Preflight

Run:

```bash
python3 benchmark/tools/preflight_score.py submission/results.txt
```

This must pass. It checks:

- Ten numeric columns per row.
- Valid event codes.
- Monotone time.
- Required events `1`, `2`, `3`, `4`.
- Event `4` as the last row.
- Event `2` and event `3` consecutive.
- Moon stay in `[3, 10]` days.
- Mission time from event `1` to event `4` at most 100 days.
- Final fuel in `[0, 100]` kg.
- Payload extractable before event `2`.

## Gate 1: Official Validator

Run:

```bash
python3 benchmark/tools/run_official_validator.py submission/results.txt
```

If Wine/CrossOver/Windows is available, the official validator must pass.

If the official executable cannot run on the host, record `official validator unavailable` and move to independent physics audit. The run is not marked fully official until the same `results.txt` later passes the official validator on a compatible host.

## Gate 2: Independent Physics Audit

The audit must verify:

- CR3BP coast propagation between consecutive coast endpoints.
- Departure state lies on the 400 km Earth circular orbit in the inertial two-body sense.
- LLO arrival and departure states lie on the 100 km lunar circular orbit with consistent direction.
- Docking state matches the L1 Lyapunov supply orbit within assignment tolerances.
- Patch-point position error at most `1e-6` LU.
- Patch-point velocity error at most `1e-6` VU.
- Moon altitude never below 100 km.
- Earth altitude before return entry never below 400 km.
- Distance never exceeds 2 LU.
- Impulse fuel accounting follows the assignment mass equation.

## Gate 3: Reproducibility

From a clean directory:

1. Install the documented dependencies.
2. Run the submitted reproduction command.
3. Confirm the regenerated `results.txt` matches the submitted file within documented tolerances.

Submissions with hand-edited numerical rows fail this gate.

## Score

For valid submissions:

```text
score = landed payload M_carry in kg
```

The explicit arena goal is to beat the current champion payload recorded in `arena/SCOREBOARD.md`.

