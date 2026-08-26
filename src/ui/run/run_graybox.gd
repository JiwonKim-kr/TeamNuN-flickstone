class_name RunGraybox
extends Control

const SHOWCASE_CONFIG_PATH := "res://src/ui/run/submission_showcase.json"
const SHOWCASE_HINTS := {
	4: "탱탱볼 · 강한 반사로 벽과 기물 사이의 연쇄 충돌을 노려보세요.",
	5: "원시인 · 벽이나 아군에 닿기 전 적중하면 피해가 2배입니다.",
	6: "AI · 조준 중 각도·힘·첫 충돌 대상이 함께 계산됩니다.",
}

@onready var _header: PanelContainer = $Header
@onready var _header_label: Label = $Header/Margin/Label
@onready var _scroll: ScrollContainer = $Content
@onready var _body: VBoxContainer = $Content/Body
@onready var _footer: PanelContainer = $Footer
@onready var _footer_label: Label = $Footer/Margin/Label
@onready var _battle: P2ContentGraybox = $Battle
@onready var _save_overlay: PanelContainer = $SaveOverlay
@onready var _save_error_label: Label = $SaveOverlay/Margin/Rows/Error
@onready var _retry_button: Button = $SaveOverlay/Margin/Rows/Retry
@onready var _showcase_intro: PanelContainer = $ShowcaseIntro
@onready var _showcase_intro_error: Label = $ShowcaseIntro/Margin/Rows/Error
@onready var _showcase_start_button: Button = $ShowcaseIntro/Margin/Rows/Start
@onready var _showcase_intro_back: Button = $ShowcaseIntro/Margin/Rows/Back
@onready var _showcase_help_button: Button = $ShowcaseHelpButton
@onready var _showcase_help: PanelContainer = $ShowcaseHelp
@onready var _showcase_help_close: Button = $ShowcaseHelp/Margin/Rows/Close
@onready var _showcase_hint: PanelContainer = $ShowcaseHint
@onready var _showcase_hint_label: Label = $ShowcaseHint/Margin/Label
@onready var _showcase_hint_timer: Timer = $ShowcaseHintTimer
@onready var _showcase_end: PanelContainer = $ShowcaseEnd
@onready var _showcase_result: Label = $ShowcaseEnd/Margin/Rows/Result
@onready var _showcase_retry: Button = $ShowcaseEnd/Margin/Rows/Retry
@onready var _showcase_full_run: Button = $ShowcaseEnd/Margin/Rows/FullRun

var _catalog := ContentCatalog.new()
var _seed_input: LineEdit = null
var _formation_ids: Array[int] = []
var _pending_battle_outcome := RunBattleOutcome.new()
var _showcase_config := SubmissionShowcaseConfig.new()
var _showcase_status := ContentStatus.new()
var _showcase_active: bool = false
var _showcase_seen_piece_hints: Dictionary = {}
var _showcase_zone_hint_seen: bool = false

func _ready() -> void:
	_catalog = RunManager.catalog_copy()
	RunManager.state_changed.connect(_on_state_changed)
	RunManager.battle_requested.connect(_on_battle_requested)
	RunManager.persistence_failed.connect(_on_persistence_failed)
	_battle.run_battle_finished.connect(_on_battle_finished)
	_battle.showcase_battle_finished.connect(_on_showcase_battle_finished)
	_battle.player_turn_started.connect(_on_showcase_player_turn_started)
	_battle.turn_start_zone_damage_applied.connect(_on_showcase_zone_damage)
	_retry_button.pressed.connect(_retry_outcome_save)
	_showcase_start_button.pressed.connect(_start_showcase_battle)
	_showcase_intro_back.pressed.connect(_close_showcase_intro)
	_showcase_help_button.pressed.connect(_open_showcase_help)
	_showcase_help_close.pressed.connect(_close_showcase_help)
	_showcase_hint_timer.timeout.connect(_hide_showcase_hint)
	_showcase_retry.pressed.connect(_retry_showcase)
	_showcase_full_run.pressed.connect(_leave_showcase)
	_showcase_config = SubmissionShowcaseConfig.load_file(SHOWCASE_CONFIG_PATH, _catalog, _showcase_status)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _showcase_active and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_open_showcase_help()
		get_viewport().set_input_as_handled()

