import os
from bmesh.types import BMesh
import bpy
import json
import math
import bmesh
#from bpy.types import Object, Camera
import mathutils

from bpy.props import (
    StringProperty,
    PointerProperty,
    BoolProperty,
    IntProperty,
    FloatProperty,
    EnumProperty,
    FloatVectorProperty
)

TO_GLOBAL = True

class DKT_OT_ExportGltfs(bpy.types.Operator):
    """Export multiple glTFs and metadata"""
    bl_idname = "dktools.export_gltfs"
    bl_label = "Export glTFs"
    # bl_options = {'REGISTER', 'UNDO'}

    # Poll for enables operator
    @classmethod
    def poll(cls, context):
        C = bpy.context
        D = bpy.data

        if (context.area.ui_type == 'VIEW_3D'):
            return True
    
    # Operator execution
    def execute(self, context):
        C = bpy.context
        D = bpy.data

        #models_path = "//../models/world/"
        #definition_path = "//../world_definition.dkworld"
        definition_path = context.scene.dkt_gltfsexportsetup.definition_path
        definition_save_path = bpy.path.abspath(bpy.path.native_pathsep(definition_path))

        with open(definition_save_path) as f:
            definition = json.load(f)
            #print(definition)

        exported_collections = []
        #for collection in C.scene.view_layers[0].layer_collection.children:
        for sector_name in definition:
            sector_def = definition[sector_name]
            for obj in sector_def["items"]:
                collection_name = sector_def["items"][obj]["instance"]
                if collection_name in exported_collections: continue
                if context.scene.view_layers[0].layer_collection.children[collection_name].exclude: continue
                self.export_gltf(D.collections[collection_name])
                exported_collections.append(collection_name)

        self.report({'INFO'}, "Successful glTFs export")
        return{'FINISHED'}
    
    def select_all_collection(self, collection):
        for obj in collection.objects:
            obj.hide_set(False)
            obj.select_set(True)
        for c in collection.children:
            self.select_all_collection(c)

    def export_gltf(self, collection):
        C = bpy.context
        D = bpy.data

        #print("Export: ", collection.name)
        models_path = C.scene.dkt_gltfsexportsetup.export_path_3dmodels
        bpy.ops.object.select_all(action='DESELECT')
        self.select_all_collection(collection)
        gltf_name = "{}.gltf".format(collection.name)
        save_path = bpy.path.abspath(os.path.join(bpy.path.native_pathsep(models_path), gltf_name))
        bpy.ops.export_scene.gltf(
            filepath=save_path,
            export_format="GLB",
            export_copyright="Eibriel",
            # NONE = no mateorials slots
            export_materials="NONE", # PLACEHOLDER
            export_image_format="NONE",
            export_apply=True, # Apply Modifier: prevents shape key export
            use_selection=True,
            export_texcoords=True,
            export_normals=True,
            export_animations=False,
            export_nla_strips=True,
            export_optimize_animation_size=False,
            export_anim_single_armature=False,
            export_extras=True
        )
        return gltf_name


class DKT_OT_SetLod(bpy.types.Operator):
    """Set LOD"""
    bl_idname = "dktools.set_lod"
    bl_label = "Set LOD"
    # bl_options = {'REGISTER', 'UNDO'}

    range_begin: IntProperty(default=0) # type: ignore
    range_end: IntProperty(default=0) # type: ignore

    # Poll for enables operator
    @classmethod
    def poll(cls, context):
        C = bpy.context
        D = bpy.data

        if (context.area.ui_type == 'VIEW_3D'):
            return True
    
    def invoke(self, context, event):
        wm = context.window_manager
        return wm.invoke_props_dialog(self)

    # Operator execution
    def execute(self, context):
        C = bpy.context
        D = bpy.data

        for obj in context.selected_objects:
            obj.dkt_properties.range_begin = self.range_begin
            obj.dkt_properties.range_end = self.range_end

        self.report({'INFO'}, "LOD set")
        return{'FINISHED'}


