# Astrodynamics Model Arena

This repository is a model arena for a hard astrodynamics agent task: solve a crewed Earth-Moon round trip in the planar circular restricted three-body problem and maximize landed payload.

The arena is built for blind, end-to-end agent runs. A model receives the original assignment, an empty workspace, validation tools, and a fixed budget. It must write code, search numerically, validate, improve, and submit a reproducible `results.txt`.

## Current Champion

| Rank | Run | Model | Mode | Budget | Payload | Status |
| ---: | --- | --- | --- | --- | ---: | --- |
| 1 | [Opus 4.5 Reference Run](arena/runs/opus-4.5-reference.md) | Opus 4.5 | not blind, long development | reference | 12,196.8897 kg | valid reference |

The arena target is simple: produce a valid submission with landed payload higher than the current champion under the same budget class.

## Challenge Modes

- **Blind Arena**: the model receives only the blind pack. It cannot see this repository's reference implementation, result file, report, generated data, figures, Git history, or champion payload.
- **Improvement Arena**: the model receives the full repository and attempts to improve the reference solution. This mode is useful, but it is not comparable to blind runs.

Use blind mode for GPT-5.5 vs Opus 4.7 comparisons.

## Standard Budget

Default scoreboard class:

- Wall-clock: 24 hours.
- Official validator calls: 50 maximum.
- Final submissions: 3 maximum.
- Human intervention: none, except infrastructure recovery.
- Clarification questions: not answered; the operator replies only with the protocol fallback.

Other budget classes are defined in [arena/BUDGETS.md](arena/BUDGETS.md). Do not compare runs across different budget classes without labeling them separately.

## Success Criteria

A run is valid only if it passes the gates in [arena/SUCCESS_CRITERIA.md](arena/SUCCESS_CRITERIA.md):

1. `results.txt` format and event order.
2. Static preflight.
3. Official validator when available.
4. Independent physics audit.
5. Clean reproduction from submitted code.

Payload ranking starts only after validity is established.

## Running A Blind Challenge

Build a blind pack:

```bash
bash benchmark/tools/make_blind_pack.sh /tmp/astrodynamics-blind-pack
```

Start the model in a clean context using:

```text
/tmp/astrodynamics-blind-pack/benchmark/AGENT_PROMPT_BLIND.md
```

The model must write final artifacts under `submission/`.

## Official Validator On Mac

The assignment ships a Windows x86-64 console executable: `error_checking_program.exe`. On this Apple Silicon Mac, the arena runner uses Wine/CrossOver/VM fallback as described in [arena/MAC_OFFICIAL_VALIDATOR.md](arena/MAC_OFFICIAL_VALIDATOR.md).

The model-facing command is:

```bash
python3 benchmark/tools/run_official_validator.py submission/results.txt
```

This command is included in the blind pack so agents have a closed validation loop.

## Repository Map

- `arena/` - public arena rules, scoreboard, budgets, validator setup, and run records.
- `benchmark/` - blind-pack prompt, protocol, scoring rules, and automation tools.
- `docs/assignment.md` - original problem statement.
- `docs/results.txt` - reference result file, excluded from blind packs.
- `docs/设计方法总结文档.md` - reference method note, excluded from blind packs.
- `matlab/` - Opus 4.5 reference implementation, excluded from blind packs.
- `error_checking_program.exe` - official Windows validator from the assignment package.

Large MATLAB data files are tracked with Git LFS. Run `git lfs pull` after cloning the full repository.