func _clear_body() -> void:
	for child: Node in _body.get_children(): child.queue_free()

func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)

func _text(text: String, muted: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if muted: label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.85))
	_body.add_child(label)

func _button(text: String, callable: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 58)
	button.pressed.connect(callable)
	_body.add_child(button)
	return button

func _phase_name(phase_id: int) -> String:
	return String(RunPhase.Value.keys()[phase_id]) if RunPhase.is_valid(phase_id) else "INVALID"

func _node_type_name(type_id: int) -> String:
	match type_id:
		RunNodeType.Value.NORMAL_BATTLE: return "일반 전투"
		RunNodeType.Value.ELITE_BATTLE: return "엘리트 전투"
		RunNodeType.Value.SHOP: return "상점"
		RunNodeType.Value.EVENT: return "이벤트"
		RunNodeType.Value.REST: return "휴식"
		RunNodeType.Value.BOSS: return "보스"
	return "알 수 없음"

func _refresh() -> void:
	if _showcase_active: return
	_clear_body()
	_save_overlay.visible = false
	if not RunManager.has_active_run():
		_show_start()
		return
	var status := SimStatus.new()
	var state: RunState = RunManager.state_copy(status)
	if not status.is_ok():
		_footer_label.text = "런 상태 오류 %d/%d" % [status.code(), status.operation()]
		return
	var battle_visible: bool = state.phase_id() == RunPhase.Value.BATTLE
	_header.visible = not battle_visible
	_scroll.visible = not battle_visible
	_footer.visible = not battle_visible
	_battle.visible = battle_visible
	if battle_visible: return
	_header_label.text = "ACT %d · phase %s · life %d/%d · gold %d\nseed %08x%08x · fp %s" % [state.act_numeric_id(), _phase_name(state.phase_id()), state.life(), state.max_life(), state.gold(), state.seed_hi(), state.seed_lo(), _catalog.fingerprint_hex().left(8)]
	_footer_label.text = "단일 continue 저장 · node 경계 자동 저장"
	match state.phase_id():
		RunPhase.Value.MAP_CHOICE: _show_map(state)
		RunPhase.Value.FORMATION: _show_formation(state)
		RunPhase.Value.REWARD, RunPhase.Value.SHOP, RunPhase.Value.EVENT, RunPhase.Value.REST: _show_pending(state)
		RunPhase.Value.ACT_COMPLETE: _show_act_complete(state)
		RunPhase.Value.RUN_COMPLETE, RunPhase.Value.RUN_FAILED: _show_terminal(state)
		_: _text("지원하지 않는 phase: %s" % _phase_name(state.phase_id()))

func _show_start() -> void:
	_header.visible = true
	_scroll.visible = true
	_footer.visible = true
	_battle.visible = false
	_header_label.text = "Flickstone · P4-6 개발 런"
	_title("Flickstone 전투를 바로 체험하세요")
	_button("5분 전투 체험", _open_showcase_intro, _showcase_status.is_ok() and _showcase_config.is_initialized())
	if not _showcase_status.is_ok():
		_text("체험 설정 오류 · code %d / op %d" % [_showcase_status.code(), _showcase_status.operation()])
	_title("전체 개발 런")
	_text("16자리 hex seed로 5층 개발 Act를 시작합니다.", true)
	_seed_input = LineEdit.new()
	_seed_input.text = "0000000000000001"
	_seed_input.placeholder_text = "0000000000000001"
	_seed_input.custom_minimum_size = Vector2(0, 52)
	_body.add_child(_seed_input)
	_button("새 런", _start_new_run)
	var probe_status := RunSaveStatus.new()
	var probe: int = RunManager.continue_probe(probe_status)
	_button("이어하기", _continue_run, probe == SaveManager.ProbeResult.VALID)
	if probe == SaveManager.ProbeResult.MISSING:
		_text("이어할 저장이 없습니다.", true)
	elif probe == SaveManager.ProbeResult.INVALID:
		_text("저장 진단: code %d / op %d / snapshot %d/%d" % [probe_status.code(), probe_status.operation(), probe_status.sim_code(), probe_status.sim_operation()])
	_footer_label.text = "제출용 직접 체험 · 전체 5층 런 · 단일 continue 저장"

