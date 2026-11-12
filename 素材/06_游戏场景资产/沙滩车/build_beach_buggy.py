import bpy,math,json,importlib.util
from pathlib import Path
from mathutils import Vector
SRC=Path(__file__).resolve().parent;PROJECT=SRC.parents[2];OUT=PROJECT/'游戏/assets/vehicle';OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('primitives',SRC.parent/'农耕与伐木/build_farming_assets.py');P=importlib.util.module_from_spec(spec);spec.loader.exec_module(P)
scene=bpy.context.scene;c=P.begin('beach_buggy');cube=P.cube;cone=P.cone;tube=P.tube;mesh=P.mesh;ico=P.ico
navy=P.material('Navy blue body',(.035,.065,.13),.56,.15);sand=P.material('Sand body trim',(.58,.40,.18),.68);rubber=P.material('All terrain rubber',(.023,.026,.028),.93);rim=P.material('Sand alloy rims',(.44,.32,.16),.45,.6);steel=P.material('Dark cage steel',(.065,.075,.080),.45,.6);seatmat=P.material('Sand canvas seat',(.40,.285,.125));seam=P.material('Seat stitching',(.65,.51,.29));headlamp=P.material('Warm white headlamps',(.85,.88,.75),.3);tailmat=P.material('Red tail lamps',(.57,.035,.018),.35)
for m,col in [(headlamp,(1,.9,.64,1)),(tailmat,(.8,.025,.008,1))]:
    bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Emission Color'].default_value=col;bs.inputs['Emission Strength'].default_value=.5
parts=[]
def add(o):parts.append(o);return o
def box(name,pos,size,mat,bev=.015):return add(cube(name,pos,size,mat,c,bev))
def pipe(name,pts,r,mat=steel):return add(tube(name,pts,r,mat,c,8))
def join(objs,name,origin=(0,0,0)):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');return o
def marker(name,p,parent=None):
    o=bpy.data.objects.new(name,None);c.objects.link(o);o.location=p
    if parent:o.parent=parent
    return o
for side in [-1,1]:box('Undercarriage side rail',(side*.46,0,.355),(.10,2.24,.13),steel)
box('Rear raised seat platform',(0,.61,.425),(.85,.73,.08),sand)
box('Deep open footwell',(0,-.16,.16),(.82,.91,.045),sand)
for side in [-1,1]:box('Recessed footwell side wall',(side*.40,-.16,.28),(.045,.91,.24),navy)
box('Front axle guard',(0,-.92,.29),(.86,.30,.10),steel)
box('Front hood navy',(0,-.87,.74),(1.06,.76,.30),navy,.10)
box('Hood centre sand stripe',(0,-.90,.907),(.34,.70,.025),sand,.015)
box('Rear engine cover',(0,.93,.69),(1.08,.51,.25),navy,.055)
for side in [-1,1]:
    box('Low side sill',(side*.53,.12,.46),(.105,1.40,.19),sand,.025)
    for y in [-.85,.85]:
        box('Raised navy fender',(side*.56,y,.75),(.35,.80,.125),navy,.045)
        box('Sand fender edge',(side*.70,y,.715),(.055,.72,.095),sand,.015)
        pipe('Suspension wishbone',[(side*.25,y,.39),(side*.63,y,.34)],.025)
        add(cone('Suspension damper',(side*.47,y-.06,.37),(side*.46,y+.04,.67),.022,.022,steel,c,8))
        for k in range(5):add(P.ring('Coil spring',(side*.465,y-.045+k*.018,.42+k*.04),.042,.009,sand,c,n=8))
    box('Front headlamp',(side*.37,-1.259,.765),(.24,.035,.105),headlamp,.02)
    box('Rear red taillight',(side*.39,1.194,.77),(.21,.028,.095),tailmat,.018)
    pipe('Roll cage side',[(side*.48,-.37,.77),(side*.46,-.17,1.64),(side*.45,.64,1.67),(side*.48,1.01,.77)],.036)
    pipe('Low side grab rail',[(side*.57,.67,.61),(side*.57,.35,.52)],.025)
