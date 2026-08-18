class_name SimStateHash
extends RefCounted
## Project-owned SHA-256 used for deterministic regression snapshots.
##
## This implementation is intentionally independent of engine hashing APIs.
## Test adapters cross-check it against engine and Python references.

const U32_MASK: int = 0xFFFFFFFF
const HEX_DIGITS: String = "0123456789abcdef"
const INITIAL: PackedInt64Array = [
	0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
	0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
]
const ROUND_CONSTANTS: PackedInt64Array = [
	0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
	0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
	0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
	0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
	0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
	0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
	0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
	0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
	0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
	0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
	0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
	0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
	0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
	0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
	0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
	0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
]


static func _rotate_right(value: int, amount: int) -> int:
	return ((value >> amount) | (value << (32 - amount))) & U32_MASK


static func _small_sigma_0(value: int) -> int:
	return (
		_rotate_right(value, 7)
		^ _rotate_right(value, 18)
		^ (value >> 3)
	) & U32_MASK


static func _small_sigma_1(value: int) -> int:
	return (
		_rotate_right(value, 17)
		^ _rotate_right(value, 19)
		^ (value >> 10)
	) & U32_MASK


static func _large_sigma_0(value: int) -> int:
	return (
		_rotate_right(value, 2)
		^ _rotate_right(value, 13)
		^ _rotate_right(value, 22)
	) & U32_MASK


static func _large_sigma_1(value: int) -> int:
	return (
		_rotate_right(value, 6)
		^ _rotate_right(value, 11)
		^ _rotate_right(value, 25)
	) & U32_MASK


static func sha256(input: PackedByteArray, status: SimStatus) -> PackedByteArray:
	if not status.is_ok():
		return PackedByteArray()
	var message: PackedByteArray = input.duplicate()
	var bit_length: int = message.size() * 8
	message.append(0x80)
	while message.size() % 64 != 56:
		message.append(0)
	for shift: int in range(56, -1, -8):
		message.append((bit_length >> shift) & 0xFF)

	var hash: Array[int] = []
	for value: int in INITIAL:
		hash.append(value)
	for block_start: int in range(0, message.size(), 64):
		var words: Array[int] = []
		words.resize(64)
		for index: int in range(16):
			var offset: int = block_start + index * 4
			words[index] = (
				(message[offset] << 24)
				| (message[offset + 1] << 16)
				| (message[offset + 2] << 8)
				| message[offset + 3]
			) & U32_MASK
		for index: int in range(16, 64):
			words[index] = (
				_small_sigma_1(words[index - 2])
				+ words[index - 7]
				+ _small_sigma_0(words[index - 15])
				+ words[index - 16]
			) & U32_MASK

		var a: int = hash[0]
		var b: int = hash[1]
		var c: int = hash[2]
		var d: int = hash[3]
		var e: int = hash[4]
		var f: int = hash[5]
		var g: int = hash[6]
		var h: int = hash[7]
		for index: int in range(64):
			var choice: int = ((e & f) ^ ((~e) & g)) & U32_MASK
			var temp_1: int = (
				h
				+ _large_sigma_1(e)
				+ choice
				+ ROUND_CONSTANTS[index]
				+ words[index]
			) & U32_MASK
			var majority: int = ((a & b) ^ (a & c) ^ (b & c)) & U32_MASK
			var temp_2: int = (_large_sigma_0(a) + majority) & U32_MASK
			h = g
			g = f
			f = e
			e = (d + temp_1) & U32_MASK
			d = c
			c = b
			b = a
			a = (temp_1 + temp_2) & U32_MASK
		hash[0] = (hash[0] + a) & U32_MASK
		hash[1] = (hash[1] + b) & U32_MASK
		hash[2] = (hash[2] + c) & U32_MASK
		hash[3] = (hash[3] + d) & U32_MASK
		hash[4] = (hash[4] + e) & U32_MASK
		hash[5] = (hash[5] + f) & U32_MASK
		hash[6] = (hash[6] + g) & U32_MASK
		hash[7] = (hash[7] + h) & U32_MASK

	var result: PackedByteArray = PackedByteArray()
	for value: int in hash:
		result.append((value >> 24) & 0xFF)
		result.append((value >> 16) & 0xFF)
		result.append((value >> 8) & 0xFF)
		result.append(value & 0xFF)
	return result


static func hex_digest(input: PackedByteArray, status: SimStatus) -> String:
	var digest: PackedByteArray = sha256(input, status)
	if not status.is_ok():
		return ""
	var result: String = ""
	for value: int in digest:
		result += HEX_DIGITS.substr((value >> 4) & 0xF, 1)
		result += HEX_DIGITS.substr(value & 0xF, 1)
	return result


static func snapshot_hex(snapshot: SimSnapshot, status: SimStatus) -> String:
	if snapshot == null:
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.HASH_SHA256,
			0,
			0
		)
		return ""
	return hex_digest(snapshot.encode(status), status)
