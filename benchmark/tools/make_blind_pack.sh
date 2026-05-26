#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_dir="${1:-"$repo_root/challenge-pack/astrodynamics-blind-challenge"}"

rm -rf "$out_dir"
mkdir -p \
  "$out_dir/docs" \
  "$out_dir/benchmark/tools" \
  "$out_dir/workspace" \
  "$out_dir/submission"

cp "$repo_root/docs/assignment.md" "$out_dir/docs/assignment.md"
cp "$repo_root/error_checking_program.exe" "$out_dir/error_checking_program.exe"
cp "$repo_root/benchmark/AGENT_PROMPT_BLIND.md" "$out_dir/benchmark/AGENT_PROMPT_BLIND.md"
cp "$repo_root/benchmark/BLIND_CHALLENGE_PROTOCOL.md" "$out_dir/benchmark/BLIND_CHALLENGE_PROTOCOL.md"
cp "$repo_root/benchmark/SCORING_BLIND.md" "$out_dir/benchmark/SCORING.md"
cp "$repo_root/benchmark/RUN_RECORD_TEMPLATE.md" "$out_dir/benchmark/RUN_RECORD_TEMPLATE.md"
cp "$repo_root/benchmark/tools/preflight_score.py" "$out_dir/benchmark/tools/preflight_score.py"

touch "$out_dir/workspace/.gitkeep" "$out_dir/submission/.gitkeep"

cat > "$out_dir/README.md" <<'EOF'
# Astrodynamics Blind Challenge Pack

Start the model with `benchmark/AGENT_PROMPT_BLIND.md`.

This pack intentionally excludes the reference implementation, reference result,
method summary, generated MATLAB data, figures, and Git history.

Final artifacts must be written to `submission/`.
EOF

find "$out_dir" -name .DS_Store -delete

echo "Blind challenge pack written to: $out_dir"