func _open_showcase_intro() -> void:
	if not _showcase_status.is_ok() or not _showcase_config.is_initialized(): return
	_showcase_intro_error.visible = false
	_set_main_ui_visible(false)
	_showcase_intro.visible = true

func _close_showcase_intro() -> void:
	_showcase_intro.visible = false
	_set_main_ui_visible(true)

func _set_main_ui_visible(value: bool) -> void:
	_header.visible = value
	_scroll.visible = value
	_footer.visible = value

func _start_showcase_battle() -> void:
	_showcase_intro_error.visible = false
	_showcase_seen_piece_hints.clear()
	_showcase_zone_hint_seen = false
	_showcase_end.visible = false
	_showcase_help.visible = false
	_showcase_hint.visible = false
	_showcase_intro.visible = false
	_showcase_active = true
	_set_main_ui_visible(false)
	_battle.visible = true
	_showcase_help_button.visible = true
	var status := SimStatus.new()
	if not _battle.start_showcase_battle(
		_showcase_config.map_numeric_id(),
		_showcase_config.encounter_numeric_id(),
		_showcase_config.piece_numeric_ids(),
		_showcase_config.seed_hi(),
		_showcase_config.seed_lo(),
		_catalog,
		status
	):
		_showcase_active = false
		_battle.visible = false
		_showcase_help_button.visible = false
		_showcase_intro_error.text = "전투 시작 오류 · %d/%d" % [status.code(), status.operation()]
		_showcase_intro_error.visible = true
		_showcase_intro.visible = true

func _show_showcase_hint(text: String) -> void:
	if not _showcase_active or _showcase_end.visible: return
	_showcase_hint_label.text = text
	_showcase_hint.visible = true
	_showcase_hint_timer.start()

func _hide_showcase_hint() -> void:
	_showcase_hint.visible = false

func _on_showcase_player_turn_started(piece_numeric_id: int) -> void:
	if not _showcase_active or _showcase_seen_piece_hints.has(piece_numeric_id): return
	_showcase_seen_piece_hints[piece_numeric_id] = true
	if SHOWCASE_HINTS.has(piece_numeric_id): _show_showcase_hint(String(SHOWCASE_HINTS[piece_numeric_id]))

func _on_showcase_zone_damage() -> void:
	if not _showcase_active or _showcase_zone_hint_seen: return
	_showcase_zone_hint_seen = true
	_show_showcase_hint("피해 구역 · 겹친 구역마다 턴 시작 피해를 각각 받습니다.")

func _open_showcase_help() -> void:
	if not _showcase_active or _showcase_end.visible: return
	_showcase_hint.visible = false
	_showcase_help.visible = true

func _close_showcase_help() -> void:
	_showcase_help.visible = false

func _on_showcase_battle_finished(result_id: int) -> void:
	if not _showcase_active: return
	_showcase_hint_timer.stop()
	_showcase_hint.visible = false
	_showcase_help.visible = false
	_showcase_help_button.visible = false
	var result_text := "무승부"
	if result_id == BattleResult.Value.PLAYER_VICTORY: result_text = "승리! 세 기물의 차이를 확인했습니다."
	elif result_id == BattleResult.Value.PLAYER_DEFEAT: result_text = "패배 · 다른 각도와 충돌 순서로 다시 도전해보세요."
	_showcase_result.text = result_text
	_showcase_end.visible = true

func _retry_showcase() -> void:
	_battle.leave_showcase_mode()
	_start_showcase_battle()

func _leave_showcase() -> void:
	_showcase_intro.visible = false
	_showcase_help.visible = false
	_showcase_hint.visible = false
	_showcase_end.visible = false
	_showcase_help_button.visible = false
	_battle.visible = false
	_battle.leave_showcase_mode()
	_showcase_active = false
	_refresh()

