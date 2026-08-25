extends SceneTree

const RUNTIME_FINGERPRINT: String = "ed6dd1319f158a539ffe4bc89bce965ea1061586b1e462a7e211bb8f0f561e3e"
const VALID_A_FINGERPRINT: String = "83e404a9cc4337b921ef18a91adffe298bc43abf2ea59d8aac01749d3a5a36fb"
const VALID_B_FINGERPRINT: String = "9339f7f2939fc23c4c05a5e2013efc7180a0c3582269004604ed3ec68a2d4eaf"
const FIXTURE_ROOT: String = "res://pipeline/tests/fixtures/p2_content_catalog"
const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")

var _failures: int = 0
var _data_db: Node


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _parse_error(text: String, expected_code: int) -> bool:
	var status := ContentStatus.new()
	StrictJsonParser.parse_utf8(text.to_utf8_buffer(), status)
	return status.code() == expected_code and status.operation() == ContentStatus.Operation.JSON_PARSE


func _test_strict_parser() -> void:
	var valid_status := ContentStatus.new()
	var parsed: Variant = StrictJsonParser.parse_utf8(
		'{"min":-9223372036854775808,"max":9223372036854775807,"negative_zero":-0,"emoji":"\\ud83d\\ude00"}'.to_utf8_buffer(),
		valid_status
	)
	var values: Dictionary = parsed as Dictionary
	_check(
		"P2-1-C01-STRICT-INTEGER-UTF8-001",
		valid_status.is_ok()
		and values["min"] == -9223372036854775807 - 1
		and values["max"] == 9223372036854775807
		and values["negative_zero"] == 0
		and String(values["emoji"]).to_utf8_buffer().size() == 4
	)
	_check("P2-1-C01-DUPLICATE-KEY-001", _parse_error('{"x":1,"x":2}', ContentStatus.Code.DUPLICATE_KEY))
	_check("P2-1-C01-TRAILING-COMMA-001", _parse_error('{"x":1,}', ContentStatus.Code.JSON_SYNTAX))
	_check("P2-1-C01-DECIMAL-001", _parse_error('{"x":1.0}', ContentStatus.Code.NON_INTEGER_NUMBER))
	_check("P2-1-C01-EXPONENT-001", _parse_error('{"x":1e2}', ContentStatus.Code.NON_INTEGER_NUMBER))
	_check("P2-1-C01-OVERFLOW-001", _parse_error('{"x":9223372036854775808}', ContentStatus.Code.INTEGER_OVERFLOW))
	_check("P2-1-C01-RAW-NEWLINE-001", _parse_error("{\"x\":\"a\nb\"}", ContentStatus.Code.JSON_SYNTAX))
	_check("P2-1-C01-LONE-SURROGATE-001", _parse_error('{"x":"\\ud800"}', ContentStatus.Code.JSON_SYNTAX))
	var invalid_utf8 := PackedByteArray([0x7B, 0x22, 0x78, 0x22, 0x3A, 0x22, 0xFF, 0x22, 0x7D])
	var utf8_status := ContentStatus.new()
	StrictJsonParser.parse_utf8(invalid_utf8, utf8_status)
	_check("P2-1-C01-INVALID-UTF8-001", utf8_status.code() == ContentStatus.Code.INVALID_UTF8)
	var bom_status := ContentStatus.new()
	StrictJsonParser.parse_utf8(PackedByteArray([0xEF, 0xBB, 0xBF, 0x7B, 0x7D]), bom_status)
	_check("P2-1-C01-BOM-REJECTED-001", bom_status.code() == ContentStatus.Code.INVALID_UTF8)
	var deep: String = ""
	for _index: int in range(33): deep += "["
	deep += "0"
	for _index: int in range(33): deep += "]"
	_check("P2-1-C08-DEPTH-LIMIT-001", _parse_error(deep, ContentStatus.Code.JSON_LIMIT))


