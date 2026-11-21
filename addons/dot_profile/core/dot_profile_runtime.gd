class_name GSProfileRuntime
extends RefCounted

## Live editing of profiles: a permission-gated, validated runtime layer that replicates. See docs/profiles.md.
## The server checks the actor, validates against the schema, writes the layer on [GSProfileSet], bumps the revision and
## hands the row to [member broadcast]; a client feeds rows to [method apply_row], which takes only newer revisions.

const CHANNEL := "profile"
const OP_SET := "set"
const OP_RESET_KEY := "reset_key"
const OP_RESET := "reset"
const OP_SAVE := "save"
## Makes a new profile (`key` unused; `value` an optional `{path: value}` to start from).
const OP_ADD := "add"
## Removes a profile; the server tier loses its file, a shipped one is hidden by a marker.
const OP_DELETE := "delete"

## A profile's runtime layer changed (edit, reset, or a newer row from the server).
signal profile_changed(kind: String, id: String, revision: int)

## `(actor, flag: String) -> bool`. Unset means everything is denied.
var permit: Callable = Callable()
## Flag needed to edit or reset; GameSpice Server's `GSAdminFlags.CVAR`.
var edit_flag := "cvar"
## Flag needed to write cfg/server; GameSpice Server's `GSAdminFlags.ROOT`.
var save_flag := "root"
## `(row: Dictionary) -> void`: send to every client.
var broadcast: Callable = Callable()
## `(peer: Variant, row: Dictionary) -> void`: send to one client.
var send_to: Callable = Callable()
## `(actor) -> String` for the audit line; default is `str(actor)`.
var actor_name: Callable = Callable()
## Config root that [constant OP_SAVE] writes below (`<root>/server/game/<game>/` or `server/addon/<addon>/`, then `<kind>/<id>.yml`; `server/<kind>/` when the set has neither).
var save_root := "user://cfg"

var _sets: Dictionary = {}
var _rev: Dictionary = {}


## Registers [param set] under its kind (its `rel_path`).
func add_set(set: GSProfileSet) -> void:
	_sets[set.rel_path] = set


## The current revision of [param kind]/[param id]; 0 when never edited.
func revision(kind: String, id: String) -> int:
	return _rev.get(_key(kind, id), 0)


## Builds a request dictionary for [method handle_request]. [param key] and [param value] are
## unused by reset and save as noted in docs/profiles.md.
static func make_request(op: String, kind: String, id: String, key: String = "", value: Variant = null) -> Dictionary:
	return {"op": op, "kind": kind, "id": id, "key": key, "value": value}


## Server side. Value on success: the changed row, or `{"saved": path}` for save.
func handle_request(actor: Variant, req: Dictionary) -> GSResult:
	var op: String = str(req.get("op", ""))
	var kind: String = str(req.get("kind", ""))
	var id: String = str(req.get("id", ""))
	var flag := save_flag if op == OP_SAVE else edit_flag
	if not permit.is_valid() or not bool(permit.call(actor, flag)):
		GSLog.warn(CHANNEL, "profile edit denied", {"who": _who(actor), "op": op, "kind": kind, "id": id})
		return GSResult.fail(GSError.CODE_FORBIDDEN, "profile edits need '%s'" % flag)
	if not [OP_SET, OP_RESET_KEY, OP_RESET, OP_SAVE, OP_ADD, OP_DELETE].has(op):
		return GSResult.fail(GSError.CODE_INVALID, "unknown profile op '%s'" % op)
	if not _sets.has(kind):
		return GSResult.fail(GSError.CODE_INVALID, "unknown profile kind '%s'" % kind)
	var set: GSProfileSet = _sets[kind]
	if op == OP_ADD:
		return _add(actor, set, id, req.get("value"))
	if not set.has_id(id):
		return GSResult.fail(GSError.CODE_INVALID, "%s/%s: no such profile" % [kind, id])
	match op:
		OP_SET:
			return _do_set(actor, set, id, str(req.get("key", "")), req.get("value"))
		OP_RESET_KEY:
			return _reset_key(actor, set, id, str(req.get("key", "")))
		OP_RESET:
			return _commit(actor, set, id, {}, "reset", "", null)
		OP_DELETE:
			return _delete(actor, set, id)
		_:
			return _save(actor, set, id)


