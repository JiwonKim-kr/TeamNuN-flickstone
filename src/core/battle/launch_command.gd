class_name LaunchCommand
extends RefCounted
## Immutable deterministic launch input. The six-byte codec is replay data.

var _initialized: bool = false
var _angle: int = 0
var _power_step: int = 0


static func create(angle: int, power_step: int, status: SimStatus) -> LaunchCommand:
	var result := LaunchCommand.new()
	if not status.is_ok():
		return result
	if not LaunchLimits.valid_quantized_angle(angle) or not LaunchLimits.valid_power_step(power_step):
		status.fail(
			SimStatus.Code.INVALID_LAUNCH_COMMAND,
			SimStatus.Operation.LAUNCH_COMMAND_CREATE,
			angle,
			power_step
		)
		return result
	result._initialized = true
	result._angle = angle
	result._power_step = power_step
	return result


static func decode(bytes: PackedByteArray, status: SimStatus) -> LaunchCommand:
	var result := LaunchCommand.new()
	if not status.is_ok():
		return result
	if bytes.size() != LaunchLimits.COMMAND_BYTE_COUNT:
		status.fail(
			SimStatus.Code.INVALID_LAUNCH_COMMAND,
			SimStatus.Operation.LAUNCH_COMMAND_DECODE,
			bytes.size(),
			LaunchLimits.COMMAND_BYTE_COUNT
		)
		return result
	var version: int = bytes[0] | (bytes[1] << 8)
	if version != LaunchLimits.COMMAND_SCHEMA_VERSION:
		status.fail(
			SimStatus.Code.UNSUPPORTED_SCHEMA,
			SimStatus.Operation.LAUNCH_COMMAND_DECODE,
			version,
			LaunchLimits.COMMAND_SCHEMA_VERSION
		)
		return result
	var angle: int = bytes[2] | (bytes[3] << 8)
	var power_step: int = bytes[4] | (bytes[5] << 8)
	var create_status := SimStatus.new()
	result = create(angle, power_step, create_status)
	if not create_status.is_ok():
		status.fail(
			create_status.code(),
			SimStatus.Operation.LAUNCH_COMMAND_DECODE,
			angle,
			power_step
		)
	return result


func encode(status: SimStatus) -> PackedByteArray:
	if not status.is_ok():
		return PackedByteArray()
	if not _initialized:
		status.fail(
			SimStatus.Code.INVALID_LAUNCH_COMMAND,
			SimStatus.Operation.LAUNCH_COMMAND_ENCODE,
			0,
			0
		)
		return PackedByteArray()
	var result := PackedByteArray()
	result.resize(LaunchLimits.COMMAND_BYTE_COUNT)
	result[0] = LaunchLimits.COMMAND_SCHEMA_VERSION & 0xFF
	result[1] = (LaunchLimits.COMMAND_SCHEMA_VERSION >> 8) & 0xFF
	result[2] = _angle & 0xFF
	result[3] = (_angle >> 8) & 0xFF
	result[4] = _power_step & 0xFF
	result[5] = (_power_step >> 8) & 0xFF
	return result


func is_initialized() -> bool:
	return _initialized


func angle() -> int:
	return _angle


func power_step() -> int:
	return _power_step


func is_equal(other: LaunchCommand) -> bool:
	return other != null and _initialized == other._initialized and _angle == other._angle and _power_step == other._power_step


func copy() -> LaunchCommand:
	var result := LaunchCommand.new()
	result._initialized = _initialized
	result._angle = _angle
	result._power_step = _power_step
	return result
