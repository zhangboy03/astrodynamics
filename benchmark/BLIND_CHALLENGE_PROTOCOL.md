# Blind Challenge Protocol

This protocol defines the end-to-end blind benchmark mode for comparing future agent models on the astrodynamics lunar mission task.

## Mode

Use **B-mode agent execution**:

- The model receives one initial task prompt.
- The model may autonomously create code, install packages, run numerical searches, debug, and validate.
- The model must not ask the human for clarification during the run.
- The default arena budget is Standard 24h: 24 hours wall-clock, 50 official validator calls, and 3 final submissions.
- The run ends when the model declares a final submission, reaches a hard budget limit, or the operator aborts for infrastructure reasons.

## Primary Measurement

The benchmark measures whether an agent can move from the original assignment to a reproducible, valid trajectory solution with high landed payload.

It should test:

- Problem understanding from the original statement.
- Numerical modeling of the planar CR3BP.
- Search and optimization strategy.
- Long-running debugging discipline.
- Constraint validation and result-file formatting.
- Reproducibility of the generated solution.

It should not test whether the model can discover this repository or copy the reference solution.

## Contamination Rules

Blind runs must not expose the model to:

- This repository's `matlab/` directory.
- `docs/results.txt`.
- `docs/设计方法总结文档.md`.
- `docs/Precision_Lunar_Dynamics_Design.pdf`.
- Any generated `.mat` files or figures from the reference solution.
- The current baseline payload value.
- Prior conversations about the baseline solution.
- Commit history, branches, or GitHub issues/PRs for this repository.

Because this repository is public, disable web/search tools for blind runs when possible. If web tools cannot be disabled, the prompt must prohibit searching for this repository, the assignment title, prior solutions, or benchmark results. Treat any run that accesses leaked reference material as invalid.

## Blind Pack Contents

The blind pack should contain only:

- `docs/assignment.md`
- `error_checking_program.exe`
- `benchmark/AGENT_PROMPT_BLIND.md`
- `benchmark/SCORING_BLIND.md` copied into the pack as `benchmark/SCORING.md`
- `benchmark/BLIND_CHALLENGE_PROTOCOL.md`
- `benchmark/RUN_RECORD_TEMPLATE.md`
- `benchmark/tools/preflight_score.py`
- `benchmark/tools/run_official_validator.py`
- `benchmark/tools/run_official_validator.sh`
- Empty `workspace/` and `submission/` directories

The pack must not include `.git/` metadata.

## Operator Runbook

For each model, create a fresh run directory:

```text
runs/YYYY-MM-DD-model-name/
  input/
  transcript/
  workspace/
  submission/
  run-record.md
```

Run setup:

1. Build a fresh blind pack from the source repository.
2. Copy or extract the blind pack into `input/`.
3. Start the model with a clean context.
4. Paste the entire contents of `benchmark/AGENT_PROMPT_BLIND.md`.
5. Attach or mount the blind pack files.
6. Do not provide any other context.
7. Do not answer clarification questions; if the model asks, reply only: `Proceed with reasonable assumptions based on the assignment.`
8. Record all tool output, final artifacts, elapsed time, model identifier, budget class, official validator calls, and environment details.

Run isolation:

- Use a separate directory for GPT-5.5 and Opus 4.7.
- Do not reuse files, caches, generated data, package environments, or intermediate notes between model runs.
- If the same machine must be reused, create separate virtual environments and clear shell history/context visible to the agent.

Budget enforcement:

- Use `arena/BUDGETS.md` as the source of truth.
- The default class is Standard 24h.
- Count every call to `benchmark/tools/run_official_validator.py` as an official validator call, whether it passes, fails, times out, or reports unavailable.
- Count a final submission each time the model declares artifacts under `submission/` as final.
- If a run exceeds any hard limit, mark it `over budget`; archive it, but do not rank it in that budget class.

## Submission Contract

The model must place final artifacts under `submission/`:

```text
submission/
  results.txt
  README.md
  run.log
  src/ or matlab/ or scripts/
```

Required contents:

- `results.txt` in the exact assignment format.
- Code that regenerates `results.txt`.
- A short method note in `submission/README.md`.
- A run log with final payload, final fuel, mission time, validation commands, and validation output.

Manual editing of final numerical rows is disallowed unless the edit is produced by a documented script that can be rerun.

## Validation Tiers

Use a multi-tier validation process.

Tier 0: static preflight

```bash
python3 benchmark/tools/preflight_score.py submission/results.txt
```

This checks format, event ordering, basic timing, final fuel, and extracts the payload. It is not a full physics validator.

Tier 1: official/package validator

- Run the official wrapper:

```bash
python3 benchmark/tools/run_official_validator.py submission/results.txt
```

- This wrapper tries Wine/CrossOver/Windows-native execution patterns for `error_checking_program.exe`.
- Save stdout/stderr to `submission/run.log`.
- If the wrapper reports that the official executable is unavailable, record `official pending` and continue to physics audit. The result is not fully official until the same file passes the executable on a compatible host.

Tier 2: independent physics audit

- Reintegrate every coast segment under the CR3BP equations.
- Check docking against the L1 Lyapunov supply orbit.
- Check LEO, LLO, and Earth-return boundary conditions.
- Check path constraints by dense resampling.
- Check impulse fuel accounting.

This audit may be done after the model run by the operator or by a separate judge agent that has not seen the reference solution.

Tier 3: reproducibility

- Start from a clean directory.
- Run the submitted reproduction commands.
- Confirm that the regenerated `results.txt` matches the submitted file within numerical tolerances.

## Scoring

Validity is a hard gate. Invalid submissions receive score 0.

For valid submissions:

```text
score = landed payload M_carry in kg
```

Tie breakers are defined in `benchmark/SCORING.md`.

## Result Comparison

For GPT-5.5 vs Opus 4.7, report:

- Whether each run remained blind.
- Whether each run produced a valid submission.
- Payload score.
- Final fuel.
- Mission time from departure to return.
- Number of autonomous debugging cycles, if available.
- Wall-clock elapsed time.
- Reproducibility status.
- Main trajectory architecture inferred from the method note.

Do not reveal one model's result to the other before both runs are complete.