## Client side: applies a server row if it is newer. Value: true when applied, false when stale.
func apply_row(row: Dictionary) -> GSResult:
	var kind: String = str(row.get("kind", ""))
	var id: String = str(row.get("id", ""))
	var rev: Variant = row.get("rev")
	var paths: Variant = row.get("paths")
	if not _sets.has(kind) or not (rev is int or rev is float) or not (paths is Dictionary):
		return GSResult.fail(GSError.CODE_INVALID, "malformed profile row")
	if int(rev) <= revision(kind, id):
		return GSResult.success(false)
	var set: GSProfileSet = _sets[kind]
	if bool(row.get("removed", false)):
		if set.has_id(id):
			var _gone := set.remove_id(id)
		_rev[_key(kind, id)] = int(rev)
		profile_changed.emit(kind, id, int(rev))
		return GSResult.success(true)
	if not set.has_id(id):
		var _made := set.add_id(id)
	var before := set.runtime_paths(id)
	set.set_runtime(id, paths)
	var loaded := set.load_profile(id)
	if not loaded.ok:
		set.set_runtime(id, before)
		return loaded.wrap("profile row %s/%s" % [kind, id])
	_rev[_key(kind, id)] = int(rev)
	profile_changed.emit(kind, id, int(rev))
	return GSResult.success(true)


## Client side: forget every runtime row and revision, before a (re)connect's snapshot.
func begin_sync() -> void:
	for kind in _sets:
		var set: GSProfileSet = _sets[kind]
		for id in set.runtime.keys():
			set.set_runtime(id, {})
			profile_changed.emit(kind, id, 0)
	_rev.clear()


## Server side: every row a late joiner needs, one per edited profile.
func snapshot() -> Array:
	var rows: Array = []
	for k in _rev:
		var kind: String = k.get_slice("/", 0)
		var id: String = k.substr(kind.length() + 1)
		rows.append(_row(kind, id))
	return rows


## Server side: sends [method snapshot] to [param peer] through [member send_to].
func send_snapshot(peer: Variant) -> void:
	if not send_to.is_valid():
		return
	for row in snapshot():
		send_to.call(peer, row)


func describe() -> String:
	return "\n".join(describe_lines())


func describe_lines() -> PackedStringArray:
	var out := PackedStringArray(["GSProfileRuntime (%d kinds, %d edited profiles)" % [_sets.size(), _rev.size()]])
	for k in _rev:
		var kind: String = k.get_slice("/", 0)
		var id: String = k.substr(kind.length() + 1)
		out.append("  %s rev %d: %s" % [k, _rev[k], str((_sets[kind] as GSProfileSet).runtime_paths(id))])
	return out


# Internals

func _key(kind: String, id: String) -> String:
	return kind + "/" + id


func _who(actor: Variant) -> String:
	return str(actor_name.call(actor)) if actor_name.is_valid() else str(actor)


func _row(kind: String, id: String) -> Dictionary:
	var set: GSProfileSet = _sets[kind]
	var row := {"kind": kind, "id": id, "rev": revision(kind, id), "paths": set.runtime_paths(id)}
	if set.removed_ids.has(id):
		row["removed"] = true
	return row


func _add(actor: Variant, set: GSProfileSet, id: String, start: Variant) -> GSResult:
	var paths := {}
	if start is Dictionary:
		paths = (start as Dictionary).duplicate(true)
	var mark := _server_file(set, id).get_basename() + "." + GSProfileSet.TOMBSTONE
	if FileAccess.file_exists(mark) and not set.has_id(id) and set._id_ok(id):
		var _lifted := DirAccess.remove_absolute(mark)
	var made := set.add_id(id)
	if not made.ok:
		return made
	for path in paths:
		var checked := set.check_edit(id, String(path), paths[path])
		if not checked.ok:
			set.added_ids.remove_at(set.added_ids.find(id))
			return checked
		paths[path] = checked.value["value"]
	set.set_runtime(id, paths)
	var loaded := set.load_profile(id)
	if not loaded.ok:
		set.set_runtime(id, {})
		set.added_ids.remove_at(set.added_ids.find(id))
		return loaded
	return _announce(actor, set, id, "add")


func _delete(actor: Variant, set: GSProfileSet, id: String) -> GSResult:
	var kind := set.rel_path
	var file := _server_file(set, id)
	var shipped := false
	for f: Dictionary in set._files_for(id):
		if f["path"] != file:
			shipped = true
	if FileAccess.file_exists(file):
		var err := DirAccess.remove_absolute(file)
		if err != OK:
			return GSResult.fail(GSError.CODE_IO, "cannot remove %s" % file)
	var gone := set.remove_id(id)
	if not gone.ok:
		return gone
	var mark := file.get_basename() + "." + GSProfileSet.TOMBSTONE
	if shipped:
		var dir := GSPaths.ensure_parent_dir(mark)
		if not dir.ok:
			return dir
		var wrote := GSPaths.write_text(mark, "deleted\n")
		if not wrote.ok:
			return wrote.wrap("marking %s deleted" % id)
	GSWeb.sync_filesystem()
	return _announce(actor, set, id, "delete")


