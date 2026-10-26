import glob, os, re
base = r"C:\RTVDev\RTVProject\cs_assets\zombies"
def sub(mapname):
    return ('_subresources={\n"nodes": {\n"PATH:Skeleton3D": {\n'
        f'"retarget/bone_map": Resource("res://cs_assets/zombies/maps/{mapname}.tres"),\n'
        '"retarget/bone_renamer/rename_bones": true,\n'
        '"retarget/bone_renamer/unique_node/make_unique": true,\n'
        '"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",\n'
        '"retarget/rest_fixer/apply_node_transforms": true,\n'
        '"retarget/rest_fixer/normalize_position_tracks": true,\n'
        '"retarget/rest_fixer/overwrite_axis": true\n'
        '}\n}\n}')
n = 0
for f in glob.glob(base + r"\**\*.import", recursive=True):
    if not re.search(r"\.fbx\.import$", f, re.I):
        continue
    mp = "biped" if os.sep + "model" + os.sep in f else "mixamo"
    s = open(f, encoding="utf-8").read()
    s = re.sub(r"_subresources=\{.*", sub(mp), s, flags=re.S)
    open(f, "w", encoding="utf-8", newline="\n").write(s + "\n")
    n += 1
print("updated", n)
