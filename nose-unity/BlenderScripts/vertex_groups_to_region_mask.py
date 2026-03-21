# SPDX-License-Identifier: Unlicense
"""
Blender script: Convert vertex groups to Region Mask (Color Attribute).

Maps Blender vertex group names to region IDs used by the Unity shader
(Nose/Body Region Mask). Creates or updates a face-corner Color Attribute so
that the Red channel = region_id / 255. Must match AssetManager.regionDefs in
nose-unity/Assets/Scripts/AssetManager.cs.

Usage:
  1. Select the body mesh object in Blender.
  2. Scripting workspace → Open this file → Run Script.
  Or: register the add-on and use the operator from the mesh context menu.
"""

import bpy

# Region name → ID. Must match AssetManager.regionDefs (Unity).
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

COLOR_ATTR_NAME = "RegionMask"


def vertex_groups_to_region_mask(obj, attr_name=COLOR_ATTR_NAME, region_map=None):
    """
    For the given mesh object, set a face-corner Color Attribute from vertex groups.
    Vertex group names are matched to region IDs (case-insensitive). If a vertex
    is in multiple matching groups, the one with the highest weight is used.
    Vertices in no matching group get region ID 0 (never hidden).
    """
    if not obj or obj.type != "MESH":
        return "Object is not a mesh"
    mesh = obj.data
    if region_map is None:
        region_map = REGION_NAME_TO_ID

    if len(mesh.vertices) == 0:
        return "Mesh has no vertices"

    num_verts = len(mesh.vertices)
    num_loops = len(mesh.loops)
    num_groups = len(obj.vertex_groups)

    # Create or get face-corner byte color attribute; this exports more reliably to Unity/FBX.
    if attr_name in mesh.color_attributes:
        layer = mesh.color_attributes[attr_name]
        if layer.domain != "CORNER":
            mesh.color_attributes.remove(layer)
            layer = mesh.color_attributes.new(attr_name, "BYTE_COLOR", "CORNER")
        elif len(layer.data) < num_loops:
            mesh.color_attributes.remove(layer)
            layer = mesh.color_attributes.new(attr_name, "BYTE_COLOR", "CORNER")
    else:
        layer = mesh.color_attributes.new(attr_name, "BYTE_COLOR", "CORNER")

    if len(layer.data) < num_loops:
        return "Color attribute has wrong size; try deleting it and run again"

    # Normalize names for matching (Unity uses OrdinalIgnoreCase)
    name_to_id = {k.lower(): v for k, v in region_map.items()}

    vertex_region_ids = [0] * num_verts
    for v in mesh.vertices:
        best_id = 0
        best_weight = 0.0
        for g in v.groups:
            if g.group >= num_groups:
                continue
            vg = obj.vertex_groups[g.group]
            key = vg.name.lower().strip()
            if key not in name_to_id:
                continue
            if g.weight > best_weight:
                best_weight = g.weight
                best_id = name_to_id[key]
        vertex_region_ids[v.index] = best_id

    for loop in mesh.loops:
        region_id = vertex_region_ids[loop.vertex_index]
        r = region_id / 255.0
        # BYTE_COLOR is stored/exported in sRGB space. Write via color_srgb so
        # Unity receives the exact byte value we intend (1 -> 1, 2 -> 2, etc.)
        layer.data[loop.index].color_srgb = (r, 0.0, 0.0, 1.0)

    return "OK"


class MESH_OT_vertex_groups_to_region_mask(bpy.types.Operator):
    bl_idname = "mesh.vertex_groups_to_region_mask"
    bl_label = "Vertex Groups to Region Mask"
    bl_description = "Convert vertex groups to Region Mask Color Attribute (Unity Nose/Body)"
    bl_options = {"REGISTER", "UNDO"}

    attr_name: bpy.props.StringProperty(name="Color Attribute", default=COLOR_ATTR_NAME)

    @classmethod
    def poll(cls, context):
        obj = context.active_object
        return obj and obj.type == "MESH"

    def execute(self, context):
        msg = vertex_groups_to_region_mask(context.active_object, attr_name=self.attr_name)
        if msg == "OK":
            self.report({"INFO"}, "Region mask Color Attribute updated from vertex groups.")
        else:
            self.report({"ERROR"}, msg)
        return {"FINISHED" if msg == "OK" else "CANCELLED"}


def register():
    bpy.utils.register_class(MESH_OT_vertex_groups_to_region_mask)


def unregister():
    bpy.utils.unregister_class(MESH_OT_vertex_groups_to_region_mask)


if __name__ == "__main__":
    register()
    obj = bpy.context.active_object
    if not obj:
        print("Select a mesh object and run again.")
    else:
        msg = vertex_groups_to_region_mask(obj)
        print(f"vertex_groups_to_region_mask: {msg}")
    # After running once, you can also use: F3 → "Vertex Groups to Region Mask"
