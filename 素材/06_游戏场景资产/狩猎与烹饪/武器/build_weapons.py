import bpy,math,json
from pathlib import Path
from mathutils import Vector
S=Path(__file__).parent;P=S.parents[3];OUT=P/'娓告垙/assets/hunting';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.72;return m
wood=mat('Warm walnut',(.28,.115,.045));wood2=mat('Cut wood',(.42,.20,.075));steel=mat('Forged steel',(.15,.16,.17),.55);dark=mat('Bore',(.018,.02,.021));rope=mat('Hemp',(.65,.47,.25));feather=mat('Cream feather',(.78,.67,.45));brass=mat('Brass',(.65,.39,.08),.5);red=mat('Red paper',(.56,.10,.035))
def v(p):return Vector((p[0],-p[2],p[1]))
def cube(n,p,s,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.name=n;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);return o
def rod(n,a,b,r,m,verts=8,r2=None):
 a,b=v(a),v(b);d=b-a;bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.name=n;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(m);return o
def marker(n,p):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.location=v(p);return o
def profile(n,coords,w,m):
 vs=[(x,-z,y) for x in [-w/2,w/2] for z,y in coords];k=len(coords);fs=[tuple(range(k-1,-1,-1)),tuple(range(k,k*2))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)];me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.data.materials.append(m)
def export(n):
 objs=list(bpy.context.scene.objects);bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUT/(n+'.glb')),export_format='GLB',use_selection=True,export_animations=False);bpy.ops.wm.save_as_mainfile(filepath=str(S/(n+'.blend')));counts[n]=sum(len(o.data.polygons) for o in objs if o.type=='MESH')
 for o in objs:bpy.data.objects.remove(o,do_unlink=True)
counts={}
profile('Walnut shoulder stock',[(-.30,-.025),(-.30,-.135),(-.25,-.145),(-.08,-.065),(-.015,-.025),(.055,-.02),(.055,.03),(-.055,.035),(-.14,-.005)],.055,wood)
cube('Butt plate',(0,-.082,-.305),(.061,.12,.012),steel)
cube('Receiver',(0,.035,.085),(.065,.085,.15),steel)
rod('Octagonal single barrel',(0,.067,.15),(0,.067,.75),.024,steel)
rod('Dark muzzle bore',(0,.067,.751),(0,.067,.753),.017,dark)
profile('Wood fore end',[(.16,.035),(.16,-.008),(.43,-.008),(.46,.018),(.43,.035)],.057,wood2)
for a,b in [((0,-.025,.015),(0,-.075,.03)),((0,-.075,.03),(0,-.078,.10)),((0,-.078,.10),(0,-.02,.13))]:rod('Trigger guard',a,b,.005,steel,6)
rod('Trigger',(0,-.01,.067),(0,-.055,.057),.004,steel,6)
cube('Front sight',(0,.096,.72),(.012,.018,.022),steel);rod('Hammer',(0,.07,.025),(0,.105,-.005),.012,steel,6)
marker('GripRight',(0,-.005,0));marker('GripLeft',(0,.008,.23));marker('Muzzle',(0,.067,.756));marker('Butt',(0,-.075,-.305));export('hunting_rifle')
# Bow is upright, forward +Z. String behind the wooden limbs.
pts=[(0,-.64,-.08),(0,-.52,.045),(0,-.32,.15),(0,-.13,.11),(0,0,0),(0,.13,.11),(0,.32,.15),(0,.52,.045),(0,.64,-.08)]
for i in range(len(pts)-1):rod('Wood limb %02d'%i,pts[i],pts[i+1],.022 if i not in [0,7] else .014,wood2,6)
for y in range(-5,6):rod('Grip wrap',(0,y*.014-.007,0),(0,y*.014+.003,0),.026,rope,8)
rod('StringUpper',(0,0,-.08),pts[-1],.002,rope,6);rod('StringLower',pts[0],(0,0,-.08),.002,rope,6)
marker('GripLeft',(0,0,0));marker('GripRight',(.035,.055,-.08));marker('ArrowRest',(.035,.055,.015));marker('StringTop',pts[-1]);marker('StringBottom',pts[0])
export('bow')
rod('Wood shaft',(0,0,-.38),(0,0,.32),.006,wood2,6);rod('Iron arrowhead',(0,0,.32),(0,0,.39),.024,steel,4,0)
for angle in [0,2*math.pi/3,4*math.pi/3]:
 o=cube('Feather',(math.cos(angle)*.013,math.sin(angle)*.013,-.29),(.003,.035,.10),feather);o.rotation_euler[1]=angle
marker('Nock',(0,0,-.38));marker('Tip',(0,0,.39));export('wooden_arrow')
rod('Paper cartridge',(0,-.03,0),(0,.03,0),.012,red,10);rod('Brass rim',(0,-.035,0),(0,-.025,0),.014,brass,10);export('rifle_ammo')
(S/'mesh_counts.json').write_text(json.dumps(counts,indent=2));print(counts)
