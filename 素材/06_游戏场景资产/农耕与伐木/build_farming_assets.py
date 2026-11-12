"""Rebuild the low-poly island farming library using Blender 5.2.

Run: blender --background --python build_farming_assets.py
Models use metres. Authoring Z-up; GLB exporter converts to Godot Y-up.
This generator never reads or changes an open Blender session.
"""
import bpy, math, random, json, os
import numpy as np
from mathutils import Vector
from pathlib import Path

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[2]
OUT = PROJECT / '游戏' / 'assets' / 'farming'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(611)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
ASSETS = {}
COLLECTIONS = {}
MATS = {}

def material(name, color, roughness=.8, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    MATS[name] = m
    return m

wood = material('Honey ash handle', (.39,.21,.085))
wood_light = material('Pale cut wood', (.65,.45,.24))
wood_ring = material('Endgrain rings', (.39,.24,.11))
bark = material('Palm bark umber', (.24,.13,.065))
bark_light = material('Palm bark facets', (.34,.215,.105))
steel = material('Forged blue steel', (.18,.25,.28), .42,.65)
edge = material('Honed steel edge', (.46,.55,.55),.3,.7)
leather = material('Dark leather bindings', (.19,.10,.055))
green = material('Leaf olive green', (.23,.39,.065))
green_light = material('Leaf sunlit green', (.39,.56,.11))
green_dark = material('Leaf shaded green', (.105,.245,.038))
stem_mat = material('Plant stems', (.30,.42,.075))
ivory = material('Turnip ivory flesh', (.88,.83,.64))
purple = material('Turnip rose shoulder', (.69,.13,.22))
red = material('Tomato ripe red', (.74,.075,.035),.48)
red_light = material('Tomato red highlight', (.88,.13,.045),.5)
unripe = material('Unripe fruit', (.40,.55,.12))
orange = material('Pumpkin burnt orange', (.83,.29,.035))
orange_light = material('Pumpkin golden facets', (.98,.43,.055))
orange_dark = material('Pumpkin rib shadows', (.61,.18,.022))
flower_mat = material('Squash and tomato blossoms', (.99,.68,.09))
watercan_mat = material('Watering can sage enamel', (.22,.38,.32),.47,.25)
watercan_dark = material('Watering can rim and interior', (.12,.22,.18),.52,.35)

def begin(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    COLLECTIONS[name] = c
    return c

def adopt(obj, name, mat, collection):
    obj.name = name
    if mat: obj.data.materials.append(mat)
    for c in list(obj.users_collection): c.objects.unlink(obj)
    collection.objects.link(obj)
    return obj

def mesh(name, verts, faces, mat, collection):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if mat: me.materials.append(mat)
    return ob

def cone(name, a, b, r1, r2, mat, collection, sides=8):
    delta = Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r1, radius2=r2, depth=delta.length, location=(Vector(a)+Vector(b))*.5)
    ob = bpy.context.object
    ob.rotation_euler = delta.to_track_quat('Z','Y').to_euler()
    return adopt(ob,name,mat,collection)

def ico(name, p, scale, mat, collection, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=p)
    ob = bpy.context.object
    ob.scale = scale
    return adopt(ob,name,mat,collection)

def cube(name, p, scale, mat, collection, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    ob = adopt(bpy.context.object,name,mat,collection)
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new('Small softened edges','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob

def tube(name, points, radius, mat, collection, sides=6):
    vs=[]; fs=[]
    for i,p in enumerate(points):
        axis = Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        axis.normalize()
        side = axis.cross(Vector((0,0,1)))
        if side.length<.01: side=axis.cross(Vector((0,1,0)))
        side.normalize(); up=axis.cross(side).normalized()
        r=radius[i] if isinstance(radius,(list,tuple)) else radius
        for j in range(sides):
            v=Vector(p)+r*(math.cos(j*math.tau/sides)*side+math.sin(j*math.tau/sides)*up)
            vs.append(v)
    for i in range(len(points)-1):
        for j in range(sides): fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    fs.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,mat,collection)

def leaf(name, base, tip, width, collection, lobed=False):
    """A folded closed leaf with actual underside and a raised midrib."""
    a,b=Vector(base),Vector(tip); d=b-a
    side=d.cross(Vector((0,0,1)))
    if side.length<.001: side=Vector((1,0,0))
    side.normalize()
    verts=[a]
    stations=[(.23,.68),(.48,1),(.72,.72)]
    for f,w in stations:
        center=a+d*f+Vector((0,0,width*.16*math.sin(f*math.pi)))
        verts.extend([center-side*width*w*.5,center+Vector((0,0,width*.12)),center+side*width*w*.5])
    verts.append(b)
    faces=[(0,1,2),(0,2,3)]
    for i in [1,4]: faces.extend([(i,i+3,i+4,i+1),(i+1,i+4,i+5,i+2)])
    faces.extend([(7,10,8),(8,10,9)])
    boundary=[0,1,4,7,10,9,6,3]
    under=len(verts); verts.append((a+b)*.5-Vector((0,0,.006)))
    for i in range(len(boundary)): faces.append((boundary[(i+1)%len(boundary)],boundary[i],under))
    ob=mesh(name,verts,faces,green,collection)
    ob.data.materials.append(green_light);ob.data.materials.append(green_dark)
    for poly in ob.data.polygons: poly.material_index = 2 if poly.index>=8 else poly.index%2
    return ob

def make_tools():
    c=begin('axe')
    cone('Shaped ash haft',(0,0,.025),(.025,0,.91),.043,.034,wood,c,8)
    cone('Handle end cap',(0,0,0),(0,0,.045),.047,.043,wood_light,c,8)
    for z in [.17,.24]: cone('Linen grip binding',(.004,0,z),(.006,0,z+.045),.046,.046,wood_light,c,8)
    # Forged wedge: thick poll around the handle, broad thin cutting edge.
    profile=[(-.075,.77),(-.075,.96),(.09,.96),(.31,.99),(.34,.69),(.14,.77)]
    vs=[]
    for side in [-1,1]:
        for x,z in profile: vs.append((x,side*(.042 if x<.15 else .011),z))
    n=len(profile); fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n): fs.append((i,(i+1)%n,(i+1)%n+n,i+n))
    head=mesh('Forged axe head',vs,fs,steel,c)
    mesh('Bright sharpened bit',[(.29,-.014,.985),(.34,-.011,.69),(.355,0,.685),(.325,0,1.0),(.29,.014,.985),(.34,.011,.69)],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)],edge,c)
    cone('Upper ferrule',(.023,0,.78),(.025,0,.84),.047,.047,steel,c,8)
    join_and_export('axe',[0,.32,0])
    c=begin('hoe')
    cone('Long ash haft',(0,0,.025),(0,0,1.12),.032,.03,wood,c,8)
    for z in [.16,.22]: cone('Linen grip binding',(0,0,z),(0,0,z+.04),.036,.036,wood_light,c,8)
    cone('Top ferrule',(0,0,1.00),(0,0,1.10),.041,.041,steel,c,8)
    tube('Bent steel socket',[(0,0,1.06),(.08,0,1.05),(.16,0,.95)],.034,steel,c,6)
    vs=[(.13,-.08,.98),(.13,.08,.98),(.19,.16,.79),(.19,-.16,.79),(.17,-.08,.99),(.17,.08,.99),(.22,.16,.79),(.22,-.16,.79)]
    mesh('Broad hoe blade',vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],steel,c)
    mesh('Honed hoe lip',[(.19,-.16,.79),(.19,.16,.79),(.23,.16,.78),(.23,-.16,.78)],[(0,1,2,3)],edge,c)
    join_and_export('hoe',[0,.38,0])
    c=begin('watering_can')
    # Open, thick-walled tapered body: no opaque lid over the fill opening.
    n=12;vs=[];fs=[]
    for r,z in [(.20,.03),(.19,.36),(.162,.36),(.172,.055)]:
        for i in range(n): vs.append((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z))
    for band in range(3):
        for i in range(n):fs.append((band*n+i,band*n+(i+1)%n,(band+1)*n+(i+1)%n,(band+1)*n+i))
    fs.append(tuple(reversed(range(n))));fs.append(tuple(3*n+i for i in range(n)))
    body=mesh('Open enamel body',vs,fs,watercan_mat,c);body.data.materials.append(watercan_dark)
    for p in body.data.polygons:
        if p.index>=2*n:p.material_index=1
    cone('Cream bottom band',(0,0,0),(0,0,.045),.205,.205,wood_light,c,12)
    ring('Rolled top rim',(0,0,.36),.178,.018,watercan_mat,c,n=12)
    tube('Carry arch',[(-.15,0,.33),(-.15,0,.48),(-.10,0,.55),(.09,0,.55),(.16,0,.48),(.16,0,.33)],.026,watercan_mat,c,6)
    tube('Side loop handle',[(.16,0,.29),(.28,0,.32),(.34,0,.25),(.33,0,.11),(.19,0,.08)],.025,watercan_mat,c,6)
    cone('Tapered pouring spout',(-.16,0,.12),(-.38,0,.34),.055,.034,watercan_mat,c,8)
    a=Vector((-.39,0,.35));b=Vector((-.435,0,.395))
    cone('Brass rose sprinkler',a,b,.077,.083,wood_light,c,12)
    axis=(b-a).normalized();u=Vector((0,1,0));v=axis.cross(u).normalized()
    for j in range(7):
        pos=b+axis*.001+(Vector((0,0,0)) if j==0 else .052*(math.cos(j*math.tau/6)*u+math.sin(j*math.tau/6)*v))
        cone('Sprinkler hole',pos,pos+axis*.002,.008,.008,watercan_dark,c,6)
    # A small cream five-petal flower emblem on the visible body face.
    for j in range(5):
        a=j*math.tau/5
        ico('Cream flower petal',(.04*math.cos(a),-.188,.205+.04*math.sin(a)),(.031,.007,.031),ivory,c,1)
    ico('Flower center',(0,-.200,.205),(.024,.008,.024),flower_mat,c,1)
    join_and_export('watering_can',[0,.55,0])

