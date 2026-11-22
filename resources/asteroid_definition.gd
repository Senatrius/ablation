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

@export_group("Generation")
@export var passes: Array[GenerationPass] = []
