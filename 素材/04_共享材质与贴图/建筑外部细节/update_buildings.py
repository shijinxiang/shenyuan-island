import bpy,bmesh,math,random,json,sys
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parent.parent
TEX=BASE/'建筑外部细节'/'textures'
NAMES=['B01_破旧木屋','B02_大型红色仓库','B03_白色灯塔']
idx=int(sys.argv[sys.argv.index('--')+1]);name=NAMES[idx];random.seed(304+idx)
ROOT=BASE/(name+'_外部细节版');ROOT.mkdir(exist_ok=True);(ROOT/'renders').mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/name/(name+'.blend')))
scene=bpy.context.scene
asset=bpy.data.collections.get(['B01 | GAME ASSET','B02 | GAME ASSET','B03_ASSET'][idx])
detail=bpy.data.collections.new('08_Exterior_growth_and_cracks');asset.children.link(detail)
def texturemat(n,path,alpha=False):
 m=bpy.data.materials.get(n) or bpy.data.materials.new(n);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.9
 tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True);tex.interpolation='Closest';tex.extension='CLIP' if alpha else 'REPEAT'
 m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 if alpha:
  m.node_tree.links.new(tex.outputs['Alpha'],p.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=False
 return m
crack=texturemat('Crack | upward weathering',TEX/'crack_decal.png',True)
ivy=texturemat('Ivy | mature climbing leaves',TEX/'ivy_wall.png',True) if idx<2 else None
def mesh(n,vs,fs,uvs,mat):
 me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new(name='UV0')
 for p in me.polygons:
  for li in p.loop_indices:uv.data[li].uv=uvs[me.loops[li].vertex_index]
 me.materials.append(mat);o=bpy.data.objects.new(n,me);detail.objects.link(o);o['component']='08_Ivy' if mat==ivy else '09_Cracks';o['intentional_surface_card']=True
 return o
serial=0
def card(side,a,b,z0,z1,mat,uv_override=None):
 global serial
 serial+=1;dep=(.061 if idx==0 else .096)+(serial%9)*.0018 if mat==ivy else (.047 if idx==0 else .084)
 X,Y=(2.3,1.9) if idx==0 else (9,4)
 def pos(u,z):return (u,-Y-dep,z) if side=='front' else (-u,Y+dep,z) if side=='back' else (-X-dep,-u,z) if side=='left' else (X+dep,u,z)
 uv=uv_override or [(0,0),(1,0),(1,1),(0,1)]
 if random.random()<.5:uv=[(1-u,v) for u,v in uv]
 return mesh(('Ivy' if mat==ivy else 'Crack')+f'_{side}_{serial:03d}',[pos(a,z0),pos(b,z0),pos(b,z1),pos(a,z1)],[(0,1,2,3)],uv,mat)
def grow(side,a,b,z0,z1,density=2):
 # Square physical patches keep leaves proportional, even around window reveals.
 width=1.12 if idx==0 else 1.9
 x=a
 while x<b-.08:
  size=random.uniform(width*.85,width*1.15);w=min(size,b-x);low=z0+random.uniform(0,.07)
  canopy=z1-random.uniform(.02,min(.52,(z1-z0)*.30))
  while low<canopy-.14:
   high=min(canopy,low+size)
   h=high-low
   if h>.12:
    u0=(1-w/size)*.5
    v0=1-h/size if high==canopy else 0
    card(side,x,x+w,low,high,ivy,[(u0,v0),(u0+w/size,v0),(u0+w/size,v0+h/size),(u0,v0+h/size)])
   low+=size*random.uniform(.63,.82)
  x+=size*random.uniform(.62,.79)
if idx==0:
 # Wall coordinates for back/left run in reverse to keep outward normals.
 regions=[('front',-2.24,-1.30,.20,2.98),('front',.39,.85,.20,2.98),('front',1.94,2.24,.20,2.95),('front',.90,1.89,.20,1.26),('front',.88,1.89,2.30,2.98),('back',-2.24,2.24,.20,3.0),('left',-1.82,-.44,.20,3.0),('left',.74,1.82,.20,3.0),('left',-.37,.67,.20,1.26),('left',-.37,.67,2.37,3.0),('right',-1.82,.23,.20,3.0),('right',1.31,1.82,.20,3.0),('right',.27,1.26,.20,1.30),('right',.27,1.26,2.34,3.0)]
 for r in regions:grow(*r)
 for side,a in [('front',-1.7),('front',.59),('back',-.8),('back',1.3),('left',1.1),('right',-1.1)]:card(side,a-.20,a+.20,.23,random.uniform(1.75,2.5),crack)
elif idx==1:
 regions=[('front',-8.87,-7.63,.24,3.95),('front',-7.57,-2.34,.24,2.93),('front',4.53,8.87,.24,2.93),('back',-8.87,8.87,.24,3.95),('left',-3.87,-.58,.24,3.95),('left',.88,3.87,.24,3.95),('right',-3.87,3.87,.24,3.95)]
 for r in regions:grow(*r)
 for side,a in [('front',-8),('front',-6.3),('front',-3.4),('front',5.5),('front',7.5),('back',-7),('back',-2),('back',3),('back',7),('left',-2),('left',2),('right',0)]:card(side,a-.24,a+.24,.26,random.uniform(2.3,2.9),crack)
else:
 texturemat('Warm old plaster',BASE/name/'textures/B03_plaster.png')
 texturemat('Orange red roof',BASE/name/'textures/B03_roof.png')
 # Boolean opening bevels can leave collapsed slivers; weld and dissolve them.
 tower=bpy.data.objects['Tapered hollow tower'];bpy.context.view_layer.objects.active=tower
 for mod in list(tower.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(tower.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00001)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(tower.data);bm.free()
 p=bpy.data.materials['Lantern glass'].node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=1;p.inputs['Roughness'].default_value=.045;p.inputs['IOR'].default_value=1.12
 bpy.data.materials['Lamp luminous glass'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.7
 profile=[(.78,1.85),(2.8,1.75),(4.8,1.64),(6.8,1.52),(8.9,1.4)]
 def radius(z):
  for (a,ra),(b,rb) in zip(profile,profile[1:]):
   if a<=z<=b:return ra+(rb-ra)*(z-a)/(b-a)
  return 1.85
 for k,(start,end) in enumerate([(22,6.7),(32,5.5),(2,7.5),(13,6.3),(17,4.5)]):
  zs=[1.0]+[z for z,r in profile if 1<z<end]+[end];vs=[];uv=[]
  for z in zs:
   for j in range(5):
    t=(start+j)*math.tau/40;r=radius(z)+.008;vs.append((r*math.cos(t),r*math.sin(t),z));uv.append((j/4,(z-1)/(end-1)))
  fs=[(i*5+j,i*5+j+1,(i+1)*5+j+1,(i+1)*5+j) for i in range(len(zs)-1) for j in range(4)]
  mesh(f'Crack_curved_tower_{k}',vs,fs,uv,crack)
 # Smooth only the shallow circumferential edges of cylindrical structures.
 for o in asset.all_objects:
  if o.type=='MESH' and any(s in o.name.lower() for s in ['tower','shell','structural ring','plinth']):
   bm=bmesh.new();bm.from_mesh(o.data)
   for f in bm.faces:f.smooth=True
   for e in bm.edges:e.smooth=e.is_manifold and e.calc_face_angle()<.48
   bm.to_mesh(o.data);bm.free()

def count():
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();n=0
 for o in asset.all_objects:
  if o.type=='MESH':
   ev=o.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();n+=len(me.loop_triangles);ev.to_mesh_clear()
 return n
optimization=[]
if idx==1:
 for o in sorted(asset.all_objects,key=lambda o:o.name):
  if count()<=12000:break
  if o.name.startswith('Column_'):
   for m in list(o.modifiers):
    if m.type=='BEVEL':o.modifiers.remove(m);optimization.append(o.name)
triangles=count();assert triangles<=12000,(name,triangles)
scene['detail_version']='Upward cracks; dense ivy on cabin and warehouse, no ivy on lighthouse';scene['asset_triangles']=triangles
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
try:
 p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
 for d in p.devices:d.use=d.type=='OPTIX'
 scene.cycles.device='GPU'
except Exception:pass
scene.cycles.transparent_max_bounces=32
scene.render.resolution_percentage=100;scene.render.resolution_x=1400;scene.render.resolution_y=1100 if idx<2 else 1700
scene.render.image_settings.file_format='PNG'
cameras=['Camera | reference perspective','Camera | back and right'] if idx<2 else ['Hero','Rear','Lantern detail']
scene.camera=bpy.data.objects[cameras[0]]
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/(name+'_外部细节.blend')))
for i,cam in enumerate(cameras):
 scene.camera=bpy.data.objects[cam];scene.render.filepath=str(ROOT/'renders'/f'{i+1:02d}_preview.png');bpy.ops.render.render(write_still=True)
# Evaluate the exact visible asset into a clean, self-contained export scene.
for o in scene.objects:o.select_set(False)
dg=bpy.context.evaluated_depsgraph_get();game=bpy.data.scenes.new(name+'_GAME');game.unit_settings.system='METRIC';groups={};solid_issues=[]
for ob in asset.all_objects:
 if ob.type!='MESH':continue
 me=bpy.data.meshes.new_from_object(ob.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
 if not ob.get('intentional_surface_card'):
  bm=bmesh.new();bm.from_mesh(me);bad=sum(not e.is_manifold for e in bm.edges);zero=sum(f.calc_area()<1e-10 for f in bm.faces);bm.free()
  if bad or zero:solid_issues.append({'object':ob.name,'nonmanifold_edges':bad,'zero_area_faces':zero})
 clone=bpy.data.objects.new(ob.name,me);clone.matrix_world=ob.matrix_world;game.collection.objects.link(clone)
 group=ob.get('component','01_Lighthouse');groups.setdefault(group,[]).append(clone)
bpy.context.window.scene=game
for group,obs in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name[:3]+'_'+group
 mod=o.modifiers.new('Final triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
meshes=list(game.objects);root=bpy.data.objects.new(name,None);game.collection.objects.link(root)
for o in meshes:o.parent=root
root['triangles']=triangles;root['budget']=12000
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
bpy.ops.export_scene.fbx(filepath=str(ROOT/(name+'.fbx')),use_selection=True,object_types={'EMPTY','MESH'},add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y')
for s in list(bpy.data.scenes):
 if s!=game:bpy.data.scenes.remove(s)
bpy.ops.outliner.orphans_purge(do_recursive=True);bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/(name+'_游戏网格.blend')))
report={'asset':name,'triangles':triangles,'budget':12000,'mesh_objects':len(meshes),'detail_cards':serial if idx<2 else 5,'interior_bevel_optimization':optimization,'solid_mesh_issues':solid_issues,'surface_cards_intentionally_open':True,'ivy':idx<2}
(ROOT/'export_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print('DETAIL_REPORT',json.dumps(report,ensure_ascii=False))
