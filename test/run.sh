#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$PLUGIN_DIR/test/.test_output"

total_passed=0
total_failed=0
failed_files=()

for test_file in "$SCRIPT_DIR"/test_*.vim; do
  test_name="$(basename "$test_file" .vim)"
  echo "=== $test_name ==="

  rm -f "$OUTPUT_FILE"

  timeout 30 vim -u NONE -N -es \
    --cmd "let g:test_file='$test_file'" \
    --cmd "let g:test_output_file='$OUTPUT_FILE'" \
    --cmd "set rtp+=$PLUGIN_DIR" \
    -S "$SCRIPT_DIR/runner.vim" 2>/dev/null
  exit_code=$?

  if [ -f "$OUTPUT_FILE" ]; then
    cat "$OUTPUT_FILE"
  else
    echo "[ERROR] No test output produced (vim exit code: $exit_code)"
  fi

  if [ "$exit_code" -eq 0 ]; then
    ((total_passed++))
  else
    ((total_failed++))
    failed_files+=("$test_name")
  fi
  echo ""
done

rm -f "$OUTPUT_FILE"

echo "=== SUMMARY ==="
echo "Test files passed: $total_passed"
echo "Test files failed: $total_failed"
if [ ${#failed_files[@]} -gt 0 ]; then
  echo "Failed: ${failed_files[*]}"
fi
exit $((total_failed > 0 ? 1 : 0))
