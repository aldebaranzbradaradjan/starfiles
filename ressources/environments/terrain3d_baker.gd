@tool
extends Node3D

@export var output_path: String = "user://terrain_capture.png"  # Chemin du fichier
var camera: Camera3D
var custom_viewport: SubViewport  # Viewport dédié à la capture

@export_tool_button("Bake Terrain")
var c : Callable = func ():
	capture_terrain()
		
func _ready():
	setup_camera()
	await get_tree().process_frame  # Attendre un frame pour la mise à jour

func setup_camera():
	# Création d'un SubViewport pour capturer en 5000x5000
	custom_viewport = SubViewport.new()
	custom_viewport.size = Vector2i(4096, 4096)  # Taille du terrain
	#custom_viewport.usage = SubViewport.USAGE_3D  # Important pour rendre en 3D
	custom_viewport.transparent_bg = false
	custom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # Forcer le rendu
	add_child(custom_viewport)

	# Création de la caméra orthogonale
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL

	# Positionner la caméra au centre du terrain et bien orientée
	camera.position = Vector3(0, 4096/2, 0)  # Centré au milieu
	camera.rotation_degrees = Vector3(-90, 0, 0)  # Vue du dessus

	# Ajuster le zoom pour bien voir les 5000x5000
	camera.size = 4096   # Ajustement pour couvrir exactement la zone

	custom_viewport.add_child(camera)  # Attacher la caméra au viewport
	camera.make_current()

func capture_terrain():
	await RenderingServer.frame_post_draw  # Attendre la fin du rendu

	# Récupérer la texture du viewport
	var img = custom_viewport.get_texture().get_image()
	
	if img.is_empty():
		push_error("❌ L'image capturée est vide ! Vérifie que la caméra est bien positionnée.")
		return

	img.save_png(output_path)  # Sauvegarde en PNG
	print("📸 Capture sauvegardée à : " + output_path)
