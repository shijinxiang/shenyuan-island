import bpy, math, json
from pathlib import Path
OUT=Path(__file__).parent
GAME=Path(r'D:\浪费GPT额度\小温的游戏\游戏')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.65
 return m
wood=mat('Warm walnut',(.27,.105,.035)); iron=mat('Forged gray iron',(.28,.29,.29),.65); edge=mat('Honed edge',(.53,.55,.54),.72); rivet=mat('Old brass pins',(.40,.29,.14),.6)
def mesh(n,v,f,materials):
 me=bpy.data.meshes.new(n); me.from_pydata([(x,-z,y) for x,y,z in v],[],f); me.update(); ob=bpy.data.objects.new(n,me); bpy.context.collection.objects.link(ob)
 for m in materials: me.materials.append(m)
 return ob
def rings(n,levels,material):
 v=[(math.cos(a*math.tau/8)*rx,y,math.sin(a*math.tau/8)*rz+cz) for y,rx,rz,cz in levels for a in range(8)]
 f=[tuple(range(7,-1,-1))]+[(j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for j in range(len(levels)-1) for i in range(8)]+[tuple((len(levels)-1)*8+i for i in range(8))]
 return mesh(n,v,f,[material])
rings('CarvedWoodGrip',[(-.06,.009,.012,-.002),(-.052,.013,.016,0),(-.022,.012,.014,.001),(.027,.011,.014,0),(.052,.012,.016,0),(.06,.009,.012,0)],wood)
rings('IronBolster',[(.052,.013,.018,0),(.064,.013,.018,0)],iron)
# Curved broad single edge, bevel has its own narrow bright planar faces.
profile=[(.06,-.012),(.125,-.011),(.184,-.004),(.22,.018),(.194,.029),(.155,.036),(.102,.031),(.06,.019)]
inner=[(.063,-.008),(.125,-.007),(.180,0),(.210,.017),(.190,.022),(.153,.028),(.102,.023),(.063,.014)]
v=[(s*.0025,y,z) for s in [-1,1] for y,z in inner]+[(0,y,z) for y,z in profile]
f=[tuple(range(7,-1,-1)),tuple(range(8,16))]
for i in range(8):
 j=(i+1)%8; f.extend([(i,j,16+j,16+i),(8+j,8+i,16+i,16+j)])
ob=mesh('CurvedSkinningBlade',v,f,[iron,edge])
for p in ob.data.polygons: p.material_index=1 if p.index>=2 and p.index//2>=4 else 0
for y in [-.035,.031]:
 for side in [-1,1]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=.0025,depth=.001,location=(side*.012,-.001,y),rotation=(0,math.pi/2,0)); ob=bpy.context.object; ob.name='GripPin'; ob.data.materials.append(rivet)
for name,pos in [('Grip',(0,0,0)),('BladeTip',(0,.22,.018)),('Muzzle',(0,.22,.018))]:
 ob=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(ob); x,y,z=pos; ob.location=(x,-z,y); ob.empty_display_size=.02
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'skinning_knife.blend'))
bpy.ops.export_scene.gltf(filepath=str(GAME/'assets/hunting/skinning_knife.glb'),export_format='GLB',export_yup=True)
tri=sum(len(p.vertices)-2 for o in bpy.data.objects if o.type=='MESH' for p in o.data.polygons)
(OUT/'model_metrics.json').write_text(json.dumps({'triangles':tri,'length_m':.28,'grip_length_m':.12,'blade_length_m':.16,'godot_axis':'+Y longitudinal, +Z edge','markers':['Grip','BladeTip','Muzzle']},indent=2))
print('KNIFE_TRIANGLES',tri)