func _announce(actor: Variant, set: GSProfileSet, id: String, what: String) -> GSResult:
	var kind := set.rel_path
	var rev := revision(kind, id) + 1
	_rev[_key(kind, id)] = rev
	GSLog.info(CHANNEL, "profile %s" % what, {"who": _who(actor), "op": what, "kind": kind, "id": id, "rev": rev})
	var row := _row(kind, id)
	if broadcast.is_valid():
		broadcast.call(row)
	profile_changed.emit(kind, id, rev)
	return GSResult.success(row)


## The server-tier file [constant OP_SAVE] writes for [param id].
func _server_file(set: GSProfileSet, id: String) -> String:
	var base := save_root.path_join("server")
	if set.game != "":
		base = base.path_join("game").path_join(set.game)
	elif set.addon_name != "":
		base = base.path_join("addon").path_join(set.addon_name)
	return base.path_join(set.rel_path).path_join(id + "." + GSProfileSet.EXTENSION)


func _effective(set: GSProfileSet, id: String, path: String) -> Variant:
	var res := set.load_profile(id)
	if not res.ok:
		return null
	var parts := path.split(".")
	var node: Variant = (res.value as GSProfile).extra if parts[0] == GSProfileSet.EXTRA_KEY else (res.value as GSProfile).values
	if parts[0] == GSProfileSet.EXTRA_KEY:
		parts = parts.slice(1)
	for p in parts:
		if not (node is Dictionary) or not (node as Dictionary).has(p):
			return null
		node = node[p]
	return node


func _do_set(actor: Variant, set: GSProfileSet, id: String, path: String, value: Variant) -> GSResult:
	var checked := set.check_edit(id, path, value)
	if not checked.ok:
		GSLog.warn(CHANNEL, "profile edit refused", {"who": _who(actor), "kind": set.rel_path, "id": id, "key": path, "why": checked.error.message})
		return checked
	var paths := set.runtime_paths(id)
	paths[path] = checked.value["value"]
	return _commit(actor, set, id, paths, "set", path, checked.value["value"])


func _reset_key(actor: Variant, set: GSProfileSet, id: String, path: String) -> GSResult:
	var paths := set.runtime_paths(id)
	if not paths.has(path):
		return GSResult.success({"changed": false})
	paths.erase(path)
	return _commit(actor, set, id, paths, "reset_key", path, null)


## Applies [param paths] as the layer, rolling back if the profile no longer loads.
func _commit(actor: Variant, set: GSProfileSet, id: String, paths: Dictionary, what: String, path: String, value: Variant) -> GSResult:
	var before := set.runtime_paths(id)
	if GSValue.same_dictionary(before, paths):
		return GSResult.success({"changed": false})
	var old: Variant = _effective(set, id, path) if path != "" else null
	set.set_runtime(id, paths)
	var loaded := set.load_profile(id)
	if not loaded.ok:
		set.set_runtime(id, before)
		return loaded
	var kind := set.rel_path
	var rev := revision(kind, id) + 1
	_rev[_key(kind, id)] = rev
	var now: Variant = _effective(set, id, path) if path != "" else null
	GSLog.info(CHANNEL, "profile edited", {"who": _who(actor), "op": what, "kind": kind, "id": id, "key": path, "old": str(old), "new": str(now), "rev": rev})
	var row := _row(kind, id)
	if broadcast.is_valid():
		broadcast.call(row)
	profile_changed.emit(kind, id, rev)
	return GSResult.success(row)


func _save(actor: Variant, set: GSProfileSet, id: String) -> GSResult:
	var paths := set.runtime_paths(id)
	if paths.is_empty() and not set.added_ids.has(id):
		return GSResult.fail(GSError.CODE_STATE, "%s/%s has no runtime edits to save" % [set.rel_path, id])
	for part in [set.game, set.addon_name]:
		if part != "" and not set._id_ok(part):
			push_error("GSProfileRuntime: bad game or addon name '%s'" % part)
			return GSResult.fail(GSError.CODE_INVALID, "bad game or addon name '%s'" % part)
	var file := _server_file(set, id)
	var tree := {}
	if FileAccess.file_exists(file):
		var existing := GSYaml.parse_file(file)
		if not existing.ok:
			return existing.wrap("saving %s" % file)
		if existing.value is Dictionary:
			tree = existing.value
	for path in paths:
		GSAddonConfig.set_nested(tree, String(path).split("."), paths[path])
	var text: Variant = GSYaml.emit(tree)
	if text == null:
		return GSResult.fail(GSError.CODE_INVALID, "%s/%s holds a value yml cannot carry" % [set.rel_path, id])
	var dir := GSPaths.ensure_parent_dir(file)
	if not dir.ok:
		return dir
	var wrote := GSPaths.write_text(file, text)
	if not wrote.ok:
		return wrote.wrap("saving %s" % file)
	GSLog.info(CHANNEL, "profile saved to server layer", {"who": _who(actor), "kind": set.rel_path, "id": id, "file": file, "keys": paths.size()})
	return GSResult.success({"saved": file})
