# Running The Official Validator On Mac

The official validator is `error_checking_program.exe`, a Windows x86-64 console executable. This repository is maintained on an Apple Silicon Mac, so it cannot run natively.

## Current Maintainer Setup

The working Mac path is CrossOver:

- CrossOver bottle: `astrodynamics-validator`
- Bottle type: `win10_64`
- MATLAB Runtime: `R2023a`, version `9.14`
- Microsoft Visual C++ Redistributable: x64, native DLL override enabled
- Smoke test: `docs/results.txt` passes the official validator

```bash
python3 benchmark/tools/run_official_validator.py docs/results.txt --timeout 120
```

The official executable's contract is:

- Place `results.txt` in the executable's working directory.
- Launch `error_checking_program.exe` with no positional arguments.

The repository wrapper handles this by copying the executable and the candidate result file into a temporary directory, naming the candidate `results.txt`, and running the executable without arguments.

The executable returns process exit code `0` for both valid and invalid result files. Treat the wrapper JSON field `official_pass`, not the raw process exit code of `error_checking_program.exe`, as the authoritative outcome.

## CrossOver Setup

Install CrossOver:

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask crossover
```

Create the 64-bit bottle:

```bash
"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxbottle" \
  --bottle astrodynamics-validator \
  --create --template win10_64 \
  --description "Astrodynamics official validator 64-bit bottle" \
  --default --verbose
```

Install MATLAB Runtime R2023a 9.14 into the bottle. The tested package is MathWorks' Windows 64-bit R2023a Update 8 runtime:

```bash
mkdir -p ~/Downloads/matlab-runtime-cache
curl -L --fail --continue-at - \
  --output ~/Downloads/matlab-runtime-cache/MATLAB_Runtime_R2023a_Update_8_win64.zip \
  "https://ssd.mathworks.com/supportfiles/downloads/R2023a/Release/8/deployment_files/installer/complete/win64/MATLAB_Runtime_R2023a_Update_8_win64.zip"

unzip -q ~/Downloads/matlab-runtime-cache/MATLAB_Runtime_R2023a_Update_8_win64.zip \
  -d ~/Downloads/matlab-runtime-cache/runtime-unzip
```

Create `~/Downloads/matlab-runtime-cache/runtime-install.input`:

```text
destinationFolder=C:\Program Files\MATLAB\MATLAB Runtime
agreeToLicense=yes
outputFile=C:\TEMP\matlab-runtime-install.log
```

Install it:

```bash
mkdir -p "$HOME/Library/Application Support/CrossOver/Bottles/astrodynamics-validator/drive_c/TEMP"
CX_BOTTLE=astrodynamics-validator \
"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" \
  "$HOME/Downloads/matlab-runtime-cache/runtime-unzip/setup.exe" \
  -inputfile "Z:\\Users\\$USER\\Downloads\\matlab-runtime-cache\\runtime-install.input"
```

Install the Microsoft Visual C++ Redistributable and force native DLLs for the VC runtime family:

```bash
curl -L --fail \
  --output ~/Downloads/matlab-runtime-cache/vc_redist.x64.exe \
  "https://aka.ms/vc14/vc_redist.x64.exe"

CX_BOTTLE=astrodynamics-validator \
"/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" \
  "$HOME/Downloads/matlab-runtime-cache/vc_redist.x64.exe" /install /quiet /norestart

for dll in msvcp140 msvcp140_1 msvcp140_2 msvcp140_atomic_wait \
  msvcp140_codecvt_ids vcruntime140 vcruntime140_1 \
  vcruntime140_threads concrt140; do
  CX_BOTTLE=astrodynamics-validator \
  "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" \
    reg add 'HKCU\Software\Wine\DllOverrides' /v "$dll" /d native,builtin /f >/dev/null
done
```

Smoke test:

```bash
python3 benchmark/tools/run_official_validator.py docs/results.txt --timeout 120
```

Expected result:

```json
{
  "official_available": true,
  "official_pass": true,
  "runner": "crossover"
}
```

## Alternative Runners

### Wine via Homebrew

Homebrew currently provides `wine-stable` as a cask for macOS, but the formula page marks it deprecated with a disable date of 2026-09-01. On this maintainer machine, the Wine route was abandoned because macOS blocked the dependent `gstreamer-runtime` package path. CrossOver is the recommended Mac route for this arena.

If a standalone Wine install is available, the wrapper can use it:

```bash
python3 benchmark/tools/run_official_validator.py submission/results.txt
```

### Windows VM Final Fallback

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

- MathWorks MATLAB Runtime R2023a is version 9.14: https://www.mathworks.com/products/compiler/matlab-runtime.html
- Microsoft latest supported Visual C++ Redistributable x64 permalink: https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
- Homebrew `wine-stable`: https://formulae.brew.sh/cask/wine-stable
- CrossOver command-line and standalone executable support: https://www.codeweavers.com/support/docs/crossover-mac/index
- Whisky is a Wine wrapper for Apple Silicon, but it is not the preferred automation path here: https://frankea.github.io/Whisky/
