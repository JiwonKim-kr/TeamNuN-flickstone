extends SceneTree

func _init() -> void:
	var started := Time.get_ticks_msec()
	var status := SimStatus.new()
	var report := P1BattleDriver.run(P1GrayboxFixture.create(0x1234, 0x5678, false, status), status)
	if not status.is_ok():
		print("[FAIL] P1-5-BASELINE code=%d op=%d a=%d b=%d" % [status.code(), status.operation(), status.detail_a(), status.detail_b()]); quit(1); return
	print("[PASS] P1-5-BASELINE result=%d turns=%d ticks=%d elapsed_ms=%d" % [report.result, report.turn_count, report.sim_tick_count, Time.get_ticks_msec() - started])
	print("P1_BATCH_ROW:%d,%d,%d,%d,%d,%d,%s" % [report.result, report.turn_count, report.sim_tick_count, report.player_alive, report.enemy_alive, report.forced_settle_count, report.terminal_hash])
	print("P1_BATCH_SIM_GRAYBOX_RESULT: PASS"); quit(0)