class DKT_OT_ExportWorld(bpy.types.Operator):
    """Export world definition"""
    bl_idname = "dktools.export_dkworld"
    bl_label = "Export Delta Kayak World"
    # bl_options = {'REGISTER', 'UNDO'}

    # Poll for enables operator
    @classmethod
    def poll(cls, context):
        C = bpy.context
        D = bpy.data

        if (context.area.ui_type == 'VIEW_3D'):
            return True
    
    # Operator execution
    def execute(self, context):
        C = bpy.context
        D = bpy.data

        C.scene.frame_set(0)

        word_scene = D.scenes["Scene"]
        sectors_collection = word_scene.collection.children["Sectors"]

        exported_collections = []
        definition = {}
        for sector in sectors_collection.children:
            sector_def = {}
            sector_def["cameras"] = self.get_cameras(sector)
            sector_def["items"] = self.get_items(sector)
            sector_def["physicsitems"] = self.get_physicsitems(sector)
            sector_def["trees"] = self.get_trees(sector)
            sector_def["triggers"] = self.get_triggers(sector)
            sector_def["current"] = self.get_current(sector)
            sector_def["colliders"] = self.get_colliders(sector)
            sector_def["lands"] = self.get_lands(sector)
            sector_def["navmesh"] = self.get_navmesh(sector)
            sector_def["enemy_points"] = self.get_enemy_points(sector)
            sector_def["rooms"] = self.get_rooms(sector)
            sector_def["lights"] = self.get_lights(sector)
            sector_def["greyboxes"] = self.get_greybox(sector)
            definition[sector.name] = sector_def

        definition_path = context.scene.dkt_gltfsexportsetup.definition_path
        definition_save_path = bpy.path.abspath(bpy.path.native_pathsep(definition_path))
        with open(definition_save_path, 'w') as fp:
            json.dump(definition, fp, sort_keys=True, indent=4)

        self.report({'INFO'}, "Delta Kayak World exported")
        return{'FINISHED'}
    
    def get_trees(self, sector):# -> dict:
        trees_def = {}
        trees_name = "Trees_" + sector.name.split("_")[1]
        if not trees_name in sector.children: return trees_def
        for tree_obj in sector.children[trees_name].objects:
            trees_def[tree_obj.name] = {
                "position": self.location_to_godot(tree_obj.location),
                "rotation": self.rotation_to_godot(tree_obj.rotation_euler),
                "scale": self.scale_to_godot(tree_obj.scale),
                "biome": tree_obj.dkt_worldproperties.tree_types
            }
        return trees_def

    def get_items(self, sector):# -> dict:
        items_def = {}
        items_name = "Items_" + sector.name.split("_")[1]
        if not items_name in sector.children: return items_def
        for item_obj in sector.children[items_name].objects:
            items_def[item_obj.name] = {
                "instance": item_obj.instance_collection.name,
                "position": self.location_to_godot(item_obj.location),
                "rotation": self.rotation_to_godot(item_obj.rotation_euler),
                "scale": self.scale_to_godot(item_obj.scale),
                "transformation": self.transform_to_godot(item_obj.matrix_world),
                "quaternion": self.quaternion_to_godot(item_obj.matrix_world)
            }
        return items_def

    def get_physicsitems(self, sector):# -> dict:
        items_def = {}
        items_name = "PhysicsItems_" + sector.name.split("_")[1]
        if not items_name in sector.children: return items_def
        for item_obj in sector.children[items_name].objects:
            items_def[item_obj.name] = {
                "instance": item_obj.name.split("_")[0],
                "position": self.location_to_godot(item_obj.location),
                "rotation": self.rotation_to_godot(item_obj.rotation_euler),
                "scale": self.scale_to_godot(item_obj.scale),
                "transformation": self.transform_to_godot(item_obj.matrix_world),
                "quaternion": self.quaternion_to_godot(item_obj.matrix_world)
            }
        return items_def

    def get_cameras(self, sector):
        cameras_def = {}
        cameras_name = "Cameras_" + sector.name.split("_")[1]
        if not cameras_name in sector.children: return cameras_def
        first_camera = True
        for camera in sector.children[cameras_name].children:
            camera_obj: bpy.types.Camera = None
            curve_obj: bpy.types.Curve = None
            camera_id: str = camera.name.split("_")[-1]
            for cobj in camera.objects:
                # only one camera expected
                #if type(cobj) == bpy.types.Camera:
                if cobj.name.startswith("camera_"):
                    camera_obj = cobj
                    break
            #
            # only one curve expected
            for cobj in camera.objects:
                if cobj.name.startswith("curve_"):
                    curve_obj = cobj
            # multiple sensors expected
            sensor_list = []
            for sobj in camera.objects:
                if sobj.name.startswith("sensor_"):
                    sensor_list.append(self.get_sensor_data(sobj))
            # multiple sensorpaths expected
            sensorpath_list = []
            for spobj in camera.objects:
                if spobj.name.startswith("sensorpath_"):
                    # TODO cleanup curve data, only needs 2d point positions
                    sensorpath_list.append(self.get_curve_data(spobj))
            # pathpoints
            pathpoints = []
            for c in camera.children:
                if c.name.startswith("pathpoints_"):
                    for point_obj in c.objects:
                        pathpoints.append(self.location_to_godot(point_obj.location))
            #
            camera_def = {
                "camera": self.get_camera_data(camera_obj),
                "curve": self.get_curve_data(curve_obj),
                "sensor": sensor_list,
                "sensorpath": sensorpath_list,
                "pathpoints": pathpoints,
                "default": False
            }
            if first_camera:
                camera_def["default"] = True
                first_camera = False
            cameras_def["camera_"+camera.name] = camera_def
        return cameras_def
    
    def get_triggers(self, sector):
        triggers_def = []
        triggers_name = "Triggers_" + sector.name.split("_")[1]
        if not triggers_name in sector.children: return triggers_def
        for trigger in sector.children[triggers_name].objects:
            if trigger.name.startswith("trigger_"):
                triggers_def.append(self.get_trigger_data(trigger))
            elif trigger.name.startswith("triggerpath_"):
                triggers_def.append(self.get_triggerpath_data(trigger))
        return triggers_def

    def get_current(self, sector):
        triggers_def = []
        triggers_name = "Current_" + sector.name.split("_")[1]
        if not triggers_name in sector.children: return triggers_def
        for trigger in sector.children[triggers_name].objects:
            triggers_def.append(self.get_current_data(trigger))
        return triggers_def

    def get_colliders(self, sector):
        colliders_def = []
        colliders_name = "Colliders_" + sector.name.split("_")[1]
        if not colliders_name in sector.children: return colliders_def
        for collider in sector.children[colliders_name].objects:
            colliders_def.append(self.get_curve_data(collider))
        return colliders_def

    def get_lands(self, sector):
        lands_def = []
        land_name = "Land_" + sector.name.split("_")[1]
        if not land_name in sector.children: return lands_def
        for land in sector.children[land_name].objects:
            data = self.get_curve_data(land)
            data["biome"]= land.dkt_worldproperties.tree_types
            lands_def.append(data)
                
        return lands_def

    def get_navmesh(self, sector):
        navmesh_def = []
        navmesh_name = "NavigationMesh_" + sector.name.split("_")[1]
        if not navmesh_name in sector.children: return navmesh_def
        for navmesh_obj in sector.children[navmesh_name].objects:
            #navmesh_obj = sector.objects[navmesh_name]
            mesh_def = {
                "name": navmesh_obj.name,
                "vertices": [],
                "polygons": [],
                "position": self.location_to_godot(navmesh_obj.location),
                "rotation": self.rotation_to_godot(navmesh_obj.rotation_euler),
            }
            for v in navmesh_obj.data.vertices:
                vertice = self.location_to_godot(v.co)
                mesh_def["vertices"].append(vertice)
            for p in navmesh_obj.data.polygons:
                #if len(polygon.vertices) > 3:
                #    self.report({'ERROR'}, "Make sure the mesh for object \"{}\" uses triangles only".format(navmesh_obj.name))
                #    return {'CANCELLED'}
                polygon = []
                for v in p.vertices:
                    polygon.append(v)
                mesh_def["polygons"].append(polygon)
            navmesh_def.append(mesh_def)
        return navmesh_def

    def get_greybox(self, sector):
        greybox_def = []
        greybox_name = "Greybox_" + sector.name.split("_")[1]
        if not greybox_name in sector.children: return greybox_def
        for greybox_obj in sector.children[greybox_name].objects:
            #navmesh_obj = sector.objects[greybox_name]
            mesh_def = {
                "name": greybox_obj.name,
                "vertices": [],
                "polygons": [],
                "normals": [],
                "uvs": [],
                "position": self.location_to_godot(greybox_obj.location),
                "rotation": self.rotation_to_godot(greybox_obj.rotation_euler),
                "texture": greybox_obj.dkt_properties.override_texture
            }

            bm = bmesh.new()
            dg = bpy.context.evaluated_depsgraph_get()
            greybox_obj_eval = greybox_obj.evaluated_get(dg)
            bm.from_mesh(greybox_obj_eval.data)
            bmesh.ops.triangulate(bm, faces=bm.faces)
            tri_mesh = bpy.data.meshes.new("Mesh")
            bm.to_mesh(tri_mesh)
            bm.free()
            del bm

            for v in tri_mesh.vertices:
                vertice = self.location_to_godot(v.co)
                mesh_def["vertices"].append(vertice)
            for p in tri_mesh.polygons:
                polygon = []
                for v in p.vertices:
                    polygon.append(v)
                mesh_def["polygons"].append(polygon)
            if tri_mesh.normals_domain == "FACE":
                for n in tri_mesh.polygon_normals:
                    mesh_def["normals"].append(self.location_to_godot(n.vector))
            else:
                for n in tri_mesh.vertex_normals:
                    mesh_def["normals"].append(self.location_to_godot(n.vector))
            for uvl in tri_mesh.uv_layers[0].uv:
                mesh_def["uvs"].append([uvl.vector.x, uvl.vector.y])
            greybox_def.append(mesh_def)

        return greybox_def

    def get_enemy_points(self, sector):
        enemy_points_def = {}
        enemy_points_name = "EnemyPoints_" + sector.name.split("_")[1]
        if not enemy_points_name in sector.children: return enemy_points_def
        for enemy_point in sector.children[enemy_points_name].objects:
            enemy_points_def[enemy_point.name] = {
                "position": self.location_to_godot(enemy_point.location),
                "rotation": self.rotation_to_godot(enemy_point.rotation_euler),
                "scale": self.scale_to_godot(enemy_point.scale),
                "transformation": self.transform_to_godot(enemy_point.matrix_world),
                "quaternion": self.quaternion_to_godot(enemy_point.matrix_world)
            }
        return enemy_points_def

    def get_rooms(self, sector):
        rooms_def = []
        rooms_name = "Rooms_" + sector.name.split("_")[1]
        if not rooms_name in sector.children: return rooms_def
        for room in sector.children[rooms_name].objects:
            room_data = self.get_triggerpath_data(room)
            room_data["enemy_points"] = []
            for rc in room.children:
                room_data["enemy_points"].append(rc.name)
            rooms_def.append(room_data)
        return rooms_def

    def get_lights(self, sector):
        lights_def = []
        lights_name = "Lights_" + sector.name.split("_")[1]
        if not lights_name in sector.children: return lights_def
        for light_obj in sector.children[lights_name].objects:
            light_data = {
                "name": light_obj.name,
                "position": self.location_to_godot(light_obj.location),
                "rotation": self.rotation_to_godot(light_obj.rotation_euler),
                "scale": self.scale_to_godot(light_obj.scale),
                "transformation": self.transform_to_godot(light_obj.matrix_world),
                "quaternion": self.quaternion_to_godot(light_obj.matrix_world),
                "type": light_obj.data.type, # POINT, SPOT
                "power": light_obj.data.energy,
                "color": [light_obj.data.color.r,light_obj.data.color.g,light_obj.data.color.b], # RGB
                "omni_radius": light_obj.data.shadow_soft_size,
                "use_shadow": light_obj.data.use_shadow,
                "distance": light_obj.data.cutoff_distance,
            }
            if light_obj.data.type == 'POINT':
                pass
            elif light_obj.data.type == 'SPOT':
                light_data["spot_size"] = light_obj.data.spot_size
            lights_def.append(light_data)
        return lights_def

    def get_camera_data(self, camera_obj):
        #camera_obj.rotation_euler[0] -= math.radians(90.0)
        #bpy.context.view_layer.update()
        camera_def = {
            "position": self.location_to_godot(camera_obj.location),
            "rotation": self.rotation_to_godot(camera_obj.rotation_euler),
            "quaternion": self.quaternion_to_godot(camera_obj.matrix_world),
            "scale": self.scale_to_godot(camera_obj.scale),
            "fov": camera_obj.data.angle,
            "animation": self.get_camera_animation(camera_obj),
            "transition_type": camera_obj.dkt_worldproperties.camera_transition_type,
            "transition_speed": camera_obj.dkt_worldproperties.camera_transition_speed,
            "speed": camera_obj.dkt_worldproperties.camera_speed,
            "point_of_interest": self.vector_to_list(camera_obj.dkt_worldproperties.camera_poi),
            "player_offset": self.vector_to_list(camera_obj.dkt_worldproperties.camera_player_offset),
            "weight": camera_obj.dkt_worldproperties.camera_weight,
            "lock_rotation_x": camera_obj.dkt_worldproperties.camera_lock_rotation_x,
            "lock_rotation_y": camera_obj.dkt_worldproperties.camera_lock_rotation_y,
            "lock_rotation_z": camera_obj.dkt_worldproperties.camera_lock_rotation_z,
            "vertical_compensation": camera_obj.dkt_worldproperties.camera_vertical_compensation,
            "horizontal_compensation": camera_obj.dkt_worldproperties.camera_horizontal_compensation,
            "fog_density": camera_obj.dkt_worldproperties.camera_fog_density,
            #"tree_group": camera_obj.dkt_worldproperties.tree_types,
        }
        #camera_obj.rotation_euler[0] += math.radians(90.0)
        #bpy.context.view_layer.update()
        return camera_def

    def get_camera_animation(self, camera_obj):
        if camera_obj.animation_data == None: return None
        if camera_obj.animation_data.action == None: return None
        if camera_obj.animation_data.action.fcurves == None: return None
        fcurves = camera_obj.animation_data.action.fcurves
        position_track_names = ["x", "z", "y"]
        quaternion_track_names = ["w", "x", "z", "y"]
        tracks = []
        for c in fcurves:
            track = {}
            value_mult = 1.0
            time_mult = 1.0 #1.0/30.0
            if c.data_path == "location":
                track["path"] = "position:" + position_track_names[c.array_index]
                if c.array_index == 1:
                    value_mult = -1
            elif c.data_path == "rotation_quaternion":
                track["path"] = "quaternion:" + quaternion_track_names[c.array_index]
                if c.array_index in [2]:
                    value_mult = -1
            elif c.data_path == "rotation_euler":
                track["path"] = "rotation:" + position_track_names[c.array_index]
                if c.array_index in [1]:
                    value_mult = -1
            else:
                continue
            keys = []
            for p in c.keyframe_points:
                key = [
                    p.co[0] * time_mult, # Time
                    p.co[1] * value_mult, # Value
                    (p.handle_left[0] * time_mult) - (p.co[0] * time_mult),
                    (p.handle_left[1] * value_mult) - (p.co[1] * value_mult),
                    (p.handle_right[0] * time_mult) - (p.co[0] * time_mult),
                    (p.handle_right[1] * value_mult) - (p.co[1] * value_mult)
                ]
                keys.append(key)
            track["keys"] = keys
            tracks.append(track)
        return tracks

    def get_curve_points(self, curve_obj):# -> list:
        points = []
        for p in curve_obj.data.splines[0].bezier_points:
            point_definition = [
                self.location_to_godot(p.co),
                self.location_to_godot(p.handle_left),
                self.location_to_godot(p.handle_right)
            ]
            points.append(point_definition)
        return points

    def get_curve_data(self, curve_obj):
        if curve_obj == None: return None
        curve_def = {
            "position": self.location_to_godot(curve_obj.location),
            "rotation": self.rotation_to_godot(curve_obj.rotation_euler),
            "quaternion": self.quaternion_to_godot(curve_obj.matrix_world),
            "scale": self.scale_to_godot(curve_obj.scale),
            "points": self.get_curve_points(curve_obj)
        }
        return curve_def

    def get_sensor_data(self, sensor_obj):
        sensor_def = {
            "position": self.location_to_godot(sensor_obj.location),
            "rotation": self.rotation_to_godot(sensor_obj.rotation_euler),
            "quaternion": self.quaternion_to_godot(sensor_obj.matrix_world),
            "scale": self.scale_to_godot(sensor_obj.scale)
        }
        return sensor_def
    
    def get_trigger_data(self, trigger_obj):
        trigger_def = {
            "position": self.location_to_godot(trigger_obj.location),
            "rotation": self.rotation_to_godot(trigger_obj.rotation_euler),
            "quaternion": self.quaternion_to_godot(trigger_obj.matrix_world),
            "scale": self.scale_to_godot(trigger_obj.scale),
            "id": trigger_obj.name
        }
        return trigger_def

    def get_triggerpath_data(self, trigger_obj):
        trigger_def = self.get_curve_data(trigger_obj)
        trigger_def["id"] = trigger_obj.name
        return trigger_def

    def get_current_data(self, current_obj):
        current_def = {
            "position": self.location_to_godot(current_obj.location),
            "rotation": self.rotation_to_godot(current_obj.rotation_euler),
            "quaternion": self.quaternion_to_godot(current_obj.matrix_world),
            "scale": self.scale_to_godot(current_obj.scale),
        }
        return current_def

    def location_to_godot(self, location) -> list:
        return [
            location[0],
            location[2],
            -location[1]
        ]

    def scale_to_godot(self, scale) -> list:
        return [
            scale[0],
            scale[2],
            scale[1]
        ]

    def rotation_to_godot(self, rotation) -> list:
        #eul = mathutils.Euler((rotation[0]-math.radians(90), rotation[2], -rotation[1]))
        return [
            rotation[0],
            rotation[2],
            -rotation[1]
        ]

    def transform_to_godot(self, matrix) -> list:
        mat: list = [
            self.matrix_to_list(matrix[0]),
            self.matrix_to_list(matrix[1]),
            self.matrix_to_list(matrix[2]),
            self.matrix_to_list(matrix[3])
        ]
        return mat

    def quaternion_to_godot(self, matrix) -> list:
        quat = matrix.to_quaternion()
        #eul = mathutils.Euler((math.radians(-90), math.radians(0), math.radians(0)))
        #quat.rotate(eul)
        return [
            quat.x,
            quat.z,
            -quat.y,
            quat.w
        ]

    def vector_to_list(self, vector) -> list:
        return [vector.x, vector.y, vector.z]

    def matrix_to_list(self, matrix) -> list:
        return [matrix[0],matrix[1],matrix[2],matrix[3]]


