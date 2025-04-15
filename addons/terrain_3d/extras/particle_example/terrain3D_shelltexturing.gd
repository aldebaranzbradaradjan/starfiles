@tool
extends Node3D

## Auto set if attached as a child of a Terrain3D node
@export var terrain: Terrain3D :
	set(value):
		terrain = value
		
@export var grid_radius = 3  # 3x3 tiles autour
@export var tile_size = 10.0
@export var follow_target_path: NodePath

## Override material for the particle mesh
@export_custom(
	PROPERTY_HINT_RESOURCE_TYPE,
	"BaseMaterial3D,ShaderMaterial") var mesh_material_override: Material:
	set(value):
		mesh_material_override = value
			
var follow_target: Node3D
var tiles := []

func _ready():
	follow_target = get_node(follow_target_path)
	_create_tile_grid()

func _process(_delta):
	_update_tile_positions()

func _create_tile_grid():
	var hr: Vector2 = terrain.data.get_height_range()
	var height: float = hr.x - hr.y
	var aabb: AABB = AABB()
	aabb.size = Vector3(tile_size, height, tile_size)
	aabb.position = aabb.size * -0.5
	aabb.position.y = hr.y
	
	for x in range(-grid_radius, grid_radius + 1):
		for z in range(-grid_radius, grid_radius + 1):
			var tile = MeshInstance3D.new()
			var plane_mesh = PlaneMesh.new()
			plane_mesh.size = Vector2(tile_size, tile_size)
		
			# Subdivision by distance
			var dist = Vector2(x, z).length()
			var subdivisions = 32 #sclamp(32 - int(dist * 16), 8, 32)
			plane_mesh.subdivide_width = subdivisions
			plane_mesh.subdivide_depth = subdivisions

			tile.mesh = plane_mesh
			tile.custom_aabb = aabb
			tile.material_override = mesh_material_override.duplicate(false)
			tile.cast_shadow = GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF
			var current_tile_material = tile.material_override
			var layers = 8
			for i in layers :
				print("Shell pass ", i)
				var inner_material_rid: RID = current_tile_material.get_rid()
				RenderingServer.material_set_param(inner_material_rid, "_background_mode", terrain.material.world_background)
				RenderingServer.material_set_param(inner_material_rid, "_vertex_spacing", terrain.vertex_spacing)
				RenderingServer.material_set_param(inner_material_rid, "_vertex_density", 1.0 / terrain.vertex_spacing)
				RenderingServer.material_set_param(inner_material_rid, "_region_size", terrain.region_size)
				RenderingServer.material_set_param(inner_material_rid, "_region_texel_size", 1.0 / terrain.region_size)
				RenderingServer.material_set_param(inner_material_rid, "_region_map_size", 32)
				RenderingServer.material_set_param(inner_material_rid, "_region_map", terrain.data.get_region_map())
				RenderingServer.material_set_param(inner_material_rid, "_region_locations", terrain.data.get_region_locations())
				RenderingServer.material_set_param(inner_material_rid, "_height_maps", terrain.data.get_height_maps_rid())
				RenderingServer.material_set_param(inner_material_rid, "_control_maps", terrain.data.get_control_maps_rid())
				RenderingServer.material_set_param(inner_material_rid, "shell_level", i)
				if(i<layers-1) :
					current_tile_material.next_pass = mesh_material_override.duplicate(false)
					current_tile_material = current_tile_material.next_pass

			add_child(tile)
			tiles.append(tile)

func _update_tile_positions():
	if terrain:
		var camera := terrain.get_camera()
		if camera:
			var center_pos = camera.global_transform.origin
			var tile_origin = Vector2(floor(center_pos.x / tile_size), floor(center_pos.z / tile_size))

			var i = 0
			for x in range(-grid_radius, grid_radius + 1):
				for z in range(-grid_radius, grid_radius + 1):
					var pos = (tile_origin + Vector2(x, z)) * tile_size
					tiles[i].global_transform.origin = Vector3(pos.x, 0, pos.y)
					i += 1
