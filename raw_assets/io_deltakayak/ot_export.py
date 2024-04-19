import os
from bmesh.types import BMesh
import bpy
import json
import bmesh
from bpy.types import Object
import mathutils

from bpy.props import (
    StringProperty,
    PointerProperty,
    BoolProperty,
    IntProperty,
    FloatProperty,
    EnumProperty
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
    
    def get_trees(self, sector):# -> dict:
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

    def get_items(self, sector):# -> dict:
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
    
    def location_to_godot(self, location):# -> list:
        return [
            location[0],
            location[2],
            -location[1]
        ]

    def scale_to_godot(self, scale):# -> list:
        return [
            scale[0],
            scale[2],
            scale[1]
        ]

    def rotation_to_godot(self, rotation):# -> list:
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

        col.operator("dktools.export_gltfs", text="Export GLTFs", icon='MESH_MONKEY')

        col.label(text="LOD:")
        for obj in context.selected_objects:
            range_begin = obj.dkt_properties.range_begin
            range_end = obj.dkt_properties.range_end
            col.label(text="{}: {} - {}".format(obj.name, range_begin, range_end))
        col.operator("dktools.set_lod", text="Set LOD", icon='MESH_ICOSPHERE')

        col.label(text="Stencils:")
        active_object: Object = context.active_object
        # composition_mode opacity normal_masking mask_image diffuse_image emission_image alpha_image
        if active_object:
            col.prop(active_object.dkt_stencil, "is_stencil")
            if active_object.dkt_stencil.is_stencil:
                col.prop(active_object.dkt_stencil, "diffuse_image")
                col.prop(active_object.dkt_stencil, "opacity")
                col.prop(active_object.dkt_stencil, "composition_mode")
                col.prop(active_object.dkt_stencil, "normal_masking")
                col.prop(active_object.dkt_stencil, "emission_image")
                col.prop(active_object.dkt_stencil, "alpha_image")
                col.prop(active_object.dkt_stencil, "mask_image")
            else:

                col.operator("dktools.apply_stencils", text="Apply Stencils", icon='IMAGE_RGB_ALPHA')


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
        C = bpy.context
        D = bpy.data

        self.source_images_cache = {}

        self.paint()

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

    def pixel_to_uv(self, img, x, y) -> list[int]:
        width: int = img.size[0]
        height:int = img.size[1]
        uv:list[int] = [
            x/width,
            y/height
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
            if in_triangle == 1:
                selected_triangles.append(t)
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


    def test_ray(self, point:mathutils.Vector, normal:mathutils.Vector, collected=[])->list:
        C = bpy.context
        D = bpy.data

        if len(collected) > 3:
            print("Max Depth")
            return collected
        bias_amount:float = 0.001
        bias: mathutils.Vector = normal * bias_amount
        ray: tuple[bool, mathutils.Vector|None, mathutils.Vector|None, int|None, bpy.types.Object|None, mathutils.Matrix|None] = C.scene.ray_cast(
            bpy.context.view_layer.depsgraph,
            point+bias,
            normal,
            distance=10
        ) # type: ignore
        
        #D.objects["Empty"].location= point
        #D.objects["Empty.001"].location= point + normal

        result, location, normal_b, index, object, matrix = ray
        if not result:
            return collected
        if len(collected) == 0 or collected[-1][1]!=object:
            collected.append([location, object, index, normal_b])
        self.test_ray(location, normal_b, collected) # type: ignore
        del ray
        return collected

    def get_source_from_obj(self, obj_hit)-> tuple[bpy.types.Image, list[float]]:
        D = bpy.data
        if not (obj_hit.name in self.source_images_cache.keys()):
            image_name: str = obj_hit.dkt_stencil.diffuse_image
            
            img_source: bpy.types.Image = D.images[image_name]
            
            source_pixels: list[float] = list(img_source.pixels) # type: ignore
            
            self.source_images_cache[obj_hit.name] = (img_source, source_pixels)
        
        return self.source_images_cache[obj_hit.name]

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
        return color_c

    def mult_color(self, color, value):
        color_c = []
        for id in range(len(color)):
            color_c.append(color[id] * value)
        return color_c

    def get_pixel_color(self, img_target:bpy.types.Image, triangles, x:int, y:int) -> list[float]:
        uv: list[int] = self.pixel_to_uv(img_target, x, y)
            
        sel_triangles = self.get_triangles_in_uv(uv, triangles)
        p: list[float] = [0.0, 0.0, 0.0, 0.0]
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
            r = self.test_ray(obj_point, normal, [])
            #print("Hits:", len(r))
            for hit in r:
                obj_hit = hit[1]
                point_hit = hit[0]
                face_hit = hit[2]
                normal_b = hit[3]
                
                if not obj_hit.dkt_stencil.is_stencil:
                    continue

                dotp = mathutils.Vector(normal).dot( mathutils.Vector(normal_b) )
                dotp = max(0.0, dotp)
                #p = [0.0, dotp, 0.0, 1.0]
                #continue
                
                #p = [0.0, 1.0, 0.0, 1.0]
                uv_source = self.point_3d_to_uv(obj_hit, point_hit, face_hit)
                if uv_source is None:
                    print("Missing UV Source")
                    continue
                img_source, source_pixels = self.get_source_from_obj(obj_hit)
                
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
                this_p = [0.0, 0.0, 0.0, 0.0]
                for offset in offsets:
                    value = self.get_pixel(img_source, source_pixels, pixel[0]+offset[0], pixel[1]+offset[1])
                    this_p = self.add_colors(value, this_p)
                this_p = self.mult_color(this_p, 1.0/len(offsets))
                p = self.color_mix(p, this_p)
                
            break
        return p



    def paint(self):
        C = bpy.context
        D = bpy.data

        obj = C.active_object
        mesh: bpy.types.Mesh = C.active_object.data # type: ignore
        bm: BMesh = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=bm.faces[:]) # type: ignore

        img_target = D.images['PEPA_house']

        # we need to know the image dimensions
        width = img_target.size[0]
        height = img_target.size[1]

        triangles = self.bmesh_to_triangles(obj, bm)

        positions = []
        hits = []

        paint_pixels = list(img_target.pixels)
        if True:
            for x in range(0, width):
                for y in range(0, height):
                    p = self.get_pixel_color(img_target, triangles, x, y)
                    self.set_pixel(img_target, paint_pixels, x, y, p[0], p[1], p[2], p[3])
        else:
            x = 40
            y = 60
            p = self.get_pixel_color(img_target, triangles, x, y)
            print(p)
            self.set_pixel(img_target, paint_pixels, x, y, p[0], p[1], p[2], p[3])

        img_target.pixels[:] = paint_pixels

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


class DKT_PG_StencilProperties(bpy.types.PropertyGroup):

    is_stencil: BoolProperty(
        name="Is Stencil",
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

    mask_image: StringProperty(
        name="Mask Image",
        description="B&W image as a cutout for next layer",
        default=""
    ) # type: ignore

    diffuse_image: StringProperty(
        name="Diffuse Image",
        description="Color image",
        default=""
    ) # type: ignore

    emission_image: StringProperty(
        name="Emission Image",
        description="Emission image",
        default=""
    ) # type: ignore

    alpha_image: StringProperty(
        name="Alpha Image",
        description="B&W image influencing only the alpha channel",
        default=""
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
    bpy.utils.register_class(DKT_PG_StencilProperties)

    bpy.types.Scene.dkt_gltfsexportsetup = PointerProperty(type=DKT_PG_GltfsExportSetup) # type: ignore
    bpy.types.Object.dkt_properties = PointerProperty(type=DKT_PG_ObjectProperties) # type: ignore
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
    bpy.utils.unregister_class(DKT_PG_StencilProperties)

    del bpy.types.Scene.dkt_gltfsexportsetup # type: ignore
    del bpy.types.Object.dkt_properties # type: ignore
    del bpy.types.Object.dkt_stencil # type: ignore