class DKT_PT_Setup(bpy.types.Panel):
    bl_label = "Setup"
    bl_idname = "DKT_PT_setup_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Delta Kayak'
    #bl_parent_id = "OMV_PT_ohmyverse_dcl_tools"
 
    def draw(self,context):
        layout = self.layout
        col = layout.column(align=True)
        #col.label(text="Export:")

        gltfs_export_setup = context.scene.dkt_gltfsexportsetup
        col.prop(gltfs_export_setup, "export_path_3dmodels")
        col.prop(gltfs_export_setup, "definition_path")


class DKT_PT_ExportItems(bpy.types.Panel):
    bl_label = "Export Items"
    bl_idname = "DKT_PT_exportitems_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Delta Kayak'
    #bl_parent_id = "OMV_PT_ohmyverse_dcl_tools"
 
    def draw(self,context):
        layout = self.layout
        col = layout.column(align=True)
        col.label(text="Export:")
        
        #gltfs_export_setup = context.scene.dkt_gltfsexportsetup
        #col.prop(gltfs_export_setup, "export_path_3dmodels")

        col.operator("dktools.export_gltfs", text="Export GLTFs", icon='MESH_MONKEY')
        active_object: Object = context.active_object

        col.label(text="LOD:")
        if active_object is not None:
            col.prop(active_object.dkt_properties, "range_begin")
            col.prop(active_object.dkt_properties, "range_end")
        for obj in context.selected_objects:
            range_begin = obj.dkt_properties.range_begin
            range_end = obj.dkt_properties.range_end
            col.label(text="{}: {} - {}".format(obj.name, range_begin, range_end))
        col.operator("dktools.set_lod", text="Set LOD", icon='MESH_ICOSPHERE')

        col.label(text="Texture:")
        if active_object is not None:
            col.prop(active_object.dkt_properties, "override_texture")
            col.prop(active_object.dkt_properties, "base_color")

        col.label(text="Stencils:")
        # composition_mode opacity normal_masking mask_image diffuse_image emission_image alpha_image
        if active_object:
            col.prop(active_object.dkt_stencil, "is_stencil")
            if active_object.dkt_stencil.is_stencil:
                col.prop(active_object.dkt_stencil, "opacity")
                col.prop(active_object.dkt_stencil, "composition_mode")
                col.prop(active_object.dkt_stencil, "normal_masking")
                col.prop(active_object.dkt_stencil, "stop_coloring")
            else:

                col.operator("dktools.apply_stencils", text="Apply Stencils", icon='IMAGE_RGB_ALPHA')
                col.prop(active_object.dkt_stencil, "keep_texture")


