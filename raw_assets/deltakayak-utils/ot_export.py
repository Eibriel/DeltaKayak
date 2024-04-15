import os
import bpy
import json

from bpy.props import (
    StringProperty,
    PointerProperty,
    BoolProperty,
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

        #gltfs_export_setup = context.scene.omv_gltfsexportsetup
        #if (gltfs_export_setup.collection_name_main == ''):
        #    return False
        #if (gltfs_export_setup.export_path_metadata == ''):
        #    return False
        #if (gltfs_export_setup.export_path_3dmodels == ''):
        #    return False
        
        #if not gltfs_export_setup.collection_name_main in D.collections:
        #    return False
        
        #if gltfs_export_setup.collection_name_empties != '' and not gltfs_export_setup.collection_name_empties in D.collections:
        #    return False

        if (context.area.ui_type == 'VIEW_3D'):
            return True

    # Operator execution
    def execute(self, context):
        C = bpy.context
        D = bpy.data
    
        self.report({'INFO'}, "Successful glTFs export")
        return{'FINISHED'}


class DKT_PG_GltfsExportSetup(bpy.types.PropertyGroup):

    export_path_3dmodels: StringProperty(
        name="glTFs path",
        subtype='DIR_PATH'
    )

    export_path_metadata: StringProperty(
        name="glTFs metadata path",
        subtype='FILE_PATH'
    )

    collection_name_main: StringProperty(
        name="Main collection name"
    )

    collection_name_empties: StringProperty(
        name="Empties collection name"
    )

    export_gltfs: BoolProperty(
        name="Export glTFs",
        default=True
    )


####################################
# REGISTER/UNREGISTER
####################################
def register():
    bpy.utils.register_class(DKT_OT_ExportGltfs)
    bpy.utils.register_class(DKT_PG_GltfsExportSetup)

    bpy.types.Scene.dkt_gltfsexportsetup = PointerProperty(type=DKT_PG_GltfsExportSetup)
        
def unregister():
    bpy.utils.unregister_class(DKT_OT_ExportGltfs)
    bpy.utils.unregister_class(DKT_PG_GltfsExportSetup)

    del bpy.types.Scene.dkt_gltfsexportsetup