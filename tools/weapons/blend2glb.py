import bpy, sys
out = sys.argv[sys.argv.index("--") + 1]
for o in bpy.data.objects:
    if o.type == "MESH":
        d = o.dimensions
        print("OBJ %-40s verts %6d  dims %.3f %.3f %.3f  parent %s" % (o.name, len(o.data.vertices), d.x, d.y, d.z, o.parent.name if o.parent else "-"))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_image_format="NONE", export_animations=False)
print("EXPORTED", out)