class DKT_PT_ExportWorld(bpy.types.Panel):
    bl_label = "Export World"
    bl_idname = "DKT_PT_exportworld_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Delta Kayak'
    #bl_parent_id = "OMV_PT_ohmyverse_dcl_tools"
 
    def draw(self,context):
        layout = self.layout
        col = layout.column(align=True)
        col.label(text="Export World:")
        col.operator("dktools.export_dkworld", text="Export World", icon='WORLD')
        obj = context.active_object
        if obj is not None and obj.name.startswith("camera_"):
            #col.prop(obj.dkt_worldproperties, "camera_transition_type")
            #col.prop(obj.dkt_worldproperties, "camera_transition_speed")
            col.prop(obj.dkt_worldproperties, "camera_speed")
            col.prop(obj.dkt_worldproperties, "camera_poi")
            #col.prop(obj.dkt_worldproperties, "camera_player_offset")
            col.prop(obj.dkt_worldproperties, "camera_weight")
            #col.prop(obj.dkt_worldproperties, "camera_lock_rotation_x")
            #col.prop(obj.dkt_worldproperties, "camera_lock_rotation_y")
            #col.prop(obj.dkt_worldproperties, "camera_lock_rotation_z")
            col.prop(obj.dkt_worldproperties, "camera_vertical_compensation")
            col.prop(obj.dkt_worldproperties, "camera_horizontal_compensation")
            col.prop(obj.dkt_worldproperties, "camera_fog_density")
        elif obj is not None and obj.name.startswith("TreeGizmo"):
            col.prop(obj.dkt_worldproperties, "tree_types")
        elif obj is not None and obj.name.startswith("land_"):
            col.prop(obj.dkt_worldproperties, "tree_types")
        


## Stencil

