#!/usr/bin/env bash
# Full project backup into ../Backups/cleanstrike-backup-<timestamp>/ :
#   repo.bundle      complete git history (restore: git clone repo.bundle)
#   workspace.zip    working tree incl. uncommitted files and dist builds (no bin/obj)
#   testgame.zip     TestGame/Cleanstrike + override.cfg (game exe/pck excluded: reinstall from Steam)
#   user-data.zip    Road to Vostok saves + Cleanstrike app config/profiles
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
P="$(dirname "$R")"
STAMP=$(date +%Y-%m-%d_%H%M%S)
OUT="$P/Backups/cleanstrike-backup-$STAMP"
mkdir -p "$OUT"
git -C "$R" bundle create "$OUT/repo.bundle" --all 2>/dev/null
python -I - "$R" "$P" "$APPDATA" "$OUT" <<'PY'
import os, sys, zipfile
R, P, APPDATA, OUT = sys.argv[1:5]
def pack(dst, roots, skip_dirs=(), skip_ext=()):
    n = 0
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for root, arc in roots:
            if os.path.isfile(root):
                z.write(root, arc); n += 1; continue
            for d, dirs, files in os.walk(root):
                dirs[:] = [x for x in dirs if x not in skip_dirs]
                for f in files:
                    if f.lower().endswith(skip_ext): continue
                    p = os.path.join(d, f)
                    z.write(p, os.path.join(arc, os.path.relpath(p, root)).replace(os.sep, "/")); n += 1
    print(f"{os.path.basename(dst)}: {n} files, {os.path.getsize(dst)/1e6:.1f} MB")
pack(os.path.join(OUT, "workspace.zip"), [(R, "cleanstrike")], skip_dirs=("bin", "obj", ".vs", "app", "save_snapshot"))
tg = os.path.join(P, "TestGame")
pack(os.path.join(OUT, "testgame.zip"), [(os.path.join(tg, "Cleanstrike"), "TestGame/Cleanstrike"), (os.path.join(tg, "override.cfg"), "TestGame/override.cfg")])
rtv = os.path.join(APPDATA, "Road to Vostok")
roots = [(os.path.join(rtv, f), "Road to Vostok/" + f) for f in os.listdir(rtv) if f.endswith(".tres")]
roots += [(os.path.join(rtv, "cleanstrike"), "Road to Vostok/cleanstrike")]
cs = os.path.join(APPDATA, "Cleanstrike")
if os.path.isdir(cs): roots.append((cs, "Cleanstrike"))
pack(os.path.join(OUT, "user-data.zip"), roots, skip_ext=(".png",))
PY
echo "Backup: $OUT"