func _test_status_first_error() -> void:
	var status := ContentStatus.new()
	status.fail(ContentStatus.Code.JSON_SYNTAX, ContentStatus.Operation.JSON_PARSE, 2, 3, 4, 5, 6, 7)
	status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.ID_REGISTER, 9, 9, 9, 9, 9, 9)
	var copied: ContentStatus = status.copy()
	_check(
		"P2-1-C10-FIRST-ERROR-WINS-001",
		copied.code() == ContentStatus.Code.JSON_SYNTAX
		and copied.operation() == ContentStatus.Operation.JSON_PARSE
		and copied.document_kind_id() == 2
		and copied.record_numeric_id() == 3
		and copied.field_id() == 4
		and copied.line() == 5
		and copied.column() == 6
		and copied.byte_offset() == 7
	)


func _test_default_catalog() -> void:
	var status := ContentStatus.new()
	var loaded: bool = bool(_data_db.call("reload_catalog", "res://src/core/data", status))
	var catalog: ContentCatalog = _data_db.call("catalog_copy", status) as ContentCatalog
	_check(
		"P2-1-C09-DEFAULT-RUNTIME-CATALOG-001",
		loaded and status.is_ok()
		and bool(_data_db.call("is_ready"))
		and catalog.is_initialized()
		and catalog.piece_count() == 3
		and catalog.ability_count() == 1
		and catalog.status_count() == 1 and catalog.synergy_count() == 2
		and catalog.map_count() == 1 and catalog.enemy_count() == 5
		and catalog.act_count() == 1 and catalog.encounter_count() == 4
		and catalog.registry_entry_count() == 20
		and catalog.fingerprint_hex() == RUNTIME_FINGERPRINT
	)


func _test_catalog_load_lookup_and_immutability() -> void:
	var status := ContentStatus.new()
	var loaded: bool = bool(_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("valid_a"), status))
	var catalog: ContentCatalog = _data_db.call("catalog_copy", status) as ContentCatalog
	var piece_a: PieceDefinition = catalog.piece_by_numeric_id(1, status)
	var piece_b: PieceDefinition = catalog.piece_by_string_id("fixture_puck", status)
	var first_piece: PieceDefinition = catalog.piece_at(0, status)
	var second_piece: PieceDefinition = catalog.piece_at(1, status)
	var level_one: PieceLevelDefinition = piece_a.level_definition(1, status)
	var first_ref: ContentIdRef = level_one.ability_ref_at(0, status)
	var second_ref: ContentIdRef = level_one.ability_ref_at(1, status)
	var wall: AbilityDefinition = catalog.ability_by_numeric_id(7, status)
	_check(
		"P2-1-C02-C06-TYPED-LOOKUP-001",
		loaded and status.is_ok()
		and catalog.fingerprint_hex() == VALID_A_FINGERPRINT
		and catalog.piece_count() == 2 and catalog.ability_count() == 2
		and first_piece.numeric_id() == 1 and second_piece.numeric_id() == 10
		and piece_a.numeric_id() == piece_b.numeric_id() and piece_a != piece_b
		and piece_a.level_count() == 2 and level_one.max_hp() == 100
		and first_ref.numeric_id() == 1 and second_ref.numeric_id() == 7
		and wall.string_id() == "fixture_wall" and wall.trigger_id() == BattleTriggerId.Value.ON_WALL_BOUNCE
	)
	var fingerprint_copy: PackedByteArray = catalog.fingerprint_bytes()
	fingerprint_copy[0] = fingerprint_copy[0] ^ 0xFF
	var compatibility_copy: PackedByteArray = catalog.compatibility_bytes_for_test()
	compatibility_copy[0] = compatibility_copy[0] ^ 0xFF
	_check(
		"P2-1-C09-IMMUTABLE-COPIES-001",
		catalog.fingerprint_hex() == VALID_A_FINGERPRINT
		and catalog.compatibility_bytes_for_test()[0] == 0x46
	)
	var retired_status := ContentStatus.new()
	var retired: PieceDefinition = catalog.piece_by_numeric_id(99, retired_status)
	_check(
		"P2-1-C03-RETIRED-NOT-LOOKUP-001",
		not retired.is_initialized() and retired_status.code() == ContentStatus.Code.MISSING_REFERENCE
	)


