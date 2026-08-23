class_name StrictJsonParser
extends RefCounted
## Byte-based RFC 8259 subset parser for authoritative content.
##
## Numbers are signed int64 literals only. Duplicate keys and the non-strict
## extensions accepted by Godot's JSON class are rejected before schema work.

var _bytes: PackedByteArray = PackedByteArray()
var _offset: int = 0
var _line: int = 1
var _column: int = 1
var _node_count: int = 0
var _status: ContentStatus


static func parse_utf8(bytes: PackedByteArray, status: ContentStatus) -> Variant:
	var parser := StrictJsonParser.new()
	return parser._parse_root(bytes, status)


func _parse_root(bytes: PackedByteArray, status: ContentStatus) -> Variant:
	if not status.is_ok():
		return null
	_status = status
	_bytes = bytes
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		_fail(ContentStatus.Code.INVALID_UTF8)
		return null
	if not _is_valid_utf8(bytes):
		_fail(ContentStatus.Code.INVALID_UTF8)
		return null
	var decoded: String = bytes.get_string_from_utf8()
	if decoded.to_utf8_buffer() != bytes:
		_fail(ContentStatus.Code.INVALID_UTF8)
		return null
	_skip_whitespace()
	if _offset >= _bytes.size():
		_fail(ContentStatus.Code.JSON_SYNTAX)
		return null
	var result: Variant = _parse_value(1)
	if not _status.is_ok():
		return null
	_skip_whitespace()
	if _offset != _bytes.size():
		_fail(ContentStatus.Code.JSON_SYNTAX)
		return null
	return result


func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first <= 0x7F:
			index += 1
			continue
		var continuation_count: int = 0
		var minimum_second: int = 0x80
		var maximum_second: int = 0xBF
		if first >= 0xC2 and first <= 0xDF:
			continuation_count = 1
		elif first >= 0xE0 and first <= 0xEF:
			continuation_count = 2
			if first == 0xE0: minimum_second = 0xA0
			if first == 0xED: maximum_second = 0x9F
		elif first >= 0xF0 and first <= 0xF4:
			continuation_count = 3
			if first == 0xF0: minimum_second = 0x90
			if first == 0xF4: maximum_second = 0x8F
		else:
			return false
		if index + continuation_count >= bytes.size():
			return false
		var second: int = bytes[index + 1]
		if second < minimum_second or second > maximum_second:
			return false
		for continuation_index: int in range(2, continuation_count + 1):
			var continuation: int = bytes[index + continuation_index]
			if continuation < 0x80 or continuation > 0xBF:
				return false
		index += continuation_count + 1
	return true


func _fail(code: int) -> void:
	_status.fail(
		code,
		ContentStatus.Operation.JSON_PARSE,
		-1,
		-1,
		-1,
		_line,
		_column,
		_offset
	)


func _peek() -> int:
	return -1 if _offset >= _bytes.size() else _bytes[_offset]


func _advance() -> int:
	if _offset >= _bytes.size():
		return -1
	var value: int = _bytes[_offset]
	_offset += 1
	if value == 0x0A:
		_line += 1
		_column = 1
	else:
		_column += 1
	return value


func _skip_whitespace() -> void:
	while _offset < _bytes.size():
		var value: int = _peek()
		if value != 0x20 and value != 0x09 and value != 0x0A and value != 0x0D:
			return
		_advance()


func _claim_node(depth: int) -> bool:
	if depth > ContentLimits.JSON_MAX_DEPTH:
		_fail(ContentStatus.Code.JSON_LIMIT)
		return false
	_node_count += 1
	if _node_count > ContentLimits.JSON_MAX_NODES:
		_fail(ContentStatus.Code.JSON_LIMIT)
		return false
	return true


func _parse_value(depth: int) -> Variant:
	if not _claim_node(depth):
		return null
	var value: int = _peek()
	match value:
		0x7B: return _parse_object(depth)
		0x5B: return _parse_array(depth)
		0x22: return _parse_string()
		0x74:
			return true if _consume_literal("true") else null
		0x66:
			return false if _consume_literal("false") else null
		0x6E:
			_consume_literal("null")
			return null
		0x2D:
			return _parse_integer()
		_:
			if value >= 0x30 and value <= 0x39:
				return _parse_integer()
	_fail(ContentStatus.Code.JSON_SYNTAX)
	return null


func _consume_literal(text: String) -> bool:
	var expected: PackedByteArray = text.to_ascii_buffer()
	if _offset + expected.size() > _bytes.size():
		_fail(ContentStatus.Code.JSON_SYNTAX)
		return false
	for value: int in expected:
		if _advance() != value:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return false
	return true


func _parse_object(depth: int) -> Dictionary:
	var result: Dictionary = {}
	_advance()
	_skip_whitespace()
	if _peek() == 0x7D:
		_advance()
		return result
	var member_count: int = 0
	while _status.is_ok():
		if _peek() != 0x22:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return {}
		var key: String = _parse_string()
		if not _status.is_ok(): return {}
		if result.has(key):
			_fail(ContentStatus.Code.DUPLICATE_KEY)
			return {}
		_skip_whitespace()
		if _advance() != 0x3A:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return {}
		_skip_whitespace()
		var parsed: Variant = _parse_value(depth + 1)
		if not _status.is_ok(): return {}
		result[key] = parsed
		member_count += 1
		if member_count > ContentLimits.JSON_MAX_OBJECT_MEMBERS:
			_fail(ContentStatus.Code.JSON_LIMIT)
			return {}
		_skip_whitespace()
		var separator: int = _advance()
		if separator == 0x7D:
			return result
		if separator != 0x2C:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return {}
		_skip_whitespace()
		if _peek() == 0x7D:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return {}
	_fail(ContentStatus.Code.JSON_SYNTAX)
	return {}


