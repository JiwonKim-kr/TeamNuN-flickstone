extends Node

enum ProbeResult { MISSING = 0, VALID = 1, INVALID = 2 }

const TARGET_NAME: String = "continue_run.bin"
const TEMP_NAME: String = "continue_run.tmp"
const BACKUP_NAME: String = "continue_run.bak"

var _storage_root: String = "user://"

func _ready() -> void:
	_cleanup_stale_temp()

func _path(name: String) -> String:
	return _storage_root.path_join(name)

func _directory(status: RunSaveStatus, operation: int) -> DirAccess:
	var directory: DirAccess = DirAccess.open(_storage_root)
	if directory == null: status.fail(RunSaveStatus.Code.IO_ERROR, operation)
	return directory

func _read_all(path: String, status: RunSaveStatus, operation: int) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		status.fail(RunSaveStatus.Code.IO_ERROR, operation, FileAccess.get_open_error())
		return PackedByteArray()
	var length: int = file.get_length()
	if length < 0 or length > RunLimits.SNAPSHOT_MAX_BYTES:
		status.fail(RunSaveStatus.Code.IO_ERROR, operation, length, RunLimits.SNAPSHOT_MAX_BYTES)
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(length)
	if bytes.size() != length: status.fail(RunSaveStatus.Code.IO_ERROR, operation, bytes.size(), length)
	return bytes

func _restore_bytes(bytes: PackedByteArray, catalog: ContentCatalog, status: RunSaveStatus, operation: int) -> RunState:
	var sim_status := SimStatus.new()
	var snapshot: RunSnapshot = RunSnapshot.decode(bytes, sim_status)
	var state := RunState.new()
	if sim_status.is_ok(): state = snapshot.restore_state(catalog, sim_status)
	if sim_status.is_ok() and state.is_initialized():
		var encoded: PackedByteArray = RunSnapshot.capture(state, sim_status).encode(sim_status)
		if sim_status.is_ok() and encoded == bytes: return state
	if sim_status.is_ok(): sim_status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.RUN_SNAPSHOT_RESTORE)
	status.fail_snapshot(operation, sim_status)
	return RunState.new()

func probe_continue(catalog: ContentCatalog, status: RunSaveStatus) -> int:
	if not status.is_ok(): return ProbeResult.INVALID
	if not _recover_valid_backup(catalog, status): return ProbeResult.INVALID
	var target: String = _path(TARGET_NAME)
	if not FileAccess.file_exists(target):
		status.fail(RunSaveStatus.Code.NOT_FOUND, RunSaveStatus.Operation.PROBE)
		return ProbeResult.MISSING
	var bytes: PackedByteArray = _read_all(target, status, RunSaveStatus.Operation.READ)
	if not status.is_ok(): return ProbeResult.INVALID
	var state: RunState = _restore_bytes(bytes, catalog, status, RunSaveStatus.Operation.PROBE)
	return ProbeResult.VALID if status.is_ok() and state.is_initialized() else ProbeResult.INVALID

func load_continue(catalog: ContentCatalog, status: RunSaveStatus) -> RunState:
	if not status.is_ok(): return RunState.new()
	if not _recover_valid_backup(catalog, status): return RunState.new()
	var target: String = _path(TARGET_NAME)
	if not FileAccess.file_exists(target):
		status.fail(RunSaveStatus.Code.NOT_FOUND, RunSaveStatus.Operation.READ)
		return RunState.new()
	var bytes: PackedByteArray = _read_all(target, status, RunSaveStatus.Operation.READ)
	if not status.is_ok(): return RunState.new()
	return _restore_bytes(bytes, catalog, status, RunSaveStatus.Operation.READ)

