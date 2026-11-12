import bpy, math, random, json, os
from mathutils import Vector
from pathlib import Path
random.seed(47)
SRC=Path(__file__).parent
OUT=Path('D:/浪费GPT额度/小温的游戏/游戏/assets/cooking')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(n,c,metal=0,em=0):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Roughness'].default_value=.88; p.inputs['Metallic'].default_value=metal
 if em: p.inputs['Emission Color'].default_value=(*c,1); p.inputs['Emission Strength'].default_value=em
 return m
wood=mat('Warm oak',(.30,.125,.045)); cut=mat('Cut wood',(.53,.29,.10)); iron=mat('Black iron',(.055,.058,.065),.25); rim=mat('Iron rim',(.09,.095,.105),.35)
leafm=[mat('Leaf olive '+str(i),c) for i,c in enumerate([(.24,.38,.04),(.36,.49,.07),(.19,.30,.035),(.43,.55,.09)])]
red=mat('Ripe crimson berries',(.67,.055,.035)); red2=mat('Berry highlight',(.86,.12,.06)); cap=mat('Russet edible mushroom',(.49,.16,.075)); stem=mat('Cream mushroom flesh',(.75,.60,.35)); stone=mat('Hearth stones',(.29,.275,.25)); rope=mat('Natural hemp',(.59,.40,.19)); flame=mat('Flame orange',(1,.22,.015),em=1.6); flame2=mat('Flame gold',(1,.65,.025),em=2)
soup=mat('Soup adjustable',(.46,.23,.055)); carrot=mat('Carrot orange',(.92,.29,.025)); potato=mat('Potato cream',(.86,.66,.25)); fish=mat('Cooked fish',(.62,.65,.54)); meatmat=mat('Fresh meat',(.61,.14,.12)); fat=mat('Meat fat',(.83,.66,.48))
def mesh(n,v,f,m):
 me=bpy.data.meshes.new(n); me.from_pydata(v,[],f); me.update(); o=bpy.data.objects.new(n,me); bpy.context.collection.objects.link(o); o.data.materials.append(m); return o
def ico(n,loc,scale,m,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.name=n; o.scale=scale; o.data.materials.append(m); return o
def rod(n,a,b,r,m,verts=7,r2=None):
 a,b=Vector(a),Vector(b); d=b-a; bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2); o=bpy.context.object; o.name=n; o.rotation_euler=d.to_track_quat('Z','Y').to_euler(); o.data.materials.append(m); return o
def lathe(n,profile,m,N=12,xy=(0,0)):
 v=[(xy[0]+r*math.cos(i*2*math.pi/N),xy[1]+r*math.sin(i*2*math.pi/N),z) for r,z in profile for i in range(N)]; f=[]
 for j in range(len(profile)-1):
  for i in range(N): f.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
 return mesh(n,v,f,m)
def leaf(n,a,b,w,m):
 a,b=Vector(a),Vector(b); d=b-a; side=d.cross(Vector((0,0,1))).normalized()*w; mid=a+d*.48; top=mid+Vector((0,0,w*.32))
 return mesh(n,[a,mid+side,b,mid-side,top],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],m)