func _test_order_fingerprint_and_atomic_reload() -> void:
	var status_a := ContentStatus.new()
	_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("valid_a"), status_a)
	var catalog_a: ContentCatalog = _data_db.call("catalog_copy", status_a) as ContentCatalog
	var bytes_a: PackedByteArray = catalog_a.compatibility_bytes_for_test()
	var hash_a: String = catalog_a.fingerprint_hex()

	var missing_status := ContentStatus.new()
	var missing_ok: bool = bool(_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("invalid_missing_reference"), missing_status))
	var retained_status := ContentStatus.new()
	var retained_hash: String = String(_data_db.call("fingerprint_hex", retained_status))
	_check(
		"P2-1-C06-ATOMIC-MISSING-REFERENCE-001",
		not missing_ok
		and missing_status.code() == ContentStatus.Code.MISSING_REFERENCE
		and retained_status.is_ok() and retained_hash == hash_a
	)

	var extra_status := ContentStatus.new()
	var extra_ok: bool = bool(_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("invalid_extra_file"), extra_status))
	var extra_retained_status := ContentStatus.new()
	_check(
		"P2-1-C02-EXTRA-JSON-ATOMIC-001",
		not extra_ok
		and extra_status.code() == ContentStatus.Code.INVALID_DOMAIN
		and String(_data_db.call("fingerprint_hex", extra_retained_status)) == hash_a
	)

	var reordered_status := ContentStatus.new()
	var reordered_ok: bool = bool(_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("valid_reordered"), reordered_status))
	var reordered: ContentCatalog = _data_db.call("catalog_copy", reordered_status) as ContentCatalog
	_check(
		"P2-1-C07-ORDER-INDEPENDENT-001",
		reordered_ok and reordered_status.is_ok()
		and reordered.compatibility_bytes_for_test() == bytes_a
		and reordered.fingerprint_hex() == hash_a
	)

	var changed_status := ContentStatus.new()
	var changed_ok: bool = bool(_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("valid_b"), changed_status))
	_check(
		"P2-1-C07-AUTHORITATIVE-CHANGE-001",
		changed_ok and changed_status.is_ok()
		and String(_data_db.call("fingerprint_hex", changed_status)) == VALID_B_FINGERPRINT
		and VALID_B_FINGERPRINT != hash_a
	)


func _test_repeatability() -> void:
	var all_equal: bool = true
	for _index: int in range(1000):
		var status := ContentStatus.new()
		if not bool(_data_db.call("reload_catalog", FIXTURE_ROOT.path_join("valid_a"), status)):
			all_equal = false
			break
		if not status.is_ok() or String(_data_db.call("fingerprint_hex", status)) != VALID_A_FINGERPRINT:
			all_equal = false
			break
	_check("P2-1-C07-REPEAT-1000-001", all_equal)
	var restore_status := ContentStatus.new()
	_data_db.call("reload_catalog", "res://src/core/data", restore_status)
	_check("P2-1-C12-RESTORE-RUNTIME-001", restore_status.is_ok() and String(_data_db.call("fingerprint_hex", restore_status)) == RUNTIME_FINGERPRINT)


func _init() -> void:
	print("== P2-1 strict JSON / typed catalog / fingerprint ==")
	_data_db = DATA_DB_SCRIPT.new() as Node
	root.add_child(_data_db)
	_check("P2-1-C09-DATA-DB-ADAPTER-LOAD-001", _data_db != null)
	if _data_db == null:
		print("P2_CONTENT_CATALOG_RESULT: FAIL (%d)" % _failures)
		quit(1)
		return
	_test_strict_parser()
	_test_status_first_error()
	_test_default_catalog()
	_test_catalog_load_lookup_and_immutability()
	_test_order_fingerprint_and_atomic_reload()
	_test_repeatability()
	if _failures == 0:
		print("P2_CONTENT_CATALOG_RESULT: PASS")
		quit(0)
	else:
		print("P2_CONTENT_CATALOG_RESULT: FAIL (%d)" % _failures)
		quit(1)