func save_continue(state: RunState, catalog: ContentCatalog, status: RunSaveStatus) -> bool:
	if not status.is_ok(): return false
	var sim_status := SimStatus.new()
	var snapshot: RunSnapshot = RunSnapshot.capture(state, sim_status)
	var bytes: PackedByteArray = snapshot.encode(sim_status)
	if not sim_status.is_ok() or bytes.is_empty():
		status.fail_snapshot(RunSaveStatus.Operation.WRITE_TEMP, sim_status)
		return false
	var directory: DirAccess = _directory(status, RunSaveStatus.Operation.WRITE_TEMP)
	if not status.is_ok(): return false
	if directory.file_exists(TEMP_NAME) and directory.remove(TEMP_NAME) != OK:
		status.fail(RunSaveStatus.Code.IO_ERROR, RunSaveStatus.Operation.CLEANUP)
		return false
	var file: FileAccess = FileAccess.open(_path(TEMP_NAME), FileAccess.WRITE)
	if file == null:
		status.fail(RunSaveStatus.Code.IO_ERROR, RunSaveStatus.Operation.WRITE_TEMP, FileAccess.get_open_error())
		return false
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var verify_status := RunSaveStatus.new()
	var verify_bytes: PackedByteArray = _read_all(_path(TEMP_NAME), verify_status, RunSaveStatus.Operation.VERIFY_TEMP)
	if verify_status.is_ok(): _restore_bytes(verify_bytes, catalog, verify_status, RunSaveStatus.Operation.VERIFY_TEMP)
	if not verify_status.is_ok() or verify_bytes != bytes:
		if verify_status.is_ok(): verify_status.fail(RunSaveStatus.Code.SNAPSHOT_REJECTED, RunSaveStatus.Operation.VERIFY_TEMP, verify_bytes.size(), bytes.size())
		_copy_failure(verify_status, status)
		return false
	if directory.file_exists(BACKUP_NAME) and directory.remove(BACKUP_NAME) != OK:
		status.fail(RunSaveStatus.Code.REPLACE_FAILED, RunSaveStatus.Operation.ROTATE_OLD)
		return false
	var rotated: bool = false
	if directory.file_exists(TARGET_NAME):
		if directory.rename(TARGET_NAME, BACKUP_NAME) != OK:
			status.fail(RunSaveStatus.Code.REPLACE_FAILED, RunSaveStatus.Operation.ROTATE_OLD)
			return false
		rotated = true
	if directory.rename(TEMP_NAME, TARGET_NAME) != OK:
		if rotated and not directory.file_exists(TARGET_NAME): directory.rename(BACKUP_NAME, TARGET_NAME)
		status.fail(RunSaveStatus.Code.REPLACE_FAILED, RunSaveStatus.Operation.COMMIT_TEMP)
		return false
	var final_status := RunSaveStatus.new()
	var final_bytes: PackedByteArray = _read_all(_path(TARGET_NAME), final_status, RunSaveStatus.Operation.VERIFY_TEMP)
	if final_status.is_ok(): _restore_bytes(final_bytes, catalog, final_status, RunSaveStatus.Operation.VERIFY_TEMP)
	if not final_status.is_ok() or final_bytes != bytes:
		if directory.file_exists(TARGET_NAME): directory.remove(TARGET_NAME)
		if rotated: directory.rename(BACKUP_NAME, TARGET_NAME)
		_copy_failure(final_status, status)
		return false
	# The new target has already been verified and committed. Backup cleanup is
	# best-effort so an antivirus/file-indexer lock cannot report a false save
	# failure after the durable state has changed.
	if directory.file_exists(BACKUP_NAME):
		directory.remove(BACKUP_NAME)
	return true

func _copy_failure(source: RunSaveStatus, target: RunSaveStatus) -> void:
	if not target.is_ok(): return
	target._code = source.code()
	target._operation = source.operation()
	target._detail_a = source.detail_a()
	target._detail_b = source.detail_b()
	target._sim_code = source.sim_code()
	target._sim_operation = source.sim_operation()
	target._sim_detail_a = source.sim_detail_a()
	target._sim_detail_b = source.sim_detail_b()

func _cleanup_stale_temp() -> void:
	var status := RunSaveStatus.new()
	var directory: DirAccess = _directory(status, RunSaveStatus.Operation.CLEANUP)
	if directory == null: return
	if directory.file_exists(TEMP_NAME): directory.remove(TEMP_NAME)

func _recover_valid_backup(catalog: ContentCatalog, status: RunSaveStatus) -> bool:
	var directory: DirAccess = _directory(status, RunSaveStatus.Operation.RECOVER_BACKUP)
	if directory == null: return false
	if directory.file_exists(TARGET_NAME) or not directory.file_exists(BACKUP_NAME): return true
	var bytes: PackedByteArray = _read_all(_path(BACKUP_NAME), status, RunSaveStatus.Operation.RECOVER_BACKUP)
	if status.is_ok(): _restore_bytes(bytes, catalog, status, RunSaveStatus.Operation.RECOVER_BACKUP)
	if not status.is_ok(): return false
	if directory.rename(BACKUP_NAME, TARGET_NAME) != OK:
		status.fail(RunSaveStatus.Code.REPLACE_FAILED, RunSaveStatus.Operation.RECOVER_BACKUP)
		return false
	return true

func set_storage_root_for_tests(root_path: String) -> void:
	_storage_root = root_path
