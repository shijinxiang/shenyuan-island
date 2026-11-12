"""Blender 5.2 procedural low-poly furniture and rigged saltwater crocodile.
Uses the adjacent farming library's primitive helpers; run in background Blender.
"""
import bpy, math, json, importlib.util, sys
from pathlib import Path
from mathutils import Vector, Quaternion
SOURCE=Path(__file__).resolve().parent
PROJECT=SOURCE.parents[2]
OUT=PROJECT/'游戏'/'assets'/'survival'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('primitives',SOURCE.parent/'农耕与伐木'/'build_farming_assets.py')
P=importlib.util.module_from_spec(spec);spec.loader.exec_module(P)
P.SOURCE=SOURCE;P.OUT=OUT
scene=bpy.context.scene
material=P.material;begin=P.begin;cube=P.cube;cone=P.cone;ico=P.ico;tube=P.tube;mesh=P.mesh;ring=P.ring
wood=material('Cabin warm oak',(.34,.16,.055));lightwood=material('Oak bevels',(.53,.29,.10));darkwood=material('Dark wood grain',(.18,.077,.025))
iron=material('Aged iron fittings',(.13,.16,.145),.5,.55);cream=material('Cream linen',(.74,.66,.48));blanket=material('Olive woven blanket',(.22,.31,.055));rope=material('Natural cord',(.59,.42,.21))
olive=material('Crocodile olive armour',(.105,.145,.040));olive_light=material('Crocodile scute highlight',(.19,.235,.065));olive_dark=material('Crocodile dark flank',(.065,.088,.025));sand=material('Crocodile ochre belly',(.36,.31,.105));tooth=material('Ivory teeth and claws',(.79,.72,.48));mouth=material('Mouth dark rose',(.21,.085,.065));gold=material('Amber iris',(.92,.49,.025));black=material('Slit pupils and nostrils',(.008,.013,.006),.3)
manifest={'units':'metres','coordinate_system':'Godot Y-up','assets':{},'tools':{},'reference':str(PROJECT/'素材'/'03_参考图与资料'/'生存与海岸生态'/'海岸生存_复合参考.png')}

def select_collection(c):
    bpy.ops.object.select_all(action='DESELECT')
    for o in c.objects:o.select_set(True)

