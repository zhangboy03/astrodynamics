# Running The Official Validator On Mac

The official validator is `error_checking_program.exe`, a Windows x86-64 console executable. This repository is maintained on an Apple Silicon Mac, so it cannot run natively.

## Recommended Order

### 1. Wine via Homebrew

Install:

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask wine-stable
```

Run through the arena wrapper:

```bash
python3 benchmark/tools/run_official_validator.py submission/results.txt
```

Homebrew currently provides `wine-stable` as a cask for macOS, but the formula page marks it deprecated with a disable date of 2026-09-01. If Wine breaks or disappears, use CrossOver or a Windows VM instead.

Current maintainer-machine status:

- Machine: Apple Silicon macOS.
- Rosetta: available.
- `wine-stable` install attempt: blocked because the `gstreamer-runtime` dependency uses a system `.pkg` installer that requires an interactive sudo password.
- Arena wrapper behavior without Wine/CrossOver: exits `86` and reports `official_available: false`.

This means agents can still follow a closed loop locally through preflight and physics audit, but the official executable is `official pending` until Wine/CrossOver is installed by the operator or the file is checked in a Windows VM.

### 2. CrossOver fallback

CrossOver supports Intel and Apple Silicon Macs and can run standalone Windows executables from a bottle. Set `CROSSOVER_WINE` to its Wine binary if auto-detection fails:

```bash
export CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
python3 benchmark/tools/run_official_validator.py submission/results.txt
```

### 3. Windows VM final fallback

If Wine/CrossOver cannot run the executable reliably, use a Windows VM and copy in:

- `error_checking_program.exe`
- `submission/results.txt`

The run may pass preflight and physics audit on macOS, but it should be labeled `official pending` until the Windows executable passes on a compatible host.

## Model Challenge Flow

Agents should use the same loop:

```text
generate results.txt
run preflight_score.py
run run_official_validator.py
inspect failures
improve trajectory
repeat within budget
```

Official validator calls count against the budget in `arena/BUDGETS.md`.

## Sources

- Homebrew `wine-stable`: https://formulae.brew.sh/cask/wine-stable
- CrossOver command-line and standalone executable support: https://www.codeweavers.com/support/docs/crossover-mac/index
- Whisky is a Wine wrapper for Apple Silicon, but it is not the preferred automation path here: https://frankea.github.io/Whisky/
