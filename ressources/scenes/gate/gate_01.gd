@tool
extends Node3D

@export var enable_effect: bool = false :
	set(value):
		enable_effect = value
		_apply_changes(value)

@export var shader_object: MeshInstance3D
@export var circle: MeshInstance3D
@export var lights: Array[Light3D]
@export var command_button: Node

var tween : Tween
var rot_tween: Tween

var target_value := 0.2
var transition_time := 1.0

func _on_interacted():
	enable_effect = !enable_effect  # Toggle the boolean
	print("Boolean changed to: ", enable_effect)

func  _ready() -> void:
	if shader_object and shader_object.material_override:
		var shader_material = shader_object.material_override
		shader_material.set_shader_parameter("PORTAL_CENTER", shader_object.global_transform.origin)
		
	if command_button :
		command_button.interacted.connect(_on_interacted)  # Connect the signal

func _apply_changes(enabled: bool):
	if shader_object and shader_object.material_override:
		var shader_material = shader_object.material_override
		var start_value = shader_material.get_shader_parameter("size")
		var end_value = target_value if enabled else 0.0
		shader_object.visible = enabled
		_create_shader_tween(shader_material, "size", start_value, end_value, 0.5)
		print("size ", start_value , " ", end_value)
		if(enabled) :
			if(rot_tween) : rot_tween.stop()
			rot_tween = get_tree().create_tween()
			rot_tween.set_loops()
			rot_tween.set_ease(Tween.EASE_IN)
			rot_tween.set_trans(Tween.TRANS_ELASTIC)
			rot_tween.tween_method(func(value): circle.rotation.y = value, 0, 360, 0.5);
		else:
			if(rot_tween) : rot_tween.stop()
			rot_tween = get_tree().create_tween()
			rot_tween.set_trans(Tween.TRANS_QUAD)
			rot_tween.set_ease(Tween.EASE_OUT)
			rot_tween.tween_method(func(value): circle.rotation.y = value, deg_to_rad(3600.), deg_to_rad(0.), 5);
	
	# Gérer les lumières
	for light in lights:
		if light:
			light.visible = enabled

func _create_shader_tween(shader_material: Material, shader_property: String, value_start: float, value_end: float, duration: float) -> Tween:
	tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_method(
	func(value): shader_material.set_shader_parameter(shader_property, value),  
		value_start, value_end, duration);
	return tween