def join(c,name,objects=None):
    obs=objects or [o for o in c.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
    return o

def export(name,c):
    select_collection(c)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_materials='EXPORT',export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_extras=True)
    stats=[]
    for o in c.objects:
        if o.type=='MESH':
            o.data.calc_loop_triangles();stats.append({'node':o.name,'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices)})
    manifest['assets'][name]={'path':'res://assets/survival/'+name+'.glb','meshes':stats}

def furniture():
    c=begin('bed')
    for x in [-.535,.535]:
        for y in [-.885,.885]:
            h=.95 if y>.0 else .59
            cube('Bed square post',(x,y,h/2),(.105,.105,h),wood,c,.012)
            for z in [.35,.39]:ring('Post cord lash',(x,y,z),.071,.009,rope,c,n=8)
    for x in [-.54,.54]:cube('Bed long rail',(x,0,.30),(.095,1.78,.17),wood,c,.008)
    for y in [-.865,.865]:cube('Bed end rail',(0,y,.31),(1.04,.08,.18),wood,c,.01)
    for y in [i*.18-.72 for i in range(9)]:cube('Bed slat',(0,y,.36),(1.02,.14,.045),lightwood,c)
    cube('Cream mattress',(0,0,.435),(1.04,1.77,.17),cream,c,.05)
    cube('Thick pillow',(0,.60,.563),(.74,.38,.16),cream,c,.07)
    cube('Headboard lower',(0,.88,.65),(1.04,.07,.11),lightwood,c,.015)
    cube('Headboard top',(0,.88,.81),(1.04,.07,.14),wood,c,.02)
    cube('Olive blanket',(0,-.39,.535),(1.065,.95,.04),blanket,c,.012)
    for x in [-.52,.52]:cube('Draped blanket side',(x,-.39,.44),(.035,.94,.20),blanket,c,.009)
    for y in [-.78,-.70,-.08]:cube('Blanket stitch',(0,y,.558),(1.04,.018,.006),rope,c)
    join(c,'BedMesh');export('bed',c)
    manifest['assets']['bed'].update({'size_x_y_z':[1.175,.95,1.875],'head_direction':'-Z','suggested_cabin_local_position':[-2.4,.65,-1.55]})
    c=begin('chest')
    for x in [-.48,.48]:
        for y in [-.20,.20]:cube('Chest foot',(x,y,.04),(.12,.12,.08),darkwood,c,.008)
    cube('Chest bottom',(0,0,.10),(1.15,.55,.12),wood,c,.012)
    for y in [-.245,.245]:
        for z in [.21,.345,.48]:cube('Chest wall plank',(0,y,z),(1.15,.06,.125),wood,c,.006)
    for x in [-.54,.54]:cube('Chest end wall',(x,0,.345),(.07,.45,.41),wood,c,.009)
    for x in [-.39,.39]:
        for y in [-.28,.28]:
            cube('Vertical iron strap',(x,y,.31),(.068,.018,.48),iron,c,.006)
            for z in [.14,.31,.49]:ico('Iron rivet',(x,y*1.025,z),(.014,.009,.014),lightwood,c,1)
    cube('Front lock plate',(0,-.289,.43),(.115,.025,.15),iron,c,.016)
    ico('Keyhole',(0,-.308,.43),(.013,.008,.025),black,c,1)
    body=join(c,'ChestBase')
    lidobjs=[]
    for i in range(5):lidobjs.append(cube('Lid plank',((i-2)*.228,0,.585),(.222,.57,.105),wood,c,.015))
    for x in [-.39,.39]:lidobjs.append(cube('Lid iron strap',(x,0,.645),(.07,.56,.018),iron,c,.006))
    lid=join(c,'ChestLid',lidobjs)
    pivot=bpy.data.objects.new('LidPivot',None);c.objects.link(pivot);pivot.location=(0,.285,.535)
    lid.parent=pivot;lid.matrix_parent_inverse=pivot.matrix_world.inverted()
    # Store mesh in hinge-local coordinates; node itself remains identity.
    for v in lid.data.vertices:v.co-=pivot.location
    lid.matrix_parent_inverse.identity();lid.location=(0,0,0)
    export('chest',c)
    manifest['assets']['chest'].update({'lid_node_path':'LidPivot','lid_mesh_path':'LidPivot/ChestLid','hinge_position':[0,.535,-.285],'rotation_axis':'X','closed_angle_rad':0,'open_angle_rad':-1.3,'size_x_y_z':[1.15,.654,.598],'interior_is_hollow':True,'suggested_cabin_local_position':[.1,.65,-2.25]})
    c=begin('cabin_lamp')
    for x,y in [(-.105,-.105),(-.105,.105),(.105,-.105),(.105,.105)]:cone('Lamp timber leg',(x*1.2,y*1.2,0),(x,y,.48),.026,.021,wood,c,5)
    for z in [.10,.40]:ring('Lamp tied frame',(0,0,z),.145,.018,rope,c,n=8)
    cone('Lamp lower tray',(0,0,.095),(0,0,.125),.13,.13,iron,c,8)
    glow=material('Warm luminous diffuser',(.95,.43,.055),.6)
    bs=glow.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(1,.43,.055,1);bs.inputs['Emission Strength'].default_value=2
    cone('WarmGlass',(0,0,.14),(0,0,.37),.075,.075,glow,c,8)
    for i in range(10):
        a=i*math.tau/10
        ob=cube('Thatched roof slat',(.095*math.cos(a),.095*math.sin(a),.48),(.12,.24,.025),lightwood,c,.005)
        ob.rotation_euler=(0,math.radians(38),a)
    cone('Lamp roof crown',(0,0,.51),(0,0,.60),.038,.03,wood,c,8)
    join(c,'CabinLampMesh');export('cabin_lamp',c)
    manifest['assets']['cabin_lamp'].update({'light_anchor':[0,.25,0],'recommended_omni_range':4.5,'recommended_energy':1.1,'warm_color':'#ffd58c','emissive_material':'Warm luminous diffuser'})

def bone_weight(obj,bone):
    vg=obj.vertex_groups.new(name=bone);vg.add(list(range(len(obj.data.vertices))),1,'REPLACE');return obj

def crocodile():
    c=begin('saltwater_crocodile');parts=[]
    def I(name,p,s,mat,bone='Body',sub=1):
        o=ico(name,p,s,mat,c,sub);bone_weight(o,bone);parts.append(o);return o
    def C(name,a,b,r1,r2,mat,bone='Body',sides=8):
        o=cone(name,a,b,r1,r2,mat,c,sides);bone_weight(o,bone);parts.append(o);return o
    def M(name,vs,fs,mat,bone='Body'):
        o=mesh(name,vs,fs,mat,c);bone_weight(o,bone);parts.append(o)
        if name in ['Upper skull and snout','Hinged lower jaw']:
            bpy.context.view_layer.objects.active=o
            mod=o.modifiers.new('Faceted jaw bevel','BEVEL');mod.width=.017;mod.segments=1
            bpy.ops.object.modifier_apply(modifier=mod.name)
        return o
    I('Armoured body',(0,.07,.30),(.32,.67,.23),olive,'Body',2)
    I('Ochre underside',(0,.02,.225),(.285,.60,.13),sand,'Body',2)
    I('Neck',(0,-.47,.31),(.24,.27,.18),olive,'Head',2)
    # Long tapering snout with a clearly separated hinged lower jaw.
    vs=[(-.215,-.49,.29),(.215,-.49,.29),(.145,-1.34,.295),(-.145,-1.34,.295),(-.22,-.49,.45),(.22,-.49,.45),(.145,-1.34,.365),(-.145,-1.34,.365)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    M('Upper skull and snout',vs,faces,olive,'Head')
    vs=[(-.185,-.49,.225),(.185,-.49,.225),(.13,-1.31,.25),(-.13,-1.31,.25),(-.195,-.49,.282),(.195,-.49,.282),(.14,-1.31,.286),(-.14,-1.31,.286)]
    M('Hinged lower jaw',vs,faces,sand,'Jaw')
    I('Mouth interior',(0,-.90,.281),(.13,.40,.014),mouth,'Jaw',2)
    for sign in [-1,1]:
        I('Raised eye ridge',(sign*.18,-.59,.443),(.085,.11,.052),olive_light,'Head',1)
        I('Amber eye',(sign*.247,-.61,.455),(.028,.039,.027),gold,'Head',2)
        I('Vertical pupil',(sign*.271,-.618,.457),(.006,.013,.022),black,'Head',1)
        I('Nostril',(sign*.088,-1.277,.37),(.029,.032,.008),black,'Head',1)
        for i in range(7):
            y=-.64-i*.095;x=sign*(.195-(abs(y)-.49)*.066)
            C('Upper tooth',(x,y,.30),(x*.99,y,.245),.014,0,tooth,'Head',5)
            if i%2==0:C('Lower tooth',(x*.91,y+.038,.282),(x*.91,y+.038,.318),.010,0,tooth,'Jaw',5)
    for y in [-.70,-.83,-.96,-1.09]:
        for x in [-.07,.07]:
            z=.45-(abs(y)-.49)*.10
            I('Faceted snout scale',(x,y,z),(.07,.065,.012),olive_light,'Head',1)
    # Continuous tapering tail, blended across three tail bones.
    sections=[(.55,.25,.28),(.75,.205,.27),(1.00,.14,.24),(1.24,.085,.18),(1.49,.018,.105),(1.57,.002,.09)]
    vs=[];fs=[];n=10
    for y,r,z in sections:
        for i in range(n):
            a=i*math.tau/n;vs.append((math.cos(a)*r,y,z+math.sin(a)*r*.68))
    for j in range(len(sections)-1):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.extend([tuple(reversed(range(n))),tuple((len(sections)-1)*n+i for i in range(n))])
    tail=mesh('Flexible muscular tail',vs,fs,olive,c);parts.append(tail)
    groups={n:tail.vertex_groups.new(name=n) for n in ['Tail1','Tail2','Tail3']}
    for v in tail.data.vertices:
        y=v.co.y
        if y<.85:weights={'Tail1':1}
        elif y<1.1:t=(y-.85)/.25;weights={'Tail1':1-t,'Tail2':t}
        elif y<1.3:t=(y-1.1)/.2;weights={'Tail2':1-t,'Tail3':t}
        else:weights={'Tail3':1}
        for name,w in weights.items():groups[name].add([v.index],w,'REPLACE')
    # Raised polygon scutes, arranged in four dorsal rows and a tail crest.
    for j in range(9):
        y=-.43+j*.12
        for x in [-.20,-.075,.075,.20]:
            z=.30+.20*math.sqrt(max(.05,1-(x/.34)**2-((y-.05)/.78)**2))
            v=[(x-.043,y-.05,z),(x+.043,y-.05,z),(x+.043,y+.05,z),(x-.043,y+.05,z),(x,y+.012,z+.065)]
            M('Raised dorsal scute',v,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],olive_light if j%3 else olive_dark)
    for j in range(8):
        y=.64+j*.11;z=.45-(y-.64)*.30;x=.08*max(0,1-(y-.64))
        bn='Tail1' if y<.91 else ('Tail2' if y<1.22 else 'Tail3')
        for sign in [-1,1]:I('Tail armour crest',(sign*x,y,z),(.045,.065,.055*(1-(y-.64)*.6)),olive_light,bn,1)
    for sign in [-1,1]:
        for j in range(7):I('Flank plate',(sign*.305,-.3+j*.125,.31),(.022,.065,.065),olive_dark if j%2 else olive_light,'Body',1)
    bones=[('Root',(0,0,0),(0,0,.16),None),('Body',(0,.12,.30),(0,-.42,.30),'Root'),('Head',(0,-.43,.32),(0,-.86,.32),'Body'),('Jaw',(0,-.48,.285),(0,-1.16,.285),'Head'),('Tail1',(0,.53,.28),(0,.88,.25),'Body'),('Tail2',(0,.88,.25),(0,1.18,.18),'Tail1'),('Tail3',(0,1.18,.18),(0,1.57,.09),'Tail2')]
    for sign,side in [(-1,'L'),(1,'R')]:
        for front,y in [(True,-.31),(False,.43)]:
            label=('Front' if front else 'Hind')+side
            hip=(sign*.23,y,.29);knee=(sign*.42,y+.10,.15);ankle=(sign*.46,y-.04,.055)
            bones.extend([(label,hip,knee,'Body'),(label+'Foot',knee,ankle,label),(label+'Toes',ankle,(sign*.46,y-.16,.055),label+'Foot')])
            C('Muscular upper leg',hip,knee,.09,.068,olive,label,8)
            C('Lower leg',knee,ankle,.068,.049,olive_dark,label+'Foot',8)
            I('Webbed clawed foot',(sign*.46,y-.085,.045),(.092,.11,.045),olive,label+'Toes',1)
            for j in range(3):C('Pale toe claw',(sign*.46+(j-1)*.045,y-.14,.04),(sign*.46+(j-1)*.045,y-.205,.022),.016,0,tooth,label+'Toes',5)
    skin=join(c,'CrocodileMesh',parts)
    armdata=bpy.data.armatures.new('CrocodileSkeleton');arm=bpy.data.objects.new('CrocodileRig',armdata);c.objects.link(arm)
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
    for name,a,b,parent in bones:
        eb=armdata.edit_bones.new(name);eb.head=a;eb.tail=b
        if parent:eb.parent=armdata.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');skin.parent=arm
    mod=skin.modifiers.new('Crocodile skin','ARMATURE');mod.object=arm
    animations(arm)
    export('saltwater_crocodile',c)
    manifest['assets']['saltwater_crocodile'].update({'forward':'+Z','length':2.91,'rig_node':'CrocodileRig','skeleton_node':'CrocodileRig/Skeleton3D','origin':'ground center','bones':[b[0] for b in bones],'animations':{'Idle':{'duration':2.,'loop':True},'Crawl':{'duration':1.2,'loop':True},'Swim':{'duration':1.6,'loop':True},'Attack':{'duration':.9,'loop':False,'bite_time':.42},'Eat':{'duration':1.4,'loop':True},'Death':{'duration':1.3,'loop':False}},'animation_note':'Animations are in-place. Set loop_mode from this manifest in Godot; glTF does not store playback looping.'})
    manifest['assets']['saltwater_crocodile']['crawl_gait']={'contact_fraction':.60,'stance_stride_m':.38,'nominal_speed_m_s':.38/(.60*1.2),'speed_scale_formula':'actual_horizontal_speed / 0.5277778','foot_ground_clearance_m':0,'toe_orientation':'level throughout contact','technique':'two-bone analytic IK baked to FK keys; diagonal pairs offset half a cycle'}
    return arm

def animations(arm):
    scene.render.fps=30;arm.animation_data_create()
    durations={'Idle':60,'Crawl':36,'Swim':48,'Attack':27,'Eat':42,'Death':39}
    def rotation(name,axis,angle):
        pb=arm.pose.bones[name];local=arm.data.bones[name].matrix_local.to_3x3().inverted()@Vector(axis);pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion(local.normalized(),angle)
    def solve_leg(name,target):
        side=-1 if name.endswith('L') else 1;y=-.31 if name.startswith('Front') else .43
        hip=Vector((side*.23,y,.29));old_knee=Vector((side*.42,y+.10,.15));old_ankle=Vector((side*.46,y-.04,.055))
        axis=(target-hip).normalized();dist=(target-hip).length;l1=(old_knee-hip).length;l2=(old_ankle-old_knee).length
        along=(l1*l1-l2*l2+dist*dist)/(2*dist);height=math.sqrt(max(0,l1*l1-along*along))
        pole=Vector((side, .35, .15));pole=(pole-axis*pole.dot(axis)).normalized();knee=hip+axis*along+pole*height
        q1=(old_knee-hip).rotation_difference(knee-hip);q2=(old_ankle-old_knee).rotation_difference(target-knee)
        for bone,q in [(name,q1),(name+'Foot',q1.inverted()@q2),(name+'Toes',q2.inverted())]:
            rest=arm.data.bones[bone].matrix_local.to_quaternion();arm.pose.bones[bone].rotation_quaternion=rest.inverted()@q@rest
    def crawl_leg(name,phase):
        side=-1 if name.endswith('L') else 1;y=-.31 if name.startswith('Front') else .43
        if phase<.60:offset=-.19+.38*phase/.60;lift=0
        else:u=(phase-.60)/.40;offset=.19-.38*u;lift=.105*math.sin(math.pi*u)
        solve_leg(name,Vector((side*.46,y+offset,.055+lift)))
    for name,frames in durations.items():
        action=bpy.data.actions.new(name);arm.animation_data.action=action;action['loop']=name in ['Idle','Crawl','Swim','Eat']
        for frame in range(frames+1):
            t=frame/frames;p=t*math.tau
            for pb in arm.pose.bones:pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0);pb.scale=(1,1,1)
            if name=='Idle':
                arm.pose.bones['Body'].scale=(1+math.sin(p)*.009,1,1+math.sin(p)*.014)
                rotation('Tail1',(0,0,1),math.sin(p)*.04);rotation('Jaw',(1,0,0),.025+.015*math.sin(p))
            if name=='Crawl':
                for i,leg in enumerate(['FrontL','HindR','FrontR','HindL']):
                    crawl_leg(leg,(t+(0 if i<2 else .5))%1)
                rotation('Head',(0,0,1),-.025*math.sin(p))
                for i,b in enumerate(['Tail1','Tail2','Tail3']):rotation(b,(0,0,1),.12*math.sin(p-i*.55))
            if name=='Swim':
                for leg in ['FrontL','HindL','FrontR','HindR']:
                    sign=-1 if leg.endswith('L') else 1
                    y=-.31 if leg.startswith('Front') else .43
                    solve_leg(leg,Vector((sign*.22,y+.26,.21)))
                for i,b in enumerate(['Tail1','Tail2','Tail3']):rotation(b,(0,0,1),.27*math.sin(p-i*.65))
                rotation('Body',(0,0,1),.07*math.sin(p+.6));rotation('Head',(0,0,1),-.05*math.sin(p+.6))
            if name=='Attack':
                opening=.72*math.sin(math.pi*min(1,t/.44)) if t<.44 else .06*max(0,1-(t-.44)/.25)
                rotation('Jaw',(1,0,0),opening);rotation('Head',(1,0,0),-opening*.70)
                # Lunge deforms the body briefly; Root translation remains zero.
                arm.pose.bones['Body'].location=(0,.19*math.sin(math.pi*t)**4,0)
                rotation('Tail1',(0,0,1),-.15*math.sin(math.pi*t))
            if name=='Eat':
                rotation('Jaw',(1,0,0),.14+.12*math.sin(p*2));rotation('Head',(0,0,1),.035*math.sin(p));rotation('Head',(1,0,0),.07*math.sin(p*2))
            if name=='Death':
                s=min(1,t/.70);s=s*s*(3-2*s)
                rotation('Body',(0,1,0),1.35*s);rotation('Head',(0,0,1),.16*s);rotation('Jaw',(1,0,0),.32*s)
                for i,b in enumerate(['Tail1','Tail2','Tail3']):rotation(b,(0,0,1),.24*s+math.sin(p*2-i)*.08*(1-s))
            for pb in arm.pose.bones:
                pb.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=pb.name);pb.keyframe_insert(data_path='location',frame=frame+1,group=pb.name);pb.keyframe_insert(data_path='scale',frame=frame+1,group=pb.name)
        for layer in action.layers:
            for action_strip in layer.strips:
                for bag in action_strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
        track=arm.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);track.mute=True
    arm.animation_data.action=None
    for pb in arm.pose.bones:pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0);pb.scale=(1,1,1)
    scene.frame_set(1)

