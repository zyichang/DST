#!/usr/bin/env bash
# Insert into R Command's saved data:
#   - my_commands.snippet    : rebuild of the user's own 11 commands (category Certification)
#   - medal_commands.snippet : 202 能力勋章 commands, each with its real mod icon
# Refuses to run while DST is open, because the mod rewrites the whole file on save.
set -euo pipefail

SAVE="/home/yichangzhang/.klei/DoNotStarveTogether/435578629/client_save/mod_config_data/nomu_command_manager"
DEV="/home/yichangzhang/Development/DST"

# Exact-binary check via /proc: pgrep -f self-matches this script's own command line.
running=0
for d in /proc/[0-9]*; do
    exe=$(readlink "$d/exe" 2>/dev/null || true)
    case "$exe" in *dontstarve*) running=1 ;; esac
done
if [ "$running" = 1 ]; then
    echo "ABORT: Don't Starve Together is still running. Quit the game first." >&2
    exit 1
fi

[ -f "$SAVE" ] || { echo "ABORT: save not found: $SAVE" >&2; exit 1; }
for s in my_commands.snippet medal_commands.snippet; do
    [ -f "$DEV/$s" ] || { echo "ABORT: missing $DEV/$s" >&2; exit 1; }
done

if grep -q '能力勋章' "$SAVE"; then
    echo "ABORT: save already has a 能力勋章 category - refusing to duplicate." >&2
    exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
cp -- "$SAVE" "$SAVE.bak"
cp -- "$SAVE" "$SAVE.$STAMP.bak"
echo "backed up -> $SAVE.bak"
echo "backed up -> $SAVE.$STAMP.bak"

python3 - "$SAVE" "$DEV/my_commands.snippet" "$DEV/medal_commands.snippet" <<'PY'
import sys, os
save, mine, medals = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(save, encoding='utf-8').read()
a = open(mine, encoding='utf-8').read()
b = open(medals, encoding='utf-8').read()

marker = 'COMMANDS={'
i = raw.index(marker) + len(marker)

o, c = raw.count('{'), raw.count('}')
merged = raw[:i] + a + ',' + b + ',' + raw[i:]

assert merged.startswith('KLEI'),                        "KLEI header lost"
assert merged.count('{') - o == a.count('{') + b.count('{'), "brace insert mismatch (open)"
assert merged.count('}') - c == a.count('}') + b.count('}'), "brace insert mismatch (close)"
assert merged.count('{') == merged.count('}'),           "unbalanced braces after merge"
assert merged.rstrip().endswith('}}}'),                  "tail structure broken"

tmp = save + '.tmp'
open(tmp, 'w', encoding='utf-8').write(merged)
os.replace(tmp, save)

print("inserted %d personal + %d medal entries" % (a.count('{'), b.count('{')))
PY

echo
echo "verification:"
echo "  能力勋章 entries : $(grep -o '能力勋章' "$SAVE" | wc -l)"
echo "  Certification    : $(grep -o 'category=\"Certification\"' "$SAVE" | wc -l)"
echo "  file size        : $(stat -c%s "$SAVE") bytes"
echo "done."
