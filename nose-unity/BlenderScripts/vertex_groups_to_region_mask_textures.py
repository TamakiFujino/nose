# SPDX-License-Identifier: Unlicense
"""
Blender script: Convert vertex groups to packed RGBA region mask textures.

Generates four PNG textures from the active mesh UVs:
  RegionMaskPack0.png -> regions 1-4 in RGBA
  RegionMaskPack1.png -> regions 5-8 in RGBA
  RegionMaskPack2.png -> regions 9-12 in RGBA
  RegionMaskPack3.png -> regions 13-16 in RGBA (13-14 currently used)

Each vertex is assigned the dominant region from matching vertex groups, then
the script rasterizes the mesh triangles into UV space and writes one-hot style
region membership into packed texture channels. This avoids the intermediate-ID
artifacts of vertex-color interpolation in Unity.
"""

import os
import bpy

REGION_NAME_TO_ID = {
    "chest": 1,
    "belly": 2,
    "shoulder": 3,
    "upper_arm": 4,
    "elbow": 5,
    "lower_arm": 6,
    "hip": 7,
    "upper_upper_leg": 8,
    "upper_lower_leg": 9,
    "knee": 10,
    "lower_upper_leg": 11,
    "lower_lower_leg": 12,
    "ankle": 13,
    "foot": 14,
}

IMAGE_SIZE = 1024
IMAGE_BASENAME = "RegionMaskPack"
DEBUG_IMAGE_BASENAME = "RegionMaskRegion"


def vertex_region_weights(obj, region_map=None):
    mesh = obj.data
    region_map = region_map or REGION_NAME_TO_ID
    name_to_id = {k.lower(): v for k, v in region_map.items()}
    num_groups = len(obj.vertex_groups)
    max_region_id = max(region_map.values())
    weights_by_vertex = [[0.0] * (max_region_id + 1) for _ in range(len(mesh.vertices))]

    for v in mesh.vertices:
        for g in v.groups:
            if g.group >= num_groups:
                continue
            vg = obj.vertex_groups[g.group]
            key = vg.name.lower().strip()
            if key not in name_to_id:
                continue
            region_id = name_to_id[key]
            weights_by_vertex[v.index][region_id] = max(weights_by_vertex[v.index][region_id], g.weight)

    return weights_by_vertex


def edge_fn(ax, ay, bx, by, px, py):
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax)


