class_name AsteroidDefinition extends ContentDefinition

@export var width: int
@export var height: int
@export var materials: Array[MaterialDefinition]
@export_range(0.0, 1.0, 0.01) var layer_boundaries: Array[float]
@export_range(0.0, 1.0, 0.01) var layer_variation: Array[float]

@export_group("Noise")
@export var noise_type: FastNoiseLite.NoiseType
@export var frequency: float

@export_group("Fractal")
@export var fractal_type: FastNoiseLite.FractalType
@export var gain: float
@export var octaves: int

@export_group("Chunks")
@export_range(2.0, 32.0, 0.5, "or_greater") var chunk_size: float = 5.0
@export_range(0.0, 0.9) var chunk_size_variation: float = 0.45
@export_range(1, 64, 1, "or_greater") var min_chunk_cells: int = 8
@export_range(0.05, 4.0, 0.05, "or_greater") var chunk_toughness: float = 1.0

@export_group("Generation")
@export var passes: Array[GenerationPass] = []
