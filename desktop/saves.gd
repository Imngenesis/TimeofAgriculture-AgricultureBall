extends RefCounted

var folder="user://"
var checkpoint={}

func put(slot: String,state: Dictionary) -> bool:
	var path=folder+slot+".bin"
	var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null: return false
	var contents={"format":1,"state":state}
	if slot=="chapter": checkpoint=state.duplicate(true)
	if slot=="campaign" and not checkpoint.is_empty(): contents["chapter"]=checkpoint
	f.store_var(contents)
	f.flush()
	var ok=f.get_error()==OK
	f.close()
	if not ok: return false
	var absolute=ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(absolute+".bak")
		if DirAccess.rename_absolute(absolute,absolute+".bak")!=OK: return false
	return DirAccess.rename_absolute(absolute+".tmp",absolute)==OK

func read(slot: String) -> Dictionary:
	if slot=="chapter" and not checkpoint.is_empty(): return checkpoint.duplicate(true)
	for suffix in ["",".bak"]:
		var path=folder+slot+".bin"+suffix
		if not FileAccess.file_exists(path): continue
		var f=FileAccess.open(path,FileAccess.READ)
		if not f: continue
		var value=f.get_var(false)
		f.close()
		if value is Dictionary and value.get("format",0)==1:
			var state=value.get("state",{})
			if valid(state):
				if slot=="campaign":
					checkpoint=value.get("chapter",{})
					if not valid(checkpoint): checkpoint={}
				return state
	return {}

func valid(state: Variant) -> bool:
	return state is Dictionary and state.get("version",0) in [1,2] and state.get("cells",[]).size()==72 and state.get("workers",[]).size()==state.get("pop",-1)