func _parse_array(depth: int) -> Array:
	var result: Array = []
	_advance()
	_skip_whitespace()
	if _peek() == 0x5D:
		_advance()
		return result
	while _status.is_ok():
		if result.size() >= ContentLimits.JSON_MAX_ARRAY_ITEMS:
			_fail(ContentStatus.Code.JSON_LIMIT)
			return []
		result.append(_parse_value(depth + 1))
		if not _status.is_ok(): return []
		_skip_whitespace()
		var separator: int = _advance()
		if separator == 0x5D:
			return result
		if separator != 0x2C:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return []
		_skip_whitespace()
		if _peek() == 0x5D:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return []
	_fail(ContentStatus.Code.JSON_SYNTAX)
	return []


func _parse_string() -> String:
	var output: PackedByteArray = PackedByteArray()
	if _advance() != 0x22:
		_fail(ContentStatus.Code.JSON_SYNTAX)
		return ""
	while _offset < _bytes.size() and _status.is_ok():
		var value: int = _peek()
		if value == 0x22:
			_advance()
			return output.get_string_from_utf8()
		if value < 0x20:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return ""
		if value != 0x5C:
			output.append(_advance())
			if output.size() > ContentLimits.JSON_MAX_STRING_BYTES:
				_fail(ContentStatus.Code.JSON_LIMIT)
				return ""
			continue
		_advance()
		var escaped: int = _advance()
		match escaped:
			0x22: output.append(0x22)
			0x5C: output.append(0x5C)
			0x2F: output.append(0x2F)
			0x62: output.append(0x08)
			0x66: output.append(0x0C)
			0x6E: output.append(0x0A)
			0x72: output.append(0x0D)
			0x74: output.append(0x09)
			0x75:
				var codepoint: int = _parse_hex_quad()
				if not _status.is_ok(): return ""
				if codepoint >= 0xD800 and codepoint <= 0xDBFF:
					if _advance() != 0x5C or _advance() != 0x75:
						_fail(ContentStatus.Code.JSON_SYNTAX)
						return ""
					var low: int = _parse_hex_quad()
					if low < 0xDC00 or low > 0xDFFF:
						_fail(ContentStatus.Code.JSON_SYNTAX)
						return ""
					codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + (low - 0xDC00)
				elif codepoint >= 0xDC00 and codepoint <= 0xDFFF:
					_fail(ContentStatus.Code.JSON_SYNTAX)
					return ""
				output.append_array(String.chr(codepoint).to_utf8_buffer())
			_:
				_fail(ContentStatus.Code.JSON_SYNTAX)
				return ""
		if output.size() > ContentLimits.JSON_MAX_STRING_BYTES:
			_fail(ContentStatus.Code.JSON_LIMIT)
			return ""
	_fail(ContentStatus.Code.JSON_SYNTAX)
	return ""


func _parse_hex_quad() -> int:
	var result: int = 0
	for _index: int in range(4):
		var value: int = _advance()
		var digit: int = -1
		if value >= 0x30 and value <= 0x39: digit = value - 0x30
		elif value >= 0x41 and value <= 0x46: digit = value - 0x41 + 10
		elif value >= 0x61 and value <= 0x66: digit = value - 0x61 + 10
		if digit < 0:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return 0
		result = (result << 4) | digit
	return result


func _parse_integer() -> int:
	var negative: bool = false
	if _peek() == 0x2D:
		negative = true
		_advance()
	var digits_start: int = _offset
	if _peek() < 0x30 or _peek() > 0x39:
		_fail(ContentStatus.Code.JSON_SYNTAX)
		return 0
	if _peek() == 0x30:
		_advance()
		if _peek() >= 0x30 and _peek() <= 0x39:
			_fail(ContentStatus.Code.JSON_SYNTAX)
			return 0
	else:
		while _peek() >= 0x30 and _peek() <= 0x39:
			_advance()
	if _peek() == 0x2E or _peek() == 0x65 or _peek() == 0x45:
		_fail(ContentStatus.Code.NON_INTEGER_NUMBER)
		return 0
	var digits: PackedByteArray = _bytes.slice(digits_start, _offset)
	if digits.size() > 19:
		_fail(ContentStatus.Code.INTEGER_OVERFLOW)
		return 0
	if digits.size() == 19:
		var limit: PackedByteArray = (
			"9223372036854775808" if negative else "9223372036854775807"
		).to_ascii_buffer()
		for index: int in range(19):
			if digits[index] > limit[index]:
				_fail(ContentStatus.Code.INTEGER_OVERFLOW)
				return 0
			if digits[index] < limit[index]:
				break
	var result: int = 0
	for value: int in digits:
		var digit: int = value - 0x30
		result = result * 10 - digit if negative else result * 10 + digit
	return result
