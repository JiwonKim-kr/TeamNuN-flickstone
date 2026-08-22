extends SceneTree

func _init() -> void:
	var seed_hi := 0x1234
	var seed_lo := 0x5678
	var reverse := false
	var restore_after_turn := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed-hi="): seed_hi = int(argument.trim_prefix("--seed-hi="))
		elif argument.begins_with("--seed-lo="): seed_lo = int(argument.trim_prefix("--seed-lo="))
		elif argument == "--reverse": reverse = true
		elif argument.begins_with("--restore-after-turn="): restore_after_turn = int(argument.trim_prefix("--restore-after-turn="))
	var started := Time.get_ticks_msec()
	var status := SimStatus.new()
	var state := P1GrayboxFixture.create(seed_hi, seed_lo, reverse, status)
	var report := P1BattleDriver.run_with_restore_after_turn(state, restore_after_turn, status)
	if not status.is_ok():
		print("[FAIL] P1-5-BASELINE code=%d op=%d a=%d b=%d" % [status.code(), status.operation(), status.detail_a(), status.detail_b()]); quit(1); return
	print("[PASS] P1-5-BASELINE result=%d turns=%d ticks=%d elapsed_ms=%d" % [report.result, report.turn_count, report.sim_tick_count, Time.get_ticks_msec() - started])
	print("P1_BATCH_ROW:%d,%d,%d,%d,%d,%d,%s" % [report.result, report.turn_count, report.sim_tick_count, report.player_alive, report.enemy_alive, report.forced_settle_count, report.terminal_hash])
	print("P1_BATCH_SIM_GRAYBOX_RESULT: PASS"); quit(0)
