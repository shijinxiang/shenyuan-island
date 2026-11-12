import bpy,json,math
from pathlib import Path
from mathutils import Vector
p=Path(__file__).parent
s=bpy.context.scene;a=bpy.data.objects['GeneralSkeleton'];body=bpy.data.objects['C01_Body']
finger_groups={g.index:g.name for g in body.vertex_groups if g.name.startswith('RightHand')}
vertex_bones={v.index:[(finger_groups[g.group],g.weight) for g in v.groups if g.group in finger_groups] for v in body.data.vertices}
records=[]
grip=Vector(json.loads((p/'watering_grip_calibration.json').read_text())['hand_local_grip_center'])
for frame in range(1,170):
    s.frame_set(frame);bpy.context.view_layer.update()
    inv=(a.matrix_world @ a.pose.bones['RightHand'].matrix).inverted()
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    penetration=[]
    for v in evaluated.data.vertices:
        groups=vertex_bones.get(v.index,[])
        if sum(w for _,w in groups)<.5:continue
        pt=inv @ evaluated.matrix_world @ v.co
        if -.1 <= pt.x <= .09:
            r=math.hypot(pt.y-grip.y,pt.z-grip.z)
            if r<.026:penetration.append({'vertex':v.index,'depth':.026-r,'groups':groups,'position':list(pt)})
    records.append({'frame':frame,'penetrating_vertices':len(penetration),'max_depth':max([v['depth'] for v in penetration],default=0),'worst':sorted(penetration,key=lambda x:-x['depth'])[:5]})
(p/'watering_grip_skin_validation.json').write_text(json.dumps(records,indent=2),encoding='utf8')
print('SKIN_COLLISION',json.dumps(records))