for y,z in [(-.17,1.64),(.64,1.67)]:pipe('Roof cross member',[(-.46,y,z),(.46,y,z)],.034)
pipe('Front bumper',[(-.50,-1.28,.43),(-.43,-1.30,.53),(.43,-1.30,.53),(.50,-1.28,.43)],.032)
pipe('Rear bumper',[(-.50,1.27,.43),(.50,1.27,.43)],.03)
box('Seat base',(0,.25,.61),(.56,.58,.18),seatmat,.065)
back=box('Bucket seat back',(0,.56,.96),(.57,.135,.69),seatmat,.075);back.rotation_euler.x=math.radians(-8)
for x in [-.25,.25]:box('Seat side bolster',(x,.26,.70),(.075,.51,.13),sand,.035)
box('Seat horizontal seam',(0,.481,.99),(.42,.012,.018),seam,.004)
box('Dashboard',(0,-.42,.84),(.89,.12,.23),navy,.025)
box('Instrument binnacle',(0,-.338,.875),(.23,.025,.12),steel,.01)
for x in [-.065,.065]:add(cone('Dashboard dial',(x,-.323,.88),(x,-.318,.88),.035,.035,seam,c,12))
pipe('Steering column',[(0,-.37,.76),(0,-.04,1.055)],.023)
box('Accelerator pedal',(-.195,-.36,.385),(.12,.17,.045),steel,.006)
box('Footrest',(.17,-.06,.19),(.17,.24,.025),steel,.006)
body=join(parts,'BuggyBody');parts=[]
wheel_positions={}
for side,label in [(-1,'L'),(1,'R')]:
    for front,y in [(True,-.85),(False,.85)]:
        n='Wheel_'+('F' if front else 'R')+label;p=Vector((side*.60,y,.329));obs=[]
        obs.append(cone('Chunky tire',p+Vector((-.12,0,0)),p+Vector((.12,0,0)),.32,.32,rubber,c,16))
        for i in range(16):
            a=i*math.tau/16
            o=cube('Tire tread block',p+Vector((0,math.sin(a)*.315,math.cos(a)*.315)),(.245,.058,.028),rubber,c,.004);o.rotation_euler.x=-a;obs.append(o)
        outer=p+Vector((side*.124,0,0))
        obs.append(cone('Inset alloy wheel',outer,outer+Vector((side*.006,0,0)),.181,.181,rim,c,12))
        obs.append(cone('Wheel hub',outer+Vector((side*.007,0,0)),outer+Vector((side*.025,0,0)),.059,.059,steel,c,8))
        for i in range(5):
            a=i*math.tau/5;q=outer+Vector((side*.01,math.sin(a)*.105,math.cos(a)*.105));obs.append(ico('Wheel nut',q,(.012,.015,.015),steel,c,1))
        wh=join(obs,n,p)
        if front:
            pivot=marker('Steer_'+label,p);wh.parent=pivot;wh.location=(0,0,0);path=pivot.name+'/'+n
        else:path=n
        wheel_positions[n]={'path':path,'position':[p.x,p.z,-p.y],'spin_axis':'X','radius':.329,'steering_pivot':'Steer_'+label if front else None}
center=Vector((0,-.04,1.055));obs=[P.ring('Steering wheel rim',center,.208,.016,rubber,c,'XZ',20)]
for a in [0,math.tau/3,2*math.tau/3]:obs.append(tube('Steering wheel spoke',[center,center+Vector((math.cos(a)*.196,0,math.sin(a)*.196))],.012,steel,c,6))
obs.append(cone('Steering boss',center-Vector((0,.017,0)),center+Vector((0,.017,0)),.044,.044,sand,c,10))
steering=join(obs,'SteeringWheel',center)
markers={'DriverSeat':(0,.25,0),'SeatPelvis':(0,.25,.78),'EntryPoint':(-.98,.25,0),'ExitPoint':(1.0,.25,0),'CameraFollow':(0,2.8,1.65),'HandGripL':(.208,-.01,1.056),'HandGripR':(-.207,-.056,1.048)}
for name,p in markers.items():marker(name,p)
bpy.ops.object.select_all(action='DESELECT')
for ob in c.objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'beach_buggy.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_extras=True)
stats={}
for ob in c.objects:
    if ob.type=='MESH':ob.data.calc_loop_triangles();stats[ob.name]={'triangles':len(ob.data.loop_triangles),'vertices':len(ob.data.vertices)}
manifest={'units':'metres','forward':'+Z','size_x_y_z':[1.558,1.706,2.664],'ground_y':-.009,'wheel_radius':.329,'wheels':wheel_positions,'steering_wheel':{'path':'SteeringWheel','position':[0,1.055,.04],'rotation_axis':'Z','radius':.208},'markers':{n:{'path':n,'position':[p[0],p[2],-p[1]]} for n,p in markers.items()},'driver_anchor_note':'Parent the C01 visual at DriverSeat (actor-origin marker Y=0). The animation itself places Hips at Y=.78. Do not add .78 twice. SeatPelvis is an anatomical reference, not the actor root.','seat_cushion_top_y':.70,'driver_pelvis_y':.78,'animations':{'Entering Car':{'resource':'res://assets/characters/C01_entering_car.res','duration':164/30,'loop':False,'horizontal_root_motion':False,'vertical_motion_preserved':True,'end_hips_y':.78},'Driving':{'resource':'res://assets/characters/C01_driving.res','duration':5.,'loop':True,'horizontal_root_motion':False,'hips_y':.78}},'meshes':stats}
manifest['size_x_y_z']=[1.498,1.704,2.631992];manifest['ground_y']=0
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');(SRC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'沙滩车_模型库.blend'))
print('BEACH_BUGGY_COMPLETE '+str(OUT))
