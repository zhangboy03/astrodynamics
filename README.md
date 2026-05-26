# Astrodynamics Lunar Mission Benchmark

This repository packages a MATLAB solution and benchmark harness for the 2025 astrodynamics course project: design a crewed Earth-Moon round trip in the planar circular restricted three-body problem and maximize landed payload.

## Current Baseline

The current submitted solution is a feasible reference point, not a claimed global optimum.

| Metric | Value |
| --- | ---: |
| Landed payload, `M_carry` | 12,196.8897 kg |
| Return fuel | 43.7577 kg |
| Departure time | 2.563508749715 TU |
| Earth return time | 13.312296453260 TU |
| Mission time from departure | 46.6764 days |
| Absolute time from `t = 0` | 57.8084 days |

The primary benchmark objective is to produce a valid `results.txt` with a larger landed payload than the baseline.

## Repository Layout

- `docs/assignment.md` - original problem statement and result-file contract.
- `docs/results.txt` - copy of the current submitted result.
- `docs/设计方法总结文档.md` - method summary for the current solution.
- `docs/Precision_Lunar_Dynamics_Design.pdf` - exported design report.
- `matlab/` - MATLAB implementation, generated data, result files, and figures.
- `benchmark/` - prompts and scoring rules for future model evaluations.
- `skills/SKILL.md` - notes for using MATLAB tooling inside VS Code-compatible IDEs.
- `error_checking_program.exe` - Windows validation executable from the assignment package.

Large MATLAB data files are tracked with Git LFS. Run `git lfs pull` after cloning if a `.mat` file appears as a small pointer file.

## Reproducing the Baseline

From MATLAB, add the repository root and `matlab/` folder to the path, then run the phase scripts in order:

```matlab
cd matlab
run_phase0
leo_to_l1
llo_to_earth
l1_to_llo
generate_results_v2
```

The generated `matlab/results.txt` should match `docs/results.txt` for the baseline submission.

## Benchmark Use

Use `benchmark/ONE_SHOT_PROMPT.md` as the prompt template when testing a new model. For a clean challenge, give the model only the original assignment, the validation executable, and an empty/starter workspace. Keep this full repository as the reference solution and baseline record.

Use `benchmark/SCORING.md` to decide whether a run counts:

1. First gate: the produced `results.txt` must satisfy the assignment constraints and validator.
2. Primary score: maximize landed payload, column 10 before event `2`.
3. Tie breakers: stronger constraint margins, shorter verified mission time, reproducible code, and clearer method notes.

