@tool
extends MultiMeshInstance3D

@export var chunk_size: int = 25  # Taille de chaque chunk
@export var chunk_mesh: Mesh  # Le mesh de base pour les chunks (par exemple, un PlaneMesh)
@export var chunk_material: Material  # Le matériau pour chaque chunk
@export var player: Node3D  # Référence au joueur

const GRID_SIZE = 10  # Grille de 3x3
const GRID_RADIUS = 1  # Rayon de la grille (1 = 3x3)

func _ready():
	_initialize_multimesh()

func _initialize_multimesh():
	# Nombre total d'instances dans la grille 3x3
	var total_chunks = GRID_SIZE * GRID_SIZE

	# Crée et configure le MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = total_chunks
	multimesh.mesh = chunk_mesh
	self.multimesh = multimesh
	self.material_override = chunk_material

	# Initialise les positions de départ
	_update_chunk_positions()

func _process(delta):
	# Mets à jour les positions des chunks autour du joueur
	_update_chunk_positions()

func _update_chunk_positions():
	# Position du joueur, en coordonnées "chunk"
	var player_chunk_x = floor((player.global_position.x-chunk_size) / chunk_size)
	var player_chunk_z = floor((player.global_position.z-chunk_size) / chunk_size)

	# Indice de l'instance dans le MultiMesh
	var index = 0
	
	# Parcours de la grille 3x3
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var chunk_x = player_chunk_x + x
			var chunk_z = player_chunk_z + z

			# Position du chunk dans le monde
			var chunk_position = Vector3(chunk_x * chunk_size, 0, chunk_z * chunk_size)

			# Définir la transformation dans le MultiMesh
			var transform = Transform3D()
			transform.origin = chunk_position
			multimesh.set_instance_transform(index, transform)

			# Avance à l'instance suivante
			index += 1