func _valid_seed(value: String) -> bool:
	if value.length() != 16: return false
	for index: int in range(value.length()):
		if "0123456789abcdefABCDEF".find(value[index]) < 0: return false
	return true

func _start_new_run() -> void:
	var seed: String = _seed_input.text.strip_edges()
	if not _valid_seed(seed):
		_footer_label.text = "seed는 정확히 16자리 0-9/a-f여야 합니다."
		return
	var sim_status := SimStatus.new()
	var save_status := RunSaveStatus.new()
	if not RunManager.start_new_development_run(seed.substr(0, 8).hex_to_int(), seed.substr(8, 8).hex_to_int(), sim_status, save_status):
		_show_command_error(sim_status, save_status)

func _continue_run() -> void:
	var sim_status := SimStatus.new()
	var save_status := RunSaveStatus.new()
	if not RunManager.continue_run(sim_status, save_status): _show_command_error(sim_status, save_status)

func _reachable_nodes(state: RunState, status: SimStatus) -> Array[RunNode]:
	var result: Array[RunNode] = []
	var graph: RunNodeGraph = state.graph_copy(status)
	if not status.is_ok(): return result
	if state.completed_node_count() == 0:
		for index: int in range(graph.node_count()):
			var node: RunNode = graph.node_at(index, status)
			if node.floor_index() == 1: result.append(node)
		return result
	var source_id: int = state.completed_node_id_at(state.completed_node_count() - 1, status)
	var source: RunNode = graph.node_by_id(source_id, status)
	for index: int in range(source.next_node_count()): result.append(graph.node_by_id(source.next_node_id_at(index, status), status))
	return result

func _show_map(state: RunState) -> void:
	_title("다음 노드 선택")
	var status := SimStatus.new()
	for node: RunNode in _reachable_nodes(state, status):
		_button("F%d · %s · node #%d" % [node.floor_index(), _node_type_name(node.node_type_id()), node.node_id()], _enter_node.bind(node.node_id()))
	_text(_roster_summary(state), true)
	for index: int in range(state.consumable_stack_count()):
		var stack: RunConsumableStack = state.consumable_stack_at(index, status)
		var content_status := ContentStatus.new()
		var item: ConsumableDefinition = _catalog.consumable_by_numeric_id(stack.consumable_numeric_id(), content_status)
		_button("사용: %s ×%d" % [item.string_id(), stack.count()], _use_consumable.bind(stack.consumable_numeric_id()), state.life() < state.max_life())

func _enter_node(node_id: int) -> void:
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if not RunManager.enter_node(node_id, sim_status, save_status): _show_command_error(sim_status, save_status)

func _expected_deployment(state: RunState, status: SimStatus) -> int:
	var graph: RunNodeGraph = state.graph_copy(status)
	var node: RunNode = graph.node_by_id(state.current_node_id(), status)
	var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = _catalog.encounter_by_numeric_id(node.content_numeric_id(), content_status)
	var map_definition: MapDefinition = _catalog.map_by_numeric_id(encounter.map_ref().numeric_id(), content_status)
	if not content_status.is_ok():
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD)
		return 0
	return mini(state.deployment_capacity(), mini(state.roster_count(), map_definition.deploy_count()))

func _show_formation(state: RunState) -> void:
	_title("편성")
	var status := SimStatus.new()
	var expected: int = _expected_deployment(state, status)
	_text("맵 슬롯 순서대로 정확히 %d기를 선택합니다." % expected, true)
	_formation_ids.clear()
	if state.deployment_count() == expected:
		for index: int in range(expected): _formation_ids.append(state.deployment_instance_id_at(index, status))
	else:
		for index: int in range(expected): _formation_ids.append(state.roster_at(index, status).instance_id())
	for index: int in range(state.roster_count()):
		var piece: RunPieceInstance = state.roster_at(index, status)
		var content_status := ContentStatus.new(); var definition: PieceDefinition = _catalog.piece_by_numeric_id(piece.piece_numeric_id(), content_status)
		var check := CheckButton.new()
		check.text = "#%d · %s · L%d" % [piece.instance_id(), definition.string_id(), piece.level()]
		check.button_pressed = _formation_ids.has(piece.instance_id())
		check.custom_minimum_size = Vector2(0, 48)
		check.toggled.connect(_toggle_formation.bind(piece.instance_id(), expected))
		_body.add_child(check)
	_button("편성 확정 후 전투", _confirm_formation.bind(expected))