class DKT_OT_ApplyStencils(bpy.types.Operator):
    """Apply Stencils to image"""
    bl_idname = "dktools.apply_stencils"
    bl_label = "Apply Stencils to image"
    # bl_options = {'REGISTER', 'UNDO'}

    source_images_cache: dict = {}

    # Poll for enables operator
    @classmethod
    def poll(cls, context):
        C = bpy.context
        D = bpy.data

        if (context.area.ui_type == 'VIEW_3D'):
            return True
    
    # Operator execution
    def execute(self, context):
        C = context
        D = bpy.data

        self.source_images_cache = {}

        target_images = self.get_images_from_obj(C.active_object)

        print("target_images", target_images)

        if target_images["base"] is None:
            self.report({'ERROR'}, "Target image not found")
            return{'CANCELLED'}

        # TODO check if images have alpha
        # TODO check if images are the same size
        
        img_target = D.images[target_images["base"]]

        # we need to know the image dimensions
        width = img_target.size[0]
        height = img_target.size[1]

        paint_pixels = list(img_target.pixels)

        first_obj = True
        for obj in C.selected_objects:
            mesh: bpy.types.Mesh = obj.data # type: ignore
            bm: BMesh = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.triangulate(bm, faces=bm.faces[:]) # type: ignore

            triangles = self.bmesh_to_triangles(obj, bm)
            if True:
                for x in range(0, width):
                    for y in range(0, height):
                        initial_color: list[float]| None = None
                        if not first_obj or C.active_object.dkt_stencil.keep_texture:
                            initial_color = self.get_pixel(img_target, paint_pixels, x, y)
                        else:
                            #mod_color = mathutils.Color(C.active_object.dkt_properties.base_color).from_rec709_linear_to_scene_linear()
                            mod_color = C.active_object.dkt_properties.base_color
                            initial_color = [
                                mod_color.r,
                                mod_color.g,
                                mod_color.b,
                                1.0
                            ]
                        p = self.get_pixel_color(img_target, triangles, x, y, initial_color)
                        self.set_pixel(img_target, paint_pixels, x, y, p[0], p[1], p[2], p[3])
            else:
                x = 73
                y = 113
                initial_color: list[float]| None = None
                print(first_obj, obj.name)
                if not first_obj:
                    initial_color = self.get_pixel(img_target, paint_pixels, x, y)
                    print("initial_color", initial_color)
                p = self.get_pixel_color(img_target, triangles, x, y, initial_color)
                print("pixel value", p)
                self.set_pixel(img_target, paint_pixels, x, y, p[0], p[1], p[2], p[3])

            first_obj = False

        img_target.pixels[:] = paint_pixels
        self.report({'INFO'}, "Stencils applied")
        return{'FINISHED'}
    

    def pixel_coord_to_index(self, img, x, y) -> int:
        width_ = img.size[0]
        return ( y * width_ + x ) * 4

    def get_pixel(self, img, pixels, x, y) -> list[float]:
        index: int = self.pixel_coord_to_index(img, x, y)
        pixel: list[float] = [
            pixels[index], # RED
            pixels[index + 1], # GREEN
            pixels[index + 2], # BLUE
            pixels[index + 3] # ALPHA
        ]
        
        return pixel

    def set_pixel(self, img, pixels, x, y, r, g, b, a) -> None:
        index: int = self.pixel_coord_to_index(img, x, y)
        pixels[index] = r # RED
        pixels[index + 1] = g # GREEN
        pixels[index + 2] = b # BLUE
        pixels[index + 3] = a # ALPHA
        

    def uv_to_pixel(self, img, x, y) -> list[int]:
        width: int = img.size[0]
        height: int = img.size[1]
        pixel: list[int] = [
            int((width-1) * x),
            int((height-1) * y)
        ]
        return pixel

    def pixel_to_uv(self, img, x:float, y:float) -> list[float]:
        width: int = img.size[0] # 0.008431 0.008431
        height:int = img.size[1]
        uv:list[float] = [
            (x+0.5)/width,
            (y+0.5)/height
        ]
        return uv

    def bmesh_to_triangles(self, obj, bm) -> list[list[list[float]]]:
        uv_lay = bm.loops.layers.uv.active
        triangles: list[list[list[float]]] = []
        for face in bm.faces:
            triangle: list[list[float]] = []
            for loop in face.loops:
                uv = loop[uv_lay].uv
                vert = loop.vert
                if TO_GLOBAL:
                    #global_vert_co = self.local_to_global(vert.co, obj)
                    global_vert_co = obj.matrix_world @ vert.co
                    #global_face_normal = self.local_normal_to_global(face.normal, obj)
                    global_face_normal = face.normal.to_4d()
                    global_face_normal.w = 0
                    global_face_normal = (obj.matrix_world @ global_face_normal).to_3d()

                    #print(vert.co, global_vert_co)

                    #global_face_normal = face.normal
                else:
                    global_vert_co = vert.co
                    global_face_normal = face.normal
                #print(TO_GLOBAL)
                #print("face.normal", face.normal)
                #print("global_face_normal", global_face_normal)
                vertex: list[float] = []
                vertex.append(global_vert_co[0])
                vertex.append(global_vert_co[1])
                vertex.append(global_vert_co[2])
                vertex.append(uv[0])
                vertex.append(uv[1])
                vertex.append(global_face_normal[0])
                vertex.append(global_face_normal[1])
                vertex.append(global_face_normal[2])
                
                triangle.append(vertex)
            triangles.append(triangle)
        return triangles


    def get_triangles_in_uv(self, uv, triangles) -> list:
        selected_triangles: list = []
        for t in triangles:
            triangle_uv1 = mathutils.Vector((t[0][3], t[0][4]))
            triangle_uv2 = mathutils.Vector((t[1][3], t[1][4]))
            triangle_uv3 = mathutils.Vector((t[2][3], t[2][4]))
            in_triangle: int = mathutils.geometry.intersect_point_tri_2d(
                uv,
                triangle_uv1,
                triangle_uv2,
                triangle_uv3
            )
            #print("in_triangle", in_triangle)
            #if in_triangle == 1:
            if in_triangle != 0:
                selected_triangles.append(t)
            #if in_triangle == -1:
            #    print("in triangle error", uv, triangle_uv1, triangle_uv2, triangle_uv3)
        return selected_triangles


    def get_triangles_in_3d(self, point, triangles):
        selected_triangles = []
        for t in triangles:
            triangle_vertex1 = mathutils.Vector((t[0][0], t[0][1], t[0][2]))
            triangle_vertex2 = mathutils.Vector((t[1][0], t[1][1], t[1][2]))
            triangle_vertex3 = mathutils.Vector((t[2][0], t[2][1], t[2][2]))
            #print(point, triangle_vertex1, triangle_vertex2, triangle_vertex3)
            in_triangle = mathutils.geometry.intersect_point_tri(
                point,
                triangle_vertex1,
                triangle_vertex2,
                triangle_vertex3
            )
            #print("in triangle", in_triangle)
            if in_triangle != None:
                selected_triangles.append(t)
        return selected_triangles


    def uv_to_3d(self, uv, t) -> tuple[mathutils.Vector, mathutils.Vector]:
        triangle_mesh1 = mathutils.Vector((t[0][0], t[0][1], t[0][2]))
        triangle_mesh2 = mathutils.Vector((t[1][0], t[1][1], t[1][2]))
        triangle_mesh3 = mathutils.Vector((t[2][0], t[2][1], t[2][2]))
        #
        triangle_uv1_3d = mathutils.Vector((t[0][3], 0.0, t[0][4]))
        triangle_uv2_3d = mathutils.Vector((t[1][3], 0.0, t[1][4]))
        triangle_uv3_3d = mathutils.Vector((t[2][3], 0.0, t[2][4]))
        #
        uv_3d = mathutils.Vector((uv[0], 0.0, uv[1]))
        #
        obj_point: mathutils.Vector = mathutils.geometry.barycentric_transform(
            uv_3d,
            triangle_uv1_3d,
            triangle_uv2_3d,
            triangle_uv3_3d,
            triangle_mesh1,
            triangle_mesh2,
            triangle_mesh3
        )
        
        normal = mathutils.Vector((t[0][5], t[0][6], t[0][7]))
        
        return (obj_point, normal)

    def global_to_local(self, point, obj) -> mathutils.Vector:
        """AI Generated function"""
        # Get the world matrix of the object
        world_matrix: mathutils.Matrix = obj.matrix_world
        
        # Invert the world matrix to get the local to world matrix
        local_to_world_matrix: mathutils.Matrix = world_matrix.inverted()
        
        # Convert the point to a Blender mathutils Vector
        point_vector: mathutils.Vector = point #Vector(point)
        
        # Use the local to world matrix to transform the point to local coordinates
        local_point_vector: mathutils.Vector = local_to_world_matrix @ point_vector
        
        # Return the point in local coordinates
        return local_point_vector

    def local_to_global(self, point: mathutils.Vector, obj) -> mathutils.Vector:
        """AI Generated function"""
        # Get the world matrix of the object
        world_matrix: mathutils.Matrix = obj.matrix_world
        
        # Convert the point to a Blender mathutils Vector
        point_vector: mathutils.Vector = point #mathutils.Vector(point)
        
        # Use the world matrix to transform the point to global coordinates
        global_point_vector: mathutils.Vector = world_matrix @ point_vector
        
        # Return the point in global coordinates
        return global_point_vector

    def local_normal_to_global(self, normal: mathutils.Vector, obj) -> mathutils.Vector:
        """AI Generated function"""
        # Get the world matrix of the object
        world_matrix: mathutils.Matrix = obj.matrix_world
        
        # Convert the normal to a Blender mathutils Vector
        normal_vector: mathutils.Vector = normal #Vector(normal)
        
        # Use the world matrix to transform the normal to global coordinates
        global_normal_vector: mathutils.Vector = (world_matrix.to_3x3() @ normal_vector).normalized()
        
        # Return the normal vector in global coordinates
        return global_normal_vector


    def point_3d_to_uv(self, obj, hit_point, face) -> mathutils.Vector | None:
        mesh_hit = obj.data
        bm_hit: BMesh = bmesh.new()
        bm_hit.from_mesh(mesh_hit)
        faces_to_delete = []
        face_id = 0
        for f in bm_hit.faces[:]: # type: ignore
            if face_id != face:
                faces_to_delete.append(f)
        #bmesh.ops.delete(bm_hit, geom=faces_to_delete, context='FACES')
        bmesh.ops.triangulate(bm_hit, faces=bm_hit.faces[:]) # type: ignore
        triangles = self.bmesh_to_triangles(obj, bm_hit)
        
        if TO_GLOBAL:
            #print("hit_point", hit_point)
            local_hit_point = hit_point
        else:
            local_hit_point = self.global_to_local(hit_point, obj)
        
        sel_triangles3d = self.get_triangles_in_3d(local_hit_point, triangles)
        #print("Selected triangles 3D", len(sel_triangles3d))
        #
        for t in sel_triangles3d:
            triangle_mesh1 = mathutils.Vector((t[0][0], t[0][1], t[0][2]))
            triangle_mesh2 = mathutils.Vector((t[1][0], t[1][1], t[1][2]))
            triangle_mesh3 = mathutils.Vector((t[2][0], t[2][1], t[2][2]))
            #
            triangle_uv1_3d = mathutils.Vector((t[0][3], 0.0, t[0][4]))
            triangle_uv2_3d = mathutils.Vector((t[1][3], 0.0, t[1][4]))
            triangle_uv3_3d = mathutils.Vector((t[2][3], 0.0, t[2][4]))
            #
            #uv_3d = mathutils.Vector((uv[0], 0.0, uv[1]))
            #
            uv_point:mathutils.Vector = mathutils.geometry.barycentric_transform(
                local_hit_point,
                triangle_mesh1,
                triangle_mesh2,
                triangle_mesh3,
                triangle_uv1_3d,
                triangle_uv2_3d,
                triangle_uv3_3d
            )
            return mathutils.Vector((uv_point.x, uv_point.z))
        return None


    def test_ray(self, point:mathutils.Vector, normal:mathutils.Vector, collected=[], depth=0)->list:
        C = bpy.context
        D = bpy.data
        #print(depth)
        if depth > 30:
            print("Max Depth")
            return collected
        bias:float = 0.001
        shift: mathutils.Vector = normal * bias
        ray: tuple[bool, mathutils.Vector|None, mathutils.Vector|None, int|None, bpy.types.Object|None, mathutils.Matrix|None] = C.scene.ray_cast(
            bpy.context.view_layer.depsgraph,
            point+shift,
            normal,
            distance=60
        ) # type: ignore
        
        #D.objects["Empty"].location= point
        #D.objects["Empty.001"].location= point + normal

        result, location, normal_b, index, object, matrix = ray
        if not result:
            #print("No hit")
            del ray
            return collected
        #print("Hit")
        if object.dkt_stencil.is_stencil:
            if len(collected) == 0 or collected[-1][1]!=object:
                collected.append([location, object, index, normal_b])
                #print("Collected")
            else:
                #print("Skip")
                pass
            if object.dkt_stencil.stop_coloring:
                del ray
                return collected
        # Continue ray from new point in original direction
        self.test_ray(location+shift, normal, collected, depth+1) # type: ignore
        del ray
        return collected

    def get_image_data(self, image_name):
        D = bpy.data

        if not (image_name in self.source_images_cache.keys()):
            img_source: bpy.types.Image = D.images[image_name]
            previous_colorspace = img_source.colorspace_settings.name
            img_source.colorspace_settings.name = "Non-Color"
            source_pixels: list[float] = list(img_source.pixels) # type: ignore
            img_source.colorspace_settings.name = previous_colorspace
            self.source_images_cache[image_name] = (img_source, source_pixels)
        
        return self.source_images_cache[image_name]


    # def get_source_from_obj(self, obj_hit)-> tuple[bpy.types.Image, list[float]]:
    #     D = bpy.data

    #     self.get_images_from_obj(obj_hit)

    #     if not (obj_hit.name in self.source_images_cache.keys()):

    #         img_source: bpy.types.Image = D.images[image_name]
            
    #         source_pixels: list[float] = list(img_source.pixels) # type: ignore
            
    #         self.source_images_cache[obj_hit.name] = (img_source, source_pixels)
        
    #     return self.source_images_cache[obj_hit.name]


    def get_images(self, output, images) -> None:
        surface = output.inputs["Surface"]
        if not surface.is_linked: return
        principled = surface.links[0].from_node
        if principled.type != "BSDF_PRINCIPLED": return
        base_color = principled.inputs["Base Color"]
        emission_color = principled.inputs["Emission Color"]
        if base_color.is_linked:
            image_base = base_color.links[0].from_node
            if image_base.type == "TEX_IMAGE":
                if not(image_base.image is None):
                    images["base"] = image_base.image.name
        if emission_color.is_linked:
            image_emission = emission_color.links[0].from_node
            if image_emission.type == "TEX_IMAGE":
                if not(image_emission.image is None):
                    images["emission"] = image_emission.image.name
        

    def get_images_from_obj(self, obj) -> dict[str, str | None]:
        mat = obj.material_slots[0].material
        imgs: dict[str, str | None] = {
            "base": None,
            "emission": None
        }
        if mat is None: return imgs
        nodes = mat.node_tree.nodes
        for n in nodes:
            if n.type == "OUTPUT_MATERIAL":
                self.get_images(n, imgs)
                break
        return imgs

    def color_mix(self, color_bg:list[float], color_fg:list[float]) -> list[float]:
        
        mcolor_bg = mathutils.Color((color_bg[0], color_bg[1], color_bg[2]))
        mcolor_fg = mathutils.Color((color_fg[0], color_fg[1], color_fg[2]))
        alpha_bg: float = color_bg[3]
        alpha_fg: float = color_fg[3]
        
        #colour_bg_a = colour_bg * alpha_bg
        mcolor_bg *= alpha_bg
        mcolor_fg *= alpha_fg
        
        #alpha_final = alpha_bg + alpha_fg - alpha_bg * alpha_fg
        alpha_final: float = alpha_bg + alpha_fg - (alpha_bg * alpha_fg)
        
        # colour_final_a = colour_fg_a + colour_bg_a * (1 - alpha_fg)
        mresult: mathutils.Color = mcolor_fg + (mcolor_bg * (1.0 - alpha_fg))
        
        #colour_final = colour_final_a / alpha_final
        if alpha_final > 0:
            mresult /= alpha_final
        
        result: list[float] = [
            mresult.r,
            mresult.g,
            mresult.b,
            alpha_final
        ]
        
        return result

    def add_colors(self, color_a:list[float], color_b:list[float]) -> list[float]:
        color_c:list[float] = []
        for id in range(len(color_a)):
            color_c.append(color_a[id] + color_b[id])
        if color_c[3] > 1.0:
            color_c[3] = 1.0
        return color_c

    def mult_color(self, color, value):
        color_c = []
        for id in range(len(color)):
            color_c.append(color[id] * value)
        return color_c

    def get_pixel_color(self, img_target:bpy.types.Image, triangles, x:int, y:int, initial_color: list[float]|None) -> list[float]:
        uv: list[int] = self.pixel_to_uv(img_target, x, y)
        #print(uv)
        sel_triangles = self.get_triangles_in_uv(uv, triangles)
        p: list[float] = [0.0, 0.0, 0.0, 0.0]
        if not (initial_color is None):
            p = initial_color
        #print("Triangles in UV:", len(sel_triangles))
        for t in sel_triangles:
            #p = [1.0, 0.0, 0.0, 1.0]
            obj_point, normal = self.uv_to_3d(uv, t)
            
            if False:
                p = [
                    obj_point.x,
                    obj_point.y,
                    obj_point.z,
                    1.0
                ]
            r = self.test_ray(obj_point, normal, [], 0)
            #print("Hits:", len(r))
            for hit in r:
                obj_hit = hit[1]
                point_hit = hit[0]
                face_hit = hit[2]
                normal_b = hit[3]

                #print(point_hit)

                dotp = mathutils.Vector(normal).dot( mathutils.Vector(normal_b) )
                dotp = max(0.0, dotp)
                #p = [0.0, dotp, 0.0, 1.0]
                #continue
                
                #p = [0.0, 1.0, 0.0, 1.0]
                uv_source = self.point_3d_to_uv(obj_hit, point_hit, face_hit)
                if uv_source is None:
                    print("Missing UV Source")
                    continue
                
                images_source = self.get_images_from_obj(obj_hit)

                if images_source["base"] is None:
                    print("Missing Base image")
                    continue

                img_source, source_pixels = self.get_image_data(images_source["base"])
                
                pixel = self.uv_to_pixel(img_source, uv_source[0], uv_source[1])
                offsets = [
                    [0, 0],
                    #[1, 0],
                    #[0, 1],
                    #[1, 1],
                    #[0, -1],
                    #[-1, 0],
                    #[-1, -1]
                ]
                #this_p = p
                sample = [0.0, 0.0, 0.0, 0.0]
                for offset in offsets:
                    value = self.get_pixel(img_source, source_pixels, pixel[0]+offset[0], pixel[1]+offset[1])

                    value[3] *= obj_hit.dkt_stencil.opacity
                    sample = self.add_colors(sample, value)
                #print("this_p", this_p, "p", p)
                layer_count:int = len(offsets)
                #print(layer_count)
                #if not(initial_color is None):
                #    layer_count += 1
                sample = self.mult_color(sample, 1.0/layer_count)
                p = self.color_mix(p, sample)
                
            break
        return p