def small_props():
    c=begin('food_bundle');ico('Leaf wrapped parcel',(0,0,.12),(.22,.16,.12),blanket,c,2)
    for y in [-.08,.08]:tube('Food cord',[(-.20,y,.11),(-.14,y,.215),(0,y,.25),(.14,y,.215),(.20,y,.11)],.008,rope,c,5)
    tube('Cross cord',[(0,-.15,.12),(0,-.10,.23),(0,0,.25),(0,.10,.23),(0,.15,.12)],.008,rope,c,5)
    join(c,'FoodBundleMesh');export('food_bundle',c)
    c=begin('medical_kit');cube('Linen medical satchel',(0,0,.13),(.36,.18,.26),cream,c,.035)
    tube('Medical case handle',[(-.085,0,.24),(-.085,0,.32),(.085,0,.32),(.085,0,.24)],.012,wood,c,6)
    patch=material('Medical patch muted green',(.12,.28,.17))
    cube('Medical label',(0,-.094,.14),(.14,.008,.08),patch,c,.009)
    cube('First aid line',(0,-.101,.14),(.08,.006,.012),cream,c)
    join(c,'MedicalKitMesh');export('medical_kit',c)

def finish(arm):
    manifest['assets']['bed']['size_x_y_z']=[1.229315,.95,1.93]
    manifest['assets']['chest']['size_x_y_z']=[1.15,.654,.609461]
    manifest['assets']['cabin_lamp']['size_x_y_z']=[.372877,.601299,.362221]
    manifest['assets']['saltwater_crocodile']['size_x_y_z']=[1.084574,.560073,2.91]
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');(SOURCE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'海岸生存_模型与动画.blend'))
    if '--no-previews' in sys.argv:
        print('SURVIVAL_ASSETS_COMPLETE '+str(OUT));return
    for name,c in P.COLLECTIONS.items():
        for o in c.objects:o.hide_render=name!='saltwater_crocodile'
    floor=material('Preview sand',(.40,.37,.29));cube('Preview floor',(0,0,-.045),(8,8,.08),floor,scene.collection)
    w=bpy.data.worlds.new('Preview world');scene.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[1].default_value=.45
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,5));bpy.context.object.data.energy=650;bpy.context.object.data.size=5
    bpy.ops.object.camera_add(location=(3.2,-4,2.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.1,.2))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.75;scene.camera=cam
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
    for name,frame in [('Idle',1),('Attack',7),('Swim',12),('Crawl',10),('Death',39)]:
        arm.animation_data.action=bpy.data.actions[name];scene.frame_set(frame);scene.render.filepath=str(SOURCE/(name+'_preview.png'));bpy.ops.render.render(write_still=True)
    arm.animation_data.action=None;scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'海岸生存_预览场景.blend'))
    print('SURVIVAL_ASSETS_COMPLETE '+str(OUT))

furniture();arm=crocodile();small_props();finish(arm)
