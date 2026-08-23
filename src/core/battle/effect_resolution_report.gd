class_name EffectResolutionReport
extends RefCounted

var _invocations: int = 0
var _applications: Array[EffectApplication] = []
var _generated_records: Array[BattleTriggerRecord] = []
var _status_applications: int = 0
var _status_updates: int = 0
var _status_removals: int = 0
var _initialized: bool = false

static func create(invocations: int, applications: Array[EffectApplication], generated_records: Array[BattleTriggerRecord], status_applications: int = 0, status_updates: int = 0, status_removals: int = 0) -> EffectResolutionReport:
	var result := EffectResolutionReport.new(); result._invocations = invocations
	for item: EffectApplication in applications: result._applications.append(item.copy())
	for record: BattleTriggerRecord in generated_records: result._generated_records.append(record.copy())
	result._status_applications = status_applications; result._status_updates = status_updates; result._status_removals = status_removals
	result._initialized = true; return result
func is_initialized() -> bool: return _initialized
func invocation_count() -> int: return _invocations
func status_application_count() -> int: return _status_applications
func status_update_count() -> int: return _status_updates
func status_removal_count() -> int: return _status_removals
func application_count() -> int: return _applications.size()
func application_at(index: int, status: SimStatus) -> EffectApplication:
	if index < 0 or index >= _applications.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, index, _applications.size()); return EffectApplication.new()
	return _applications[index].copy()
func generated_record_count() -> int: return _generated_records.size()
func generated_record_at(index: int, status: SimStatus) -> BattleTriggerRecord:
	if index < 0 or index >= _generated_records.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, index, _generated_records.size()); return BattleTriggerRecord.new()
	return _generated_records[index].copy()
