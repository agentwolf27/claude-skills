#!/bin/sh
# Checks every skills/*/SKILL.md: frontmatter present, name matches the folder,
# description non-empty. Exits non-zero on the first failure.
#
#   sh scripts/check-skills.sh            # from the repo root
#   sh scripts/check-skills.sh ~/.claude/skills   # or any skills directory

set -eu
root="${1:-$(dirname "$0")/../skills}"
fail=0
count=0

for dir in "$root"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  file="$dir/SKILL.md"
  count=$((count + 1))

  if [ ! -f "$file" ]; then
    echo "FAIL  $name: no SKILL.md"; fail=1; continue
  fi
  if [ "$(head -n 1 "$file")" != "---" ]; then
    echo "FAIL  $name: SKILL.md does not open with ---"; fail=1; continue
  fi
  # frontmatter = lines between the first and second ---
  fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")
  fm_name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)
  fm_desc=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n 1)

  if [ -z "$fm_name" ]; then
    echo "FAIL  $name: no name in frontmatter"; fail=1; continue
  fi
  if [ "$fm_name" != "$name" ]; then
    echo "FAIL  $name: frontmatter name is '$fm_name'"; fail=1; continue
  fi
  if [ -z "$fm_desc" ]; then
    echo "FAIL  $name: no description in frontmatter"; fail=1; continue
  fi
  echo "ok    $name"
done

if [ "$count" -eq 0 ]; then
  echo "FAIL  no skill folders under $root"; exit 1
fi
[ "$fail" -eq 0 ] && echo "$count skills checked, all ok"
exit "$fail"