func _toggle_formation(pressed: bool, instance_id: int, expected: int) -> void:
	if pressed:
		if not _formation_ids.has(instance_id): _formation_ids.append(instance_id)
	else:
		_formation_ids.erase(instance_id)
	_formation_ids.sort()
	_footer_label.text = "선택 %d/%d · 작은 instance ID 순으로 슬롯 배치" % [_formation_ids.size(), expected]

func _confirm_formation(expected: int) -> void:
	if _formation_ids.size() != expected:
		_footer_label.text = "정확히 %d기를 선택해야 합니다." % expected
		return
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if not RunManager.set_deployment(_formation_ids, sim_status, save_status):
		_show_command_error(sim_status, save_status); return
	sim_status = SimStatus.new(); save_status = RunSaveStatus.new()
	var request: RunBattleRequest = RunManager.begin_battle(sim_status, save_status)
	if not request.is_initialized(): _show_command_error(sim_status, save_status)

func _choice_label(entry: RunChoiceEntry) -> String:
	match entry.kind_id():
		RunChoiceKind.Value.RECRUIT_PIECE:
			var cs := ContentStatus.new(); return "영입 · %s" % _catalog.piece_by_numeric_id(entry.primary_numeric_id(), cs).string_id()
		RunChoiceKind.Value.TAKE_RELIC:
			var cs := ContentStatus.new(); return "유물 · %s · %dG" % [_catalog.relic_by_numeric_id(entry.primary_numeric_id(), cs).string_id(), entry.cost()]
		RunChoiceKind.Value.TAKE_CONSUMABLE:
			var cs := ContentStatus.new(); return "소모품 · %s ×%d · %dG" % [_catalog.consumable_by_numeric_id(entry.primary_numeric_id(), cs).string_id(), entry.amount(), entry.cost()]
		RunChoiceKind.Value.GAIN_GOLD: return "골드 +%d" % entry.amount()
		RunChoiceKind.Value.RECOVER_LIFE: return "라이프 +%d" % entry.amount()
		RunChoiceKind.Value.MERGE_PIECES: return "같은 기물·레벨 2기 합성"
		RunChoiceKind.Value.EVENT_OPTION: return "이벤트 선택 #%d" % entry.choice_id()
		RunChoiceKind.Value.TAKE_REVENGE: return "다음 전투 보복 효과"
		RunChoiceKind.Value.LEAVE_SHOP: return "나가기"
	return "선택 #%d" % entry.choice_id()

func _merge_pair(state: RunState, status: SimStatus) -> Array[int]:
	for left_index: int in range(state.roster_count()):
		var left: RunPieceInstance = state.roster_at(left_index, status)
		for right_index: int in range(left_index + 1, state.roster_count()):
			var right: RunPieceInstance = state.roster_at(right_index, status)
			if left.piece_numeric_id() == right.piece_numeric_id() and left.level() == right.level() and left.level() < 3:
				return [left.instance_id(), right.instance_id()]
	return []

func _show_pending(state: RunState) -> void:
	_title(_phase_name(state.phase_id()))
	var pending: RunPendingChoice = state.pending_choice_copy()
	var status := SimStatus.new()
	var pair: Array[int] = _merge_pair(state, status)
	for index: int in range(pending.entry_count()):
		var entry: RunChoiceEntry = pending.entry_at(index, status)
		var label: String = _choice_label(entry)
		var first_id: int = 0; var second_id: int = 0
		if entry.kind_id() == RunChoiceKind.Value.MERGE_PIECES and pair.size() == 2:
			first_id = pair[0]; second_id = pair[1]; label += " · #%d + #%d" % [first_id, second_id]
		_button(label, _choose_pending.bind(entry.choice_id(), first_id, second_id), entry.enabled())
	_text(_roster_summary(state), true)

