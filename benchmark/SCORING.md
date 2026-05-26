# Scoring Rules

This benchmark is useful only if feasibility is treated as a hard gate. A higher payload that violates a mission constraint should not outrank a lower but valid solution.

## Validity Gate

A submission must include:

- A `results.txt` file in the assignment format.
- Source code or scripts that regenerate the result.
- A short method note explaining the trajectory construction.
- Validator output or equivalent numerical evidence for all constraints.

Reject the submission if any of these fail:

- Missing final event `4`.
- Event format or row ordering violates `docs/assignment.md`.
- Total mission time from event `1` departure to event `4` return exceeds 100 days.
- Moon stay between events `2` and `3` is outside 3.0 to 10.0 days.
- Final fuel exceeds 100 kg.
- Any docking, patching, departure, LLO, or return state misses the required tolerance.
- The trajectory violates the altitude or 2 LU path constraints.

## Primary Score

For valid submissions, rank by landed payload:

```text
score = M_carry in kg
```

Use the carried mass from the departure rows before event `2`; after event `2`, `M_carry` should become zero because the payload is left on the Moon.

Current champion:

```text
Model = Opus 4.5
Run = arena/runs/opus-4.5-reference.md
M_carry = 12196.88969372 kg
```

Public scoreboard: `arena/SCOREBOARD.md`.

## Tie Breakers

When two valid submissions differ by less than 1 kg of payload, break ties in this order:

1. Larger minimum constraint margin across patch-point position and velocity errors.
2. Lower final fuel while staying non-negative and <= 100 kg.
3. Shorter verified mission time from departure to return.
4. Simpler reproduction path: fewer manual steps, fewer hidden dependencies, deterministic output.
5. Clearer explanation of trajectory architecture and optimization choices.

## Run Record Template

Record every benchmark attempt with:

```text
Model:
Date:
Context/window:
Tool access:
Challenge mode: blind | improvement
Time budget:
Input package commit/hash:
Validation command:
Payload:
Final fuel:
Mission time:
Result file path:
Notes:
```
