"""Package a Cleanstrike mod folder into a .csmod archive.

Usage: python tools/build_mod.py mods/RoadToTarkov [--out dist] [--install <game folder>]

Checks that mod.txt sits at the archive root and has an id, and writes
forward-slash paths (Godot cannot mount zips with backslash paths).
"""
import argparse
import configparser
import os
import shutil
import sys
import zipfile


def read_manifest(path):
    cp = configparser.ConfigParser(delimiters=("=",), comment_prefixes=(";", "#"), inline_comment_prefixes=None, strict=False, interpolation=None)
    cp.optionxform = str
    with open(path, encoding="utf-8") as f:
        cp.read_file(f)
    get = lambda s, k, d="": cp.get(s, k, fallback=d).strip().strip('"')
    return cp, get


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--out", default="dist")
    ap.add_argument("--install", help="game folder; copies the build into <game>/Cleanstrike/mods")
    a = ap.parse_args()

    manifest = os.path.join(a.folder, "mod.txt")
    if not os.path.isfile(manifest):
        sys.exit("error: %s has no mod.txt at its root" % a.folder)
    cp, get = read_manifest(manifest)
    mod_id, version = get("mod", "id"), get("mod", "version", "0.0.0")
    if not mod_id:
        sys.exit("error: mod.txt needs [mod] id=\"...\"")
    for section in ("script_extend", "script_overrides"):
        if cp.has_section(section):
            for target, ext in cp.items(section):
                rel = ext.strip().strip('"').replace("res://", "", 1)
                if not os.path.isfile(os.path.join(a.folder, rel)):
                    sys.exit("error: %s points at missing file %s" % (target, ext))

    os.makedirs(a.out, exist_ok=True)
    name = os.path.basename(os.path.normpath(a.folder))
    dst = os.path.join(a.out, "%s.csmod" % name)
    count = 0
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(a.folder):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for f in sorted(files):
                if f.startswith(".") or f.endswith((".uid", ".import")):
                    continue
                p = os.path.join(root, f)
                z.write(p, os.path.relpath(p, a.folder).replace(os.sep, "/"))
                count += 1
    print("built %s (%s v%s, %d files)" % (dst, mod_id, version, count))

    if a.install:
        mods_dir = os.path.join(a.install, "Cleanstrike", "mods")
        os.makedirs(mods_dir, exist_ok=True)
        shutil.copy2(dst, mods_dir)
        print("installed to", mods_dir)


if __name__ == "__main__":
    main()
