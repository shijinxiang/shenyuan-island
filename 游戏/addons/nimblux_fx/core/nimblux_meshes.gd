class_name NimbluxMeshes
extends RefCounted
## Index meshes shared by every effect (Lite). Each vertex stores its element index in x and
## its corner in UV; the shaders compute the real positions, so one cached mesh per size is
## reused by all instances.

static var _cache: Dictionary = {}


## count quads (4 vertices each), UV = corner.
static func quads(count: int) -> ArrayMesh:
	var key: String = "q3_%d" % count
	if _cache.has(key):
		return _cache[key]
	var mesh: ArrayMesh = _build(count)
	_cache[key] = mesh
	return mesh


static func _build(count: int) -> ArrayMesh:
	count = maxi(count, 1)
	var n: int = count * 4
	var uvs: PackedVector2Array = PackedVector2Array()
	uvs.resize(n)
	var verts: PackedVector3Array = PackedVector3Array()
	verts.resize(n)
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(count * 6)
	for i in count:
		var j: int = i * 4
		var fi: float = float(i)
		uvs[j] = Vector2(0.0, 0.0)
		uvs[j + 1] = Vector2(1.0, 0.0)
		uvs[j + 2] = Vector2(0.0, 1.0)
		uvs[j + 3] = Vector2(1.0, 1.0)
		verts[j] = Vector3(fi, 0.0, 0.0)
		verts[j + 1] = Vector3(fi, 1.0, 0.0)
		verts[j + 2] = Vector3(fi, 0.0, 0.0)
		verts[j + 3] = Vector3(fi, 1.0, 0.0)
		var k: int = i * 6
		idx[k] = j
		idx[k + 1] = j + 1
		idx[k + 2] = j + 3
		idx[k + 3] = j
		idx[k + 4] = j + 3
		idx[k + 5] = j + 2
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
