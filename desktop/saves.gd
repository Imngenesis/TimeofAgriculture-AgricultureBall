extends RefCounted

const V = preload("res://valley.gd")

var folder = "user://"
var checkpoint = {}
var previous_folder = ""

func use_version_folder(previous: String = "user://"):
	previous_folder = previous
	folder = previous.path_join("v1.20.2") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

func put(slot: String, state: Dictionary) -> bool:
	var path = folder + slot + ".bin"
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return false
	var contents = {"format": 1, "state": state}
	if slot == "chapter": checkpoint = state.duplicate(true)
	if slot == "campaign" and not checkpoint.is_empty(): contents["chapter"] = checkpoint
	f.store_var(contents)
	f.flush()
	var ok = f.get_error() == OK
	f.close()
	if not ok: return false
	var absolute = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(absolute + ".bak")
		if DirAccess.rename_absolute(absolute, absolute + ".bak") != OK: return false
	return DirAccess.rename_absolute(absolute + ".tmp", absolute) == OK

func read(slot: String) -> Dictionary:
	if slot == "chapter" and not checkpoint.is_empty(): return checkpoint.duplicate(true)
	var locations = [folder]

	if previous_folder != "" and slot in ["campaign", "chapter"] and not FileAccess.file_exists(folder + slot + ".bin") and not FileAccess.file_exists(folder + slot + ".bin.bak"):
		locations.append(previous_folder.path_join("v1.20") + "/")
		locations.append(previous_folder.path_join("v1.19") + "/")
		locations.append(previous_folder.path_join("v1.18") + "/")
		locations.append(previous_folder.path_join("v1.17") + "/")
		locations.append(previous_folder.path_join("v1.16") + "/")
		locations.append(previous_folder.path_join("v1.15") + "/")
		locations.append(previous_folder)
	for location in locations:
		for suffix in ["", ".bak"]:
			var path = location + slot + ".bin" + suffix
			if not FileAccess.file_exists(path): continue
			var f = FileAccess.open(path, FileAccess.READ)
			if not f: continue
			var value = f.get_var(false)
			f.close()
			if value is Dictionary and value.get("format", 0) == 1:
				var state = value.get("state", {})
				if valid(state):
					if slot == "campaign":
						checkpoint = value.get("chapter", {})
						if not valid(checkpoint): checkpoint = {}
					return state
	return {}

func valid(state: Variant) -> bool:
	if not state is Dictionary or not state.get("version", 0) in [1, 2, 3, 4, 5, 6, 7, 8]: return false
	if state.has("incidents") and not state.incidents is Array: return false
	if state.has("field_events"):
		if not preload("res://field_events.gd").valid(state.field_events): return false
		var offers = state.get("incidents",[]).filter(func(item): return item is Dictionary and item.get("kind","") == "field_event")
		if offers.size() != int(state.field_events.pending != ""): return false
	if state.version >= 7:
		var record = state.get("research_record")
		if not record is Dictionary or not record.get("focus") in [""] + preload("res://curriculum.gd").TRACKS: return false
		if not record.get("observations") is int or not record.get("terms") is int or not record.get("hazards") is Array: return false
	var count = V.COLS * V.ROWS if state.version >= 3 else V.CORE_CELLS
	if state.version >= 6 and ( not state.get("guide") is Dictionary or not state.get("weather") is Dictionary or not state.get("frontier", {}).get("yards") is Dictionary): return false
	if state.version >= 5 and not state.get("streets") is Dictionary: return false
	if state.version >= 4:
		var frontier = state.get("frontier")
		if not frontier is Dictionary: return false
		if not frontier.get("region") is int or frontier.region < 0 or frontier.region >= V.RELIEF.size(): return false
		if not frontier.get("home") is int or frontier.home < 0 or frontier.home >= count: return false
		if not frontier.get("missions") is Array or not frontier.get("roads") is Dictionary or not frontier.get("posts") is Dictionary: return false
	if state.version >= 8:
		if not state.get("birth_progress") is int or state.birth_progress < 0 or state.birth_progress >= 100: return false
		if not state.frontier.get("envoy_rng") is int: return false
		for w in state.get("workers", []):
			if not w is Dictionary or not w.get("farmer") is bool: return false
		for post in state.frontier.posts.values():
			if not post.get("farmers") is int or post.farmers < 0 or post.farmers > post.people: return false
		for mission in state.frontier.missions:
			if mission.key == "people" and ( not mission.get("farmers") is int or mission.farmers < 0 or mission.farmers > mission.amount): return false
	return state.get("cells", []).size() == count and state.get("workers", []).size() == state.get("pop", -1)