def make_wood():
    c=begin('log')
    cone('Faceted bark',(0,-.40,.17),(0,.40,.17),.17,.15,bark,c,12)
    for i in range(7):
        y=-.36+i*.115
        cone('Palm bark growth band',(0,y,.17),(0,y+.06,.17),.172-i*.0028,.168-i*.0028,bark_light,c,12)
    for sign in [-1,1]:
        y=sign*.402
        cone('Cut timber end',(0,y,.17),(0,y+sign*.005,.17),.145,.145,wood_light,c,12)
        for radius in [.048,.091,.13]: ring('Visible endgrain',(0,y+sign*.006,.17),radius,.004,wood_ring,c,'XZ',12)
    # A broken branch nub adds a silhouette cue without violating the floor.
    cone('Branch knot',(.105,.10,.25),(.19,.11,.32),.045,.033,bark_light,c,7)
    cone('Branch cut',(.188,.11,.318),(.193,.11,.324),.031,.031,wood_light,c,7)
    join_and_export('log')
    c=begin('stump')
    n=12;vs=[]
    for level,(r,z) in enumerate([(.31,0),(.235,.08),(.20,.33),(.205,.36)]):
        for i in range(n):
            a=i*math.tau/n;rr=r*(1+.06*math.sin(i*2.1+level))
            vs.append((rr*math.cos(a),rr*math.sin(a),z))
    fs=[]
    for k in range(3):
        for i in range(n):fs.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
    fs.append(tuple(reversed(range(n))))
    ob=mesh('Flared stump bark',vs,fs,bark,c);ob.data.materials.append(bark_light)
    for p in ob.data.polygons:p.material_index=p.index%3==0
    cone('Stump fresh cut',(0,0,.352),(0,0,.365),.19,.19,wood_light,c,12)
    for radius in [.045,.091,.14,.175]:ring('Stump annual rings',(0,0,.368),radius,.0045,wood_ring,c,n=12)
    for i in range(6):
        a=i*math.tau/6+.1
        tube('Spreading root',[(.16*math.cos(a),.16*math.sin(a),.16),(.29*math.cos(a),.29*math.sin(a),.065),(.40*math.cos(a),.40*math.sin(a),.025)],[.07,.052,.023],bark_light,c,5)
    join_and_export('stump')

