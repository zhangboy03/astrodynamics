---
name: matlab-windsurf-extension
description: "Use when configuring/troubleshooting the MathWorks MATLAB extension in Windsurf/Anti Gravity (VS Code-like IDE): editing .m files, enabling run/debug/format/navigation features, setting MATLAB.installPath, and resolving common limitations/errors (MATLAB R2021b+ required for advanced features)."
---

# MATLAB Extension for Windsurf / Anti Gravity

## Overview

Provide a practical workflow for using the MATLAB extension to **edit**, **run**, and **debug** MATLAB code in Windsurf/Anti Gravity. Distinguish **basic features** (no MATLAB install) vs **advanced features** (requires MATLAB R2021b or later).

## Quick Triage (ask first)

- Confirm the IDE: Windsurf / Anti Gravity (VS Code compatible).
- Confirm user intent: edit-only vs run/debug/format/navigation.
- Confirm MATLAB availability:
  - If user wants advanced features: require MATLAB **R2021b+** installed (R2021a is not supported).
  - Ask OS + MATLAB version + install location (Windows/macOS/Linux).

## Feature Map

### Basic (MATLAB not required)
- Syntax highlighting
- Snippets
- Commenting and code folding

### Advanced (requires MATLAB installed)
- Run and debug MATLAB code
- Auto-completion, formatting, navigation, and code analysis

## Run MATLAB Code (workflow)

- Open a `.m` file (or set language mode to MATLAB).
- Run via the editor run controls or command palette:
  - `MATLAB: Run File` (`matlab.runFile`, default `F5`)
  - `MATLAB: Run Current Selection` (`matlab.runSelection`, default `Shift+Enter`)
- Read output in the IDE terminal (“Terminal” pane) / MATLAB terminal.
- Stop execution with `Ctrl+C`.

## Useful Commands (command palette / context menus)
- Open MATLAB UI terminals/windows:
  - `MATLAB: Open Command Window` (`matlab.openCommandWindow`)
- Run helpers:
  - `MATLAB: Run File` (`matlab.runFile`)
  - `MATLAB: Run Current Selection` (`matlab.runSelection`)
  - `MATLAB: Interrupt` (`matlab.interrupt`)
- Working directory / path management:
  - `MATLAB: Change current directory` (`matlab.changeDirectory`)
  - `MATLAB: Add Folder to Path` / `Add Folder and Subfolders to Path` (`matlab.addFolderToPath`, `matlab.addFolderAndSubfoldersToPath`)
- Connection / sign-in:
  - `MATLAB: Change MATLAB Connection` (`matlab.changeMatlabConnection`)
  - `MATLAB: Manage Sign In Options` (`matlab.enableSignIn`)
- Misc:
  - `MATLAB: Open File` (`matlab.openFile`)
  - `MATLAB: Reset Deprecation Warning Popups` (`matlab.resetDeprecationPopups`)

## Debug MATLAB Code (workflow)

- Set breakpoints by clicking the gutter left of an executable line.
- Run the file; execution stops at the first breakpoint.
- Use the Debug toolbar actions (Continue / Step / Stop).
- Use the Run and Debug view for workspace variables, watches, and call stack.
- If the IDE debugger does not auto-open on breakpoint, enable:
  - `MATLAB.startDebuggerAutomatically: true`

## Configuration (what to change, when)

### `MATLAB.installPath` (most common fix)
- Use when MATLAB is installed but not discoverable on PATH.
- Set it to the **top-level MATLAB installation directory** (not a binary deep path).
- Recommend verifying the value using MATLAB itself:
  - Run `matlabroot` in MATLAB and use that returned path as `MATLAB.installPath`.
- Example paths:
  - Windows: `C:\\Program Files\\MATLAB\\R2022b`
  - macOS: `/Applications/MATLAB_R2022b.app`
  - Linux: `/usr/local/MATLAB/R2022b`

### Other settings (use selectively)
- `MATLAB.matlabConnectionTiming`:
  - `onStart` (default): start MATLAB when a `.m` file opens
  - `onDemand`: start only when needed
  - `never`: never start MATLAB (limits advanced functionality)
- `MATLAB.indexWorkspace` (default `true`): disable to improve performance in large workspaces.
- `MATLAB.maxFileSizeForAnalysis` (default `0`): set a character limit to skip analysis on huge files.
- `MATLAB.showFeatureNotAvailableError` (default `true`): disable if the user prefers fewer popups.
- `MATLAB.signIn` (default `false`): enable for browser-based sign-in on unactivated installs.
- `MATLAB.telemetry` (default `true`): disable if telemetry is not desired.

## Known Limitations (set expectations)

- Output from timers/callbacks/DataQueue is not shown in the MATLAB Command Window output stream.
- Custom run configurations per file are not supported.
- Breakpoints set/cleared via `dbstop`/`dbclear` may not appear in the IDE UI.
- Variable changes made in the MATLAB terminal while paused may not reflect in Run and Debug view until the next pause.

## Troubleshooting Playbook

### “Feature requires MATLAB” / advanced features not working
- Confirm MATLAB is installed and version is **R2021b or later**.
- If MATLAB is not on PATH, set `MATLAB.installPath`.
- If the user does not want MATLAB started automatically, set `MATLAB.matlabConnectionTiming: onDemand` (or `never` if they only want basic features).

### Performance issues (slow indexing / analysis)
- Disable indexing: `MATLAB.indexWorkspace: false`.
- Cap analysis for huge files: set `MATLAB.maxFileSizeForAnalysis` (or keep `0` for no limit).

## Example User Requests This Skill Should Handle
- “我装了 MATLAB，但在 Anti Gravity 里无法 Run/Debug，怎么配置？”
- “macOS 上 `MATLAB.installPath` 应该填什么？”
- “为什么我设置了断点但调试器不自动弹出来？”
- “工作区很大，MATLAB indexing 太慢怎么办？”
