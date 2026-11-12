"""Small warm-oak bedside table, matching the supplied cabin bed."""
import bpy,json,importlib.util
from pathlib import Path
SRC=Path(__file__).resolve().parent;PROJECT=SRC.parents[2];OUT=PROJECT/'游戏/assets/survival'
spec=importlib.util.spec_from_file_location('primitives',SRC.parent/'农耕与伐木/build_farming_assets.py');P=importlib.util.module_from_spec(spec);spec.loader.exec_module(P)
c=P.begin('bedside_table')
wood=P.material('Cabin warm oak',(.34,.16,.055));edge=P.material('Oak bevels',(.53,.29,.10));dark=P.material('Dark drawer recess',(.18,.077,.025));iron=P.material('Aged iron handle',(.13,.16,.145),.5,.55)
for x in [-.215,.215]:
    for y in [-.215,.215]:P.cube('Square oak leg',(x,y,.27),(.065,.065,.54),wood,c,.007)
P.cube('Level top slab',(0,0,.575),(.55,.55,.05),edge,c,.009)
P.cube('Top wood inset',(0,0,.588),(.49,.49,.024),wood,c,.006)
P.cube('Drawer body',(0,0,.445),(.48,.48,.18),wood,c,.012)
P.cube('Drawer shadow gap',(0,-.247,.447),(.435,.012,.135),dark,c,.003)
P.cube('Single drawer front',(0,-.258,.447),(.416,.018,.116),edge,c,.008)
P.tube('Iron pull handle',[(-.065,-.270,.445),(-.065,-.286,.445),(.065,-.286,.445),(.065,-.270,.445)],.009,iron,c,6)
P.cube('Lower shelf',(0,0,.15),(.46,.46,.035),wood,c,.006)
bpy.ops.object.select_all(action='DESELECT')
for o in c.objects:o.select_set(True)
bpy.context.view_layer.objects.active=list(c.objects)[0];bpy.ops.object.join();o=bpy.context.object;o.name='BedsideTableMesh'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'bedside_table.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
o.data.calc_loop_triangles();coords=[v.co for v in o.data.vertices]
mins=[min(v[i] for v in coords) for i in range(3)];maxs=[max(v[i] for v in coords) for i in range(3)]
report={'path':'res://assets/survival/bedside_table.glb','mesh_node':'BedsideTableMesh','size_x_y_z':[maxs[0]-mins[0],maxs[2]-mins[2],maxs[1]-mins[1]],'bounds_min_godot':[mins[0],mins[2],-maxs[1]],'top_surface_y':.60,'usable_top_xz':[.49,.49],'triangles':len(o.data.loop_triangles),'vertices':len(coords),'cabin_position':[-1.4,.65,-2.15],'lamp_position':[-1.4,1.25,-2.15]}
(SRC/'bedside_table_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
manifest_path=OUT/'manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf-8'));manifest['assets']['bedside_table']=report;manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');(SRC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'床头柜_模型.blend'))
print('BEDSIDE_TABLE_COMPLETE '+json.dumps(report))
