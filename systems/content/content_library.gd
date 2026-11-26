class_name ContentLibrary extends RefCounted

static func load_all(path: String) -> Array[Resource]:
	var result: Array[Resource] = []

	for entry: String in ResourceLoader.list_directory(path):
		if entry.ends_with("/"):
			result.append_array(load_all(path.path_join(entry)))
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			result.append(load(path.path_join(entry)))

	return result