def rasterize_region_masks(obj, image_size=IMAGE_SIZE):
    if not obj or obj.type != "MESH":
        return False, "Object is not a mesh", None

    # When run from Edit Mode, sync the edit mesh back to object data so
    # loops/UV layers have valid sizes for indexed access.
    if obj.mode == "EDIT":
        obj.update_from_editmode()

    mesh = obj.data
    if len(mesh.vertices) == 0:
        return False, "Mesh has no vertices", None
    if not mesh.uv_layers.active:
        return False, "Mesh has no active UV map", None
    if len(mesh.loops) == 0:
        return False, "Mesh has no loops/faces to rasterize", None

    uv_layer = mesh.uv_layers.active.data
    if len(uv_layer) < len(mesh.loops):
        return False, "Active UV map has no valid UV data. Try switching to Object Mode and unwrap again.", None
    weights_by_vertex = vertex_region_weights(obj)
    max_region_id = max(REGION_NAME_TO_ID.values())

    width = image_size
    height = image_size
    plane_size = width * height * 4
    packs = [[0.0] * plane_size for _ in range(4)]
    region_debug = [[0.0] * plane_size for _ in range(max(REGION_NAME_TO_ID.values()) + 1)]

    def write_pixel(pack_idx, pixel_idx, rgba):
        base = pixel_idx * 4
        packs[pack_idx][base + 0] = max(packs[pack_idx][base + 0], rgba[0])
        packs[pack_idx][base + 1] = max(packs[pack_idx][base + 1], rgba[1])
        packs[pack_idx][base + 2] = max(packs[pack_idx][base + 2], rgba[2])
        packs[pack_idx][base + 3] = max(packs[pack_idx][base + 3], rgba[3])

    def write_region_debug(region_id, pixel_idx, value):
        if region_id <= 0 or region_id >= len(region_debug):
            return
        base = pixel_idx * 4
        region_debug[region_id][base + 0] = max(region_debug[region_id][base + 0], value)
        region_debug[region_id][base + 1] = max(region_debug[region_id][base + 1], value)
        region_debug[region_id][base + 2] = max(region_debug[region_id][base + 2], value)
        region_debug[region_id][base + 3] = 1.0

    for poly in mesh.polygons:
        if len(poly.loop_indices) < 3:
            continue

        loop_indices = list(poly.loop_indices)
        for i in range(1, len(loop_indices) - 1):
            tri_loops = [loop_indices[0], loop_indices[i], loop_indices[i + 1]]
            tri = []
            for loop_index in tri_loops:
                loop = mesh.loops[loop_index]
                uv = uv_layer[loop_index].uv
                x = uv.x * (width - 1)
                y = uv.y * (height - 1)
                tri.append((x, y, weights_by_vertex[loop.vertex_index]))

            (x0, y0, rw0), (x1, y1, rw1), (x2, y2, rw2) = tri
            area = edge_fn(x0, y0, x1, y1, x2, y2)
            if abs(area) < 1e-8:
                continue

            min_x = max(0, int(min(x0, x1, x2)))
            max_x = min(width - 1, int(max(x0, x1, x2)) + 1)
            min_y = max(0, int(min(y0, y1, y2)))
            max_y = min(height - 1, int(max(y0, y1, y2)) + 1)

            for y in range(min_y, max_y + 1):
                py = y + 0.5
                for x in range(min_x, max_x + 1):
                    px = x + 0.5
                    w0 = edge_fn(x1, y1, x2, y2, px, py) / area
                    w1 = edge_fn(x2, y2, x0, y0, px, py) / area
                    w2 = edge_fn(x0, y0, x1, y1, px, py) / area

                    if w0 < -1e-6 or w1 < -1e-6 or w2 < -1e-6:
                        continue

                    pixel_idx = y * width + x
                    dominant_weight = 0.0
                    dominant_region_id = 0
                    for region_id in range(1, max_region_id + 1):
                        interpolated_weight = (
                            w0 * rw0[region_id] +
                            w1 * rw1[region_id] +
                            w2 * rw2[region_id]
                        )
                        if interpolated_weight > dominant_weight:
                            dominant_weight = interpolated_weight
                            dominant_region_id = region_id

                    if dominant_region_id > 0:
                        pack_idx = (dominant_region_id - 1) // 4
                        channel_idx = (dominant_region_id - 1) % 4
                        rgba = [0.0, 0.0, 0.0, 0.0]
                        rgba[channel_idx] = 1.0
                        write_pixel(pack_idx, pixel_idx, rgba)
                        write_region_debug(dominant_region_id, pixel_idx, 1.0)

    output_dir = bpy.path.abspath("//")
    if not output_dir:
        return False, "Blend file must be saved before exporting textures", None

    def fresh_image(image_name):
        existing = bpy.data.images.get(image_name)
        if existing is not None:
            bpy.data.images.remove(existing)
        return bpy.data.images.new(image_name, width=width, height=height, alpha=True, float_buffer=False)

    saved_paths = []
    for pack_idx in range(4):
        image_name = f"{IMAGE_BASENAME}{pack_idx}"
        image = fresh_image(image_name)

        image.filepath_raw = os.path.join(output_dir, f"{image_name}.png")
        image.file_format = "PNG"
        image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(packs[pack_idx])
        image.save()
        saved_paths.append(image.filepath_raw)

    id_to_name = {region_id: name for name, region_id in REGION_NAME_TO_ID.items()}
    for region_id in sorted(id_to_name.keys()):
        image_name = f"{DEBUG_IMAGE_BASENAME}_{region_id:02d}_{id_to_name[region_id]}"
        image = fresh_image(image_name)

        image.filepath_raw = os.path.join(output_dir, f"{image_name}.png")
        image.file_format = "PNG"
        image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(region_debug[region_id])
        image.save()
        saved_paths.append(image.filepath_raw)

    return True, "OK", saved_paths


class MESH_OT_vertex_groups_to_region_mask_textures(bpy.types.Operator):
    bl_idname = "mesh.vertex_groups_to_region_mask_textures"
    bl_label = "Vertex Groups to Region Mask Textures"
    bl_description = "Generate packed RGBA region mask textures from vertex groups"
    bl_options = {"REGISTER", "UNDO"}

    image_size: bpy.props.IntProperty(name="Image Size", default=IMAGE_SIZE, min=128, max=4096)

    @classmethod
    def poll(cls, context):
        obj = context.active_object
        return obj and obj.type == "MESH"

    def execute(self, context):
        ok, msg, saved_paths = rasterize_region_masks(context.active_object, image_size=self.image_size)
        if ok:
            self.report({"INFO"}, "Generated region mask textures:\n" + "\n".join(saved_paths))
            return {"FINISHED"}
        self.report({"ERROR"}, msg)
        return {"CANCELLED"}


def register():
    bpy.utils.register_class(MESH_OT_vertex_groups_to_region_mask_textures)


def unregister():
    bpy.utils.unregister_class(MESH_OT_vertex_groups_to_region_mask_textures)


if __name__ == "__main__":
    register()
    obj = bpy.context.active_object
    if not obj:
        print("Select a mesh object and run again.")
    else:
        ok, msg, saved_paths = rasterize_region_masks(obj)
        if ok:
            print("vertex_groups_to_region_mask_textures: OK")
            for path in saved_paths:
                print(path)
        else:
            print(f"vertex_groups_to_region_mask_textures: {msg}")
