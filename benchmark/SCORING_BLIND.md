# Blind Scoring Rules

This file is safe to include in blind challenge packs. It intentionally does not disclose any reference payload or baseline result.

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
- Final fuel exceeds 100 kg or is negative.
- Any docking, patching, departure, LLO, or return state misses the required tolerance.
- The trajectory violates the altitude or 2 LU path constraints.
- The submitted `results.txt` cannot be regenerated from the submitted code.

## Primary Score

For valid submissions, rank by landed payload:

```text
score = M_carry in kg
```

Use the carried mass from the departure rows before event `2`; after event `2`, `M_carry` should become zero because the payload is left on the Moon.

## Tie Breakers

When two valid submissions differ by less than 1 kg of payload, break ties in this order:

1. Larger minimum constraint margin across patch-point position and velocity errors.
2. Lower final fuel while staying non-negative and <= 100 kg.
3. Shorter verified mission time from departure to return.
4. Simpler reproduction path: fewer manual steps, fewer hidden dependencies, deterministic output.
5. Clearer explanation of trajectory architecture and optimization choices.

## Reporting

Do not tell a model any other model's score or payload before all blind runs are complete.