func _choose_pending(choice_id: int, first_id: int, second_id: int) -> void:
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if not RunManager.choose_pending(choice_id, first_id, second_id, sim_status, save_status): _show_command_error(sim_status, save_status)

func _use_consumable(numeric_id: int) -> void:
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if not RunManager.use_consumable(numeric_id, sim_status, save_status): _show_command_error(sim_status, save_status)

func _show_act_complete(state: RunState) -> void:
	_title("개발 Act 보스 격파")
	_text(_roster_summary(state))
	_button("런 완료 기록", _complete_run)

func _complete_run() -> void:
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if not RunManager.complete_run(sim_status, save_status): _show_command_error(sim_status, save_status)

func _show_terminal(state: RunState) -> void:
	_title("런 완료" if state.phase_id() == RunPhase.Value.RUN_COMPLETE else "런 실패")
	_text("seed %08x%08x · 완료 node %d개 · life %d/%d · gold %d" % [state.seed_hi(), state.seed_lo(), state.completed_node_count(), state.life(), state.max_life(), state.gold()])
	_text(_roster_summary(state), true)
	_seed_input = LineEdit.new(); _seed_input.text = "%08x%08x" % [state.seed_hi(), state.seed_lo()]; _seed_input.custom_minimum_size = Vector2(0, 52); _body.add_child(_seed_input)
	_button("새 런으로 교체", _start_new_run)

func _roster_summary(state: RunState) -> String:
	var status := SimStatus.new(); var values: PackedStringArray = PackedStringArray()
	for index: int in range(state.roster_count()):
		var piece: RunPieceInstance = state.roster_at(index, status)
		var content_status := ContentStatus.new(); var definition: PieceDefinition = _catalog.piece_by_numeric_id(piece.piece_numeric_id(), content_status)
		values.append("#%d %s L%d" % [piece.instance_id(), definition.string_id(), piece.level()])
	return "로스터: " + ", ".join(values)

func _on_state_changed(_state: RunState) -> void:
	_refresh()

func _on_battle_requested(request: RunBattleRequest) -> void:
	_battle.visible = true
	_header.visible = false; _scroll.visible = false; _footer.visible = false
	var status := SimStatus.new()
	if not _battle.start_run_battle(request, _catalog, status):
		_footer_label.text = "전투 시작 오류 %d/%d" % [status.code(), status.operation()]

func _on_battle_finished(outcome: RunBattleOutcome) -> void:
	_pending_battle_outcome = outcome.copy()
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if RunManager.accept_battle_outcome(outcome, sim_status, save_status):
		_pending_battle_outcome = RunBattleOutcome.new(); _battle.leave_run_mode(); _refresh()
	else:
		_show_save_overlay(sim_status, save_status)

func _retry_outcome_save() -> void:
	var sim_status := SimStatus.new(); var save_status := RunSaveStatus.new()
	if RunManager.retry_battle_outcome_commit(sim_status, save_status):
		_save_overlay.visible = false; _pending_battle_outcome = RunBattleOutcome.new(); _battle.leave_run_mode(); _refresh()
	else: _show_save_overlay(sim_status, save_status)

func _on_persistence_failed(status: RunSaveStatus) -> void:
	_footer_label.text = "저장 실패 %d/%d" % [status.code(), status.operation()]

func _show_save_overlay(sim_status: SimStatus, save_status: RunSaveStatus) -> void:
	_save_error_label.text = "전투 결과 저장 실패\nsave %d/%d · sim %d/%d\n재시도 전에는 추가 입력이 잠깁니다." % [save_status.code(), save_status.operation(), sim_status.code(), sim_status.operation()]
	_save_overlay.visible = true

func _show_command_error(sim_status: SimStatus, save_status: RunSaveStatus) -> void:
	_footer_label.text = "명령 실패 · sim %d/%d · save %d/%d" % [sim_status.code(), sim_status.operation(), save_status.code(), save_status.operation()]
