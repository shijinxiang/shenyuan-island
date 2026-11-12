import bpy,json
from pathlib import Path
from mathutils import Vector
p=Path(__file__).parent
s=bpy.context.scene;s.frame_set(68)
a=bpy.data.objects['GeneralSkeleton']
h=a.pose.bones['RightHand'].matrix.copy()
hand_inv=h.inverted()
info={'hand_matrix':[list(r) for r in h],'bones':{}}
for b in a.pose.bones:
    if b.name.startswith('RightHand'):
        info['bones'][b.name]={'parent':b.parent.name,'head_handlocal':list(hand_inv @ b.head),'tail_handlocal':list(hand_inv @ b.tail),'local_quaternion':list(b.rotation_quaternion),'rest_matrix':[list(r) for r in b.bone.matrix_local]}
before=set(s.objects)
bpy.ops.import_scene.gltf(filepath='D:/浪费GPT额度/小温的游戏/游戏/assets/farming/watering_can.glb')
info['can_objects']=[]
for o in set(s.objects)-before:
    if o.type=='MESH':
        info['can_objects'].append({'name':o.name,'min':[min((o.matrix_world@v.co)[i] for v in o.data.vertices) for i in range(3)],'max':[max((o.matrix_world@v.co)[i] for v in o.data.vertices) for i in range(3)],'vertices':len(o.data.vertices)})
(p/'watering_grip_inspection.json').write_text(json.dumps(info,indent=2),encoding='utf8')
print('GRIP_INSPECTION',json.dumps(info))
