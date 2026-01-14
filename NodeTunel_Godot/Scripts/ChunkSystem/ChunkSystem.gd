@tool
extends Node3D
class_name ChunkGrassManager

@export var player: Node3D
@export var terrain: MeshInstance3D

#@export_group("Chunk Settings")
@export var chunk_size: float = 8.0
@export var view_distance_chunks: int = 8

#@export_group("Grass Mesh")
@export var grass_blade_mesh: Mesh

@export_group("LOD Levels")
@export var lod_distances: Array[float] = [40.0, 80.0, 160.0]
@export var lod_densities: Array[int] = [1500, 750, 200]

@export_group("Grass Variation")
@export var scale_range: Vector2 = Vector2(0.8, 1.2)
@export var random_rotation: bool = true

@export_group("Performance")
@export var update_on_chunk_change_only: bool = true
@export var update_interval: float = 0.5
@export var max_chunks_per_frame: int = 2
@export var async_generation: bool = true
@export var batch_size_per_frame: int = 50

var active_chunks: Dictionary = {}
var chunk_pool: Array[ChunkData] = []
var last_player_chunk: Vector2i = Vector2i(999999, 999999)
var update_timer: float = 0.0
var generation_queue: Array[Dictionary] = []

class ChunkData:
	var chunk_coord: Vector2i
	var world_position: Vector3
	var lod_level: int = -1
	var multimesh_instances: Array[MultiMeshInstance3D] = []
	var _multimesh: MultiMesh = null
	var _gen_index: int = 0

func _ready():
	if not player:
		return
	_update_chunks()

func _process(delta):
	if not player:
		return

	if update_on_chunk_change_only:
		var current_chunk = _world_to_chunk(player.global_position)
		if current_chunk != last_player_chunk:
			last_player_chunk = current_chunk
			_update_chunks()
	else:
		update_timer += delta
		if update_timer >= update_interval:
			update_timer = 0.0
			_update_chunks()

	if async_generation:
		_process_generation_queue()

#-------------------------------------------------
func _update_chunks():
	if not player or not grass_blade_mesh:
		return

	var player_pos = player.global_position
	var player_chunk = _world_to_chunk(player_pos)
	var needed_chunks: Dictionary = {}

	for x in range(-view_distance_chunks, view_distance_chunks + 1):
		for z in range(-view_distance_chunks, view_distance_chunks + 1):
			var coord = Vector2i(player_chunk.x + x, player_chunk.y + z)
			var center = _chunk_to_world(coord)
			var dist = player_pos.distance_to(center)
			var lod = _get_lod_level(dist)
			if lod >= 0:
				needed_chunks[coord] = lod

	for coord in active_chunks.keys():
		if not needed_chunks.has(coord):
			_deactivate_chunk(coord)

	for coord in needed_chunks.keys():
		if active_chunks.has(coord):
			var chunk = active_chunks[coord]
			if chunk.lod_level != needed_chunks[coord]:
				_update_chunk_lod(chunk, needed_chunks[coord])
		else:
			if async_generation:
				_queue_chunk_generation(coord, needed_chunks[coord])
			else:
				_activate_chunk(coord, needed_chunks[coord])

#-------------------------------------------------
func _queue_chunk_generation(coord: Vector2i, lod_level: int):
	for item in generation_queue:
		if item.coord == coord:
			return

	var center = _chunk_to_world(coord)
	var distance = player.global_position.distance_to(center)

	generation_queue.append({
		"coord": coord,
		"lod": lod_level,
		"priority": -distance
	})

	generation_queue.sort_custom(func(a, b): return a.priority > b.priority)

func _process_generation_queue():
	var chunks_generated = 0

	while chunks_generated < max_chunks_per_frame and generation_queue.size() > 0:
		var item = generation_queue.pop_front()
		if not active_chunks.has(item.coord):
			_activate_chunk(item.coord, item.lod)
			chunks_generated += 1

	# Generează batch pentru fiecare chunk activ
	for chunk in active_chunks.values():
		if chunk._multimesh == null:
			continue

		var density = lod_densities[chunk.lod_level]
		var start = chunk._gen_index
		var end = min(start + batch_size_per_frame, density)
		var half = chunk_size * 0.5

		for i in range(start, end):
			var lx = randf_range(-half, half)
			var lz = randf_range(-half, half)
			var wx = chunk.world_position.x + lx
			var wz = chunk.world_position.z + lz
			var h = _get_terrain_height(wx, wz)
			if h == null:
				continue

			var t := Transform3D()
			t.origin = Vector3(wx, h, wz)
			if random_rotation:
				t.basis = t.basis.rotated(Vector3.UP, randf() * TAU)
			var s = randf_range(scale_range.x, scale_range.y)
			t.basis = t.basis.scaled(Vector3.ONE * s)
			chunk._multimesh.set_instance_transform(i, t)

		chunk._gen_index = end
		if chunk._gen_index >= density:
			chunk._multimesh = null
			chunk._gen_index = 0

#-------------------------------------------------
func _activate_chunk(coord: Vector2i, lod_level: int):
	var chunk: ChunkData = chunk_pool.pop_back() if chunk_pool.size() > 0 else ChunkData.new()
	chunk.chunk_coord = coord
	chunk.world_position = _chunk_to_world(coord)
	chunk.lod_level = -1
	active_chunks[coord] = chunk
	_update_chunk_lod(chunk, lod_level)

func _deactivate_chunk(coord: Vector2i):
	var chunk = active_chunks[coord]
	for mmi in chunk.multimesh_instances:
		if is_instance_valid(mmi):
			mmi.queue_free()
	chunk.multimesh_instances.clear()
	active_chunks.erase(coord)
	chunk_pool.append(chunk)

func _update_chunk_lod(chunk: ChunkData, new_lod: int):
	for mmi in chunk.multimesh_instances:
		if is_instance_valid(mmi):
			mmi.queue_free()
	chunk.multimesh_instances.clear()
	chunk.lod_level = new_lod
	_generate_grass_for_chunk(chunk)

func _generate_grass_for_chunk(chunk: ChunkData):
	if chunk.lod_level < 0 or chunk.lod_level >= lod_densities.size():
		return

	var density = lod_densities[chunk.lod_level]

	var mmi := MultiMeshInstance3D.new()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = grass_blade_mesh
	mm.instance_count = density

	mmi.multimesh = mm
	add_child(mmi)
	chunk.multimesh_instances.append(mmi)

	chunk._multimesh = mm
	chunk._gen_index = 0

#-------------------------------------------------
func _world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / chunk_size),
		floori(pos.z / chunk_size)
	)

func _chunk_to_world(coord: Vector2i) -> Vector3:
	return Vector3(
		coord.x * chunk_size + chunk_size * 0.5,
		0,
		coord.y * chunk_size + chunk_size * 0.5
	)

func _get_lod_level(distance: float) -> int:
	for i in range(lod_distances.size()):
		if distance < lod_distances[i]:
			return i
	return -1

func _get_terrain_height(x: float, z: float) -> Variant:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(x, 1000, z),
		Vector3(x, -1000, z)
	)
	query.collide_with_areas = false
	if player:
		query.exclude = [player]
	var result = space.intersect_ray(query)
	return result.position.y if result else null
