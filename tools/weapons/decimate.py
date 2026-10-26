import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
src, out, target = args[0], args[1], int(args[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
total = sum(len(o.data.polygons) for o in meshes)
for o in meshes:
    n = len(o.data.polygons)
    share = target * n / total
    m = o.modifiers.new("dec", "DECIMATE")
    m.ratio = max(0.01, min(1.0, share / max(1, n)))
    m.use_collapse_triangulate = True
    print("OBJ", o.name, "faces", n, "ratio %.3f" % m.ratio, "dims", tuple(round(d, 3) for d in o.dimensions))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_image_format="NONE", export_animations=False)
print("EXPORTED", out)
