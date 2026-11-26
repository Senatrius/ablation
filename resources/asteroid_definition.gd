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

@export_group("Physics")
@export_range(0.0001, 1.0, 0.0001, "or_greater") var mass_per_density: float = 0.01
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:s") var collision_rebuild_interval: float = 0.1

@export_group("Breaking")
@export_range(0, 200, 1, "or_greater") var min_fragment_cells: int = 40
@export_range(0.0, 1.0) var damage_spread: float = 0.1
@export var fragment_kick: float = 12.0
@export var explosion_kick: float = 150.0
@export var blast_debris_speed: float = 2.5
@export var debris_min_speed: float = 20.0
@export_range(0.0, 500.0, 1.0, "or_greater") var debris_max_speed: float = 60.0
@export var debris_max_spin: float = 4.0

@export_group("Generation")
@export var passes: Array[GenerationPass] = []
