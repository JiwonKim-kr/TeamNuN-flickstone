class_name ResolvePacingPolicy
extends RefCounted
## Deterministic authoritative cutoff for residual motion.

static func should_settle(world: SimWorld, status: SimStatus) -> bool:
	if not status.is_ok() or world == null: return false
	var has_motion := false
	for index: int in range(world.body_count()):
		var body: SimBody = world.body_at(index, status)
		if body.velocity().is_zero(): continue
		has_motion = true
		if not body.velocity().is_length_at_most_raw(BattleLimits.OUTCOME_SETTLE_MAX_SPEED_RAW, status): return false
	return has_motion and status.is_ok()