def write_texture(name, rgb):
    h,w,_=rgb.shape
    im=bpy.data.images.new(name,width=w,height=h,alpha=True)
    rgba=np.concatenate([np.clip(rgb,0,1),np.ones((h,w,1),dtype=np.float32)],axis=2).astype(np.float32)
    im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save()
    return im

def make_soil():
    rng=np.random.default_rng(611);n=512
    yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
    noise=rng.normal(0,.012,(n,n)).astype(np.float32)
    coarse=np.sin(xx*31+np.cos(yy*24))*np.sin(yy*38+xx*8)*.018
    ridges=(.5+.5*np.cos(xx*math.tau*5))*.055
    # Organic, distorted Voronoi cell boundaries produce an actual crack texture.
    wx=xx+.018*np.sin(yy*31)+.009*np.sin(yy*79)
    wy=yy+.015*np.sin(xx*28)+.008*np.sin(xx*57)
    nearest=np.full((n,n),100.,dtype=np.float32);second=nearest.copy()
    for cy in np.linspace(-.1,1.1,9):
        for cx in np.linspace(-.1,1.1,9):
            px=cx+rng.uniform(-.045,.045);py=cy+rng.uniform(-.045,.045)
            d=np.sqrt((wx-px)**2+(wy-py)**2)
            new=np.minimum(nearest,d);second=np.minimum(second,np.maximum(nearest,d));nearest=new
    crack=(second-nearest)<(.003+.0015*np.sin(xx*120)*np.sin(yy*83))
    crack_edge=(second-nearest)<.008
    grain=noise+coarse
    dry=np.stack([.51+grain+ridges,.32+grain*.7+ridges*.75,.17+grain*.45+ridges*.45],axis=2)
    dry[crack_edge]*=.85;dry[crack]*=np.array([.43,.38,.30])
    wet=np.stack([.205+grain*.65+ridges*.52,.115+grain*.45+ridges*.30,.060+grain*.27+ridges*.17],axis=2)
    # Fine grit flecks and damp channels are baked into the wet state.
    flecks=rng.random((n,n))>.994;wet[flecks]+=np.array([.07,.055,.03])
    dry_im=write_texture('soil_dry_albedo',dry);wet_im=write_texture('soil_wet_albedo',wet)
    dr=write_texture('soil_dry_roughness',np.repeat((.92+noise*.3)[...,None],3,axis=2))
    wr=write_texture('soil_wet_roughness',np.repeat(np.clip(.53+noise*2-ridges,0,1)[...,None],3,axis=2))
    soil=material('Cultivated earth dry textured',(1,1,1),.92)
    nodes=soil.node_tree.nodes;p=nodes.get('Principled BSDF');tex=nodes.new('ShaderNodeTexImage');tex.image=dry_im;soil.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    c=begin('soil_plot');N=29;vs=[];fs=[]
    # Fully volumetric slab. 29 by 29 top grid accommodates per-vertex terrain fitting.
    for j in range(N):
        for i in range(N):
            x=-.7+1.4*i/(N-1);y=-.7+1.4*j/(N-1)
            edgefade=min(1,min(i,j,N-1-i,N-1-j)/1.7)
            z=.081+edgefade*(.032*(.5+.5*math.cos((x+.7)/1.4*math.tau*5))+.010*math.sin(x*53+y*19)*math.cos(y*41))
            if i in (0,N-1):x+=.009*math.sin(j*2.4)
            if j in (0,N-1):y+=.009*math.sin(i*2.2)
            vs.append((x,y,z))
    for j in range(N-1):
        for i in range(N-1):
            q=j*N+i
            if (i+j)%2:fs.extend([(q,q+1,q+N),(q+1,q+N+1,q+N)])
            else:fs.extend([(q,q+1,q+N+1),(q,q+N+1,q+N)])
    boundary=list(range(N))+[j*N+N-1 for j in range(1,N)]+[(N-1)*N+i for i in range(N-2,-1,-1)]+[j*N for j in range(N-2,0,-1)]
    bottom=[]
    for idx in boundary:
        x,y,z=vs[idx];bottom.append(len(vs));vs.append((x,y,0))
    for i,idx in enumerate(boundary):
        nxt=(i+1)%len(boundary);fs.append((idx,bottom[i],bottom[nxt],boundary[nxt]))
    center=len(vs);vs.append((0,0,0))
    for i in range(len(bottom)):fs.append((center,bottom[(i+1)%len(bottom)],bottom[i]))
    ob=mesh('Soil surface ridges and closed sides',vs,fs,soil,c)
    uv=ob.data.uv_layers.new(name='SoilUV')
    for p in ob.data.polygons:
        for li in p.loop_indices:
            v=ob.data.vertices[ob.data.loops[li].vertex_index].co
            uv.data[li].uv=((v.x+.7)/1.4,(v.y+.7)/1.4)
    join_and_export('soil_plot')
    for state,rough in [('dry',.92),('wet',.53)]:
        (OUT/f'soil_{state}.tres').write_text('[gd_resource type="StandardMaterial3D" load_steps=3 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/farming/soil_'+state+'_albedo.png" id="1"]\n[ext_resource type="Texture2D" path="res://assets/farming/soil_'+state+'_roughness.png" id="2"]\n\n[resource]\nresource_name = "Cultivated soil '+state+'"\nalbedo_texture = ExtResource("1")\nroughness = '+str(rough)+'\nroughness_texture = ExtResource("2")\nroughness_texture_channel = 0\n',encoding='utf-8')