##


class DKT_PG_GltfsExportSetup(bpy.types.PropertyGroup):

    export_path_3dmodels: StringProperty(
        name="glTFs path",
        subtype='DIR_PATH'
    ) # type: ignore

    definition_path: StringProperty(
        name="DKWorld definition path",
        subtype='FILE_PATH'
    ) # type: ignore

    item_data_path: StringProperty(
        name="Items data path",
        subtype='FILE_PATH'
    ) # type: ignore

class DKT_PG_ObjectProperties(bpy.types.PropertyGroup):

    range_begin: IntProperty(
        name="Range Begin",
        default=0,
        min=0,
        max=5000
    ) # type: ignore

    range_end: IntProperty(
        name="Range End",
        default=0,
        min=0,
        max=5000
    ) # type: ignore

    override_texture: StringProperty(
        name="Override Texture",
        description="Item to get texture from",
        default=""
    ) # type: ignore

    base_color: FloatVectorProperty(name="Base Color", 
        subtype='COLOR',
        default=[0.0,0.0,0.0]
    ) # type: ignore

class DKT_PG_WorldObjectProperties(bpy.types.PropertyGroup):

    ## All

    attach_to: StringProperty(
        name="Attach to",
        description="Attach this element to another element",
        default=""
    ) # type: ignore

    ## Sound source

    sound_type: EnumProperty(
        name="Sound Type",
        description="Sound Type",
        items=[
            ("simple", "Simple", "Plays one time", "", 0),
            ("loop", "Loop", "Plays on continuous loop", "", 1),
            ("random", "Random", "Plays at random times", "", 2),
        ], # type: ignore
        default="random"
    ) # type: ignore

    sound_source: StringProperty(
        name="Sound source",
        description="Sound source",
        default=""
    ) # type: ignore

    ## Trigger

    trigger_primary_action: StringProperty(
        name="Primary Action",
        description="Trigger Primary Action",
        default=""
    ) # type: ignore

    trigger_secondary_action: StringProperty(
        name="Secondary Action",
        description="Trigger Secondary Action",
        default=""
    ) # type: ignore

    trigger_always_visible: BoolProperty(
        name="Always Visible",
        default=False
    ) # type: ignore

    trigger_type: EnumProperty(
        name="Trigger Type",
        description="What triggers the trigger?",
        items=[
            ("proximity", "Proximity", "Fires on proximity", "", 0),
            ("button", "Button", "Fires on button pressed", "", 1),
        ], # type: ignore
        default="button"
    ) # type: ignore

    trigger_angle: IntProperty(
        name="Trigger Angle",
        description="Direction the player must be facing, relative to Trigger front",
        default=360,
        min=0,
        max=360
    ) # type: ignore

    ## Camera

    camera_transition_type: EnumProperty(
        name="Transition Type",
        description="How the transition to this camera must be?",
        items=[
            ("cut", "Cut", "Hard jump", "", 0),
            ("smooth", "Smooth", "Smooth transition", "", 1),
        ], # type: ignore
        default="smooth"
    ) # type: ignore

    camera_transition_speed: FloatProperty(
        name="Transition Speed",
        description="Camera smooth transition speed",
        default=5.,
        min=0.,
        max=10.
    ) # type: ignore

    camera_speed: FloatProperty(
        name="Speed",
        description="Camera speed",
        default=5.,
        min=0.,
        max=10.
    ) # type: ignore

    camera_poi: FloatVectorProperty(
        name="Point of Interest",
        description="Point relative to player the camera looks at",
        default=mathutils.Vector((0,0,0)),
        subtype="TRANSLATION"
    ) # type: ignore

    camera_player_offset: FloatVectorProperty(
        name="Player Offset",
        description="Offsets player position for camera position calculation",
        default=mathutils.Vector((0,0,0)),
        subtype="TRANSLATION"
    ) # type: ignore

    camera_weight: IntProperty(
        name="Camera Weight",
        description="Helps prioritize cameras",
        default=0,
        min=0,
        max=360
    ) # type: ignore

    camera_lock_rotation_x: BoolProperty(
        name="Lock camera rotation X",
        default=False
    ) # type: ignore

    camera_lock_rotation_y: BoolProperty(
        name="Lock camera rotation Y",
        default=False
    ) # type: ignore

    camera_lock_rotation_z: BoolProperty(
        name="Lock camera rotation Z",
        default=False
    ) # type: ignore

    camera_vertical_compensation: EnumProperty(
        name="Vertical compensation",
        description="Move the camera in the vertical axis to keep the subject centered",
        items=[
            ("none", "None", "No compensation", "", 0),
            ("rotation", "Rotation", "Rotate camera to keep subject centered", "", 1),
            ("translation", "Translation", "Translate camera to keep subject centered", "", 2),
        ], # type: ignore
        default="none"
    ) # type: ignore

    camera_horizontal_compensation: EnumProperty(
        name="Horizontal compensation",
        description="Move the camera in the horizontal axis to keep the subject centered",
        items=[
            ("none", "None", "No compensation", "", 0),
            ("rotation", "Rotation", "Rotate camera to keep subject centered", "", 1),
            ("translation", "Translation", "Translate camera to keep subject centered", "", 2),
        ], # type: ignore
        default="none"
    ) # type: ignore

    camera_fog_density: FloatProperty(
        name="Fog Density",
        description="Fog Density",
        default=0.015,
        min=0.,
        max=1.,
        step=0.001,
        precision=4
    ) # type: ignore

    tree_types: StringProperty(
        name="Tree Types",
        description="Coma separated tree types to use",
        default=""
    ) # type: ignore

