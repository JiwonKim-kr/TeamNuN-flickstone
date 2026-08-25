class_name RunPendingChoice
extends RefCounted

var _kind_id: int = RunPendingKind.Value.INVALID
var _source_node_id: int = 0
var _generation_ordinal: int = 0
var _entries: Array[RunChoiceEntry] = []
var _initialized: bool = false

static func none(status: SimStatus) -> RunPendingChoice:
	return create(RunPendingKind.Value.NONE, 0, 0, [], status)

static func create(kind_id: int, source_node_id: int, generation_ordinal: int, entries: Array[RunChoiceEntry], status: SimStatus) -> RunPendingChoice:
	var result := RunPendingChoice.new()
	if not status.is_ok(): return result
	if not RunPendingKind.is_valid(kind_id) or entries.size() > RunLimits.MAX_PENDING_ENTRIES:
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_PENDING_CHOICE_CREATE, kind_id, entries.size()); return result
	if kind_id == RunPendingKind.Value.NONE:
		if source_node_id != 0 or generation_ordinal != 0 or not entries.is_empty():
			status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_PENDING_CHOICE_CREATE, source_node_id, generation_ordinal); return result
	else:
		if source_node_id <= 0 or generation_ordinal <= 0 or entries.is_empty():
			status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_PENDING_CHOICE_CREATE, source_node_id, generation_ordinal); return result
	for index: int in range(entries.size()):
		var entry: RunChoiceEntry = entries[index]
		if entry == null or not entry.is_initialized() or entry.choice_id() != index + 1:
			status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_PENDING_CHOICE_CREATE, index + 1, 0 if entry == null else entry.choice_id()); return RunPendingChoice.new()
		result._entries.append(entry.copy())
	result._kind_id = kind_id; result._source_node_id = source_node_id; result._generation_ordinal = generation_ordinal; result._initialized = true
	return result

func copy() -> RunPendingChoice:
	var result := RunPendingChoice.new()
	result._kind_id = _kind_id; result._source_node_id = _source_node_id; result._generation_ordinal = _generation_ordinal
	for entry: RunChoiceEntry in _entries: result._entries.append(entry.copy())
	result._initialized = _initialized
	return result
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func source_node_id() -> int: return _source_node_id
func generation_ordinal() -> int: return _generation_ordinal
func entry_count() -> int: return _entries.size()
func entry_at(index: int, status: SimStatus) -> RunChoiceEntry:
	if not status.is_ok(): return RunChoiceEntry.new()
	if index < 0 or index >= _entries.size():
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_PENDING_CHOICE_CREATE, index, _entries.size()); return RunChoiceEntry.new()
	return _entries[index].copy()