def make_turnip():
    for stage in range(4):
        c=begin('turnip_stage_'+str(stage))
        if stage==0:
            cone('New sprout',(0,0,0),(0,0,.13),.012,.008,stem_mat,c,6)
            for sign in [-1,1]:leaf('Cotyledon',(0,0,.10),(sign*.105,sign*.025,.16),.065,c)
        else:
            radius=[0,.048,.10,.155][stage]
            height=[0,.055,.11,.17][stage]
            # Pale lower bulb and rose shoulder share a continuous faceted profile.
            n=12;vs=[];fs=[]
            for r,z in [(radius*.06,0),(radius*.65,height*.20),(radius,height*.62),(radius*.93,height),(radius*.46,height*1.12)]:
                for i in range(n):
                    a=i*math.tau/n;vs.append((r*math.cos(a),r*math.sin(a),z))
            for k in range(4):
                for i in range(n):fs.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
            fs.append(tuple(reversed(range(n))));fs.append(tuple(4*n+i for i in range(n)))
            bulb=mesh('Faceted turnip bulb',vs,fs,ivory,c);bulb.data.materials.append(purple)
            for p in bulb.data.polygons:p.material_index=1 if p.index>=2*n else 0
            radial_leaves(c,[0,4,6,9][stage],height*1.25,[0,.18,.24,.32][stage],[0,.09,.12,.145][stage],stage+7)
            # Upright central new leaves diversify the rosette silhouette.
            for i in range(stage):
                a=i*2.4;leaf('Upright new leaf',(0,0,height),(.10*math.cos(a),.10*math.sin(a),height+.20+stage*.025),.08,c)
        join_and_export('turnip_stage_'+str(stage))

