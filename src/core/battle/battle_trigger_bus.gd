class_name BattleTriggerBus
extends RefCounted

var _waves: Array = []
var _draining: bool = false
var _current_wave: int = -1
var _record_count: int = 0

func enqueue(record: BattleTriggerRecord, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if record == null or not record.is_initialized():
		status.fail(SimStatus.Code.INVALID_TRIGGER_RECORD, SimStatus.Operation.TRIGGER_ENQUEUE, 0, 0); return false
	var wave: int = record.wave()
	if wave >= BattleLimits.TRIGGER_MAX_WAVES or (_draining and wave <= _current_wave) or _record_count >= BattleLimits.TRIGGER_MAX_RECORDS:
		status.fail(SimStatus.Code.TRIGGER_LIMIT_EXCEEDED, SimStatus.Operation.TRIGGER_ENQUEUE, wave, _record_count); return false
	while _waves.size() <= wave: _waves.append([])
	_waves[wave].append(record.copy())
	_record_count += 1
	return true

func drain(status: SimStatus) -> Array[BattleTriggerRecord]:
	var result: Array[BattleTriggerRecord] = []
	if not status.is_ok(): return result
	_draining = true
	for wave_index: int in range(_waves.size()):
		_current_wave = wave_index
		for record: BattleTriggerRecord in _waves[wave_index]: result.append(record.copy())
	_draining = false; _current_wave = -1; _waves.clear(); _record_count = 0
	return result

func is_empty() -> bool: return _record_count == 0