def join_named(objs,n):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join(); o=objs[0]; o.name=n; return o
def newset():return set(bpy.context.scene.objects)
manifest={'units':'meters','axis':'Godot +Y up, +Z front; origin bottom center','assets':{}}
assets=[]
def finish(n,before,target=None):
 obs=list(set(bpy.context.scene.objects)-before)
 static=[o for o in obs if o.type=='MESH' and o.name not in ['Flame','Soup','Berries','Harvest']]
 if len(static)>1:join_named(static,n+'_Base')
 obs=list(set(bpy.context.scene.objects)-before); meshes=[o for o in obs if o.type=='MESH']; bpy.context.view_layer.update()
 pts=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]; mn=Vector([min(p[i] for p in pts) for i in range(3)]); mx=Vector([max(p[i] for p in pts) for i in range(3)])
 shift=Vector((-(mn.x+mx.x)/2,-(mn.y+mx.y)/2,-mn.z)); factor=1 if target is None else target/(mx.z-mn.z)
 for o in obs:o.location=(o.location+shift)*factor; o.scale*=factor
 root=bpy.data.objects.new(n,None); bpy.context.collection.objects.link(root)
 for o in obs:o.parent=root
 bpy.context.view_layer.update(); bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
 for o in obs:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(n+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 dim=(mx-mn)*factor
 manifest['assets'][n]={'size_xyz':[round(dim.x,4),round(dim.z,4),round(dim.y,4)],'nodes':[o.name for o in obs],'path':'res://assets/cooking/'+n+'.glb'}
 assets.append((n,root,obs)); return obs
# Compact three-pole hearth; open pot has real inner wall and visible stew.
b=newset()
for i in range(9):
 a=i*math.tau/9; ico('HearthStone',(.37*math.cos(a),.37*math.sin(a),.065),(.115,.09,.065),stone)
for i in range(3):
 a=i*math.tau/3; rod('CharredLog',(-.26*math.cos(a),-.26*math.sin(a),.075),(.26*math.cos(a),.26*math.sin(a),.075),.047,wood)
fire=[]
for x,y,h in [(-.12,0,.27),(.11,.04,.3),(0,-.1,.37)]:
 fire.append(rod('FireTongue',(x,y,.09),(x+.025,y,.09+h),.10,flame,5,r2=0)); fire.append(rod('GoldenCore',(x,y-.025,.10),(x,y-.02,.10+h*.66),.065,flame2,5,r2=0))
join_named(fire,'Flame')
lathe('Pot',[(0,.34),(.16,.34),(.24,.39),(.30,.53),(.285,.68),(.30,.70),(.27,.70),(.255,.65),(.265,.53),(.21,.41),(.15,.38),(0,.38)],iron)
lathe('PotRim',[(.285,.675),(.315,.685),(.315,.715),(.28,.715),(.28,.69)],rim)
lathe('Soup',[(.262,.642),(0,.642)],soup)
for i in range(12):
 a=random.random()*math.tau; r=random.uniform(.04,.22); ico('StewVegetable',(r*math.cos(a),r*math.sin(a),.653),(.037,.03,.019),[carrot,potato,leafm[1]][i%3])
for i in range(3):
 a=i*math.tau/3; rod('PotFoot',(.17*math.cos(a),.17*math.sin(a),.37),(.20*math.cos(a),.20*math.sin(a),.29),.025,iron)
for i in range(12):
 a=math.pi*i/12; c=math.pi*(i+1)/12; rod('BailHandle',(.29*math.cos(a),0,.70+.26*math.sin(a)),(.29*math.cos(c),0,.70+.26*math.sin(c)),.014,rim,6)
for i in range(3):
 a=i*math.tau/3+math.pi/2; rod('TripodPole',(.49*math.cos(a),.49*math.sin(a),.028),(.37*math.cos(a),.37*math.sin(a),.79),.037,wood,6); rod('TripodShoulder',(.37*math.cos(a),.37*math.sin(a),.79),(-.045*math.cos(a),-.045*math.sin(a),1.15),.037,wood,6)
for z in [1.02,1.045,1.07]:lathe('RopeBinding',[(.063,z),(.063,z+.018)],rope,10)
rod('Suspension',(0,0,.96),(0,0,1.04),.013,iron)
rod('WoodSpoonHandle',(.05,-.11,.65),(.36,-.22,.89),.014,cut); ico('WoodSpoonBowl',(.035,-.10,.646),(.045,.065,.014),wood)
finish('cooking_pot',b,1.15)
# Berry bush: woody branching framework and individually folded leaves.
b=newset(); rod('Root',(0,0,0),(0,0,.43),.052,wood,6,r2=.024)
for j in range(8):
 a=j*math.tau/8; end=Vector((.31*math.cos(a),.31*math.sin(a),.37+(j%3)*.13)); rod('Branch',(0,0,.13),end,.022,wood,5,r2=.009)
 for k in range(7):
  t=k/7; origin=end*t+Vector((0,0,.13*(1-t))); an=a+(1 if k%2 else -1)*.9; dest=origin+Vector((.20*math.cos(an),.20*math.sin(an),.08)); leaf('Leaf',origin,dest,.075,leafm[(j+k)%4])
 for k in range(4):
  an=a+k*1.7; origin=end+Vector((0,0,-.05)); leaf('TipLeaf',origin,origin+Vector((.16*math.cos(an),.16*math.sin(an),.12)),.07,leafm[k])
berries=[]
for j in range(7):
 a=j*math.tau/7; x,y,z=.30*math.cos(a),.30*math.sin(a),.38+(j%3)*.12
 for k in range(5):
  an=k*math.tau/5; berries.append(ico('BerryCluster',(x+.035*math.cos(an),y+.035*math.sin(an),z+(k%2)*.035),(.036,)*3,red if k%2 else red2))
join_named(berries,'Berries'); obs=finish('berry_bush',b,.8)
# Empty version exports identical structure and leaf coordinates.
bpy.ops.object.select_all(action='DESELECT')
for o in obs:
 if o.name!='Berries':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'berry_bush_empty.glb'),export_format='GLB',use_selection=True)