class DKT_PG_StencilProperties(bpy.types.PropertyGroup):

    is_stencil: BoolProperty(
        name="Is Stencil",
        default=False
    ) # type: ignore

    stop_coloring: BoolProperty(
        name="Stop Coloring",
        default=False
    ) # type: ignore

    composition_mode: EnumProperty(
        name="Composition Mode",
        description="Composition Mode",
        items=[
            ("normal", "Normal", "Normal composition", "BRUSHES_ALL", 0),
            ("add", "Add", "Add composition", "PLUS", 1),
            ("multiply", "Multiply", "Multiply composition", "SORTBYEXT", 2),
            ("overlay", "Overlay", "Overlay composition", "PIVOT_INDIVIDUAL", 3),
            ("mask", "Mask", "Masks next layer", "PIVOT_INDIVIDUAL", 4),
        ], # type: ignore
        default="normal"
    ) # type: ignore

    opacity: FloatProperty(
        name="Opacity",
        description="How much influence the stencil has",
        default=1.0,
        min=0.0,
        max=1.0
    ) # type: ignore

    normal_masking: FloatProperty(
        name="Normal Masking",
        description="How the direction of the stencil affects the opacity",
        default=1.0,
        min=0.0,
        max=1.0
    ) # type: ignore

    # Move out of stencils
    keep_texture: BoolProperty(
        name="Keep Texture",
        default=False
    ) # type: ignore


