import os
import bpy
import json

from bpy.props import (
    StringProperty,
    PointerProperty,
    BoolProperty,
    IntProperty
)

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
            print(definition)

        exported_collections = []
        for sector_name in definition:
            sector_def = definition[sector_name]
            for obj in sector_def["items"]:
                collection_name = sector_def["items"][obj]["instance"]
                if collection_name in exported_collections: continue
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

    range_begin: IntProperty(default=0)
    range_end: IntProperty(default=0)

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

        word_scene = D.scenes["Scene"]
        sectors_collection = word_scene.collection.children["Sectors"]

        exported_collections = []
        definition = {}
        for sector in sectors_collection.children:
            sector_def = {}
            sector_def["cameras"] = self.get_cameras(sector)
            sector_def["items"] = self.get_items(sector)
            sector_def["trees"] = self.get_trees(sector)
            definition[sector.name] = sector_def

        definition_path = context.scene.dkt_gltfsexportsetup.definition_path
        definition_save_path = bpy.path.abspath(bpy.path.native_pathsep(definition_path))
        with open(definition_save_path, 'w') as fp:
            json.dump(definition, fp, sort_keys=True, indent=4)

        self.report({'INFO'}, "Delta Kayak World exported")
        return{'FINISHED'}
    
    def get_trees(self, sector):
        trees_def = {}
        trees_name = "Trees_" + sector.name.split("_")[1]
        if not trees_name in sector.children: return trees_def
        for tree_obj in sector.children[trees_name].objects:
            trees_def[tree_obj.name] = {
                "position": self.location_to_godot(tree_obj.location),
                "rotation": self.rotation_to_godot(tree_obj.rotation_euler),
                "scale": self.scale_to_godot(tree_obj.scale)
            }
        return trees_def

    def get_items(self, sector):
        items_def = {}
        items_name = "Items_" + sector.name.split("_")[1]
        if not items_name in sector.children: return items_def
        for item_obj in sector.children[items_name].objects:
            items_def[item_obj.name] = {
                "instance": item_obj.instance_collection.name,
                "position": self.location_to_godot(item_obj.location),
                "rotation": self.rotation_to_godot(item_obj.rotation_euler),
                "scale": self.scale_to_godot(item_obj.scale)
            }
        return items_def

    def get_cameras(self, sector):
        cameras_def = {}
        cameras_name = "Cameras_" + sector.name.split("_")[1]
        if not cameras_name in sector.children: return cameras_def
        for camera in sector.children[cameras_name].children:
            # only one camera expected
            camera_id = camera.name.split("_")[1]
            camera_obj = camera.objects["camera_"+camera_id]
            #
            # only one curve expected
            curve_obj = camera.objects["curve_"+camera_id]
            # multiple sensors expected
            sensor_obj = camera.objects["sensor_"+camera_id]
            #
            camera_def = {
                "camera": self.get_camera_data(camera_obj),
                "curve": self.get_curve_data(curve_obj),
                "sensor": self.get_sensor_data(sensor_obj),
                "default": False
            }
            if camera_id == "001":
                camera_def["default"] = True
            cameras_def["camera_"+camera_id] = camera_def
        return cameras_def
    
    def get_camera_data(self, camera_obj):
        camera_def = {
            "position": self.location_to_godot(camera_obj.location),
            "rotation": self.rotation_to_godot(camera_obj.rotation_euler),
            "scale": self.scale_to_godot(camera_obj.scale),
            "fov": camera_obj.data.angle
        }
        return camera_def


    def get_curve_points(self, curve_obj):
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
        curve_def = {
            "position": self.location_to_godot(curve_obj.location),
            "rotation": self.rotation_to_godot(curve_obj.rotation_euler),
            "scale": self.scale_to_godot(curve_obj.scale),
            "points": self.get_curve_points(curve_obj)
        }
        return curve_def


    def get_sensor_data(self, sensor_obj):
        sensor_def = {
            "position": self.location_to_godot(sensor_obj.location),
            "rotation": self.rotation_to_godot(sensor_obj.rotation_euler),
            "scale": self.scale_to_godot(sensor_obj.scale)
        }
        return sensor_def
    
    def location_to_godot(self, location):
        return [
            location[0],
            location[2],
            -location[1]
        ]

    def scale_to_godot(self, scale):
        return [
            scale[0],
            scale[2],
            scale[1]
        ]

    def rotation_to_godot(self, rotation):
        return [
            rotation[0],
            rotation[2],
            -rotation[1]
        ]


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

        col.operator("dktools.export_gltfs", text="Export GLTFs", icon='GROUP_VERTEX')

        col.label(text="LOD:")
        for obj in context.selected_objects:
            range_begin = obj.dkt_properties.range_begin
            range_end = obj.dkt_properties.range_end
            col.label(text="{}: {} - {}".format(obj.name, range_begin, range_end))
        col.operator("dktools.set_lod", text="Set LOD", icon='GROUP_VERTEX')

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
        col.operator("dktools.export_dkworld", text="Export World", icon='GROUP_VERTEX')
        


class DKT_PG_GltfsExportSetup(bpy.types.PropertyGroup):

    export_path_3dmodels: StringProperty(
        name="glTFs path",
        subtype='DIR_PATH'
    )

    definition_path: StringProperty(
        name="DKWorld definition path",
        subtype='FILE_PATH'
    )

    item_data_path: StringProperty(
        name="Items data path",
        subtype='FILE_PATH'
    )

class DKT_PG_ObjectProperties(bpy.types.PropertyGroup):

    range_begin: IntProperty(
        name="Range Begin",
        default=0,
        min=0,
        max=5000
    )

    range_end: IntProperty(
        name="Range End",
        default=0,
        min=0,
        max=5000
    )


####################################
# REGISTER/UNREGISTER
####################################
def register():
    bpy.utils.register_class(DKT_OT_ExportGltfs)
    bpy.utils.register_class(DKT_OT_SetLod)
    bpy.utils.register_class(DKT_PT_Setup)
    bpy.utils.register_class(DKT_PT_ExportItems)
    bpy.utils.register_class(DKT_PT_ExportWorld)
    bpy.utils.register_class(DKT_OT_ExportWorld)
    bpy.utils.register_class(DKT_PG_GltfsExportSetup)
    bpy.utils.register_class(DKT_PG_ObjectProperties)

    bpy.types.Scene.dkt_gltfsexportsetup = PointerProperty(type=DKT_PG_GltfsExportSetup)
    bpy.types.Object.dkt_properties = PointerProperty(type=DKT_PG_ObjectProperties)

def unregister():
    bpy.utils.unregister_class(DKT_OT_ExportGltfs)
    bpy.utils.unregister_class(DKT_OT_SetLod)
    bpy.utils.unregister_class(DKT_PT_Setup)
    bpy.utils.unregister_class(DKT_PT_ExportItems)
    bpy.utils.unregister_class(DKT_PT_ExportWorld)
    bpy.utils.unregister_class(DKT_OT_ExportWorld)
    bpy.utils.unregister_class(DKT_PG_GltfsExportSetup)
    bpy.utils.unregister_class(DKT_PG_ObjectProperties)

    del bpy.types.Scene.dkt_gltfsexportsetup
    del bpy.types.Object.dkt_properties