@abstract
class_name GenerationPass extends Resource

@abstract
func apply(generator: AsteroidGenerator, cells: PackedByteArray, size: Vector2i, rng: RandomNumberGenerator) -> PackedByteArray
