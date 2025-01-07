extends Node3D

# Paramètres de la grille d'herbe
const CHUNK_SIZE = 10.0         # Taille de chaque chunk
const GRID_RADIUS = 3           # Nombre de chunks visibles autour du joueur (3x3, 5x5, etc.)

# Préfabriqué pour les chunks d'herbe (peut être une instance avec un ShaderMaterial appliqué)
@export var grass_chunk_scene: PackedScene

# Référence au joueur
@export var player: Node3D

# Stockage des chunks d'herbe
var chunks = {}

func _ready():
	# Initialisation des chunks d'herbe
	for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for z in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var chunk = grass_chunk_scene.instantiate()
			chunk.position = Vector3(x * CHUNK_SIZE, 0, z * CHUNK_SIZE)
			add_child(chunk)
			chunks[Vector2(x, z)] = chunk

func _process(delta):
	# Mise à jour des chunks autour du joueur
	var player_chunk_x = floor(player.global_position.x / CHUNK_SIZE)
	var player_chunk_z = floor(player.global_position.z / CHUNK_SIZE)

	for x in range(player_chunk_x - GRID_RADIUS, player_chunk_x + GRID_RADIUS + 1):
		for z in range(player_chunk_z - GRID_RADIUS, player_chunk_z + GRID_RADIUS + 1):
			var chunk_key = Vector2(x, z)
			
			if not chunks.has(chunk_key):
				# Crée un nouveau chunk si manquant
				var chunk = grass_chunk_scene.instantiate()
				chunk.position = Vector3(x * CHUNK_SIZE, 0, z * CHUNK_SIZE)
				add_child(chunk)
				chunks[chunk_key] = chunk
			
			# Marquer les chunks inutiles pour suppression
			for key in chunks.keys():
				if abs(key.x - player_chunk_x) > GRID_RADIUS or abs(key.y - player_chunk_z) > GRID_RADIUS:
					chunks[key].queue_free()
					chunks.erase(key)
