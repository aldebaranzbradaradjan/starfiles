@tool
extends GPUParticles3D

@export var terrain: Terrain3D :
	set(value):
		terrain = value
		_update_process_parameters()
		
@export var player: Node3D :
	set(value):
		player = value
		_update_process_parameters()

func _update_process_parameters() -> void:
	var process_rid: RID = process_material.get_rid()
	if terrain:
		var camera := terrain.get_camera()
		if camera:
			global_position.x = floorf(camera.global_position.x)
			global_position.z = floorf(camera.global_position.z)
			if(player) :
				RenderingServer.material_set_param(process_rid, "camera_transform", player.transform)
			else :
				RenderingServer.material_set_param(process_rid, "camera_transform", camera.get_camera_transform())
		RenderingServer.material_set_param(process_rid, "_background_mode", terrain.material.world_background)
		RenderingServer.material_set_param(process_rid, "_vertex_spacing", terrain.vertex_spacing)
		RenderingServer.material_set_param(process_rid, "_vertex_density", 1.0 / terrain.vertex_spacing)
		RenderingServer.material_set_param(process_rid, "_region_size", terrain.region_size)
		RenderingServer.material_set_param(process_rid, "_region_texel_size", 1.0 / terrain.region_size)
		RenderingServer.material_set_param(process_rid, "_region_map_size", 32)
		RenderingServer.material_set_param(process_rid, "_region_map", terrain.data.get_region_map())
		RenderingServer.material_set_param(process_rid, "_region_locations", terrain.data.get_region_locations())
		RenderingServer.material_set_param(process_rid, "_height_maps", terrain.data.get_height_maps_rid())
		RenderingServer.material_set_param(process_rid, "_control_maps", terrain.data.get_control_maps_rid())
		
		
func _ready() -> void:
	_update_process_parameters()

func _physics_process(delta: float) -> void:
	_update_process_parameters() # lazy but catches vertex spacing changes
	
