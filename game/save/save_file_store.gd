class_name SaveFileStore
extends RefCounted
## Reads and writes local save and settings files cleanly, closing every file handle
## between writes so Steam Auto-Cloud and Epic launchers can sync on exit (ADR 0019).


## Writes [param bytes] to [param path] via a temporary sibling file and rename, closing
## every file handle before returning. Never replaces an existing file if the temp write
## fails.
static func write_bytes(path: String, bytes: PackedByteArray) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var parent_dir := path.get_base_dir()
	if (
		not parent_dir.is_empty() and parent_dir != "user://"
		and not DirAccess.dir_exists_absolute(parent_dir)
	):
		var mkdir_err := DirAccess.make_dir_recursive_absolute(parent_dir)
		if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
			return mkdir_err
	var tmp_path := "%s.tmp" % path
	var tmp_err := _write_file(tmp_path, bytes)
	if tmp_err != OK:
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return tmp_err
	var rename_err := DirAccess.rename_absolute(tmp_path, path)
	if rename_err == OK:
		return OK
	# Fallback if rename over an existing file failed on the host filesystem: keep the
	# known-good temp copy until the direct write succeeds.
	var direct_err := _write_file(path, bytes)
	if direct_err == OK and FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	return direct_err


## Reads all bytes from [param path] and closes the file handle, returning an empty buffer
## if the file does not exist or cannot be opened.
static func read_bytes(path: String) -> PackedByteArray:
	if path.is_empty() or not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


static func _write_file(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_buffer(bytes)
	file.flush()
	var write_err := file.get_error()
	file.close()
	if not stored:
		return write_err if write_err != OK else ERR_FILE_CANT_WRITE
	if write_err != OK:
		return write_err
	return OK