def star_blossom(name,p,r,collection):
    p=Vector(p)
    for i in range(5):
        a=i*math.tau/5
        ico(name+' petal',p+Vector((math.cos(a)*r*.65,math.sin(a)*r*.65,0)),(r*.52,r*.43,r*.16),flower_mat,collection,1)
    ico(name+' center',p+Vector((0,0,r*.12)),(r*.23,r*.23,r*.18),orange,collection,1)

def tomato_fruit(p,r,ripe,c):
    ico('Ripe tomato' if ripe else 'Young green tomato',p,(r,r,r*.88),red if ripe else unripe,c,2)
    p=Vector(p)
    for j in range(5):
        a=j*math.tau/5
        leaf('Tomato star calyx',p+Vector((0,0,r*.85)),p+Vector((math.cos(a)*r*.75,math.sin(a)*r*.75,r*.9)),r*.22,c)

def make_tomato():
    for stage in range(4):
        c=begin('tomato_stage_'+str(stage));h=[.17,.40,.64,.82][stage]
        tube('Tomato main stem',[(0,0,0),(.008,0,h*.35),(-.012,.005,h*.70),(.015,0,h)],[.014,.013,.01,.006],stem_mat,c,6)
        if stage==0:
            for sign in [-1,1]:leaf('First true leaf',(0,0,h*.65),(sign*.13,0,h*.95),.075,c)
        else:
            for i in range([0,5,7,8][stage]):
                a=i*2.399;z=h*(.28+i*.065);reach=.16+stage*.035
                end=Vector((math.cos(a)*reach,math.sin(a)*reach,z+.06));base=Vector((0,0,z))
                cone('Side branch',base,end,.008,.004,stem_mat,c,5)
                tip=end+Vector((math.cos(a)*.08,math.sin(a)*.08,-.025))
                leaf('Serrated tomato terminal leaf',base.lerp(end,.6),tip,.08+stage*.008,c)
                for s in [-1,1]:
                    mid=base.lerp(end,.50);d=Vector((math.cos(a+s*.8),math.sin(a+s*.8),.15))*.12
                    leaf('Compound tomato leaflet',mid,mid+d,.06,c)
            if stage>=2:
                fruits=[(-.16,-.085,h*.52),(.16,.045,h*.71)]
                if stage==3:fruits.append((.075,-.15,h*.38))
                for i,p in enumerate(fruits):
                    r=.055 if stage==2 else [.085,.074,.065][i]
                    top=Vector(p)+Vector((0,0,r))
                    cone('Fruit pedicel',(0,0,p[2]+.08),top,.006,.004,stem_mat,c,5)
                    tomato_fruit(p,r,stage==3,c)
                for i in range(3):
                    a=i*2.2;p=(.13*math.cos(a),.13*math.sin(a),h*.83)
                    cone('Flower pedicel',(0,0,h*.78),p,.004,.002,stem_mat,c,5)
                    star_blossom('Yellow tomato flower',p,.033,c)
        join_and_export('tomato_stage_'+str(stage))

