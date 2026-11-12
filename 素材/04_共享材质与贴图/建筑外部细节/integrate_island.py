import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parent.parent;OUT=BASE/'整岛灰模_v08_建筑细节';OUT.mkdir(exist_ok=True);(OUT/'renders').mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'整岛灰模_v07/深渊岛_独立山体方案_v07.blend'))
scene=bpy.context.scene;target=bpy.data.collections['03_FINISHED_BUILDINGS']
def landscape_hash():
 h=hashlib.sha256()
 for cn in ['01_TERRAIN_50K_BUDGET','08_INDEPENDENT_MOUNTAINS_12K']:
  for ob in sorted(bpy.data.collections[cn].all_objects,key=lambda o:o.name):
   if ob.type=='MESH':
    h.update(ob.name.encode());h.update(str([(tuple(v.co)) for v in ob.data.vertices]).encode());h.update(str([tuple(p.vertices) for p in ob.data.polygons]).encode())
 return h.hexdigest()
before=landscape_hash();placements={}
for name,cn in [('B01_破旧木屋','B01 | completed asset'),('B02_大型红色仓库','B02 | completed asset')]:
 c=bpy.data.collections[cn];root=next(o for o in c.objects if o.type=='EMPTY');placements[name]=root.matrix_world.copy()
 for o in list(c.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(c)
for o in list(scene.objects):
 if o.name.startswith('B03 proxy |'):bpy.data.objects.remove(o,do_unlink=True)
for name in ['B01_破旧木屋','B02_大型红色仓库','B03_白色灯塔']:
 c=bpy.data.collections.new(name+' | exterior details');target.children.link(c)
 with bpy.data.libraries.load(str(BASE/(name+'_外部细节版')/(name+'_游戏网格.blend')),link=False) as (src,dst):dst.objects=src.objects
 for o in dst.objects:
  if o:c.objects.link(o)
 root=next(o for o in c.objects if o.type=='EMPTY' and o.parent is None)
 if name in placements:root.matrix_world=placements[name]
 else:root.location=(163.0007019,-81.6978378,7.4999847);root.rotation_euler.z=-math.pi/2
 bpy.context.view_layer.update()
assert before==landscape_hash()
bpy.ops.file.pack_all();scene.camera=bpy.data.objects['Camera | landing detail'];scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.cycles.transparent_max_bounces=32
try:
 p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
 for d in p.devices:d.use=d.type=='OPTIX'
 scene.cycles.device='GPU'
except Exception:pass
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'深渊岛_建筑细节_v08.blend'))
scene.render.filepath=str(OUT/'renders/01_buildings_on_island.png');bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for c in scene.collection.children:
 if 'STUDIO' not in c.name and 'LABEL' not in c.name:
  for o in c.all_objects:
   if o.type in {'MESH','EMPTY','CURVE'} and not o.hide_render:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'深渊岛_建筑细节_v08.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
(OUT/'update_report.json').write_text(json.dumps({'updated':['B01','B02','B03'],'terrain_and_mountain_unchanged':True,'terrain_geometry_sha256':before},indent=2),encoding='utf8')
print('ISLAND_UPDATED',str(OUT))