def mushroom(x,y,z,h,r):
 rod('MushroomStem',(x,y,z),(x+.015,y,z+h*.73),r*.25,stem,7,r2=r*.19)
 lathe('MushroomCap',[(0,z+h*.64),(r*.75,z+h*.63),(r,z+h*.70),(r*.84,z+h*.88),(r*.42,z+h),(0,z+h*1.02)],cap,9,(x+.015,y))
b=newset()
for j in range(10):
 a=j*math.tau/10; leaf('GroundLeaf',(0,0,.01),(.22*math.cos(a),.22*math.sin(a),.03),.04,leafm[j%4])
before=newset(); mushroom(0,.02,.01,.29,.105); mushroom(-.12,-.035,.01,.17,.068); mushroom(.13,.015,.01,.20,.08); join_named(list(set(bpy.context.scene.objects)-before),'Harvest'); obs=finish('mushrooms',b,.30)
bpy.ops.object.select_all(action='DESELECT')
for o in obs:
 if o.name!='Harvest':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'mushrooms_empty.glb'),export_format='GLB',use_selection=True)
b=newset(); lathe('WoodBowl',[(0,0),(.065,0),(.105,.035),(.125,.085),(.125,.095),(.112,.095),(.09,.04),(0,.021)],wood); lathe('BowlRim',[(.112,.089),(.125,.089),(.125,.098),(.112,.098)],cut); lathe('MealSoup',[(.11,.078),(0,.078)],soup)
for j in range(9):
 a=j*2.4; r=.025+.045*(j%2); ico('MealVegetable',(r*math.cos(a),r*math.sin(a),.085),(.016,.013,.009),carrot if j%2 else potato)
ico('FishFillet',(-.025,.014,.087),(.04,.018,.009),fish); leaf('Herb',(.02,.01,.085),(.06,.035,.095),.013,leafm[1]); finish('meal_bowl',b)
b=newset(); ico('Berry',(0,0,.04),(.04,)*3,red,2); leaf('BerryCalyx',(0,0,.075),(.04,0,.085),.014,leafm[1]); rod('BerryStem',(0,0,.075),(0,0,.10),.004,wood,5); finish('berry',b)
b=newset(); mushroom(0,0,0,.18,.07); finish('mushroom',b)
b=newset(); ico('MeatCut',(0,0,.04),(.12,.075,.04),meatmat,2); lathe('FatBand',[(.03,.075),(.022,.081),(.01,.081)],fat,9,(-.025,0)); ico('Bone',(-.025,0,.081),(.011,.011,.004),stem); finish('meat',b)
manifest['interfaces']={'cooking_pot':'Flame mesh visibility; Soup material override for recipe color','berry_bush':'Berries mesh visibility OR berry_bush_empty.glb; identical foliage','mushrooms':'Harvest mesh visibility OR mushrooms_empty.glb; identical foliage','collision':'No collisions embedded; controller owns them'}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
# Gallery in source blend only. Exported meshes stay at bottom-centered origins.
positions=[(-1.2,.3,0),(.15,.4,0),(1.25,.35,0),(-.3,-.6,0),(.3,-.6,0),(.75,-.6,0),(1.15,-.6,0)]
for (n,root,obs),p in zip(assets,positions):root.location=p
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012)); bpy.context.object.data.materials.append(mat('Gallery parchment',(.55,.49,.37)))
world=bpy.context.scene.world; world.color=(.5,.5,.5)
for loc,power,size in [((-3,-4,6),900,5),((4,2,5),650,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc); bpy.context.object.data.energy=power; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=size
bpy.ops.object.camera_add(location=(2.7,-4.7,3.1)); cam=bpy.context.object; cam.rotation_euler=(Vector((0,.05,.4))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=3.65; bpy.context.scene.camera=cam
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.render.resolution_x=1600; sc.render.resolution_y=1100; sc.render.resolution_percentage=100; sc.view_settings.view_transform='Standard'; sc.render.filepath=str(SRC/'cooking_gallery.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'cooking_forage.blend')); bpy.ops.render.render(write_still=True)
print('COOKING_ASSETS_COMPLETE',json.dumps({n:d['size_xyz'] for n,d in manifest['assets'].items()}))



