# Challenge Pack Construction

For a fair blind B-mode test, avoid giving the model the reference MATLAB implementation unless the run is explicitly an improvement challenge.

## Recommended Blind Pack

Include:

- `docs/assignment.md`
- `error_checking_program.exe`
- `benchmark/AGENT_PROMPT_BLIND.md`
- `benchmark/SCORING_BLIND.md` copied into the pack as `benchmark/SCORING.md`
- `benchmark/BLIND_CHALLENGE_PROTOCOL.md`
- `benchmark/RUN_RECORD_TEMPLATE.md`
- `benchmark/tools/preflight_score.py`
- `benchmark/tools/run_official_validator.py`
- `benchmark/tools/run_official_validator.sh`
- An empty `src/` or `matlab/` directory

Withhold:

- `matlab/`
- `docs/results.txt`
- `docs/设计方法总结文档.md`
- `docs/Precision_Lunar_Dynamics_Design.pdf`
- Any prior run logs or generated `.mat` files
- `.git/` history and branch names
- The current baseline payload value

Build the pack with:

```bash
bash benchmark/tools/make_blind_pack.sh
```

## Recommended Improvement Pack

Include the full repository. Ask the model to beat the baseline payload while keeping the solution reproducible.

## Why Split The Modes

The full repository is valuable as a baseline and implementation reference, but it leaks a strong solution. Blind mode measures whether a model can solve the task from the assignment. Improvement mode measures whether it can understand and improve an existing high-payload solution.

Because the repository is public, blind runs should disable web/search tools when possible. If web/search cannot be disabled, the prompt must prohibit looking up this repository, the assignment title, prior solutions, or benchmark results.
