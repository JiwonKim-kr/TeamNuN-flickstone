class_name EffectResolutionReport
extends RefCounted

var _invocations: int = 0
var _applications: Array[EffectApplication] = []
var _initialized: bool = false

static func create(invocations: int, applications: Array[EffectApplication]) -> EffectResolutionReport:
	var result := EffectResolutionReport.new(); result._invocations = invocations
	for item: EffectApplication in applications: result._applications.append(item.copy())
	result._initialized = true; return result
func is_initialized() -> bool: return _initialized
func invocation_count() -> int: return _invocations
func application_count() -> int: return _applications.size()
func application_at(index: int, status: SimStatus) -> EffectApplication:
	if index < 0 or index >= _applications.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, index, _applications.size()); return EffectApplication.new()
	return _applications[index].copy()
