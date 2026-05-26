# Challenge Pack Construction

For a fair one-shot test, avoid giving the model the reference MATLAB implementation unless the run is explicitly an improvement challenge.

## Recommended Blind Pack

Include:

- `docs/assignment.md`
- `error_checking_program.exe`
- `benchmark/ONE_SHOT_PROMPT.md`
- `benchmark/SCORING.md`
- An empty `src/` or `matlab/` directory

Withhold:

- `matlab/`
- `docs/results.txt`
- `docs/设计方法总结文档.md`
- `docs/Precision_Lunar_Dynamics_Design.pdf`
- Any prior run logs or generated `.mat` files

## Recommended Improvement Pack

Include the full repository. Ask the model to beat the baseline payload while keeping the solution reproducible.

## Why Split The Modes

The full repository is valuable as a baseline and implementation reference, but it leaks a strong solution. Blind mode measures whether a model can solve the task from the assignment. Improvement mode measures whether it can understand and improve an existing high-payload solution.

