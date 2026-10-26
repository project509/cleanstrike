import zipfile, os, sys
src = r"C:\Users\greyp\OneDrive\Desktop\Cleanstrike Mod Loader\ideaboard\zombies"
dst = r"C:\RTVDev\RTVProject\cs_assets\zombies"
for z, d in [("Not So Scary Zombie Pack.zip", "mixamo_a"), ("Scary Zombie Pack.zip", "mixamo_b")]:
    zz = zipfile.ZipFile(os.path.join(src, z))
    for i in zz.infolist():
        if i.filename == "Erika Archer.fbx" and d == "mixamo_b":
            continue
        out = os.path.join(dst, d, i.filename.replace(" ", "_").replace("(", "").replace(")", ""))
        with open(out, "wb") as f:
            f.write(zz.read(i))
print("ok")