####################################
# REGISTER/UNREGISTER
####################################
def register():
    bpy.utils.register_class(DKT_OT_ExportGltfs)
    bpy.utils.register_class(DKT_OT_SetLod)
    bpy.utils.register_class(DKT_OT_ExportWorld)
    bpy.utils.register_class(DKT_OT_ApplyStencils)
    bpy.utils.register_class(DKT_PT_Setup)
    bpy.utils.register_class(DKT_PT_ExportItems)
    bpy.utils.register_class(DKT_PT_ExportWorld)
    bpy.utils.register_class(DKT_PG_GltfsExportSetup)
    bpy.utils.register_class(DKT_PG_ObjectProperties)
    bpy.utils.register_class(DKT_PG_WorldObjectProperties)
    bpy.utils.register_class(DKT_PG_StencilProperties)

    bpy.types.Scene.dkt_gltfsexportsetup = PointerProperty(type=DKT_PG_GltfsExportSetup) # type: ignore
    bpy.types.Object.dkt_properties = PointerProperty(type=DKT_PG_ObjectProperties) # type: ignore
    bpy.types.Object.dkt_worldproperties = PointerProperty(type=DKT_PG_WorldObjectProperties) # type: ignore
    bpy.types.Object.dkt_stencil = PointerProperty(type=DKT_PG_StencilProperties) # type: ignore

def unregister():
    bpy.utils.unregister_class(DKT_OT_ExportGltfs)
    bpy.utils.unregister_class(DKT_OT_SetLod)
    bpy.utils.unregister_class(DKT_OT_ExportWorld)
    bpy.utils.unregister_class(DKT_OT_ApplyStencils)
    bpy.utils.unregister_class(DKT_PT_Setup)
    bpy.utils.unregister_class(DKT_PT_ExportItems)
    bpy.utils.unregister_class(DKT_PT_ExportWorld)
    bpy.utils.unregister_class(DKT_PG_GltfsExportSetup)
    bpy.utils.unregister_class(DKT_PG_ObjectProperties)
    bpy.utils.unregister_class(DKT_PG_WorldObjectProperties)
    bpy.utils.unregister_class(DKT_PG_StencilProperties)

    del bpy.types.Scene.dkt_gltfsexportsetup # type: ignore
    del bpy.types.Object.dkt_properties # type: ignore
    del bpy.types.Object.dkt_worldproperties # type: ignore
    del bpy.types.Object.dkt_stencil # type: ignore