def pumpkin_leaf(base,tip,width,c):
    """Broad five-point maple-like squash leaf with a folded solid underside."""
    a,b=Vector(base),Vector(tip);d=b-a;side=d.cross(Vector((0,0,1))).normalized()
    outline=[a,a+d*.25-side*width*.48,a+d*.50-side*width*.40,a+d*.70-side*width*.47,b,a+d*.70+side*width*.47,a+d*.50+side*width*.40,a+d*.25+side*width*.48]
    center=a+d*.46+Vector((0,0,.025));vs=outline+[center,center-Vector((0,0,.032))]
    fs=[]
    for i in range(8):fs.append((i,(i+1)%8,8));fs.append(((i+1)%8,i,9))
    ob=mesh('Broad folded squash leaf',vs,fs,green,c);ob.data.materials.append(green_light);ob.data.materials.append(green_dark)
    for p in ob.data.polygons:p.material_index=2 if p.index%2 else (p.index//2)%2

def pumpkin_fruit(center,r,ripe,c):
    n=48;levels=9;vs=[];fs=[];center=Vector(center)
    for j in range(levels+1):
        theta=math.pi*j/levels
        for i in range(n):
            a=i*math.tau/n;rad=r*math.sin(theta)*(1+.075*math.cos(a*8))
            z=r*.79*math.cos(theta)
            vs.append(center+Vector((rad*math.cos(a),rad*math.sin(a),z)))
    for j in range(levels):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    ob=mesh('Eight ribbed mature pumpkin' if ripe else 'Small unripe squash',vs,fs,orange if ripe else unripe,c)
    if ripe:
        ob.data.materials.append(orange_light);ob.data.materials.append(orange_dark)
        for p in ob.data.polygons:p.material_index=[1,0,2,2,0,1][p.index%n%6]
    tube('Crooked pumpkin stalk',[center+Vector((0,0,r*.72)),center+Vector((.01,0,r+.025)),center+Vector((.05,0,r+.06))],[.024,.019,.012],stem_mat,c,6)

def make_pumpkin():
    for stage in range(4):
        c=begin('pumpkin_stage_'+str(stage))
        if stage==0:
            cone('Pumpkin sprout',(0,0,0),(0,0,.12),.014,.009,stem_mat,c,6)
            for sign in [-1,1]:pumpkin_leaf((0,0,.09),(sign*.15,sign*.025,.19),.12,c)
        else:
            spread=[0,.28,.38,.44][stage]
            paths=[(-spread,.08,.045),(-spread*.5,-.05,.06),(0,0,.065),(spread*.55,.045,.07),(spread,-.08,.08)]
            tube('Creeping squash vine',paths,.015,stem_mat,c,6)
            for i in range([0,5,7,9][stage]):
                a=i*2.399+.3;r=spread*(.62 if i%2 else .9)
                base=Vector(paths[i%len(paths)]);mid=Vector((r*math.cos(a),r*math.sin(a),.15+(i%3)*.045))
                cone('Squash leaf stalk',base,mid,.010,.006,stem_mat,c,5)
                end=mid+Vector((math.cos(a)*.15,math.sin(a)*.15,.055))
                pumpkin_leaf(mid,end,.16+stage*.018,c)
            for sign in [-1,1]:
                pts=[]
                for k in range(14):
                    a=k*math.pi*2/13;r=.045*(1-k/18)
                    pts.append((sign*(spread+.04+r*math.cos(a)),.06+r*math.sin(a),.14+k*.003))
                tube('Coiled tendril',pts,.005,stem_mat,c,5)
            if stage>=2:
                r=.105 if stage==2 else .235
                pumpkin_fruit((.09,-.09,r*.79),r,stage==3,c)
                bp=(-.19,-.10,.23)
                cone('Blossom stem',(-.16,-.04,.055),bp,.009,.006,stem_mat,c,5)
                star_blossom('Golden squash flower',bp,.065,c)
        join_and_export('pumpkin_stage_'+str(stage))

def save_and_preview():
    manifest={'format_version':1,'units':'metres','coordinate_system':'Godot Y-up; local floor Y=0; front -Z','authoring':'Blender 5.2; original low-poly meshes derived from supplied composite concept','reference_image':str(PROJECT/'素材'/'03_参考图与资料'/'农耕与伐木'/'农耕伐木_复合参考.png'),'soil':{'size_xz':[1.418,1.418],'top_height_range':[.071,.113],'bottom_y':0,'terrain_fit':'Add sampled terrain height to each local vertex Y, including sides and bottom. Root has identity transform. Recompute normals after deformation.','dry_material':'res://assets/farming/soil_dry.tres','wet_material':'res://assets/farming/soil_wet.tres','textures':['soil_dry_albedo.png','soil_wet_albedo.png','soil_dry_roughness.png','soil_wet_roughness.png']},'stage_meanings':['sprout','vegetative','immature fruit/flower','harvest-ready'],'suggested_growth_days':{'turnip':3,'tomato':4,'pumpkin':5},'assets':ASSETS}
    manifest['tools']={name:{'grip':ASSETS[name]['grip_local_godot']} for name in ['axe','hoe','watering_can']}
    manifest['soil']['top_height_range']=[.071,.123]
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (SOURCE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    # Preserve the clean library at the correct origins in the master .blend.
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'农耕与伐木_模型库.blend'))
    # Contact-sheet staging exists only in the preview .blend, never in exported assets.
    positions={'axe':(-2.8,2.4,0),'hoe':(-1.65,2.4,0),'watering_can':(-.4,2.4,0),'stump':(.75,2.4,0),'log':(1.9,2.4,0),'soil_plot':(3.35,2.4,0)}
    for row,crop in enumerate(['turnip','tomato','pumpkin']):
        for stage in range(4):positions[f'{crop}_stage_{stage}']=(-2.25+stage*1.55,.5-row*1.5,0)
    for name,pos in positions.items():
        for ob in COLLECTIONS[name].objects:ob.location=pos
    cream=material('Preview backdrop',(.69,.65,.55))
    cube('Preview ground',(0,0,-.06),(12,10,.1),cream,scene.collection)
    world=bpy.data.worlds.new('Soft studio');scene.world=world;world.use_nodes=True
    world.node_tree.nodes.get('Background').inputs[0].default_value=(.7,.75,.8,1)
    world.node_tree.nodes.get('Background').inputs[1].default_value=.7
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,7));key=bpy.context.object;key.data.energy=1800;key.data.shape='DISK';key.data.size=6
    bpy.ops.object.camera_add(location=(7,-10,10));cam=bpy.context.object;target=Vector((.25,0,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=10.5;scene.camera=cam
    scene.render.engine='CYCLES';scene.cycles.samples=32
    scene.render.resolution_x=1800;scene.render.resolution_y=1500;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(SOURCE/'农耕与伐木_模型总览.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'农耕与伐木_预览场景.blend'))
    bpy.ops.render.render(write_still=True)
    print('FARMING_ASSETS_COMPLETE '+str(OUT))
    print(json.dumps({k:{'triangles':v['triangles'],'vertices':v['vertices']} for k,v in ASSETS.items()}))

def radial_leaves(collection, count, height, reach, width, seed=0):
    rng=random.Random(seed)
    for i in range(count):
        angle=i*math.tau/count+rng.uniform(-.16,.16)
        tip=(math.cos(angle)*reach*rng.uniform(.8,1),math.sin(angle)*reach*rng.uniform(.8,1),height+rng.uniform(.02,.13))
        base=(0,0,height*.6)
        mid=Vector(base).lerp(Vector(tip),.28)
        cone('Leaf petiole',base,mid,.009,.005,stem_mat,collection,5)
        leaf('Folded leaf',mid,tip,width,collection)

def ring(name, center, radius, tube_radius, mat, collection, plane='XY', n=16):
    points=[]
    for i in range(n+1):
        a=i*math.tau/n
        if plane=='XY': d=(radius*math.cos(a),radius*math.sin(a),0)
        elif plane=='XZ': d=(radius*math.cos(a),0,radius*math.sin(a))
        else: d=(0,radius*math.cos(a),radius*math.sin(a))
        points.append(Vector(center)+Vector(d))
    return tube(name,points,tube_radius,mat,collection,4)

def join_and_export(name, grip=None):
    c=COLLECTIONS[name]
    bpy.ops.object.select_all(action='DESELECT')
    obs=[o for o in c.objects if o.type=='MESH']
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name+'_mesh'
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    floor=min(v.co.z for v in ob.data.vertices)
    for v in ob.data.vertices:v.co.z-=floor
    scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    # Recalculate all closed component normals consistently before export.
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    if not ob.data.uv_layers:
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
    ob.data.calc_loop_triangles()
    coords=[v.co for v in ob.data.vertices]
    mins=[min(v[i] for v in coords) for i in range(3)];maxs=[max(v[i] for v in coords) for i in range(3)]
    ASSETS[name]={'path':'res://assets/farming/'+name+'.glb','vertices':len(coords),'triangles':len(ob.data.loop_triangles),'mesh_node':ob.name,'materials':[m.name for m in ob.data.materials], 'bounds_godot':{'min':[mins[0],mins[2],-maxs[1]],'max':[maxs[0],maxs[2],-mins[1]]},'mesh_node_transform':'identity','uv_layers':len(ob.data.uv_layers)}
    if grip: ASSETS[name]['grip_local_godot']=grip
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_extras=True)
    return ob

if __name__=='__main__':
    make_tools();make_wood();make_soil();make_turnip();make_tomato();make_pumpkin();save_and_preview()
