extends MeshInstance3D
class_name PlanarReflector

@export var materialToSet:ShaderMaterial = load("res://external_ressources/materials/PlanarReflectionWindow.tres");

@export var reflection_fps: int = 15  # FPS de la réflexion
var _time_accumulator = 0.0

@export var blur : float = 0.015 :
	set(value):
		blur = value
		if reflect_camera != null :
			var attributes = reflect_camera.attributes
			attributes.dof_blur_amount = value
			reflect_camera.attributes = attributes

@export var far : int = 500 :
	set(value):
		far = value
		if reflect_camera != null :
			reflect_camera.far = value
		
var reflect_camera : Camera3D
var reflect_viewport: SubViewport
@export var oblique_supported: bool = false
@export var main_cam : Node3D = null
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)
@export var reflection_camera_resolution_multiplier: float = 0.2 :
	set(value):
		reflection_camera_resolution_multiplier = value
		if reflect_viewport != null :
			reflect_viewport.size = reflection_camera_resolution * reflection_camera_resolution_multiplier;

# Called when the node enters the scene tree for the first time.
func _ready():
	reflect_viewport = SubViewport.new();
	add_child(reflect_viewport);
	reflect_viewport.size = reflection_camera_resolution * reflection_camera_resolution_multiplier;
	reflect_camera = Camera3D.new();
	reflect_viewport.add_child(reflect_camera);
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if(oblique_supported):
		reflect_camera.use_oblique_frustum = true;
		reflect_camera.oblique_position = self.global_position;
		reflect_camera.oblique_normal = Vector3.UP;
	reflect_camera.cull_mask = 1;
	reflect_camera.fov = main_cam.fov
	reflect_camera.far = far
	
	var cam_attributes = CameraAttributesPractical.new() #get_world_3d().camera_attributes.duplicate() #
	cam_attributes.dof_blur_far_enabled = true  # Active le DOF sur l'arrière-plan
	cam_attributes.dof_blur_far_distance = 5.0  # Distance où commence le flou
	cam_attributes.dof_blur_far_transition = 10.0  # Adoucit la transition
	cam_attributes.dof_blur_amount = blur  # Intensité du flou
	#cam_attributes.exposure_multiplier = 3.0
	reflect_camera.attributes = cam_attributes  # Appliquer à la caméra de réflexion

	reflect_camera.doppler_tracking = main_cam.doppler_tracking
	reflect_camera.projection = main_cam.projection
	reflect_camera.current = true;
	self.mesh.surface_set_material(0, materialToSet);
	
	reflect_camera.make_current();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (!main_cam):
		return
		
	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2);
	var plane_origin = reflection_transform.origin;
	var plane_normal = reflection_transform.basis.z.normalized();
	var reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
	
	var cam_pos = main_cam.global_transform.origin
	
	var proj_pos := reflection_plane.project(cam_pos)
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	reflect_camera.global_transform.origin = mirrored_pos

	reflect_camera.basis = Basis(
		main_cam.global_basis.x.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.global_basis.y.normalized().bounce(reflection_plane.normal).normalized(),
		main_cam.global_basis.z.normalized().bounce(reflection_plane.normal).normalized()
	)
	
	var mat:ShaderMaterial = self.mesh.surface_get_material(0)
	mat.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture());

func _physics_process(_delta):
	_time_accumulator += _delta
	if _time_accumulator >= (1.0 / reflection_fps):
		_time_accumulator -= (1.0 / reflection_fps)
		reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_viewport() -> void:
	reflect_viewport.size = get_viewport().size
